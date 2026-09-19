"""ChannelAdapter ABC and channel-neutral message types.

No orchestration or business logic imports a concrete channel library.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
from typing import Any


class ApprovalChoice(str, Enum):
    APPROVE = "approve"
    REJECT = "reject"
    PREVIEW = "preview"  # channel-internal: re-shows details, never a final decision


@dataclass(frozen=True)
class IncomingMessage:
    chat_ref: str
    text: str
    kind: str = "text"  # text | command | callback
    user_ref: str | None = None
    raw: dict[str, Any] = field(default_factory=dict)


class ChannelAdapter(ABC):
    name: str = "abstract"

    @abstractmethod
    async def receive(self, raw_payload: dict) -> IncomingMessage: ...

    @abstractmethod
    async def send_text(self, chat_ref: str, text: str) -> None: ...

    @abstractmethod
    async def send_document(self, chat_ref: str, file_path: str, caption: str) -> None: ...

    @abstractmethod
    async def send_approval_prompt(self, chat_ref: str, action_summary: str, cost_estimate: str) -> ApprovalChoice:
        """Block until the human approves or rejects. Must resolve to APPROVE or REJECT."""
        ...
