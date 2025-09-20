#!/usr/bin/env python3
"""
Python Agent Runner (Template) for agent-finder.nvim

Uses the Python SDK (protocol v1) to communicate with the plugin.
You can replace the simple policy below with LangChain/LangGraph logic.
"""

import json
import sys
from typing import Any, Dict

try:
    # Prefer local sdk.py in the same package path
    from sdk import (
        read_request,
        reply,
        call_tool,
        ask_user,
        terminate,
        error,
        Request,
    )
except Exception:  # pragma: no cover - fallback if import path differs
    # Relative import fallback
    from .sdk import (  # type: ignore
        read_request,
        reply,
        call_tool,
        ask_user,
        terminate,
        error,
        Request,
    )


def build_simple_response(req: Request) -> Dict[str, Any]:
    instructions = req.instructions
    messages = req.messages
    iteration = req.iteration

    # Demo: Ask user on first iteration if buffer path is missing
    buf_path = req.context.buffer.path
    if iteration == 1 and not buf_path:
        return ask_user("Which file should I inspect?")

    # Demo: If we can read the current buffer and the tool exists, request it
    if iteration == 1 and "ReadFileLines" in req.tools and buf_path:
        return call_tool(
            "ReadFileLines",
            {"path": buf_path, "start_line": 1, "end_line": 60},
        )

    # Otherwise, reply with a short helpful message
    last_user = next((m for m in reversed(messages) if m.role == "user"), None)
    text = last_user.content if last_user else "How can I help you?"
    if instructions:
        text = f"{instructions}\n\n{text}"
    return reply(text)


def main() -> None:
    try:
        req = read_request()
    except Exception as e:
        sys.stdout.write(json.dumps(error(f"Invalid input JSON: {e}")))
        return

    try:
        out = build_simple_response(req)
    except Exception as e:
        sys.stdout.write(json.dumps(error(f"Runner error: {e}")))
        return

    sys.stdout.write(json.dumps(out))


if __name__ == "__main__":
    main()


