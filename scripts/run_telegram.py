#!/usr/bin/env python3
"""Run the Telegram bot: long polling (dev) or webhook (prod).

    python scripts/run_telegram.py                 # polling
    python scripts/run_telegram.py --webhook https://bot.example.com --port 8080
"""
from __future__ import annotations

import argparse
import asyncio
import sys

from _bootstrap import build, get_logger  # noqa: E402
from channels.rate_limit import TenantRateLimiter  # noqa: E402
from channels.telegram.bot import TelegramAdapter, build_application  # noqa: E402
from channels.telegram.session_map import SessionMap  # noqa: E402
from channels.telegram.webhook import TelegramWebhook  # noqa: E402

log = get_logger("telegram.main")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--engine", choices=["claude_sdk", "fake"])
    ap.add_argument("--webhook", help="public HTTPS base URL; enables webhook mode")
    ap.add_argument("--port", type=int, default=8080)
    args = ap.parse_args()

    settings, store, vault, orch = build(args.engine)
    if not settings.telegram_bot_token:
        print("TELEGRAM_BOT_TOKEN is not set", file=sys.stderr)
        return 2

    def adapter_factory(bot):
        return TelegramAdapter(bot=bot, session_map=SessionMap(store), orchestrator=orch,
                               rate_limiter=TenantRateLimiter(per_minute=settings.rate_limit_per_minute),
                               doc_dir=settings.workdir / "documents")

    app = build_application(settings.telegram_bot_token, adapter_factory)
    adapter: TelegramAdapter = app.bot_data["adapter"]

    if not args.webhook:
        log.info("telegram.polling")
        app.run_polling()
        return 0

    async def run_webhook() -> None:
        hook = TelegramWebhook(adapter, settings.telegram_webhook_secret or "")
        async with app:
            await app.bot.set_webhook(url=args.webhook.rstrip("/") + hook.path, secret_token=settings.telegram_webhook_secret,
                                      allowed_updates=["message", "callback_query"])
            await hook.serve(port=args.port)

    asyncio.run(run_webhook())
    return 0


if __name__ == "__main__":
    sys.exit(main())
