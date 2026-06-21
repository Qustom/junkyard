# M1.3 Re-gate Findings (RG3) — Verdict: **ITERATE → M1.4**

**Date:** 2026-06-21
**Decider:** Director (human)
**Basis:** Director playtest of the M1.3 build (RG1 `d9138c7`, default play-preset).

---

## Verdict

**ITERATE → M1.4.** The M1.3 build (legibility + density + depth-spread hazards on the new
larger canvas) is a keeper direction, but the Director's playtest surfaced a concrete batch
of feature + tuning gaps that define the next iteration. RG2 telemetry analysis was **bypassed
in favour of direct qualitative Director feedback** (the playtest produced a clear feature
work-order, not a metrics ambiguity that needed log analysis).

## Director feedback (verbatim work-order → M1.4 scope)

1. **Pursuing-hazard defaults** — set `catch_speed_per_depth → 3.0`, `catch_radius_per_depth → 1.0`,
   `speed_per_depth → 3.0` (the current preset values were too aggressive).
2. **Quota system** — give the money a *reason*: every run must meet a quota or it's **game over**;
   meeting it increments the run number and raises the next quota; configurable; start **$50**, **+$50/run**.
   **Director disposition (2026-06-21): quota miss = FULL roguelite wipe** (meta-state reset).
3. **Resolution-independent camera** — what the camera shows must be consistent regardless of screen
   resolution (so "how far can I see" is a controlled variable, not a function of window size); configurable.
4. **Configurable timer** — expose the dive timer; add a near-end **warning** threshold/cue.
5. **More hazards, each configurable, more-with-depth:**
   - **Ping-pong** — bounces off walls within a room, lethal on contact, stays in its room.
   - **Big bomb enemy** — proximity radius; if the player gets close it pulses ~2s then explodes;
     kills if the player is inside the radius at detonation; spawns randomly around the room.
   - **Rotating spikes** — placed randomly in part of a room; more of them the deeper you go.
6. **Movement jitter** — slight jitter on the character while moving; investigate + fix.
7. **Exit placement** — spawn the exit randomly around the level; allow multiple exits; configurable
   frequency + depth-scaling; configurable whether one exit always stays at the spawn.

## Hand-off

M1.4 is authored from this work-order via the four-phase process (Director-chosen, 2026-06-21).
Breakdown + per-task designs: `design/M1_4_Tasks/`.
