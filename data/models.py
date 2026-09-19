"""Tenant-scoped domain models. Plain dataclasses; persistence lives in data/store.py."""
from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Literal


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def new_id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:16]}"


@dataclass
class Tenant:
    id: str
    name: str
    plan_tier: str = "free"
    settings: dict[str, Any] = field(default_factory=dict)
    created_at: str = field(default_factory=now_iso)


@dataclass
class Brand:
    id: str
    tenant_id: str
    name: str
    voice_profile: dict[str, Any] = field(default_factory=dict)
    competitors: list[str] = field(default_factory=list)
    guidelines: str = ""
    created_at: str = field(default_factory=now_iso)


@dataclass
class Session:
    id: str
    tenant_id: str
    channel: str
    channel_ref: str
    active_brand_id: str | None = None
    created_at: str = field(default_factory=now_iso)


ApprovalStatus = Literal["pending", "approved", "rejected", "expired"]


@dataclass
class ApprovalRequest:
    id: str
    tenant_id: str
    tool_name: str
    args_summary: str
    cost_estimate: str = ""
    status: ApprovalStatus = "pending"
    decided_by: str | None = None
    decided_at: str | None = None
    created_at: str = field(default_factory=now_iso)


@dataclass(frozen=True)
class AuditLogEntry:
    """Immutable, append-only. ``id`` is assigned by the store on insert."""

    tenant_id: str
    actor: str
    action: str
    tool_call: dict[str, Any] = field(default_factory=dict)
    result_summary: str = ""
    timestamp: str = field(default_factory=now_iso)
    id: int | None = None


@dataclass
class ConnectorCredential:
    id: str
    tenant_id: str
    connector_name: str
    encrypted_value: bytes
    oauth_refresh_token: bytes | None = None
    expires_at: str | None = None
    created_at: str = field(default_factory=now_iso)


@dataclass
class UsageRecord:
    tenant_id: str
    brand_id: str | None
    session_id: str | None
    engine: str | None
    model: str | None
    skills: list[str]
    input_tokens: int
    output_tokens: int
    cache_read_tokens: int
    cache_write_tokens: int
    cost_usd: float
    created_at: str = field(default_factory=now_iso)
    id: int | None = None
