class_name SetPieceInjectStage
extends BandFlavorStage
## SetPieceInjectStage — attach authored set-pieces at retained open sockets
## (M1.9 S5, spec §3, e4's "cheapest anti-sameness win").
##
## ATTACH, not e4's swap lean (§10 Q3, ratified): the set-piece is appended to
## a depth-gated socket from band.open_sockets — the retained unconsumed
## frontier kept precisely "so a later pass has everything it needs"
## (band.gd:26-29) — using the EXACT grow-loop machinery (_find_mate_socket ->
## _alignment_offset -> band.fits -> _make_placed -> band.occupy). The
## set-piece becomes a dead-end special room off the spine: a detour, e4's
## risk/reward read. Swap would require re-mating a mid-spine neighborhood.
##
## LAYOUT-AFFECTING (spec §1.4): appending pieces moves fingerprint()
## deterministically under the (seed + config) contract. The injection draws
## ride a LOCAL sub-stream (stage_seed), so the underlying spine draw sequence
## is untouched — the control layout is a strict prefix of the flavored one.
##
## band.entry_piece / band.deepest_piece are NEVER reassigned — the extraction
## anchor stays on the spine; the set-piece is a side attraction even if its
## re-graded depth_index exceeds the old max. The set-piece does not count
## toward target_piece_count / soft-floor (it appends post-generation). The
## materialisation-time SocketSealer caps its unused sockets for free
## (geometry-keyed, downstream of this stage).

const _WEIGHT_SCALE := 1000

var _cfg: SetPieceInjectConfig
## Helper reuse only — never its generate(). Zero edits to band_generator.gd:
## its _read_piece / _find_mate_socket / _alignment_offset / _make_placed /
## _global_cells / _sort_frontier are callable cross-class (spec §2.3).
var _gen := BandGenerator.new()


func _init(cfg: SetPieceInjectConfig = null) -> void:
	_cfg = cfg


func mutates_pieces() -> bool:
	return true


func apply(band: Band, _profile: BandProfile, rng: RandomNumberGenerator) -> void:
	if band == null or _cfg == null or _cfg.entries.is_empty():
		return

	# rng arrives fully configured (RNG.substream_hashed, the JunkPlacer pattern);
	# the RNG autoload is never touched here.

	# Authoring lint (e4 / spec §3.1): a set-piece needs a scene with >= 1
	# socket to ride the mate machinery. push_error + exclude, never fail the
	# band. Evaluated once, in stable config order.
	var usable: Array[bool] = []
	for i in _cfg.entries.size():
		var e := _cfg.entries[i]
		var ok := e != null and e.piece != null and e.piece.scene != null
		if ok:
			var lint := _gen._read_piece(e.piece.scene)
			if lint.socket_dirs.is_empty():
				push_error("SetPieceInjectStage: entry %d ('%s') has no sockets — cannot mate; skipped"
						% [i, e.piece.piece_id])
				ok = false
		else:
			push_error("SetPieceInjectStage: entry %d has no piece/scene; skipped" % i)
		usable.append(ok)

	var placed_per_entry := {}                           # entry index -> count

	for _slot in _cfg.max_total:
		# 1. Eligible entries, stable config order (caps + unique dedupe).
		var eligible: Array[int] = []
		for i in _cfg.entries.size():
			if not usable[i]:
				continue
			var e := _cfg.entries[i]
			var cap := 1 if e.unique else e.max_per_band
			if int(placed_per_entry.get(i, 0)) < cap:
				eligible.append(i)
		if eligible.is_empty():
			break
		var entry_i: int = eligible[_weighted_entry_pick(eligible, rng)]
		var entry := _cfg.entries[entry_i]
		var data := _gen._read_piece(entry.piece.scene)

		# 2. Candidate sockets: the retained frontier in the grow loop's own
		#    stable order (_sort_frontier: depth, cell.y, cell.x, dir, index),
		#    depth-gated on the HOST piece's provisional depth_norm (the
		#    pipeline grades before this stage runs).
		var socks: Array[OpenSocket] = band.open_sockets.duplicate()
		_gen._sort_frontier(socks)
		var gated: Array[OpenSocket] = []
		for s in socks:
			if s.owner.depth_norm >= entry.min_depth_norm:
				gated.append(s)
		if gated.is_empty():
			# e4: graceful skip-and-log, never fail the band.
			push_warning("SetPieceInjectStage: no socket passes min_depth_norm %.2f for '%s' (seed %d) — skipped"
					% [entry.min_depth_norm, entry.piece.piece_id, band.resolved_seed])
			continue

		# 3. Try sockets starting at an rng-drawn index (deterministic ring walk).
		var start := rng.randi_range(0, gated.size() - 1)
		var injected := false
		for k in gated.size():
			var sock: OpenSocket = gated[(start + k) % gated.size()]
			var mate_idx := _gen._find_mate_socket(data, sock, ZoneSocket.opposite(sock.dir))
			if mate_idx == -1:
				continue
			var offset := _gen._alignment_offset(sock, data, mate_idx)
			if not band.fits(_gen._global_cells(data.occupied_cells, offset)):
				continue
			var placed := _gen._make_placed(entry.piece.piece_id, entry.piece.scene,
					data, offset, mate_idx, band.pieces.size())
			band.pieces.append(placed)                   # fingerprint moves HERE, deterministically
			band.occupy(placed)
			band.open_sockets.erase(sock)                # consumed
			band.open_sockets.append_array(placed.open_sockets)  # sealer caps leftovers for free
			placed_per_entry[entry_i] = int(placed_per_entry.get(entry_i, 0)) + 1
			injected = true
			break
		if not injected:
			# No fit anywhere -> skip and log, per e4's recommendation.
			push_warning("SetPieceInjectStage: '%s' fits no open socket (seed %d) — skipped"
					% [entry.piece.piece_id, band.resolved_seed])


## Seeded weighted draw over the eligible entry indices (integer cumulative
## table over entry.piece.weight — the generator's _build_weight_table shape).
## Returns a position WITHIN `eligible`.
func _weighted_entry_pick(eligible: Array[int], rng: RandomNumberGenerator) -> int:
	var table: Array[int] = []
	var running := 0
	for idx in eligible:
		var w := int(round(maxf(_cfg.entries[idx].piece.weight, 0.0) * _WEIGHT_SCALE))
		if w <= 0:
			w = 1                                        # authored entries are never unpickable
		running += w
		table.append(running)
	var roll := rng.randi_range(0, running - 1)
	for k in table.size():
		if roll < table[k]:
			return k
	return eligible.size() - 1                           # unreachable; defensive
