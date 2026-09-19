"""Human-in-the-loop gate. Engine- and channel-agnostic.

Every ToolSpec with ``requires_approval=True`` routes through :meth:`ApprovalGate.request`
before the tool handler executes. The gate persists an ApprovalRequest, logs the
request and the decision to the append-only audit log unconditionally, and asks
the active channel to collect the human decision.
"""
from __future__ import annotations

import asyncio
import json
from collections.abc import Callable

from channels.interface import ApprovalChoice, ChannelAdapter
from config.logging import get_logger
from data.models import AuditLogEntry
from data.store import Store
from orchestration.interface import ToolCall

log = get_logger("approval_gate")

Summarizer = Callable[[ToolCall], str]


def default_summary(tool_call: ToolCall) -> str:
    args = json.dumps(tool_call.arguments, default=str, ensure_ascii=False)
    if len(args) > 400:
        args = args[:400] + "…"
    return f"{tool_call.name}({args})"


class ApprovalGate:
    """Never bypassed regardless of engine or channel."""

    def __init__(self, store: Store, timeout_seconds: int = 900) -> None:
        self.store = store
        self.timeout_seconds = timeout_seconds

    async def request(
        self,
        tenant_id: str,
        tool_call: ToolCall,
        channel: ChannelAdapter,
        chat_ref: str,
        *,
        summary: str | None = None,
        cost_estimate: str | None = None,
        actor: str = "user",
    ) -> bool:
        summary = summary or default_summary(tool_call)
        cost_estimate = cost_estimate or "unknown"
        approval = self.store.create_approval(tenant_id, tool_call.name, summary, cost_estimate)
        self.store.append_audit(AuditLogEntry(
            tenant_id=tenant_id, actor="system", action="approval_requested",
            tool_call={"id": tool_call.id, "name": tool_call.name, "arguments": tool_call.arguments,
                       "approval_id": approval.id},
            result_summary=f"{summary} | cost: {cost_estimate}",
        ))
        log.info("approval.requested", tenant_id=tenant_id, approval_id=approval.id, tool=tool_call.name,
                 cost_estimate=cost_estimate, channel=channel.name)

        try:
            choice = await asyncio.wait_for(
                channel.send_approval_prompt(chat_ref, summary, cost_estimate),
                timeout=self.timeout_seconds,
            )
        except asyncio.TimeoutError:
            choice = ApprovalChoice.REJECT
            status = "expired"
        except Exception as exc:  # channel failure must fail closed
            log.error("approval.channel_error", tenant_id=tenant_id, approval_id=approval.id, error=str(exc))
            choice = ApprovalChoice.REJECT
            status = "rejected"
        else:
            status = "approved" if choice is ApprovalChoice.APPROVE else "rejected"

        self.store.decide_approval(approval.id, status, decided_by=f"{channel.name}:{chat_ref}:{actor}")
        self.store.append_audit(AuditLogEntry(
            tenant_id=tenant_id, actor=actor, action=f"approval_{status}",
            tool_call={"id": tool_call.id, "name": tool_call.name, "approval_id": approval.id},
            result_summary=summary,
        ))
        log.info("approval.decided", tenant_id=tenant_id, approval_id=approval.id, tool=tool_call.name, status=status)
        return choice is ApprovalChoice.APPROVE
