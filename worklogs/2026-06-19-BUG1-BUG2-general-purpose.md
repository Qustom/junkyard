# Worklog — BUG1 + BUG2 (combined game_state.gd pass)

- **Tasks:** BUG1 (real `run_ended.duration_s`) + BUG2 (live within-band depth)
- **Date:** 2026-06-19
- **Subagent:** general-purpose (the programmer)
- **Milestone:** M1.1 — Greybox Cost Axis (Wave 1)
- **Branch:** general-purpose/bug1-bug2-game-state
- **Commit:** 963154c2a0f3dff73d397f01ce46afe76b9f4d8b

Combined into one `game_state.gd` pass on a shared branch per BUG1 §8 Decision 4
(small, file-adjacent, logically orthogonal; open `game_state.gd` once post-R0).
One shared worklog, one commit, both task ids.

## What changed

**BUG1 — `run_ended.duration_s` was a hardcoded `0.0` on every end path.**
`GameState` now stamps `_run_start_ms = Time.get_ticks_msec()` at `start_run`
(monotonic wall-ish clock, Decision 1) and a single `_elapsed_s()` helper computes
raw float seconds (no rounding at source, Decision 2). The two hardcoded `0.0`
literals in `extract_and_end_run` and `fail_run` (the latter serves both death and
timeout) now call `_elapsed_s()`. `end_run` stays a pure relay. The existing
`_run_ended` guard makes the compute idempotent for free (it early-returns above the
duration line), so a same-frame losing end-cause never recomputes/re-emits.

**BUG2 — within-band depth was stuck at 1 (band-entry counter, not spatial depth).**
Added three run-state members to `GameState` (`current_depth_index`,
`max_depth_reached`, `current_dist_to_gate`), all reset to 0 in `start_run`. New
`set_current_depth(idx, dist_home)` mutator always refreshes `current_dist_to_gate`,
edge-triggers on `depth_index` (no emit on same-depth ticks), ratchets
`max_depth_reached` via `maxi`, and emits the pre-declared `EventBus.depth_changed`.
`end_run` now emits `max_depth_reached` (was `current_depth`) as the 3rd arg — fixing
extract/death/timeout at once with no arity change. `current_depth` (the band-entry
counter / HUD source) is left untouched; BUG2 adds separate members.

`MainGame` is the scene-side driver: it flattens the graded band's depth model into a
per-cell `{Vector2i cell -> Vector2i(depth_index, dist_to_gate)}` dict right after
`grader.compute_return_distance()` and before the throwaway `band` local is discarded
(Decision 4 carries both metrics). A throttled `_physics_process`
(`@export depth_tick_interval := 0.15`, Decision 2) resolves the player's band-global
cell (player via the `"player"` group) → owning piece → depth and calls
`GameState.set_current_depth()`. It resolves once immediately at run start so frame-0
depth is correct. If the cell maps to no floor cell (wall edge / mid-doorway), it
keeps the last depth — never snaps to 0 (Decision 6).

## Files touched
- `systems/game_state.gd` — BUG1: `_run_start_ms` member + stamp in `start_run` +
  `_elapsed_s()` helper + two `0.0`→`_elapsed_s()` swaps. BUG2: three run-state depth
  members + reset in `start_run` + `set_current_depth()` mutator + `end_run` 3rd arg
  now `max_depth_reached`.
- `scenes/game/main_game.gd` — BUG2 driver: `_cell_to_depth` map + `_build_cell_depth_map()`
  + throttled `_physics_process` + `_resolve_player_depth()` + an immediate resolve and
  accum reset after `start_run`; `@export depth_tick_interval`.
- `tests/test_run_duration.gd` + `.tscn` — BUG1 headless-scene test (extract/death/timeout).
- `tests/test_within_band_depth.gd` + `.tscn` — BUG2 headless-scene test.

**Not touched (per spec constraints):** `systems/event_bus.gd` (`depth_changed` was
pre-declared by the orchestrator, commit `2450cde` — BUG2 only emits it), 
`systems/telemetry/telemetry.gd` (TEL owns it), the HUD (E2 migrates `current_depth`
later), `placed_piece.gd` / `band.gd` (read-only), the save schema (no change).

## Checks run
- [x] `godot --headless --import` → exit 0, no parse errors
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK`, exit 0
- [x] `godot --headless res://tests/test_run_duration.tscn` → `RUN DURATION OK`, exit 0
- [x] `godot --headless res://tests/test_within_band_depth.tscn` → `WITHIN BAND DEPTH OK`, exit 0
- [x] `bash tools/run_gdunit.sh` → 30/30 test cases PASSED, exit 0 (pre-existing
      ObjectDB-leaked-at-exit warning from GdUnit teardown is unrelated to this change)
- [x] Definition of done: BUG1 — `run_ended.duration_s` is real (>0) and within a frame
      of a direct `Time.get_ticks_msec()` reference (telemetry not forced on) for all
      three end-causes. BUG2 — `current_depth_index`/`max_depth_reached` track,
      `depth_changed` is edge-triggered (no same-piece spam), max ratchets on retreat,
      and `run_ended.depth_reached == max` for all three end-causes.

## Design deviations
none.

Note: `depth_changed` was pre-declared on `main` by the orchestrator (commit `2450cde`);
this pass only EMITS it from `GameState.set_current_depth()` and never edits
`event_bus.gd`, exactly as ratified in BUG2 §3 / §8 Decision 3.

No existing test asserted the old stuck values (`tests/test_decision_hud.gd` reads the
untouched `current_depth` band-entry counter; `tests/test_dive_clock.gd` passes a fixed
depth into a hand-built `run_ended.emit`, independent of GameState). Full suite stays
30/30.

## Handoffs / follow-ups
- TEL: add a `DEPTH_CHANGED` JSONL row from `depth_changed` and migrate
  `telemetry.gd::_current_depth()` to read `current_depth_index` (ratified Decision 5).
- ui-ux-designer (E2): migrate the HUD "Depth N" readout to `current_depth_index`
  (ratified Decision 5).
- R1–R4: read `GameState.current_depth_index` (pull) / `current_dist_to_gate`, or
  connect `EventBus.depth_changed` (push) — the BUG2→opposition read surface (BUG2 §4).
