"""Telegram ChannelAdapter (python-telegram-bot, async).

Responsibilities: deserialize updates, map chats to tenants (session_map),
onboarding commands, per-tenant rate limiting, ack + async skill run, chunked
or document replies, and inline-keyboard approval prompts whose callbacks
resolve the pending ApprovalGate future.
"""
from __future__ import annotations

import asyncio
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.constants import ParseMode
from telegram.ext import Application, CallbackQueryHandler, CommandHandler, ContextTypes, MessageHandler, filters

from channels.interface import ApprovalChoice, ChannelAdapter, IncomingMessage
from channels.rate_limit import TenantRateLimiter
from channels.telegram.formatting import decide_delivery, split_message
from channels.telegram.session_map import SessionMap
from config.logging import get_logger
from orchestration.orchestrator import Orchestrator

log = get_logger("channel.telegram")

HELP_TEXT = (
    "I'm your marketing operator. Describe what you need, for example:\n"
    "• audit my site's SEO for acme.com\n"
    "• plan a campaign for our product launch\n"
    "• write a welcome email sequence\n"
    "• what's the ROI on this campaign (paste the numbers)\n\n"
    "Commands: /brand — show or switch brand · /newbrand <name> · /skills · /usage · /help"
)

ONBOARD_TEXT = (
    "Welcome! This chat isn't linked to a workspace yet.\n"
    "• /new <workspace name> — create a new workspace\n"
    "• /link <code> — link to an existing workspace using a one-time code"
)


@dataclass
class _PendingApproval:
    future: asyncio.Future
    chat_ref: str
    summary: str
    cost_estimate: str
    message_id: int | None = None
    previews: int = 0


@dataclass
class TelegramAdapter(ChannelAdapter):
    """Wraps a python-telegram-bot ``Bot``-like client (duck-typed so tests can inject a fake)."""

    bot: Any
    session_map: SessionMap
    orchestrator: Orchestrator
    rate_limiter: TenantRateLimiter = field(default_factory=TenantRateLimiter)
    doc_dir: Path | None = None
    name: str = "telegram"
    _pending: dict[str, _PendingApproval] = field(default_factory=dict)
    _tasks: set[asyncio.Task] = field(default_factory=set)

    # ---------------------------------------------------------- ChannelAdapter
    async def receive(self, raw_payload: dict) -> IncomingMessage:
        update = Update.de_json(raw_payload, self.bot if hasattr(self.bot, "request") else None)
        if update.callback_query is not None:
            cq = update.callback_query
            return IncomingMessage(chat_ref=str(cq.message.chat.id) if cq.message else "", text=cq.data or "",
                                   kind="callback", user_ref=str(cq.from_user.id), raw=raw_payload)
        msg = update.effective_message
        if msg is None:
            raise ValueError("unsupported update type")
        text = msg.text or msg.caption or ""
        kind = "command" if text.startswith("/") else "text"
        return IncomingMessage(chat_ref=str(msg.chat.id), text=text, kind=kind,
                               user_ref=str(msg.from_user.id) if msg.from_user else None, raw=raw_payload)

    async def send_text(self, chat_ref: str, text: str) -> None:
        for chunk in split_message(text):
            await self.bot.send_message(chat_id=chat_ref, text=chunk)

    async def send_document(self, chat_ref: str, file_path: str, caption: str) -> None:
        with open(file_path, "rb") as fh:
            await self.bot.send_document(chat_id=chat_ref, document=fh, caption=caption[:1000],
                                         filename=Path(file_path).name)

    async def send_approval_prompt(self, chat_ref: str, action_summary: str, cost_estimate: str) -> ApprovalChoice:
        approval_id = uuid.uuid4().hex[:10]
        loop = asyncio.get_running_loop()
        pending = _PendingApproval(future=loop.create_future(), chat_ref=chat_ref, summary=action_summary,
                                   cost_estimate=cost_estimate)
        self._pending[approval_id] = pending
        text = f"⚠️ Approval needed\n\n{action_summary}\n\nEstimated cost: {cost_estimate}"
        msg = await self.bot.send_message(chat_id=chat_ref, text=text[:TELEGRAM_TEXT_LIMIT],
                                          reply_markup=self._keyboard(approval_id))
        pending.message_id = getattr(msg, "message_id", None)
        try:
            return await pending.future
        finally:
            self._pending.pop(approval_id, None)

    @staticmethod
    def _keyboard(approval_id: str) -> InlineKeyboardMarkup:
        return InlineKeyboardMarkup([[
            InlineKeyboardButton("✅ Approve", callback_data=f"apr:{approval_id}:approve"),
            InlineKeyboardButton("❌ Reject", callback_data=f"apr:{approval_id}:reject"),
            InlineKeyboardButton("👁 Preview", callback_data=f"apr:{approval_id}:preview"),
        ]])

    # ------------------------------------------------------------ dispatching
    async def handle_incoming(self, incoming: IncomingMessage) -> None:
        """Single entry point used by both polling handlers and the webhook receiver."""
        if incoming.kind == "callback":
            await self._handle_callback(incoming)
            return
        if incoming.kind == "command":
            await self._handle_command(incoming)
            return
        await self._handle_text(incoming)

    async def _handle_callback(self, incoming: IncomingMessage) -> None:
        parts = incoming.text.split(":")
        if len(parts) != 3 or parts[0] != "apr":
            return
        _, approval_id, choice = parts
        pending = self._pending.get(approval_id)
        if pending is None or pending.chat_ref != incoming.chat_ref:
            await self.bot.send_message(chat_id=incoming.chat_ref, text="That approval is no longer pending.")
            return
        if choice == "preview":
            pending.previews += 1
            await self.bot.send_message(chat_id=incoming.chat_ref,
                                        text=f"Preview\n\n{pending.summary}\n\nEstimated cost: {pending.cost_estimate}",
                                        reply_markup=self._keyboard(approval_id))
            return
        if pending.future.done():
            return
        decision = ApprovalChoice.APPROVE if choice == "approve" else ApprovalChoice.REJECT
        pending.future.set_result(decision)
        if pending.message_id is not None and hasattr(self.bot, "edit_message_reply_markup"):
            try:
                await self.bot.edit_message_reply_markup(chat_id=incoming.chat_ref, message_id=pending.message_id,
                                                         reply_markup=None)
            except Exception:  # cosmetic only
                pass
        await self.bot.send_message(chat_id=incoming.chat_ref,
                                    text="✅ Approved — executing." if decision is ApprovalChoice.APPROVE else "❌ Rejected — nothing was sent.")
        log.info("telegram.approval", chat_ref=incoming.chat_ref, approval_id=approval_id, decision=decision.value,
                 user_ref=incoming.user_ref)

    async def _handle_command(self, incoming: IncomingMessage) -> None:
        cmd, _, arg = incoming.text.partition(" ")
        cmd = cmd.split("@", 1)[0].lower()
        arg = arg.strip()
        chat = incoming.chat_ref
        resolved = self.session_map.resolve(chat)

        if cmd in ("/start", "/help"):
            await self.send_text(chat, HELP_TEXT if resolved else ONBOARD_TEXT)
            return
        if cmd == "/new":
            if not arg:
                await self.send_text(chat, "Usage: /new <workspace name>")
                return
            try:
                r = self.session_map.create_tenant_for_chat(chat, arg)
            except ValueError as exc:
                await self.send_text(chat, str(exc))
                return
            log.info("telegram.onboard.new", chat_ref=chat, tenant_id=r.tenant.id)
            await self.send_text(chat, f"Workspace '{r.tenant.name}' created with brand '{r.brand.name}'.\n\n{HELP_TEXT}")
            return
        if cmd == "/link":
            try:
                r = self.session_map.link_chat_with_code(chat, arg)
            except ValueError as exc:
                await self.send_text(chat, str(exc))
                return
            if r is None:
                await self.send_text(chat, "That code is invalid or expired.")
                return
            log.info("telegram.onboard.link", chat_ref=chat, tenant_id=r.tenant.id)
            await self.send_text(chat, f"Linked to workspace '{r.tenant.name}'"
                                       f"{' (brand: ' + r.brand.name + ')' if r.brand else ''}.\n\n{HELP_TEXT}")
            return
        if resolved is None:
            await self.send_text(chat, ONBOARD_TEXT)
            return
        if cmd == "/brand":
            if arg:
                b = self.session_map.switch_brand(chat, arg)
                await self.send_text(chat, f"Switched to brand '{b.name}'." if b else f"No brand named '{arg}'. Use /newbrand <name>.")
            else:
                brands = self.orchestrator.store.list_brands(resolved.tenant.id)
                active = resolved.brand.name if resolved.brand else "none"
                await self.send_text(chat, f"Active brand: {active}\nBrands: " + ", ".join(b.name for b in brands)
                                     + "\nSwitch with /brand <name>.")
            return
        if cmd == "/newbrand":
            if not arg:
                await self.send_text(chat, "Usage: /newbrand <name>")
                return
            b = self.session_map.create_brand(chat, arg)
            await self.send_text(chat, f"Brand '{b.name}' created and set active." if b else "Could not create brand.")
            return
        if cmd == "/skills":
            names = sorted(m.name for m in self.orchestrator.catalog.ported())
            await self.send_text(chat, "Available skills:\n" + "\n".join(f"• /{n}" for n in names))
            return
        if cmd == "/usage":
            u = self.orchestrator.store.usage_summary(resolved.tenant.id)
            await self.send_text(chat, f"Runs: {u['runs']}\nTokens in/out: {u['input_tokens']}/{u['output_tokens']}\nCost: ${u['cost_usd']}")
            return
        # "/seo-audit acme.com" style: explicit skill invocation
        skill = cmd[1:]
        if skill in self.orchestrator.catalog.metas and self.orchestrator.catalog.metas[skill].ported:
            await self._run(incoming, resolved, arg or incoming.text, skill_override=skill)
            return
        await self.send_text(chat, f"Unknown command {cmd}. {HELP_TEXT}")

    async def _handle_text(self, incoming: IncomingMessage) -> None:
        resolved = self.session_map.resolve(incoming.chat_ref)
        if resolved is None:
            await self.send_text(incoming.chat_ref, ONBOARD_TEXT)
            return
        await self._run(incoming, resolved, incoming.text)

    async def _run(self, incoming: IncomingMessage, resolved, text: str, skill_override: str | None = None) -> None:
        tenant_id = resolved.tenant.id
        if not self.rate_limiter.allow(tenant_id):
            wait = self.rate_limiter.retry_after_seconds(tenant_id)
            log.warning("telegram.rate_limited", tenant_id=tenant_id, chat_ref=incoming.chat_ref)
            await self.send_text(incoming.chat_ref, f"Rate limit reached for this workspace. Try again in ~{wait:.0f}s.")
            return
        try:
            skills = self.orchestrator.plan(text, skill_override)
        except KeyError as exc:
            await self.send_text(incoming.chat_ref, str(exc))
            return
        target = resolved.brand.name if resolved.brand else "your workspace"
        ack = f"Running {', '.join(skills)} for {target}…" if skills else "Working on it…"
        await self.send_text(incoming.chat_ref, ack)

        task = asyncio.create_task(self._run_and_reply(incoming, resolved, text, skill_override))
        self._tasks.add(task)
        task.add_done_callback(self._tasks.discard)

    async def _run_and_reply(self, incoming: IncomingMessage, resolved, text: str, skill_override: str | None) -> None:
        chat = incoming.chat_ref
        try:
            result = await self.orchestrator.handle(tenant_id=resolved.tenant.id, session_id=resolved.session.id,
                                                    text=text, channel=self, chat_ref=chat, skill_override=skill_override)
        except Exception as exc:
            log.error("telegram.run_failed", chat_ref=chat, error=str(exc), exc_info=True)
            await self.send_text(chat, "Sorry — that run failed. The error has been logged.")
            return
        body = result.final_text or "(no response)"
        delivery = decide_delivery(body, out_dir=self.doc_dir, fallback_name=(result.skills[0] if result.skills else "report"))
        if delivery.mode == "document" and delivery.file_path:
            await self.send_document(chat, delivery.file_path, delivery.caption or "Report attached")
        else:
            for chunk in delivery.chunks:
                await self.bot.send_message(chat_id=chat, text=chunk)

    async def wait_for_tasks(self) -> None:
        if self._tasks:
            await asyncio.gather(*list(self._tasks), return_exceptions=True)


TELEGRAM_TEXT_LIMIT = 4096


# ------------------------------------------------------------------ wiring
def build_application(token: str, adapter_factory) -> Application:
    """Create a python-telegram-bot Application (polling or webhook) bound to a TelegramAdapter.

    ``adapter_factory(bot)`` returns the TelegramAdapter once the Bot exists.
    """
    app = Application.builder().token(token).build()
    adapter: TelegramAdapter = adapter_factory(app.bot)
    app.bot_data["adapter"] = adapter

    async def on_update(update: Update, _ctx: ContextTypes.DEFAULT_TYPE) -> None:
        if update.callback_query is not None:
            try:
                await update.callback_query.answer()
            except Exception:
                pass
        incoming = await adapter.receive(update.to_dict())
        await adapter.handle_incoming(incoming)

    app.add_handler(CallbackQueryHandler(on_update))
    app.add_handler(CommandHandler(None, on_update))  # any command
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_update))
    return app
