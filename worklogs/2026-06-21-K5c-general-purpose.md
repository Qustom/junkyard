# Worklog — K5c Rotating-spikes hazard

- **Date:** 2026-06-21
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.4 (Wave 3)
- **Branch:** general-purpose/K5c-spikes
- **Commit:** 9b764f5d13b27b707eb839dad8d7cb434ec6519b

## What changed
Built the new greybox **SpikeHazard** entity (K5c) — an ANCHORED `Node2D` hub that spins at a
constant signed angular velocity with 3 (const) lethal arms radiating from it. The kill is an
analytic distance-to-arm-segment test (`Geometry2D.get_closest_point_to_segment`) against the
player each frame — no `CollisionShape2D`, no physics overlap (the R1 deterministic convention).
The rotation itself is the telegraph. Initial phase is derived deterministically per-instance from
`spawn_ctx["phase_salt"]` (NO global RNG). Entity-only; the spawn seam is K5i's.

## Files touched
- `scenes/hazards/spike_hazard.gd` — NEW. `class_name SpikeHazard extends Node2D`. LOCKED
  `setup(cfg, player, spawn_ctx := {})`; reads `hspike_rotation_speed` + `hspike_arm_length`;
  emits `EventBus.new_hazard_killed(&"spike", depth, run_t_ms)` once (one-shot latch) and routes
  death through the existing `GameState.fail_run(&"death")`. Steel/cyan tell color.
- `scenes/hazards/spike_hazard.tscn` — NEW. `Node2D` "SpikeHazard" (group `hazard`) + child
  `Polygon2D` "Tell" (the multi-arm star, steel/cyan), **no** `CollisionShape2D` (OQ-1/OQ-6).
- `tests/test_spike_hazard.gd` + `.tscn` — NEW. Headless acceptance test.

## Checks run
- [x] `godot --headless --import` clean — `SpikeHazard` compiles, scene loads, no parse errors.
      (The `*_strings.en.translation` "Cannot open file" lines are pre-existing, unrelated to K5c.)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy`
- [x] `godot --headless res://tests/test_bandgen_determinism.tscn` → `fp=e943ac9c8bc1` (unmoved baseline)
- [x] `godot --headless res://tests/test_spike_hazard.tscn` → `K5c OK` — verifies: empty + real
      spawn_ctx construct safely; same phase_salt → same `_angle` (deterministic, RNG-free);
      rotating-arm kill fires on a blade and NOT in the gap / beyond the tip; `new_hazard_killed`
      emits exactly once on kill and routes through `fail_run`; `ARM_COUNT == 3`.
- [x] Definition of done met: "build ONLY the entity (script + scene + test), file-disjoint;
      all-off = no instances = byte-identical baseline (fp e943ac9c8bc1)."

## Design deviations
- **Adopted the LOCKED `setup(cfg, player, spawn_ctx: Dictionary = {})` signature** over the
  Phase-2 doc's proposed `setup(cfg, player, phase_salt: int)`. Per the Phase-3 cross-cutting
  lock, `phase_salt` is read from `spawn_ctx.get("phase_salt", 0)`. Not a substantive deviation —
  it IS the ratified family contract; recorded here per the worklog requirement.
- **Tell color = steel/grey-cyan `Color(0.55, 0.70, 0.80)`** (not the Phase-2 placeholder orange
  `Color(0.95,0.55,0.1)`). This is the Director-ratified palette separation (cool blades hue-
  separated from the warm amber/orange ping-pong + bomb). Folded in per the Resolved Decisions.
- Otherwise on-spec: analytic hit test, `Node2D` + no collision, ARM_COUNT const 3, uniform
  signed direction, one-shot kill latch, existing fail_run end path. None of substance beyond
  the two ratified items above.

## Handoffs / follow-ups
- **K5i** (spawn seam) loads this at `scenes/hazards/spike_hazard.tscn`, gates on `hspike_enabled`,
  spawns through the per-room density machinery, and passes `spawn_ctx["phase_salt"] =
  p.depth_index * 131 + k` per spike. The kill signal kind is `&"spike"` (singular).
- Director-facing flags carried from the design (not blockers for the build): arm count could be
  promoted to a swept `hspike_arm_count` knob (currently const 3); per-instance direction variety
  vs uniform; the `hspike_arm_length` preset magnitude (~56px recommended) is the Director's sweep.
