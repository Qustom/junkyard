extends Node
## Headless acceptance test for J2 (M1.3) — distribute R1 hazards across depth_index.
##
## Run as a SCENE (autoloads + a live tree) so MainGame's script resolves exactly as in
## the real game:
##   godot --headless res://tests/test_hazard_spread.tscn
##
## J2 turns the single-gate hazard spawn (all N at one r1_depth_threshold) into N hazards
## DISTRIBUTED across depth_index. This test drives MainGame._hazard_spawn_depths(band, rc)
## directly — it is a PURE function of band topology (depth_index / band.max_depth) + the
## config, with NO RNG and NO node state — against a hand-built graded Band.
##
## Asserts (per the Director Disposition + the J2 spec §0/§B):
##   (a) single_gate (mode 0, the default) reproduces the M1.2 placement EXACTLY: every
##       hazard at clampi(r1_depth_threshold, 0, max_depth). All-off-equivalent — the
##       M1.2-comparable cohort and the all-off control stay byte-identical.
##   (b) even_spread (mode 1) scatters N hazards across [spread_min_depth .. max_depth]
##       inclusive: endpoints hit lo and max, the spread is monotonic non-decreasing, and
##       it spans more than one distinct depth (the F2 fix — danger at multiple depths).
##   (c) curve (mode 2) is the locked pow(t, 1.6) shape (built but preset-OFF, §C-Q1): since
##       pow(t,1.6) <= t for t in [0,1], each intermediate depth is <= the even_spread depth
##       at the same index, with the SAME endpoints (lo, max). The exponent is a sweep target
##       (the "deeper-biased" feel is the Director's to tune at RG2 — see the J2 worklog's
##       Design deviations note on the curve exponent vs the spec's "clusters deep" comment).
##   (d) DETERMINISM: the same (band, rc) yields a byte-identical depth list every call
##       (no RNG) — and the depth list NEVER depends on anything that feeds fingerprint().
##   (e) spread_min_depth is respected (no hazard shallower than it) and clamps to max_depth.
##   (f) N == r1_spawn_count for every mode; n==1 is well-defined (no div-by-zero).

const MAIN_GAME_SCRIPT := "res://scenes/game/main_game.gd"


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	# MainGame's spawn-depth helpers (_hazard_spawn_depths / _band_max_depth) read only the
	# Band + RunConfig — no node state — so we exercise them on a bare script instance.
	var mg_script := load(MAIN_GAME_SCRIPT) as GDScript
	if mg_script == null:
		printerr("J2 FAIL: could not load %s" % MAIN_GAME_SCRIPT)
		return 1
	var mg = mg_script.new()

	# A graded linear band: depth_index 0..MAX on the spine (entry == 0). One floor cell per
	# piece so cell selection is unambiguous; band.max_depth set as DepthGrader.grade() would.
	const MAX := 18
	var band := _make_graded_band(MAX)
	if band.max_depth != MAX:
		failures.append("setup: band.max_depth == %d, expected %d" % [band.max_depth, MAX])

	# --- (a) single_gate reproduces M1.2: every hazard at the clamped threshold ----
	for thr in [0, 1, 4, MAX, MAX + 100]:
		var rc_sg := _rc(0, 5, 0)
		rc_sg.r1_depth_threshold = thr
		var got: Array = mg._hazard_spawn_depths(band, rc_sg)
		var want := clampi(thr, 0, MAX)
		if got.size() != 5:
			failures.append("(a) thr %d: single_gate produced %d depths, expected 5" % [thr, got.size()])
		for d in got:
			if d != want:
				failures.append("(a) thr %d: single_gate depth %d != clamped threshold %d" % [thr, d, want])

	# --- (b) even_spread scatters across [lo .. max] inclusive, monotonic, multi-depth ---
	var rc_even := _rc(1, 5, 1)          # even_spread, N=5, min-depth 1
	var ev: Array = mg._hazard_spawn_depths(band, rc_even)
	if ev.size() != 5:
		failures.append("(b) even_spread produced %d depths, expected 5" % ev.size())
	else:
		if ev[0] != 1:
			failures.append("(b) even_spread first depth %d != lo (spread_min_depth) 1" % ev[0])
		if ev[ev.size() - 1] != MAX:
			failures.append("(b) even_spread last depth %d != max_depth %d" % [ev[ev.size() - 1], MAX])
		for i in range(1, ev.size()):
			if ev[i] < ev[i - 1]:
				failures.append("(b) even_spread not monotonic non-decreasing at %d (%d < %d)" % [i, ev[i], ev[i - 1]])
		var distinct := {}
		for d in ev:
			distinct[d] = true
		if distinct.size() < 2:
			failures.append("(b) even_spread collapsed to a single depth (no spread): %s" % str(ev))

	# --- (c) curve is the locked pow(t,1.6) shape: depth[i] <= even_spread depth[i], same ends ---
	var rc_curve := _rc(2, 5, 1)
	var cv: Array = mg._hazard_spawn_depths(band, rc_curve)
	if cv.size() != 5:
		failures.append("(c) curve produced %d depths, expected 5" % cv.size())
	elif ev.size() == 5:
		if cv[0] != 1 or cv[cv.size() - 1] != MAX:
			failures.append("(c) curve endpoints (%d..%d) != (lo 1 .. max %d)" % [cv[0], cv[cv.size() - 1], MAX])
		for i in cv.size():
			if cv[i] > ev[i]:
				failures.append("(c) curve depth[%d]=%d deeper than even_spread depth %d (pow(t,1.6) must be <= even)" % [i, cv[i], ev[i]])
		# Curve must actually DIFFER from even_spread somewhere (it is a distinct mode).
		if cv == ev:
			failures.append("(c) curve produced the same list as even_spread (the pow() shape did nothing)")

	# --- (d) DETERMINISM: same (band, rc) → byte-identical list (no RNG) ------------
	for rc_det in [_rc(0, 5, 0), _rc(1, 5, 1), _rc(2, 5, 1)]:
		var a: Array = mg._hazard_spawn_depths(band, rc_det)
		var b: Array = mg._hazard_spawn_depths(band, rc_det)
		if a != b:
			failures.append("(d) mode %d: depth list not deterministic across calls (%s vs %s)" % [rc_det.r1_spawn_distribution, str(a), str(b)])

	# --- (e) spread_min_depth respected + clamped ----------------------------------
	var rc_min := _rc(1, 6, 5)            # min-depth 5
	var em: Array = mg._hazard_spawn_depths(band, rc_min)
	for d in em:
		if d < 5:
			failures.append("(e) even_spread placed a hazard at depth %d below spread_min_depth 5" % d)
	# min-depth above max clamps to max (degenerate but well-defined: all at max).
	var rc_over := _rc(1, 4, MAX + 50)
	var eo: Array = mg._hazard_spawn_depths(band, rc_over)
	for d in eo:
		if d != MAX:
			failures.append("(e) over-max min-depth: depth %d != clamped max %d" % [d, MAX])

	# --- (f) N == r1_spawn_count for every mode; n==1 is well-defined ---------------
	for mode in [0, 1, 2]:
		for n in [1, 2, 7]:
			var rc_n := _rc(mode, n, 1)
			var got_n: Array = mg._hazard_spawn_depths(band, rc_n)
			if got_n.size() != n:
				failures.append("(f) mode %d N %d: produced %d depths" % [mode, n, got_n.size()])
			for d in got_n:
				if d < 0 or d > MAX:
					failures.append("(f) mode %d N %d: depth %d out of [0, %d]" % [mode, n, d, MAX])

	mg.free()
	_free_band(band)

	if failures.is_empty():
		print("J2 OK — hazard depth-spread verified: single_gate reproduces the M1.2 single-threshold "
			+ "placement (all-off-equivalent), even_spread scatters N across [min..max] (F2), curve is "
			+ "the locked pow(t,1.6) shape (preset-OFF), all RNG-free + deterministic, spread_min_depth respected/clamped, and "
			+ "N == r1_spawn_count for every mode.")
		return 0
	for f in failures:
		printerr("J2 FAIL: ", f)
	return 1


## An R1-on RunConfig with the J2 distribution knobs set.
func _rc(distribution: int, count: int, min_depth: int) -> RunConfig:
	var rc := RunConfig.new()
	rc.r1_enabled = true
	rc.r1_spawn_count = count
	rc.r1_spawn_distribution = distribution
	rc.r1_spread_min_depth = min_depth
	rc.r1_depth_threshold = 4   # the single_gate spawn depth (and the per-hazard wake threshold)
	return rc


## A linear graded band: pieces at depth_index 0..max (one floor cell each), band.max_depth
## set exactly as DepthGrader.grade() leaves it (depth_grader.gd:47).
func _make_graded_band(max_depth: int) -> Band:
	var band := Band.new()
	for d in range(max_depth + 1):
		var p := PlacedPiece.new()
		p.piece_id = StringName("p%d" % d)
		p.offset_cell = Vector2i(d * 8, 0)
		p.depth_index = d
		p.depth_norm = float(d) / float(max_depth) if max_depth > 0 else 0.0
		p.floor_cells = [Vector2i(d * 8 + 1, 1)]
		band.pieces.append(p)
	band.entry_piece = band.pieces[0]
	band.deepest_piece = band.pieces[band.pieces.size() - 1]
	band.max_depth = max_depth
	return band


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
