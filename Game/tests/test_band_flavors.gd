extends Node
## S5 acceptance — band flavor stages: SetPieceInject + WearDecay + the
## Stage-5 connectivity guarantee (M1.9, spec §6.2 checks 1-8).
##
## Run as a SCENE (not --script) so the autoload globals resolve at compile
## time, exactly as in the real game:
##   godot --headless --path Game res://tests/test_band_flavors.tscn
##
## Profiles are built IN CODE (BandProfile.new() + config resources) against
## S1's band_greybox inputs, across the test_bandgen_determinism seed matrix:
##   F1. control unmoved: empty-flavors profile fingerprint() byte-matches the
##       direct BandGenerator path per seed (the wave contract, with the
##       flavor plumbing present)
##   F2. SetPieceInject determinism: same seed+profile -> same fp twice; fp
##       moves off control; control layout is a STRICT PREFIX; caps respected;
##       host socket satisfied min_depth_norm; a 1.1 gate injects nothing
##   F3. WearDecay determinism + fp-invariance: same floor_fingerprint()
##       twice; fingerprint() byte-equals control (off-fingerprint, asserted
##       not assumed); floor fps vary across seeds
##   F4. WearDecay cannot strand (the DoD test): max decay across the matrix
##       -> cell-level fully connected, no unreachable-depth sentinel, and the
##       sweep is NON-VACUOUS (decay committed ops on >= 1 seed)
##   F5. tree-topology fact pinned (conditional per §10 C2): precondition
##       edges == n-1 asserted first, then breach 0 / block 8 -> ZERO block
##       journal entries and floor fp == control
##   F6. CARVE unit test: hand-block a doorway bypassing the inline reject ->
##       disconnected -> enforce(CARVE, journal) reconnects + restores tiles
##       and floor_cells
##   F7. ordering/composition: [SetPieceInject, WearDecay] deterministic;
##       set-piece placed; band stays connected (the e4×e5 decayed-vault path)
##   F8. salt independence: two WearDecay entries draw distinct index-mixed
##       sub-streams -> floor fp differs from the single-entry run

const CONFIG_PATH := "res://data/bandgen_config.tres"
const CATALOG_PATH := "res://data/piece_catalog.tres"

## The existing large piece the vault reuses (D-RAT-3: no bespoke landmark).
const VAULT_PIECE_ID := &"piece_box_large"

# Same spread as test_bandgen_determinism.gd (the determinism matrix).
const SEEDS := [12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]


func _ready() -> void:
	var code := _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []

	var cfg := load(CONFIG_PATH) as BandGenConfig
	var catalog := load(CATALOG_PATH) as PieceCatalog
	if cfg == null or catalog == null:
		printerr("FLAVORS FAIL: could not load bandgen config/catalog")
		return 1

	_check_control(failures)
	_check_set_piece_inject(failures)
	_check_wear_decay_determinism(failures)
	_check_strand_proof(failures)
	_check_tree_topology_fact(failures)
	_check_carve_unit(failures)
	_check_composition(failures)
	_check_salt_independence(failures)

	if failures.is_empty():
		print("BAND FLAVORS OK — SetPieceInject + WearDecay + connectivity guarantee verified across %d seeds"
				% SEEDS.size())
		return 0
	for f in failures:
		printerr("FLAVORS FAIL: ", f)
	return 1


# --- Profile / config builders --------------------------------------------------

func _make_profile(flavors: Array[Resource]) -> BandProfile:
	var p := BandProfile.new()
	p.id = &"synthetic_flavors"
	p.backend = "socket"
	p.backend_config = load(CONFIG_PATH)
	p.piece_pool = load(CATALOG_PATH) as PieceCatalog
	p.flavors = flavors
	return p


func _vault_entry(min_depth_norm: float) -> SetPieceEntry:
	var entry := SetPieceEntry.new()
	entry.piece = _catalog_piece(VAULT_PIECE_ID)
	entry.min_depth_norm = min_depth_norm
	return entry


func _catalog_piece(piece_id: StringName) -> ZonePieceData:
	var catalog := load(CATALOG_PATH) as PieceCatalog
	for zpd in catalog.pieces:
		if zpd.piece_id == piece_id:
			return zpd
	return null


func _inject_config(min_depth_norm: float, max_total: int = 1) -> SetPieceInjectConfig:
	var c := SetPieceInjectConfig.new()
	var entries: Array[SetPieceEntry] = [_vault_entry(min_depth_norm)]
	c.entries = entries
	c.max_total = max_total
	return c


func _decay_config(level: float, breach: int, block: int,
		state: StringName = &"flooded") -> WearDecayConfig:
	var c := WearDecayConfig.new()
	c.state = state
	c.decay_level = level
	c.breach_budget = breach
	c.block_budget = block
	return c


# --- F1. Control unmoved (the wave contract) -------------------------------------

func _check_control(failures: Array[String]) -> void:
	var gen := BandGenerator.new()
	var pipe := BandPipeline.new()
	var cfg := load(CONFIG_PATH) as BandGenConfig
	var catalog: Array[ZonePieceData] = (load(CATALOG_PATH) as PieceCatalog).pieces
	var empty: Array[Resource] = []
	var profile := _make_profile(empty)
	for seed in SEEDS:
		var direct := gen.generate(seed, cfg, catalog)
		var piped := pipe.generate(profile, seed)
		if direct == null or piped == null:
			failures.append("F1 seed %d: null band" % seed)
		elif direct.fingerprint() != piped.fingerprint():
			failures.append("F1 seed %d: empty-flavors pipeline fp != direct fp (%s vs %s)"
					% [seed, piped.fingerprint().substr(0, 12), direct.fingerprint().substr(0, 12)])
		_free_band(direct)
		_free_band(piped)


# --- F2. SetPieceInject determinism + policy -------------------------------------

func _check_set_piece_inject(failures: Array[String]) -> void:
	var empty: Array[Resource] = []
	var control_profile := _make_profile(empty)
	var inject_flavors: Array[Resource] = [_inject_config(0.5, 1)]
	var profile := _make_profile(inject_flavors)
	var gated_flavors: Array[Resource] = [_inject_config(1.1, 1)]
	var gated_profile := _make_profile(gated_flavors)

	var total_injected := 0
	for seed in SEEDS:
		var control := BandPipeline.new().generate(control_profile, seed)
		var a := BandPipeline.new().generate(profile, seed)
		var b := BandPipeline.new().generate(profile, seed)   # fresh pipeline instance
		if control == null or a == null or b == null:
			failures.append("F2 seed %d: null band" % seed)
			_free_band(control); _free_band(a); _free_band(b)
			continue

		# Determinism: same seed + profile -> same fp twice.
		if a.fingerprint() != b.fingerprint():
			failures.append("F2 seed %d: inject NOT deterministic (%s vs %s)"
					% [seed, a.fingerprint().substr(0, 12), b.fingerprint().substr(0, 12)])

		# Strict-prefix property: the control layout is a prefix of the flavored one.
		if a.pieces.size() < control.pieces.size():
			failures.append("F2 seed %d: flavored band SHORTER than control (%d < %d)"
					% [seed, a.pieces.size(), control.pieces.size()])
		else:
			for i in control.pieces.size():
				var cp := control.pieces[i]
				var fp := a.pieces[i]
				if cp.piece_id != fp.piece_id or cp.offset_cell != fp.offset_cell \
						or cp.mated_socket_index != fp.mated_socket_index:
					failures.append("F2 seed %d: control not a strict prefix at piece %d" % [seed, i])
					break

		# Cap + identity of the injected suffix.
		var injected := a.pieces.size() - control.pieces.size()
		if injected > 1:
			failures.append("F2 seed %d: %d pieces injected > max_total 1" % [seed, injected])
		for i in range(control.pieces.size(), a.pieces.size()):
			if a.pieces[i].piece_id != VAULT_PIECE_ID:
				failures.append("F2 seed %d: injected piece %d id '%s' != '%s'"
						% [seed, i, a.pieces[i].piece_id, VAULT_PIECE_ID])
		if injected > 0:
			total_injected += injected
			# fp legitimately moved off control.
			if a.fingerprint() == control.fingerprint():
				failures.append("F2 seed %d: piece injected but fp unchanged from control" % seed)
			# Anchors never reassigned (spec §3.3): extraction anchor stays on the spine.
			if a.deepest_piece.piece_id != control.deepest_piece.piece_id \
					or a.pieces.find(a.deepest_piece) != control.pieces.find(control.deepest_piece):
				failures.append("F2 seed %d: deepest_piece was reassigned by injection" % seed)
			# Host depth gate: some prefix piece adjacent to the vault satisfied
			# min_depth_norm against the provisional (control-shaped) grade.
			if control.max_depth > 0:
				for i in range(control.pieces.size(), a.pieces.size()):
					if not _has_deep_adjacent_host(a, i, control.pieces.size(),
							control.max_depth, 0.5):
						failures.append("F2 seed %d: injected piece %d attached to a host below min_depth_norm 0.5"
								% [seed, i])
			# Connectivity ASSERT path: injection can never disconnect.
			if not ConnectivityGuarantee.new().is_fully_connected(a):
				failures.append("F2 seed %d: injected band NOT fully connected" % seed)

		# Graceful-skip path: an unsatisfiable gate injects nothing (fp == control).
		var g := BandPipeline.new().generate(gated_profile, seed)
		if g == null or g.fingerprint() != control.fingerprint():
			failures.append("F2 seed %d: min_depth_norm 1.1 profile did not reproduce control fp" % seed)
		_free_band(g)

		_free_band(control)
		_free_band(a)
		_free_band(b)

	# Non-vacuous: the machinery must actually inject somewhere in the matrix.
	if total_injected <= 0:
		failures.append("F2: no seed injected the set-piece — machinery not proven (vacuous)")


## True when some ORIGINAL (prefix) piece 4-adjacent (floor-floor) to injected
## piece `idx` has depth_index/control_max_depth >= gate (the host passed the
## provisional depth gate; leaf appends never change prefix depth_index).
func _has_deep_adjacent_host(band: Band, idx: int, prefix_n: int,
		control_max_depth: int, gate: float) -> bool:
	var cell_owner := {}
	for i in prefix_n:
		for c in band.pieces[i].floor_cells:
			cell_owner[c] = i
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for c in band.pieces[idx].floor_cells:
		for step in steps:
			var n: Vector2i = c + step
			if cell_owner.has(n):
				var host: int = cell_owner[n]
				var norm := float(band.pieces[host].depth_index) / float(control_max_depth)
				if norm >= gate - 0.0001:
					return true
	return false


# --- F3. WearDecay determinism + fingerprint invariance ---------------------------

func _check_wear_decay_determinism(failures: Array[String]) -> void:
	var empty: Array[Resource] = []
	var control_profile := _make_profile(empty)
	var decay_flavors: Array[Resource] = [_decay_config(1.0, 2, 2)]
	var profile := _make_profile(decay_flavors)

	var floor_fps := {}
	for seed in SEEDS:
		var control := BandPipeline.new().generate(control_profile, seed)
		var a := BandPipeline.new().generate(profile, seed)
		var b := BandPipeline.new().generate(profile, seed)
		if control == null or a == null or b == null:
			failures.append("F3 seed %d: null band" % seed)
			_free_band(control); _free_band(a); _free_band(b)
			continue
		if a.floor_fingerprint() != b.floor_fingerprint():
			failures.append("F3 seed %d: decay floor_fp NOT deterministic" % seed)
		# The off-fingerprint claim, asserted not assumed: piece list untouched.
		if a.fingerprint() != control.fingerprint():
			failures.append("F3 seed %d: WearDecay MOVED fingerprint() (%s vs control %s)"
					% [seed, a.fingerprint().substr(0, 12), control.fingerprint().substr(0, 12)])
		floor_fps[a.floor_fingerprint()] = true
		_free_band(control)
		_free_band(a)
		_free_band(b)

	if floor_fps.size() < 2:
		failures.append("F3: all seeds yielded the SAME floor_fingerprint (no variation)")


# --- F4. WearDecay cannot strand (the DoD test) -----------------------------------

func _check_strand_proof(failures: Array[String]) -> void:
	var empty: Array[Resource] = []
	var control_profile := _make_profile(empty)
	var aggressive: Array[Resource] = [_decay_config(1.0, 8, 8)]
	var profile := _make_profile(aggressive)
	var conn := ConnectivityGuarantee.new()

	var any_decayed := false
	for seed in SEEDS:
		var control := BandPipeline.new().generate(control_profile, seed)
		var band := BandPipeline.new().generate(profile, seed)
		if band == null or control == null:
			failures.append("F4 seed %d: null band" % seed)
			_free_band(control); _free_band(band)
			continue
		# Cell-level full coverage: the player can reach everywhere that matters.
		if not conn.is_fully_connected(band):
			failures.append("F4 seed %d: MAX decay stranded floor cells (connectivity lost)" % seed)
		# No DepthGrader unreachable sentinel (depth_index == pieces.size()) —
		# every piece incl. deepest_piece (the extraction anchor) is reached.
		for i in band.pieces.size():
			if band.pieces[i].depth_index >= band.pieces.size():
				failures.append("F4 seed %d: piece %d carries the unreachable-depth sentinel" % [seed, i])
				break
		if band.deepest_piece.depth_index >= band.pieces.size():
			failures.append("F4 seed %d: deepest_piece (extraction anchor) unreachable" % seed)
		if band.floor_fingerprint() != control.floor_fingerprint():
			any_decayed = true
		_free_band(control)
		_free_band(band)

	if not any_decayed:
		failures.append("F4: max decay changed NO floor on any seed — strand-proof sweep is vacuous")


# --- F5. Tree-topology fact pinned (conditional, §10 C2) ---------------------------

func _check_tree_topology_fact(failures: Array[String]) -> void:
	var empty: Array[Resource] = []
	var control_profile := _make_profile(empty)
	var block_only: Array[Resource] = [_decay_config(1.0, 0, 8)]
	var profile := _make_profile(block_only)
	var probe := WearDecayStage.new(_decay_config(1.0, 0, 8))

	for seed in SEEDS:
		var control := BandPipeline.new().generate(control_profile, seed)
		if control == null:
			failures.append("F5 seed %d: null control band" % seed)
			continue
		# PRECONDITION (§10 C2): the pre-decay piece-adjacency graph is a tree
		# (edges == n - 1). If a future seed/config trips this, fail HERE.
		var edges: int = probe._enumerate_doorways(control).size()
		if edges != control.pieces.size() - 1:
			failures.append("F5 seed %d: PRECONDITION broken — adjacency edges %d != pieces-1 %d (band not a tree; zero-blocks assertion would be stale)"
					% [seed, edges, control.pieces.size() - 1])
			_free_band(control)
			continue

		# On a tree, EVERY block is a bridge cut -> all rejected -> floor unchanged.
		var band := BandPipeline.new().generate(profile, seed)
		if band == null or band.floor_fingerprint() != control.floor_fingerprint():
			failures.append("F5 seed %d: block-only decay on a tree band CHANGED the floor (a block landed?)" % seed)
		_free_band(band)

		# Journal-level proof on a dedicated band: zero committed block ops.
		var direct := BandPipeline.new().generate(control_profile, seed)
		var stage := WearDecayStage.new(_decay_config(1.0, 0, 8))
		stage.apply(direct, control_profile,
				BandPipeline._stage_seed(direct.resolved_seed, 0x57454152, 0))
		for op in stage.journal():
			if op["kind"] == &"block":
				failures.append("F5 seed %d: a block op was COMMITTED on an acyclic band" % seed)
				break
		_free_band(direct)
		_free_band(control)


# --- F6. CARVE unit test ------------------------------------------------------------

func _check_carve_unit(failures: Array[String]) -> void:
	var empty: Array[Resource] = []
	var control_profile := _make_profile(empty)
	var band := BandPipeline.new().generate(control_profile, 12345)
	if band == null:
		failures.append("F6: null band")
		return
	var conn := ConnectivityGuarantee.new()
	if not conn.is_fully_connected(band):
		failures.append("F6: control band not connected before the hand-block (setup broken)")
		_free_band(band)
		return

	# Hand-block the first doorway, BYPASSING the inline reject (spec §6.2-6).
	var doorways: Array = WearDecayStage.new(null)._enumerate_doorways(band)
	if doorways.is_empty():
		failures.append("F6: no doorway found on the control band (setup broken)")
		_free_band(band)
		return
	var d: Dictionary = doorways[0]
	var piece_i: PlacedPiece = band.pieces[d["i"]]
	var writes: Array = []
	for cell in d["cells_i"]:
		WearDecayStage._write_cell(piece_i, cell, ConnectivityGuarantee.WALL_ATLAS, writes)
	var journal: Array = [{"kind": &"block", "writes": writes}]

	if conn.is_fully_connected(band):
		failures.append("F6: hand-blocked doorway did NOT disconnect the band (test premise broken)")
	elif not conn.enforce(band, ConnectivityGuarantee.Mode.CARVE, journal):
		failures.append("F6: CARVE failed to reconnect the band")
	else:
		# Tiles + floor_cells restored.
		var geo := piece_i.instance.get_node_or_null("Geometry") as TileMapLayer
		for cell in d["cells_i"]:
			if not piece_i.floor_cells.has(cell):
				failures.append("F6: floor_cells not restored at %s" % str(cell))
				break
			if geo != null and geo.get_cell_atlas_coords(cell - piece_i.offset_cell) \
					!= ConnectivityGuarantee.FLOOR_ATLAS:
				failures.append("F6: FLOOR tile not restored at %s" % str(cell))
				break
		if not journal.is_empty():
			failures.append("F6: CARVE left %d op(s) in the journal after reverting" % journal.size())
	_free_band(band)


# --- F7. Ordering / composition (the decayed vault) --------------------------------

func _check_composition(failures: Array[String]) -> void:
	var empty: Array[Resource] = []
	var control_profile := _make_profile(empty)
	var combo: Array[Resource] = [_inject_config(0.5, 1), _decay_config(1.0, 2, 2)]
	var profile := _make_profile(combo)
	var conn := ConnectivityGuarantee.new()

	var any_injected := false
	for seed in SEEDS:
		var control := BandPipeline.new().generate(control_profile, seed)
		var a := BandPipeline.new().generate(profile, seed)
		var b := BandPipeline.new().generate(profile, seed)
		if control == null or a == null or b == null:
			failures.append("F7 seed %d: null band" % seed)
			_free_band(control); _free_band(a); _free_band(b)
			continue
		if a.fingerprint() != b.fingerprint() \
				or a.floor_fingerprint() != b.floor_fingerprint():
			failures.append("F7 seed %d: [inject, decay] composition NOT deterministic" % seed)
		# Inject runs before decay (array order): the set-piece is in the piece
		# list (prefix property held), and decay never disconnects the result.
		if a.pieces.size() > control.pieces.size():
			any_injected = true
		if not conn.is_fully_connected(a):
			failures.append("F7 seed %d: composed band NOT fully connected" % seed)
		_free_band(control)
		_free_band(a)
		_free_band(b)

	if not any_injected:
		failures.append("F7: composition never injected the set-piece across the matrix (vacuous)")


# --- F8. Salt independence (index-mixed sub-streams) --------------------------------

func _check_salt_independence(failures: Array[String]) -> void:
	# Budget-1 breach-only stages: the as-built greybox bands carry at most ~2
	# width-2 breach runs, so a bigger budget would let the FIRST stage exhaust
	# the run list and leave the second (index-1 sub-stream) provably idle.
	var single: Array[Resource] = [_decay_config(1.0, 1, 0)]
	var double: Array[Resource] = [_decay_config(1.0, 1, 0), _decay_config(1.0, 1, 0)]
	var single_profile := _make_profile(single)
	var double_profile := _make_profile(double)

	var any_differs := false
	for seed in SEEDS:
		var s := BandPipeline.new().generate(single_profile, seed)
		var d1 := BandPipeline.new().generate(double_profile, seed)
		var d2 := BandPipeline.new().generate(double_profile, seed)
		if s == null or d1 == null or d2 == null:
			failures.append("F8 seed %d: null band" % seed)
			_free_band(s); _free_band(d1); _free_band(d2)
			continue
		if d1.floor_fingerprint() != d2.floor_fingerprint():
			failures.append("F8 seed %d: double-decay profile NOT deterministic" % seed)
		if d1.floor_fingerprint() != s.floor_fingerprint():
			any_differs = true
		_free_band(s)
		_free_band(d1)
		_free_band(d2)

	if not any_differs:
		failures.append("F8: a second WearDecay entry changed NOTHING on every seed — index-mixed sub-stream not proven")


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
