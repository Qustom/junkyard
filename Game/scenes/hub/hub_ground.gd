class_name HubGround
extends TileMapLayer
## HubGround (M1.8 H1) — paints the dressed Layout-A vertical-spine floor for the static
## surface Hub. Pure presentation: a deterministic, RNG-FREE programmatic paint (the hub is
## an authored room, not a generated band — it must NOT touch the RNG autoload, which is
## reserved for reproducible proc-gen). Reads/writes no game state.
##
## The spine, south(+y)→north(-y), mirrors staging_area_layout_a_dressed.md §1:
##   • south street edge   → asphalt  `=` (tiles 00/08)
##   • open yard (middle)   → packed dirt `.` (tiles 05/13)  ← central lane stays cleanest
##   • north clutter fringe → dirt-litter `░` (tiles 14/15)
##   • the framing border   → scrap-wall `~` (tiles 02/06/10), under the wall colliders
##
## Variant selection is a fixed hash of the cell coords (NOT RNG) so the floor doesn't
## visibly repeat yet is byte-identical every run. The hub_ground.tres TileSet exposes one
## 32×32 tile per source, source_id == tile index (0..15), tile coord (0,0).

## Source ids in hub_ground.tres == the ground_tile_NN index.
const ASPHALT: Array[int] = [0, 8]            # `=`
const DIRT: Array[int] = [5, 13]              # `.`
const LITTER: Array[int] = [14, 15]           # `░`
const SCRAP: Array[int] = [2, 6, 10]          # `~`

## Cell grid covering the room interior (room is 760×488 px; 32px cells). We paint a
## 24×16 block centred on origin (cx -12..11, cy -8..7) so the floor fully underlaps the
## walls. The outermost ring reads as the scrap-wall border (the wall colliders sit on it).
const CX_MIN: int = -12
const CX_MAX: int = 11
const CY_MIN: int = -8
const CY_MAX: int = 7

## The central walking lane (spawn→shack→gate) is kept cleanest: these columns never get
## litter, only plain dirt, so the path always reads (layout §1, "keep the centre lane
## cleanest").
const LANE_HALF_WIDTH: int = 3   # cells either side of cx==0 stay clean dirt


func _ready() -> void:
	_paint()


## Deterministic, order-independent variant pick. A cheap integer hash of (cx, cy) folded
## into the palette length — NOT RNG. Same coords → same tile, forever.
func _variant(cx: int, cy: int, palette: Array[int]) -> int:
	var h: int = (cx * 73856093) ^ (cy * 19349663)
	h = (h ^ (h >> 13)) & 0x7fffffff
	return palette[h % palette.size()]


func _paint() -> void:
	clear()
	for cy in range(CY_MIN, CY_MAX + 1):
		for cx in range(CX_MIN, CX_MAX + 1):
			var source_id: int = _pick(cx, cy)
			set_cell(Vector2i(cx, cy), source_id, Vector2i(0, 0))


## Band assignment for a cell. North (-y, smaller cy) is the dangerous/grubby end; south
## (+y, larger cy) is the safe street edge.
func _pick(cx: int, cy: int) -> int:
	# Border ring → scrap-wall (under the wall colliders).
	if cx == CX_MIN or cx == CX_MAX or cy == CY_MIN or cy == CY_MAX:
		return _variant(cx, cy, SCRAP)

	# South street edge: the bottom two interior rows are asphalt.
	if cy >= CY_MAX - 2:
		return _variant(cx, cy, ASPHALT)

	# North clutter fringe: top interior rows thicken with litter — EXCEPT the central lane,
	# which stays clean dirt so the path to the gate always reads.
	var in_lane: bool = absi(cx) <= LANE_HALF_WIDTH
	if cy <= CY_MIN + 2 and not in_lane:
		return _variant(cx, cy, LITTER)

	# Everything else (the open yard + the clean central lane) is packed dirt.
	return _variant(cx, cy, DIRT)
