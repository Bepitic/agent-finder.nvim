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
    return { success = false, error = "path must be a string" }
  end
  
  if type(pattern) ~= "string" then
    return { success = false, error = "pattern must be a string" }
  end
  
  if type(include_hidden) ~= "boolean" then
    return { success = false, error = "include_hidden must be a boolean" }
  end
  
  if type(max_depth) ~= "number" or max_depth < 0 then
    return { success = false, error = "max_depth must be a non-negative number" }
  end
  
  -- Get workspace root
  local workspace_root = vim.fn.getcwd()
  local target_path = workspace_root .. "/" .. path
  
  -- Check if path exists
  if vim.fn.isdirectory(target_path) == 0 then
    return { success = false, error = "Directory does not exist: " .. target_path }
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
  
  -- Find files
  local files = vim.fn.globpath(target_path, glob_pattern, false, true)
  
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
