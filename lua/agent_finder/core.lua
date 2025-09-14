-- Core functionality for agent-finder.nvim

local M = {}

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
  end
  
  local agent_count = vim.tbl_count(agents)
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
  if not agents or vim.tbl_isempty(agents) then
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
  if not agents or vim.tbl_isempty(agents) then
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
  if not agents or vim.tbl_isempty(agents) then
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

-- Clear buffer state
function M.clear_state()
  vim.b.agent_finder_agents = nil
  vim.b.agent_finder_goal = nil
  vim.b.agent_finder_api_keys = nil
  vim.b.agent_finder_selected_agent = nil
  
  vim.notify('agent-finder.nvim: Buffer state cleared', vim.log.levels.INFO)
end

return M
