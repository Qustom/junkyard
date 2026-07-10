extends Node
## V1 regression (M1.12) — the by-id spawn-weight map cannot misalign.
##
## Run as a SCENE (not --script) so the autoloads (EventBus / RNG / GameState)
## that band generation relies on are present:
##   godot --headless res://tests/test_junk_catalog_by_id.tscn
##
## Proves the invariant V1 retired: a mid-list INSERT into `items` no longer
## shifts any weight (the old index-aligned PackedFloat32Array would have), plus:
##   1. Insert-invariance: every ORIGINAL item resolves to its original weight
##      after inserting a new item at index 0 (by-id: unaffected). The old index
##      model WOULD have shifted them — asserted explicitly for contrast.
##   2. Default: the inserted item (no map entry) resolves to the 1.0 pick-time
##      default (== JunkPlacer's `get(id, 1.0)` fallback).
##   3. Authoring gate: check_junk_catalog's id-coverage assertion WOULD flag the
##      missing entry (the "forgot a weight" case the old size-check missed).
##   4. Q2 hash-order invariance: two catalogs with identical items+weights but
##      DIFFERENT map insertion order produce an identical junk plan_fingerprint.

const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"
const PIECE_CATALOG_PATH := "res://data/piece_catalog.tres"
const CONFIG_PATH := "res://data/bandgen_config.tres"
const DEPTH_CURVE_PATH := "res://systems/depth/depth_curve.tres"

const SEED := 12345


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	var cat: JunkCatalog = load(JUNK_CATALOG_PATH)
	if cat == null:
		printerr("JUNK BY-ID FAIL: could not load catalog")
		return 1

	# --- Snapshot resolved weight-per-id for the authored catalog ------------
	var original: Dictionary = {}  # id -> resolved weight
	for it in cat.items:
		original[it.id] = _resolved_weight(cat, it.id)

	# --- 1+2. Mid-list insert: a NEW item at index 0, no weight entry ---------
	var inserted := JunkItem.new()
	inserted.id = &"junk_test_insert"
	inserted.tier = 1
	inserted.base_sell_value = 10

	var cat2 := JunkCatalog.new()
	cat2.spawn_weights_by_id = cat.spawn_weights_by_id  # SAME map, unchanged
	var items2: Array[JunkItem] = []
	items2.append(inserted)                              # <-- insert at index 0
	for it in cat.items:
		items2.append(it)
	cat2.items = items2

	# By-id: every original item resolves to its original weight, insert or not.
	for id in original:
		var now := _resolved_weight(cat2, id)
		if now != original[id]:
			failures.append("by-id insert shifted weight for '%s': %s -> %s"
				% [id, original[id], now])

	# Contrast: the OLD index model WOULD have misaligned. cat2.items[i] no longer
	# lines up with the positional weight it had in `cat` — prove the shift the
	# by-id map now immunises against actually exists under positional lookup.
	var shifted_any := false
	var weights_in_order: Array[float] = []
	for it in cat.items:
		weights_in_order.append(float(cat.spawn_weights_by_id[it.id]))
	for i in cat.items.size():
		# item now at position i+1 in cat2; old index model would read weights_in_order[i+1]
		var pos_in_cat2 := i + 1
		if pos_in_cat2 < weights_in_order.size():
			var id_now: StringName = cat2.items[pos_in_cat2].id
			if float(cat.spawn_weights_by_id[id_now]) != weights_in_order[pos_in_cat2]:
				shifted_any = true
	if not shifted_any:
		failures.append("test setup weak: index model would not have shifted — "
			+ "cannot demonstrate the retired bug")

	# The inserted item (no map entry) resolves to the 1.0 default.
	var ins_w := _resolved_weight(cat2, inserted.id)
	if ins_w != 1.0:
		failures.append("inserted item resolved to %s, expected 1.0 default" % ins_w)

	# --- 3. Authoring gate: id-coverage flags the missing entry --------------
	if not _would_flag_missing_coverage(cat2):
		failures.append("id-coverage check did NOT flag the missing weight entry "
			+ "for the inserted item")

	# --- 4. Q2 hash-order invariance of the junk plan_fingerprint ------------
	# Two catalogs, identical items+weights, but the map built in DIFFERENT
	# insertion orders. _weighted_pick iterates `indices` (array order), never the
	# map keys, so the plan must be byte-identical.
	var fp_a := _plan_fp(_catalog_with_map_order(cat, false), failures)
	var fp_b := _plan_fp(_catalog_with_map_order(cat, true), failures)
	if fp_a != "" and fp_b != "" and fp_a != fp_b:
		failures.append("map insertion order changed plan_fingerprint: %s != %s"
			% [fp_a, fp_b])

	if failures.is_empty():
		print("JUNK BY-ID OK — mid-list insert leaves all %d weights unshifted; "
			% original.size()
			+ "inserted item -> 1.0 default; id-coverage flags it; "
			+ "plan_fingerprint invariant to map hash order.")
		return 0
	for f in failures:
		printerr("JUNK BY-ID FAIL: ", f)
	return 1


## Resolved pick-time weight for an id — mirrors JunkPlacer._weighted_pick's
## `maxf(float(spawn_weights_by_id.get(id, 1.0)), 0.0)` contract exactly.
func _resolved_weight(cat: JunkCatalog, id: StringName) -> float:
	return maxf(float(cat.spawn_weights_by_id.get(id, 1.0)), 0.0)


## Mirrors check_junk_catalog.gd's id-coverage assertion: true iff some item id
## lacks a spawn_weights_by_id entry.
func _would_flag_missing_coverage(cat: JunkCatalog) -> bool:
	for it in cat.items:
		if it != null and it.id != &"" and not cat.spawn_weights_by_id.has(it.id):
			return true
	return false


## A fresh JunkCatalog with the same items and the same id->weight pairs, but with
## the map built in forward (reversed=false) or reverse (reversed=true) insertion
## order — to prove the pick is independent of Dictionary hash/insertion order.
func _catalog_with_map_order(src: JunkCatalog, reversed: bool) -> JunkCatalog:
	var c := JunkCatalog.new()
	c.items = src.items
	var m: Dictionary[StringName, float] = {}
	var ids: Array[StringName] = []
	for it in src.items:
		ids.append(it.id)
	if reversed:
		ids.reverse()
	for id in ids:
		m[id] = float(src.spawn_weights_by_id[id])
	c.spawn_weights_by_id = m
	return c


## Generate + grade a band and return the junk plan_fingerprint for `cat`.
func _plan_fp(cat: JunkCatalog, failures: Array[String]) -> String:
	var piece_catalog_res = load(PIECE_CATALOG_PATH)
	var cfg = load(CONFIG_PATH)
	var curve: DepthCurve = load(DEPTH_CURVE_PATH)
	if piece_catalog_res == null or cfg == null or curve == null:
		failures.append("could not load band fixtures for plan fp")
		return ""
	var piece_catalog: Array[ZonePieceData] = piece_catalog_res.pieces
	var gen := BandGenerator.new()
	var grader := DepthGrader.new()
	var placer := JunkPlacer.new()
	var band := gen.generate(SEED, cfg, piece_catalog)
	grader.grade(band)
	grader.compute_return_distance(band)
	var plan := placer.plan(band, curve, cat)
	var fp := placer.plan_fingerprint(plan)
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
	return fp
