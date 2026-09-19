"""Email deliverability tools: subject-line scoring and spam-risk scanning.

Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee) —
wraps scripts/email-subject-tester.py and spam-score-checker.py (verbatim
copies in tools/ported/). Deterministic, read-only.
"""
from __future__ import annotations

from typing import Any

from tools.ported import email_subject_tester as _subject
from tools.ported import spam_score_checker as _spam
from tools.registry import ToolContext, tool


@tool(
    "email_subject_score",
    "Score email subject lines 0-100 across length, word count, spam triggers, personalisation, emoji, caps, "
    "numbers, power words and mobile preview compatibility, with warnings and recommendations.",
    {"properties": {"subjects": {"type": "array", "items": {"type": "string"}, "minItems": 1, "maxItems": 30}},
     "required": ["subjects"]},
)
def email_subject_score(ctx: ToolContext, args: dict[str, Any]) -> dict:
    return {"results": [_subject.analyze_subject(s) for s in args["subjects"]]}


@tool(
    "email_spam_check",
    "Scan an email body (and optional subject) for spam-risk indicators: trigger words by severity, punctuation and "
    "caps abuse, link density, suspicious phrases, missing unsubscribe, image ratio. Returns risk 0-100 (lower is better).",
    {"properties": {"content": {"type": "string", "minLength": 1}, "subject": {"type": "string"}},
     "required": ["content"]},
)
def email_spam_check(ctx: ToolContext, args: dict[str, Any]) -> dict:
    return _spam.analyze_email(args["content"], args.get("subject"))


TOOLS = [email_subject_score, email_spam_check]
