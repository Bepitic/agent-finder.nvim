-- List Workspace Files Tool
-- Lists all files in the current workspace directory with optional filtering

local M = {}

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
  local path = params.path or "."
  local pattern = params.pattern or "*"
  local include_hidden = params.include_hidden or false
  local max_depth = params.max_depth or 10
  
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
  
  -- Check if path exists
  if vim.fn.isdirectory(target_path) == 0 then
    -- Check if it's a file instead of directory
    if vim.fn.filereadable(target_path) == 1 then
      return { 
        success = false, 
        error = "Path is a file, not a directory: " .. target_path,
        error_type = "not_directory"
      }
    else
      return { 
        success = false, 
        error = "Directory does not exist: " .. target_path,
        error_type = "directory_not_found"
      }
    end
  end
  
  -- Check if we have read permissions for the directory
  local read_permission = vim.fn.getfperm(target_path)
  if not read_permission or not read_permission:match("r") then
    return { 
      success = false, 
      error = "No read permission for directory: " .. target_path,
      error_type = "permission_denied"
    }
  end
  
  -- Build glob pattern
  local glob_pattern = pattern
  if max_depth > 0 then
    -- Add depth limitation
    local depth_pattern = ""
    for i = 1, max_depth do
      if i == 1 then
        depth_pattern = "**/"
      else
        depth_pattern = depth_pattern .. "*/"
      end
    end
    glob_pattern = depth_pattern .. pattern
  end
  
  -- Find files with error handling
  local success, files = pcall(function()
    return vim.fn.globpath(target_path, glob_pattern, false, true)
  end)
  
  if not success then
    return { 
      success = false, 
      error = "Failed to search directory: " .. tostring(files),
      error_type = "search_failed"
    }
  end
  
  -- Check if files is nil or empty (could indicate permission issues)
  if not files or type(files) ~= "table" then
    return { 
      success = false, 
      error = "Invalid response from file search in directory: " .. target_path,
      error_type = "invalid_response"
    }
  end
  
  -- Filter out hidden files if not requested
  if not include_hidden then
    local filtered_files = {}
    for _, file in ipairs(files) do
      local filename = vim.fn.fnamemodify(file, ":t")
      if not filename:match("^%.") then
        table.insert(filtered_files, file)
      end
    end
    files = filtered_files
  end
  
  -- Sort files
  table.sort(files)
  
  -- Check if no files were found and provide helpful message
  if #files == 0 then
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
  
  return result
end

return M
