---
name: competitor-analysis
description: "Run a multi-dimensional competitive teardown of 2-5 competitors — content strategy, SEO, paid ads, social, AI answer-engine visibility, and pricing/positioning — producing a competitor overview matrix, per-competitor SWOT, gap analysis, and strategic recommendations prioritized by opportunity size. Point-in-time analysis, not ongoing tracking. Triggers on \"analyze our competitors\", \"how do we stack up against X\", \"competitive landscape report\", \"what are competitors doing that we aren't\"."
triggers:
  - "competitor analysis"
  - "analyze our competitors"
  - "analyse our competitors"
  - "how do we stack up against"
  - "competitive landscape"
  - "what are competitors doing"
tools: [seo_audit_urls, headline_score]
requires_brand: true
---
<!-- Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) — skills/competitor-analysis/SKILL.md, stripped of plugin-specific file paths. -->

# Competitor Analysis

## Purpose

Deliver a competitive intelligence report across all major marketing dimensions. Identify competitor strengths, weaknesses, strategies and the gaps the brand can exploit.

## Input required

- **Competitors**: 2-5 names and/or URLs (use the brand profile's competitor list if present)
- **Analysis scope**: full or specific dimensions (SEO, content, ads, social, pricing)
- **Battleground keywords**: terms where the brand competes head-to-head
- **Industry/category** for benchmarking

## Process

1. Apply the brand context above, including the brand's own positioning so comparisons are relative to it.
2. **Content analysis**: content types, publishing frequency, top-performing content, gaps, topic authority.
3. **SEO analysis**: run `seo_audit_urls` on each competitor's homepage and one key landing page to compare technical health and on-page basics; score their title tags with `headline_score`. Domain authority, keyword overlap and backlink comparisons require connected data — state what is missing rather than estimating.
4. **Paid advertising**: ad copy themes, landing page strategies, platform focus. Estimated spend only as a labelled range.
5. **Social media**: platform presence, content mix, cadence, engagement patterns.
6. **AI visibility**: how competitors appear in AI answer engines versus the brand.
7. **Pricing and positioning**: pricing models, value proposition, messaging frameworks, market position.
8. Synthesise into opportunities and threats.
9. Produce prioritised recommendations.

## Output

- Competitor overview matrix with key metrics per competitor
- Content strategy comparison with gap analysis
- SEO competitive landscape with keyword and link opportunities
- Paid media intelligence
- Social benchmarking
- AI visibility comparison
- Pricing and positioning map
- SWOT per competitor
- Strategic recommendations prioritised by opportunity size

## Guardrails

- This is a point-in-time analysis; ongoing tracking is a separate capability.
- Distinguish observed facts (from tool results or user-provided data) from inferences.
