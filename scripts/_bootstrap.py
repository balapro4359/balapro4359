"""Shared wiring for the CLI entry points."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config.logging import configure_logging, get_logger  # noqa: E402
from config.settings import Settings, load_settings  # noqa: E402
from connectors.vault import CredentialVault, FernetVault, InMemoryVault  # noqa: E402
from data.store import Store  # noqa: E402
from orchestration.approval_gate import ApprovalGate  # noqa: E402
from orchestration.engines import build_engine  # noqa: E402
from orchestration.orchestrator import Orchestrator  # noqa: E402
from skills.loader import SkillCatalog  # noqa: E402
from tools.registry import default_registry  # noqa: E402


def build(engine_name: str | None = None, settings: Settings | None = None, store: Store | None = None):
    settings = settings or load_settings()
    configure_logging(settings.log_level, settings.log_format)
    store = store or Store(settings.sqlite_path)
    vault: CredentialVault = FernetVault(store, settings.vault_encryption_key) if settings.vault_encryption_key else InMemoryVault()
    name = engine_name or settings.engine
    kwargs = {}
    if name == "claude_sdk":
        kwargs = {"model": settings.default_model, "api_key": settings.anthropic_api_key,
                  "max_turns": settings.max_agent_turns, "workdir": settings.workdir / "agent-work"}
    engine = build_engine(name, **kwargs)
    catalog = SkillCatalog.load(settings.skills_dir)
    orchestrator = Orchestrator(engine=engine, store=store, catalog=catalog, registry=default_registry(),
                                gate=ApprovalGate(store, settings.approval_timeout_seconds), settings=settings, vault=vault)
    return settings, store, vault, orchestrator
