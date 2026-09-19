# Product research: what agentic products sell, where the pain is, what to replicate

Researched September 2026. Companion to `docs/PLAN.md` and `docs/MARKET.md`.

## 1. What is actually selling

| Category | Evidence | Verdict |
|---|---|---|
| Vertical front-office agents for local businesses | Avoca (home services) raised $125M+ at ~$1B, 800 to 1,000+ operators at $1,000 to $3,000 per month; Sameday $449 to $789 flat; Arini (dental, YC W24) reports 1M booked appointments; EliseAI (real estate and healthcare scheduling) raised $250M at $2.2B | strongest demand, clearest ROI, vertical agents retain 3 to 5x horizontal tools |
| Customer-service agents (enterprise) | Sierra $200M ARR in nine quarters; Fin and Zendesk at $0.99 to $2 per resolution | real but enterprise sales, not a two-person team's market |
| AI SDR / outbound | 11x and Artisan: 50 to 70 percent churn in 12 months, estimated 70 to 80 percent churn in three months at 11x, output described as "bland, obviously AI" | avoid |
| Generic AI receptionist | 30+ vendors at $49 to $899; built on Retell, Vapi or Bland at $0.10 to $0.30 per minute all-in | commoditised, price war |
| AI chief of staff on WhatsApp or Telegram | Products at $49; no traction evidence | weak willingness to pay |
| Accounts-receivable agents | Enterprise only ($30k to $150k per year, Tesorio); Paraglide reports 34 percent DSO reduction | gap below enterprise exists but sales cycle is finance-led |

## 2. The pain, quantified

- Small business owners spend 16+ hours a week on admin; invoice and payment follow-up is the most common "always behind" task.
- Home-service businesses miss about 27 percent of inbound calls; a missed call is a $300 service call or a $4,500 replacement job that goes to whoever answers next.
- Estimates: 80 percent of deals need five or more follow-ups, most contractors stop after one; median quote conversion is 38 percent; a systematic 5-touch sequence lifts close rate 8 to 12 points; following up within an hour closes 30 to 50 percent more.
- The revenue-model shift: a business that paid $200 a month for software pays $2,000 a month when the agent does the job end to end.

## 3. The gap

Below Avoca ($1,000 to $3,000, sales-led, front office only) and Podium ($500 to $800 real cost, sales-led) sit the majority of contractors: one to ten people, on Jobber ($49 to $249) or Housecall Pro ($59 to $299). Their options are a voice-only receptionist (Sameday, Rosie, Goodcall), a messaging tool that automates but does not decide (Hatch $75 to $149, NiceJob $75), or the field-service app's own AI receptionist add-on. Nobody sells them the thing that makes money: an agent that chases every estimate, texts back every missed call, collects every invoice and asks for every review, with the owner approving from their phone.

## 4. Recommendation: the follow-up agent for home-service contractors

Working name: **Closer**. An AI office manager for HVAC, plumbing, electrical, roofing and similar trades that runs the money-leaking follow-ups, not just the phone.

Modules, in build order:

1. **Never miss**: missed-call text-back within 60 seconds, qualify, offer slots, book into Jobber or Housecall Pro.
2. **Quote closer**: 5-touch estimate follow-up over SMS and email with owner-approved wording; objections and price questions routed to the owner's chat with a one-tap reply.
3. **Get paid**: invoice reminders with payment links, escalating cadence, owner approval before any tone change.
4. **Reputation**: post-job review requests timed to job completion; negative sentiment routed to the owner first.
5. **Reactivation**: seasonal maintenance campaigns to past customers.
6. **Voice** (phase 2): 24/7 answering built on Retell or Vapi, booking into the same pipelines.

Owner interface: SMS, WhatsApp or Telegram for approvals and questions, plus one web page showing money recovered, quotes chased, jobs booked, reviews earned.

Why it fits what is already built: every module is a deterministic pipeline with an approval gate on the outbound step, which is exactly `orchestration/pipeline` plus `approval_gate`; tenancy, audit, budgets, channels and the engine seam carry over unchanged. Voice is a commodity input, not a differentiator.

## 5. Pricing

| Plan | Monthly | Includes |
|---|---|---|
| Starter | $149 | text-only modules 1 to 5, one line, 1,000 messages |
| Pro | $299 | plus voice answering with 300 minutes, two lines |
| Team | $499 | five lines, 1,000 minutes, multi-user approvals |
| Overage | $0.20 per voice minute, $0.02 per message | |

Optional outcome pricing once measured: $10 per booked job from a recovered quote, capped monthly, which mirrors the industry move to outcome pricing and is easy to justify against a $300 to $4,500 job. Cost of goods at Pro: roughly $40 to $90 in voice minutes, $10 to $20 in messaging, under $10 in model spend.

## 6. Risks

- **Field-service apps bundle it.** Jobber and Housecall Pro ship AI receptionist add-ons. Mitigation: be cross-channel (phone, text, email, web forms) and outcome-focused; list in their marketplaces rather than fight them; own the "money recovered" number.
- **Telephony compliance.** A2P 10DLC registration, TCPA consent and opt-out handling are mandatory before the first message. Build in from day one.
- **API access.** Housecall Pro requires the MAX plan or a partner agreement; Jobber's GraphQL API is the cleaner surface. Start with Jobber plus email or CSV fallbacks.
- **Trust.** Wrong bookings and hallucinated answers are the top complaints in the category. Deterministic pipelines and owner approval on anything with money attached are the answer, and the selling point.

## 7. Validation plan (four weeks)

1. One trade, one metro (HVAC or plumbing). Ten contractors from Facebook groups, supplier counters and the Jobber marketplace.
2. Ship modules 1 and 2 only, on Telegram or WhatsApp for the owner, Jobber integration, Twilio messaging.
3. Charge $149 from day one. Measure quotes recovered and jobs booked per contractor.
4. Kill line: fewer than six of ten paying and reporting recovered jobs by week four.

## 8. Alternatives considered

- **Accounts-receivable agent for small professional firms**: real gap under the enterprise tools, but finance-led sales and a slower loop. Second choice.
- **Dental receptionist**: proven (Arini), but practice-management integrations are closed and hard.
- **Generic receptionist, AI SDR, chief of staff**: commoditised, churning, or unproven willingness to pay.
- **Marketing agency operations layer** (`docs/PLAN.md`): defensible but crowded and slower to prove; keep as a later expansion, since the platform is shared.

## Sources

TechCrunch and Clink on AI revenue leaders; Vellum, ALM Corp, NextPhone and SchedulingKit on AI receptionists; Sameday, fieldcamp.ai and serviceagent.ai on Avoca and Sameday pricing; Arini reviews (AInora, Appscribed); Wellington and SaaSMag on vertical retention; SchedulingKit, RevAnalysis, Pear and Level on estimate follow-up; Astucia and WiserReview on Podium; Authencio on NiceJob and Hatch; Medium (Automation Labs), Klariqo and CloudTalk on voice cost per minute; Housecall Pro developer docs and OnCrew on API access; Upwork, Xero and business.com on admin time; TechCrunch and SultanOfSaaS on 11x and Artisan churn.
