# Spinner
**Category:** Ranged & projectile enemies

## The idea
A stationary emitter that fires a steady stream of slow projectiles from a **rotating barrel**, producing an expanding spiral of bullets with readable **gaps between the arms**. It doesn't aim at you at all — it fires a fixed pattern that sweeps the whole room, and survival is about **reading the gaps and threading them**. Its behavioral distinctness is that it's the only enemy in the set that is *fully deterministic and player-agnostic*: the Sentry reacts to your lane crossing, the Lobber targets you, the Suppressor sets you up — but the Spinner just *turns*, and the challenge is spatial pattern-reading, not reacting to a telegraph aimed at you. It's a bullet-hell "find the gap, move through it" skill, scaled way down for a top-down salvage game.

## How it fits THE FAR YARD
It converts an area (often a room with good loot or a chokepoint to a gate) into a **timed traversal puzzle**: cross when the spiral arm has rotated past your lane. This taxes the **move** verb and the **extract-before-timer** clock — threading a slow spinner costs time, sharpening push-vs-cash-out. It reuses the existing distance-test projectile contact and the L1 projectile look; the only new system is a rotating multi-emitter that spawns N slow bolts per period at an incrementing angle. Pure run-state, knob-gated, deterministic (the angle is a function of run time, so it's reproducible and never feeds `fingerprint()`). First appears in **Band 3 (Lateral)** where "a sprinkler from a reality with different physics" is on-theme; the deterministic, almost-mechanical wrongness suits the band. Deeper: arms that reverse direction, or two counter-rotating spinners.

## Graybox sketch
- A static circle (Spinner, layer `hazard`) with an `angle` that advances `spin_rate * dt` each frame.
- Every `emit_period_ms ≈ 250`, spawn `arm_count` slow projectiles at `angle + k * (360/arm_count)` for k in 0..arm_count-1; each flies straight outward, lives `bolt_lifetime_ms`, contact → `fail_run(&"death")` behind a `spinner_kills` toggle.
- The spiral and its gaps emerge for free from `spin_rate` (slow turn) + `bolt_speed` (slow bolts). Tune so a walking player can fit through a gap.
- Knobs: `spinner_arm_count` (2–4), `spinner_spin_rate`, `spinner_emit_period_ms`, `spinner_bolt_speed`, `spinner_bolt_lifetime_ms`. The gap width is `bolt_speed`/`spin_rate`-derived — the core readability dial.

## Synergies & counters
- **Counter (move):** stand in a gap and walk outward along it, or wait at the rim for an arm to pass. No item cost — pure positioning.
- **Throw counter:** mouse-aimed throw kills the emitter and stops the whole pattern; high value when a spinner guards a gate.
- **Hazard combo:** Spinner + Suppressor is the nastiest pairing in the set — a slow shot clips you, and during the slow you can no longer thread the gap in time. Spinner near a pursuer forces you to thread bullets *while* being chased, with no room to wait.

## Open questions
- **Bullet-hell density risk:** even a "gentle" spinner can read as unfair bullet-hell, which clashes with the "engineer, not a soldier; avoidance is first-class" pillar. Is a rotating spiral *tonally right* for THE FAR YARD, or does it pull toward a genre we don't want? (Vision/tone — Director; this is the load-bearing call for whether Spinner ships at all.)
- **Arm count and rotation speed** are extremely fun-sensitive; 2 slow arms may be the ceiling for a non-bullet-hell game. Resolve only at a fun gate.
- **Does it need an off-state** (spin up only when the player is in the room) so it doesn't tax the dive clock from across the level? Recommend yes — proximity-gated activation, like R1's wake. (Scope — Director.)
