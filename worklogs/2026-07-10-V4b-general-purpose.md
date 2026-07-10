# Worklog — V4b Address quota-delegate deviation

- **Date:** 2026-07-10
- **Subagent:** general-purpose
- **Milestone:** M1.12 (Wave-3 close-out ADDRESSING task)
- **Branch:** feat/V4b-quota-delegate-addressed
- **Commit:** <FILLED BELOW AFTER COMMIT>

## What changed
The Director dispositioned the M1.12 V4 deviation (private `GameState._evaluate_quota(sold_total)`
facade delegate, kept so `test_quota_system`'s 6 white-box call sites needed zero edits) as
**Addressed**, not Reviewed. This task removes that delegate and rewrites the test onto a proper
public seam.

Chose seam (a) from the task's three options: **a clean public accessor to the owned `QuotaLadder`
instance**, rather than (b) a test-constructed standalone ladder (would decouple from the real
`_economy`/`_quota` state the other assertions in the same run depend on) or (c) routing through
`sell_banked_junk`/`evaluate_quota_on_return` (both couple `sold_total` to actual sold `JunkItem`
inventory, which would force fabricating catalog items to hit each case's arbitrary sold_total —
much larger surface for no gain in intent-fidelity). Added two one-line accessors to `GameState`,
consistent with its existing facade-delegate convention:
- `quota_ladder() -> QuotaLadder` — returns the owned `_quota` instance (the same object
  `start_run()`/`end_run()` already coordinate via `begin_run`/`set_end_reason`).
- `held_haul_value() -> int` — forwards `_economy.held_haul_value()`, the second input
  `_evaluate_quota` used to compute internally.

Rewrote all 6 `test_quota_system.gd` call sites from `gs._evaluate_quota(sold_total)` to
`gs.quota_ladder().evaluate(gs.money, sold_total, gs.held_haul_value())` — the exact same three
arguments the removed private delegate passed to `QuotaLadder.evaluate`, so behavior and every
assertion are byte-for-byte preserved. Then deleted the private `_evaluate_quota` delegate from
`game_state.gd`. Updated the test file's header docstring to describe the new seam. No assertion
was weakened, added, or removed.

## Files touched
- `Game/systems/game_state.gd` — removed the private `_evaluate_quota(sold_total)` delegate;
  added public `quota_ladder()` accessor (returns `_quota`) and public `held_haul_value()`
  delegate (forwards `_economy.held_haul_value()`).
- `Game/tests/test_quota_system.gd` — rewrote 6 call sites (lines that were `gs._evaluate_quota(N)`)
  to `gs.quota_ladder().evaluate(gs.money, N, gs.held_haul_value())`; updated header docstring.

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game res://tests/test_quota_system.tscn` → **QUOTA OK** (all 7 cases:
  met advances+persists, miss defers to wipe_meta, idempotent, on_extract gating, this_run_banked
  basis, quota-off inert, M1.6 Hub-return held-haul basis)
- [x] `godot --headless --path Game res://tests/test_save_migration.tscn` → v1/v2/v3→v4 all
  **SAVE MIGRATION OK** (meta stays v4, unaffected)
- [x] `godot --headless --path Game res://tests/test_shop_economy.tscn` → **SHOP ECONOMY OK**
- [x] `godot --headless --path Game --script res://tests/test_money_ledger.gd` → **MONEY LEDGER OK**
- [x] `godot --headless --path Game res://tests/test_band_pipeline_parity.tscn` → **PIPELINE PARITY
  OK**, `fp=e943ac9c8bc1` (exit 0; the test's own deliberate fail-loud negative-path push_errors in
  the log are expected assertions in that test, not failures) — confirms quota isn't on the layout path
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK**
- [x] Definition of done met: `test_quota_system` exercises quota logic through the proper
  `QuotaLadder.evaluate(...)` public path (via `quota_ladder()`/`held_haul_value()` accessors);
  private `_evaluate_quota` delegate is gone; no other test file touched; meta save (v4) and the
  four control layout fingerprints are unaffected.

## Design deviations
None — this task itself *is* the Addressed resolution of the M1.12 V4 deviation
(`design/DESIGN_DEVIATIONS.md`, "M1.12 V4/private-quota-delegate"). No new deviation introduced:
the two added accessors are read-only one-line delegates following the exact convention already
used throughout `game_state.gd` (`add_currency`, `add_exposure`, `purchase`, `owns`,
`last_quota_result`, etc.), and the test's assertions and intent (verifying quota ladder
advance/persist/target/idempotency/timing/basis logic) are unchanged.

## Handoffs / follow-ups
- The orchestrator should move the "M1.12 V4/private-quota-delegate" entry from
  `design/DESIGN_DEVIATIONS.md` to `design/DESIGN_DEVIATIONS_HISTORY.md`, tagged **Addressed**
  (2026-07-10), referencing this task's commit as where it was reapplied (the delegate removed,
  the test rewritten onto `QuotaLadder.evaluate` via the new public accessors). `GameState`'s
  class-header comment (lines ~9-19, "M1.12 V4: ...") may also want a one-line note that the
  private white-box delegate was removed in V4b — left as-is here since the header already
  describes the facade/forwarding pattern generically and doesn't name `_evaluate_quota`
  specifically.
- Not pushed (per task instructions).
