-- Python LangGraph/LangChain Agent Template

local M = {}

M.name = "Python LangGraph Template"
M.description = "Template agent that delegates to a Python JSON-IO runner (LangGraph/LangChain)"

-- Set adapter to python and point to your runner script
M.adapter = "python"
M.command = "python3 /absolute/path/to/python/agent_runner.py"

-- Optional: arguments to pass to the runner process
M.args = { }

-- Optional: prompt/instructions sent in payload (your Python runner can use it)
M.prompt = "You are a helpful code assistant running in Python."

-- Optional: tool/response iterations
M.max_iters = 3

return M


