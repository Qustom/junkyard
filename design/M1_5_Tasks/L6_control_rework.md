# L6 — Control rework: mouse-aim throwing + twin-stick controller support

**Task id:** L6 · **Milestone:** M1.5 (Agency & Legibility) · **Wave:** 4 (post-RG3 control feedback) · **Role:** `general-purpose`
**Source:** Director M1.5 playtest feedback (RG3) — "controls are clunky." Aim from the mouse (not facing), click to throw,
scroll wheel to cycle the highlighted item, the player points at the aim, and add controller support.
**Companion docs:** `design/M1_5_Tasks/L1_throwing_mechanic.md` (the scheme this replaces), `entities/player/player.gd`,
`scenes/game/main_game.gd` (the throw seam ~L1163), `ui/inventory/inventory_panel.gd` (highlight selector), `project.godot` `[input]`.

> **This is a control-scheme rework, not new gameplay.** The throwing mechanic, highlight selector, and thrown projectile
> (L1) all stay; only **how you aim, throw, and cycle** changes, plus **controller bindings**. It is **input + presentation
> only** — it does NOT touch `RunConfig`, generation, saves, or telemetry semantics. **The all-off fingerprint stays
> `e943ac9c8bc1` and the knob count stays 89** (input is global, never run-config).

---

## 1. Locked decisions (Director-ratified)

- **Aim = where you point, not where you move.** Decouple an explicit **`aim`** direction from movement.
  - **Mouse/keyboard:** `aim = (get_global_mouse_position() - player.global_position).normalized()`. The player **points at
    the mouse** (rotate the existing `Nose` marker; `facing` becomes the aim).
  - **Controller (twin-stick):** `aim = right-stick direction` when its magnitude > deadzone.
- **Throw = click / trigger.** Throw fires on **left mouse button** (KB/M) and **right trigger RT** (controller), in the
  **aim** direction. **Keep Space** bound as a fallback (Director: keep KB fallback).
- **Cycle = scroll / bumpers.** Cycle the highlighted item with the **mouse scroll wheel** (KB/M) and **LB/RB** (controller).
  **Keep Q/E** bound as a fallback.
- **Controller scheme = twin-stick:** left stick/dpad move (already bound), right stick aims+turns, RT throws, LB/RB cycle.
  `A`=grab/interact, `B`=extract, `Start`=pause are already bound — leave them.
- **Device arbitration:** prefer the **right stick when it is above its deadzone**; otherwise use **mouse aim only after a
  mouse-motion event** (so on a controller, a stale mouse position does not hijack the aim); otherwise **hold the last aim**.
  When neither has ever been used this run, default aim to the **movement direction** (falls back to `Vector2.DOWN` like today).

## 2. Changes

### 2.1 `project.godot` `[input]`
- **`throw`** — add **LMB** (`InputEventMouseButton` button_index 1) and **RT** (`InputEventJoypadMotion` axis 5,
  axis_value 1.0). Keep the existing Space event.
- **`highlight_left`** — add **mouse wheel up** (`InputEventMouseButton` button_index 4) and **LB**
  (`InputEventJoypadButton` button_index 9). Keep Q.
- **`highlight_right`** — add **mouse wheel down** (`InputEventMouseButton` button_index 5) and **RB**
  (`InputEventJoypadButton` button_index 10). Keep E.
- **New aim actions** for the right stick so `Input.get_vector` applies the deadzone consistently:
  `aim_left`/`aim_right` on **axis 2** (±1.0), `aim_up`/`aim_down` on **axis 3** (±1.0), deadzone ≈ 0.25. (KB/M aim comes
  from the mouse position, not an action.)

### 2.2 `entities/player/player.gd`
- Add `var aim: Vector2 = Vector2.DOWN` (read-only for the throw seam + A2 grab bias). Keep `facing` as an alias/keep it
  in sync (or replace its assignment): the visual nose and the A2 facing-bias should follow **aim**.
- Compute aim each `_physics_process` via a **pure, unit-testable helper** (mirror `step_velocity`'s split):
  `resolve_aim(stick: Vector2, mouse_dir: Vector2, mouse_active: bool, move_dir: Vector2, prev: Vector2) -> Vector2`
  implementing the §1 arbitration. `_physics_process` gathers the inputs (right-stick via `Input.get_vector(aim_*)`, mouse
  via `get_global_mouse_position()`, a `_mouse_active` flag toggled by `InputEventMouseMotion` in `_input`) and calls it.
- Point the nose at aim: `_nose.rotation = aim.angle()` (replaces the facing-based line). Movement is unchanged.

### 2.3 `scenes/game/main_game.gd` (throw seam ~L1163–1223)
- The `throw` action already routes through `_unhandled_input` → `_try_throw()`; the new LMB/RT events flow through it
  unchanged. **Spawn the projectile in the aim direction:** pass `player.aim` (not `player.facing`) to `_spawn_thrown_item`.
- Cycle: confirm the inventory panel's highlight responds to `highlight_left`/`highlight_right` (it does for Q/E); the new
  wheel/bumper events fire the same actions, so no panel change should be needed — verify and wire if the panel reads the
  raw keys instead of the actions.

### 2.4 Tests
- **`tests/test_throw_mechanic`** — update: the throw now uses **aim**, not facing. Drive a known `aim` and assert the
  projectile's direction matches.
- **New coverage for `resolve_aim`** — headless unit cases: stick-above-deadzone wins; mouse-after-motion when stick
  neutral; last-aim held when neither active; movement-direction default on first frame. (Pure function, no physics space.)
- Re-run the full gate; **assert no regression**: smoke, `test_run_config` (R0 OK, 89 knobs), `test_config_menu` (89/89),
  `test_rg1_m15_verify` (RG1 M1.5 VERIFY OK, **all-off fp `e943ac9c8bc1`**), `test_pursuing_hazard`, `test_player_movement`.

## 3. Invariants (must hold)
- **All-off band fingerprint `e943ac9c8bc1` byte-unmoved** (input changes never touch generation).
- **Knob count stays 89**; no `RunConfig` field added (input is global, not run-config); no `to_flat_dict()` change.
- **No save/schema change**; `run_ended` arity untouched; telemetry semantics unchanged (the L1 throw rows still fire).
- Movement feel unchanged (left stick/WASD identical); only aim/throw/cycle bindings + the player's facing source change.

## 4. Definition of done
1. In a desktop build: the player **points at the mouse**, **left-click throws** a highlighted item toward the cursor,
   **scroll wheel cycles** the highlight; **Q/E + Space still work**.
2. With a controller: **right stick aims+turns** the player, **RT throws**, **LB/RB cycle**; left stick moves; A/B/Start as before.
3. Full headless gate green incl. `RG1 M1.5 VERIFY OK` and the all-off fp `e943ac9c8bc1`; new `resolve_aim` cases pass.
4. Worklog `worklogs/2026-06-25-L6-general-purpose.md` names the commit SHA + a Design-deviations section (or "none").
