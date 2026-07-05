extends Node
## Headless verification for T2a (M1.10 Wave 1) — the Ambusher ("The Lurker"): the
## TG3 scalability proof (ambusher.tres + the ONE new Concealment component; the pounce
## is the REUSED S6a ChargeLane, everything else reused from the S2 set).
##
## Runs as a headless SCENE (test_ambusher.tscn) so the EventBus / GameState autoloads
## resolve via the live SceneTree. Instantiates AmbusherHazard from ambusher.tscn,
## setup()s it with a stub player + a spawn_ctx "params" bag (the deck lane's ctx-merge
## shape), and advances REAL physics frames so ChargeLane's host-ticked pounce FSM and
## move_and_slide run as in-game.
##
## Asserts the T2a DoD (spec §3 + Resolved Decisions, BINDING):
##  (1) def contract: ambusher.tres loads; id &"ambusher"; the card (min_band=3,
##      credit_cost=2, per_room_cap=2, per_band_cap=6); entity params mirror
##      AmbusherHazard.DEFAULTS exactly (no code/data drift); host contract (root class
##      AmbusherHazard + node name "Ambusher", &"hazard" group at author time, get_def_id/
##      resolve_throw_death seams); $Body/$Tell/$FloorTell triangulate (invisible-blade).
##  (2) all-off gate: &"ambusher" is in neither RunConfig.new().oppositions_enabled nor
##      the default play preset nor band_greybox's deck; the all-off pipeline fingerprint
##      e943a… is untouched (the permanent control).
##  (a) HIDDEN = non-lethal + un-hittable: arm_radius 0 (inert) with the player on it
##      never ends the run; is_hittable() false; collision_layer == 0 (clean pass-through
##      — a thrown item flies through, no kill, Ambusher survives); body.modulate.a ==
##      concealed_alpha; $FloorTell.a > 0.
##  (b) arm radius: player inside arm_radius → HIDDEN→ARMED (reveal: $Body.a==1.0, in
##      "hazard" group, collision_layer==16); arm_radius 0 → permanently inert.
##  (c) tell precedes pounce by the authored lead: ARMED (TELEGRAPH) holds ~tell_lead_s
##      before POUNCE (CHARGE); exactly one &"telegraph" row.
##  (d) lane lock: a perpendicular step AFTER arming dodges the locked lunge lane.
##  (e) pounce kill gated by kills: kills=true on-lane → fail_run(&"death") + gated
##      opposition_killed_player(&"ambusher") EXACTLY once (BUG6) + &"hit_player";
##      kills=false → &"hit_player" fires but the run stays active, no killed row.
##  (f) EXPOSED throw-killable: during EXPOSED (post-pounce) a thrown item kills the
##      Ambusher (throw_killed_hazard/&"killed_by_throw" kind &"ambusher", queue_free).
##  (g) one-shot: after a full pounce→exposed cycle with re_hide_s=0 the Ambusher is
##      SPENT — re-entering arm_radius does NOT re-arm (no 2nd &"telegraph"); is_hittable()
##      false. With re_hide_s>0 it re-hides and CAN re-arm on a later entry.
##  (h) deterministic placement: the same synthetic band + deck twice through the REAL
##      EncounterBuilder + SpawnService yields identical Ambusher spawn cells; per_band_cap
##      binds; min_band=3 refuses a band-depth-2 profile entirely.
##  (i) RNG-free: concealment.gd + ambusher_hazard.gd contain no global RNG reference.
##  (j) tells render: $Body, $Tell, $FloorTell triangulate to >0 triangles.
## Run: godot --headless --path Game res://tests/test_ambusher.tscn

const AMBUSHER_SCENE := "res://scenes/hazards/ambusher.tscn"
const AMBUSHER_DEF := "res://data/oppositions/ambusher.tres"
const THROWN_SCENE := "res://entities/thrown_item/thrown_item.tscn"
const PROFILE_PATH := "res://data/bands/band_greybox.tres"
const BASELINE_FP := "e943ac9c8bc1"
const CELL := 16

var _opp_events: Array = []                    # [id, event] pairs per opposition_event
var _opp_killed: Array[StringName] = []        # id per opposition_killed_player
var _killed_kinds: Array[StringName] = []      # kind per new_hazard_killed
var _run_ended_reasons: Array[StringName] = []
var _throw_kills: Array[StringName] = []       # kind per throw_killed_hazard
var _throw_misses: int = 0
var _junk_drops: int = 0


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: Array[String] = []

	var gs := get_node_or_null("/root/GameState")
	var eb := get_node_or_null("/root/EventBus")
	if gs == null or eb == null:
		printerr("AMBUSHER FAIL: GameState/EventBus autoload missing")
		get_tree().quit(1)
		return

	eb.opposition_event.connect(_on_opposition_event)
	eb.opposition_killed_player.connect(_on_opposition_killed)
	eb.new_hazard_killed.connect(_on_hazard_killed)
	eb.run_ended.connect(_on_run_ended)
	eb.throw_killed_hazard.connect(_on_throw_killed)
	eb.throw_missed.connect(_on_throw_missed)
	eb.junk_dropped.connect(_on_junk_dropped)

	_case_def_contract(failures)
	_case_all_off_gate(failures)
	await _case_hidden_inert(gs, failures)
	await _case_arm_radius(gs, failures)
	await _case_tell_lead(gs, failures)
	await _case_lane_lock(gs, failures)
	await _case_kills_gate(gs, failures)
	await _case_exposed_throw(gs, failures)
	await _case_one_shot(gs, failures)
	_case_rng_free(failures)
	_case_deterministic_placement(failures)

	if failures.is_empty():
		print("T2a OK — Ambusher verified: def card locked (min_band 3 / cost 2 / caps 2+6, "
			+ "params mirror DEFAULTS), all-off gate holds (fp " + BASELINE_FP + ", ambusher in "
			+ "no default lever/deck), HIDDEN is non-lethal + un-hittable (layer 0 clean "
			+ "pass-through), arm radius reveals + joins the hazard group, the tell precedes the "
			+ "pounce by the authored lead (exactly 1 telegraph row), the locked lunge lane is "
			+ "dodgeable, the L5 kills gate + BUG6 latch fire exactly once, the EXPOSED window is "
			+ "throw-killable, the pounce is ONE-SHOT (spent, never re-arms; re_hide_s re-arms), "
			+ "Concealment/host are RNG-free, and deck placement is deterministic with "
			+ "per_band_cap/min_band enforced by the real service.")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("AMBUSHER FAIL: ", f)
		get_tree().quit(1)


# === (1) def contract ==========================================================

func _case_def_contract(failures: Array[String]) -> void:
	var def := load(AMBUSHER_DEF) as OppositionDef
	if def == null:
		failures.append("(1) ambusher.tres does not load as OppositionDef")
		return
	if def.id != &"ambusher":
		failures.append("(1) def id %s != &\"ambusher\"" % def.id)
	if def.min_band != 3:
		failures.append("(1) min_band %d != 3 (band-3 hard gate, OQ-9)" % def.min_band)
	if def.credit_cost != 2:
		failures.append("(1) credit_cost %d != 2" % def.credit_cost)
	if def.per_room_cap != 2:
		failures.append("(1) per_room_cap %d != 2" % def.per_room_cap)
	if def.per_band_cap != 6:
		failures.append("(1) per_band_cap %d != 6" % def.per_band_cap)
	if not def.kills:
		failures.append("(1) typed kills field is false (ships lethal, OQ-3)")
	if not bool(def.params.get("kills", false)):
		failures.append("(1) def default params.kills != true")
	# Entity-read params mirror the host's code fallbacks exactly (no drift).
	for key: String in AmbusherHazard.DEFAULTS:
		if not def.params.has(key):
			failures.append("(1) def params missing entity key '%s'" % key)
		elif def.params[key] != AmbusherHazard.DEFAULTS[key]:
			failures.append("(1) def params['%s'] = %s != AmbusherHazard.DEFAULTS %s"
				% [key, str(def.params[key]), str(AmbusherHazard.DEFAULTS[key])])
	# Only the builder-read spawn-card keys may exist beyond the entity keys.
	for k: Variant in def.params.keys():
		var ks := String(k)
		if not AmbusherHazard.DEFAULTS.has(ks) and ks != "base_count" and ks != "count_per_depth":
			failures.append("(1) unexpected def param '%s' (not entity-read, not spawn-card)" % ks)
	# Host contract: root class/name/group + the S2 seams.
	var root := def.host_scene.instantiate()
	if root == null:
		failures.append("(1) host_scene does not instantiate")
		return
	var script: Script = root.get_script()
	if script == null or String(script.get_global_name()) != "AmbusherHazard":
		failures.append("(1) host root class != AmbusherHazard")
	if String(root.name) != "Ambusher":
		failures.append("(1) host root node name '%s' != 'Ambusher' (§2.7 kind fallback)" % root.name)
	if not root.is_in_group(&"hazard"):
		failures.append("(1) host root not in the 'hazard' group at author time")
	if not root.has_method(&"resolve_throw_death") or not root.has_method(&"get_def_id"):
		failures.append("(1) host root missing the S2 throw/def-id seams")
	elif StringName(root.call(&"get_def_id")) != &"ambusher":
		failures.append("(1) get_def_id() != &\"ambusher\"")
	# (j) the placeholders must actually render (invisible-blade guard).
	for pname in ["Body", "Tell", "FloorTell"]:
		var poly: Polygon2D = root.get_node_or_null(pname)
		if poly == null:
			failures.append("(1/j) host has no %s polygon" % pname)
		elif Geometry2D.triangulate_polygon(poly.polygon).is_empty():
			failures.append("(1/j) %s triangulates to 0 triangles — renders NOTHING" % pname)
	root.free()


# === (2) all-off gate ==========================================================

func _case_all_off_gate(failures: Array[String]) -> void:
	if RunConfig.new().oppositions_enabled.has(&"ambusher"):
		failures.append("(2) all-off RunConfig lists &\"ambusher\" in oppositions_enabled")
	if RunConfig.make_default_play_preset().oppositions_enabled.has(&"ambusher"):
		failures.append("(2) the default play preset lists &\"ambusher\" (ships OFF)")
	var profile := load(PROFILE_PATH) as BandProfile
	if profile == null:
		failures.append("(2) could not load %s" % PROFILE_PATH)
		return
	for r in profile.opposition_deck:
		var d := r as OppositionDef
		if d != null and d.id == &"ambusher":
			failures.append("(2) band_greybox's deck lists the ambusher (band-3-exclusive)")
	if not EncounterBuilder.new().is_inert(profile, RunConfig.new()):
		failures.append("(2) all-off + band_greybox is not inert")
	var control := BandPipeline.new().generate(profile, 12345, RunConfig.new())
	if control == null or control.fingerprint().substr(0, 12) != BASELINE_FP:
		failures.append("(2) all-off pipeline fp %s != %s (baseline moved!)"
			% [control.fingerprint().substr(0, 12) if control != null else "null", BASELINE_FP])
	if control != null:
		for p in control.pieces:
			if p.instance != null and is_instance_valid(p.instance):
				p.instance.free()


# === (a) HIDDEN non-lethal + un-hittable (layer-0 clean pass-through) ===========

func _case_hidden_inert(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 7001)
	gs.set_current_depth(3, 3)
	# arm_radius 0 → permanently inert (ProximityTrigger 0-gate); player standing ON it.
	var player := _make_player(Vector2.ZERO)
	var amb := _make_ambusher(Vector2.ZERO, player, _params({ "arm_radius": 0.0 }))
	await _frames(15)
	if amb.lane_state() != ChargeLane.State.DORMANT:
		failures.append("(a) arm_radius 0 ambusher woke up (0 must be inert)")
	if not gs.run_active or _count_events(&"ambusher", &"hit_player") != 0:
		failures.append("(a) a HIDDEN ambusher hurt the player standing on it")
	if amb.is_hittable():
		failures.append("(a) HIDDEN ambusher reports is_hittable() true")
	if amb.collision_layer != 0:
		failures.append("(a) HIDDEN ambusher collision_layer %d != 0 (pass-through, OQ-10)"
			% amb.collision_layer)
	var body: Polygon2D = amb.get_node_or_null("Body")
	var floor_tell: Polygon2D = amb.get_node_or_null("FloorTell")
	if body == null or not is_equal_approx(body.modulate.a, 0.0):
		failures.append("(a) HIDDEN body.modulate.a != concealed_alpha (0.0)")
	if floor_tell == null or floor_tell.modulate.a <= 0.0:
		failures.append("(a) HIDDEN floor tell not shown (a <= 0)")
	# A throw ACROSS the hidden ambusher passes clean through (layer 0 → no body_entered):
	# the item flies on to its own max-range miss, the ambusher is never killed.
	var item := _make_thrown(Vector2(-40, 0), Vector2.RIGHT, 300.0, 100.0)
	await _frames(20)
	if not is_instance_valid(amb):
		failures.append("(a) a throw across a HIDDEN ambusher killed/freed it (no pass-through)")
	if _throw_kills.has(&"ambusher"):
		failures.append("(a) throw across HIDDEN ambusher logged a kill row")
	if is_instance_valid(item):
		item.queue_free()
	amb.queue_free()
	player.queue_free()
	await _frames(1)


# === (b) arm radius reveals + joins the hazard group ===========================

func _case_arm_radius(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 7002)
	gs.set_current_depth(3, 3)
	var player := _make_player(Vector2(100, 0))
	var amb := _make_ambusher(Vector2.ZERO, player, _params({ "kills": false }))
	if await _await_state(amb, ChargeLane.State.TELEGRAPH, 5) < 0:
		failures.append("(b) player inside arm_radius never armed (HIDDEN→ARMED)")
	var body: Polygon2D = amb.get_node_or_null("Body")
	if body == null or not is_equal_approx(body.modulate.a, 1.0):
		failures.append("(b) ARMED body.modulate.a != 1.0 (did not reveal)")
	if not amb.is_in_group(&"hazard") or not amb.is_hittable():
		failures.append("(b) ARMED ambusher not in the 'hazard' group (not throw-killable)")
	if amb.collision_layer != 16:
		failures.append("(b) ARMED ambusher collision_layer %d != 16 (solid target)" % amb.collision_layer)
	amb.queue_free()
	player.queue_free()
	await _frames(1)


# === (c) tell precedes the pounce by the authored lead =========================

func _case_tell_lead(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 7003)
	gs.set_current_depth(3, 3)
	var player := _make_player(Vector2(100, 0))
	var amb := _make_ambusher(Vector2.ZERO, player, _params({ "kills": false }))
	if await _await_state(amb, ChargeLane.State.TELEGRAPH, 5) < 0:
		failures.append("(c) never entered ARMED")
	# tell_lead_s 0.2 ≈ 12 frames @ 60Hz before the pounce.
	var to_pounce := await _await_state(amb, ChargeLane.State.CHARGE, 30)
	if to_pounce < 0:
		failures.append("(c) never pounced")
	elif to_pounce < 8 or to_pounce > 20:
		failures.append("(c) ARMED lasted %d frames, expected ~12 (0.2s tell_lead_s)" % to_pounce)
	if _count_events(&"ambusher", &"telegraph") != 1:
		failures.append("(c) expected exactly 1 telegraph row, got %d"
			% _count_events(&"ambusher", &"telegraph"))
	# S0-locked vocabulary only.
	for e: Array in _opp_events:
		if e[0] == &"ambusher" and not [&"telegraph", &"state", &"hit_player"].has(e[1]):
			failures.append("(c) out-of-vocabulary opposition_event '%s' (S0 locked set)" % e[1])
	amb.queue_free()
	player.queue_free()
	await _frames(1)


# === (d) lane lock: the shown lunge lane is dodgeable ==========================

func _case_lane_lock(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 7004)
	gs.set_current_depth(3, 3)
	var player := _make_player(Vector2(100, 0))
	var amb := _make_ambusher(Vector2.ZERO, player, _params({ "kills": true }))
	if await _await_state(amb, ChargeLane.State.TELEGRAPH, 5) < 0:
		failures.append("(d) never armed")
	player.global_position = Vector2(100, 90)   # perpendicular, well clear of the 28px corridor
	if await _await_state(amb, ChargeLane.State.RECOVER, 90) < 0:
		failures.append("(d) pounce never completed")
	if _count_events(&"ambusher", &"hit_player") != 0:
		failures.append("(d) a perpendicular dodge off the LOCKED lunge lane was still hit")
	if not gs.run_active:
		failures.append("(d) the dodged pounce ended the run")
	amb.queue_free()
	player.queue_free()
	await _frames(1)


# === (e) pounce kill gated by kills + BUG6 latch ===============================

func _case_kills_gate(gs: Node, failures: Array[String]) -> void:
	# kills=true, player stays on the lane → death, each channel exactly once.
	_reset_logs()
	gs.start_run(&"test_band", 7005)
	gs.set_current_depth(3, 3)
	var player := _make_player(Vector2(100, 0))
	var amb := _make_ambusher(Vector2.ZERO, player, _params({ "kills": true }))
	await _frames(45)   # telegraph (12) + pounce reach (~20) + margin
	if not _run_ended_reasons.has(&"death"):
		failures.append("(e) on-lane player was not killed via fail_run(&\"death\")")
	if gs.run_active:
		failures.append("(e) run still active after a fatal pounce")
	if _opp_killed.count(&"ambusher") != 1:
		failures.append("(e) opposition_killed_player(&\"ambusher\") fired %d times, expected exactly 1"
			% _opp_killed.count(&"ambusher"))
	if _count_events(&"ambusher", &"hit_player") != 1:
		failures.append("(e) hit_player rows %d, expected exactly 1 (BUG6 latch)"
			% _count_events(&"ambusher", &"hit_player"))
	amb.queue_free()
	player.queue_free()
	await _frames(1)

	# kills=false, same geometry → the contact row minus the gated pair; run survives.
	_reset_logs()
	gs.start_run(&"test_band", 7006)
	gs.set_current_depth(3, 3)
	var player2 := _make_player(Vector2(100, 0))
	var amb2 := _make_ambusher(Vector2.ZERO, player2, _params({ "kills": false }))
	await _frames(45)
	if _count_events(&"ambusher", &"hit_player") != 1:
		failures.append("(e) kills=false contact rows %d, expected exactly 1 (emit-always + latch)"
			% _count_events(&"ambusher", &"hit_player"))
	if not _opp_killed.is_empty():
		failures.append("(e) kills=false emitted opposition_killed_player (must be gated)")
	if _run_ended_reasons.has(&"death") or not gs.run_active:
		failures.append("(e) kills=false ended the run")
	amb2.queue_free()
	player2.queue_free()
	await _frames(1)


# === (f) EXPOSED window is throw-killable ======================================

func _case_exposed_throw(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 7007)
	gs.set_current_depth(3, 3)
	# Player parked far on +X so the locked lane is the x-axis; kills=false (the sweep
	# over the player is irrelevant here); a slow, long recover for a stable throw window.
	var player := _make_player(Vector2(200, 0))
	var amb := _make_ambusher(Vector2.ZERO, player,
		_params({ "kills": false, "arm_radius": 260.0, "lunge_speed": 200.0,
			"lunge_dist": 120.0, "exposed_window_s": 1.0 }))
	if await _await_state(amb, ChargeLane.State.RECOVER, 120) < 0:
		failures.append("(f) never reached the EXPOSED window")
	if not amb.is_in_group(&"hazard") or not amb.is_hittable():
		failures.append("(f) EXPOSED ambusher not throw-killable (not in the 'hazard' group)")
	var item := _make_thrown(amb.global_position, Vector2.RIGHT, 0.0, 0.0)  # parked ON it
	await _frames(10)
	if not _throw_kills.has(&"ambusher"):
		failures.append("(f) EXPOSED throw did not kill (throw_killed_hazard kinds: %s)"
			% str(_throw_kills))
	if is_instance_valid(amb) and not amb.is_queued_for_deletion():
		failures.append("(f) throw-killed ambusher still alive")
	if is_instance_valid(item):
		item.queue_free()
	player.queue_free()
	await _frames(2)


# === (g) one-shot: SPENT after the pounce; re_hide_s re-arms ===================

func _case_one_shot(gs: Node, failures: Array[String]) -> void:
	# re_hide_s = 0 → one-shot. Full cycle, then SPENT + never re-arms.
	_reset_logs()
	gs.start_run(&"test_band", 7008)
	gs.set_current_depth(3, 3)
	var player := _make_player(Vector2(100, 0))
	var amb := _make_ambusher(Vector2.ZERO, player,
		_params({ "kills": false, "re_hide_s": 0.0 }))
	# Drive telegraph→pounce→exposed→dormant(spent).
	if await _await_state(amb, ChargeLane.State.CHARGE, 30) < 0:
		failures.append("(g) one-shot ambusher never pounced")
	# After the recover window it returns to DORMANT and latches SPENT.
	await _await_spent(amb, 120)
	if not amb.is_spent():
		failures.append("(g) ambusher not SPENT after a full cycle (re_hide_s=0 one-shot)")
	if amb.is_hittable():
		failures.append("(g) SPENT ambusher still reports is_hittable() true")
	var telegraphs_after_spend := _count_events(&"ambusher", &"telegraph")
	# Re-enter the arm radius — a SPENT ambusher must NOT re-arm.
	player.global_position = Vector2(400, 0)
	await _frames(4)
	player.global_position = Vector2(100, 0)
	await _frames(40)
	if _count_events(&"ambusher", &"telegraph") != telegraphs_after_spend:
		failures.append("(g) a SPENT ambusher re-armed (2nd telegraph row) — one-shot broken")
	if amb.lane_state() != ChargeLane.State.DORMANT:
		failures.append("(g) SPENT ambusher left DORMANT")
	amb.queue_free()
	player.queue_free()
	await _frames(1)

	# re_hide_s > 0 → the area-denial variant: re-hides after EXPOSED and CAN re-arm.
	_reset_logs()
	gs.start_run(&"test_band", 7009)
	gs.set_current_depth(3, 3)
	var player2 := _make_player(Vector2(100, 0))
	var amb2 := _make_ambusher(Vector2.ZERO, player2,
		_params({ "kills": false, "re_hide_s": 0.3 }))
	if await _await_state(amb2, ChargeLane.State.CHARGE, 30) < 0:
		failures.append("(g) re-hide ambusher never pounced")
	# Let it cycle back to DORMANT (it re-hides, does NOT spend).
	if await _await_state(amb2, ChargeLane.State.DORMANT, 120) < 0:
		failures.append("(g) re-hide ambusher never returned to DORMANT")
	if amb2.is_spent():
		failures.append("(g) re_hide_s>0 ambusher latched SPENT (must re-hide, not spend)")
	if amb2.is_hittable() or amb2.collision_layer != 0:
		failures.append("(g) re-hidden ambusher not back to HIDDEN (layer 0 / out of group)")
	# With the player still in range it re-arms after the cooldown → a 2nd telegraph.
	var second := await _await_state(amb2, ChargeLane.State.TELEGRAPH, 60)
	if second < 0 or _count_events(&"ambusher", &"telegraph") < 2:
		failures.append("(g) re_hide_s>0 ambusher did not re-arm (no 2nd telegraph)")
	amb2.queue_free()
	player2.queue_free()
	await _frames(1)


# === (i) RNG-free ===============================================================

func _case_rng_free(failures: Array[String]) -> void:
	for path in ["res://scenes/hazards/components/concealment.gd",
			"res://scenes/hazards/ambusher_hazard.gd"]:
		var src := FileAccess.get_file_as_string(path)
		if src.is_empty():
			failures.append("(i) could not read %s for the RNG audit" % path)
		elif "RNG." in src:
			failures.append("(i) %s references the global RNG autoload (must be RNG-free)" % path)


# === (h) deterministic placement through the REAL builder + service ============

func _case_deterministic_placement(failures: Array[String]) -> void:
	var def := load(AMBUSHER_DEF) as OppositionDef
	if def == null:
		failures.append("(h) ambusher.tres missing")
		return
	var band := _make_band([16, 25, 25, 25, 25, 25, 25, 25])   # depths 0..7; 7 eligible pieces
	var cells_a := _deck_spawn_cells(def, band, 3, failures)
	var cells_b := _deck_spawn_cells(def, band, 3, failures)
	if cells_a.is_empty():
		failures.append("(h) band-depth-3 deck spawned no ambushers")
	if cells_a.size() != 6:
		failures.append("(h) spawned %d ambushers, expected per_band_cap = 6 to bind" % cells_a.size())
	if cells_a != cells_b:
		failures.append("(h) same band + config twice produced different spawn cells: %s vs %s"
			% [str(cells_a), str(cells_b)])
	# min_band = 3 refuses a band-depth-2 profile entirely (band-3-exclusivity).
	var cells_low := _deck_spawn_cells(def, band, 2, failures)
	if not cells_low.is_empty():
		failures.append("(h) min_band=3 ambusher spawned at band_depth 2 (%d)" % cells_low.size())


## Populate a synthetic deck band through the REAL EncounterBuilder + SpawnService,
## returning the ordered ambusher spawn cells (then tears everything down).
func _deck_spawn_cells(def: OppositionDef, band: Band, band_depth: int,
		failures: Array[String]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var profile := BandProfile.new()
	profile.id = &"synthetic_band_three"
	profile.band_depth = band_depth
	var deck: Array[Resource] = [def]
	profile.opposition_deck = deck
	var rc := RunConfig.new()
	var container := Node2D.new()
	add_child(container)
	var svc := SpawnService.new()
	svc.begin_band(container, CELL, Vector2.INF, rc)
	EncounterBuilder.new().populate(band, profile, rc, svc)
	for node in svc.live_instances(&"ambusher"):
		if node.get_script() == null or String((node.get_script() as Script).get_global_name()) != "AmbusherHazard":
			failures.append("(h) service spawned a non-AmbusherHazard node for &\"ambusher\"")
		out.append(svc.spawn_cell_of(node))
	svc.clear_all()
	remove_child(container)
	container.free()
	svc.free()
	return out


# --- harness plumbing -----------------------------------------------------------

## Fast-cycle test knobs (spawn_ctx["params"] — the deck lane's ctx-merge shape).
## Ambusher-SEMANTIC keys (the host maps them → ChargeLane keys).
func _params(overrides: Dictionary) -> Dictionary:
	var p := {
		"arm_radius": 120.0, "tell_lead_s": 0.2, "lunge_speed": 300.0,
		"lunge_dist": 120.0, "exposed_window_s": 0.5, "lunge_width": 28.0,
		"concealed_alpha": 0.0, "tell_alpha": 0.28, "re_hide_s": 0.0,
		"kills": true,
	}
	for k: Variant in overrides:
		p[k] = overrides[k]
	return p


func _make_player(pos: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.global_position = pos
	add_child(p)
	return p


func _make_ambusher(pos: Vector2, player: Node2D, params: Dictionary) -> AmbusherHazard:
	var scn := load(AMBUSHER_SCENE) as PackedScene
	var amb := scn.instantiate() as AmbusherHazard
	add_child(amb)
	amb.global_position = pos
	amb.setup(RunConfig.new(), player, { "params": params })
	return amb


func _make_thrown(pos: Vector2, dir: Vector2, speed: float, max_range: float) -> ThrownItem:
	var scn := load(THROWN_SCENE) as PackedScene
	var t := scn.instantiate() as ThrownItem
	add_child(t)
	t.global_position = pos
	var item := JunkItem.new()
	item.id = &"test_scrap"
	t.setup(item, dir, speed, max_range, 3)
	return t


## A graded linear synthetic band (the test_encounter_builder shape): piece at depth
## d has areas[d] floor cells in a contiguous block at x base d*100.
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


## Frames until the ambusher reports `want` (or -1 after max_frames).
func _await_state(amb: AmbusherHazard, want: int, max_frames: int) -> int:
	var n := 0
	while n < max_frames:
		if amb.lane_state() == want:
			return n
		await get_tree().physics_frame
		n += 1
	return -1 if amb.lane_state() != want else n


## Frames until the ambusher latches SPENT (or gives up after max_frames).
func _await_spent(amb: AmbusherHazard, max_frames: int) -> void:
	var n := 0
	while n < max_frames and not amb.is_spent():
		await get_tree().physics_frame
		n += 1


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _count_events(id: StringName, event: StringName) -> int:
	var n := 0
	for e: Array in _opp_events:
		if e[0] == id and e[1] == event:
			n += 1
	return n


# --- signal sinks ----------------------------------------------------------------

func _reset_logs() -> void:
	_opp_events.clear()
	_opp_killed.clear()
	_killed_kinds.clear()
	_run_ended_reasons.clear()
	_throw_kills.clear()
	_throw_misses = 0
	_junk_drops = 0


func _on_opposition_event(id: StringName, event: StringName, _depth: int, _ms: int) -> void:
	_opp_events.append([id, event])


func _on_opposition_killed(id: StringName, _depth: int, _ms: int) -> void:
	_opp_killed.append(id)


func _on_hazard_killed(kind: StringName, _depth: int, _ms: int) -> void:
	_killed_kinds.append(kind)


func _on_run_ended(reason: StringName, _duration_s: float, _depth_reached: int) -> void:
	_run_ended_reasons.append(reason)


func _on_throw_killed(_item_id: StringName, kind: StringName, _depth: int, _ms: int) -> void:
	_throw_kills.append(kind)


func _on_throw_missed(_item_id: StringName, _depth: int, _ms: int) -> void:
	_throw_misses += 1


func _on_junk_dropped(_item: JunkItem, _pos: Vector2) -> void:
	_junk_drops += 1
