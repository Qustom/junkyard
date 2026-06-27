extends SceneTree
## Headless verification for F1 — Money ledger + sell_banked_junk().
##
## Drives the real GameState autoload through the cash-out flow and asserts the
## F1 acceptance criteria + the human design recommendations:
##   - sell_banked_junk() converts ALL banked_junk -> Money at base_sell_value,
##     crediting Money by the EXACT sum,
##   - banked_junk is empty after the sale (items consumed),
##   - the returned breakdown itemizes each sold item {id, name, value},
##   - exactly ONE currency_changed(&"money", total, source) fires for the lot,
##   - the source tag flows through (default &"sell"; &"pockets" for a fail sale),
##   - selling an empty bank is a no-op (returns [], no crash, no negative),
##   - Money is meta-state and round-trips through save_meta(0)/load_meta(0).
## Run: godot --headless --script res://tests/test_money_ledger.gd


# A catalog-independent JunkItem so the asserted values are stable.
func _make_item(id: StringName, value: int, name: String = "Junk") -> JunkItem:
	var it := JunkItem.new()
	it.id = id
	it.display_name = name
	it.slot_size = 1
	it.base_sell_value = value
	it.containment_flags = JunkItem.ContainmentFlag.PLACEABLE
	return it


func _initialize() -> void:
	var failures: Array[String] = []

	var eb := root.get_node_or_null("EventBus")
	var gs := root.get_node_or_null("GameState")
	var sm := root.get_node_or_null("SaveManager")
	if eb == null or gs == null or sm == null:
		printerr("F1 FAIL: EventBus, GameState, or SaveManager autoload missing")
		quit(1)
		return

	# --- Signal tracking -----------------------------------------------------
	# Log only money-kind currency_changed events so other currencies don't pollute.
	var money_log: Array = []
	eb.currency_changed.connect(func(kind: StringName, delta: int, source: StringName) -> void:
		if kind == &"money":
			money_log.append([delta, source]))

	var empty_junk: Array[JunkItem] = []

	# === Case 1: sell a known pile credits Money by the exact sum ============
	# Items 30, 20, 10 → total 60.
	gs.banked_junk = empty_junk.duplicate()
	var a := _make_item(&"junk_a", 30, "Alpha")
	var b := _make_item(&"junk_b", 20, "Bravo")
	var c := _make_item(&"junk_c", 10, "Charlie")
	var pile: Array[JunkItem] = [a, b, c]
	gs.banked_junk = pile
	var money_before: int = gs.money
	var money_events_before := money_log.size()

	var breakdown: Array = gs.sell_banked_junk()

	# Money credited by the exact sum.
	if gs.money != money_before + 60:
		failures.append("Case1 money %d -> %d, expected +60" % [money_before, gs.money])
	# banked_junk emptied (items consumed).
	if gs.banked_junk.size() != 0:
		failures.append("Case1 banked_junk not empty after sale (%d left)" % gs.banked_junk.size())
	# Exactly one money currency_changed event for the lot.
	if money_log.size() != money_events_before + 1:
		failures.append("Case1 currency_changed(money) fired %d times, expected 1"
			% (money_log.size() - money_events_before))
	elif money_log[money_log.size() - 1][0] != 60:
		failures.append("Case1 currency_changed delta == %d, expected 60" % money_log[money_log.size() - 1][0])
	elif money_log[money_log.size() - 1][1] != &"sell":
		failures.append("Case1 default source == %s, expected &\"sell\"" % str(money_log[money_log.size() - 1][1]))
	# Breakdown itemizes each item.
	if breakdown.size() != 3:
		failures.append("Case1 breakdown has %d entries, expected 3" % breakdown.size())
	else:
		var sum_b: int = 0
		var ok_fields := true
		for e in breakdown:
			if not (e.has("id") and e.has("name") and e.has("value")):
				ok_fields = false
			sum_b += int(e.get("value", 0))
		if not ok_fields:
			failures.append("Case1 breakdown entries missing id/name/value fields")
		if sum_b != 60:
			failures.append("Case1 breakdown values sum to %d, expected 60" % sum_b)
		if breakdown[0].get("id", &"") != &"junk_a" or breakdown[0].get("name", "") != "Alpha":
			failures.append("Case1 breakdown[0] does not itemize the first item (id/name)")

	# === Case 2: empty-bag sale is a no-op ==================================
	gs.banked_junk = empty_junk.duplicate()
	var money_pre2: int = gs.money
	var events_pre2 := money_log.size()
	var empty_breakdown: Array = gs.sell_banked_junk()
	if not empty_breakdown.is_empty():
		failures.append("Case2 empty-bag sale returned %d entries, expected []" % empty_breakdown.size())
	if gs.money != money_pre2:
		failures.append("Case2 empty-bag sale changed money %d -> %d (should be no-op)" % [money_pre2, gs.money])
	if gs.banked_junk.size() != 0:
		failures.append("Case2 empty-bag sale left items in bank")
	# add_currency(0) still emits one event with delta 0; assert it's non-negative + tagged.
	if money_log.size() != events_pre2 + 1:
		failures.append("Case2 expected exactly one currency_changed(money) for the empty sale")
	elif money_log[money_log.size() - 1][0] != 0:
		failures.append("Case2 empty sale delta == %d, expected 0 (no negative)" % money_log[money_log.size() - 1][0])

	# === Case 3: source tag flows through (failed-run pockets sale) =========
	gs.banked_junk = empty_junk.duplicate()
	var p := _make_item(&"pocket_x", 7, "PocketX")
	var pocket_pile: Array[JunkItem] = [p]
	gs.banked_junk = pocket_pile
	var events_pre3 := money_log.size()
	gs.sell_banked_junk(&"pockets")
	if money_log.size() != events_pre3 + 1:
		failures.append("Case3 pockets sale did not fire exactly one currency_changed(money)")
	else:
		if money_log[money_log.size() - 1][0] != 7:
			failures.append("Case3 pockets sale delta == %d, expected 7" % money_log[money_log.size() - 1][0])
		if money_log[money_log.size() - 1][1] != &"pockets":
			failures.append("Case3 source tag == %s, expected &\"pockets\"" % str(money_log[money_log.size() - 1][1]))

	# === Case 4: Money persists through save_meta/load_meta round-trip ======
	# Set a known Money total + empty bank, save, perturb in memory, reload, assert.
	gs.banked_junk = empty_junk.duplicate()
	gs.money = 1234
	var err: int = sm.save_meta(0)
	if err != OK:
		failures.append("Case4 save_meta(0) returned error %d" % err)
	gs.money = 0   # perturb in-memory so load must restore it
	var loaded: Dictionary = sm.load_meta(0)
	if loaded.is_empty():
		failures.append("Case4 load_meta(0) returned empty (save did not round-trip)")
	if gs.money != 1234:
		failures.append("Case4 money after reload == %d, expected 1234 (did not persist)" % gs.money)

	# === Verdict ============================================================
	gs.banked_junk = empty_junk.duplicate()   # leave no meta residue for other harnesses
	gs.money = 0
	if failures.is_empty():
		print("MONEY LEDGER OK")
		quit(0)
	else:
		for f in failures:
			printerr("F1 FAIL: ", f)
		quit(1)
