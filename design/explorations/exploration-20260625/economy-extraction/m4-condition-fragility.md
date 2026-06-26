# Condition / Fragility
**Category:** The economy itself

## The mechanic
Every junk item carries a **condition** (0.0–1.0, "Pristine → Battered"). It
starts at full and is **chipped by the world**: hazard hits (crusher piston,
flame vent) and — the key coupling — **being thrown**. Sell value scales with
condition, so a rare item *flung across the room to kill the pursuer* doesn't
just risk a miss, it **arrives at the sell screen worth less** (if it survives at
all). The throw verb gains a third, always-on stake beyond "did it hit / did I
get it back": **"was it worth degrading?"** The decision the Director wants —
*throw the cheap thing, not the rare one* — becomes the literal, costed default,
because the cheap thing has little condition-value to lose and the rare one has
a lot. Hard/charged throws (t1) hit harder and degrade more: power has a price.

## What exists today
**Item value is fixed.** `JunkItem.base_sell_value` (`data/junk/junk_item.gd`) is
a flat int credited at cash-out; F2's sell screen renders `entry["value"]`
straight from it (`F2_sell_screen.md`) and `value_per_slot()` divides the same
constant. There is **no condition field, no per-item state at all** — two copies
of the same `.tres` are economically identical.

**The throw has no value cost.** `entities/thrown_item/thrown_item.gd` resolves a
throw to exactly two outcomes: **kill** (item *consumed*, gone) or **miss** (item
*re-dropped unchanged* via `junk_dropped`). A successful retrieve returns the
item byte-identical. So today the spend-decision is binary — *lose it forever vs.
get it back whole* — with **no middle ground**. Hazards (`hazards/`) damage the
*player/clock*, never carried loot. **Missing:** a `condition` field on the
per-run item instance, degradation hooks on throw-fire / hazard-overlap / hard
impact, and a value formula that reads condition.

## How to fit it in
- **Data:** condition lives on the **run-state inventory entry**, not the
  `.tres` (the `.tres` is the shared template; condition is per-instance,
  per-run — respects the run/meta boundary). Add `condition: float = 1.0` to the
  RunInventory record. Sell value `= round(base_sell_value * lerp(floor, 1.0,
  condition))` with a `condition_value_floor` (e.g. 0.4) so a battered item is
  never *worthless*, just discounted.
- **Throw coupling:** in `ThrownItem`, debit condition **on fire** by a flat
  `throw_condition_cost`, and **extra on a hard/charged throw** (t1: scale the
  debit by the charge fraction `t` — the heavy hit that cracks a shell also
  scuffs the item most). A surviving **miss** re-drops the item at its *reduced*
  condition (carry the value forward through `junk_dropped`). A **kill** consumes
  it as today (condition moot). t5 throw-to-place degrades little; t6
  recall/retrieve is where you *get the dinged item back* and feel the loss.
- **Hazard coupling:** when a carried item overlaps a damaging hazard (or a
  thrown item *passes through* a flame vent en route), debit condition — flame =
  scorch, crusher = a big chunk. This makes hazard lanes a *loot-tax*, not just a
  player-tax.
- **The deepened decision:** facing the pursuer with one rare + three commons,
  the costed-correct play is *throw a common* — and if you must throw the rare,
  you watch its sell value visibly drop on extract. That is the Director's "visible
  cost" made concrete.
- **RunConfig knob + telemetry:** `fragility_enabled: bool = false` (all-off
  reproduces today's fixed-value baseline byte-identical, per the knob contract),
  plus `throw_condition_cost`, `hazard_condition_cost`, `condition_value_floor`.
  Emit a `condition_changed(item_id, from, to, cause)` row and a per-sale
  `value_lost_to_damage` total, plus tag throws by the thrown item's tier — so
  the gate sees **how much value players burn on throws** and **how often they
  throw a rare** (the behavior we're trying to shape).

## Research (cited)
- **Tarkov** gates *sellability* on durability (vendors reject weapons under ~60
  durability) and repair *lowers max durability* — condition as an ongoing
  economic pressure, not a one-time hit. Our softer analog: a **value floor**
  (discount, never reject) avoids the "now it's literal trash" feel-bad.
  ([Tarkov flea durability](https://forum.escapefromtarkov.com/topic/104647-fleemarkt-item-durability/), [vendor durability gate](https://www.gosunoob.com/guides/cant-sell-weapons-traders-jaeger-fence-mechanic-escape-tarkov/))
- **Breath of the Wild** is the cautionary tale: a ~52/48 split, with the core
  complaint that *too-brittle* items punish the very engagement the game wants
  (combat / here: throwing). The lesson is direct — **don't make fragility tax
  the signature verb so hard that players hoard and stop throwing.** Tune the
  per-throw debit small, the value floor high, breakage off by default.
  ([BotW durability analysis](https://medium.com/@JohnnyUzan/weapon-durability-in-breath-of-the-wild-botw-has-been-a-source-of-controversy-among-gamers-ever-675e9c1bdae0), [GameInformer critique](https://gameinformer.com/b/features/archive/2017/05/16/opinion-why-breaking-weapons-are-ruining-my-zelda-experience.aspx))

## Open questions (Director)
- **Does fragility punish the signature throw verb too much?** This is the central
  tension: the GDD wants players *throwing freely*, and a per-throw condition cost
  pushes the opposite (hoard the rare, never throw it). Recommend: cost is
  **value-only** (never destroys the item), debit is small for a baseline throw and
  only meaningful for *charged* throws of *high-tier* items — so the tax lands
  exactly on "I flung my best loot," not "I throw at all." **Needs Director review.**
- **Which items are fragile?** All junk, or a `fragile` flag on the `.tres` (glass
  curios degrade, scrap metal shrugs)? A flag adds an authoring axis and a
  silhouette/color tell, but more `.tres` surface. Recommend a flag, default off.
- **Repair as another sink?** A surface bench that restores condition for Money/
  Salvage closes the loop (degrade in the dive → pay on the surface) and feeds the
  three-currency economy — but it's an M3+ system, out of scope for a first probe.
- **Is "condition" legible mid-run?** If the player can't *see* an item dinged,
  the cost isn't "visible" as the Director asked. Needs a UI tell (a crack overlay
  / dimmed greybox) — defer to the UI role, but the mechanic depends on it landing.
- **Breakage (condition→0 = destroyed)** at all? Recommend **no** for the first
  pass (BotW lesson); value-floor only. Revisit if the floor makes the cost feel
  toothless.
```
