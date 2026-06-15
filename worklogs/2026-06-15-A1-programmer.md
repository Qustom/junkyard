# Worklog — A1 Player Scene with Top-Down Movement

- **Date:** 2026-06-15
- **Subagent:** programmer (general-purpose)
- **Milestone:** M1
- **Branch:** programmer/A1-player-movement
- **Commit:** f09691ae621a0f0b9dcaf95dac21b8a253d1246f

## What changed
Built the `Player` entity foundation: a `CharacterBody2D` scene with greybox
visuals and smooth 8-direction movement (accel/friction) driven entirely by named
Input Map actions, identical for keyboard and controller via `Input.get_vector`.
Movement tuning is data-authored as a `PlayerMovementStats` Resource. Added the
locked project-wide Input Map (movement + interact, plus reserved extract/pause)
and the locked collision-layer map. Movement is verified headlessly via a new
test that drives the player's own integration math for all 8 directions.

## Files touched
- `entities/player/player.gd` — `class_name Player`. `_physics_process` reads
  `Input.get_vector(...)`, calls `step_velocity()` (extracted pure helper for
  testability), updates read-only `facing` (last non-zero dir, for A2), then
  `move_and_slide()`. Optional `Nose` marker rotates to `facing`.
- `entities/player/player.tscn` — root `Player` (CharacterBody2D, layer 1 /
  mask 26 = world+enemy+hazard). Children: `Visual` (28×28 teal ColorRect
  centered), `Nose` (Polygon2D facing indicator pointing +X), `CollisionShape2D`
  (CircleShape2D r=14), `InteractionOrigin` (Marker2D for A2). Stats wired to the
  .tres.
- `data/player/player_movement_stats.gd` — `class_name PlayerMovementStats
  extends Resource`: exported `max_speed`, `acceleration`, `friction`.
- `data/player/player_movement.tres` — authors ship values 200 / 2000 / 2000.
- `entities/player/player_test.tscn` — Node2D with Player instanced + 4 static
  walls on the `world` layer to demonstrate movement + collision in-editor and
  to give a headless load target.
- `tests/test_player_movement.gd` — headless SceneTree harness asserting all 8
  directions move the body the right way, diagonal speed == cardinal speed, the
  body reaches `max_speed`, and `facing` tracks input. Prints `MOVE OK`.
- `project.godot` — added `[input]` (move_up/down/left/right with WASD + arrows +
  left-stick axes (deadzone 0.2) + D-pad; `interact` = E/Space/joy0; reserved
  `extract` = Q/joy1 and `pause` = Start/joy6, declared but unbound to listeners)
  and `[layer_names]` (1=player, 2=world, 3=interactable, 4=enemy, 5=hazard).

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy`
- [x] task-specific: `godot --headless --script res://tests/test_player_movement.gd`
  → `MOVE OK — 8-direction movement verified (cardinal=91.7px diagonal=91.7px over 0.5s, max_speed=200)`
- [x] scenes instantiate headlessly (`player.tscn` root=Player, `player_test.tscn` root=PlayerTest)
- [x] collision layer/mask verified at runtime: layer=1, mask=26 (world+enemy+hazard, not interactable)
- [x] definition of done met: "Movement is smooth in all 8 directions, read from
  named Input Map actions; both keyboard and controller produce identical
  movement." Both devices bind the same actions and `Input.get_vector` normalizes
  identically; the 8-dir math is asserted automatically. The keyboard-vs-controller
  *feel* parity is a one-time manual in-editor confirmation (input cannot be
  injected headless) — see follow-up.

## Design deviations
- **Greybox placeholder stubbed inline as a `ColorRect`** (28×28 teal) plus a tiny
  Polygon2D nose, instead of dispatching character-animator / PixelLab for art.
  This is **on-spec** — the A1 spec explicitly says "For M1 use a `ColorRect` ...
  OR a `Polygon2D` outline" — so it needs no Director sign-off. PixelLab is
  paid/human-gated and out of scope for A1.
- **Extracted `step_velocity()` pure helper** from `_physics_process` (not in the
  spec's code sketch) so the movement math is unit-testable headlessly (a raw
  `--script` SceneTree has no stepped physics space, so `move_and_slide()` is a
  no-op there). Behavior is byte-identical to the sketch; this is a structural
  testability choice, not a design change. No sign-off needed.
- Otherwise fully on-spec (followed all "Open questions" recommendations: .tres
  stats, movement-only facing, reserved extract/pause, locked layer map, level-
  owned camera deferred — no PhantomCamera in player.tscn).

## Handoffs / follow-ups
- **Manual parity check (human, ~1 min):** open `entities/player/player_test.tscn`
  in the editor and confirm WASD/arrows and a controller left-stick both drive
  identical 8-dir movement and that diagonals don't feel faster. Automated math
  already proves equality; this just confirms real-device bindings.
- **Tuning gate:** 200 / 2000 / 2000 are M1 ship values; lock only after one
  playtest pass against real room scale (per A1 open question).
- **A2 hooks ready:** `InteractionOrigin` Marker2D and read-only `Player.facing`
  are in place; A2's `InteractionDetector` Area2D should use layer empty / mask 3
  (interactable) per the locked map.
- **Concurrency note for orchestrator (IMPORTANT):** the shared working tree at
  `/mnt/c/source/junkyard` is being used by multiple parallel agents that each run
  `git switch`; this repeatedly clobbered/removed my untracked files and switched
  my branch out from under me (it ended up on `programmer/B1-zone-piece-format`).
  I finished A1 in an isolated git worktree (`git worktree add /tmp/junkyard-A1-worktree
  programmer/A1-player-movement`) and committed there. Strongly recommend giving
  each parallel agent its own worktree rather than one shared checkout.
