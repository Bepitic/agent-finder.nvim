#!/usr/bin/env python3
"""
Agent Finder Python SDK (Protocol v1)

This SDK helps Python-based agents communicate with agent-finder.nvim via
stdin/stdout JSON using a small, versioned protocol.

Input (stdin JSON):
{
  "protocol": { "version": "1.0" },
  "instructions": "...",              # optional system/instructions
  "messages": [                        # chat history for this session
    { "role": "system|user|assistant", "content": "..." },
    ...
  ],
  "tools": {                           # available editor tools (JSON schema)
    "ToolName": {
      "name": "ToolName",
      "description": "...",
      "parameters": { "type": "object", ... }
    }
  },
  "context": {                         # editor context (best-effort)
    "buffer": { "path": "...", "filetype": "..." },
    "editor": { "cwd": "..." }
  },
  "iteration": 1                       # integer, increments across tool calls
}

Output (stdout JSON): exactly ONE of the following top-level objects per turn:
- { "content": "final assistant reply text" }
- { "tool_call": { "name": "ToolName", "arguments": { ... } } }
- { "ask_user": { "message": "question or clarification for user" } }
- { "terminate": { "message": "optional end note" } }
- { "error": { "message": "explanation" } }
"""

from __future__ import annotations

import dataclasses
import json
import sys
from typing import Any, Dict, Iterable, List, Mapping, MutableMapping, Optional


PROTOCOL_VERSION = "1.0"


@dataclasses.dataclass
class Message:
    role: str
    content: str


@dataclasses.dataclass
class BufferContext:
    path: Optional[str] = None
    filetype: Optional[str] = None


@dataclasses.dataclass
class EditorContext:
    cwd: Optional[str] = None


@dataclasses.dataclass
class Context:
    buffer: BufferContext = dataclasses.field(default_factory=BufferContext)
    editor: EditorContext = dataclasses.field(default_factory=EditorContext)


@dataclasses.dataclass
class Request:
    instructions: str
    messages: List[Message]
    tools: Mapping[str, Any]
    context: Context
    iteration: int
    protocol_version: str = PROTOCOL_VERSION

    @staticmethod
    def from_dict(data: Mapping[str, Any]) -> "Request":
        proto = data.get("protocol", {}) or {}
        pv = str(proto.get("version") or PROTOCOL_VERSION)
        msgs = [
            Message(role=str(m.get("role", "user")), content=str(m.get("content", "")))
            for m in (data.get("messages") or [])
        ]
        ctx_raw = data.get("context") or {}
        buf = ctx_raw.get("buffer") or {}
        edt = ctx_raw.get("editor") or {}
        ctx = Context(
            buffer=BufferContext(path=buf.get("path"), filetype=buf.get("filetype")),
            editor=EditorContext(cwd=edt.get("cwd")),
        )
        return Request(
            instructions=str(data.get("instructions") or ""),
            messages=msgs,
            tools=data.get("tools") or {},
            context=ctx,
            iteration=int(data.get("iteration") or 1),
            protocol_version=pv,
        )


def read_request() -> Request:
    raw = sys.stdin.read()
    return Request.from_dict(json.loads(raw or "{}"))


def reply(content: str) -> Dict[str, Any]:
    return {"content": str(content)}


def call_tool(name: str, arguments: Optional[Mapping[str, Any]] = None) -> Dict[str, Any]:
    return {"tool_call": {"name": str(name), "arguments": dict(arguments or {})}}


def ask_user(message: str) -> Dict[str, Any]:
    return {"ask_user": {"message": str(message)}}


def terminate(message: Optional[str] = None) -> Dict[str, Any]:
    out: Dict[str, Any] = {"terminate": {}}
    if message:
        out["terminate"]["message"] = str(message)
    return out


def error(message: str) -> Dict[str, Any]:
    return {"error": {"message": str(message)}}


def emit(obj: Mapping[str, Any]) -> None:
    sys.stdout.write(json.dumps(obj))


