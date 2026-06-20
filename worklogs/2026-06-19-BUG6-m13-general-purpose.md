# Worklog — BUG6 hazard_caught debounce + config-trap guards

- **Date:** 2026-06-19
- **Subagent:** general-purpose
- **Milestone:** M1.3
- **Branch:** gp/BUG6-m13
- **Commit:** 921174e86bd106cc1bb16dc8de0269d26160de5c (build) + worklog-SHA fixup follow-up

## What changed
Two telemetry-trustworthiness correctness fixes from the M1.2 re-gate, per the LOCKED spec
(`design/M1_3_Tasks/BUG6_hazard_debounce_and_config_traps.md`, Resolved Decisions + Director Disposition FINAL):

1. **`hazard_caught` one-shot latch.** Added `_caught_latched: bool` to `HazardEntity`. `hazard_caught`
   now emits exactly once on the rising edge into catch radius and re-arms only on the falling edge (player
   leaves radius). Kills the per-frame emit storm (M1.2: 85→2,199 events/run) on both lethality paths. The
   rising-edge condition is the SAME conjunction as before (`in_range and _catch_cooldown <= 0.0`), so the
   fatal catch still fires on the identical frame → `fail_run(&"death")` timing / `duration_s` byte-identical.
   Latch reset added to `setup()`.
2. **`RunConfig.inert_enabled_oppositions() -> PackedStringArray`** — warn-only config-trap detector, the
   5-trap set: `r3_no_thresholds`, `r4_no_lost_proxy`, `r4_no_vision` (gated on `r4_vision_radius<=0.0` only,
   NOT `r4_fog_enabled` — Correction 1), `r1_no_spawn`, `r1_catch_radius_too_small` (`<24.0`, gated on
   `spawn_count>0`). Hard-coded constants, no new `@export` knob (CFG 36-knob count pinned). Returns `[]` for
   the all-off control. Appended as a self-contained method at EOF so J1 rebases its preset factory on top.
3. **Telemetry flag** — additive `run_started.data.inert_enabled_oppositions` stamped via a new
   `_active_inert_oppositions()` helper riding the existing `/root/GameState` snapshot call site. No schema
   bump, no `run_ended` arity change, no new EventBus signal.

## Files touched
- `scenes/hazards/hazard_entity.gd` — `_caught_latched` rising/falling-edge emit latch + `setup()` reset.
- `data/run_config/run_config.gd` — appended `inert_enabled_oppositions()` (append-only; J1 rebases on top).
- `systems/telemetry/telemetry.gd` — additive `inert_enabled_oppositions` field on `run_started` + helper.
- `tests/test_pursuing_hazard.gd` — Case 6 (sustained fatal overlap → exactly 1 emit) + Case 7 (non-fatal
  escape-and-re-catch → exactly 2 emits; no emit while out of radius).
- `tests/test_run_config.gd` — Case 6: `inert_enabled_oppositions()` — all-off + populated `[]`, each of the
  5 traps detected exactly, 24px floor inclusive, multi-trap union, r1_no_spawn alone on 0-spawn.
- `tests/test_telemetry_config_marking.gd` — assert the additive flag is present + an Array (flags r1_no_spawn
  for the R1-on/0-spawn config) and `[]` for the all-off control.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `test_run_config.tscn` → R0 OK (BUG6 detects all 5 traps, []-clean for all-off + populated)
- [x] `test_pursuing_hazard.tscn` → PURSUING HAZARD OK (latch cases 6+7 green)
- [x] `test_telemetry_config_marking.tscn` → TEL CONFIG MARKING OK (additive flag present + []-for-all-off)
- [x] `test_bandgen_determinism.tscn` → BANDGEN OK, fp=**e943ac9c8bc1** (all-off fingerprint UNCHANGED)
- [x] `test_level_scale_determinism.tscn` → LVL OK
- [x] `test_config_menu.tscn` → CONFIG MENU OK (36/36 knobs bound — coverage unchanged, no new @export)
- [x] definition of done met: "`hazard_caught` emits at most once per catch episode … fatal-path death frame
      (and thus duration_s) is unchanged for a given seed"; "`inert_enabled_oppositions()` returns the
      enabled-but-inert ids ([] for all-off), unit-tested per trap"; "additive
      `run_started.data.inert_enabled_oppositions`, warn-only, Start not blocked"; "no run_ended arity change,
      no schema bump, no new EventBus signal, fp e943ac9c8bc1 unchanged."

## Design deviations
None. Built exactly to the LOCKED spec + Director Disposition (warn-only; 5-trap set with the corrected
`r4_no_vision` condition; latch re-arms on leaving radius; no new knob/signal/schema bump). Ownership
respected: BUG6 owns the latch (`hazard_entity.gd`), the `inert_enabled_oppositions()` method
(`run_config.gd`, append-only), and the telemetry flag (`telemetry.gd`); did NOT touch `config_menu.gd` /
`config_strings.csv` (J1 folds the CFG warn-line), `decision_hud.gd` (J5), `main_game.gd`, or `event_bus.gd`.

## Handoffs / follow-ups
- **J1:** the `run_config.gd` edit is append-only at EOF (the preset factory + RANGE_MULT can be added without
  touching BUG6's lines). J1 folds the CFG warn-line into `config_menu.gd` driven by
  `inert_enabled_oppositions()` + adds `CFG_TRAP_*` `config_strings.csv` keys; J1's preset must consult the
  trap list so the shipped default boots trap-free.
- Do NOT merge/push — left on branch `gp/BUG6-m13` for the orchestrator to integrate.
