# Worklog — V5 Extract the duplicated interaction-owner boilerplate (R6)

- **Date:** 2026-07-10
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.12 (behavior-preserving refactor, Wave 1)
- **Branch:** feat/V5-interaction-owner
- **Commit:** fef4042574375cb7e599b9f91b19902448742d29

## What changed
Extracted the id-guard + parent-check + fat-finger-lockout mechanism that was
duplicated verbatim across `ExtractGate`, `DeparturePortal`, and `HubShop` (all
three, lockout 0.25s) and partially (id-guard + parent-check only, NO lockout) in
`JunkPickup` into a single shared helper `InteractionOwner`
(`Game/components/interaction/interaction_owner.gd`). It is a plain `Node`
constructed and `add_child()`-ed in each owner's own `_ready()` (NO `.tscn`
edits), owns the `_locked` state + timer arm, and emits a clean
`activated(target)` signal once the guards pass. It takes a `lockout_s: float`
param; `0.0` disables the lockout arm entirely — JunkPickup's explicit opt-out,
preserving its verified-absent debounce exactly. Each owner keeps its own
`interactable_id`/`input_lockout_s` exports (authoring surface unchanged) and its
own one-line FINAL ACTION in an `_on_activated()` handler. Added a new
scene-based lockout test (none existed before).

## Files touched
- `Game/components/interaction/interaction_owner.gd` — NEW helper (the extracted mechanism + `activated` signal).
- `Game/entities/gate/extract_gate.gd` — rewired to `InteractionOwner` (lockout 0.25); action `GameState.extract_and_end_run()`.
- `Game/scenes/hub/departure_portal.gd` — rewired (lockout 0.25); action `EventBus.dive_requested.emit(band_id)`; the S8 id/tint push-down block untouched.
- `Game/scenes/hub/shop.gd` — rewired (lockout 0.25); action `_shop_ui.open()`.
- `Game/entities/junk_pickup/junk_pickup.gd` — rewired with lockout **0.0** (explicit no-debounce opt-out); action `_try_pickup()`; the child-id caching before construction preserved.
- `Game/tests/test_interaction_owner.gd` + `.tscn` — NEW scene test covering the lockout window (fires-once-then-re-arms), the 0.0 no-debounce path (fires every time), and wrong-id/wrong-parent rejection.
- The four owner `.tscn` files are UNTOUCHED (zero-byte diff — mechanism is constructed in code, not scene-authored).

## Checks run
- [x] `godot --headless --path Game --import` clean (IMPORT_EXIT=0, no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `res://tests/test_interaction_owner.tscn` (NEW) → INTERACTION_OWNER OK
- [x] `res://tests/test_exit_placement.tscn` (extract gate multi-gate/lockout) → K7 OK
- [x] `res://tests/test_junk_pickup.tscn` → JUNK PICKUP OK
- [x] `res://tests/test_shop_economy.tscn` → SHOP ECONOMY OK
- [x] `res://tests/test_hub_contract.tscn` → HUB_CONTRACT OK (5 interactables, portals + shop)
- [x] `res://tests/test_interaction.gd` (--script detector) → INTERACT OK
- [x] `res://tests/test_extract_bank.gd` (--script) → EXTRACT OK
- [x] Definition of done met: "duplicated interaction-owner boilerplate collapsed to one helper; every interaction fires under IDENTICAL conditions to today; `.tscn` owner files stay zero-byte-diff; a focused lockout unit test added." All four owner `.tscn` files verified zero-diff via `git diff --stat`.

## Debt ledger
- **Duplicate-copy count: 4 → 1.** The mechanism block existed as 3 verbatim copies (ExtractGate/DeparturePortal/HubShop) + 1 partial (JunkPickup: id-guard + parent-check only). All collapse into one canonical implementation in `InteractionOwner`.
- **Owner LOC:** `git diff --stat` on the four owner `.gd` files = **+44 / -99 (net -55)**.
- **New helper:** `interaction_owner.gd` = **+58 LOC**.
- **Net production-code LOC ≈ +3** (owner -55, helper +58). Marginally positive because the helper carries a full doc-comment header; the real win is qualitative: one canonical mechanism instead of four hand-maintained near-copies, and JunkPickup's previously-silent missing lockout is now an explicit, self-documenting `0.0` parameter at the call site rather than an unstated omission.
- **New test:** `test_interaction_owner.gd/.tscn` = **+132 LOC** of NEW coverage (the lockout window had zero test coverage before) — coverage, not debt.

## Design deviations
none. Implemented exactly per `design/M1_12_Tasks/V5_interaction_owner_helper.md` + its
Phase-3 Resolved Decisions: shape (A) `InteractionOwner` Node, `lockout_s: float`
with `0.0` as JunkPickup's opt-out, new sibling scene test (not an extension of
`test_interaction.gd`), zero `.tscn` edits. No fingerprint/signal/timing change.

## Handoffs / follow-ups
- Design-doc OQ5 (owner's own `interactable_id` export duplicating the child
  `Interactable`'s id) was explicitly scoped OUT of V5; noted there as a
  related-but-separate future seam. Not touched.
