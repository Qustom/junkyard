# Charger
**Category:** Pursuers & movement enemies

## The idea
A heavy thing that sits dormant in the junk until your position crosses an invisible
sightline (a straight lane it "watches"). When you cross it, it telegraphs for a beat,
then **rushes in a straight line at high speed**, overshoots well past where you were,
and must spend a long, vulnerable recovery window decelerating/turning before it can
charge again.

The behavioral distinctness: every other pursuer in THE FAR YARD reads as a *chase you
solve by distance* (the R1 pursuer you run from, the I2 wall-refuge). The Charger inverts
it — **standing still is the trap and moving across it at the right moment is the answer.**
It forces a *timing + positioning* read, not a footrace. You bait the charge, sidestep
perpendicular to its lane, and the level geometry behind it does the work. It is the first
enemy that rewards you for being calm and still.

## How it fits THE FAR YARD
- **Move:** the whole fight is a perpendicular dodge — its straight-line lock means lateral
  movement always beats it. Reuses the existing `player.facing`/movement with no new verbs.
- **Throw:** during the long recovery window it is a free, stationary target — the throw
  verb (Space, mask `hazard`=16) reads as a deliberate *punish*, not a panic toss. This is
  the cleanest "bait → dodge → throw the recovery" loop in the roster.
- **Extract pressure:** a Charger parked in a corridor *denies the lane on a rhythm* — you
  either time a crossing or burn dive-clock seconds routing around it. Direct push/cash-out
  tax.
- **Systems reused:** it's a behaviour branch on `HazardEntity` (CharacterBody2D, `hazard`
  layer, no health → `queue_free` on throw-kill; catch → `GameState.fail_run(&"death")`).
  Charge = `move_and_slide` along a locked vector; overshoot is just "don't re-target until
  recovery ends." A `r1_`-style knob group (`chg_charge_speed`, `chg_recover_s`,
  `chg_sightline_len`), all off/neutral by default per the M1.5 contract.
- **First appears:** Band 1 (Near) as a slow, readable telegraph; Band 2+ shortens the
  telegraph and lengthens the lane.

## Graybox sketch
States: `DORMANT` (still) → `TELEGRAPH` (0.4–0.7s shake/flash, lane drawn as a debug line) →
`CHARGE` (locked-vector `move_and_slide` at high speed until it hits a wall or travels
`charge_len`) → `RECOVER` (frozen `recover_s`, visibly stunned) → back to `DORMANT`.
Trigger: player crosses the sightline ray. Smallest fun proof: one Charger, one debug-line
sightline, a stun colour during RECOVER, and the existing throw — does "bait, sidestep,
throw the stun" feel good? No art.

## Synergies & counters
- **+ walls/pits:** a Charger aimed at a hazard or wall *self-destroys or self-stuns* — the
  player's job is to be the bait that lines it up.
- **+ Leaper/Burrower:** a Charger that can't be baited into geometry forces the throw answer.
- **Counters:** sidestep (free), throw during RECOVER (costs an item), or simply never cross
  its lane (route around — costs time). Three honest answers at three different costs.

## Open questions
- Does the charge stop at the first wall, or punch through soft junk? (Punch-through is
  cooler but needs destructible props we don't have in greybox.)
- Sightline as a single ray vs. a cone — a ray is a cleaner "lane" read; a cone is more
  forgiving but muddier. **Recommend ray for legibility; flag to Director.**
- Should overshoot damage *other enemies* it ploughs into? Fun emergent synergy but a scope
  creep risk. **Fun/scope call — Director.**
- Recovery length is the core feel knob and the most playtest-sensitive value (too short =
  unkillable, too long = trivial). Sweep at the fun gate.
