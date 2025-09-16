-- TalkToUser tool for agent-finder.nvim
-- Allows AI agents to send messages directly to the chat window

local M = {}

M.name = "TalkToUser"
M.description = "Send a message directly to the user in the chat window"

M.parameters = {
  message = {
    type = "string",
    description = "The message to send to the user",
    required = true
  }
}

M.execute = function(parameters)
  local message = parameters.message
  
  if not message or message == "" then
    return {
      success = false,
      error = "Message parameter is required and cannot be empty"
    }
  end
  
  -- Get the current chat buffer and add the message
  local chat_bufnr = vim.b.agent_finder_chat_bufnr
  if not chat_bufnr or not vim.api.nvim_buf_is_valid(chat_bufnr) then
    return {
      success = false,
      error = "No active chat session found"
    }
  end
  
  -- Format the message with agent prefix
  local formatted_message = "@> " .. message
  
  -- Add the message to the chat buffer
  vim.api.nvim_buf_set_lines(chat_bufnr, -1, -1, false, { formatted_message, "" })
  
  -- Move cursor to the end of the buffer
  local line_count = vim.api.nvim_buf_line_count(chat_bufnr)
  vim.api.nvim_win_set_cursor(0, { line_count, 0 })
  
  -- Add to chat messages history
  if vim.b.agent_finder_chat_messages then
    table.insert(vim.b.agent_finder_chat_messages, { role = "assistant", content = message })
  end
  
  return {
    success = true,
    data = {
      message = message,
      formatted_message = formatted_message,
      timestamp = os.date("%Y-%m-%d %H:%M:%S")
    }
  }
end

return M
