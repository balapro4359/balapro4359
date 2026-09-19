# Marketing AI Orchestration Platform

Multi-tenant AI orchestration for marketing automation, delivered through chat
(Telegram first). Skills and tools are adapted from the MIT-licensed
[Digital Marketing Pro](https://github.com/indranilbanerjee/digital-marketing-pro)
plugin — see `THIRD_PARTY_NOTICES.md`.

The primary architectural goal of Phase 1 is a **swappable orchestration
engine**: the Claude Agent SDK sits behind `orchestration/interface.py`, and a
LangGraph implementation can replace it later without touching the router,
approval gate, tools, skills, data layer or channel adapters.

## Layout

```
orchestration/
  interface.py          AgentEngine ABC + ToolSpec/Message/ToolCall/ToolResult/AgentRunResult (the seam)
  engines/
    claude_sdk_engine.py  Phase 1 — the ONLY file that imports claude_agent_sdk
    fake_engine.py        deterministic engine for tests / offline dev
    langgraph_engine.py   Phase 2 stub
  router.py             user intent -> 1-3 skills (keyword/trigger matching over the 163-skill index)
  approval_gate.py      human-in-the-loop gate; every request + decision is audit-logged
  orchestrator.py       composition: router -> skills -> gated tools -> engine -> usage/cost log
  pricing.py            per-model price table and cost computation
skills/                 plain SKILL.md (YAML front matter + markdown); index.json for routing
tools/                  plain functions + JSON schema; tools/ported/ holds verbatim plugin scripts
connectors/             connector catalog, encrypted credential vault, oauth/ and apikey/ handlers
channels/
  interface.py          ChannelAdapter ABC, ApprovalChoice, IncomingMessage
  rate_limit.py         per-tenant token bucket (applied at the channel, not the engine)
  telegram/             bot.py (adapter), webhook.py, session_map.py, formatting.py
data/                   models.py + SQLite store + migrations/
config/                 env-driven settings, structured logging
scripts/                run_skill.py (CLI), run_telegram.py, manage.py
tests/                  65 tests incl. the fake-engine seam check and import-boundary guards
```

## Quick start

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env            # fill in ANTHROPIC_API_KEY, TELEGRAM_BOT_TOKEN, VAULT_ENCRYPTION_KEY
pytest -q                       # 65 tests, no network needed

# M1: one skill end-to-end from the CLI (real engine)
python scripts/run_skill.py --skill seo-audit "Audit https://example.com"
# same path, offline
python scripts/run_skill.py --engine fake --skill roi-calculator "what's the ROI on this campaign"

# Telegram (polling for dev, webhook for prod)
python scripts/run_telegram.py
python scripts/run_telegram.py --webhook https://bot.example.com --port 8080
```

Admin: `python scripts/manage.py create-tenant "Acme"`, `link-code <tenant_id>`
(one-time code for `/link` in Telegram), `set-credential`, `audit`, `usage`.

## How a request flows

1. **Channel adapter** (`channels/telegram/bot.py`) receives an update, maps
   `chat_id -> tenant + active brand` via `session_map.py`, applies the
   per-tenant rate limit, sends an immediate ack, and runs the request in the
   background.
2. **Orchestrator** asks the **router** for 1-3 skills, renders their
   `SKILL.md` bodies plus the brand profile into one plain system prompt, and
   collects the `ToolSpec`s those skills declare.
3. **Engine** (`AgentEngine.run`) drives the model. Every tool invocation comes
   back through `on_tool_call`; the engine never executes tools itself.
4. **ApprovalGate**: tools with `requires_approval=True` (send email, sync CRM,
   launch ads, post social) block until the channel returns Approve/Reject. In
   Telegram that is an inline keyboard (`Approve / Reject / Preview`) whose
   callback resolves the pending future. Timeouts and channel errors fail
   closed. Every request and decision is written to the append-only audit log.
5. **Usage**: tokens and computed cost are recorded per tenant for billing.
6. The reply is chunked to Telegram's 4096-char limit or, above 4000 chars,
   sent as a Markdown document.

## Multi-tenancy

Every table carries `tenant_id`; brand lookups, sessions, approvals, audit,
credentials and usage are all tenant-scoped in `data/store.py`. Telegram
onboarding: `/new <workspace>` creates a tenant + brand; `/link <code>` joins an
existing tenant via a one-time code; `/brand <name>` and `/newbrand <name>`
manage brands.

## Engine seam rules (enforced by `tests/test_boundaries.py`)

- Only `orchestration/engines/*` may import `claude_agent_sdk` / `langgraph`.
- Only `channels/telegram/*` may import `telegram`.
- Tools are never SDK-decorated; skills contain no engine-specific syntax.
- `tests/test_seam_fake_engine.py` runs router, gate, orchestrator and the
  Telegram adapter against `FakeEngine` unchanged.

## Porting more skills

Skills are ported on demand. The router logs `router.port_demand` whenever the
best match is an unported skill from `skills/index.json`; port it by adding
`skills/<name>/SKILL.md` (front matter: `name`, `description`, `triggers`,
`tools`) with the attribution comment, and wrap any script it needs in `tools/`.

## Status of milestones

| Milestone | Status |
|---|---|
| M1 core interfaces + Claude SDK engine + CLI | done (`scripts/run_skill.py`) |
| M2 approval gate with logging | done (`tests/test_approval_gate.py`, seam tests) |
| M3 Telegram adapter | done (`channels/telegram/`, polling + webhook) |
| M4 multi-tenant isolation | done (`tests/test_telegram.py::test_onboarding_and_multi_tenant_isolation`) |
| M5 approval via inline buttons | done (`tests/test_telegram.py::test_approval_via_inline_keyboard_buttons`) |
| M6 ten priority skills | done (`skills/`, `tests/test_router_and_skills.py`) |
| M7 fake-engine seam check | done (`tests/test_seam_fake_engine.py`, `tests/test_boundaries.py`) |

Phase 1 limitations: connector write tools run as **mock executors** (they
build and record the manifest; no outbound request is sent); long replies are
attached as Markdown, not PDF; storage is SQLite.
