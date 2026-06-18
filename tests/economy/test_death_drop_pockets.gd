extends GdUnitTestSuite
## G2 — death/timeout pockets math (E3 fail_run, ratified decision #13).
##
## On death/timeout the player keeps WHOLE items up to a value budget =
## floor(run_haul_value() * pockets_fraction), chosen by `pockets_policy`
## (HIGHEST_VALUE: best find first), and loses the rest. This is NOT the stale
## spec's int(carry * fraction) scalar — kept value is the sum of whole items that
## fit the budget, so F2 can itemize exactly what survived. The shipped design
## value is pockets_fraction = 0.20 (decision #13 supersedes the spec open-Q's
## stale POCKET_FRACTION = 0.0 recommendation).
##
## We pin a fresh RunRules (0.20 / HIGHEST_VALUE) onto GameState so the budget math
## is deterministic regardless of the authored .tres, and separately assert the
## authored run_rules.tres carries the shipped defaults. Meta is snapshot/restored.

const PLACEABLE := JunkItem.ContainmentFlag.PLACEABLE

var _banked_log: Array = []
var _ended_log: Array = []
var _money_before := 0
var _banked_junk_before: Array[JunkItem] = []
var _rules_before: RunRules
var _on_banked: Callable
var _on_ended: Callable


func _item(id: StringName, value: int, size: int = 1) -> JunkItem:
	var it := JunkItem.new()
	it.id = id
	it.slot_size = size
	it.base_sell_value = value
	it.containment_flags = PLACEABLE
	return it


func before_test() -> void:
	_banked_log = []
	_ended_log = []
	_on_banked = func(total: int) -> void: _banked_log.append(total)
	_on_ended = func(reason: StringName, dur: float, depth: int) -> void:
		_ended_log.append([reason, dur, depth])
	EventBus.haul_banked.connect(_on_banked)
	EventBus.run_ended.connect(_on_ended)

	_money_before = GameState.money
	_banked_junk_before = GameState.banked_junk.duplicate()
	_rules_before = GameState.run_rules
	var empty: Array[JunkItem] = []
	GameState.banked_junk = empty.duplicate()

	# Deterministic budget math, independent of the authored .tres tuning.
	var rules := RunRules.new()
	rules.pockets_fraction = 0.20
	rules.pockets_policy = RunRules.PocketsPolicy.HIGHEST_VALUE
	GameState.run_rules = rules


func after_test() -> void:
	EventBus.haul_banked.disconnect(_on_banked)
	EventBus.run_ended.disconnect(_on_ended)
	GameState.banked_junk = _banked_junk_before.duplicate()
	GameState.money = _money_before
	GameState.run_rules = _rules_before


func test_highest_value_pocket_kept_rest_lost() -> void:
	# Items 100,30,20,10,5 -> pre 165, budget floor(165*0.20)=33.
	# HIGHEST_VALUE order: 100(>33 skip), 30(keep), 20(30+20=50>33 skip),
	# 10(40>33 skip), 5(35>33 skip) -> kept {30}, kept_value 30.
	GameState.start_run(&"near", 4242)
	GameState.run_inventory.try_add(_item(&"j100", 100))
	var j30 := _item(&"j30", 30)
	GameState.run_inventory.try_add(j30)
	GameState.run_inventory.try_add(_item(&"j20", 20))
	GameState.run_inventory.try_add(_item(&"j10", 10))
	GameState.run_inventory.try_add(_item(&"j5", 5))
	var bag := GameState.run_inventory

	GameState.fail_run(&"death")

	assert_int(GameState.banked_junk.size()).is_equal(1)
	assert_object(GameState.banked_junk[0]).is_equal(j30)
	assert_int(bag.items.size()).is_equal(0)          # lost remainder never survives
	assert_int(_banked_log.size()).is_equal(1)
	assert_int(_banked_log[0]).is_equal(30)           # haul_banked == kept value
	assert_object(_ended_log[0][0]).is_equal(&"death")
	assert_bool(GameState.run_active).is_false()


func test_timeout_routes_through_same_path() -> void:
	# Items 50,40 -> pre 90, budget floor(90*0.20)=18. Both exceed 18 -> kept {}.
	GameState.start_run(&"near", 99)
	GameState.run_inventory.try_add(_item(&"k50", 50))
	GameState.run_inventory.try_add(_item(&"k40", 40))
	GameState.fail_run(&"timeout")
	assert_int(GameState.banked_junk.size()).is_equal(0)
	assert_int(_banked_log[0]).is_equal(0)
	assert_object(_ended_log[0][0]).is_equal(&"timeout")


func test_zero_carry_is_safe() -> void:
	# Empty-bag fail keeps nothing but still ends the run (valid).
	GameState.start_run(&"near", 7)
	GameState.fail_run(&"death")
	assert_int(GameState.banked_junk.size()).is_equal(0)
	assert_int(_ended_log.size()).is_equal(1)
	assert_object(_ended_log[0][0]).is_equal(&"death")


func test_cheapest_item_exceeds_budget_keeps_nothing() -> void:
	# Single 100-value item -> pre 100, budget 20; the only item (100) > 20 -> {}.
	GameState.start_run(&"near", 5)
	GameState.run_inventory.try_add(_item(&"only", 100))
	GameState.fail_run(&"death")
	assert_int(GameState.banked_junk.size()).is_equal(0)
	assert_int(_banked_log[0]).is_equal(0)


func test_double_fail_is_idempotent() -> void:
	# Items 100,10 -> pre 110, budget 22. 100>22 skip, 10<=22 keep -> {10}.
	GameState.start_run(&"near", 11)
	GameState.run_inventory.try_add(_item(&"d100", 100))
	GameState.run_inventory.try_add(_item(&"d10", 10))
	GameState.fail_run(&"death")
	var banked_after_first := GameState.banked_junk.size()
	GameState.fail_run(&"timeout")   # second call must be a no-op (run-end guard)
	assert_int(GameState.banked_junk.size()).is_equal(banked_after_first)
	assert_int(_ended_log.size()).is_equal(1)
	assert_int(_banked_log.size()).is_equal(1)


func test_extract_wins_a_tie_over_fail() -> void:
	# Extract resolves first -> banks ALL; a same-frame fail is the tie loser (no-op).
	GameState.start_run(&"near", 13)
	GameState.run_inventory.try_add(_item(&"e80", 80))
	GameState.extract_and_end_run()
	var banked_after_extract := GameState.banked_junk.size()
	GameState.fail_run(&"timeout")
	assert_int(GameState.banked_junk.size()).is_equal(banked_after_extract)
	assert_int(banked_after_extract).is_equal(1)
	assert_object(_ended_log[_ended_log.size() - 1][0]).is_equal(&"extract")


func test_authored_run_rules_carries_shipped_defaults() -> void:
	# The .tres the game actually ships with: pockets_fraction 0.20, HIGHEST_VALUE.
	var authored := load("res://data/economy/run_rules.tres") as RunRules
	assert_object(authored).is_not_null()
	assert_float(authored.pockets_fraction).is_equal_approx(0.20, 0.0001)
	assert_int(authored.pockets_policy).is_equal(RunRules.PocketsPolicy.HIGHEST_VALUE)
