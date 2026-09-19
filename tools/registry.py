"""Tool registry: plain functions + JSON schema, wrapped into ToolSpecs for any engine."""
from __future__ import annotations

import asyncio
import inspect
import json
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from typing import Any

from orchestration.interface import ToolSpec


@dataclass
class ToolContext:
    """What a tool handler may know about the caller. Never the engine."""

    tenant_id: str
    brand_id: str | None
    store: Any = None   # data.store.Store (duck-typed to keep tools import-light)
    vault: Any = None   # connectors.vault.CredentialVault


Handler = Callable[[ToolContext, dict[str, Any]], Any | Awaitable[Any]]


@dataclass
class ToolDef:
    spec: ToolSpec
    handler: Handler
    summarize: Callable[[dict[str, Any]], str] | None = None
    estimate_cost: Callable[[dict[str, Any]], str] | None = None

    async def invoke(self, ctx: ToolContext, args: dict[str, Any]) -> str:
        """Run the handler (sync handlers run in a worker thread) and return JSON text."""
        if asyncio.iscoroutinefunction(self.handler):
            result = await self.handler(ctx, args)
        else:
            result = await asyncio.to_thread(self.handler, ctx, args)
            if inspect.isawaitable(result):
                result = await result
        if isinstance(result, str):
            return result
        return json.dumps(result, indent=1, ensure_ascii=False, default=str)


@dataclass
class ToolRegistry:
    _tools: dict[str, ToolDef] = field(default_factory=dict)

    def register(self, tool: ToolDef) -> ToolDef:
        if tool.spec.name in self._tools:
            raise ValueError(f"tool {tool.spec.name!r} already registered")
        self._tools[tool.spec.name] = tool
        return tool

    def get(self, name: str) -> ToolDef:
        return self._tools[name]

    def has(self, name: str) -> bool:
        return name in self._tools

    def names(self) -> list[str]:
        return sorted(self._tools)

    def specs(self, names: list[str] | None = None) -> list[ToolSpec]:
        if names is None:
            return [t.spec for t in self._tools.values()]
        missing = [n for n in names if n not in self._tools]
        if missing:
            raise KeyError(f"unknown tools requested: {missing}")
        return [self._tools[n].spec for n in names]


def tool(name: str, description: str, json_schema: dict[str, Any], *, requires_approval: bool = False,
         summarize: Callable[[dict], str] | None = None, estimate_cost: Callable[[dict], str] | None = None):
    """Decorator producing a ToolDef from a plain function ``fn(ctx, args)``.

    This is our own decorator, not an SDK one: the result is a dataclass any
    engine adapter can consume.
    """
    schema = dict(json_schema)
    schema.setdefault("type", "object")
    schema.setdefault("additionalProperties", False)

    def deco(fn: Handler) -> ToolDef:
        return ToolDef(
            spec=ToolSpec(name=name, description=description, json_schema=schema, requires_approval=requires_approval),
            handler=fn, summarize=summarize, estimate_cost=estimate_cost,
        )

    return deco


def default_registry() -> ToolRegistry:
    """Registry with every built-in tool. Import here to avoid circular imports."""
    from tools import ab_testing, connector_executor, email_tools, roi_calculator, seo_scorer, utm_generator

    reg = ToolRegistry()
    for module in (roi_calculator, seo_scorer, email_tools, ab_testing, utm_generator, connector_executor):
        for t in module.TOOLS:
            reg.register(t)
    return reg
