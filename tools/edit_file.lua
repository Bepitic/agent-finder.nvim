-- EditFile tool for agent-finder.nvim
-- Applies line-based edits to a file given absolute path and line ranges

local M = {}

M.name = "EditFile"
M.description = "Apply one or more line-based edits to a file by absolute path"
M.version = "1.0.0"
M.author = "agent-finder.nvim"

-- Parameters:
-- - path (string, required): absolute path to file
-- - edits (array of objects, required): each edit: { start_line, end_line, new_lines(array of strings) }
-- Notes:
--   Lines are 1-based and inclusive. To insert without replacing, set start_line=end_line+1 and provide new_lines.

M.parameters = {
  path = {
    type = "string",
    required = true,
    description = "Absolute file path to edit"
  },
  edits = {
    type = "array",
    required = true,
    description = "Array of edits with start_line, end_line, new_lines (strings)",
    items = {
      type = "object",
      properties = {
        start_line = { type = "integer", description = "1-based start line (inclusive)" },
        end_line = { type = "integer", description = "1-based end line (inclusive). Use start-1 for insert" },
        new_lines = { type = "array", items = { type = "string" }, description = "Replacement lines; empty to delete" },
      },
      required = { "start_line", "new_lines" }
    }
  }
}

local function read_all_lines(path)
  local ok, fd = pcall(vim.loop.fs_open, path, "r", 438)
  if not ok or not fd then return nil, "Unable to open file for reading: " .. tostring(path) end
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
  return lines, nil
end

local function write_all_lines(path, lines)
  local data = table.concat(lines, "\n") .. "\n"
  local ok, fd = pcall(vim.loop.fs_open, path, "w", 420) -- 0644
  if not ok or not fd then return false, "Unable to open file for writing: " .. tostring(path) end
  local write_ok, err = pcall(vim.loop.fs_write, fd, data, 0)
  vim.loop.fs_close(fd)
  if not write_ok then return false, "Unable to write file: " .. tostring(err) end
  return true
end

local function validate_edits(edits)
  if type(edits) ~= "table" then return false, "edits must be an array/table" end
  for idx, e in ipairs(edits) do
    if type(e) ~= "table" then return false, string.format("edits[%d] must be a table", idx) end
    if type(e.start_line) ~= "number" or e.start_line < 1 then
      return false, string.format("edits[%d].start_line must be a positive number", idx)
    end
    if e.end_line ~= nil and (type(e.end_line) ~= "number" or e.end_line < e.start_line - 1) then
      return false, string.format("edits[%d].end_line must be >= start_line-1", idx)
    end
    if type(e.new_lines) ~= "table" then
      return false, string.format("edits[%d].new_lines must be an array of strings", idx)
    end
    for j, ln in ipairs(e.new_lines) do
      if type(ln) ~= "string" then
        return false, string.format("edits[%d].new_lines[%d] must be string", idx, j)
      end
    end
  end
  return true
end

function M.execute(params)
  local path = params.path
  local edits = params.edits

  if type(path) ~= "string" or path == "" then
    return { success = false, error = "path must be a non-empty string" }
  end
  if vim.fn.filereadable(path) ~= 1 then
    return { success = false, error = "File not found or not readable: " .. path, error_type = "file_not_found" }
  end

  local ok, err = validate_edits(edits)
  if not ok then
    return { success = false, error = err }
  end

  local lines, rerr = read_all_lines(path)
  if not lines then
    return { success = false, error = rerr or "Failed to read file" }
  end

  -- Apply edits. To keep line indices stable per user intent, sort by start_line ascending, then apply sequentially while adjusting offset.
  table.sort(edits, function(a, b)
    if a.start_line == b.start_line then
      local ae = a.end_line or a.start_line - 1
      local be = b.end_line or b.start_line - 1
      return ae < be
    end
    return a.start_line < b.start_line
  end)

  local offset = 0
  for _, e in ipairs(edits) do
    local s = e.start_line + offset
    local ee = e.end_line
    if ee == nil then
      ee = s - 1 -- insertion before s
    else
      ee = ee + offset
    end

    -- Bounds normalization
    if s < 1 then s = 1 end
    if ee < 0 then ee = 0 end
    local max_line = #lines
    if s > max_line + 1 then s = max_line + 1 end
    if ee > max_line then ee = max_line end

    -- Remove [s..ee]
    if ee >= s then
      for i = s, ee do
        table.remove(lines, s)
      end
    end

    -- Insert new_lines at position s
    if #e.new_lines > 0 then
      for i = 1, #e.new_lines do
        table.insert(lines, s + i - 1, e.new_lines[i])
      end
    end

    local removed = math.max(0, ee - s + 1)
    local added = #e.new_lines
    offset = offset + (added - removed)
  end

  local wrote, werr = write_all_lines(path, lines)
  if not wrote then
    return { success = false, error = werr or "Failed to write file" }
  end

  return {
    success = true,
    data = {
      path = path,
      edits_applied = #edits,
      final_line_count = #lines
    }
  }
end

return M


