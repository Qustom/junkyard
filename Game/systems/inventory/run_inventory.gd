class_name RunInventory
extends RefCounted
## RunInventory — the run-state truth of "what is currently carried" (D1).
##
## A small, total inventory model: items occupy slots by `slot_size`, capacity is
## enforced by summing footprint against `max_slots`, and a full bag blocks pickup.
## This is the count-based model locked in for M1 (D1 spec, Open questions): the
## carry-choice tension comes from value-vs-space, not from spatial packing.
##
## Boundary (TDD §2/§3): this is RUN-STATE. It is constructed fresh in
## GameState.start_run() and wiped on run end — never banked, never persisted.
## It knows about JunkItem (data) and EventBus (signal) and nothing else: no UI,
## no world entities. Consumers reach it through GameState.run_inventory and react
## to EventBus.run_inventory_changed.
##
## M1 simplifications (deliberate, see D1 Open questions):
##   - Flat top-level slots, no nesting (but the PLACEABLE gate is honored).
##   - No stacking: each piece occupies its own slot(s).
##   - Carried items are shared refs to the catalog .tres (no per-instance state
##     yet). remove_at() is index-safe and remove() matches by object identity,
##     rather than relying on value identity, so the later switch to duplicated
##     per-instance items stays a localized change.

var max_slots: int = 12
var items: Array[JunkItem] = []   # carried junk (run-state truth)


## Emit the inventory-changed signal through the EventBus autoload.
## Resolved via the live SceneTree (not the compile-time `EventBus` global) so the
## model compiles and runs when loaded standalone — e.g. a `--script` test harness,
## where autoload *names* aren't registered as globals but the autoload Node still
## exists in the tree. In the normal booted project this is the same EventBus node.
func _emit_changed(used: int) -> void:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var bus := (loop as SceneTree).root.get_node_or_null("EventBus")
		if bus != null:
			bus.run_inventory_changed.emit(used, max_slots)


func used_slots() -> int:
	var total: int = 0
	for it in items:
		if it != null:
			total += it.slot_size
	return total


func free_slots() -> int:
	return max_slots - used_slots()


func is_full() -> bool:
	return free_slots() <= 0


## Pure predicate — no mutation, no side effects. Safe for UI/AI to ask.
## Rejects null, non-PLACEABLE items, and anything that doesn't fit.
func can_accept(item: JunkItem) -> bool:
	if item == null:
		return false
	if not (item.containment_flags & JunkItem.ContainmentFlag.PLACEABLE):
		return false
	return item.slot_size <= free_slots()


## Mutating add. Returns whether the item was accepted.
## C2's pickup calls this and only removes the world entity on `true`.
func try_add(item: JunkItem) -> bool:
	if not can_accept(item):
		return false
	items.append(item)
	_emit_changed(used_slots())
	return true


## Index-safe removal — preferred entry point from D2 (the cell the player
## clicked maps to an array index). Returns the removed item, or null on a bad
## index. Index identity is robust to duplicate shared refs in a way find() is not.
func remove_at(index: int) -> JunkItem:
	if index < 0 or index >= items.size():
		return null
	var removed: JunkItem = items[index]
	items.remove_at(index)
	_emit_changed(used_slots())
	return removed


## Instance-safe removal of a specific item reference. Matches by object identity
## (find()), which is correct for distinct instances; for duplicate shared refs it
## removes the first matching instance (harmless for identical M1 junk). Prefer
## remove_at() when the caller knows the slot position.
func remove(item: JunkItem) -> bool:
	if item == null:
		return false
	var idx: int = items.find(item)
	if idx == -1:
		return false
	items.remove_at(idx)
	_emit_changed(used_slots())
	return true


## Wipe the bag at run end. Always emits so listeners reset to empty.
func clear_run() -> void:
	items.clear()
	_emit_changed(0)
