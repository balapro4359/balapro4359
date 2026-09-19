---
name: campaign-plan
description: "Generate a complete multi-channel campaign plan document — SMART objectives, audience segments with targeting criteria, channel mix with rationale, a budget allocation table with reach/cost estimates, a phased timeline from pre-launch to wrap-up, a KPI framework, and a risk register. Plans only; it does not launch or modify campaigns. Triggers on \"plan a campaign for our product launch\", \"build the Q3 campaign plan\", \"what channels and budget for lead gen\", \"draft a campaign timeline with KPIs\"."
triggers:
  - "campaign plan"
  - "plan a campaign"
  - "build the q3 campaign plan"
  - "what channels and budget"
  - "campaign timeline with kpis"
  - "product launch campaign"
tools: [budget_optimize, utm_build, roi_calculate]
requires_brand: true
---
<!-- Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) — skills/campaign-plan/SKILL.md, stripped of plugin-specific file paths. -->

# Campaign Plan

## Purpose

Generate a comprehensive multi-channel campaign plan ready for execution: strategic objectives, audience segmentation, channel selection, budget distribution, phased timeline and measurable KPIs. This skill plans; it never launches or edits live campaigns.

## Input required

- **Campaign goal**: awareness, leads, sales, retention, etc.
- **Product/service**: what is being promoted
- **Target audience**: who the campaign is for (or reuse brand personas)
- **Budget**: total or range
- **Timeline**: duration or key dates (launch, event, season)
- **Constraints**: channel restrictions, compliance requirements, creative limits

If more than two of these are missing, ask for them in one message before planning.

## Process

1. Apply the brand context above (voice, industry, target markets, compliance rules for those markets).
2. Clarify the objective and classify it as awareness, consideration or conversion.
3. Define primary and secondary audience segments with targeting parameters.
4. Recommend the channel mix based on audience behaviour, budget and objective. Give a rationale per channel and say which channels you are deliberately excluding.
5. Allocate budget across channels using industry CPM/CPC benchmarks (state them as ranges with the assumption behind each). If the user has historical channel performance, run `budget_optimize` to ground the split in data.
6. Build a phased timeline: pre-launch, launch, sustain, optimise, wrap-up.
7. Define KPIs per channel and overall success metrics with targets. Use `utm_build` to specify the tracking links naming convention.
8. Identify dependencies, risks and contingency actions.
9. Output the full plan in a structured, actionable format.

## Output

- Campaign overview and SMART objectives
- Audience segments with targeting criteria
- Channel strategy with rationale for each channel
- Budget allocation table with expected reach/cost estimates
- Phased timeline with milestones and deliverables
- KPI framework with targets and measurement approach (including UTM conventions)
- Risk register with mitigations

## Guardrails

- Benchmarks are estimates; present ranges, cite the assumption, never a single "true" number.
- Any spend, send or publish action is out of scope for this skill and must be requested separately, where it will require explicit approval.
