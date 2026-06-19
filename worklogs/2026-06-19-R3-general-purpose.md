# Worklog — R3 Rising Instability / Exposure Meter (meter + greybox HUD readout)

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer; also owns the greybox HUD readout this wave)
- **Milestone:** M1.1 (Wave 2 — the four oppositions)
- **Branch:** general-purpose/R3
- **Commit:** d6f4d1aff0bfa466cab10b6319a0a1b63dfc98c6

## What changed
Built the R3 ExposureMeter: a run-state Node (NOT autoload) that climbs a 0–100 meter
faster the deeper/longer the player lingers (`base + per_depth*depth`), decays on retreat
(stateless `live_depth < max_depth`), fires edge-triggered one-shot threshold crossings
(no re-arm), applies the configured penalty kind by EMITTING the TEL-pre-declared signals
(speed/vision/clock), and calls the existing `GameState.fail_run(&"timeout")` when
`r3_max_forces_loss` and the meter caps. Wired the three penalty consumers I own: the
Player multiplies its `max_speed` by the cached exposure speed mult in `step_velocity`;
the A3 DiveClock subtracts the clock tax via its existing `modify_light(-seconds)`. Added
the greybox `ExposureReadout` HUD bar (pure projection, mirrors `decision_hud.gd`) as a
child of the E2 `decision_hud.tscn`, visible only when `r3_enabled`. All-off (`r3_enabled
= false`) is fully inert → HUD bar hidden, M1.0 behavior preserved.

## Files touched
- `systems/oppositions/exposure_meter.gd` — NEW. The `ExposureMeter` run-state node: climb/
  decay, edge-triggered one-shot crossings, penalty emit, max→`fail_run` call, HUD emit.
- `entities/player/player.gd` — speed-penalty seam: subscribe `exposure_speed_mult_changed`,
  cache it (default 1.0), multiply `stats.max_speed` by it in `step_velocity`. Minimal.
- `systems/dive_clock.gd` — clock-tax consumer: subscribe `exposure_clock_tax`, subtract via
  existing `modify_light(-seconds)`. Minimal.
- `ui/hud/exposure_readout.gd` — NEW. Greybox `Control`, pure projection of
  `exposure_meter_changed`; visible only when `r3_enabled`; re-evaluates on run boundaries.
- `ui/hud/decision_hud.tscn` — mounted `ExposureReadout` (Control + ExposureBar + ExposureLabel)
  under `Root`, below the Holding label. (Lower-risk mount than a standalone fragment — see note.)
- `ui/hud/hud_strings.csv` — added `HUD_EXPOSURE_FMT,Exposure: {value} / {max}`.
- `tests/test_exposure_meter.{gd,tscn}` — NEW headless scene test (6 cases + HUD projection).

## Checks run
- [x] `godot --headless --import` clean (exit 0, all scripts compiled, translation rebuilt)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `godot --headless res://tests/test_exposure_meter.tscn` → EXPOSURE METER OK + EXPOSURE HUD OK
- [x] `godot --headless --script res://tests/test_decision_hud.gd` → DECISION HUD OK (E2 not broken by my player/HUD edits)
- [x] `godot --headless res://tests/test_main_game_loop.tscn` → MAIN GAME OK
- [x] `bash tools/run_gdunit.sh` → GdUnit4 PASSED (30/30, 0 failures)
- [x] definition of done met: meter climbs faster at depth, decays on retreat, edge-triggered
      one-shot crossings emit `exposure_crossed`+`exposure_penalty`, `r3_max_forces_loss` →
      `fail_run(&"timeout")`, speed mult emitted, all-off inert; HUD bar hidden with R3 off.

## Design deviations
**none** (mechanically on-spec, all §9 D1–D7 honored). Two as-built name corrections vs. the
spec's pre-BUG2/pre-TEL text (already flagged in the brief, not deviations from the ratified
contract):
- Live depth read from `EventBus.depth_changed(depth_index, max_depth)` / `GameState`'s
  `current_depth_index` + `max_depth_reached` (spec §6 pseudocode said `current_depth`).
- `exposure_penalty`'s 2nd arg is a **StringName** (`penalty_kind`) per the as-built
  `event_bus.gd` declaration, not the enum int the spec §5/§6 implied. The meter emits the
  kind NAME (`&"speed"`/`&"vision"`/`&"clock"`/`&"none"`) via `_penalty_kind_name()` to match
  the declared signature exactly.

Confirmed: **did NOT edit** `systems/event_bus.gd` or `systems/game_state.gd` (the meter only
EMITS the six pre-declared signals and CALLS the existing public `fail_run`). Did not touch
`main_game.gd` or other oppositions' files.

## Handoffs / follow-ups
- **RG1/G3 wires the `ExposureMeter` node into the dive scene** — this task built + unit-tested
  it standalone and did NOT add it to `main_game.gd` (per §8). RG1 should instantiate one
  `ExposureMeter` as a child of the dive/run-systems node (alongside the DiveClock).
- **HUD mount choice:** mounted the readout INSIDE `decision_hud.tscn` (under `Root`) rather than
  as a separate fragment RG1 must add — lowest-risk: the E2 HUD already loads in the dive scene,
  so the bar comes along for free and stays hidden until `r3_enabled`. RG1 needs no extra HUD wiring.
- **Vision penalty (`r3_penalty_kind = vision`)** emits `exposure_vision_mult_changed` but is an
  on-screen no-op until R4's fog consumes it (§9 D4) — telemetry still logs the crossing/penalty.
