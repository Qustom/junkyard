# Pop-Up Spikes
**Category:** Static & environmental traps

## The idea
A floor tile that sits flush and harmless, then **extends spikes on a fixed timer** and retracts again — a metronome of death you cross by reading its beat. The behavioral distinctness is **rhythm-reading under spatial commitment**: unlike the existing R1 pursuer (a thing that chases you) or the K5 ping-pong/bomb/spike entities (things that move *to* you), a pop-up spike never comes to you. It owns a square of floor permanently. The decision it forces is *timing a crossing* — wait at the edge, watch two or three cycles, then commit to walking through the gap in the threat's duty cycle. It converts a piece of geometry from "free floor" into "floor you must earn with patience," which costs the one resource the dive can't refund: the extract timer (`dive_clock`).

## How it fits THE FAR YARD
It extends the existing fair-share hazard system. Like the K5 family it is pure run-state, placed by the allocator, snapshots its `RunConfig` at `setup(cfg, player, spawn_ctx)`, and reads typed `_cfg.hspk_*` fields (mirroring the `hspike_` rotating-spikes prefix house style in `data/run_config/run_config.gd`). Lethal contact routes through `GameState.fail_run(&"death")` behind an `hspk_kills` toggle (default `true`), exactly the L5 pattern, and emits `EventBus.new_hazard_killed(&"popup_spike", depth, run_t_ms)` before the gated kill so telemetry stays comparable.

It sharpens the GDD's **push-or-extract** tension specifically because it *taxes time*: a spike field laid across a corridor between the player and a loot-rich dead end (depth-scaled junk from B3's `JunkPlacer`) makes "grab the good junk" cost real seconds off the clock — a clean push-your-luck lever. It plays cleanly with the L6 mouse-aim throw too: you can lob a low-value item across a spike field to a pursuer on the far side without crossing yourself.

First appearance: **Band 1 (Near)**. It is the gentlest static trap — a single-tile, slow, clearly-telegraphed hazard ideal for teaching "watch the beat before you walk." Density and cycle-speed scale with depth via the `density_curve` / a per-depth speed lerp.

## Graybox sketch
A `ColorRect` floor tile, ~1 cell. State machine: `SAFE` (flat, dark gray) → brief `WARN` (tile flashes / a small inset square grows, ~0.4 s tell) → `LETHAL` (bright red, spikes "up") → back to `SAFE`. Two timers: `hspk_safe_s` (window to cross) and `hspk_lethal_s` (window that kills). Contact test while `LETHAL` = the player's position inside the tile rect → `fail_run`. No art: the color swap *is* the spike. Tune `safe_s` long enough that one tile is trivial and a **row** of out-of-phase tiles is the real puzzle.

## Synergies & counters
- **With throw (L6):** thrown items are unaffected by the trap (they fly over), so a spike field is a wall to *you* but not to your projectiles — throw to kill across it.
- **With the pursuer (R1):** lure the pursuer onto a phase-locked field; if `hspk_kills` also kills hazards (an OQ below), the field becomes a passive defense.
- **With conveyor/ice tiles:** a spike row downstream of a conveyor or on ice is brutal — you may be *pushed* or *slide* onto it mid-cycle. Strong combo for deep bands.
- **Counter:** patience (read the beat), or route around. Never an unavoidable-damage tile in the player's *only* path.

## Open questions
- **Phase offset across a field** — do tiles share one global clock (a clean wall that opens all at once) or stagger phases (a shimmer you weave through)? Staggered is more interesting but harder to read fairly. *Recommend staggered only from Band 2+.*
- **Does the spike kill hazards too, or only the player?** A hazard-killing field is a great toy but adds a collision-test cost and a balance lever. *Fun/scope call — flag for the Director.*
- **Telegraph length vs. lethal window** — too short a `WARN` feels like a gotcha (anti-pillar: this is an engineer's game, not a twitch game). Needs the G4 fun gate to tune `safe_s`/`lethal_s`.
- **Is "stand still and wait" boring?** The time-tax is the cost, but if a player can always just wait it out for free-minus-seconds, is it a *decision* or a *toll*? Pairing with timer pressure is what makes it a decision — verify at playtest.
