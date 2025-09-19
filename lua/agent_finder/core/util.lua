local M = {}

local config = require('agent_finder.config')

function M.debug_log(message, ...)
  if config.get('debug') then
    if ... then
      print("DEBUG:", message, ...)
    else
      print("DEBUG:", message)
    end
  end
end

return M



