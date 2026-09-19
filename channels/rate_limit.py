"""Per-tenant token-bucket rate limiter, applied at the channel adapter level.

Living here (not in the engine) means it applies identically once LangGraph
or any other engine is plugged in.
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field


@dataclass
class _Bucket:
    tokens: float
    updated: float


@dataclass
class TenantRateLimiter:
    per_minute: int = 20
    burst: int | None = None
    _buckets: dict[str, _Bucket] = field(default_factory=dict)

    def _capacity(self) -> float:
        return float(self.burst if self.burst is not None else self.per_minute)

    def allow(self, tenant_id: str, now: float | None = None) -> bool:
        now = time.monotonic() if now is None else now
        cap = self._capacity()
        b = self._buckets.get(tenant_id)
        if b is None:
            b = _Bucket(tokens=cap, updated=now)
            self._buckets[tenant_id] = b
        refill = (now - b.updated) * (self.per_minute / 60.0)
        b.tokens = min(cap, b.tokens + refill)
        b.updated = now
        if b.tokens >= 1.0:
            b.tokens -= 1.0
            return True
        return False

    def retry_after_seconds(self, tenant_id: str) -> float:
        b = self._buckets.get(tenant_id)
        if b is None or b.tokens >= 1.0:
            return 0.0
        return round((1.0 - b.tokens) / (self.per_minute / 60.0), 1)
