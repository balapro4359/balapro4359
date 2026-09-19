---
name: keyword-research
description: "Standalone keyword research — expands seeds, classifies search intent, maps keywords to content types, surfaces competitor content gaps, long-tail and SERP-feature opportunities, and delivers a prioritized keyword strategy document. Volume and difficulty come from connected data or the user and are never fabricated. Triggers on \"what keywords should we target\", \"find content gaps versus competitors\", \"expand these seed keywords\", \"which queries have buying intent\". Hands 20+ raw keywords to clustering."
triggers:
  - "keyword research"
  - "what keywords should we target"
  - "find content gaps"
  - "expand these seed keywords"
  - "which queries have buying intent"
  - "seed keywords"
tools: [keyword_cluster]
requires_brand: true
---
<!-- Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) — skills/keyword-research/SKILL.md, stripped of plugin-specific file paths and script invocations. -->

# Keyword Research

## Purpose

Expansion, search-intent classification and competitor gap analysis. Produces a prioritised, intent-classified keyword list with content recommendations. Volume and keyword-difficulty figures come from a connected keyword provider or from the user — this skill surfaces and interprets them, it does not fabricate them.

## Input required

- **Seed keywords or topic** (or a URL to extract themes from)
- **Target audience**: demographics, expertise level, pain points
- **Industry** to contextualise volume and difficulty
- **Competitor domains** (optional, 1-3)
- **Target market/language**
- **Content goals**: traffic, leads, thought leadership, sales, awareness
- **Existing content inventory** (optional) to avoid duplication

## Process

1. Apply the brand context above.
2. **Expand the seed set** into candidates: variants, modifiers, questions, comparisons. If the user pastes provider data (volume, KD), keep it attached to each keyword and record the provider and date. Providers disagree by 20-50%; never present a single point estimate as truth.
3. **Classify intent** for every keyword: informational (how-to, what-is), navigational (brand, product names), commercial (best, reviews, comparison), transactional (buy, pricing, demo, free trial).
4. **Map keywords to content types**: blog post, landing page, pillar page, comparison page, FAQ, video, tool, interactive.
5. **Content gaps vs competitors** if domains were given: which topics they cover that the brand does not.
6. **Long-tail opportunities**: question-based keywords (People Also Ask patterns) and modifiers that are lower-difficulty entry points.
7. **SERP feature opportunities** per primary keyword: featured snippets, PAA, knowledge panels, image packs, video carousels.
8. **Seasonal and trending** keywords requiring time-sensitive scheduling.
9. **Prioritise** on estimated volume, difficulty, business relevance, conversion potential and gap opportunity.
10. Once there are 20+ keywords, run `keyword_cluster` to group them into pillar and spokes with an internal-link map and cannibalisation check.
11. Compile the keyword strategy document.

## Output

- Keyword clusters organised by topic theme with individual keywords
- Volume and difficulty per keyword where supplied (ranges, with source)
- Intent classification per keyword
- SERP feature opportunities per cluster
- Recommended content type and format per cluster
- Priority score (high/medium/low) with rationale
- Content gap analysis vs competitors
- Long-tail and question-based opportunities
- Quick-win keywords flagged for immediate action
- Seasonal or trending opportunities with timing
- Internal linking opportunities between clusters

## Tips and caveats

- Keyword difficulty is a heuristic, not a measurement. KD 60 means competitive, not impossible.
- Long-tail is not always lower volume; AI search rewrites queries, so check the resulting query users typed where data exists.
- Intent beats volume: "buy [product]" at 200/mo is worth more than "what is [product]" at 5,000/mo for most commercial brands.
- Do not re-research the same set quarterly unless the business model, market or competitive landscape changed.
