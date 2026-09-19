"""Load SKILL.md files (YAML front matter + markdown body) and render them.

Skills contain no engine-specific syntax. Rendering only substitutes the brand
context block; the body is otherwise passed through verbatim.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

from data.models import Brand

FRONT_MATTER_DELIM = "---"


@dataclass(frozen=True)
class SkillMeta:
    name: str
    description: str
    triggers: tuple[str, ...] = ()
    tools: tuple[str, ...] = ()
    requires_brand: bool = True
    ported: bool = False
    tier: str | None = None


@dataclass
class Skill:
    meta: SkillMeta
    body: str
    path: Path


@dataclass
class SkillCatalog:
    """All skill descriptions (for routing) plus the subset with SKILL.md (runnable)."""

    skills_dir: Path
    metas: dict[str, SkillMeta] = field(default_factory=dict)

    @classmethod
    def load(cls, skills_dir: Path) -> "SkillCatalog":
        cat = cls(skills_dir=skills_dir)
        index_path = skills_dir / "index.json"
        if index_path.is_file():
            index = json.loads(index_path.read_text(encoding="utf-8"))
            for s in index.get("skills", []):
                cat.metas[s["name"]] = SkillMeta(
                    name=s["name"], description=s.get("description", ""),
                    triggers=tuple(s.get("triggers", [])), tier=s.get("tier"), ported=False,
                )
        # SKILL.md files override / extend the index and mark the skill as ported.
        for skill_md in sorted(skills_dir.glob("*/SKILL.md")):
            fm, _ = parse_skill_file(skill_md)
            name = fm.get("name") or skill_md.parent.name
            base = cat.metas.get(name)
            cat.metas[name] = SkillMeta(
                name=name,
                description=fm.get("description") or (base.description if base else ""),
                triggers=tuple(fm.get("triggers") or (base.triggers if base else ())),
                tools=tuple(fm.get("tools") or ()),
                requires_brand=bool(fm.get("requires_brand", True)),
                ported=True,
                tier=base.tier if base else fm.get("tier"),
            )
        return cat

    def ported(self) -> list[SkillMeta]:
        return [m for m in self.metas.values() if m.ported]

    def get(self, name: str) -> Skill:
        meta = self.metas.get(name)
        if meta is None or not meta.ported:
            raise KeyError(f"skill {name!r} is not ported (no SKILL.md)")
        path = self.skills_dir / name / "SKILL.md"
        _, body = parse_skill_file(path)
        return Skill(meta=meta, body=body.strip(), path=path)


def parse_skill_file(path: Path) -> tuple[dict[str, Any], str]:
    text = path.read_text(encoding="utf-8")
    if not text.startswith(FRONT_MATTER_DELIM):
        return {}, text
    parts = text.split("\n" + FRONT_MATTER_DELIM + "\n", 1)
    if len(parts) != 2:
        return {}, text
    fm_text = parts[0][len(FRONT_MATTER_DELIM):]
    fm = yaml.safe_load(fm_text) or {}
    return fm, parts[1]


def render_brand_context(brand: Brand | None) -> str:
    if brand is None:
        return ("## Brand context\n\nNo brand profile is configured for this workspace yet. "
                "Ask for the essentials (brand name, what it does, audience, voice) before producing "
                "brand-specific output, or proceed with clearly labelled defaults.")
    lines = [f"## Brand context: {brand.name}", ""]
    if brand.voice_profile:
        lines.append("Voice profile: " + json.dumps(brand.voice_profile, ensure_ascii=False))
    if brand.competitors:
        lines.append("Competitors: " + ", ".join(brand.competitors))
    if brand.guidelines:
        lines.append("Guidelines:\n" + brand.guidelines.strip())
    return "\n".join(lines)


BASE_SYSTEM_PROMPT = """You are a senior marketing operator working inside a multi-tenant marketing automation platform.

Ground rules:
- Use the skill instructions below as your operating procedure for this request.
- Use the provided tools for any calculation, scoring or external action; never fabricate numbers a tool would produce.
- Actions that send, publish, spend or write to external systems require explicit human approval. The platform enforces this: when a tool result says the action was rejected, do not retry it and do not work around it.
- Never claim volume, ranking, or performance data that no tool or the user supplied. Say what is missing.
- Write for a chat interface: lead with the deliverable, keep sections short, use plain markdown (no tables wider than four columns)."""


def render_system_prompt(skills: list[Skill], brand: Brand | None, extra: str | None = None) -> str:
    parts = [BASE_SYSTEM_PROMPT, render_brand_context(brand)]
    for s in skills:
        parts.append(f"# Skill: {s.meta.name}\n\n{s.body}")
    if extra:
        parts.append(extra)
    return "\n\n".join(parts)
