from pathlib import Path

import pytest

from orchestration.router import Router
from skills.loader import parse_skill_file, render_system_prompt

PRIORITY = ["seo-audit", "campaign-plan", "content-brief", "competitor-analysis", "keyword-research",
            "brand-setup", "performance-report", "email-sequence", "ad-creative", "roi-calculator"]

ATTRIBUTION = "Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee)"


def test_ten_priority_skills_are_ported_with_attribution(catalog):
    for name in PRIORITY:
        meta = catalog.metas[name]
        assert meta.ported, name
        skill = catalog.get(name)
        assert ATTRIBUTION in skill.path.read_text(encoding="utf-8"), name
        assert meta.triggers, name


def test_skill_files_have_no_plugin_specific_syntax(catalog):
    for meta in catalog.ported():
        text = catalog.get(meta.name).path.read_text(encoding="utf-8")
        for needle in ("${CLAUDE_PLUGIN_ROOT}", "~/.claude-marketing", "/digital-marketing-pro:", "CLAUDE_PLUGIN_DATA"):
            assert needle not in text, f"{meta.name} still references {needle}"


def test_skill_tools_exist_in_registry(catalog):
    from tools.registry import default_registry
    reg = default_registry()
    for meta in catalog.ported():
        for t in meta.tools:
            assert reg.has(t), f"{meta.name} references unknown tool {t}"


def test_catalog_carries_full_index_for_routing(catalog):
    assert len(catalog.metas) >= 150
    assert sum(1 for m in catalog.metas.values() if m.ported) == len(PRIORITY)


@pytest.mark.parametrize("query,expected", [
    ("Audit my site's SEO for acme.com", "seo-audit"),
    ("why did our rankings drop last month?", "seo-audit"),
    ("plan a campaign for our product launch in Q4", "campaign-plan"),
    ("write a brief for a blog post on remote onboarding", "content-brief"),
    ("analyze our competitors: hubspot and mailchimp", "competitor-analysis"),
    ("what keywords should we target for our CRM product", "keyword-research"),
    ("set up a new brand", "brand-setup"),
    ("write the monthly performance report from these numbers", "performance-report"),
    ("build a welcome sequence for trial users", "email-sequence"),
    ("write ad copy for Meta for our new shoes", "ad-creative"),
    ("what's the ROI on this campaign", "roi-calculator"),
    ("/roi-calculator", "roi-calculator"),
])
def test_router_picks_expected_skill(catalog, query, expected):
    matches = Router(catalog).route(query)
    assert matches and matches[0].skill == expected, [(m.skill, m.score) for m in matches]
    assert len(matches) <= 3


def test_router_declines_when_unported_skill_dominates(catalog):
    r = Router(catalog)
    assert r.route("translate this campaign into German") == []
    assert r.last_port_demand is not None and r.last_port_demand.skill == "translate-content"
    assert r.route("hello there") == []


def test_render_system_prompt_is_plain_text(catalog, store):
    t = store.create_tenant("A")
    b = store.create_brand(t.id, "Acme", voice_profile={"formality": 8}, competitors=["Globex"], guidelines="No jargon.")
    prompt = render_system_prompt([catalog.get("seo-audit")], b)
    assert "Brand context: Acme" in prompt and "Globex" in prompt and "No jargon." in prompt
    assert "# Skill: seo-audit" in prompt
    fm, body = parse_skill_file(Path("skills/seo-audit/SKILL.md"))
    assert fm["name"] == "seo-audit" and body.strip().startswith("<!--")
