-- List Workspace Files Tool
-- Lists all files in the current workspace directory with optional filtering

local M = {}

-- Debug logging function
local function debug_log(message, ...)
  local config = require('agent_finder.config')
  if config and config.get and config.get('debug') then
    local args = {...}
    if #args > 0 then
      local arg_str = ""
      for i, arg in ipairs(args) do
        if i > 1 then arg_str = arg_str .. " " end
        if type(arg) == "table" then
          arg_str = arg_str .. vim.inspect(arg)
        else
          arg_str = arg_str .. tostring(arg)
        end
      end
      print("DEBUG [list_files]:", message, arg_str)
    else
      print("DEBUG [list_files]:", message)
    end
  end
end

-- Tool metadata
M.name = "List Workspace Files"
M.description = "Lists all files in the current workspace directory with optional filtering"
M.version = "1.0.0"
M.author = "agent-finder.nvim"

-- Tool parameters definition
M.parameters = {
  path = {
    type = "string",
    required = false,
    default = ".",
    description = "Directory path to list files from (relative to workspace root)"
  },
  pattern = {
    type = "string",
    required = false,
    default = "*",
    description = "File pattern to match (e.g., '*.lua', '*.yaml', '**/*.md')"
  },
  include_hidden = {
    type = "boolean",
    required = false,
    default = false,
    description = "Whether to include hidden files (starting with .)"
  },
  max_depth = {
    type = "number",
    required = false,
    default = 10,
    description = "Maximum directory depth to search (0 = current directory only)"
  }
}

-- Tool implementation
function M.execute(params)
  debug_log("=== LIST_FILES TOOL EXECUTED ===")
  debug_log("Starting list_files tool execution")
  debug_log("Input parameters:", vim.inspect(params))
  
  local path = params.path or "."
  local pattern = params.pattern or "*"
  local include_hidden = params.include_hidden or false
  local max_depth = params.max_depth or 10
  
  debug_log("Processed parameters - path:", path)
  debug_log("Processed parameters - pattern:", pattern)
  debug_log("Processed parameters - include_hidden:", include_hidden)
  debug_log("Processed parameters - max_depth:", max_depth)
  
  -- Validate parameters
  if type(path) ~= "string" then
    return { 
      success = false, 
      error = "path must be a string, got: " .. type(path),
      error_type = "invalid_parameter"
    }
  end
  
  if type(pattern) ~= "string" then
    return { 
      success = false, 
      error = "pattern must be a string, got: " .. type(pattern),
      error_type = "invalid_parameter"
    }
  end
  
  if type(include_hidden) ~= "boolean" then
    return { 
      success = false, 
      error = "include_hidden must be a boolean, got: " .. type(include_hidden),
      error_type = "invalid_parameter"
    }
  end
  
  if type(max_depth) ~= "number" or max_depth < 0 then
    return { 
      success = false, 
      error = "max_depth must be a non-negative number, got: " .. tostring(max_depth),
      error_type = "invalid_parameter"
    }
  end
  
  -- Get workspace root
  local workspace_root = vim.fn.getcwd()
  local target_path = workspace_root .. "/" .. path
  
  debug_log("Path resolution - workspace_root:", workspace_root)
  debug_log("Path resolution - target_path:", target_path)
  
  -- Check if path exists
  debug_log("Checking if directory exists:", target_path)
  if vim.fn.isdirectory(target_path) == 0 then
    debug_log("Directory does not exist, checking if it's a file")
    -- Check if it's a file instead of directory
    if vim.fn.filereadable(target_path) == 1 then
      debug_log("Path is a file, not a directory")
      return { 
        success = false, 
        error = "Path is a file, not a directory: " .. target_path,
        error_type = "not_directory"
      }
    else
      debug_log("Path does not exist at all")
      return { 
        success = false, 
        error = "Directory does not exist: " .. target_path,
        error_type = "directory_not_found"
      }
    end
  end
  
  debug_log("Directory exists, checking permissions")
  -- Check if we have read permissions for the directory
  local read_permission = vim.fn.getfperm(target_path)
  debug_log("Directory permissions:", read_permission)
  if not read_permission or not read_permission:match("r") then
    debug_log("No read permission for directory")
    return { 
      success = false, 
      error = "No read permission for directory: " .. target_path,
      error_type = "permission_denied"
    }
  end
  
  -- Build glob pattern
  local glob_pattern = pattern
  if max_depth > 0 then
    -- For recursive search, use **/ prefix
    if pattern == "*" then
      glob_pattern = "**/*"
    else
      glob_pattern = "**/" .. pattern
    end
  end
  
  debug_log("Glob pattern built - original_pattern:", pattern)
  debug_log("Glob pattern built - final_glob_pattern:", glob_pattern)
  debug_log("Glob pattern built - max_depth:", max_depth)
  
  -- Find files with error handling
  debug_log("Starting file search with globpath")
  debug_log("globpath parameters - target_path:", target_path)
  debug_log("globpath parameters - glob_pattern:", glob_pattern)
  
  -- Test with a simple pattern first
  local test_files = vim.fn.globpath(target_path, "*", false, true)
  debug_log("Test with simple pattern '*':", #test_files, "files found")
  
  local success, files = pcall(function()
    return vim.fn.globpath(target_path, glob_pattern, false, true)
  end)
  
  if not success then
    debug_log("File search failed:", tostring(files))
    return { 
      success = false, 
      error = "Failed to search directory: " .. tostring(files),
      error_type = "search_failed"
    }
  end
  
  debug_log("File search completed successfully")
  debug_log("Raw files found:", #files, "files")
  
  -- Check if files is nil or empty (could indicate permission issues)
  if not files or type(files) ~= "table" then
    debug_log("Invalid response from file search:", type(files))
    return { 
      success = false, 
      error = "Invalid response from file search in directory: " .. target_path,
      error_type = "invalid_response"
    }
  end
  
  -- Filter out hidden files if not requested
  if not include_hidden then
    debug_log("Filtering out hidden files")
    local filtered_files = {}
    for _, file in ipairs(files) do
      local filename = vim.fn.fnamemodify(file, ":t")
      if not filename:match("^%.") then
        table.insert(filtered_files, file)
      end
    end
    debug_log("Files after hidden filter:", #filtered_files, "files (removed", #files - #filtered_files, "hidden files)")
    files = filtered_files
  else
    debug_log("Including hidden files")
  end
  
  -- Sort files
  table.sort(files)
  debug_log("Files sorted, final count:", #files)
  
  -- Check if no files were found and provide helpful message
  if #files == 0 then
    debug_log("No files found matching criteria")
    local message = "No files found"
    local details = {
      workspace_root = workspace_root,
      target_path = target_path,
      pattern = pattern,
      include_hidden = include_hidden,
      max_depth = max_depth
    }
    
    -- Provide more specific information about why no files were found
    if pattern == "*" then
      message = message .. " in directory: " .. target_path
    else
      message = message .. " matching pattern '" .. pattern .. "' in directory: " .. target_path
    end
    
    if not include_hidden then
      message = message .. " (hidden files excluded)"
    end
    
    return {
      success = true,
      data = details,
      message = message,
      file_count = 0,
      files = {}
    }
  end
  
  -- Format results
  debug_log("Preparing successful result")
  local result = {
    success = true,
    data = {
      workspace_root = workspace_root,
      target_path = target_path,
      pattern = pattern,
      include_hidden = include_hidden,
      max_depth = max_depth,
      file_count = #files,
      files = files
    }
  }
  
  debug_log("Tool execution completed successfully")
  debug_log("Final result summary - file_count:", #files)
  debug_log("Final result summary - target_path:", target_path)
  debug_log("Final result summary - pattern:", pattern)
  
  return result
end

return M
