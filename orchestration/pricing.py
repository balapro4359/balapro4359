"""Model pricing table (USD per million tokens) and cost computation.

Cache pricing follows the standard Anthropic multipliers: cache writes at
1.25x input, cache reads at 0.1x input. Update the table when prices change.
"""
from __future__ import annotations

from dataclasses import dataclass

from orchestration.interface import TokenUsage


@dataclass(frozen=True)
class ModelPrice:
    input_per_mtok: float
    output_per_mtok: float


PRICING: dict[str, ModelPrice] = {
    "claude-fable-5-1": ModelPrice(10.0, 50.0),
    "claude-fable-5": ModelPrice(10.0, 50.0),
    "claude-opus-5": ModelPrice(5.0, 25.0),
    "claude-opus-4-8": ModelPrice(5.0, 25.0),
    "claude-opus-4-7": ModelPrice(5.0, 25.0),
    "claude-opus-4-6": ModelPrice(5.0, 25.0),
    "claude-sonnet-5": ModelPrice(2.0, 10.0),
    "claude-sonnet-4-6": ModelPrice(3.0, 15.0),
    "claude-haiku-4-5": ModelPrice(1.0, 5.0),
}

CACHE_WRITE_MULTIPLIER = 1.25
CACHE_READ_MULTIPLIER = 0.10


def canonical_model(model: str | None) -> str | None:
    """Map provider-specific or dated ids onto a pricing key (best effort)."""
    if not model:
        return None
    m = model.lower()
    for key in sorted(PRICING, key=len, reverse=True):
        if key in m:
            return key
    return None


def compute_cost_usd(usage: TokenUsage, fallback_model: str | None = None) -> float:
    """Compute cost from token counts; prefer the engine-reported figure when present."""
    if usage.reported_cost_usd is not None:
        return round(usage.reported_cost_usd, 6)
    key = canonical_model(usage.model) or canonical_model(fallback_model)
    if key is None:
        return 0.0
    price = PRICING[key]
    cost = (
        usage.input_tokens * price.input_per_mtok
        + usage.output_tokens * price.output_per_mtok
        + usage.cache_write_tokens * price.input_per_mtok * CACHE_WRITE_MULTIPLIER
        + usage.cache_read_tokens * price.input_per_mtok * CACHE_READ_MULTIPLIER
    ) / 1_000_000
    return round(cost, 6)
