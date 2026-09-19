---
name: content-brief
description: "Create a production-ready content brief a writer can execute without extra context — keyword map (primary, secondary, related questions), H2/H3 outline with key points and word-count targets, brand voice guidance, on-page SEO checklist, visual/media spec with AI-generation and provenance notes, and success metrics. Triggers on \"write a brief for this topic\", \"brief a blog post on X\", \"what should this article cover\", \"outline and SEO requirements for a pillar page\"."
triggers:
  - "content brief"
  - "write a brief"
  - "brief a blog post"
  - "what should this article cover"
  - "outline and seo requirements"
  - "pillar page outline"
tools: [headline_score, keyword_cluster]
requires_brand: true
---
<!-- Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) — skills/content-brief/SKILL.md, stripped of plugin-specific file paths. -->

# Content Brief

## Purpose

Create a production-ready content brief that a writer can execute without additional context: keyword strategy, outline, structural requirements, brand voice guidance and on-page SEO specifications.

## Input required

- **Topic or working title**
- **Content type**: blog post, landing page, pillar page, guide, whitepaper, etc.
- **Target keyword(s)** or a request to research them
- **Target audience**
- **Funnel stage**: awareness, consideration or decision
- **Competitive URLs** (optional): existing content to outperform

## Process

1. Apply the brand context above: voice, restrictions, messaging and compliance rules.
2. Map the keyword landscape: primary keyword, secondary keywords, related questions. If the user supplies a keyword list, run `keyword_cluster` to pick the pillar and spokes. Never invent search volumes; label estimates.
3. Analyse what top-ranking content must cover for the target keyword and identify gaps.
4. Define the content angle and unique value proposition.
5. Build a detailed outline with H2/H3 structure, key points per section and word-count targets.
6. Specify on-page SEO requirements: title tag (score 2-3 options with `headline_score`), meta description, URL slug, internal links, schema markup.
7. Document voice and tone guidance specific to this piece.
8. Define success metrics: target ranking, traffic, engagement, conversions.

## Output

- Target keyword map (primary, secondary, related terms, questions to answer) with placement guidance (title, intro, at least two H2s, conclusion, meta) rather than a density target
- Content outline with heading hierarchy and key points per section
- Word-count target and format specifications
- Brand voice and tone guidance for this piece
- On-page SEO checklist (title, meta, headers, links, schema)
- Visual/media requirements
- Internal and external linking strategy
- Success metrics and measurement plan

## Visual/media spec

If the piece will include AI-generated images, infographics or short video, the brief must state:

- **Provenance marking**: AI assets shipped to EU readers should carry C2PA Content Credentials; default to signing all AI visuals.
- **Synthetic-human flag**: photoreal humans (real or synthetic) need a visible disclosure in EU markets under the AI Act's transparency rules.
- **Editorial-responsibility owner**: for health, finance, elections or public-safety topics, name the human editor who signs off.
- Keep the spec tool-agnostic: describe subject, composition, on-image text and brand-character constraints so any production track can use it.
