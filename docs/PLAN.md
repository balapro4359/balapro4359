# Product plan: best-of-catalogue skills on deterministic pipelines

Status: proposal, September 2026. Companion data: `skills/catalog_plan.json`
(disposition of every upstream skill; consumed by the M8 porter).

## 1. Principles

1. **Script what can be verified; spend model tokens only on judgment.** Audits,
   calculators, monitors and reports run as deterministic pipelines. The model
   writes the narrative and makes recommendations; it never produces the numbers.
2. **One orchestrator, many surfaces.** Telegram and the web UI are both
   `ChannelAdapter`s. Every run, approval and output is visible from either.
3. **The engine seam holds.** Pipelines, personas, routines and the UI sit on
   `orchestration/interface.py`. The LangGraph swap remains a one-file change.
4. **Every write is gated.** Send, publish, spend and sync steps pause for a
   human, on whichever surface the human is on.
5. **Tenant-scoped everything**, including snapshots, outputs and budgets.

## 2. Catalogue disposition (163 upstream skills)

| Disposition | Count | Meaning |
|---|---|---|
| Pipeline | 40 | deterministic steps, model narrates; 9 run as scheduled routines, 6 are approval-gated |
| Prompt skill | 44 | judgment and creative work, with tools available |
| Chain | 3 | multi-step programs: `engagement-workflow`, `content-engine`, `launch-campaign` |
| Merged into another skill | 33 | triggers carried over so routing still catches every phrasing |
| Replaced by a platform feature | 46 | setup, memory, dashboards, delivery, self-evaluation |

Net: **87 runnable skills** plus 3 new merged targets (`ai-search-audit`,
`ai-search-monitor`, `localization-audit`). The full table is in section 9.

Specialist agents: all 24 are ported as **personas** (system-prompt profiles).
Skills declare which personas they use; users can also address a persona directly.

## 3. Architecture additions

- **Pipeline skill type** (`orchestration/pipeline.py`): a Python-defined list
  of steps. Step kinds: `tool` (deterministic), `llm` (model call with a required
  JSON schema and a chosen model tier), `gate` (approval checkpoint), `narrate`
  (final model call that writes for the audience). Pipelines run through the
  orchestrator, so the gate, audit log and usage costing are unchanged.
- **Personas** (`skills/personas/*.md`): rendered into the system prompt when a
  skill names them or the user picks one.
- **Chains**: ordered skills with handoff of outputs, one approval per gated step,
  resumable after a rejection.
- **Snapshots** (`data`): tenant-scoped time series per monitor so routines only
  wake the model when something changed.
- **Routines**: cron-scheduled pipeline runs per brand with delivery to Telegram,
  Slack or email. Backed by the existing rate limiter and budget cap.
- **Outputs library**: every deliverable stored with inputs, skill, cost, gate
  results; re-runnable; exportable as Markdown or PDF.
- **Model tiers**: pipelines narrate on Sonnet 5 (Haiku 4.5 for monitors);
  prompt skills and chains use Opus 5. Per-tenant override stays.
- **Quality gates as code**: crawl coverage, voice distance, AI-tell density,
  claim verification, spam risk. A gate result is data on the output, not prose.

## 4. Tools roadmap

Existing: 16 tools (calculators, scorers, SEO fetch, gated writers).
Referenced by the plan: 66. To build: 51, in four groups.

| Group | Tools | Source |
|---|---|---|
| Wrap upstream stdlib scripts | ad_budget_pacer, ai_visibility_checker, audience_simulator, backlink_gap, calendar_validator, campaign_health_monitor, churn_predictor, claim_verifier, competitor_tracker, content_repurposer, creative_fatigue_predictor, form_analyzer, geo_tracker, growth_loop_modeler, hallucination_detector, hashtag_analyzer, intelligence_graph, journey_engine, link_profile_analyzer, local_seo_checker, macro_signal_tracker, narrative_mapper, posting_time_analyzer, review_response_drafter, revenue_forecaster, revenue_simulator, schema_generator, send_time_optimizer, seo_drift, seo_executor, social_post_formatter, ai_tell_scan | verbatim copies with attribution, same pattern as `tools/ported/` |
| Reimplement (upstream needs nltk/textstat/bs4) | readability_score, brand_voice_score, competitor_scraper, fetch_page | small stdlib implementations |
| Platform tools | csv_ingest, snapshot_save, snapshot_compare, anomaly_detect, cohort_calc, funnel_calc, hreflang_check, save_brand_profile, save_product, save_template | new, deterministic |
| Connectors | ga4_read, gsc_read, ads_read, rank_read (read); publish_cms, send_sms, enable_automation (gated writes); real executors for send_email_campaign, crm_sync_contacts, launch_ad_campaign, schedule_social_post | per-tenant credentials from the vault |

## 5. Web UI

Server-rendered FastAPI + HTMX in this repo, one SSE endpoint for streaming.
Magic-link login; users, memberships, roles (owner, admin, approver, member).
Telegram chats link to a user, so approvals are attributed to a person.

Pages: skill catalogue with guided run forms · specialists · chat with uploads ·
runs and outputs library · chains and routines · approvals inbox · brand editor ·
products (manual, CSV, website extraction) · templates and rules · connectors
(API key + OAuth callback) · usage and budget · audit · team and Telegram linking.

Telegram keeps parity for control: `/skills`, `/<skill>`, approvals, routine
delivery, `/brand`, `/usage`.

## 6. Milestones and acceptance

| # | Milestone | Done when |
|---|---|---|
| M8 | Catalogue and pipelines (wk 1-2) | Pipeline type shipped; porter imports the 87 skills and 24 personas from `catalog_plan.json`; stdlib tools wrapped; the 40 pipelines have golden-output tests; every skill runnable from Telegram |
| M9 | Foundation (wk 3) | Schema (users, memberships, products, templates, rules, snapshots, outputs, routines, persisted approvals); save tools; cross-surface approvals; FastAPI, login, tenant/brand switcher; catalogue + guided run forms |
| M10 | Customisation (wk 4) | Brand editor, products with CSV and website extraction, templates and rules enforced in prompts, connectors page with OAuth callback, specialists page |
| M11 | Operate (wk 5) | Web chat with streaming and uploads, outputs library, chains and routines with scheduling, approvals inbox, usage with budget cap, audit viewer, team |
| M12 | Production (wk 6) | Postgres, Docker + Caddy HTTPS, read connectors (GA4, GSC), real executors for one ESP, one CRM, Slack; recorded-response tests; error reporting; first client workspace live |

## 7. Cost model (per run, Anthropic list prices)

| Run type | Model | Typical cost |
|---|---|---|
| Monitor routine, no change | Haiku 4.5 or none | under $0.01 |
| Pipeline with narrative | Sonnet 5 | $0.01 to $0.05 |
| Prompt skill | Opus 5 | $0.05 to $0.30 |
| Chain (engagement-workflow) | Opus 5 | $3 to $8 |

Budget cap per tenant with an 80 percent warning; plan tiers map to caps.

## 8. Risks

- **Upstream content drift**: skills embed dated guidance (algorithm updates,
  model names). The porter strips time-boxed blocks; a quarterly review re-checks.
- **Read connectors**: rank, GSC and GA4 data need OAuth; without them, the
  monitors run on uploads only. Ship upload-first.
- **Approval fatigue**: chains can raise several approvals; batch them per
  channel step and show cost totals.
- **Model behaviour on pipelines**: enforce JSON schemas on every `llm` step and
  validate before the next tool runs.

## 9. Full disposition table

| Skill | Disposition | Tools | Note |
|---|---|---|---|
| content-engine | chain (gated) | fetch_page, readability_score, ai_tell_scan, brand_voice_score, claim_verifier, publish_cms | brief → draft → score → humanize gates → gated publish |
| engagement-workflow | chain |  | flagship 12-part strategy chain: brand-setup → audience-profile → competitor-analysis → seo-audit → campaign-plan → content-calendar → performance-report |
| launch-campaign | chain (gated) | utm_build, launch_ad_campaign, send_email_campaign, schedule_social_post | one approval per channel step |
| ab-test-plan | pipeline | ab_sample_size, ab_significance |  |
| ai-search-audit | pipeline | ai_visibility_checker, schema_generator, seo_audit_urls | NEW merged skill |
| ai-search-monitor | pipeline (routine) | geo_tracker, gsc_read, snapshot_compare | NEW merged skill |
| analytics-insights | pipeline | csv_ingest, anomaly_detect |  |
| anomaly-scan | pipeline (routine) | csv_ingest, anomaly_detect, snapshot_compare |  |
| attribution-model | pipeline | roi_calculate, csv_ingest |  |
| backlink-gap | pipeline | backlink_gap, csv_ingest | needs link export upload or Ahrefs read connector |
| budget-optimizer | pipeline | budget_optimize, ad_budget_pacer |  |
| campaign-audit | pipeline | campaign_health_monitor, ads_read |  |
| churn-risk | pipeline | churn_predictor, csv_ingest |  |
| cohort-analysis | pipeline | csv_ingest, cohort_calc |  |
| competitor-monitor | pipeline (routine) | competitor_tracker, fetch_page, snapshot_compare |  |
| content-decay-scan | pipeline (routine) | gsc_read, seo_drift, snapshot_compare | needs GSC read connector |
| content-repurpose | pipeline | content_repurposer, social_post_formatter |  |
| creative-health | pipeline | creative_fatigue_predictor, ads_read |  |
| crm-sync | pipeline (gated) | crm_sync_contacts, csv_ingest |  |
| focus-group | pipeline | audience_simulator |  |
| funnel-audit | pipeline | csv_ingest, funnel_calc |  |
| intelligence-report | pipeline | intelligence_graph, macro_signal_tracker |  |
| landing-page-audit | pipeline | seo_audit_urls, form_analyzer, readability_score, headline_score |  |
| local-seo-audit | pipeline | local_seo_checker, fetch_page |  |
| localization-audit | pipeline | hreflang_check, readability_score | NEW merged skill |
| market-weather | pipeline (routine) | macro_signal_tracker |  |
| marketing-automation | pipeline (gated) | journey_engine, enable_automation |  |
| message-test | pipeline | audience_simulator, headline_score |  |
| narrative-tracker | pipeline (routine) | narrative_mapper, snapshot_compare |  |
| performance-check | pipeline (routine) | ga4_read, ads_read, snapshot_save | needs read connectors |
| performance-report | pipeline | csv_ingest, roi_calculate, anomaly_detect, ab_significance | narrative for exec or tactical audience |
| rank-monitor | pipeline (routine) | rank_read, snapshot_compare | needs rank/SERP read connector |
| review-response | pipeline | review_response_drafter |  |
| roi-calculator | pipeline | roi_calculate, budget_optimize, clv_calculate |  |
| schedule-social | pipeline (gated) | social_post_formatter, posting_time_analyzer, schedule_social_post |  |
| send-email-campaign | pipeline (gated) | email_spam_check, send_time_optimizer, send_email_campaign |  |
| send-sms | pipeline (gated) | send_sms |  |
| seo-audit | pipeline | seo_audit_urls, link_profile_analyzer, local_seo_checker, headline_score |  |
| seo-drift | pipeline (routine) | seo_drift, snapshot_compare |  |
| seo-implement | pipeline (gated) | schema_generator, seo_executor |  |
| share-of-voice | pipeline | geo_tracker, snapshot_compare |  |
| verify-claims | pipeline | claim_verifier, hallucination_detector |  |
| what-if | pipeline | revenue_simulator, revenue_forecaster |  |
| ad-creative | prompt | headline_score, ab_sample_size |  |
| audience-profile | prompt | audience_simulator |  |
| brand-setup | prompt | save_brand_profile |  |
| campaign-plan | prompt | budget_optimize, utm_build, roi_calculate |  |
| case-study-plan | prompt |  |  |
| client-onboarding | prompt | save_brand_profile |  |
| client-proposal | prompt |  |  |
| competitor-analysis | prompt | seo_audit_urls, headline_score, competitor_scraper, fetch_page |  |
| content-brief | prompt | headline_score, keyword_cluster, fetch_page |  |
| content-calendar | prompt | calendar_validator |  |
| counter-narrative | prompt | narrative_mapper |  |
| creative-testing-framework | prompt | ab_sample_size |  |
| crisis-response | prompt |  |  |
| cro | prompt | form_analyzer, seo_audit_urls |  |
| dark-funnel | prompt |  |  |
| digital-pr | prompt | headline_score |  |
| email-sequence | prompt | email_subject_score, email_spam_check |  |
| emerging-channels | prompt |  |  |
| funnel-architect | prompt | journey_engine |  |
| goal-filter | prompt |  |  |
| growth-engineering | prompt | growth_loop_modeler |  |
| growth-plan | prompt |  |  |
| influencer-brief | prompt |  |  |
| influencer-creator | prompt |  |  |
| journey-design | prompt | journey_engine |  |
| keyword-research | prompt | keyword_cluster, gsc_read |  |
| lead-magnet-ideas | prompt |  |  |
| martech-audit | prompt |  |  |
| narrative-landscape | prompt | narrative_mapper |  |
| paid-advertising | prompt | ad_budget_pacer |  |
| pricing-test | prompt | ab_sample_size |  |
| programmatic-seo | prompt |  |  |
| qbr-plan | prompt |  |  |
| reputation-management | prompt | review_response_drafter |  |
| retargeting-strategy | prompt |  |  |
| seo-plan | prompt |  |  |
| signal-mine | prompt |  |  |
| social-strategy | prompt | hashtag_analyzer, posting_time_analyzer |  |
| story-mine | prompt |  |  |
| translate-content | prompt |  |  |
| video-packaging | prompt | headline_score |  |
| video-script | prompt |  |  |
| webinar-plan | prompt |  |  |
| yearly-planner | prompt |  |  |
| aeo-audit | merge → ai-search-audit |  |  |
| aeo-geo | merge → ai-search-audit |  |  |
| attribution-report | merge → performance-report |  |  |
| audience-intelligence | merge → audience-profile |  |  |
| campaign-orchestrator | merge → campaign-plan |  |  |
| client-report | merge → performance-report |  |  |
| client-validation-document | merge → client-proposal |  |  |
| competitor-alerts | merge → competitor-monitor |  |  |
| competitor-pages | merge → competitor-analysis |  |  |
| entity-audit | merge → ai-search-audit |  |  |
| exec-summary | merge → performance-report |  |  |
| geo-monitor | merge → ai-search-monitor |  |  |
| gsc-ai-performance | merge → ai-search-monitor |  |  |
| hreflang-check | merge → localization-audit |  |  |
| image-seo-audit | merge → seo-audit |  |  |
| keyword-cluster | merge → keyword-research |  |  |
| language-audit | merge → localization-audit |  |  |
| launch-ad-campaign | merge → launch-campaign |  |  |
| launch-plan | merge → campaign-plan |  |  |
| local-seo | merge → local-seo-audit |  |  |
| localize-campaign | merge → translate-content |  |  |
| media-plan | merge → campaign-plan |  |  |
| multilingual-score | merge → localization-audit |  |  |
| page-seo-analysis | merge → seo-audit |  |  |
| pr-pitch | merge → digital-pr |  |  |
| publish-blog | merge → content-engine |  |  |
| redirect-manager | merge → seo-implement |  |  |
| segment-audience | merge → audience-profile |  |  |
| serp-tracker | merge → rank-monitor |  |  |
| simulate | merge → what-if |  |  |
| sitemap-manager | merge → seo-implement |  |  |
| tech-seo-audit | merge → seo-audit |  |  |
| technical-seo | merge → seo-audit |  |  |
| add-integration | drop |  | connectors page |
| agency-dashboard | drop |  | usage page |
| autopilot-status | drop |  | routines page |
| budget-tracker | drop |  | usage & budget page |
| c2pa-metadata | drop |  | tool in publish pipeline |
| campaign-status | drop |  | runs/outputs page |
| check | drop |  | pre-publish quality gate in publish pipelines |
| connect | drop |  | connectors page |
| context-engine | drop |  | brand context + compliance rules rendering |
| continuous-improvement-loop | drop |  | routines |
| cowork-setup | drop |  | n/a (web app) |
| credential-switch | drop |  | connectors page |
| data-export | drop |  | outputs library export |
| data-import | drop |  | file upload |
| eval-config | drop |  | internal eval harness |
| eval-content | drop |  | quality gates |
| eval-suite | drop |  | internal eval harness |
| executive-dashboard | drop |  | usage page |
| four-core-documents | drop |  | engagement-workflow outputs |
| help | drop |  | skill catalogue page + /skills |
| import-guidelines | drop |  | brand editor |
| import-sop | drop |  | templates & rules |
| import-template | drop |  | templates & rules |
| integrations | drop |  | connectors page |
| language-config | drop |  | brand settings |
| lead-import | drop |  | file upload + crm-sync |
| learn | drop |  | catalogue docs |
| live-dashboard | drop |  | usage page |
| loop-detect | drop |  | orchestrator safeguard |
| pdf-report | drop |  | outputs library PDF render |
| pipeline-update | drop |  | outputs library |
| prompt-test | drop |  | internal eval harness |
| quality-report | drop |  | quality gates on outputs |
| recall | drop |  | brand store |
| region-config | drop |  | brand settings |
| save-knowledge | drop |  | brand store (notes) |
| search-knowledge | drop |  | brand store search |
| send-notification | drop |  | routine delivery (Telegram/Slack) |
| send-report | drop |  | routine delivery |
| sop-library | drop |  | templates & rules |
| status | drop |  | runs page |
| switch-brand | drop |  | brand switcher + /brand |
| sync-memory | drop |  | database |
| team-assign | drop |  | team page |
| validate-output | drop |  | quality gates |
| validate-profile | drop |  | brand editor validation |
