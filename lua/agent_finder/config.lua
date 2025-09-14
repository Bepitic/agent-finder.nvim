-- Configuration management for agent-finder.nvim

local M = {}

-- Default configuration
local defaults = {
  -- Path to agents YAML file
  agents_file = vim.fn.expand('~/.config/nvim/agents.yaml'),
  
  -- Default keymaps
  default_keymaps = true,
  
  -- YAML parsing preferences
  yaml_parser = 'yq', -- 'yq' or 'lua'
  
  -- API key configuration
  api_keys = {
    openai = nil,
    anthropic = nil,
    -- Add more services as needed
  },
  
  -- Agent configuration
  agents = {},
  
  -- Debug mode
  debug = false,
}

-- User configuration
local user_config = {}

-- Setup function to merge user config with defaults
function M.setup(opts)
  opts = opts or {}
  user_config = vim.tbl_deep_extend('force', defaults, opts)
  
  -- Validate configuration
  M._validate_config()
  
  if user_config.debug then
    vim.notify('agent-finder.nvim: Configuration loaded', vim.log.levels.INFO)
  end
end

-- Get configuration value
function M.get(key)
  return user_config[key] or defaults[key]
end

-- Set configuration value
function M.set(key, value)
  user_config[key] = value
end

-- Get all configuration
function M.get_all()
  return vim.tbl_deep_extend('force', defaults, user_config)
end

-- Validate configuration
function M._validate_config()
  local config = M.get_all()
  
  -- Check if agents file exists
  if not vim.fn.filereadable(config.agents_file) then
    vim.notify(
      string.format('agent-finder.nvim: Agents file not found: %s', config.agents_file),
      vim.log.levels.WARN
    )
  end
  
  -- Validate YAML parser
  if config.yaml_parser ~= 'yq' and config.yaml_parser ~= 'lua' then
    vim.notify(
      'agent-finder.nvim: Invalid yaml_parser. Must be "yq" or "lua"',
      vim.log.levels.ERROR
    )
  end
end

-- Initialize with defaults if not already set up
if vim.tbl_isempty(user_config) then
  M.setup()
end

return M
