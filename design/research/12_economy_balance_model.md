# Economy Balance Model for THE FAR YARD — Research Report

*A research companion to the Technical Design Doc §9. Scope: how to model and balance THE FAR YARD's three-currency (Money / Salvage / Lore) economy under a debt-repayment pressure curve, and a concrete spreadsheet structure the team should build before tuning.*

---

## 1. The problem in one paragraph

THE FAR YARD is a faucet-and-drain economy wearing a roguelite-extraction costume. Each run pumps resources *in* (a faucet); buying tools, upgrades, and paying down debt pulls them back *out* (a drain). With three currencies and four upgrade tracks spread across multiple acts, the risk is not that any single number is wrong — it is that the *flows* drift out of balance: one currency floods while another starves, the debt either crushes the player in Act 1 or becomes trivial by Act 3, and an upgrade track sits unused because nothing it buys is worth the resource it costs. The discipline that prevents this is **source/sink (faucet/drain) accounting**: enumerate every way each currency enters and leaves the game, model the expected per-run inflow against the per-act outflow, and tune until the chains stay "taut." This report assembles the established frameworks for doing that and ends with a spreadsheet spec.

---

## 2. Faucets and drains: the core mental model

Every internal game economy is built from three primitive operations: **sources** (nodes that create tokens from nothing), **sinks** (nodes that destroy them), and **transforms/transports** that move and convert them ([Lost Garden, "Value chains"](https://lostgarden.com/2021/12/12/value-chains/)). A **gold sink** is simply any process that removes currency from circulation; without sinks, currency only accumulates and the result is inflation ([Wikipedia, "Gold sink"](https://en.wikipedia.org/wiki/Gold_sink)). The terms *faucet* and *drain* are the same idea framed as plumbing: resources are generated as needed (faucet), flow one way through designed transforms, and are deleted at the end (drain).

Daniel Cook's "value chains" framing is the most useful lens for a game like THE FAR YARD because it is **linear and analyzable** rather than a spaghetti of feedback loops:

- **Early stage = sources.** The player performs the *core gameplay* (a salvage run) and generates a steady flow of base resources.
- **Mid stage = transforms.** Those raw resources become a small number of intermediate goods (refined salvage, crafted parts).
- **End stage = sinks tied to an "anchor."** The player spends into a sink that grants access to whatever psychologically motivates them — paying off the debt, owning the yard, unlocking lore ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)).

The power of this model is that **a strong sink "pulls" resources up the whole chain**. If the debt and the upgrade tracks are desirable sinks, players are automatically motivated to run, salvage, and refine. A *broken* chain — a sink nobody wants, or a resource with no sink — kills the value of every node before it. That is the structural cause of a "dead currency."

Unity's economy guides reinforce the same picture: map your sources and sinks against time, keep them roughly balanced, but deliberately introduce **fluctuations in the sink** to create "pain points" (moments of scarcity that motivate engagement) followed by "moments of release" (abundance), so players stay engaged ([Unity, "Designing a balanced in-game economy"](https://unity.com/how-to/design-balanced-in-game-economy-guide-part-3)).

---

## 3. Designing three currencies with distinct roles

The classic free-to-play split is **soft currency** (earned by playing, abundant, used for routine purchases) vs. **hard/premium currency** (scarce, often bought with real money, gates the most desirable items) ([Wikipedia, "Video game monetization"](https://en.wikipedia.org/wiki/Video_game_monetization); [Wikipedia, "Hard currency"](https://en.wikipedia.org/wiki/Hard_currency)). THE FAR YARD is premium-free, so map the *roles*, not the monetization, onto its three currencies. The guiding principle from value-chain theory is **parallel chains**: keep each currency's faucets and sinks largely separate so each can be balanced in isolation without accidentally unbalancing the others ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)).

A proposed role split:

- **Salvage = the volume / "soft" currency.** High flow, earned every run, the raw fuel of the loop. Its primary sink is *crafting and refining* (transforms) and routine yard maintenance. It should feel abundant-but-spent — players always have some, never enough to ignore the next run. Because it is earned through repeatable runs, it behaves like a **grind/trickle source** and must be paired with **repeatable or exponential sinks**, never a fixed one (a fixed sink gets swamped over many runs).
- **Money = the "hard" pressure currency.** Scarcer, the thing the **debt sink** consumes. Money should be partly *derived* from Salvage (a transform: sell/refine salvage → money) and partly from distinct run sources (cash bounties, selling rare finds). This makes Salvage's value chain "pull" toward Money, which in turn pulls toward debt repayment — a clean three-node chain anchored on "get out of debt / own the yard."
- **Lore = the slow "prestige/knowledge" currency.** Low flow, gated, spent on the Knowledge/narrative track and the most powerful permanent unlocks. Lore should be a **capped or trickle source per act** (you can only find so much per region) so it can't be grinded infinitely, and it should gate progression rather than power, avoiding direct competition with Salvage/Money.

Keeping these as parallel chains that *converge only at deliberate transforms* (Salvage→Money) is the single most important architectural decision. It gives independence (balance one without breaking another) and modularity (retire or add an act's content without re-tuning everything) ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)).

---

## 4. Source and sink taxonomy (and how to match them)

Cook's taxonomy is the practical tuning vocabulary. **Five source types:** *Capped* (fixed total, x⁰), *Trickle* (fixed rate over time, linear x¹), *Grind* (uncapped, player-effort-limited, linear but highly variable), *Investment* (positive feedback loop — treat defensively as **exponential**), and *Random* (loot tables; average them for long-run balancing). **Four sink types:** *Fixed* (one-time removal, mirror of capped), *Repeatable* (per-action, mirror of trickle), *Exponential* (each linear gain costs geometrically more), and *Competitive* (adaptive, multiplayer-only — not relevant here) ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)).

The **matching rule** is the heart of numerical balance: *match the power of your sinks to the power of your sources.* Mismatches produce economies that are nearly impossible to balance ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)):

| Power class | Sources | Sinks |
|---|---|---|
| Constant (x⁰) | Capped | Fixed |
| Linear (x¹) | Trickle, Grind | Repeatable |
| Exponential (x¹⁺) | Investment | Exponential |

Concretely for THE FAR YARD:
- **Salvage** is a grind source → pair its main spend with **repeatable or exponential sinks** (per-craft costs; upgrade tracks whose tiers cost geometrically more). A *fixed* salvage sink would be trivialized after a few runs.
- **Upgrade tracks** are the natural **exponential sinks** — tier N+1 should cost meaningfully more than tier N. Exponential sinks "always have room to sop up more," which is exactly what soaks excess Salvage from a heavy grinder and prevents overabundance ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)).
- A critical warning: **avoid a true exponential source.** Investment loops (e.g., "upgrades that increase salvage yield, which buy more upgrades") explode for clever players. Cook's defensive move is to *cap* investment sources — a hard tier cap or limited upgrade slots converts a runaway exponential into a manageable trickle ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)). If yield-boosting tools exist, cap them.

The general aim is **taut chains**: sinks slightly stronger than sources, so there is mild ongoing demand without painful dead-stop scarcity, and without resources pooling into meaninglessness.

---

## 5. Inflation, overabundance, and dead currencies (the pitfalls)

The three named failure modes ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)):

1. **Overabundance / inflation.** Sinks weaker than sources → a resource accumulates in a pool nobody can spend. The motivational anchor is exhausted ("I own everything, why salvage another pile?") and the early nodes lose all pull. In MMOs this is "mudflation" — players drowning in useless gold and +10 swords ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/); [Wikipedia, "Gold sink"](https://en.wikipedia.org/wiki/Gold_sink)). *Defense:* exponential sinks (upgrade tiers), capped sources for Lore, and time-limited "events" that periodically suck hoarded resources back out.
2. **Scarcity / grind burnout.** Sinks far stronger than sources → the player must repeat an early node laboriously. *Defense:* watch the per-act inflow vs. outflow gap; lean only *slightly* taut. Note the difference between *power* and *magnitude*: faking a strong sink with a huge one-time cost feels grindy and breaks the moment you change run length — avoid substituting magnitude for power ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)).
3. **Dead currency / dead chain.** A resource with no desirable sink, or a sink with no clear anchor. Players report "X seems pointless." *Defense:* for every currency, name its anchor and confirm a sink connects to it. If Lore has nothing compelling to buy, it is dead by construction.

Two more long-run traps worth naming: **content treadmills** (heavy reliance on capped sources/fixed sinks means you must keep shipping new content to stay alive — prefer repeatable sinks for longevity) and **marginal-value erosion / burnout** (even a balanced trickle-and-repeatable pair wears out as repetition kills novelty; mitigate with "high-leverage" content and content recharge via forgetting) ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)).

---

## 6. Modeling methodology: per-act spreadsheets and expected value

Because THE FAR YARD has acts and a debt endpoint, it is closer to a **fixed-length game** than an endless live-service one, which is the *easy* case to model ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)). The method:

1. **List every source per currency, per act, in a spreadsheet**, and sum the capped + trickle totals a player will encounter across that act.
2. **List every sink per currency, per act**, and sum the fixed + repeatable totals.
3. **Golden-path modeling.** For trickle sources and repeatable sinks you must assume how many times an "ideal" player interacts with each (e.g., *N runs per act*). This golden path won't match every player, but it approximates earn/spend so you can compare faucet totals to drain totals per act ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)).

The faucet side of each run is an **expected-value (EV)** calculation. A run's reward is a probabilistic mix (random loot, variable enemy counts, success/failure of extraction). Compute `EV(run) = Σ (probability × payout)` for each currency. Increasing the number of independent reward events per run *reduces variance* and pulls actual outcomes toward the EV — useful for making "average run income" a number you can actually balance against ([game economy / spreadsheet practice summarized in](https://medium.com/strike-the-pixels/game-design-101-balancing-economy-5f3e5a7eecc5)). For random sources specifically, Cook's advice is to **balance against the average drop** rather than any single roll ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)).

Jamey Stevenson's widely-cited Excel method gives the concrete cell-level discipline ([Game Developer, "My Approach to Economy Balancing Using Spreadsheets"](https://www.gamedeveloper.com/design/my-approach-to-economy-balancing-using-spreadsheets)):
- **Color-code columns:** green = hand-entered design knobs; yellow = distribution/curve formulas; white = fully derived values you almost never touch directly.
- **Normalize inputs to 0–1** (`(x - min)/(max - min)`) before combining factors, storing the per-column min/max as named global variables.
- **Derive costs from weighted factors:** e.g., an item's cost is a weighted mean of its normalized power and rarity, with the weights as editable globals — so you re-tune behavior by changing *one* weight, not hundreds of cells.
- **Range-control variables** (e.g., `WeaponCostMax`) keep derived values inside a band — e.g., capping max upgrade cost to the max money a player can realistically hold by that act.

For deeper, simulation-based modeling beyond static spreadsheets, **Machinations** is the standard tool: a browser-based platform (co-founded by Joris Dormans) for diagramming and *simulating* economies as networks of sources, drains, pools, and feedback loops, letting you run thousands of plays to see how flows behave before you build them ([Wikipedia, "Joris Dormans"](https://en.wikipedia.org/wiki/Joris_Dormans); [Machinations articles](https://machinations.io/articles/category/game-economy-design)). Cook explicitly recommends it for exploring what these simulations look like, while cautioning that full feedback-loop simulations are hard to reason about and balance — a static value-chain spreadsheet is the better *first* pass ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)). The underlying theory is Dormans & Adams' *Game Mechanics: Advanced Game Design*, which formalized internal economies and feedback loops as the basis for Machinations.

---

## 7. Pacing the debt-repayment pressure curve

The debt is THE FAR YARD's master sink and its narrative anchor — the thing that pulls the whole Money chain. The design goal is a curve that feels *motivating, not crushing*. The shop-debt genre gives direct precedent. In **Recettear**, the player inherits an 820,000-pix debt and must pay an *escalating* weekly installment; missing a payment ends the run, and "the mounting repayments are the real concern" — by the time 200,000 pix is due you are "scrambling for every coin" ([PC Gamer](https://www.pcgamer.com/10-years-on-recettear-an-item-shops-tale-is-still-the-best-fantasy-shopkeeper-tycoon-game/); [Wikipedia, "Recettear"](https://en.wikipedia.org/wiki/Recettear:_An_Item_Shop%27s_Tale)). **CloverPit** likewise drives an *ever-increasing* debt where failure to pay ends the run ([Wikipedia, "CloverPit"](https://en.wikipedia.org/wiki/CloverPit)). The common pattern: **stepped, escalating installments with a fail state**, which manufactures recurring scarcity-then-release beats.

Principles for tuning it:

- **Escalate the installment slightly faster than baseline income grows, but slower than *upgraded* income grows.** This means a player who ignores upgrades feels rising pressure (motivation to engage the upgrade tracks), while a player who invests stays comfortably ahead. The debt curve should track the *upgrade* curve, not the raw faucet.
- **Use stepped milestones, not a single wall.** Per-act or per-week installments give frequent small wins (a release beat after each payment), echoing Unity's "dips followed by moments of release" and a smoothly upward-sloping difficulty curve rather than a spike ([Unity](https://unity.com/how-to/design-balanced-in-game-economy-guide-part-3); [Wikipedia, "Dynamic game difficulty balancing"](https://en.wikipedia.org/wiki/Dynamic_game_difficulty_balancing)).
- **State the player promise up front.** Cook stresses that long-term anchors must be *visible early* — tell the player "pay off the debt and own the yard" at the start so distant payments justify present grinding ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)).
- **Soften the fail state.** Pure "miss a payment → game over" (Recettear/CloverPit) is harsh for a life-sim audience. Consider extensions, partial payments, or a debt-collector grace period (as in *Samson*, three missed days before game-over) so failure is a setback, not an instant wall ([Wikipedia search result, "Samson (video game)"](https://en.wikipedia.org/wiki/Dynamic_game_difficulty_balancing)). The right harshness depends on audience — workshop it; a cozy-leaning player base is "repulsed" by punishing mastery pressure (Cook's Cozy Grove finding) ([Lost Garden](https://lostgarden.com/2021/12/12/value-chains/)).
- **Model it as a sink curve in the spreadsheet.** Plot cumulative debt-due against cumulative golden-path Money income per act; the gap *is* the pressure. Keep the gap small and positive (taut), widening briefly before each milestone for tension and closing on payment for release.

---

## 8. Proposed spreadsheet model (tabs, variables, formulas)

Build a single workbook. Use Stevenson's green/yellow/white color discipline throughout: **green = design knobs you tune, yellow = curve/distribution formulas, white = derived outputs.**

**Tab 1 — `Globals` (all green knobs in one place).**
Named variables only: `RunsPerAct`, `SalvagePerRun_EV`, `MoneyPerRun_EV`, `LorePerRun_EV`, `SalvageToMoneyRate`, per-track `CostBase` and `CostMultiplier` (the exponential factor), `DebtTotal`, `DebtInstallment_ActN`, `DebtGrowthRate`, and factor weights. Every other tab references these — never hard-code a number elsewhere.

**Tab 2 — `Sources` (faucets).**
One row per source, columns: `Currency | Type (Capped/Trickle/Grind/Investment/Random) | Act | PerEvent | EventsPerAct (golden path) | EV (= PerEvent × prob) | TotalPerAct (= EV × EventsPerAct)`. Pivot/sum `TotalPerAct` by Currency × Act → the **faucet total**.

**Tab 3 — `Sinks` (drains).**
One row per sink, columns: `Currency | Type (Fixed/Repeatable/Exponential) | Act | UnitCost | ExpectedPurchases | TotalPerAct`. For exponential upgrade tiers, `UnitCost_tierN = CostBase × CostMultiplier^N`. Sum by Currency × Act → the **drain total**.

**Tab 4 — `Run_EV`.**
Models a single run as a distribution: rows of `Outcome | Probability | Salvage | Money | Lore`; footer computes `EV` per currency = `SUMPRODUCT(prob, payout)` and a variance estimate. This feeds `*PerRun_EV` in `Globals`. Add a row for failed/aborted runs (probability of a wipe × its reduced payout) so EV is honest.

**Tab 5 — `Upgrade_Tracks`.**
Four blocks (one per track), each tier a row: `Tier | EffectValue | Cost (=CostBase×Mult^Tier) | CumulativeCost | RunsToAfford (=CumulativeCost / income_EV)`. The `RunsToAfford` column is your grind-detector — if it spikes, you have a scarcity wall; if it's near zero, overabundance. Derive `EffectValue` from normalized inputs × weighted factors (Stevenson method) so power scales smoothly with cost.

**Tab 6 — `Debt_Curve`.**
Rows = acts (or weeks). Columns: `Act | Installment (=prev × DebtGrowthRate) | CumulativeDue | CumulativeMoneyIncome (golden path) | Headroom (=income − due) | UpgradedHeadroom`. Chart `CumulativeDue` vs. `CumulativeMoneyIncome` vs. `UpgradedIncome` — the three-line graph that tells you instantly whether the debt is crushing, trivial, or taut.

**Tab 7 — `Balance_Dashboard`.**
Per Currency × Act: `FaucetTotal − DrainTotal = NetFlow`. Conditional-format: red if NetFlow strongly positive (inflation risk), red if strongly negative (grind/scarcity), green if slightly negative-to-zero (taut). One glance shows whether any of the three currencies or four tracks is broken.

**Tab 8 (optional) — `Sensitivity`.**
A data-table / what-if that varies `RunsPerAct` ±50% and `DebtGrowthRate`, showing how the dashboard reacts — this surfaces brittleness (the kind Cook warns about when length changes) before players do.

Workflow: tune **only** `Globals` and the yellow curve cells; everything else recomputes. Validate the model against a Machinations simulation or playtest telemetry, then iterate — and remember Unity's caution that you will not get it right the first time; the spreadsheet exists to make the second, third, and fourth passes cheap ([Unity](https://unity.com/how-to/design-balanced-in-game-economy-guide-part-3)).

---

## 9. Recommendations in brief

1. **Treat the economy as three parallel value chains** (Salvage / Money / Lore) that converge only at deliberate transforms (Salvage→Money). Balance each in isolation.
2. **Assign clear roles:** Salvage = abundant grind fuel (repeatable/exponential sinks); Money = scarce pressure currency feeding the debt sink; Lore = capped, gating progression not power.
3. **Match sink power to source power.** Use exponential upgrade-tier costs to soak grindable Salvage; cap any yield-boosting "investment" source to prevent runaway exponentials.
4. **Lean taut** — sinks slightly ahead of sources — and use deliberate scarcity/release beats for emotion.
5. **Pace the debt as stepped, escalating installments** that track the *upgrade* curve, stated as a player promise up front, with a softened fail state for the life-sim audience.
6. **Build the workbook above first**, drive everything from a single `Globals` tab, and validate with Machinations and/or telemetry before committing tuning numbers.

---

## Sources

- [Daniel Cook (Lost Garden), "Value chains – A method for creating and balancing faucet-and-drain game economies"](https://lostgarden.com/2021/12/12/value-chains/) — the primary framework: faucets/drains, source & sink taxonomy, power-matching, taut chains, balancing a fixed-length game, overabundance/scarcity, treadmills, anchors.
- [Unity, "Designing a balanced in-game economy: How-to guide (Part 3)"](https://unity.com/how-to/design-balanced-in-game-economy-guide-part-3) — sources-vs-sinks-over-time, pain points and release, A/B-testable variables, "you won't get it right the first time."
- [Jamey Stevenson (Game Developer), "My Approach to Economy Balancing Using Spreadsheets"](https://www.gamedeveloper.com/design/my-approach-to-economy-balancing-using-spreadsheets) — color-coded columns, normalized ranges, distribution equations, range-control variables, weighted factors.
- [Wikipedia, "Gold sink"](https://en.wikipedia.org/wiki/Gold_sink) — sinks/drains, inflation, mudflation.
- [Wikipedia, "Hard currency"](https://en.wikipedia.org/wiki/Hard_currency) and [Wikipedia, "Video game monetization"](https://en.wikipedia.org/wiki/Video_game_monetization) — soft vs. hard vs. premium currency roles.
- [Wikipedia, "Joris Dormans"](https://en.wikipedia.org/wiki/Joris_Dormans) — co-founder of Machinations; formal tools for game mechanics. (Underlying theory: Dormans & Adams, *Game Mechanics: Advanced Game Design*.)
- [Machinations.io — Game Economy Design articles](https://machinations.io/articles/category/game-economy-design) — simulation-based economy modeling tool.
- [GDC Vault, "Economic Balancing and Improved Monetization Through Clever Sink Design"](https://www.gdcvault.com/play/1020085/Economic-Balancing-and-Improved-Monetization) and ["Balancing Your Game Economy: Lessons Learned"](https://www.gdcvault.com/play/1015151/Balancing-Your-Game-Economy-Lessons) — practitioner talks on sink design and currency/pricing balance.
- [PC Gamer, "10 years on, Recettear... is still the best fantasy shopkeeper tycoon game"](https://www.pcgamer.com/10-years-on-recettear-an-item-shops-tale-is-still-the-best-fantasy-shopkeeper-tycoon-game/) and [Wikipedia, "Recettear: An Item Shop's Tale"](https://en.wikipedia.org/wiki/Recettear:_An_Item_Shop%27s_Tale) — escalating-debt pressure curve precedent.
- [Wikipedia, "CloverPit"](https://en.wikipedia.org/wiki/CloverPit) — ever-increasing debt with run-ending fail state.
- [Wikipedia, "Dynamic game difficulty balancing"](https://en.wikipedia.org/wiki/Dynamic_game_difficulty_balancing) — smoothly upward-sloping difficulty curve; debt-collector grace-period precedent.
- [Andrey Panfilov (Medium), "Game Design 101: Balancing Economy"](https://medium.com/strike-the-pixels/game-design-101-balancing-economy-5f3e5a7eecc5) — expected value and variance in run rewards.
