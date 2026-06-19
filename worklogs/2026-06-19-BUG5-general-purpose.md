# Worklog — BUG5 R2 `exposure` toll doesn't charge R3's meter (missing `add()` mutator)

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.2 (Wave 2 close-out)
- **Branch:** gp/BUG5
- **Commit:** dfe68c25d0dead9e987095167299265085a51a00

## What changed
R2's `ReturnCost._charge()` TOLL_EXPOSURE branch already calls `meter.call(&"add", cost)`
guarded by `has_method(&"add")`, but `ExposureMeter` exposed only read-only getters — so the
guard was false and the exposure toll was a silent no-op on R3's meter (cue + telemetry fired,
meter never moved). Added a public `func add(amount: float)` to `exposure_meter.gd` that injects
the toll into the same run-state meter the time-accrual path drives. Refactored so both
`_process()` accrual and `add()` funnel the meter mutation + crossing-detection + forced-loss
through ONE new shared helper `_mutate_meter(value)` (clamps to `[0, METER_MAX]`, fires the same
edge-triggered one-shot `exposure_crossed`/`exposure_penalty`, honors `r3_max_forces_loss`, emits
`exposure_meter_changed`) — no second divergent crossing path. `add()` defensively no-ops when
R3 is inactive. Run-state only; no meta write, no new signal/knob/telemetry, no `run_ended` arity
change. `return_cost.gd`, `event_bus.gd`, `game_state.gd` untouched.

## Files touched
- `systems/oppositions/exposure_meter.gd` — new public `add(amount)` mutator + extracted shared
  `_mutate_meter(value)` helper; `_process()` now computes the new meter value and delegates the
  clamp/cross/loss/emit to `_mutate_meter`.
- `tests/test_exposure_meter.gd` — Case 6 (`add()` raises meter by amount, emits
  `exposure_meter_changed`, crossing a threshold fires `exposure_crossed`/`exposure_penalty` +
  speed mult, clamps at both `METER_MAX` and 0), Case 7 (`add()` inert with R3 disabled), Case 8
  integration (`_check_r2_integration`: a real `ReturnCost` + grouped `ExposureMeter`, taxed
  retreat moves R3's meter by the toll amount end-to-end = 6.5).

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `tests/test_exposure_meter.tscn` → EXPOSURE METER OK (incl. BUG5 add() cases + R2 integration) + EXPOSURE HUD OK
- [x] `tests/test_return_cost.tscn` → RETURN COST OK (R2 unchanged)
- [x] `tests/test_bandgen_determinism.tscn` → BANDGEN OK (fp=e943ac9c8bc1, unchanged) + BUG3/R4/BUG4 seals OK
- [x] `tests/test_level_scale_determinism.tscn` → LVL OK (fp=d7c249c3584b, unchanged)
- [x] `tests/test_decision_hud.gd` (via --script) → DECISION HUD OK
- [x] Definition of done met: "R2 on + r2_toll_resource=exposure + R3 on → a retreat toll raises
  R3's meter by the toll amount and fires the matching crossing/penalty (I3's bar/banner respond);
  R3/R2 off → add() never runs, all-off = M1.0 baseline; regression test green; smoke + determinism
  + HUD suites green." Verified via Case 8 (meter → 6.5) and Case 7 (R3 off → no-op).

## Design deviations
none. The fix is entirely on the R3 side as the spec dictates; `return_cost.gd` was already
correct and is untouched. Determinism fingerprints unchanged.

## Handoffs / follow-ups
none. The "resources still in use at exit" lines from the determinism scenes are pre-existing
engine-shutdown cleanup warnings (present before this change), not test failures — both print OK.
