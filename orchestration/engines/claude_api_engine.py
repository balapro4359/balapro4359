"""Production AgentEngine on the Claude Messages API (no subprocess).

Only ``orchestration/engines/*`` may import ``anthropic``. This engine runs the
tool loop itself: every ``tool_use`` block is forwarded to ``on_tool_call`` (so
the ApprovalGate stays in the path), results are returned in a single user turn,
and usage is accumulated across iterations. Remote MCP servers (for example the
official Google/Meta/TikTok Ads servers) can be attached per engine instance;
their tools execute server-side and are reported back as tool calls.
"""
from __future__ import annotations

import asyncio
import json
from typing import Any

import anthropic
import jsonschema

from config.logging import get_logger
from orchestration.interface import (
    AgentEngine,
    AgentRunResult,
    Message,
    TokenUsage,
    ToolCall,
    ToolCallHandler,
    ToolResult,
    ToolSpec,
)

log = get_logger("engine.claude_api")

MCP_BETA = "mcp-client-2025-11-20"
MAX_TOOL_RESULT_CHARS = 60_000


class ClaudeAPIEngine(AgentEngine):
    name = "claude_api"

    def __init__(self, model: str = "claude-opus-5", api_key: str | None = None, max_turns: int = 12,
                 max_tokens: int = 16000, effort: str | None = None,
                 mcp_servers: list[dict[str, Any]] | None = None, client: Any = None) -> None:
        self.model = model
        self.max_turns = max_turns
        self.max_tokens = max_tokens
        self.effort = effort
        self.mcp_servers = list(mcp_servers or [])
        self.client = client or anthropic.AsyncAnthropic(api_key=api_key)

    # ------------------------------------------------------------ translation
    @staticmethod
    def _messages(conversation: list[Message]) -> list[dict[str, Any]]:
        if not conversation or conversation[-1].role != "user":
            raise ValueError("conversation must end with a user message")
        out: list[dict[str, Any]] = []
        for m in conversation:
            if m.role == "system" or not m.content.strip():
                continue
            if out and out[-1]["role"] == m.role:
                out[-1]["content"] += "\n\n" + m.content   # API requires alternating roles
            else:
                out.append({"role": m.role, "content": m.content})
        if out[0]["role"] != "user":
            out.insert(0, {"role": "user", "content": "(conversation start)"})
        return out

    @staticmethod
    def _tools(tools: list[ToolSpec]) -> list[dict[str, Any]]:
        return [{"name": t.name, "description": t.description, "input_schema": t.json_schema,
                 "eager_input_streaming": True} for t in tools]

    def _params(self, system_prompt: str, tools: list[ToolSpec], messages: list[dict[str, Any]]) -> dict[str, Any]:
        params: dict[str, Any] = {
            "model": self.model,
            "max_tokens": self.max_tokens,
            "system": [{"type": "text", "text": system_prompt, "cache_control": {"type": "ephemeral"}}],
            "messages": messages,
        }
        api_tools = self._tools(tools)
        if self.mcp_servers:
            params["mcp_servers"] = self.mcp_servers
            params["betas"] = [MCP_BETA]
            api_tools += [{"type": "mcp_toolset", "mcp_server_name": s["name"]} for s in self.mcp_servers]
        if api_tools:
            params["tools"] = api_tools
        if self.effort:
            params["output_config"] = {"effort": self.effort}
        return params

    async def _complete(self, params: dict[str, Any]) -> Any:
        """One model call. Streaming keeps long outputs clear of HTTP timeouts."""
        api = self.client.beta.messages if "betas" in params else self.client.messages
        async with api.stream(**params) as stream:
            return await stream.get_final_message()

    @staticmethod
    def _add_usage(total: TokenUsage, usage: Any, model: str) -> TokenUsage:
        g = lambda k: int(getattr(usage, k, 0) or 0)  # noqa: E731
        return TokenUsage(
            input_tokens=total.input_tokens + g("input_tokens"),
            output_tokens=total.output_tokens + g("output_tokens"),
            cache_read_tokens=total.cache_read_tokens + g("cache_read_input_tokens"),
            cache_write_tokens=total.cache_write_tokens + g("cache_creation_input_tokens"),
            model=model,
        )

    # -------------------------------------------------------------------- run
    async def run(self, tenant_id: str, brand_id: str, system_prompt: str, tools: list[ToolSpec],
                  conversation: list[Message], on_tool_call: ToolCallHandler) -> AgentRunResult:
        messages = self._messages(conversation)
        specs = {t.name: t for t in tools}
        usage = TokenUsage(model=self.model)
        calls: list[ToolCall] = []
        final_text = ""
        stop_reason: str | None = None
        is_error = False
        log.info("engine.run.start", tenant_id=tenant_id, brand_id=brand_id, model=self.model,
                 tools=sorted(specs), mcp=[s.get("name") for s in self.mcp_servers], history=len(messages))

        try:
            for turn in range(self.max_turns):
                response = await self._complete(self._params(system_prompt, tools, messages))
                usage = self._add_usage(usage, getattr(response, "usage", None), getattr(response, "model", self.model))
                stop_reason = response.stop_reason
                texts = [b.text for b in response.content if getattr(b, "type", "") == "text"]
                if texts:
                    final_text = "\n\n".join(t for t in texts if t.strip())
                for b in response.content:
                    if getattr(b, "type", "") == "mcp_tool_use":   # executed server-side; record for audit
                        calls.append(ToolCall(id=b.id, name=f"mcp:{getattr(b, 'server_name', '?')}:{b.name}",
                                              arguments=dict(b.input or {})))
                tool_uses = [b for b in response.content if getattr(b, "type", "") == "tool_use"]

                if stop_reason == "pause_turn":
                    messages.append({"role": "assistant", "content": response.content})
                    continue
                if stop_reason == "refusal":
                    is_error = True
                    final_text = final_text or "The model declined this request."
                    break
                if stop_reason == "max_tokens":
                    final_text = (final_text + "\n\n[response truncated at the token limit]").strip()
                    break
                if not tool_uses:
                    break

                messages.append({"role": "assistant", "content": response.content})
                results = await asyncio.gather(*(self._run_tool(b, specs, on_tool_call, calls) for b in tool_uses))
                messages.append({"role": "user", "content": list(results)})
            else:
                stop_reason = "max_turns"
                final_text = (final_text + "\n\n[stopped: maximum number of tool turns reached]").strip()
        except anthropic.RateLimitError as exc:
            log.warning("engine.rate_limited", tenant_id=tenant_id, error=str(exc))
            return AgentRunResult("The model service is busy; please try again in a minute.", calls, usage,
                                  "rate_limited", True, self.name)
        except anthropic.APIConnectionError as exc:
            log.error("engine.connection_error", tenant_id=tenant_id, error=str(exc))
            return AgentRunResult("Could not reach the model service.", calls, usage, "connection_error", True, self.name)
        except anthropic.APIStatusError as exc:
            log.error("engine.api_error", tenant_id=tenant_id, status=exc.status_code, error=str(exc))
            return AgentRunResult(f"Model service error ({exc.status_code}).", calls, usage, "api_error", True, self.name)

        log.info("engine.run.end", tenant_id=tenant_id, tool_calls=len(calls), stop=stop_reason, is_error=is_error,
                 input_tokens=usage.input_tokens, output_tokens=usage.output_tokens,
                 cache_read_tokens=usage.cache_read_tokens, cache_write_tokens=usage.cache_write_tokens)
        return AgentRunResult(final_text=final_text, tool_calls_made=calls, tokens_used=usage,
                              stop_reason=stop_reason, is_error=is_error, engine=self.name)

    async def _run_tool(self, block: Any, specs: dict[str, ToolSpec], on_tool_call: ToolCallHandler,
                        calls: list[ToolCall]) -> dict[str, Any]:
        args = dict(block.input or {})
        spec = specs.get(block.name)
        if spec is None:
            return {"type": "tool_result", "tool_use_id": block.id, "is_error": True,
                    "content": f"Unknown tool {block.name}"}
        try:
            jsonschema.validate(args, spec.json_schema)   # eager streaming: the client owns validation
        except jsonschema.ValidationError as exc:
            log.warning("engine.tool_input_invalid", tool=block.name, error=exc.message)
            return {"type": "tool_result", "tool_use_id": block.id, "is_error": True,
                    "content": f"Invalid input for {block.name}: {exc.message}"}
        call = ToolCall(id=block.id, name=block.name, arguments=args)
        calls.append(call)
        result: ToolResult = await on_tool_call(call)
        content = result.content if len(result.content) <= MAX_TOOL_RESULT_CHARS else result.content[:MAX_TOOL_RESULT_CHARS] + "\n…[truncated]"
        out: dict[str, Any] = {"type": "tool_result", "tool_use_id": block.id, "content": content}
        if result.is_error:
            out["is_error"] = True
        return out
