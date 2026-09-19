---
name: seo-audit
description: "Run a comprehensive SEO audit across technical health, on-page, content quality, E-E-A-T, link profile, and local SEO — producing a scored report with an impact-by-effort action plan and a quality scorecard. Triggers on \"audit my site's SEO\", \"why did our rankings drop\", \"check our technical SEO health\", \"how strong is our E-E-A-T\". Reads the brand profile; the action plan feeds seo-implement, seo-plan and seo-drift, with link prospecting handed to backlink-gap."
triggers:
  - "seo audit"
  - "audit my site"
  - "audit my site's seo"
  - "why did our rankings drop"
  - "check our technical seo"
  - "technical seo health"
  - "how strong is our e-e-a-t"
tools: [seo_audit_urls, headline_score, keyword_cluster]
requires_brand: true
---
<!-- Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) — skills/seo-audit/SKILL.md, stripped of plugin-specific file paths and script invocations. -->

# SEO Audit

## Purpose

Perform a comprehensive SEO audit that evaluates a website across all major ranking dimensions. Produce a prioritized action plan with estimated impact and effort for each recommendation.

## Input required

Ask for anything missing before doing deep work; proceed with sensible defaults if the user says so:

- **Website URL**: the domain or specific pages to audit
- **Target keywords**: primary keywords the site should rank for (optional)
- **Competitors**: 2-3 competitor URLs for benchmarking (optional)
- **Audit scope**: full site or a specific area (technical, content, local, links)
- **Known issues**: anything the user already suspects

## Process

1. **Apply brand context** from the brand profile above: industry, target markets, business model (local vs national), compliance constraints and voice.
2. **Technical audit**: run `seo_audit_urls` on the homepage plus up to nine representative template URLs (product, category, blog post, landing page). Interpret status codes, redirect chains, title/meta/canonical/robots, HTTPS and security headers, and speed hints. Add what the tool cannot measure (crawlability, indexation, Core Web Vitals, structured data, sitemap) as questions or assumptions, clearly labelled.
3. **On-page audit**: title tags, meta descriptions, heading hierarchy, keyword usage, image alt text, internal linking, URL structure. Use `headline_score` to evaluate title tags and H1s where they are known.
4. **Content audit**: thin content, duplicate content, content gaps, freshness, E-E-A-T signals (author pages, citations, credentials, first-hand experience). If the user supplies a keyword list, run `keyword_cluster` to reveal topical coverage and cannibalisation.
5. **Local SEO** (only if the brand serves specific geographies with a physical presence): Google Business Profile, NAP consistency, local schema, reviews, local links.
6. **Link profile**: own-domain backlink health — anchor distribution, toxic links, velocity. Competitor link-gap prospecting belongs to the backlink-gap skill; do not attempt both here.
7. Score each dimension 1-10.
8. Prioritise findings by impact (high/medium/low) and effort (quick win / medium / major project).
9. Write the report.

## Output

A structured SEO audit report containing:

- Executive summary with an overall health score
- Technical SEO scorecard with specific issues and fixes (cite the tool's per-URL scores)
- On-page findings per page/template
- Content quality assessment with gap analysis
- E-E-A-T evaluation and improvements
- Local SEO assessment (if applicable)
- Link profile analysis with opportunities
- Prioritised action plan (top 20 actions) sorted by impact-to-effort ratio, each with an owner role and an effort estimate

## Quality scorecard

Before declaring the audit ready, check these gates and state which passed:

| Gate | What it checks |
|---|---|
| dimension_completeness | scores filled for all mandatory dimensions (technical, on-page, content, E-E-A-T, link, local-if-applicable) |
| finding_actionability | every high-impact finding has a named owner role and an effort estimate |
| data_provenance | every measured number traces to a tool result or user input; judgement calls are labelled as such |
| algorithm_update_flag | if the user reports volatility that coincides with a known core update, the summary says so and advises against reactive changes for 7-14 days |

## Tips and caveats

- **During a core algorithm update**, say so loudly and do not recommend reactive changes. Findings stay valid; the timing of action does not. Do not assert dates of updates you cannot verify.
- **Do not audit at URL level for sites over 10k pages.** Sample by template, audit one representative URL per template, generalise.
- **E-E-A-T scoring is judgement, not measurement.** Calibrate against the brand's industry: a 7/10 author signal is excellent for SaaS but minimum-viable for a YMYL health publisher.
- **Never guarantee rankings.** Give expected impact ranges and timelines.
- Label every recommendation with the surface it targets: SEO (traditional rankings), AEO (answer engines / featured snippets) or GEO (generative engines and AI answers).
