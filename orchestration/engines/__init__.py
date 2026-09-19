"""Engine implementations of :class:`orchestration.interface.AgentEngine`.

Only modules in this package may import ``claude_agent_sdk`` or ``langgraph``.
"""
from __future__ import annotations

from orchestration.interface import AgentEngine


def build_engine(name: str, **kwargs) -> AgentEngine:
    """Factory used by the CLI and the Telegram bot. Keeps engine selection in one place."""
    if name == "claude_sdk":
        from orchestration.engines.claude_sdk_engine import ClaudeSDKEngine

        return ClaudeSDKEngine(**kwargs)
    if name == "claude_api":
        from orchestration.engines.claude_api_engine import ClaudeAPIEngine

        return ClaudeAPIEngine(**kwargs)
    if name == "fake":
        from orchestration.engines.fake_engine import FakeEngine

        return FakeEngine(**{k: v for k, v in kwargs.items() if k in ("responses", "tool_plan")})
    if name == "langgraph":
        from orchestration.engines.langgraph_engine import LangGraphEngine

        return LangGraphEngine(**kwargs)
    raise ValueError(f"Unknown engine {name!r}; expected claude_api, claude_sdk, fake or langgraph")
