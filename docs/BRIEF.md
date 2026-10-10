# Holdings — design brief

Source of truth for the game design. Working title: Holdings. The final name is open (`docs/DECISIONS.md` OQ-17).

This is the brief as given. Phase 1 added only the Harborview rumor lines Appendix A asks for. Those lines are marked. Game rules are not to be edited in place. A change is a decision and is recorded in `docs/DECISIONS.md`.

Harborview constants and testable rules are extracted in `docs/REFERENCE.md`. Working rules for every session are in `AGENTS.md`.

## How to work with me

Work one phase at a time (section 12). At the end of each phase, stop, summarize what you built and how to run it, and wait for me to say go.

Write complete files, never fragments with "the rest stays the same".

When something isn't covered here, ask. Don't invent rules.

The first city, Harborview, is already designed and tested in a prototype. Its exact rules are in Appendix A and its look is in Appendix B. Build it exactly as written, then generalize from it.

The numbers this brief gives for new systems are starting values that have not been tested. Put them all in `tuning.dart`. The balance simulator in phase 4 exists to correct them.

Section 12 lists the simulator after engine part 2, which is fifth when the list is numbered from the brief. That numbering mismatch is `docs/DECISIONS.md` OQ-23. Until it is answered, follow the section 12 order.

## 1. The game in one paragraph

A fictional map of cities, each a small economy with its own resources, government and policies, growing at its own pace. Players are outside investors, not mayors. With limited cash, they buy land, build businesses and rental houses, and trade shares in each city's companies. Everyone plays in the same shared world at their own pace. Orders are collected and cleared together, so what the crowd does as a whole sets prices. Prices move on a fast clock and city fundamentals on a slow one, so day traders and long-term investors both have a game. Disasters and booms are signalled ahead of time and can be read, so players who diversify and read the map do well over time, while any single bet can still blow up. Bots make the world feel alive from day one, and they step back as real players arrive.

## 2. Design pillars

Never break these.

- **Game first.** It's 99% game. The economics is the physics of the world, never a lecture. No popups explaining what a bubble is.
- **Simple to learn, deep to master.** A few asset types, each with a distinct playstyle. A new feature has to enable a way of playing that doesn't already exist.
- **Readable but uncertain.** Every risk shows warning signs. Skill tilts the odds, and luck keeps any single bet uncertain.
- **Limited cash is the core decision.** You can never do everything.
- **The crowd is the market.** Players' combined actions move prices, and herding creates bubbles without any scripting.
- **Lessons are felt.** Diversification, bubbles, location value, cash flow against capital gains, policy risk, correlated crashes, and the cost of churning are all learned by winning and losing.
- **Fair and honest.** Bots are labelled as bots. No pay-to-win. Outcomes are computed on the server.

## 3. The world

The map is one stylized island with three starting cities connected by roads. The data model must support adding more cities later through config, with no code changes.

| City | Economy | Character | Main risks | Main booms |
|---|---|---|---|---|
| Harborview (Appendix A) | Port and trade | Balanced, medium growth | Storms and floods, the shipping yard leaving | Ferry terminal, new trade routes |
| Ironridge | Mining, one dominant industry | Fast growth, fragile | The ore running out, an ore price collapse, the mine shutting down | A new ore vein, a rail spur |
| Greenvale | Farming valley | Slow and steady, pays dividends | Drought, crop blight | A rail line, a food processing plant |

City fundamentals are updated on the slow clock:

- Population
- Jobs and employment rate
- Resource output (trade volume, ore, or harvest)
- Growth rate
- Traffic per street, derived from the above as in Appendix A
- Concentration: the share of the city's economy coming from its largest industry. Show it to players as a fragility meter. This is how a risk becomes visible before it happens: Ironridge's meter should read high.

Cities grow at their own pace. When population crosses a threshold, a new street unlocks with fresh plots. When it falls, streets decline: traffic drops and buildings earn less. Harborview starts with the four streets in Appendix A.

### Governments and policies

Each city has a council with a leaning, and the leaning sets its policies.

| Leaning | Taxes | Permits and zoning | Effect on the city |
|---|---|---|---|
| Pro-growth | Low | Easy, cheaper building | Faster growth, bigger bubbles |
| Steady | Medium | Normal | Balanced |
| Cautious | High | Restricted, some building types banned on some streets | Slower growth, fewer crashes |

The policies are:

- Property tax, charged on plot value each slow tick.
- Business tax, charged on income.
- Zoning: which building types are allowed on which street.
- Permit cost, a modifier on the cost of building.
- Public projects, which can trigger booms.

Policy changes and elections are telegraphed like rumors. A proposal appears with a decision date and an approval chance. Elections happen a few times a season and show polling.

## 4. What players can own

Keep it to these four. Each one is its own playstyle.

| Asset | Playstyle | How it pays | How it's priced |
|---|---|---|---|
| Land (plots) | Slow, patient investing | Capital gains | Traffic and the street's crowd multiplier, as in Appendix A |
| Businesses built on your land | Active building and location skill | Daily cash flow, plus resale | As in Appendix A: land value plus building value |
| Rental houses built on your land | Steady income | Rent driven by population and employment | Land value plus the house's value from its rent |
| Company shares | Fast trading | Price moves, plus dividends on the slow clock | Fundamental value plus the crowd's net order flow |

### Businesses

Car wash and parking lot (from Appendix A) are available in every city. Each city adds one or two of its own:

- Harborview: warehouse
- Ironridge: workers' diner
- Greenvale: grain silo and farm stand

Each building's income depends on a different driver (traffic, resource output, or population), so where you build matters in a different way for each.

### Companies

Two or three per city at first:

- Harborview Shipping and Harbor Savings Bank
- Ironridge Mining
- Greenvale Farms Co-op

Earnings come from the city's fundamentals and policies. A system market maker always quotes a price with a small spread, so a trade never waits for another player to take the other side. Limit any one player to 20% of a company's shares.

### Selling

You can always sell a plot back to the city instantly at 95% of its formula value, and that sale includes whatever is built on it. You can also list it for other players at your own price. Trading shares costs a 0.5% fee. The fees exist to make churning cost something.

Whether player-to-player plot listings exist at launch is open (`docs/DECISIONS.md` OQ-21).

Loans and leverage are left out of this version.

## 5. The two clocks

| Clock | Online default | Solo default | What it moves |
|---|---|---|---|
| Fast tick | Every hour | Each tap of "Next" | Clears the order window, moves share prices and crowd multipliers |
| Slow tick (a day) | Daily at a fixed hour | Every 4 fast ticks | Income, rent, dividends, taxes, fundamentals, growth, events, policies |
| Season | 6 weeks | 40 days, as in Appendix A | Ends with a final ranking and a reset |

Every duration is in `tuning.dart`.

Section 13 marks season length and tick times as open. Appendix A is exact for Harborview. The conflict is `docs/DECISIONS.md` OQ-2 and OQ-20.

## 6. The market

Orders aren't filled the moment they're placed. They're collected over the fast-tick window and cleared together, which keeps the game fair for players who check in once a day.

**Shares.** At each tick, net demand (buys minus sells, plus bot flow) moves the price by a price-impact factor divided by the number of shares. Price also drifts toward fundamental value with a little noise. All orders in the window fill at the same tick price, plus or minus the spread.

**Plots for sale by the city** use sealed bids. The highest bid at or above the list price wins, and ties go to whoever bid first.

**Plots listed by players** sell to the first valid buyer at the tick.

**Crowd demand on land** works as in Appendix A: buys raise a street's multiplier, sells lower it, and it decays back toward normal.

The app always shows when the next tick is ("fills in 23 min").

## 7. Events, disasters and booms

Every event is telegraphed. It's announced with a decision date and a chance, it moves prices when announced (the crowd reacts), and again when it resolves, either way. This works the same as in Appendix A.

The events are fictional versions of patterns from economic history. Never name or depict a real tragedy.

| Pattern | Scope | Example in the game |
|---|---|---|
| Natural disaster | One street or city | Storm floods the docks, buildings close for a few days |
| One-industry collapse | City | The Ironridge ore vein runs out, and population and traffic fall over several slow ticks |
| Speculative bubble | Emergent | Not scripted. It comes from the crowd pricing, and an event can pop it |
| Credit crunch | Whole world | Every price falls at once, so diversifying across cities doesn't fully protect you |
| Bank scare | Company | Harbor Savings Bank shares fall, and fear spreads to the city |
| Drought or blight | City | Greenvale harvest falls for a period |
| Industry leaving | City | A big employer moves away, and jobs and rents fall |
| Infrastructure boom | City or street | A rail line, ferry, or highway exit permanently raises traffic or output |
| Resource boom | City | A new ore vein: a fast boom that starts a bubble |
| Policy change | City | A tax rise, a zoning change, or a project approved after an election |

Use the eight events in Appendix A as Harborview's set. Write similar sets for Ironridge and Greenvale, plus the world-level events. Those sets are not written yet. Draft them for approval at the start of engine part 2. Do not invent the numbers in code. See `docs/DECISIONS.md`.

## 8. Players, worlds and modes

- **Solo.** An offline world against bots on the solo clock. It's the tutorial and the place to practise, and it works with no network.
- **Private worlds.** Created with an invite code for friends and family. This is the first online mode to ship.
- **Public worlds.** Later.
- **Seasons.** Each world runs for a season, then shows a final ranking and a short recap of the story (what you owned, your best and worst moves, which events hit you), then resets. The recap tells what happened, never what the player should have learned.
- **Leaderboards** for each world and each season.
- **Notifications**, opt-in by category, with a daily cap. Examples: a rumor about a city you're invested in, a business that closed, a daily earnings summary, and an order that filled.

## 9. Bots

Bots make the market feel alive before there are enough players. Behavioral archetypes are enough here, so no machine learning.

| Bot | Style | Behavior |
|---|---|---|
| Rita | Follows the crowd | Buys whatever rose most recently, sells when it falls. Inflates bubbles |
| Omar | Reads fundamentals | Buys the highest traffic, output, or population, and builds what fits |
| Mei | Diversifies | Spreads holdings across cities and asset types |
| Dex | Panics | Sells everything in a city with pending bad news |
| Tara | Day trader | Trades share momentum on the fast clock |
| Vik | Contrarian | Buys after crashes and sells into booms |

Build Rita, Omar, Mei and Dex's land rules exactly as in Appendix A, then extend them to shares and the new cities. Additional rules:

- Bots act through the same action API as human players, with no shortcuts.
- Each world fills up to a target number of participants with bots, and bots leave as humans join. Bots' share of trading volume is capped.
- Bots are labelled as bots everywhere.
- Every human and bot action is logged with the world state at that moment, so a future version can train bots on how real players behave. That's a later step. For now, only log the data.

## 10. Look and feel

**World map.** A stylized island with the three cities, roads between them with traffic, and a sea with boats. Each city shows its daily change, a fragility meter, and a marker for any pending rumor. As a city grows or shrinks, it gets visibly bigger or smaller.

**City view.** Tap a city to zoom into its isometric town. Build it as described in Appendix B: plots, roads with cars driven by traffic, car wash foam, parking lots filling up, ownership flags, floating money, rumor markers, flood water, road cones, and night mode. Then add the new building types and the houses, plus a distinct look for each city (cranes and a harbor, a mine headframe and ore carts, fields and silos).

**Company screen.** Price chart for the fast and slow clocks, fundamentals, dividends, the number of shares you hold, and buy and sell with a preview of the order.

**Portfolio.** Net worth over time, holdings by city and by asset type (diversification you can see), and income per slow tick.

**News feed, standings, and ledger**, as described in Appendix B.

Pinch to zoom and drag to pan, haptics on every action, sound, reduced motion, nothing below 12pt, and every button at least 48 by 48 points.

Every visual object sits behind a sprite interface, so pre-rendered isometric art from Blender can replace the code-drawn shapes later without touching game logic.

## 11. Tech stack and architecture

### Stack

- Flutter stable channel only, Flame for the map and cities, Riverpod for state.
- Firebase Auth (Apple, Google, email), Firestore, and Firebase Cloud Messaging.
- A Dart world service on Cloud Run built with shelf, triggered by Cloud Scheduler for the fast and slow ticks.
- BigQuery for analytics and the action log.
- Terraform for the infrastructure, GitHub Actions for CI, and the Firebase emulators for local development.

### Monorepo layout (use melos)

- `packages/engine/` holds the whole game in pure Dart, with no Flutter, Flame or Firebase imports: world, cities, fundamentals, governments, assets, market, order clearing, events, bots, clocks, seasons, scoring. It's deterministic: the same seed and the same actions always produce the same world. The same code runs in the app for solo play and on the server for online worlds.
- `apps/mobile/` holds Flutter and Flame. It draws engine state and sends actions. No game rules live here.
- `services/world/` is the Cloud Run service. It validates actions, queues orders, runs ticks with the engine, and writes state to Firestore. It is the only thing that decides outcomes online.
- `tools/sim/` is the headless balance simulator.
- `infra/` holds the Terraform.

### Rules for the engine

- Every tunable value lives in `packages/engine/lib/tuning.dart`.
- Each tick and action returns a list of events (earned, bought, sold, rumor announced, rumor decided, order filled, city grew). The ledger, floating labels, notifications, sounds and analytics all read from that list.
- Plan the Firestore data so a tick writes a small number of documents, not one per plot. Watch read and write costs.

## 12. Phases

Stop after each phase, show what was built, and wait for "go".

1. **Brief and plan.** Save this brief as `docs/BRIEF.md`. Write `AGENTS.md` with the pillars, architecture and working rules so every future session keeps them, whichever AI tool reads it. Many tools read `AGENTS.md` automatically. If a tool looks for a different file, copy the same content there. Write `docs/REFERENCE.md` listing every rule and constant from Appendix A in a form that can be tested. Write `docs/DECISIONS.md` with the open questions in section 13 and anything else unclear. No code yet.
2. **Repo and tooling.** Set up the melos workspace, all five folders, CI that runs analysis and tests, and the emulator setup.
3. **Engine, part 1.** Build Harborview exactly as one city, following Appendix A, with unit tests for every rule in `docs/REFERENCE.md`.
4. **Engine, part 2.** Build the full world: the map, three cities, fundamentals, growth and new streets, governments and policies, all four asset types, companies and the market maker, order windows and clearing, both clocks, every event set, seasons, and all six bots acting through the action API. Write tests for each.
5. **Balance simulator.** Run 1,000 bot-only seasons headless. Report each archetype's average and spread of returns, how often bubbles form and burst, price ranges, how unequal final wealth is, and how diversified players do against concentrated ones. Output CSV and a short summary. Tuning is repeated until it feels right.
6. **Solo app, flat UI.** The whole world, playable offline against bots, with plain screens: world list, city, plot panel, company, portfolio, news, standings, and ledger. It can be ugly, but the full season has to work.
7. **The world in Flame.** The island map, zooming into each city's isometric view, and visible growth and decline.
8. **Life and polish.** Everything in Appendix B, plus each city's look, haptics, sound, night mode, settings, save and resume, and accessibility.
9. **Backend.** Auth, the Firestore data model, the Cloud Run world service using the same engine, validated actions, the scheduled ticks, bots running on the server, and Terraform for all of it.
10. **Multiplayer.** Private worlds with invite codes, live updates, the order queue in the app, leaderboards, season end and recap, and push notifications.
11. **Analytics.** Stream every action, tick and event to BigQuery. Write saved queries for day-1 and day-7 return rates, where players quit, what they buy, and bot against human results. At the end of a season, ask one question: "Would you play another season?"
12. **Friends-and-family release.** App icon, splash screen, bundle ID `com.nuriom.holdings`, a privacy policy placeholder, TestFlight and Google Play internal testing builds, and a checklist of what has to be done by hand.

Later (don't build these, just keep the list in `docs/DECISIONS.md`): a web interface for larger screens, public worlds, more cities, bots that learn from player data, real art, loans and leverage, cosmetic purchases, and a public store launch. The web interface uses the same engine and the same server. It exists so a large screen can show more of the map, the portfolio, and the charts at once.

## 13. Decisions

### Made

- Flutter stable channel, Flame, Riverpod, Firebase, and a Dart service on Cloud Run. The shipping client is the mobile app. A web interface for larger screens is later.
- One pure Dart engine shared by the app and the server.
- The server decides all outcomes online.
- Orders cleared in batches at each fast tick.
- Four asset types, three starting cities, seasons, and labelled archetype bots.

### Open

Ask when a session reaches them. The living list, including gaps found in phase 1, is `docs/DECISIONS.md`.

- The game's final name.
- Season length and tick times.
- How players who join mid-season get a fair start.
- How many humans per private world.
- Whether players can sell plots directly to each other at launch, or only to the city.
- How fragile Ironridge should feel in practice. Tune this with the simulator.

## 14. Rules for working

- At the start of every new session, read `AGENTS.md`, `docs/BRIEF.md` and `docs/DECISIONS.md` before doing anything.
- Commit after each phase with a clear message.
- Run analysis and the tests before every commit, and fix all warnings.
- Game rules live only in the engine. Never put them in widgets, Flame components, or server code.
- No features beyond this brief. Write ideas in `docs/DECISIONS.md` under "Later".
- Keep `AGENTS.md` and `docs/DECISIONS.md` up to date as decisions are made.
- Ask when something is ambiguous. Don't guess on balance, economics, or game feel.

## Appendix A. Harborview, the first city: exact rules

The testable extraction is `docs/REFERENCE.md`. This appendix is the original rule text.

### Game

In solo mode: 40 days and $12,000 starting cash. The player taps "Next day" to advance, or turns on Auto, which advances one day every 1.5 seconds.

Net worth is cash plus the value of every plot you own.

### Town

Four streets with five plots each, 20 plots in total.

- **The Docks:** base traffic 55. Plots are Pier 1 to Pier 5.
- **Main Street:** base 72. Plots are 101, 115, 130, 144, and 160 Main.
- **Old Town:** base 42. Plots are Chapel Ln, Mill Row, Bell Ct, Tanner St, and Well Sq.
- **Edge Road:** base 22. Plots are Lot 1 to Lot 5.

Each plot's starting traffic is its street's base plus a random amount from −13 to +13, clamped to 6–95.

At the start, two random plots that aren't on Edge Road already have an unowned parking lot on them.

### Traffic

Current traffic is the plot's base plus any active temporary changes, clamped to 0–100.

The traffic shown to the player is "cars a day": traffic × 12, with ±9% noise, rerolled every day.

Weekly census on every 7th day: each plot's base moves randomly by −5 to +5. The panel shows whether the plot rose, fell, or stayed flat since the last census.

### Prices and income

Land price = round((900 + traffic × 42) × street multiplier, to the nearest $10).

Daily income:

- Car wash: traffic × 5.5 − 130. This loses money on quiet streets.
- Parking lot: traffic × 2 − 25.
- Zero while the building is closed by damage.

Building value = the larger of 40% of its build cost and daily income × 18.

Plot value = land price + building value, rounded to the nearest $10.

Build costs: car wash $5,000 and parking lot $2,500. A new building starts earning the next day.

Buying pays the plot value. Selling returns 95% of it, and the 5% is a fee.

### The market (crowd pricing)

Each street has a price multiplier that starts at 1.0, and a demand value.

Each buy adds 0.03 to that street's demand. Each sell subtracts 0.03.

Every day, for each street: multiplier × (1 + demand + random −0.022 to +0.022), then pulled 3% back toward 1.0, then clamped to 0.5–2.2. After that, demand × 0.45.

Keep the multiplier history. The map shows each street's change from yesterday, and the bots use the 2-day and 3-day changes.

### Town news (telegraphed events)

The first rumor is announced on day 3, and the next ones every 4 to 6 days.

A rumor is decided 3 to 5 days after it's announced. Each street can have only one pending rumor at a time.

Draw events from a shuffled deck so they don't repeat until the deck is used up.

When announced: good news adds 0.07 to that street's demand, and bad news subtracts 0.06.

When decided:

- If it happens, apply the effect, then add 0.05 demand for good news or subtract 0.10 for bad news.
- If it doesn't happen, good news subtracts 0.10 demand and bad news adds 0.05. The crowd overreacted.

Permanent effects change every plot's base traffic on that street by the stated amount, ±3, clamped to 3–98. Temporary effects change traffic for a set number of days. Damage closes every building on that street for a set number of days.

| Event | Street | Good or bad | Chance | Effect |
|---|---|---|---|---|
| Ferry terminal | Docks | Good | 60% | Permanent +20 |
| Storm flood | Docks | Bad | 50% | Temporary −30 for 6 days, and buildings closed for 4 days |
| Highway exit | Edge Road | Good | 45% | Permanent +28 |
| Repaving | Main Street | Bad | 75% | Temporary −32 for 6 days |
| Market hall | Old Town | Good | 55% | Permanent +16 |
| Shipping yard leaves | Docks | Bad | 40% | Permanent −14 |
| Sports arena | Main Street | Good | 50% | Permanent +12 |
| Mill closes | Old Town | Bad | 45% | Permanent −12 |

One-line rumor, outcome, and non-outcome for each event. The ferry lines are the brief's example. The other seven were written in phase 1 and are waiting for approval (`docs/DECISIONS.md` OQ-16).

| Event | Rumor | If it happens | If it doesn't |
|---|---|---|---|
| Ferry terminal | The port authority is weighing a ferry terminal on the docks. | Ferry terminal approved. Dock traffic is up for good. | Ferry terminal plan shelved. |
| Storm flood | Forecasters are tracking a storm that could flood the docks. | The storm floods the docks. Traffic drops and the buildings close. | The storm misses the harbor. |
| Highway exit | The county is considering a highway exit on Edge Road. | Highway exit approved. Edge Road traffic is up for good. | Highway exit plan shelved. |
| Repaving | Main Street may be torn up for repaving. | Repaving starts. Main Street traffic is down for a while. | The repaving plan was postponed. |
| Market hall | The council is weighing a market hall in Old Town. | Market hall approved. Old Town traffic is up for good. | Market hall plan shelved. |
| Shipping yard leaves | Word is the shipping yard may leave the docks. | The shipping yard is leaving. Dock traffic is down for good. | The shipping yard is staying. |
| Sports arena | A sports arena is proposed beside Main Street. | Sports arena approved. Main Street traffic is up for good. | Sports arena plan shelved. |
| Mill closes | The mill in Old Town may close. | The mill has closed. Old Town traffic is down for good. | The mill is staying open. |

### Bot rivals

Each bot holds at most 3 plots, keeps a $300 cash buffer when buying, and only builds if it has the build cost plus $500. If it can't afford its preferred building, it builds a parking lot. On day 1, every bot makes a forced buy.

| Bot | Style | Chance to act each day | Buys | Builds | Sells |
|---|---|---|---|---|---|
| Rita | Follows the crowd | 50% | The cheapest plot on the street with the best 3-day price rise, if that rise is over 2% | Car wash | When her street fell more than 5% over 2 days |
| Omar | Counts cars | 45% | The highest-traffic plot | Car wash if traffic is over 48, otherwise a parking lot | 50% chance when a building earns under $15 a day |
| Mei | Spreads her bets | 40% | The cheapest plot on a street she doesn't own | Parking lot | Never |
| Dex | Sells on bad news | 40% | A random plot | Car wash or parking lot at random | Every plot on a street with pending bad news |

Selling checks run every day, even when the bot doesn't act.

### End of game

On day 40, show a result card with your rank out of five, net worth, return, total earned from businesses, how many of the four streets you invested in, and your best sale. Offer "Play again".

## Appendix B. The city view: how it looks

An isometric harbor town. Water and a harbor across the top with sailing boats and a lighthouse on a rock. Four streets of five plots run diagonally, with a road along each street and a side road. There's grass and a tree line along the edges.

**Traffic you can see.** The number of cars driving on each street follows its traffic, at roughly one car per 10 traffic, up to 9.

**Living buildings.**

- A car wash has a tunnel, a door, and a water-drop sign. It bubbles with foam when it's making money, and cars queue in front of it when it's busy.
- A parking lot has painted stalls that fill up as traffic rises.
- Empty plots are bare dirt with a For Sale sign.

**Ownership.** Each owned plot has a flag and an outline in its owner's color. A name floats up when a bot buys, and "Sold" floats up when one sells.

**Floating money.** When the day ticks, the amount earned or lost rises off each of your businesses, in green or red.

**News on the map.** A bobbing "!" marker appears beside any street with a pending rumor. A flood puts water over the docks, and repaving puts cones on the road and slows the cars.

**Street labels.** Each street name has its daily price change next to it, with an up or down arrow.

**Night mode.** When the phone is in dark mode, the town turns to night: headlights on the cars, a lit car wash door, and a sweeping lighthouse beam.

**Interaction.** Tap a plot to select it, and a pulsing outline and a bouncing arrow appear above it. Pinch to zoom, drag to pan, and give a light haptic tick on selection.

### The plot panel shows

- Cars a day, plus the census trend.
- The price or sale value, plus today's street change.
- Daily earnings and the amount you put in, when it's yours.
- The pending rumor for that street, any damage or temporary closure, and context-specific buttons: Buy, Build a car wash, Build a parking lot (each showing its cost and estimated daily income), or Sell.

### Other screens and panels

A top bar with the day (1 of 40), cash, net worth, Auto, and Next day.

Standings with all five players, each with their style, plot count, net worth, and return.

A small line chart of your net worth against the leading rival.

A ledger of everything that happened.

A collapsible "How to play" with five rules:

1. You start with $12,000 and 40 days. Finish with the highest net worth.
2. Tap a plot, buy it, then build a car wash or a parking lot. Car washes earn more on busy streets and lose money on quiet ones.
3. Cars on each street show its traffic. A weekly census on every 7th day shifts it.
4. News arrives a few days before it lands. It might not happen.
5. Four rivals trade the same streets. When the crowd piles into a street, its prices climb.
