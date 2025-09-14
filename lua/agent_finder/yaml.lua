-- YAML parsing utilities for agent-finder.nvim

local M = {}

-- Parse YAML using yq (preferred method)
local function parse_with_yq(filepath)
  local cmd = string.format('yq eval-all -o=json "%s"', filepath)
  local handle = io.popen(cmd)
  
  if not handle then
    return nil, 'Failed to execute yq command'
  end
  
  local result = handle:read('*a')
  local success, exit_reason, exit_code = handle:close()
  
  if not success or exit_code ~= 0 then
    return nil, string.format('yq command failed: %s (exit code: %s)', exit_reason or 'unknown', exit_code or 'unknown')
  end
  
  -- Parse JSON result
  local ok, parsed = pcall(vim.fn.json_decode, result)
  if not ok then
    return nil, 'Failed to parse yq JSON output: ' .. tostring(parsed)
  end
  
  return parsed, nil
end

-- Simple YAML parser fallback (basic implementation)
local function parse_with_lua(filepath)
  local content = vim.fn.readfile(filepath)
  if vim.tbl_isempty(content) then
    return nil, 'Empty YAML file'
  end
  
  -- This is a very basic YAML parser for simple cases
  -- For production use, consider using a proper YAML library
  local result = {}
  local current_section = nil
  
  for _, line in ipairs(content) do
    line = vim.trim(line)
    
    -- Skip empty lines and comments
    if line == '' or line:match('^%s*#') then
      goto continue
    end
    
    -- Section headers (e.g., "agents:")
    if line:match('^%w+:%s*$') then
      current_section = line:match('^(%w+):')
      result[current_section] = {}
      goto continue
    end
    
    -- Key-value pairs
    local key, value = line:match('^%s*([%w_]+):%s*(.*)$')
    if key and value then
      if current_section then
        result[current_section][key] = value
      else
        result[key] = value
      end
    end
    
    ::continue::
  end
  
  return result, nil
end

-- Main YAML parsing function
function M.parse_file(filepath)
  local config = require('agent_finder.config')
  local parser = config.get('yaml_parser')
  
  if parser == 'yq' then
    local result, err = parse_with_yq(filepath)
    if result then
      return result, nil
    end
    
    -- Fallback to Lua parser if yq fails
    vim.notify(
      string.format('yq parsing failed (%s), falling back to Lua parser', err or 'unknown error'),
      vim.log.levels.WARN
    )
    return parse_with_lua(filepath)
  else
    return parse_with_lua(filepath)
  end
end

-- Validate YAML structure
function M.validate_structure(data)
  if type(data) ~= 'table' then
    return false, 'Root element must be a table'
  end
  
  -- Check for required sections
  if not data.agents then
    return false, 'Missing required "agents" section'
  end
  
  if type(data.agents) ~= 'table' then
    return false, '"agents" section must be a table'
  end
  
  -- Validate agent definitions
  for name, agent in pairs(data.agents) do
    if type(agent) ~= 'table' then
      return false, string.format('Agent "%s" must be a table', name)
    end
    
    if not agent.name then
      return false, string.format('Agent "%s" missing required "name" field', name)
    end
    
    if not agent.prompt then
      return false, string.format('Agent "%s" missing required "prompt" field', name)
    end
  end
  
  return true, nil
end

return M
