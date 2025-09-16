-- Terminate tool for agent-finder.nvim
-- Allows AI agents to terminate their processing loop and wait for user input

local M = {}

M.name = "Terminate"
M.description = "Terminate the agent's processing loop and wait for user input"

M.parameters = {
  message = {
    type = "string",
    description = "Optional message to display when terminating (e.g., 'Waiting for your response...')",
    required = false
  }
}

M.execute = function(parameters)
  local message = parameters.message or "Agent processing terminated. Waiting for your response..."
  
  -- Get the current chat buffer
  local chat_bufnr = vim.b.agent_finder_chat_bufnr
  if not chat_bufnr or not vim.api.nvim_buf_is_valid(chat_bufnr) then
    return {
      success = false,
      error = "No active chat session found"
    }
  end
  
  -- Format the termination message
  local formatted_message = "@> " .. message
  
  -- Add the termination message to the chat buffer
  vim.api.nvim_buf_set_lines(chat_bufnr, -1, -1, false, { formatted_message, "" })
  
  -- Move cursor to the end of the buffer
  local line_count = vim.api.nvim_buf_line_count(chat_bufnr)
  vim.api.nvim_win_set_cursor(0, { line_count, 0 })
  
  -- Add to chat messages history
  if vim.b.agent_finder_chat_messages then
    table.insert(vim.b.agent_finder_chat_messages, { role = "assistant", content = message })
  end
  
  -- Set a flag to indicate that the agent has terminated and is waiting for user input
  vim.b.agent_finder_terminated = true
  
  return {
    success = true,
    data = {
      message = message,
      formatted_message = formatted_message,
      timestamp = os.date("%Y-%m-%d %H:%M:%S"),
      terminated = true
    }
  }
end

return M
