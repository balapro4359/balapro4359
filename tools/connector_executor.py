"""Approval-gated write tools that execute through per-tenant connectors.

Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) —
the manifest-then-execute concept from scripts/connector_executor.py and
scripts/connector_resolver.py. Phase 1 builds and records an execution
manifest and performs a MOCK execution (no outbound HTTP). Every tool here has
``requires_approval=True`` and therefore cannot run without the ApprovalGate.
"""
from __future__ import annotations

from typing import Any

from connectors.registry import find_connector
from tools.registry import ToolContext, tool

MOCK_EXECUTION = True  # flip per connector as real executors land


def _credential_status(ctx: ToolContext, connector: str) -> str:
    if ctx.vault is None:
        return "no_vault"
    return "configured" if ctx.vault.is_configured(ctx.tenant_id, connector) else "not_configured"


def _execute(ctx: ToolContext, connector: str, operation: str, payload: dict[str, Any]) -> dict[str, Any]:
    info = find_connector(connector)
    manifest = {
        "status": "mock_executed" if MOCK_EXECUTION else "executed",
        "tenant_id": ctx.tenant_id,
        "brand_id": ctx.brand_id,
        "connector": connector,
        "known_connector": info is not None,
        "operation": operation,
        "payload": payload,
        "credential_status": _credential_status(ctx, connector),
    }
    if MOCK_EXECUTION:
        manifest["note"] = ("Phase 1 mock executor: the action was approved and recorded, but no request was sent "
                            "to the external system.")
    return manifest


def _money(x: float) -> str:
    return f"${x:,.2f}"


# --- email -------------------------------------------------------------------
_EMAIL_COST_PER_RECIPIENT = 0.0005


@tool(
    "send_email_campaign",
    "SEND an email campaign to a subscriber segment through the tenant's email connector (klaviyo, mailchimp, "
    "sendgrid, brevo, customerio, hubspot). This is an irreversible send and always requires human approval.",
    {
        "properties": {
            "connector": {"type": "string", "enum": ["klaviyo", "mailchimp", "sendgrid", "brevo", "customerio", "hubspot"]},
            "campaign_name": {"type": "string"},
            "segment": {"type": "string", "description": "Audience/list/segment identifier"},
            "recipient_count": {"type": "integer", "minimum": 1},
            "subject": {"type": "string"},
            "preview_text": {"type": "string"},
            "body_html": {"type": "string"},
            "send_at": {"type": "string", "description": "ISO-8601 or 'now'", "default": "now"},
        },
        "required": ["connector", "campaign_name", "segment", "recipient_count", "subject", "body_html"],
    },
    requires_approval=True,
    summarize=lambda a: f"Send email campaign '{a.get('campaign_name')}' (subject: {a.get('subject')!r}) to "
                        f"{a.get('recipient_count'):,} subscribers in segment '{a.get('segment')}' via {a.get('connector')}",
    estimate_cost=lambda a: _money(int(a.get("recipient_count", 0)) * _EMAIL_COST_PER_RECIPIENT),
)
def send_email_campaign(ctx: ToolContext, args: dict[str, Any]) -> dict:
    return _execute(ctx, args["connector"], "send_campaign", args)


# --- CRM ---------------------------------------------------------------------
@tool(
    "crm_sync_contacts",
    "WRITE contacts/leads into the tenant's CRM (hubspot, salesforce, pipedrive, zoho-crm): create or update records. "
    "Modifies customer data and always requires human approval.",
    {
        "properties": {
            "connector": {"type": "string", "enum": ["hubspot", "salesforce", "pipedrive", "zoho-crm"]},
            "operation": {"type": "string", "enum": ["create", "update", "upsert"], "default": "upsert"},
            "contacts": {"type": "array", "minItems": 1, "maxItems": 5000,
                         "items": {"type": "object", "properties": {"email": {"type": "string"}},
                                   "required": ["email"], "additionalProperties": True}},
        },
        "required": ["connector", "contacts"],
    },
    requires_approval=True,
    summarize=lambda a: f"{a.get('operation', 'upsert').title()} {len(a.get('contacts', [])):,} contacts in {a.get('connector')}",
    estimate_cost=lambda a: "$0.00 (API quota only)",
)
def crm_sync_contacts(ctx: ToolContext, args: dict[str, Any]) -> dict:
    return _execute(ctx, args["connector"], f"{args.get('operation', 'upsert')}_contacts",
                    {**args, "contacts": f"<{len(args['contacts'])} contacts>"})


# --- paid media --------------------------------------------------------------
@tool(
    "launch_ad_campaign",
    "LAUNCH or change budget on a paid campaign (google-ads, meta-ads, linkedin-ads, tiktok-ads). Spends money and "
    "always requires human approval.",
    {
        "properties": {
            "connector": {"type": "string", "enum": ["google-ads", "meta-ads", "linkedin-ads", "tiktok-ads"]},
            "campaign_name": {"type": "string"},
            "objective": {"type": "string"},
            "daily_budget": {"type": "number", "exclusiveMinimum": 0},
            "duration_days": {"type": "integer", "minimum": 1, "default": 30},
            "targeting": {"type": "object", "additionalProperties": True},
            "creatives": {"type": "array", "items": {"type": "object", "additionalProperties": True}},
        },
        "required": ["connector", "campaign_name", "daily_budget"],
    },
    requires_approval=True,
    summarize=lambda a: f"Launch '{a.get('campaign_name')}' on {a.get('connector')} at {_money(float(a.get('daily_budget', 0)))}/day "
                        f"for {a.get('duration_days', 30)} days",
    estimate_cost=lambda a: _money(float(a.get("daily_budget", 0)) * int(a.get("duration_days", 30))) + " total media spend",
)
def launch_ad_campaign(ctx: ToolContext, args: dict[str, Any]) -> dict:
    return _execute(ctx, args["connector"], "create_campaign", args)


# --- social ------------------------------------------------------------------
@tool(
    "schedule_social_post",
    "PUBLISH or schedule a social post via buffer/hootsuite or a native platform connector. Public and hard to "
    "retract; always requires human approval.",
    {
        "properties": {
            "connector": {"type": "string", "enum": ["buffer", "hootsuite", "linkedin", "twitter", "facebook", "instagram"]},
            "platforms": {"type": "array", "items": {"type": "string"}},
            "text": {"type": "string", "minLength": 1},
            "media_urls": {"type": "array", "items": {"type": "string"}},
            "scheduled_at": {"type": "string", "default": "now"},
        },
        "required": ["connector", "text"],
    },
    requires_approval=True,
    summarize=lambda a: f"Post to {', '.join(a.get('platforms') or [a.get('connector')])} at {a.get('scheduled_at', 'now')}: "
                        f"{a.get('text', '')[:120]!r}",
    estimate_cost=lambda a: "$0.00",
)
def schedule_social_post(ctx: ToolContext, args: dict[str, Any]) -> dict:
    return _execute(ctx, args["connector"], "schedule_post", args)


# --- read-only helper --------------------------------------------------------
@tool(
    "list_connectors",
    "List which connectors are configured for this workspace (credentials present) and which are available to "
    "connect. Read-only.",
    {"properties": {}, "required": []},
)
def list_connectors(ctx: ToolContext, args: dict[str, Any]) -> dict:
    from connectors.registry import load_catalog

    configured = set(ctx.vault.list_names(ctx.tenant_id)) if ctx.vault is not None else set()
    return {
        "configured": sorted(configured),
        "available": [{"name": c.name, "category": c.category, "auth": c.auth_kind, "description": c.description}
                      for c in load_catalog().values() if c.name not in configured],
    }


TOOLS = [send_email_campaign, crm_sync_contacts, launch_ad_campaign, schedule_social_post, list_connectors]
