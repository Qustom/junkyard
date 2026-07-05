class_name CaveBackend
extends RefCounted
## CaveBackend — cellular-automata caverns, the M1.10 second generation backend.
##
## The exploration's Phase-D second backend behind the one BandPipeline seam:
## seeded fill% -> N CA smoothing passes -> keep-largest flood region ->
## deterministic carve of secondary regions -> player-scale (2x2-open) pass ->
## west-most entry anchor -> emit SYNTHETIC PlacedPieces (one per floor-bearing
## grid chunk) carrying floor_cells so Band's data shape (and fingerprint()) is
## backend-agnostic. No pieces, no sockets, no assets — just an integer grid.
## The entire downstream stack (DepthGrader / JunkPlacer / EncounterBuilder /
## ConnectivityGuarantee / materialisation seal) is reused UNCHANGED.
##
## DETERMINISM ARCHITECTURE (the whole design in one paragraph):
## all randomness happens in ONE block. After RNG.seed_from(attempt_seed) the
## fill loop draws exactly one RNG.randi_range(0, 99) per interior cell in fixed
## scan order (y outer ascending, x inner ascending). Every subsequent step —
## smoothing, flood-fill, region sort, discard, carve, player-scale pass, entry
## selection, chunking, piece emission — is a PURE INTEGER function of the grid
## with ZERO draws and a fixed iteration order. Retries reseed with
## _derive_seed(seed, attempt) (the socket backend's exact boost-style
## hash-combine, reimplemented locally so band_generator.gd stays untouched).
## Same (cfg + seed) -> same grid -> same pieces -> same fingerprint, forever.
##
## rc IGNORED (M1.10): every as-built rc generation hook is socket-interior
## (r4 branching, lvl room-count/catalog swap, J4 corridor weights). The
## parameter is kept for signature symmetry; C7 pins the invariance.

const WALL := 1
const FLOOR := 0

# 4-neighbour steps in N/E/S/W order, matching ConnectivityGuarantee._STEPS
# (connectivity_guarantee.gd:35-36) for cross-system order consistency.
const _STEP_DX: Array[int] = [0, 1, 0, -1]
const _STEP_DY: Array[int] = [-1, 0, 1, 0]

# Q9: test-visible non-vacuity stats, set from the RETURNED attempt.
var last_region_count: int = 0        # pre-carve flood-region tally
var last_throat_carve_count: int = 0  # player-scale carves + orphan widenings


func generate(seed: int, cfg: CaveBandConfig, _rc: RunConfig = null) -> Band:
	EventBus.band_generation_started.emit(seed)  # telemetry parity with the socket path
	var attempt := 0
	var best: Band = null
	while attempt < cfg.max_attempts:
		var attempt_seed := seed if attempt == 0 else _derive_seed(seed, attempt)
		var band := _generate_once(attempt_seed, cfg)
		band.requested_seed = seed
		band.resolved_seed = attempt_seed
		if best == null or _floor_count(band) > _floor_count(best):
			best = band  # largest-floor fallback (mirrors "largest band seen")
		if _floor_count(band) >= cfg.min_floor_cells:
			EventBus.band_generated.emit(seed, band.pieces.size())
			return band
		attempt += 1
	EventBus.band_generation_failed.emit(seed, &"undersized")
	if best != null:
		EventBus.band_generated.emit(seed, best.pieces.size())
	return best


# --- One deterministic attempt ------------------------------------------------

func _generate_once(seed: int, cfg: CaveBandConfig) -> Band:
	# DETERMINISM: reset the shared stream before any draw (band_generator.gd:88).
	RNG.seed_from(seed)
	var w := cfg.grid_width
	var h := cfg.grid_height
	var grid := _seeded_fill(w, h, cfg.fill_pct)          # the ONLY RNG block
	for _i in cfg.smooth_passes:
		grid = _smooth(grid, w, h, cfg.wall_threshold)    # pure integer CA, RNG-free
	var regions := _flood_regions(grid, w, h)             # fixed scan order, sorted output
	last_region_count = regions.size()
	_keep_and_carve(grid, w, h, regions, cfg)             # keep-largest + deterministic carve
	last_throat_carve_count = _player_scale_pass(grid, w, h, cfg)  # 2x2-open guarantee (Q8)
	var entry_cell := _select_entry(grid, w, h)           # west-most 2x2-open cell (Q10)
	return _emit_band(grid, w, h, entry_cell, cfg)        # chunk -> synthetic pieces


# --- The single RNG block -----------------------------------------------------

func _seeded_fill(w: int, h: int, fill_pct: int) -> PackedByteArray:
	var grid := PackedByteArray()
	grid.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				grid[i] = WALL                            # forced border, no draw
			else:
				grid[i] = WALL if RNG.randi_range(0, 99) < fill_pct else FLOOR
	return grid


## Double-buffered CA smoothing (never in-place — in-place reads half-updated
## neighbours and is scan-order-dependent). Border stays forced WALL.
func _smooth(src: PackedByteArray, w: int, h: int, wall_threshold: int) -> PackedByteArray:
	var dst := PackedByteArray()
	dst.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				dst[i] = WALL
				continue
			var walls := 0
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					if src[(y + dy) * w + (x + dx)] == WALL:
						walls += 1
			dst[i] = WALL if walls >= wall_threshold else FLOOR
	return dst


# --- Flood regions (order-stable) ---------------------------------------------

## Discover 4-connected FLOOR regions in fixed (y, x) scan order; each region's
## anchor is its (y, x)-minimal cell (= first-discovered). Sorted size desc,
## anchor (y, x) asc — a total order, so "largest" / "secondary in order" are
## unambiguous on every seed.
func _flood_regions(grid: PackedByteArray, w: int, h: int) -> Array:
	var visited := {}
	var regions: Array = []
	for y in h:
		for x in w:
			var i := y * w + x
			if grid[i] != FLOOR or visited.has(i):
				continue
			var cells: Array[int] = []
			var queue: Array[int] = [i]
			visited[i] = true
			while not queue.is_empty():
				var cur: int = queue.pop_front()
				cells.append(cur)
				var cx := cur % w
				var cy := cur / w
				for s in 4:
					var nx := cx + _STEP_DX[s]
					var ny := cy + _STEP_DY[s]
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var ni := ny * w + nx
					if grid[ni] == FLOOR and not visited.has(ni):
						visited[ni] = true
						queue.append(ni)
			regions.append({"cells": cells, "size": cells.size(), "anchor": i})
	_sort_regions(regions, w)
	return regions


func _sort_regions(regions: Array, w: int) -> void:
	regions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["size"] != b["size"]:
			return a["size"] > b["size"]
		var ay: int = a["anchor"] / w
		var ax: int = a["anchor"] % w
		var by: int = b["anchor"] / w
		var bx: int = b["anchor"] % w
		if ay != by:
			return ay < by
		return ax < bx)


# --- Keep-largest, discard-small, carve-the-rest ------------------------------

func _keep_and_carve(grid: PackedByteArray, w: int, h: int, regions: Array,
		cfg: CaveBandConfig) -> void:
	if regions.is_empty():
		return
	var main_cells: Array[int] = (regions[0]["cells"] as Array[int]).duplicate()
	for r in range(1, regions.size()):
		var region: Dictionary = regions[r]
		var cells: Array[int] = region["cells"]
		if region["size"] < cfg.min_region_cells:
			for c in cells:
				grid[c] = WALL            # discard: fill to wall (before any carve targets it)
			continue
		var src: int = region["anchor"]
		var dst := _nearest_cell(src, main_cells, w)
		_carve_l(grid, w, h, src, dst, cfg.carve_width)
		for c in cells:
			main_cells.append(c)          # a later region may connect via this one


## Nearest candidate by Manhattan distance; ties broken by (y, x) ascending on
## the candidate — a total order, so the pick is deterministic.
func _nearest_cell(src: int, candidates: Array[int], w: int) -> int:
	var sx := src % w
	var sy := src / w
	var best := -1
	var best_d := 1 << 30
	var best_y := 1 << 30
	var best_x := 1 << 30
	for c in candidates:
		var cx := c % w
		var cy := c / w
		var d: int = absi(cx - sx) + absi(cy - sy)
		if d < best_d or (d == best_d and (cy < best_y or (cy == best_y and cx < best_x))):
			best = c
			best_d = d
			best_y = cy
			best_x = cx
	return best


## L-shaped corridor: walk x first (at row sy) then y (at col dx), each segment
## thickened to `width` on its perpendicular axis, extending toward +y / +x
## (fixed rule), clamped inside the border ring. Pure integer geometry, no RNG.
func _carve_l(grid: PackedByteArray, w: int, h: int, src: int, dst: int, width: int) -> void:
	var sx := src % w
	var sy := src / w
	var dx := dst % w
	var dy := dst / w
	var x0 := mini(sx, dx)
	var x1 := maxi(sx, dx)
	for x in range(x0, x1 + 1):
		for t in width:
			_set_floor(grid, w, h, x, sy + t)     # thicken in +y
	var y0 := mini(sy, dy)
	var y1 := maxi(sy, dy)
	for y in range(y0, y1 + 1):
		for t in width:
			_set_floor(grid, w, h, dx + t, y)     # thicken in +x


func _set_floor(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> void:
	if x >= 1 and y >= 1 and x <= w - 2 and y <= h - 2:  # inside the border ring
		grid[y * w + x] = FLOOR


# --- Player-scale (2x2-open) pass (Q8) ----------------------------------------

## After keep+carve, guarantee the traversable set T (floor cells belonging to
## >=1 all-floor 2x2 block — a 28px player disc fits a 32x32px block) is
## non-empty, single-component, and covers the floor (every floor cell is a
## member of or 4-adjacent to T). Reuses the carve machinery (width >= 2) to
## connect secondary T-components to the largest, then widens any remaining
## orphan floor cell into a 2x2. Carves ONLY add floor, so the §3.4
## connectivity-by-construction argument is preserved. Returns the carve count.
func _player_scale_pass(grid: PackedByteArray, w: int, h: int, cfg: CaveBandConfig) -> int:
	var carves := 0
	var guard := 0
	var limit := w * h
	var carve_w: int = maxi(cfg.carve_width, 2)
	while guard < limit:
		guard += 1
		var t_set := _compute_traversable(grid, w, h)
		var comps := _flood_set(t_set, w, h)
		if comps.size() > 1:
			_sort_regions(comps, w)
			var main_cells: Array[int] = (comps[0]["cells"] as Array[int]).duplicate()
			for r in range(1, comps.size()):
				var src: int = comps[r]["anchor"]
				var dst := _nearest_cell(src, main_cells, w)
				_carve_l(grid, w, h, src, dst, carve_w)
				carves += 1
				for c in (comps[r]["cells"] as Array[int]):
					main_cells.append(c)
			continue                                     # recompute after carving
		var orphans := _find_orphans(grid, t_set, w, h)  # floor cells >1 from T
		if orphans.is_empty():
			break                                        # T single-component + covers
		for o in orphans:
			_widen_2x2(grid, w, h, o)
			carves += 1
	return carves


## The traversable set T: every cell of an all-floor 2x2 block (block anchored
## at (x, y) covers (x,y),(x+1,y),(x,y+1),(x+1,y+1)).
func _compute_traversable(grid: PackedByteArray, w: int, h: int) -> Dictionary:
	var t := {}
	for y in range(0, h - 1):
		for x in range(0, w - 1):
			var i := y * w + x
			if grid[i] == FLOOR and grid[i + 1] == FLOOR \
					and grid[i + w] == FLOOR and grid[i + w + 1] == FLOOR:
				t[i] = true
				t[i + 1] = true
				t[i + w] = true
				t[i + w + 1] = true
	return t


## 4-connected components over a membership set (grid indices). Same shape as
## _flood_regions (cells/size/anchor), so _sort_regions applies. Scan order is
## index-ascending (== (y, x)-ascending), so anchors are (y, x)-minimal.
func _flood_set(members: Dictionary, w: int, h: int) -> Array:
	var keys: Array = members.keys()
	keys.sort()
	var visited := {}
	var comps: Array = []
	for start in keys:
		if visited.has(start):
			continue
		var cells: Array[int] = []
		var queue: Array[int] = [start]
		visited[start] = true
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			cells.append(cur)
			var cx := cur % w
			var cy := cur / w
			for s in 4:
				var nx := cx + _STEP_DX[s]
				var ny := cy + _STEP_DY[s]
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var ni := ny * w + nx
				if members.has(ni) and not visited.has(ni):
					visited[ni] = true
					queue.append(ni)
		comps.append({"cells": cells, "size": cells.size(), "anchor": start})
	return comps


## Floor cells that are neither in T nor 4-adjacent to T, in fixed (y, x) order.
func _find_orphans(grid: PackedByteArray, t_set: Dictionary, w: int, h: int) -> Array[int]:
	var orphans: Array[int] = []
	for y in h:
		for x in w:
			var i := y * w + x
			if grid[i] != FLOOR or t_set.has(i):
				continue
			var adj := false
			for s in 4:
				var nx := x + _STEP_DX[s]
				var ny := y + _STEP_DY[s]
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if t_set.has(ny * w + nx):
					adj = true
					break
			if not adj:
				orphans.append(i)
	return orphans


## Widen a cell into a 2x2 all-floor block (so it joins T next iteration).
## Anchor extends toward +x/+y where it fits, clamped inside the border ring.
func _widen_2x2(grid: PackedByteArray, w: int, h: int, i: int) -> void:
	var x := i % w
	var y := i / w
	var ax: int = clampi((x if x <= w - 3 else x - 1), 1, w - 3)
	var ay: int = clampi((y if y <= h - 3 else y - 1), 1, h - 3)
	_set_floor(grid, w, h, ax, ay)
	_set_floor(grid, w, h, ax + 1, ay)
	_set_floor(grid, w, h, ax, ay + 1)
	_set_floor(grid, w, h, ax + 1, ay + 1)


# --- Entry anchor -------------------------------------------------------------

## West-most cell of the traversable set T (min x, tie min y) — edge-biased and
## orientation-stable across seeds, and guaranteed player-scale (Q10).
func _select_entry(grid: PackedByteArray, w: int, h: int) -> int:
	var t := _compute_traversable(grid, w, h)
	var best := -1
	var best_x := 1 << 30
	var best_y := 1 << 30
	for i in t:
		var x: int = i % w
		var y: int = i / w
		if x < best_x or (x == best_x and y < best_y):
			best_x = x
			best_y = y
			best = i
	return best


# --- Emit synthetic pieces (chunk partition) ----------------------------------

func _emit_band(grid: PackedByteArray, w: int, h: int, entry_cell: int,
		cfg: CaveBandConfig) -> Band:
	var band := Band.new()
	var cc := cfg.chunk_cells
	var entry_chunk_x := -1
	var entry_chunk_y := -1
	if entry_cell >= 0:
		entry_chunk_x = (entry_cell % w) / cc * cc
		entry_chunk_y = (entry_cell / w) / cc * cc

	var entry_piece: PlacedPiece = null
	var ordered: Array[PlacedPiece] = []
	var cy0 := 0
	while cy0 < h:
		var cx0 := 0
		while cx0 < w:
			var piece := _build_chunk_piece(grid, w, h, cx0, cy0, cc, entry_cell)
			if piece != null:
				if cx0 == entry_chunk_x and cy0 == entry_chunk_y:
					entry_piece = piece
				else:
					ordered.append(piece)  # fixed (chunk-y, chunk-x) scan order
			cx0 += cc
		cy0 += cc

	if entry_piece != null:
		band.pieces.append(entry_piece)          # Band.entry_piece = pieces[0] convention
	for p in ordered:
		band.pieces.append(p)
	for p in band.pieces:
		band.occupy(p)
	if not band.pieces.is_empty():
		band.entry_piece = band.pieces[0]
		band.deepest_piece = _pick_deepest_piece(band)
	band.open_sockets = []

	# Q11 runtime guard: a pathological config can emit one chunk, reintroducing
	# the mega-piece failure. The band is still playable (just depth-degenerate),
	# so push_error but return it (never-crash posture); C4 asserts >= 2.
	if band.pieces.size() < 2:
		push_error("CaveBackend: emitted %d piece(s) (< 2) — depth axis degenerate (grid %dx%d, chunk %d)"
				% [band.pieces.size(), w, h, cc])
	return band


func _build_chunk_piece(grid: PackedByteArray, w: int, h: int, cx0: int, cy0: int,
		cc: int, entry_cell: int) -> PlacedPiece:
	var floor_cells: Array[Vector2i] = []
	var footprint: Array[Vector2i] = []
	var x_end: int = mini(cx0 + cc, w)
	var y_end: int = mini(cy0 + cc, h)
	for y in range(cy0, y_end):
		for x in range(cx0, x_end):
			footprint.append(Vector2i(x, y))
			if grid[y * w + x] == FLOOR:
				floor_cells.append(Vector2i(x, y))  # band-global, (y, x) scan order
	if floor_cells.is_empty():
		return null

	var placed := PlacedPiece.new()
	placed.instance = null                          # T1 builds runtime greybox geometry
	placed.offset_cell = Vector2i(cx0, cy0)         # grid coords are band-global
	placed.footprint_cells = footprint              # full chunk rect (floor + wall)
	placed.mated_socket_index = -1                  # entry-piece convention; nothing mated
	placed.open_sockets = []                        # no sockets in a cave

	# Entry chunk: front-position the entry anchor as floor_cells[0] (T1's
	# _entry_spawn_position reads floor_cells[0]); remainder stays (y, x) order.
	if entry_cell >= 0:
		var ex := entry_cell % w
		var ey := entry_cell / w
		if cx0 == (ex / cc) * cc and cy0 == (ey / cc) * cc:
			var anchor := Vector2i(ex, ey)
			floor_cells.erase(anchor)
			floor_cells.insert(0, anchor)
	placed.floor_cells = floor_cells

	# §3.7 content-hashed id: pins the entire cave floor through fingerprint()
	# with zero band.gd edits. Hash is over chunk-LOCAL floor cells sorted (y, x),
	# so entry front-positioning does not change it.
	placed.piece_id = _chunk_id(floor_cells, placed.offset_cell)
	return placed


func _chunk_id(floor_cells: Array[Vector2i], origin: Vector2i) -> StringName:
	var local: Array[Vector2i] = []
	for c in floor_cells:
		local.append(c - origin)
	local.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	var parts := PackedStringArray()
	for c in local:
		parts.append("%d,%d" % [c.x, c.y])
	var content_hash := "|".join(parts).sha256_text().substr(0, 12)
	return StringName("cave_" + content_hash)


## Pick band.deepest_piece by replicating DepthGrader's piece adjacency (FLOOR
## 4-adjacency, neighbours ascending) + BFS from the entry piece, so the deepest
## piece sits at the MAXIMUM chunk-hop depth — guaranteeing
## deepest_piece.depth_index == band.max_depth after the pipeline's grade (C4).
func _pick_deepest_piece(band: Band) -> PlacedPiece:
	var n := band.pieces.size()
	if n == 0:
		return null
	var cell_owner := {}
	for i in n:
		for c in band.pieces[i].floor_cells:
			cell_owner[c] = i
	var adjacency: Array = []
	for i in n:
		adjacency.append([] as Array[int])
	for i in n:
		var seen := {}
		for c in band.pieces[i].floor_cells:
			for s in 4:
				var nb: Vector2i = c + Vector2i(_STEP_DX[s], _STEP_DY[s])
				if cell_owner.has(nb):
					var j: int = cell_owner[nb]
					if j != i and not seen.has(j):
						seen[j] = true
						(adjacency[i] as Array[int]).append(j)
		(adjacency[i] as Array[int]).sort()
	var entry_idx := band.pieces.find(band.entry_piece)
	if entry_idx == -1:
		entry_idx = 0
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	dist[entry_idx] = 0
	var queue: Array[int] = [entry_idx]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nxt in adjacency[cur]:
			if dist[nxt] == -1:
				dist[nxt] = dist[cur] + 1
				queue.append(nxt)
	var best_idx := entry_idx
	var best_d := 0
	for i in n:
		if dist[i] > best_d:
			best_d = dist[i]
			best_idx = i
	return band.pieces[best_idx]


# --- Deterministic retry-seed derivation (boost-style; band_generator.gd:352) --

func _derive_seed(seed: int, attempt: int) -> int:
	var hh := seed
	hh = _hash_combine(hh, attempt)
	hh = _hash_combine(hh, 0x9E3779B9)  # golden-ratio salt
	return hh & 0x7FFFFFFFFFFFFFFF


func _hash_combine(hh: int, v: int) -> int:
	var mixed := (v + 0x9E3779B9 + ((hh << 6) & 0x7FFFFFFFFFFFFFFF) + (hh >> 2))
	return (hh ^ mixed) & 0x7FFFFFFFFFFFFFFF


func _floor_count(band: Band) -> int:
	if band == null:
		return 0
	var n := 0
	for p in band.pieces:
		n += p.floor_cells.size()
	return n
