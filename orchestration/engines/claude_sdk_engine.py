"""Phase 1 AgentEngine backed by the Claude Agent SDK.

This is the ONLY module in the repository allowed to import ``claude_agent_sdk``.
It translates ToolSpec/Message into the SDK's shapes (in-process MCP tools,
ClaudeAgentOptions, query()) and translates SDK messages back into
AgentRunResult. Tool execution is never done here: every call is forwarded to
``on_tool_call`` so approval gating stays engine-agnostic.
"""
from __future__ import annotations

import os
import uuid
from pathlib import Path
from typing import Any

from claude_agent_sdk import (
    AssistantMessage,
    ClaudeAgentOptions,
    PermissionResultAllow,
    PermissionResultDeny,
    ResultMessage,
    SdkMcpTool,
    TextBlock,
    ToolUseBlock,
    create_sdk_mcp_server,
    query,
)

from config.logging import get_logger
from orchestration.interface import (
    AgentEngine,
    AgentRunResult,
    Message,
    TokenUsage,
    ToolCall,
    ToolCallHandler,
    ToolSpec,
)

log = get_logger("engine.claude_sdk")

MCP_SERVER_NAME = "marketing"


def _mcp_name(tool_name: str) -> str:
    return f"mcp__{MCP_SERVER_NAME}__{tool_name}"


class ClaudeSDKEngine(AgentEngine):
    name = "claude_sdk"

    def __init__(self, model: str = "claude-opus-5", api_key: str | None = None, max_turns: int = 12,
                 workdir: str | Path | None = None, effort: str | None = None) -> None:
        self.model = model
        self.api_key = api_key
        self.max_turns = max_turns
        self.workdir = Path(workdir) if workdir else Path.cwd() / "var" / "agent-work"
        self.effort = effort

    # ------------------------------------------------------------ translation
    @staticmethod
    def _split_conversation(conversation: list[Message]) -> tuple[str, str]:
        """Return (prior transcript for the system prompt, prompt = last user turn)."""
        if not conversation or conversation[-1].role != "user":
            raise ValueError("conversation must end with a user message")
        prompt = conversation[-1].content
        prior = conversation[:-1]
        if not prior:
            return "", prompt
        lines = ["## Conversation so far (most recent last)", ""]
        for m in prior:
            if m.role == "system":
                continue
            who = "User" if m.role == "user" else "Assistant"
            lines.append(f"**{who}:** {m.content}")
            lines.append("")
        return "\n".join(lines), prompt

    def _wrap_tools(self, tools: list[ToolSpec], on_tool_call: ToolCallHandler,
                    calls: list[ToolCall]) -> list[SdkMcpTool[Any]]:
        wrapped: list[SdkMcpTool[Any]] = []
        for spec in tools:
            def make_handler(s: ToolSpec):
                async def handler(args: dict[str, Any]) -> dict[str, Any]:
                    call = ToolCall(id=f"tc_{uuid.uuid4().hex[:12]}", name=s.name, arguments=dict(args or {}))
                    calls.append(call)
                    result = await on_tool_call(call)
                    return {"content": [{"type": "text", "text": result.content}], "is_error": bool(result.is_error)}
                return handler
            wrapped.append(SdkMcpTool(name=spec.name, description=spec.description,
                                      input_schema=spec.json_schema, handler=make_handler(spec)))
        return wrapped

    @staticmethod
    def _usage(result: ResultMessage | None, fallback_model: str) -> TokenUsage:
        if result is None:
            return TokenUsage(model=fallback_model)
        u = result.usage or {}
        model = fallback_model
        if result.model_usage:
            model = next(iter(result.model_usage))
        return TokenUsage(
            input_tokens=int(u.get("input_tokens", 0) or 0),
            output_tokens=int(u.get("output_tokens", 0) or 0),
            cache_read_tokens=int(u.get("cache_read_input_tokens", 0) or 0),
            cache_write_tokens=int(u.get("cache_creation_input_tokens", 0) or 0),
            model=model,
            reported_cost_usd=result.total_cost_usd,
        )

    # -------------------------------------------------------------------- run
    async def run(self, tenant_id: str, brand_id: str, system_prompt: str, tools: list[ToolSpec],
                  conversation: list[Message], on_tool_call: ToolCallHandler) -> AgentRunResult:
        transcript, prompt = self._split_conversation(conversation)
        full_system = system_prompt if not transcript else f"{system_prompt}\n\n{transcript}"
        calls: list[ToolCall] = []
        server = create_sdk_mcp_server(name=MCP_SERVER_NAME, version="1.0.0",
                                       tools=self._wrap_tools(tools, on_tool_call, calls))
        allowed = {_mcp_name(t.name) for t in tools}

        async def can_use_tool(tool_name: str, tool_input: dict[str, Any], _ctx: Any):
            # The single allow-list for this run: only the declared tools, and every call is consulted
            # (no ``allowed_tools`` entries, which would auto-approve before this callback runs).
            if tool_name in allowed:
                return PermissionResultAllow()
            log.warning("engine.tool_denied", tenant_id=tenant_id, tool=tool_name)
            return PermissionResultDeny(message=f"Tool {tool_name} is not available in this workspace")

        workdir = self.workdir / tenant_id
        workdir.mkdir(parents=True, exist_ok=True)
        env = {"ANTHROPIC_API_KEY": self.api_key} if self.api_key else {}
        options = ClaudeAgentOptions(
            system_prompt=full_system,
            tools=[],                      # no built-in Claude Code tools (no file/bash/web access)
            mcp_servers={MCP_SERVER_NAME: server},
            strict_mcp_config=True,
            setting_sources=[],            # ignore any local Claude Code settings/plugins
            permission_mode="default",
            can_use_tool=can_use_tool,
            model=self.model,
            max_turns=self.max_turns,
            cwd=str(workdir),
            env=env,
            effort=self.effort,            # type: ignore[arg-type]
        )
        log.info("engine.run.start", tenant_id=tenant_id, brand_id=brand_id, model=self.model,
                 tools=[t.name for t in tools], prompt_chars=len(prompt), system_chars=len(full_system))

        texts: list[str] = []
        result_msg: ResultMessage | None = None
        async for message in query(prompt=prompt, options=options):
            if isinstance(message, AssistantMessage):
                for block in message.content:
                    if isinstance(block, TextBlock):
                        texts.append(block.text)
                    elif isinstance(block, ToolUseBlock):
                        log.debug("engine.tool_use", tenant_id=tenant_id, tool=block.name, id=block.id)
            elif isinstance(message, ResultMessage):
                result_msg = message

        final_text = result_msg.result if (result_msg and result_msg.result) else "\n\n".join(t for t in texts if t.strip())
        usage = self._usage(result_msg, self.model)
        is_error = bool(result_msg.is_error) if result_msg else False
        log.info("engine.run.end", tenant_id=tenant_id, tool_calls=len(calls), is_error=is_error,
                 input_tokens=usage.input_tokens, output_tokens=usage.output_tokens,
                 cache_read_tokens=usage.cache_read_tokens, cache_write_tokens=usage.cache_write_tokens,
                 cost_usd=usage.reported_cost_usd, stop=(result_msg.stop_reason if result_msg else None),
                 num_turns=(result_msg.num_turns if result_msg else None))
        return AgentRunResult(final_text=final_text or "", tool_calls_made=calls, tokens_used=usage,
                              stop_reason=result_msg.stop_reason if result_msg else None, is_error=is_error,
                              engine=self.name)
