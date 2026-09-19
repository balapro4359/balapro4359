"""The swap seam: the only contract the rest of the system has with an agent engine.

Every type here is a plain dataclass with no framework dependency. An engine
implementation translates these into its native shapes and back. Nothing else
in the codebase may depend on an engine's native types.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from typing import Any, Literal

Role = Literal["user", "assistant", "system"]


@dataclass(frozen=True)
class ToolSpec:
    """Engine-agnostic tool description. ``json_schema`` is a JSON Schema object."""

    name: str
    description: str
    json_schema: dict[str, Any]
    requires_approval: bool  # True for any send/write/spend action


@dataclass(frozen=True)
class Message:
    role: Role
    content: str


@dataclass(frozen=True)
class ToolCall:
    id: str
    name: str
    arguments: dict[str, Any]


@dataclass(frozen=True)
class ToolResult:
    tool_call_id: str
    content: str
    is_error: bool = False


@dataclass(frozen=True)
class TokenUsage:
    input_tokens: int = 0
    output_tokens: int = 0
    cache_read_tokens: int = 0
    cache_write_tokens: int = 0
    model: str | None = None
    reported_cost_usd: float | None = None  # engine-reported cost, if any

    @property
    def total_tokens(self) -> int:
        return self.input_tokens + self.output_tokens + self.cache_read_tokens + self.cache_write_tokens


@dataclass
class AgentRunResult:
    final_text: str
    tool_calls_made: list[ToolCall] = field(default_factory=list)
    tokens_used: TokenUsage = field(default_factory=TokenUsage)
    stop_reason: str | None = None
    is_error: bool = False
    engine: str | None = None


ToolCallHandler = Callable[[ToolCall], Awaitable[ToolResult]]


class AgentEngine(ABC):
    """Abstract agent loop. Phase 1: ClaudeSDKEngine. Phase 2: LangGraphEngine.

    Contract:
      * ``system_prompt`` is a fully rendered string (skill content already merged).
      * ``tools`` are plain :class:`ToolSpec` objects; the engine wraps them.
      * Every tool invocation the model makes MUST be routed through ``on_tool_call``.
        The engine never executes tools itself and never bypasses the callback,
        because approval gating lives behind that callback.
      * ``conversation`` is the prior transcript; the last message is the new user turn.
    """

    name: str = "abstract"

    @abstractmethod
    async def run(
        self,
        tenant_id: str,
        brand_id: str,
        system_prompt: str,
        tools: list[ToolSpec],
        conversation: list[Message],
        on_tool_call: ToolCallHandler,
    ) -> AgentRunResult: ...
