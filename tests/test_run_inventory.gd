extends SceneTree
## Headless verification for D1 — the run-state slot inventory model.
##
## Drives RunInventory directly (it is a plain RefCounted) plus one integration
## check through the real GameState autoload. Proves the M1 acceptance criteria:
##   - accepts items until capacity, then REJECTS one that doesn't fit (full bag blocks pickup),
##   - can_accept() is a pure predicate (no mutation),
##   - a non-PLACEABLE item is rejected at the gate,
##   - remove_at()/remove() are index/instance-safe,
##   - clear_run() empties the bag and emits run_inventory_changed,
##   - a fresh GameState.start_run() yields an empty bag sized from InventoryConfig,
##     and the bag is run-state (cleared on run end, money/meta untouched).
## Run: godot --headless --script res://tests/test_run_inventory.gd


# Build a JunkItem in code so the test is independent of catalog .tres tuning.
func _make_item(size: int, flags: int, value: int = 10) -> JunkItem:
	var it := JunkItem.new()
	it.slot_size = size
	it.containment_flags = flags
	it.base_sell_value = value
	return it


func _initialize() -> void:
	var failures: Array[String] = []
	const PLACEABLE := JunkItem.ContainmentFlag.PLACEABLE

	# --- Signal emission tracking (decoupling contract) ----------------------
	var eb := root.get_node_or_null("EventBus")
	if eb == null:
		printerr("D1 FAIL: EventBus autoload missing")
		quit(1)
		return
	var emit_log: Array = []
	eb.run_inventory_changed.connect(func(used: int, maxs: int) -> void:
		emit_log.append([used, maxs]))

	# --- Capacity: accept until full, then reject -----------------------------
	var inv := RunInventory.new()
	inv.max_slots = 4
	# Two size-1 items + one size-2 item == 4 slots exactly.
	var bolt_a := _make_item(1, PLACEABLE)
	var bolt_b := _make_item(1, PLACEABLE)
	var battery := _make_item(2, PLACEABLE)
	if not inv.try_add(bolt_a):
		failures.append("try_add rejected first size-1 item into empty 4-slot bag")
	if not inv.try_add(bolt_b):
		failures.append("try_add rejected second size-1 item")
	if not inv.try_add(battery):
		failures.append("try_add rejected size-2 item that exactly fills the bag")
	if inv.used_slots() != 4:
		failures.append("used_slots == %d, expected 4" % inv.used_slots())
	if not inv.is_full():
		failures.append("is_full() false on a full bag")
	# Now the bag is full — one more item MUST be rejected (acceptance criterion).
	var overflow := _make_item(1, PLACEABLE)
	if inv.try_add(overflow):
		failures.append("FULL BAG accepted an item — capacity not enforced")
	if inv.used_slots() != 4:
		failures.append("used_slots changed after a rejected add (was mutated): %d" % inv.used_slots())

	# An item too big for the remaining space (after a partial bag) is rejected.
	var inv2 := RunInventory.new()
	inv2.max_slots = 3
	inv2.try_add(_make_item(2, PLACEABLE))   # 2 used, 1 free
	if inv2.try_add(_make_item(2, PLACEABLE)):
		failures.append("size-2 item accepted into 1 free slot — size check failed")

	# --- can_accept() is pure (no mutation, no side effects) ------------------
	var pure_inv := RunInventory.new()
	pure_inv.max_slots = 5
	var probe := _make_item(1, PLACEABLE)
	var emits_before := emit_log.size()
	var verdict := pure_inv.can_accept(probe)
	if not verdict:
		failures.append("can_accept() said no for a fitting item")
	if pure_inv.used_slots() != 0 or pure_inv.items.size() != 0:
		failures.append("can_accept() mutated the inventory")
	if emit_log.size() != emits_before:
		failures.append("can_accept() emitted run_inventory_changed (should be silent)")

	# --- Non-PLACEABLE item is rejected at the gate ---------------------------
	var no_place_inv := RunInventory.new()
	no_place_inv.max_slots = 10
	var not_placeable := _make_item(1, JunkItem.ContainmentFlag.NONE)  # missing PLACEABLE
	if no_place_inv.can_accept(not_placeable):
		failures.append("can_accept() allowed a non-PLACEABLE item")
	if no_place_inv.try_add(not_placeable):
		failures.append("try_add() accepted a non-PLACEABLE item")
	# Null safety.
	if no_place_inv.can_accept(null):
		failures.append("can_accept(null) returned true")

	# --- remove_at() / remove() are index/instance-safe -----------------------
	var rem_inv := RunInventory.new()
	rem_inv.max_slots = 6
	var keep := _make_item(1, PLACEABLE)
	var drop := _make_item(2, PLACEABLE)
	rem_inv.try_add(keep)
	rem_inv.try_add(drop)
	var removed := rem_inv.remove_at(1)
	if removed != drop:
		failures.append("remove_at(1) returned the wrong item")
	if rem_inv.items.size() != 1 or rem_inv.items[0] != keep:
		failures.append("remove_at left the wrong item behind")
	if rem_inv.remove_at(99) != null:
		failures.append("remove_at(out-of-range) did not return null")
	if not rem_inv.remove(keep):
		failures.append("remove(keep) failed for a present item")
	if rem_inv.remove(keep):
		failures.append("remove(keep) succeeded twice for the same instance")

	# --- clear_run() empties and emits ----------------------------------------
	var clear_inv := RunInventory.new()
	clear_inv.max_slots = 8
	clear_inv.try_add(_make_item(1, PLACEABLE))
	clear_inv.try_add(_make_item(1, PLACEABLE))
	var emits_pre_clear := emit_log.size()
	clear_inv.clear_run()
	if clear_inv.items.size() != 0 or clear_inv.used_slots() != 0:
		failures.append("clear_run() did not empty the bag")
	if emit_log.size() <= emits_pre_clear:
		failures.append("clear_run() did not emit run_inventory_changed")
	else:
		var last: Array = emit_log[emit_log.size() - 1]
		if last[0] != 0 or last[1] != 8:
			failures.append("clear_run() emitted %s, expected [0, 8]" % str(last))

	# --- Integration: GameState.start_run() yields an empty run-state bag ------
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		failures.append("GameState autoload missing")
	else:
		var money_before: int = gs.money
		gs.start_run(&"near", 777)
		if gs.run_inventory == null:
			failures.append("start_run() did not construct run_inventory")
		else:
			if gs.run_inventory.items.size() != 0:
				failures.append("fresh bag from start_run() is not empty")
			# max_slots comes from the authored InventoryConfig.tres (base 12).
			if gs.run_inventory.max_slots != 12:
				failures.append("fresh bag max_slots == %d, expected 12 from config"
					% gs.run_inventory.max_slots)
			# Add something, then prove run-end wipes it (run-state, not meta).
			gs.run_inventory.try_add(_make_item(1, PLACEABLE, 50))
			var bag_ref: RunInventory = gs.run_inventory
			gs.end_run(&"extract", 1.0)
			if bag_ref.items.size() != 0:
				failures.append("end_run() did not clear the run inventory")
			# Meta money must be untouched by D1's inventory lifecycle.
			if gs.money != money_before:
				failures.append("inventory lifecycle changed meta money %d -> %d (run/meta leak)"
					% [money_before, gs.money])
			# A second start_run() yields a brand-new empty bag (run-state reset).
			gs.start_run(&"near", 778)
			if gs.run_inventory == bag_ref:
				failures.append("start_run() reused the old bag instance instead of a fresh one")
			if gs.run_inventory.items.size() != 0:
				failures.append("second run did not start with an empty bag")

	if failures.is_empty():
		print("INV OK — D1 slot inventory verified (capacity reject, full-bag block, pure can_accept, non-PLACEABLE gate, index-safe remove, clear emits, run-state-only).")
		quit(0)
	else:
		for f in failures:
			printerr("INV FAIL: ", f)
		quit(1)
