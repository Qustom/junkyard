extends GdUnitTestSuite
## G2 — proc-gen determinism (B2 BandGenerator + B3 JunkPlacer).
##
## The hard acceptance bar of the whole project: same seed -> byte-identical
## world, different seed -> different world, and no hidden dependence on call
## order or prior global-RNG state. We assert that on BOTH deterministic stages:
##   - BandGenerator.generate(seed, cfg, catalog) -> Band   (layout)
##   - JunkPlacer.plan(graded_band, curve, catalog)         (loot placement)
##
## Real APIs (M1_As_Built): the generator reseeds the `RNG` autoload internally
## and a band exposes fingerprint(); the placer rolls a LOCAL sub-stream off
## band.resolved_seed (never the autoload) and exposes plan_fingerprint(). There
## is no LayoutGen.generate / a.tiles / a.fingerprint() string-vs-string as the
## stale spec sketch implies — those are corrected here to the shipped surface.

const Seeds := preload("res://tests/helpers/test_seeds.gd")

const CATALOG_PATH := "res://data/piece_catalog.tres"
const CONFIG_PATH := "res://data/bandgen_config.tres"
const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"
const DEPTH_CURVE_PATH := "res://systems/depth/depth_curve.tres"

var _gen: BandGenerator
var _catalog: Array[ZonePieceData]
var _cfg: BandGenConfig
var _junk_catalog: JunkCatalog
var _curve: DepthCurve
var _bands: Array[Band] = []   # tracked per-test; freed in _cleanup() before the method returns


func before() -> void:
	_gen = BandGenerator.new()
	var cat_res = load(CATALOG_PATH)
	assert_object(cat_res).is_not_null()
	_catalog = cat_res.pieces
	_cfg = load(CONFIG_PATH) as BandGenConfig
	assert_object(_cfg).is_not_null()
	_junk_catalog = load(JUNK_CATALOG_PATH) as JunkCatalog
	assert_object(_junk_catalog).is_not_null()
	_curve = load(DEPTH_CURVE_PATH) as DepthCurve
	assert_object(_curve).is_not_null()


func after_test() -> void:
	_cleanup()   # safety net if a test returns early before its own _cleanup()


## Free every band's throwaway ZonePiece instances. The generator parents them to
## nothing (they live only inside the Band data), so they are orphan Nodes until
## freed. GdUnit4 counts orphans at the END of each test METHOD, so each test calls
## this before returning — otherwise the run exits 101 (orphan warning) not 0.
func _cleanup() -> void:
	for band in _bands:
		_free_band(band)
	_bands.clear()


func _gen_band(seed: int) -> Band:
	var b := _gen.generate(seed, _cfg, _catalog)
	_bands.append(b)
	return b


func _graded_band(seed: int) -> Band:
	var b := _gen_band(seed)
	var grader := DepthGrader.new()
	grader.grade(b)
	grader.compute_return_distance(b)
	return b


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()


# --- Layout (B2) -------------------------------------------------------------

func test_same_seed_same_layout() -> void:
	var a := _gen_band(Seeds.CANONICAL)
	var b := _gen_band(Seeds.CANONICAL)
	var fp_a := a.fingerprint()
	var fp_b := b.fingerprint()
	var count_a := a.pieces.size()
	var count_b := b.pieces.size()
	_cleanup()
	assert_str(fp_a).is_equal(fp_b)
	# Structural equality too: identical piece count is a cheap corroborating check.
	assert_int(count_a).is_equal(count_b)


func test_different_seed_differs() -> void:
	var fp_a := _gen_band(Seeds.CANONICAL).fingerprint()
	var fp_b := _gen_band(Seeds.OTHER).fingerprint()
	_cleanup()
	assert_str(fp_a).is_not_equal(fp_b)


func test_repeated_generation_is_stable_across_calls() -> void:
	# Guards against hidden global-RNG bleed / call-order dependence: an unrelated
	# generation between two same-seed runs must not change the result.
	var first := _gen_band(Seeds.CANONICAL).fingerprint()
	_gen_band(Seeds.OTHER)                       # unrelated call in between
	var again := _gen_band(Seeds.CANONICAL).fingerprint()
	_cleanup()
	assert_str(first).is_equal(again)


func test_layout_pure_despite_global_rng_perturbation() -> void:
	# The generator reseeds the autoload internally, so perturbing the global RNG
	# between two same-seed runs must NOT change the layout (proves the seed, not
	# ambient state, determines the world).
	var first := _gen_band(424242).fingerprint()
	RNG.seed_from(987654321)
	RNG.randi()
	RNG.randi()
	var second := _gen_band(424242).fingerprint()
	_cleanup()
	assert_str(first).is_equal(second)


func test_all_canonical_seeds_deterministic() -> void:
	# Same-seed determinism + variation across the whole canonical spread in one
	# pass, so a regression on any single seed is caught.
	var fingerprints := {}
	var deterministic := true
	var offender := 0
	for seed in Seeds.ALL:
		var fp_a := _gen_band(seed).fingerprint()
		var fp_b := _gen_band(seed).fingerprint()
		if fp_a != fp_b:
			deterministic = false
			offender = seed
		fingerprints[fp_a] = true
	_cleanup()
	assert_bool(deterministic) \
		.override_failure_message("seed %d not deterministic" % offender) \
		.is_true()
	# Across distinct seeds we expect real variation (not all collapsing to one).
	assert_int(fingerprints.size()).is_greater(1)


# --- Loot placement (B3) -----------------------------------------------------

func test_plan_same_seed_same_plan() -> void:
	var band_a := _graded_band(Seeds.CANONICAL)
	var band_b := _graded_band(Seeds.CANONICAL)
	var placer := JunkPlacer.new()
	var plan_a := placer.plan(band_a, _curve, _junk_catalog)
	var plan_b := placer.plan(band_b, _curve, _junk_catalog)
	var fp_a := placer.plan_fingerprint(plan_a)
	var fp_b := placer.plan_fingerprint(plan_b)
	_cleanup()
	assert_str(fp_a).is_equal(fp_b)


func test_plan_does_not_perturb_layout_rng() -> void:
	# B3 sub-stream guarantee: planning loot off a band must leave the band's own
	# fingerprint unchanged and must be reproducible regardless of the global RNG.
	var band := _graded_band(Seeds.CANONICAL)
	var fp_before := band.fingerprint()
	var placer := JunkPlacer.new()
	var plan_1 := placer.plan(band, _curve, _junk_catalog)
	RNG.seed_from(13)
	RNG.randi()
	var plan_2 := placer.plan(band, _curve, _junk_catalog)
	var fp_after := band.fingerprint()
	var pfp_1 := placer.plan_fingerprint(plan_1)
	var pfp_2 := placer.plan_fingerprint(plan_2)
	_cleanup()
	assert_str(fp_after).is_equal(fp_before)
	assert_str(pfp_1).is_equal(pfp_2)
