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
  
  -- Get the directory of the main config file
  local config_dir = vim.fn.fnamemodify(main_config_file, ':h')
  local agents_path = config_dir .. '/' .. agents_dir
  
  -- Check if agents directory exists
  if vim.fn.isdirectory(agents_path) == 0 then
    vim.notify(
      string.format('agent-finder.nvim: Agents directory not found: %s', agents_path),
      vim.log.levels.ERROR
    )
    return agents
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

-- Clear buffer state
function M.clear_state()
  vim.b.agent_finder_agents = nil
  vim.b.agent_finder_goal = nil
  vim.b.agent_finder_api_keys = nil
  
  vim.notify('agent-finder.nvim: Buffer state cleared', vim.log.levels.INFO)
end

return M
