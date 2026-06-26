# Throw-to-Place vs. Throw-to-Hit
**Category:** Deepening the throw

## The mechanic
One button, two intents, disambiguated by charge. **Tap = soft place** — the held
item is lobbed a short, fixed distance and comes to rest as a *grabbable pickup*
(bait, a weight for a plate, a cache to retrieve later). **Charge/hold = damaging
throw** — the existing fast, straight-line projectile that kills a hazard or
re-drops on a miss.

A *placed* item is tactically distinct from a thrown one because it **persists and
interacts** rather than resolving instantly: it sits on the floor as a lure for an
eater/sound-zone, weighs down a pressure plate, or stashes a heavy haul item near
the exit to grab on the way out. The throw is a verb that *ends*; the place is a
verb that *leaves something behind*.

## What exists today
`thrown_item.gd` has exactly one outcome model: `setup()` launches a straight-line
`Area2D` at `_speed`/`_max_range`; on a `hazard` body it kills + **consumes** the
item, on a wall/range/lifetime it **re-drops** the item via
`EventBus.junk_dropped` (the JunkSpawner re-spawns a grabbable `JunkPickup`).

The re-drop is the seed of throw-to-place: a missed throw already *becomes a
placed item at a location*. What's missing is **intent** — today every throw is a
full-power kill attempt and "placing" only happens by failing. There is no
soft/short trajectory, no charge gate, no telemetry separating an *intended* place
from a *missed* hit. Damage/force is binary (free the body); there is no carry
state, no arc, no aim-assisted short toss.

## How to fit it in
- **Charge (`t1`) is the intent selector.** Below a charge threshold → place:
  reuse the `_miss()` path's `junk_dropped` emit, but with a short fixed
  `_max_range` (e.g. ~64px) and slow `_speed` so it lands deliberately at the
  reticle, *consuming no damage check*. At/above threshold → the current
  full-power projectile. `t1` already owns the charge curve; this only reads its
  output bucket.
- **Oppositions it feeds:** `hazards/6-weight-plate.md` (place an item to hold a
  plate down — needs the placed pickup to count as plate mass),
  `hazards/6-eater.md` + `hazards/4-sound-aggro-zone.md` (toss bait to a spot to
  pull aggro), `hazards/1-ambusher.md` (bait-trip a lurker from range).
- **Dive clock:** placing-then-retrieving costs seconds against the ~300s
  `dive_clock` — bait is a *time-for-safety* trade, the core tension knob.
- **DIFFERENTIATE from deploy/place (`u2`):** throw-to-place **lobs a normal
  inventory item a short distance** (any junk; it stays inert junk, just relocated
  and grabbable). Deploy/place sets down a **special, function-bearing object** at
  the player's feet (a trap, a beacon — a designed device, not relocated cargo).
  Throw-to-place is *logistics*; deploy is *equipment*.
- **Control mapping:** same throw button as today; charge-gated, so no new bind.
  Hold-to-throw, quick-tap-to-place (mirrors Spelunky's crouch-drop vs. throw and
  Death Stranding's hold-aim vs. release-toss).
- **RunConfig knob:** `throw_place_enabled` (default `false` → reproduces today's
  always-hit baseline), `throw_place_max_range`, `throw_place_charge_threshold`.
- **Telemetry:** `EventBus.throw_placed(item_id, depth, t_ms)` distinct from
  `throw_missed`; gate measures place-vs-hit ratio and bait → aggro-pull success.

## Research (cited)
**Death Stranding** uses hold-aim then release to *throw* cargo, vs. a menu
*place* — same held object, two delivery intents (improvised weapon vs. disposal/
delivery). **Spelunky** maps drop-vs-throw onto the *same* action button via
crouch/direction context — proof one input can carry both with a clear modifier.
General **tap-vs-hold** design guidance: tap = fast, forgiving, single commit
(place a waypoint); hold/charge = intentional, must show a fill so the player can
tell the modes apart — directly relevant to the intent-ambiguity risk below.

Sources:
- [Death Stranding: How to Throw Cargo — Twinfinite](https://twinfinite.net/guides/death-stranding-cargo-throw-how/)
- [Death Stranding Throw Cargo — GameRevolution](https://www.gamerevolution.com/guides/615248-death-stranding-throw-cargo-toss-packages-containers)
- [Controls — Spelunky Wiki](https://spelunky.fandom.com/wiki/Controls)
- [Spelunky 2: How to Pick Up & Throw — Twinfinite](https://twinfinite.net/guides/spelunky-2-pick-up-throw-objects-items/)
- [Tap & Hold interactions (Unity Input System) — Medium](https://medium.com/@codingcoremd/utilizing-the-hold-and-tap-interactions-to-trigger-different-animations-new-unity-input-system-bbd51d304094)

## Graybox sketch
Add a `place: bool` arg to `ThrownItem.setup()`. When `place`, override
`_speed`/`_max_range` with the short-toss constants and **skip the hazard kill
branch** — on landing always emit `junk_dropped` + a new `throw_placed`. Drive
`place` from a charge bucket in the player throw handler: release under threshold
→ `place=true`. Visual tell: the greybox draws a faint **landing-ring reticle** at
the predicted rest spot while charge is below threshold, and the charge bar arms
(brightens) once it crosses into damage range. That ring + bar is the whole "two
intents read clearly" test.

## Open questions
- **Intent ambiguity:** is a charge threshold legible enough mid-combat, or does a
  panicked tap that *meant* to kill become a useless soft drop at the player's
  feet? (Tester-feel call — Director.)
- **Overlap with deploy/place (`u2`):** if `u2` ships, are two "put something on
  the ground" verbs one too many? Recommend keeping both *only if* throw-to-place
  stays strictly "relocate inert junk at range" and deploy stays "special device
  at feet"; if that line blurs in playtest, merge. (Scope call — Director.)
- **Does a placed item count as plate mass / valid bait,** or only items flagged
  `bait`/`heavy`? Affects whether *any* junk is universally useful as a tool
  (powerful, maybe too much) vs. tagged subsets (more authored).
