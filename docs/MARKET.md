# Market check: competition, cracks in the plan, and pricing

Researched September 2026 against `docs/PLAN.md`. Sources are listed at the end.

## 1. Who we compete with

| Segment | Players | Model | Price points |
|---|---|---|---|
| AI writing / content platforms | Jasper, Copy.ai, Writesonic | per seat | $39 to $69 per seat per month; Copy.ai Advanced $249; enterprise custom |
| SEO and AI-visibility suites | Semrush One, Surfer, Ahrefs | per account plus add-ons | Semrush from $139.95 plus $99 AI toolkit; Surfer from $99 |
| Agent builders | Lindy, Relevance AI, Zapier Agents, Relay.app | per seat plus credits | Lindy $50 to $200, agency tier $300 to $1,000; Relevance $19 to $234; Zapier agents $33 add-on |
| CRM-native agents | HubSpot Breeze | outcome based | $0.50 per resolved conversation, $1 per lead, $0.10 per data answer, credits $10 per 1,000 |
| Agency reporting | AgencyAnalytics, Swydo, DashThis, Databox | per client or flat | AgencyAnalytics $20 per client per month (from $59); Swydo flat $69; mid-tier $159 to $479 |
| Free / bundled | Anthropic Marketing plugin in Claude Cowork; the upstream Digital Marketing Pro plugin | included in Claude Pro | $20 per month per user |
| Platform-native execution | Google Ads, Meta, TikTok official Ads MCP servers | free API access | n/a |

## 2. What the market is doing that matters

1. **The skills themselves are commoditised.** Anthropic ships a free Marketing plugin in Cowork (content, campaign briefs, brand voice, competitive analysis, reporting, SEO audits) with HubSpot, Klaviyo, Ahrefs, Canva and Slack connectors, on a $20 plan. The upstream plugin we ported is also free and runs there. "The same skills in a chat" is not a product.
2. **Execution is moving to official MCP servers.** Google (read-only), Meta (29 tools, everything created lands paused, human activation required) and TikTok (plan, launch, optimise end to end) shipped platform-official servers between April and May 2026. Hand-built ad executors are now the wrong investment; governance around official servers is the right one.
3. **Pricing is shifting to outcomes.** HubSpot repriced to per-resolution and per-lead in April 2026; Intercom charges $0.99 per resolution; outcome-priced vendors report far higher margins than usage-priced ones. Category pricing changed at least four times in the first half of 2026.
4. **Agencies already pay per client.** $20 per client per month for reporting alone is an accepted line item, and white-label reports are table stakes in that segment.
5. **Human-in-the-loop is expected, not differentiating on its own.** Relay.app, Lindy and the Meta server all pause for approval. Our edge has to be approvals plus audit plus multi-client isolation as one system, not the pause itself.

## 3. Cracks in the plan and the fixes

| Crack | Why it matters | Fix |
|---|---|---|
| Positioning as "163 skills in chat" | Free alternatives cover the same skills for one user | Position as the **agency operations layer**: many brands, isolated data, role-based approvals, audit, scheduled routines, client-facing delivery, deterministic quality gates. Sell governance and throughput, not prompts. |
| Building ad executors by hand (M12) | Official MCP servers exist and are safer | Add MCP-server support to the engine interface (the direct API engine can attach MCP servers); wrap Meta, Google and TikTok official servers behind the same ApprovalGate; keep hand-built executors only for email and CRM where no official server exists. |
| Telegram before Slack | Agencies and in-house teams live in Slack; Telegram is strong in specific regions and for solo operators | Keep Telegram, ship Slack with the web UI in M11, WhatsApp later. The adapter design makes this sequencing only. |
| No white-label client reporting | A proven $20 per client line item we would otherwise leave to AgencyAnalytics | Outputs library gets white-label PDF, brand logo, scheduled client delivery, in M11. |
| No data moat | Skills and models are available to everyone | Per-brand memory and snapshots (planned), plus anonymised cross-tenant benchmarks (CPA, ROAS, open rates by industry) as the thing only we can offer. Needs a consent flag per tenant. |
| Billing not ready for outcomes | Market is heading there; we meter tokens only | Meter runs by type and outcome now (pipeline run, strategy run, campaign launched, report delivered). The audit log and outputs library already record the events. |
| Pricing volatility | Competitors repriced four times in six months | Plan limits, credit rates and per-brand fees live in config, not code. |

Everything else in the plan holds: pipeline-first execution, the engine seam, per-tenant budgets, and the six-week milestone order.

## 4. Pricing for the finished product

Cost of goods, from the cost model in the plan: a pipeline run is roughly $0.03, a strategy skill $0.15, a full engagement chain $3 to $8. A "run" below means one skill execution; credits map to those.

| Plan | Monthly | Included | For |
|---|---|---|---|
| Starter | $49 | 1 brand, 1 seat, 150 run credits, Telegram + web, all skills, approvals | solo marketer, freelancer |
| Team | $149 | 3 brands, 5 seats, 600 run credits, routines, connectors, Slack | in-house team |
| Agency | $399 plus $25 per additional brand | 10 brands, unlimited seats, 2,500 run credits, roles and approver controls, white-label client reports, scheduled client delivery, audit export | agencies |
| Enterprise | custom, from $1,500 | SSO, dedicated model budget, custom skills, SLA, data residency, benchmark access | 50+ brands |

Metering on top of the included credits:

- Pipeline run 1 credit, strategy run 5 credits, engagement chain 40 credits; overage $0.10 per credit, sold in blocks of 1,000 for $80.
- Outcome add-ons, priced against what competitors charge for the outcome: campaign launched through an official ads server $2; client report delivered $3 (AgencyAnalytics charges $20 per client per month just for the dashboard); email campaign sent $1 plus ESP costs.

Margin check: an Agency tenant using all 2,500 credits at the mix in the plan costs about $60 to $90 in model spend against $399, before hosting. Starter at full use costs about $6 against $49. Both clear 75 percent gross margin with headroom for Opus-heavy tenants, and the per-tenant budget cap bounds the downside.

Anchors: per-seat writing tools at $49 to $69 mean Starter must include real execution, not writing alone, to justify $49. Lindy's agency tier at $300 to $1,000 and AgencyAnalytics at $20 per client set the range for Agency; $399 plus $25 per brand undercuts the combination of an agent builder plus a reporting tool that agencies buy today.

## 5. Decision summary

- Keep the architecture and milestones.
- Change M12: official ads MCP servers behind the gate instead of hand-built ad executors; MCP support in the direct API engine.
- Add to M11: Slack adapter, white-label scheduled client reports.
- Add to M9: run and outcome metering, config-driven plan limits.
- Position and price as the agency operations layer, hybrid platform fee plus credits, with outcome add-ons.

## Sources

- Jasper, Copy.ai, Writesonic pricing: theaiagentindex.com, pikaseo.com, aiworthit.com, netpartners.marketing, jasper.ai/pricing
- HubSpot Breeze outcome pricing: martech.org, hubspot.com company news, resolve247.ai, marketingmary.ai
- Semrush and Surfer pricing: semrush.com/pricing/ai, stackmatix.com, hashmeta.ai
- Lindy, Relevance AI, Zapier agents: cloudtalk.io, lindy.ai/blog, nocode.mba
- Official Ads MCP servers: digiday.com, pymnts.com, digitalapplied.com, natecue.com
- Agency reporting pricing: swydo.com, reportingninja.com, paceads.com
- Claude Cowork Marketing plugin: claude.com/plugins/marketing, techsy.io, getmarketingwithai.substack.com
- Outcome-based pricing benchmarks: aissist.io, withorb.com, sierra.ai, thepricingconundrum.substack.com
