"""ClaudeAPIEngine loop tests with a scripted fake client (no network)."""
from types import SimpleNamespace as NS

import pytest

from orchestration.engines.claude_api_engine import ClaudeAPIEngine
from orchestration.interface import Message, ToolResult, ToolSpec

SPEC = ToolSpec("roi_calculate", "d", {"type": "object", "properties": {"x": {"type": "number"}},
                                       "required": ["x"], "additionalProperties": False}, False)


def text(t):
    return NS(type="text", text=t)


def tool_use(i, name, inp):
    return NS(type="tool_use", id=i, name=name, input=inp)


def resp(content, stop="end_turn", usage=None, model="claude-opus-5"):
    usage = usage or {}
    return NS(content=content, stop_reason=stop, model=model,
              usage=NS(input_tokens=usage.get("in", 10), output_tokens=usage.get("out", 5),
                       cache_read_input_tokens=usage.get("cr", 0), cache_creation_input_tokens=usage.get("cw", 0)))


class ScriptedEngine(ClaudeAPIEngine):
    def __init__(self, responses, **kw):
        super().__init__(client=object(), **kw)
        self.responses = list(responses)
        self.params_seen = []

    async def _complete(self, params):
        self.params_seen.append(params)
        return self.responses.pop(0)


async def echo_tool(call):
    return ToolResult(call.id, f"result for {call.name} {call.arguments}")


async def test_tool_loop_and_usage_accumulate():
    eng = ScriptedEngine([
        resp([text("let me compute"), tool_use("t1", "roi_calculate", {"x": 2})], stop="tool_use", usage={"in": 100, "out": 20, "cw": 50}),
        resp([text("done: 4")], usage={"in": 30, "out": 10, "cr": 50}),
    ])
    res = await eng.run("t", "b", "SYS", [SPEC], [Message("user", "hi")], echo_tool)
    assert res.final_text == "done: 4" and res.stop_reason == "end_turn" and not res.is_error
    assert [c.name for c in res.tool_calls_made] == ["roi_calculate"] and res.tool_calls_made[0].id == "t1"
    u = res.tokens_used
    assert (u.input_tokens, u.output_tokens, u.cache_write_tokens, u.cache_read_tokens) == (130, 30, 50, 50)
    # request shape: cached system prompt, eager-streaming tools, tool results in ONE user turn
    p0, p1 = eng.params_seen
    assert p0["system"][0]["cache_control"] == {"type": "ephemeral"} and p0["system"][0]["text"] == "SYS"
    assert p0["tools"][0]["eager_input_streaming"] is True and p0["tools"][0]["input_schema"] == SPEC.json_schema
    assert p1["messages"][-1]["role"] == "user" and p1["messages"][-1]["content"][0]["type"] == "tool_result"
    assert p1["messages"][-1]["content"][0]["content"].startswith("result for roi_calculate")
    assert "betas" not in p0


async def test_invalid_tool_input_is_rejected_before_handler():
    called = []

    async def handler(call):
        called.append(call)
        return ToolResult(call.id, "ok")

    eng = ScriptedEngine([resp([tool_use("t1", "roi_calculate", {"x": "nope"})], stop="tool_use"), resp([text("ok")])])
    res = await eng.run("t", "b", "SYS", [SPEC], [Message("user", "hi")], handler)
    assert called == [] and res.tool_calls_made == []
    tr = eng.params_seen[1]["messages"][-1]["content"][0]
    assert tr["is_error"] is True and "Invalid input" in tr["content"]


async def test_unknown_tool_and_error_results():
    async def failing(call):
        return ToolResult(call.id, "boom", is_error=True)

    eng = ScriptedEngine([resp([tool_use("a", "nope", {}), tool_use("b", "roi_calculate", {"x": 1})], stop="tool_use"), resp([text("x")])])
    await eng.run("t", "b", "S", [SPEC], [Message("user", "hi")], failing)
    results = eng.params_seen[1]["messages"][-1]["content"]
    assert [r["tool_use_id"] for r in results] == ["a", "b"] and all(r["is_error"] for r in results)


async def test_max_tokens_refusal_and_max_turns():
    eng = ScriptedEngine([resp([text("partial"), tool_use("t", "roi_calculate", {"x": 1})], stop="max_tokens")])
    res = await eng.run("t", "b", "S", [SPEC], [Message("user", "hi")], echo_tool)
    assert "truncated" in res.final_text and res.tool_calls_made == []

    eng = ScriptedEngine([resp([], stop="refusal")])
    res = await eng.run("t", "b", "S", [], [Message("user", "hi")], echo_tool)
    assert res.is_error and res.stop_reason == "refusal"

    eng = ScriptedEngine([resp([tool_use(f"t{i}", "roi_calculate", {"x": i})], stop="tool_use") for i in range(3)], max_turns=2)
    res = await eng.run("t", "b", "S", [SPEC], [Message("user", "hi")], echo_tool)
    assert res.stop_reason == "max_turns" and len(res.tool_calls_made) == 2


async def test_pause_turn_continues():
    eng = ScriptedEngine([resp([text("searching")], stop="pause_turn"), resp([text("final")])])
    res = await eng.run("t", "b", "S", [], [Message("user", "hi")], echo_tool)
    assert res.final_text == "final" and len(eng.params_seen) == 2
    assert eng.params_seen[1]["messages"][-1]["role"] == "assistant"


def test_history_mapping_merges_same_role_and_drops_system():
    conv = [Message("system", "x"), Message("user", "a"), Message("user", "b"), Message("assistant", "c"), Message("user", "d")]
    msgs = ClaudeAPIEngine._messages(conv)
    assert msgs == [{"role": "user", "content": "a\n\nb"}, {"role": "assistant", "content": "c"}, {"role": "user", "content": "d"}]
    with pytest.raises(ValueError):
        ClaudeAPIEngine._messages([Message("assistant", "x")])


def test_mcp_servers_add_toolset_and_beta():
    eng = ScriptedEngine([], mcp_servers=[{"type": "url", "url": "https://mcp.facebook.com/ads", "name": "meta-ads"}])
    p = eng._params("S", [SPEC], [{"role": "user", "content": "hi"}])
    assert p["betas"] == ["mcp-client-2025-11-20"]
    assert {"type": "mcp_toolset", "mcp_server_name": "meta-ads"} in p["tools"] and p["tools"][0]["name"] == "roi_calculate"


async def test_api_errors_fail_soft():
    import anthropic

    class Boom(ClaudeAPIEngine):
        async def _complete(self, params):
            raise anthropic.APIConnectionError(request=None)  # type: ignore[arg-type]

    res = await Boom(client=object()).run("t", "b", "S", [], [Message("user", "hi")], echo_tool)
    assert res.is_error and res.stop_reason == "connection_error"
