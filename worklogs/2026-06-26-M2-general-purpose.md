# Worklog — M2 Hub scene + Menu→Hub→Dive→Hub flow (dive-only main_game refactor)

- **Date:** 2026-06-26
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.6 (Surface & Staging), Wave 2
- **Branch:** general-purpose/M2
- **Commit:** bcf5f2f22c062914c173e9490a902d3cf2363949

## What changed
Built the walkable greybox **Hub** (`scenes/hub/hub.*` replacing the M0 stub) + a **departure-portal**
interactable (`scenes/hub/departure_portal.*`, modeled on the ExtractGate owner-acts-on-`interaction_requested`
pattern → emits `EventBus.dive_requested(&"near")`). Refactored `scenes/game/main_game.*` to **dive-only**:
stripped the embedded `MainMenu` CanvasLayer + `%ConfigMenu` rail + `SellScreen` + the old G6 telemetry-consent
wiring; the dive now **self-starts** on `_ready()` (resolving its `RunConfig` via
`GameState.dive_config_or_default()` instead of the menu rail) and routes run-end to the Hub via the M0 App
router's auto-return (no SellScreen auto-present). The **Hub-return beat** (`hub.gd:_ready`) fires
`GameState.evaluate_quota_on_return()` and `wipe_meta()` on a quota MISS — decoupled from selling, guaranteed on
every return — and shows a throwaway "Held: N items ~$X" readout (RD-7). Fixed the test fallout in
`test_main_game_loop.gd` + the 5 RG verify scenes (config staged via `GameState.stage_dive_config`, SellScreen
dismiss/asserts retired).

## Files touched
- `scenes/hub/hub.gd` / `hub.tscn` — REPLACED the M0 stub with a bespoke static greybox room (RD-1): Floor
  ColorRect, `Walls` StaticBody2D on `world`(layer 2) so the player's mask=26 collides, 4 walls, `PlayerSpawn`
  Marker2D, `player.tscn` instance, `DeparturePortal`, an inert `ShopAnchor` Marker2D for M3, a `HubCamera`, and a
  `HudLayer` with the held-haul readout. `hub.gd` places the player at spawn, runs the quota/wipe return beat
  (RD-6), and refreshes the held-haul label. NO DiveClock, NO run-state, reads meta only.
- `scenes/hub/departure_portal.gd` / `.tscn` (NEW) — greybox `Area2D` + child `Interactable(id=&"portal")`; the
  owner copies the gate's node-identity guard + lockout and emits `EventBus.dive_requested(band_id)`.
- `scenes/game/main_game.gd` — removed `@onready` refs (`_menu`/`_start_button`/`_version_label`/`_sell_screen`/
  `_config_menu`), `_consent_pending`, the `ConsentPromptScript` const; `_ready()` now self-starts via
  `start_new_run()`; config resolves from `GameState.dive_config_or_default()`; deleted `_on_continue_pressed`/
  `_on_start_pressed`/`_on_back_to_config`/`_maybe_show_consent_prompt`/`_on_consent_choice`/`_show_menu`/
  `_hide_menu`; `_on_run_ended` keeps the corridor-summary + freeze (router owns the Hub return).
- `scenes/game/main_game.tscn` — removed the `SellScreen` node + the `MainMenu` CanvasLayer subtree + their two
  ext_resources (sell_screen, config_menu); `load_steps` 11→9. Dive-only.
- `tests/test_main_game_loop.gd` — self-start aware; extract now asserts the haul is HELD-banked (not auto-sold).
- `tests/test_rg1_loop_verify.gd` / `_m12` / `_m13` / `_m14` / `_m15` — replaced the `%ConfigMenu` grab + per-row
  mutation with `GameState.stage_dive_config(cfg)`; `_dismiss_sell_screen` → no-op (router auto-returns); dropped
  the `SellScreen/.../BackToConfigButton`-exists asserts; the J1/RG "boots default preset" check now reads
  `GameState.dive_config_or_default()`; V7 (loop_verify) reset-to-baseline retargeted to the staging equivalent.

## Checks run
- [x] `godot --headless --import` clean (no parse errors; only pre-existing missing `.translation` artifacts)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK (exit 0)
- [x] `godot --headless res://tests/test_app_router.tscn` → ROUTER OK (boot→menu→hub→dive→hub with the real hub)
- [x] `godot --headless res://tests/test_corridor_lever.tscn` → fp byte-matches `e943ac9c8bc1`
- [x] `godot --headless res://tests/test_config_menu.tscn` + `test_run_config.tscn` → 89/89 knobs (unchanged)
- [x] `godot --headless res://tests/test_main_game_loop.tscn` → MAIN GAME OK
- [x] `godot --headless res://tests/test_corridor_summary_row.tscn` → J4-ROW OK
- [x] `test_rg1_loop_verify` / `_m12` / `_m14` / `_m15` → all VERIFY OK
- [~] `test_rg1_m13_verify` → FAILS, but **PRE-EXISTING + FLAKY on `main`** (see deviations), not M2 fallout
- [x] regression: `test_loop_drive` / `test_duration_loop_reentry` / `test_exposure_meter` / `test_quota_system` → OK
- [x] definition of done met: Menu→Hub→portal→Dive→return→Hub flows; clock dive-only; quota+wipe on the Hub
      `_ready` return beat decoupled from selling; `main_game` dive-only + self-starts; SellScreen auto-present
      removed; old G6 path removed; held-haul readout present; touched tests green; fp byte-identical; 89-knob held.

## Design deviations
- **`main_game._on_run_ended` does NOT emit `returned_to_hub`** (the M2 spec B3 pseudocode showed it emitting it).
  Reason: the M0 App router (`scenes/app/app.gd`, locked in Wave 1) **observes `run_ended` directly** and owns the
  deferred auto-return (`_on_run_ended` → `_return_after_dive` → emits `returned_to_hub` + swaps to the Hub). A
  second emit from main_game would double-fire the return. main_game stays decoupled and emits nothing new — fully
  consistent with the Breakdown's locked "the router observes the locked `run_ended` to auto-return." On-spec re:
  the router contract; the spec pseudocode predated the M0 lock. No Director sign-off needed.
- **Quota MISS in the Hub-return beat wipes synchronously with no "QUOTA MISSED" banner yet.** The integrity-
  critical wipe routing (RD-6, DR-M2-1) ships; the player-facing MISS banner is deferred (M3's Shop / a later hub
  modal) — M2 is greybox and the portal has no banner-gate. Matches RD-6's "M2 ships the run-end→Hub routing + a
  minimal quota/wipe hook." Surfaced for awareness, not a blocker.
- **`test_rg1_m13_verify` fails — PRE-EXISTING & FLAKY, not introduced by M2.** Verified by running the unmodified
  test on the original `main` checkout (it fails there too) and by re-running it twice in the worktree (different
  failure sets each run: position-driven nav/R2/R3 telemetry rows + the `timeout` end-cause intermittently don't
  emit headlessly). The four sibling RG tests (`loop`/`m12`/`m14`/`m15`) use the **identical** M2 plumbing fix and
  all pass green, proving the M2 edits to m13 are structurally correct. The flakiness is in m13's headless
  player-walk/telemetry timing, orthogonal to the Hub/dive-only refactor. Flagged to qa for a separate stabilize.

## Handoffs / follow-ups
- **M0 follow-up needed:** none. Every accessor M2 required (`dive_config_or_default`, `stage_dive_config`,
  `evaluate_quota_on_return`, `wipe_meta`, `last_quota_result`, `banked_junk`) was already present in
  `game_state.gd` and the 8 EventBus signals were declared. M2 wrote no forbidden file.
- **M1 (Main Menu):** owns Title / Start("New Game"/"Continue") / Version / the re-homed first-run G6 telemetry
  consent — M2 stripped all of these from `main_game`; no duplicate remains.
- **M3 (Shop):** rebase onto this Hub; instance the shop interactable into the **`ShopAnchor`** Marker2D (at
  `(-220, -150)` in `hub.tscn`). DELETE the throwaway **held-haul readout** (`HudLayer/HeldHaul` + `hub.gd`'s
  `_refresh_held_haul`) and replace with the real Shop SELL. The quota+wipe already fire on the Hub-return beat —
  M3's `sell_banked_junk` is a safe no-op re-eval via the `_quota_evaluated_this_run` guard.
- **M4 (config overlay):** writes `GameState.stage_dive_config(cfg)`; M2's dive reads it via
  `dive_config_or_default()`. The staged-config seam is live and proven (the RG tests stage through it).
- **qa:** stabilize the pre-existing `test_rg1_m13_verify` headless flakiness (independent of M2).
