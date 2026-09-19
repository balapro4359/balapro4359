"""SQLite-backed store. Every query is scoped by tenant_id.

Deliberately simple for Phase 1 (sync sqlite3 behind a lock; calls are fast).
A Postgres implementation later only has to keep this class's public surface.
"""
from __future__ import annotations

import json
import secrets
import sqlite3
import threading
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from data.models import (
    ApprovalRequest,
    AuditLogEntry,
    Brand,
    ConnectorCredential,
    Session,
    Tenant,
    UsageRecord,
    new_id,
    now_iso,
)

MIGRATIONS_DIR = Path(__file__).resolve().parent / "migrations"


class Store:
    def __init__(self, path: str = ":memory:") -> None:
        if path != ":memory:":
            Path(path).parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
        self._conn.row_factory = sqlite3.Row
        self._conn.execute("PRAGMA foreign_keys = ON")
        self._lock = threading.RLock()
        self.migrate()

    # ------------------------------------------------------------------ infra
    def migrate(self) -> None:
        with self._lock:
            self._conn.execute(
                "CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at TEXT NOT NULL)"
            )
            applied = {r["version"] for r in self._conn.execute("SELECT version FROM schema_migrations")}
            for sql_file in sorted(MIGRATIONS_DIR.glob("*.sql")):
                if sql_file.stem in applied:
                    continue
                self._conn.executescript(sql_file.read_text(encoding="utf-8"))
                self._conn.execute(
                    "INSERT INTO schema_migrations(version, applied_at) VALUES (?, ?)", (sql_file.stem, now_iso())
                )

    def close(self) -> None:
        self._conn.close()

    def _exec(self, sql: str, params: tuple = ()) -> sqlite3.Cursor:
        with self._lock:
            return self._conn.execute(sql, params)

    # ---------------------------------------------------------------- tenants
    def create_tenant(self, name: str, plan_tier: str = "free", settings: dict | None = None) -> Tenant:
        t = Tenant(id=new_id("tnt"), name=name, plan_tier=plan_tier, settings=settings or {})
        self._exec(
            "INSERT INTO tenants(id, name, plan_tier, settings, created_at) VALUES (?,?,?,?,?)",
            (t.id, t.name, t.plan_tier, json.dumps(t.settings), t.created_at),
        )
        return t

    def get_tenant(self, tenant_id: str) -> Tenant | None:
        r = self._exec("SELECT * FROM tenants WHERE id=?", (tenant_id,)).fetchone()
        return None if r is None else Tenant(r["id"], r["name"], r["plan_tier"], json.loads(r["settings"]), r["created_at"])

    def list_tenants(self) -> list[Tenant]:
        return [Tenant(r["id"], r["name"], r["plan_tier"], json.loads(r["settings"]), r["created_at"])
                for r in self._exec("SELECT * FROM tenants ORDER BY created_at")]

    # ----------------------------------------------------------------- brands
    def create_brand(self, tenant_id: str, name: str, voice_profile: dict | None = None,
                     competitors: list[str] | None = None, guidelines: str = "") -> Brand:
        b = Brand(id=new_id("brd"), tenant_id=tenant_id, name=name, voice_profile=voice_profile or {},
                  competitors=competitors or [], guidelines=guidelines)
        self._exec(
            "INSERT INTO brands(id, tenant_id, name, voice_profile, competitors, guidelines, created_at) VALUES (?,?,?,?,?,?,?)",
            (b.id, b.tenant_id, b.name, json.dumps(b.voice_profile), json.dumps(b.competitors), b.guidelines, b.created_at),
        )
        return b

    def update_brand(self, tenant_id: str, brand_id: str, **fields: Any) -> Brand | None:
        allowed = {"name", "voice_profile", "competitors", "guidelines"}
        sets, params = [], []
        for k, v in fields.items():
            if k not in allowed:
                raise ValueError(f"cannot update field {k}")
            sets.append(f"{k}=?")
            params.append(json.dumps(v) if k in ("voice_profile", "competitors") else v)
        if sets:
            params += [tenant_id, brand_id]
            self._exec(f"UPDATE brands SET {', '.join(sets)} WHERE tenant_id=? AND id=?", tuple(params))
        return self.get_brand(tenant_id, brand_id)

    @staticmethod
    def _brand(r: sqlite3.Row) -> Brand:
        return Brand(r["id"], r["tenant_id"], r["name"], json.loads(r["voice_profile"]),
                     json.loads(r["competitors"]), r["guidelines"], r["created_at"])

    def get_brand(self, tenant_id: str, brand_id: str) -> Brand | None:
        r = self._exec("SELECT * FROM brands WHERE tenant_id=? AND id=?", (tenant_id, brand_id)).fetchone()
        return None if r is None else self._brand(r)

    def find_brand_by_name(self, tenant_id: str, name: str) -> Brand | None:
        r = self._exec("SELECT * FROM brands WHERE tenant_id=? AND lower(name)=lower(?)", (tenant_id, name)).fetchone()
        return None if r is None else self._brand(r)

    def list_brands(self, tenant_id: str) -> list[Brand]:
        return [self._brand(r) for r in self._exec("SELECT * FROM brands WHERE tenant_id=? ORDER BY created_at", (tenant_id,))]

    # --------------------------------------------------------------- sessions
    @staticmethod
    def _session(r: sqlite3.Row) -> Session:
        return Session(r["id"], r["tenant_id"], r["channel"], r["channel_ref"], r["active_brand_id"], r["created_at"])

    def create_session(self, tenant_id: str, channel: str, channel_ref: str, active_brand_id: str | None) -> Session:
        s = Session(id=new_id("ses"), tenant_id=tenant_id, channel=channel, channel_ref=channel_ref, active_brand_id=active_brand_id)
        self._exec(
            "INSERT INTO sessions(id, tenant_id, channel, channel_ref, active_brand_id, created_at) VALUES (?,?,?,?,?,?)",
            (s.id, s.tenant_id, s.channel, s.channel_ref, s.active_brand_id, s.created_at),
        )
        return s

    def get_session_by_ref(self, channel: str, channel_ref: str) -> Session | None:
        r = self._exec("SELECT * FROM sessions WHERE channel=? AND channel_ref=?", (channel, channel_ref)).fetchone()
        return None if r is None else self._session(r)

    def get_session(self, session_id: str) -> Session | None:
        r = self._exec("SELECT * FROM sessions WHERE id=?", (session_id,)).fetchone()
        return None if r is None else self._session(r)

    def set_active_brand(self, session_id: str, brand_id: str) -> None:
        s = self.get_session(session_id)
        if s is None:
            raise KeyError(session_id)
        if self.get_brand(s.tenant_id, brand_id) is None:
            raise PermissionError("brand does not belong to the session's tenant")
        self._exec("UPDATE sessions SET active_brand_id=? WHERE id=?", (brand_id, session_id))

    # ------------------------------------------------------------ conversation
    def append_message(self, tenant_id: str, session_id: str, role: str, content: str) -> None:
        self._exec(
            "INSERT INTO conversation_messages(tenant_id, session_id, role, content, created_at) VALUES (?,?,?,?,?)",
            (tenant_id, session_id, role, content, now_iso()),
        )

    def recent_messages(self, tenant_id: str, session_id: str, limit: int = 12) -> list[tuple[str, str]]:
        rows = self._exec(
            "SELECT role, content FROM conversation_messages WHERE tenant_id=? AND session_id=? ORDER BY id DESC LIMIT ?",
            (tenant_id, session_id, limit),
        ).fetchall()
        return [(r["role"], r["content"]) for r in reversed(rows)]

    # --------------------------------------------------------------- approvals
    def create_approval(self, tenant_id: str, tool_name: str, args_summary: str, cost_estimate: str = "") -> ApprovalRequest:
        a = ApprovalRequest(id=new_id("apr"), tenant_id=tenant_id, tool_name=tool_name,
                            args_summary=args_summary, cost_estimate=cost_estimate)
        self._exec(
            "INSERT INTO approval_requests(id, tenant_id, tool_name, args_summary, cost_estimate, status, created_at) VALUES (?,?,?,?,?,?,?)",
            (a.id, a.tenant_id, a.tool_name, a.args_summary, a.cost_estimate, a.status, a.created_at),
        )
        return a

    def decide_approval(self, approval_id: str, status: str, decided_by: str) -> ApprovalRequest | None:
        self._exec(
            "UPDATE approval_requests SET status=?, decided_by=?, decided_at=? WHERE id=? AND status='pending'",
            (status, decided_by, now_iso(), approval_id),
        )
        return self.get_approval(approval_id)

    def get_approval(self, approval_id: str) -> ApprovalRequest | None:
        r = self._exec("SELECT * FROM approval_requests WHERE id=?", (approval_id,)).fetchone()
        if r is None:
            return None
        return ApprovalRequest(r["id"], r["tenant_id"], r["tool_name"], r["args_summary"], r["cost_estimate"],
                               r["status"], r["decided_by"], r["decided_at"], r["created_at"])

    def list_approvals(self, tenant_id: str, status: str | None = None) -> list[ApprovalRequest]:
        sql, params = "SELECT id FROM approval_requests WHERE tenant_id=?", [tenant_id]
        if status:
            sql += " AND status=?"
            params.append(status)
        return [self.get_approval(r["id"]) for r in self._exec(sql + " ORDER BY created_at", tuple(params))]  # type: ignore[misc]

    # --------------------------------------------------------------- audit log
    def append_audit(self, entry: AuditLogEntry) -> AuditLogEntry:
        cur = self._exec(
            "INSERT INTO audit_log(tenant_id, actor, action, tool_call, result_summary, timestamp) VALUES (?,?,?,?,?,?)",
            (entry.tenant_id, entry.actor, entry.action, json.dumps(entry.tool_call, default=str),
             entry.result_summary, entry.timestamp),
        )
        return AuditLogEntry(entry.tenant_id, entry.actor, entry.action, entry.tool_call,
                             entry.result_summary, entry.timestamp, id=cur.lastrowid)

    def list_audit(self, tenant_id: str, limit: int = 100) -> list[AuditLogEntry]:
        rows = self._exec("SELECT * FROM audit_log WHERE tenant_id=? ORDER BY id LIMIT ?", (tenant_id, limit))
        return [AuditLogEntry(r["tenant_id"], r["actor"], r["action"], json.loads(r["tool_call"]),
                              r["result_summary"], r["timestamp"], id=r["id"]) for r in rows]

    # -------------------------------------------------------------- credentials
    def put_credential(self, tenant_id: str, connector_name: str, encrypted_value: bytes,
                       oauth_refresh_token: bytes | None = None, expires_at: str | None = None) -> ConnectorCredential:
        c = ConnectorCredential(id=new_id("crd"), tenant_id=tenant_id, connector_name=connector_name,
                                encrypted_value=encrypted_value, oauth_refresh_token=oauth_refresh_token, expires_at=expires_at)
        self._exec("DELETE FROM connector_credentials WHERE tenant_id=? AND connector_name=?", (tenant_id, connector_name))
        self._exec(
            "INSERT INTO connector_credentials(id, tenant_id, connector_name, encrypted_value, oauth_refresh_token, expires_at, created_at) VALUES (?,?,?,?,?,?,?)",
            (c.id, c.tenant_id, c.connector_name, c.encrypted_value, c.oauth_refresh_token, c.expires_at, c.created_at),
        )
        return c

    def get_credential(self, tenant_id: str, connector_name: str) -> ConnectorCredential | None:
        r = self._exec("SELECT * FROM connector_credentials WHERE tenant_id=? AND connector_name=?", (tenant_id, connector_name)).fetchone()
        if r is None:
            return None
        return ConnectorCredential(r["id"], r["tenant_id"], r["connector_name"], r["encrypted_value"],
                                   r["oauth_refresh_token"], r["expires_at"], r["created_at"])

    def list_credential_names(self, tenant_id: str) -> list[str]:
        return [r["connector_name"] for r in self._exec(
            "SELECT connector_name FROM connector_credentials WHERE tenant_id=? ORDER BY connector_name", (tenant_id,))]

    def delete_credential(self, tenant_id: str, connector_name: str) -> None:
        self._exec("DELETE FROM connector_credentials WHERE tenant_id=? AND connector_name=?", (tenant_id, connector_name))

    # ------------------------------------------------------------------- usage
    def record_usage(self, u: UsageRecord) -> UsageRecord:
        cur = self._exec(
            "INSERT INTO usage_records(tenant_id, brand_id, session_id, engine, model, skills, input_tokens, output_tokens, "
            "cache_read_tokens, cache_write_tokens, cost_usd, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (u.tenant_id, u.brand_id, u.session_id, u.engine, u.model, json.dumps(u.skills), u.input_tokens, u.output_tokens,
             u.cache_read_tokens, u.cache_write_tokens, u.cost_usd, u.created_at),
        )
        u.id = cur.lastrowid
        return u

    def usage_summary(self, tenant_id: str) -> dict[str, Any]:
        r = self._exec(
            "SELECT COUNT(*) AS runs, COALESCE(SUM(input_tokens),0) AS input_tokens, COALESCE(SUM(output_tokens),0) AS output_tokens, "
            "COALESCE(SUM(cost_usd),0) AS cost_usd FROM usage_records WHERE tenant_id=?", (tenant_id,)).fetchone()
        return {"runs": r["runs"], "input_tokens": r["input_tokens"], "output_tokens": r["output_tokens"], "cost_usd": round(r["cost_usd"], 6)}

    # -------------------------------------------------------------- onboarding
    def create_onboarding_code(self, tenant_id: str, ttl_minutes: int = 60) -> str:
        code = secrets.token_hex(4).upper()
        expires = (datetime.now(timezone.utc) + timedelta(minutes=ttl_minutes)).isoformat(timespec="seconds")
        self._exec("INSERT INTO onboarding_codes(code, tenant_id, expires_at) VALUES (?,?,?)", (code, tenant_id, expires))
        return code

    def redeem_onboarding_code(self, code: str) -> str | None:
        """Return tenant_id if the code is valid and unused; marks it used."""
        r = self._exec("SELECT * FROM onboarding_codes WHERE code=?", (code.strip().upper(),)).fetchone()
        if r is None or r["used_at"] is not None:
            return None
        if datetime.fromisoformat(r["expires_at"]) < datetime.now(timezone.utc):
            return None
        self._exec("UPDATE onboarding_codes SET used_at=? WHERE code=?", (now_iso(), r["code"]))
        return r["tenant_id"]
