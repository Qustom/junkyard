class_name ScatterBackend
extends RefCounted
## ScatterBackend — open-field arena, the M1.11 third generation backend.
##
## The spatial opposite of both shipped generators: one all-floor arena
## interior with poisson-disk-style cover footprints stamped in as NON-floor
## (the unedited SocketSealer caps every footprint + the border ring for free),
## a seed-drawn full-width clear lane (the constructed long-sightline identity),
## and the cave's chunk-partition idiom emitting synthetic PlacedPieces so the
## whole downstream stack (DepthGrader / JunkPlacer / EncounterBuilder /
## ConnectivityGuarantee / materialisation seal) is reused UNCHANGED.
##
## DETERMINISM ARCHITECTURE (the whole design in one paragraph): all randomness
## happens in ONE block. After RNG.seed_from(seed), draw exactly 1 + 4*S
## integers in fixed order — one lane-row draw, then a fixed 4-draw tuple
## (accept roll, jitter-x, jitter-y, size roll) for EVERY sampling stratum in
## fixed (stratum-y, stratum-x) scan order, UNCONDITIONALLY (a stratum draws its
## full tuple even when rejected), so the stream length is a pure function of
## cfg alone (RD-13 — stronger than the cave's outcome-dependent stream). Every
## subsequent step — stamping, chunk partition, entry selection, deepest BFS,
## piece emission — is a pure integer function of the grid with zero draws and
## fixed iteration order. NO retry loop (an arena cannot undershoot, RD-5) and
## NO carve pass (connectivity + 2x2 player-scale hold BY CONSTRUCTION at every
## legal knob value — RD-6's adversarially re-derived proof; the validate()
## clamps min_cover_spacing >= 3 / border_margin >= 2 are its teeth). Same
## (cfg + seed) -> same draws -> same grid -> same fingerprint, forever.
##
## rc IGNORED (the cave C7 precedent): every as-built rc generation hook is
## socket-interior. The parameter is kept for signature symmetry; S7 pins it.
##
## Chunk/emit machinery deliberately DUPLICATES cave_backend.gd:376-521 rather
## than extracting a shared helper (RD-14): extraction would edit the cave in
## the same wave that promotes band_three to a byte-identical control. UG3
## watch-item: extract on the third consumer.

const WALL := 1
const FLOOR := 0

# 4-neighbour steps in N/E/S/W order, matching ConnectivityGuarantee._STEPS
# (connectivity_guarantee.gd:36-37) for cross-system order consistency.
const _STEP_DX: Array[int] = [0, 1, 0, -1]
const _STEP_DY: Array[int] = [-1, 0, 1, 0]

## Fixed cover shape catalog, index-stable (RD-6's proof requires <= 2x2):
## 0 = 1x1 pillar · 1 = 2x1 low wall · 2 = 1x2 low wall · 3 = 2x2 wreck.
const _SHAPES: Array = [
	[Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(1, 0)],
	[Vector2i(0, 0), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
]

# Test-visible non-vacuity stats (the cave Q9 precedent), set per generate().
var last_cover_count: int = 0        # footprints actually stamped
var last_spacing_rejects: int = 0    # candidates rejected by margin/lane/spacing
var last_lane_row: int = -1          # the seed-picked lane top row


func generate(seed: int, cfg: ScatterBandConfig, _rc: RunConfig = null) -> Band:
	EventBus.band_generation_started.emit(seed)  # telemetry parity with both backends
	RNG.seed_from(seed)                           # the ONE reseed (band_generator.gd:88 discipline)
	last_cover_count = 0
	last_spacing_rejects = 0
	var w := cfg.grid_width
	var h := cfg.grid_height
	var grid := _arena_floor(w, h)                # border WALL ring, all-floor interior; NO draws
	var lane_y := _pick_lane_row(h, cfg)          # draw #1
	last_lane_row = lane_y
	_stamp_cover(grid, w, h, lane_y, cfg)         # the RNG block: fixed 4-draw tuple per stratum
	var entry_cell := _select_entry(grid, w, h, lane_y, cfg)  # deterministic, RNG-free
	var band := _emit_band(grid, w, h, entry_cell, cfg)       # chunk partition, RNG-free
	band.requested_seed = seed
	band.resolved_seed = seed                     # no retry (RD-5): requested == resolved, always
	EventBus.band_generated.emit(seed, band.pieces.size())
	return band


# --- Arena floor (RNG-free) -----------------------------------------------------

## Rectangle only (RD-18): forced WALL border ring, all-FLOOR interior.
func _arena_floor(w: int, h: int) -> PackedByteArray:
	var grid := PackedByteArray()
	grid.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			grid[i] = WALL if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else FLOOR
	return grid


# --- The single RNG block --------------------------------------------------------

## Draw #1: the protected all-floor E-W lane's top row, seed-varied so the one
## guaranteed sightline corridor is not always dead-center (RD-15). Kept between
## the margins so the lane and the perimeter road stay distinct floor bands.
func _pick_lane_row(h: int, cfg: ScatterBandConfig) -> int:
	var lo := 1 + cfg.border_margin
	var hi := h - 2 - cfg.border_margin - cfg.clear_lane_width + 1
	if hi < lo:
		hi = lo  # lane wider than fits between the margins: pin (still ONE draw)
	return RNG.randi_range(lo, hi)


## Steps S: order-stable stratified grid-jitter poisson sampling (RD-1). The
## stratum grid IS the sorted candidate order; every stratum draws its full
## 4-tuple unconditionally (RD-13's fixed-length stream); the decision phase is
## pure integer predicates with zero further draws.
func _stamp_cover(grid: PackedByteArray, w: int, h: int, lane_y: int,
		cfg: ScatterBandConfig) -> void:
	var s := cfg.min_cover_spacing + 2       # stratum side: spacing + widest shape extent
	var wsum: int = maxi(1, cfg.cover_w_1x1 + cfg.cover_w_2x1 + cfg.cover_w_1x2 + cfg.cover_w_2x2)
	var blocked := {}                        # Chebyshev-dilated spacing set (Vector2i -> true)
	var sy := 1
	while sy < h - 1:
		var sx := 1
		while sx < w - 1:
			# --- the fixed 4-draw tuple (ALWAYS drawn, even when rejected) ---
			var accept_roll := RNG.randi_range(0, 99)
			var jx := RNG.randi_range(0, s - 1)
			var jy := RNG.randi_range(0, s - 1)
			var size_roll := RNG.randi_range(0, wsum - 1)
			# --- decision phase: pure integer predicates, zero further draws ---
			if accept_roll < _stratum_density_pct(sx, sy, s, w, h, cfg):
				var origin := Vector2i(sx + jx, sy + jy)
				var cells := _shape_cells(origin, _weighted_shape_index(size_roll, cfg))
				if _fits(cells, w, h, lane_y, cfg, blocked):
					for c in cells:
						grid[c.y * w + c.x] = WALL   # STAMP: cover is NON-floor
					_mark_blocked(blocked, cells, cfg.min_cover_spacing)
					last_cover_count += 1
				else:
					last_spacing_rejects += 1
			sx += s
		sy += s


## Two-zone density (RD-17): a stratum whose center sits in the outer third of
## the interior scales density by (100 + bias); inner strata by (100 - bias).
## Integer division throughout; clamped 0..100.
func _stratum_density_pct(sx: int, sy: int, s: int, w: int, h: int,
		cfg: ScatterBandConfig) -> int:
	var cx := sx + s / 2
	var cy := sy + s / 2
	var d: int = mini(mini(cx, w - 1 - cx), mini(cy, h - 1 - cy))  # dist to border ring
	var outer := d * 3 < mini(w - 2, h - 2)
	var scale := 100 + cfg.edge_cover_bias_pct if outer else 100 - cfg.edge_cover_bias_pct
	return clampi(cfg.cover_density_pct * scale / 100, 0, 100)


## Integer cumulative weighted pick over the fixed shape catalog.
func _weighted_shape_index(size_roll: int, cfg: ScatterBandConfig) -> int:
	var acc := cfg.cover_w_1x1
	if size_roll < acc:
		return 0
	acc += cfg.cover_w_2x1
	if size_roll < acc:
		return 1
	acc += cfg.cover_w_1x2
	if size_roll < acc:
		return 2
	return 3


func _shape_cells(origin: Vector2i, shape_index: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in (_SHAPES[shape_index] as Array):
		cells.append(origin + (offset as Vector2i))
	return cells


## The three rejection predicates (RD-6's by-construction teeth), all pure
## integers, order-stable because acceptance order = stratum scan order:
## 1. bounds + border margin (preserves the all-floor perimeter road);
## 2. clear lane (the constructed sightline + protected entry->gate route);
## 3. spacing (Chebyshev >= min_cover_spacing via the dilated blocked set).
func _fits(cells: Array[Vector2i], w: int, h: int, lane_y: int,
		cfg: ScatterBandConfig, blocked: Dictionary) -> bool:
	var m := cfg.border_margin
	for c in cells:
		if c.x < 1 + m or c.x > w - 2 - m or c.y < 1 + m or c.y > h - 2 - m:
			return false
		if c.y >= lane_y and c.y < lane_y + cfg.clear_lane_width:
			return false
		if blocked.has(c):
			return false
	return true


## Dilate the stamped footprint by Chebyshev (spacing - 1): any later candidate
## cell inside the dilation would sit < spacing from this footprint -> reject.
## O(1) per candidate cell, no distance scans, visibly order-stable.
func _mark_blocked(blocked: Dictionary, cells: Array[Vector2i], spacing: int) -> void:
	var r := spacing - 1
	for c in cells:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				blocked[Vector2i(c.x + dx, c.y + dy)] = true


# --- Entry anchor (RNG-free) -----------------------------------------------------

## West-most cell of the 2x2-open set T (the M1.10 Q10 contract). On an arena
## the west-most set is the whole x = 1 margin column, so the TIE-BREAK picks
## the spawn: lane-aligned (min |y - lane_center|, then min y — RD-2) so the
## player's first frame stares straight down the guaranteed sightline. A total
## order (x, |y - lane_center|, y), hence deterministic and order-independent.
func _select_entry(grid: PackedByteArray, w: int, h: int, lane_y: int,
		cfg: ScatterBandConfig) -> int:
	var t := _compute_traversable(grid, w, h)
	var lane_center: int = lane_y + cfg.clear_lane_width / 2
	var best := -1
	var best_x := 1 << 30
	var best_dy := 1 << 30
	var best_y := 1 << 30
	for i in t:
		var x: int = i % w
		var y: int = i / w
		var dy: int = absi(y - lane_center)
		if x < best_x or (x == best_x and (dy < best_dy or (dy == best_dy and y < best_y))):
			best_x = x
			best_dy = dy
			best_y = y
			best = i
	return best


## The traversable set T: every cell of an all-floor 2x2 block (duplicated from
## cave_backend.gd:274-285 per RD-14).
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


# --- Emit synthetic pieces (chunk partition — the cave idiom, scat_ ids) ---------

func _emit_band(grid: PackedByteArray, w: int, h: int, entry_cell: int,
		cfg: ScatterBandConfig) -> Band:
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

	# Unreachable given the validate() chunks_x >= 5 clamp; kept for the
	# never-crash posture (the cave's Q11 guard, duplicated per RD-14).
	if band.pieces.size() < 2:
		push_error("ScatterBackend: emitted %d piece(s) (< 2) — depth axis degenerate (grid %dx%d, chunk %d)"
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
	placed.instance = null                          # U1/T1 builds runtime greybox geometry
	placed.offset_cell = Vector2i(cx0, cy0)         # grid coords are band-global
	placed.footprint_cells = footprint              # full chunk rect (floor + cover/wall)
	placed.mated_socket_index = -1                  # entry-piece convention; nothing mated
	placed.open_sockets = []                        # no sockets in an arena

	# Entry chunk: front-position the entry anchor as floor_cells[0]
	# (main_game.gd's _entry_spawn_position reads floor_cells[0]); the
	# remainder stays (y, x) order.
	if entry_cell >= 0:
		var ex := entry_cell % w
		var ey := entry_cell / w
		if cx0 == (ex / cc) * cc and cy0 == (ey / cc) * cc:
			var anchor := Vector2i(ex, ey)
			floor_cells.erase(anchor)
			floor_cells.insert(0, anchor)
	placed.floor_cells = floor_cells

	# Content-hashed id (the cave scheme verbatim, scat_ prefix): pins every
	# cover hole through fingerprint() with zero band.gd edits. Hash is over
	# chunk-LOCAL floor cells sorted (y, x), so entry front-positioning does
	# not change it; identical full-floor chunks share an id and are
	# disambiguated by @offset exactly as repeated catalog pieces are.
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
	return StringName("scat_" + content_hash)


## Pick band.deepest_piece by replicating DepthGrader's piece adjacency (FLOOR
## 4-adjacency, neighbours ascending) + BFS from the entry piece, so the deepest
## piece sits at the MAXIMUM chunk-hop depth — guaranteeing
## deepest_piece.depth_index == band.max_depth after the pipeline's grade.
## (Duplicated from cave_backend.gd:479-521 per RD-14.)
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
