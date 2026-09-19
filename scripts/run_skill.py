#!/usr/bin/env python3
"""M1 acceptance: run one skill end-to-end from the command line against a tenant.

Examples:
    python scripts/run_skill.py --skill seo-audit "Audit https://example.com"
    python scripts/run_skill.py --engine fake "what's the ROI on this campaign: ..."
    python scripts/run_skill.py --tenant tnt_xxx --brand Acme "plan a Q4 campaign"

Approval prompts render on the console ([a]pprove / [r]eject); the same
ApprovalGate code path is used by Telegram.
"""
from __future__ import annotations

import argparse
import asyncio
import sys

from _bootstrap import build, get_logger  # noqa: E402
from channels.interface import ApprovalChoice, ChannelAdapter, IncomingMessage  # noqa: E402

log = get_logger("cli")


class ConsoleChannel(ChannelAdapter):
    name = "console"

    def __init__(self, auto_approve: bool | None = None) -> None:
        self.auto_approve = auto_approve

    async def receive(self, raw_payload: dict) -> IncomingMessage:
        return IncomingMessage(chat_ref="console", text=str(raw_payload.get("text", "")))

    async def send_text(self, chat_ref: str, text: str) -> None:
        print(text)

    async def send_document(self, chat_ref: str, file_path: str, caption: str) -> None:
        print(f"[document] {file_path}: {caption}")

    async def send_approval_prompt(self, chat_ref: str, action_summary: str, cost_estimate: str) -> ApprovalChoice:
        print(f"\n=== APPROVAL REQUIRED ===\n{action_summary}\nEstimated cost: {cost_estimate}")
        if self.auto_approve is not None:
            print(f"(auto-{'approve' if self.auto_approve else 'reject'})")
            return ApprovalChoice.APPROVE if self.auto_approve else ApprovalChoice.REJECT
        answer = await asyncio.to_thread(input, "[a]pprove / [r]eject: ")
        return ApprovalChoice.APPROVE if answer.strip().lower().startswith("a") else ApprovalChoice.REJECT


async def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("text", help="the user request")
    ap.add_argument("--skill", help="force a specific skill instead of routing")
    ap.add_argument("--engine", choices=["claude_sdk", "fake"], help="override ENGINE from the environment")
    ap.add_argument("--tenant", help="tenant id (default: a 'cli-demo' tenant is created/reused)")
    ap.add_argument("--brand", help="brand name to use/create in that tenant")
    ap.add_argument("--auto-approve", action="store_true")
    ap.add_argument("--auto-reject", action="store_true")
    args = ap.parse_args()

    settings, store, vault, orch = build(args.engine)
    tenant = store.get_tenant(args.tenant) if args.tenant else None
    if tenant is None:
        tenant = next((t for t in store.list_tenants() if t.name == "cli-demo"), None) or store.create_tenant("cli-demo")
    brand = None
    if args.brand:
        brand = store.find_brand_by_name(tenant.id, args.brand) or store.create_brand(tenant.id, args.brand)
    else:
        brands = store.list_brands(tenant.id)
        brand = brands[0] if brands else store.create_brand(tenant.id, "Demo Brand", voice_profile={"formality": 6, "energy": 6})
    session = store.get_session_by_ref("cli", tenant.id) or store.create_session(tenant.id, "cli", tenant.id, brand.id)
    if session.active_brand_id != brand.id:
        store.set_active_brand(session.id, brand.id)

    channel = ConsoleChannel(auto_approve=True if args.auto_approve else (False if args.auto_reject else None))
    log.info("cli.start", tenant_id=tenant.id, brand=brand.name, engine=orch.engine.name, skill=args.skill)
    result = await orch.handle(tenant_id=tenant.id, session_id=session.id, text=args.text, channel=channel,
                               chat_ref="console", skill_override=args.skill)
    print("\n" + "=" * 70)
    print(result.final_text)
    print("=" * 70)
    print(f"skills={result.skills} tool_calls={[c.name for c in result.tool_calls]} "
          f"tokens={result.usage.input_tokens}/{result.usage.output_tokens} cost=${result.cost_usd}")
    return 1 if result.is_error else 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
