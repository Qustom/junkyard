# Worklog — TUNE3: enable exits in the play preset

- **Task:** Director pre-playtest preset tweak — turn K7 exits ON with specified values.
- **Milestone:** M1.4 (pre-re-gate-playtest tuning).
- **Assignee:** Claude (orchestrator, direct preset tweak).

## What changed
- `data/run_config/run_config.gd` `make_default_play_preset()` — exits now ON (supersedes the
  Phase-3 "ship exits OFF" lock): `exit_enabled=true`, `exit_base_count=1`,
  `exit_count_per_depth=0.1`, `exit_keep_one_at_spawn=true`, `exit_max_count=7`.
- `tests/test_rg1_m14_verify.gd` — preset-shape assert now requires exits ON at those values;
  CFG-boot check expects `exit_enabled`; doc/print/deferred strings updated.

## Why fingerprint is unmoved
Exits are pure run-state placed via a LOCAL RNG (`run_seed ^ EXITS_RNG_SALT`), never the global
RNG, and only in the named preset — the all-off control (`RunConfig.new()`) is untouched.

## Commit
- merged in `1ad35bc` (branch `tune/exits-on-preset`).

## Tests / checks run
- `--import` clean; `ci_smoke_test` SMOKE OK.
- `test_rg1_m14_verify` VERIFY OK — all-off fp byte-identical **e943ac9c8bc1**; preset = fun stack w/ exits ON.
- `test_run_config` R0 OK; `test_config_menu` 81/81 OK; `test_exit_placement` K7 OK.

## Design deviations
Supersedes the Phase-3 "exits OFF for a clean re-gate" lock per explicit Director request — note for
the Wave-5 close-out deviation sweep (recommend Reviewed: a Director-directed playtest config change).
