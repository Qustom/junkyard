# Worklog — V4 Split GameState into Economy/QuotaLadder/core sub-objects

- **Date:** 2026-07-10
- **Subagent:** general-purpose
- **Milestone:** M1.12
- **Branch:** feat/V4-split-gamestate
- **Commit:** f8a2adf8c81e7bb185e8c34a1918fe7950ae689b

## What changed
Decomposed the 752-LOC `game_state.gd` god-object into three files per the V4 Resolved
Decisions (Phase 3): a slim `GameState` lifecycle **core + facade**, plus two `GameState`-owned
`RefCounted` sub-objects — `Economy` (currencies, buy/sell, banked junk, pockets) and
`QuotaLadder` (the K2 ladder + eval). Behavior-preserving: every moved field is forwarded with a
Godot-4 **getter+setter** property and every moved method with a one-line delegate, so the ~38
callers compile + pass with zero edits. The four `_quota_*` snapshot scalars collapsed to one held
`QuotaLadder._qc: RunConfig` reference (OQ1). `POCKETS_RNG_SALT` + the pockets/rehydration code +
`run_rules` load moved into `Economy`; `EXITS_RNG_SALT` + `GATE_SPAWN_OFFSET` stayed on the facade
for their cross-file readers. `to_meta_dict` assembles an ordered literal in the exact prior key
order → meta blob byte-identical at v4; SaveManager untouched. V6's `RNG.substream(run_seed,
POCKETS_RNG_SALT)` pockets seam and V9's slot-0 tracking comments carried verbatim across the split.

## Files touched
- `Game/systems/game_state.gd` — 752 → **467 LOC**. Slim lifecycle core (run-state + start/enter/
  extract/fail/end/set_depth + dive-staging seams) + the meta facade (getter+setter forwards for
  money/salvage/lore/exposure/banked_junk/owned_items/run_rules/run_number/quota_target; method
  delegates for add_currency/add_exposure/purchase/owns/last_quota_result) + the serialization
  dispatcher (ordered-literal `to_meta_dict`, `from_meta_dict` pushing into sub-objects) + the four
  coordinator flows (start_run/sell_banked_junk/fail_run/wipe_meta). `knowledge_level`/
  `unlocked_recipes` stay here. A private `_evaluate_quota(sold_total)` delegate was kept on the
  facade (see Design deviations — a white-box test calls it directly).
- `Game/systems/economy.gd` (new) — **251 LOC**, `class_name Economy extends RefCounted`. Meta
  currencies + `add_currency`/`add_exposure`/`purchase`/`owns`/`sell`(returns {breakdown,total})/
  `resolve_pockets`(run context passed in, carries V6 substream)/`held_haul_value`/`sum_values` +
  serialization value providers (`banked_junk_ids`/`owned_item_ids`/`rehydrate_banked_junk_from_ids`)
  + `wipe`. Owns `RUN_RULES_PATH`/`JUNK_CATALOG_PATH`/`POCKETS_RNG_SALT` (all zero external readers);
  loads RunRules in `_init` (OQ3).
- `Game/systems/quota_ladder.gd` (new) — **96 LOC**, `class_name QuotaLadder extends RefCounted`.
  `run_number`/`quota_target` meta + `begin_run`(returns needs-save bool)/`set_end_reason`/
  `evaluate`(money/sold_total/held_haul passed in)/`last_result`/`wipe`. Holds one `_qc: RunConfig`
  (OQ1 collapse) instead of four snapshot scalars; all seven old `_quota_*` fields left GameState.
- `Game/systems/economy.gd.uid`, `Game/systems/quota_ladder.gd.uid` — Godot-generated import uids.

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK — M0 architecture spike healthy**
- [x] **Meta byte-identity** (temp probe, fixed state): pre-split and post-split both
  `sha256=8e69332a174ade746457b92dc8661ffea6997c4ed1b286ffe8357d5972980d40`, bytelen 368, key order
  `money…owned_items`, `to_meta_dict→from_meta_dict→to_meta_dict` round-trip equal. Probe removed after.
- [x] `test_save_migration` (v1/v2/v3→v4) → all three SAVE MIGRATION OK (meta stays v4, SaveManager untouched)
- [x] `test_shop_economy` → SHOP ECONOMY OK · `test_money_ledger` → MONEY LEDGER OK · `test_death_drop` → DEATH DROP OK
- [x] `test_quota_system` → QUOTA OK (met advances+persists, miss defers, idempotent, on_extract gating, cumulative held-haul basis)
- [x] `test_loop_drive` → LOOP OK · `test_main_game_loop` → MAIN GAME OK · `test_duration_loop_reentry` → DURATION LOOP OK · `test_rg1_loop_verify` → RG1 BUILD VERIFY OK
- [x] `test_exit_placement` → K7 OK · `test_exit_placement_count` → FB5/EXIT-COUNT OK (EXITS_RNG_SALT + GATE_SPAWN_OFFSET intact on facade)
- [x] **Four control layout fingerprints byte-identical:** `test_band_pipeline_parity` → PIPELINE
  PARITY OK, `fp=e943ac9c8bc1` (band_greybox); `test_band_two_profile`/`_three_profile`/`_four_profile`
  each OK and each re-asserts the prior band(s) byte-identical (greybox+two+three+four); GameState is
  not referenced anywhere in `systems/bandgen|depth|spawning` — the layout path is structurally
  independent of this split. `test_bandgen_determinism` → R4 NAV OK.
- [x] Definition of done met: "GameState public API unchanged — the 38 callers compile + pass with
  zero edits; meta save bytes byte-identical for a fixed state; meta stays v4, SaveManager untouched,
  v1/v2/v3→v4 fixtures pass; the four control layout fps byte-identical; autoload count stays six
  (no new autoloads — Economy/QuotaLadder are GameState-owned RefCounted)."

## Debt ledger
| unit | before | after | responsibility |
|---|---|---|---|
| `game_state.gd` (monolith) | **752** | **467** | run lifecycle + facade + serialization dispatch |
| `systems/economy.gd` (new) | — | **251** | currencies, buy/sell, banked junk, pockets, wipe |
| `systems/quota_ladder.gd` (new) | — | **96** | K2 ladder meta + eval + begin_run |
| **total** | 752 | **814** (3 files) | — |

Net LOC ~flat (+62, the facade getter/setter/delegate boilerplate that buys **zero caller edits**).
The win is **coupling + cohesion**, per the version's structural measure: one 752-line god-object owning
four responsibilities → three single-responsibility files (max file size 752 → 467). Sub-objects hold
**zero back-references and zero cross-references** — run context (inventory, run_seed, money,
sold_total, held_haul) is *passed in*, never reached-for, so the run/meta boundary is now enforced by
the type seam. Seven `_quota_*` fields left GameState; the four snapshot scalars collapsed to one held
`RunConfig` ref (a genuine field-count reduction). M2 seam: crafting/upgrades extend `Economy`,
instability escalation extends `QuotaLadder`, as clean types.

## Design deviations
**One minor facade-completeness addition (not a behavioral change, zero caller edits):** the design's
OQ5 audit enumerated the *public* forwarded surface and predicted zero caller edits. `test_quota_system`
white-box-calls the **private** `GameState._evaluate_quota(sold_total)` directly (6 call sites). To keep
the promised **zero caller edits**, I kept a private `_evaluate_quota(sold_total)` delegate on the facade
that forwards to `_quota.evaluate(_economy.money, sold_total, _economy.held_haul_value())` — the exact
pre-V4 contract. No test was edited; no behavior changed. This is fully within the facade-preserving
contract (DR-4), just one delegate beyond the design's enumerated list. Recommend **Reviewed**. No other
departures — all four HARD CONTRACT items proven (zero caller edits, meta byte-identical, v1–v3→v4 green,
four control fps byte-identical). Autoload count stays six.

## Handoffs / follow-ups
- V9's slot-0 `SaveManager.save_meta(0)` tracking comments now live across three files (4 on core:
  start_run/extract/wipe/fail; 2 in Economy: purchase/sell; 1 in QuotaLadder: quota-advance) — the
  future multi-slot `GameState.active_slot` work (deferred, OQ6) is unaffected; the seam is if anything
  clearer (economy-owned vs quota-owned vs lifecycle-owned save sites).
- No push (per task). Ready for orchestrator integration/merge.
