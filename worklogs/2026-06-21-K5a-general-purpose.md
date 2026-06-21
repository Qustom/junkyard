# Worklog — K5a Ping-pong hazard

- **Date:** 2026-06-21
- **Subagent:** general-purpose
- **Milestone:** M1.4 (Wave 3)
- **Branch:** general-purpose/K5a-pingpong
- **Commit:** c60a4e93e06d612073b50b301acdc8b9ab10579c

## What changed
Built the new **PingPongHazard** greybox entity (script + scene) + a headless test. A
`CharacterBody2D` that travels at a constant `hpp_speed`, explicitly reflects its velocity
off `world`-layer walls (`velocity.bounce(n).normalized() * _speed` with a `dot(n) < 0`
corner-jitter guard), optionally clamps+reflects at a room-rect (`spawn_ctx["room_bounds"]`,
no-op for an empty Rect2), and kills the player on a deterministic per-frame distance test
(`CONTACT_RADIUS = 24`) routed through the existing `GameState.fail_run(&"death")`. Emits the
K0-declared `EventBus.new_hazard_killed(&"pingpong", depth, run_t_ms)` exactly once via a
BUG6-style rising-edge latch. ONLY the entity was built — the spawn-seam wiring is K5i's
single-writer job; this entity is file-disjoint (touches no `main_game.gd` / `run_config.gd`
/ `event_bus.gd`).

## Files touched
- `scenes/hazards/pingpong_hazard.gd` — new entity script (mirrors `hazard_entity.gd` shape;
  no state machine, constant velocity, explicit bounce + optional room clamp, distance kill).
- `scenes/hazards/pingpong_hazard.tscn` — new scene: `CharacterBody2D` in group `["hazard"]`,
  `collision_layer=16` (hazard), `collision_mask=2` (world) — identical to R1; `CircleShape2D`
  radius 10; amber box `Tell` `Polygon2D` (`Color(0.95,0.65,0.15)`, 20×20 square).
- `tests/test_pingpong_hazard.gd` + `.tscn` — new headless acceptance test (see Checks).

## Checks run
- [x] `godot --headless --import` clean — no parse errors referencing pingpong/SCRIPT ERROR.
      (Pre-existing unrelated `ui/*_strings.en.translation` "Cannot open file" warnings only —
      generated artifacts, not my files.)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK` (exit 0).
- [x] `godot --headless res://tests/test_bandgen_determinism.tscn` → exit 0, fingerprint
      unmoved: `BANDGEN OK — ... sample seed 12345 -> 12 pieces, fp=e943ac9c8bc1`.
- [x] `godot --headless res://tests/test_pingpong_hazard.tscn` → `K5a OK` (exit 0): empty
      spawn_ctx constructs safely (default RIGHT heading), `initial_dir` sets velocity,
      `room_bounds` clamp reflects + snaps back inside, the distance-test kill ends the run
      via `fail_run(&"death")` and emits `new_hazard_killed(&"pingpong")` EXACTLY once, and
      the entity source makes no global-RNG call.
- [x] Definition of done met: "Create the new PingPongHazard entity script + scene (+ a test);
      do not touch main_game.gd / run_config.gd / event_bus.gd; setup uses the LOCKED
      `setup(cfg, player, spawn_ctx)`; all-off baseline byte-identical (fp `e943ac9c8bc1`)."

## Design deviations
- **Adopted the LOCKED `setup(cfg, player, spawn_ctx: Dictionary = {})` over the Phase-2
  positional `setup(cfg, player, initial_dir, room_bounds)`** — per the Phase-3 cross-cutting
  lock in the doc's Resolved Decisions ("CROSS-CUTTING — shared setup() contract"). The entity
  reads `spawn_ctx.get("initial_dir", Vector2.RIGHT)` and `spawn_ctx.get("room_bounds", Rect2())`.
  This is the ratified contract, not a true departure. No other deviation of substance.
- All Resolved Decisions honored: OQ-1 (b)+(a) combined wall-bounce + room-rect clamp; OQ-2
  explicit `bounce(n)` reflect with `dot(n)<0` guard; OQ-4 fixed direction supplied by K5i
  (entity is RNG-free); OQ-5 fatal-no-toggle; OQ-6 fixed `CONTACT_RADIUS=24`; OQ-7 amber
  `COLOR_LIVE` + box silhouette (the final palette remains a Director/character-animator RG1
  call — greybox placeholder per scope). Added a scope-safe one-shot squash Tween on bounce
  (juice only; the doc §3 explicitly allows it as the character-animator's optional call).

## Handoffs / follow-ups
- **K5i (spawn seam)** wires this entity in: `const PINGPONG_SCENE_PATH`, a
  `_spawn_hpp_hazards(rc, band)` gated on `rc.hpp_enabled`, building `spawn_ctx` per instance
  (`initial_dir` as a deterministic function of spawn index; `room_bounds` = the room's
  floor-cell bounding box) and applying the per-room depth-scaled count + `hpp_per_room_cap`.
- **OQ-7 palette** (amber hue + box shape) is flagged in the doc as a Director +
  character-animator "decide-as-a-set" call across R1/K5a/K5b/K5c, to ratify at RG1.
- New scene path for K5i: `res://scenes/hazards/pingpong_hazard.tscn`.
