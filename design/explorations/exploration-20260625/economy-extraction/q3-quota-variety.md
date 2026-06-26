# Quota Variety
**Category:** Quota system depth

## The mechanic
Today every run asks the same thing: bank $N of money or wipe. **Quota variety** makes the *requirement itself* roll per run, so each dive re-aims your optimization:

- **Money** — bank ≥ $N of cumulative value (today's quota; the baseline).
- **Specific item type** — deliver ≥ K junk of `tier`/`origin_band`/`id` X (e.g. "3 temporal-band parts"). Forces *what* you pick up, not just total value.
- **Rarity threshold** — extract at least one item of `tier ≥ T` (e.g. "a tier-4+ find"). Pushes you *deeper* even on a thin run.
- **Quantity** — bank ≥ Q items regardless of value. Rewards volume/footprint play; punishes cherry-picking single high-value pieces.

The point: stop every run collapsing to the same "maximize $/slot" greedy solve. A money run optimizes value density; a type run optimizes routing to a band; a rarity run optimizes depth-vs-time; a quantity run optimizes inventory throughput. Same map, different question.

## What exists today
`K2_quota_system.md` is **money-value-only and single-axis**: `quota_target: int` (a Money bar), `quota_base/quota_step` knobs, and a met-test of `achieved >= quota_target` where `achieved` is cumulative `money` (Q2 resolution). The escalation is purely numeric (`quota_target += quota_step`). There is **no objective abstraction** — the quota *is* an int.

But the substrate for typed quotas already exists. `JunkItem` (`data/junk/junk_item.gd`) carries everything a typed quota needs to key off: `id: StringName`, `tier: int (1–5)`, `origin_band: String`, `base_sell_value`, `slot_size`. `GameState.banked_junk` is an `Array[JunkItem]` (identities, not just a sum) at evaluation time — so a typed/rarity/quantity test can already iterate the real banked items. The hole is purely the **objective representation**: K2 collapses the banked bag to one int before testing it.

## How to fit it in
Promote the quota from an `int` to a **`QuotaObjective` Resource** (data, not code), rolled per run from a weighted table:

```gdscript
class_name QuotaObjective extends Resource
@export_enum("money","item_type","rarity","quantity") var kind: String = "money"
@export var amount: int = 50            # $ for money; K count for type/quantity; min tier for rarity
@export var item_tier: int = 0          # item_type/rarity filter (0 = any)
@export var item_band: String = ""      # item_type filter (""=any)
func met(banked: Array[JunkItem], money: int) -> bool
func describe() -> String                # the HUD line: "Bank 3 temporal parts"
```

`met()` reads `banked_junk` (already in scope at `_evaluate_quota`, K2 B.2) — money keeps the cumulative test; the other three iterate `banked` with the filter. Escalation bumps `amount` (or re-rolls `kind` on a met quota for variety).

A typed/rarity objective **pushes routing** (procgen, `procgen-bands/`): "tier-4+ find" sends you deep; "temporal parts" sends you to that band's rooms via `junk_placer.gd`'s band-keyed placement. That coupling is the *point* — the quota tells you which part of the generated space to chase.

**Differentiate from demand/orders** (`m2-demand-orders.md`): orders are a *buyer's optional bonus* — sell into a demand for extra money, an upside you can ignore. Quota-variety is the **survival requirement itself** — miss it and you wipe. Orders sweeten; the quota gates. They can coexist (and even reference the same `JunkItem` axes), but one is carrot, one is stick.

**RunConfig knob + telemetry:** a `quota_variety_enabled` master toggle (default OFF → reproduces K2 money-only baseline byte-for-byte, the standing all-off contract) plus a `quota_kind_weights` table. Stamp `objective_kind` onto the existing `quota_evaluated` row so the gate reports **completion rate per objective type** — the metric that says whether one kind is unfairly hard.

## Research (cited)
Objective variety is the standard antidote to single-metric staleness in this genre. **Deep Rock Galactic** ships eight mission types (Mining/quota, Deep Scan/Aquarqs, Egg Hunt/count), each pairing a primary objective with a bonus and a *different generated cave* — exactly the "objective re-aims the run + the space" coupling proposed here. **Lethal Company**'s pure-money quota is the cautionary baseline: a single rising metric that optimizes to one routine. **Escape from Tarkov** layers task variety per dealer (kill/place/deliver/find-in-raid) over the raid economy — varied *requirements*, not just varied *amounts*. **Hunt: Showdown**'s bounty is a fixed find-kill-extract loop with only daily-objective veneer, and is widely read as more repetitive than Tarkov's task tree — evidence that *amount* variety alone isn't enough; *kind* variety is what refreshes. **Spelunky**'s daily seed shows the orthogonal axis (same objective, varied layout) — useful but not a substitute for objective variety.

## Open questions
- **Objective-type balance.** A "tier-4+ find" quota and a "$50" quota are not equal difficulty on the same map/depth. Do we balance per-kind `amount` against the run's reachable depth/band, or accept variance? (needs Director — fun/fairness call)
- **Unfair RNG roll.** Can a rolled objective be *impossible* for the current band? "3 temporal parts" on run 1 (surface-only) is unwinnable. Need a guard: roll only objectives satisfiable by the run's reachable bands (couple the roll to procgen depth) — or restrict typed/rarity quotas to deeper run numbers.
- **Readability.** "What does this run want?" must be instantly legible on the HUD — a money bar is trivial, "3 temporal parts" + a progress counter is more UI. Does `describe()` + a live count fit the decision_hud projection cleanly? (ui-ux)
- **Met-basis coherence with K2.** K2's cumulative-money basis is forgiving (savings carry). Typed/quantity/rarity are inherently *this-run* (you can't "save up" a temporal part across wipes if banked_junk is sold). Does mixing a cumulative-money kind with this-run typed kinds confuse the stakes? (needs Director)
- **Scope.** Is this M1.5-greybox-able, or genuinely an M2 feature riding on real bands/recipes? Recommend: M2, after procgen bands are real enough to make typed routing meaningful.

Sources:
- [Missions — Deep Rock Galactic Wiki](https://deeprockgalactic.fandom.com/wiki/Missions)
- [Assignments — Deep Rock Galactic Wiki](https://deeprockgalactic.wiki.gg/wiki/Assignments)
- [Game Modes — Hunt: Showdown Wiki](https://huntshowdown.fandom.com/wiki/Game_Modes)
- [Escape From Tarkov vs Hunt Showdown — West Games](https://west-games.com/escape-from-tarkov-vs-hunt-showdown/)
