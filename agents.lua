-- agent-finder.nvim Configuration
-- Main configuration file that loads agents from individual files

local M = {}

-- Debug mode - set to true to see detailed logging
M.debug = true

-- API Keys Configuration
M.api_keys = {
  openai = os.getenv("OPENAI_API_KEY") or "your-openai-api-key-here",
  anthropic = "your-anthropic-api-key-here",
  -- Add more services as needed
}

-- Agents Directory
-- The plugin will automatically load all .lua files from the agents/ directory
M.agents_directory = "agents/"

-- Alternative: You can still define agents inline if needed
-- M.agents = {
--   custom_agent = {
--     name = "Custom Agent",
--     description = "A custom agent defined inline",
--     prompt = "Your custom prompt here"
--   }
-- }

return M
