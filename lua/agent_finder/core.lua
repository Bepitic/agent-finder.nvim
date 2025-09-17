-- Core functionality for agent-finder.nvim

local M = {}
local config = require('agent_finder.config')

-- Debug logging function
local function debug_log(message, ...)
  if config.get('debug') then
    if ... then
      print("DEBUG:", message, ...)
    else
      print("DEBUG:", message)
    end
  end
end

-- Load agents from Lua configuration
function M.load_agents()
  local config = require('agent_finder.config')
  
  local agents_file = config.get('agents_file')
  
  if not vim.fn.filereadable(agents_file) then
    vim.notify(
      string.format('agent-finder.nvim: Agents file not found: %s', agents_file),
      vim.log.levels.ERROR
    )
    return false
  end
  
  -- Load Lua configuration file
  local success, data = pcall(function()
    -- Temporarily add the directory to package.path
    local dir = vim.fn.fnamemodify(agents_file, ':h')
    local original_path = package.path
    package.path = dir .. '/?.lua;' .. package.path
    
    -- Load the configuration
    local config_module = dofile(agents_file)
    
    -- Restore original package.path
    package.path = original_path
    
    return config_module
  end)
  
  if not success then
    vim.notify(
      string.format('agent-finder.nvim: Failed to load Lua config: %s', data or 'unknown error'),
      vim.log.levels.ERROR
    )
    return false
  end
  
  -- Update config with values from Lua file
  if data.debug ~= nil then
    config.set('debug', data.debug)
  end
  
  -- Debug: Show what was loaded
  if config.get('debug') then
    vim.notify('agent-finder.nvim: Loaded Lua config: ' .. vim.fn.json_encode(data), vim.log.levels.DEBUG)
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
  local valid, validation_err = M._validate_agents(agents)
  if not valid then
    vim.notify(
      string.format('agent-finder.nvim: Invalid agents structure: %s', validation_err),
      vim.log.levels.ERROR
    )
    return false
  end
  
  -- Store agents in buffer variable
  vim.b.agent_finder_agents = agents
  
  -- Store API keys globally so they're available across all buffers
  if data.api_keys then
    vim.g.agent_finder_api_keys = data.api_keys
    vim.b.agent_finder_api_keys = data.api_keys  -- Also store in buffer for backward compatibility
    if config.get('debug') then
      vim.notify('agent-finder.nvim: API keys loaded: ' .. vim.fn.json_encode(data.api_keys), vim.log.levels.DEBUG)
    end
    -- Check if OpenAI key is properly configured
    if data.api_keys.openai and data.api_keys.openai ~= "your-openai-api-key-here" then
      vim.notify('agent-finder.nvim: OpenAI API key configured successfully', vim.log.levels.INFO)
    else
      vim.notify('agent-finder.nvim: Warning: OpenAI API key not properly configured in agents.lua', vim.log.levels.WARN)
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
  local api_keys = vim.g.agent_finder_api_keys or vim.b.agent_finder_api_keys
  local config = require('agent_finder.config')
  
  -- Use global/buffer API keys if available, otherwise use config
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

-- Validate agents structure
function M._validate_agents(agents)
  if type(agents) ~= 'table' then
    return false, 'Agents must be a table'
  end
  
  -- Validate each agent
  for name, agent in pairs(agents) do
    if type(agent) ~= 'table' then
      return false, string.format('Agent "%s" must be a table', name)
    end
    
    if not agent.name then
      return false, string.format('Agent "%s" missing required "name" field', name)
    end
    
    if not agent.prompt then
      return false, string.format('Agent "%s" missing required "prompt" field', name)
    end
    
    -- Validate prompt is a string (not a table)
    if type(agent.prompt) ~= 'string' then
      return false, string.format('Agent "%s" prompt must be a string, got %s', name, type(agent.prompt))
    end
  end
  
  return true, nil
end

-- Load agents from individual files in a directory
function M._load_agents_from_directory(main_config_file, agents_dir)
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
  
  -- Find all .lua files in the agents directory
  local agent_files = vim.fn.globpath(agents_path, '*.lua', false, true)
  
  for _, file in ipairs(agent_files) do
    local success, agent_data = pcall(function()
      -- Load the agent module
      local agent_name = vim.fn.fnamemodify(file, ':t:r')
      local module_path = agent_name
      
      -- Add agents directory to package path temporarily
      local original_path = package.path
      package.path = agents_path .. '/?.lua;' .. package.path
      
      local agent_module = dofile(file)
      
      -- Restore original package path
      package.path = original_path
      
      return agent_module
    end)
    
    if success and agent_data then
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
        string.format('agent-finder.nvim: Failed to load agent from %s: %s', file, agent_data or 'unknown error'),
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
  local api_keys = vim.g.agent_finder_api_keys or vim.b.agent_finder_api_keys or {}
  if not api_keys.openai and not vim.env.OPENAI_API_KEY then
    vim.notify('agent-finder.nvim: OpenAI API key not found. Please ensure your agents.lua contains the openai key or set OPENAI_API_KEY environment variable.', vim.log.levels.WARN)
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
  vim.api.nvim_win_set_option(0, 'number', false)
  vim.api.nvim_win_set_option(0, 'relativenumber', false)
  vim.api.nvim_win_set_option(0, 'wrap', true)
  
  -- Initialize chat content
  local chat_content = {
    string.format("# Chat with %s", agent.display_name),
    "",
    string.format("**Agent:** %s", agent.display_name),
    string.format("**Description:** %s", agent.description),
    "",
    "## Instructions",
    "",
    "- Type your message below and press `<Enter>` to send",
    "- Press `<Esc>` to exit chat",
    "- Press `<C-s>` to save conversation",
    "",
    "---",
    "",
    "## Conversation",
    "",
    string.format("@> Hello! I'm %s. How can I help you today?", agent.display_name),
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
  
  -- Auto-load agents and API keys in the chat buffer context
  vim.notify('agent-finder.nvim: Loading agents and API keys for chat...', vim.log.levels.INFO)
  local load_success = M.load_agents()
  if load_success then
    vim.notify('agent-finder.nvim: Agents and API keys loaded successfully for chat', vim.log.levels.INFO)
  else
    vim.notify('agent-finder.nvim: Warning: Failed to load agents/API keys for chat', vim.log.levels.WARN)
  end
  
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

-- Start/stop "thinking" animation in chat buffer
function M._start_thinking_animation()
  local bufnr = vim.b.agent_finder_chat_bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

  -- The thinking line is the second-to-last line (followed by an empty line)
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local start0 = math.max(0, total_lines - 2)
  vim.b.agent_finder_thinking_line0 = start0

  local frames = { ".", "o", "O", "@" }
  local frame_idx = 1

  local timer = vim.loop.new_timer()
  vim.b.agent_finder_thinking_timer = timer
  timer:start(0, 200, function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      timer:stop(); timer:close()
      vim.b.agent_finder_thinking_timer = nil
      return
    end
    local idx0 = vim.b.agent_finder_thinking_line0
    if type(idx0) ~= 'number' then return end
    local symbol = frames[frame_idx]
    frame_idx = frame_idx + 1
    if frame_idx > #frames then frame_idx = 1 end
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        local new_line = symbol .. "> thinking"
        vim.api.nvim_buf_set_lines(bufnr, idx0, idx0 + 1, false, { new_line })
      end
    end)
  end)
end

function M._stop_thinking_animation()
  local timer = vim.b.agent_finder_thinking_timer
  if timer then
    pcall(function() timer:stop(); timer:close() end)
  end
  vim.b.agent_finder_thinking_timer = nil
  vim.b.agent_finder_thinking_line0 = nil
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
  
  -- Get user message (everything after the last separator), skipping headers/instructions or lines with agent/user prefixes
  local user_message = ""
  for i = last_separator + 1, #lines do
    local l = lines[i]
    if l ~= ""
      and not l:match("^##%s")
      and not l:match("^-%s")
      and not l:match("^@> ")
      and not l:match("^%(%w+%)>%s")
    then
      user_message = user_message .. l .. "\n"
    end
  end
  
  user_message = vim.trim(user_message)
  
  if user_message == "" then
    vim.notify('agent-finder.nvim: Please enter a message', vim.log.levels.WARN)
    return
  end
  
  -- Remove the raw typed lines from the buffer to avoid duplication
  for i = #lines, last_separator + 1, -1 do
    local l = lines[i]
    if l ~= ""
      and not l:match("^##%s")
      and not l:match("^-%s")
      and not l:match("^@> ")
      and not l:match("^%(%w+%)>%s")
    then
      vim.api.nvim_buf_set_lines(chat_bufnr, i - 1, i, false, {})
    end
  end

  -- Add user message to chat (split into lines for proper formatting)
  local user_lines = {}
  local first_user = true
  for line in string.gmatch(user_message, "[^\r\n]+") do
    if first_user then
      table.insert(user_lines, "(You)> " .. line)
      first_user = false
    else
      table.insert(user_lines, line)
    end
  end
  table.insert(user_lines, "") -- Add empty line after user message

  vim.api.nvim_buf_set_lines(chat_bufnr, -1, -1, false, user_lines)
  
  -- Add to messages history
  table.insert(vim.b.agent_finder_chat_messages, { role = "user", content = user_message })
  
  -- Show thinking message and start animation
  local thinking_line = "@> thinking"
  vim.api.nvim_buf_set_lines(chat_bufnr, -1, -1, false, { thinking_line, "" })
  M._start_thinking_animation()
  
  -- Move cursor to end
  local new_lines = vim.api.nvim_buf_get_lines(chat_bufnr, 0, -1, false)
  vim.api.nvim_win_set_cursor(0, { #new_lines, 0 })
  
  -- Generate agent response using OpenAI API with tools
  local response = M._generate_ai_response(agent, user_message, vim.b.agent_finder_chat_messages)
  
  if response.success then
    -- Remove "Thinking..." message
    M._stop_thinking_animation()
    local line_count = vim.api.nvim_buf_line_count(chat_bufnr)
    vim.api.nvim_buf_set_lines(chat_bufnr, line_count - 2, line_count, false, {})
    
    -- Check if response contains tool usage
    local tool_used = false
    local tool_result = nil
    local parsed_tool_name = nil
    
    -- Check for direct tool call from new API
    if response.tool_call then
      local tool_call = response.tool_call
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
        tool_args = tool_call.arguments or tool_call.input or {}
      end
      
      if tool_name then
        tool_result = M.execute_tool(tool_name, tool_args)
        tool_used = true
        parsed_tool_name = tool_name
      end
    else
      -- Fallback: Try to parse JSON tool usage from response content
    local tool_match = response.content:match("```json%s*({[\n\r\t %-%w_%[%]{}:\",.]+})%s*```")
    if tool_match then
      local success, tool_data = pcall(vim.fn.json_decode, tool_match)
      if success and tool_data.tool_name and tool_data.parameters then
        -- Execute the tool
        tool_result = M.execute_tool(tool_data.tool_name, tool_data.parameters)
        tool_used = true
        parsed_tool_name = tool_data.tool_name
        end
      end
    end
    
    -- Format the response
    local response_lines = {}
    local first_resp = true
    -- Split AI response into lines and prefix the first with @>
    for line in string.gmatch(response.content, "[^\r\n]+") do
      if first_resp then
        table.insert(response_lines, "@> " .. line)
        first_resp = false
      else
        table.insert(response_lines, line)
      end
    end
    
    if tool_used and tool_result then
      -- Handle TalkToUser tool specially - it already displays its message
      if parsed_tool_name == "TalkToUser" and tool_result.success then
        -- TalkToUser tool handles its own display, so we don't need to show tool result
        -- Just add a small indicator that a tool was used
        table.insert(response_lines, "")
        table.insert(response_lines, "💬 *[Used TalkToUser tool]*")
      elseif parsed_tool_name == "Terminate" and tool_result.success then
        -- Terminate tool handles its own display and stops processing
        -- Just add a small indicator that the tool was used
        table.insert(response_lines, "")
        table.insert(response_lines, "⏹️ *[Agent terminated - waiting for user input]*")
        -- Don't continue processing - return immediately
        table.insert(response_lines, "") -- Add empty line after response
        vim.api.nvim_buf_set_lines(chat_bufnr, -1, -1, false, response_lines)
        -- Add to messages history
        table.insert(vim.b.agent_finder_chat_messages, { role = "assistant", content = response.content })
        -- Move cursor to end
        local new_lines = vim.api.nvim_buf_get_lines(chat_bufnr, 0, -1, false)
        vim.api.nvim_win_set_cursor(0, { #new_lines, 0 })
        return -- Exit the function - agent has terminated
      else
        -- For other tools, show the result
      table.insert(response_lines, "") -- Add empty line before tool result
      if tool_result.success then
        table.insert(response_lines, "🔧 **Tool Result:**")
        local tool_result_json = vim.fn.json_encode(tool_result.data or tool_result)
        for tool_line in string.gmatch(tool_result_json, "[^\r\n]+") do
          table.insert(response_lines, tool_line)
        end
        -- After showing tool result, make a follow-up model call including memory and tool output
        local function build_history_text()
          local parts = {}
          if vim.b.agent_finder_chat_messages then
            for _, msg in ipairs(vim.b.agent_finder_chat_messages) do
              local role = msg.role or "user"
              local text = msg.content or ""
              table.insert(parts, string.format("[%s] %s", role, text))
            end
          end
          return table.concat(parts, "\n\n")
        end
        local followup_input = {}
        if vim.b.agent_finder_chat_messages then
          for _, msg in ipairs(vim.b.agent_finder_chat_messages) do
            table.insert(followup_input, {
              type = "message",
              role = msg.role or "user",
              content = { { type = "input_text", text = msg.content or "" } },
            })
          end
        end
        table.insert(followup_input, {
          type = "message",
          role = "assistant",
          content = { { type = "output_text", text = string.format("Tool '%s' result as JSON:\n%s", parsed_tool_name or "tool", tool_result_json) } },
        })
        local followup = M._call_openai_api(followup_input, nil, nil, { prebuilt_input = followup_input, instructions = (vim.b.agent_finder_chat_agent and vim.b.agent_finder_chat_agent.prompt) or "" })
        if followup and followup.success and followup.content and followup.content ~= "" then
          table.insert(response_lines, "")
          local first_follow = true
          for line in string.gmatch(followup.content, "[^\r\n]+") do
            if first_follow then
              table.insert(response_lines, "@> " .. line)
              first_follow = false
            else
              table.insert(response_lines, line)
            end
          end
          -- Update history with assistant's follow-up content
          table.insert(vim.b.agent_finder_chat_messages, { role = "assistant", content = followup.content })
        end
      else
        table.insert(response_lines, "❌ **Tool Error:** " .. tool_result.error)
        end
      end
    end
    
    table.insert(response_lines, "") -- Add empty line after response
    
    vim.api.nvim_buf_set_lines(chat_bufnr, -1, -1, false, response_lines)
    
    -- Add to messages history
    table.insert(vim.b.agent_finder_chat_messages, { role = "assistant", content = response.content })
  else
    -- Remove "Thinking..." message
    M._stop_thinking_animation()
    local line_count = vim.api.nvim_buf_line_count(chat_bufnr)
    vim.api.nvim_buf_set_lines(chat_bufnr, line_count - 2, line_count, false, {})
    
    -- Show error message
    local error_lines = {}
    local error_msg = response.error or "Unknown error"
    -- Split error message by newlines and add each line
    for line in string.gmatch(error_msg, "[^\r\n]+") do
      table.insert(error_lines, "@> ❌ Error: " .. line)
    end
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
        properties[param_name] = {
          type = param_def.type,
          description = param_def.description or ""
        }
        
        if param_def.default then
          properties[param_name].default = param_def.default
        end
        
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
local json = vim.fn.json_encode
local decode = vim.json and vim.json.decode or vim.fn.json_decode

-- Try to use plenary.curl, fallback to system curl
local curl_available, curl = pcall(require, "plenary.curl")
if not curl_available then
  curl = nil  -- Will use system curl fallback
end

-- Helper: convert local tools -> OpenAI schema (supports both APIs)
local function build_tools_for(api_kind, tools_schema)
  if not tools_schema then return nil end
  debug_log("build_tools_for called with tools_schema:", vim.inspect(tools_schema))
  local out = {}
  for tool_key, spec in pairs(tools_schema) do
    debug_log("Processing tool:", tool_key, "spec:", vim.inspect(spec))
    local raw_name = spec.name or spec.tool_name or tool_key

    -- Clone parameters and adjust types/defaults as needed
    local parameters = spec.parameters or { type = "object", properties = {}, required = {} }
    parameters.type = parameters.type or "object"
    parameters.properties = parameters.properties or {}
    parameters.required = parameters.required or {}

    -- Ensure integer type for max_depth if present
    if parameters.properties.max_depth and parameters.properties.max_depth.type == "number" then
      parameters.properties.max_depth.type = "integer"
    end

    if api_kind == "responses" then
      -- Responses API expects flat tool objects: { type, name, description, parameters }
      local tool_obj = {
        type = "function",
        name = raw_name,
        description = spec.description or "",
        parameters = parameters,
      }
      debug_log("Built function (flat):", vim.inspect(tool_obj))
      table.insert(out, tool_obj)
    else
      -- Chat Completions API expects nested under "function"
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
  -- 1) Responses API happy path
  if api_kind == "responses" then
    if body.output_text and body.output_text ~= "" then
      return { kind = "text", content = body.output_text }
    end
    -- fallback: walk output array
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
          return { kind = "tool_call", content = item } -- hand back to caller
        end
      end
    end
    -- refusal?
    if body.refusal and body.refusal ~= "" then
      return { kind = "refusal", content = body.refusal }
    end
    return { kind = "none", content = nil }
  end

  -- 2) Chat Completions API
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

-- Main call
function M._call_openai_api(messages, model, api_key, opts)
  model = model or "gpt-5-nano-2025-08-07"
  api_key = api_key or vim.env.OPENAI_API_KEY
  opts = opts or {}

  if not api_key then
    return { success = false, error = "OpenAI API key not found. Set OPENAI_API_KEY or configure it in agents.lua" }
  end

  -- Decide endpoint
  local api_kind = (opts.api == "chat") and "chat" or "responses"
  local url = (api_kind == "responses")
      and "https://api.openai.com/v1/responses"
      or  "https://api.openai.com/v1/chat/completions"

  -- Build tools (if any)
  local tools_schema = nil
  local available_tools = M.get_tools and M.get_tools() or nil
  debug_log("Available tools:", vim.inspect(available_tools))
  if available_tools and type(available_tools) == "table" and not vim.tbl_isempty(available_tools) then
    tools_schema = M.generate_tools_schema and M.generate_tools_schema() or nil
    debug_log("Generated tools schema:", vim.inspect(tools_schema))
  end
  local openai_tools = build_tools_for(api_kind, tools_schema)
  debug_log("OpenAI tools:", vim.inspect(openai_tools))

  -- Build payload
  local payload
  if api_kind == "responses" then
    -- Responses API takes `input` (array of messages or mixed parts)
    payload = {
      model = model,
      input = messages,                     -- you can pass chat-style messages directly
      tools = openai_tools,
      tool_choice = opts.tool_choice or "auto",       -- e.g., "auto"
      max_output_tokens = opts.max_tokens,  -- Responses uses max_output_tokens
      response_format = opts.response_format, -- e.g. { type="json_schema", json_schema={...} }
      instructions = opts.instructions,     -- system-style instructions for Responses API
    }
  else
    -- Chat Completions API uses `messages`
    payload = {
      model = model,
      messages = messages,
      tools = openai_tools,
      tool_choice = opts.tool_choice,       -- "auto" / { "type": "function", "function": { "name": "..." } }
      max_tokens = opts.max_tokens,
      response_format = opts.response_format, -- newer chat API also supports structured outputs
    }
  end

  -- Send HTTP request
  local res, body
  local timeout_ms = tonumber((opts and opts.timeout_ms) or 300000)
  if not curl then
    return { success = false, error = "HTTP client unavailable: plenary.curl not found" }
  end
  local ok, r = pcall(curl.post, url, {
    headers = {
      ["Authorization"] = "Bearer " .. api_key,
      ["Content-Type"] = "application/json",
    },
    body = json(payload),
    timeout = timeout_ms,
  })
  if not ok or not r or not r.status then
    return { success = false, error = "HTTP request failed or timed out" }
  end
  if r.status < 200 or r.status >= 300 then
    return { success = false, error = ("HTTP %d: %s"):format(r.status, r.body or "") }
  end
  body = decode(r.body)
  local out = extract_content(api_kind, body)

  if out.kind == "text" then
    return { success = true, content = out.content, raw = body }
  elseif out.kind == "tool_call" then
    -- Hand tool call up to your tool runner; include raw for arguments
    return { success = true, tool_call = out.content, raw = body }
  elseif out.kind == "refusal" then
    return { success = false, error = out.content, raw = body }
  else
    return { success = false, error = "no content found", raw = body }
  end
end

-- Generate AI response using OpenAI with tools integration
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
  
  -- Ensure tools are loaded (tools are added to request automatically inside _call_openai_api)
  local tools = M.get_tools()
  if not tools or type(tools) ~= "table" or vim.tbl_isempty(tools) then
    M.load_tools()
  end
  
  -- Build initial input list as per Responses API
  local function build_history_text()
    local parts = {}
    if chat_history then
      for _, msg in ipairs(chat_history) do
        local role = msg.role or "user"
        local text = msg.content or ""
        table.insert(parts, string.format("[%s] %s", role, text))
      end
    end
    table.insert(parts, string.format("[user] %s", user_message or ""))
    return table.concat(parts, "\n\n")
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
  
  local max_iters = 3
  for iter = 1, max_iters do
    debug_log("API call iteration:", iter)
    debug_log("Input list:", vim.inspect(input_list))
    local resp = M._call_openai_api(input_list, nil, openai_key, { instructions = instructions })
    debug_log("API response:", vim.inspect(resp))
    if not resp.success then
      debug_log("API call failed:", resp.error)
      -- If it's a reasoning error and this is the first iteration, try with different parameters
      if iter == 1 and string.find(resp.error, "reasoning") and string.find(resp.error, "required following item") then
        debug_log("Retrying with different model parameters to avoid reasoning error")
        -- Try with a different model or parameters
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
    
    -- Check if we got a tool call directly from the API
    if resp.tool_call then
      debug_log("Found direct tool call:", vim.inspect(resp.tool_call))
      local tool_call = resp.tool_call
      local tool_name = nil
      local tool_args = {}
      
      -- Extract tool name and arguments based on API format
      if tool_call["function"] then
        tool_name = tool_call["function"].name
        if tool_call["function"].arguments then
          if type(tool_call["function"].arguments) == "string" then
            local success, parsed = pcall(vim.fn.json_decode, tool_call["function"].arguments)
            if success then
              tool_args = parsed
            end
          elseif type(tool_call["function"].arguments) == "table" then
            tool_args = tool_call["function"].arguments
          end
        end
      elseif tool_call.name then
        tool_name = tool_call.name
        -- Responses API may return arguments as a JSON string
        local args = tool_call.arguments or tool_call.input or {}
        if type(args) == "string" then
          local ok, parsed = pcall(vim.fn.json_decode, args)
          tool_args = ok and parsed or {}
        else
          tool_args = args
        end
      end
      
      if tool_name then
        debug_log("Executing tool:", tool_name, "with args:", vim.inspect(tool_args))
        local tool_result = M.execute_tool(tool_name, tool_args)
        debug_log("Tool result:", vim.inspect(tool_result))
        
        -- Check if this is a Terminate tool - if so, stop processing
        if tool_name == "Terminate" and tool_result.success then
          debug_log("Terminate tool executed, stopping processing loop")
          return { success = true, content = "Agent processing terminated. Waiting for user input." }
        end
        
        -- Add the tool result to the input list for the next iteration
        local tool_result_json = vim.fn.json_encode(tool_result.data or tool_result)
        table.insert(input_list, {
          type = "message",
          role = "assistant",
          content = { { type = "output_text", text = string.format("Tool '%s' result as JSON:\n%s", tool_name, tool_result_json) } },
        })
        
        -- Continue the loop to get the agent's response to the tool result
      else
        debug_log("Could not extract tool name from tool call")
        return { success = false, error = "Invalid tool call format" }
      end
    elseif resp.content and resp.content ~= "" then
      debug_log("Found text content:", resp.content)
      -- Check if the content contains a JSON tool call (fallback for older formats)
      local tool_match = resp.content:match("```json%s*({[^`]+})%s*```")
      if tool_match then
        debug_log("Found tool match in content:", tool_match)
        local success, tool_data = pcall(vim.fn.json_decode, tool_match)
        if success and tool_data.tool_name and tool_data.parameters then
          debug_log("Executing tool from content:", tool_data.tool_name)
          local tool_result = M.execute_tool(tool_data.tool_name, tool_data.parameters)
          debug_log("Tool result:", vim.inspect(tool_result))
          
          -- Check if this is a Terminate tool - if so, stop processing
          if tool_data.tool_name == "Terminate" and tool_result.success then
            debug_log("Terminate tool executed, stopping processing loop")
            return { success = true, content = "Agent processing terminated. Waiting for user input." }
          end
          
          -- Add the tool result to the input list for the next iteration
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
    
    -- Continue the loop to process the next iteration
    debug_log("Continuing to next iteration")
  end
  
  -- If we reach here, we've exhausted all iterations without getting a final response
  debug_log("Exhausted all iterations without final response")
  return { success = false, error = "No final response after processing iterations" }
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