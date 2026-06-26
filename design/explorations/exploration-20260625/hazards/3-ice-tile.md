# Ice Tile
**Category:** Static & environmental traps

## The idea
A slick floor region where **momentum carries you past where you meant to stop** — release the stick and you keep sliding, change direction and you drift. Distinctness vs. the conveyor (an *external* fixed push): ice removes your *braking and turning authority*, so the threat is **your own velocity**. The decision it forces is **anticipating your stopping point and committing to movement earlier**: you brake before the edge, not at it; you can't make tight adjustments mid-slide. Where a conveyor adds a vector, ice *subtracts friction* — it makes precise positioning (the thing every other static trap demands) hard exactly where you most need it.

## How it fits THE FAR YARD
A placed run-state region (`Area2D`) in the fair-share system. It snapshots `RunConfig` at `setup(...)` and reads `_cfg.hic_*` (a friction/accel scalar `hic_grip` in 0..1). While the player overlaps it, the **acceleration/deceleration term in the existing `step_velocity` movement helper** (`player.gd`) is scaled down — low grip means inputs ramp velocity slowly and released inputs decay slowly (the slide). Keeping it inside `step_velocity` preserves the pure, unit-testable movement seam (the L6 docs lean on exactly this split). **It is non-lethal** — no `*_kills` knob, no `new_hazard_killed`. Like every M1.5 lever it defaults `hic_enabled=false`, leaving the all-off fingerprint untouched (it's run-state physics, not generation).

Its purpose is to **make the other static traps bite**: ice next to spikes, a flame lane, a crusher, or a sweeping laser converts "stop precisely on the safe tile" into "judge your slide." On its own it's a mild traversal-feel modifier; in combination it's a force-multiplier — the same role as the conveyor but via control-loss instead of a vector. Thematically it suits Band 2–3 (a frost-locked future megafill, a reality where the floor is wrong) more than the mundane surface.

First appearance: **Band 2 (Temporal)** — late enough that the player has the movement fluency for the slide to be a skill expression rather than pure frustration, and it reads as the band getting *stranger* underfoot.

## Graybox sketch
A pale-blue `ColorRect` `Area2D`. On overlap, set the player's grip scalar to `hic_grip` (e.g. 0.15); on exit, restore 1.0. No state machine — always slick. The slide *is* the reduced friction in `step_velocity`; no separate physics body or animation. Knob: `hic_grip`. Tune so crossing open ice is fun-slidey-harmless, but ice *adjacent to a lethal trap* forces a real "brake early" read. Validate the slide feels controllable-but-loose, never rng-feeling.

## Synergies & counters
- **With throw (L6):** sliding while aiming the mouse-throw is a genuine skill moment — you must aim and time the click while your position drifts. Doesn't change the projectile (the projectile isn't on ice), only *your* footing as you throw.
- **With spikes / flame / laser / crusher:** the marquee combos — ice forces you to commit to a stopping point before a lethal tile, turning each timing trap into a positioning-under-low-control puzzle.
- **With conveyor:** ice + conveyor stacks an external push onto lost braking — a deep-band "you are not driving" tile; use sparingly.
- **Counter:** slow down and commit early; approach lethal tiles at low speed so the slide is short; never sprint onto ice near danger.

## Open questions
- **Does it affect the pursuer?** A pursuer sliding on ice could over- or under-shoot the player — potentially a great escape tool, potentially janky pathing. *Recommend player-only for graybox; enemy-ice as a later toy — Director call.*
- **Grip floor** — how low can `hic_grip` go before it reads as "lost control" (anti-agency, against the engineer pillar) rather than "skillful slide"? Needs the G4 fun gate. *Recommend a conservative floor (~0.1–0.2) initially.*
- **Visual readability of the slide** — the player must *understand* they're on ice before they're punished; the tint plus a subtle skid/decay tell may be needed so it never feels like a bug.
- **Does ice + the dive clock create a "wait for nothing" frustration?** Unlike a timed trap there's no beat to wait out — the skill is all in the approach. Verify it's a *skill* tile, not a *tax* tile, at playtest.
