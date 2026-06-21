# Worklog — K5i New-hazard spawn-seam integration

- **Date:** 2026-06-21
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.4 (Wave 3 — Danger variety)
- **Branch:** general-purpose/K5i-spawn-integration
- **Commit:** b1f7f0f (worklog SHA-fix follow-up)

## What changed
Wired the three merged M1.4 hazard entities (K5a ping-pong, K5b bomb, K5c spikes) into
`main_game.gd`'s spawn seam as a sibling of `_spawn_r1_hazards`. New `_spawn_new_hazards(rc, band)`
dispatches over a per-type descriptor table (kind / scene path / 4 spawn-seam knobs), placing each
type with the depth-scaled count law `n = base + floor(per_depth * depth_index)` (per-room cap +
shared band ceiling), striding across each room's own J3 sorted floor cells. Placement is pure
run-state — NO RNG, never feeds `fingerprint()`. Per-instance `spawn_ctx` is built per kind
(ping-pong: golden-angle `initial_dir` + world-space `room_bounds` Rect2; spikes: deterministic
`phase_salt = depth_index*131+k`; bomb: `{}`) and handed to the LOCKED `setup(rc, player, spawn_ctx)`.
R1's `_density_spawn_positions` was NOT refactored — only its cell helpers are shared.

## Files touched
- `scenes/game/main_game.gd` — added the new-hazard spawn seam: `_spawn_new_hazards`,
  `_new_hazard_descriptors`, `_new_hazard_spawn_ctx`, `_piece_floor_bounds_world`, the
  `HPP/HBOMB/HSPIKE_SCENE_PATH` + `NEW_HAZARD_BAND_CEILING` (48) + `NEW_HAZARD_GOLDEN_ANGLE`
  consts, and the one new call in `start_new_run` right after `_spawn_r1_hazards`. Player lookup
  uses `_band_container.get_tree()` (null-safe) so the seam does not depend on MainGame itself
  being in the tree (lets the helper run under the headless test exactly as in-game).
- `tests/test_new_hazard_spawn.gd` + `.tscn` — new dedicated acceptance test (all-off → 0 nodes;
  base>0 fills every room; depth scaling monotonic; per-room cap; shared band ceiling saturates
  at 48 never above; determinism; per-kind spawn_ctx correctness).
- `tests/test_per_room_density.gd` — added the K5i golden guard: J3's `_density_spawn_positions`
  golden positions `[(1608,8),(3208,8),(3208,88)]` for the fixed (areas [32,96,200], density 1.0)
  band are byte-unchanged (guards the "don't refactor R1" decision).

## Checks run
- [x] `godot --headless --import` → clean, no parse/compile errors.
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK`.
- [x] `godot --headless res://tests/test_bandgen_determinism.tscn` → `fp=e943ac9c8bc1` (UNMOVED).
- [x] `godot --headless res://tests/test_new_hazard_spawn.tscn` → `K5i OK` (all 6 assertion groups).
- [x] `godot --headless res://tests/test_per_room_density.tscn` → `J3 OK` (incl. the new golden guard).
- [x] `godot --headless res://tests/test_hazard_spread.tscn` → `J2 OK`.
- [x] Node-count sanity (headless probes, removed after):
      - typical 5-room band, all three types on (base 1, per_depth ~0.2-0.3, caps 3-4) → 16 nodes (well under 48).
      - 12-deep-room band, same preset → saturates at 48 (ceiling), starvation order pingpong→bomb→spikes.
      - worst-case flood (base 99 each, uncapped) → exactly 48, never above.
- [x] Definition of done met: "Add the new-hazard spawn dispatch to main_game.gd only … all-off
      byte-identical to M1.3 (fp e943ac9c8bc1 UNMOVED) … placed-node count bounded by the ceilings."

## Design deviations
None of substance. Two implementation notes (both within the locked design):
1. The player-group lookup in `_spawn_new_hazards` resolves the tree via `_band_container.get_tree()`
   rather than `self.get_tree()`. Equivalent in-game (the container is always parented before this
   runs) and null-safe; chosen so the pure spawn logic is testable on a bare script instance, exactly
   as the J2/J3 tests do. Not a behaviour change.
2. A single-row room yields a zero-area floor-cell bbox → `room_bounds` is an empty Rect2; the
   ping-pong entity already handles this (its `has_area()` guard falls back to pure-wall confinement).
   This is correct as-built behaviour, not a deviation.

## Handoffs / follow-ups
- **RG1 (carry forward):** worst-case combined tick-time check is still owed. The new-hazard ceiling
  is 48 and R1's is a separate 64, so a fully-loaded run is up to ~112 hazard `_physics_process`
  bodies on the web-export target. The three new checks are individually cheap (bomb proximity test,
  spike ≤3 segment tests, ping-pong `move_and_slide`+reflect), but RG1 must MEASURE the 112-body tick
  time on the itch web build, not assume it (OQ-3 Resolved action item 2).
- **Director taste calls (deferred, no action now):** `NEW_HAZARD_BAND_CEILING = 48` is a Director
  sweep knob; and OQ-4's pure-deterministic striped placement may be promoted to a local
  `run_seed ^ K5I_SALT` sub-stream if the striping reads too regular at playtest (never global RNG,
  never feeds fingerprint).
