"""Connector metadata registry.

Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) —
the ``CONNECTOR_REGISTRY`` catalog concept from scripts/_connector_registry.py.
The catalog data lives in ``catalog.json``; configuration checks are per-tenant
and go through the vault instead of the plugin's local ``.mcp.json`` probe.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

CATALOG_PATH = Path(__file__).resolve().parent / "catalog.json"

# Write/send/spend operations per connector that must be approval-gated.
WRITE_OPERATIONS: dict[str, tuple[str, ...]] = {
    "hubspot": ("create_contact", "update_contact", "create_campaign", "enable_workflow"),
    "klaviyo": ("send_campaign", "create_flow", "add_profile"),
    "mailchimp": ("send_campaign", "add_member"),
    "sendgrid": ("send_email",),
    "brevo": ("send_email", "send_campaign"),
    "customerio": ("send_broadcast", "track_event"),
    "slack": ("post_message",),
    "google-ads": ("create_campaign", "update_budget", "pause_campaign"),
    "meta-ads": ("create_campaign", "update_budget", "pause_campaign"),
    "linkedin-ads": ("create_campaign", "update_budget"),
    "tiktok-ads": ("create_campaign", "update_budget"),
    "buffer": ("schedule_post",),
    "hootsuite": ("schedule_post",),
}


@dataclass(frozen=True)
class ConnectorInfo:
    name: str
    category: str
    description: str
    transport: str | None
    env_vars: tuple[str, ...]
    skills_unlocked: tuple[str, ...]
    auth_kind: str  # oauth | apikey | none

    def is_write_operation(self, operation: str) -> bool:
        return operation in WRITE_OPERATIONS.get(self.name, ())


_OAUTH_CONNECTORS = {
    "google-ads", "meta-ads", "linkedin-ads", "tiktok-ads", "google-analytics",
    "google-search-console", "gmail", "google-calendar", "twitter", "youtube", "linkedin",
    "facebook", "instagram", "google-drive", "hubspot",
}


@lru_cache(maxsize=1)
def load_catalog() -> dict[str, ConnectorInfo]:
    raw: dict[str, Any] = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    out: dict[str, ConnectorInfo] = {}
    for category, cat in raw.items():
        for name, info in cat.get("connectors", {}).items():
            env_vars = tuple(info.get("env_vars") or ())
            auth = "oauth" if name in _OAUTH_CONNECTORS else ("apikey" if env_vars else "none")
            out[name] = ConnectorInfo(
                name=name, category=category, description=info.get("description", ""),
                transport=info.get("transport"), env_vars=env_vars,
                skills_unlocked=tuple(info.get("skills_unlocked") or ()), auth_kind=auth,
            )
    return out


def find_connector(name: str) -> ConnectorInfo | None:
    return load_catalog().get(name)


def list_connector_names() -> list[str]:
    return sorted(load_catalog())


def connectors_for_skill(skill_name: str) -> list[ConnectorInfo]:
    return [c for c in load_catalog().values() if skill_name in c.skills_unlocked]
