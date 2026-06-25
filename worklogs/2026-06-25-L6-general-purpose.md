# Worklog — L6 Control rework: mouse-aim throwing + twin-stick controller

- **Date:** 2026-06-25
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.5
- **Branch:** general-purpose/L6
- **Commit:** 19b5823fb24f03af259e4d70a33be4811764d4cd

## What changed
Reworked the control scheme per the Director's RG3 playtest feedback ("controls are clunky"),
**input + presentation only** — no RunConfig / generation / save / telemetry changes. Decoupled an
explicit `aim` from movement: KB/M aims at the mouse, controller aims with the right stick (twin-stick).
The player now **points at the aim** (nose + `facing` follow `aim`, not the movement direction), throwing
fires in the aim direction on **LMB / RT** (Space kept), and the highlight cycles on **mouse wheel / LB·RB**
(Q/E kept). Device arbitration lives in a pure, headlessly-tested `resolve_aim()` helper.

## Files touched
- `project.godot` — `[input]`: added LMB (btn 1) + RT (joypad axis 5, +1.0) to `throw`; mouse-wheel-up
  (btn 4) + LB (btn 9) to `highlight_left`; mouse-wheel-down (btn 5) + RB (btn 10) to `highlight_right`
  (all keep their existing KB events); **new** right-stick aim actions `aim_left`/`aim_right` (axis 2 ±1.0)
  and `aim_up`/`aim_down` (axis 3 ±1.0), deadzone 0.25.
- `entities/player/player.gd` — added `var aim` (new facing source) + `AIM_STICK_DEADZONE` const +
  `_mouse_active` flag; `_physics_process` now gathers right-stick (`Input.get_vector(aim_*)`) + mouse
  direction and calls the new **pure** `resolve_aim(stick, mouse_dir, mouse_active, move_dir, prev)`;
  `_input` sets `_mouse_active` on `InputEventMouseMotion`; nose + `facing` now track `aim`. Movement
  math (`step_velocity`) untouched.
- `scenes/game/main_game.gd` — throw seam (`_try_throw`) now passes `player.aim` (was `player.facing`)
  to `_spawn_thrown_item`; doc comment updated.
- `entities/thrown_item/thrown_item.gd` — `setup()` doc comment updated (`dir` is now `player.aim`).
- `tests/test_throw_mechanic.gd` — added CASE 4: a thrown item flies along `player.aim` (non-cardinal
  aim, proving the seam reads aim not facing) + `resolve_aim` surfaces the mouse aim. Player instantiated
  but NOT added to the tree (no physics space needed). Success banner → `L1+L6 OK`.
- `tests/test_resolve_aim.gd` — **new** headless unit test (`--script`) for the pure arbitration:
  stick>deadzone wins (+normalized), sub-deadzone defers, mouse-after-motion, stale-mouse ignored
  (hold last), first-frame move/DOWN default, hold-last beats movement.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK**
- [x] `godot --headless res://tests/test_run_config.tscn` → **R0 OK** (89 knobs, all-off baseline)
- [x] `godot --headless res://tests/test_config_menu.tscn` → **CONFIG MENU OK** (89/89 knobs)
- [x] `godot --headless res://tests/test_rg1_m15_verify.tscn` → **RG1 M1.5 VERIFY OK**, all-off
      fingerprint **`e943ac9c8bc1`** (byte-unmoved), exit 0
- [x] `godot --headless res://tests/test_throw_mechanic.tscn` → **L1+L6 OK** (CASE4 aim-direction throw)
- [x] `godot --headless --script res://tests/test_resolve_aim.gd` → **RESOLVE_AIM OK** (4 priority
      branches + deadzone + stale-mouse)
- [x] `godot --headless --script res://tests/test_player_movement.gd` → **MOVE OK** (no regression;
      cardinal==diagonal, max_speed 200)
- [x] Definition of done: aim decoupled (mouse/right-stick), point-at-aim, LMB/RT throw in aim dir +
      Space kept, wheel/LB·RB cycle + Q/E kept, full headless gate green incl. fp `e943ac9c8bc1` and
      89 knobs; new `resolve_aim` cases pass. (Felt mouse/controller experience is human-deferred to the
      Director's re-test — headless cannot inject real mouse/gamepad hardware.)

## Invariants confirmed
- All-off band fingerprint **`e943ac9c8bc1`** — unchanged (input never touches generation).
- Knob count **89** — unchanged; no `RunConfig` field added, no `to_flat_dict()` change.
- No save/schema change; `run_ended` arity untouched; L1 throw telemetry rows still fire.
- Movement feel unchanged (`step_velocity` + move bindings identical); only the `facing`/aim source +
  aim/throw/cycle bindings changed.

## Design deviations
none — implemented exactly per `design/M1_5_Tasks/L6_control_rework.md` §1–§2 and the locked decisions.

Two implementation notes (not deviations from the locked spec):
1. The `_mouse_active` clear-on-stick-takeover happens in `_physics_process` (not inside `resolve_aim`),
   keeping `resolve_aim` a genuinely **side-effect-free pure function** so the unit test exercises it in
   isolation. The §2.2 contract (the resolver implements the arbitration; `_physics_process` gathers
   inputs + maintains the flag) is preserved.
2. `tests/test_player_movement` and the new `tests/test_resolve_aim` run as SceneTree **`--script`** tests
   (they have no `.tscn`), matching the existing movement-test invocation — not as scenes. The L6 brief's
   verify-matrix listed `test_player_movement.tscn`; that scene does not exist in-repo and the test is a
   `--script` SceneTree. Ran it the correct (existing) way.

## Handoffs / follow-ups
- **Human Director re-test:** the felt mouse-aim + twin-stick controller experience needs a live play
  pass (headless can't drive real mouse/gamepad). All logic (resolve_aim, action wiring, aim-direction
  throw) is verified headlessly.
- Left the branch `general-purpose/L6` for the orchestrator to integrate — **not merged to main**.
