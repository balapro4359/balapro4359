import asyncio

import pytest

from channels.interface import ApprovalChoice, ChannelAdapter, IncomingMessage
from orchestration.approval_gate import ApprovalGate
from orchestration.interface import ToolCall
from tests.conftest import RecordingChannel


async def test_gate_approve_logs_request_and_decision(store, tenant_session):
    t, _, _ = tenant_session
    gate = ApprovalGate(store, timeout_seconds=2)
    ch = RecordingChannel([ApprovalChoice.APPROVE])
    call = ToolCall("tc1", "send_email_campaign", {"recipient_count": 4200})
    ok = await gate.request(t.id, call, ch, "chat-1", summary="Send to 4,200 subscribers", cost_estimate="$2.10")
    assert ok is True
    assert ch.prompts == [("chat-1", "Send to 4,200 subscribers", "$2.10")]
    actions = [e.action for e in store.list_audit(t.id)]
    assert actions == ["approval_requested", "approval_approved"]
    assert store.list_approvals(t.id)[0].status == "approved"


async def test_gate_reject_and_default_summary(store, tenant_session):
    t, _, _ = tenant_session
    gate = ApprovalGate(store, timeout_seconds=2)
    ch = RecordingChannel([ApprovalChoice.REJECT])
    ok = await gate.request(t.id, ToolCall("tc2", "launch_ad_campaign", {"daily_budget": 100}), ch, "chat-1")
    assert ok is False
    assert "launch_ad_campaign" in ch.prompts[0][1]
    assert [e.action for e in store.list_audit(t.id)] == ["approval_requested", "approval_rejected"]


async def test_gate_times_out_to_rejection(store, tenant_session):
    t, _, _ = tenant_session

    class SlowChannel(RecordingChannel):
        async def send_approval_prompt(self, chat_ref, action_summary, cost_estimate):
            await asyncio.sleep(5)
            return ApprovalChoice.APPROVE

    gate = ApprovalGate(store, timeout_seconds=0.05)
    ok = await gate.request(t.id, ToolCall("tc3", "crm_sync_contacts", {}), SlowChannel(), "chat-1")
    assert ok is False
    assert store.list_approvals(t.id)[0].status == "expired"
    assert store.list_audit(t.id)[-1].action == "approval_expired"


async def test_gate_fails_closed_on_channel_error(store, tenant_session):
    t, _, _ = tenant_session

    class BrokenChannel(RecordingChannel):
        async def send_approval_prompt(self, chat_ref, action_summary, cost_estimate):
            raise RuntimeError("network down")

    ok = await ApprovalGate(store, 1).request(t.id, ToolCall("tc4", "send_email_campaign", {}), BrokenChannel(), "c")
    assert ok is False
    assert store.list_approvals(t.id)[0].status == "rejected"
