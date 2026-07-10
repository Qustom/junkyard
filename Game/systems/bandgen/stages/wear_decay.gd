class_name WearDecayStage
extends BandFlavorStage
## WearDecayStage — breach-led ruin over the assembled band (M1.9 S5, spec §4,
## e5's decay modifier). Same layout in, per-seed ruin out: pure post-pass over
## geometry/connectivity — no new pieces, no new archetype.
##
## OPS (as-built geometry, §4.3):
##   BREACH — a non-doorway seam between two flush-mated pieces is TWO wall
##   cells thick (each piece's own perimeter). A breach converts breach_width
##   parallel wall-cell pairs (colinear with floor on both outer sides) to
##   FLOOR: a shortcut the generator never authored. Breaches only add edges.
##   BLOCK — a doorway (FLOOR cells of piece i 4-adjacent to FLOOR of piece j,
##   pre-decay snapshot) has EVERY i-side seam cell converted to WALL — closes
##   the connection, forces a detour. TENTATIVE: reject-on-disconnect (e5's
##   non-negotiable) reverts any block the cell-level flood-fill rejects.
##
## ORDER (§4.2, hardcoded — not authored): breaches BEFORE blocks. On the
## as-built tree bands every doorway is a bridge, so every block disconnects
## until a prior breach has created the cycle providing the alternate route —
## M1.9 decay is breach-led (the Q4 headline). Breach-first stays weakly
## dominant on ANY topology: breaches only add edges, and each block is
## individually guarded by the topology-agnostic reject.
##
## OFF-FINGERPRINT but layout-touching (§1.4): the piece list is untouched
## (fingerprint() byte-stable); the walkable graph changes — determinism is
## held by Band.floor_fingerprint() instead. All draws ride the local
## stage_seed sub-stream in a fixed op order (all breaches, then all blocks).
##
## Every committed op is journaled — the ConnectivityGuarantee CARVE surface.

const _TINT_COLLAPSED := Color(0.82, 0.74, 0.62)   # warm grey-brown (§10 Q5)
const _TINT_FLOODED := Color(0.60, 0.78, 0.76)     # blue-green (D-RAT-1)
const _BIAS_SCALE := 1000

var _cfg: WearDecayConfig
## Committed ops: { "kind": &"breach"|&"block", "writes": Array[Dictionary] }
## (write shape per ConnectivityGuarantee.revert_op).
var _journal: Array = []


func _init(cfg: WearDecayConfig = null) -> void:
	_cfg = cfg


func reshapes_floor() -> bool:
	return true


func journal() -> Array:
	return _journal


func apply(band: Band, _profile: BandProfile, rng: RandomNumberGenerator) -> void:
	if band == null or _cfg == null or _cfg.decay_level <= 0.0:
		return

	# rng arrives fully configured (RNG.substream_hashed, the JunkPlacer pattern);
	# the RNG autoload is never touched.

	# Pre-decay doorway snapshot (breach-created adjacencies excluded — §4.3).
	var doorways := _enumerate_doorways(band)

	# §4.2 author warning, TREE-GATED (§10 C2): only meaningful while every
	# doorway is a bridge (edges == n - 1); never mis-fires on a cyclic band.
	if _cfg.block_budget > 0 and _cfg.breach_budget == 0 \
			and doorways.size() == band.pieces.size() - 1:
		push_warning("WearDecayStage: block_budget > 0 with breach_budget == 0 on a tree band — every doorway is a bridge, every block will be rejected (breach-led decay, spec §4.2)")

	var breach_ops := ceili(float(_cfg.breach_budget) * _cfg.decay_level)
	var block_ops := ceili(float(_cfg.block_budget) * _cfg.decay_level)
	var touched := {}                                   # PlacedPiece -> true

	# --- PASS 1: breaches (must precede blocks — tree topology, §4.2) --------
	var runs := _enumerate_breach_runs(band, maxi(_cfg.breach_width, 1))
	for _b in breach_ops:
		if runs.is_empty():
			break
		var run: Array = runs.pop_at(rng.randi_range(0, runs.size() - 1))
		# Overlap guard: a cell shared with an earlier-committed op may already
		# be floor; skip the run (the attempt is consumed — draw order stable).
		if not _run_still_wall(band, run):
			continue
		var writes: Array = []
		for pair_v in run:
			var pair: Dictionary = pair_v
			var pa: PlacedPiece = band.pieces[pair["a"]]
			var pb: PlacedPiece = band.pieces[pair["b"]]
			_write_cell(pa, pair["w1"], ConnectivityGuarantee.FLOOR_ATLAS, writes)
			_write_cell(pb, pair["w2"], ConnectivityGuarantee.FLOOR_ATLAS, writes)
			touched[pa] = true
			touched[pb] = true
		_journal.append({"kind": &"breach", "writes": writes})

	# --- PASS 2: blocks (tentative + reject-on-disconnect, e5's rule) --------
	var conn := ConnectivityGuarantee.new()
	for _k in block_ops:
		if doorways.is_empty():
			break
		var d: Dictionary = doorways.pop_at(_biased_pick(doorways, rng))
		var piece_i: PlacedPiece = band.pieces[d["i"]]
		var writes: Array = []
		for cell_v in d["cells_i"]:
			var cell: Vector2i = cell_v
			if piece_i.floor_cells.has(cell):           # junction guard (still floor?)
				_write_cell(piece_i, cell, ConnectivityGuarantee.WALL_ATLAS, writes)
		if writes.is_empty():
			continue
		var op := {"kind": &"block", "writes": writes}
		if conn.is_fully_connected(band):
			_journal.append(op)                         # committed
			touched[piece_i] = true
		else:
			ConnectivityGuarantee.revert_op(op)         # reject: doorway stays open
		# Either way the doorway is retired (popped above).

	# --- Q5 greybox tell: modulate tint on decay-touched pieces --------------
	# Zero new assets, fingerprint-neutral (modulate touches no tile data).
	var tint := _TINT_FLOODED if _cfg.state == &"flooded" else _TINT_COLLAPSED
	for piece_v in touched:
		var piece: PlacedPiece = piece_v
		if piece.instance == null:
			continue
		var geo := piece.instance.get_node_or_null("Geometry") as TileMapLayer
		if geo != null:
			geo.modulate = tint


# --- Tile write primitive (shared with tests) ----------------------------------

## Write `atlas` at a band-global cell into the owner's Geometry layer (the
## sealer's proven write pattern, socket_sealer.gd:_place_wall_cap), keep the
## owner's floor_cells truthful, and record the write (with its prior atlas)
## for the journal / revert surface. Static so the CARVE unit test can
## hand-block a doorway bypassing the inline reject (spec §6.2-6).
static func _write_cell(piece: PlacedPiece, cell: Vector2i, atlas: Vector2i,
		writes: Array) -> void:
	if piece == null or piece.instance == null:
		return
	var geo := piece.instance.get_node_or_null("Geometry") as TileMapLayer
	if geo == null:
		return
	var local := cell - piece.offset_cell
	var prior := geo.get_cell_atlas_coords(local)
	geo.set_cell(local, ConnectivityGuarantee.GREYBOX_SOURCE_ID, atlas)
	if atlas == ConnectivityGuarantee.FLOOR_ATLAS:
		if not piece.floor_cells.has(cell):
			piece.floor_cells.append(cell)
	else:
		piece.floor_cells.erase(cell)
	writes.append({"piece": piece, "cell": cell, "prior": prior})


# --- Candidate enumeration (order-stable, RNG-free) -----------------------------

## Doorways per unordered piece pair (i < j): the FLOOR cells of piece i
## 4-adjacent to FLOOR cells of piece j (the walkable-adjacency definition
## shared by is_band_connected / DepthGrader / the sealer's guard). Pairs
## sorted ascending; each doorway's i-side cells sorted (y, x). Returns
## Array[Dictionary { i, j, cells_i: Array[Vector2i], deep_norm: float }].
func _enumerate_doorways(band: Band) -> Array:
	var floor_owner := {}                                # Vector2i -> piece index
	for i in band.pieces.size():
		for c in band.pieces[i].floor_cells:
			floor_owner[c] = i

	var pairs := {}                                      # Vector2i(i,j), i<j -> cells_i set
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for i in band.pieces.size():
		for c in band.pieces[i].floor_cells:
			for step in steps:
				var n: Vector2i = c + step
				if not floor_owner.has(n):
					continue
				var j: int = floor_owner[n]
				if j == i:
					continue
				var lo := mini(i, j)
				var hi := maxi(i, j)
				var key := Vector2i(lo, hi)
				if not pairs.has(key):
					pairs[key] = {}
				if i == lo:                              # collect the i-side (lower index) cells
					pairs[key][c] = true

	var keys: Array = pairs.keys()
	keys.sort()                                          # Vector2i sorts (x, then y) — ascending pairs
	var out: Array = []
	for key_v in keys:
		var key: Vector2i = key_v
		var cells: Array[Vector2i] = []
		for c in pairs[key]:
			cells.append(c)
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			return a.x < b.x)
		if cells.is_empty():
			continue                                     # one-sided adjacency artifact; defensive
		var deep_norm: float = maxf(
			band.pieces[key.x].depth_norm, band.pieces[key.y].depth_norm)
		out.append({"i": key.x, "j": key.y, "cells_i": cells, "deep_norm": deep_norm})
	return out


## Breach candidates: pairs of 4-adjacent WALL cells (w1 ∈ piece A, w2 ∈ piece
## B, A ≠ B) colinear with FLOOR on both outer sides of the two-thick seam
## (floor(A) — w1 — w2 — floor(B) in a straight line), grouped into DISJOINT
## runs of `width` parallel pairs along the seam. Runs sorted by (first w1.y,
## w1.x, axis). Returns Array[Array[Dictionary { a, b, w1, w2, axis }]].
func _enumerate_breach_runs(band: Band, width: int) -> Array:
	var floor_owner := {}
	var wall_owner := {}
	for i in band.pieces.size():
		for c in band.pieces[i].floor_cells:
			floor_owner[c] = i
	for i in band.pieces.size():
		for c in band.pieces[i].footprint_cells:
			if int(floor_owner.get(c, -1)) != i:
				wall_owner[c] = i                        # footprints never overlap → wall of i

	# Canonical directions E and S so each physical pair appears exactly once.
	var pairs: Array = []
	for i in band.pieces.size():
		for c in band.pieces[i].footprint_cells:
			if int(wall_owner.get(c, -1)) != i:
				continue
			for step_v in [Vector2i(1, 0), Vector2i(0, 1)]:
				var step: Vector2i = step_v
				var n: Vector2i = c + step
				var j: int = int(wall_owner.get(n, -1))
				if j == -1 or j == i:
					continue
				if int(floor_owner.get(c - step, -1)) != i:
					continue                             # no floor behind A's wall, in-line
				if int(floor_owner.get(n + step, -1)) != j:
					continue                             # no floor behind B's wall, in-line
				pairs.append({"a": i, "b": j, "w1": c, "w2": n, "axis": step})

	# Bucket by (axis, seam line, piece pair); consecutive perpendicular
	# coordinates form maximal sequences, chunked into disjoint width-windows.
	var buckets := {}
	for p_v in pairs:
		var p: Dictionary = p_v
		var axis: Vector2i = p["axis"]
		var w1: Vector2i = p["w1"]
		var fixed: int = w1.x if axis.x != 0 else w1.y
		var key := "%d,%d:%d:%d:%d" % [axis.x, axis.y, fixed, int(p["a"]), int(p["b"])]
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(p)

	var runs: Array = []
	for key in buckets:
		var bucket: Array = buckets[key]
		bucket.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
			return _perp_coord(p) < _perp_coord(q))
		var k := 0
		while k < bucket.size():
			var seq: Array = [bucket[k]]
			var m := k + 1
			while m < bucket.size() \
					and _perp_coord(bucket[m]) == _perp_coord(bucket[m - 1]) + 1:
				seq.append(bucket[m])
				m += 1
			var w0 := 0
			while w0 + width <= seq.size():
				runs.append(seq.slice(w0, w0 + width))
				w0 += width
			k = m

	runs.sort_custom(func(r1: Array, r2: Array) -> bool:
		var a1: Vector2i = r1[0]["w1"]
		var a2: Vector2i = r2[0]["w1"]
		if a1.y != a2.y:
			return a1.y < a2.y
		if a1.x != a2.x:
			return a1.x < a2.x
		var x1: Vector2i = r1[0]["axis"]
		var x2: Vector2i = r2[0]["axis"]
		return x1.y < x2.y)
	return runs


static func _perp_coord(p: Dictionary) -> int:
	var axis: Vector2i = p["axis"]
	var w1: Vector2i = p["w1"]
	return w1.y if axis.x != 0 else w1.x


## True while every cell of the run is still a wall of its owner piece
## (floor_cells is the walkable truth — a cell an earlier committed op floored
## is in its owner's floor_cells).
func _run_still_wall(band: Band, run: Array) -> bool:
	for pair_v in run:
		var pair: Dictionary = pair_v
		var w1: Vector2i = pair["w1"]
		var w2: Vector2i = pair["w2"]
		if band.pieces[pair["a"]].floor_cells.has(w1):
			return false
		if band.pieces[pair["b"]].floor_cells.has(w2):
			return false
	return true


## Seeded pick over the (sorted) doorway list, depth_bias-weighted by the
## deeper piece's depth_norm (integer cumulative table; bias 0 = uniform, but
## the draw still happens — stable draw sequence).
func _biased_pick(doorways: Array, rng: RandomNumberGenerator) -> int:
	var table: Array[int] = []
	var running := 0
	var bias := maxf(_cfg.depth_bias, 0.0)
	for d_v in doorways:
		var d: Dictionary = d_v
		var w := _BIAS_SCALE + int(round(bias * float(d["deep_norm"]) * float(_BIAS_SCALE)))
		running += w
		table.append(running)
	var roll := rng.randi_range(0, running - 1)
	for k in table.size():
		if roll < table[k]:
			return k
	return doorways.size() - 1                           # unreachable; defensive
