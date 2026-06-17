class_name InventoryPanel
extends Control
## InventoryPanel (D2) — the player's keep/drop decision surface. PURE VIEW /
## PURE PROJECTION: it holds NO inventory truth. It reads GameState.run_inventory
## and rebuilds itself whenever EventBus.run_inventory_changed fires — never polls,
## never caches the model (so it cannot drift). Persistent HUD panel (always-on),
## per the D2 Open-questions recommendation: the carry decision happens in the
## moment, so capacity + contents stay visible without a keypress.
##
## Rebuild strategy: full clear-and-repopulate on every change (M1 item counts are
## tiny; the drop gesture is discrete with no held selection to preserve, so
## diffing is unnecessary — D2 Open questions).
##
## Readability (playbook): a "used / max slots" label + a fullness bar that shifts
## green→red, plus an explicit "BAG FULL" state driven from the SAME D1 truth
## (is_full()) that C2's pickup-rejected feedback uses, so the two surfaces agree.
## Empty placeholder cells are drawn (not omitted) so free space reads spatially.
##
## All player-facing strings go through tr() against keys in the localization CSV
## (ui/inventory/inventory_strings.csv) so nothing is hardcoded for translation.

@export var cell_scene: PackedScene  # ui/inventory/inventory_cell.tscn

@onready var capacity_label: Label = $Margin/VBox/CapacityHeader/CapacityLabel
@onready var capacity_bar: ProgressBar = $Margin/VBox/CapacityHeader/CapacityBar
@onready var grid: GridContainer = $Margin/VBox/Grid

const COLOR_EMPTY := Color(0.4, 0.9, 0.4)
const COLOR_FULL := Color(0.95, 0.3, 0.3)


func _ready() -> void:
	EventBus.run_inventory_changed.connect(_on_inventory_changed)
	# A run boundary swaps the underlying bag (start_run builds a fresh one;
	# end_run/clear leaves it null-or-empty) WITHOUT going through try_add, so the
	# panel re-projects on those edges too — otherwise it would lag a whole run.
	EventBus.run_started.connect(_on_run_boundary)
	EventBus.run_ended.connect(_on_run_boundary)
	_refresh()  # paint initial state (empty bag at run start, or "no run")


func _on_inventory_changed(_used: int, _max_slots: int) -> void:
	# Signal-driven: a single entry point keeps the view from drifting. The args
	# are authoritative but we re-read the model so cell rebuild and bar agree.
	_refresh()


func _on_run_boundary(_a = null, _b = null, _c = null) -> void:
	# Variadic-tolerant: run_started(band, seed) and run_ended(reason, dur, depth)
	# carry different arg counts; the panel ignores them and re-reads the model.
	_refresh()


func _refresh() -> void:
	var inv: RunInventory = GameState.run_inventory
	if inv == null:
		# Between runs there is no bag. Show an empty, non-misleading panel.
		_clear_grid()
		capacity_label.text = tr("INV_NO_RUN")
		capacity_bar.max_value = 1.0
		capacity_bar.value = 0.0
		capacity_bar.modulate = COLOR_EMPTY
		return
	_rebuild_cells(inv)
	_update_capacity(inv)


func _clear_grid() -> void:
	# queue_free (deferred) rather than free()/remove_child: a rebuild can be
	# triggered from inside a cell's own drop_requested emission, and a node that
	# is mid-signal is locked — detaching or freeing it synchronously errors. The
	# old cells leave the tree next frame; new cells are appended now, so for one
	# frame the grid holds both. Listeners that inspect the grid should do so after
	# a process frame (the headless test awaits one). Stale cells are hidden so the
	# transient frame does not show doubled content.
	for child in grid.get_children():
		var c := child as CanvasItem
		if c != null:
			c.visible = false
		child.queue_free()


func _rebuild_cells(inv: RunInventory) -> void:
	_clear_grid()
	# One cell per item (count model). The cell shows the greybox shape, $value,
	# and a slot-cost badge when slot_size > 1 — see D2 Open questions.
	for i in inv.items.size():
		var item: JunkItem = inv.items[i]
		if item == null:
			continue
		var cell := cell_scene.instantiate() as InventoryCell
		grid.add_child(cell)
		cell.set_item(item, i)
		cell.drop_requested.connect(_on_cell_drop_requested)
	# Render free_slots() empty placeholder cells so remaining room is visible.
	for _i in inv.free_slots():
		var empty := cell_scene.instantiate() as InventoryCell
		grid.add_child(empty)
		empty.set_empty()


func _update_capacity(inv: RunInventory) -> void:
	var used: int = inv.used_slots()
	var max_slots: int = inv.max_slots
	var t: float = float(used) / float(maxi(max_slots, 1))
	capacity_bar.max_value = max_slots
	capacity_bar.value = used
	if inv.is_full():
		# Explicit FULL state — same predicate (is_full) C2 uses to reject pickup,
		# so the bag and the ground prompt never disagree. Redundant non-colour
		# cue: the word "FULL" plus the pinned-red bar.
		capacity_label.text = tr("INV_FULL").format(
			{"used": used, "max": max_slots})
		capacity_bar.modulate = COLOR_FULL
	else:
		capacity_label.text = tr("INV_CAPACITY").format(
			{"used": used, "max": max_slots})
		capacity_bar.modulate = COLOR_EMPTY.lerp(COLOR_FULL, t)


# Drop gesture from a cell: remove from the MODEL (the single source of truth).
# That fires run_inventory_changed → _refresh rebuilds the grid. Re-spawning the
# dropped JunkPickup in the world is C2's job (handoff noted in the worklog).
func _on_cell_drop_requested(index: int) -> void:
	var inv: RunInventory = GameState.run_inventory
	if inv == null:
		return
	inv.remove_at(index)
