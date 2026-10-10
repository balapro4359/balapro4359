# Decisions

Working title: Holdings. This file is the record of what is decided, what is still open, and what must not be built. If a session is unsure, the answer is in here or it is not decided. Do not guess.

## Look previews

Concept screens live in `docs/concepts/`. They show the intended mood from Appendix B. They are not final art. Real art stays under Later.

Dollars, percentages, and ranks drawn on those screens are picture labels. They are not values for `tuning.dart`, except where `docs/concepts/README.md` says a figure comes from Appendix A.

## Status

- Phase 1 is written.
- The user said to go forward and build the investor app. The game lives in this repository beside the marketing platform (`packages/engine`, `apps/mobile`). That is OQ-1 option 3 until they pick another home.
- `packages/engine` is Harborview, playable from `apps/mobile`. Ironridge and Greenvale are on the map only. Their prices are not invented.
- Run it from `apps/mobile` with Flutter stable: `flutter run`, or `flutter run -d chrome` for a desktop window. Engine checks are `dart test` in `packages/engine`.
- The island, Harborview, Ironridge, and Greenvale are the clean plates in `apps/mobile/assets/world/`, taken from the agreed concept screens. Live labels sit on top of them. The picture numbers were not copied into the game.
- Open Harborview questions are still open. The app uses the provisional readings below so it can be played. They are not locked rules.

## Provisional, so the app can play

Used only because the solo app had to run. Correct any of these and the engine should change to match.

- One tap of Next settles one Appendix A day.
- Starting street demand is 0. Random ranges are inclusive and uniform.
- Halfway prices round away from zero. Sale proceeds are the exact 95 percent.
- Income can take cash below zero.
- Census days are 7, 14, 21, 28, and 35. The census does not clamp base traffic.
- A building earns on the settlement of the next day, not the day it is built.
- Bots start with $12,000. The day-1 forced buy skips the act roll. If the normal buy rule cannot choose, the bot buys the cheapest plot that leaves a $300 buffer.
- A bot builds on the empty plot it owns with the highest traffic. The parking-lot fallback also requires the build cost plus $500.
- Omar rolls once per building. Ties keep the earlier plot.
- Street change is `(multiplier now / multiplier then) - 1`.
- Rumor gaps are measured from announcement to announcement. A busy street is skipped and the card stays in the deck. An empty deck is shuffled again. Permanent ±3 is rolled per plot. A new effect starts after today's income and then lasts its full duration.
- Return is `(net worth − 12,000) / 12,000`. Total earned includes losing days. Streets invested in are the streets owned when the card is shown. Best sale is the highest cash received. Rank ties break by investor id.

## Made

From the brief. Do not reopen these unless the user does.

- The game ships as a mobile app. Confirmed. Day-to-day play, notifications, offline solo, and the friends-and-family release are the phone. Client: Flutter stable channel, Flame, Riverpod, in `apps/mobile/`.
- Backend: Firebase Auth (Apple, Google, email), Firestore, Cloud Messaging. A Dart world service on Cloud Run, built with shelf, triggered by Cloud Scheduler. BigQuery for analytics and the action log. Terraform. GitHub Actions. Firebase emulators for local development.
- One pure Dart engine, shared by the solo app and the server. No Flutter, Flame, or Firebase imports inside `packages/engine/`.
- The server decides all outcomes in online worlds.
- Orders are collected and cleared in a batch at each fast tick. Online, a trade does not fill at the moment it is placed.
- Four asset types: land, businesses, rental houses, company shares. Loans and leverage are not in this version.
- Three starting cities, added through config so later cities need no code changes: Harborview, Ironridge, Greenvale.
- Seasons. Each world runs for a season, then a final ranking, a recap of what happened, and a reset. The recap tells what happened. It does not tell the player what they should have learned.
- Bots are labelled archetype bots. The first six are Rita, Omar, Mei, Dex, Tara, and Vik. They use the same action API as humans.
- Every tunable lives in `packages/engine/lib/tuning.dart`.
- Bundle id, when release work starts: `com.nuriom.holdings`.
- Harborview's prototype rules in Appendix A are exact. `docs/REFERENCE.md` is the test catalog for them.
- Phase 3 is Harborview only: the four Appendix A bots (Rita, Omar, Mei, Dex), land, car wash, parking lot. Tara, Vik, shares, houses, other cities, governments, and the fast/slow split belong to engine part 2.

## Tooling notes from phase 1

- Cursor reads `AGENTS.md` and `CLAUDE.md` automatically. Both files carry the same instructions.
- `.cursorrules` is legacy in Cursor and is not used. A plain markdown file in `.cursor/rules/` is ignored. Scoped Cursor rules, if needed later, are `.mdc` files in `.cursor/rules/`.
- The Harborview prototype is not in this repository. `docs/REFERENCE.md` was taken from Appendix A of the brief only.

## Open

Answer by id. A session must not pick an answer on its own.

### Before phase 2

#### OQ-1 — Where the game lives `blocks phase 2`

This repository (`balapro4359/balapro4359`) already contains a marketing AI orchestration platform: `orchestration/`, `skills/`, `channels/`, `connectors/`, `data/`, `tools/`, `tests/`, `README.md`, and `docs/PLAN.md`. The Holdings brief asks for a melos monorepo at the repo root (`packages/engine`, `apps/mobile`, `services/world`, `tools/sim`, `infra`).

Which of these should phase 2 do?

1. New git repository, Holdings only.
2. This repository, and the marketing platform is removed.
3. This repository, game under a subdirectory, marketing platform left in place.
4. Something else.

### Before phase 3

These are holes in Appendix A. `docs/REFERENCE.md` locks only what the appendix actually says, and lists these ids next to the gaps.

#### OQ-2 — Two clocks versus the prototype day `blocks phase 3`

Appendix A: the player taps "Next day" and one day happens. Income, the crowd multiplier, the census, and rumors all move with that day. The season is 40 of those days.

Section 5: in solo play, "Next" is a fast tick, and a slow tick (a day) happens every 4 fast ticks. The solo season is still 40 days, which would be 160 fast ticks.

Section 6: buys are not filled when placed. They clear on the fast tick. Appendix A: buying pays the plot value immediately, and selling to the city returns 95% immediately.

Phase 3 is specified as "Harborview exactly". The reading that matches that sentence is: phase 3 uses Appendix A's single day tick and instant city buy and sell. The two clocks and the order window arrive in engine part 2.

Confirm that reading, or describe the mapping you want instead. The section 13 question about season length and tick times stays open for the full game (OQ-20).

#### OQ-3 — Order of operations inside a day `blocks phase 3`

Appendix A names these operations and does not say which happens first. On a given day, what is the order?

- Player buys, builds, and sells
- Bot sell checks
- Bot act roll, then bot buys and builds
- Income from buildings that are open and already earning
- Weekly census, on a census day
- Announce a rumor, if one is due
- Decide a rumor, if one is due
- Apply a permanent, temporary, or closure effect
- Count down temporary traffic and closures
- Update each street multiplier and decay demand
- Reroll the "cars a day" noise
- Advance the day number
- On day 40, show the result card

Also: does day 40 pay income and run its events before the card, or does the card replace day 40's tick?

#### OQ-4 — Money `blocks phase 3`

- Land price and plot value round to the nearest $10. What happens on an exact halfway case, such as a raw value of 1605 or 6315 (examples in `docs/REFERENCE.md`)?
- Daily income can be a half dollar (`traffic × 5.5`). Is income stored exactly, or rounded to the cent or the dollar?
- Sale proceeds are 95% of plot value. 95% of $4,740 is $4,503. Is that paid exactly, or rounded?
- Can income drive cash below zero?

#### OQ-5 — Random draws `blocks phase 3`

For each draw below: integer or continuous, are the endpoints included, and what distribution?

- Starting traffic: street base plus a random amount from −13 to +13, then clamped to 6–95
- Census: base moves by −5 to +5
- Street multiplier noise: −0.022 to +0.022
- Permanent effect: the stated amount, ±3
- Rumor gap: every 4 to 6 days
- Decision delay: 3 to 5 days after announcement
- Event chance roll
- Bot act chance, Omar's 50% sell check, Dex's random plot and random building

"Stayed flat" since the last census is a real panel state. That outcome has probability zero if the census step is a continuous draw. Is the census step an integer that includes 0?

#### OQ-6 — Starting demand `blocks phase 3`

Each street's multiplier starts at 1.0. The brief does not say what the demand value starts at.

#### OQ-7 — Bot starting cash `blocks phase 3`

The player starts with $12,000. The brief does not say what Rita, Omar, Mei, and Dex start with.

#### OQ-8 — The day-1 forced buy `blocks phase 3`

"On day 1, every bot makes a forced buy."

- Does "forced" only skip the act-chance roll, with the normal buy rule, the 3-plot cap, and the $300 buffer still applied?
- If the normal rule cannot pick a plot (Rita has no 3-day history yet), what does that bot buy?

#### OQ-9 — Where a bot builds `blocks phase 3`

The brief says what each bot prefers to build, and that a bot who cannot afford the preferred building builds a parking lot. It does not say which owned plot they build on when they own more than one empty plot.

The general rule "only builds if it has the build cost plus $500" is recorded in `docs/REFERENCE.md` as applying to the parking-lot fallback too: if the fallback also fails that test, the bot does not build. Confirm or correct that.

Omar sells with a 50% chance when a building earns under $15 a day. Is that one independent roll per such building, or one roll for the bot?

#### OQ-10 — Census `blocks phase 3`

- Which day numbers are census days in a 40-day game that starts on day 1? The brief says "every 7th day".
- After the census moves a plot's base, is the base clamped? Starting traffic is clamped to 6–95. Permanent effects clamp base to 3–98. The census sentence gives no clamp.

#### OQ-11 — Rumors `blocks phase 3`

- Is the 4-to-6-day gap measured from announcement to announcement, or from decision to the next announcement?
- If the drawn event's street already has a pending rumor, what happens? Redraw, delay, or skip?
- When the deck of eight is used up, is it shuffled and refilled with all eight?
- Permanent ±3: one draw for the whole street, or a separate draw for each plot?
- Temporary effects and closures: does the decision day count as day 1 of the duration?
- Do two active temporary modifiers on the same plot add together? `docs/REFERENCE.md` reads "any active temporary changes" as a sum. Confirm or correct.

#### OQ-12 — Street change the bots and the map use `blocks phase 3`

The multiplier history is kept. The map shows each street's change from yesterday. Bots use the 2-day and 3-day changes. Rita buys when the best 3-day rise is over 2%, and sells when her street fell more than 5% over 2 days.

- Is the change `(multiplier now / multiplier then) − 1`?
- For a 3-day change on day D, is "then" day D−3?
- What is the change before that much history exists?

#### OQ-13 — Ties `blocks phase 3`

No tie-break is given for:

- Two streets with the same 3-day rise (Rita)
- Two plots with the same price (Rita, Mei)
- Two plots with the same traffic (Omar)
- Two players with the same net worth on the result card

#### OQ-14 — Building value on the day it is built `blocks phase 3`

A new building starts earning the next day. Building value is the larger of 40% of build cost and `daily income × 18`. On the build day, is daily income 0, so the building is worth 40% of its cost until the next day?

#### OQ-15 — Result card definitions `blocks phase 3`

On day 40 the card shows rank out of five, net worth, return, total earned from businesses, how many of the four streets you invested in, and your best sale.

- Return: `(net worth − 12,000) / 12,000`, or something else?
- Total earned: sum of daily business income, including losing days, or only positive income?
- Streets invested in: streets where you own a plot when the card is shown, or streets you owned at any point?
- Best sale: highest cash received, or largest gain over what you paid?
- Rank ties: see OQ-13.

#### OQ-16 — Rumor lines `blocks phase 3` if tests lock the strings

The ferry lines are the brief's example. The other seven were written in phase 1 so the catalog is complete. They are in `docs/REFERENCE.md` under HV-NEWS-09. Replace any line you want changed. Until you do, they are the working copy.

### From the brief, still open

These are section 13. They do not block phase 2. They block the phase that would hard-code an answer.

#### OQ-17 — Final name

Working title is Holdings.

#### OQ-18 — Players who join mid-season

How they get a fair start. No rule is given.

#### OQ-19 — Humans per private world

No cap or target is given. Separately, the bot rule is "fill up to a target number of participants", and that target number is not given either. Bot trading-volume cap is also not given.

#### OQ-20 — Season length and tick times

Section 13 marks this open. The brief also gives defaults. Treat the defaults as unconfirmed proposals, except that phase 3 uses Appendix A's 40 solo days if OQ-2 is confirmed.

| Clock | Online text in the brief | Solo text in the brief |
|---|---|---|
| Fast tick | Every hour | Each tap of Next |
| Slow tick (a day) | Daily at a fixed hour. The hour and the time zone are not stated. | Every 4 fast ticks |
| Season | 6 weeks | 40 days |

Appendix A also gives Auto as one day every 1.5 seconds. That is UI timing for the prototype.

#### OQ-21 — Plots sold to other players at launch

Appendix A has one sale: instant, back to the city, at 95% of plot value, building included. Section 4 also allows a player to list a plot at their own price. Section 13 asks whether player-to-player listings exist at launch or only the city buyback.

Phase 3 implements the city buyback only, because that is Appendix A. This question is for the later phase that adds listings.

#### OQ-22 — How fragile Ironridge feels

To be tuned with the balance simulator. Do not pick a concentration target before that.

#### OQ-23 — Which phase number the simulator is

The preamble calls the balance simulator phase 4. Section 12 places it after engine part 2. Numbered from the top of that list, the simulator is phase 5:

1. Brief and plan
2. Repo and tooling
3. Engine, part 1
4. Engine, part 2
5. Balance simulator

`AGENTS.md` follows that list order. Confirm the list, or say if the simulator should run before engine part 2.

### Before engine part 2

The brief names these systems and does not give the numbers. They go in `tuning.dart` only after you supply a starting value. Do not invent them in a session. When engine part 2 starts, the session should turn this list into a question for you before coding the system.

Harborview's own numbers are already in `docs/REFERENCE.md` and are not repeated here.

**Cities other than Harborview**

- Starting streets, plot names, and base traffic for Ironridge and Greenvale
- Starting population, jobs, employment rate, resource output, and growth rate for each city
- The formula that derives street traffic from population, jobs, output, and growth. Appendix A traffic is a base plus census noise, not a formula of population. Section 3 says traffic is derived from those fundamentals "as in Appendix A". Those two descriptions do not match.
- Population threshold that unlocks a new street, and what that street's plots are
- How a street declines when population falls: the traffic drop and the income drop
- Concentration formula behind the fragility meter

**Governments**

- Starting council leaning for each city
- Property-tax rate for pro-growth, steady, and cautious
- Business-tax rate for each leaning
- Permit-cost modifier for each leaning
- Which building types cautious zoning bans, and on which streets
- How often elections happen ("a few times a season")
- How polling and a proposal's approval chance are produced
- What a public project does to traffic or output, and for how long

**Businesses beyond car wash and parking lot**

- Warehouse, workers' diner, grain silo, farm stand: build cost, income formula, and which driver (traffic, resource output, or population)
- Whether a building can be replaced or demolished. No rule is given. Do not add one.

**Rental houses**

- Build cost
- Rent from population and employment
- How the house's value is computed from its rent. Land value plus that house value is the plot value. The "income × 18" rule is stated for Appendix A businesses only.

**Companies and the share market**

- Shares outstanding for each company
- Fundamental value formula
- Dividend formula
- Price-impact factor
- Spread ("a small spread")
- How hard price drifts toward fundamental value, and the noise on that drift
- System market maker behavior beyond "always quotes"
- The 20% ownership cap and the 0.5% trading fee are given. Do not change them.

**Bots in the full world**

- Tara and Vik: act chance, thresholds, and position limits. The brief gives their style and not their numbers.
- How Rita, Omar, Mei, and Dex extend from land to shares and to the new cities. The brief says to extend them and does not give the extra rules.
- Target participant count, the rule for a bot leaving when a human joins, and the cap on bots' share of trading volume
- Whether solo Harborview stays at four bots after the full world exists. Rank "out of five" is the Appendix A end card.

**Events beyond Harborview**

Section 7 says to write similar sets for Ironridge and Greenvale, plus world-level events. That writing is an authoring task for engine part 2, and the numbers are balance. Draft the tables and wait for approval before they are coded. Patterns the brief already names:

- Ironridge: ore runs out, ore price collapse, mine shuts down, new ore vein, rail spur
- Greenvale: drought, crop blight, rail line, food processing plant
- World: credit crunch, every price falls at once
- Company: bank scare at Harbor Savings Bank, fear spreads to the city
- Policy events: tax rise, zoning change, project approved after an election

**Other full-game gaps**

- Online starting cash. Solo is $12,000.
- Notification categories are exemplified. The daily cap number is not given.
- Ranking in the full game: Appendix A ranks by net worth. The full game does not restate the formula. Net worth in the full game includes shares and houses. The weights are not given.
- Sealed bids for city plots (section 6) versus instant purchase at formula value (Appendix A). Highest bid at or above the list price wins, ties go to the earliest bid. The list price formula and whether this replaces instant buy are not given.

## Later

Do not build these. Keep the list.

- Public worlds
- More cities
- Bots that learn from the action log
- Real art (Blender isometric sprites replacing code-drawn shapes)
- Loans and leverage
- Cosmetic purchases
- A public store launch
- A web interface, for the extra screen space. Same engine, same server, same rules. A large screen can show more of the map, the portfolio, and the charts at once. It is not a second game, and it is not part of the current phases. How that client is built stays undecided until that work starts.

## Draft copy waiting for approval

The seven non-ferry rumor lines in `docs/REFERENCE.md` HV-NEWS-09. See OQ-16.
