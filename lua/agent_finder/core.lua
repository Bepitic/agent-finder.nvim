-- Core functionality for agent-finder.nvim

local M = {}
local config = require('agent_finder.config')

-- Load agents from YAML configuration
function M.load_agents()
  local config = require('agent_finder.config')
  local yaml = require('agent_finder.yaml')
  
  local agents_file = config.get('agents_file')
  
  if not vim.fn.filereadable(agents_file) then
    vim.notify(
      string.format('agent-finder.nvim: Agents file not found: %s', agents_file),
      vim.log.levels.ERROR
    )
    return false
  end
  
  local data, err = yaml.parse_file(agents_file)
  if not data then
    vim.notify(
      string.format('agent-finder.nvim: Failed to parse YAML: %s', err or 'unknown error'),
      vim.log.levels.ERROR
    )
    return false
  end
  
  -- Debug: Show what was parsed
  if config.get('debug') then
    vim.notify('agent-finder.nvim: Parsed YAML data: ' .. vim.fn.json_encode(data), vim.log.levels.DEBUG)
  end
  
  -- Load agents from individual files if agents_directory is specified
  local agents = {}
  if data.agents_directory then
    agents = M._load_agents_from_directory(agents_file, data.agents_directory)
  elseif data.agents then
    agents = data.agents
  else
    vim.notify('agent-finder.nvim: No agents found in configuration', vim.log.levels.ERROR)
    return false
  end
  
  -- Validate agents
  local valid, validation_err = yaml.validate_agents(agents)
  if not valid then
    vim.notify(
      string.format('agent-finder.nvim: Invalid agents structure: %s', validation_err),
      vim.log.levels.ERROR
    )
    return false
  end
  
  -- Store agents in buffer variable
  vim.b.agent_finder_agents = agents
  
  -- Store API keys if present
  if data.api_keys then
    vim.b.agent_finder_api_keys = data.api_keys
    if config.get('debug') then
      vim.notify('agent-finder.nvim: API keys loaded: ' .. vim.fn.json_encode(data.api_keys), vim.log.levels.DEBUG)
    end
  else
    if config.get('debug') then
      vim.notify('agent-finder.nvim: No API keys found in data: ' .. vim.fn.json_encode(data), vim.log.levels.DEBUG)
    end
  end
  
  local agent_count = (agents and type(agents) == "table") and vim.tbl_count(agents) or 0
  vim.notify(
    string.format('agent-finder.nvim: Loaded %d agents', agent_count),
    vim.log.levels.INFO
  )
  
  return true
end

-- Set goal for current buffer
function M.set_goal()
  -- Auto-load agents if not already loaded
  local agents = vim.b.agent_finder_agents
  if not agents or type(agents) ~= "table" or vim.tbl_isempty(agents) then
    vim.notify('agent-finder.nvim: Loading agents automatically...', vim.log.levels.INFO)
    local load_success = M.load_agents()
    if not load_success then
      vim.notify('agent-finder.nvim: Failed to load agents automatically.', vim.log.levels.ERROR)
      return false
    end
  end
  
  local goal = vim.fn.input('Enter AI agent goal: ')
  
  if goal == '' then
    vim.notify('agent-finder.nvim: No goal entered', vim.log.levels.WARN)
    return false
  end
  
  -- Store goal in buffer variable
  vim.b.agent_finder_goal = goal
  
  vim.notify(
    string.format('agent-finder.nvim: Goal set: %s', goal),
    vim.log.levels.INFO
  )
  
  return true
end

-- Apply goal to current buffer
function M.apply_goal()
  local goal = vim.b.agent_finder_goal
  
  if not goal then
    vim.notify('agent-finder.nvim: No goal set. Use :AFGoal first.', vim.log.levels.WARN)
    return false
  end
  
  local agents = vim.b.agent_finder_agents
  if not agents then
    vim.notify('agent-finder.nvim: No agents loaded. Use :AFLoad first.', vim.log.levels.WARN)
    return false
  end
  
  -- For now, just append a comment with the goal
  -- This can be replaced with actual API calls later
  M._apply_goal_to_buffer(goal)
  
  vim.notify('agent-finder.nvim: Goal applied to buffer', vim.log.levels.INFO)
  
  return true
end

-- Export API keys to vim.env
function M.export_env()
  local api_keys = vim.b.agent_finder_api_keys
  local config = require('agent_finder.config')
  
  -- Use buffer API keys if available, otherwise use config
  local keys_to_export = api_keys or config.get('api_keys')
  
  local exported_count = 0
  
  for service, key in pairs(keys_to_export) do
    if key and key ~= '' then
      local env_var = string.upper('AGENT_FINDER_' .. service .. '_API_KEY')
      vim.env[env_var] = key
      exported_count = exported_count + 1
      
      if config.get('debug') then
        vim.notify(
          string.format('agent-finder.nvim: Exported %s', env_var),
          vim.log.levels.DEBUG
        )
      end
    end
  end
  
  if exported_count > 0 then
    vim.notify(
      string.format('agent-finder.nvim: Exported %d API keys to environment', exported_count),
      vim.log.levels.INFO
    )
  else
    vim.notify('agent-finder.nvim: No API keys to export', vim.log.levels.WARN)
  end
  
  return exported_count > 0
end

-- Internal function to apply goal to buffer
-- This is where you would integrate with actual AI APIs
function M._apply_goal_to_buffer(goal)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  
  -- Determine comment style based on file type
  local comment_prefix = M._get_comment_prefix()
  
  -- Append goal comment
  local goal_comment = string.format('%s AgentGoal: %s', comment_prefix, goal)
  table.insert(lines, goal_comment)
  
  -- Write back to buffer
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { goal_comment })
end

-- Get comment prefix based on file type
function M._get_comment_prefix()
  local filetype = vim.bo.filetype
  
  local comment_map = {
    lua = '--',
    vim = '"',
    python = '#',
    javascript = '//',
    typescript = '//',
    go = '//',
    rust = '//',
    c = '//',
    cpp = '//',
    java = '//',
    html = '<!--',
    css = '/*',
    sql = '--',
    yaml = '#',
    json = '//',
    markdown = '<!--',
    sh = '#',
    bash = '#',
    zsh = '#',
  }
  
  return comment_map[filetype] or '//'
end

-- Get current agents
function M.get_agents()
  return vim.b.agent_finder_agents or {}
end

-- Get current goal
function M.get_goal()
  return vim.b.agent_finder_goal
end

-- Load agents from individual files in a directory
function M._load_agents_from_directory(main_config_file, agents_dir)
  local yaml = require('agent_finder.yaml')
  local config = require('agent_finder.config')
  local agents = {}
  
  -- Clean up the agents_dir path (remove quotes if present)
  agents_dir = string.gsub(agents_dir, '"', '')
  agents_dir = string.gsub(agents_dir, "'", '')
  agents_dir = vim.trim(agents_dir)
  
  -- Get the directory of the main config file
  local config_dir = vim.fn.fnamemodify(main_config_file, ':h')
  local agents_path = config_dir .. '/' .. agents_dir
  
  -- Debug output
  if config.get('debug') then
    vim.notify(
      string.format('agent-finder.nvim: Looking for agents in: %s', agents_path),
      vim.log.levels.DEBUG
    )
  end
  
  -- Check if agents directory exists
  if vim.fn.isdirectory(agents_path) == 0 then
    -- Try alternative path: relative to plugin directory
    local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
    local alt_agents_path = plugin_dir .. '/' .. agents_dir
    
    if vim.fn.isdirectory(alt_agents_path) == 1 then
      agents_path = alt_agents_path
      if config.get('debug') then
        vim.notify(
          string.format('agent-finder.nvim: Using plugin agents directory: %s', agents_path),
          vim.log.levels.DEBUG
        )
      end
    else
      vim.notify(
        string.format('agent-finder.nvim: Agents directory not found in config (%s) or plugin (%s)', 
          config_dir .. '/' .. agents_dir, alt_agents_path),
        vim.log.levels.ERROR
      )
      return agents
    end
  end
  
  -- Find all .yaml files in the agents directory
  local agent_files = vim.fn.globpath(agents_path, '*.yaml', false, true)
  
  for _, file in ipairs(agent_files) do
    local agent_data, err = yaml.parse_file(file)
    if agent_data then
      -- Use filename (without extension) as agent key
      local agent_name = vim.fn.fnamemodify(file, ':t:r')
      agents[agent_name] = agent_data
      
      if config.get('debug') then
        vim.notify(
          string.format('agent-finder.nvim: Loaded agent "%s" from %s', agent_name, file),
          vim.log.levels.DEBUG
        )
      end
    else
      vim.notify(
        string.format('agent-finder.nvim: Failed to load agent from %s: %s', file, err or 'unknown error'),
        vim.log.levels.WARN
      )
    end
  end
  
  return agents
end

-- List available agents
function M.list_agents()
  local agents = vim.b.agent_finder_agents
  
  -- Auto-load agents if not already loaded
  if not agents or type(agents) ~= "table" or vim.tbl_isempty(agents) then
    vim.notify('agent-finder.nvim: No agents loaded. Loading agents automatically...', vim.log.levels.INFO)
    local load_success = M.load_agents()
    if not load_success then
      vim.notify('agent-finder.nvim: Failed to load agents automatically.', vim.log.levels.ERROR)
      return false
    end
    agents = vim.b.agent_finder_agents
  end
  
  -- Check if telescope is available
  local telescope_ok, telescope = pcall(require, 'telescope')
  if not telescope_ok then
    -- Fallback: print agents to command line
    M._print_agents_list(agents)
    return true
  end
  
  -- Use telescope to show agents
  M._show_agents_telescope(agents)
  return true
end

-- Select an agent using telescope
function M.select_agent()
  local agents = vim.b.agent_finder_agents
  
  -- Auto-load agents if not already loaded
  if not agents or type(agents) ~= "table" or vim.tbl_isempty(agents) then
    vim.notify('agent-finder.nvim: No agents loaded. Loading agents automatically...', vim.log.levels.INFO)
    local load_success = M.load_agents()
    if not load_success then
      vim.notify('agent-finder.nvim: Failed to load agents automatically.', vim.log.levels.ERROR)
      return false
    end
    agents = vim.b.agent_finder_agents
  end
  
  -- Check if telescope is available
  local telescope_ok, telescope = pcall(require, 'telescope')
  if not telescope_ok then
    vim.notify('agent-finder.nvim: Telescope not available. Please install telescope.nvim', vim.log.levels.ERROR)
    return false
  end
  
  -- Use telescope to select agent
  M._select_agent_telescope(agents)
  return true
end

-- Print agents list to command line (fallback)
function M._print_agents_list(agents)
  print("Available AI Agents:")
  print("===================")
  
  for name, agent in pairs(agents) do
    print(string.format("• %s (%s)", agent.name or name, agent.description or "No description"))
  end
  
  print("\nUse :AFSelect to choose an agent, or :AFGoal to set a goal.")
end

-- Show agents in telescope
function M._show_agents_telescope(agents)
  local telescope = require('telescope')
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  
  -- Convert agents to telescope entries
  local entries = {}
  for name, agent in pairs(agents) do
    table.insert(entries, {
      name = name,
      display_name = agent.name or name,
      description = agent.description or "No description",
      prompt = agent.prompt or "",
    })
  end
  
  -- Sort entries by name
  table.sort(entries, function(a, b)
    return a.display_name < b.display_name
  end)
  
  local picker = pickers.new({}, {
    prompt_title = "AI Agents",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format("%s - %s", entry.display_name, entry.description),
          ordinal = entry.display_name,
          name = entry.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          vim.b.agent_finder_selected_agent = selection.value
          vim.notify(
            string.format('agent-finder.nvim: Selected agent "%s"', selection.value.display_name),
            vim.log.levels.INFO
          )
        end
      end)
      
      -- Add preview action
      map('i', '<C-p>', function()
        local selection = action_state.get_selected_entry()
        if selection then
          M._preview_agent(selection.value)
        end
      end)
      
      return true
    end,
  })
  
  picker:find()
end

-- Select agent in telescope
function M._select_agent_telescope(agents)
  local telescope = require('telescope')
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  
  -- Convert agents to telescope entries
  local entries = {}
  for name, agent in pairs(agents) do
    table.insert(entries, {
      name = name,
      display_name = agent.name or name,
      description = agent.description or "No description",
      prompt = agent.prompt or "",
    })
  end
  
  -- Sort entries by name
  table.sort(entries, function(a, b)
    return a.display_name < b.display_name
  end)
  
  local picker = pickers.new({}, {
    prompt_title = "Select AI Agent",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format("%s - %s", entry.display_name, entry.description),
          ordinal = entry.display_name,
          name = entry.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          vim.b.agent_finder_selected_agent = selection.value
          vim.notify(
            string.format('agent-finder.nvim: Selected agent "%s". Now use :AFGoal to set a goal.', selection.value.display_name),
            vim.log.levels.INFO
          )
        end
      end)
      
      -- Add preview action
      map('i', '<C-p>', function()
        local selection = action_state.get_selected_entry()
        if selection then
          M._preview_agent(selection.value)
        end
      end)
      
      return true
    end,
  })
  
  picker:find()
end

-- Preview agent details
function M._preview_agent(agent)
  local lines = {
    string.format("Agent: %s", agent.display_name),
    string.format("Description: %s", agent.description),
    "",
    "Prompt:",
    string.rep("-", 50),
  }
  
  -- Split prompt into lines and add them
  for line in string.gmatch(agent.prompt, "[^\r\n]+") do
    table.insert(lines, line)
  end
  
  -- Create a temporary buffer to show the preview
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
  
  -- Create a floating window
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(20, vim.o.lines - 4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  local win_id = vim.api.nvim_open_win(bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    border = 'rounded',
    title = 'Agent Preview',
    title_pos = 'center',
  })
  
  -- Close window on any key press
  vim.api.nvim_buf_set_keymap(bufnr, 'n', '<Esc>', ':close<CR>', { silent = true })
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'q', ':close<CR>', { silent = true })
  vim.api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', ':close<CR>', { silent = true })
end

-- Get selected agent
function M.get_selected_agent()
  return vim.b.agent_finder_selected_agent
end

-- Start chat with an agent
function M.start_chat()
  local agents = vim.b.agent_finder_agents
  
  -- Auto-load agents if not already loaded
  if not agents or type(agents) ~= "table" or vim.tbl_isempty(agents) then
    vim.notify('agent-finder.nvim: Loading agents automatically...', vim.log.levels.INFO)
    local load_success = M.load_agents()
    if not load_success then
      vim.notify('agent-finder.nvim: Failed to load agents automatically.', vim.log.levels.ERROR)
      return false
    end
    agents = vim.b.agent_finder_agents
  end
  
  -- Check if telescope is available
  local telescope_ok, telescope = pcall(require, 'telescope')
  if not telescope_ok then
    vim.notify('agent-finder.nvim: Telescope not available. Please install telescope.nvim', vim.log.levels.ERROR)
    return false
  end
  
  -- Check if API keys are loaded
  local api_keys = vim.b.agent_finder_api_keys or {}
  if not api_keys.openai and not vim.env.OPENAI_API_KEY then
    vim.notify('agent-finder.nvim: OpenAI API key not found. Please ensure your agents.yaml contains the openai key or set OPENAI_API_KEY environment variable.', vim.log.levels.WARN)
    return false
  end
  
  -- Use telescope to select agent for chat
  M._select_agent_for_chat(agents)
  return true
end

-- Select agent for chat in telescope
function M._select_agent_for_chat(agents)
  local telescope = require('telescope')
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  
  -- Convert agents to telescope entries
  local entries = {}
  for name, agent in pairs(agents) do
    table.insert(entries, {
      name = name,
      display_name = agent.name or name,
      description = agent.description or "No description",
      prompt = agent.prompt or "",
    })
  end
  
  -- Sort entries by name
  table.sort(entries, function(a, b)
    return a.display_name < b.display_name
  end)
  
  local picker = pickers.new({}, {
    prompt_title = "Select Agent for Chat",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format("%s - %s", entry.display_name, entry.description),
          ordinal = entry.display_name,
          name = entry.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          M._open_chat_window(selection.value)
        end
      end)
      
      return true
    end,
  })
  
  picker:find()
end

-- Open chat window with selected agent
function M._open_chat_window(agent)
  -- Create a new buffer for the chat
  local chat_bufnr = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(chat_bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(chat_bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(chat_bufnr, 'swapfile', false)
  vim.api.nvim_buf_set_option(chat_bufnr, 'filetype', 'markdown')
  
  -- Create split window
  vim.cmd('vsplit')
  vim.api.nvim_win_set_buf(0, chat_bufnr)
  
  -- Set window options
  vim.api.nvim_win_set_option(0, 'number', true)
  vim.api.nvim_win_set_option(0, 'relativenumber', false)
  vim.api.nvim_win_set_option(0, 'wrap', true)
  
  -- Initialize chat content
  local chat_content = {
    string.format("# Chat with %s", agent.display_name),
    "",
    string.format("**Agent:** %s", agent.display_name),
    string.format("**Description:** %s", agent.description),
    "",
    "---",
    "",
    "## Conversation",
    "",
    string.format("**%s:** Hello! I'm %s. How can I help you today?", agent.display_name, agent.display_name),
    "",
    "---",
    "",
    "## Instructions",
    "",
    "- Type your message below and press `<Enter>` to send",
    "- Press `<Esc>` to exit chat",
    "- Press `<C-s>` to save conversation",
    "",
  }
  
  vim.api.nvim_buf_set_lines(chat_bufnr, 0, -1, false, chat_content)
  
  -- Store chat state
  vim.b.agent_finder_chat_bufnr = chat_bufnr
  vim.b.agent_finder_chat_agent = agent
  vim.b.agent_finder_chat_messages = {
    { role = "system", content = agent.prompt },
    { role = "assistant", content = string.format("Hello! I'm %s. How can I help you today?", agent.display_name) }
  }
  
  -- Set up chat keymaps
  M._setup_chat_keymaps(chat_bufnr)
  
  -- Move cursor to the end
  vim.api.nvim_win_set_cursor(0, { #chat_content, 0 })
  
  vim.notify(
    string.format('agent-finder.nvim: Started chat with %s. Type your message and press Enter.', agent.display_name),
    vim.log.levels.INFO
  )
end

-- Set up keymaps for chat buffer
function M._setup_chat_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true, noremap = true }
  
  -- Enter to send message
  vim.keymap.set('n', '<CR>', function()
    M._send_chat_message()
  end, opts)
  
  -- Escape to exit chat
  vim.keymap.set('n', '<Esc>', function()
    M._close_chat()
  end, opts)
  
  -- Ctrl+S to save conversation
  vim.keymap.set('n', '<C-s>', function()
    M._save_chat_conversation()
  end, opts)
  
  -- Insert mode mappings
  vim.keymap.set('i', '<CR>', function()
    M._send_chat_message()
  end, opts)
  
  vim.keymap.set('i', '<Esc>', function()
    M._close_chat()
  end, opts)
end

-- Send chat message
function M._send_chat_message()
  local chat_bufnr = vim.b.agent_finder_chat_bufnr
  local agent = vim.b.agent_finder_chat_agent
  
  if not chat_bufnr or not agent then
    vim.notify('agent-finder.nvim: No active chat session', vim.log.levels.ERROR)
    return
  end
  
  -- Get current line content
  local current_line = vim.api.nvim_get_current_line()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor_pos[1]
  
  -- Check if we're in a message area (after the last "---")
  local lines = vim.api.nvim_buf_get_lines(chat_bufnr, 0, -1, false)
  local last_separator = 0
  for i, line in ipairs(lines) do
    if line:match("^---$") then
      last_separator = i
    end
  end
  
  if line_num <= last_separator then
    vim.notify('agent-finder.nvim: Please type your message after the last separator line', vim.log.levels.WARN)
    return
  end
  
  -- Get user message (everything after the last separator)
  local user_message = ""
  for i = last_separator + 1, #lines do
    if lines[i] ~= "" and not lines[i]:match("^**%w+:**") then
      user_message = user_message .. lines[i] .. "\n"
    end
  end
  
  user_message = vim.trim(user_message)
  
  if user_message == "" then
    vim.notify('agent-finder.nvim: Please enter a message', vim.log.levels.WARN)
    return
  end
  
  -- Add user message to chat (split into lines for proper formatting)
  local user_lines = {}
  table.insert(user_lines, "**You:**")
  for line in string.gmatch(user_message, "[^\r\n]+") do
    table.insert(user_lines, line)
  end
  table.insert(user_lines, "") -- Add empty line after user message
  
  vim.api.nvim_buf_set_lines(chat_bufnr, -1, -1, false, user_lines)
  
  -- Add to messages history
  table.insert(vim.b.agent_finder_chat_messages, { role = "user", content = user_message })
  
  -- Show "Thinking..." message
  local thinking_line = string.format("**%s:** 🤔 Thinking...", agent.display_name)
  vim.api.nvim_buf_set_lines(chat_bufnr, -1, -1, false, { thinking_line, "" })
  
  -- Move cursor to end
  local new_lines = vim.api.nvim_buf_get_lines(chat_bufnr, 0, -1, false)
  vim.api.nvim_win_set_cursor(0, { #new_lines, 0 })
  
  -- Generate agent response using OpenAI API with tools
  local response = M._generate_ai_response(agent, user_message, vim.b.agent_finder_chat_messages)
  
  if response.success then
    -- Remove "Thinking..." message
    local line_count = vim.api.nvim_buf_line_count(chat_bufnr)
    vim.api.nvim_buf_set_lines(chat_bufnr, line_count - 2, line_count, false, {})
    
    -- Check if response contains tool usage
    local tool_used = false
    local tool_result = nil
    
    -- Try to parse JSON tool usage from response
    local tool_match = response.content:match("```json%s*({[^}]+})%s*```")
    if tool_match then
      local success, tool_data = pcall(vim.fn.json_decode, tool_match)
      if success and tool_data.tool_name and tool_data.parameters then
        -- Execute the tool
        tool_result = M.execute_tool(tool_data.tool_name, tool_data.parameters)
        tool_used = true
      end
    end
    
    -- Format the response
    local response_lines = {}
    table.insert(response_lines, string.format("**%s:**", agent.display_name))
    
    -- Split AI response into lines
    for line in string.gmatch(response.content, "[^\r\n]+") do
      table.insert(response_lines, line)
    end
    
    if tool_used and tool_result then
      table.insert(response_lines, "") -- Add empty line before tool result
      if tool_result.success then
        table.insert(response_lines, "🔧 **Tool Result:**")
        local tool_result_json = vim.fn.json_encode(tool_result.data or tool_result)
        for tool_line in string.gmatch(tool_result_json, "[^\r\n]+") do
          table.insert(response_lines, tool_line)
        end
      else
        table.insert(response_lines, "❌ **Tool Error:** " .. tool_result.error)
      end
    end
    
    table.insert(response_lines, "") -- Add empty line after response
    
    vim.api.nvim_buf_set_lines(chat_bufnr, -1, -1, false, response_lines)
    
    -- Add to messages history
    table.insert(vim.b.agent_finder_chat_messages, { role = "assistant", content = response.content })
  else
    -- Remove "Thinking..." message
    local line_count = vim.api.nvim_buf_line_count(chat_bufnr)
    vim.api.nvim_buf_set_lines(chat_bufnr, line_count - 2, line_count, false, {})
    
    -- Show error message
    local error_lines = {}
    table.insert(error_lines, string.format("**%s:**", agent.display_name))
    table.insert(error_lines, "❌ Error: " .. response.error)
    table.insert(error_lines, "")
    
    vim.api.nvim_buf_set_lines(chat_bufnr, -1, -1, false, error_lines)
    
    vim.notify('agent-finder.nvim: ' .. response.error, vim.log.levels.ERROR)
  end
  
  -- Move cursor to end
  local new_lines = vim.api.nvim_buf_get_lines(chat_bufnr, 0, -1, false)
  vim.api.nvim_win_set_cursor(0, { #new_lines, 0 })
end

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
      local module_path = 'tools.' .. tool_name
      
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
        properties[param_name] = {
          type = param_def.type,
          description = param_def.description or ""
        }
        
        if param_def.default then
          properties[param_name].default = param_def.default
        end
        
        if param_def.required then
          table.insert(required, param_name)
        end
      end
      
      schema[tool_name] = {
        tool_name = tool_name,
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
        tool_name = tool_name,
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

-- Generate AI agent prompt with tool schemas
function M.generate_agent_prompt()
  local tools_schema = M.generate_tools_schema()
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

-- OpenAI API integration
function M._call_openai_api(messages, model, api_key)
  model = model or "gpt-3.5-turbo"
  api_key = api_key or vim.env.OPENAI_API_KEY
  
  if not api_key then
    return { success = false, error = "OpenAI API key not found. Set OPENAI_API_KEY environment variable or configure it in agents.yaml" }
  end
  
  local request_body = {
    model = model,
    messages = messages,
    temperature = 0.7,
    max_tokens = 1000
  }
  
  local json_body = vim.fn.json_encode(request_body)
  
  -- Make HTTP request to OpenAI API
  local response = vim.fn.system({
    'curl',
    '-s',
    '-X', 'POST',
    'https://api.openai.com/v1/chat/completions',
    '-H', 'Content-Type: application/json',
    '-H', 'Authorization: Bearer ' .. api_key,
    '-d', json_body
  })
  
  if vim.v.shell_error ~= 0 then
    return { success = false, error = "Failed to make API request to OpenAI" }
  end
  
  local success, result = pcall(vim.fn.json_decode, response)
  if not success then
    return { success = false, error = "Failed to parse OpenAI API response" }
  end
  
  if result.error then
    return { success = false, error = "OpenAI API error: " .. (result.error.message or "Unknown error") }
  end
  
  if not result.choices or #result.choices == 0 then
    return { success = false, error = "No response from OpenAI API" }
  end
  
  local content = result.choices[1].message.content
  if not content then
    return { success = false, error = "Empty response from OpenAI API" }
  end
  
  return { success = true, content = content }
end

-- Generate AI response using OpenAI with tools integration
function M._generate_ai_response(agent, user_message, chat_history)
  local api_keys = vim.b.agent_finder_api_keys or {}
  local openai_key = api_keys.openai or vim.env.OPENAI_API_KEY
  
  -- Debug information
  if config.get('debug') then
    vim.notify('agent-finder.nvim: API keys from config: ' .. vim.fn.json_encode(api_keys), vim.log.levels.DEBUG)
    vim.notify('agent-finder.nvim: OpenAI key found: ' .. (openai_key and "yes" or "no"), vim.log.levels.DEBUG)
  end
  
  if not openai_key then
    return { success = false, error = "OpenAI API key not configured. Please run :AFLoad to load your agents.yaml configuration, or set OPENAI_API_KEY environment variable." }
  end
  
  -- Load tools if not already loaded
  local tools = M.get_tools()
  if not tools or type(tools) ~= "table" or vim.tbl_isempty(tools) then
    M.load_tools()
    tools = M.get_tools()
  end
  
  -- Build messages array
  local messages = {}
  
  -- System message with agent prompt and tools
  local system_message = agent.prompt
  
  if tools and type(tools) == "table" and not vim.tbl_isempty(tools) then
    local tools_schema = M.generate_tools_schema()
    local tools_json = vim.fn.json_encode(tools_schema)
    system_message = system_message .. "\n\nYou have access to the following tools:\n" .. tools_json .. "\n\nYou can use these tools to help answer questions and perform tasks. When you want to use a tool, respond with a JSON object containing the tool name and parameters."
  end
  
  table.insert(messages, {
    role = "system",
    content = system_message
  })
  
  -- Add chat history
  if chat_history then
    for _, msg in ipairs(chat_history) do
      table.insert(messages, {
        role = msg.role,
        content = msg.content
      })
    end
  end
  
  -- Add current user message
  table.insert(messages, {
    role = "user",
    content = user_message
  })
  
  -- Call OpenAI API
  return M._call_openai_api(messages, "gpt-3.5-turbo", openai_key)
end

-- Close chat
function M._close_chat()
  local chat_bufnr = vim.b.agent_finder_chat_bufnr
  if chat_bufnr and vim.api.nvim_buf_is_valid(chat_bufnr) then
    vim.api.nvim_buf_delete(chat_bufnr, { force = true })
  end
  
  vim.b.agent_finder_chat_bufnr = nil
  vim.b.agent_finder_chat_agent = nil
  vim.b.agent_finder_chat_messages = nil
  
  vim.notify('agent-finder.nvim: Chat closed', vim.log.levels.INFO)
end

-- Save chat conversation
function M._save_chat_conversation()
  local chat_bufnr = vim.b.agent_finder_chat_bufnr
  local agent = vim.b.agent_finder_chat_agent
  
  if not chat_bufnr or not agent then
    vim.notify('agent-finder.nvim: No active chat session to save', vim.log.levels.ERROR)
    return
  end
  
  local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
  local filename = string.format("chat_%s_%s.md", agent.name, timestamp)
  local filepath = vim.fn.expand("~/") .. filename
  
  -- Get chat content
  local lines = vim.api.nvim_buf_get_lines(chat_bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")
  
  -- Write to file
  local file = io.open(filepath, "w")
  if file then
    file:write(content)
    file:close()
    vim.notify(string.format('agent-finder.nvim: Chat saved to %s', filepath), vim.log.levels.INFO)
  else
    vim.notify('agent-finder.nvim: Failed to save chat', vim.log.levels.ERROR)
  end
end

-- Clear buffer state
function M.clear_state()
  vim.b.agent_finder_agents = nil
  vim.b.agent_finder_goal = nil
  vim.b.agent_finder_api_keys = nil
  vim.b.agent_finder_selected_agent = nil
  vim.b.agent_finder_chat_bufnr = nil
  vim.b.agent_finder_chat_agent = nil
  vim.b.agent_finder_chat_messages = nil
  vim.b.agent_finder_tools = nil
  
  vim.notify('agent-finder.nvim: Buffer state cleared', vim.log.levels.INFO)
end

return M
