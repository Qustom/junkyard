# Sweeping Laser
**Category:** Static & environmental traps

## The idea
A beam anchored to one wall that **rotates or slides across the room edge to edge**, a moving lethal line you stay ahead of (or duck behind). Distinctness vs. the flame vent (a *fixed* lethal lane) and the crusher (a *gap* you dash through): the laser is a **continuously moving threat with no single safe tile** — safety is relative to the beam's current position and travel direction. The decision it forces is **continuous spatial management while doing something else**: you must keep moving relative to the sweep while *also* looting, aiming a throw, or routing to the gate. It's the one static trap that pressures you *during* your other verbs rather than at a discrete crossing.

## How it fits THE FAR YARD
A placed run-state hazard in the fair-share system, snapshotting `RunConfig` at `setup(...)`, reading `_cfg.hlz_*` knobs. Lethal contact = the player's point within `hlz_width` of the beam segment (analytic distance-to-segment — the exact math the rotating-spike hazard already uses, `spike_hazard.gd` `_is_player_on_any_arm()`), routing through `GameState.fail_run(&"death")` behind `hlz_kills` (default `true`, L5 pattern) and emitting `new_hazard_killed(&"laser", ...)`. No body, no animation — a rotating/sliding line drawn each frame, distance-tested each `_physics_process`, exactly like the body-less K5 distance hazards.

It is the most demanding static trap and lands deep: it pressures the GDD's "loot under pressure" loop directly — you can't safely stand and sort an inventory in a swept room, so it forces the push-or-extract call *spatially* (grab and go, or eat the clock dancing with the beam). It pairs naturally with the L6 mouse-aim throw: aiming a throw while tracking a sweeping beam is a genuine two-axis-of-attention moment, the kind of "answer danger, don't only flee" texture the M1.5 gate wanted.

First appearance: **Band 3 (Lateral)** — a beam of impossible color from a reality where physics is slightly off fits the band fiction, and its difficulty suits a deep band where the player has the movement fluency to handle a continuous threat.

## Graybox sketch
A pivot `Marker2D` on one wall + a `Line2D`/drawn segment that **rotates** between two angle limits (or **translates** across the room). State machine is just `SWEEP` with a direction flag that flips at the limits; optional `WARN` pre-sweep flash. One timer/speed `hlz_sweep_speed`, a width `hlz_width`, and angle/position bounds. Kill-test = distance-to-segment < width. No art: a bright line that swings is the laser. Tune speed so a walking player can stay ahead but a *standing* player (looting) gets caught — that gap is the whole design.

## Synergies & counters
- **With throw (L6):** the beam blocks line-of-travel for *you* but a throw flies over/under the plane in fiction — answer a pursuer across a swept room while keeping ahead of the beam.
- **With ice tile:** a sweep over an ice patch is vicious — you can't make the precise micro-adjustments to stay ahead when momentum carries you. Deep-band signature.
- **With collapsing floor:** dodging a sweep onto floor that then drops forces route-planning under continuous pressure.
- **Counter:** keep moving in the beam's travel direction or duck just behind it after it passes; never stop to loot/sort in a swept room.

## Open questions
- **Rotating vs. translating sweep** — rotation makes the safe zone vary with distance from the pivot (near the wall you barely move; far out you sprint), which is rich but can read as unfair near the far wall. Translation is uniform and more readable. *Recommend translating for graybox; rotation as a deep-band variant — Director call on whether the rotation unfairness is "interesting" or "cheap."*
- **One safe gap, or fully lethal line?** A beam with a moving *gap* in it (dodge through the hole) is a different, busier toy. *Keep the solid line for graybox.*
- **Does it kill enemies?** A sweep that mows the room is a strong passive but a balance and collision-cost lever. *Scope call.*
- **Anti-pillar risk** — a fast continuous beam edges toward twitch/bullet-hell, against the engineer-not-soldier pillar. Speed and width must keep it a *positioning* puzzle, not a reflex test. Tune hard at G4.
