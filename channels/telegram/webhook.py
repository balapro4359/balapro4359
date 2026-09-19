"""Webhook receiver: verifies Telegram's secret-token header, deserializes, dispatches.

Framework-free: ``TelegramWebhook.handle`` takes headers+body and returns an
HTTP status, so it can be mounted in any web server. ``serve`` runs a minimal
asyncio HTTP/1.1 listener for deployments without a separate web framework.
"""
from __future__ import annotations

import asyncio
import hmac
import json
from collections.abc import Mapping

from channels.telegram.bot import TelegramAdapter
from config.logging import get_logger

log = get_logger("channel.telegram.webhook")

SECRET_HEADER = "x-telegram-bot-api-secret-token"


class TelegramWebhook:
    def __init__(self, adapter: TelegramAdapter, secret_token: str, path: str = "/telegram/webhook") -> None:
        if not secret_token:
            raise ValueError("TELEGRAM_WEBHOOK_SECRET must be set for webhook mode")
        self.adapter = adapter
        self.secret_token = secret_token
        self.path = path

    def verify(self, headers: Mapping[str, str]) -> bool:
        provided = ""
        for k, v in headers.items():
            if k.lower() == SECRET_HEADER:
                provided = v
                break
        return hmac.compare_digest(provided, self.secret_token)

    async def handle(self, headers: Mapping[str, str], body: bytes) -> tuple[int, str]:
        if not self.verify(headers):
            log.warning("webhook.rejected", reason="bad_secret")
            return 403, "forbidden"
        try:
            payload = json.loads(body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return 400, "bad json"
        try:
            incoming = await self.adapter.receive(payload)
        except ValueError:
            return 200, "ignored"
        if incoming.kind == "callback" and hasattr(self.adapter.bot, "answer_callback_query"):
            cq_id = payload.get("callback_query", {}).get("id")
            if cq_id:
                try:
                    await self.adapter.bot.answer_callback_query(cq_id)
                except Exception:
                    pass
        # Respond to Telegram immediately; the adapter runs the skill asynchronously.
        asyncio.create_task(self.adapter.handle_incoming(incoming))
        return 200, "ok"

    async def _serve_conn(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        try:
            request_line = await reader.readline()
            parts = request_line.decode("latin-1").split()
            method, target = (parts[0], parts[1]) if len(parts) >= 2 else ("", "")
            headers: dict[str, str] = {}
            while True:
                line = await reader.readline()
                if line in (b"\r\n", b"\n", b""):
                    break
                k, _, v = line.decode("latin-1").partition(":")
                headers[k.strip().lower()] = v.strip()
            body = await reader.readexactly(int(headers.get("content-length", "0") or 0))
            if method == "POST" and target == self.path:
                status, text = await self.handle(headers, body)
            elif method == "GET" and target == "/healthz":
                status, text = 200, "ok"
            else:
                status, text = 404, "not found"
            payload = text.encode()
            writer.write(f"HTTP/1.1 {status} {'OK' if status == 200 else 'ERR'}\r\nContent-Type: text/plain\r\n"
                         f"Content-Length: {len(payload)}\r\nConnection: close\r\n\r\n".encode() + payload)
            await writer.drain()
        except Exception as exc:  # never crash the listener
            log.warning("webhook.conn_error", error=str(exc))
        finally:
            writer.close()

    async def serve(self, host: str = "0.0.0.0", port: int = 8080) -> None:
        server = await asyncio.start_server(self._serve_conn, host, port)
        log.info("webhook.listening", host=host, port=port, path=self.path)
        async with server:
            await server.serve_forever()
