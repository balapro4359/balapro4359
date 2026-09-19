from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from channels.interface import ApprovalChoice, ChannelAdapter, IncomingMessage  # noqa: E402
from config.settings import Settings, load_settings  # noqa: E402
from connectors.vault import InMemoryVault  # noqa: E402
from data.store import Store  # noqa: E402
from orchestration.approval_gate import ApprovalGate  # noqa: E402
from orchestration.engines.fake_engine import FakeEngine  # noqa: E402
from orchestration.orchestrator import Orchestrator  # noqa: E402
from skills.loader import SkillCatalog  # noqa: E402
from tools.registry import default_registry  # noqa: E402


class RecordingChannel(ChannelAdapter):
    """Channel test double: records sends, answers approvals from a queue."""

    name = "test"

    def __init__(self, decisions: list[ApprovalChoice] | None = None) -> None:
        self.sent: list[tuple[str, str]] = []
        self.docs: list[tuple[str, str, str]] = []
        self.prompts: list[tuple[str, str, str]] = []
        self.decisions = list(decisions or [])

    async def receive(self, raw_payload: dict) -> IncomingMessage:
        return IncomingMessage(chat_ref=str(raw_payload.get("chat", "c1")), text=raw_payload.get("text", ""))

    async def send_text(self, chat_ref: str, text: str) -> None:
        self.sent.append((chat_ref, text))

    async def send_document(self, chat_ref: str, file_path: str, caption: str) -> None:
        self.docs.append((chat_ref, file_path, caption))

    async def send_approval_prompt(self, chat_ref: str, action_summary: str, cost_estimate: str) -> ApprovalChoice:
        self.prompts.append((chat_ref, action_summary, cost_estimate))
        return self.decisions.pop(0) if self.decisions else ApprovalChoice.REJECT


@pytest.fixture
def settings(tmp_path) -> Settings:
    base = load_settings(dotenv=tmp_path / "nonexistent.env")
    return Settings(**{**base.__dict__, "database_url": "sqlite:///:memory:", "engine": "fake",
                       "skills_dir": ROOT / "skills", "workdir": tmp_path, "log_level": "WARNING"})


@pytest.fixture
def store() -> Store:
    s = Store(":memory:")
    yield s
    s.close()


@pytest.fixture
def catalog() -> SkillCatalog:
    return SkillCatalog.load(ROOT / "skills")


@pytest.fixture
def tenant_session(store):
    t = store.create_tenant("Acme Inc")
    b = store.create_brand(t.id, "Acme", voice_profile={"formality": 7}, competitors=["Globex"])
    s = store.create_session(t.id, "test", "chat-1", b.id)
    return t, b, s


def make_orchestrator(engine, store, catalog, settings, gate=None) -> Orchestrator:
    return Orchestrator(engine=engine, store=store, catalog=catalog, registry=default_registry(),
                        gate=gate or ApprovalGate(store, timeout_seconds=2), settings=settings, vault=InMemoryVault())


@pytest.fixture
def orchestrator_factory(store, catalog, settings):
    def _make(engine: FakeEngine | None = None, gate: ApprovalGate | None = None) -> Orchestrator:
        return make_orchestrator(engine or FakeEngine(), store, catalog, settings, gate)
    return _make
