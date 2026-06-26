# Electrified Floor
**Category:** Zone & area-denial

## The idea
A room whose floor tiles **energize on a repeating cycle** — at any instant some tiles are live (lethal) and some are safe, and the pattern shifts on a timer, so the **safe footing keeps moving**. The behavioral distinctness: it's a **rhythm/timing-traversal** hazard, the first one that turns the floor itself into the threat and demands you *read a cycle and time your steps* rather than read an entity's position. The decision it forces is *when to cross and where to stand*: the high-value junk sits on a tile that's only safe 1 second in every 3 — do you wait for the window and grab it, or write it off? It's the spike hazard's "find the safe spot" idea (M1.4 K5c rotating spikes) generalized from one rotating arm to a whole-room pattern.

## How it fits THE FAR YARD
It extends the existing M1.4 hazard family's "telegraphed cyclic threat" shape (the rotating spike already cycles a lethal arm and you find the safe gap) to a full-room grid, so it slots into the same lethality model: live-tile contact routes through the existing `new_hazard_killed` → `GameState.fail_run(&"death")` path with an `electric_kills` toggle (mirroring L5's `hspike_kills`). Against the core verbs: **move** is the entire skill (footwork across a shifting safe-path); **loot** is gated by the cycle (the prize tile is intermittently reachable); **throw** is *unaffected* — a projectile arcs over live tiles, so you can still answer a pursuer from safe footing (a nice asymmetry: the floor traps your feet, not your hands); **extract tension** is sharp and *fair* — the cycle is a clock-within-the-clock, and waiting for a safe window directly spends the dive timer, so "is this tile's junk worth three cycles of waiting?" is a clean push/cash-out micro-decision that the extraction clock (`dive_clock_changed`) prices. Crucially it's **honest area-denial**: unlike gas (attrition) or dark (blindness), the threat is fully legible — you can always see which tiles are live — so the difficulty is execution, not information. First appears **Band 2 (Temporal)** as a slow, generous cycle (long safe windows), tightening to fast, dense patterns by **Band 3 (Lateral)** where "physics is slightly off" (GDD §4) justifies the energized floor fictionally.

## Graybox sketch
- A `Node2D` over `spawn_ctx["room_bounds"]` (L2 Rect2 primitive) with a coarse tile grid.
- State: a deterministic pattern function `is_live(cell, t)` — e.g. checkerboard that flips every `cycle_seconds`, or a sweeping band that scans across the room. Pure function of cell + time, no per-tile storage, fully reproducible (no RNG needed → determinism-safe by construction).
- Tell: live tiles render a bright flat color; safe tiles dim. A short **pre-charge flash** (tile blinks for `warn_seconds` before going live) so a death is always telegraphed — the fairness guarantee.
- Contact: each frame, if the player's cell `is_live` and the warn already elapsed → emit `new_hazard_killed(&"electric", ...)`, and if `electric_kills` → `fail_run`.
- Knobs (`electric_` prefix, all-off default): `electric_enabled`, `electric_cycle_seconds`, `electric_warn_seconds`, `electric_pattern` (enum: checker / sweep / random-fair), `electric_live_fraction`, `electric_kills` (default true).

## Synergies & counters
- **Throw synergy:** stand on a safe tile and throw across the live field at a pursuer — the floor restricts *your* feet but not your reach, so the L1 throw is a clean answer from cover.
- **Pursuer interaction:** an R1 pursuer (L2) crossing the field — does it ignore the floor (unfair to the player who must respect it) or also die to it (a tool: bait the hunter onto a live tile)? The latter is a great emergent kill and reuses nothing new. *Recommend the pursuer respects the floor.*
- **Counter:** read the cycle, time the cross, claim the prize tile during its safe window. The pre-charge warn flash is the learnable tell. A future insulated-boots Gear upgrade is the natural negation.

## Open questions
- **Does the pursuer respect the floor?** Player-only lethality feels unfair; mutual lethality adds a bait-the-hunter tool but needs the pursuer to pathfind around live tiles (more AI than L2 ships). *Recommend mutual but defer pursuer-pathing — for the first ship, pursuer ignores the floor and the player accepts the asymmetry, flagged as a known rough edge.* Fun call.
- **Pattern legibility vs. challenge:** checkerboard is instantly readable but trivial; a sweeping band is readable and tense; "random-fair" (guaranteed-solvable random) is hardest to telegraph. *Recommend sweep as the default; expose pattern as a knob for RG to compare.*
- **Standing-on-the-prize-tile camping.** If the safe window is long, a player can park on the goal tile and wait out everything else. Tie window length to `cycle_seconds` so no tile is safe long enough to camp. *Tuning, not a Director call.*
