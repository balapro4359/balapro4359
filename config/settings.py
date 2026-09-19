"""Environment-driven configuration with per-tenant overrides.

Nothing in this module reads secrets from files in the repository. All values
come from the process environment (optionally populated from a local ``.env``
file that is git-ignored).
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


def _load_dotenv(path: Path) -> None:
    """Minimal .env loader (KEY=VALUE, '#' comments). Never overrides real env."""
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        value = value.split("#", 1)[0].strip().strip('"').strip("'")
        os.environ.setdefault(key.strip(), value)


def _env(name: str, default: str | None = None) -> str | None:
    value = os.environ.get(name)
    return value if value not in (None, "") else default


@dataclass(frozen=True)
class Settings:
    anthropic_api_key: str | None
    telegram_bot_token: str | None
    telegram_webhook_secret: str | None
    database_url: str
    vault_encryption_key: str | None
    default_model: str
    engine: str
    log_level: str
    log_format: str
    rate_limit_per_minute: int
    approval_timeout_seconds: int
    max_agent_turns: int
    skills_dir: Path
    workdir: Path
    tenant_overrides: dict[str, dict[str, Any]] = field(default_factory=dict)

    @property
    def sqlite_path(self) -> str:
        """Resolve DATABASE_URL to a SQLite file path (or ':memory:')."""
        url = self.database_url
        if url.startswith("sqlite:///"):
            return url[len("sqlite:///"):]
        if url in ("sqlite://", "sqlite:///:memory:", ":memory:"):
            return ":memory:"
        raise ValueError(
            f"Phase 1 storage is SQLite only; unsupported DATABASE_URL {url!r}"
        )

    def for_tenant(self, tenant_id: str, overrides: dict[str, Any] | None = None) -> "Settings":
        """Return a copy with per-tenant overrides applied (model, max turns, rate limit)."""
        merged = dict(self.tenant_overrides.get(tenant_id, {}))
        merged.update(overrides or {})
        if not merged:
            return self
        allowed = {"default_model", "max_agent_turns", "rate_limit_per_minute", "approval_timeout_seconds"}
        changes = {k: v for k, v in merged.items() if k in allowed}
        return Settings(**{**self.__dict__, **changes})


def load_settings(dotenv: Path | None = None) -> Settings:
    root = Path(__file__).resolve().parent.parent
    _load_dotenv(dotenv or root / ".env")
    return Settings(
        anthropic_api_key=_env("ANTHROPIC_API_KEY"),
        telegram_bot_token=_env("TELEGRAM_BOT_TOKEN"),
        telegram_webhook_secret=_env("TELEGRAM_WEBHOOK_SECRET"),
        database_url=_env("DATABASE_URL", f"sqlite:///{root / 'var' / 'marketing.db'}") or "",
        vault_encryption_key=_env("VAULT_ENCRYPTION_KEY"),
        default_model=_env("DEFAULT_MODEL", "claude-opus-5") or "claude-opus-5",
        engine=_env("ENGINE", "claude_api") or "claude_api",
        log_level=_env("LOG_LEVEL", "INFO") or "INFO",
        log_format=_env("LOG_FORMAT", "console") or "console",
        rate_limit_per_minute=int(_env("RATE_LIMIT_PER_MINUTE", "20") or 20),
        approval_timeout_seconds=int(_env("APPROVAL_TIMEOUT_SECONDS", "900") or 900),
        max_agent_turns=int(_env("MAX_AGENT_TURNS", "12") or 12),
        skills_dir=Path(_env("SKILLS_DIR", str(root / "skills")) or root / "skills"),
        workdir=Path(_env("WORKDIR", str(root / "var")) or root / "var"),
    )
