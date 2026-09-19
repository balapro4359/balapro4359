"""Intent router: natural-language request -> 1-3 skills.

Keyword/trigger matching against the ~163 skill descriptions carried over from
the plugin index. Only *ported* skills (those with a SKILL.md) are returned as
runnable; the best unported match is logged as a porting demand signal.
"""
from __future__ import annotations

import math
import re
from collections import Counter
from dataclasses import dataclass

from config.logging import get_logger
from skills.loader import SkillCatalog, SkillMeta

log = get_logger("router")

_STOP = set("""a an the and or of for to in on at by with from as is are be was were this that these those it its our your
my we you they them their us me i can could should would will do does did have has had how what which who whom why when
where please help me need want like make get set up run give show tell about into onto over under some any all more most
less new old""".split())

_TOKEN_RE = re.compile(r"[a-z0-9][a-z0-9'\-]*")


def tokenize(text: str) -> list[str]:
    return [t for t in _TOKEN_RE.findall(text.lower()) if t not in _STOP and len(t) > 1]


@dataclass(frozen=True)
class RouteMatch:
    skill: str
    score: float
    reason: str
    ported: bool


class Router:
    def __init__(self, catalog: SkillCatalog, max_skills: int = 3, min_score: float = 5.0,
                 unported_dominance: float = 1.5) -> None:
        self.catalog = catalog
        self.max_skills = max_skills
        self.min_score = min_score
        self.unported_dominance = unported_dominance
        self.last_port_demand: RouteMatch | None = None
        self._doc_tokens: dict[str, Counter] = {}
        df: Counter = Counter()
        for meta in catalog.metas.values():
            toks = Counter(tokenize(meta.description) + tokenize(meta.name.replace("-", " ")) * 3)
            self._doc_tokens[meta.name] = toks
            df.update(set(toks))
        n = max(1, len(catalog.metas))
        self._idf = {t: math.log(1 + n / (1 + c)) for t, c in df.items()}

    def _score(self, meta: SkillMeta, text_lower: str, q_tokens: list[str]) -> tuple[float, str]:
        reasons = []
        score = 0.0
        # 1. explicit slash command or exact name mention
        if re.search(rf"(^|\s)/{re.escape(meta.name)}(\s|$)", text_lower) or meta.name in text_lower:
            score += 20
            reasons.append("name")
        # 2. trigger phrases
        for trig in meta.triggers:
            t = trig.lower().strip()
            if t and t in text_lower:
                score += 8
                reasons.append(f"trigger:{t}")
        # 3. name token overlap
        name_toks = set(tokenize(meta.name.replace("-", " ")))
        hit = name_toks & set(q_tokens)
        if hit:
            score += 3 * len(hit)
            reasons.append("name-tokens:" + ",".join(sorted(hit)))
        # 4. IDF-weighted description overlap
        doc = self._doc_tokens.get(meta.name, Counter())
        overlap = 0.0
        for tok in set(q_tokens):
            if tok in doc:
                overlap += self._idf.get(tok, 1.0)
        if overlap:
            score += overlap
            reasons.append(f"desc:{overlap:.1f}")
        return score, " ".join(reasons)

    def route(self, text: str, *, only_ported: bool = True) -> list[RouteMatch]:
        text_lower = text.lower()
        q_tokens = tokenize(text)
        scored: list[RouteMatch] = []
        for meta in self.catalog.metas.values():
            s, why = self._score(meta, text_lower, q_tokens)
            if s > 0:
                scored.append(RouteMatch(meta.name, round(s, 2), why, meta.ported))
        scored.sort(key=lambda m: (-m.score, m.skill))

        candidates = [m for m in scored if (m.ported or not only_ported)]
        chosen: list[RouteMatch] = []
        if candidates:
            best = candidates[0].score
            for m in candidates:
                if m.score >= self.min_score and m.score >= 0.5 * best and len(chosen) < self.max_skills:
                    chosen.append(m)
        unported_best = next((m for m in scored if not m.ported), None)
        self.last_port_demand = None
        if unported_best and (not chosen or unported_best.score > chosen[0].score):
            # The user clearly wants a capability we have not ported yet: record the demand signal
            # and, when the unported match dominates, do not force a weak ported skill onto the request.
            self.last_port_demand = unported_best
            log.info("router.port_demand", skill=unported_best.skill, score=unported_best.score, query=text[:120])
            if chosen and unported_best.score >= self.unported_dominance * chosen[0].score:
                chosen = []
        log.info("router.decision", query=text[:120], chosen=[(m.skill, m.score) for m in chosen],
                 top_unported=(unported_best.skill, unported_best.score) if unported_best else None,
                 considered=len(scored))
        return chosen
