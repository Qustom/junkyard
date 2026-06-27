extends GdUnitTestSuite
## G2 — banking math (E1 extract_and_end_run).
##
## On extract the run-state bag's item IDENTITIES move into meta `banked_junk`,
## the bag is wiped, haul_banked fires with the summed base_sell_value, and
## run_ended(&"extract") fires once. Money is NOT credited at the gate (decision
## #6 — F2's sell screen owns that). The stale spec sketch's Economy.bank(carry)/
## Economy.sell(n)/CURRENCY_RATE do not exist; the real, shipped surface is the
## GameState extract flow, asserted here.
##
## This suite touches the GameState / EventBus autoloads. GdUnit4's headless
## harness loads project autoloads (unlike `--script`, the very pain G2 fixes), so
## they resolve as globals. We snapshot + restore meta `banked_junk`/money so the
## suite leaves no residue for sibling suites.

const PLACEABLE := JunkItem.ContainmentFlag.PLACEABLE

var _banked_log: Array = []
var _ended_log: Array = []
var _money_before := 0
var _banked_junk_before: Array[JunkItem] = []
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
	# Snapshot meta so the suite is non-destructive to a real save/session.
	_money_before = GameState.money
	_banked_junk_before = GameState.banked_junk.duplicate()
	var empty: Array[JunkItem] = []
	GameState.banked_junk = empty.duplicate()


func after_test() -> void:
	EventBus.haul_banked.disconnect(_on_banked)
	EventBus.run_ended.disconnect(_on_ended)
	GameState.banked_junk = _banked_junk_before.duplicate()
	GameState.money = _money_before


func test_extract_banks_item_identities_to_meta() -> void:
	GameState.start_run(&"near", 4242)
	var a := _item(&"junk_a", 30)
	var b := _item(&"junk_b", 20, 2)
	GameState.run_inventory.try_add(a)
	GameState.run_inventory.try_add(b)
	var bag := GameState.run_inventory

	GameState.extract_and_end_run()

	assert_int(GameState.banked_junk.size()).is_equal(2)
	assert_bool(GameState.banked_junk.has(a)).is_true()
	assert_bool(GameState.banked_junk.has(b)).is_true()
	# Run-state bag wiped (never survives the extract).
	assert_int(bag.items.size()).is_equal(0)
	assert_bool(GameState.run_active).is_false()


func test_extract_haul_banked_value_no_drift() -> void:
	GameState.start_run(&"near", 1)
	GameState.run_inventory.try_add(_item(&"x", 30))
	GameState.run_inventory.try_add(_item(&"y", 20))
	GameState.run_inventory.try_add(_item(&"z", 87))
	GameState.extract_and_end_run()
	# haul_banked fires exactly once with the summed value (30+20+87=137).
	assert_int(_banked_log.size()).is_equal(1)
	assert_int(_banked_log[0]).is_equal(137)


func test_extract_emits_run_ended_extract_once() -> void:
	GameState.start_run(&"near", 2)
	GameState.run_inventory.try_add(_item(&"q", 10))
	GameState.extract_and_end_run()
	assert_int(_ended_log.size()).is_equal(1)
	assert_object(_ended_log[0][0]).is_equal(&"extract")


func test_extract_does_not_credit_money() -> void:
	# Decision #6: extract moves item identities, never Money. Money is unchanged.
	var money_at_start := GameState.money
	GameState.start_run(&"near", 3)
	GameState.run_inventory.try_add(_item(&"big", 999))
	GameState.extract_and_end_run()
	assert_int(GameState.money).is_equal(money_at_start)


func test_zero_haul_extract_is_valid() -> void:
	# Decision #7: bail out alive with nothing. Banks nothing, haul_banked(0),
	# run_ended(&"extract") still fires.
	GameState.start_run(&"near", 7)
	GameState.extract_and_end_run()
	assert_int(GameState.banked_junk.size()).is_equal(0)
	assert_int(_banked_log.size()).is_equal(1)
	assert_int(_banked_log[0]).is_equal(0)
	assert_int(_ended_log.size()).is_equal(1)
	assert_object(_ended_log[0][0]).is_equal(&"extract")


func test_sell_converts_banked_junk_to_money_at_base_value() -> void:
	# F1 cash-out: sell_banked_junk credits Money at each item's base_sell_value,
	# empties the bank, and returns the per-item breakdown. This is the only place
	# Money increments in the loop. Integer math, no drift.
	GameState.start_run(&"near", 9)
	GameState.run_inventory.try_add(_item(&"s1", 40))
	GameState.run_inventory.try_add(_item(&"s2", 60))
	GameState.extract_and_end_run()
	var money_pre := GameState.money

	var breakdown := GameState.sell_banked_junk(&"sell")

	assert_int(breakdown.size()).is_equal(2)
	assert_int(GameState.money).is_equal(money_pre + 100)
	assert_int(GameState.banked_junk.size()).is_equal(0)   # bank consumed by the sale
