# Third-party notices

This product includes content adapted from **Digital Marketing Pro**, an
MIT-licensed Claude Code plugin created by Indranil Banerjee.

- Source repository: https://github.com/indranilbanerjee/digital-marketing-pro
- Author: Indranil Banerjee (https://indranil.in)
- License: MIT (full text below, reproduced verbatim from the repository's `LICENSE` file)

## What was adapted

| Location in this repository | Origin in digital-marketing-pro | Nature of change |
|---|---|---|
| `skills/*/SKILL.md` (10 skills) | `skills/<name>/SKILL.md` | Instructions kept; plugin-specific file paths, script invocations and slash-command syntax removed; front matter reshaped to this platform's format. |
| `skills/index.json` | `skills-index.json` | Names, tiers and descriptions carried over for intent routing; trigger phrases extracted from descriptions. |
| `tools/ported/*.py` | `scripts/*.py` (roi-calculator, budget-optimizer, clv-calculator, sample-size-calculator, significance-tester, headline-analyzer, email-subject-tester, spam-score-checker, utm-generator, keyword_cluster, tech-seo-auditor, _common) | Verbatim copies with an attribution header; files renamed from kebab-case to snake_case to be importable. |
| `tools/*.py` | the same scripts | Thin wrappers exposing the scripts' pure functions as JSON-schema tools. |
| `connectors/catalog.json`, `connectors/registry.py` | `scripts/_connector_registry.py` | Connector catalog data carried over; local `.mcp.json` probing replaced by per-tenant vault checks. |
| `tools/connector_executor.py` | `scripts/connector_executor.py`, `scripts/connector_resolver.py` | Concept (manifest, then gated execution) re-implemented; Phase 1 executes as a mock. |

Every adapted file carries the header comment
`Adapted from digital-marketing-pro (MIT License, (c) Indranil Banerjee)`.

Note: the upstream `LICENSE` file's copyright line reads "Copyright (c) 2026
Digital Marketing Pro"; the project README names Indranil Banerjee as the
author. Both attributions are preserved here.

## MIT License (digital-marketing-pro)

```
MIT License

Copyright (c) 2026 Digital Marketing Pro

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Other dependencies

Runtime dependencies (`claude-agent-sdk`, `python-telegram-bot`, `PyYAML`,
`cryptography`, `structlog`) are used unmodified under their own licenses; see
each package's distribution for license text.
