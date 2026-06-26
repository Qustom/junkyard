# Carry Load → Speed
**Category:** Tradeoff systems (extraction-binding) — DIRECTOR-PRIORITIZED

## The mechanic
The more you carry, the slower you move. Greed is no longer a number that only
matters at cash-out — it is a weight on your legs *during* the run. Each piece of
junk you grab now answers a second question beyond "is it worth the slot?": "is it
worth the speed?" A full bag is a felt liability the instant the timer dips, a
hazard wakes, or the Hunter rounds a corner.

The decision loop this creates: walk into a room, see junk + value, weigh it
against current load. Early in a dive, loose and fast, you grab freely. Late —
near-full, the dive clock warning fired, a pursuer behind you — every additional
pickup measurably worsens your escape. The flagship property is that the cost is
*continuous and physical*: it's paid the whole walk home, not as a one-time tax,
so the player feels their own greed the entire return trip. This is what binds
inventory, the clock, and the pursuers into one decision instead of three.

## What exists today
**Move speed is a single data constant.** `PlayerMovementStats.max_speed` (200
px/s) in `data/player/player_movement.tres`, scaled once in `player.gd`
`step_velocity()`. Acceleration/friction are untouched by anything.

**There is a perfect seam already.** R3 exposure already multiplies top speed:
`player.gd` caches `_exposure_speed_mult` from
`EventBus.exposure_speed_mult_changed(mult)` and applies it as
`stats.max_speed * _exposure_speed_mult` (defaults 1.0). A carry-load mult is the
*same shape* — a second multiplicative term, or its own signal.

**Load = slots-filled today; there is no weight.** `JunkItem` has `slot_size`
(1–9) and `grid_footprint` but **no `weight` field**. `RunInventory.used_slots()`
already sums `slot_size` against `max_slots` (12) — so a load ratio
`used_slots() / max_slots` is computable *right now* with zero new data. The bag
also emits `EventBus.run_inventory_changed(used, max)` on every add/remove — a
ready trigger to recompute the penalty.

**Existing greed pressure to relate to:** the E2 push/cash-out decision, the
`DiveClock` drain, R2 `ReturnCost` (depth-scaled exit toll), R3 exposure. All make
*pushing deeper* cost. None make *carrying more* cost — that's the missing axis,
and it's the most legible one because it's spatial and immediate.

## How to fit it in
- **Load metric:** start with **slot-fill ratio** (`used_slots()/max_slots`) — no
  new data, ships today. A later `JunkItem.weight` field upgrades the metric to
  density (a tiny dense ingot heavy for its slot) without touching the curve.
- **Speed curve:** a **soft-cap with a free band** beats linear. Below ~50% load,
  full speed (early grabbing stays frictionless). From 50→100% load, speed falls
  to a floor (~0.55× — never freeze; mirror R3's `SPEED_FLOOR=0.35`). Threshold
  bands read more clearly than a smooth ramp (Tarkov's tiers, below).
- **Dive clock:** slow + a draining clock = the squeeze — a heavy late bag
  literally costs you light on the walk back, compounding R2's exit toll.
- **Exposure:** stacks *multiplicatively* with R3 via the existing mult seam (two
  independent slow sources; floor the product so they can't lock you solid).
- **Pursuers / Hunter:** the load curve must dip the player's top speed **below a
  loaded pursuer's chase speed** (`r1_chase_speed`, preset 56 vs player 200) at
  high load — that's the moment "I can't outrun it carrying this" lands. Pairs
  hard with deliberate-drop (`i3`): drop junk to get fast again.
- **Pairs with** loadout-vs-cargo (`x3`) and deliberate-drop (`i3`).
- **RunConfig knob:** `carry_speed_enabled` + `carry_free_fraction` (free band) +
  `carry_floor_mult` + `carry_curve` (enum linear/threshold/soft_cap). All-off
  default reproduces baseline exactly (constant 200 px/s). Ideal A/B: free-band
  size and floor harshness.
- **Telemetry:** load-at-extract, peak-load, deaths-while-overloaded (load >
  free-band at death), drops-under-pursuit. The "is the greed tax felt?" proof.

## Research (cited)
- **Escape from Tarkov** — discrete weight *tiers* (underweight = no debuff;
  overweight ≈ 39–50 kg gates) that add slower move/sprint, louder steps, and
  faster stamina drain. Lesson: **tiered thresholds read as decisions** ("am I
  over the line?") better than an invisible continuous ramp; and the penalty is a
  *bundle* of felt effects, not one number.
- **Death Stranding** — cargo weight scales speed, stamina, and fall/topple risk;
  the felt-not-fiddly trick is an **auto-optimize button** so the *management* is
  one tap while the *consequence* (slow, tippy) is the gameplay. Lesson: keep the
  bookkeeping cheap; make the *movement* carry the tension.
- **Skyrim/Fallout encumbrance** — the cautionary tale: a hard "over-encumbered =
  can't run/fast-travel" wall feels like a *menu chore*, not a thrill, because
  there's no live threat punishing the slowdown. Our version only works because
  the clock + pursuers make the slow *immediately* dangerous.
- Felt-not-fiddly synthesis: **continuous penalty + threshold readout + a live
  threat that punishes it + a one-action escape valve (drop).**

## Graybox sketch
Smallest version, all from existing surfaces:
1. On `EventBus.run_inventory_changed(used, max)`, compute
   `load = used/float(max)`.
2. `mult = 1.0` if `load <= 0.5`, else `lerp(1.0, 0.55, (load-0.5)/0.5)`.
3. Emit a new `EventBus.carry_speed_mult_changed(mult)`; cache it in `player.gd`
   exactly like `_exposure_speed_mult`; apply as a second factor in
   `step_velocity` (`max_speed * _exposure_speed_mult * _carry_speed_mult`).
4. HUD: tint the load bar amber past the free band (the "you're getting slow" tell).
This proves the tension with **no new data, one signal, one cached float.**

## Open questions
- **Weight vs slot-count?** *Recommendation:* ship **slot-fill** for the graybox
  (zero data cost, immediate), add an *optional* `JunkItem.weight` later only if
  testers want dense-but-small to feel heavy. Don't gate the flagship on a data
  migration. **Director call.**
- **Curve harshness — where's the fun floor?** A 0.55× floor at full load is a
  guess. Too soft = no decision; too harsh = the bag feels like a punishment for
  playing well. **Needs playtest A/B (free-band size × floor)** — recommend
  free-band 0.5 / floor 0.55 as the first sweep. **Director call after data.**
- **Readability of a continuous slowdown.** Pixel-art top-down may not *show*
  speed loss clearly. *Recommendation:* pair the number with a discrete cue (load
  bar amber/red tiers + maybe a footstep/step-rate change) so the player *reads*
  the penalty, not just suffers it (the Tarkov-tier lesson). **Director: is a
  visible tier readout wanted, or keep it purely felt?**
