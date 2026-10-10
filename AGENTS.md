# Holdings — agent instructions

Working title: **Holdings**. The final name is open. See `docs/DECISIONS.md`.

`CLAUDE.md` is the same text as this file. Cursor reads both. If you change one, change the other in the same commit.

## Read first

Before any work in a session, read these, in order:

1. `AGENTS.md`
2. `docs/BRIEF.md` — the full design
3. `docs/DECISIONS.md` — decided, open, and later

Harborview's exact rules and constants are in `docs/REFERENCE.md`. Test against that file. Do not re-derive them from memory.

## What this is

A fictional island of cities. Each city is a small economy with its own resources, government, and policies, growing at its own pace. Players are outside investors, not mayors. With limited cash they buy land, build businesses and rental houses, and trade shares in each city's companies. Everyone plays the same shared world at their own pace. Orders are collected and cleared together, so the crowd sets prices. Prices move on a fast clock and city fundamentals on a slow clock. Disasters and booms are signalled ahead of time. Bots make the world feel alive and are labelled as bots. Outcomes online are computed on the server.

## Design pillars

Never break these.

1. **Game first.** It is 99% game. The economics is the physics of the world, never a lecture. No popups explaining what a bubble is.
2. **Simple to learn, deep to master.** A few asset types, each with a distinct playstyle. A new feature has to enable a way of playing that does not already exist.
3. **Readable but uncertain.** Every risk shows warning signs. Skill tilts the odds, and luck keeps any single bet uncertain.
4. **Limited cash is the core decision.** The player can never do everything.
5. **The crowd is the market.** Combined actions move prices. Herding creates bubbles. Bubbles are not scripted.
6. **Lessons are felt.** Diversification, bubbles, location value, cash flow against capital gains, policy risk, correlated crashes, and the cost of churning are learned by winning and losing.
7. **Fair and honest.** Bots are labelled as bots everywhere. No pay-to-win. Outcomes are computed on the server.

## Architecture

Monorepo, managed with melos once phase 2 exists:

| Path | Responsibility |
|---|---|
| `packages/engine/` | The whole game in pure Dart. No Flutter, Flame, or Firebase imports. Deterministic: the same seed and the same actions always produce the same world. Solo play and the server both run this code. |
| `apps/mobile/` | Flutter stable and Flame. Draws engine state and sends actions. No game rules. Riverpod for state. |
| `services/world/` | Cloud Run service built with shelf. Validates actions, queues orders, runs ticks with the engine, writes Firestore. The only thing that decides outcomes online. |
| `tools/sim/` | Headless balance simulator. |
| `infra/` | Terraform. |

Decided stack: Flutter stable, Flame, Riverpod, Firebase Auth (Apple, Google, email), Firestore, Firebase Cloud Messaging, Cloud Scheduler, BigQuery, Terraform, GitHub Actions, Firebase emulators for local development.

Engine rules:

- Every tunable value lives in `packages/engine/lib/tuning.dart`. Numbers the brief gives go there as starting values. If the brief does not give a number, do not invent one. Stop, ask, and record the gap in `docs/DECISIONS.md`.
- Each tick and each action returns a list of events (earned, bought, sold, rumor announced, rumor decided, order filled, city grew). The ledger, floating labels, notifications, sounds, and analytics all read from that list.
- A tick writes a small number of Firestore documents, not one per plot.
- Game rules live only in the engine. Never put them in widgets, Flame components, or server code.
- Every visual object sits behind a sprite interface, so later Blender art can replace code-drawn shapes without touching game logic.
- Bots act through the same action API as human players. No shortcuts.
- Log every human and bot action with the world state. Do not train bots on that log. Training is under Later.

## How to work

- Work one phase at a time, in the order in `docs/BRIEF.md` section 12. The current phase is recorded at the top of `docs/DECISIONS.md`.
- At the end of a phase, stop. Summarize what you built and how to run it. Wait until the user says go. Do not start the next phase in the same turn.
- Write complete files. Never leave a fragment and say the rest stays the same.
- When the brief does not cover something, ask. Do not invent rules. Do not guess on balance, economics, or game feel.
- Build Harborview exactly as `docs/REFERENCE.md`, then generalize from it only in the phase that says to.
- No features beyond the brief. Put ideas under Later in `docs/DECISIONS.md`.
- When a decision is made, update `docs/DECISIONS.md` and, if the working rules changed, this file and `CLAUDE.md`.
- Commit after each phase with a clear message. Run analysis and the tests before every commit, and fix all warnings.
- Unit tests that depend on a random draw take that draw as an input. Do not assert a lucky layout from an unspecified random stream.
- This repository already contains an unrelated marketing-platform tree (`orchestration/`, `skills/`, `channels/`, and the rest). Leave it alone until `docs/DECISIONS.md` OQ-1 is answered. Do not start phase 2 until the user says go and OQ-1 is answered.

## Phases

1. Brief and plan. Documents only. No code.
2. Repo and tooling. Melos workspace, all five folders, CI for analysis and tests, Firebase emulators.
3. Engine, part 1. Harborview only, with a unit test for every rule in `docs/REFERENCE.md`.
4. Engine, part 2. The full world: map, three cities, fundamentals, governments, four asset types, companies, order clearing, both clocks, every event set, seasons, six bots.
5. Balance simulator. 1,000 bot-only seasons. CSV and a short summary. The preamble of the brief calls this phase 4. Follow this list until `docs/DECISIONS.md` OQ-23 is answered.
6. Solo app, flat UI. Offline, full season, plain screens.
7. The world in Flame. Island map and isometric cities.
8. Life and polish. Appendix B, haptics, sound, night mode, settings, save and resume, accessibility.
9. Backend. Auth, Firestore, Cloud Run, scheduled ticks, server bots, Terraform.
10. Multiplayer. Private worlds, invite codes, live updates, leaderboards, season recap, push notifications.
11. Analytics. BigQuery, saved queries, end-of-season question.
12. Friends-and-family release. Icon, splash, bundle id `com.nuriom.holdings`, privacy-policy placeholder, TestFlight and Play internal testing, a checklist of what only the user can do.

Later, do not build: public worlds, more cities, bots that learn from player data, real art, loans and leverage, cosmetic purchases, a public store launch.
