extends Node
## S9 acceptance (M1.9 Wave 5) — DeckEntry deck-row override wrapper, the
## D-RAT-2 delivery. Run as a SCENE (autoloads + a live tree):
##   godot --headless --path Game res://tests/test_deck_entry.tscn
##
## A FakeSpawnService (extends SpawnService, overrides spawn() only — the
## test_encounter_builder recorder pattern) captures the builder's ordered
## (def_id, cell, ctx) plan; every case is PLAN-level, no entity instantiation.
##
## Asserts (TASKS §S9 contract):
##  (a) EMPTY-OVERRIDES PARITY: a DeckEntry with empty param_overrides produces a
##      plan byte-identical to the plain def ref (same requests, cells, ctx).
##  (b) PRECEDENCE: def params < deck-entry overrides < rc.param_overrides —
##      each layer's exclusive keys survive, contested keys resolve outward;
##      deck-entry overrides also reach the COUNT math (base_count override).
##  (c) BAND_TWO CHARGER: through the real band_two.tres + BandPipeline, every
##      charger instruction's resolved ctx params carry the D-RAT-2 values
##      (throwable_while_charging=false, wall_crash_recover_mult=2.0), every
##      non-overridden charger param stays def-authored, non-charger deck rows
##      are untouched, and rc.param_overrides still wins on top of the wrapper.
##  (d) MIXED ARRAY: plain refs and wrappers interleave (order preserved,
##      overrides bind only to the wrapped row); id-dedup stays FIRST-wins
##      including the first row's overrides; a broken wrapper (null def)
##      fail-louds + is skipped without derailing the rest of the deck.
##  (e) FP GUARDS: all-off through the pipeline pins the permanent control
##      fp e943ac9c8bc1; all-off + band_greybox stays inert; band_two layout
##      generation stays deterministic (fingerprints are layout-only — the
##      deck rewrap must not move them).

const CELL := 16
const BASELINE_FP := "e943ac9c8bc1"

const GREYBOX_PATH := "res://data/bands/band_greybox.tres"
const BAND_TWO_PATH := "res://data/bands/band_two.tres"
const CHARGER_DEF_PATH := "res://data/oppositions/charger.tres"


## The policy-blind recording service (test_encounter_builder's pattern):
## inherits the REAL begin_band/valid_cells, replaces only the mechanism.
class FakeSpawnService:
	extends SpawnService
	var requests: Array[Dictionary] = []         # ordered successful (id, cell, ctx)
	var _stub_nodes: Array[Node] = []

	func spawn(def: OppositionDef, cell: Vector2i, ctx: Dictionary = {}) -> Node:
		var one: Array[Vector2i] = [cell]
		if valid_cells(one).size() != 1:         # the real BUG7 re-check
			return null
		requests.append({ "id": def.id, "cell": cell, "ctx": ctx })
		var n := Node.new()
		_stub_nodes.append(n)
		return n

	func cleanup() -> void:
		for n in _stub_nodes:
			if is_instance_valid(n):
				n.free()
		_stub_nodes.clear()


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	_case_empty_overrides_parity(failures)
	_case_precedence(failures)
	_case_band_two_charger(failures)
	_case_mixed_array(failures)
	_case_fp_guards(failures)

	if failures.is_empty():
		print("S9 OK — DeckEntry verified: empty-overrides wrapper byte-identical to the "
			+ "plain ref, precedence def params < deck-entry overrides < rc.param_overrides "
			+ "(incl. the count math), band_two's charger resolves the D-RAT-2 values "
			+ "(throwable_while_charging=false / wall_crash_recover_mult=2.0) with "
			+ "non-overridden params def-authored and rc still winning on top, mixed "
			+ "plain/wrapper decks order-preserving + first-wins-deduped + fail-loud on "
			+ "broken wrappers, all-off fp " + BASELINE_FP + " pinned + greybox inert + "
			+ "band_two layout deterministic.")
		return 0
	for f in failures:
		printerr("S9 FAIL: ", f)
	return 1


# --- (a) empty-overrides wrapper ≡ plain ref -----------------------------------

func _case_empty_overrides_parity(failures: Array[String]) -> void:
	var def := _make_def(&"synth_a", 1, 0, 2, 0.5)
	def.params["flavor_knob"] = 7.5
	var band := _make_band([16, 64, 100])
	var rc := RunConfig.new()

	var svc_plain := _fresh_fake(rc, Vector2.INF)
	EncounterBuilder.new().populate(band, _deck_profile([def], 2), rc, svc_plain)

	var svc_wrapped := _fresh_fake(rc, Vector2.INF)
	EncounterBuilder.new().populate(band, _deck_profile([_wrap(def, {})], 2), rc, svc_wrapped)

	if svc_plain.requests.is_empty():
		failures.append("(a) plain-ref control produced no requests (test mis-set)")
	if svc_plain.requests.size() != svc_wrapped.requests.size():
		failures.append("(a) wrapped plan size %d != plain plan size %d"
			% [svc_wrapped.requests.size(), svc_plain.requests.size()])
	else:
		for i in svc_plain.requests.size():
			if svc_plain.requests[i] != svc_wrapped.requests[i]:
				failures.append("(a) empty-overrides wrapper diverges from the plain ref at "
					+ "index %d: %s vs %s" % [i, str(svc_wrapped.requests[i]), str(svc_plain.requests[i])])
				break
	_free_fake(svc_plain)
	_free_fake(svc_wrapped)


# --- (b) precedence: def < deck-entry < rc --------------------------------------

func _case_precedence(failures: Array[String]) -> void:
	var def := _make_def(&"synth_x", 1, 0, 1, 0.0)
	def.params["p_shared"] = 1        # contested on all three layers
	def.params["p_def"] = "authored"  # def-only key must survive untouched
	var wrapper := _wrap(def, { "p_shared": 2, "p_deck": true })
	var band := _make_band([16, 64])

	# Deck-entry layer beats the def; def-only keys survive; deck-only keys land.
	var rc_plain := RunConfig.new()
	var svc1 := _fresh_fake(rc_plain, Vector2.INF)
	EncounterBuilder.new().populate(band, _deck_profile([wrapper], 1), rc_plain, svc1)
	if svc1.requests.is_empty():
		failures.append("(b) wrapper deck produced no requests (test mis-set)")
	else:
		var params: Dictionary = (svc1.requests[0]["ctx"] as Dictionary).get("params", {})
		if int(params.get("p_shared", -1)) != 2:
			failures.append("(b) deck-entry override lost to the def: p_shared=%s, expected 2"
				% str(params.get("p_shared")))
		if params.get("p_deck", null) != true:
			failures.append("(b) deck-only override key missing from the ctx merge")
		if params.get("p_def", "") != "authored":
			failures.append("(b) def-only param clobbered: p_def=%s" % str(params.get("p_def")))
	_free_fake(svc1)

	# rc layer beats the deck entry; unrelated deck keys survive; rc-only keys land.
	var rc_over := RunConfig.new()
	rc_over.param_overrides = { "synth_x": { "p_shared": 3, "p_rc": 0.5 } }
	var svc2 := _fresh_fake(rc_over, Vector2.INF)
	EncounterBuilder.new().populate(band, _deck_profile([wrapper], 1), rc_over, svc2)
	if svc2.requests.is_empty():
		failures.append("(b) wrapper deck + rc produced no requests")
	else:
		var params: Dictionary = (svc2.requests[0]["ctx"] as Dictionary).get("params", {})
		if int(params.get("p_shared", -1)) != 3:
			failures.append("(b) rc.param_overrides lost to the deck entry: p_shared=%s, expected 3"
				% str(params.get("p_shared")))
		if params.get("p_deck", null) != true:
			failures.append("(b) deck-only key lost when rc overlaid")
		if float(params.get("p_rc", 0.0)) != 0.5:
			failures.append("(b) rc-only key missing from the ctx merge")
		if params.get("p_def", "") != "authored":
			failures.append("(b) def-only param clobbered when both layers overlaid")
	_free_fake(svc2)

	# Deck-entry overrides reach the COUNT math: a neutral card (base_count 0)
	# spawns only because the wrapper re-tunes base_count.
	var neutral := _make_def(&"synth_n", 1, 0, 0, 0.0)
	var svc3 := _fresh_fake(rc_plain, Vector2.INF)
	EncounterBuilder.new().populate(band,
		_deck_profile([_wrap(neutral, { "base_count": 1 })], 1), rc_plain, svc3)
	if svc3.requests.size() != 1:
		failures.append("(b) base_count deck override did not reach the count math: %d requests, expected 1"
			% svc3.requests.size())
	_free_fake(svc3)


# --- (c) band_two's charger receives the D-RAT-2 values --------------------------

func _case_band_two_charger(failures: Array[String]) -> void:
	var profile := load(BAND_TWO_PATH) as BandProfile
	var charger_def := load(CHARGER_DEF_PATH) as OppositionDef
	if profile == null or charger_def == null:
		failures.append("(c) could not load band_two.tres / charger.tres")
		return
	var band := BandPipeline.new().generate(profile, 12345, RunConfig.new())
	if band == null:
		failures.append("(c) band_two pipeline returned null")
		return

	var rc := RunConfig.new()
	var svc := _fresh_fake(rc, Vector2.INF)
	EncounterBuilder.new().populate(band, profile, rc, svc)
	var charger_n := 0
	for r in svc.requests:
		var params: Dictionary = (r["ctx"] as Dictionary).get("params", {})
		if r["id"] == &"charger":
			charger_n += 1
			# The resolved bag == def params + EXACTLY the two D-RAT-2 overrides.
			var want: Dictionary = charger_def.params.duplicate(true)
			want["throwable_while_charging"] = false
			want["wall_crash_recover_mult"] = 2.0
			if params != want:
				failures.append("(c) charger resolved params != def + D-RAT-2 overrides: %s"
					% str(params))
				break
		else:
			# Non-charger rows are untouched: resolved bag == the def's authored bag.
			var d := load("res://data/oppositions/%s.tres" % String(r["id"])) as OppositionDef
			if d != null and params != d.params:
				failures.append("(c) non-charger deck row '%s' params drifted from its def: %s"
					% [str(r["id"]), str(params)])
	if charger_n < 1:
		failures.append("(c) band_two populate produced no charger instructions (override unproven)")
	_free_fake(svc)

	# rc still wins ON TOP of the wrapper on the real data.
	var rc_top := RunConfig.new()
	rc_top.param_overrides = { "charger": { "wall_crash_recover_mult": 5.0 } }
	var svc2 := _fresh_fake(rc_top, Vector2.INF)
	EncounterBuilder.new().populate(band, profile, rc_top, svc2)
	var checked := false
	for r in svc2.requests:
		if r["id"] != &"charger":
			continue
		checked = true
		var params: Dictionary = (r["ctx"] as Dictionary).get("params", {})
		if float(params.get("wall_crash_recover_mult", 0.0)) != 5.0:
			failures.append("(c) rc.param_overrides did not win over the DeckEntry: %s"
				% str(params.get("wall_crash_recover_mult")))
		if params.get("throwable_while_charging", true) != false:
			failures.append("(c) untouched DeckEntry override lost when rc overlaid another key")
		break
	if not checked:
		failures.append("(c) rc-on-top pass produced no charger instructions")
	_free_fake(svc2)
	_free_band(band)


# --- (d) mixed plain/wrapper decks ------------------------------------------------

func _case_mixed_array(failures: Array[String]) -> void:
	var a := _make_def(&"synth_a", 1, 0, 1, 0.0)
	var b := _make_def(&"synth_b", 1, 0, 1, 0.0)
	var c := _make_def(&"synth_c", 1, 0, 1, 0.0)
	var band := _make_band([16, 64])
	var rc := RunConfig.new()

	# Interleaved: order preserved per piece (a, b, c); only b carries the override.
	var deck: Array[Resource] = [a, _wrap(b, { "marker": 9 }), c]
	var svc := _fresh_fake(rc, Vector2.INF)
	EncounterBuilder.new().populate(band, _res_deck_profile(deck, 1), rc, svc)
	if svc.requests.size() != 3:
		failures.append("(d) mixed deck spawned %d, expected 3 (one per row on the eligible piece)"
			% svc.requests.size())
	else:
		var ids: Array = [svc.requests[0]["id"], svc.requests[1]["id"], svc.requests[2]["id"]]
		if ids != [&"synth_a", &"synth_b", &"synth_c"]:
			failures.append("(d) mixed deck order not preserved: %s" % str(ids))
		for r in svc.requests:
			var params: Dictionary = (r["ctx"] as Dictionary).get("params", {})
			var has_marker := params.has("marker")
			if r["id"] == &"synth_b" and (not has_marker or int(params["marker"]) != 9):
				failures.append("(d) wrapped row lost its override in the mix")
			elif r["id"] != &"synth_b" and has_marker:
				failures.append("(d) override leaked from the wrapper onto plain row %s" % str(r["id"]))
	_free_fake(svc)

	# Dedup stays FIRST-wins including overrides: a plain first row shadows a later
	# wrapper of the same id (no override applies)…
	var svc2 := _fresh_fake(rc, Vector2.INF)
	var dupe_late: Array[Resource] = [a, _wrap(_make_def(&"synth_a", 1, 0, 9, 0.0), { "marker": 1 })]
	EncounterBuilder.new().populate(band, _res_deck_profile(dupe_late, 1), rc, svc2)
	if svc2.requests.size() != 1:
		failures.append("(d) plain-then-wrapper dupe drew %d, expected 1 (first card n=1)"
			% svc2.requests.size())
	elif ((svc2.requests[0]["ctx"] as Dictionary).get("params", {}) as Dictionary).has("marker"):
		failures.append("(d) a DEDUPED later wrapper's overrides applied — first-wins broken")
	_free_fake(svc2)

	# …and a wrapper first row keeps its overrides against a later plain dupe.
	var svc3 := _fresh_fake(rc, Vector2.INF)
	var dupe_early: Array[Resource] = [_wrap(a, { "marker": 2 }), _make_def(&"synth_a", 1, 0, 9, 0.0)]
	EncounterBuilder.new().populate(band, _res_deck_profile(dupe_early, 1), rc, svc3)
	if svc3.requests.size() != 1:
		failures.append("(d) wrapper-then-plain dupe drew %d, expected 1" % svc3.requests.size())
	elif int((((svc3.requests[0]["ctx"] as Dictionary).get("params", {})) as Dictionary).get("marker", -1)) != 2:
		failures.append("(d) first wrapper's overrides lost to a later plain dupe")
	_free_fake(svc3)

	# Broken wrapper (null def): fail-loud + skipped; the rest of the deck survives.
	var svc4 := _fresh_fake(rc, Vector2.INF)
	var broken: Array[Resource] = [DeckEntry.new(), b]
	EncounterBuilder.new().populate(band, _res_deck_profile(broken, 1), rc, svc4)
	if svc4.requests.size() != 1 or svc4.requests[0]["id"] != &"synth_b":
		failures.append("(d) broken wrapper derailed the deck: %d requests" % svc4.requests.size())
	_free_fake(svc4)


# --- (e) fp guards ------------------------------------------------------------------

func _case_fp_guards(failures: Array[String]) -> void:
	var greybox := load(GREYBOX_PATH) as BandProfile
	if greybox == null:
		failures.append("(e) could not load band_greybox.tres")
		return
	var all_off := RunConfig.new()
	if not EncounterBuilder.new().is_inert(greybox, all_off):
		failures.append("(e) all-off + band_greybox is not inert")
	var control := BandPipeline.new().generate(greybox, 12345, all_off)
	if control == null or control.fingerprint().substr(0, 12) != BASELINE_FP:
		failures.append("(e) all-off pipeline fp is %s, expected %s (baseline moved!)"
			% [control.fingerprint().substr(0, 12) if control != null else "null", BASELINE_FP])
	_free_band(control)

	# Layout determinism on the rewrapped band_two (fps are layout-only; the deck
	# rewrap must not perturb generation).
	var band_two := load(BAND_TWO_PATH) as BandProfile
	if band_two == null:
		failures.append("(e) could not load band_two.tres")
		return
	var b1 := BandPipeline.new().generate(band_two, 99999)
	var b2 := BandPipeline.new().generate(band_two, 99999)
	if b1 == null or b2 == null or b1.fingerprint() != b2.fingerprint():
		failures.append("(e) band_two generation not deterministic after the S9 rewrap")
	_free_band(b1)
	_free_band(b2)


# --- harness plumbing -----------------------------------------------------------

func _wrap(def: OppositionDef, overrides: Dictionary) -> DeckEntry:
	var e := DeckEntry.new()
	e.def = def
	e.param_overrides = overrides
	return e


func _fresh_fake(rc: RunConfig, entry_pos: Vector2) -> FakeSpawnService:
	var svc := FakeSpawnService.new()
	var container := Node2D.new()
	add_child(container)
	svc.begin_band(container, CELL, entry_pos, rc)
	svc.set_cap_group(&"new_hazards", SpawnService.NEW_HAZARD_BAND_CEILING)
	return svc


func _free_fake(svc: FakeSpawnService) -> void:
	svc.cleanup()
	var container: Node2D = svc._container
	if container != null and is_instance_valid(container):
		remove_child(container)
		container.free()
	svc.free()


func _deck_profile(deck: Array, depth: int) -> BandProfile:
	var res_deck: Array[Resource] = []
	for d in deck:
		res_deck.append(d as Resource)
	return _res_deck_profile(res_deck, depth)


func _res_deck_profile(deck: Array[Resource], depth: int) -> BandProfile:
	var p := BandProfile.new()
	p.id = &"synthetic_deck"
	p.band_depth = depth
	p.opposition_deck = deck
	return p


func _make_def(id: StringName, cost: int, min_band: int, base: int, per_depth: float) -> OppositionDef:
	var d := OppositionDef.new()
	d.id = id
	d.credit_cost = cost
	d.min_band = min_band
	d.params = { "base_count": base, "count_per_depth": per_depth }
	var scene := PackedScene.new()
	var root := Node2D.new()
	root.name = "Stub"
	scene.pack(root)
	root.free()
	d.host_scene = scene
	return d


## A graded linear band (test_encounter_builder's shape): piece at depth d has
## areas[d] floor cells in a contiguous block at x base d*100.
func _make_band(areas: Array) -> Band:
	var band := Band.new()
	var max_depth: int = areas.size() - 1
	for d in areas.size():
		var area: int = areas[d]
		var p := PlacedPiece.new()
		p.piece_id = StringName("piece_room_%d" % d)
		p.offset_cell = Vector2i(d * 100, 0)
		p.depth_index = d
		p.depth_norm = float(d) / float(max_depth) if max_depth > 0 else 0.0
		var cells: Array[Vector2i] = []
		for k in area:
			cells.append(Vector2i(d * 100 + (k % 20), k / 20))
		p.floor_cells = cells
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
