# Worklog — FIXINTERP reset_physics_interpolation at world-entity spawn teleports

- **Date:** 2026-06-28
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.7
- **Branch:** general-purpose/fix-interp
- **Commit:** aa3e59d40f95bc049f827ad982646d5bc6f7b371

## What changed
The project runs with `physics/common/physics_interpolation=true` (`Game/project.godot:161`).
Every spawn followed the `add_child(node)` → `node.global_position = …` pattern WITHOUT a
`reset_physics_interpolation()` call, so Godot rendered each newly-spawned/teleported world
Node2D for one frame interpolated between its (origin) spawn transform and its real position —
a visible one-frame "ghost/flash to somewhere else". There were ZERO such reset calls in the
codebase. Added a `reset_physics_interpolation()` call immediately after the position is set at
every world-entity spawn-teleport. This is a render-only change: no position VALUE, spawn logic,
gameplay, or RNG was touched, so the determinism fingerprint is unmoved (verified below).

## Files touched
- `Game/systems/spawning/junk_spawner.gd` — `spawn_one()` after `pickup.global_position = world_pos`.
  Single fix covers BOTH planned band junk AND re-dropped junk (the `_on_junk_dropped` path
  routes through `spawn_one`) — the main reported "junk jumps when picked up / at end of throw" bug.
- `Game/scenes/game/main_game.gd` — five sites:
  - `start_new_run()` after `_player.global_position = spawn_pos` (dive-start player ghost).
  - `start_new_run()` after `_camera_rig.global_position = spawn_pos` (dive-start camera ghost; null-guarded as the existing code is).
  - `_spawn_new_hazards()` J2 spread path after `hz.global_position = pos` (hazard spawn ghost).
  - `_spawn_new_hazards()` R1 density/per-kind path after `hz.global_position = pos` (hazard spawn ghost).
  - `_populate_room_density()` after `hz.global_position = positions[i]` (density hazard spawn ghost).
  - `_spawn_thrown_item()` after `proj.global_position = origin` (thrown-item projectile ghost).
  - `_spawn_gate_at()` after `gate.global_position = world_pos` (extract-gate spawn ghost).

## Sites deliberately NOT changed
- `main_game.gd _physics_process()` `_camera_rig.global_position = _player.global_position`
  (~line 960) — this is the per-tick camera FOLLOW, not a spawn-teleport. Its interpolation is
  the intended K6 (M1.4) jitter fix; resetting it every tick would defeat camera smoothing. Left
  as-is by design.

## Checks run
- [x] `godot --headless --path Game --import` clean — no parse errors, IMPORT_EXIT=0.
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → "SMOKE OK — M0 architecture spike healthy", exit 0.
- [x] All-off determinism fingerprint UNCHANGED: `godot --headless --path Game res://tests/test_rg1_m15_verify.tscn`
      → "RG1 M1.5 VERIFY OK … All-off control is byte-identical to the locked baseline
      (fp=e943ac9c8bc1)", exit 0. Fingerprint still `e943ac9c8bc1` — confirms the change is render-only.
- [x] `res://tests/test_junk_pickup.tscn` → "JUNK PICKUP OK …", exit 0.
- [x] `res://tests/test_drop_swap.tscn` → "DROP SWAP OK …", exit 0.
- [x] `res://tests/test_main_game_loop.tscn` → "MAIN GAME OK …", exit 0.
- Note: the leaked-RID / ObjectDB-leak warnings on scene exit are pre-existing headless-shutdown
  noise (present on baseline runs), unrelated to this change. The "Camera2D overridden to physics
  process mode due to use of physics interpolation" warning is also pre-existing (interpolation
  was already on).
- [x] Definition of done: "after every spawn-teleport of a world Node2D … call
      `node.reset_physics_interpolation()`" — met at all 7 visible-world-entity spawn sites;
      import + smoke + fp + junk/throw tests all green; fingerprint unmoved.

## RG1 manual verification item (cannot be confirmed headless)
The actual disappearance of the one-frame ghost is a render-only effect that a headless run
cannot observe. **Flagged as an RG1 manual-playtest item:** in a GUI/web build confirm that
(a) thrown junk and re-dropped junk no longer flash/ghost for one frame, (b) the player/camera
no longer ghost at dive start, and (c) hazards and the extract gate no longer flash on spawn.

## Design deviations
none — render-only call addition; no design/GDD/TDD/playbook surface changed; determinism
fingerprint preserved (e943ac9c8bc1).

## Handoffs / follow-ups
- Branch left unmerged/unpushed for the orchestrator to integrate (per task instructions).
- Manual visual confirmation of the ghost being gone is the one RG1 checklist item above.
