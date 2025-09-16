-- Documentation Generator
-- Generates comprehensive documentation for code

local M = {}

M.name = "Documentation Generator"
M.description = "Generates comprehensive documentation for code"
M.prompt = [[You are a technical documentation expert. Generate clear, comprehensive documentation for the provided code including:
1. Function/class descriptions
2. Parameter documentation
3. Usage examples
4. Return value descriptions

Use appropriate documentation format for the language.]]

return M
