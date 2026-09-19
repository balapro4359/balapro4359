---
name: email-sequence
description: "Design a complete, ESP-ready email sequence — per-email subject line options, preview text, body copy with CTAs, send timing, segmentation and branching logic, plus a bulk-sender deliverability checklist (SPF/DKIM/DMARC, one-click unsubscribe, complaint-rate limits). Designs only; sending is a separate approval-gated action. Triggers on \"build a welcome sequence\", \"write a cart abandonment flow\", \"our emails keep landing in spam\", \"nurture sequence for trial users\"."
triggers:
  - "email sequence"
  - "welcome sequence"
  - "cart abandonment"
  - "nurture sequence"
  - "landing in spam"
  - "drip campaign"
  - "onboarding emails"
tools: [email_subject_score, email_spam_check, send_email_campaign]
requires_brand: true
---
<!-- Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) — skills/email-sequence/SKILL.md, stripped of plugin-specific file paths. -->

# Email Sequence

## Purpose

Design a full email sequence ready for implementation in any ESP: subject lines, preview text, body copy, send timing, segmentation rules and deliverability best practices.

## Input required

- **Sequence type**: welcome, nurture, onboarding, re-engagement, cart abandonment, post-purchase, event, promotional
- **Goal**: activate, convert, retain, upsell, educate
- **Audience segment** and entry trigger
- **Number of emails** (or recommend one)
- **Key messages/offers**
- **ESP in use** (Klaviyo, Mailchimp, HubSpot, etc.) for format guidance

## Process

1. Apply the brand context above: voice, restrictions, compliance rules for the target markets.
2. Map the sequence to the customer-journey stage and define the narrative arc.
3. Choose the email count and cadence for the sequence type.
4. Write each email: 2-3 subject line options, preview text, body copy with one clear CTA. Score every subject line with `email_subject_score` and keep the best two per email; report the scores.
5. Define segmentation and branching logic (open/click triggers, conditional paths).
6. Run `email_spam_check` on each body and fix anything above low risk before presenting.
7. Add personalisation tokens and dynamic-content recommendations.
8. Review the whole sequence for voice consistency and regulatory compliance (CAN-SPAM, GDPR, CASL as applicable).

### Bulk-sender deliverability checklist

Any brand sending ~5,000+ messages/day to a mailbox provider must meet sender requirements or mail is throttled or rejected:

- **Authenticate the sending domain**: SPF and DKIM and a published, aligned DMARC policy (at least `p=none`).
- **One-click unsubscribe**: `List-Unsubscribe` header with one-click support (RFC 8058); honour opt-outs within two days; keep a visible unsubscribe link in the body.
- **Spam-complaint rate under 0.3%**, ideally under 0.1%.
- **Consistent, reverse-DNS-valid sending IP over TLS**, warmed-up domain, stable from-address.
- **Physical mailing address and accurate From/Reply-To** in every message; documented opt-in consent per jurisdiction.
- **List hygiene**: suppress hard bounces and inactives; never send to purchased lists.

## Output

- Sequence overview: goals, audience, trigger conditions
- Per-email breakdown: subject lines (with scores), preview text, body copy, CTA, send timing
- Segmentation and branching logic
- Deliverability checklist per email (spam-risk score included)
- Personalisation and dynamic-content recommendations
- Compliance checklist
- Benchmarks to measure against

## Sending

If, and only if, the user explicitly asks to send the campaign now, call `send_email_campaign` with the exact recipient count and connector. The platform will ask the user to approve the send with the cost estimate; if it is rejected, report that nothing was sent and stop.
