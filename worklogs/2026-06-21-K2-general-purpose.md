# Worklog — K2 Quota system + roguelite wipe

- **Date:** 2026-06-21
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.4 (Wave 2)
- **Branch:** general-purpose/K2-quota
- **Commit:** HEAD of branch `general-purpose/K2-quota` (single squashed commit "K2: quota system + roguelite wipe (M1.4 Wave 2)"; this worklog is part of that commit)   ← required

## What changed
Implemented the M1.4 headline-stakes feature: a per-run quota whose miss is a full
roguelite wipe. The live quota (`quota_target` + `run_number`) is META-STATE that
persists, escalates on a met quota, and resets on a wipe; the per-run "did this run
meet it?" evaluation is run-state. The quota is evaluated in `sell_banked_junk()`
AFTER the credit + save (so `money` is final), honors the K0 `quota_check_timing`
(on_extract / every_run_end) and `quota_basis` (this_run_banked / cumulative_money)
knobs, is idempotent per run, and is fully inert when `quota_enabled=false` (the
all-off control is byte-identical to M1.3). The default play-preset ships the
Director-FINAL fun stack (on, $50 base, +$50/run, every_run_end × cumulative_money).
Save schema bumped v2→v3 with a migration step + a committed v2 fixture. HUD shows a
gated quota readout; the SellScreen renders the met/miss outcome (title override +
pending-wipe flag); MainGame routes Continue through `wipe_meta()` on a miss.

## Files touched
- `systems/game_state.gd` — meta `run_number`/`quota_target`; run-state quota snapshots +
  `_quota_evaluated_this_run` idempotency flag + cached result; snapshot/lazy-init/eager-save
  (guarded) in `start_run`; end-reason capture in `end_run`; `_evaluate_quota(sold_total)`
  call in `sell_banked_junk`; `last_quota_result()`; `wipe_meta()`; extended meta bridge.
- `systems/save_manager.gd` — `META_SCHEMA_VERSION` 2→3; v2→v3 migration case (run_number=1,
  quota_target=0 defaults).
- `data/run_config/run_config.gd` — preset fun-stack quota values (enabled/base 50/step 50/
  every_run_end/cumulative_money). No new RunConfig fields (K0 pre-declared the 5 knobs).
- `ui/sell/sell_screen.gd` + `.tscn` — `QuotaLine` label; `_render_quota()` (met line / miss
  title override + `_pending_wipe`); `pending_wipe()` getter.
- `scenes/game/main_game.gd` — `continue_pressed` → `_on_continue_pressed()` which calls
  `GameState.wipe_meta()` when `pending_wipe()` before `start_new_run()`.
- `ui/hud/decision_hud.gd` + `.tscn` — gated `QuotaLabel` readout ("Run N · Quota: $have/$need");
  subscribes to `quota_advanced`/`meta_wiped`/`run_started`.
- `ui/hud/hud_strings.csv` — `HUD_QUOTA`.
- `ui/sell/sell_strings.csv` — `SELL_QUOTA_MET`, `SELL_QUOTA_MISS`, `SELL_TITLE_QUOTA_FAIL`.
- `systems/telemetry/telemetry.gd` — Q8: stamp live `quota_run_number`/`quota_target` onto the
  `run_started` row (additive `data` keys; no schema bump; `_active_quota_meta()` helper).
- `tests/fixtures/gen_meta_v2_fixture.gd` + `tests/fixtures/meta_v2.sav` — committed binary v2 fixture.
- `tests/test_save_migration.gd` — v2→v3 case + v1-now-lands-at-v3 quota-default asserts.
- `tests/test_quota_system.gd` + `.tscn` — headless behavior regression for the quota/wipe logic.

## Checks run
- [x] `godot --headless --import` clean (no parse/compile errors).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy` (exit 0).
- [x] Determinism gate: `test_bandgen_determinism` → `BANDGEN OK ... fp=e943ac9c8bc1` (neutral fingerprint UNMOVED).
      `test_rg1_m13_verify` → `RG1 M1.3 VERIFY OK ... All-off control is byte-identical to the locked baseline (fp=e943ac9c8bc1)`.
- [x] `test_save_migration` → BOTH cases OK: v1→v3 and v2→v3 land at schema 3 with run_number=1/quota_target=0, prior fields intact, round-trip + .bak.
- [x] `test_run_config` → R0 OK (81 knobs; no count change — K2 added zero RunConfig fields). `test_config_menu` → 81/81 OK.
- [x] `test_quota_system` → QUOTA OK: met advances+persists, miss defers to `wipe_meta` (9-field reset + `meta_wiped`), eval idempotent, on_extract skips non-extract, this_run_banked reads sold_total, quota-off fully inert.
- [x] Regression: `test_main_game_loop`, `test_loop_drive`, `test_telemetry_config_marking`, `test_telemetry_jsonl`, `test_camera_view`, `test_corridor_summary_row`, `test_duration_loop_reentry`, `test_within_band_depth` all OK.
- [x] Definition of done met: quota persists/escalates on met; miss at Continue wipes all 9 meta fields and re-seeds the next run at run 1 / $50; eval fires exactly once per run; all-off reproduces M1.3 byte-for-byte; `run_ended` arity unchanged.

## Design deviations
None of substance. Notes on as-built reconciliation:
- The K2 doc section (a)/(b) proposed `quota_check_timing`/`quota_basis` as Open Questions
  to be hard-coded; the Phase-3 + K0 as-built shipped them as RunConfig knobs (the doc's
  Resolved Decisions adopt this). Implemented the knobs as the live branch — preset ships
  every_run_end × cumulative_money, but the code honors on_extract / this_run_banked.
- The K2 doc's `meta_wiped` arity (`prev_run_number: int`) matches the as-built K0 signal.
  All three K2 signals were already present in `event_bus.gd` with the Phase-3-reconciled
  names — only EMITted them, did not re-declare.
- Q8 (`run_started` quota stamp) implemented as it was a trivial additive one-liner in the
  existing telemetry seam (kept the lock's recommendation).

## Handoffs / follow-ups
- The two stakes "feel" knobs (`quota_check_timing`, `quota_basis`) ship at the Director-locked
  preset values but remain swept — RG2's wipe-rate distribution can re-tune them in M1.5 with
  no code change.
- ui-ux polish (GameOver framing copy / red title styling) is greybox; a human owns the visual pass.
