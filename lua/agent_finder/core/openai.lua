local M = {}

local config = require('agent_finder.config')
local tools = require('agent_finder.core.tools')
local util = require('agent_finder.core.util')
local debug_log = util.debug_log

local json = vim.fn.json_encode
local decode = vim.json and vim.json.decode or vim.fn.json_decode

local curl_available, curl = pcall(require, "plenary.curl")
if not curl_available then
  curl = nil
end

-- Python adapter: JSON-IO subprocess runner
function M._generate_python_response_async(agent, user_message, chat_history, callback)
  local cmd = agent.command
  local args = agent.args or {}
  local max_iters = agent.max_iters or 10
  local input_list = {}
  if chat_history then
    for _, msg in ipairs(chat_history) do
      table.insert(input_list, { role = msg.role or 'user', content = msg.content or '' })
    end
  end
  table.insert(input_list, { role = 'user', content = user_message or '' })

  local function run_once(payload, on_done)
    local stdin_data = vim.fn.json_encode(payload)
    local full_cmd = cmd
    if args and #args > 0 then
      full_cmd = cmd .. ' ' .. table.concat(args, ' ')
    end
    local out = vim.fn.systemlist(full_cmd, stdin_data)
    local text = table.concat(out or {}, '\n')
    if vim.v.shell_error ~= 0 then
      on_done({ success = false, error = text ~= '' and text or 'Python agent process error' })
      return
    end
    local ok, decoded = pcall(vim.fn.json_decode, text)
    if not ok then
      on_done({ success = false, error = 'Invalid JSON from python agent' })
      return
    end
    on_done({ success = true, data = decoded })
  end

  local instructions = agent.prompt or ''
  local iter = 1
  local function step()
    local payload = {
      instructions = instructions,
      messages = input_list,
      tools = tools.generate_tools_schema(),
      iteration = iter,
    }
    run_once(payload, function(resp)
      if not resp.success then callback(resp); return end
      local data = resp.data or {}
      if data.tool_call then
        local tool_name = data.tool_call.name or (data.tool_call["function"] and data.tool_call["function"].name)
        local args_tbl = data.tool_call.arguments or {}
        if type(args_tbl) == 'string' then
          local ok, parsed = pcall(vim.fn.json_decode, args_tbl)
          args_tbl = ok and parsed or {}
        end
        if not tool_name then
          callback({ success = false, error = 'Python agent returned invalid tool_call' })
          return
        end
        local tool_result = tools.execute_tool(tool_name, args_tbl)
        local tool_result_json = vim.fn.json_encode(tool_result.data or tool_result)
        table.insert(input_list, { role = 'assistant', content = string.format("Tool '%s' result as JSON:\n%s", tool_name, tool_result_json) })
        iter = iter + 1
        if iter <= max_iters then
          step()
        else
          callback({ success = false, error = 'No final response after processing iterations (python)' })
        end
      else
        callback({ success = true, content = data.content or data.message or '' })
      end
    end)
  end

  step()
end

-- Helper: convert local tools -> OpenAI schema (supports both APIs)
local function build_tools_for(api_kind, tools_schema)
  if not tools_schema then return nil end
  debug_log("build_tools_for called with tools_schema:", vim.inspect(tools_schema))
  local out = {}
  for tool_key, spec in pairs(tools_schema) do
    debug_log("Processing tool:", tool_key, "spec:", vim.inspect(spec))
    local raw_name = spec.name or spec.tool_name or tool_key

    local parameters = spec.parameters or { type = "object", properties = {}, required = {} }
    parameters.type = parameters.type or "object"
    parameters.properties = parameters.properties or {}
    parameters.required = parameters.required or {}

    if parameters.properties.max_depth and parameters.properties.max_depth.type == "number" then
      parameters.properties.max_depth.type = "integer"
    end

    if api_kind == "responses" then
      local tool_obj = {
        type = "function",
        name = raw_name,
        description = spec.description or "",
        parameters = parameters,
      }
      debug_log("Built function (flat):", vim.inspect(tool_obj))
      table.insert(out, tool_obj)
    else
      local fn = {
        name = raw_name,
        description = spec.description or "",
        parameters = parameters,
      }
      local wrapped = { type = "function", ["function"] = fn }
      debug_log("Built function (nested):", vim.inspect(wrapped))
      table.insert(out, wrapped)
    end
  end
  return (#out > 0) and out or nil
end

-- Helper: robust content extractor
local function extract_content(api_kind, body)
  if api_kind == "responses" then
    if body.output_text and body.output_text ~= "" then
      return { kind = "text", content = body.output_text }
    end
    if body.output and type(body.output) == "table" then
      for _, item in ipairs(body.output) do
        if item.type == "message" and item.content then
          local buf = {}
          for _, c in ipairs(item.content) do
            if c.type == "output_text" and c.text then table.insert(buf, c.text)
            elseif c.type == "text" and c.text then table.insert(buf, c.text) end
          end
          if #buf > 0 then return { kind = "text", content = table.concat(buf, "") } end
        elseif item.type == "tool_call" or item.type == "function_call" then
          return { kind = "tool_call", content = item }
        end
      end
    end
    if body.refusal and body.refusal ~= "" then
      return { kind = "refusal", content = body.refusal }
    end
    return { kind = "none", content = nil }
  end

  if body.choices and body.choices[1] then
    local m = body.choices[1].message or {}
    if m.content and m.content ~= "" then
      return { kind = "text", content = m.content }
    end
    if m.tool_calls and #m.tool_calls > 0 then
      return { kind = "tool_call", content = m.tool_calls[1] }
    end
    if m.refusal and m.refusal ~= "" then
      return { kind = "refusal", content = m.refusal }
    end
  end
  return { kind = "none", content = nil }
end

function M._call_openai_api(messages, model, api_key, opts)
  model = model or "gpt-5-nano-2025-08-07"
  api_key = api_key or vim.env.OPENAI_API_KEY
  opts = opts or {}

  if not api_key then
    return { success = false, error = "OpenAI API key not found. Set OPENAI_API_KEY or configure it in agents.lua" }
  end

  local api_kind = (opts.api == "chat") and "chat" or "responses"
  local url = (api_kind == "responses") and "https://api.openai.com/v1/responses" or "https://api.openai.com/v1/chat/completions"

  local tools_schema = nil
  local available_tools = tools.get_tools and tools.get_tools() or nil
  debug_log("Available tools:", vim.inspect(available_tools))
  if available_tools and type(available_tools) == "table" and not vim.tbl_isempty(available_tools) then
    tools_schema = tools.generate_tools_schema and tools.generate_tools_schema() or nil
    debug_log("Generated tools schema:", vim.inspect(tools_schema))
  end
  local openai_tools = build_tools_for(api_kind, tools_schema)
  debug_log("OpenAI tools:", vim.inspect(openai_tools))

  local payload
  if api_kind == "responses" then
    payload = {
      model = model,
      input = messages,
      tools = openai_tools,
      tool_choice = opts.tool_choice or "auto",
      max_output_tokens = opts.max_tokens,
      response_format = opts.response_format,
      instructions = opts.instructions,
    }
  else
    payload = {
      model = model,
      messages = messages,
      tools = openai_tools,
      tool_choice = opts.tool_choice,
      max_tokens = opts.max_tokens,
      response_format = opts.response_format,
    }
  end

  if not curl then
    return { success = false, error = "HTTP client unavailable: plenary.curl not found" }
  end
  local ok, r = pcall(curl.post, url, {
    headers = {
      ["Authorization"] = "Bearer " .. api_key,
      ["Content-Type"] = "application/json",
    },
    body = json(payload),
    timeout = tonumber((opts and opts.timeout_ms) or 300000),
  })
  if not ok or not r or not r.status then
    return { success = false, error = "HTTP request failed or timed out" }
  end
  if r.status < 200 or r.status >= 300 then
    return { success = false, error = ("HTTP %d: %s"):format(r.status, r.body or "") }
  end
  local body_tbl = decode(r.body)
  local out = extract_content(api_kind, body_tbl)
  if out.kind == "text" then
    return { success = true, content = out.content, raw = body_tbl }
  elseif out.kind == "tool_call" then
    return { success = true, tool_call = out.content, raw = body_tbl }
  elseif out.kind == "refusal" then
    return { success = false, error = out.content, raw = body_tbl }
  else
    return { success = false, error = "no content found", raw = body_tbl }
  end
end

function M._call_openai_api_async(messages, model, api_key, opts, callback)
  model = model or "gpt-5-nano-2025-08-07"
  api_key = api_key or vim.env.OPENAI_API_KEY
  opts = opts or {}
  if type(callback) ~= "function" then
    error("callback is required for _call_openai_api_async")
  end
  if not api_key then
    callback({ success = false, error = "OpenAI API key not found. Set OPENAI_API_KEY or configure it in agents.lua" })
    return
  end

  local api_kind = (opts.api == "chat") and "chat" or "responses"
  local url = (api_kind == "responses") and "https://api.openai.com/v1/responses" or "https://api.openai.com/v1/chat/completions"

  local tools_schema = nil
  local available_tools = tools.get_tools and tools.get_tools() or nil
  if available_tools and type(available_tools) == "table" and not vim.tbl_isempty(available_tools) then
    tools_schema = tools.generate_tools_schema and tools.generate_tools_schema() or nil
  end
  local openai_tools = build_tools_for(api_kind, tools_schema)

  local payload
  if api_kind == "responses" then
    payload = {
      model = model,
      input = messages,
      tools = openai_tools,
      tool_choice = opts.tool_choice or "auto",
      max_output_tokens = opts.max_tokens,
      response_format = opts.response_format,
      instructions = opts.instructions,
    }
  else
    payload = {
      model = model,
      messages = messages,
      tools = openai_tools,
      tool_choice = opts.tool_choice,
      max_tokens = opts.max_tokens,
      response_format = opts.response_format,
    }
  end

  local timeout_ms = tonumber((opts and opts.timeout_ms) or 300000)
  if not curl or not curl.request then
    callback({ success = false, error = "HTTP client unavailable: plenary.curl not found" })
    return
  end

  curl.request({
    url = url,
    method = "post",
    headers = {
      ["Authorization"] = "Bearer " .. api_key,
      ["Content-Type"] = "application/json",
    },
    body = json(payload),
    timeout = timeout_ms,
    callback = function(res)
      vim.schedule(function()
        if not res or not res.status then
          callback({ success = false, error = "HTTP request failed or timed out" })
          return
        end
        if res.status < 200 or res.status >= 300 then
          callback({ success = false, error = ("HTTP %d: %s"):format(res.status, res.body or "") })
          return
        end
        local ok, body_tbl = pcall(decode, res.body)
        if not ok then
          callback({ success = false, error = "Failed to parse OpenAI API response" })
          return
        end
        local out = extract_content(api_kind, body_tbl)
        if out.kind == "text" then
          callback({ success = true, content = out.content, raw = body_tbl })
        elseif out.kind == "tool_call" then
          callback({ success = true, tool_call = out.content, raw = body_tbl })
        elseif out.kind == "refusal" then
          callback({ success = false, error = out.content, raw = body_tbl })
        else
          callback({ success = false, error = "no content found", raw = body_tbl })
        end
      end)
    end,
  })
end

function M._generate_ai_response(agent, user_message, chat_history)
  debug_log("=== _generate_ai_response called ===")
  debug_log("Debug mode enabled:", config.get('debug'))
  debug_log("Agent:", vim.inspect(agent))
  debug_log("User message:", user_message)

  local api_keys = vim.g.agent_finder_api_keys or vim.b.agent_finder_api_keys or {}
  local openai_key = api_keys.openai or vim.env.OPENAI_API_KEY

  if config.get('debug') then
    vim.notify('agent-finder.nvim: API keys from config: ' .. vim.fn.json_encode(api_keys), vim.log.levels.DEBUG)
    vim.notify('agent-finder.nvim: OpenAI key found: ' .. (openai_key and "yes" or "no"), vim.log.levels.DEBUG)
  end

  if not openai_key then
    return { success = false, error = "OpenAI API key not configured. Please run :AFLoad to load your agents.lua configuration, or set OPENAI_API_KEY environment variable." }
  end

  local loaded_tools = tools.get_tools()
  if not loaded_tools or type(loaded_tools) ~= "table" or vim.tbl_isempty(loaded_tools) then
    tools.load_tools()
  end

  local input_list = {}
  if chat_history then
    for _, msg in ipairs(chat_history) do
      local role = msg.role or "user"
      local content_type = (role == "assistant") and "output_text" or "input_text"
      table.insert(input_list, {
        type = "message",
        role = role,
        content = { { type = content_type, text = msg.content or "" } },
      })
    end
  end
  table.insert(input_list, {
    type = "message",
    role = "user",
    content = { { type = "input_text", text = user_message or "" } },
  })

  local instructions = agent.prompt or ""

  -- Respect agent.max_iters when iterating tools/responses (fallback to higher default)
  local max_iters = (agent and agent.max_iters) or 10
  for iter = 1, max_iters do
    debug_log("API call iteration:", iter)
    debug_log("Input list:", vim.inspect(input_list))
    local resp = M._call_openai_api(input_list, nil, openai_key, { instructions = instructions })
    debug_log("API response:", vim.inspect(resp))
    if not resp.success then
      debug_log("API call failed:", resp.error)
      if iter == 1 and string.find(resp.error, "reasoning") and string.find(resp.error, "required following item") then
        debug_log("Retrying with different model parameters to avoid reasoning error")
        local fallback_resp = M._call_openai_api(input_list, "gpt-4o-mini", openai_key, { instructions = instructions })
        if fallback_resp.success then
          debug_log("Fallback API call succeeded")
          resp = fallback_resp
        else
          debug_log("Fallback API call also failed:", fallback_resp.error)
          return resp
        end
      else
        return resp
      end
    end

    if resp.tool_call then
      debug_log("Found direct tool call:", vim.inspect(resp.tool_call))
      local tool_call = resp.tool_call
      local tool_name = nil
      local tool_args = {}
      if tool_call["function"] then
        tool_name = tool_call["function"].name
        if tool_call["function"].arguments then
          if type(tool_call["function"].arguments) == "string" then
            local success, parsed = pcall(vim.fn.json_decode, tool_call["function"].arguments)
            if success then tool_args = parsed end
          elseif type(tool_call["function"].arguments) == "table" then
            tool_args = tool_call["function"].arguments
          end
        end
      elseif tool_call.name then
        tool_name = tool_call.name
        local args_tbl = tool_call.arguments or tool_call.input or {}
        if type(args_tbl) == "string" then
          local ok, parsed = pcall(vim.fn.json_decode, args_tbl)
          tool_args = ok and parsed or {}
        else
          tool_args = args_tbl
        end
      end

      if tool_name then
        debug_log("Executing tool:", tool_name, "with args:", vim.inspect(tool_args))
        local tool_result = tools.execute_tool(tool_name, tool_args)
        debug_log("Tool result:", vim.inspect(tool_result))

        if tool_name == "Terminate" and tool_result.success then
          debug_log("Terminate tool executed, stopping processing loop")
          return { success = true, content = "Agent processing terminated. Waiting for user input." }
        end

        local tool_result_json = vim.fn.json_encode(tool_result.data or tool_result)
        table.insert(input_list, {
          type = "message",
          role = "assistant",
          content = { { type = "output_text", text = string.format("Tool '%s' result as JSON:\n%s", tool_name, tool_result_json) } },
        })
      else
        debug_log("Could not extract tool name from tool call")
        return { success = false, error = "Invalid tool call format" }
      end
    elseif resp.content and resp.content ~= "" then
      debug_log("Found text content:", resp.content)
      local tool_match = resp.content:match("```json%s*({[^`]+})%s*```")
      if tool_match then
        debug_log("Found tool match in content:", tool_match)
        local success, tool_data = pcall(vim.fn.json_decode, tool_match)
        if success and tool_data.tool_name and tool_data.parameters then
          debug_log("Executing tool from content:", tool_data.tool_name)
          local tool_result = tools.execute_tool(tool_data.tool_name, tool_data.parameters)
          debug_log("Tool result:", vim.inspect(tool_result))

          if tool_data.tool_name == "Terminate" and tool_result.success then
            debug_log("Terminate tool executed, stopping processing loop")
            return { success = true, content = "Agent processing terminated. Waiting for user input." }
          end

          local tool_result_json = vim.fn.json_encode(tool_result.data or tool_result)
          table.insert(input_list, {
            type = "message",
            role = "assistant",
            content = { { type = "output_text", text = string.format("Tool '%s' result as JSON:\n%s", tool_data.tool_name, tool_result_json) } },
          })
        else
          debug_log("Tool parsing failed, returning content as-is")
          return { success = true, content = resp.content }
        end
      else
        debug_log("No tool call found, returning content")
        return { success = true, content = resp.content }
      end
    else
      debug_log("No content or tool call found")
      return { success = false, error = "No content or tool call found in response" }
    end
  end

  debug_log("Exhausted all iterations without final response")
  return { success = false, error = "No final response after processing iterations" }
end

function M._generate_ai_response_async(agent, user_message, chat_history, callback)
  if agent and agent.adapter == 'python' then
    return M._generate_python_response_async(agent, user_message, chat_history, callback)
  end

  local api_keys = vim.g.agent_finder_api_keys or vim.b.agent_finder_api_keys or {}
  local openai_key = api_keys.openai or vim.env.OPENAI_API_KEY
  if not openai_key then
    callback({ success = false, error = "OpenAI API key not configured. Please run :AFLoad or set OPENAI_API_KEY." })
    return
  end

  local loaded_tools = tools.get_tools()
  if not loaded_tools or type(loaded_tools) ~= "table" or vim.tbl_isempty(loaded_tools) then
    tools.load_tools()
  end

  local input_list = {}
  if chat_history then
    for _, msg in ipairs(chat_history) do
      local role = msg.role or "user"
      local content_type = (role == "assistant") and "output_text" or "input_text"
      table.insert(input_list, {
        type = "message",
        role = role,
        content = { { type = content_type, text = msg.content or "" } },
      })
    end
  end
  table.insert(input_list, {
    type = "message",
    role = "user",
    content = { { type = "input_text", text = user_message or "" } },
  })

  local instructions = (agent and agent.prompt) or ""
  -- Allow override via agent.max_iters for async path as well
  local max_iters = (agent and agent.max_iters) or 10
  local iter = 1

  local function step()
    M._call_openai_api_async(input_list, nil, openai_key, { instructions = instructions }, function(resp)
      if not resp.success then
        callback(resp)
        return
      end

      if resp.tool_call then
        local tool_call = resp.tool_call
        local tool_name, tool_args = nil, {}
        if tool_call["function"] then
          tool_name = tool_call["function"].name
          local args_tbl = tool_call["function"].arguments
          if type(args_tbl) == "string" then
            local ok, parsed = pcall(vim.fn.json_decode, args_tbl)
            tool_args = ok and parsed or {}
          elseif type(args_tbl) == "table" then
            tool_args = args_tbl
          end
        elseif tool_call.name then
          tool_name = tool_call.name
          local args_tbl = tool_call.arguments or tool_call.input or {}
          if type(args_tbl) == "string" then
            local ok, parsed = pcall(vim.fn.json_decode, args_tbl)
            tool_args = ok and parsed or {}
          else
            tool_args = args_tbl
          end
        end

        if not tool_name then
          callback({ success = false, error = "Invalid tool call format" })
          return
        end

        local tool_result = tools.execute_tool(tool_name, tool_args)
        if tool_name == "Terminate" and tool_result.success then
          callback({ success = true, content = "Agent processing terminated. Waiting for user input." })
          return
        end

        local tool_result_json = vim.fn.json_encode(tool_result.data or tool_result)
        table.insert(input_list, {
          type = "message",
          role = "assistant",
          content = { { type = "output_text", text = string.format("Tool '%s' result as JSON:\n%s", tool_name, tool_result_json) } },
        })

        iter = iter + 1
        if iter <= max_iters then
          step()
        else
          callback({ success = false, error = "No final response after processing iterations" })
        end
      else
        callback({ success = true, content = resp.content, raw = resp.raw })
      end
    end)
  end

  step()
end

function M.generate_agent_prompt()
  local tools_schema = tools.generate_tools_schema()
  local tools_json = vim.fn.json_encode(tools_schema)

  local prompt = [[I'd like to simulate an AI agent that I'm designing. The agent will be built using these components:

Goals:
* Find potential code enhancements
* Ensure changes are small and self-contained
* Get user approval before making changes
* Maintain existing interfaces

Available Tools:
]] .. tools_json .. [[

At each step, your output must be an action to take using one of the available tools. 

Stop and wait and I will type in the result of the action as my next message.

Ask me for the first task to perform.]]

  return prompt
end

return M



