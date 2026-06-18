# Worklog — F1 Single Placeholder Currency: Money Ledger

- **Date:** 2026-06-17
- **Subagent:** programmer (general-purpose)
- **Milestone:** M1
- **Branch:** programmer/F1
- **Commit:** 54f4f5979758e8845b5b4ecc280d215ee0bc9a6b

## What changed
Added `GameState.sell_banked_junk(source := &"sell") -> Array[Dictionary]` — the
one new piece F1 actually needed. It converts the whole `banked_junk` pile to
Money at each item's `base_sell_value`, builds a per-item `{id, name, value}`
breakdown for F2 to itemize, clears the bank, credits the total via the existing
canonical ledger mutation `add_currency(&"money", total, source)` (one
`currency_changed` event for the lot), and persists meta (`save_meta(0)`). The
`money` field, its v2 persistence, and the migration chain already existed
(E1/G5), so F1 shipped much smaller than its spec implied — see deviations.

Added headless test `tests/test_money_ledger.gd` (script-style, matching
`test_extract_bank.gd` / `test_death_drop.gd`).

## Files touched
- `systems/game_state.gd` — added `sell_banked_junk()` in the Ledger section; no
  other change (money/serialize/migrate were already done).
- `tests/test_money_ledger.gd` — new headless verification, prints `MONEY LEDGER OK`.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy`
- [x] `godot --headless --script res://tests/test_money_ledger.gd` → `MONEY LEDGER OK`
- [x] regression: `test_extract_bank.gd` → `EXTRACT OK`; `test_death_drop.gd` → `DEATH DROP OK`
- [x] definition of done met: "sell_banked_junk() converts all banked_junk → Money
  at base_sell_value, empties the bank, persists meta, emits one
  currency_changed(&"money", total, source), and returns an itemized breakdown."
  Test asserts: exact-sum credit (30+20+10=60); bank empty after; breakdown
  itemizes each {id,name,value}; empty-bag sale is a no-op returning [] with a
  delta-0 (non-negative) event; source tag (&"sell" default, &"pockets") flows to
  currency_changed; Money round-trips through save_meta(0)/load_meta(0).

## Design deviations
F1's written spec assumed work that the as-built codebase already does, so this is
a **reconciliation, not a design change** (flag for the wave-4 close-out):
- Spec said to **bump the meta schema** and add a `money` migration step. Reality:
  `META_SCHEMA_VERSION` is already 2, `money` is already in `to_meta_dict`/
  `from_meta_dict`, and `_migrate_meta` already chains v0→v1→v2. No schema change made.
- Spec proposed a new `credit_money(amount, source)` + `EventBus.money_changed`
  signal. Reality: the canonical ledger mutation is `add_currency(&"money", delta,
  source)`, which already emits `currency_changed(kind, delta, source)` (Telemetry's
  currency-in hook). `sell_banked_junk` reuses that instead of adding a parallel
  signal/method. `event_bus.gd` and `save_manager.gd` were NOT touched.
- Conversion timing is **Option B (sell-at-F2)**, matching the existing E1 "bank
  items not Money" decision — `extract_and_end_run()`/`fail_run()` still bank item
  identities only; Money increments solely in `sell_banked_junk()`. On-spec
  (recommended option), noted for completeness.

No Director sign-off needed beyond noting these reconciliations at close-out.

## Handoffs / follow-ups
- F2 consumes `sell_banked_junk()`: drive its per-item count-up animation purely
  from the returned breakdown array; pass `&"pockets"` when selling a failed-run
  haul and `&"sell"`/`&"extract"` for a clean extract, for Telemetry's
  currency-in-by-source analysis.
