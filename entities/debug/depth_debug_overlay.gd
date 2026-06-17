class_name DepthDebugOverlay
extends Node2D
## DepthDebugOverlay — visualises the B3 depth axis for the "is the rise visible?"
## smoke check. Draws, per piece, its depth_index / dist_to_gate and the total
## planned junk value placed there; and a greybox marker per planned item, sized
## and tinted so deeper/richer junk reads bigger at a glance.
##
## VISUALISATION ONLY. The authoritative interactive pickup is C2's JunkPickup;
## these markers are throwaway debug squares (entities/debug), never gameplay.
##
## Usage (debug scene or tool):
##   var ov := DepthDebugOverlay.new()
##   ov.setup(band, plan, cell_size_px)
##   add_child(ov)

const _LABEL_FONT_SIZE := 8
const _MARKER_MIN := 3.0
const _MARKER_MAX := 9.0

var _band: Band
var _plan: Array = []
var _cell_size_px: int = 16
var _max_value: int = 1  # for marker-size normalisation


## Bind the data and refresh the draw. Call after grading + planning.
func setup(band: Band, plan: Array, cell_size_px: int = 16) -> void:
	_band = band
	_plan = plan
	_cell_size_px = cell_size_px
	_max_value = 1
	for e in _plan:
		var item: JunkItem = e["item"]
		_max_value = maxi(_max_value, item.base_sell_value)
	queue_redraw()


func _draw() -> void:
	if _band == null:
		return

	# Per-piece value totals (for the per-piece label).
	var piece_value := {}  # piece_index -> total planned value
	for e in _plan:
		var depth: int = e["depth"]
		piece_value[depth] = int(piece_value.get(depth, 0)) + int((e["item"] as JunkItem).base_sell_value)

	var font := ThemeDB.fallback_font

	# Piece labels at each piece's first floor cell.
	for p in _band.pieces:
		if p.floor_cells.is_empty():
			continue
		var anchor := Vector2(p.floor_cells[0] * _cell_size_px) + Vector2(2, 10)
		var total := int(piece_value.get(p.depth_index, 0))
		var txt := "d=%d  home=%d  $%d" % [p.depth_index, p.dist_to_gate, total]
		draw_string(font, anchor, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, _LABEL_FONT_SIZE, Color.WHITE)

	# Junk markers: square sized by value, tinted by the template colour.
	for e in _plan:
		var item: JunkItem = e["item"]
		var pos: Vector2 = e["world_pos"]
		var t := float(item.base_sell_value) / float(_max_value)
		var half := lerpf(_MARKER_MIN, _MARKER_MAX, clampf(t, 0.0, 1.0))
		var rect := Rect2(pos - Vector2(half, half), Vector2(half, half) * 2.0)
		draw_rect(rect, item.greybox_color, true)
		draw_rect(rect, Color.BLACK, false, 1.0)
