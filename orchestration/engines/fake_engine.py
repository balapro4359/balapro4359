"""Deterministic AgentEngine for tests and offline development.

It exercises the same contract as a real engine: it calls ``on_tool_call`` for a
scripted plan of tool invocations and returns canned text. If this engine works
end-to-end, the surrounding system has no engine-specific assumptions.
"""
from __future__ import annotations

import uuid
from typing import Any

from orchestration.interface import (
    AgentEngine,
    AgentRunResult,
    Message,
    TokenUsage,
    ToolCall,
    ToolCallHandler,
    ToolSpec,
)


class FakeEngine(AgentEngine):
    name = "fake"

    def __init__(self, responses: list[str] | None = None,
                 tool_plan: list[tuple[str, dict[str, Any]]] | None = None) -> None:
        self.responses = list(responses or [])
        self.tool_plan = list(tool_plan or [])
        self.runs: list[dict[str, Any]] = []

    async def run(self, tenant_id: str, brand_id: str, system_prompt: str, tools: list[ToolSpec],
                  conversation: list[Message], on_tool_call: ToolCallHandler) -> AgentRunResult:
        available = {t.name for t in tools}
        calls: list[ToolCall] = []
        results: list[str] = []
        for name, args in self.tool_plan:
            if name not in available:
                results.append(f"[skipped {name}: not offered to this run]")
                continue
            call = ToolCall(id=f"fake_{uuid.uuid4().hex[:8]}", name=name, arguments=dict(args))
            calls.append(call)
            res = await on_tool_call(call)
            results.append(f"[{name} -> {'error' if res.is_error else 'ok'}] {res.content[:800]}")
        canned = self.responses.pop(0) if self.responses else f"(fake engine) {conversation[-1].content}"
        text = canned if not results else canned + "\n\n" + "\n".join(results)
        usage = TokenUsage(input_tokens=len(system_prompt) // 4 + len(conversation[-1].content) // 4,
                           output_tokens=len(text) // 4, model="fake-model")
        self.runs.append({"tenant_id": tenant_id, "brand_id": brand_id, "system_prompt": system_prompt,
                          "tools": sorted(available), "conversation": conversation})
        return AgentRunResult(final_text=text, tool_calls_made=calls, tokens_used=usage, stop_reason="end_turn",
                              engine=self.name)
