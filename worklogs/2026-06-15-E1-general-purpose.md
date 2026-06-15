# Worklog — E1 Gate node + extract-and-bank

- **Date:** 2026-06-15
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1
- **Branch:** general-purpose/E1-gate-extract
- **Commit:** 7da1a6546dc895f417baec1edc64ccd579eab4f4

## What changed
Built the M1 extraction gate and the run-state → meta-state bank path. A greybox
green doorway (`entities/gate/`) registers an A2 `Interactable` (id `&"gate"`,
prompt "Extract") and, on the player's interact, hands off to a new
`GameState.extract_and_end_run()` that banks the carried `JunkItem` *identities*
into a new meta-state `banked_junk: Array[JunkItem]` (decision #6 — no Money
conversion here), emits `haul_banked(value)`, persists meta, then ends the run
through the existing `end_run(&"extract", ...)` lifecycle (emits `run_ended`).
Per orchestrator direction this reuses `run_ended` + `haul_banked` rather than a
new `run_end(cause, payload)` signal. Zero-haul extract is allowed (decision #7).
The gate has a 200–300 ms fat-finger input lockout (decision #5, default 0.25 s).

## Files touched
- `systems/game_state.gd` — added meta-state `banked_junk`; `extract_and_end_run()`;
  `GATE_SPAWN_OFFSET` + `JUNK_CATALOG_PATH` consts; wired `banked_junk` into
  `to_meta_dict`/`from_meta_dict` (persist ids, rehydrate via catalog), plus
  `_rehydrate_banked_junk` / `_build_catalog_index` helpers.
- `systems/save_manager.gd` — bumped `META_SCHEMA_VERSION` 1 → 2; added a v1→v2
  migration step defaulting `banked_junk` to `[]` for old saves.
- `entities/gate/extract_gate.gd` + `.tscn` — `ExtractGate` (Area2D, no movement
  collision) with green 48×64 ColorRect doorway, `PlayerSnapPoint` marker, and an
  `Interactable` child on the interactable layer (bit 3 / collision_layer 4).
- `entities/gate/gate_test.gd` + `.tscn` — manual demo: player + gate at the fixed
  offset, starts a run, seeds 2 catalog junk, prints bank/run-end feedback.
- `tests/test_extract_bank.gd` — headless E1 verification (haul + zero-haul + save
  round-trip).

## Checks run
- [x] `godot --headless --import` clean (no parse errors; `ExtractGate` registers)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK` (re-run after schema bump)
- [x] `godot --headless --script res://tests/test_extract_bank.gd` → `EXTRACT OK` (exit 0)
- [x] `godot --headless --script res://tests/test_run_inventory.gd` → `INV OK` (schema bump didn't regress D1)
- [x] `gate_test.tscn` instantiates headlessly (run starts, inventory seeds, no errors)
- [x] Definition of done: "Using the gate ends the run and transfers carried junk
      to the banked / meta total; an EventBus extract run-end event fires." — met:
      extract moves items into `banked_junk`, wipes `run_inventory`, fires
      `haul_banked(value)` + `run_ended(&"extract", ...)`.

## Design deviations
- **Reused `run_ended` + `haul_banked` instead of a new `run_end(cause, payload)`
  signal.** The E1 spec's "Code to generate" shows `EventBus.run_end.emit(&"extract", {...})`;
  the orchestrator directed reusing the existing lifecycle so A3's clock and
  Telemetry react to one `run_ended` and there is no parallel run-end path.
  Already ratified in `M1_Design_Decisions.md` (#6 consequences) — no new sign-off.
- **`banked_junk` persists as junk ids (String), rehydrated via the catalog.** The
  save model is objects-OFF (`store_var(..., false)`), so banking Resource refs is
  not viable. `to_meta_dict` writes `String(item.id)`; `from_meta_dict` looks each
  id up in `data/junk/junk_catalog.tres`. Unknown ids (retired `.tres`) are skipped
  with a warning rather than crashing load. On-spec with the brief's preferred
  "store ids, rehydrate from catalog" option.
- **SaveManager API adaptation:** the spec referenced `SaveManager.save_meta()`;
  the real signature is `save_meta(slot: int)`. `extract_and_end_run()` saves to the
  default slot 0 (M1 has no slot-selection UI yet). Flagged as a follow-up below.
- **Schema bumped 1 → 2** with a migration + the M0 smoke test still green; no QA
  fixture file exists yet for meta migrations (smoke test exercises `_migrate_meta`
  inline). Noted for QA.

## Handoffs / follow-ups
- **F1/F2:** `GameState.banked_junk: Array[JunkItem]` is now the meta source of
  truth for unsold haul. E1 does NOT credit Money — F2's sell screen must convert
  `banked_junk` → Money and clear/consume the banked entries. The itemized list is
  intact (real `JunkItem` refs in memory, ids on disk).
- **E3 (death/timeout):** death already drops haul via `_on_player_died` (pockets
  fraction) and does NOT bank items — E3 should mirror E1's *teardown* but bank
  nothing. The extract path and death path now diverge intentionally (extract banks;
  death drops). E3 can reuse `end_run(reason, duration)` for its run-end emit.
- **Save slot:** `extract_and_end_run()` hardcodes slot 0. When a save/slot layer
  lands, route the slot through (small change — pass/store the active slot on
  GameState).
- **Duration:** `extract_and_end_run()` passes `duration_s = 0.0` to `end_run` (A3's
  clock owns the real elapsed time and listens to `run_ended` itself). If a caller
  has the elapsed time it can be threaded through later; not load-bearing for E1.
- **QA:** consider a meta save-migration fixture for v1→v2 (`banked_junk` default).
