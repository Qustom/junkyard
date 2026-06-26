# Demand / Orders
**Category:** The economy itself

## The mechanic
A run can carry one (or a few) **optional buyer orders**: a named buyer wants **N of item X this run** for a **premium price** — paid only if you extract all N alive. "Cyrus's contact wants 3 temporal coils — 2.5× sell each if you bring all three." The order doesn't gate survival (miss it and you still cash out the haul); it *re-aims* the run by attaching outsized value to a specific `JunkItem` axis, which in turn pulls your routing toward the bands/rooms that hold X. It is the economy's **carrot**: a self-imposed side-quest that converts "grab the densest value" into "go deep for *that* thing." Orders refresh per run from a buyer; accepting one is a bet that the routing cost is worth the premium.

## What exists today
**Honest read:** no order/contract system exists. The GDD's surface life describes NPCs/buyers (Cyrus, the fence, the surface economy) as *flavor and sell endpoints*, not as request-issuing agents — there is no per-run order data, no "bring N of X" objective, no premium payout path. Selling (`F2_sell_screen.md`) is a flat itemized cash-out at `base_sell_value`; `RunRules` only models the *failure* downside (`pockets_fraction`), not buyer-side upside.

The **substrate is fully there**, though. `JunkItem` (`data/junk/junk_item.gd`) carries every key an order needs to match against: `id: StringName`, `tier (1–5)`, `origin_band`, `base_sell_value`. `GameState.banked_junk` is an `Array[JunkItem]` at cash-out, so "did you bring 3 of X?" is a filter+count over real identities, not a guess. Procgen already places junk **band-keyed and tier-thresholded** (`junk_placer.gd` scales drops by depth value curve + tier floor), so "where does X live?" is a deterministic property of the generated space.

**Differentiate from quota-variety** (`q3-quota-variety.md`): the quota is the **mandatory survival target** — miss it and you wipe. An order is an **optional premium** — pure upside you can decline. Same `JunkItem` axes, opposite stakes: quota = stick, order = carrot. (And from fluctuating prices `m1`: prices flex *passively* on what you happen to carry; an order is a *named commitment* with an all-or-nothing bonus.)

## How to fit it in
Model an order as data, rolled per run from a buyer's table:

```gdscript
class_name BuyerOrder extends Resource
@export var buyer_id: StringName                # ties to a GDD NPC/buyer
@export var match_id: StringName                # or tier/band filter (one axis)
@export var match_tier: int = 0                 # 0 = any
@export var match_band: String = ""             # "" = any
@export var count: int = 3
@export var premium_mult: float = 2.5           # applied to the N matched items
@export var all_or_nothing: bool = true         # partial = base price only
func filled_by(banked: Array[JunkItem]) -> bool
func describe() -> String                        # "Bring 3 temporal coils — 2.5x"
```

`filled_by()` runs at F2 cash-out over `banked_junk`; on fill, those N items pay `base_sell_value * premium_mult` instead of base. **Routing emerges for free**: an order keyed to a band/tier makes those `junk_placer` rooms the rational target — the order is *why* you push past the safe extract. Orders **stack with the quota** (filling an order's items usually advances a money/quantity quota too) and **stack with fluctuating prices** (an order is a guaranteed floor over a noisy market). The deep-dive incentive is the core payoff: the premium is sized to *just* offset the marginal risk of the extra rooms.

**RunConfig knob:** `orders_enabled: bool = false` (all-off reproduces the current no-order baseline byte-for-byte, per the standing contract), plus `orders_per_run` and an `order_premium_mult`. **Telemetry:** stamp `orders_offered`, `orders_accepted`, `orders_filled`, and `order_match_band/tier` so the gate reports **accept-rate and fill-rate per order kind** — the metric that exposes an order that's too generous (always taken) or unfillable (never filled).

## Research (cited)
Directed-objective economies are well-proven. **Recettear** and **Moonlighter** push the buyer-request loop directly: a customer *asks* for an item and pays a premium, which back-pressures your dungeon routing toward where that item drops — the closest analog to this mechanic. **Stardew Valley's Special Orders** board posts NPC requests ("collect N of X within a timeframe") for a reward — optional, time-boxed, item-keyed, exactly the carrot framing here. **Escape from Tarkov** task economy requires items **found-in-raid** ("the raid must end with Survived"), which is precisely "extract all N alive or it doesn't count" — strong grounding for `all_or_nothing` + the extraction gate, and players explicitly **plan loot routes** around which tasks are active. **Deep Rock Galactic Assignments** chain objective-bearing missions, and the genre lesson (vs. Hunt: Showdown's repetitive fixed bounty) is that *directed, varied requests* refresh a run better than a single rising number.

## Open questions
- **Optional vs. soft-mandatory.** Pure-optional risks being *ignored* if the premium is too small or the routing too costly. Tune `premium_mult` so accept-rate lands ~40–70% (a real choice), not 0% or 100%. (needs Director — fun call)
- **Reward size & all-or-nothing.** Does partial fulfillment pay anything, or strictly zero bonus? All-or-nothing is tense but feels-bad on a 2/3 near-miss (carried two, died for the third). Recommend a small partial credit unless playtest wants the sting.
- **Unfillable RNG roll.** Can an order key to an item the run's reachable bands can't produce ("3 far-band cores" on an early shallow run)? Same guard as q3: roll only orders satisfiable by the run's reachable depth, or gate deep-band orders behind run number. (needs guard, not Director)
- **Overlap with quota-variety.** If a typed quota *and* a typed order both key off `JunkItem`, do they collide or compound? Recommend: when both ship, forbid an order that *duplicates* the active quota's filter (else one fetch trivially clears both) — keep them aimed at different axes so the run pulls in two directions. (needs Director if both ship)
- **Buyer fiction.** Which GDD NPC issues orders, and does declining/failing one cost relationship (the Relationships track)? Pure-economic for M2; relationship coupling is a later hook. (needs Director — scope)

Sources:
- [Special Orders — Stardew Valley Wiki](https://stardewvalleywiki.com/Special_Orders)
- [Found in raid — Escape from Tarkov Wiki](https://escapefromtarkov.fandom.com/wiki/Found_in_raid)
- [Quests — Escape from Tarkov Wiki](https://escapefromtarkov.fandom.com/wiki/Quests)
- [Assignments — Deep Rock Galactic Wiki](https://deeprockgalactic.wiki.gg/wiki/Assignments)
