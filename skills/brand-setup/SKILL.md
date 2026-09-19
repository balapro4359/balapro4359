---
name: brand-setup
description: "Create or update the brand profile every other skill reads — a quick 5-question or full 17-question interactive setup capturing identity, business model, industry and compliance markets, 4-dimension voice scales, channels, goals, and competitors. Triggers on \"set up a new brand\", \"onboard a new client\", \"switch to another brand\", \"update our brand voice\". Run this first — all marketing skills auto-apply the resulting profile."
triggers:
  - "brand setup"
  - "set up a new brand"
  - "set up my brand"
  - "create a brand profile"
  - "onboard a new client"
  - "update our brand voice"
  - "brand profile"
tools: []
requires_brand: false
---
<!-- Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) — skills/brand-setup/SKILL.md, stripped of plugin-specific file paths and script invocations. Profiles persist in the platform's Brand model; the user applies the final JSON via the workspace admin or the /brand commands. -->

# Brand Setup — Interactive Brand Profiling

## When to use

- The user wants to set up a new brand or client, or update voice, audiences or goals.
- Any marketing skill is requested but the brand context above says no profile exists.

Ask one question at a time; this is a chat interface. Keep each question to two lines.

## Quick setup (5 questions — default)

1. **Brand name** — "What's your brand or business name?"
2. **What you do** — "In one sentence, what does [brand] do?" (infer industry, business model, USP)
3. **Target audience** — "Who is your primary customer?" (infer B2B/B2C, demographics)
4. **Brand voice** — "Pick 3 words that describe how your brand communicates" (map to formality / energy / humour / authority 1-10 scales)
5. **Primary channel** — "Where do you primarily market?"

From these answers populate a full profile with sensible defaults, then say: "Quick profile created. Say 'full brand setup' any time to refine it."

## Full setup (17 questions)

Use when the user asks for a detailed setup or wants to update specific sections.

**Identity**: brand name; elevator pitch; USP; mission and values.
**Business model**: type (B2B SaaS, B2C eCommerce/DTC, B2B services, local business, agency, creator, enterprise, non-profit, marketplace); revenue model; price range and sales cycle.
**Industry and compliance**: industry; regulated? (healthcare, finance, legal, alcohol, cannabis…); target markets (drives compliance rules such as GDPR, CCPA, DPDPA, LGPD, CAN-SPAM, CASL).
**Voice**: formality, energy, humour, authority (1-10 each); 3-5 personality traits; "this-not-that" examples; 2-3 sample snippets that nail the voice.
**Channels and goals**: active channels; #1 goal with target KPIs, budget range and team size.
**Competitors**: 3-5 with name, URL, relationship (direct/indirect/aspirational), known strengths/weaknesses.

## Output

At the end, present the profile as a compact JSON block the platform can store on the brand:

```json
{
  "name": "...",
  "elevator_pitch": "...",
  "usp": "...",
  "business_model": "...",
  "industry": "...",
  "regulated": false,
  "target_markets": ["..."],
  "voice": {"formality": 6, "energy": 6, "humor": 3, "authority": 7, "traits": ["..."], "this_not_that": ["..."]},
  "channels": ["..."],
  "goals": {"primary": "...", "kpis": ["..."], "budget_range": "...", "team_size": "..."},
  "competitors": [{"name": "...", "url": "...", "relationship": "direct"}],
  "ai_disclosure": {"mode": "default", "text": null, "author": null}
}
```

Then confirm: "Brand profile ready for [brand]. All marketing skills will use this context." Explain that `/brand <name>` switches brands and `/newbrand <name>` creates another one (agencies keep one profile per client).

## Important

- Never skip the voice section; it is what makes outputs on-brand.
- Auto-detect compliance rules from the industry and markets and list them back to the user.
