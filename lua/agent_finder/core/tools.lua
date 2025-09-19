local M = {}

local config = require('agent_finder.config')

-- Load tools from tools directory
function M.load_tools()
  local tools = {}

  -- Get tools directory path
  local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
  local tools_path = plugin_dir .. '/tools'

  -- Check if tools directory exists
  if vim.fn.isdirectory(tools_path) == 0 then
    vim.notify('agent-finder.nvim: Tools directory not found: ' .. tools_path, vim.log.levels.WARN)
    return tools
  end

  -- Find all .lua files in the tools directory
  local tool_files = vim.fn.globpath(tools_path, '*.lua', false, true)

  for _, file in ipairs(tool_files) do
    local success, tool_data = pcall(function()
      -- Load the tool module
      local tool_name = vim.fn.fnamemodify(file, ':t:r')
      local module_path = tool_name

      -- Add tools directory to package path temporarily
      local original_path = package.path
      package.path = tools_path .. '/?.lua;' .. package.path

      local tool_module = require(module_path)

      -- Restore original package path
      package.path = original_path

      return tool_module
    end)

    if success and tool_data then
      -- Use filename (without extension) as tool key
      local tool_name = vim.fn.fnamemodify(file, ':t:r')
      tools[tool_name] = tool_data

      if config.get('debug') then
        vim.notify(
          string.format('agent-finder.nvim: Loaded tool "%s" from %s', tool_name, file),
          vim.log.levels.DEBUG
        )
      end
    else
      vim.notify(
        string.format('agent-finder.nvim: Failed to load tool from %s: %s', file, tool_data or 'unknown error'),
        vim.log.levels.WARN
      )
    end
  end

  -- Store tools in buffer variable
  vim.b.agent_finder_tools = tools

  return tools
end

-- Execute a tool with given parameters
function M.execute_tool(tool_name, parameters)
  local tools = vim.b.agent_finder_tools

  if not tools or not tools[tool_name] then
    return { success = false, error = "Tool not found: " .. tool_name }
  end

  local tool = tools[tool_name]

  -- Validate parameters
  local validation_result = M._validate_tool_parameters(tool, parameters)
  if not validation_result.success then
    return validation_result
  end

  -- Execute tool implementation
  local success, result = pcall(function()
    -- Check if tool has execute function
    if not tool.execute or type(tool.execute) ~= "function" then
      error("Tool does not have a valid execute function")
    end

    -- Execute the tool
    return tool.execute(parameters)
  end)

  if not success then
    return { success = false, error = "Tool execution failed: " .. tostring(result) }
  end

  return result
end

-- Validate tool parameters
function M._validate_tool_parameters(tool, parameters)
  parameters = parameters or {}

  -- Check required parameters
  if tool.parameters then
    for param_name, param_def in pairs(tool.parameters) do
      if param_def.required and parameters[param_name] == nil then
        return { success = false, error = "Required parameter missing: " .. param_name }
      end

      -- Type validation
      if parameters[param_name] ~= nil then
        local param_value = parameters[param_name]
        local expected_type = param_def.type

        if expected_type == "string" and type(param_value) ~= "string" then
          return { success = false, error = "Parameter '" .. param_name .. "' must be a string" }
        elseif expected_type == "number" and type(param_value) ~= "number" then
          return { success = false, error = "Parameter '" .. param_name .. "' must be a number" }
        elseif expected_type == "boolean" and type(param_value) ~= "boolean" then
          return { success = false, error = "Parameter '" .. param_name .. "' must be a boolean" }
        end
      end
    end
  end

  return { success = true }
end

-- Get available tools
function M.get_tools()
  return vim.b.agent_finder_tools or {}
end

-- Generate JSON schema for all tools
function M.generate_tools_schema()
  local tools = M.get_tools()
  local schema = {}

  for tool_name, tool in pairs(tools) do
    if tool.parameters then
      local properties = {}
      local required = {}

      for param_name, param_def in pairs(tool.parameters) do
        local prop = {
          type = param_def.type,
          description = param_def.description or ""
        }

        -- Preserve array item schemas when provided
        if param_def.type == "array" and param_def.items ~= nil then
          prop.items = vim.deepcopy(param_def.items)
        end

        -- Preserve enums if present
        if param_def.enum ~= nil then
          prop.enum = vim.deepcopy(param_def.enum)
        end

        -- Carry default through
        if param_def.default ~= nil then
          prop.default = param_def.default
        end

        properties[param_name] = prop

        if param_def.required == true then
          table.insert(required, param_name)
        end
      end

      schema[tool_name] = {
        name = tool_name,
        description = tool.description or "",
        parameters = {
          type = "object",
          properties = properties,
          required = required
        }
      }
    else
      -- Tool with no parameters
      schema[tool_name] = {
        name = tool_name,
        description = tool.description or "",
        parameters = {
          type = "object",
          properties = {},
          required = {}
        }
      }
    end
  end

  return schema
end

return M



