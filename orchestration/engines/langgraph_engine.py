"""Phase 2 placeholder: AgentEngine backed by LangGraph (model-agnostic).

TODO(phase-2): implement ``run`` by building a LangGraph ReAct-style graph whose
tool nodes forward every call to ``on_tool_call`` (never executing tools
directly), translating ToolSpec -> LangChain tool schemas and Message -> the
chat model's message types. Nothing outside this file should change.
"""
from __future__ import annotations

from orchestration.interface import AgentEngine, AgentRunResult, Message, ToolCallHandler, ToolSpec


class LangGraphEngine(AgentEngine):
    name = "langgraph"

    def __init__(self, **_: object) -> None:
        pass

    async def run(self, tenant_id: str, brand_id: str, system_prompt: str, tools: list[ToolSpec],
                  conversation: list[Message], on_tool_call: ToolCallHandler) -> AgentRunResult:
        raise NotImplementedError("LangGraphEngine is a Phase 2 deliverable; use engine=claude_sdk or fake")
