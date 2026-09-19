"""Message chunking and text-vs-document decisions for Telegram (4096-char cap)."""
from __future__ import annotations

import re
import tempfile
from dataclasses import dataclass
from pathlib import Path

TELEGRAM_MAX = 4096
DOCUMENT_THRESHOLD = 4000


@dataclass(frozen=True)
class Delivery:
    mode: str                 # "text" | "document"
    chunks: list[str]         # for text mode
    file_path: str | None     # for document mode
    caption: str | None


def split_message(text: str, limit: int = TELEGRAM_MAX) -> list[str]:
    """Split on paragraph, then line, then hard boundaries. Never returns an empty chunk."""
    text = text.strip()
    if not text:
        return []
    if len(text) <= limit:
        return [text]
    chunks: list[str] = []
    remaining = text
    while len(remaining) > limit:
        window = remaining[:limit]
        cut = max(window.rfind("\n\n"), window.rfind("\n") if window.rfind("\n\n") < limit // 3 else -1)
        if cut < limit // 3:
            cut = window.rfind(" ")
        if cut <= 0:
            cut = limit
        chunk, remaining = remaining[:cut].rstrip(), remaining[cut:].lstrip()
        if chunk:
            chunks.append(chunk)
    if remaining:
        chunks.append(remaining)
    return chunks


def _title_from(text: str, fallback: str) -> str:
    m = re.search(r"^#+\s*(.+)$", text, re.M)
    title = (m.group(1) if m else fallback).strip()
    return re.sub(r"[^A-Za-z0-9._-]+", "-", title).strip("-")[:60] or fallback


def decide_delivery(text: str, *, threshold: int = DOCUMENT_THRESHOLD, out_dir: Path | None = None,
                    fallback_name: str = "report", caption: str | None = None) -> Delivery:
    """Long answers become a Markdown document (PDF conversion is a later hook); short ones are chunked text."""
    text = text.strip()
    if len(text) <= threshold:
        return Delivery("text", split_message(text), None, None)
    out_dir = out_dir or Path(tempfile.mkdtemp(prefix="mkt-doc-"))
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{_title_from(text, fallback_name)}.md"
    path.write_text(text + "\n", encoding="utf-8")
    first_line = text.splitlines()[0].lstrip("# ").strip()
    return Delivery("document", [], str(path), caption or f"{first_line[:150]} (full report attached)")


def escape_markdown_v1(text: str) -> str:
    """Telegram's legacy Markdown is fragile; we send plain text and keep markdown as-is."""
    return text
