# Worklog — L1 Throwing Mechanic

- **Date:** 2026-06-24
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.5
- **Branch:** general-purpose/L1
- **Commit:** 6bc6bf3eaa8b304b6055600acc8c861b114b5daa (worklog SHA-stamp amended in)   ← required

## What changed
Implemented the L1 throwing mechanic per the Phase-4-locked contract. Players can now
highlight a carried inventory item (Q/E, wraps), then Space throws it in the player's
facing direction; a hit on any `hazard`-layer body (the R1 pursuer or the K5 ping-pong)
kills the body + consumes the item, while a miss (wall / max-range / in-script lifetime
fallback) re-drops the item as a grabbable pickup via the existing `EventBus.junk_dropped`
path. Includes the input remap (F = interact, Q/E = highlight L/R, Space = throw). Throw +
highlight are pure run-state; the all-off baseline fingerprint stays `e943ac9c8bc1`.

## Files touched
- `project.godot` — `[input]` remap: `interact`=F(physical 70)+joypad-btn0 (dropped E+Space);
  new `highlight_left`=Q(physical 81), `highlight_right`=E(physical 69), `throw`=Space(keycode 32);
  `extract` kept declared (telemetry references `&"extract"`) with only its joypad btn1 (Q key dropped).
- `data/run_config/run_config.gd` — preset line only: `c.throw_enabled = true` in
  `make_default_play_preset()` (ships the mechanic live for RG1). No code-level default changed.
- `ui/inventory/inventory_cell.gd` — `set_highlighted(on)` view method; a 2px bright whole-cell
  `StyleBoxFlat` border override on the PanelContainer (transparent fill; removed on toggle-off).
- `ui/inventory/inventory_panel.gd` — `_highlight_index` view state; `highlighted_index()` /
  `highlighted_item()` getters; Q/E `_unhandled_input` navigation (modulo wrap); `_revalidate_highlight`
  (clampi on shrink) + `_apply_highlight_visual` hooked into `_refresh()`; reset to -1 on no-bag.
- `scenes/game/main_game.gd` — `_inventory_panel` ref (DecisionHUD/Root/InventoryPanel);
  `_unhandled_input` throw handler (run-active gated); `_try_throw` (knob-gated, `remove_at`,
  emits `item_thrown`); `_spawn_thrown_item` (lazy scene load, parents under `_band_container`).
- `entities/thrown_item/thrown_item.gd` + `.tscn` — new Area2D projectile (layer 0, mask 18),
  hand-integrated motion, `body_entered`-driven, one-shot `_spent` guard, hidden `MAX_LIFETIME_S=5.0`
  fallback, reuses JunkPickup's greybox look; kill → `throw_killed_hazard` + free body + consume item;
  miss → `throw_missed` + `junk_dropped`.
- `tests/test_throw_mechanic.gd` + `.tscn` — new headless scene test (kill / miss / `_spent`).

## Checks run
- [x] `godot --headless --import` clean (no parse errors in any L1 file; pre-existing missing
  `.translation` warnings are unrelated and regenerate on import)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK (exit 0)
- [x] `godot --headless res://tests/test_run_config.tscn` → R0 OK, **89 knobs**, preset trap-free,
  all-off control intact (exit 0)
- [x] `godot --headless res://tests/test_corridor_lever.tscn` → J4 OK, all-off fp byte-matches
  **e943ac9c8bc1** (exit 0)
- [x] `godot --headless res://tests/test_throw_mechanic.tscn` → **L1 OK**: hazard-hit kills body +
  consumes item (no re-drop) + emits `throw_killed_hazard`; miss emits `throw_missed` + `junk_dropped`;
  one-shot `_spent` guard resolves exactly once (exit 0)
- [x] Definition of done: "Inventory item highlightable (Q/E, wraps, re-validates, visible highlight);
  Space removes the highlighted item + spawns a thrown projectile travelling in facing; hits a pursuer
  → kills it + destroys item; miss → re-drops via junk_dropped; input remap; knob-gated (throw_enabled
  default off, preset on)." — met.

## Design deviations
- **Telemetry `run_t_ms` time base.** The spec pseudocode referenced a `_run_t_ms()` helper but
  GameState exposes no public run-elapsed accessor (`_elapsed_s()` is private; game_state.gd is NOT in
  my touch list). I used `Time.get_ticks_msec()` (monotonic engine clock) for the `item_thrown` /
  `throw_missed` / `throw_killed_hazard` timestamps in both main_game and the projectile, so the three
  rows of one throw share a time base. RG2 only needs in-run ordering; this matches the spirit of
  hazard_entity.gd's local ms stamping. Low-risk, no contract change. — surfaced for review, no Director
  sign-off needed.
- **Throw test runs as a SCENE, not `--script`.** The projectile references the `EventBus` autoload
  directly, which only exists when autoloads load (i.e. running a scene). Per orchestrator memory
  ("verify tests run as SCENES"), the test is `tests/test_throw_mechanic.tscn`. On-spec.
- Otherwise fully on-spec (Area2D layer 0/mask 18, kind = `&"pursuer"`/`&"pingpong"` typed checks,
  clampi-revalidate + modulo-wrap, StyleBoxFlat border, no code-level default change).

## Handoffs / follow-ups
- L2 (spawn-room pursuer) is SEQUENCED AFTER L1 on `main_game.gd` per the Wave-2 verdict — L2 rebases
  on this branch's main_game.gd throw seam. L5 (K5 `*_kills`) is disjoint and parallel.
- `throw_speed` (180) / `throw_max_range` (320) ship at the L0 code defaults — sweepable by the
  Director in RG1.
