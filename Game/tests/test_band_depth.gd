extends Node
## Headless acceptance test for B3 — the band depth axis + depth-scaled junk
## placement planner.
##
## Run as a SCENE (not --script) so the EventBus / RNG autoloads the
## BandGenerator emits/draws through resolve at compile time, exactly as in the
## real game (mirrors test_bandgen_determinism):
##   godot --headless res://tests/test_band_depth.tscn
##
## Asserts:
##   1. Grading: entry depth_index == 0; depth_index monotonic non-decreasing
##      along band.pieces on the linear spine; depth_norm in [0,1];
##      dist_to_gate computed for every piece (and == depth_index on the spine).
##   2. Plan determinism: same seed -> identical plan fingerprint; diff seeds ->
##      different plans.
##   3. Value rises with depth: avg planned value in the deeper half > shallower.
##   4. Tier gate: items planned deep respect the depth tier threshold.
##   5. No RNG cross-talk: generate -> plan -> regenerate (same seed) yields the
##      same band.fingerprint() (junk rolls didn't perturb the layout RNG).
##   6. duplicate(true) isolation: mutating one planned item leaves the catalog
##      template and siblings unchanged.

const PIECE_CATALOG_PATH := "res://data/piece_catalog.tres"
const CONFIG_PATH := "res://data/bandgen_config.tres"
const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"
const DEPTH_CURVE_PATH := "res://systems/depth/depth_curve.tres"

const SEEDS := [12345, 99999, 1, 7, 808, 424242, -33]


func _ready() -> void:
	var code := _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []

	var piece_catalog_res = load(PIECE_CATALOG_PATH)
	var cfg = load(CONFIG_PATH)
	var junk_catalog: JunkCatalog = load(JUNK_CATALOG_PATH)
	var curve: DepthCurve = load(DEPTH_CURVE_PATH)
	if piece_catalog_res == null or cfg == null or junk_catalog == null or curve == null:
		printerr("BAND DEPTH FAIL: could not load fixtures")
		return 1
	var piece_catalog: Array[ZonePieceData] = piece_catalog_res.pieces

	var gen := BandGenerator.new()
	var grader := DepthGrader.new()
	var placer := JunkPlacer.new()

	# --- 1. Grading correctness across seeds --------------------------------
	for seed in SEEDS:
		var band := gen.generate(seed, cfg, piece_catalog)
		grader.grade(band)
		grader.compute_return_distance(band)

		if band.entry_piece.depth_index != 0:
			failures.append("seed %d: entry depth_index=%d (expected 0)"
				% [seed, band.entry_piece.depth_index])

		var prev := -1
		for p in band.pieces:
			if p.depth_index < prev:
				failures.append("seed %d: depth_index NOT monotonic along spine (%d after %d)"
					% [seed, p.depth_index, prev])
				break
			prev = p.depth_index
			if p.depth_norm < 0.0 or p.depth_norm > 1.0:
				failures.append("seed %d: depth_norm out of [0,1]: %f" % [seed, p.depth_norm])
			if p.dist_to_gate < 0:
				failures.append("seed %d: dist_to_gate not computed (%d)" % [seed, p.dist_to_gate])
			# On the linear M1 spine, return distance must equal forward depth.
			if p.dist_to_gate != p.depth_index:
				failures.append("seed %d: dist_to_gate %d != depth_index %d on linear spine"
					% [seed, p.dist_to_gate, p.depth_index])
		_free_band(band)

	# --- 2. Plan determinism (same seed identical; diff seeds differ) -------
	var plan_fps := {}
	for seed in SEEDS:
		var band_a := gen.generate(seed, cfg, piece_catalog)
		grader.grade(band_a)
		var plan_a := placer.plan(band_a, curve, junk_catalog)

		var band_b := gen.generate(seed, cfg, piece_catalog)
		grader.grade(band_b)
		var plan_b := placer.plan(band_b, curve, junk_catalog)

		var fp_a := placer.plan_fingerprint(plan_a)
		var fp_b := placer.plan_fingerprint(plan_b)
		if fp_a != fp_b:
			failures.append("seed %d: plan NOT deterministic (%s vs %s)"
				% [seed, fp_a.substr(0, 12), fp_b.substr(0, 12)])
		plan_fps[fp_a] = true
		_free_band(band_a)
		_free_band(band_b)
	if plan_fps.size() < 2:
		failures.append("all seeds produced the SAME plan (no variation)")

	# --- 3. Value rises with depth (deeper half avg > shallower half avg) ---
	# Aggregate across seeds for a stable signal (one band can be noisy).
	var shallow_sum := 0.0
	var shallow_n := 0
	var deep_sum := 0.0
	var deep_n := 0
	for seed in SEEDS:
		var band := gen.generate(seed, cfg, piece_catalog)
		grader.grade(band)
		var plan := placer.plan(band, curve, junk_catalog)
		var half := band.max_depth / 2
		for e in plan:
			var v: int = (e["item"] as JunkItem).base_sell_value
			if e["depth"] <= half:
				shallow_sum += v
				shallow_n += 1
			else:
				deep_sum += v
				deep_n += 1
		_free_band(band)
	var shallow_avg := (shallow_sum / shallow_n) if shallow_n > 0 else 0.0
	var deep_avg := (deep_sum / deep_n) if deep_n > 0 else 0.0
	if not (deep_avg > shallow_avg):
		failures.append("value does not rise with depth: deep_avg=%.1f shallow_avg=%.1f"
			% [deep_avg, shallow_avg])

	# --- 4. Tier gate respected at depth ------------------------------------
	for seed in SEEDS:
		var band := gen.generate(seed, cfg, piece_catalog)
		grader.grade(band)
		var plan := placer.plan(band, curve, junk_catalog)
		# Build piece depth_norm by depth_index for the gate lookup.
		for e in plan:
			var item: JunkItem = e["item"]
			var dnorm := 0.0 if band.max_depth == 0 else float(e["depth"]) / float(band.max_depth)
			var gate := curve.min_tier(dnorm)
			# Eligible set may have fallen back to tier-1 only if nothing qualified
			# at the gate; in that case any tier is acceptable (documented fallback).
			var any_at_gate := false
			for it in junk_catalog.items:
				if it.tier >= gate:
					any_at_gate = true
					break
			if any_at_gate and item.tier < gate:
				failures.append("seed %d: tier %d item placed at depth %d (gate >= %d)"
					% [seed, item.tier, e["depth"], gate])
				break
		_free_band(band)

	# --- 5. No RNG cross-talk: planning must not perturb the layout stream --
	for seed in SEEDS:
		var band1 := gen.generate(seed, cfg, piece_catalog)
		var fp1 := band1.fingerprint()
		grader.grade(band1)
		# Run the planner (draws from its OWN local sub-stream) between gens.
		var _plan := placer.plan(band1, curve, junk_catalog)
		var band2 := gen.generate(seed, cfg, piece_catalog)
		var fp2 := band2.fingerprint()
		if fp1 != fp2:
			failures.append("seed %d: planning perturbed the layout RNG (fp %s != %s)"
				% [seed, fp1.substr(0, 12), fp2.substr(0, 12)])
		_free_band(band1)
		_free_band(band2)

	# --- 6. duplicate(true) isolation ---------------------------------------
	var iso_band := gen.generate(424242, cfg, piece_catalog)
	grader.grade(iso_band)
	var iso_plan := placer.plan(iso_band, curve, junk_catalog)
	if iso_plan.size() >= 2:
		var first: JunkItem = iso_plan[0]["item"]
		var first_id := first.id
		# Snapshot the catalog template and a sibling's value before mutation.
		var template_before := -1
		for it in junk_catalog.items:
			if it.id == first_id:
				template_before = it.base_sell_value
				break
		var sibling: JunkItem = iso_plan[1]["item"]
		var sibling_before := sibling.base_sell_value
		first.base_sell_value = 999999
		# Template untouched?
		var template_after := -1
		for it in junk_catalog.items:
			if it.id == first_id:
				template_after = it.base_sell_value
				break
		if template_after != template_before:
			failures.append("duplicate(true) leaked: catalog template changed %d -> %d"
				% [template_before, template_after])
		if sibling.base_sell_value != sibling_before:
			failures.append("duplicate(true) leaked: sibling changed %d -> %d"
				% [sibling_before, sibling.base_sell_value])
	else:
		failures.append("isolation check: plan too small (%d) to compare siblings" % iso_plan.size())
	_free_band(iso_band)

	# --- Report -------------------------------------------------------------
	if failures.is_empty():
		var b := gen.generate(12345, cfg, piece_catalog)
		grader.grade(b)
		grader.compute_return_distance(b)
		var pl := placer.plan(b, curve, junk_catalog)
		print("BAND DEPTH OK — graded %d pieces (max_depth=%d), planned %d junk items; "
				% [b.pieces.size(), b.max_depth, pl.size()]
			+ "value rises with depth (shallow $%.1f -> deep $%.1f), tier gate + plan "
				% [shallow_avg, deep_avg]
			+ "determinism + no RNG cross-talk verified across %d seeds (sample fp=%s)"
				% [SEEDS.size(), placer.plan_fingerprint(pl).substr(0, 12)])
		_free_band(b)
		return 0
	for f in failures:
		printerr("BAND DEPTH FAIL: ", f)
	return 1


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
