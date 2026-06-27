extends SceneTree
## Headless verification for E3 — death / timeout drops haul (pockets fraction).
##
## Drives the real GameState autoload through the FAIL flow and asserts the E3
## acceptance criteria + the human design recommendations:
##   - fail_run keeps WHOLE items up to floor(pre_value * pockets_fraction),
##     HIGHEST_VALUE policy first, discards the rest (deterministic budget math),
##   - kept item identities are appended to meta `banked_junk` (same transfer as E1),
##   - haul_banked fires with the KEPT value (parity with extract),
##   - run_ended fires exactly once with reason &"death" / &"timeout" (reused
##     lifecycle, no parallel run_end signal),
##   - run_inventory is wiped (the lost remainder never survives),
##   - empty-bag fail keeps nothing yet still ends the run (valid),
##   - the smallest-item-exceeds-budget edge keeps nothing (legible/fair),
##   - idempotency: double fail_run, and extract-then-fail, never double-bank or
##     double-emit run_ended (first run-end wins; extract wins a tie),
##   - meta money is UNCHANGED by a fail (F2 owns the sell, not E3).
## Run: godot --headless --script res://tests/test_death_drop.gd


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
		printerr("E3 FAIL: EventBus or GameState autoload missing")
		quit(1)
		return

	# --- Signal tracking -----------------------------------------------------
	var banked_log: Array = []
	eb.haul_banked.connect(func(total: int) -> void: banked_log.append(total))
	var ended_log: Array = []
	eb.run_ended.connect(func(reason: StringName, dur: float, depth: int) -> void:
		ended_log.append([reason, dur, depth]))

	var empty_junk: Array[JunkItem] = []

	# Pin tuning so the budget math is deterministic regardless of the authored
	# .tres (the .tres value is a separately-verified default).
	var rules := RunRules.new()
	rules.pockets_fraction = 0.20
	rules.pockets_policy = RunRules.PocketsPolicy.HIGHEST_VALUE
	gs.run_rules = rules

	# === Case 1: death drop, known budget math ==============================
	# Items 100,30,20,10,5 → pre_value 165, budget floor(165*0.20)=33.
	# HIGHEST_VALUE order: 100(>33 skip), 30(keep, spent 30), 20(30+20=50>33 skip),
	# 10(30+10=40>33 skip), 5(30+5=35>33 skip) → kept = {30}, kept_value=30.
	gs.banked_junk = empty_junk.duplicate()
	var money_before: int = gs.money
	gs.start_run(&"near", 4242)
	gs.run_inventory.try_add(_make_item(&"j100", 100))
	var j30 := _make_item(&"j30", 30)
	gs.run_inventory.try_add(j30)
	gs.run_inventory.try_add(_make_item(&"j20", 20))
	gs.run_inventory.try_add(_make_item(&"j10", 10))
	gs.run_inventory.try_add(_make_item(&"j5", 5))
	var bag_ref: RunInventory = gs.run_inventory

	var banked_count_before := banked_log.size()
	var ended_count_before := ended_log.size()
	gs.fail_run(&"death")

	if gs.banked_junk.size() != 1:
		failures.append("Case1 banked_junk size %d, expected 1 (kept {30})" % gs.banked_junk.size())
	elif gs.banked_junk[0] != j30:
		failures.append("Case1 kept the wrong item (expected j30=30)")
	if bag_ref.items.size() != 0:
		failures.append("Case1 run_inventory not wiped after fail (%d left)" % bag_ref.items.size())
	if banked_log.size() != banked_count_before + 1:
		failures.append("Case1 haul_banked did not fire exactly once")
	elif banked_log[banked_log.size() - 1] != 30:
		failures.append("Case1 haul_banked == %d, expected kept_value 30" % banked_log[banked_log.size() - 1])
	if ended_log.size() != ended_count_before + 1:
		failures.append("Case1 run_ended did not fire exactly once")
	elif ended_log[ended_log.size() - 1][0] != &"death":
		failures.append("Case1 run_ended reason == %s, expected &\"death\"" % str(ended_log[ended_log.size() - 1][0]))
	if gs.money != money_before:
		failures.append("Case1 fail changed meta money %d -> %d (E3 must NOT convert to Money)"
			% [money_before, gs.money])
	if gs.run_active:
		failures.append("Case1 run_active still true after fail")

	# === Case 2: timeout cause routes through the same path =================
	# Items 50,40 → pre 90, budget floor(90*0.2)=18. 50>18 skip, 40>18 skip → kept {}.
	gs.banked_junk = empty_junk.duplicate()
	gs.start_run(&"near", 99)
	gs.run_inventory.try_add(_make_item(&"k50", 50))
	gs.run_inventory.try_add(_make_item(&"k40", 40))
	var ec2 := ended_log.size()
	var bc2 := banked_log.size()
	gs.fail_run(&"timeout")
	if gs.banked_junk.size() != 0:
		failures.append("Case2 kept %d items, expected 0 (cheapest exceeds budget)" % gs.banked_junk.size())
	if banked_log.size() != bc2 + 1 or banked_log[banked_log.size() - 1] != 0:
		failures.append("Case2 timeout did not fire haul_banked(0)")
	if ended_log.size() != ec2 + 1 or ended_log[ended_log.size() - 1][0] != &"timeout":
		failures.append("Case2 timeout did not fire run_ended(&\"timeout\")")

	# === Case 3: empty-bag fail is valid ====================================
	gs.banked_junk = empty_junk.duplicate()
	gs.start_run(&"near", 7)
	var ec3 := ended_log.size()
	var meta3: int = gs.banked_junk.size()
	gs.fail_run(&"death")
	if gs.banked_junk.size() != meta3:
		failures.append("Case3 empty-bag fail changed banked_junk (should keep nothing)")
	if ended_log.size() != ec3 + 1 or ended_log[ended_log.size() - 1][0] != &"death":
		failures.append("Case3 empty-bag fail did not still end the run")

	# === Case 4: idempotency — double fail_run ==============================
	gs.banked_junk = empty_junk.duplicate()
	gs.start_run(&"near", 11)
	gs.run_inventory.try_add(_make_item(&"d100", 100))  # budget 20 → keeps nothing, but still ends once
	gs.run_inventory.try_add(_make_item(&"d10", 10))    # 10 <= 20 → kept {10}
	var ec4 := ended_log.size()
	var bc4 := banked_log.size()
	gs.fail_run(&"death")
	var banked_after_first: int = gs.banked_junk.size()
	gs.fail_run(&"timeout")   # second call must be a no-op
	if gs.banked_junk.size() != banked_after_first:
		failures.append("Case4 double fail_run double-banked (%d -> %d)"
			% [banked_after_first, gs.banked_junk.size()])
	if ended_log.size() != ec4 + 1:
		failures.append("Case4 double fail_run fired run_ended %d times, expected 1" % (ended_log.size() - ec4))
	if banked_log.size() != bc4 + 1:
		failures.append("Case4 double fail_run fired haul_banked %d times, expected 1" % (banked_log.size() - bc4))

	# === Case 5: idempotency — extract wins a tie (extract then fail) =======
	gs.banked_junk = empty_junk.duplicate()
	gs.start_run(&"near", 13)
	gs.run_inventory.try_add(_make_item(&"e80", 80))
	var ec5 := ended_log.size()
	gs.extract_and_end_run()           # extract resolves first → banks ALL (1 item)
	var banked_after_extract: int = gs.banked_junk.size()
	gs.fail_run(&"timeout")            # same-frame tie loser → no-op
	if gs.banked_junk.size() != banked_after_extract:
		failures.append("Case5 fail-after-extract mutated banked_junk (%d -> %d); extract must win"
			% [banked_after_extract, gs.banked_junk.size()])
	if banked_after_extract != 1:
		failures.append("Case5 extract should have banked all 1 item, got %d" % banked_after_extract)
	if ended_log.size() != ec5 + 1:
		failures.append("Case5 extract+fail fired run_ended %d times, expected 1" % (ended_log.size() - ec5))
	elif ended_log[ended_log.size() - 1][0] != &"extract":
		failures.append("Case5 run_ended reason == %s, expected &\"extract\" (extract wins)"
			% str(ended_log[ended_log.size() - 1][0]))

	# === Case 6: authored run_rules.tres has the shipped defaults ===========
	var authored: RunRules = load("res://data/economy/run_rules.tres") as RunRules
	if authored == null:
		failures.append("Case6 run_rules.tres failed to load")
	else:
		if not is_equal_approx(authored.pockets_fraction, 0.20):
			failures.append("Case6 run_rules.tres pockets_fraction == %f, expected 0.20" % authored.pockets_fraction)
		if authored.pockets_policy != RunRules.PocketsPolicy.HIGHEST_VALUE:
			failures.append("Case6 run_rules.tres pockets_policy != HIGHEST_VALUE")

	# === Verdict ============================================================
	gs.banked_junk = empty_junk.duplicate()   # leave no meta residue for other harnesses
	if failures.is_empty():
		print("DEATH DROP OK")
		quit(0)
	else:
		for f in failures:
			printerr("E3 FAIL: ", f)
		quit(1)
