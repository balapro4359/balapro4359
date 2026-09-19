"""Composition point: request -> router -> skills -> tools (gated) -> engine -> usage log.

Knows nothing about which engine or channel is active; both arrive as
interfaces. This is the code path every channel adapter calls.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field

from channels.interface import ChannelAdapter
from config.logging import get_logger
from config.settings import Settings
from connectors.vault import CredentialVault
from data.models import AuditLogEntry, UsageRecord
from data.store import Store
from orchestration.approval_gate import ApprovalGate
from orchestration.interface import AgentEngine, Message, TokenUsage, ToolCall, ToolResult, ToolSpec
from orchestration.pricing import compute_cost_usd
from orchestration.router import Router
from skills.loader import Skill, SkillCatalog, render_system_prompt
from tools.registry import ToolContext, ToolRegistry

log = get_logger("orchestrator")

MAX_TOOL_RESULT_CHARS = 20_000


@dataclass
class OrchestratorResult:
    final_text: str
    skills: list[str]
    tool_calls: list[ToolCall] = field(default_factory=list)
    usage: TokenUsage = field(default_factory=TokenUsage)
    cost_usd: float = 0.0
    is_error: bool = False


class Orchestrator:
    def __init__(self, *, engine: AgentEngine, store: Store, catalog: SkillCatalog, registry: ToolRegistry,
                 gate: ApprovalGate, settings: Settings, vault: CredentialVault | None = None,
                 router: Router | None = None) -> None:
        self.engine = engine
        self.store = store
        self.catalog = catalog
        self.registry = registry
        self.gate = gate
        self.settings = settings
        self.vault = vault
        self.router = router or Router(catalog)

    # ----------------------------------------------------------------- plan
    def plan(self, text: str, skill_override: str | None = None) -> list[str]:
        if skill_override:
            if skill_override not in self.catalog.metas or not self.catalog.metas[skill_override].ported:
                raise KeyError(f"skill {skill_override!r} is not available")
            return [skill_override]
        return [m.skill for m in self.router.route(text)]

    def _tools_for(self, skills: list[Skill]) -> list[ToolSpec]:
        names: list[str] = []
        for s in skills:
            for t in s.meta.tools:
                if not self.registry.has(t):
                    log.warning("orchestrator.unknown_tool", skill=s.meta.name, tool=t)
                    continue
                if t not in names:
                    names.append(t)
        return self.registry.specs(names)

    def _general_prompt(self) -> str:
        lines = ["# Available capabilities", "", "No specific skill matched. Help the user pick one of these:"]
        demand = self.router.last_port_demand
        if demand is not None:
            lines.insert(2, f"The closest capability, '{demand.skill}', exists in the catalogue but is not enabled in this "
                            f"workspace yet. Say so plainly, then offer the nearest enabled skill below.")
        for m in self.catalog.ported():
            lines.append(f"- **{m.name}** — {m.description.split('. ')[0]}.")
        lines.append("")
        lines.append("Ask a clarifying question if the request is ambiguous; do not invent data.")
        return "\n".join(lines)

    # --------------------------------------------------------------- handle
    async def handle(self, *, tenant_id: str, session_id: str, text: str, channel: ChannelAdapter, chat_ref: str,
                     skill_override: str | None = None) -> OrchestratorResult:
        tenant = self.store.get_tenant(tenant_id)
        if tenant is None:
            raise KeyError(f"unknown tenant {tenant_id}")
        session = self.store.get_session(session_id)
        if session is None or session.tenant_id != tenant_id:
            raise PermissionError("session does not belong to tenant")
        settings = self.settings.for_tenant(tenant_id, tenant.settings)
        brand = self.store.get_brand(tenant_id, session.active_brand_id) if session.active_brand_id else None
        brand_id = brand.id if brand else ""

        skill_names = self.plan(text, skill_override)
        skills = [self.catalog.get(n) for n in skill_names]
        tools = self._tools_for(skills)
        system_prompt = render_system_prompt(skills, brand, extra=None if skills else self._general_prompt())

        history = [Message(role=r, content=c) for r, c in self.store.recent_messages(tenant_id, session_id)]  # type: ignore[arg-type]
        conversation = history + [Message(role="user", content=text)]
        ctx = ToolContext(tenant_id=tenant_id, brand_id=brand_id or None, store=self.store, vault=self.vault)

        async def on_tool_call(call: ToolCall) -> ToolResult:
            return await self._execute_tool(ctx, call, channel, chat_ref)

        log.info("orchestrator.run", tenant_id=tenant_id, session_id=session_id, skills=skill_names,
                 tools=[t.name for t in tools], engine=self.engine.name)
        try:
            result = await self.engine.run(tenant_id, brand_id, system_prompt, tools, conversation, on_tool_call)
        except Exception as exc:
            log.error("orchestrator.engine_error", tenant_id=tenant_id, error=str(exc), exc_info=True)
            self.store.append_audit(AuditLogEntry(tenant_id=tenant_id, actor="system", action="agent_run_failed",
                                                  tool_call={"skills": skill_names}, result_summary=str(exc)[:500]))
            raise

        cost = compute_cost_usd(result.tokens_used, fallback_model=settings.default_model)
        self.store.record_usage(UsageRecord(
            tenant_id=tenant_id, brand_id=brand_id or None, session_id=session_id, engine=result.engine or self.engine.name,
            model=result.tokens_used.model or settings.default_model, skills=skill_names,
            input_tokens=result.tokens_used.input_tokens, output_tokens=result.tokens_used.output_tokens,
            cache_read_tokens=result.tokens_used.cache_read_tokens, cache_write_tokens=result.tokens_used.cache_write_tokens,
            cost_usd=cost,
        ))
        self.store.append_audit(AuditLogEntry(
            tenant_id=tenant_id, actor="system", action="agent_run",
            tool_call={"skills": skill_names, "engine": result.engine or self.engine.name,
                       "tool_calls": [c.name for c in result.tool_calls_made]},
            result_summary=f"tokens in={result.tokens_used.input_tokens} out={result.tokens_used.output_tokens} cost=${cost}",
        ))
        log.info("orchestrator.usage", tenant_id=tenant_id, model=result.tokens_used.model, cost_usd=cost,
                 input_tokens=result.tokens_used.input_tokens, output_tokens=result.tokens_used.output_tokens)

        self.store.append_message(tenant_id, session_id, "user", text)
        if result.final_text:
            self.store.append_message(tenant_id, session_id, "assistant", result.final_text)
        return OrchestratorResult(final_text=result.final_text, skills=skill_names, tool_calls=result.tool_calls_made,
                                  usage=result.tokens_used, cost_usd=cost, is_error=result.is_error)

    # ---------------------------------------------------------------- tools
    async def _execute_tool(self, ctx: ToolContext, call: ToolCall, channel: ChannelAdapter, chat_ref: str) -> ToolResult:
        if not self.registry.has(call.name):
            return ToolResult(call.id, f"Unknown tool {call.name}", is_error=True)
        tool = self.registry.get(call.name)

        if tool.spec.requires_approval:
            summary = tool.summarize(call.arguments) if tool.summarize else None
            cost = tool.estimate_cost(call.arguments) if tool.estimate_cost else None
            approved = await self.gate.request(ctx.tenant_id, call, channel, chat_ref, summary=summary, cost_estimate=cost)
            if not approved:
                self.store.append_audit(AuditLogEntry(tenant_id=ctx.tenant_id, actor="system", action="tool_rejected",
                                                      tool_call={"id": call.id, "name": call.name, "arguments": call.arguments},
                                                      result_summary="not executed: approval denied"))
                return ToolResult(call.id, "REJECTED: the user did not approve this action. Do not retry it; "
                                           "explain what was not done and offer alternatives.", is_error=True)
        try:
            content = await tool.invoke(ctx, call.arguments)
            if len(content) > MAX_TOOL_RESULT_CHARS:
                content = content[:MAX_TOOL_RESULT_CHARS] + "\n…[truncated]"
            self.store.append_audit(AuditLogEntry(tenant_id=ctx.tenant_id, actor="system", action="tool_executed",
                                                  tool_call={"id": call.id, "name": call.name, "arguments": call.arguments},
                                                  result_summary=content[:300]))
            log.info("tool.executed", tenant_id=ctx.tenant_id, tool=call.name, gated=tool.spec.requires_approval)
            return ToolResult(call.id, content)
        except Exception as exc:
            log.warning("tool.failed", tenant_id=ctx.tenant_id, tool=call.name, error=str(exc))
            self.store.append_audit(AuditLogEntry(tenant_id=ctx.tenant_id, actor="system", action="tool_failed",
                                                  tool_call={"id": call.id, "name": call.name, "arguments": call.arguments},
                                                  result_summary=str(exc)[:300]))
            return ToolResult(call.id, json.dumps({"error": str(exc)}), is_error=True)
