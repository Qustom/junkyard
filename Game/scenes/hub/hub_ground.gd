class_name HubGround
extends TileMapLayer
## HubGround (M1.8 H4 — 45° isometric re-dress) — paints the surface Hub floor as a
## diamond-isometric terrain. Pure presentation: a deterministic, RNG-FREE programmatic
## paint (the hub is an authored room, not a generated band — it must NOT touch the RNG
## autoload, which is reserved for reproducible proc-gen). Reads/writes no game state.
##
## hub_ground_iso.tres holds ONE 8×6 atlas (64×78 cells) of PixelLab 45° isometric
## tiles (create_tiles_pro, tile_view_angle=45): rows 0–1 junk/scrap variants, rows 2–3
## plain grass/dirt, rows 4–5 grass↔dirt edge transitions. Each source tile is
## re-canvased so its diamond FACE center (y≈28 of the 64px source) sits at the texture
## center — no per-tile texture_origin needed.
##
## Grid: TILE_LAYOUT_DIAMOND_DOWN, tile_size 64×32 — cell (cx,cy) sits at screen
## ((cx-cy)*32, (cx+cy)*16). Tile faces are ~42px tall, so southern tiles overlap
## northern skirts; the layer y-sorts (set in hub.tscn) so draw order is strictly N→S
## and the overlap hides the painterly diamond edges.
##
## Zones (screen space, matching the wall colliders): the walled yard rectangle is
## packed DIRT with scrap/tuft accents; everything beyond is overgrown GRASS with junk
## heaps; the yard boundary picks a directional grass-edge transition tile by which
## diamond neighbour is grass (corners → patchy mix), and grass cells touching the
## yard blend back with tuft/patchy tiles.

const SRC: int = 0

## Atlas tile indices (index = col + row*8; atlas coord = (idx % 8, idx / 8)).
const GRASS_PLAIN: Array[int] = [16, 17, 20, 25]
const GRASS_ACC: Array[int] = [21, 22, 18, 29]     # weeds / darker patches
const GRASS_FLOWERS: Array[int] = [23, 24, 28]
const GRASS_SCRAP: Array[int] = [0, 1, 2, 3, 4, 5] # junk heaps in the meadow
const DIRT_PLAIN: Array[int] = [26, 27]
const DIRT_ACC: Array[int] = [30, 31, 6]           # pebbles / footprints / rich dirt
const DIRT_SCRAP: Array[int] = [9, 10]             # tools / dark debris
const DIRT_TUFTS: int = 11
const PATCHY: int = 12
## Transition tiles: dirt face with grass creeping over ONE edge.
const TR_NW: int = 32
const TR_NE: int = 35
const TR_SW: int = 34
const TR_SE: int = 39

## Dirt-yard half-extent in screen px (matches the walled room bounds).
const YARD_X: int = 340
const YARD_Y: int = 216

## Cell iteration bounds: covers screen x ∈ [-640,640], y ∈ [-380,380] under the
## DIAMOND_DOWN mapping (fills the 1152×648 view at HubCamera zoom 1.05 with margin).
const C_MIN: int = -24
const C_MAX: int = 24


func _ready() -> void:
	_paint()


## Deterministic integer hash of a cell coord — NOT RNG. Same coords → same tile.
func _h32(x: int, y: int) -> int:
	var h: int = ((x * 73856093) ^ (y * 19349663)) & 0xFFFFFFFF
	h = (h ^ (h >> 13)) & 0x7fffffff
	return h


func _screen(cx: int, cy: int) -> Vector2i:
	return Vector2i((cx - cy) * 32, (cx + cy) * 16)


func _is_dirt(cx: int, cy: int) -> bool:
	var s := _screen(cx, cy)
	return absi(s.x) <= YARD_X and absi(s.y) <= YARD_Y


func _paint() -> void:
	clear()
	for cx in range(C_MIN, C_MAX + 1):
		for cy in range(C_MIN, C_MAX + 1):
			var s := _screen(cx, cy)
			if absi(s.x) > 640 or absi(s.y) > 380:
				continue
			var idx: int = _pick(cx, cy)
			set_cell(Vector2i(cx, cy), SRC, Vector2i(idx % 8, idx / 8))


func _pick(cx: int, cy: int) -> int:
	var h: int = _h32(cx + 64, cy + 64)
	if _is_dirt(cx, cy):
		# Yard boundary: which diamond neighbours are grass?
		# DIAMOND_DOWN: +cx → SE, -cx → NW, +cy → SW, -cy → NE.
		var grass_edges: Array[int] = []
		if not _is_dirt(cx - 1, cy): grass_edges.append(TR_NW)
		if not _is_dirt(cx + 1, cy): grass_edges.append(TR_SE)
		if not _is_dirt(cx, cy + 1): grass_edges.append(TR_SW)
		if not _is_dirt(cx, cy - 1): grass_edges.append(TR_NE)
		if grass_edges.size() == 1:
			return grass_edges[0]
		if grass_edges.size() >= 2:
			return PATCHY
		var r: int = h % 20
		if r < 14: return DIRT_PLAIN[h % DIRT_PLAIN.size()]
		if r < 17: return DIRT_ACC[h % DIRT_ACC.size()]
		if r < 19: return DIRT_SCRAP[h % DIRT_SCRAP.size()]
		return DIRT_TUFTS
	# Grass cell touching the yard → tufty blend toward the dirt.
	if _is_dirt(cx + 1, cy) or _is_dirt(cx - 1, cy) \
			or _is_dirt(cx, cy + 1) or _is_dirt(cx, cy - 1):
		return DIRT_TUFTS if h % 3 == 0 else PATCHY
	var r: int = h % 20
	if r < 11: return GRASS_PLAIN[h % GRASS_PLAIN.size()]
	if r < 15: return GRASS_ACC[h % GRASS_ACC.size()]
	if r < 17: return GRASS_FLOWERS[h % GRASS_FLOWERS.size()]
	return GRASS_SCRAP[h % GRASS_SCRAP.size()]
