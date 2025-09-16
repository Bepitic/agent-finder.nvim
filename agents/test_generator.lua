-- Test Generator
-- Generates comprehensive test cases for code

local M = {}

M.name = "Test Generator"
M.description = "Generates comprehensive test cases for code"
M.prompt = [[You are a testing expert. Generate comprehensive test cases for the provided code:
1. Unit tests for all functions
2. Edge cases and error conditions
3. Integration tests where appropriate
4. Mock objects if needed

Use appropriate testing framework for the language.]]

return M
