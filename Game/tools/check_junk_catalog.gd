extends SceneTree
## C1 headless data check (game-director-designer): validates the junk catalog
## loads, references 8 items, has by-id weights (id-coverage + no orphans +
## non-negative), and spans the intended ~40x value spread. Run with:
##
##   godot --headless --script res://tools/check_junk_catalog.gd
##
## Exits non-zero on any failure so it can gate CI alongside ci_smoke_test.gd.

const CATALOG_PATH := "res://data/junk/junk_catalog.tres"
const EXPECTED_ITEMS := 8
const MIN_SPREAD := 30.0  # floor-to-ceiling ratio must be at least this (target ~40x)

func _initialize() -> void:
	var failures: Array[String] = []

	var cat: JunkCatalog = load(CATALOG_PATH) as JunkCatalog
	if cat == null:
		failures.append("catalog failed to load or is not a JunkCatalog: %s" % CATALOG_PATH)
		_finish(failures)
		return

	if cat.items.size() != EXPECTED_ITEMS:
		failures.append("expected %d items, got %d" % [EXPECTED_ITEMS, cat.items.size()])

	var seen_ids := {}
	var min_val := 1 << 30
	var max_val := 0
	for it in cat.items:
		if it == null:
			failures.append("catalog contains a null item")
			continue
		if it.id == &"":
			failures.append("item '%s' has an empty id" % it.display_name)
		# Duplicate id is now doubly load-bearing: a repeated id also silently
		# collides in spawn_weights_by_id (last-writer-wins), so this walk guards
		# the by-id weight mapping too.
		if seen_ids.has(it.id):
			failures.append("duplicate id: %s" % it.id)
		seen_ids[it.id] = true
		if it.base_sell_value <= 0:
			failures.append("item '%s' has non-positive base_sell_value" % it.id)
		# C1b: every junk item must carry a depth/rarity tier (1–5) for B3's
		# tier-threshold unlocks.
		if it.tier < 1 or it.tier > 5:
			failures.append("item '%s' has tier %d outside the 1–5 range" % [it.id, it.tier])
		min_val = mini(min_val, it.base_sell_value)
		max_val = maxi(max_val, it.base_sell_value)

	if min_val > 0:
		var spread := float(max_val) / float(min_val)
		if spread < MIN_SPREAD:
			failures.append("value spread %.1fx below required %.0fx (min=%d max=%d)" % [spread, MIN_SPREAD, min_val, max_val])

	# --- by-id spawn-weight mapping (replaces the old size-only alignment check) ---
	# Semantic mapping-check: id-coverage + no-orphans + non-negative. The old
	# `spawn_weights.size() == items.size()` gate was a COUNT check that could not
	# catch a mis-positioned insert; the by-id map makes the check a MAPPING check.

	# id-coverage: every item id must have a weight entry (catch "forgot a weight").
	for it in cat.items:
		if it != null and it.id != &"" and not cat.spawn_weights_by_id.has(it.id):
			failures.append("item '%s' has no spawn_weights_by_id entry" % it.id)

	# no-orphans: every weight key must correspond to a real catalog item id
	# (catch "weight for a deleted/renamed item").
	for key in cat.spawn_weights_by_id:
		if not seen_ids.has(key):
			failures.append("spawn_weights_by_id has orphan key with no item: %s" % key)

	# non-negative: mirrors JunkPlacer's maxf(.,0.0) intent — a negative authored
	# weight is an authoring error, not a silent clamp.
	for key in cat.spawn_weights_by_id:
		if float(cat.spawn_weights_by_id[key]) < 0.0:
			failures.append("spawn_weights_by_id[%s] is negative: %s" % [key, cat.spawn_weights_by_id[key]])

	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("JUNK CATALOG OK")
		quit(0)
	else:
		for f in failures:
			printerr("JUNK CATALOG FAIL: %s" % f)
		quit(1)
