"""Unit tests for the Claude SDK engine's translation layer (no network, no CLI)."""
import asyncio

from orchestration.engines.claude_sdk_engine import ClaudeSDKEngine, _mcp_name
from orchestration.interface import Message, ToolResult, ToolSpec


def test_split_conversation():
    conv = [Message("user", "hi"), Message("assistant", "hello"), Message("user", "audit acme.com")]
    transcript, prompt = ClaudeSDKEngine._split_conversation(conv)
    assert prompt == "audit acme.com" and "**User:** hi" in transcript and "**Assistant:** hello" in transcript
    assert ClaudeSDKEngine._split_conversation([Message("user", "x")]) == ("", "x")


def test_wrap_tools_forwards_to_on_tool_call():
    engine = ClaudeSDKEngine(model="claude-opus-5")
    spec = ToolSpec("roi_calculate", "d", {"type": "object", "properties": {}}, False)
    seen = []

    async def on_tool_call(call):
        seen.append(call)
        return ToolResult(call.id, "42", is_error=False)

    calls = []
    [sdk_tool] = engine._wrap_tools([spec], on_tool_call, calls)
    assert sdk_tool.name == "roi_calculate" and sdk_tool.input_schema == spec.json_schema
    out = asyncio.run(sdk_tool.handler({"a": 1}))
    assert out == {"content": [{"type": "text", "text": "42"}], "is_error": False}
    assert calls == seen and seen[0].arguments == {"a": 1}
    assert _mcp_name("roi_calculate") == "mcp__marketing__roi_calculate"


def test_usage_translation():
    from claude_agent_sdk import ResultMessage
    rm = ResultMessage(subtype="success", duration_ms=1, duration_api_ms=1, is_error=False, num_turns=1, session_id="s",
                       total_cost_usd=0.0123, usage={"input_tokens": 100, "output_tokens": 20, "cache_read_input_tokens": 5},
                       model_usage={"claude-opus-5": {}})
    u = ClaudeSDKEngine._usage(rm, "fallback")
    assert (u.input_tokens, u.output_tokens, u.cache_read_tokens, u.model, u.reported_cost_usd) == (100, 20, 5, "claude-opus-5", 0.0123)
    assert ClaudeSDKEngine._usage(None, "m").model == "m"


def test_pricing_table():
    from orchestration.interface import TokenUsage
    from orchestration.pricing import compute_cost_usd
    assert compute_cost_usd(TokenUsage(1_000_000, 1_000_000, model="claude-sonnet-5")) == 12.0
    assert compute_cost_usd(TokenUsage(1_000_000, 0, model="claude-opus-5")) == 5.0
    assert compute_cost_usd(TokenUsage(10, 10, reported_cost_usd=0.5)) == 0.5
