-- Initial schema. Every table that holds user data carries tenant_id.
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS tenants (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    plan_tier   TEXT NOT NULL DEFAULT 'free',
    settings    TEXT NOT NULL DEFAULT '{}',   -- JSON per-tenant overrides
    created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS brands (
    id            TEXT PRIMARY KEY,
    tenant_id     TEXT NOT NULL REFERENCES tenants(id),
    name          TEXT NOT NULL,
    voice_profile TEXT NOT NULL DEFAULT '{}', -- JSON
    competitors   TEXT NOT NULL DEFAULT '[]', -- JSON
    guidelines    TEXT NOT NULL DEFAULT '',
    created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_brands_tenant ON brands(tenant_id);

CREATE TABLE IF NOT EXISTS sessions (
    id              TEXT PRIMARY KEY,
    tenant_id       TEXT NOT NULL REFERENCES tenants(id),
    channel         TEXT NOT NULL,
    channel_ref     TEXT NOT NULL,
    active_brand_id TEXT REFERENCES brands(id),
    created_at      TEXT NOT NULL,
    UNIQUE(channel, channel_ref)
);
CREATE INDEX IF NOT EXISTS idx_sessions_tenant ON sessions(tenant_id);

CREATE TABLE IF NOT EXISTS conversation_messages (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    tenant_id   TEXT NOT NULL,
    session_id  TEXT NOT NULL REFERENCES sessions(id),
    role        TEXT NOT NULL,
    content     TEXT NOT NULL,
    created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_conv_session ON conversation_messages(session_id, id);

CREATE TABLE IF NOT EXISTS approval_requests (
    id            TEXT PRIMARY KEY,
    tenant_id     TEXT NOT NULL REFERENCES tenants(id),
    tool_name     TEXT NOT NULL,
    args_summary  TEXT NOT NULL,
    cost_estimate TEXT NOT NULL DEFAULT '',
    status        TEXT NOT NULL,             -- pending | approved | rejected | expired
    decided_by    TEXT,
    decided_at    TEXT,
    created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_approvals_tenant ON approval_requests(tenant_id, status);

-- Append-only. No UPDATE/DELETE path exists in the store API.
CREATE TABLE IF NOT EXISTS audit_log (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    tenant_id      TEXT NOT NULL,
    actor          TEXT NOT NULL,
    action         TEXT NOT NULL,
    tool_call      TEXT NOT NULL DEFAULT '{}', -- JSON
    result_summary TEXT NOT NULL DEFAULT '',
    timestamp      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_audit_tenant ON audit_log(tenant_id, id);

CREATE TABLE IF NOT EXISTS connector_credentials (
    id                  TEXT PRIMARY KEY,
    tenant_id           TEXT NOT NULL REFERENCES tenants(id),
    connector_name      TEXT NOT NULL,
    encrypted_value     BLOB NOT NULL,
    oauth_refresh_token BLOB,
    expires_at          TEXT,
    created_at          TEXT NOT NULL,
    UNIQUE(tenant_id, connector_name)
);

CREATE TABLE IF NOT EXISTS usage_records (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    tenant_id     TEXT NOT NULL,
    brand_id      TEXT,
    session_id    TEXT,
    engine        TEXT,
    model         TEXT,
    skills        TEXT NOT NULL DEFAULT '[]',
    input_tokens  INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0,
    cache_read_tokens INTEGER NOT NULL DEFAULT 0,
    cache_write_tokens INTEGER NOT NULL DEFAULT 0,
    cost_usd      REAL NOT NULL DEFAULT 0,
    created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_usage_tenant ON usage_records(tenant_id, id);

CREATE TABLE IF NOT EXISTS onboarding_codes (
    code        TEXT PRIMARY KEY,
    tenant_id   TEXT NOT NULL REFERENCES tenants(id),
    expires_at  TEXT NOT NULL,
    used_at     TEXT
);

CREATE TABLE IF NOT EXISTS schema_migrations (
    version     TEXT PRIMARY KEY,
    applied_at  TEXT NOT NULL
);
