# Burrower
**Category:** Pursuers & movement enemies

## The idea
A pursuer that travels **underground** — invisible and **un-hittable while buried** — tracking
your position below the floor, then **surfaces to attack** on a rhythm before diving again. The
only window to hurt it (or to safely cross its turf) is the brief moment it's above ground.

The behavioral distinctness: it inverts the throw-kill loop's core assumption that the threat
is *always a valid target*. Against the Burrower, your throw is useless most of the time —
**you must wait for the surface window**, which means the skill is *patience and reading the
rhythm*, not reaction. And because it ignores walls underground, it **denies an area on a
timer** rather than chasing through corridors — a zone you cross *when it's down*, not a body
you flee. No other enemy makes "the ground itself is unsafe on a beat."

## How it fits THE FAR YARD
- **Move:** crossing its territory is a rhythm read — move while it's buried-and-far, freeze or
  reposition before it surfaces under you. Reuses movement; the enemy adds a vertical state the
  player can't directly touch.
- **Throw:** the throw is gated to the surface window — you bank an item-throw for the ~1s it's
  exposed. This makes the throw a *committed, timed* punish (the opposite of the Charger's
  generous recovery window), adding variety to how the throw verb is used across the roster.
- **Extract pressure:** a Burrower patrolling the lane to the gate means you time your dash to
  extract around its dive cycle — costing seconds and nerve. Direct push/cash-out tax on the
  exit.
- **Systems reused:** `HazardEntity` with a `BURIED`/`SURFACED` state. While `BURIED`:
  `collision_layer` cleared (off the `hazard` mask) so the throw passes through and the body
  is non-lethal-on-contact; a ground decal/rumble telegraphs its tracked position. While
  `SURFACED`: back on the `hazard` layer (throw-killable, contact-fatal). Burrowing ignores
  `world` collision (moves under walls). Knob group `bur_*` (`bur_buried_s`, `bur_surface_s`,
  `bur_track_speed`, `bur_telegraph_lead_s`), off by default.
- **First appears:** Band 2 (Temporal) and deeper — a "stranger entity" that suits the band's
  escalation; too mechanically rich for the Band-1 intro.

## Graybox sketch
States: `BURIED` (invisible body + a moving floor decal that tracks toward the player at
`track_speed`; un-hittable) → `TELEGRAPH` (decal pulses for `telegraph_lead_s`) → `SURFACED`
(visible circle, on `hazard` layer, lethal + throwable, holds `surface_s`) → back to `BURIED`.
Smallest proof: one Burrower, a tracking decal, a surface pulse — can the player read the
rhythm well enough to cross safely and to land a surface throw? The decal legibility *is* the
test.

## Synergies & counters
- **+ open rooms / loot fields:** a Burrower under a field of pickups makes greedy looting a
  rhythm game (grab between surfaces).
- **+ Pack/Patroller:** forced to stand still for a Patroller cone while a Burrower's surface
  window approaches = real depth tension.
- **Counters:** read the telegraph and reposition off its surface point (free); throw during
  the surface window (timed item cost); or just *wait it out* and cross while it's buried-and-far
  (costs dive-clock).

## Open questions
- Does the buried decal show its *exact* position, or just a vague rumble area? Exact = fair but
  trivial; vague = tense but risks feel-bad surprise surfaces. **Recommend a clear telegraph,
  vague tracking — flag the fairness line to Director.**
- Surface attack: does it lunge at the player on surfacing, or just *be lethal where it pops*?
  A lunge is scarier; a static pop is more readable. **Recommend static pop for greybox clarity.**
- Can it surface *through* a pickup/wall, and does surfacing under the player guarantee a hit
  (unfair) or give a dodge frame? Must give a dodge frame (the telegraph). **Technical fairness.**
- Is "un-hittable while buried" frustrating with the throw-centric verb set, or a welcome
  change of pace? It's a deliberate counter-lesson to throw-everything — but verify it doesn't
  just feel like the throw "doesn't work." **Fun call — Director, validate at the gate.**
