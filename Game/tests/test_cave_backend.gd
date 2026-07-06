extends Node
## Headless acceptance test for M1.10 T0 — the CaveBackend (CA caverns, the
## second generation backend behind BandPipeline).
##
## Run as a SCENE (not --script) so the EventBus / RNG autoload globals resolve
## at compile time, exactly as in the real game:
##   godot --headless --path Game res://tests/test_cave_backend.tscn
##
## Assertion groups (mirroring test_bandgen_determinism C1-C5 + parity P-groups):
##   C1  same seed  -> byte-identical fingerprint (+ floor_fingerprint), twice,
##       THROUGH BandPipeline.generate (dispatch included in the bar)
##   C2  different seeds differ (>= 2 distinct fingerprints)
##   C3  connectivity, both levels: is_band_connected (piece) + is_fully_connected (cell)
##   C4  structural invariants (disjoint chunks; border intact; entry == pieces[0];
##       synthetic-piece fields; pieces >= 2; max_depth >= 4 on the DEFAULT config;
##       deepest_piece.depth_index == max_depth)
##   C5  purity under RNG perturbation
##   C6  region keep + carve determinism across a fragmenting knob/seed matrix
##       (+ non-vacuity: >= 1 seed produced > 1 raw region, via last_region_count)
##   C7  rc-invariance (cave ignores rc: r4-on / lvl-on fp == rc-null fp)
##   C8  fail-loud guards (null/wrong-typed config; flavor-bearing; degenerate; scatter)
##   C9  socket-control regression (band_greybox + band_two reproduce in-run)
##   C10 player-scale 2x2-open invariant (T non-empty, single-component, contains
##       entry anchor, covers the floor), per seed, on BOTH test configs

const SEEDS := [12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]
const GREYBOX_PROFILE := "res://data/bands/band_greybox.tres"
const BAND_TWO_PROFILE := "res://data/bands/band_two.tres"


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []
	var pipe := BandPipeline.new()
	var default_cfg := _make_default_config()
	var frag_cfg := _make_fragmenting_config()
	var cave_profile := _make_cave_profile(default_cfg)

	_c1_determinism(pipe, cave_profile, failures)
	_c2_variation(pipe, cave_profile, failures)
	_c3_connectivity(pipe, cave_profile, failures)
	_c4_structure(pipe, cave_profile, default_cfg, failures)
	_c5_purity(pipe, cave_profile, failures)
	_c6_carve_determinism(pipe, frag_cfg, failures)
	_c7_rc_invariance(pipe, cave_profile, failures)
	_c8_fail_loud(pipe, failures)
	_c9_socket_control(pipe, failures)
	_c10_player_scale(pipe, cave_profile, default_cfg, failures)
	_c10_player_scale(pipe, _make_cave_profile(frag_cfg), frag_cfg, failures)

	if failures.is_empty():
		var sample := pipe.generate(cave_profile, 12345)
		print("CAVE BACKEND OK — determinism + connectivity + player-scale verified across %d seeds (sample seed 12345 -> %d pieces, max_depth=%d, fp=%s)"
			% [SEEDS.size(), sample.pieces.size(), sample.max_depth, sample.fingerprint().substr(0, 12)])
		return 0
	for f in failures:
		printerr("CAVE BACKEND FAIL: ", f)
	return 1


# --- Config / profile builders ------------------------------------------------

func _make_default_config() -> CaveBandConfig:
	return CaveBandConfig.new()  # 56x56 defaults — "the default config" for C4/C10


## Fragmenting config: under-smoothed + higher fill -> many secondary regions,
## so keep/discard/carve is actually exercised (C6 non-vacuity). Non-default on
## several knobs so defaults-drift cannot mask a dead knob.
func _make_fragmenting_config() -> CaveBandConfig:
	var c := CaveBandConfig.new()
	c.fill_pct = 52
	c.smooth_passes = 1
	c.min_region_cells = 6
	c.min_floor_cells = 150
	return c


func _make_cave_profile(cfg: CaveBandConfig) -> BandProfile:
	var p := BandProfile.new()
	p.id = &"test_cave"
	p.backend = "cave"
	p.backend_config = cfg
	p.archetype = "linear"
	p.band_depth = 3
	return p


func _r4_on_rc() -> RunConfig:
	var rc := RunConfig.new()
	rc.r4_enabled = true
	rc.r4_branch_chance_base = 0.0
	rc.r4_branch_per_depth = 0.10
	rc.r4_max_branch_depth = 8
	return rc


func _lvl_on_rc() -> RunConfig:
	var rc := RunConfig.new()
	rc.lvl_enabled = true
	rc.lvl_room_count = 20
	return rc


# --- C1: same seed -> byte-identical fingerprint (+ floor_fingerprint) --------

func _c1_determinism(pipe: BandPipeline, prof: BandProfile, failures: Array[String]) -> void:
	for seed in SEEDS:
		var a := pipe.generate(prof, seed)
		var b := pipe.generate(prof, seed)
		if a == null or b == null:
			failures.append("C1 seed %d produced a null band" % seed)
			continue
		if a.fingerprint() != b.fingerprint():
			failures.append("C1 seed %d NOT deterministic: %s vs %s"
				% [seed, a.fingerprint().substr(0, 12), b.fingerprint().substr(0, 12)])
		if a.floor_fingerprint() != b.floor_fingerprint():
			failures.append("C1 seed %d floor_fingerprint NOT deterministic" % seed)


# --- C2: different seeds differ ------------------------------------------------

func _c2_variation(pipe: BandPipeline, prof: BandProfile, failures: Array[String]) -> void:
	var distinct := {}
	for seed in SEEDS:
		distinct[pipe.generate(prof, seed).fingerprint()] = true
	if distinct.size() < 2:
		failures.append("C2 all %d seeds yielded the SAME cave layout (no variation)" % SEEDS.size())


# --- C3: connectivity at both levels ------------------------------------------

func _c3_connectivity(pipe: BandPipeline, prof: BandProfile, failures: Array[String]) -> void:
	var gen := BandGenerator.new()
	var conn := ConnectivityGuarantee.new()
	for seed in SEEDS:
		var band := pipe.generate(prof, seed)
		if not gen.is_band_connected(band):
			failures.append("C3 seed %d: piece-level is_band_connected FALSE" % seed)
		if not conn.is_fully_connected(band):
			failures.append("C3 seed %d: cell-level is_fully_connected FALSE" % seed)


# --- C4: structural invariants ------------------------------------------------

func _c4_structure(pipe: BandPipeline, prof: BandProfile, cfg: CaveBandConfig,
		failures: Array[String]) -> void:
	var w := cfg.grid_width
	var h := cfg.grid_height
	for seed in SEEDS:
		var band := pipe.generate(prof, seed)
		if band == null:
			failures.append("C4 seed %d null band" % seed)
			continue

		# Depth axis exists.
		if band.pieces.size() < 2:
			failures.append("C4 seed %d: pieces.size() = %d < 2 (mega-piece)" % [seed, band.pieces.size()])

		# Disjoint chunk footprints.
		var seen := {}
		var overlap := false
		for p in band.pieces:
			for c in p.footprint_cells:
				if seen.has(c):
					overlap = true
				seen[c] = true
		if overlap:
			failures.append("C4 seed %d: pieces share a footprint cell (chunks not disjoint)" % seed)

		# Border ring intact: every floor cell is strictly inside the interior.
		var bad_border := false
		for p in band.pieces:
			for c in p.floor_cells:
				if c.x < 1 or c.y < 1 or c.x > w - 2 or c.y > h - 2:
					bad_border = true
		if bad_border:
			failures.append("C4 seed %d: a floor cell lies on/outside the border ring" % seed)

		# Entry is pieces[0] and its floor_cells[0] is the (front-positioned) anchor.
		if band.entry_piece != band.pieces[0]:
			failures.append("C4 seed %d: entry_piece != pieces[0]" % seed)
		if band.entry_piece.floor_cells.is_empty():
			failures.append("C4 seed %d: entry piece has no floor cells" % seed)

		# Synthetic-piece fields: no sockets, entry-piece mated marker.
		for p in band.pieces:
			if p.mated_socket_index != -1:
				failures.append("C4 seed %d: piece mated_socket_index != -1" % seed)
			if not p.open_sockets.is_empty():
				failures.append("C4 seed %d: piece has open_sockets" % seed)
			if p.instance != null:
				failures.append("C4 seed %d: synthetic piece has a non-null instance" % seed)
			if not String(p.piece_id).begins_with("cave_"):
				failures.append("C4 seed %d: piece_id '%s' lacks the cave_ prefix" % [seed, p.piece_id])

		# Depth: default config must reach max_depth >= 4 (Q1 hard bar), and the
		# deepest piece sits at the maximum depth (grade ran in the pipeline).
		if band.max_depth < 4:
			failures.append("C4 seed %d: max_depth %d < 4 on the default config" % [seed, band.max_depth])
		if band.deepest_piece == null or band.deepest_piece.depth_index != band.max_depth:
			var di := -999 if band.deepest_piece == null else band.deepest_piece.depth_index
			failures.append("C4 seed %d: deepest_piece.depth_index %d != max_depth %d" % [seed, di, band.max_depth])


# --- C5: purity under RNG perturbation ----------------------------------------

func _c5_purity(pipe: BandPipeline, prof: BandProfile, failures: Array[String]) -> void:
	var first := pipe.generate(prof, 424242)
	RNG.seed_from(987654321)
	RNG.randi()
	var second := pipe.generate(prof, 424242)
	if first.fingerprint() != second.fingerprint():
		failures.append("C5: seed 424242 differed across runs despite RNG perturbation (retry/fill not pure)")


# --- C6: region keep + carve determinism (+ non-vacuity) ----------------------

func _c6_carve_determinism(pipe: BandPipeline, frag_cfg: CaveBandConfig,
		failures: Array[String]) -> void:
	var frag_profile := _make_cave_profile(frag_cfg)
	var conn := ConnectivityGuarantee.new()
	for seed in SEEDS:
		var a := pipe.generate(frag_profile, seed)
		var b := pipe.generate(frag_profile, seed)
		if a.fingerprint() != b.fingerprint():
			failures.append("C6 seed %d: fragmenting config NOT deterministic" % seed)
		if not conn.is_fully_connected(a):
			failures.append("C6 seed %d: fragmenting config band NOT fully connected (carve failed to unify)" % seed)

	# Non-vacuity: the fragmenting config must actually produce > 1 raw region on
	# >= 1 seed, so a green carve-determinism sweep proves carve/discard ran.
	var backend := CaveBackend.new()
	var any_multi := false
	for seed in SEEDS:
		backend.generate(seed, frag_cfg)
		if backend.last_region_count > 1:
			any_multi = true
	if not any_multi:
		failures.append("C6 VACUOUS: no fragmenting seed produced > 1 raw flood region (carve never exercised)")


# --- C7: rc-invariance (cave ignores rc) --------------------------------------

func _c7_rc_invariance(pipe: BandPipeline, prof: BandProfile, failures: Array[String]) -> void:
	var r4 := _r4_on_rc()
	var lvl := _lvl_on_rc()
	for seed in SEEDS:
		var base_fp := pipe.generate(prof, seed).fingerprint()
		if pipe.generate(prof, seed, r4).fingerprint() != base_fp:
			failures.append("C7 seed %d: r4-on rc changed the cave fingerprint (backend must ignore rc)" % seed)
		if pipe.generate(prof, seed, lvl).fingerprint() != base_fp:
			failures.append("C7 seed %d: lvl-on rc changed the cave fingerprint (backend must ignore rc)" % seed)


# --- C8: fail-loud guards -----------------------------------------------------

func _c8_fail_loud(pipe: BandPipeline, failures: Array[String]) -> void:
	# Cave profile with NO backend_config -> null (validate).
	var no_cfg := BandProfile.new()
	no_cfg.id = &"cave_no_cfg"
	no_cfg.backend = "cave"
	if pipe.generate(no_cfg, 1) != null:
		failures.append("C8: cave profile with null config did not return null")

	# Cave profile with a WRONG-TYPED (BandGenConfig) backend_config -> null.
	var wrong := BandProfile.new()
	wrong.id = &"cave_wrong_cfg"
	wrong.backend = "cave"
	wrong.backend_config = BandGenConfig.new()
	if pipe.generate(wrong, 1) != null:
		failures.append("C8: cave profile with a BandGenConfig did not return null")

	# Cave profile with a FLAVOR stage -> null (flavors ship empty; validate).
	var flavored := BandProfile.new()
	flavored.id = &"cave_flavored"
	flavored.backend = "cave"
	flavored.backend_config = CaveBandConfig.new()
	flavored.flavors = [Resource.new()]
	if pipe.generate(flavored, 1) != null:
		failures.append("C8: flavor-bearing cave profile did not return null")

	# DEGENERATE config (grid too small) -> null (validate).
	var degen := BandProfile.new()
	degen.id = &"cave_degen"
	degen.backend = "cave"
	var dc := CaveBandConfig.new()
	dc.grid_width = 4
	degen.backend_config = dc
	if pipe.generate(degen, 1) != null:
		failures.append("C8: degenerate (grid_width=4) cave config did not return null")

	# Config-less scatter profile -> null (M1.11 U0 wired scatter; the fail-loud
	# moved from the wiring guard to validate() — assertion unchanged).
	var scatter := BandProfile.new()
	scatter.id = &"scatter_x"
	scatter.backend = "scatter"
	if pipe.generate(scatter, 1) != null:
		failures.append("C8: backend 'scatter' did not return null")


# --- C9: socket-control regression --------------------------------------------

func _c9_socket_control(pipe: BandPipeline, failures: Array[String]) -> void:
	for path in [GREYBOX_PROFILE, BAND_TWO_PROFILE]:
		var prof := load(path) as BandProfile
		if prof == null:
			failures.append("C9: could not load %s" % path)
			continue
		var a := pipe.generate(prof, 12345)
		var b := pipe.generate(prof, 12345)
		if a == null or b == null:
			failures.append("C9: %s produced a null band" % path)
			continue
		if a.fingerprint() != b.fingerprint():
			failures.append("C9: %s fingerprint not reproducible (dispatch broke the socket path)" % path)


# --- C10: player-scale (2x2-open) invariant -----------------------------------

func _c10_player_scale(pipe: BandPipeline, prof: BandProfile, cfg: CaveBandConfig,
		failures: Array[String]) -> void:
	var tag := "%dx%d f%d s%d" % [cfg.grid_width, cfg.grid_height, cfg.fill_pct, cfg.smooth_passes]
	for seed in SEEDS:
		var band := pipe.generate(prof, seed)
		if band == null:
			continue
		var floor_set := {}
		for p in band.pieces:
			for c in p.floor_cells:
				floor_set[c] = true
		var t := _traversable_set(floor_set)

		if t.is_empty():
			failures.append("C10 [%s] seed %d: traversable set T is EMPTY" % [tag, seed])
			continue
		# Single component (BFS over T, 4-adjacency).
		if _component_count(t) != 1:
			failures.append("C10 [%s] seed %d: T has %d components (not single)" % [tag, seed, _component_count(t)])
		# Entry anchor is a T member.
		if not t.has(band.entry_piece.floor_cells[0]):
			failures.append("C10 [%s] seed %d: entry anchor not in T (not player-scale)" % [tag, seed])
		# Every floor cell is a member of, or 4-adjacent to, T.
		if not _floor_covered_by_t(floor_set, t):
			failures.append("C10 [%s] seed %d: a floor cell is > 1 cell from T (isolated non-standable)" % [tag, seed])


# --- C10 helpers (Vector2i-keyed, mirroring the backend's integer T) ----------

func _traversable_set(floor_set: Dictionary) -> Dictionary:
	var t := {}
	for c in floor_set:
		var r: Vector2i = c + Vector2i(1, 0)
		var d: Vector2i = c + Vector2i(0, 1)
		var rd: Vector2i = c + Vector2i(1, 1)
		if floor_set.has(r) and floor_set.has(d) and floor_set.has(rd):
			t[c] = true
			t[r] = true
			t[d] = true
			t[rd] = true
	return t


func _component_count(members: Dictionary) -> int:
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var visited := {}
	var comps := 0
	for start in members:
		if visited.has(start):
			continue
		comps += 1
		var queue: Array[Vector2i] = [start]
		visited[start] = true
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			for s in steps:
				var n: Vector2i = cur + s
				if members.has(n) and not visited.has(n):
					visited[n] = true
					queue.append(n)
	return comps


func _floor_covered_by_t(floor_set: Dictionary, t: Dictionary) -> bool:
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for c in floor_set:
		if t.has(c):
			continue
		var adj := false
		for s in steps:
			if t.has(c + s):
				adj = true
				break
		if not adj:
			return false
	return true
