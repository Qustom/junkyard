class_name BandGenerator
extends RefCounted
## BandGenerator — the seeded modular room-graph stitcher (B2).
##
## generate(seed, cfg, catalog) -> Band is a PURE FUNCTION of its inputs:
## start from an entry piece at the origin, repeatedly pick a frontier socket,
## pick a weighted-random compatible piece, align its mating socket, reject
## overlaps, and grow until target length. Every stochastic decision flows
## through the RNG autoload, and every branch-affecting comparison is on integer
## math, so a given seed yields a byte-identical layout on a given engine build
## (B2 determinism contract).
##
## M1 scope (per the spec's Open-questions recommendations):
##   - Socket match: direction-opposite only. width_ok/tags_ok are dormant
##     predicates that return true, so width/biome can bolt on without a rewrite.
##   - branch_chance default 0.0 -> strictly linear spine (depth == placement).
##   - No per-socket backtracking; whole-band retry with a DERIVED seed
##     (integer hash-combine), soft floor ~80%, bounded attempts, then
##     band_generation_failed.
##   - All placement in integer cells; loop logic deferred (loop_back_count
##     retained on Band but unused).

## Lightweight capture of an instanced piece's geometry + sockets, read directly
## from its nodes so the generator never depends on _ready() having fired.
class _PieceData:
	var piece_id: StringName
	var cell_size_px: int
	var occupied_cells: Array[Vector2i]
	var floor_cells: Array[Vector2i]  # walkable cells only (atlas FLOOR), piece-local
	var footprint_rect: Rect2i       # minimal enclosing rect of occupied cells
	var socket_dirs: Array[int]      # ZoneSocket.Dir per socket, authored order
	var socket_cells: Array[Vector2i]  # boundary floor cell, piece-local
	var socket_widths: Array[int]


# R4 (M1.1): fixed-point precision for the depth-scaled branch-chance integer
# compare. The branch roll stays on the RNG autoload, on integer math, at the
# SAME draw site/order as M1.0 — R4 only makes the COMPARED THRESHOLD depth-
# dependent, so the (seed + config) layout stays byte-reproducible. With R4 off
# (rc == null or r4_enabled == false) the threshold is cfg.branch_chance (0.0 in
# M1.0), so the integer compare is always false → identical M1.0 draw sequence
# and a pure linear spine.
const _R4_BRANCH_SCALE := 10000


func generate(seed: int, cfg: BandGenConfig, catalog: Array[ZonePieceData],
		rc: RunConfig = null) -> Band:
	EventBus.band_generation_started.emit(seed)

	# Pre-compute the integer cumulative-weight table once (stable catalog order).
	var weight_table := _build_weight_table(catalog)
	var cell_size_px := _assert_uniform_cell_size(catalog)

	var attempt := 0
	var best: Band = null
	while attempt < cfg.max_band_attempts:
		var attempt_seed := seed if attempt == 0 else _derive_seed(seed, attempt)
		var band := _generate_once(attempt_seed, cfg, catalog, weight_table, cell_size_px, rc)
		band.requested_seed = seed
		band.resolved_seed = attempt_seed

		# Keep the largest band seen, as a fallback if every attempt undershoots.
		if best == null or band.pieces.size() > best.pieces.size():
			best = band

		if band.pieces.size() >= _soft_floor(cfg):
			EventBus.band_generated.emit(seed, band.pieces.size())
			return band
		attempt += 1

	# Every attempt fell short of the soft floor — surface it, return the best.
	EventBus.band_generation_failed.emit(seed, &"undersized")
	if best != null:
		EventBus.band_generated.emit(seed, best.pieces.size())
	return best


# --- One deterministic assembly attempt --------------------------------------

func _generate_once(seed: int, cfg: BandGenConfig, catalog: Array[ZonePieceData],
		weight_table: Array[int], cell_size_px: int, rc: RunConfig = null) -> Band:
	# DETERMINISM: reset the shared stream to this attempt's seed before any
	# random call. RNG.seed_from is the real autoload surface (not set_seed).
	RNG.seed_from(seed)

	var band := Band.new()

	# 1. Entry piece: deterministic, index 0, no RNG. Placed at the origin.
	var entry_data := _read_piece(catalog[0].scene)
	var entry := _make_placed(catalog[0].piece_id, catalog[0].scene, entry_data,
			Vector2i.ZERO, -1, 0)
	band.pieces.append(entry)
	band.occupy(entry)
	band.entry_piece = entry
	band.deepest_piece = entry

	# 2. Frontier = entry's open sockets (band-global cells, depth-tagged).
	var frontier: Array[OpenSocket] = entry.open_sockets.duplicate()

	while band.pieces.size() < cfg.target_piece_count and not frontier.is_empty():
		_sort_frontier(frontier)  # stable order before any RNG indexing

		var grow_idx := _select_frontier_index(frontier, cfg, rc)
		var sock: OpenSocket = frontier[grow_idx]

		var placed := _try_attach_piece(band, sock, cfg, catalog, weight_table,
				cell_size_px)
		if placed == null:
			frontier.remove_at(grow_idx)  # dead end; retire the socket
			continue

		# Consume the grown-from socket; publish the new piece's other sockets.
		frontier.remove_at(grow_idx)
		for s in placed.open_sockets:
			frontier.append(s)

		band.deepest_piece = placed  # last-placed on a linear spine == deepest

	# Retain leftover frontier for a future loop-closing pass (M1: unused).
	band.open_sockets = frontier
	return band


# --- Socket-adjacency matching + placement -----------------------------------

func _try_attach_piece(band: Band, sock: OpenSocket, cfg: BandGenConfig,
		catalog: Array[ZonePieceData], weight_table: Array[int],
		cell_size_px: int) -> PlacedPiece:
	var need_dir := ZoneSocket.opposite(sock.dir)  # mate must face back at us
	var attempts := 0
	while attempts < cfg.max_place_attempts:
		attempts += 1

		var cand_idx := _weighted_pick_index(catalog, weight_table)
		var entry := catalog[cand_idx]
		var data := _read_piece(entry.scene)

		# Find a socket on the candidate that satisfies the predicate chain.
		var cand_sock_idx := _find_mate_socket(data, sock, need_dir)
		if cand_sock_idx == -1:
			continue  # this piece can't mate this way; try another draw

		# Compute the cell offset that mates the candidate flush against the host.
		var offset := _alignment_offset(sock, data, cand_sock_idx)

		var global_cells := _global_cells(data.occupied_cells, offset)
		if not band.fits(global_cells):
			continue  # overlap; redraw

		var depth := band.pieces.size()
		var placed := _make_placed(entry.piece_id, entry.scene, data, offset,
				cand_sock_idx, depth)
		band.pieces.append(placed)
		band.occupy(placed)
		return placed
	return null


## Cell offset that mates the candidate piece flush against the host along the
## host socket's facing direction.
##
## B1's authored greybox pieces are solid-walled rects whose openings reach the
## piece EDGE while the socket marker sits one cell IN from that edge. So the
## spec's raw seam formula (cand_cell == sock_cell + dir) double-counts the inset
## and overlaps the pieces. Instead we place flush: the candidate's leading
## footprint edge abuts the host's footprint edge (adjacent, no overlap) on the
## facing axis, and the candidate socket lane is aligned to the host socket lane
## on the perpendicular axis. Pure integer-cell math, fully deterministic.
func _alignment_offset(host: OpenSocket, cand: _PieceData, cand_sock_idx: int) -> Vector2i:
	var step := ZoneSocket.dir_to_cell(host.dir)  # +1 along the facing axis
	var cand_sock_local: Vector2i = cand.socket_cells[cand_sock_idx]
	var hr := host.owner_rect
	var cr := cand.footprint_rect

	var offset := Vector2i.ZERO
	if step.x != 0:
		# Horizontal mate (E/W): align rows (Y) on the socket lane; abut on X.
		offset.y = host.cell.y - cand_sock_local.y
		if step.x > 0:  # host faces E: candidate sits to the right, flush.
			offset.x = (hr.position.x + hr.size.x) - cr.position.x
		else:           # host faces W: candidate sits to the left, flush.
			offset.x = (hr.position.x - cr.size.x) - cr.position.x
	else:
		# Vertical mate (N/S): align columns (X) on the socket lane; abut on Y.
		offset.x = host.cell.x - cand_sock_local.x
		if step.y > 0:  # host faces S: candidate sits below, flush.
			offset.y = (hr.position.y + hr.size.y) - cr.position.y
		else:           # host faces N: candidate sits above, flush.
			offset.y = (hr.position.y - cr.size.y) - cr.position.y
	return offset


## Predicate chain: dir_ok AND width_ok AND tags_ok. Only dir_ok is active in
## M1; the others are dormant true-stubs so width/biome constraints bolt on
## later without restructuring the loop (B2 open-Q: socket-matching strictness).
func _find_mate_socket(data: _PieceData, host: OpenSocket, need_dir: int) -> int:
	for i in data.socket_dirs.size():
		var dir_ok := data.socket_dirs[i] == need_dir
		var width_ok := _width_ok(data.socket_widths[i], host.width_cells)
		var tags_ok := _tags_ok()
		if dir_ok and width_ok and tags_ok:
			return i
	return -1


func _width_ok(_cand_width: int, _host_width: int) -> bool:
	# DORMANT: B1 fixes a single 2-cell width, so every socket is interchangeable.
	# Activate (return _cand_width == _host_width) when B1 introduces width variance.
	return true


func _tags_ok() -> bool:
	# DORMANT: biome/theme tag matching, added when content tags exist.
	return true


# --- Seeded selection (integer math only) ------------------------------------

## Cumulative integer weight table over the catalog (stable order). Float
## ZonePieceData.weight scaled to ints once so the pick is pure integer math.
func _build_weight_table(catalog: Array[ZonePieceData]) -> Array[int]:
	const SCALE := 1000
	var table: Array[int] = []
	var running := 0
	for entry in catalog:
		var w := int(round(maxf(entry.weight, 0.0) * SCALE))
		if w <= 0:
			w = 1  # never let an authored piece be unpickable
		running += w
		table.append(running)  # store cumulative sum
	return table


## Weighted draw: roll an int in [0, total-1] and binary-position it against the
## cumulative table. RNG.randi_range is the sole randomness source here.
func _weighted_pick_index(catalog: Array[ZonePieceData], table: Array[int]) -> int:
	var total := table[table.size() - 1]
	var roll := RNG.randi_range(0, total - 1)
	for i in table.size():
		if roll < table[i]:
			return i
	return catalog.size() - 1  # unreachable; defensive


## Which open socket to grow from. With branch_chance == 0.0 (M1) and R4 off the
## branch roll never fires, so the band is a strictly linear spine growing from
## the deepest (last, post-stable-sort) socket.
##
## R4 (M1.1) — depth-scaled branching. When the active RunConfig enables R4, the
## fork chance becomes a function of the grow socket's gen-time depth (the
## owner's placement-order index, OpenSocket.depth — §10 Q6, NOT
## DepthGrader.depth_index which isn't assigned during growth). The deepest
## socket is frontier[-1] after the stable sort, so its .depth is the gen-time
## depth proxy this hook scales off.
##
## DETERMINISM (RATIFIED §10 Q5, contract = fingerprint(seed + config)): the roll
## stays on the RNG autoload, on INTEGER math, at the SAME draw site/order as
## M1.0 — R4 only changes the COMPARED THRESHOLD. To byte-match the M1.0 band
## with R4 off, the draw is gated exactly as M1.0 was: it only happens when the
## effective chance is > 0. With R4 off (rc null / disabled) and cfg.branch_chance
## == 0.0 the effective chance is 0 → NO draw → identical M1.0 RNG sequence and a
## pure linear spine.
func _select_frontier_index(frontier: Array[OpenSocket], cfg: BandGenConfig,
		rc: RunConfig = null) -> int:
	var chance := cfg.branch_chance  # M1.0 baseline path (0.0 when R4 off)
	if rc != null and rc.r4_enabled:
		# Gen-time depth = placement-order index of the deepest socket's owner.
		var grow_depth: int = frontier[frontier.size() - 1].depth
		if grow_depth <= rc.r4_max_branch_depth:
			chance = rc.r4_branch_chance_base + rc.r4_branch_per_depth * float(grow_depth)
		else:
			# Above the branch cap: force linear so the deepest pieces still chain
			# and the band reaches target_piece_count.
			chance = 0.0
	chance = clampf(chance, 0.0, 1.0)

	# Gate the draw on chance > 0 exactly as M1.0 did (chance == 0.0 means no draw,
	# preserving the M1.0 RNG sequence). The roll is an INTEGER compare on the RNG
	# autoload — never randf(), never a second stream.
	if chance > 0.0:
		var threshold := int(round(chance * _R4_BRANCH_SCALE))
		if RNG.randi_range(0, _R4_BRANCH_SCALE - 1) < threshold:
			return RNG.randi_range(0, frontier.size() - 1)  # FORK: random socket
	return frontier.size() - 1                               # SPINE: deepest socket


## Stable frontier ordering so RNG indexing is reproducible regardless of append
## order: by depth, then cell.y, then cell.x, then socket dir, then index.
func _sort_frontier(frontier: Array[OpenSocket]) -> void:
	frontier.sort_custom(func(a: OpenSocket, b: OpenSocket) -> bool:
		if a.depth != b.depth:
			return a.depth < b.depth
		if a.cell.y != b.cell.y:
			return a.cell.y < b.cell.y
		if a.cell.x != b.cell.x:
			return a.cell.x < b.cell.x
		if int(a.dir) != int(b.dir):
			return int(a.dir) < int(b.dir)
		return a.socket_index < b.socket_index)


# --- Deterministic retry seed derivation -------------------------------------

## Integer hash-combine (boost-style mix), NOT seed + attempt: adjacent seeds
## can correlate, this scrambles. Pure function of (seed, attempt) so the whole
## retry chain stays deterministic. Masked to 63 bits to stay a valid int.
func _derive_seed(seed: int, attempt: int) -> int:
	var h := seed
	h = _hash_combine(h, attempt)
	h = _hash_combine(h, 0x9E3779B9)  # golden-ratio salt
	return h & 0x7FFFFFFFFFFFFFFF


func _hash_combine(h: int, v: int) -> int:
	# h ^= v + 0x9e3779b9 + (h<<6) + (h>>2)  (masked to stay in 64-bit range)
	var mixed := (v + 0x9E3779B9 + ((h << 6) & 0x7FFFFFFFFFFFFFFF) + (h >> 2))
	return (h ^ mixed) & 0x7FFFFFFFFFFFFFFF


# --- Geometry helpers (integer cells; pixels only at instance time) ----------

## Read a piece scene's geometry + sockets WITHOUT relying on _ready(): we
## instantiate, read the Geometry TileMapLayer and Sockets markers directly,
## then free the throwaway node. Deterministic and tree-independent.
func _read_piece(scene: PackedScene) -> _PieceData:
	var node := scene.instantiate() as ZonePiece
	var data := _PieceData.new()
	data.piece_id = node.piece_id
	data.cell_size_px = node.cell_size_px

	var geo := node.get_node_or_null("Geometry") as TileMapLayer
	data.floor_cells = []
	if geo != null:
		data.occupied_cells = geo.get_used_cells()
		data.footprint_rect = geo.get_used_rect()
		# FLOOR tile is atlas (0,0); WALL is (1,0) (carries collision). Walkable
		# connectivity flood-fills over floor cells only.
		for c in data.occupied_cells:
			if geo.get_cell_atlas_coords(c) == Vector2i(0, 0):
				data.floor_cells.append(c)
	else:
		data.occupied_cells = []
		data.footprint_rect = Rect2i()

	data.socket_dirs = []
	data.socket_cells = []
	data.socket_widths = []
	var holder := node.get_node_or_null("Sockets")
	if holder != null:
		for m in holder.get_children():
			if m is Marker2D:
				var marker := m as Marker2D
				var d := int(marker.get_meta(&"dir", ZoneSocket.Dir.N))
				var w := int(marker.get_meta(&"width_cells", 2))
				var local_cell := Vector2i(
					int(floor(marker.position.x / float(data.cell_size_px))),
					int(floor(marker.position.y / float(data.cell_size_px))))
				data.socket_dirs.append(d)
				data.socket_cells.append(local_cell)
				data.socket_widths.append(w)

	node.free()
	return data


## Build a PlacedPiece: instance the real scene, place it in band-global cell
## space, and capture its frontier sockets (excluding the mated one).
func _make_placed(piece_id: StringName, scene: PackedScene, data: _PieceData,
		offset: Vector2i, mated_socket_idx: int, depth: int) -> PlacedPiece:
	var placed := PlacedPiece.new()
	placed.piece_id = piece_id
	placed.instance = scene.instantiate() as ZonePiece
	placed.offset_cell = offset
	placed.mated_socket_index = mated_socket_idx
	placed.footprint_cells = _global_cells(data.occupied_cells, offset)
	placed.floor_cells = _global_cells(data.floor_cells, offset)
	var global_rect := Rect2i(data.footprint_rect.position + offset, data.footprint_rect.size)

	placed.open_sockets = []
	for i in data.socket_dirs.size():
		if i == mated_socket_idx:
			continue
		var s := OpenSocket.new()
		s.owner = placed
		s.socket_index = i
		s.dir = data.socket_dirs[i] as ZoneSocket.Dir
		s.cell = data.socket_cells[i] + offset
		s.width_cells = data.socket_widths[i]
		s.depth = depth
		s.owner_rect = global_rect
		placed.open_sockets.append(s)
	return placed


func _global_cells(local_cells: Array[Vector2i], offset: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in local_cells:
		out.append(c + offset)
	return out


# --- Config / catalog helpers ------------------------------------------------

func _soft_floor(cfg: BandGenConfig) -> int:
	# ceil(target * percent / 100) on pure integer math.
	return (cfg.target_piece_count * cfg.soft_floor_percent + 99) / 100


## Assert every catalog piece shares one cell_size_px (cell<->pixel must be a
## lossless integer multiply). Fails fast if a piece is authored at wrong scale.
func _assert_uniform_cell_size(catalog: Array[ZonePieceData]) -> int:
	assert(not catalog.is_empty(), "BandGenerator: empty piece catalog")
	var size := -1
	for entry in catalog:
		var data := _read_piece(entry.scene)
		if size == -1:
			size = data.cell_size_px
		else:
			assert(data.cell_size_px == size,
				"BandGenerator: piece '%s' cell_size_px=%d != %d" % [
					data.piece_id, data.cell_size_px, size])
	return size


# --- Connectivity (acceptance: "connected, walkable band") -------------------

## Flood-fill from the entry across walkable doorways; true iff every placed
## piece is reached. Two pieces count as connected only when their FLOOR cells
## are 4-adjacent (a real doorway, never a shared wall), so this is a genuine
## traversability guarantee — "connected AND walkable" (the acceptance bar).
## Structural (cell-based), so a future branchy/loopy band is covered too.
func is_band_connected(band: Band) -> bool:
	if band.pieces.is_empty():
		return false
	if band.entry_piece == null:
		return false

	# Map every FLOOR (walkable) cell -> the piece index that owns it.
	var cell_owner := {}
	for i in band.pieces.size():
		for c in band.pieces[i].floor_cells:
			cell_owner[c] = i

	# Adjacency: piece A links piece B if a FLOOR cell of A has a 4-neighbour
	# FLOOR cell owned by B (a walkable doorway, not a shared wall).
	var adjacency: Array[Array] = []
	for i in band.pieces.size():
		adjacency.append([])
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for i in band.pieces.size():
		var seen := {}
		for c in band.pieces[i].floor_cells:
			for step in steps:
				var n: Vector2i = c + step
				if cell_owner.has(n):
					var j: int = cell_owner[n]
					if j != i and not seen.has(j):
						seen[j] = true
						adjacency[i].append(j)

	# BFS from the entry piece.
	var entry_idx := band.pieces.find(band.entry_piece)
	if entry_idx == -1:
		return false
	var visited := {}
	var queue: Array[int] = [entry_idx]
	visited[entry_idx] = true
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nxt in adjacency[cur]:
			if not visited.has(nxt):
				visited[nxt] = true
				queue.append(nxt)

	return visited.size() == band.pieces.size()
