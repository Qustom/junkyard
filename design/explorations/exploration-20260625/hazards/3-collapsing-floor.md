# Collapsing Floor
**Category:** Static & environmental traps

## The idea
A floor tile that **cracks the moment you stand on it and drops away ~1 s later**, leaving a hole. Distinctness vs. every timed trap above: the clock is **player-triggered, not ambient** — nothing happens until you step on it, then you have one second before that tile is gone for good (or for a long respawn). The decision it forces is **commit-and-keep-moving plus route memory**: you can't stand still, you can't backtrack across collapsed tiles, and a field of them becomes a one-way route you must plan and execute without stopping. It is the trap that most shapes the *topology* of a room — it turns reversible space into one-way space, which has huge consequences for the extract loop.

## How it fits THE FAR YARD
A placed run-state region (a grid of tiles) in the fair-share system, snapshotting `RunConfig` at `setup(...)` and reading `_cfg.hcf_*`. Each tile is a small `ColorRect` + a `world`-layer collision (so a *dropped* tile is a real gap the player and the pursuer can't cross). Per-tile state machine: `SOLID` → (on player overlap) `CRACKING` (timer `hcf_warn_s` ≈ 1.0, tile flashes/jitters) → `GONE` (collision off, hole). Falling into a hole is **not** instakill in graybox — it routes through `GameState.fail_run(&"death")` behind `hcf_kills` (default `true`, L5 pattern; emits `new_hazard_killed(&"collapse", ...)`), OR (an OQ) it merely blocks/drops you to a known fail; design leans toward "the hole is a wall you made," not a pit-death, for fairness. Optional `hcf_respawn_s` to re-solidify so the room isn't permanently shredded across a long dive.

This is the strongest **one-way-route / push-or-extract** lever in the set. A collapsing bridge to a loot-rich pocket means *getting the junk commits you* — you can't carry it back the way you came, you must find another exit or a gate (A2 `ExtractGate`) before the clock runs out. That's the GDD extraction tension expressed as geometry. It also creates great pursuer interplay: collapse the floor behind you and R1 (room-bound per L2) is cut off.

First appearance: **Band 1 (Near)** as a single short collapsing bridge (teaches "keep moving"), scaling to multi-tile fields and one-way mazes in deeper bands.

## Graybox sketch
A grid of `ColorRect` tiles, each an `Area2D` (player-detect) over a toggleable `StaticBody2D` (`world` collision). On first player overlap: start `hcf_warn_s`, tint amber→red; on expiry, disable collision + hide. Optional respawn timer restores it. No art: the color and the disappearing rect carry it. Tune `warn_s` so a brisk walk clears a tile but dawdling drops you, and so a *row* read at a glance tells the player "don't stop here."

## Synergies & counters
- **With throw (L6):** you can stand on solid ground and throw across a collapse field at a pursuer trapped on the far side — the hole keeps it there.
- **With pursuer (R1):** the marquee use — bait the pursuer onto a collapsing bridge or drop the floor behind you to sever the chase (room-bound L2 pursuer can't path across a gap).
- **With conveyor / ice:** a conveyor or ice patch over collapsing tiles removes your ability to control *where* you trigger the drop — brutal deep-band combo.
- **With crusher:** crusher + one-way collapse = a true point-of-no-return commitment gate.
- **Counter:** keep moving, plan the crossing before you start, and treat the far side as committed — bring a plan to get out, not just in.

## Open questions
- **Pit-death vs. wall-only** — does falling kill, or does the hole just become impassable terrain (a gap you and enemies route around)? Wall-only is fairer and creates richer topology; pit-death is a cleaner threat but a harsher gotcha. *Recommend wall-only / no pit-death in graybox (the hole is the threat, not the fall); flag the fun call to the Director.*
- **Respawn or permanent?** Permanent collapse risks soft-locking a player who shredded their only route back to a gate; respawn keeps the room recoverable but weakens the one-way fiction. *Recommend a long `hcf_respawn_s` so routes are *temporarily* one-way but the dive never dead-ends.*
- **Soft-lock guarantee** — the allocator must never place a collapse field as the *only* path to a *required* gate without an alternate or a respawn. *Placement-rules call.*
- **Does `warn_s` ≈ 1 s feel fair?** Too short = gotcha; too long = no pressure. The one most playtest-sensitive number — tune at G4.
