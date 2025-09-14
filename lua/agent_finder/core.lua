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
  
  -- Show "Thinking..." message
  local thinking_line = "@> 🤔 Thinking..."
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
    table.insert(error_lines, "@> ❌ Error: " .. response.error)
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
function M._call_openai_api(messages, model, api_key, opts)
  model = model or "gpt-5-nano-2025-08-07"
  api_key = api_key or vim.env.OPENAI_API_KEY
  opts = opts or {}
  
  if not api_key then
    return { success = false, error = "OpenAI API key not found. Set OPENAI_API_KEY environment variable or configure it in agents.yaml" }
  end

  -- Convert local tools into OpenAI tool schema if available
  local openai_tools = nil
  local available_tools = M.get_tools()
  if available_tools and type(available_tools) == "table" and not vim.tbl_isempty(available_tools) then
    local tools_schema = M.generate_tools_schema()
    openai_tools = {}
    for tool_name, spec in pairs(tools_schema or {}) do
      table.insert(openai_tools, {
        type = "function",
        name = spec.tool_name or tool_name,
        description = spec.description or "",
        parameters = spec.parameters or { type = "object", properties = {}, required = {} },
      })
    end
  end

  -- Build input for Responses API
  local request_input = nil
  if opts.prebuilt_input ~= nil then
    request_input = opts.prebuilt_input
  else
    local input_text = ""
    if type(messages) == "table" then
      for _, msg in ipairs(messages) do
        local role = msg.role or "user"
        local text = msg.content or ""
        input_text = input_text .. string.format("[%s] %s\n\n", role, text)
      end
    elseif type(messages) == "string" then
      input_text = messages
    end
    request_input = vim.trim(input_text)
  end
  
  local request_body = {
    model = model,
    input = request_input,
    temperature = 0.7,
    max_output_tokens = 1000,
  }

  if opts.instructions and type(opts.instructions) == "string" then
    request_body.instructions = opts.instructions
  end

  if openai_tools and #openai_tools > 0 then
    request_body.tools = openai_tools
    request_body.tool_choice = "auto"
  end
  
  local json_body = vim.fn.json_encode(request_body)
  
  -- Make HTTP request to OpenAI API
  local response = vim.fn.system({
    'curl',
    '-s',
    '-X', 'POST',
    'https://api.openai.com/v1/responses',
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
  
  if result.error ~= nil and result.error ~= vim.NIL then
    local err_msg = "Unknown error"
    if type(result.error) == "table" then
      err_msg = result.error.message or result.error.type or vim.fn.json_encode(result.error)
    elseif type(result.error) == "string" then
      err_msg = result.error
    else
      -- result.error can be userdata; stringify safely
      local ok, s = pcall(function()
        return tostring(result.error)
      end)
      if ok and s and s ~= "" then
        err_msg = s
      end
    end
    return { success = false, error = "OpenAI API error: " .. err_msg }
  end
  
  -- Try Responses API fields first
  local content = nil
  if type(result.output_text) == "string" and result.output_text ~= "" then
    content = result.output_text
  elseif type(result.content) == "table" then
    -- Aggregate text from content items
    local parts = {}
    for _, item in ipairs(result.content) do
      if type(item) == "table" then
        if item.type == "output_text" and type(item.text) == "string" then
          table.insert(parts, item.text)
        elseif item.type == "text" and type(item.text) == "string" then
          table.insert(parts, item.text)
        elseif item.type == "message" and type(item.content) == "table" then
          for _, sub in ipairs(item.content) do
            if (sub.type == "text" or sub.type == "output_text") and type(sub.text) == "string" then
              table.insert(parts, sub.text)
            end
          end
        end
      end
    end
    if #parts > 0 then
      content = table.concat(parts, "\n")
    end
  elseif type(result.output) == "table" then
    -- Some models return `output` instead of `content`
    local parts = {}
    for _, item in ipairs(result.output) do
      if type(item) == "table" then
        if item.type == "output_text" and type(item.text) == "string" then
          table.insert(parts, item.text)
        elseif item.type == "text" and type(item.text) == "string" then
          table.insert(parts, item.text)
        elseif item.type == "message" and type(item.content) == "table" then
          for _, sub in ipairs(item.content) do
            if (sub.type == "text" or sub.type == "output_text") and type(sub.text) == "string" then
              table.insert(parts, sub.text)
            end
          end
        end
      end
    end
    if #parts > 0 then
      content = table.concat(parts, "\n")
    end
  end

  -- Back-compat: Chat Completions shape
  if not content and result.choices and #result.choices > 0 then
    local message = result.choices[1].message or {}
    content = message.content
    -- If model responded with tool calls, translate first one into a JSON block
    if (not content or content == "") and message.tool_calls and #message.tool_calls > 0 then
      local tool_call = message.tool_calls[1]
      if tool_call and tool_call.type == "function" and tool_call["function"] then
        local fn = tool_call["function"]
        local args_tbl = nil
        if type(fn.arguments) == "string" and fn.arguments ~= "" then
          local ok, parsed_args = pcall(vim.fn.json_decode, fn.arguments)
          if ok then args_tbl = parsed_args end
        elseif type(fn.arguments) == "table" then
          args_tbl = fn.arguments
        end
        args_tbl = args_tbl or {}
        local tool_json = {
          tool_name = fn.name,
          parameters = args_tbl,
        }
        content = "```json\n" .. vim.fn.json_encode(tool_json) .. "\n```"
      end
    end
  end

  -- Responses tool call shape: try to translate if no plain text was found
  local function try_extract_tool_from_items(items)
    for _, item in ipairs(items) do
      if type(item) == "table" then
        if item.type == "tool_call" or item.type == "tool_use" or item.type == "function_call" then
          local name = item.name or (item.tool and item.tool.name) or (item["function"] and item["function"].name)
          local args = item.arguments or item.input or (item["function"] and item["function"].arguments)
          local args_tbl = {}
          if type(args) == "string" and args ~= "" then
            local ok, parsed = pcall(vim.fn.json_decode, args)
            if ok then args_tbl = parsed else args_tbl = { _raw = args } end
          elseif type(args) == "table" then
            args_tbl = args
          end
          if name then
            local tool_json = { tool_name = name, parameters = args_tbl }
            return "```json\n" .. vim.fn.json_encode(tool_json) .. "\n```"
          end
        elseif item.type == "message" and type(item.content) == "table" then
          local inner = try_extract_tool_from_items(item.content)
          if inner then return inner end
        end
      end
    end
    return nil
  end

  if (not content or content == "") and type(result.content) == "table" then
    content = try_extract_tool_from_items(result.content) or content
  end
  if (not content or content == "") and type(result.output) == "table" then
    content = try_extract_tool_from_items(result.output) or content
  end

  if not content or content == "" then
    if opts.return_raw then
      return { success = true, content = "", raw = result }
    end
    return { success = false, error = "Empty response from OpenAI API" }
  end
  
  if opts.return_raw then
    return { success = true, content = content, raw = result }
  end
  return { success = true, content = content }
end

-- Generate AI response using OpenAI with tools integration
function M._generate_ai_response(agent, user_message, chat_history)
  local api_keys = vim.b.agent_finder_api_keys or {}
  local openai_key = api_keys.openai or vim.env.OPENAI_API_KEY
  
  if config.get('debug') then
    vim.notify('agent-finder.nvim: API keys from config: ' .. vim.fn.json_encode(api_keys), vim.log.levels.DEBUG)
    vim.notify('agent-finder.nvim: OpenAI key found: ' .. (openai_key and "yes" or "no"), vim.log.levels.DEBUG)
  end
  
  if not openai_key then
    return { success = false, error = "OpenAI API key not configured. Please run :AFLoad to load your agents.yaml configuration, or set OPENAI_API_KEY environment variable." }
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
  
  local input_list = {
    { type = "input_text", text = build_history_text() }
  }
  
  local instructions = agent.prompt or ""
  
  local max_iters = 3
  for _ = 1, max_iters do
    local resp = M._call_openai_api(input_list, nil, openai_key, { prebuilt_input = input_list, instructions = instructions, return_raw = true })
    if not resp.success then
      return resp
    end
    
    -- If we got text content, return it
    if resp.content and resp.content ~= "" then
      return { success = true, content = resp.content }
    end
    
    local raw = resp.raw or {}
    local output_items = {}
    if type(raw.output) == "table" then
      output_items = raw.output
    elseif type(raw.content) == "table" then
      output_items = raw.content
    end
    
    -- Append model output back into the next request input
    for _, item in ipairs(output_items) do
      table.insert(input_list, item)
    end
    
    -- Execute any function calls and append their outputs
    local executed_any = false
    for _, item in ipairs(output_items) do
      if type(item) == "table" then
        local item_type = item.type
        if item_type == "function_call" or item_type == "tool_use" or item_type == "tool_call" then
          local name = item.name or (item.tool and item.tool.name) or (item["function"] and item["function"].name)
          local args = item.arguments or item.input or (item["function"] and item["function"].arguments)
          local args_tbl = {}
          if type(args) == "string" and args ~= "" then
            local ok, parsed = pcall(vim.fn.json_decode, args)
            if ok then args_tbl = parsed else args_tbl = { _raw = args } end
          elseif type(args) == "table" then
            args_tbl = args
          end
          if name and name ~= "" then
            local tool_result = M.execute_tool(name, args_tbl)
            local call_id = item.call_id or item.id or (name .. "_call")
            local output_payload = tool_result
            -- Ensure output is a JSON string
            local output_str = nil
            local ok_json, encoded = pcall(vim.fn.json_encode, output_payload)
            if ok_json then output_str = encoded else output_str = tostring(output_payload) end
            table.insert(input_list, {
              type = "function_call_output",
              call_id = call_id,
              output = output_str,
            })
            executed_any = true
          end
        end
      end
    end
    
    -- If we executed a tool, loop to send the augmented input_list; otherwise break to avoid infinite loop
    if not executed_any then
      break
    end
  end
  
  return { success = false, error = "No textual output from model after tool calls" }
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
