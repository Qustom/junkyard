extends SceneTree
## Headless verification for D2 — the greybox inventory UI panel.
##
## Proves the panel is a PURE PROJECTION of GameState.run_inventory, driven by the
## EventBus run_inventory_changed signal (no polling, no cached truth):
##   - with no active run the panel paints an empty, non-crashing "no run" state,
##   - after start_run() + seeding real catalog JunkItems, the grid child count ==
##     item-cells + free_slots() empty placeholder cells,
##   - the capacity label reflects used/max slots,
##   - a model change (try_add / remove_at) fires the signal and the grid rebuilds,
##   - the explicit BAG FULL state appears when is_full(),
##   - the drop gesture path (cell.drop_requested -> remove_at) shrinks the bag.
## Run: godot --headless --script res://tests/test_inventory_ui.gd


const PANEL_SCENE := "res://ui/inventory/inventory_panel.tscn"
const CATALOG_PATH := "res://data/junk/junk_catalog.tres"


func _initialize() -> void:
	# A Control panel's _ready (and its EventBus.connect calls) fire only once the
	# node is processed inside the tree — which, under a custom SceneTree --script
	# harness, needs at least one frame to pump. So we run the body as a coroutine
	# that awaits process_frame after each tree mutation. Kicked off deferred so
	# the main loop is iterating by the time the body runs.
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []

	var gs := root.get_node_or_null("GameState")
	var eb := root.get_node_or_null("EventBus")
	if gs == null or eb == null:
		printerr("D2 FAIL: GameState/EventBus autoload missing")
		quit(1)
		return

	# --- Real catalog items so the test exercises C1 greybox data ----------------
	var catalog: JunkCatalog = load(CATALOG_PATH)
	if catalog == null or catalog.items.is_empty():
		printerr("D2 FAIL: junk catalog missing or empty")
		quit(1)
		return

	# --- Instantiate the panel and add it to the tree ---------------------------
	var panel_scene: PackedScene = load(PANEL_SCENE)
	var panel := panel_scene.instantiate()
	root.add_child(panel)
	await process_frame  # let _ready fire + EventBus.connect wire up

	var grid: GridContainer = panel.get_node("Margin/VBox/Grid")
	var cap_label: Label = panel.get_node("Margin/VBox/CapacityHeader/CapacityLabel")

	# --- No active run: panel shows empty, does not crash -----------------------
	# (GameState has no run_inventory before start_run.)
	if gs.run_inventory == null and grid.get_child_count() != 0:
		failures.append("grid not empty while there is no active run")

	# --- Start a run: empty bag, all cells are empty placeholders ----------------
	gs.start_run(&"near", 4242)
	var inv: RunInventory = gs.run_inventory
	if inv == null:
		printerr("D2 FAIL: start_run did not create run_inventory")
		quit(1)
		return
	# Signal-driven rebuild already happened via start_run's emit; force a paint
	# in case start_run does not emit, then assert against the model.
	await _flush()
	var expected_empty: int = inv.free_slots()  # whole bag free
	if _live_cell_count(grid) != expected_empty:
		failures.append("empty bag: grid has %d cells, expected %d free-slot cells"
			% [_live_cell_count(grid), expected_empty])
	if cap_label.text != _cap_text(inv):
		failures.append("empty bag: capacity label '%s' != expected '%s'"
			% [cap_label.text, _cap_text(inv)])

	# --- Seed a few items: grid == item-cells + free_slots() empty cells ---------
	var seeded: int = 0
	for item in catalog.items:
		if seeded >= 3:
			break
		if inv.try_add(item):  # fires run_inventory_changed -> panel rebuilds
			seeded += 1
	if seeded == 0:
		failures.append("could not seed any catalog item into the bag")
	await _flush()
	var expected_cells: int = inv.items.size() + inv.free_slots()
	if _live_cell_count(grid) != expected_cells:
		failures.append("seeded: grid has %d cells, expected items(%d)+free(%d)=%d"
			% [_live_cell_count(grid), inv.items.size(), inv.free_slots(), expected_cells])
	if cap_label.text != _cap_text(inv):
		failures.append("seeded: capacity label '%s' != expected '%s'"
			% [cap_label.text, _cap_text(inv)])

	# Item cells must carry data (non-empty); placeholder cells must be empty.
	if _live_item_cells(grid) != inv.items.size():
		failures.append("non-empty cell count %d != items %d"
			% [_live_item_cells(grid), inv.items.size()])

	# --- Signal drives rebuild: remove via model -> grid re-projects ------------
	# (Removing a 1-slot item turns one item-cell into one empty-cell, so total
	# cell count can legitimately stay equal; the rebuild invariant is that the
	# grid still equals items + free_slots and the item-cell count tracks items.)
	var before_items: int = inv.items.size()
	inv.remove_at(0)  # fires run_inventory_changed
	await _flush()
	if inv.items.size() != before_items - 1:
		failures.append("remove_at did not shrink the model")
	if _live_cell_count(grid) != inv.items.size() + inv.free_slots():
		failures.append("after remove: grid %d cells != items(%d)+free(%d) (rebuild not wired?)"
			% [_live_cell_count(grid), inv.items.size(), inv.free_slots()])
	if _live_item_cells(grid) != inv.items.size():
		failures.append("after remove: item-cells %d != model items %d"
			% [_live_item_cells(grid), inv.items.size()])

	# --- BAG FULL state: fill the bag, label flips to the FULL treatment --------
	var guard: int = 0
	while not inv.is_full() and guard < 100:
		var added := false
		for item in catalog.items:
			if inv.try_add(item):
				added = true
				break
		if not added:
			break
		guard += 1
	await _flush()
	if inv.is_full():
		var full_text := tr("INV_FULL").format(
			{"used": inv.used_slots(), "max": inv.max_slots})
		if cap_label.text != full_text:
			failures.append("full bag: label '%s' != FULL text '%s'"
				% [cap_label.text, full_text])
	else:
		failures.append("could not fill the bag to exercise the BAG FULL state")

	# --- Drop gesture path: cell.drop_requested -> panel removes from model ------
	var drop_target: InventoryCell = null
	for child in grid.get_children():
		var c := child as InventoryCell
		if c != null and not c.is_empty():
			drop_target = c
			break
	if drop_target != null:
		var items_before_drop: int = inv.items.size()
		drop_target.drop_requested.emit(0)  # panel's handler removes index 0
		await _flush()
		if inv.items.size() != items_before_drop - 1:
			failures.append("drop gesture did not remove an item from the model")
	else:
		failures.append("no item cell available to test the drop gesture")

	# --- Verdict ----------------------------------------------------------------
	if failures.is_empty():
		print("INV UI OK — D2 panel verified (pure projection, signal-driven rebuild, "
			+ "item+free-slot cell count, capacity label, BAG FULL state, drop gesture).")
		quit(0)
	else:
		for f in failures:
			printerr("INV UI FAIL: ", f)
		quit(1)


# Capacity label text the panel should show for a non-full bag.
func _cap_text(inv: RunInventory) -> String:
	if inv.is_full():
		return tr("INV_FULL").format({"used": inv.used_slots(), "max": inv.max_slots})
	return tr("INV_CAPACITY").format({"used": inv.used_slots(), "max": inv.max_slots})


# Signals deliver synchronously and the panel rebuilds with immediate free(), so
# the grid is already correct when a try_add/remove_at returns. We still await one
# frame as a safety seam (and to settle any deferred tree bookkeeping).
func _flush() -> void:
	await process_frame


# Cells not pending deletion — the true live projection on this frame.
func _live_cell_count(grid: GridContainer) -> int:
	var n: int = 0
	for child in grid.get_children():
		if not child.is_queued_for_deletion():
			n += 1
	return n


func _live_item_cells(grid: GridContainer) -> int:
	var n: int = 0
	for child in grid.get_children():
		if child.is_queued_for_deletion():
			continue
		var cell := child as InventoryCell
		if cell != null and not cell.is_empty():
			n += 1
	return n
