"""ROI, budget-optimisation and CLV tools.

Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) —
wraps scripts/roi-calculator.py, budget-optimizer.py and clv-calculator.py
(verbatim copies in tools/ported/). Deterministic, read-only.
"""
from __future__ import annotations

from types import SimpleNamespace
from typing import Any

from tools.ported import budget_optimizer as _budget
from tools.ported import clv_calculator as _clv
from tools.ported import roi_calculator as _roi
from tools.registry import ToolContext, tool

_CHANNEL_ITEM = {
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "spend": {"type": "number", "minimum": 0},
        "conversions": {"type": "number", "minimum": 0},
        "revenue": {"type": "number", "minimum": 0},
    },
    "required": ["name", "spend", "conversions", "revenue"],
    "additionalProperties": False,
}


def _validate_channels(channels: list[dict]) -> list[dict]:
    data, err = _roi.load_channels(SimpleNamespace(file=None, channels=__import__("json").dumps(channels)))
    if err:
        raise ValueError(err)
    return data


@tool(
    "roi_calculate",
    "Compute per-channel and blended ROI, ROAS, CPA, contribution and LTV:CAC from spend/conversions/revenue, "
    "with attribution weights and budget recommendations. Input order is treated as touch order.",
    {
        "properties": {
            "channels": {"type": "array", "items": _CHANNEL_ITEM, "minItems": 1},
            "attribution": {"type": "string", "enum": sorted(_roi.VALID_MODELS), "default": "last_touch"},
            "ltv": {"type": "number", "exclusiveMinimum": 0, "description": "Average customer lifetime value"},
            "period": {"type": "string"},
        },
        "required": ["channels"],
    },
)
def roi_calculate(ctx: ToolContext, args: dict[str, Any]) -> dict:
    channels = _validate_channels(args["channels"])
    model = args.get("attribution", "last_touch")
    ltv = args.get("ltv")
    total_revenue = sum(c["revenue"] for c in channels)
    metrics = [_roi.calculate_channel_metrics(c, total_revenue, ltv=ltv) for c in channels]
    for m, w in zip(metrics, _roi.apply_attribution(channels, model)):
        m["attribution_weight"] = round(w, 4)
    summary = _roi.calculate_summary(metrics)
    out: dict[str, Any] = {"attribution_model": model, "channels": metrics, "summary": summary,
                           "recommendations": _roi.generate_recommendations(metrics, summary)}
    if args.get("period"):
        out["period"] = args["period"]
    return out


@tool(
    "budget_optimize",
    "Recommend a reallocated channel budget that maximises projected revenue under a diminishing-returns model. "
    "Returns current vs optimised allocation, projected lift and a reserved test budget.",
    {
        "properties": {
            "channels": {"type": "array", "items": _CHANNEL_ITEM, "minItems": 1},
            "total_budget": {"type": "number", "exclusiveMinimum": 0},
            "min_spend": {"type": "number", "minimum": 0, "default": 0},
            "test_budget_pct": {"type": "number", "minimum": 0, "maximum": 50, "default": 10},
        },
        "required": ["channels", "total_budget"],
    },
)
def budget_optimize(ctx: ToolContext, args: dict[str, Any]) -> dict:
    channels = _validate_channels(args["channels"])
    total = float(args["total_budget"])
    min_spend = float(args.get("min_spend", 0))
    test_pct = float(args.get("test_budget_pct", 10))
    allocation, test_budget = _budget.optimise(channels, total, min_spend, test_pct)
    output = _budget.build_output(channels, allocation, test_budget, total)
    output["recommendations"] = _budget.generate_recommendations(channels, output["optimized_allocation"]["channels"], test_budget)
    return output


@tool(
    "clv_calculate",
    "Customer lifetime value: 'simple' (purchase value x frequency x lifespan), 'contractual' (monthly revenue / churn) "
    "or 'cohort' (weighted segments). Includes NPV adjustment and LTV:CAC health when cac is given.",
    {
        "properties": {
            "model": {"type": "string", "enum": ["simple", "contractual", "cohort"]},
            "avg_purchase_value": {"type": "number"},
            "purchase_frequency": {"type": "number", "description": "Purchases per year"},
            "customer_lifespan": {"type": "number", "description": "Years"},
            "monthly_revenue": {"type": "number"},
            "churn_rate": {"type": "number", "description": "Monthly churn as a fraction, e.g. 0.05"},
            "margin": {"type": "number", "default": 100, "description": "Gross margin percent"},
            "discount_rate": {"type": "number", "default": 10, "description": "Annual discount rate percent for NPV"},
            "cac": {"type": "number"},
            "segments": {"type": "array", "items": {"type": "object"}},
        },
        "required": ["model"],
    },
)
def clv_calculate(ctx: ToolContext, args: dict[str, Any]) -> dict:
    import json

    ns = SimpleNamespace(
        model=args["model"],
        avg_purchase_value=args.get("avg_purchase_value"),
        purchase_frequency=args.get("purchase_frequency"),
        customer_lifespan=args.get("customer_lifespan"),
        monthly_revenue=args.get("monthly_revenue"),
        churn_rate=args.get("churn_rate"),
        margin=float(args.get("margin", 100)),
        discount_rate=float(args.get("discount_rate", 10)),
        cac=args.get("cac"),
        segments=json.dumps(args["segments"]) if args.get("segments") is not None else None,
    )
    runner = {"simple": _clv.run_simple, "contractual": _clv.run_contractual, "cohort": _clv.run_cohort}[ns.model]
    return runner(ns)


TOOLS = [roi_calculate, budget_optimize, clv_calculate]
