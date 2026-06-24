class_name InventoryCell
extends PanelContainer
## InventoryCell (D2) — one greybox slot cell. PURE VIEW: it renders a single
## JunkItem (or an empty placeholder) read straight from C1 data. It holds no
## inventory truth and never mutates GameState — the panel owns that. When the
## player triggers the drop gesture on an item cell, the cell only EMITS
## `drop_requested(index)`; the panel performs the actual RunInventory.remove_at.
##
## Readability (playbook §"readability rules"): every colour cue is backed by a
## redundant NON-colour channel so the cell reads without relying on hue —
##   - shape: greybox_shape (rect/circle/triangle/diamond) drawn distinctly,
##   - value: an always-on "$N" text readout (the keep/drop decision metric),
##   - footprint: a "Nslot"/"Nslots" badge when slot_size > 1 (count model),
##   - $/slot: a smaller subordinate line shown on hover/focus only.
## Empty cells draw a faint dashed outline so remaining capacity is spatially
## obvious even though, under the count model, one cell != one slot for big junk.

## Emitted when the player performs the deliberate drop gesture on an item cell.
## Carries the cell's array index into RunInventory.items (the panel removes it).
signal drop_requested(index: int)

@onready var greybox: Control = $VBox/Greybox
@onready var value_label: Label = $VBox/ValueLabel
@onready var slot_badge: Label = $SlotBadge
@onready var per_slot_label: Label = $VBox/PerSlotLabel

## Index of this cell's item within RunInventory.items. -1 for an empty cell
## (empty cells are non-interactive — there is nothing to drop).
var _index: int = -1
var _item: JunkItem = null

## L1 (M1.5): the throw-selector highlight. PURE VIEW state (the panel owns which
## index is highlighted; this cell only renders the on/off). Rendered as a bright
## whole-cell StyleBoxFlat border (a non-colour FRAME channel, distinct from the
## fill hue and the reject-flash red — readability rule). The theme-stylebox
## override is added/removed on toggle so an un-highlighted cell keeps the default
## PanelContainer look exactly.
var _highlighted: bool = false
## Border treatment for the highlighted cell (2px bright frame, transparent fill so
## the cell's existing greybox/value content shows through unchanged).
const _HIGHLIGHT_BORDER_PX := 2
const _HIGHLIGHT_BORDER_COLOR := Color(1.0, 0.95, 0.4)   # bright amber frame
var _highlight_stylebox: StyleBoxFlat = null


func _ready() -> void:
	# The Greybox child draws via this cell's _draw_greybox (no second script).
	greybox.draw.connect(_draw_greybox)
	mouse_filter = Control.MOUSE_FILTER_STOP
	per_slot_label.visible = false
	greybox.queue_redraw()


## L1 (M1.5): toggle the throw-selector highlight border on this cell. Pure view —
## holds no truth (the panel decides which index is highlighted and calls this). A
## bright whole-cell frame so the selected slot reads at a glance; removing the
## override restores the default PanelContainer styling exactly (no leak).
func set_highlighted(on: bool) -> void:
	if _highlighted == on:
		return
	_highlighted = on
	if on:
		if _highlight_stylebox == null:
			_highlight_stylebox = StyleBoxFlat.new()
			_highlight_stylebox.bg_color = Color(0, 0, 0, 0)   # transparent fill: content shows through
			_highlight_stylebox.set_border_width_all(_HIGHLIGHT_BORDER_PX)
			_highlight_stylebox.border_color = _HIGHLIGHT_BORDER_COLOR
		add_theme_stylebox_override("panel", _highlight_stylebox)
	else:
		remove_theme_stylebox_override("panel")


## Populate this cell as an occupied slot showing one carried item.
## `index` is the item's position in RunInventory.items (for the drop gesture).
func set_item(item: JunkItem, index: int) -> void:
	_item = item
	_index = index
	# tr() keeps the readout localizable; the value/number is the payload.
	value_label.text = tr("INV_CELL_VALUE").format({"value": item.base_sell_value})
	per_slot_label.text = tr("INV_CELL_PER_SLOT").format(
		{"per_slot": "%.1f" % item.value_per_slot()})
	if item.slot_size > 1:
		slot_badge.text = tr("INV_CELL_SLOTS").format({"slots": item.slot_size})
		slot_badge.visible = true
	else:
		slot_badge.visible = false
	tooltip_text = item.display_name
	if is_node_ready():
		greybox.queue_redraw()


## Populate this cell as an empty capacity placeholder (non-interactive).
func set_empty() -> void:
	_item = null
	_index = -1
	value_label.text = ""
	per_slot_label.text = ""
	slot_badge.visible = false
	tooltip_text = ""
	if is_node_ready():
		greybox.queue_redraw()


func is_empty() -> bool:
	return _item == null


# --- Drop gesture --------------------------------------------------------------
# Deliberate (right-click) so a stray left-click never dumps a valuable item.
# Re-spawning the dropped JunkPickup in the world is C2's job; D2 only removes it
# from the model (which fires run_inventory_changed and rebuilds the grid).
func _gui_input(event: InputEvent) -> void:
	if _item == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			drop_requested.emit(_index)
			accept_event()


# --- Hover reveals the secondary $/slot comparison metric ----------------------
func _on_mouse_entered() -> void:
	per_slot_label.visible = _item != null


func _on_mouse_exited() -> void:
	per_slot_label.visible = false


# --- Greybox draw (called from the Greybox child's `draw` signal) --------------
func _draw_greybox() -> void:
	var r := greybox.get_rect()
	var box := Rect2(Vector2.ZERO, r.size)
	if _item == null:
		# Empty slot: faint dashed-feel outline. Pure non-colour cue (no fill).
		_draw_empty_outline(box)
		return
	var col := _item.greybox_color
	var inset := box.grow(-4.0)
	match _item.greybox_shape:
		JunkItem.GreyboxShape.RECT:
			greybox.draw_rect(inset, col, true)
			greybox.draw_rect(inset, Color.BLACK, false, 2.0)
		JunkItem.GreyboxShape.CIRCLE:
			var c := inset.get_center()
			var rad: float = minf(inset.size.x, inset.size.y) * 0.5
			greybox.draw_circle(c, rad, col)
			greybox.draw_arc(c, rad, 0.0, TAU, 32, Color.BLACK, 2.0)
		JunkItem.GreyboxShape.TRIANGLE:
			var pts := PackedVector2Array([
				Vector2(inset.position.x + inset.size.x * 0.5, inset.position.y),
				Vector2(inset.position.x, inset.end.y),
				Vector2(inset.end.x, inset.end.y),
			])
			greybox.draw_colored_polygon(pts, col)
			greybox.draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 2.0)
		JunkItem.GreyboxShape.DIAMOND:
			var ctr := inset.get_center()
			var hx: float = inset.size.x * 0.5
			var hy: float = inset.size.y * 0.5
			var dpts := PackedVector2Array([
				Vector2(ctr.x, ctr.y - hy),
				Vector2(ctr.x + hx, ctr.y),
				Vector2(ctr.x, ctr.y + hy),
				Vector2(ctr.x - hx, ctr.y),
			])
			greybox.draw_colored_polygon(dpts, col)
			greybox.draw_polyline(dpts + PackedVector2Array([dpts[0]]), Color.BLACK, 2.0)


func _draw_empty_outline(box: Rect2) -> void:
	# Faint outline only — no fill — so empty space reads as "room left" by
	# brightness/fill (a non-colour channel), not by hue.
	greybox.draw_rect(box.grow(-3.0), Color(1, 1, 1, 0.18), false, 1.0)
