#!/usr/bin/env python3
"""Admin helpers: tenants, brands, onboarding codes, credentials, audit and usage views."""
from __future__ import annotations

import argparse
import json
import sys

from _bootstrap import build  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list-tenants")
    p = sub.add_parser("create-tenant"); p.add_argument("name"); p.add_argument("--plan", default="free")
    p = sub.add_parser("create-brand"); p.add_argument("tenant_id"); p.add_argument("name")
    p = sub.add_parser("link-code"); p.add_argument("tenant_id"); p.add_argument("--ttl", type=int, default=60)
    p = sub.add_parser("set-credential"); p.add_argument("tenant_id"); p.add_argument("connector"); p.add_argument("value")
    p = sub.add_parser("audit"); p.add_argument("tenant_id"); p.add_argument("--limit", type=int, default=50)
    p = sub.add_parser("usage"); p.add_argument("tenant_id")
    args = ap.parse_args()

    settings, store, vault, orch = build("fake")
    if args.cmd == "list-tenants":
        for t in store.list_tenants():
            print(t.id, t.name, t.plan_tier, [b.name for b in store.list_brands(t.id)])
    elif args.cmd == "create-tenant":
        t = store.create_tenant(args.name, args.plan); print(t.id)
    elif args.cmd == "create-brand":
        b = store.create_brand(args.tenant_id, args.name); print(b.id)
    elif args.cmd == "link-code":
        print(store.create_onboarding_code(args.tenant_id, args.ttl))
    elif args.cmd == "set-credential":
        vault.put(args.tenant_id, args.connector, args.value); print("stored")
    elif args.cmd == "audit":
        for e in store.list_audit(args.tenant_id, args.limit):
            print(e.timestamp, e.actor, e.action, json.dumps(e.tool_call)[:120], "|", e.result_summary[:100])
    elif args.cmd == "usage":
        print(json.dumps(store.usage_summary(args.tenant_id), indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
