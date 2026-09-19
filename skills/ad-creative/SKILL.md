---
name: ad-creative
description: "Generate 3-5 ad copy variations per platform — headlines, descriptions, and CTAs formatted to Google, Meta, LinkedIn, TikTok, X, and Pinterest specs — each scored 1-10 with policy-compliance flags, A/B testing groupings, and a message-match check against the landing page. Triggers on \"write ad copy for Meta\", \"give me RSA headline variations\", \"we need LinkedIn ad copy\", \"draft TikTok ad creative\"."
triggers:
  - "ad creative"
  - "ad copy"
  - "write ad copy"
  - "rsa headline"
  - "headline variations"
  - "linkedin ad copy"
  - "tiktok ad"
  - "meta ads copy"
tools: [headline_score, ab_sample_size, launch_ad_campaign]
requires_brand: true
---
<!-- Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) — skills/ad-creative/SKILL.md, stripped of plugin-specific file paths. -->

# Ad Creative

## Purpose

Generate high-performing ad copy variations tailored to specific platforms and formats. Each variation is scored for quality and compliance, with a testing strategy.

## Input required

- **Product/service**
- **Platform(s)**: Google Ads, Meta (Facebook/Instagram), LinkedIn, TikTok, X, Pinterest
- **Ad format**: RSA, single image, carousel, story, etc. (video scripts are a separate skill; this skill owns the copy around the video)
- **Campaign objective**: awareness, traffic, leads, conversions, app installs
- **Target audience**
- **Key offer/CTA**
- **Landing page URL** (optional)

## Platform limits (apply strictly)

| Platform | Headline | Description / primary text |
|---|---|---|
| Google RSA | 30 chars, up to 15 headlines | 90 chars, up to 4 descriptions |
| Meta | 40 chars (headline) | 125 chars primary text recommended |
| LinkedIn | 70 chars | 150 chars intro text recommended |
| TikTok | n/a | 100 chars ad text |

## Process

1. Apply the brand context above: voice, banned words, restricted claims, compliance rules for the markets.
2. Identify platform-specific constraints: character limits, format requirements, policy restrictions.
3. Generate 3-5 variations per platform, each with a distinct angle: benefit, urgency, social proof, curiosity, direct.
4. Score each variation on brand alignment, clarity, emotional impact, CTA strength and policy compliance (1-10). Run `headline_score` on every headline and fold its emotional/power-word signal into the score.
5. Flag potential policy violations: restricted claims, prohibited language, before/after promises, personal attributes.
6. Recommend A/B test groupings and priority order; use `ab_sample_size` to say how much traffic each test needs given a realistic baseline CTR or CVR.
7. If a landing page URL is provided, check message match between ad and page.

## Output

Per platform:

- Headlines, descriptions and CTAs formatted to spec with character counts
- Quality score (1-10) with reasoning per variation
- Policy compliance check with flagged issues
- A/B test recommendation with a hypothesis and required sample size
- Message-match assessment (if landing page provided)
- Creative direction notes for visual assets

## AI visual guidance

When the brief includes AI-generated stills or short video: keep the visual spec tool-agnostic (subject, composition, on-image text, brand-character constraints); treat all AI visuals as in scope for EU AI Act transparency obligations until proven otherwise; synthetic humans need visible disclosure in EU markets; recommend C2PA content credentials before EU distribution.

## Launching

Only if the user explicitly asks to launch, call `launch_ad_campaign` with the daily budget and duration. The platform requires the user to approve the spend first; if rejected, report that nothing was launched.
