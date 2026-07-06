extends Node
## Headless acceptance test for M1.11 U0 — the ScatterBackend (open-field
## arena, the third generation backend behind BandPipeline).
##
## Run as a SCENE (not --script) so the EventBus / RNG autoload globals resolve
## at compile time, exactly as in the real game:
##   godot --headless --path Game res://tests/test_scatter_backend.tscn
##
## Assertion groups (mirroring test_cave_backend C1-C10, renamed S*, plus the
## S11 long-sightline identity bar — U0 spec §5 as corrected by RD-4):
##   S1  same seed -> byte-identical fingerprint (+ floor_fingerprint), twice,
##       THROUGH BandPipeline.generate (dispatch inside the bar), both configs
##   S2  different seeds differ (>= 2 distinct fingerprints)
##   S3  connectivity, both levels: is_band_connected (piece) + is_fully_connected
##       (cell), per seed, both configs — RD-6's by-construction claim's teeth
##   S4  structural invariants (disjoint chunks; border intact; entry == pieces[0]
##       with floor_cells[0] in T; synthetic-piece fields; scat_ prefix;
##       pieces >= 2; max_depth >= 4 on the DEFAULT config;
##       deepest_piece.depth_index == max_depth)
##   S5  purity under RNG perturbation (the fixed-length 1+4S stream, RD-13)
##   S6  dense-config sampler determinism + the anti-maze invariant asserted
##       DIRECTLY (every pair of cover blobs >= min_cover_spacing Chebyshev
##       apart) + non-vacuity via backend stats (cover stamped on every seed;
##       spacing rejection exercised on >= 1 seed)
##   S7  rc-invariance (scatter ignores rc: r4-on / lvl-on fp == rc-null fp)
##   S8  fail-loud guards (null/wrong-typed/flavored profile; every RD-8
##       validate() clamp: extents, spacing < 3, margin < 2, zero weight sum,
##       lane wider than interior, chunks_x < 5)
##   S9  three-profile control regression (band_greybox + band_two + band_three
##       reproduce in-run; absolute goldens live in the existing suites)
##   S10 player-scale 2x2-open invariant, both configs — asserted in RD-6's
##       STRONG form (every floor cell IS in T; T single-component; entry in T)
##   S11 the long-sightline identity bar (RD-4): (a) the constructed full-width
##       lane (some row's uninterrupted floor run == grid_width - 2, load-
##       bearing); (b) build-calibrated openness percentile (measured values in
##       the U0 worklog); (c) the stratum bound cover_cells * s^2 <= 4 * interior

const SEEDS := [12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]
const GREYBOX_PROFILE := "res://data/bands/band_greybox.tres"
const BAND_TWO_PROFILE := "res://data/bands/band_two.tres"
const BAND_THREE_PROFILE := "res://data/bands/band_three.tres"

## S11(b) build-calibrated openness bar (RD-4: measured, not magic-numbered):
## percentage of floor cells whose max uninterrupted axis run (E-W or N-S)
## is >= K = min(interior_w, interior_h) / 2. Measured minima across the seed
## matrix at build time (2026-07-06): default config 99%, dense config 95%.
## Asserted floors carry margin below the measured minima.
const OPENNESS_MIN_PCT_DEFAULT := 90
const OPENNESS_MIN_PCT_DENSE := 75


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []
	var pipe := BandPipeline.new()
	var default_cfg := _make_default_config()
	var dense_cfg := _make_dense_config()
	var default_prof := _make_scatter_profile(default_cfg)
	var dense_prof := _make_scatter_profile(dense_cfg)

	_s1_determinism(pipe, default_prof, "default", failures)
	_s1_determinism(pipe, dense_prof, "dense", failures)
	_s2_variation(pipe, default_prof, failures)
	_s3_connectivity(pipe, default_prof, "default", failures)
	_s3_connectivity(pipe, dense_prof, "dense", failures)
	_s4_structure(pipe, default_prof, default_cfg, failures)
	_s5_purity(pipe, default_prof, failures)
	_s6_sampler(pipe, dense_prof, dense_cfg, failures)
	_s7_rc_invariance(pipe, default_prof, failures)
	_s8_fail_loud(pipe, failures)
	_s9_three_profile_control(pipe, failures)
	_s10_player_scale(pipe, default_prof, default_cfg, failures)
	_s10_player_scale(pipe, dense_prof, dense_cfg, failures)
	_s11_sightline(default_cfg, OPENNESS_MIN_PCT_DEFAULT, "default", failures)
	_s11_sightline(dense_cfg, OPENNESS_MIN_PCT_DENSE, "dense", failures)

	if failures.is_empty():
		var sample := pipe.generate(default_prof, 12345)
		print("SCATTER BACKEND OK — determinism + connectivity + player-scale + sightline identity verified across %d seeds (sample seed 12345 -> %d pieces, max_depth=%d, fp=%s)"
			% [SEEDS.size(), sample.pieces.size(), sample.max_depth, sample.fingerprint().substr(0, 12)])
		return 0
	for f in failures:
		printerr("SCATTER BACKEND FAIL: ", f)
	return 1


# --- Config / profile builders ------------------------------------------------

func _make_default_config() -> ScatterBandConfig:
	return ScatterBandConfig.new()  # 56x36 defaults — "the default config" for S4/S10/S11


## Dense config: non-default on several knobs (defaults-drift cannot mask a
## dead knob) and maximally stressing spacing rejection so the anti-maze
## machinery provably runs (S6 non-vacuity).
func _make_dense_config() -> ScatterBandConfig:
	var c := ScatterBandConfig.new()
	c.cover_density_pct = 90
	c.min_cover_spacing = 3
	c.edge_cover_bias_pct = 40
	c.clear_lane_width = 2
	return c


func _make_scatter_profile(cfg: ScatterBandConfig) -> BandProfile:
	var p := BandProfile.new()
	p.id = &"test_scatter"
	p.backend = "scatter"
	p.backend_config = cfg
	p.archetype = "linear"
	p.band_depth = 4
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


# --- Shared geometry helpers ---------------------------------------------------

func _floor_set_of(band: Band) -> Dictionary:
	var floor_set := {}
	for p in band.pieces:
		for c in p.floor_cells:
			floor_set[c] = true
	return floor_set


## Band-global cover set: footprint cells strictly inside the interior that are
## not floor (edge-chunk footprints include border-ring cells — excluded).
func _cover_set_of(band: Band, w: int, h: int) -> Dictionary:
	var floor_set := _floor_set_of(band)
	var cover := {}
	for p in band.pieces:
		for c in p.footprint_cells:
			if c.x >= 1 and c.y >= 1 and c.x <= w - 2 and c.y <= h - 2 \
					and not floor_set.has(c):
				cover[c] = true
	return cover


# --- S1: same seed -> byte-identical fingerprint (+ floor_fingerprint) --------

func _s1_determinism(pipe: BandPipeline, prof: BandProfile, tag: String,
		failures: Array[String]) -> void:
	for seed in SEEDS:
		var a := pipe.generate(prof, seed)
		var b := pipe.generate(prof, seed)
		if a == null or b == null:
			failures.append("S1 [%s] seed %d produced a null band" % [tag, seed])
			continue
		if a.fingerprint() != b.fingerprint():
			failures.append("S1 [%s] seed %d NOT deterministic: %s vs %s"
				% [tag, seed, a.fingerprint().substr(0, 12), b.fingerprint().substr(0, 12)])
		if a.floor_fingerprint() != b.floor_fingerprint():
			failures.append("S1 [%s] seed %d floor_fingerprint NOT deterministic" % [tag, seed])


# --- S2: different seeds differ ------------------------------------------------

func _s2_variation(pipe: BandPipeline, prof: BandProfile, failures: Array[String]) -> void:
	var distinct := {}
	for seed in SEEDS:
		distinct[pipe.generate(prof, seed).fingerprint()] = true
	if distinct.size() < 2:
		failures.append("S2 all %d seeds yielded the SAME arena layout (no variation)" % SEEDS.size())


# --- S3: connectivity at both levels ------------------------------------------

func _s3_connectivity(pipe: BandPipeline, prof: BandProfile, tag: String,
		failures: Array[String]) -> void:
	var gen := BandGenerator.new()
	var conn := ConnectivityGuarantee.new()
	for seed in SEEDS:
		var band := pipe.generate(prof, seed)
		if not gen.is_band_connected(band):
			failures.append("S3 [%s] seed %d: piece-level is_band_connected FALSE" % [tag, seed])
		if not conn.is_fully_connected(band):
			failures.append("S3 [%s] seed %d: cell-level is_fully_connected FALSE" % [tag, seed])


# --- S4: structural invariants ------------------------------------------------

func _s4_structure(pipe: BandPipeline, prof: BandProfile, cfg: ScatterBandConfig,
		failures: Array[String]) -> void:
	var w := cfg.grid_width
	var h := cfg.grid_height
	for seed in SEEDS:
		var band := pipe.generate(prof, seed)
		if band == null:
			failures.append("S4 seed %d null band" % seed)
			continue

		# Depth axis exists.
		if band.pieces.size() < 2:
			failures.append("S4 seed %d: pieces.size() = %d < 2 (mega-piece)" % [seed, band.pieces.size()])

		# Disjoint chunk footprints.
		var seen := {}
		var overlap := false
		for p in band.pieces:
			for c in p.footprint_cells:
				if seen.has(c):
					overlap = true
				seen[c] = true
		if overlap:
			failures.append("S4 seed %d: pieces share a footprint cell (chunks not disjoint)" % seed)

		# Border ring intact: every floor cell is strictly inside the interior.
		var bad_border := false
		for p in band.pieces:
			for c in p.floor_cells:
				if c.x < 1 or c.y < 1 or c.x > w - 2 or c.y > h - 2:
					bad_border = true
		if bad_border:
			failures.append("S4 seed %d: a floor cell lies on/outside the border ring" % seed)

		# Entry is pieces[0]; its floor_cells[0] is the front-positioned anchor
		# and a member of the 2x2-open set T (player-scale spawn).
		if band.entry_piece != band.pieces[0]:
			failures.append("S4 seed %d: entry_piece != pieces[0]" % seed)
		if band.entry_piece.floor_cells.is_empty():
			failures.append("S4 seed %d: entry piece has no floor cells" % seed)
		else:
			var t := _traversable_set(_floor_set_of(band))
			if not t.has(band.entry_piece.floor_cells[0]):
				failures.append("S4 seed %d: entry anchor floor_cells[0] not in T" % seed)

		# Synthetic-piece fields: no sockets, no instance, scat_ ids.
		for p in band.pieces:
			if p.mated_socket_index != -1:
				failures.append("S4 seed %d: piece mated_socket_index != -1" % seed)
			if not p.open_sockets.is_empty():
				failures.append("S4 seed %d: piece has open_sockets" % seed)
			if p.instance != null:
				failures.append("S4 seed %d: synthetic piece has a non-null instance" % seed)
			if not String(p.piece_id).begins_with("scat_"):
				failures.append("S4 seed %d: piece_id '%s' lacks the scat_ prefix" % [seed, p.piece_id])

		# Depth: default config must reach max_depth >= 4 (the depth-economy
		# bar, U1's hard input contract), and the deepest piece sits at the
		# maximum depth (grade ran in the pipeline).
		if band.max_depth < 4:
			failures.append("S4 seed %d: max_depth %d < 4 on the default config" % [seed, band.max_depth])
		if band.deepest_piece == null or band.deepest_piece.depth_index != band.max_depth:
			var di := -999 if band.deepest_piece == null else band.deepest_piece.depth_index
			failures.append("S4 seed %d: deepest_piece.depth_index %d != max_depth %d" % [seed, di, band.max_depth])


# --- S5: purity under RNG perturbation ----------------------------------------

func _s5_purity(pipe: BandPipeline, prof: BandProfile, failures: Array[String]) -> void:
	var first := pipe.generate(prof, 424242)
	RNG.seed_from(987654321)
	RNG.randi()
	var second := pipe.generate(prof, 424242)
	if first.fingerprint() != second.fingerprint():
		failures.append("S5: seed 424242 differed across runs despite RNG perturbation (stream not pure)")


# --- S6: sampler determinism + the anti-maze invariant (+ non-vacuity) ---------

func _s6_sampler(pipe: BandPipeline, dense_prof: BandProfile, dense_cfg: ScatterBandConfig,
		failures: Array[String]) -> void:
	var w := dense_cfg.grid_width
	var h := dense_cfg.grid_height
	for seed in SEEDS:
		var a := pipe.generate(dense_prof, seed)
		var b := pipe.generate(dense_prof, seed)
		if a.fingerprint() != b.fingerprint():
			failures.append("S6 seed %d: dense config NOT deterministic" % seed)

		# The anti-maze invariant, asserted DIRECTLY: every pair of cover blobs
		# is >= min_cover_spacing Chebyshev (cell-to-cell) apart.
		var cover := _cover_set_of(a, w, h)
		var blobs := _blob_components(cover)
		var min_gap := _min_blob_chebyshev(blobs)
		if min_gap >= 0 and min_gap < dense_cfg.min_cover_spacing:
			failures.append("S6 seed %d: two cover blobs are Chebyshev %d apart (< min_cover_spacing %d)"
				% [seed, min_gap, dense_cfg.min_cover_spacing])
		# Cover blobs never exceed the 2x2 shape catalog.
		for blob in blobs:
			if (blob as Array).size() > 4:
				failures.append("S6 seed %d: a cover blob has %d cells (> 2x2 catalog)" % [seed, (blob as Array).size()])

	# Non-vacuity via the backend stats fields (the cave Q9 precedent).
	var backend := ScatterBackend.new()
	var any_reject := false
	for seed in SEEDS:
		backend.generate(seed, dense_cfg)
		if backend.last_cover_count <= 0:
			failures.append("S6 VACUOUS: dense seed %d stamped ZERO cover footprints" % seed)
		if backend.last_spacing_rejects > 0:
			any_reject = true
	if not any_reject:
		failures.append("S6 VACUOUS: no dense seed exercised margin/lane/spacing rejection")


## 4-connected components over the cover set. Distinct footprints are >= 3
## Chebyshev apart (never adjacent), so components == stamped footprints.
func _blob_components(cover: Dictionary) -> Array:
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var visited := {}
	var blobs: Array = []
	for start in cover:
		if visited.has(start):
			continue
		var cells: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start]
		visited[start] = true
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			cells.append(cur)
			for s in steps:
				var n: Vector2i = cur + s
				if cover.has(n) and not visited.has(n):
					visited[n] = true
					queue.append(n)
		blobs.append(cells)
	return blobs


## Minimum cell-to-cell Chebyshev distance between any two DIFFERENT blobs
## (-1 when fewer than two blobs exist).
func _min_blob_chebyshev(blobs: Array) -> int:
	var best := -1
	for i in blobs.size():
		for j in range(i + 1, blobs.size()):
			for a in (blobs[i] as Array):
				for b in (blobs[j] as Array):
					var av: Vector2i = a
					var bv: Vector2i = b
					var d: int = maxi(absi(av.x - bv.x), absi(av.y - bv.y))
					if best == -1 or d < best:
						best = d
	return best


# --- S7: rc-invariance (scatter ignores rc) ------------------------------------

func _s7_rc_invariance(pipe: BandPipeline, prof: BandProfile, failures: Array[String]) -> void:
	var r4 := _r4_on_rc()
	var lvl := _lvl_on_rc()
	for seed in SEEDS:
		var base_fp := pipe.generate(prof, seed).fingerprint()
		if pipe.generate(prof, seed, r4).fingerprint() != base_fp:
			failures.append("S7 seed %d: r4-on rc changed the scatter fingerprint (backend must ignore rc)" % seed)
		if pipe.generate(prof, seed, lvl).fingerprint() != base_fp:
			failures.append("S7 seed %d: lvl-on rc changed the scatter fingerprint (backend must ignore rc)" % seed)


# --- S8: fail-loud guards (the RD-8 clamps are the by-construction teeth) ------

func _s8_fail_loud(pipe: BandPipeline, failures: Array[String]) -> void:
	# Scatter profile with NO backend_config -> null (validate).
	var no_cfg := BandProfile.new()
	no_cfg.id = &"scat_no_cfg"
	no_cfg.backend = "scatter"
	if pipe.generate(no_cfg, 1) != null:
		failures.append("S8: scatter profile with null config did not return null")

	# WRONG-TYPED config — a CaveBandConfig (the cross-backend confusion case).
	var wrong := BandProfile.new()
	wrong.id = &"scat_wrong_cfg"
	wrong.backend = "scatter"
	wrong.backend_config = CaveBandConfig.new()
	if pipe.generate(wrong, 1) != null:
		failures.append("S8: scatter profile with a CaveBandConfig did not return null")

	# Flavor-bearing scatter profile -> null (flavors ship empty; RD-10).
	var flavored := BandProfile.new()
	flavored.id = &"scat_flavored"
	flavored.backend = "scatter"
	flavored.backend_config = ScatterBandConfig.new()
	flavored.flavors = [Resource.new()]
	if pipe.generate(flavored, 1) != null:
		failures.append("S8: flavor-bearing scatter profile did not return null")

	# Every RD-8 validate() clamp, one degenerate config each.
	var too_small := ScatterBandConfig.new()
	too_small.grid_width = 8
	_s8_expect_null(pipe, too_small, "grid too small", failures)

	var tight := ScatterBandConfig.new()
	tight.min_cover_spacing = 2
	_s8_expect_null(pipe, tight, "min_cover_spacing = 2", failures)

	var thin := ScatterBandConfig.new()
	thin.border_margin = 1
	_s8_expect_null(pipe, thin, "border_margin = 1", failures)

	var weightless := ScatterBandConfig.new()
	weightless.cover_w_1x1 = 0
	weightless.cover_w_2x1 = 0
	weightless.cover_w_1x2 = 0
	weightless.cover_w_2x2 = 0
	_s8_expect_null(pipe, weightless, "zero weight sum", failures)

	var wide_lane := ScatterBandConfig.new()
	wide_lane.clear_lane_width = wide_lane.grid_height - 1
	_s8_expect_null(pipe, wide_lane, "lane wider than interior", failures)

	var shallow := ScatterBandConfig.new()
	shallow.chunk_cells = 16  # ceil(56/16) = 4 chunk columns < 5
	_s8_expect_null(pipe, shallow, "chunks_x < 5 (depth bar)", failures)


func _s8_expect_null(pipe: BandPipeline, cfg: ScatterBandConfig, label: String,
		failures: Array[String]) -> void:
	var degen := BandProfile.new()
	degen.id = &"scat_degen"
	degen.backend = "scatter"
	degen.backend_config = cfg
	if pipe.generate(degen, 1) != null:
		failures.append("S8: degenerate scatter config (%s) did not return null" % label)


# --- S9: three-profile control regression (in-suite belt-and-braces) -----------

func _s9_three_profile_control(pipe: BandPipeline, failures: Array[String]) -> void:
	for path in [GREYBOX_PROFILE, BAND_TWO_PROFILE, BAND_THREE_PROFILE]:
		var prof := load(path) as BandProfile
		if prof == null:
			failures.append("S9: could not load %s" % path)
			continue
		var a := pipe.generate(prof, 12345)
		var b := pipe.generate(prof, 12345)
		if a == null or b == null:
			failures.append("S9: %s produced a null band" % path)
			continue
		if a.fingerprint() != b.fingerprint():
			failures.append("S9: %s fingerprint not reproducible (dispatch broke an older path)" % path)


# --- S10: player-scale 2x2-open invariant (RD-6's STRONG form) ------------------

func _s10_player_scale(pipe: BandPipeline, prof: BandProfile, cfg: ScatterBandConfig,
		failures: Array[String]) -> void:
	var tag := "%dx%d d%d b%d" % [cfg.grid_width, cfg.grid_height, cfg.cover_density_pct, cfg.edge_cover_bias_pct]
	for seed in SEEDS:
		var band := pipe.generate(prof, seed)
		if band == null:
			continue
		var floor_set := _floor_set_of(band)
		var t := _traversable_set(floor_set)

		if t.is_empty():
			failures.append("S10 [%s] seed %d: traversable set T is EMPTY" % [tag, seed])
			continue
		if _component_count(t) != 1:
			failures.append("S10 [%s] seed %d: T has %d components (not single)" % [tag, seed, _component_count(t)])
		if not t.has(band.entry_piece.floor_cells[0]):
			failures.append("S10 [%s] seed %d: entry anchor not in T (not player-scale)" % [tag, seed])
		# RD-6's strong form: EVERY floor cell is IN T (stronger than the cave's
		# "in or 4-adjacent to T"; U1's M6 asserts the same provable form).
		var outside := 0
		for c in floor_set:
			if not t.has(c):
				outside += 1
		if outside > 0:
			failures.append("S10 [%s] seed %d: %d floor cell(s) NOT in T (RD-6 strong form violated)" % [tag, seed, outside])


# --- S11: the long-sightline identity bar (RD-4) --------------------------------

func _s11_sightline(cfg: ScatterBandConfig, min_open_pct: int, tag: String,
		failures: Array[String]) -> void:
	var backend := ScatterBackend.new()
	var w := cfg.grid_width
	var h := cfg.grid_height
	var interior := (w - 2) * (h - 2)
	var s := cfg.min_cover_spacing + 2
	var k: int = mini(w - 2, h - 2) / 2
	var min_pct := 101
	for seed in SEEDS:
		var band := backend.generate(seed, cfg)
		var floor_set := _floor_set_of(band)

		# (a) The constructed lane (LOAD-BEARING): every lane row is all-floor
		# across the full interior width -> max E-W run == grid_width - 2.
		var lane_y := backend.last_lane_row
		if lane_y < 1 or lane_y + cfg.clear_lane_width > h - 1:
			failures.append("S11a [%s] seed %d: lane rows [%d, %d) exceed the interior"
				% [tag, seed, lane_y, lane_y + cfg.clear_lane_width])
		else:
			for y in range(lane_y, lane_y + cfg.clear_lane_width):
				for x in range(1, w - 1):
					if not floor_set.has(Vector2i(x, y)):
						failures.append("S11a [%s] seed %d: lane cell (%d, %d) is not floor" % [tag, seed, x, y])
						break
		var best_run := 0
		for y in range(1, h - 1):
			var run := 0
			for x in range(1, w - 1):
				run = run + 1 if floor_set.has(Vector2i(x, y)) else 0
				best_run = maxi(best_run, run)
		if best_run != w - 2:
			failures.append("S11a [%s] seed %d: max E-W floor run %d != interior width %d" % [tag, seed, best_run, w - 2])

		# (b) Openness percentile (BUILD-CALIBRATED, RD-4): % of floor cells
		# whose max axis run >= K = interior_min / 2.
		var pct := _openness_pct(floor_set, w, h, k)
		min_pct = mini(min_pct, pct)
		if pct < min_open_pct:
			failures.append("S11b [%s] seed %d: openness %d%% < calibrated floor %d%% (K=%d)"
				% [tag, seed, pct, min_open_pct, k])

		# (c) The stratum bound (RD-4's corrected ceiling, integer + non-flaky):
		# cover_cells * s^2 <= 4 * interior_cells.
		var cover_cells := _cover_set_of(band, w, h).size()
		if cover_cells * s * s > 4 * interior:
			failures.append("S11c [%s] seed %d: cover %d * s^2 %d > 4 * interior %d"
				% [tag, seed, cover_cells, s * s, interior])
	print("S11b [%s] measured openness minimum across seeds: %d%% (K=%d, asserted floor %d%%)"
		% [tag, min_pct, k, min_open_pct])


## Percentage (integer) of floor cells whose longest uninterrupted axis-aligned
## floor run through the cell (max of E-W, N-S) is >= k.
func _openness_pct(floor_set: Dictionary, w: int, h: int, k: int) -> int:
	var run_ew := {}
	for y in range(1, h - 1):
		var x := 1
		while x < w - 1:
			if not floor_set.has(Vector2i(x, y)):
				x += 1
				continue
			var x0 := x
			while x < w - 1 and floor_set.has(Vector2i(x, y)):
				x += 1
			var run := x - x0
			for xi in range(x0, x):
				run_ew[Vector2i(xi, y)] = run
	var open_count := 0
	var run_ns := {}
	for x in range(1, w - 1):
		var y := 1
		while y < h - 1:
			if not floor_set.has(Vector2i(x, y)):
				y += 1
				continue
			var y0 := y
			while y < h - 1 and floor_set.has(Vector2i(x, y)):
				y += 1
			var run := y - y0
			for yi in range(y0, y):
				run_ns[Vector2i(x, yi)] = run
	for c in floor_set:
		if maxi(run_ew.get(c, 0), run_ns.get(c, 0)) >= k:
			open_count += 1
	if floor_set.is_empty():
		return 0
	return open_count * 100 / floor_set.size()


# --- S4/S10 helpers (Vector2i-keyed, mirroring the backend's integer T) --------

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
