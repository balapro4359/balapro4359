"""A/B testing statistics: sample size and significance.

Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) —
wraps scripts/sample-size-calculator.py and significance-tester.py.
"""
from __future__ import annotations

import math
from typing import Any

from tools.ported import sample_size_calculator as _ss
from tools.ported import significance_tester as _sig
from tools.registry import ToolContext, tool


@tool(
    "ab_sample_size",
    "Required sample size per variant for an A/B test (two-proportion z-test). mde_type 'absolute' means mde is an "
    "absolute rate change (0.05 -> 0.055 is mde 0.005); 'relative' means a fractional lift (0.10 = +10%).",
    {
        "properties": {
            "baseline_rate": {"type": "number", "exclusiveMinimum": 0, "exclusiveMaximum": 1},
            "mde": {"type": "number", "exclusiveMinimum": 0},
            "mde_type": {"type": "string", "enum": ["absolute", "relative"], "default": "absolute"},
            "significance": {"type": "number", "default": 0.95},
            "power": {"type": "number", "default": 0.8},
            "variants": {"type": "integer", "minimum": 2, "default": 2},
            "daily_traffic": {"type": "integer", "minimum": 1},
        },
        "required": ["baseline_rate", "mde"],
    },
)
def ab_sample_size(ctx: ToolContext, args: dict[str, Any]) -> dict:
    baseline = float(args["baseline_rate"])
    mde = float(args["mde"])
    if args.get("mde_type", "absolute") == "relative":
        mde = baseline * mde
    if baseline + mde >= 1:
        raise ValueError("baseline_rate + absolute mde must be less than 1")
    sig, power, variants = float(args.get("significance", 0.95)), float(args.get("power", 0.8)), int(args.get("variants", 2))
    per_variant = _ss.calculate_sample_size(baseline, mde, sig, power)
    total = per_variant * variants
    daily = args.get("daily_traffic")
    days = math.ceil(total / daily) if daily else None
    return {
        "baseline_rate": baseline, "absolute_mde": round(mde, 6), "target_rate": round(baseline + mde, 6),
        "significance": sig, "power": power, "variants": variants,
        "sample_per_variant": per_variant, "total_sample": total, "estimated_days": days,
        "recommendations": _ss.build_recommendations(baseline, mde, per_variant, total, daily, days, variants),
    }


@tool(
    "ab_significance",
    "Test whether an A/B result is statistically significant (two-proportion z-test and chi-squared), with "
    "confidence interval for the difference and a recommendation.",
    {
        "properties": {
            "control_visitors": {"type": "integer", "minimum": 1},
            "control_conversions": {"type": "integer", "minimum": 0},
            "variant_visitors": {"type": "integer", "minimum": 1},
            "variant_conversions": {"type": "integer", "minimum": 0},
            "confidence": {"type": "number", "default": 0.95},
        },
        "required": ["control_visitors", "control_conversions", "variant_visitors", "variant_conversions"],
    },
)
def ab_significance(ctx: ToolContext, args: dict[str, Any]) -> dict:
    cv, cc = int(args["control_visitors"]), int(args["control_conversions"])
    vv, vc = int(args["variant_visitors"]), int(args["variant_conversions"])
    conf = float(args.get("confidence", 0.95))
    z = _sig.z_test_two_proportions(cv, cc, vv, vc)
    chi = _sig.chi_squared_test(cv, cc, vv, vc)
    ci = _sig.confidence_interval_for_diff(cv, cc, vv, vc, conf)
    alpha = 1 - conf
    z_sig = z["p_value"] < alpha
    chi_sig = chi["p_value"] < alpha
    c_rate, v_rate = cc / cv, vc / vv
    return {
        "control_rate": round(c_rate, 5), "variant_rate": round(v_rate, 5),
        "relative_lift_pct": round((v_rate - c_rate) / c_rate * 100, 2) if c_rate else None,
        "z_test": z, "chi_squared": chi, "confidence_interval": ci, "confidence": conf,
        "significant": bool(z_sig and chi_sig),
        "recommendation": _sig.build_recommendation(c_rate, v_rate, z_sig, chi_sig, conf),
    }


TOOLS = [ab_sample_size, ab_significance]
