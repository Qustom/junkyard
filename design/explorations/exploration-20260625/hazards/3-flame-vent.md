# Flame Vent
**Category:** Static & environmental traps

## The idea
A nozzle in a wall (or floor) that **jets fire on a timer** across a fixed line, safe between pulses. The behavioral distinctness vs. the crusher and spikes: it projects a **directional, lethal *line* across open space** rather than owning a tile or a corridor. It threatens a *lane* — you can stand right next to the vent safely; danger is the column of flame in front of it. The decision it forces is **reading a directional hazard and choosing your side of it**: cross during the off-pulse, or stay on the safe side and route around, or use the lane as a barrier between you and a pursuer. It is the static trap that most shapes *where you stand in a fight*, not just *when you move*.

## How it fits THE FAR YARD
A placed run-state hazard in the fair-share system. It snapshots `RunConfig` at `setup(...)`, reads `_cfg.hfv_*` knobs, and a player inside the active flame column routes through `GameState.fail_run(&"death")` behind `hfv_kills` (default `true`, L5 pattern), emitting `new_hazard_killed(&"flame_vent", ...)`. The flame column is a fixed-direction rectangular/Area test (origin at the nozzle, extent `hfv_reach`), active only during the `BURN` phase — pure distance/AABB math, no animation needed, consistent with how the K5 bomb and spike are body-less `Node2D` distance hazards.

It deepens the **fight-or-flee** texture the M1.5 work added (L1 throw, L2 room-bound pursuer): a flame lane is a positional tool — keep it between you and R1 and the pursuer either waits or (if hazards take hazard damage) dies in it. It also taxes the extract clock when a vent guards a loot lane. Thematically it suits the "things that came through" dread — a wall that breathes fire on a count you can't quite trust feels wrong in the right way (GDD diegetic-dread pillar).

First appearance: **Band 1–2 boundary.** Mechanically simple (a binary on/off line) so it can appear early, but its positional-fight depth blooms in Band 2 where pursuers and other hazards share the room.

## Graybox sketch
A small `ColorRect` nozzle on a wall + a flame `ColorRect` lane that toggles visible/lethal. State machine: `IDLE` (no flame) → `WARN` (nozzle glows / sputter flicker, ~0.4 s) → `BURN` (flame rect drawn bright orange across `hfv_reach`; AABB kill-test) → `IDLE`. Timers `hfv_idle_s` / `hfv_burn_s`. No art: an orange rectangle that blinks on is the jet. Tune so a single lane is a trivial wait but **two opposed vents** firing out of phase make a corridor a real timing puzzle.

## Synergies & counters
- **With throw (L6):** a thrown item flies through the flame harmlessly (or, OQ, *ignites* into a higher-damage projectile) — either way you can answer a pursuer across a flame lane without crossing.
- **With conveyor / ice:** being pushed or sliding into a `BURN` phase is the deep-band trap; a conveyor feeding a flame lane is a classic.
- **With crusher:** flame lane + crusher on the same chokepoint = two phases to align.
- **Counter:** cross on the off-pulse; stand to the *side* of the nozzle (safe); use the lane as a wall against enemies.

## Open questions
- **Does flame ignite thrown items into a buffed projectile?** A fun toy (fire-arrow moment) but new state on the projectile and a balance lever. *Recommend NOT in graybox; flag as a stretch toy for the Director.*
- **Does flame damage hazards/enemies?** Turning a vent into a passive trap for the pursuer is strong; needs a hazard-vs-hazard rule the system doesn't have yet. *Scope call.*
- **Telegraph trust** — the GDD's engineer-not-twitch pillar means the WARN must be honest and readable; a too-short tell makes it a gotcha. Tune at G4.
- **Floor vent vs. wall vent** — a floor vent (vertical column) reads differently from a wall vent (horizontal lane) and changes which axis it gates. *Pick one for graybox (recommend wall/horizontal), add the other later if it earns it.*
