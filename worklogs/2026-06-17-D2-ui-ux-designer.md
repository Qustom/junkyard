# Worklog — D2 Inventory UI (greybox)

- **Date:** 2026-06-17
- **Subagent:** ui-ux-designer
- **Milestone:** M1
- **Branch:** ui-ux-designer/D2-inventory-ui
- **Commit:** 66b9f0d6c0f14365a09c9660a584b7b534f2cdad

## What changed
Built the greybox inventory UI: a persistent HUD `InventoryPanel` that is a pure
projection of `GameState.run_inventory`, plus an `InventoryCell` that renders one
`JunkItem` (greybox shape + `$value` + slot-cost badge) or an empty placeholder.
The panel never holds inventory truth — it rebuilds from the model on the EventBus
`run_inventory_changed` signal (and on `run_started`/`run_ended` run boundaries,
which swap the bag without going through `try_add`). Implemented all the D2
Open-questions recommendations: one cell per item + slot-cost badge, rendered
`free_slots()` empty cells, flat `$value` primary readout with `$/slot` on hover,
right-click hold-to-drop gesture, full clear-and-repopulate rebuild, and an
explicit "BAG FULL" state driven from the same `is_full()` predicate C2 uses.

## Files touched
- `ui/inventory/inventory_panel.gd` — `class_name InventoryPanel extends Control`; signal-driven projection, capacity bar (green→red), BAG FULL state, drop handler calling `RunInventory.remove_at`.
- `ui/inventory/inventory_panel.tscn` — docked bottom-right HUD panel (4-col GridContainer, capacity header, dimmed background); `cell_scene` export wired to the cell.
- `ui/inventory/inventory_cell.gd` — `class_name InventoryCell extends PanelContainer`; `_draw_greybox` (rect/circle/triangle/diamond, each with a black outline = non-colour channel), value/per-slot/badge labels, right-click `drop_requested(index)` gesture.
- `ui/inventory/inventory_cell.tscn` — fixed-size cell with Greybox Control + value/per-slot/badge labels.
- `ui/inventory/inventory_strings.csv` (+ generated `.en.translation`) — externalized all player-facing strings; resolved via `tr()`.
- `project.godot` — registered the translation under `[internationalization] locale/translations`.
- `tests/test_inventory_ui.gd` — headless D2 verification.

## Checks run
- [x] `godot --headless --import` clean (no parse errors; `InventoryPanel`/`InventoryCell` register as global classes)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy`
- [x] `godot --headless --script res://tests/test_inventory_ui.gd` passes:
  `INV UI OK — D2 panel verified (pure projection, signal-driven rebuild, item+free-slot cell count, capacity label, BAG FULL state, drop gesture).` (exit 0)
- [x] Definition of done met: "HUD/inventory driven by signals; all text externalized; readability rules implemented; visual polish/icons handed to a human." The panel polls nothing, reads truth only from `GameState.run_inventory`, rebuilds on `run_inventory_changed`; strings are externalized to CSV; colour cues are each backed by a non-colour channel (shape outline, "$N"/"FULL"/badge text); final art is left for a human.

## Design deviations
- **Panel also listens to `run_started`/`run_ended`, not only `run_inventory_changed`.** The spec skeleton connected solely to `run_inventory_changed`, but `GameState.start_run()` builds a fresh empty bag and `end_run()` clears it *without* always routing through `try_add`/`clear_run` at a moment the panel is listening (start_run emits `run_started`, not `run_inventory_changed`). Connecting the two run-boundary signals (handler ignores their args) makes the panel re-project the fresh empty bag at run start and the "No active dive" state at run end. Stays within the architecture (still EventBus signals, no hard refs, no cached truth). Low risk; recommend Director note "Reviewed".
- **Added a "No active dive" state for `run_inventory == null`.** Spec's `_refresh` just `return`ed on null; an always-on HUD panel needs a non-misleading idle state between runs. Additive, no model impact.
- **Drop gesture is right-click only (no hold-to-drop variant).** Spec recommended "right-click or hold-to-drop". I shipped right-click as the single deliberate gesture (greybox-simple, no held-timer UI). Hold-to-drop can be added later if playtest wants it. Within the recommendation's intent (a non-trivial gesture so a stray click never dumps an item).
- **Rebuild uses `queue_free()` + hide (not synchronous `free()`).** A rebuild can be triggered from inside a cell's own `drop_requested` emission; that node is locked mid-signal and cannot be freed/detached synchronously (Godot errors "Object is locked"). Old cells are hidden immediately and `queue_free`d, so they leave the tree next frame. This is an engine-correctness detail, not a design change; the visible projection is still correct.
- **No `theme.tres`.** Spec listed it as optional. Per-cell theme overrides (outline, font sizes) sufficed for greybox; a shared theme is deferred to the human visual pass.
- Otherwise on-spec. No API names were invented — all `RunInventory`/`JunkItem`/EventBus calls match the live signatures (`used_slots()`, `free_slots()`, `is_full()`, `remove_at(index)`, `run_inventory_changed(used, max)`).

## Handoffs / follow-ups
- **C2 (junk pickup):** the drop gesture removes the item from the model only. Re-spawning the dropped `JunkPickup` in the world at the player is C2's job — it should listen for the resulting `run_inventory_changed` or expose a drop hook. Noted for the C2 dispatch.
- **HUD integration:** `inventory_panel.tscn` is a self-contained `Control`; whoever assembles the main HUD CanvasLayer (with `dive_clock_meter`, etc.) should add it as a child. It currently anchors bottom-right.
- **Visual polish / icons:** greybox shapes + placeholder layout only. Real icons, theme, and band/era styling per the readability rules are the human visual pass.
- **Localization:** strings live in `ui/inventory/inventory_strings.csv`. As more UI lands, consolidate into a single project-wide strings CSV/PO.
- **Accessibility (M5):** colorblind-safe palette hooks, text-size scaling, and the band-signature layer tie into the shared readability source planned for the settings task.
