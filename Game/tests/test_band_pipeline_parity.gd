extends Node
## S1 acceptance — BandPipeline parity vs direct BandGenerator (band Phase A).
##
## Run as a SCENE (not --script) so the EventBus / RNG autoload globals resolve
## at compile time, exactly as in the real game:
##   godot --headless --path Game res://tests/test_band_pipeline_parity.tscn
##
## Proves the orchestrated BandPipeline.generate(profile, seed, rc) path is a
## byte-perfect wrapper around the direct BandGenerator.generate path. Same
## seed matrix as test_bandgen_determinism (the assertions transfer):
##   P0. profile-load contract: band_greybox.tres is exactly the baseline-as-data
##   P1. THE BAR: byte-identical fingerprint per seed (pipeline vs direct)
##   P2. pipeline path run-to-run deterministic (same seed twice)
##   P3. grading parity: piecewise depth_index/depth_norm/dist_to_gate/max_depth
##   P4. structural invariants transfer: connectivity, overlap-free, soft floor
##   P5. rc pass-through parity: r4-on + lvl room-count configs flow through the
##       pipeline to the SAME interior hooks, byte-exactly
##   P6. purity under RNG perturbation through the pipeline
##   P7. fail-loud guards: null / unwired backend / early stage-bearing profiles

const PROFILE_PATH := "res://data/bands/band_greybox.tres"
const CONFIG_PATH := "res://data/bandgen_config.tres"
const CATALOG_PATH := "res://data/piece_catalog.tres"
## M1.9 (S3, §7.2 Q6(iv)): the lvl_enabled ext-catalog swap moved INTO the pipeline
## (profile.piece_pool_ext) — P5's lvl case compares against the direct path on the
## SAME extended catalog, exactly as the old main_game call-site swap did.
const CATALOG_EXT_PATH := "res://data/piece_catalog_ext.tres"
const CURVE_PATH := "res://systems/depth/depth_curve.tres"
const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"

# Same spread as test_bandgen_determinism.gd (the determinism matrix).
const SEEDS := [12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]


func _ready() -> void:
	var code := _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []

	# --- P0. Profile-load contract -------------------------------------------
	var profile := load(PROFILE_PATH) as BandProfile
	if profile == null:
		printerr("PIPELINE FAIL: could not load ", PROFILE_PATH, " as BandProfile")
		return 1
	_check_profile_contract(profile, failures)

	var gen := BandGenerator.new()
	var pipe := BandPipeline.new()
	var cfg := load(CONFIG_PATH) as BandGenConfig
	var catalog: Array[ZonePieceData] = (load(CATALOG_PATH) as PieceCatalog).pieces
	var grader := DepthGrader.new()

	for seed in SEEDS:
		var direct := gen.generate(seed, cfg, catalog)          # today's path
		var piped := pipe.generate(profile, seed)               # orchestrated path
		if direct == null or piped == null:
			failures.append("seed %d: null band (direct=%s piped=%s)"
				% [seed, str(direct != null), str(piped != null)])
			_free_band(direct)
			_free_band(piped)
			continue

		# --- P1. THE BAR: byte-identical fingerprint, per seed ---------------
		if direct.fingerprint() != piped.fingerprint():
			failures.append("P1 seed %d: pipeline fp != direct fp (%s vs %s)"
				% [seed, direct.fingerprint().substr(0, 12), piped.fingerprint().substr(0, 12)])

		# --- P2. Pipeline path run-to-run deterministic -----------------------
		var piped2 := pipe.generate(profile, seed)
		if piped2 == null or piped.fingerprint() != piped2.fingerprint():
			failures.append("P2 seed %d: pipeline NOT run-to-run deterministic" % seed)

		# --- P3. Grading parity: pipeline's built-in grade == grading the
		#     direct band by hand — piecewise, not just the hash. --------------
		grader.grade(direct)
		grader.compute_return_distance(direct)
		if direct.max_depth != piped.max_depth:
			failures.append("P3 seed %d: max_depth mismatch (%d vs %d)"
				% [seed, direct.max_depth, piped.max_depth])
		if direct.pieces.size() != piped.pieces.size():
			failures.append("P3 seed %d: piece count mismatch (%d vs %d)"
				% [seed, direct.pieces.size(), piped.pieces.size()])
		else:
			for i in direct.pieces.size():
				var dp := direct.pieces[i]
				var pp := piped.pieces[i]
				if dp.depth_index != pp.depth_index \
						or not is_equal_approx(dp.depth_norm, pp.depth_norm) \
						or dp.dist_to_gate != pp.dist_to_gate:
					failures.append("P3 seed %d piece %d: grade mismatch (depth %d/%d norm %f/%f dist %d/%d)"
						% [seed, i, dp.depth_index, pp.depth_index,
							dp.depth_norm, pp.depth_norm, dp.dist_to_gate, pp.dist_to_gate])
					break
		if direct.entry_piece.piece_id != piped.entry_piece.piece_id:
			failures.append("P3 seed %d: entry piece id mismatch" % seed)
		if direct.deepest_piece.piece_id != piped.deepest_piece.piece_id:
			failures.append("P3 seed %d: deepest piece id mismatch" % seed)

		# --- P4. Structural invariants transfer -------------------------------
		if not gen.is_band_connected(piped):
			failures.append("P4 seed %d: piped band is DISCONNECTED (%d pieces)"
				% [seed, piped.pieces.size()])
		var seen := {}
		var overlap := false
		for p in piped.pieces:
			for c in p.footprint_cells:
				if seen.has(c):
					overlap = true
				seen[c] = true
		if overlap:
			failures.append("P4 seed %d: piped band has overlapping piece cells" % seed)
		var floor_target: int = (int(cfg.target_piece_count) * int(cfg.soft_floor_percent) + 99) / 100
		if piped.pieces.size() < floor_target:
			failures.append("P4 seed %d: piped band undersized: %d < soft floor %d"
				% [seed, piped.pieces.size(), floor_target])

		_free_band(direct)
		_free_band(piped)
		_free_band(piped2)

	# --- P5. rc pass-through parity ------------------------------------------
	_run_rc_passthrough_checks(gen, pipe, profile, cfg, catalog, failures)

	# --- P6. Purity under RNG perturbation through the pipeline ---------------
	var first_run := pipe.generate(profile, 424242)
	RNG.seed_from(987654321)
	RNG.randi()
	var second_run := pipe.generate(profile, 424242)
	if first_run == null or second_run == null \
			or first_run.fingerprint() != second_run.fingerprint():
		failures.append("P6: pipeline seed chain not pure: 424242 differed across runs despite RNG perturbation")
	_free_band(first_run)
	_free_band(second_run)

	# --- P7. Fail-loud guards ---------------------------------------------------
	_run_fail_loud_checks(pipe, cfg, failures)

	if failures.is_empty():
		var sample := pipe.generate(profile, 12345)
		print("PIPELINE PARITY OK — BandPipeline byte-matches BandGenerator across %d seeds (sample seed 12345 -> %d pieces, fp=%s)"
			% [SEEDS.size(), sample.pieces.size(), sample.fingerprint().substr(0, 12)])
		_free_band(sample)
		return 0
	for f in failures:
		printerr("PIPELINE FAIL: ", f)
	return 1


# --- P0: band_greybox.tres is exactly today's baseline as data -----------------

func _check_profile_contract(profile: BandProfile, failures: Array[String]) -> void:
	if not profile.validate().is_empty():
		failures.append("P0: band_greybox.validate() reported problems: %s"
			% str(profile.validate()))
	if profile.id != &"band_greybox":
		failures.append("P0: id is '%s', expected &\"band_greybox\"" % profile.id)
	if profile.backend != "socket":
		failures.append("P0: backend is '%s', expected socket" % profile.backend)
	if profile.archetype != "linear":
		failures.append("P0: archetype is '%s', expected linear" % profile.archetype)
	if not profile.archetype_params.is_empty():
		failures.append("P0: archetype_params not empty")
	if not profile.principles.is_empty() or not profile.flavors.is_empty():
		failures.append("P0: principles/flavors not empty (Phase-A profile must carry no stages)")
	# V3 (M1.12): band_greybox now carries the migrated K5 deck (pingpong/bomb/spike) +
	# opposition_credits=48 — the legacy hpp_/hbomb_/hspike_ knob lane was retired. Layout
	# fingerprints (P1) stay byte-identical (hazards are run-state, never feed fingerprint()).
	if profile.opposition_deck.size() != 3:
		failures.append("P0: opposition_deck size %d, expected 3 (V3 K5 deck: pingpong/bomb/spike)"
			% profile.opposition_deck.size())
	if profile.opposition_credits != 48:
		failures.append("P0: opposition_credits %d, expected 48 (V3 K5 density preserve)"
			% profile.opposition_credits)
	if profile.band_depth != 1:
		failures.append("P0: band_depth is %d, expected 1" % profile.band_depth)
	if profile.palette_tint != Color(1, 1, 1, 1):
		failures.append("P0: palette_tint is %s, expected neutral white" % str(profile.palette_tint))
	# Same-cached-object identity: the two paths cannot fork on a duplicated
	# config/catalog/curve/junk-catalog (Q2's anti-drift assertion).
	if profile.backend_config != load(CONFIG_PATH):
		failures.append("P0: backend_config is NOT the live bandgen_config.tres object")
	if profile.piece_pool != load(CATALOG_PATH):
		failures.append("P0: piece_pool is NOT the live piece_catalog.tres object")
	# M1.9 (S3): the profile now carries the I1 extended pool for the lvl swap.
	if profile.piece_pool_ext != load(CATALOG_EXT_PATH):
		failures.append("P0: piece_pool_ext is NOT the live piece_catalog_ext.tres object")
	if profile.depth_curve != load(CURVE_PATH):
		failures.append("P0: depth_curve is NOT the live depth_curve.tres object")
	if profile.junk_catalog != load(JUNK_CATALOG_PATH):
		failures.append("P0: junk_catalog is NOT the live junk_catalog.tres object")


# --- P5: non-neutral RunConfigs flow through the pipeline byte-exactly ---------

func _run_rc_passthrough_checks(gen: BandGenerator, pipe: BandPipeline,
		profile: BandProfile, cfg: BandGenConfig, catalog: Array[ZonePieceData],
		failures: Array[String]) -> void:
	# r4-on shape reused from test_bandgen_determinism (_make_r4_on_config).
	var r4_on := RunConfig.new()
	r4_on.r4_enabled = true
	r4_on.r4_branch_chance_base = 0.0
	r4_on.r4_branch_per_depth = 0.06
	r4_on.r4_max_branch_depth = 8

	# lvl room-count override → the generator's effective_room_count hook.
	# M1.9 (S3, §7.2 Q6(iv)): lvl_enabled ALSO swaps the pipeline onto
	# profile.piece_pool_ext, so the direct comparison generates against the same
	# extended catalog (the old main_game.gd:205-207 swap, now pipeline-owned).
	var lvl_on := RunConfig.new()
	lvl_on.lvl_enabled = true
	lvl_on.lvl_room_count = 8
	var catalog_ext: Array[ZonePieceData] = (load(CATALOG_EXT_PATH) as PieceCatalog).pieces

	var any_r4_differs := false
	for seed in SEEDS:
		var direct_r4 := gen.generate(seed, cfg, catalog, r4_on)
		var piped_r4 := pipe.generate(profile, seed, r4_on)
		if piped_r4 == null or direct_r4.fingerprint() != piped_r4.fingerprint():
			failures.append("P5 seed %d: r4-on pipeline fp != direct fp" % seed)
		var baseline := gen.generate(seed, cfg, catalog)
		if piped_r4 != null and piped_r4.fingerprint() != baseline.fingerprint():
			any_r4_differs = true
		_free_band(direct_r4)
		_free_band(piped_r4)
		_free_band(baseline)

		var direct_lvl := gen.generate(seed, cfg, catalog_ext, lvl_on)
		var piped_lvl := pipe.generate(profile, seed, lvl_on)
		if piped_lvl == null or direct_lvl.fingerprint() != piped_lvl.fingerprint():
			failures.append("P5 seed %d: lvl room-count pipeline fp != direct fp" % seed)
		if piped_lvl != null and piped_lvl.pieces.size() > 8:
			failures.append("P5 seed %d: lvl_room_count=8 did not cap the piped band (%d pieces)"
				% [seed, piped_lvl.pieces.size()])
		_free_band(direct_lvl)
		_free_band(piped_lvl)

	# Non-vacuous: the r4 config must actually change at least one seed's band,
	# proving the rc reached the interior hooks THROUGH the pipeline.
	if not any_r4_differs:
		failures.append("P5: r4-on config produced the SAME band as baseline on every seed — rc not reaching the generator through the pipeline?")


# --- P7: fail-loud guards (synthetic profiles, no throwaway .tres) -------------

func _run_fail_loud_checks(pipe: BandPipeline, cfg: BandGenConfig,
		failures: Array[String]) -> void:
	# Null profile → null.
	if pipe.generate(null, 1) != null:
		failures.append("P7: null profile did not return null")

	# Invalid profile (empty id, no config/pool) → null.
	var invalid := BandProfile.new()
	if pipe.generate(invalid, 1) != null:
		failures.append("P7: invalid (empty) profile did not return null")

	# Config-less scatter profile → null. M1.11 (U0) wired scatter, so this
	# fail-loud moved from the wiring guard to validate() (a scatter profile
	# needs a ScatterBandConfig) — the assertion is unchanged.
	var scatter := BandProfile.new()
	scatter.id = &"synthetic_scatter"
	scatter.backend = "scatter"
	if pipe.generate(scatter, 1) != null:
		failures.append("P7: backend 'scatter' did not return null (unwired-backend guard missing)")

	# M1.10 (T0): a cave backend IS wired, so its fail-loud moved to validate() —
	# a cave profile with a missing/wrong-typed backend_config returns null.
	var cave := BandProfile.new()
	cave.id = &"synthetic_cave"
	cave.backend = "cave"    # no CaveBandConfig → validate() fails → null
	if pipe.generate(cave, 1) != null:
		failures.append("P7: cave profile with no CaveBandConfig did not return null (validate guard missing)")

	# Stage-bearing profile before S5 → null (control safety).
	var staged := BandProfile.new()
	staged.id = &"synthetic_staged"
	staged.backend = "socket"
	staged.backend_config = cfg
	staged.piece_pool = load(CATALOG_PATH) as PieceCatalog
	staged.flavors = [Resource.new()]
	if pipe.generate(staged, 1) != null:
		failures.append("P7: flavor-bearing profile did not return null (pre-S5 stage guard missing)")


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
