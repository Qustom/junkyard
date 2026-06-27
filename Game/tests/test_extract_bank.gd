extends SceneTree
## Headless verification for E1 — extract gate + bank run inventory to meta.
##
## Drives the real GameState autoload through the extract flow and asserts the
## E1 acceptance criteria + the human design decisions:
##   - extract banks run-inventory item IDENTITIES into meta `banked_junk` (#6),
##   - run_inventory is wiped (run-state → never survives the extract),
##   - haul_banked fires with the summed base_sell_value (Money NOT credited here, #6),
##   - run_ended fires with reason &"extract" (reused lifecycle, no parallel run_end),
##   - meta money is UNCHANGED by extract (F2 owns the sell, not E1),
##   - a zero-haul extract still banks nothing, fires haul_banked(0) + run_ended(&"extract") (#7),
##   - banked_junk round-trips through the save bridge (ids persist, rehydrate via catalog).
## Run: godot --headless --script res://tests/test_extract_bank.gd


# A catalog-independent JunkItem so the asserted values are stable.
func _make_item(id: StringName, value: int, size: int = 1) -> JunkItem:
	var it := JunkItem.new()
	it.id = id
	it.slot_size = size
	it.base_sell_value = value
	it.containment_flags = JunkItem.ContainmentFlag.PLACEABLE
	return it


func _initialize() -> void:
	var failures: Array[String] = []

	var eb := root.get_node_or_null("EventBus")
	var gs := root.get_node_or_null("GameState")
	if eb == null or gs == null:
		printerr("E1 FAIL: EventBus or GameState autoload missing")
		quit(1)
		return

	# --- Signal tracking -----------------------------------------------------
	var banked_log: Array = []
	eb.haul_banked.connect(func(total: int) -> void: banked_log.append(total))
	var ended_log: Array = []
	eb.run_ended.connect(func(reason: StringName, dur: float, depth: int) -> void:
		ended_log.append([reason, dur, depth]))

	# Typed empties/lists: `gs` is dynamic, so untyped literals fail to assign
	# into GameState's typed Array[JunkItem] property — build typed arrays here.
	var empty_junk: Array[JunkItem] = []

	# === Case 1: extract with a haul ========================================
	gs.banked_junk = empty_junk.duplicate()   # clean meta slate for the assertion
	var money_before: int = gs.money
	gs.start_run(&"near", 4242)
	var a := _make_item(&"junk_a", 30)
	var b := _make_item(&"junk_b", 20, 2)
	gs.run_inventory.try_add(a)
	gs.run_inventory.try_add(b)
	var bag_ref: RunInventory = gs.run_inventory

	var banked_count_before := banked_log.size()
	var ended_count_before := ended_log.size()
	gs.extract_and_end_run()

	# banked_junk now holds those item identities.
	if gs.banked_junk.size() != 2:
		failures.append("banked_junk holds %d items, expected 2" % gs.banked_junk.size())
	elif not (gs.banked_junk.has(a) and gs.banked_junk.has(b)):
		failures.append("banked_junk does not hold the exact item identities banked")
	# run_inventory wiped (run-state never survives extract).
	if bag_ref.items.size() != 0:
		failures.append("run_inventory not cleared after extract (%d left)" % bag_ref.items.size())
	# haul_banked fired once with the summed value (30 + 20 = 50).
	if banked_log.size() != banked_count_before + 1:
		failures.append("haul_banked did not fire exactly once on extract")
	elif banked_log[banked_log.size() - 1] != 50:
		failures.append("haul_banked value == %d, expected 50" % banked_log[banked_log.size() - 1])
	# run_ended fired with reason &"extract".
	if ended_log.size() != ended_count_before + 1:
		failures.append("run_ended did not fire exactly once on extract")
	elif ended_log[ended_log.size() - 1][0] != &"extract":
		failures.append("run_ended reason == %s, expected &\"extract\"" % str(ended_log[ended_log.size() - 1][0]))
	# Money NOT credited at the gate (decision #6: F2 sells, E1 only moves items).
	if gs.money != money_before:
		failures.append("extract changed meta money %d -> %d (E1 must NOT convert to Money)"
			% [money_before, gs.money])
	# run flagged inactive.
	if gs.run_active:
		failures.append("run_active still true after extract")

	# === Case 2: zero-haul extract (decision #7) ============================
	gs.start_run(&"near", 7)
	# Empty bag — bail out alive with nothing.
	var banked_count_z := banked_log.size()
	var ended_count_z := ended_log.size()
	var banked_meta_before: int = gs.banked_junk.size()
	gs.extract_and_end_run()
	if gs.banked_junk.size() != banked_meta_before:
		failures.append("zero-haul extract changed banked_junk count (should add nothing)")
	if banked_log.size() != banked_count_z + 1:
		failures.append("zero-haul extract did not fire haul_banked")
	elif banked_log[banked_log.size() - 1] != 0:
		failures.append("zero-haul haul_banked == %d, expected 0" % banked_log[banked_log.size() - 1])
	if ended_log.size() != ended_count_z + 1 or ended_log[ended_log.size() - 1][0] != &"extract":
		failures.append("zero-haul extract did not fire run_ended(&\"extract\")")

	# === Case 3: banked_junk persists through the save bridge ===============
	# Use catalog items so rehydration-by-id can resolve them.
	var cat: JunkCatalog = load("res://data/junk/junk_catalog.tres") as JunkCatalog
	if cat == null or cat.items.size() < 2:
		failures.append("catalog unavailable for save round-trip case")
	else:
		var two: Array[JunkItem] = [cat.items[0], cat.items[1]]
		gs.banked_junk = two
		var meta: Dictionary = gs.to_meta_dict()
		var ids: Array = meta.get("banked_junk", [])
		if ids.size() != 2:
			failures.append("to_meta_dict persisted %d banked ids, expected 2" % ids.size())
		if not (ids.has(String(cat.items[0].id)) and ids.has(String(cat.items[1].id))):
			failures.append("to_meta_dict did not persist banked junk ids as strings")
		# Wipe then rehydrate from the dict.
		gs.banked_junk = empty_junk.duplicate()
		gs.from_meta_dict(meta)
		if gs.banked_junk.size() != 2:
			failures.append("from_meta_dict rehydrated %d banked items, expected 2" % gs.banked_junk.size())
		elif gs.banked_junk[0].id != cat.items[0].id or gs.banked_junk[1].id != cat.items[1].id:
			failures.append("rehydrated banked_junk ids do not match what was saved")

	# === Verdict ============================================================
	gs.banked_junk = empty_junk.duplicate()   # leave no meta residue for other harnesses
	if failures.is_empty():
		print("EXTRACT OK — E1 verified (banks item identities to meta, wipes run-state, haul_banked + run_ended[extract] fire, no Money credit, zero-haul valid, banked_junk persists by id).")
		quit(0)
	else:
		for f in failures:
			printerr("E1 FAIL: ", f)
		quit(1)
