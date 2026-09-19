---
name: performance-report
description: "Turn marketing data into a stakeholder-ready performance report: executive summary, channel-by-channel KPI dashboard, trend analysis, anomaly alerts with root-cause hypotheses, and recommendations ranked by expected impact — formatted for an executive or tactical audience. Triggers on \"write the monthly performance report\", \"summarize campaign results for stakeholders\", \"why did performance change last quarter\", \"turn these metrics into a report\"."
triggers:
  - "performance report"
  - "monthly performance report"
  - "summarize campaign results"
  - "summarise campaign results"
  - "why did performance change"
  - "turn these metrics into a report"
  - "results for stakeholders"
tools: [roi_calculate, ab_significance]
requires_brand: true
---
<!-- Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) — skills/performance-report/SKILL.md, stripped of plugin-specific file paths. -->

# Performance Report

## Purpose

Generate a structured marketing performance report that turns raw data into insight: KPI tracking, trend analysis, anomaly detection and prioritised recommendations. This is the narrative layer — it consumes numbers the user pastes or a connected source provides; it does not invent them.

## Input required

- **Reporting period**
- **Channels to cover**
- **Data**: pasted metrics, CSV text, or a note that a connected platform should be queried
- **KPIs of interest** (or channel defaults)
- **Comparison period**: previous period, year-over-year, or a custom benchmark
- **Audience**: executive summary vs tactical detail

## Process

1. Apply the brand context above (goals and KPIs from the profile define "good").
2. Ingest and validate the data; list any gaps or inconsistencies before analysing.
3. Compute core KPIs per channel — traffic, conversions, revenue, ROAS, CPA, engagement, growth. Use `roi_calculate` for spend/conversion/revenue tables so ROI, ROAS and CPA are computed, not estimated. Break out AI-assistant referral traffic (ChatGPT, Gemini, Copilot, Perplexity) as its own line where the data allows.
4. Trend analysis: period-over-period change, trajectory, seasonality.
5. Anomalies: significant spikes or drops with likely root causes. When a change is claimed as an experiment result, verify it with `ab_significance` before calling it a win.
6. Benchmark against industry averages (as ranges) and brand targets.
7. Insights: what worked, what underperformed, and why.
8. Prioritised recommendations for the next period.
9. Format for the requested audience.

## Output

- Executive summary with headline metrics and overall assessment
- Channel-by-channel KPI dashboard with period-over-period comparison
- Trend analysis with the key data points
- Anomaly alerts with root-cause hypotheses
- Top wins and underperformers with context
- Recommendations ranked by expected impact
- Next-period goals and focus areas
