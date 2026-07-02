class_name HubGround
extends TileMapLayer
## HubGround (M1.8 hub re-dress) — paints the dressed Layout-A vertical-spine floor for
## the static surface Hub. Pure presentation: a deterministic, RNG-FREE programmatic
## paint (the hub is an authored room, not a generated band — it must NOT touch the RNG
## autoload, which is reserved for reproducible proc-gen). Reads/writes no game state.
##
## The floor is a corner-based Wang paint: terrain is defined at cell VERTICES and each
## cell picks the tile whose four corners match, so every material seam (asphalt→dirt,
## dirt→litter, dirt→scrap-wall) gets an organic seamless transition instead of the old
## framed per-tile squares. hub_ground.tres holds three 4×4 Wang atlases (PixelLab
## topdown tilesets, chained off one shared dirt base tile so their dirt is pixel-
## identical), each laid out in Wang-index order: idx = NW*8+NE*4+SW*2+SE, where a set
## bit means the corner is the atlas's UPPER material; atlas coords = (idx % 4, idx / 4).
##
## The spine, south(+y)→north(-y), mirrors staging_area_layout_a_dressed.md §1:
##   • south street band    → asphalt (world y >= 192, runs to the view edges)
##   • open yard (middle)   → packed dirt — the central lane stays cleanest
##   • north fringe         → sparse litter patches (never in the central lane)
##   • the framing border   → scrap-wall heaps (under/behind the wall colliders)
## The painted grid (36×20 cells) intentionally overshoots the walled room so the camera
## view is filled with scrap/street instead of black backdrop.

## Sources in hub_ground.tres.
const SRC_ASPHALT_DIRT: int = 0   # lower=asphalt, upper=dirt
const SRC_DIRT_LITTER: int = 1    # lower=dirt,    upper=litter
const SRC_DIRT_SCRAP: int = 2     # lower=dirt,    upper=scrap wall

enum Mat { DIRT, ASPHALT, LITTER, SCRAP }

## Cell grid: 36×20 cells (1152×640 px) centred on origin — fills the default
## 1152×648 view at HubCamera zoom 1.05. Vertices run (0..37, 0..21).
const CX_MIN: int = -18
const CX_MAX: int = 17
const CY_MIN: int = -10
const CY_MAX: int = 9


func _ready() -> void:
	_paint()


## Deterministic integer hash of a vertex coord — NOT RNG. Same coords → same value,
## forever (the hub floor must be byte-identical every run).
func _h32(vx: int, vy: int) -> int:
	var h: int = ((vx * 73856093) ^ (vy * 19349663)) & 0xFFFFFFFF
	h = (h ^ (h >> 13)) & 0x7fffffff
	return h


## Terrain material at a vertex. Rules keep incompatible pairs (asphalt+scrap,
## asphalt+litter, litter+scrap) at least one full cell apart so every cell mixes at
## most one atlas's lower/upper pair.
func _vertex_mat(vx: int, vy: int) -> Mat:
	# South street band (world y >= 192): asphalt across the full painted width.
	if vy >= 16:
		return Mat.ASPHALT
	# Border scrap heaps: west (x <= -352), east (x >= 352), north (y <= -224); the
	# side walls stop short of the street so scrap never touches asphalt in one cell.
	if (vx <= 7 or vx >= 29 or vy <= 3) and vy <= 14:
		return Mat.SCRAP
	# North fringe: sparse hash-scattered litter patches, clear of the central lane
	# (|vx-18| > 4 keeps the spawn→shack→gate lane clean, layout §1) and one cell
	# clear of the scrap border.
	if vx >= 10 and vx <= 26 and vy >= 5 and vy <= 8 and absi(vx - 18) > 4:
		if _h32(vx, vy) % 6 == 0:
			return Mat.LITTER
	return Mat.DIRT


func _paint() -> void:
	clear()
	for cy in range(CY_MIN, CY_MAX + 1):
		for cx in range(CX_MIN, CX_MAX + 1):
			var vx: int = cx - CX_MIN
			var vy: int = cy - CY_MIN
			var m: Array[Mat] = [
				_vertex_mat(vx, vy), _vertex_mat(vx + 1, vy),        # NW NE
				_vertex_mat(vx, vy + 1), _vertex_mat(vx + 1, vy + 1) # SW SE
			]
			var source_id: int
			var idx: int
			if m.has(Mat.ASPHALT):
				source_id = SRC_ASPHALT_DIRT
				idx = _wang(m, Mat.DIRT)     # upper material of this atlas is DIRT
			elif m.has(Mat.SCRAP):
				source_id = SRC_DIRT_SCRAP
				idx = _wang(m, Mat.SCRAP)
			elif m.has(Mat.LITTER):
				source_id = SRC_DIRT_LITTER
				idx = _wang(m, Mat.LITTER)
			else:
				# Pure dirt. The all-dirt tile is pixel-identical in all three atlases
				# (chained from one base tile); use the asphalt_dirt copy (idx 15).
				source_id = SRC_ASPHALT_DIRT
				idx = 15
			set_cell(Vector2i(cx, cy), source_id, Vector2i(idx % 4, idx / 4))


## Wang corner index for the atlas whose UPPER material is `upper`:
## NW*8 + NE*4 + SW*2 + SE*1, bit set where the corner is the upper material.
func _wang(m: Array[Mat], upper: Mat) -> int:
	var idx: int = 0
	if m[0] == upper: idx += 8
	if m[1] == upper: idx += 4
	if m[2] == upper: idx += 2
	if m[3] == upper: idx += 1
	return idx
