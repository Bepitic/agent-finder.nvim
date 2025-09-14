-- agent-finder.nvim - Public API

local M = {}

-- Core functionality
local core = require('agent_finder.core')
local config = require('agent_finder.config')

-- Public API functions
function M.setup(opts)
  config.setup(opts)
end

function M.load_agents()
  return core.load_agents()
end

function M.set_goal()
  return core.set_goal()
end

function M.apply_goal()
  return core.apply_goal()
end

function M.export_env()
  return core.export_env()
end

function M.list_agents()
  return core.list_agents()
end

function M.select_agent()
  return core.select_agent()
end

-- Utility functions
function M.get_agents()
  return core.get_agents()
end

function M.get_goal()
  return core.get_goal()
end

function M.get_selected_agent()
  return core.get_selected_agent()
end

function M.clear_state()
  return core.clear_state()
end

-- Configuration helpers
function M.get_config(key)
  return config.get(key)
end

function M.set_config(key, value)
  return config.set(key, value)
end

return M
