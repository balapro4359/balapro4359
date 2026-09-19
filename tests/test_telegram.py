"""Telegram adapter tests with a fake Bot: onboarding, multi-tenant isolation, chunking,
document fallback, inline-keyboard approvals, rate limiting and webhook verification."""
import asyncio
from dataclasses import dataclass, field

import pytest

from channels.interface import ApprovalChoice
from channels.rate_limit import TenantRateLimiter
from channels.telegram.bot import TelegramAdapter
from channels.telegram.formatting import decide_delivery, split_message
from channels.telegram.session_map import SessionMap
from channels.telegram.webhook import TelegramWebhook
from orchestration.engines.fake_engine import FakeEngine
from tests.conftest import make_orchestrator

EMAIL_ARGS = {"connector": "klaviyo", "campaign_name": "Q4", "segment": "all", "recipient_count": 4200,
              "subject": "Hi", "body_html": "<p>x</p>"}


@dataclass
class FakeMessage:
    message_id: int


@dataclass
class FakeBot:
    sent: list[dict] = field(default_factory=list)
    docs: list[dict] = field(default_factory=list)
    edits: list[dict] = field(default_factory=list)
    _n: int = 0

    async def send_message(self, chat_id, text, reply_markup=None, **kw):
        self._n += 1
        self.sent.append({"chat_id": str(chat_id), "text": text, "markup": reply_markup})
        return FakeMessage(self._n)

    async def send_document(self, chat_id, document, caption=None, filename=None, **kw):
        self.docs.append({"chat_id": str(chat_id), "caption": caption, "filename": filename, "bytes": document.read()})
        return FakeMessage(0)

    async def edit_message_reply_markup(self, chat_id, message_id, reply_markup=None, **kw):
        self.edits.append({"chat_id": str(chat_id), "message_id": message_id})

    async def answer_callback_query(self, callback_query_id, **kw):
        return True


def text_update(chat_id: int, text: str, uid: int = 42) -> dict:
    return {"update_id": 1, "message": {"message_id": 1, "date": 0, "chat": {"id": chat_id, "type": "private"},
                                        "from": {"id": uid, "is_bot": False, "first_name": "U"}, "text": text}}


def callback_update(chat_id: int, data: str, uid: int = 42) -> dict:
    return {"update_id": 2, "callback_query": {"id": "cq1", "chat_instance": "x", "data": data,
                                               "from": {"id": uid, "is_bot": False, "first_name": "U"},
                                               "message": {"message_id": 5, "date": 0, "chat": {"id": chat_id, "type": "private"}}}}


@pytest.fixture
def adapter(store, catalog, settings, tmp_path):
    def _make(engine=None, per_minute=100):
        bot = FakeBot()
        orch = make_orchestrator(engine or FakeEngine(responses=["done"]), store, catalog, settings)
        return bot, TelegramAdapter(bot=bot, session_map=SessionMap(store), orchestrator=orch,
                                    rate_limiter=TenantRateLimiter(per_minute=per_minute), doc_dir=tmp_path)
    return _make


async def push(ad: TelegramAdapter, payload: dict) -> None:
    await ad.handle_incoming(await ad.receive(payload))
    await ad.wait_for_tasks()


# ------------------------------------------------------------------ formatting
def test_split_message_respects_limit():
    text = "\n\n".join(f"paragraph {i} " + "x" * 900 for i in range(10))
    chunks = split_message(text)
    assert all(len(c) <= 4096 for c in chunks) and len(chunks) >= 3
    assert "".join(c.replace("\n", "") for c in chunks).replace(" ", "") == text.replace("\n", "").replace(" ", "")
    assert split_message("") == [] and split_message("short") == ["short"]


def test_decide_delivery_switches_to_document(tmp_path):
    short = decide_delivery("# Title\n\nbody", out_dir=tmp_path)
    assert short.mode == "text" and short.chunks == ["# Title\n\nbody"]
    long = decide_delivery("# SEO Audit Report\n\n" + "x" * 5000, out_dir=tmp_path)
    assert long.mode == "document" and long.file_path.endswith("SEO-Audit-Report.md") and "attached" in long.caption


# ------------------------------------------------------------------ onboarding + multi-tenant (M3, M4)
async def test_onboarding_and_multi_tenant_isolation(adapter, store):
    bot, ad = adapter()
    await push(ad, text_update(111, "hello"))
    assert "isn't linked" in bot.sent[-1]["text"]
    await push(ad, text_update(111, "/new Acme Corp"))
    assert "Workspace 'Acme Corp' created" in bot.sent[-1]["text"]

    # second chat links to a different, pre-existing tenant via one-time code
    t2 = store.create_tenant("Globex")
    store.create_brand(t2.id, "Globex Brand")
    code = store.create_onboarding_code(t2.id)
    await push(ad, text_update(222, f"/link {code}"))
    assert "Linked to workspace 'Globex'" in bot.sent[-1]["text"]
    await push(ad, text_update(333, f"/link {code}"))
    assert "invalid or expired" in bot.sent[-1]["text"]

    r1, r2 = ad.session_map.resolve("111"), ad.session_map.resolve("222")
    assert r1.tenant.id != r2.tenant.id and r1.brand.name == "Acme Corp" and r2.brand.name == "Globex Brand"

    # brands are isolated: chat 111 cannot switch to Globex's brand
    await push(ad, text_update(111, "/brand Globex Brand"))
    assert "No brand named" in bot.sent[-1]["text"]
    await push(ad, text_update(111, "/newbrand Acme Labs"))
    assert store.list_brands(r1.tenant.id)[1].name == "Acme Labs"
    assert [b.name for b in store.list_brands(r2.tenant.id)] == ["Globex Brand"]

    # runs are attributed to the right tenant, and history does not cross chats
    await push(ad, text_update(111, "/seo-audit acme.com"))
    await push(ad, text_update(222, "/seo-audit globex.com"))
    assert store.usage_summary(r1.tenant.id)["runs"] == 1 and store.usage_summary(r2.tenant.id)["runs"] == 1
    assert store.recent_messages(r2.tenant.id, r2.session.id)[0][1] == "globex.com"


async def test_skill_runs_from_message_with_ack_and_reply(adapter):
    bot, ad = adapter(FakeEngine(responses=["Here is your audit."]))
    await push(ad, text_update(1, "/new Acme"))
    await push(ad, text_update(1, "Audit my site's SEO for acme.com"))
    texts = [m["text"] for m in bot.sent if m["chat_id"] == "1"]
    assert any(t.startswith("Running seo-audit for Acme") for t in texts)
    assert texts[-1] == "Here is your audit."


async def test_long_reply_becomes_document(adapter):
    bot, ad = adapter(FakeEngine(responses=["# Big Report\n\n" + "y" * 6000]))
    await push(ad, text_update(1, "/new Acme"))
    await push(ad, text_update(1, "/seo-audit acme.com"))
    assert bot.docs and bot.docs[0]["filename"] == "Big-Report.md" and b"yyyy" in bot.docs[0]["bytes"]


# ------------------------------------------------------------------ approvals via inline keyboard (M5)
async def test_approval_via_inline_keyboard_buttons(adapter, store):
    engine = FakeEngine(responses=["sent"], tool_plan=[("send_email_campaign", EMAIL_ARGS)])
    bot, ad = adapter(engine)
    await push(ad, text_update(7, "/new Acme"))
    incoming = await ad.receive(text_update(7, "build a welcome sequence and send it"))
    await ad.handle_incoming(incoming)  # ack + background run
    await asyncio.sleep(0.05)
    prompt = bot.sent[-1]
    assert "Approval needed" in prompt["text"] and "4,200 subscribers" in prompt["text"] and "$2.10" in prompt["text"]
    buttons = [b.text for row in prompt["markup"].inline_keyboard for b in row]
    assert buttons == ["✅ Approve", "❌ Reject", "👁 Preview"]
    approval_id = prompt["markup"].inline_keyboard[0][0].callback_data.split(":")[1]

    await ad.handle_incoming(await ad.receive(callback_update(7, f"apr:{approval_id}:preview")))
    assert bot.sent[-1]["text"].startswith("Preview") and bot.sent[-1]["markup"] is not None

    # another chat cannot approve this action
    await ad.handle_incoming(await ad.receive(callback_update(8, f"apr:{approval_id}:approve")))
    assert bot.sent[-1]["chat_id"] == "8" and "no longer pending" in bot.sent[-1]["text"]

    await ad.handle_incoming(await ad.receive(callback_update(7, f"apr:{approval_id}:approve")))
    await ad.wait_for_tasks()
    assert bot.edits and any("Approved" in m["text"] for m in bot.sent)
    tenant_id = ad.session_map.resolve("7").tenant.id
    actions = [e.action for e in store.list_audit(tenant_id)]
    assert "approval_approved" in actions and "tool_executed" in actions
    assert "mock_executed" in bot.sent[-1]["text"]


async def test_reject_button_blocks_execution(adapter, store):
    engine = FakeEngine(responses=["x"], tool_plan=[("launch_ad_campaign", {"connector": "meta-ads", "campaign_name": "Q4",
                                                                            "daily_budget": 100, "duration_days": 10})])
    bot, ad = adapter(engine)
    await push(ad, text_update(9, "/new Acme"))
    await ad.handle_incoming(await ad.receive(text_update(9, "write ad copy for Meta and launch it")))
    await asyncio.sleep(0.05)
    prompt = bot.sent[-1]
    assert "$1,000.00 total media spend" in prompt["text"]
    approval_id = prompt["markup"].inline_keyboard[0][1].callback_data.split(":")[1]
    await ad.handle_incoming(await ad.receive(callback_update(9, f"apr:{approval_id}:reject")))
    await ad.wait_for_tasks()
    tenant_id = ad.session_map.resolve("9").tenant.id
    actions = [e.action for e in store.list_audit(tenant_id)]
    assert "approval_rejected" in actions and "tool_executed" not in actions


# ------------------------------------------------------------------ rate limit + webhook
async def test_rate_limit_is_per_tenant(adapter):
    bot, ad = adapter(per_minute=2)
    await push(ad, text_update(1, "/new A"))
    await push(ad, text_update(2, "/new B"))
    for _ in range(2):
        await push(ad, text_update(1, "/seo-audit a.com"))
    await push(ad, text_update(1, "/seo-audit a.com"))
    assert "Rate limit reached" in [m["text"] for m in bot.sent if m["chat_id"] == "1"][-1]
    await push(ad, text_update(2, "/seo-audit b.com"))
    assert "Rate limit" not in [m["text"] for m in bot.sent if m["chat_id"] == "2"][-1]


def test_rate_limiter_refills():
    rl = TenantRateLimiter(per_minute=60)
    assert all(rl.allow("t", now=0.0) for _ in range(60))
    assert not rl.allow("t", now=0.0)
    assert rl.allow("t", now=1.0)


async def test_webhook_verifies_secret_and_dispatches(adapter):
    bot, ad = adapter()
    hook = TelegramWebhook(ad, secret_token="s3cret")
    import json
    body = json.dumps(text_update(5, "/new Acme")).encode()
    assert (await hook.handle({}, body))[0] == 403
    assert (await hook.handle({"X-Telegram-Bot-Api-Secret-Token": "wrong"}, body))[0] == 403
    assert (await hook.handle({"X-Telegram-Bot-Api-Secret-Token": "s3cret"}, b"{not json"))[0] == 400
    status, _ = await hook.handle({"X-Telegram-Bot-Api-Secret-Token": "s3cret"}, body)
    assert status == 200
    await asyncio.sleep(0.05)
    await ad.wait_for_tasks()
    assert any("Workspace 'Acme' created" in m["text"] for m in bot.sent)
