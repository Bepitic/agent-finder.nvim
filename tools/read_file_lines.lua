-- ReadFileLines tool for agent-finder.nvim
-- Reads a file from start_line to end_line (inclusive) and returns the lines

local M = {}

M.name = "ReadFileLines"
M.description = "Read a file by absolute path and return a line range"
M.version = "1.0.0"
M.author = "agent-finder.nvim"

M.parameters = {
  path = {
    type = "string",
    required = true,
    description = "Absolute file path to read"
  },
  start_line = {
    type = "number",
    required = false,
    default = 1,
    description = "1-based start line (inclusive)"
  },
  end_line = {
    type = "number",
    required = false,
    description = "1-based end line (inclusive). Omit to read to EOF"
  }
}

local function read_file_lines_abs(path, start_line, end_line)
  local ok, fd = pcall(vim.loop.fs_open, path, "r", 438)
  if not ok or not fd then
    return nil, "Unable to open file: " .. tostring(path)
  end

  local stat_ok, stat = pcall(vim.loop.fs_fstat, fd)
  if not stat_ok or not stat or not stat.size then
    vim.loop.fs_close(fd)
    return nil, "Unable to stat file: " .. tostring(path)
  end

  local read_ok, data = pcall(vim.loop.fs_read, fd, stat.size, 0)
  vim.loop.fs_close(fd)
  if not read_ok or type(data) ~= "string" then
    return nil, "Unable to read file: " .. tostring(path)
  end

  local lines = {}
  for line in (data .. "\n"):gmatch("(.-)\n") do
    table.insert(lines, line)
  end
  local total = #lines

  if start_line < 1 then start_line = 1 end
  if end_line == nil or end_line > total then end_line = total end
  if start_line > end_line then
    return {}, nil
  end

  local slice = {}
  for i = start_line, end_line do
    table.insert(slice, lines[i])
  end
  return slice, nil
end

function M.execute(params)
  local path = params.path
  local start_line = params.start_line or 1
  local end_line = params.end_line

  if type(path) ~= "string" or path == "" then
    return { success = false, error = "path must be a non-empty string" }
  end
  if start_line ~= nil and type(start_line) ~= "number" then
    return { success = false, error = "start_line must be a number" }
  end
  if end_line ~= nil and type(end_line) ~= "number" then
    return { success = false, error = "end_line must be a number or nil" }
  end

  if vim.fn.filereadable(path) ~= 1 then
    return { success = false, error = "File not found or not readable: " .. path, error_type = "file_not_found" }
  end

  local lines, err = read_file_lines_abs(path, start_line, end_line)
  if not lines then
    return { success = false, error = err or "Failed to read file" }
  end

  return {
    success = true,
    data = {
      path = path,
      start_line = start_line,
      end_line = end_line,
      line_count = #lines,
      lines = lines
    }
  }
end

return M


