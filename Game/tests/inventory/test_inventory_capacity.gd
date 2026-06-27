extends GdUnitTestSuite
## G2 — inventory capacity (D1 RunInventory).
##
## The count-based slot model locked for M1: items occupy `slot_size` slots,
## capacity is summed against `max_slots`, a full bag blocks pickup, and only
## PLACEABLE items are accepted. Real API (M1_As_Built): RunInventory.new() then
## set max_slots; try_add(JunkItem)->bool, can_accept(JunkItem)->bool (pure),
## used_slots()/free_slots()/is_full(), remove_at()/remove(). There is no
## Inventory.new(capacity) ctor or {"id","value"} dict items as the stale spec
## sketch shows — items are JunkItem resources and value is base_sell_value.

const PLACEABLE := JunkItem.ContainmentFlag.PLACEABLE


func _item(size: int, value: int, flags: int = PLACEABLE) -> JunkItem:
	var it := JunkItem.new()
	it.slot_size = size
	it.base_sell_value = value
	it.containment_flags = flags
	return it


func _inv(max_slots: int) -> RunInventory:
	var inv := RunInventory.new()
	inv.max_slots = max_slots
	return inv


func test_add_within_capacity() -> void:
	var inv := _inv(3)
	assert_bool(inv.try_add(_item(1, 12))).is_true()
	assert_int(inv.items.size()).is_equal(1)
	assert_int(inv.used_slots()).is_equal(1)
	assert_int(inv.free_slots()).is_equal(2)
	assert_bool(inv.is_full()).is_false()


func test_fill_exactly_to_capacity() -> void:
	# Two size-1 + one size-2 == 4 slots exactly fills a 4-slot bag.
	var inv := _inv(4)
	assert_bool(inv.try_add(_item(1, 5))).is_true()
	assert_bool(inv.try_add(_item(1, 5))).is_true()
	assert_bool(inv.try_add(_item(2, 5))).is_true()
	assert_int(inv.used_slots()).is_equal(4)
	assert_bool(inv.is_full()).is_true()


func test_reject_over_capacity_full_bag() -> void:
	var inv := _inv(2)
	inv.try_add(_item(1, 5))
	inv.try_add(_item(1, 5))
	# Full bag MUST reject the next item and stay unmutated (acceptance criterion).
	assert_bool(inv.try_add(_item(1, 5))).is_false()
	assert_int(inv.items.size()).is_equal(2)
	assert_int(inv.used_slots()).is_equal(2)


func test_reject_item_too_big_for_remaining_space() -> void:
	# 2 used, 1 free -> a size-2 item does not fit even though the bag isn't full.
	var inv := _inv(3)
	inv.try_add(_item(2, 5))
	assert_bool(inv.try_add(_item(2, 5))).is_false()
	assert_int(inv.used_slots()).is_equal(2)


func test_can_accept_is_pure() -> void:
	# Pure predicate: no mutation, no append. (Signal silence is covered by the
	# legacy D1 scene test, which can observe EventBus; here we assert no state change.)
	var inv := _inv(5)
	var probe := _item(1, 10)
	assert_bool(inv.can_accept(probe)).is_true()
	assert_int(inv.items.size()).is_equal(0)
	assert_int(inv.used_slots()).is_equal(0)


func test_non_placeable_rejected_at_gate() -> void:
	var inv := _inv(10)
	var not_placeable := _item(1, 10, JunkItem.ContainmentFlag.NONE)
	assert_bool(inv.can_accept(not_placeable)).is_false()
	assert_bool(inv.try_add(not_placeable)).is_false()


func test_can_accept_null_is_safe() -> void:
	var inv := _inv(10)
	assert_bool(inv.can_accept(null)).is_false()


func test_remove_at_is_index_safe() -> void:
	var inv := _inv(6)
	var keep := _item(1, 10)
	var drop := _item(2, 20)
	inv.try_add(keep)
	inv.try_add(drop)
	assert_object(inv.remove_at(1)).is_equal(drop)
	assert_int(inv.items.size()).is_equal(1)
	assert_object(inv.items[0]).is_equal(keep)
	assert_object(inv.remove_at(99)).is_null()    # out-of-range -> null, no crash


func test_remove_by_identity() -> void:
	var inv := _inv(6)
	var a := _item(1, 10)
	inv.try_add(a)
	assert_bool(inv.remove(a)).is_true()
	assert_bool(inv.remove(a)).is_false()         # already gone


func test_total_carried_value_via_used_slots_and_items() -> void:
	# Carried VALUE is summed by GameState.run_haul_value() over items, but the
	# inventory itself tracks slot occupancy; verify both totals stay correct.
	var inv := _inv(8)
	inv.try_add(_item(1, 12))
	inv.try_add(_item(2, 30))
	var value := 0
	for it in inv.items:
		value += it.base_sell_value
	assert_int(value).is_equal(42)
	assert_int(inv.used_slots()).is_equal(3)
