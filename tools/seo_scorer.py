"""SEO scoring tools: technical URL audit, headline scoring, keyword clustering.

Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) —
wraps scripts/tech-seo-auditor.py, headline-analyzer.py and keyword_cluster.py
(verbatim copies in tools/ported/).
"""
from __future__ import annotations

import asyncio
import csv
import tempfile
from pathlib import Path
from typing import Any

from tools.ported import headline_analyzer as _headline
from tools.ported import keyword_cluster as _kc
from tools.ported import tech_seo_auditor as _tech
from tools.registry import ToolContext, tool

_ALL_CHECKS = ["status", "redirects", "meta", "headers", "security", "speed"]


@tool(
    "seo_audit_urls",
    "Fetch up to 10 URLs and run technical SEO checks (status, redirect chains, title/meta/canonical/robots, "
    "headers, HTTPS/security posture, speed hints). Returns a 0-100 score per URL with categorised issues. "
    "Read-only; makes outbound HTTP requests.",
    {
        "properties": {
            "urls": {"type": "array", "items": {"type": "string"}, "minItems": 1, "maxItems": 10},
            "checks": {"type": "array", "items": {"type": "string", "enum": _ALL_CHECKS}},
            "timeout": {"type": "integer", "minimum": 3, "maximum": 30, "default": 10},
        },
        "required": ["urls"],
    },
)
async def seo_audit_urls(ctx: ToolContext, args: dict[str, Any]) -> dict:
    checks = set(args.get("checks") or _ALL_CHECKS)
    timeout = int(args.get("timeout", 10))
    urls = [u if u.startswith(("http://", "https://")) else f"https://{u}" for u in args["urls"]]
    results = await asyncio.gather(*(asyncio.to_thread(_tech.audit_url, u, checks, timeout) for u in urls))
    scores = [r.get("score", 0) for r in results]
    return {
        "results": list(results),
        "summary": {
            "urls_audited": len(results),
            "average_score": round(sum(scores) / len(scores), 1) if scores else 0,
            "critical_issues": sum(1 for r in results for i in r.get("issues", []) if i.get("severity") == "critical"),
        },
    }


@tool(
    "headline_score",
    "Score headlines/titles for emotional impact, power words, length, reading grade and structural type. "
    "Use for title tags, H1s, email subjects and ad headlines.",
    {"properties": {"headlines": {"type": "array", "items": {"type": "string"}, "minItems": 1, "maxItems": 50}},
     "required": ["headlines"]},
)
def headline_score(ctx: ToolContext, args: dict[str, Any]) -> dict:
    return {"results": [_headline.analyze_headline(h) for h in args["headlines"]]}


@tool(
    "keyword_cluster",
    "Cluster keywords into pillar + spoke groups with intent, priority score, internal-link map and a quality "
    "scorecard. Provide optional per-keyword volume and difficulty (kd) and optional SERP URL lists for "
    "higher-confidence clustering.",
    {
        "properties": {
            "keywords": {
                "type": "array", "minItems": 2, "maxItems": 500,
                "items": {"type": "object", "properties": {
                    "keyword": {"type": "string"}, "volume": {"type": "integer", "minimum": 0},
                    "kd": {"type": "number", "minimum": 0, "maximum": 100}, "intent": {"type": "string"}},
                    "required": ["keyword"], "additionalProperties": False},
            },
            "serps": {"type": "object", "additionalProperties": {"type": "array", "items": {"type": "string"}},
                      "description": "keyword -> top result URLs"},
            "overlap": {"type": "number", "minimum": 0.1, "maximum": 0.9, "default": 0.4},
            "min_volume": {"type": "integer", "minimum": 0, "default": 0},
            "max_kd": {"type": "number", "minimum": 0, "maximum": 100, "default": 100},
        },
        "required": ["keywords"],
    },
)
def keyword_cluster(ctx: ToolContext, args: dict[str, Any]) -> dict:
    import json

    with tempfile.TemporaryDirectory() as tmp:
        csv_path = Path(tmp) / "keywords.csv"
        with csv_path.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=["keyword", "volume", "kd", "intent"])
            w.writeheader()
            for k in args["keywords"]:
                w.writerow({"keyword": k["keyword"], "volume": k.get("volume", 0), "kd": k.get("kd", 0),
                            "intent": k.get("intent", "")})
        serps_path = None
        if args.get("serps"):
            serps_path = Path(tmp) / "serps.json"
            serps_path.write_text(json.dumps(args["serps"]), encoding="utf-8")
        return _kc.cluster(csv_path, serps_path, float(args.get("overlap", 0.4)),
                           int(args.get("min_volume", 0)), float(args.get("max_kd", 100)))


TOOLS = [seo_audit_urls, headline_score, keyword_cluster]
