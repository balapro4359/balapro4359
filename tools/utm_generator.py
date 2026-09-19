"""UTM link builder with GA4 channel-grouping validation.

Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) —
wraps scripts/utm-generator.py.
"""
from __future__ import annotations

from typing import Any

from tools.ported import utm_generator as _utm
from tools.registry import ToolContext, tool


@tool(
    "utm_build",
    "Build tagged campaign URLs (utm_source/medium/campaign/content/term) and report which GA4 default channel "
    "grouping each will land in. Accepts one or many link specs.",
    {
        "properties": {
            "links": {
                "type": "array", "minItems": 1, "maxItems": 100,
                "items": {"type": "object", "properties": {
                    "base_url": {"type": "string"}, "source": {"type": "string"}, "medium": {"type": "string"},
                    "campaign": {"type": "string"}, "content": {"type": "string"}, "term": {"type": "string"}},
                    "required": ["base_url", "source", "medium", "campaign"], "additionalProperties": False},
            }
        },
        "required": ["links"],
    },
)
def utm_build(ctx: ToolContext, args: dict[str, Any]) -> dict:
    results = [_utm.build_utm_url(l["base_url"], l["source"], l["medium"], l["campaign"],
                                  l.get("content", ""), l.get("term", "")) for l in args["links"]]
    return {"results": results}


TOOLS = [utm_build]
