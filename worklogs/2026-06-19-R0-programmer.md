# Worklog — R0 Run-config data model

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.1
- **Branch:** programmer/R0
- **Commit:** f7ae8f99df783da8279a8d9797acd61bc9f61ece

## What changed
Added the `RunConfig` Resource (`data/run_config/run_config.gd` + all-off default
`run_config.tres`), the M1.1 cost-axis config *container* holding every R1–R4
opposition's knobs (typed, one `@export_group` per opposition, each fronted by an
`enabled` master toggle, default OFF) plus a small Meta block (`seed_override` = -1,
`build_tag`). Wired `GameState` to hold the active config as run-state
(`active_run_config`), staged via a new `stage_run_config()` seam and consumed at
`start_run`; it defaults to the all-off config when nothing is staged, so any existing
no-config run reproduces the M1.0 baseline exactly. It is cleared on run end (run-state
boundary). `MainGame` stages the default config before `start_run` to exercise the
wiring. `RunConfig.to_flat_dict()` serializes every knob to a flat JSON-safe dict for
TEL to snapshot onto `run_started` later. R0 implements the container + wiring + all-off
default only — no opposition behaviour, no EventBus signals, no save-schema change.

## Files touched
- `data/run_config/run_config.gd` — new `class_name RunConfig` Resource: all R1–R4 knobs, `all_oppositions_disabled()`, `to_flat_dict()`.
- `data/run_config/run_config.tres` — new all-off default config (script defaults = M1.0 baseline control).
- `systems/game_state.gd` — run-state `active_run_config` + `_staged_run_config`; `DEFAULT_RUN_CONFIG_PATH`; `stage_run_config()`; `_default_run_config()`; bind in `start_run`, clear in `end_run`. (Expected `[GS]` touch for R0.)
- `scenes/game/main_game.gd` — `RUN_CONFIG_PATH`; stage the all-off default before `GameState.start_run` (backward-compatible seam for CFG).
- `tests/test_run_config.gd` + `tests/test_run_config.tscn` — headless scene test for the R0 acceptance criteria.

## Checks run
- [x] `godot --headless --import` clean (no parse errors; only pre-existing `*.en.translation` warnings)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy`
- [x] `bash tools/run_gdunit.sh` → GdUnit4 run PASSED (existing suites green — unchanged by R0)
- [x] `godot --headless res://tests/test_main_game_loop.tscn` → `MAIN GAME OK`
- [x] `godot --headless res://tests/test_loop_drive.tscn` → `LOOP OK`
- [x] `godot --headless res://tests/test_run_config.tscn` → `R0 OK — ... all 32 knobs.`
- [x] definition of done met: "a `RunConfig.tres` loads; `GameState.active_run_config` is populated at run start; with the all-off default the loop behaves identically to M1.0 (no opposition active); the config serializes to a flat dict for telemetry."

## Design deviations
- **Touched `game_state.gd`** — expected and flagged in the breakdown (R0 is `[GS]`). Added run-state `active_run_config`/`_staged_run_config`, a `stage_run_config()` seam, and a `_default_run_config()` loader; bound in `start_run`, cleared in `end_run`. The locked `start_run(band_id, seed)` / `run_ended` signatures are unchanged — the config rides the staging seam rather than a new `start_run` arg, so all existing callers and tests work untouched.
- Used `@export_group(..., "r<n>_")` prefixed groups (the breakdown offered nested-vs-prefix as the implementer's call). Kept the explicit `r<n>_` field-name prefix so flat-dict keys and external reads are unambiguous.
- `r2_mechanism` / `r2_toll_resource` / `r3_penalty_kind` use `@export_enum(...)` ints (enum placeholders per the brief) — the R2/R3 specs assign final meaning; R0 only fixes the field + index meaning noted in comments.
- No save-schema change (RunConfig is run-scoped config, not meta) — as required.

## Handoffs / follow-ups
- **CFG** writes the menu-built `RunConfig` and hands it to the run via `GameState.stage_run_config(cfg)` before Start (replacing MainGame's current "stage the all-off default" line).
- **TEL** snapshots `GameState.active_run_config.to_flat_dict()` onto the `run_started` row's `data` (additive payload, no schema bump).
- **R1–R4** read `GameState.active_run_config` (read-only) for their knobs; never mutate it.
