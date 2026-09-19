---
name: roi-calculator
description: "Compute campaign ROI from spend, conversion, and revenue inputs — channel-level ROI/ROAS/CPA/CPL, blended totals, five-model attribution comparison (last-touch, first-touch, linear, time-decay, position-based), LTV payback periods, benchmark ratings, and 2-3 modeled budget-reallocation scenarios, packaged as an executive-ready report. Triggers on \"what's the ROI on this campaign\", \"compare ROAS across channels\", \"is our CAC sustainable against LTV\", \"where should we shift budget\"."
triggers:
  - "roi calculator"
  - "roi on this campaign"
  - "what's the roi"
  - "calculate roi"
  - "compare roas"
  - "roas across channels"
  - "cac sustainable"
  - "where should we shift budget"
  - "ltv:cac"
tools: [roi_calculate, budget_optimize, clv_calculate]
requires_brand: true
---
<!-- Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) — skills/roi-calculator/SKILL.md, stripped of plugin-specific file paths and script invocations. -->

# ROI Calculator

## Purpose

Campaign ROI analysis with multi-touch attribution models, for budget justification, optimisation recommendations and executive reporting.

## Input required

- **Spend by channel**
- **Conversions and revenue by channel**
- **Time period**
- **Attribution model preference** (or compare all five)
- **Customer LTV** (optional)
- **Industry vertical** for benchmark context
- **Conversion definition** (purchase, lead, signup, demo, trial)
- **Costs beyond ad spend** (optional): agency fees, tools, creative production, team time

If spend, conversions and revenue per channel are missing, ask for them as a short table; do not guess.

## Process

1. Apply the brand context above (industry drives which benchmarks apply).
2. Run `roi_calculate` with the channel table. If the user wants a comparison, call it once per attribution model (last_touch, first_touch, linear, time_decay, position_based) and show how credit shifts. Input order is treated as touch order.
3. Report per-channel ROI, ROAS, CPA (and CPL where conversions are leads) and contribution share, plus the blended totals — all from the tool output.
4. If LTV is provided, include LTV:CAC per channel and compute payback periods; `clv_calculate` can derive LTV when the user only has purchase value, frequency and lifespan, or monthly revenue and churn.
5. Compare against industry benchmarks as ranges; rate each channel above / at / below.
6. Identify efficiency opportunities: diminishing returns, channels where more spend could scale, channels where CPA exceeds LTV.
7. Model 2-3 reallocation scenarios with `budget_optimize` (vary total budget or test-budget share) and present projected impact on revenue, conversions and blended CPA.
8. Compile the executive report.

## Output

- Channel-by-channel table: spend, revenue, conversions, ROI, ROAS, CPA/CPL
- Blended ROI and ROAS with totals
- Attribution comparison showing credit distribution shifts
- LTV-adjusted projection and payback analysis (if LTV given)
- Benchmark comparison per channel
- Efficiency analysis
- Reallocation scenarios with projected outcomes
- Underperforming-channel diagnosis with specific actions
- Executive summary with the top three insights and next steps

## Guardrails

- Every number in the report must come from a tool result or the user's input. Recommendations may be judgement; figures may not.
- Attribution weights are advisory metadata per channel; they do not redistribute the reported revenue in the computed metrics. Say so when comparing models.
