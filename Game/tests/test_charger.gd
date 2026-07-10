extends Node
## Headless verification for S6a (M1.9 Wave 4) — the Charger ("The Wrecker"): the
## canonical Phase-E "content = data" proof (charger.tres + the ONE new ChargeLane
## component, everything else reused from the S2 set).
##
## Runs as a headless SCENE (test_charger.tscn) so the EventBus / GameState autoloads
## resolve via the live SceneTree. Instantiates ChargerHazard from charger.tscn,
## setup()s it with a stub player + a spawn_ctx "params" bag (the deck lane's ctx
## merge shape), and advances REAL physics frames so ChargeLane's host-ticked FSM and
## move_and_slide run as in-game.
##
## Asserts the S6a DoD (spec §3 + Resolved Decisions + D-RAT-2):
##  (1) def contract: charger.tres loads; id &"charger"; the D-RAT/adjudication card
##      (min_band=2, credit_cost=2, per_room_cap=1, per_band_cap=4); entity params
##      mirror ChargerHazard.DEFAULTS exactly (no code/data drift); host contract
##      (root class + node name "Charger", &"hazard" group, get_def_id/
##      resolve_throw_death seams).
##  (2) all-off gate: &"charger" is in neither RunConfig.new().oppositions_enabled
##      nor the default play preset nor band_greybox's deck; the all-off pipeline
##      fingerprint e943a… is untouched (the permanent control).
##  (3) FSM timing (DoD a): DORMANT→TELEGRAPH on aggro; TELEGRAPH holds ~telegraph_s;
##      CHARGE ends at ~charge_max_dist; RECOVER lasts ~recover_s; back to DORMANT.
##      Telemetry: exactly one &"telegraph" row + &"state" rows on the S0 locked
##      vocabulary (Correction 1 — no bespoke &"charge" token).
##  (4) lane lock (DoD b): a perpendicular step AFTER the telegraph starts dodges the
##      locked lane; a player who stays on the lane is hit.
##  (5) kills gate + latch (DoD c): kills=true → fail_run(&"death") + gated
##      opposition_killed_player(&"charger") EXACTLY once + emit-always
##      &"hit_player" + new_hazard_killed(&"charger"); kills=false → the contact rows
##      still fire but the run stays active (Correction 2 semantics).
##  (6) wall stop (DoD d): a `world`-layer wall ends the dash early (no pass-through)
##      and wall_crash_recover_mult=2 makes the recovery measurably longer.
##  (7) non-lethal outside CHARGE (DoD e): dormant/telegraph/recover touch never ends
##      the run; aggro_range 0 is permanently inert (the ProximityTrigger gate).
##  (8) throw (DoD f): throwable_while_charging=false → a CHARGE-phase throw MISSES
##      (re-drop via junk_dropped, Charger survives) while a RECOVER throw kills
##      (throw_killed_hazard kind &"charger" via get_def_id); =true → a CHARGE-phase
##      throw kills.
##  (9) RNG-free (DoD g): charge_lane.gd + charger_hazard.gd contain no global RNG
##      reference.
## (10) deterministic placement (DoD 3): the same synthetic band + deck twice through
##      the REAL EncounterBuilder + SpawnService yields identical charger spawn
##      cells; per_band_cap=4 binds; min_band=2 refuses a band-depth-1 profile.
## (11) tells render: the Tell wedge (and the TELEGRAPH lane strip) triangulate to
##      >0 triangles (the invisible-blade guard).
## Run: godot --headless --path Game res://tests/test_charger.tscn

const CHARGER_SCENE := "res://scenes/hazards/charger.tscn"
const CHARGER_DEF := "res://data/oppositions/charger.tres"
const THROWN_SCENE := "res://entities/thrown_item/thrown_item.tscn"
const PROFILE_PATH := "res://data/bands/band_greybox.tres"
const BASELINE_FP := "e943ac9c8bc1"
const CELL := 16

var _opp_events: Array = []                    # [id, event] pairs per opposition_event
var _opp_killed: Array[StringName] = []        # id per opposition_killed_player
var _killed_kinds: Array[StringName] = []      # kind per opposition_event(&"hit_player") (V2)
var _run_ended_reasons: Array[StringName] = []
var _throw_kills: Array[StringName] = []       # kind per opposition_event(&"killed_by_throw") (V2)
var _throw_misses: int = 0
var _junk_drops: int = 0


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: Array[String] = []

	var gs := get_node_or_null("/root/GameState")
	var eb := get_node_or_null("/root/EventBus")
	if gs == null or eb == null:
		printerr("CHARGER FAIL: GameState/EventBus autoload missing")
		get_tree().quit(1)
		return

	eb.opposition_event.connect(_on_opposition_event)
	eb.opposition_killed_player.connect(_on_opposition_killed)
	eb.run_ended.connect(_on_run_ended)
	eb.throw_missed.connect(_on_throw_missed)
	eb.junk_dropped.connect(_on_junk_dropped)

	_case_def_contract(failures)
	_case_all_off_gate(failures)
	await _case_fsm_timing(gs, failures)
	await _case_lane_lock(gs, failures)
	await _case_kills_gate(gs, failures)
	await _case_wall_stop(gs, failures)
	await _case_nonlethal_states(gs, failures)
	await _case_throw(gs, failures)
	_case_rng_free(failures)
	_case_deterministic_placement(failures)

	if failures.is_empty():
		print("S6a OK — Charger verified: def card locked (min_band 2 / cost 2 / caps 1+4, "
			+ "params mirror DEFAULTS), all-off gate holds (fp " + BASELINE_FP + ", charger in "
			+ "no default lever/deck), three-beat FSM times out (telegraph -> locked dash -> "
			+ "recover -> dormant, S0-locked telemetry vocabulary), the shown lane is dodgeable "
			+ "and lethal only while dashing, the L5 kills gate + BUG6 latch fire exactly once, "
			+ "walls stop the dash with the D-RAT-2 bonus-stun knob binding, dash-invulnerability "
			+ "(group toggle) misses + re-drops a mid-dash throw while a recovery throw kills, "
			+ "ChargeLane is RNG-free, and deck placement is deterministic with per_band_cap/"
			+ "min_band enforced by the real service.")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("CHARGER FAIL: ", f)
		get_tree().quit(1)


# === (1) def contract ==========================================================

func _case_def_contract(failures: Array[String]) -> void:
	var def := load(CHARGER_DEF) as OppositionDef
	if def == null:
		failures.append("(1) charger.tres does not load as OppositionDef")
		return
	if def.id != &"charger":
		failures.append("(1) def id %s != &\"charger\"" % def.id)
	if def.min_band != 2:
		failures.append("(1) min_band %d != 2 (adjudication #1 — band-2 hard gate)" % def.min_band)
	if def.credit_cost != 2:
		failures.append("(1) credit_cost %d != 2" % def.credit_cost)
	if def.per_room_cap != 1:
		failures.append("(1) per_room_cap %d != 1 (OQ-5)" % def.per_room_cap)
	if def.per_band_cap != 4:
		failures.append("(1) per_band_cap %d != 4" % def.per_band_cap)
	if not def.kills:
		failures.append("(1) typed kills field is false (D-RAT-2 ships lethal)")
	if not bool(def.params.get("throwable_while_charging", false)):
		failures.append("(1) def default throwable_while_charging != true (D-RAT-2: the deck "
			+ "override, not the def, sets false)")
	if float(def.params.get("wall_crash_recover_mult", 0.0)) != 1.0:
		failures.append("(1) def default wall_crash_recover_mult != 1.0 (D-RAT-2)")
	# Entity-read params mirror the host's code fallbacks exactly (no drift).
	for key: String in ChargerHazard.DEFAULTS:
		if not def.params.has(key):
			failures.append("(1) def params missing entity key '%s'" % key)
		elif def.params[key] != ChargerHazard.DEFAULTS[key]:
			failures.append("(1) def params['%s'] = %s != ChargerHazard.DEFAULTS %s"
				% [key, str(def.params[key]), str(ChargerHazard.DEFAULTS[key])])
	# Only the builder-read spawn-card keys may exist beyond the entity keys.
	for k: Variant in def.params.keys():
		var ks := String(k)
		if not ChargerHazard.DEFAULTS.has(ks) and ks != "base_count" and ks != "count_per_depth":
			failures.append("(1) unexpected def param '%s' (not entity-read, not spawn-card)" % ks)
	# Host contract: root class/name/group + the S2 seams.
	var root := def.host_scene.instantiate()
	if root == null:
		failures.append("(1) host_scene does not instantiate")
		return
	var script: Script = root.get_script()
	if script == null or String(script.get_global_name()) != "ChargerHazard":
		failures.append("(1) host root class != ChargerHazard")
	if String(root.name) != "Charger":
		failures.append("(1) host root node name '%s' != 'Charger' (§2.7 kind fallback)" % root.name)
	if not root.is_in_group(&"hazard"):
		failures.append("(1) host root not in the 'hazard' group")
	if not root.has_method(&"resolve_throw_death") or not root.has_method(&"get_def_id"):
		failures.append("(1) host root missing the S2 throw/def-id seams")
	elif StringName(root.call(&"get_def_id")) != &"charger":
		failures.append("(1) get_def_id() != &\"charger\"")
	# (11) the Tell wedge must actually render (invisible-blade guard).
	var tell: Polygon2D = root.get_node_or_null("Tell")
	if tell == null:
		failures.append("(1) host has no Tell polygon")
	elif Geometry2D.triangulate_polygon(tell.polygon).is_empty():
		failures.append("(1) Tell wedge triangulates to 0 triangles — renders NOTHING")
	root.free()


# === (2) all-off gate ==========================================================

func _case_all_off_gate(failures: Array[String]) -> void:
	if RunConfig.new().oppositions_enabled.has(&"charger"):
		failures.append("(2) all-off RunConfig lists &\"charger\" in oppositions_enabled")
	if RunConfig.make_default_play_preset().oppositions_enabled.has(&"charger"):
		failures.append("(2) the default play preset lists &\"charger\" (D-RAT-2: NOT in the preset)")
	var profile := load(PROFILE_PATH) as BandProfile
	if profile == null:
		failures.append("(2) could not load %s" % PROFILE_PATH)
		return
	for r in profile.opposition_deck:
		var d := r as OppositionDef
		if d != null and d.id == &"charger":
			failures.append("(2) band_greybox's deck lists the charger (band-2-exclusive)")
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


# === (3) FSM timing + locked telemetry vocabulary ==============================

func _case_fsm_timing(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 6001)
	gs.set_current_depth(2, 2)
	var player := _make_player(Vector2(100, 0))
	var chg := _make_charger(Vector2.ZERO, player, _params({ "kills": false }))

	# DORMANT → TELEGRAPH on aggro (player inside 120px at spawn).
	var to_tele := await _await_state(chg, ChargeLane.State.TELEGRAPH, 5)
	if to_tele < 0:
		failures.append("(3) never entered TELEGRAPH on aggro")
	# TELEGRAPH holds ~telegraph_s (0.2s ≈ 12 frames @ 60Hz).
	var to_charge := await _await_state(chg, ChargeLane.State.CHARGE, 30)
	if to_charge < 0:
		failures.append("(3) never entered CHARGE")
	elif to_charge < 8 or to_charge > 20:
		failures.append("(3) TELEGRAPH lasted %d frames, expected ~12 (0.2s)" % to_charge)
	# CHARGE ends at charge_max_dist (120px @ 300px/s ≈ 24 frames), overshooting the player.
	var to_recover := await _await_state(chg, ChargeLane.State.RECOVER, 60)
	if to_recover < 0:
		failures.append("(3) never entered RECOVER")
	elif to_recover < 18 or to_recover > 34:
		failures.append("(3) CHARGE lasted %d frames, expected ~24 (120px @ 300px/s)" % to_recover)
	# RECOVER lasts ~recover_s (0.3s ≈ 18 frames), then DORMANT.
	var to_dormant := await _await_state(chg, ChargeLane.State.DORMANT, 60)
	if to_dormant < 0:
		failures.append("(3) never returned to DORMANT")
	elif to_dormant < 12 or to_dormant > 28:
		failures.append("(3) RECOVER lasted %d frames, expected ~18 (0.3s)" % to_dormant)

	# Telemetry vocabulary: exactly one &"telegraph", the rest &"state" (Correction 1).
	if _count_events(&"charger", &"telegraph") != 1:
		failures.append("(3) expected exactly 1 telegraph row, got %d"
			% _count_events(&"charger", &"telegraph"))
	if _count_events(&"charger", &"state") < 3:
		failures.append("(3) expected >= 3 state rows (charge/recover/dormant), got %d"
			% _count_events(&"charger", &"state"))
	for e: Array in _opp_events:
		if e[0] == &"charger" and not [&"telegraph", &"state", &"hit_player"].has(e[1]):
			failures.append("(3) out-of-vocabulary opposition_event '%s' (S0 locked set)" % e[1])
	# The overshoot passed THROUGH the player (kills=false): the emit-always contact
	# row fired, but the run must still be active.
	if _count_events(&"charger", &"hit_player") < 1:
		failures.append("(3) dash through the player emitted no hit_player row (emit-always)")
	if not gs.run_active:
		failures.append("(3) kills=false dash ended the run")
	# (11) the TELEGRAPH lane strip was built and triangulates.
	var lane_rect: Polygon2D = chg.get_node_or_null("LaneRect")
	if lane_rect == null or Geometry2D.triangulate_polygon(lane_rect.polygon).is_empty():
		failures.append("(3) LaneRect never built a renderable committed-lane strip")

	chg.queue_free()
	player.queue_free()


# === (4) lane lock: the shown lane is dodgeable ================================

func _case_lane_lock(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 6002)
	gs.set_current_depth(2, 2)
	var player := _make_player(Vector2(100, 0))
	var chg := _make_charger(Vector2.ZERO, player, _params({ "kills": true }))

	# Wait for the wind-up, then step perpendicular OFF the locked lane.
	if await _await_state(chg, ChargeLane.State.TELEGRAPH, 5) < 0:
		failures.append("(4) never telegraphed")
	player.global_position = Vector2(100, 90)   # corridor half-width is 28px — well clear
	if await _await_state(chg, ChargeLane.State.RECOVER, 90) < 0:
		failures.append("(4) dash never completed")
	if _count_events(&"charger", &"hit_player") != 0:
		failures.append("(4) a perpendicular dodge off the LOCKED lane was still hit")
	if not gs.run_active:
		failures.append("(4) the dodged dash ended the run")
	chg.queue_free()
	player.queue_free()
	await _frames(1)


# === (5) kills gate + BUG6 latch ===============================================

func _case_kills_gate(gs: Node, failures: Array[String]) -> void:
	# kills=true, player stays on the lane → death, each channel exactly once.
	_reset_logs()
	gs.start_run(&"test_band", 6003)
	gs.set_current_depth(2, 2)
	var player := _make_player(Vector2(100, 0))
	var chg := _make_charger(Vector2.ZERO, player, _params({ "kills": true }))
	await _frames(45)   # telegraph (12) + dash reach (~20) + margin
	if not _run_ended_reasons.has(&"death"):
		failures.append("(5) on-lane player was not killed via fail_run(&\"death\")")
	if gs.run_active:
		failures.append("(5) run still active after a fatal dash")
	if _opp_killed.count(&"charger") != 1:
		failures.append("(5) opposition_killed_player(&\"charger\") fired %d times, expected exactly 1"
			% _opp_killed.count(&"charger"))
	if _killed_kinds.count(&"charger") != 1:
		failures.append("(5) new_hazard_killed(&\"charger\") fired %d times, expected exactly 1 (BUG6)"
			% _killed_kinds.count(&"charger"))
	if _count_events(&"charger", &"hit_player") != 1:
		failures.append("(5) hit_player rows %d, expected exactly 1 (latch)"
			% _count_events(&"charger", &"hit_player"))
	chg.queue_free()
	player.queue_free()
	await _frames(1)

	# kills=false, same geometry → the rows minus the gated pair; run survives.
	_reset_logs()
	gs.start_run(&"test_band", 6004)
	gs.set_current_depth(2, 2)
	var player2 := _make_player(Vector2(100, 0))
	var chg2 := _make_charger(Vector2.ZERO, player2, _params({ "kills": false }))
	await _frames(45)
	if _count_events(&"charger", &"hit_player") != 1:
		failures.append("(5) kills=false contact rows %d, expected exactly 1 (emit-always + latch)"
			% _count_events(&"charger", &"hit_player"))
	if not _opp_killed.is_empty():
		failures.append("(5) kills=false emitted opposition_killed_player (must be gated — Correction 2)")
	if _run_ended_reasons.has(&"death") or not gs.run_active:
		failures.append("(5) kills=false ended the run")
	chg2.queue_free()
	player2.queue_free()
	await _frames(1)


# === (6) wall stop + the bonus-stun knob =======================================

func _case_wall_stop(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 6005)
	gs.set_current_depth(2, 2)
	# Player far along +X (aggro 260 reaches, lane locks +X); a world wall between.
	var player := _make_player(Vector2(200, 0))
	var wall := _make_wall(Vector2(80, 0), Vector2(10, 100))
	var chg := _make_charger(Vector2.ZERO, player,
		_params({ "kills": true, "aggro_range": 260.0, "charge_max_dist": 400.0,
			"wall_crash_recover_mult": 2.0 }))

	if await _await_state(chg, ChargeLane.State.CHARGE, 30) < 0:
		failures.append("(6) never charged")
	# The wall face is at x=70: an unobstructed 400px dash needs ~80 frames; the wall
	# must stop it far sooner.
	var to_recover := await _await_state(chg, ChargeLane.State.RECOVER, 40)
	if to_recover < 0:
		failures.append("(6) wall never stopped the dash (no early RECOVER)")
	if chg.global_position.x > 72.0:
		failures.append("(6) charger passed through the world wall (x=%.1f)" % chg.global_position.x)
	if _count_events(&"charger", &"hit_player") != 0 or not gs.run_active:
		failures.append("(6) the walled-off player was hit through the wall")
	# Bonus stun: recover_s 0.3 × mult 2.0 = 0.6s ≈ 36 frames (plain is ~18).
	var crash_recover := await _await_state(chg, ChargeLane.State.DORMANT, 80)
	if crash_recover < 0:
		failures.append("(6) never recovered from the wall crash")
	elif crash_recover < 28:
		failures.append("(6) wall-crash recovery lasted %d frames — the ×2 bonus stun did not bind"
			% crash_recover)

	# DoD (e) rider: standing on a RECOVERING/DORMANT charger is safe. (The charger
	# is dormant here post-cycle; walk the player onto it.)
	player.global_position = chg.global_position
	# Keep it from immediately re-telegraphing into a kill: it must first cool down,
	# then telegraph (0.2s) — probe well inside that window.
	await _frames(6)
	if not gs.run_active:
		failures.append("(6) touching a non-CHARGE charger ended the run")

	chg.queue_free()
	wall.queue_free()
	player.queue_free()
	await _frames(1)


# === (7) non-lethal outside CHARGE =============================================

func _case_nonlethal_states(gs: Node, failures: Array[String]) -> void:
	# aggro_range 0 → permanently inert (the ProximityTrigger 0-gate); standing ON a
	# DORMANT charger is safe indefinitely.
	_reset_logs()
	gs.start_run(&"test_band", 6006)
	gs.set_current_depth(2, 2)
	var player := _make_player(Vector2.ZERO)
	var chg := _make_charger(Vector2.ZERO, player,
		_params({ "kills": true, "aggro_range": 0.0 }))
	await _frames(15)
	if chg.lane_state() != ChargeLane.State.DORMANT:
		failures.append("(7) aggro_range 0 charger woke up (0 must be inert)")
	if not gs.run_active or _count_events(&"charger", &"hit_player") != 0:
		failures.append("(7) a DORMANT charger hurt the player standing on it")
	chg.queue_free()
	player.queue_free()
	await _frames(1)

	# TELEGRAPH touch is safe until the dash begins: player ON the charger for the
	# whole wind-up survives it; the kill lands only once CHARGE starts.
	_reset_logs()
	gs.start_run(&"test_band", 6007)
	gs.set_current_depth(2, 2)
	var player2 := _make_player(Vector2.ZERO)
	var chg2 := _make_charger(Vector2.ZERO, player2, _params({ "kills": true }))
	if await _await_state(chg2, ChargeLane.State.TELEGRAPH, 5) < 0:
		failures.append("(7) never telegraphed")
	await _frames(6)   # mid-wind-up (~half of the 12-frame telegraph)
	if not gs.run_active:
		failures.append("(7) a TELEGRAPHING charger killed on touch (only CHARGE is lethal)")
	if chg2.lane_state() != ChargeLane.State.TELEGRAPH:
		failures.append("(7) telegraph ended unexpectedly early (test mis-timed)")
	await _frames(20)  # let the dash begin — frame 1 of CHARGE sweeps over the player
	if gs.run_active:
		failures.append("(7) the dash over an on-lane player did not kill (kills=true)")
	chg2.queue_free()
	player2.queue_free()
	await _frames(1)


# === (8) throw interaction — dash-invulnerability + the recovery punish ========

func _case_throw(gs: Node, failures: Array[String]) -> void:
	# throwable_while_charging = FALSE (the D-RAT-2 band_two deck override): a throw
	# during the dash MISSES and re-drops; a throw during RECOVER kills.
	_reset_logs()
	gs.start_run(&"test_band", 6008)
	gs.set_current_depth(2, 2)
	# Player parked on +X so the locked lane is the x-axis (kills=false — the sweep
	# over the player is irrelevant to this case).
	var player := _make_player(Vector2(200, 0))
	var chg := _make_charger(Vector2.ZERO, player,
		_params({ "kills": false, "aggro_range": 260.0, "charge_speed": 200.0,
			"charge_max_dist": 300.0, "throwable_while_charging": false,
			"recover_s": 1.0 }))
	if await _await_state(chg, ChargeLane.State.CHARGE, 30) < 0:
		failures.append("(8) never charged")
	if chg.is_in_group(&"hazard"):
		failures.append("(8) charging charger still in the 'hazard' group (dash-invulnerability off)")
	# Park an item in the dash lane just ahead — the charger runs into it.
	var item1 := _make_thrown(chg.global_position + Vector2(40, 0))
	await _frames(20)
	if _throw_misses != 1 or _junk_drops != 1:
		failures.append("(8) mid-dash throw vs an invulnerable charger: misses=%d drops=%d, expected 1/1 (re-drop)"
			% [_throw_misses, _junk_drops])
	if not is_instance_valid(chg):
		failures.append("(8) an invulnerable (mid-dash) charger was throw-killed")
	if not _throw_kills.is_empty():
		failures.append("(8) mid-dash throw logged a kill row")
	if is_instance_valid(item1):
		item1.queue_free()
	# Now the punish window: RECOVER re-joins the group; a throw kills.
	if await _await_state(chg, ChargeLane.State.RECOVER, 90) < 0:
		failures.append("(8) never recovered")
	elif not chg.is_in_group(&"hazard"):
		failures.append("(8) recovering charger not back in the 'hazard' group")
	var item2 := _make_thrown(chg.global_position)
	await _frames(10)
	if not _throw_kills.has(&"charger"):
		failures.append("(8) RECOVER throw did not kill (throw_killed_hazard kinds: %s)"
			% str(_throw_kills))
	if is_instance_valid(chg) and not chg.is_queued_for_deletion():
		failures.append("(8) throw-killed charger still alive")
	if is_instance_valid(item2):
		item2.queue_free()
	player.queue_free()
	await _frames(2)

	# throwable_while_charging = TRUE (the def default): a mid-dash throw kills.
	_reset_logs()
	gs.start_run(&"test_band", 6009)
	gs.set_current_depth(2, 2)
	var player2 := _make_player(Vector2(200, 0))
	var chg2 := _make_charger(Vector2.ZERO, player2,
		_params({ "kills": false, "aggro_range": 260.0, "charge_speed": 200.0,
			"charge_max_dist": 300.0 }))
	if await _await_state(chg2, ChargeLane.State.CHARGE, 30) < 0:
		failures.append("(8) default charger never charged")
	elif not chg2.is_in_group(&"hazard"):
		failures.append("(8) default (throwable) charger left the 'hazard' group mid-dash")
	var item3 := _make_thrown(chg2.global_position + Vector2(40, 0))
	await _frames(20)
	if not _throw_kills.has(&"charger"):
		failures.append("(8) mid-dash throw vs the throwable default did not kill")
	if is_instance_valid(item3):
		item3.queue_free()
	if is_instance_valid(chg2):
		chg2.queue_free()
	player2.queue_free()
	await _frames(1)


# === (9) RNG-free ===============================================================

func _case_rng_free(failures: Array[String]) -> void:
	for path in ["res://scenes/hazards/components/charge_lane.gd",
			"res://scenes/hazards/charger_hazard.gd"]:
		var src := FileAccess.get_file_as_string(path)
		if src.is_empty():
			failures.append("(9) could not read %s for the RNG audit" % path)
		elif "RNG." in src:
			failures.append("(9) %s references the global RNG autoload (must be RNG-free)" % path)


# === (10) deterministic placement through the REAL builder + service ===========

func _case_deterministic_placement(failures: Array[String]) -> void:
	var def := load(CHARGER_DEF) as OppositionDef
	if def == null:
		failures.append("(10) charger.tres missing")
		return
	var band := _make_band([16, 25, 25, 25, 25, 25, 25])   # depths 0..6; 6 eligible pieces
	var cells_a := _deck_spawn_cells(def, band, 2, failures)
	var cells_b := _deck_spawn_cells(def, band, 2, failures)
	if cells_a.is_empty():
		failures.append("(10) band-depth-2 deck spawned no chargers")
	if cells_a.size() != 4:
		failures.append("(10) spawned %d chargers, expected per_band_cap = 4 to bind" % cells_a.size())
	if cells_a != cells_b:
		failures.append("(10) same band + config twice produced different spawn cells: %s vs %s"
			% [str(cells_a), str(cells_b)])
	# min_band = 2 refuses a band-depth-1 profile entirely (band-2-exclusivity).
	var cells_low := _deck_spawn_cells(def, band, 1, failures)
	if not cells_low.is_empty():
		failures.append("(10) min_band=2 charger spawned at band_depth 1 (%d)" % cells_low.size())


## Populate a synthetic deck band through the REAL EncounterBuilder + SpawnService,
## returning the ordered charger spawn cells (then tears everything down).
func _deck_spawn_cells(def: OppositionDef, band: Band, band_depth: int,
		failures: Array[String]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var profile := BandProfile.new()
	profile.id = &"synthetic_band_two"
	profile.band_depth = band_depth
	var deck: Array[Resource] = [def]
	profile.opposition_deck = deck
	var rc := RunConfig.new()
	var container := Node2D.new()
	add_child(container)
	var svc := SpawnService.new()
	svc.begin_band(container, CELL, Vector2.INF, rc)
	EncounterBuilder.new().populate(band, profile, rc, svc)
	for node in svc.live_instances(&"charger"):
		if node.get_script() == null or String((node.get_script() as Script).get_global_name()) != "ChargerHazard":
			failures.append("(10) service spawned a non-ChargerHazard node for &\"charger\"")
		out.append(svc.spawn_cell_of(node))
	svc.clear_all()
	remove_child(container)
	container.free()
	svc.free()
	return out


# --- harness plumbing -----------------------------------------------------------

## Fast-cycle test knobs (spawn_ctx["params"] — the deck lane's ctx-merge shape).
func _params(overrides: Dictionary) -> Dictionary:
	var p := {
		"aggro_range": 120.0, "telegraph_s": 0.2, "charge_speed": 300.0,
		"charge_max_dist": 120.0, "recover_s": 0.3, "cooldown_s": 0.2,
		"lane_width": 28.0, "lock_at_telegraph_start": true,
		"throwable_while_charging": true, "wall_crash_recover_mult": 1.0,
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


func _make_charger(pos: Vector2, player: Node2D, params: Dictionary) -> ChargerHazard:
	var scn := load(CHARGER_SCENE) as PackedScene
	var chg := scn.instantiate() as ChargerHazard
	add_child(chg)
	chg.global_position = pos
	chg.setup(RunConfig.new(), player, { "params": params })
	return chg


func _make_thrown(pos: Vector2) -> ThrownItem:
	var scn := load(THROWN_SCENE) as PackedScene
	var t := scn.instantiate() as ThrownItem
	add_child(t)
	t.global_position = pos
	var item := JunkItem.new()
	item.id = &"test_scrap"
	t.setup(item, Vector2.RIGHT, 0.0, 0.0, 2)   # parked: speed 0, no max-range miss
	return t


func _make_wall(pos: Vector2, half: Vector2) -> StaticBody2D:
	var w := StaticBody2D.new()
	w.collision_layer = 2      # `world` — the layer the charger's dash masks
	w.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = half * 2.0
	cs.shape = sh
	w.add_child(cs)
	add_child(w)
	w.global_position = pos
	return w


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


## Frames until the charger reports `want` (or -1 after max_frames).
func _await_state(chg: ChargerHazard, want: int, max_frames: int) -> int:
	var n := 0
	while n < max_frames:
		if chg.lane_state() == want:
			return n
		await get_tree().physics_frame
		n += 1
	return -1 if chg.lane_state() != want else n


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
	# V2: the legacy new_hazard_killed / throw_killed_hazard signals retired — derive
	# the kind-count arrays from the generic family (same site/moment; kind == id).
	if event == &"hit_player":
		_killed_kinds.append(id)
	elif event == &"killed_by_throw":
		_throw_kills.append(id)


func _on_opposition_killed(id: StringName, _depth: int, _ms: int) -> void:
	_opp_killed.append(id)


func _on_run_ended(reason: StringName, _duration_s: float, _depth_reached: int) -> void:
	_run_ended_reasons.append(reason)


func _on_throw_missed(_item_id: StringName, _depth: int, _ms: int) -> void:
	_throw_misses += 1


func _on_junk_dropped(_item: JunkItem, _pos: Vector2) -> void:
	_junk_drops += 1
