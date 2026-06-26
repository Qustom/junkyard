# Leaper
**Category:** Pursuers & movement enemies

## The idea
A pursuer that **ignores walls and gaps by jumping over them** — it periodically launches in an
arc toward your position, clearing obstacles, pits, and chokepoints that would stop or slow a
ground chaser. Between leaps it's grounded and slow (and vulnerable); the leap is its closing
move.

The behavioral distinctness: the whole rest of the roster can be *out-geometried* — you put a
wall between you and the R1 pursuer (the I2 refuge), you funnel a pack into a doorway, you bait
a Charger into a pit. The Leaper **takes geometry off the table.** It is the enemy that says
"the room won't save you," forcing the player to solve it *directly* — with the throw, or with
movement timed against the leap windup — rather than by routing. It keeps the level-geometry
counters from becoming a universal "just hide behind a wall" solution to every pursuer.

## How it fits THE FAR YARD
- **Move:** the skill is the *windup read* — when it crouches to leap, sidestep its landing arc
  (the arc lands where you *were*, like the Charger but airborne). No new player verbs.
- **Throw:** the grounded, post-landing recovery is the throw window — a clean punish, and the
  *primary* answer since walls don't help. Reinforces the throw as the player's main offensive
  tool exactly where evasion-by-geometry fails.
- **Extract pressure:** it can leap across the gaps and barriers that normally make a route
  safe, so a Leaper between you and the gate can't simply be walled off — you must deal with it,
  costing items or time.
- **Systems reused:** `HazardEntity` (CharacterBody2D, `hazard` layer, throw-killable) with a
  leap state that *disables `world` collision mid-arc* (so it clears walls/pits) and lands at a
  predicted point, then a grounded recovery. Reuses the Charger's "telegraph → committed move →
  recovery" skeleton, just airborne and homing-on-windup. Knob group `lep_*` (`lep_leap_range`,
  `lep_windup_s`, `lep_recover_s`, `lep_cooldown_s`), off by default.
- **First appears:** Band 2+ — it specifically counters the wall-refuge habit players form in
  Band 1, so it lands once that habit exists.

## Graybox sketch
States: `GROUND` (slow walk toward player) → `WINDUP` (crouch/flash `windup_s`, lock the target
landing point) → `LEAP` (arc to the landing point, `world` collision off, ~0.4s, draw the arc
as a debug line) → `RECOVER` (grounded, vulnerable `recover_s`) → cooldown → `GROUND`. Smallest
proof: one Leaper, a wall, and a pit — does it convincingly *clear* the wall, and can the player
sidestep the telegraphed landing and throw the recovery? The "the wall didn't help" beat is the
test.

## Synergies & counters
- **+ Pack hunters / Charger:** a Leaper paired with ground threats means you can't solve the
  whole encounter by routing into a doorway — you must split your attention. Strong depth combo.
- **+ pits/vertical zones:** if the GDD's grapple/vertical traversal arrives, the Leaper is the
  enemy that follows you across the gap you crossed to escape.
- **Counters:** sidestep the telegraphed landing arc (free, the core skill); throw during the
  grounded recovery (item cost, the main answer); you *cannot* simply wall it off.

## Open questions
- Does the leap home on your *current* position (it tracks you mid-air — relentless, harder) or
  lock the landing point at windup (dodgeable — fairer)? **Recommend lock-at-windup so it's
  honestly dodgeable; flag to Director.**
- Mid-arc: fully intangible (passes through everything, including you — only the landing is
  dangerous) vs. lethal in-flight (can clip you mid-leap)? Landing-only is more readable.
  **Recommend landing-only.**
- Leap cadence: frequent short hops (relentless pressure) vs. rare big leaps (punctuation). The
  feel differs a lot. **Sweep `lep_cooldown_s` at the gate — Director tunes.**
- Can it leap *out* of a room you've sealed it in (e.g. over a pursuer-bounding room like L2's
  spawn-room)? If so it breaks the room-bound legibility we just built — needs a rule.
  **Flag the interaction with L2's spawn-room pursuer to Director.**
