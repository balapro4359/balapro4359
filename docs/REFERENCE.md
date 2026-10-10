# Harborview reference

Test catalog for Appendix A of `docs/BRIEF.md`. Phase 3 writes one unit test for every rule id in the "Rules" section. Rules say what the engine does. The "Open" section is not a rule. Do not write a test that freezes an open item, and do not fill the gap in code.

Random inputs are arguments to the function under test. A test that needs "a random amount from −13 to +13" passes the amount in. Two runs with the same seed and the same actions must match (HV-GAME-04), once a seed exists. The order in which the engine consumes randomness is OQ-5, so a test must not depend on an unspecified stream.

Notation: `clamp(x, lo, hi) = min(hi, max(lo, x))`. Bounds written as `6–95` are inclusive: 6 and 95 are allowed values.

## Constants

These are the numbers Appendix A states. They are the Harborview entries for `tuning.dart` in phase 3. Nothing in the "Open" section belongs in that file until it is decided.

| Id | Name | Value |
|---|---|---|
| C01 | Solo season length | 40 days |
| C02 | Player starting cash | 12000 |
| C03 | Auto advance | 1 day per 1.5 seconds (UI timer, not an engine rule) |
| C04 | Streets | 4 |
| C05 | Plots per street | 5 |
| C06 | Docks base traffic | 55 |
| C07 | Main Street base traffic | 72 |
| C08 | Old Town base traffic | 42 |
| C09 | Edge Road base traffic | 22 |
| C10 | Starting-traffic clamp | 6 to 95 inclusive |
| C11 | Current-traffic clamp | 0 to 100 inclusive |
| C12 | Cars-a-day factor | × 12 |
| C13 | Cars-a-day noise | ± 9% |
| C14 | Land price intercept | 900 |
| C15 | Land price per traffic | 42 |
| C16 | Money round quantum | 10 |
| C17 | Car wash income slope | 5.5 |
| C18 | Car wash income intercept | −130 |
| C19 | Parking income slope | 2 |
| C20 | Parking income intercept | −25 |
| C21 | Building value, cost fraction | 0.40 |
| C22 | Building value, income multiple | 18 |
| C23 | Car wash build cost | 5000 |
| C24 | Parking lot build cost | 2500 |
| C25 | Sale proceeds | 0.95 of plot value |
| C26 | Sale fee | 0.05 of plot value |
| C27 | Demand per buy | +0.03 |
| C28 | Demand per sell | −0.03 |
| C29 | Multiplier start | 1.0 |
| C30 | Multiplier daily noise amplitude | 0.022 |
| C31 | Pull toward 1.0 | 0.03 |
| C32 | Multiplier clamp | 0.5 to 2.2 inclusive |
| C33 | Demand decay | × 0.45 |
| C34 | First rumor day | 3 |
| C35 | Announce, good demand | +0.07 |
| C36 | Announce, bad demand | −0.06 |
| C37 | Happens, good demand | +0.05 |
| C38 | Happens, bad demand | −0.10 |
| C39 | Does not happen, good demand | −0.10 |
| C40 | Does not happen, bad demand | +0.05 |
| C41 | Permanent base clamp | 3 to 98 inclusive |
| C42 | Bot plot cap | 3 |
| C43 | Bot buy cash buffer | 300 |
| C44 | Bot build extra cash | 500 |
| C45 | Forced buy day | 1 |
| C46 | Rita act chance | 0.50 |
| C47 | Omar act chance | 0.45 |
| C48 | Mei act chance | 0.40 |
| C49 | Dex act chance | 0.40 |
| C50 | Rita buy rise | over 2% on the 3-day change |
| C51 | Rita sell fall | more than 5% down on the 2-day change |
| C52 | Omar car-wash traffic | over 48 |
| C53 | Omar sell income | under 15 per day |
| C54 | Omar sell chance | 0.50 |
| C55 | Starting unowned parking lots | 2, and none of them on Edge Road |
| C56 | Rank field size | 5 (the player plus Rita, Omar, Mei, Dex) |

Event constants are HV-NEWS-08.

## Town layout

Exact plot names, in street order:

| Street | Base | Plots |
|---|---|---|
| The Docks | 55 | Pier 1, Pier 2, Pier 3, Pier 4, Pier 5 |
| Main Street | 72 | 101 Main, 115 Main, 130 Main, 144 Main, 160 Main |
| Old Town | 42 | Chapel Ln, Mill Row, Bell Ct, Tanner St, Well Sq |
| Edge Road | 22 | Lot 1, Lot 2, Lot 3, Lot 4, Lot 5 |

"Docks" in the event table is The Docks.

## Rules

### Game

**HV-GAME-01.** A solo Harborview game lasts 40 days and shows the day as "1 of 40" through "40 of 40".

**HV-GAME-02.** The player starts with cash 12000. Net worth is cash plus the plot value of every plot that player owns. Bots are included when a bot's net worth is shown. What a bot starts with is OQ-7.

**HV-GAME-03.** "Next day" advances one day. Auto advances one day every 1.5 seconds. Auto is a client timer. The engine exposes a single advance-one-day operation.

**HV-GAME-04.** The same seed and the same list of player actions produce the same world and the same list of tick events.

**HV-GAME-05.** Phase 3 actions are: buy a plot, build a car wash, build a parking lot, sell a plot to the city, advance one day. There is no share trade, no house, no tax, no loan, no other city, and no order window. Those arrive in later phases.

### Town

**HV-TOWN-01.** The town has the four streets and twenty plots named above, five per street, with those base traffics.

**HV-TOWN-02.** A plot's starting traffic is `clamp(streetBase + jitter, 6, 95)`. The legal set of `jitter` is OQ-5. Tests pass `jitter` in. For every allowed jitter, the result is inside 6–95 inclusive.

**HV-TOWN-03.** At setup, exactly two plots have a parking lot, both are unowned, and neither is on Edge Road. Which two is a random draw (OQ-5). Tests assert the count, the type, the lack of owner, and the street constraint. They do not assert particular addresses unless they pass the selection in.

**HV-TOWN-04.** A plot has at most one building. The build action applies to a plot the actor owns that has no building. Buy applies to a plot nobody owns. Sell applies to a plot the actor owns. Appendix B's panel offers Buy, or Build a car wash, or Build a parking lot, or Sell, as the matching action, not as a set of always-on buttons.

### Traffic

**HV-TRAFFIC-01.** Current traffic is `clamp(base + sum of active temporary modifiers, 0, 100)`.

**HV-TRAFFIC-02.** Cars a day, before noise, is current traffic × 12. The value shown to the player is that quantity with ±9% noise, rerolled every day. Income, land price, and building value use current traffic, not the noisy cars-a-day figure. How the ±9% draw is distributed, and whether the shown number is rounded, is OQ-5 and OQ-4.

**HV-TRAFFIC-03.** On a census day, each plot's base changes by a census draw. The panel trend is rose if the change is positive, fell if negative, and flat if zero. Which days are census days, the legal census draws, and any clamp on the new base are OQ-10 and OQ-5.

### Prices and income

**HV-PRICE-01.** Land price is the nearest $10 of `(900 + traffic × 42) × streetMultiplier`. The multiplication happens before the rounding. Traffic here is current traffic (HV-TRAFFIC-01).

**HV-PRICE-02.** When the raw land price is not exactly halfway between two multiples of 10, it rounds to the closer multiple. Halfway cases are OQ-4. Do not assert them.

Worked land prices at multiplier 1. These raw values are not halfway:

| Traffic | Raw | Land price |
|---|---|---|
| 0 | 900 | 900 |
| 6 | 1152 | 1150 |
| 22 | 1824 | 1820 |
| 42 | 2664 | 2660 |
| 55 | 3210 | 3210 |
| 72 | 3924 | 3920 |
| 95 | 4890 | 4890 |
| 100 | 5100 | 5100 |

Traffic 55 and multiplier 0.5 has raw 1605, which is halfway. Leave it untested until OQ-4.

**HV-PRICE-03.** Car wash daily income is `traffic × 5.5 − 130` while the building is open, and 0 while damage has it closed.

**HV-PRICE-04.** Parking lot daily income is `traffic × 2 − 25` while open, and 0 while closed.

**HV-PRICE-05.** For integer traffic, car wash income is negative at traffic 23 and below (`23 × 5.5 − 130 = −3.5`) and positive at 24 and above (`24 × 5.5 − 130 = 2`). Parking income is negative at 12 and below (`12 × 2 − 25 = −1`) and positive at 13 and above (`26 − 25 = 1`).

**HV-PRICE-06.** Building value is `max(0.40 × buildCost, dailyIncome × 18)`. Car wash cost fraction is 2000. Parking lot cost fraction is 1000. A negative income does not pull building value below the cost fraction.

**HV-PRICE-07.** An empty plot has building value 0. Plot value is the nearest $10 of `landPrice + buildingValue`. The same halfway rule as HV-PRICE-02 applies, and halfway sums are OQ-4.

Worked values at traffic 55 and multiplier 1, land price 3210:

| Building | Income | Income × 18 | Building value | Sum | Plot value |
|---|---|---|---|---|---|
| None | — | — | 0 | 3210 | 3210 |
| Parking lot | 85 | 1530 | 1530 | 4740 | 4740 |
| Car wash | 172.5 | 3105 | 3105 | 6315 | halfway, OQ-4 |

**HV-PRICE-08.** Build costs are 5000 for a car wash and 2500 for a parking lot. Paying the cost happens when the building is placed. A new building's daily income is 0 on the day it is placed and starts the next day. Whether building value uses that 0 on the placement day is OQ-14. Tests of the value formula take daily income as an input and do not assume the placement-day answer.

**HV-PRICE-09.** Buying transfers the plot to the buyer and subtracts the plot value from the buyer's cash. The buyer must have enough cash to pay the plot value. (The bot buffer in HV-BOT-02 is an extra bot constraint, not a player constraint.)

**HV-PRICE-10.** Selling to the city transfers the plot, building included, back to unowned, and adds `0.95 × plotValue` to the seller's cash. The fee is `0.05 × plotValue`. Whether those products are rounded is OQ-4. For the non-ambiguous case plot value 4740, `0.95 × 4740 = 4503` and `0.05 × 4740 = 237`.

### Crowd pricing

**HV-MKT-01.** Each street has its own multiplier and its own demand. The multiplier starts at 1.0. Starting demand is OQ-6. Tests of the update function pass the starting demand in.

**HV-MKT-02.** A completed buy on a street adds 0.03 to that street's demand. A completed sell subtracts 0.03. Two buys add 0.06. Buys and sells on other streets do not change this demand. Player actions and bot actions both count. The two setup parking lots are not buys.

**HV-MKT-03.** The daily street update, given the current multiplier `m`, the current demand `d`, and a noise draw `n`, is:

```
m = m * (1 + d + n)
m = m + 0.03 * (1 - m)
m = clamp(m, 0.5, 2.2)
d = d * 0.45
```

`n` is the random draw from −0.022 to +0.022. The legal set of `n` is OQ-5. Tests pass `n` in. The pull toward 1.0 is 3% of the gap, applied after the demand-and-noise multiply and before the clamp. Demand decays after the clamp, and the decay uses the demand that went into the multiply.

Worked updates:

| m in | d in | n | m out | d out |
|---|---|---|---|---|
| 1 | 0 | 0 | 1 | 0 |
| 1 | 0.03 | 0 | 1.0291 | 0.0135 |
| 1 | −0.03 | 0 | 0.9709 | −0.0135 |
| 2.2 | 0.5 | 0.022 | 2.2 | 0.225 |

The last row's pre-clamp value is `2.2 × 1.522 = 3.3484`, then `3.3484 + 0.03 × (1 − 3.3484) = 3.277948`, then clamped to 2.2.

**HV-MKT-04.** Multiplier history is kept for every street. Yesterday's change, the 2-day change, and the 3-day change are derived from that history. The formula that turns two history points into a change is OQ-12. Rita's thresholds use that change: she needs the best 3-day change to be over 2% (strictly greater than 0.02), and she sells when a street she owns fell by more than 5% over 2 days (strictly worse than −0.05).

**HV-MKT-05.** When rumor demand and buy/sell demand change the same street, they change the same demand number. Announcing or resolving a rumor does not write the multiplier directly. The multiplier moves when HV-MKT-03 runs. Where that run sits relative to announces, resolves, buys, and sells inside the day is OQ-3.

### News

**HV-NEWS-01.** The first rumor is announced on day 3. Further rumors are announced on a gap of 4, 5, or 6 days. What the gap is measured from is OQ-11.

**HV-NEWS-02.** A rumor is decided 3, 4, or 5 days after its announcement day. The legal delays are OQ-5. Each street has at most one rumor that has been announced and not yet decided.

**HV-NEWS-03.** Events are drawn from a deck of the eight events in HV-NEWS-08. A shuffle draws without replacement, so an event is not announced again while it is still out of the deck. What happens on the draw after the eighth distinct announcement is OQ-11.

**HV-NEWS-04.** On announcement, good news adds 0.07 to that street's demand and bad news subtracts 0.06. No traffic effect is applied at announcement.

**HV-NEWS-05.** If the event happens, apply HV-NEWS-06, then add 0.05 demand for good news or subtract 0.10 for bad news. If it does not happen, apply no traffic effect, then subtract 0.10 demand for good news or add 0.05 for bad news. The chance in HV-NEWS-08 is the probability that it happens.

**HV-NEWS-06.** A permanent effect adds `stated + permanentJitter` to the base traffic of every plot on that street, then clamps each base to 3–98 inclusive. A temporary effect adds a modifier of the stated amount to current traffic for the stated number of days, with no ±3. Damage sets every building on that street closed for the stated number of days. While closed, HV-PRICE-03 and HV-PRICE-04 return 0. The building is still there when the closure ends. Whether the decision day counts toward the duration, and whether `permanentJitter` is per plot or per street, are OQ-11.

**HV-NEWS-07.** Storm flood is the only one of the eight events that closes buildings. Repaving changes traffic and does not close buildings.

**HV-NEWS-08.** The deck is exactly these eight events.

| Id | Event | Street | Polarity | Chance | Effect |
|---|---|---|---|---|---|
| ferry | Ferry terminal | The Docks | Good | 0.60 | Permanent +20 |
| storm | Storm flood | The Docks | Bad | 0.50 | Temporary −30 for 6 days, and buildings closed for 4 days |
| highway | Highway exit | Edge Road | Good | 0.45 | Permanent +28 |
| repaving | Repaving | Main Street | Bad | 0.75 | Temporary −32 for 6 days |
| market | Market hall | Old Town | Good | 0.55 | Permanent +16 |
| yard | Shipping yard leaves | The Docks | Bad | 0.40 | Permanent −14 |
| arena | Sports arena | Main Street | Good | 0.50 | Permanent +12 |
| mill | Mill closes | Old Town | Bad | 0.45 | Permanent −12 |

Worked permanent result with jitter 0. A Docks plot at base 55 becomes 75 after a ferry that happens. A Docks plot at base 95 becomes 98, because `clamp(115, 3, 98) = 98`. A plot at base 6 after the yard leaves becomes `clamp(6 − 14, 3, 98) = 3`.

Worked temporary result. A Docks plot at base 55 during a storm that happens has current traffic `clamp(55 − 30, 0, 100) = 25`, and its buildings are closed. An Edge Road plot at base 22 during a hypothetical −30 would be `clamp(22 − 30, 0, 100) = 0`. Storm does not target Edge Road. This row only checks the clamp.

**HV-NEWS-09.** Each event has one rumor line, one happened line, and one did-not-happen line. The ferry lines are from the brief. The other lines are the phase 1 draft (OQ-16).

| Id | Rumor | Happened | Did not happen |
|---|---|---|---|
| ferry | The port authority is weighing a ferry terminal on the docks. | Ferry terminal approved. Dock traffic is up for good. | Ferry terminal plan shelved. |
| storm | Forecasters are tracking a storm that could flood the docks. | The storm floods the docks. Traffic drops and the buildings close. | The storm misses the harbor. |
| highway | The county is considering a highway exit on Edge Road. | Highway exit approved. Edge Road traffic is up for good. | Highway exit plan shelved. |
| repaving | Main Street may be torn up for repaving. | Repaving starts. Main Street traffic is down for a while. | The repaving plan was postponed. |
| market | The council is weighing a market hall in Old Town. | Market hall approved. Old Town traffic is up for good. | Market hall plan shelved. |
| yard | Word is the shipping yard may leave the docks. | The shipping yard is leaving. Dock traffic is down for good. | The shipping yard is staying. |
| arena | A sports arena is proposed beside Main Street. | Sports arena approved. Main Street traffic is up for good. | Sports arena plan shelved. |
| mill | The mill in Old Town may close. | The mill has closed. Old Town traffic is down for good. | The mill is staying open. |

### Bots

**HV-BOT-01.** The solo rivals are exactly Rita, Omar, Mei, and Dex, labelled as bots. Styles: Rita follows the crowd, Omar counts cars, Mei spreads her bets, Dex sells on bad news.

**HV-BOT-02.** A bot that owns 3 plots does not buy. A bot buys only if `cash − plotValue >= 300` after the purchase. A bot builds only if `cash >= buildCost + 500` for the building it is about to place. If it cannot meet that test for its preferred building, it tries a parking lot under the same test. If the parking lot also fails, it does not build. Mei's preferred building is the parking lot, so she does not try a car wash. Confirm the fallback buffer in OQ-9 if this combination of the two sentences is wrong.

**HV-BOT-03.** On day 1 each bot makes a forced buy. What "forced" skips is OQ-8.

**HV-BOT-04.** Selling checks run every day, including days the act roll fails. The act chance gates buying and building only.

| Bot | Act chance | Buy predicate | Build preference | Sell predicate |
|---|---|---|---|---|
| Rita | 0.50 | Cheapest plot on the street with the best 3-day rise, and only if that rise is over 2% | Car wash | A street she owns whose 2-day change is worse than −5% |
| Omar | 0.45 | The plot with the highest current traffic | Car wash if that plot's traffic is over 48, otherwise parking lot | A building whose daily income is under 15, with probability 0.50 |
| Mei | 0.40 | Cheapest plot on a street where she owns nothing | Parking lot | Never |
| Dex | 0.40 | A random unowned plot | Car wash or parking lot with equal chance, then HV-BOT-02 | Every plot he owns on a street with a pending bad rumor |

**HV-BOT-05.** "Over 48" and "over 2%" are strict. Traffic 48 is a parking lot for Omar. A 3-day rise of exactly 2% does not let Rita buy. "More than 5%" and "under $15" are strict. A 2-day change of exactly −5% does not make Rita sell. Income of exactly 15 does not make Omar sell.

**HV-BOT-06.** Dex's sell predicate is true for a street with an announced, undecided, bad event, and false for good news and for streets with no pending rumor. He sells every plot he owns on each such street.

**HV-BOT-07.** Mei never sells, including on day 1 and including when she is holding a losing building.

Open inside these predicates, and not to be frozen by a test: which plot they build on (OQ-9), whether Omar rolls once per qualifying building or once for the whole turn (OQ-9), tie-breaks (OQ-13), the change formula (OQ-12), and the day-1 override (OQ-8).

### End of the game

**HV-END-01.** The result is available on day 40 and ranks the player among five: the player, Rita, Omar, Mei, and Dex. Whether day 40's income and events run first is OQ-3.

**HV-END-02.** The card includes rank, net worth (HV-GAME-02), return, total earned from businesses, the count of the four streets invested in, and the best sale, and it offers Play again. The definitions of return, total earned, streets invested in, and best sale are OQ-15. Tests should assert that those fields are present once OQ-15 is answered. Until then, assert rank field size and net worth only.

**HV-END-03.** Play again starts a new solo game under HV-GAME-02 and HV-TOWN-03.

### Tick events

**HV-EVT-01.** Advancing a day and applying an action each return a list of events. The list is the only source for the ledger. Event kinds used by Harborview are: earned, bought, sold, rumor announced, rumor decided. `order filled` and `city grew` are later-phase kinds. They are not required in phase 3.

## Appendix B numbers that are presentation

These are not engine rules. Phase 8 uses them. "Roughly" is the brief's word for the car count.

| Item | Value |
|---|---|
| Cars drawn on a street | about 1 per 10 traffic, capped at 9 |
| Type size | nothing below 12pt |
| Button size | at least 48 by 48 points |
| Selection haptic | a light tick |
| Night mode | follows the phone's dark mode |

The five "How to play" sentences are copied in `docs/BRIEF.md` Appendix B. Show those sentences. Do not add a sixth that explains a bubble, a tax, or a lesson.

## Open items

Not rules. The write-up is `docs/DECISIONS.md`.

| Id | Gap |
|---|---|
| OQ-2 | One day-tick in phase 3, versus the fast and slow clocks |
| OQ-3 | Order of operations inside a day, and what day 40 includes |
| OQ-4 | Halfway rounding, income precision, sale rounding, negative cash |
| OQ-5 | Which random draws exist, and their distributions |
| OQ-6 | Starting demand |
| OQ-7 | Bot starting cash |
| OQ-8 | What the day-1 forced buy skips |
| OQ-9 | Which plot a bot builds on, the parking-lot fallback buffer, and Omar's sell roll |
| OQ-10 | Census day numbers and base clamp |
| OQ-11 | Rumor gap, pending-street collision, deck refill, ±3 scope, effect timing |
| OQ-12 | How a 2-day or 3-day change is computed |
| OQ-13 | Tie-breaks, including the result card |
| OQ-14 | Building value on the day it is built |
| OQ-15 | Return, total earned, streets invested in, best sale |
| OQ-16 | Approval of the seven draft rumor lines |

## Phase 3 test map

Every id from HV-GAME-01 through HV-EVT-01 in the Rules section gets a test. Presentation rows do not. Open ids do not.

Suggested split, so the formulas stay pure and the unspecified day loop stays out of the assertions:

- Layout and setup invariants: HV-TOWN-01, HV-TOWN-03, HV-GAME-02
- Pure pricing: HV-PRICE-01 through HV-PRICE-07, HV-PRICE-10's 4740 case
- Pure traffic: HV-TRAFFIC-01, HV-TRAFFIC-02's un-noised cars figure, HV-PRICE-05
- Pure street update: HV-MKT-03, including the four worked rows
- Pure rumor effects: HV-NEWS-04, HV-NEWS-05, HV-NEWS-06 with jitter and duration passed in, HV-NEWS-08
- Predicate tests with history and cash passed in: HV-BOT-02, HV-BOT-04, HV-BOT-05, HV-BOT-06, HV-BOT-07
