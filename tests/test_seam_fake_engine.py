"""M7 seam check: router, approval gate, orchestrator and the Telegram adapter all run
against a fake AgentEngine with zero changes. Also proves M2 (write tool pauses for approval)."""
import asyncio

from channels.interface import ApprovalChoice
from orchestration.engines.fake_engine import FakeEngine
from orchestration.interface import AgentEngine, Message, ToolSpec
from tests.conftest import RecordingChannel

EMAIL_ARGS = {"connector": "klaviyo", "campaign_name": "Q4 launch", "segment": "trial-users", "recipient_count": 4200,
              "subject": "Welcome aboard", "body_html": "<p>Welcome</p>"}


def test_fake_engine_honours_the_interface():
    assert issubclass(FakeEngine, AgentEngine)


async def test_read_tool_runs_without_approval(orchestrator_factory, store, tenant_session):
    t, b, s = tenant_session
    engine = FakeEngine(responses=["ROI report"], tool_plan=[("roi_calculate", {"channels": [
        {"name": "Google Ads", "spend": 5000, "conversions": 150, "revenue": 22500}]})])
    orch = orchestrator_factory(engine)
    ch = RecordingChannel()
    res = await orch.handle(tenant_id=t.id, session_id=s.id, text="what's the ROI on this campaign", channel=ch, chat_ref="c")
    assert res.skills == ["roi-calculator"]
    assert [c.name for c in res.tool_calls] == ["roi_calculate"]
    assert ch.prompts == [], "read-only tools must not prompt for approval"
    assert "ROI report" in res.final_text and "roas" in res.final_text
    assert res.cost_usd >= 0 and store.usage_summary(t.id)["runs"] == 1
    actions = [e.action for e in store.list_audit(t.id)]
    assert "tool_executed" in actions and "agent_run" in actions
    # skill content reached the engine as a plain string, tools as plain specs
    run = engine.runs[0]
    assert "# Skill: roi-calculator" in run["system_prompt"] and "Brand context: Acme" in run["system_prompt"]
    assert run["tools"] == ["budget_optimize", "clv_calculate", "roi_calculate"]


async def test_write_tool_pauses_for_approval_and_executes_when_approved(orchestrator_factory, store, tenant_session):
    t, b, s = tenant_session
    engine = FakeEngine(responses=["Sequence sent"], tool_plan=[("send_email_campaign", EMAIL_ARGS)])
    orch = orchestrator_factory(engine)
    ch = RecordingChannel([ApprovalChoice.APPROVE])
    res = await orch.handle(tenant_id=t.id, session_id=s.id, text="build a welcome sequence and send it", channel=ch, chat_ref="c")
    assert res.skills == ["email-sequence"]
    assert len(ch.prompts) == 1
    chat_ref, summary, cost = ch.prompts[0]
    assert chat_ref == "c" and "4,200 subscribers" in summary and cost == "$2.10"
    assert "mock_executed" in res.final_text
    actions = [e.action for e in store.list_audit(t.id)]
    assert actions[:3] == ["approval_requested", "approval_approved", "tool_executed"]


async def test_write_tool_is_not_executed_when_rejected(orchestrator_factory, store, tenant_session):
    t, b, s = tenant_session
    engine = FakeEngine(responses=["ok"], tool_plan=[("send_email_campaign", EMAIL_ARGS)])
    orch = orchestrator_factory(engine)
    ch = RecordingChannel([ApprovalChoice.REJECT])
    res = await orch.handle(tenant_id=t.id, session_id=s.id, text="send the welcome sequence", channel=ch, chat_ref="c")
    assert "REJECTED" in res.final_text and "mock_executed" not in res.final_text
    actions = [e.action for e in store.list_audit(t.id)]
    assert "tool_rejected" in actions and "tool_executed" not in actions


async def test_engine_cannot_call_tools_outside_the_selected_skills(orchestrator_factory, tenant_session):
    t, b, s = tenant_session
    engine = FakeEngine(responses=["x"], tool_plan=[("send_email_campaign", EMAIL_ARGS)])
    orch = orchestrator_factory(engine)
    ch = RecordingChannel([ApprovalChoice.APPROVE])
    await orch.handle(tenant_id=t.id, session_id=s.id, text="what's the ROI on this campaign", channel=ch, chat_ref="c")
    assert ch.prompts == [] and engine.runs[0]["tools"] == ["budget_optimize", "clv_calculate", "roi_calculate"]


async def test_conversation_history_is_passed_to_engine(orchestrator_factory, tenant_session):
    t, b, s = tenant_session
    engine = FakeEngine(responses=["first", "second"])
    orch = orchestrator_factory(engine)
    ch = RecordingChannel()
    await orch.handle(tenant_id=t.id, session_id=s.id, text="/seo-audit acme.com", channel=ch, chat_ref="c")
    await orch.handle(tenant_id=t.id, session_id=s.id, text="/seo-audit now the pricing page", channel=ch, chat_ref="c")
    conv = engine.runs[1]["conversation"]
    assert [m.role for m in conv] == ["user", "assistant", "user"]
    assert conv[1] == Message("assistant", "first")


async def test_tenant_isolation_in_orchestrator(orchestrator_factory, store, tenant_session):
    t, b, s = tenant_session
    other = store.create_tenant("Other")
    orch = orchestrator_factory(FakeEngine())
    try:
        await orch.handle(tenant_id=other.id, session_id=s.id, text="hi", channel=RecordingChannel(), chat_ref="c")
    except PermissionError:
        pass
    else:
        raise AssertionError("a session must not be usable from another tenant")


async def test_unmatched_request_gets_general_prompt(orchestrator_factory, tenant_session):
    t, b, s = tenant_session
    engine = FakeEngine()
    orch = orchestrator_factory(engine)
    res = await orch.handle(tenant_id=t.id, session_id=s.id, text="translate this campaign into German",
                            channel=RecordingChannel(), chat_ref="c")
    assert res.skills == [] and engine.runs[0]["tools"] == []
    assert "translate-content" in engine.runs[0]["system_prompt"]
