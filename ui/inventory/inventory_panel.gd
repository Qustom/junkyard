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

# --- L1 (M1.5) throw-selector highlight (run-state VIEW only; never touches the
# model truth). The panel tracks which RunInventory.items index is highlighted; the
# throw seam in main_game reads it via highlighted_index()/highlighted_item(). Q/E
# (highlight_left/right) move it with modulo wrap; the index is re-validated whenever
# the inventory contents change (a throw shrinks the bag) so it never points at a
# freed slot. -1 == nothing highlighted (empty bag). The panel stays a PURE VIEW: it
# exposes only getters + reads input to move the selector; the model mutation
# (remove_at) and the throw itself live in main_game (the orchestrator).
var _highlight_index: int = -1


func _ready() -> void:
	EventBus.run_inventory_changed.connect(_on_inventory_changed)
	# A run boundary swaps the underlying bag (start_run builds a fresh one;
	# end_run/clear leaves it null-or-empty) WITHOUT going through try_add, so the
	# panel re-projects on those edges too — otherwise it would lag a whole run.
	EventBus.run_started.connect(_on_run_boundary)
	EventBus.run_ended.connect(_on_run_boundary)
	_refresh()  # paint initial state (empty bag at run start, or "no run")


# --- L1 (M1.5): throw-selector read seam + navigation -------------------------

## The currently-highlighted index into RunInventory.items, or -1 if nothing is
## highlighted (empty bag / no run). The throw seam (main_game) reads this.
func highlighted_index() -> int:
	return _highlight_index


## The currently-highlighted JunkItem, or null. Null-safe against an empty/stale bag.
func highlighted_item() -> JunkItem:
	var inv: RunInventory = GameState.run_inventory
	if inv == null or _highlight_index < 0 or _highlight_index >= inv.items.size():
		return null
	return inv.items[_highlight_index]


## Q/E navigate the selector. unhandled (not _gui_input) so it fires even though the
## cells eat clicks; just_pressed via is_action_pressed so a held key steps once.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"highlight_left"):
		_move_highlight(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"highlight_right"):
		_move_highlight(1)
		get_viewport().set_input_as_handled()


## Move the highlight by `step` (+1 = right, -1 = left) with modulo wrap in both
## directions. No-op on an empty bag (stays -1).
func _move_highlight(step: int) -> void:
	var inv: RunInventory = GameState.run_inventory
	var n: int = 0 if inv == null else inv.items.size()
	if n == 0:
		_highlight_index = -1
		return
	if _highlight_index < 0:
		_highlight_index = 0
	else:
		_highlight_index = ((_highlight_index + step) % n + n) % n   # wrap both ways
	_apply_highlight_visual()


## Re-validate the highlight after the inventory contents changed. A throw shrinks
## the bag, so CLAMP (not modulo) into range — landing on the new last item is more
## intuitive than wrapping to slot 0 (RD-4). Empty bag → -1; first non-empty → 0.
func _revalidate_highlight() -> void:
	var inv: RunInventory = GameState.run_inventory
	var n: int = 0 if inv == null else inv.items.size()
	if n == 0:
		_highlight_index = -1
	elif _highlight_index < 0:
		_highlight_index = 0
	else:
		_highlight_index = clampi(_highlight_index, 0, n - 1)


## Push the highlighted flag onto each item cell. Item cells are appended in
## RunInventory.items order (then the empty placeholders), so the i-th item cell
## maps to items index i.
func _apply_highlight_visual() -> void:
	var i: int = 0
	for child in grid.get_children():
		var cell := child as InventoryCell
		if cell == null or cell.is_empty() or not cell.visible:
			continue   # skip empty placeholders + the stale (hidden) cells of a pending rebuild
		cell.set_highlighted(i == _highlight_index)
		i += 1


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
		_highlight_index = -1   # L1: no bag → nothing highlighted
		_clear_grid()
		capacity_label.text = tr("INV_NO_RUN")
		capacity_bar.max_value = 1.0
		capacity_bar.value = 0.0
		capacity_bar.modulate = COLOR_EMPTY
		return
	_rebuild_cells(inv)
	_update_capacity(inv)
	# L1 (M1.5): re-validate the throw selector against the (possibly shrunk/grown)
	# bag and re-apply the highlight border to the freshly-built cells.
	_revalidate_highlight()
	_apply_highlight_visual()


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
# That fires run_inventory_changed → _refresh rebuilds the grid. THEN emit
# EventBus.junk_dropped(item, world_pos) so C2's JunkSpawner (already subscribed)
# re-spawns a re-grabbable JunkPickup at the drop position — closing drop-to-swap
# (D3). Removal happens FIRST so the item is never both carried AND on the ground
# (swap integrity); we capture the removed JunkItem from remove_at's return value.
func _on_cell_drop_requested(index: int) -> void:
	var inv: RunInventory = GameState.run_inventory
	if inv == null:
		return
	var dropped: JunkItem = inv.remove_at(index)
	if dropped == null:
		# Stale/invalid index (e.g. a rebuild raced the gesture) — nothing was
		# removed, so there is nothing to re-spawn. Do NOT emit a phantom drop.
		return
	# Drop where the player is standing ("I dropped it where I'm standing"). The
	# panel is a Control with no world transform, so we resolve the player's world
	# position from the scene tree (see _player_world_pos). The spawner only acts
	# when a band drop-container is registered, so an unresolved player (e.g. the
	# inventory open outside a live dive) harmlessly re-spawns nothing.
	EventBus.junk_dropped.emit(dropped, _player_world_pos())


# Resolve the active player's world position as the drop point. The player joins
# the "player" group (added in player.tscn for G3's assembled dive scene), so the
# drop lookup is an O(1) group query instead of a current_scene tree-walk (close-out
# reapply note W4-6). Returns Vector2.ZERO when no player is in the tree (between
# dives / tests) — the spawner ignores the emit in that case (no drop-container
# registered), so the fallback is inert rather than dropping junk at the origin.
func _player_world_pos() -> Vector2:
	var tree := get_tree()
	if tree == null:
		return Vector2.ZERO
	var player := tree.get_first_node_in_group(&"player") as Node2D
	if player != null:
		return player.global_position
	return Vector2.ZERO
