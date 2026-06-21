# Worklog — BUG8 Ping-pong hazard sticks on walls/corners

- **Date:** 2026-06-21
- **Subagent:** general-purpose
- **Milestone:** M1.4 (Wave 5 — bug-fix re-gate)
- **Branch:** worktree-agent-a5a116edd676e190d
- **Commit:** b11571c729acb545774b92675d4ad0580adac44e (BUG8 fix; this worklog SHA-stamp
  follows in the next commit on the branch)

## What changed
Fixed the ping-pong bouncer grinding along walls / stalling at corners (RG3 feedback #2).
Root cause: `_physics_process` reflected the **post-`move_and_slide`** velocity, which
`move_and_slide` had already projected ALONG the wall (tangential). In a glancing hit or a
corner that tangential vector points nearly wall-parallel, so `bounce()` could not restore
the real incoming heading — the heading collapsed and the bouncer ground to a halt.

Fix: track the intended unit heading in an own var `_dir` (the source of truth). Each frame
set `velocity = _dir * _speed`, call `move_and_slide()`, then reflect **`_dir`** (not the
slid velocity) off the wall normal(s). A corner (two contacts in one frame) is handled by
**summing all slide-collision normals** and reflecting `_dir` off the resultant, so the
bouncer reverses out of the corner instead of being trapped between two walls. The `dot(n) <
0` into-wall guard is preserved (prevents double-flip jitter). The room-rect clamp
`_confine_to_room` now flips the perpendicular component of `_dir` (then re-syncs `velocity`)
rather than flipping `velocity` alone — a velocity-only flip would be overwritten by the
top-of-frame `velocity = _dir * _speed` and the bouncer would walk back through the edge.

Behaviour preserved: constant `_speed` forever, the room-rect clamp, the one-shot kill latch
+ `new_hazard_killed(&"pingpong", ...)` telemetry, RNG-free determinism (heading still comes
from `spawn_ctx["initial_dir"]`; no global RNG call added).

## Files touched
- `scenes/hazards/pingpong_hazard.gd` — added `_dir` heading var; reflect `_dir` (not slid
  velocity) off summed slide normals; clamp flips `_dir` + re-syncs velocity.
- `tests/test_pingpong_hazard.gd` — added case (f): build an L-corner of `world`-layer static
  walls, aim a bouncer diagonally into the vertex, step 90 physics frames, assert speed is
  still ~`_speed` AND it has bounced away from the corner (not parked). Added `_make_wall`
  helper. (Cases a–e unchanged.)

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK (exit 0)
- [x] `godot --headless res://tests/test_pingpong_hazard.tscn` → K5a OK, exit 0 (incl. new
  BUG8 corner anti-stall case f)
- [x] `godot --headless res://tests/test_rg1_m14_verify.tscn` → RG1 M1.4 VERIFY OK; all-off
  control **byte-identical, fp=e943ac9c8bc1**, exit 0
- [x] definition of done met: "the bouncer reflects cleanly off walls and corners and keeps
  moving at constant `_speed` forever (never stalls or grinds along a wall)"; all-off
  fingerprint unchanged at `e943ac9c8bc1`.

## Design deviations
none. The fix realises OQ-2's intent ("explicit reflect, never wall-grind — the I2 bug")
more faithfully than the original code did: it reflects the intended heading rather than the
slid velocity, which is what the design comment already described. No knob, signal, scene, or
contract change. Edited only `pingpong_hazard.gd` + its test, as scoped.

## Handoffs / follow-ups
none.
