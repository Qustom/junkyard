extends Node
## V3b (M1.12) — THE R1 pursuer → deck EQUIVALENCE PROOF (D-RAT-3a sign-off artifact).
##
## Compares the POST-migration band_greybox DECK plan (the pursuer drawn through
## EncounterBuilder's credit machine at the play-preset param_overrides) against the
## FROZEN pre-migration R1 pursuer plan captured before the main_game R1 machine was
## deleted (tests/goldens/pursuer_r1_plan.json — the J2 spread + J3 density total). Same
## fixed hand-built graded bands (tests/k5_equivalence_bands.gd) both sides.
##
## The equivalence bar (D-RAT-3a, ratified):
##   1. TYPE COVERAGE (exact) — the deck plan spawns &"pursuer" (present before & after).
##   2. PER-TYPE TOTAL within ±15% — |deck − fixture| <= max(1, ceil(0.15·fixture)).
##      The budget is sized (opposition_credits 58 = K5 48 + pursuer 10) + the pursuer's
##      per_band_cap (10) reserves its share, so it hits its historical ~5–10 regardless
##      of deck order (it draws LAST).
##   3. DISTRIBUTION (proxy) — the deck reaches AT LEAST as deep as the fixture. NOTE the
##      LICENSED FIDELITY LOSS: the historical J3 per-room AREA-SCALED density (big rooms
##      cluster more pursuers) has NO deck equivalent — those bodies FOLD into the deck's
##      flat even-spread. The per-type TOTAL is preserved (bar 2); the big-room spatial
##      clustering is NOT. D-RAT-3a explicitly licenses "deck even-spread ≠ per-piece
##      formula, spread slightly deeper" — this is the version's single largest behavioural
##      delta, surfaced to the Director as part of the D-RAT-3a close-out.
##   4. L2 ROOM-BOUNDS (hard) — a deck-spawned pursuer receives a non-empty room_bounds
##      (ctx["room_bounds"].has_area()), so r1_spawn_room_only's patrol works (the §a.4
##      regression guard: the legacy_ctx &"pursuer" arm threads the piece bounds).
##   5. ENTRY SAFETY (hard) — zero pursuers in the depth-0 entry piece (BUG7).
##   6. CAPS (hard) — pursuer total <= per_band_cap (10) <= the sized budget.
##   7. DETERMINISM (hard) — two deck builds → byte-identical plans (RNG-free).
##
## The BEHAVIOUR value-preserving-rewire proof (trace_pursuer_room.txt / trace_pursuer_chase.txt
## byte-identical after cfg.r1_* → spawn_ctx["params"]) is test_opposition_components.gd.
##
## Run as a SCENE:  godot --headless --path Game res://tests/test_pursuer_deck_equivalence.tscn

const CELL := 16
const FIXTURE_PATH := "res://tests/goldens/pursuer_r1_plan.json"
const GREYBOX_PROFILE_PATH := "res://data/bands/band_greybox.tres"
const K5_BANDS := preload("res://tests/k5_equivalence_bands.gd")
const CEILING := 48    # the &"new_hazards" cap-group ceiling (K5 trio only; pursuer is additive)
const CREDITS := 58    # band_greybox.opposition_credits (K5 48 + pursuer 10)
const PER_BAND_CAP := 10   # pursuer.tres.per_band_cap (reserves its share, order-independent)
const TOLERANCE := 0.15


## The plan-recording service: real BUG7 filter + the real cap stack, records the ordered
## (id, cell, depth, room_key, has_bounds) instructions without instantiating.
class RecordingService:
	extends SpawnService
	var plan: Array[Dictionary] = []

	func spawn(def: OppositionDef, cell: Vector2i, ctx: Dictionary = {}) -> Node:
		if not bool(ctx.get("ignore_entry_safety", false)) and valid_cells([cell]).size() != 1:
			return null
		if not _caps_allow(def, ctx):
			return null
		var rb: Rect2 = ctx.get("room_bounds", Rect2())
		plan.append({
			"id": String(def.id),
			"cx": int(cell.x), "cy": int(cell.y),
			"depth": int(ctx.get("depth", 0)),
			"room_key": String(ctx.get("room_key", "")),
			# THREADED = the legacy_ctx &"pursuer" arm passed a real piece bbox (non-default
			# Rect2). The pre-fix bug returned {} → an empty Rect2 (size 0,0). On the synthetic
			# flat single-row test rooms the bbox has 0 height (has_area false) yet is correctly
			# threaded (width > 0); real greybox rooms are 2D → has_area true (see the trace test).
			"threaded": rb.size.x > 0.0 or rb.size.y > 0.0,
			"has_area": rb.has_area(),
		})
		_register(def, self, cell, String(ctx.get("room_key", "")))
		return self


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	var f := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if f == null:
		printerr("V3b EQUIV FAIL: frozen fixture missing at %s" % FIXTURE_PATH)
		return 1
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("bands"):
		printerr("V3b EQUIV FAIL: fixture malformed")
		return 1
	var fixture: Dictionary = (parsed as Dictionary)["bands"]

	var profile := load(GREYBOX_PROFILE_PATH) as BandProfile
	if profile == null or profile.opposition_deck.is_empty():
		failures.append("band_greybox profile has no opposition_deck")
	if profile != null and profile.opposition_credits != CREDITS:
		failures.append("band_greybox.opposition_credits = %d, expected %d (K5 48 + pursuer 10)"
			% [profile.opposition_credits, CREDITS])
	# The pursuer's per_band_cap (its reserved share) rides the SHARED def (band_two's pursuer
	# is neutral → skipped → the cap never binds there).
	var pursuer_def := load("res://data/oppositions/pursuer.tres") as OppositionDef
	if pursuer_def == null or pursuer_def.per_band_cap != PER_BAND_CAP:
		failures.append("pursuer.tres.per_band_cap = %s, expected %d"
			% [str(pursuer_def.per_band_cap if pursuer_def != null else "<null>"), PER_BAND_CAP])

	var rc := RunConfig.make_default_play_preset()

	var bands := K5_BANDS.all_bands()
	print("V3b PURSUER EQUIVALENCE (deck vs frozen R1 J2+J3 plan) @ play preset:")
	print("  band          fixture  deck   Δ%%    within ±15%%?   L2 bounds?")
	for name: String in bands:
		if not fixture.has(name):
			failures.append("fixture has no band '%s'" % name)
			continue
		var band: Band = bands[name]
		var fx: Dictionary = fixture[name]
		var deck_plan := _deck_plan(band, profile, rc)

		# (7) determinism — a second build must be byte-identical.
		var deck_plan2 := _deck_plan(band, profile, rc)
		if str(deck_plan2) != str(deck_plan):
			failures.append("(%s) deck plan is NOT deterministic across builds" % name)

		_assert_band(name, fx, deck_plan, failures)

	K5_BANDS.free_all(bands)

	if failures.is_empty():
		print("V3b EQUIV OK — the band_greybox deck reproduces the pre-migration R1 pursuer "
			+ "per-type TOTAL within ±15% (exact type coverage, entry-safe, per_band_cap honoured, "
			+ "L2 room-bounds present, deterministic, distribution reaches ≥ as deep) across %d "
			% bands.size() + "fixed bands. LICENSED: the J3 per-room area-scaled density folds to "
			+ "the deck's even-spread — the per-type total is preserved, big-room clustering is not.")
		return 0
	for fail in failures:
		printerr("V3b EQUIV FAIL: ", fail)
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


func _assert_band(name: String, fx: Dictionary, deck: Array[Dictionary],
		failures: Array[String]) -> void:
	var fixture_total := int(fx.get("total", 0))
	var fixture_deepest := _fixture_deepest(fx)

	var deck_total := 0
	var deck_deepest := -1
	for r in deck:
		if r["id"] != "pursuer":
			continue   # K5 spawns are proven by test_greybox_deck_equivalence.gd
		deck_total += 1
		deck_deepest = maxi(deck_deepest, int(r["depth"]))
		# (5) entry safety.
		if int(r["depth"]) <= 0:
			failures.append("(%s) pursuer spawned in the depth-0 entry piece (BUG7)" % name)
		# (4) L2 room-bounds THREADED (the legacy_ctx &"pursuer" arm passed the piece bbox —
		# the §a.4 regression guard: the pre-fix returned {} → empty bounds → chase-everywhere).
		if not bool(r["threaded"]):
			failures.append("(%s) deck-spawned pursuer got EMPTY (default) room_bounds — the "
				% name + "legacy_ctx &\"pursuer\" arm did not thread the piece bounds")

	# (1) type coverage — the pursuer must spawn (it did in the fixture on every band).
	if fixture_total > 0 and deck_total <= 0:
		failures.append("(%s) type coverage: fixture had %d pursuers, deck spawned 0" % [name, fixture_total])

	# (6) caps — never exceed the reserved per_band_cap.
	if deck_total > PER_BAND_CAP:
		failures.append("(%s) pursuer total %d > per_band_cap %d" % [name, deck_total, PER_BAND_CAP])

	# (2) per-type total within ±15%.
	var allow := maxi(1, int(ceil(TOLERANCE * float(fixture_total))))
	var ok := absi(deck_total - fixture_total) <= allow
	var pct := 0.0 if fixture_total == 0 else 100.0 * float(deck_total - fixture_total) / float(fixture_total)
	var threaded_ok := deck_total == 0 or _all_threaded(deck)
	print("  %-13s %5d  %5d  %+5.1f   %-11s   %s"
		% [name, fixture_total, deck_total, pct, "yes" if ok else "NO", "yes" if threaded_ok else "NO"])
	if not ok:
		failures.append("(%s) pursuer total %d vs fixture %d exceeds ±15%% (allow ±%d)"
			% [name, deck_total, fixture_total, allow])

	# (3) distribution proxy — the deck reaches ≥ as deep as the fixture (density-fold licensed).
	if fixture_total > 0 and deck_total > 0 and deck_deepest < fixture_deepest:
		failures.append("(%s) pursuer deepest deck spawn depth %d < fixture deepest %d (should spread ≥ as deep)"
			% [name, deck_deepest, fixture_deepest])


func _all_threaded(deck: Array[Dictionary]) -> bool:
	for r in deck:
		if r["id"] == "pursuer" and not bool(r["threaded"]):
			return false
	return true


func _fixture_deepest(fx: Dictionary) -> int:
	var out := 0
	var per_depth: Dictionary = fx.get("per_depth", {})
	for d: String in per_depth:
		out = maxi(out, int(d))
	return out
