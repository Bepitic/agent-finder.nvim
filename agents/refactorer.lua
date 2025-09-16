-- Code Refactorer
-- Refactors code for better structure and maintainability

local M = {}

M.name = "Code Refactorer"
M.description = "Refactors code for better structure and maintainability"
M.prompt = [[You are a code refactoring expert. Analyze the code and suggest refactoring improvements:
1. Extract functions/methods
2. Improve variable names
3. Reduce complexity
4. Apply design patterns where appropriate

Provide the refactored code with explanations.]]

return M
