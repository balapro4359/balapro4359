"""Architectural guardrails: engine SDKs and channel libraries stay behind their seams."""
import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACKAGES = ["orchestration", "skills", "tools", "connectors", "channels", "data", "config", "scripts"]

ENGINE_MODULES = {"claude_agent_sdk", "langgraph", "langchain", "langchain_core", "anthropic"}
CHANNEL_MODULES = {"telegram", "aiogram"}


def _imports(path: Path) -> set[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"))
    names: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            names.update(a.name.split(".")[0] for a in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            names.add(node.module.split(".")[0])
    return names


def _py_files():
    for pkg in PACKAGES:
        yield from (ROOT / pkg).rglob("*.py")


def test_only_engine_modules_import_agent_frameworks():
    offenders = []
    for f in _py_files():
        if ENGINE_MODULES & _imports(f):
            rel = f.relative_to(ROOT).as_posix()
            if not rel.startswith("orchestration/engines/"):
                offenders.append(rel)
    assert offenders == [], offenders


def test_only_telegram_package_imports_telegram():
    offenders = []
    for f in _py_files():
        if CHANNEL_MODULES & _imports(f):
            rel = f.relative_to(ROOT).as_posix()
            if not rel.startswith("channels/telegram/"):
                offenders.append(rel)
    assert offenders == [], offenders


def test_engines_do_not_import_channels_or_telegram():
    for f in (ROOT / "orchestration" / "engines").glob("*.py"):
        assert not ({"channels", "telegram"} & _imports(f)), f


def test_tools_are_not_sdk_decorated():
    for f in (ROOT / "tools").glob("*.py"):
        assert "claude_agent_sdk" not in f.read_text(encoding="utf-8")


def test_ported_files_carry_attribution():
    needle = "Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee)"
    for f in (ROOT / "tools" / "ported").glob("*.py"):
        assert needle in f.read_text(encoding="utf-8"), f
    assert (ROOT / "THIRD_PARTY_NOTICES.md").is_file()


def test_no_print_statements_in_library_code():
    for pkg in ["orchestration", "channels", "data", "connectors", "config", "skills"]:
        for f in (ROOT / pkg).rglob("*.py"):
            tree = ast.parse(f.read_text(encoding="utf-8"))
            calls = [n for n in ast.walk(tree) if isinstance(n, ast.Call) and getattr(n.func, "id", "") == "print"]
            assert not calls, f"print() in {f}"
