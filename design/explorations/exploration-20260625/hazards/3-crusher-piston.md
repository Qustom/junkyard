# Crusher / Piston
**Category:** Static & environmental traps

## The idea
A heavy block that **slams a corridor or doorway shut on a cycle**, then withdraws — a moving wall you must dash through between strokes. The behavioral distinctness vs. the pop-up spike is **committing your whole body to a moving gap, not waiting out a beat**: a spike field you cross at walking pace; a crusher you must *time a dash through* a closing aperture, where being caught mid-stroke is fatal and hesitation traps you on the wrong side. It is the most "decisive commitment" of the static traps — you can't half-cross. It also **gates space**: a crusher on a chokepoint means the room beyond is only reachable on the crusher's schedule, which interacts with the extract timer (you may have to wait for the next open-stroke to get *out*, not just in).

## How it fits THE FAR YARD
Extends the fair-share hazard system as a placed run-state entity. It snapshots `RunConfig` at `setup(...)`, reads `_cfg.hcr_*` knobs (prefix house style), and its lethal contact (player inside the crush volume on the closed frame) routes through `GameState.fail_run(&"death")` behind `hcr_kills` (default `true`, L5 pattern), emitting `new_hazard_killed(&"crusher", ...)`.

Architecturally it is a moving `StaticBody2D`/`AnimatableBody2D` on the `world` layer (bit 2) so it **also blocks movement** while closed — the player physically cannot pass, reinforcing the "gate" fiction without relying only on a kill test. The kill test is a separate overlap check on the crush volume the instant it seats. This makes it a true traversal gate, fitting the GDD's "traverse hazardous terrain" dive verb and the push-or-extract clock: a crusher between you and a gate (A2 `ExtractGate`) means extraction itself has a timing cost.

First appearance: **Band 2 (Temporal)** — it reads as industrial machinery (a stamping press from an old scrapyard), thematically perfect for the "junkyard from another time" band, and it is a step up in commitment from Band 1's spikes.

## Graybox sketch
A `ColorRect` block (one wall of a 2-cell corridor) on an `AnimatableBody2D`. State machine: `OPEN` (block retracted into the wall, corridor clear) → `WARN` (block edges out a few px + flashes, ~0.5 s) → `CLOSED` (block fills the corridor; `world`-layer collision on; kill-test the crush cells) → `OPEN`. Timers `hcr_open_s` / `hcr_closed_s` and a short `hcr_travel_s` for the slam. No art: a sliding red rectangle is the press. Tune so a single confident dash clears it but a mistimed one strands or kills you.

## Synergies & counters
- **With throw (L6):** throw an item *through* the open stroke to bait/kill a pursuer beyond it, or to a friend's far side, without risking the dash yourself.
- **With pop-up spikes / flame vent:** a crusher whose only safe approach runs over a spike field or past a flame vent stacks two clocks you must phase-align — a deep-band signature puzzle.
- **With collapsing floor:** a one-way collapse behind a crusher creates a true commitment gate (you can't back out).
- **Counter:** read the open-stroke, dash on the rising edge of `OPEN`; never enter the corridor during `WARN`.

## Open questions
- **Does the closed block deal contact damage, or only crush at the seated frame?** A full "any contact while moving kills" is harsher and more readable as danger; "only the seated crush cells kill" is fairer. *Recommend seated-frame-only for fairness; revisit at G4.*
- **Can the crusher trap the player in a sealed pocket (block closes behind, spikes/wall ahead)?** Soft-lock risk if a player walks into a dead pocket and a crusher seals it with no open-stroke escape. *Must guarantee every crusher has a recurring open-stroke and the pocket is never zero-exit.*
- **`world`-layer blocking vs. kill-only** — physically blocking is more honest but means the allocator must place it where blocking a path is acceptable (not the *only* route at the wrong phase). *Scope/placement-rules call for the Director.*
- **Cycle visibility from a distance** — the player needs to read the rhythm before committing; the WARN tell may need to be visible across the room.
