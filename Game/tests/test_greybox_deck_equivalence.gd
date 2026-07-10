extends Node
## V3 (M1.12) — THE K5 legacy→deck EQUIVALENCE PROOF (DR-3 / D-RAT-3a sign-off artifact).
##
## Compares the POST-migration band_greybox DECK plan (pingpong/bomb/spike drawn through
## EncounterBuilder's credit machine at the play-preset param_overrides) against the
## FROZEN pre-migration K5 fair-share plan captured before `_populate_legacy` was deleted
## (tests/goldens/greybox_k5_legacy_plan.json). Same fixed hand-built graded bands
## (tests/k5_equivalence_bands.gd) both sides.
##
## The equivalence bar (D-RAT-3a, ratified):
##   1. TYPE COVERAGE (exact) — the SET of spawned def_ids is identical before/after
##      (a neutral type that spawned 0 in the legacy plan spawns 0 in the deck plan).
##   2. PER-TYPE TOTAL within ±15% — |deck − legacy| <= max(1, ceil(0.15·legacy)).
##   3. DISTRIBUTION (proxy) — the deck reaches AT LEAST as deep as the legacy plan
##      (FBM19/FB2 even-spread spreads greybox hazards slightly DEEPER — same types,
##      comparable totals, deeper distribution: a Director-accepted improvement).
##   4. ENTRY SAFETY (hard) — zero spawns in the depth-0 entry piece (BUG7).
##   5. CAPS (hard) — per-room count <= the def per_room_cap (2/2/1); band total <= the
##      &"new_hazards" cap-group ceiling (48).
##   6. DETERMINISM (hard) — two deck builds → byte-identical plans (RNG-free).
##
## Run as a SCENE:  godot --headless --path Game res://tests/test_greybox_deck_equivalence.tscn

const CELL := 16
const FIXTURE_PATH := "res://tests/goldens/greybox_k5_legacy_plan.json"
const GREYBOX_PROFILE_PATH := "res://data/bands/band_greybox.tres"
const K5_BANDS := preload("res://tests/k5_equivalence_bands.gd")
const CEILING := 48    # the &"new_hazards" cap-group ceiling (bounds the K5 trio only)
# V3b (M1.12): band_greybox.opposition_credits was bumped 48 → 58 so the shared credit
# budget covers the K5 trio (≤48, cap-group bound) PLUS the pursuer (10, per_band_cap
# bound) — the pursuer is NOT in the new_hazards cap-group (additive). K5 counts are
# UNCHANGED (still cap-bound at 48), so this test stays green; the pursuer's own
# equivalence is proven separately in test_pursuer_deck_equivalence.gd.
const CREDITS := 58
const TOLERANCE := 0.15
const PER_ROOM_CAP := { "pingpong": 2, "bomb": 2, "spike": 1 }   # the shared-def caps
const K5_IDS := ["pingpong", "bomb", "spike"]


## The plan-recording service (mirrors the capture recorder): real BUG7 filter + the real
## cap stack (per-room / per-band / cap-group), records the ordered (id, cell, depth,
## room_key) instructions without instantiating.
class RecordingService:
	extends SpawnService
	var plan: Array[Dictionary] = []

	func spawn(def: OppositionDef, cell: Vector2i, ctx: Dictionary = {}) -> Node:
		if not bool(ctx.get("ignore_entry_safety", false)) and valid_cells([cell]).size() != 1:
			return null
		if not _caps_allow(def, ctx):
			return null
		plan.append({
			"id": String(def.id),
			"cx": int(cell.x), "cy": int(cell.y),
			"depth": int(ctx.get("depth", 0)),
			"room_key": String(ctx.get("room_key", "")),
		})
		_register(def, self, cell, String(ctx.get("room_key", "")))
		return self


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	var f := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if f == null:
		printerr("V3 EQUIV FAIL: frozen fixture missing at %s" % FIXTURE_PATH)
		return 1
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("bands"):
		printerr("V3 EQUIV FAIL: fixture malformed")
		return 1
	var fixture: Dictionary = (parsed as Dictionary)["bands"]

	var profile := load(GREYBOX_PROFILE_PATH) as BandProfile
	if profile == null or profile.opposition_deck.is_empty():
		failures.append("band_greybox profile has no opposition_deck (V3 authoring missing)")
	if profile != null and profile.opposition_credits != CREDITS:
		failures.append("band_greybox.opposition_credits = %d, expected %d (K5 48 + pursuer 10, V3b)"
			% [profile.opposition_credits, CREDITS])
	var rc := RunConfig.make_default_play_preset()

	var bands := K5_BANDS.all_bands()
	print("V3 K5 EQUIVALENCE (deck vs frozen legacy fair-share) @ play preset:")
	print("  band          type       legacy  deck   Δ%%    within ±15%%?")
	for name: String in bands:
		if not fixture.has(name):
			failures.append("fixture has no band '%s'" % name)
			continue
		var band: Band = bands[name]
		var legacy: Dictionary = fixture[name]
		var deck_plan := _deck_plan(band, profile, rc)

		# (6) determinism — a second build must be byte-identical.
		var deck_plan2 := _deck_plan(band, profile, rc)
		if str(deck_plan2) != str(deck_plan):
			failures.append("(%s) deck plan is NOT deterministic across builds" % name)

		_assert_band(name, band, legacy, deck_plan, failures)

	K5_BANDS.free_all(bands)

	if failures.is_empty():
		print("V3 EQUIV OK — the band_greybox deck reproduces the pre-migration K5 fair-share plan "
			+ "(exact type coverage, per-type totals within ±15%%, entry-safe, caps honoured, "
			+ "deterministic, distribution reaches ≥ as deep) across %d fixed bands." % bands.size())
		return 0
	for fail in failures:
		printerr("V3 EQUIV FAIL: ", fail)
	return 1


## Run the deck lane on a band via the recording service; return the ordered plan.
func _deck_plan(band: Band, profile: BandProfile, rc: RunConfig) -> Array[Dictionary]:
	var svc := RecordingService.new()
	var container := Node2D.new()
	add_child(container)
	svc.begin_band(container, CELL, K5_BANDS.entry_pos(band, CELL), rc)
	svc.set_cap_group(&"new_hazards", CEILING)
	EncounterBuilder.new().populate(band, profile, rc, svc)
	var out: Array[Dictionary] = svc.plan.duplicate(true)
	remove_child(container)
	container.free()
	return out


func _assert_band(name: String, band: Band, legacy: Dictionary, deck: Array[Dictionary],
		failures: Array[String]) -> void:
	var legacy_per_type: Dictionary = legacy["per_type"]
	# --- reduce the deck plan ---
	var deck_per_type := { "pingpong": 0, "bomb": 0, "spike": 0 }
	var deck_deepest := { "pingpong": -1, "bomb": -1, "spike": -1 }
	var per_room := {}   # "id|room_key" -> count
	var legacy_deepest := _legacy_deepest(legacy)
	var k5_count := 0    # V3b: count only new_hazards cap-group members against the 48 ceiling
	for r in deck:
		var id: String = r["id"]
		# V3b (M1.12): the deck now also spawns the pursuer — skip it from every K5-specific
		# assertion (its own equivalence is test_pursuer_deck_equivalence.gd). This keeps THIS
		# proof exactly the K5 fair-share check it always was.
		if not K5_IDS.has(id):
			continue
		k5_count += 1
		deck_per_type[id] = int(deck_per_type.get(id, 0)) + 1
		deck_deepest[id] = maxi(int(deck_deepest[id]), int(r["depth"]))
		# (4) entry safety.
		if int(r["depth"]) <= 0:
			failures.append("(%s) %s spawned in the depth-0 entry piece (BUG7)" % [name, id])
		# (5) per-room cap.
		var rk: String = "%s|%s" % [id, r["room_key"]]
		per_room[rk] = int(per_room.get(rk, 0)) + 1
		if int(per_room[rk]) > int(PER_ROOM_CAP.get(id, 99)):
			failures.append("(%s) %s exceeded per-room cap %d in room %s"
				% [name, id, int(PER_ROOM_CAP.get(id, 99)), r["room_key"]])

	# (5) band ceiling — the K5 trio (cap-group members) must stay within the 48 ceiling.
	if k5_count > CEILING:
		failures.append("(%s) K5 total %d > cap-group ceiling %d" % [name, k5_count, CEILING])

	# (1) type coverage — the SET of types that spawned (>0) must match exactly.
	var legacy_set := _nonzero_set(legacy_per_type)
	var deck_set := _nonzero_set(deck_per_type)
	if legacy_set != deck_set:
		failures.append("(%s) type coverage differs: legacy %s vs deck %s"
			% [name, str(legacy_set), str(deck_set)])

	# (2) per-type total within ±15%, and (3) distribution reaches ≥ as deep.
	for id: String in ["pingpong", "bomb", "spike"]:
		var old_n := int(legacy_per_type.get(id, 0))
		var new_n := int(deck_per_type.get(id, 0))
		var allow := maxi(1, int(ceil(TOLERANCE * float(old_n))))
		var ok := absi(new_n - old_n) <= allow
		var pct := 0.0 if old_n == 0 else 100.0 * float(new_n - old_n) / float(old_n)
		print("  %-13s %-10s %5d  %5d  %+5.1f   %s"
			% [name, id, old_n, new_n, pct, "yes" if ok else "NO"])
		if not ok:
			failures.append("(%s) %s total %d vs legacy %d exceeds ±15%% (allow ±%d)"
				% [name, id, new_n, old_n, allow])
		# (3) distribution proxy: a type that spawns in both must reach ≥ as deep as legacy.
		if old_n > 0 and new_n > 0 and int(deck_deepest[id]) < int(legacy_deepest.get(id, 0)):
			failures.append("(%s) %s deepest deck spawn depth %d < legacy deepest %d (should spread ≥ as deep)"
				% [name, id, int(deck_deepest[id]), int(legacy_deepest.get(id, 0))])


func _nonzero_set(per_type: Dictionary) -> Array:
	var out: Array = []
	for id: String in per_type:
		if int(per_type[id]) > 0:
			out.append(id)
	out.sort()
	return out


func _legacy_deepest(legacy: Dictionary) -> Dictionary:
	var out := {}
	var per_depth: Dictionary = legacy.get("per_depth", {})
	for id: String in per_depth:
		var deepest := 0
		for d: String in per_depth[id]:
			deepest = maxi(deepest, int(d))
		out[id] = deepest
	return out
