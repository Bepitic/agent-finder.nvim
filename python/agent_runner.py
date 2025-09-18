#!/usr/bin/env python3
"""
Python Agent Runner (Template) for agent-finder.nvim

Protocol (stdin -> stdout JSON):
Input JSON:
{
  "instructions": "string",
  "messages": [{"role": "system|user|assistant", "content": "..."}],
  "tools": { "ToolName": { "name": "ToolName", "description": "...", "parameters": {...} } },
  "iteration": 1
}

Output JSON: either
{ "content": "final assistant reply text" }
or
{ "tool_call": { "name": "ReadFileLines", "arguments": { ... } } }

You can replace the simple echo logic below with LangChain/LangGraph logic.
"""

import json
import sys
from typing import Any, Dict


def read_stdin_json() -> Dict[str, Any]:
    data = sys.stdin.read()
    return json.loads(data or "{}")


def build_simple_response(payload: Dict[str, Any]) -> Dict[str, Any]:
    instructions = payload.get("instructions") or ""
    messages = payload.get("messages") or []
    iteration = payload.get("iteration") or 1

    # Very simple demo policy:
    # - On first iteration, if tools exist, demonstrate a tool call for reading the current file header.
    # - Otherwise, echo a helpful message.
    tools = payload.get("tools") or {}
    if iteration == 1 and "ReadFileLines" in tools:
        # Try to read the current buffer file if provided in messages; this is only a template.
        # Replace with your own logic to decide paths/arguments.
        return {
            "tool_call": {
                "name": "ReadFileLines",
                "arguments": {
                    "path": "/etc/hosts",  # replace with a meaningful path from context
                    "start_line": 1,
                    "end_line": 20,
                },
            }
        }

    # Otherwise, reply normally by echoing last user message
    last_user = next((m for m in reversed(messages) if m.get("role") == "user"), None)
    text = last_user.get("content") if last_user else "How can I help you?"
    if instructions:
        text = f"{instructions}\n\n{text}"
    return {"content": text}


def main() -> None:
    try:
        payload = read_stdin_json()
    except Exception as e:
        sys.stdout.write(json.dumps({"error": f"Invalid input JSON: {e}"}))
        return

    try:
        out = build_simple_response(payload)
    except Exception as e:
        sys.stdout.write(json.dumps({"error": f"Runner error: {e}"}))
        return

    sys.stdout.write(json.dumps(out))


if __name__ == "__main__":
    main()


