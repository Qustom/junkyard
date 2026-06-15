# Worklog — D1 Slot inventory data model

- **Date:** 2026-06-15
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1
- **Branch:** general-purpose/D1-inventory
- **Commit:** 987c23f9e8245b23022a4c89be88375579219d03 (D1 implementation; this worklog's SHA-record fixup follows)

## What changed
Implemented the run-state slot inventory model that owns "what is currently
carried" and the rules for whether one more thing fits — the heart of the M1
push/cash-out tension. Count-based capacity (sum `slot_size` vs `max_slots`),
flat top-level slots honoring the `PLACEABLE` gate, no stacking, shared-ref
catalog items with index/instance-safe removal. Capacity is authored on a
designer-tunable `InventoryConfig.tres` (`base_max_slots = 12`), read once at run
start. Wired a fresh `RunInventory` into the existing `GameState.start_run()` and
cleared it on both run-end paths so the bag never survives into the next run.

## Files touched
- `systems/inventory/run_inventory.gd` — NEW. `class_name RunInventory extends RefCounted`. `max_slots`, `items: Array[JunkItem]`, `used_slots()/free_slots()/is_full()`, pure null-safe `can_accept()`, mutating `try_add()`, `remove_at()` (index-safe) + `remove()` (instance-safe), `clear_run()`. Emits `EventBus.run_inventory_changed` via a SceneTree-resolved helper.
- `data/inventory/inventory_config.gd` — NEW. `class_name InventoryConfig extends Resource`, `base_max_slots: int = 12`.
- `data/inventory/inventory_config.tres` — NEW. Authored config instance (`base_max_slots = 12`).
- `systems/game_state.gd` — added `var run_inventory: RunInventory` (run-state); added `INVENTORY_CONFIG_PATH` const + `_make_run_inventory()` helper; construct a fresh bag in the existing `start_run()`; clear it in the existing `end_run()` and `_on_player_died()`. No other members touched.
- `tests/test_run_inventory.gd` — NEW. Plain `--script` SceneTree harness (GdUnit4 not yet vendored).

## Checks run
- [x] `godot --headless --import` clean (no parse errors; `RunInventory`/`InventoryConfig` registered as global classes)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy`
- [x] `godot --headless --script res://tests/test_run_inventory.gd` → `INV OK` — verifies: accepts to capacity then REJECTS an overflow item (full bag blocks pickup — the acceptance criterion); rejects an item too big for remaining space; `can_accept()` is pure (no mutation, no emit); non-PLACEABLE and null rejected at the gate; `remove_at()`/`remove()` index/instance-safe; `clear_run()` empties + emits `[0, max]`; a fresh `start_run()` yields an empty bag with `max_slots = 12` from config; `end_run()` wipes the bag while meta `money` is untouched (run/meta boundary); a second `start_run()` allocates a brand-new bag instance.
- [x] Definition of done met (D1 acceptance: "Inventory accepts/rejects items by size and capacity; a full inventory blocks pickup; the inventory lives in run-state (not meta-state)").

## Design deviations
- **Integrated with the REAL GameState, not the spec's idealized excerpt** (orchestrator-directed; no sign-off needed). The D1 spec showed `banked_money`/`cash_out`/`start_run()` illustratively. The real `systems/game_state.gd` already has `money` as the banked currency, `unbanked_value` run-state, and `bank_haul()`/`end_run()`/`_on_player_died()`. I did NOT add `banked_money` or `cash_out`, and did NOT touch `unbanked_value`/`bank_haul`/the pockets logic. I only added `run_inventory` + its fresh-construct-on-`start_run` / clear-on-run-end lifecycle. Junk→value reconciliation is C2/E1/F1's job.
- **`max_slots` from an authored `InventoryConfig.tres`** (spec Open-question recommendation, adopted): `start_run()` reads `base_max_slots` once when building the fresh bag. Capacity *value* is config/meta-derived; the live bag stays run-state.
- **EventBus emit resolved via the live SceneTree, not the `EventBus` compile-time global.** `RunInventory` is a `class_name` script; when loaded standalone in a `--script` test harness, autoload *names* are not registered as global identifiers (the autoload Node still exists in the tree), so a direct `EventBus.…emit()` fails to compile there even though it is fine in the booted project. The model now emits through `_emit_changed()`, which fetches the EventBus node from `Engine.get_main_loop()`. Same node in normal runs; keeps the model unit-testable in isolation. Minor implementation detail, on-spec behaviorally (still signal-driven via EventBus, no hard refs). Did NOT edit `systems/event_bus.gd` — the `run_inventory_changed` signal already exists on main.
- **`remove_at(index)` added alongside `remove(item)`** (spec Open-question recommendation): index-safe removal is the preferred D2 entry point; `remove(item)` retained for instance-identity callers. `find()`-by-value as the *sole* path was rejected per the spec recommendation.

(Worktree note, not a design deviation: this branch was created off a stale base and rebased onto the current `main` (`3bd7fb1`, which carries C1's `JunkItem` + the locked `run_inventory_changed` signal) before building.)

## Handoffs / follow-ups
- **C2 (pickup):** call `GameState.run_inventory.try_add(item)`; keep the world entity on `false` (full bag blocks pickup), free it on `true`.
- **D2 (UI grid):** listen to `EventBus.run_inventory_changed(used_slots, max_slots)`; use `remove_at(index)` for the drop affordance (clicked cell → array index).
- **C2/E1/F1:** junk→`unbanked_value` reconciliation on cash-out is still open; D1 deliberately does not touch value. When per-instance state (condition/wear) lands, switch pickup to `item.duplicate()` and the carried-item shared-ref assumption becomes per-instance (localized change; `remove_at` already index-safe).
