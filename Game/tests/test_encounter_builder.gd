extends Node
## Headless acceptance test for S3 (M1.9) — EncounterBuilder policy extraction +
## RunConfig generic levers + the band-pipeline call-site switch.
##
## Run as a SCENE (autoloads + a live tree):
##   godot --headless --path Game res://tests/test_encounter_builder.tscn
##
## A FakeSpawnService (extends SpawnService, overrides spawn() only) records the ordered
## (def_id, cell, ctx) requests the builder issues — every case is PLAN-level and fast,
## no entity instantiation. The fake inherits the REAL begin_band/valid_cells, so the
## BUG7 filter-then-stride sequence is exercised exactly as in production (§7.2 Q1
## harness note (ii): the fake is armed with the same entry_pos/cell size the mirror
## math uses).
##
## Asserts (spec §3.5 cases 1-8 + the Q6(iv) pipeline-swap DoD):
##   (1) all-off + empty-deck profile → ZERO requests; is_inert() true.
##   (2) PRESET BYTE-PARITY (the acceptance bar, §7.2 Q1): the builder's ordered
##       (def_id, cell, ctx) plan equals a VERBATIM in-test mirror of the pre-S3
##       main_game math (same cells, same counts, same initial_dir fan keyed on the
##       cross-type accumulator, same phase_salts, same order) — and is refusal-free.
##   (3) fair-share + starvation: demand > 48 across 3 types → 16/16/16 slices;
##       deepest pieces starved first within a type; 2-type case → 24/24.
##   (4) deck budget math: budget = floor(BASE_CREDITS * instability(depth)); spending
##       stops exactly at exhaustion; a REFUSED spawn does not decrement the budget.
##   (5) min_band gating off profile.band_depth (amendment 10).
##   (6) deterministic draw order: same (band, deck, rc) twice → identical ordered
##       request lists; deck order = authored array order, id-deduped (first wins).
##   (7) levers: oppositions_enabled seeds the deck machinery on a deck-less band;
##       param_overrides reaches the count math + the ctx "params" merge; the authored
##       (neutral) card alone spawns nothing; empty levers are perfectly neutral.
##   (8) caps-in-service respected: a refusing service degrades the plan without error
##       and the builder never bypasses it.
##   (9) Q6(iv): BandPipeline's lvl_enabled ext-catalog swap byte-matches the direct
##       generator on piece_catalog_ext; all-off through the pipeline pins e943ac9c8bc1.
##  (10) instability(): band 1 = exactly 1.0 (parity clean); band 2 = 1.15.

const CELL := 16
const CEILING := 48                              # independent mirror of the K5 ceiling
const GOLDEN := 2.39996322972865332              # independent mirror of the golden angle
const SAFE_CELLS := 2.5                          # independent mirror of the BUG7 radius
const BASELINE_FP := "e943ac9c8bc1"

const PROFILE_PATH := "res://data/bands/band_greybox.tres"
const CATALOG_EXT_PATH := "res://data/piece_catalog_ext.tres"


## The policy-blind recording service: inherits the REAL arming + BUG7 validation;
## replaces only the mechanism (no instantiation). Configurable refusal so the caps-in-
## service contract (§3.5 case 8) is testable at plan level.
class FakeSpawnService:
	extends SpawnService
	var requests: Array[Dictionary] = []         # ordered successful (id, cell, ctx)
	var refusals: Array[Dictionary] = []
	var refuse_ids: Dictionary = {}              # def_id -> true → always refuse
	var limits: Dictionary = {}                  # def_id -> max successes (fake per-band cap)
	var _ok_counts: Dictionary = {}
	var _stub_nodes: Array[Node] = []

	func spawn(def: OppositionDef, cell: Vector2i, ctx: Dictionary = {}) -> Node:
		var ok := true
		if refuse_ids.has(def.id):
			ok = false
		elif limits.has(def.id) and int(_ok_counts.get(def.id, 0)) >= int(limits[def.id]):
			ok = false
		else:
			var one: Array[Vector2i] = [cell]
			if valid_cells(one).size() != 1:     # the real BUG7 re-check
				ok = false
		if not ok:
			refusals.append({ "id": def.id, "cell": cell })
			return null
		requests.append({ "id": def.id, "cell": cell, "ctx": ctx })
		_ok_counts[def.id] = int(_ok_counts.get(def.id, 0)) + 1
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

	_case_all_off(failures)
	_case_preset_parity(failures)
	_case_fair_share(failures)
	_case_budget(failures)
	_case_min_band(failures)
	_case_draw_order(failures)
	_case_levers(failures)
	_case_service_caps(failures)
	_case_pipeline_swap(failures)
	_case_instability(failures)

	if failures.is_empty():
		print("S3 OK — EncounterBuilder verified: all-off inert (zero requests), preset "
			+ "byte-parity vs the pre-S3 mirror (cells + ctx + order, refusal-free), "
			+ "fair-share 16/16/16 + 24/24 with deepest-first starvation, deck budget "
			+ "floor(24*I) with refusals not spending, min_band gating off "
			+ "profile.band_depth, deterministic id-deduped authored-order draw, "
			+ "oppositions_enabled/param_overrides additive + neutral-when-empty, "
			+ "service caps respected, pipeline lvl ext-swap byte-exact + all-off fp "
			+ BASELINE_FP + " pinned, instability(1)=1.0/instability(2)=1.15.")
		return 0
	for f in failures:
		printerr("S3 FAIL: ", f)
	return 1


# --- (1) all-off → zero requests -------------------------------------------------

func _case_all_off(failures: Array[String]) -> void:
	var rc := RunConfig.new()
	var profile := _empty_profile(1)
	var builder := EncounterBuilder.new()
	if not builder.is_inert(profile, rc):
		failures.append("(1) is_inert() false on the all-off control")
	var svc := _fresh_fake(rc, Vector2.INF)
	builder.populate(_make_band([16, 16, 16]), profile, rc, svc)
	if not svc.requests.is_empty():
		failures.append("(1) all-off produced %d requests, expected 0" % svc.requests.size())
	if not svc.refusals.is_empty():
		failures.append("(1) all-off produced refusals")
	_free_fake(svc)
	if builder.is_inert(profile, RunConfig.make_default_play_preset()):
		failures.append("(1) is_inert() true on the default play preset")


# --- (2) preset byte-parity vs the verbatim pre-S3 mirror -------------------------

func _case_preset_parity(failures: Array[String]) -> void:
	var rc := RunConfig.make_default_play_preset()
	# A band shaped like the real preset's (~15 depths): the hpp/hbomb per-depth ramps
	# (0.15) only produce a first instance at depth >= 7, so the band must be DEEP
	# enough that all three preset kinds actually spawn (the m14 >=1-of-each floor).
	var band := _make_band([16, 25, 36, 49, 64, 100, 120,
		64, 81, 100, 64, 81, 100, 64, 81])
	var entry_pos := _entry_pos(band)
	var svc := _fresh_fake(rc, entry_pos)
	EncounterBuilder.new().populate(band, _empty_profile(1), rc, svc)
	var mirror := _mirror_legacy_plan(rc, band, entry_pos)
	if svc.requests.is_empty():
		failures.append("(2) preset produced no requests (test mis-set)")
	if not svc.refusals.is_empty():
		failures.append("(2) preset plan was NOT refusal-free (%d refusals)" % svc.refusals.size())
	if svc.requests.size() != mirror.size():
		failures.append("(2) plan size %d != mirror size %d" % [svc.requests.size(), mirror.size()])
	else:
		for i in mirror.size():
			var got: Dictionary = svc.requests[i]
			var want: Dictionary = mirror[i]
			if got["id"] != want["id"] or got["cell"] != want["cell"] or got["ctx"] != want["ctx"]:
				failures.append("(2) plan diverges from the pre-S3 mirror at index %d: got %s expected %s"
					% [i, str(got), str(want)])
				break
	# Every preset kind actually appears (the m14-style >=1-of-each floor).
	for kind: StringName in [&"pingpong", &"bomb", &"spike"]:
		if _count_id(svc.requests, kind) < 1:
			failures.append("(2) preset plan spawned 0 of %s" % kind)
	_free_fake(svc)


# --- (3) fair-share + starvation ---------------------------------------------------

func _case_fair_share(failures: Array[String]) -> void:
	# Demand >> 48 across all three types, uncapped per-room → 16/16/16.
	var rc := RunConfig.new()
	rc.hpp_enabled = true
	rc.hpp_base_count = 50
	rc.hbomb_enabled = true
	rc.hbomb_base_count = 50
	rc.hspike_enabled = true
	rc.hspike_base_count = 50
	var band := _make_band([16, 100, 100])
	var svc := _fresh_fake(rc, Vector2.INF)
	EncounterBuilder.new().populate(band, _empty_profile(1), rc, svc)
	if svc.requests.size() != CEILING:
		failures.append("(3) saturated demand spawned %d, expected the %d ceiling"
			% [svc.requests.size(), CEILING])
	for kind: StringName in [&"pingpong", &"bomb", &"spike"]:
		if _count_id(svc.requests, kind) != 16:
			failures.append("(3) %s got %d of the fair share, expected 16"
				% [kind, _count_id(svc.requests, kind)])
	# Starvation is shallow-first fill: with a 50-demand in the depth-1 room, the slice
	# is exhausted there — the DEEPEST room gets nothing (deepest starved first).
	for r in svc.requests:
		if int((r["cell"] as Vector2i).x) >= 200:
			failures.append("(3) a request landed in the deepest room — starvation should bite deepest-first")
			break
	_free_fake(svc)

	# 2-type case → 24/24.
	var rc2 := RunConfig.new()
	rc2.hpp_enabled = true
	rc2.hpp_base_count = 50
	rc2.hbomb_enabled = true
	rc2.hbomb_base_count = 50
	var svc2 := _fresh_fake(rc2, Vector2.INF)
	EncounterBuilder.new().populate(_make_band([16, 100, 100]), _empty_profile(1), rc2, svc2)
	if _count_id(svc2.requests, &"pingpong") != 24 or _count_id(svc2.requests, &"bomb") != 24:
		failures.append("(3) 2-type split %d/%d, expected 24/24"
			% [_count_id(svc2.requests, &"pingpong"), _count_id(svc2.requests, &"bomb")])
	_free_fake(svc2)


# --- (4) deck budget math ------------------------------------------------------------

func _case_budget(failures: Array[String]) -> void:
	# band_depth 2 → I = 1.15 → budget = floor(24 * 1.15) = 27. One def, cost 5,
	# demand 10 in one deep room → exactly 5 spawns (25 spent; 2 left < 5).
	var def_a := _make_def(&"synth_a", 5, 0, 10, 0.0)
	var profile := _deck_profile([def_a], 2)
	var rc := RunConfig.new()
	var band := _make_band([16, 400])
	var svc := _fresh_fake(rc, Vector2.INF)
	EncounterBuilder.new().populate(band, profile, rc, svc)
	if svc.requests.size() != 5:
		failures.append("(4) budget 27 / cost 5 spawned %d, expected exactly 5" % svc.requests.size())
	_free_fake(svc)

	# A refused spawn must NOT decrement the budget: refuse def_a entirely; def_b
	# (also cost 5) must still afford its full 5 — not fewer.
	var def_b := _make_def(&"synth_b", 5, 0, 10, 0.0)
	var profile2 := _deck_profile([def_a, def_b], 2)
	var svc2 := _fresh_fake(rc, Vector2.INF)
	svc2.refuse_ids[&"synth_a"] = true
	EncounterBuilder.new().populate(band, profile2, rc, svc2)
	if _count_id(svc2.requests, &"synth_a") != 0:
		failures.append("(4) refused def still recorded successes")
	if _count_id(svc2.requests, &"synth_b") != 5:
		failures.append("(4) refusals leaked budget: synth_b got %d, expected 5 (refusal must not spend)"
			% _count_id(svc2.requests, &"synth_b"))
	_free_fake(svc2)

	# Mixed costs never overspend the pool.
	var mixed: Array[OppositionDef] = [
		_make_def(&"synth_c1", 1, 0, 4, 0.0),
		_make_def(&"synth_c2", 2, 0, 4, 0.0),
		_make_def(&"synth_c5", 5, 0, 4, 0.0),
	]
	var svc3 := _fresh_fake(rc, Vector2.INF)
	EncounterBuilder.new().populate(band, _deck_profile(mixed, 2), rc, svc3)
	var spent := 0
	for r in svc3.requests:
		match r["id"]:
			&"synth_c1": spent += 1
			&"synth_c2": spent += 2
			&"synth_c5": spent += 5
	if spent > 27:
		failures.append("(4) mixed-cost deck overspent the 27-credit pool (%d)" % spent)
	_free_fake(svc3)


# --- (5) min_band gating ---------------------------------------------------------------

func _case_min_band(failures: Array[String]) -> void:
	var gated := _make_def(&"synth_gated", 1, 2, 2, 0.0)
	var rc := RunConfig.new()
	var band := _make_band([16, 100])
	var svc1 := _fresh_fake(rc, Vector2.INF)
	EncounterBuilder.new().populate(band, _deck_profile([gated], 1), rc, svc1)
	if not svc1.requests.is_empty():
		failures.append("(5) min_band=2 def spawned at band_depth 1")
	_free_fake(svc1)
	var svc2 := _fresh_fake(rc, Vector2.INF)
	EncounterBuilder.new().populate(band, _deck_profile([gated], 2), rc, svc2)
	if svc2.requests.is_empty():
		failures.append("(5) min_band=2 def did NOT spawn at band_depth 2")
	_free_fake(svc2)


# --- (6) deterministic, id-deduped authored-order draw ---------------------------------

func _case_draw_order(failures: Array[String]) -> void:
	var a := _make_def(&"synth_a", 1, 0, 1, 0.0)
	var b := _make_def(&"synth_b", 1, 0, 1, 0.0)
	var a_dupe := _make_def(&"synth_a", 1, 0, 9, 0.0)   # same id, different card
	var profile := _deck_profile([a, b, a_dupe], 1)
	var rc := RunConfig.new()
	var band := _make_band([16, 64, 64])
	var svc1 := _fresh_fake(rc, Vector2.INF)
	EncounterBuilder.new().populate(band, profile, rc, svc1)
	var svc2 := _fresh_fake(rc, Vector2.INF)
	EncounterBuilder.new().populate(band, profile, rc, svc2)
	if svc1.requests.size() != svc2.requests.size():
		failures.append("(6) two identical populates differ in size")
	else:
		for i in svc1.requests.size():
			if svc1.requests[i] != svc2.requests[i]:
				failures.append("(6) two identical populates diverge at index %d" % i)
				break
	# Dedup: the duplicated id draws once per piece (first occurrence's card: n=1, not 9).
	# Per eligible piece the draw order is authored order: a, b.
	if svc1.requests.size() != 4:
		failures.append("(6) expected 4 requests (a,b per eligible room, dupe deduped), got %d"
			% svc1.requests.size())
	elif not (svc1.requests[0]["id"] == &"synth_a" and svc1.requests[1]["id"] == &"synth_b"):
		failures.append("(6) draw order is not the authored deck order (got %s, %s first)"
			% [str(svc1.requests[0]["id"]), str(svc1.requests[1]["id"])])
	_free_fake(svc1)
	_free_fake(svc2)


# --- (7) generic levers -----------------------------------------------------------------

func _case_levers(failures: Array[String]) -> void:
	var band := _make_band([16, 100])
	var profile := _empty_profile(1)

	# The authored spike card is NEUTRAL (S2 mirrors the all-off code defaults), so the
	# enable-list alone engages the lane but spawns nothing…
	var rc_list := RunConfig.new()
	rc_list.oppositions_enabled = [&"spike"]
	if EncounterBuilder.new().is_inert(profile, rc_list):
		failures.append("(7) is_inert() true with oppositions_enabled set")
	var svc1 := _fresh_fake(rc_list, Vector2.INF)
	EncounterBuilder.new().populate(band, profile, rc_list, svc1)
	if not svc1.requests.is_empty():
		failures.append("(7) neutral authored card spawned %d (expected 0 — card is all-off-mirrored)"
			% svc1.requests.size())
	_free_fake(svc1)

	# …and param_overrides re-tunes the def-driven card: base_count 1 → one spike per
	# eligible room via the deck machinery (band 1 extras budget = exactly BASE_CREDITS),
	# with the override visible in the ctx "params" merge.
	var rc_over := RunConfig.new()
	rc_over.oppositions_enabled = [&"spike"]
	rc_over.param_overrides = { "spike": { "base_count": 1 } }
	var svc2 := _fresh_fake(rc_over, Vector2.INF)
	EncounterBuilder.new().populate(band, profile, rc_over, svc2)
	if svc2.requests.size() != 1:
		failures.append("(7) extras + override expected 1 spike request, got %d" % svc2.requests.size())
	elif svc2.requests[0]["id"] != &"spike":
		failures.append("(7) extras request id is %s, expected spike" % str(svc2.requests[0]["id"]))
	else:
		var ctx: Dictionary = svc2.requests[0]["ctx"]
		var params: Dictionary = ctx.get("params", {})
		if int(params.get("base_count", -1)) != 1:
			failures.append("(7) param_overrides did not reach the ctx merge: params=%s" % str(params))
		if not ctx.has("room_key") or not ctx.has("depth"):
			failures.append("(7) deck-lane ctx missing the reserved keys: %s" % str(ctx))
	_free_fake(svc2)

	# Both levers empty = byte-identical to the plain plan (neutrality).
	var rc_a := RunConfig.make_default_play_preset()
	var rc_b := RunConfig.make_default_play_preset()
	rc_b.oppositions_enabled = []
	rc_b.param_overrides = {}
	var entry_pos := _entry_pos(band)
	var svc_a := _fresh_fake(rc_a, entry_pos)
	EncounterBuilder.new().populate(band, profile, rc_a, svc_a)
	var svc_b := _fresh_fake(rc_b, entry_pos)
	EncounterBuilder.new().populate(band, profile, rc_b, svc_b)
	if svc_a.requests != svc_b.requests:
		failures.append("(7) explicit empty levers changed the plan (must be perfectly neutral)")
	_free_fake(svc_a)
	_free_fake(svc_b)


# --- (8) caps-in-service respected --------------------------------------------------------

func _case_service_caps(failures: Array[String]) -> void:
	# The service refuses above a per-band cap of 3; the builder's demand is 8. The plan
	# degrades (3 successes), refusals are recorded, no error, no bypass.
	var d := _make_def(&"synth_capped", 1, 0, 8, 0.0)
	var rc := RunConfig.new()
	var svc := _fresh_fake(rc, Vector2.INF)
	svc.limits[&"synth_capped"] = 3
	EncounterBuilder.new().populate(_make_band([16, 400]), _deck_profile([d], 1), rc, svc)
	if _count_id(svc.requests, &"synth_capped") != 3:
		failures.append("(8) capped def got %d successes, expected the service's 3"
			% _count_id(svc.requests, &"synth_capped"))
	if svc.refusals.is_empty():
		failures.append("(8) no refusals recorded — the builder bypassed the service cap?")
	_free_fake(svc)


# --- (9) Q6(iv): the pipeline-owned lvl ext-catalog swap ------------------------------------

func _case_pipeline_swap(failures: Array[String]) -> void:
	var profile := load(PROFILE_PATH) as BandProfile
	if profile == null:
		failures.append("(9) could not load %s" % PROFILE_PATH)
		return
	var pipe := BandPipeline.new()

	# All-off through the pipeline pins the permanent control fp.
	var all_off := RunConfig.new()
	var control := pipe.generate(profile, 12345, all_off)
	if control == null or control.fingerprint().substr(0, 12) != BASELINE_FP:
		failures.append("(9) all-off pipeline fp is %s, expected %s"
			% [control.fingerprint().substr(0, 12) if control != null else "null", BASELINE_FP])

	# lvl_enabled → the pipeline swaps to profile.piece_pool_ext, byte-matching the
	# direct generator on the SAME extended catalog (the relocated I1 call-site swap).
	var lvl_on := RunConfig.new()
	lvl_on.lvl_enabled = true
	var piped := pipe.generate(profile, 12345, lvl_on)
	var ext := load(CATALOG_EXT_PATH) as PieceCatalog
	var direct := BandGenerator.new().generate(12345,
		profile.backend_config as BandGenConfig, ext.pieces, lvl_on)
	if piped == null or direct == null or piped.fingerprint() != direct.fingerprint():
		failures.append("(9) lvl-on pipeline fp != direct ext-catalog fp (swap not pipeline-owned?)")
	# Non-vacuous: the swap must actually change the band vs the baseline catalog.
	if piped != null and control != null and piped.fingerprint() == control.fingerprint():
		failures.append("(9) lvl-on band == all-off band — the ext swap never engaged")
	_free_band(control)
	_free_band(piped)
	_free_band(direct)


# --- (10) instability normalization ---------------------------------------------------------

func _case_instability(failures: Array[String]) -> void:
	if EncounterBuilder.instability(1) != 1.0:
		failures.append("(10) instability(1) == %f, expected exactly 1.0 (parity clean)"
			% EncounterBuilder.instability(1))
	if not is_equal_approx(EncounterBuilder.instability(2), 1.15):
		failures.append("(10) instability(2) == %f, expected 1.15" % EncounterBuilder.instability(2))


# --- the verbatim pre-S3 mirror (main_game._spawn_new_hazards @ 6fbded1, post-S0 shape) ----

## Independent re-implementation of the OLD policy math — kept deliberately separate
## from EncounterBuilder so a faithful relocation and a drifted one are distinguishable
## (extends the test_rg1_m14_verify count mirror to cells + ctx, per §7.2 Q1).
func _mirror_legacy_plan(rc: RunConfig, band: Band, entry_pos: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var defs := {
		&"pingpong": load("res://data/oppositions/pingpong.tres") as OppositionDef,
		&"bomb": load("res://data/oppositions/bomb.tres") as OppositionDef,
		&"spike": load("res://data/oppositions/spike.tres") as OppositionDef,
	}
	var table := [
		[&"pingpong", rc.hpp_enabled, rc.hpp_base_count, rc.hpp_count_per_depth, rc.hpp_per_room_cap],
		[&"bomb", rc.hbomb_enabled, rc.hbomb_base_count, rc.hbomb_count_per_depth, rc.hbomb_per_room_cap],
		[&"spike", rc.hspike_enabled, rc.hspike_base_count, rc.hspike_count_per_depth, rc.hspike_per_room_cap],
	]
	var active: Array = []
	for row: Array in table:
		if not row[1]:
			continue
		if int(row[2]) <= 0 and float(row[3]) <= 0.0:
			continue
		if defs[row[0]] == null:
			continue
		active.append(row)
	if active.is_empty():
		return out
	var n_active: int = active.size()
	var base_share: int = CEILING / n_active
	var remainder: int = CEILING % n_active
	var spawned_total := 0
	var pieces := _pieces_sorted(band)
	var safe_px := SAFE_CELLS * float(CELL)
	for ti in n_active:
		if spawned_total >= CEILING:
			break
		var row: Array = active[ti]
		var kind: StringName = row[0]
		var type_budget: int = base_share + (1 if ti < remainder else 0)
		var type_spawned := 0
		for p in pieces:
			if spawned_total >= CEILING:
				break
			if type_spawned >= type_budget:
				break
			var depth: int = p.depth_index
			if depth <= 0:
				continue
			var n: int = int(row[2]) + int(floor(float(row[3]) * float(depth)))
			if int(row[4]) > 0:
				n = mini(n, int(row[4]))
			n = mini(n, type_budget - type_spawned)
			n = mini(n, CEILING - spawned_total)
			if n <= 0:
				continue
			# BUG7 filter BEFORE stride (the load-bearing sequence point).
			var cells: Array[Vector2i] = []
			for c in _cells_sorted(p):
				if entry_pos == Vector2.INF or _cell_world(c).distance_to(entry_pos) >= safe_px:
					cells.append(c)
			if cells.is_empty():
				continue
			var bounds := Rect2(_cell_world(cells[0]), Vector2.ZERO)
			for c in cells:
				bounds = bounds.expand(_cell_world(c))
			var stride: int = maxi(cells.size() / maxi(n, 1), 1)
			for k in n:
				var cell: Vector2i = cells[(k * stride) % cells.size()]
				var ctx: Dictionary = {}
				match kind:
					&"pingpong":
						ctx = { "initial_dir": Vector2.from_angle(float(spawned_total) * GOLDEN),
							"room_bounds": bounds }
					&"spike":
						ctx = { "phase_salt": p.depth_index * 131 + k }
					_:
						ctx = {}
				ctx["depth"] = p.depth_index
				ctx["run_t_ms"] = 0
				out.append({ "id": kind, "cell": cell, "ctx": ctx })
				spawned_total += 1
				type_spawned += 1
	return out


func _pieces_sorted(band: Band) -> Array[PlacedPiece]:
	var pieces: Array[PlacedPiece] = []
	for p in band.pieces:
		if p.depth_index < 0:
			continue
		pieces.append(p)
	pieces.sort_custom(func(a: PlacedPiece, b: PlacedPiece) -> bool:
		if a.depth_index != b.depth_index:
			return a.depth_index < b.depth_index
		if a.offset_cell.y != b.offset_cell.y:
			return a.offset_cell.y < b.offset_cell.y
		return a.offset_cell.x < b.offset_cell.x)
	return pieces


func _cells_sorted(p: PlacedPiece) -> Array[Vector2i]:
	var cells: Array[Vector2i] = p.floor_cells.duplicate()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	return cells


func _cell_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * CELL) + Vector2(CELL, CELL) * 0.5


# --- harness plumbing ------------------------------------------------------------------

## An armed fake: real begin_band (container + CELL + entry exclusion + cfg), fake spawn.
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


func _empty_profile(depth: int) -> BandProfile:
	var p := BandProfile.new()
	p.id = &"synthetic_empty"
	p.band_depth = depth
	return p


func _deck_profile(deck: Array[OppositionDef], depth: int) -> BandProfile:
	var p := BandProfile.new()
	p.id = &"synthetic_deck"
	p.band_depth = depth
	var res_deck: Array[Resource] = []
	for d in deck:
		res_deck.append(d)
	p.opposition_deck = res_deck
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


func _count_id(requests: Array[Dictionary], id: StringName) -> int:
	var n := 0
	for r in requests:
		if r["id"] == id:
			n += 1
	return n


## A graded linear band, mirroring test_new_hazard_spawn._make_band: piece at depth d
## has areas[d] floor cells in a contiguous block at x base d*100.
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


func _entry_pos(band: Band) -> Vector2:
	var cell: Vector2i = band.entry_piece.floor_cells[0]
	return Vector2(cell * CELL) + Vector2(CELL, CELL) * 0.5


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
