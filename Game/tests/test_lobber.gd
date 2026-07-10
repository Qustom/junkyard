extends Node
## Headless verification for U2a (M1.11 Wave 1) — the Lobber ("The Mortar"): the
## indirect-AoE cost-ledger proof (lobber.tres + the ONE new MortarCycle component,
## everything else reused from the S2 set).
##
## Runs as a headless SCENE (test_lobber.tscn) so the EventBus / GameState autoloads
## resolve via the live SceneTree. Instantiates LobberHazard from lobber.tscn,
## setup()s it with a stub player + a spawn_ctx "params" bag (the deck lane's
## ctx-merge shape), and advances REAL physics frames so MortarCycle's host-ticked
## fire-period FSM runs as in-game.
##
## Asserts the U2a DoD (spec §3 + Resolved Decisions, BINDING — per_band_cap 5):
##  (1) def contract: lobber.tres loads; id &"lobber"; the card (min_band=4,
##      credit_cost=2, cap_group=&"new_hazards", per_room_cap=1, per_band_cap=5,
##      kills); entity params mirror LobberHazard.DEFAULTS exactly; only
##      base_count/count_per_depth beyond the entity keys; per-def params<->schema
##      bijection (count-agnostic — NO global def-count assert; U2b lands in the
##      same wave); host contract (root class LobberHazard, node "Lobber", &"hazard"
##      group at author time, get_def_id/resolve_throw_death seams); $Body +
##      $MarkerRoot/Ring polygons triangulate to >0 (invisible-hazard guard).
##  (2) all-off gate: &"lobber" in neither RunConfig.new().oppositions_enabled nor
##      the default play preset nor band_greybox/band_two/band_three decks; the
##      all-off pipeline fingerprint e943ac9c8bc1 is untouched. PLUS the additive-OR
##      lever nuance (as-built correction 2): oppositions_enabled=[&"lobber"] on
##      shallow bands (band_depth 1/2/3) through the REAL builder+service spawns
##      ZERO lobbers (zero SPAWNS asserted, not zero loads).
##  (3) cycle timing from params: AIM ~fire_period_s then IN-FLIGHT ~arc_time_s then
##      AIM again. Telemetry: exactly one &"telegraph" per shell + &"state" on
##      impact; no out-of-vocabulary opposition_event token (S0 locked set).
##  (4) marker locked at fire + precedes impact by arc_time (the fairness bar): the
##      marker appears at the fire-time player position, is visible for the flight,
##      does NOT re-track a moving player, and a player who steps > blast_radius off
##      the FROZEN point before impact is NOT killed (run active, zero &"hit_player").
##  (5) blast kill gated + centre-in-radius only: kills=true player on the marker at
##      IMPACT -> fail_run(&"death") + opposition_killed_player(&"lobber") exactly
##      once (BUG6) + one &"hit_player" + one new_hazard_killed; kills=false, same
##      geometry -> &"hit_player" fires, run stays active, no killed row.
##  (6) geometry-ignoring across a wall: a world-layer wall between Lobber and player
##      changes nothing — the marker still locks onto the player and the blast still
##      kills (no LOS/occlusion — the Lobber's identity).
##  (7) fire-period cycle: >= 2 &"telegraph" rows over a multi-cycle run (the rain
##      continues after an impact).
##  (8) throw-killable, always: a ThrownItem at the Lobber body kills it
##      (throw_killed_hazard &"lobber"), it frees, and NO further &"telegraph" rows
##      appear (the rain stops).
##  (9) params flow def < DeckEntry < rc.param_overrides through the REAL
##      EncounterBuilder: the entity's effective fire_period_s is the deck value
##      under a deck-entry override, and the rc value when rc.param_overrides also
##      names it (the locked precedence).
## (10) deterministic placement + caps through the REAL builder+service: same
##      synthetic band-4 band twice -> identical lobber spawn cells; per_band_cap=5
##      binds; min_band=4 refuses a band-depth-3 profile entirely (zero spawns).
## (11) cadence desync: two lobbers at DIFFERENT spawn positions fire on DIFFERENT
##      frames (positional salt, no RNG); the same explicit ctx phase_salt twice ->
##      identical fire frame (deterministic; the harness-override mirror).
## (12) RNG-free: mortar_cycle.gd + lobber_hazard.gd contain no "RNG." substring.
## Run: godot --headless --path Game res://tests/test_lobber.tscn

const LOBBER_SCENE := "res://scenes/hazards/lobber.tscn"
const LOBBER_DEF := "res://data/oppositions/lobber.tres"
const THROWN_SCENE := "res://entities/thrown_item/thrown_item.tscn"
const GREYBOX_PROFILE := "res://data/bands/band_greybox.tres"
const BAND_TWO_PROFILE := "res://data/bands/band_two.tres"
const BAND_THREE_PROFILE := "res://data/bands/band_three.tres"
const BASELINE_FP := "e943ac9c8bc1"
const CELL := 16

var _opp_events: Array = []                    # [id, event] pairs per opposition_event
var _opp_killed: Array[StringName] = []        # id per opposition_killed_player
var _killed_kinds: Array[StringName] = []      # kind per opposition_event(&"hit_player") (V2)
var _run_ended_reasons: Array[StringName] = []
var _throw_kills: Array[StringName] = []       # kind per opposition_event(&"killed_by_throw") (V2)


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: Array[String] = []

	var gs := get_node_or_null("/root/GameState")
	var eb := get_node_or_null("/root/EventBus")
	if gs == null or eb == null:
		printerr("LOBBER FAIL: GameState/EventBus autoload missing")
		get_tree().quit(1)
		return

	eb.opposition_event.connect(_on_opposition_event)
	eb.opposition_killed_player.connect(_on_opposition_killed)
	eb.run_ended.connect(_on_run_ended)

	_case_def_contract(failures)
	_case_all_off_gate(failures)
	await _case_cycle_timing(gs, failures)
	await _case_marker_lock_dodge(gs, failures)
	await _case_blast_kill(gs, failures)
	await _case_wall_ignored(gs, failures)
	await _case_rain_continues(gs, failures)
	await _case_throw_kill(gs, failures)
	_case_params_flow(failures)
	_case_deterministic_placement(failures)
	await _case_desync(gs, failures)
	_case_rng_free(failures)

	if failures.is_empty():
		print("U2a OK — Lobber verified: def card locked (min_band 4 / cost 2 / caps 1+5, "
			+ "params mirror DEFAULTS), all-off gate holds (fp " + BASELINE_FP + ", lobber in "
			+ "no default lever/preset/band 1-3 deck, additive-OR lever spawns ZERO on shallow "
			+ "bands), the AIM->IN-FLIGHT cycle times out on the S0-locked vocabulary, the "
			+ "marker LOCKS at fire time + precedes impact by arc_time (stepping off the frozen "
			+ "point is a guaranteed dodge), the centre-in-radius blast is kills-gated with the "
			+ "BUG6 latch firing exactly once, a wall between Lobber and player changes nothing "
			+ "(geometry-ignoring identity), the rain continues across cycles and STOPS on a "
			+ "throw-kill (always a valid target), params flow def < DeckEntry < "
			+ "rc.param_overrides through the real builder, deck placement is deterministic "
			+ "with per_band_cap 5 / min_band 4 enforced by the real service, co-located "
			+ "lobbers desync by position (ctx phase_salt harness-override mirrored), and "
			+ "MortarCycle is RNG-free.")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("LOBBER FAIL: ", f)
		get_tree().quit(1)


# === (1) def contract ==========================================================

func _case_def_contract(failures: Array[String]) -> void:
	var def := load(LOBBER_DEF) as OppositionDef
	if def == null:
		failures.append("(1) lobber.tres does not load as OppositionDef")
		return
	if def.id != &"lobber":
		failures.append("(1) def id %s != &\"lobber\"" % def.id)
	if def.min_band != 4:
		failures.append("(1) min_band %d != 4 (band-4 hard gate)" % def.min_band)
	if def.credit_cost != 2:
		failures.append("(1) credit_cost %d != 2" % def.credit_cost)
	if def.cap_group != &"new_hazards":
		failures.append("(1) cap_group %s != &\"new_hazards\"" % def.cap_group)
	if def.per_room_cap != 1:
		failures.append("(1) per_room_cap %d != 1" % def.per_room_cap)
	if def.per_band_cap != 5:
		failures.append("(1) per_band_cap %d != 5 (Phase-3 card override)" % def.per_band_cap)
	if not def.kills:
		failures.append("(1) typed kills field is false (ships lethal)")
	# Entity-read params mirror the host's code fallbacks exactly (no drift).
	for key: String in LobberHazard.DEFAULTS:
		if not def.params.has(key):
			failures.append("(1) def params missing entity key '%s'" % key)
		elif def.params[key] != LobberHazard.DEFAULTS[key]:
			failures.append("(1) def params['%s'] = %s != LobberHazard.DEFAULTS %s"
				% [key, str(def.params[key]), str(LobberHazard.DEFAULTS[key])])
	# Only the builder-read spawn-card keys may exist beyond the entity keys.
	for k: Variant in def.params.keys():
		var ks := String(k)
		if not LobberHazard.DEFAULTS.has(ks) and ks != "base_count" and ks != "count_per_depth":
			failures.append("(1) unexpected def param '%s' (not entity-read, not spawn-card)" % ks)
	# Per-def params<->param_schema bijection (count-agnostic — the lobber's OWN
	# bijection only; U2a lands 9->10 and U2b 10->11 in the same wave).
	var schema_keys: Array[String] = []
	for entry: Dictionary in def.param_schema:
		schema_keys.append(String(entry.get("key", "")))
	for k: Variant in def.params.keys():
		if not schema_keys.has(String(k)):
			failures.append("(1) param '%s' has no schema row (bijection)" % str(k))
	for sk in schema_keys:
		if not def.params.has(sk):
			failures.append("(1) schema row '%s' has no param (orphan)" % sk)
	# Host contract: root class/name/group + the S2 seams.
	var root := def.host_scene.instantiate()
	if root == null:
		failures.append("(1) host_scene does not instantiate")
		return
	var script: Script = root.get_script()
	if script == null or String(script.get_global_name()) != "LobberHazard":
		failures.append("(1) host root class != LobberHazard")
	if String(root.name) != "Lobber":
		failures.append("(1) host root node name '%s' != 'Lobber'" % root.name)
	if not root.is_in_group(&"hazard"):
		failures.append("(1) host root not in the 'hazard' group at author time")
	if not root.has_method(&"resolve_throw_death") or not root.has_method(&"get_def_id"):
		failures.append("(1) host root missing the S2 throw/def-id seams")
	elif StringName(root.call(&"get_def_id")) != &"lobber":
		failures.append("(1) get_def_id() != &\"lobber\"")
	# Body + marker Ring must actually render (invisible-hazard guard).
	var body: Polygon2D = root.get_node_or_null("Body")
	if body == null or Geometry2D.triangulate_polygon(body.polygon).is_empty():
		failures.append("(1) Body polygon triangulates to 0 triangles — renders NOTHING")
	var ring: Polygon2D = root.get_node_or_null("MarkerRoot/Ring")
	if ring == null or Geometry2D.triangulate_polygon(ring.polygon).is_empty():
		failures.append("(1) MarkerRoot/Ring polygon triangulates to 0 triangles — renders NOTHING")
	var mroot: Node2D = root.get_node_or_null("MarkerRoot")
	if mroot == null or not mroot.top_level:
		failures.append("(1) MarkerRoot missing or not top_level (marker must be world-absolute)")
	root.free()


# === (2) all-off gate + the additive-OR lever nuance ===========================

func _case_all_off_gate(failures: Array[String]) -> void:
	if RunConfig.new().oppositions_enabled.has(&"lobber"):
		failures.append("(2) all-off RunConfig lists &\"lobber\" in oppositions_enabled")
	if RunConfig.make_default_play_preset().oppositions_enabled.has(&"lobber"):
		failures.append("(2) the default play preset lists &\"lobber\"")
	for prof_path in [GREYBOX_PROFILE, BAND_TWO_PROFILE, BAND_THREE_PROFILE]:
		var profile := load(prof_path) as BandProfile
		if profile == null:
			continue   # a band profile may not exist in this worktree; skip silently
		for r in profile.opposition_deck:
			var d := r as OppositionDef
			if r is DeckEntry:
				d = (r as DeckEntry).def as OppositionDef
			if d != null and d.id == &"lobber":
				failures.append("(2) %s's deck lists the lobber (band-4-exclusive)" % prof_path)
	var greybox := load(GREYBOX_PROFILE) as BandProfile
	if greybox != null:
		if not EncounterBuilder.new().is_inert(greybox, RunConfig.new()):
			failures.append("(2) all-off + band_greybox is not inert")
		var control := BandPipeline.new().generate(greybox, 12345, RunConfig.new())
		if control == null or control.fingerprint().substr(0, 12) != BASELINE_FP:
			failures.append("(2) all-off pipeline fp %s != %s (baseline moved!)"
				% [control.fingerprint().substr(0, 12) if control != null else "null", BASELINE_FP])
		if control != null:
			for p in control.pieces:
				if p.instance != null and is_instance_valid(p.instance):
					p.instance.free()
	# The lever is additive-OR (as-built correction 2): naming &"lobber" on a shallow
	# band may LOAD the def but must spawn ZERO nodes (min_band=4 refuses every
	# placement). Assert zero SPAWNS, not zero loads.
	var def := load(LOBBER_DEF) as OppositionDef
	if def != null:
		var band := _make_band([16, 25, 25, 25, 25, 25, 25])
		for shallow_depth: int in [1, 2, 3]:
			var cells := _deck_spawn_cells_lever(band, shallow_depth)
			if not cells.is_empty():
				failures.append("(2) oppositions_enabled=[&\"lobber\"] spawned %d lobbers on a "
					% cells.size() + "band_depth-%d band (min_band 4 must refuse)" % shallow_depth)


## The rc.oppositions_enabled lever on a deck-LESS shallow profile, through the REAL
## builder + service — returns the lobber spawn cells (must be empty below band 4).
func _deck_spawn_cells_lever(band: Band, band_depth: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var profile := BandProfile.new()
	profile.id = &"synthetic_shallow"
	profile.band_depth = band_depth
	var rc := RunConfig.new()
	rc.oppositions_enabled.append(&"lobber")
	var container := Node2D.new()
	add_child(container)
	var svc := SpawnService.new()
	svc.begin_band(container, CELL, Vector2.INF, rc)
	EncounterBuilder.new().populate(band, profile, rc, svc)
	for node in svc.live_instances(&"lobber"):
		out.append(svc.spawn_cell_of(node))
	svc.clear_all()
	remove_child(container)
	container.free()
	svc.free()
	return out


# === (3) cycle timing + locked telemetry vocabulary ============================

func _case_cycle_timing(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 8001)
	gs.set_current_depth(4, 4)
	# blast_radius 0 = inert (trap_if_neutral — the shell always lands ON the live
	# player position, so distance never avoids contact; only the neutral radius does).
	var player := _make_player(Vector2(600, 0))
	var lob := _make_lobber(Vector2.ZERO, player,
		_params({ "fire_period_s": 0.4, "arc_time_s": 0.3, "blast_radius": 0.0,
			"kills": false }))

	# AIM (~24f) -> IN-FLIGHT (~18f) -> AIM again (the impact beat).
	var to_flight := await _await_phase(lob, MortarCycle.Phase.IN_FLIGHT, 45)
	if to_flight < 0:
		failures.append("(3) never fired (no IN-FLIGHT)")
	elif to_flight < 16 or to_flight > 32:
		failures.append("(3) AIM lasted %d frames, expected ~24 (0.4s)" % to_flight)
	var to_aim := await _await_phase(lob, MortarCycle.Phase.AIM, 30)
	if to_aim < 0:
		failures.append("(3) never impacted (no return to AIM)")
	elif to_aim < 12 or to_aim > 26:
		failures.append("(3) IN-FLIGHT lasted %d frames, expected ~18 (0.3s)" % to_aim)

	# Telemetry vocabulary: exactly one &"telegraph" (the shell), &"state" on impact.
	if _count_events(&"lobber", &"telegraph") != 1:
		failures.append("(3) expected exactly 1 telegraph row, got %d"
			% _count_events(&"lobber", &"telegraph"))
	if _count_events(&"lobber", &"state") != 1:
		failures.append("(3) expected exactly 1 state row (the impact), got %d"
			% _count_events(&"lobber", &"state"))
	for e: Array in _opp_events:
		if e[0] == &"lobber" and not [&"telegraph", &"state", &"hit_player"].has(e[1]):
			failures.append("(3) out-of-vocabulary opposition_event '%s' (S0 locked set)" % e[1])
	if _count_events(&"lobber", &"hit_player") != 0:
		failures.append("(3) a far-away shell registered &\"hit_player\"")
	if not gs.run_active:
		failures.append("(3) the far-away cycle ended the run")
	lob.queue_free()
	player.queue_free()
	await _frames(1)


# === (4) marker LOCKED at fire + the dodge window ===============================

func _case_marker_lock_dodge(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 8002)
	gs.set_current_depth(4, 4)
	# Lobber AWAY from the player (the blast lands away from the body); long flight
	# so the mid-flight step-off is unambiguous. kills=true — the dodge must save us.
	var player := _make_player(Vector2.ZERO)
	var lob := _make_lobber(Vector2(200, 0), player,
		_params({ "fire_period_s": 0.3, "arc_time_s": 0.5, "blast_radius": 48.0,
			"kills": true }))
	if await _await_phase(lob, MortarCycle.Phase.IN_FLIGHT, 30) < 0:
		failures.append("(4) never fired")
	var mortar := _mortar_of(lob)
	var marker_root: Node2D = lob.get_node_or_null("MarkerRoot")
	if mortar == null or marker_root == null:
		failures.append("(4) MortarCycle/MarkerRoot missing on the host")
	else:
		if not marker_root.visible:
			failures.append("(4) marker not visible during IN-FLIGHT (the dodge window)")
		if mortar.marker_point().distance_to(Vector2.ZERO) > 1.0:
			failures.append("(4) marker locked at %s, expected the fire-time player pos (0,0)"
				% str(mortar.marker_point()))
		if marker_root.global_position.distance_to(mortar.marker_point()) > 0.5:
			failures.append("(4) MarkerRoot not placed at the locked landing point")
	await _frames(6)   # mid-flight
	player.global_position = Vector2(0, 120)   # step 120 > 48 off the FROZEN point
	await _frames(2)
	if mortar != null and mortar.marker_point().distance_to(Vector2.ZERO) > 1.0:
		failures.append("(4) marker RE-TRACKED the moving player (must stay frozen): %s"
			% str(mortar.marker_point()))
	if marker_root != null and not marker_root.visible:
		failures.append("(4) marker hid mid-flight (must show for the full arc_time)")
	if await _await_phase(lob, MortarCycle.Phase.AIM, 40) < 0:
		failures.append("(4) never impacted")
	await _frames(2)
	if _count_events(&"lobber", &"hit_player") != 0:
		failures.append("(4) a dodge off the FROZEN marker was still hit")
	if not gs.run_active:
		failures.append("(4) the dodged shell ended the run")
	if marker_root != null and marker_root.visible:
		failures.append("(4) marker still visible after impact (must hide)")
	lob.queue_free()
	player.queue_free()
	await _frames(1)


# === (5) blast kill: kills-gated, centre-in-radius, BUG6 once ===================

func _case_blast_kill(gs: Node, failures: Array[String]) -> void:
	# (a) kills=true, player stays on the locked point -> death, each channel once.
	_reset_logs()
	gs.start_run(&"test_band", 8003)
	gs.set_current_depth(4, 4)
	var player := _make_player(Vector2.ZERO)
	var lob := _make_lobber(Vector2(200, 0), player,
		_params({ "fire_period_s": 0.3, "arc_time_s": 0.3, "blast_radius": 48.0,
			"kills": true }))
	if await _await_phase(lob, MortarCycle.Phase.IN_FLIGHT, 30) < 0:
		failures.append("(5a) never fired")
	if await _await_phase(lob, MortarCycle.Phase.AIM, 30) < 0:
		failures.append("(5a) never impacted")
	await _frames(2)
	if not _run_ended_reasons.has(&"death"):
		failures.append("(5a) on-marker player not killed via fail_run(&\"death\")")
	if gs.run_active:
		failures.append("(5a) run still active after a fatal impact")
	if _opp_killed.count(&"lobber") != 1:
		failures.append("(5a) opposition_killed_player(&\"lobber\") fired %d times, expected 1"
			% _opp_killed.count(&"lobber"))
	if _killed_kinds.count(&"lobber") != 1:
		failures.append("(5a) new_hazard_killed(&\"lobber\") fired %d times, expected 1 (BUG6)"
			% _killed_kinds.count(&"lobber"))
	if _count_events(&"lobber", &"hit_player") != 1:
		failures.append("(5a) hit_player rows %d, expected exactly 1 (latch)"
			% _count_events(&"lobber", &"hit_player"))
	lob.queue_free()
	player.queue_free()
	await _frames(1)

	# (b) kills=false, same geometry -> contact row fires, run survives, no gated pair.
	_reset_logs()
	gs.start_run(&"test_band", 8004)
	gs.set_current_depth(4, 4)
	var player2 := _make_player(Vector2.ZERO)
	var lob2 := _make_lobber(Vector2(200, 0), player2,
		_params({ "fire_period_s": 0.3, "arc_time_s": 0.3, "blast_radius": 48.0,
			"kills": false }))
	if await _await_phase(lob2, MortarCycle.Phase.IN_FLIGHT, 30) < 0:
		failures.append("(5b) never fired")
	if await _await_phase(lob2, MortarCycle.Phase.AIM, 30) < 0:
		failures.append("(5b) never impacted")
	await _frames(2)
	if _count_events(&"lobber", &"hit_player") != 1:
		failures.append("(5b) kills=false contact rows %d, expected exactly 1 (emit-always)"
			% _count_events(&"lobber", &"hit_player"))
	if not _opp_killed.is_empty():
		failures.append("(5b) kills=false emitted opposition_killed_player (must be gated)")
	if _run_ended_reasons.has(&"death") or not gs.run_active:
		failures.append("(5b) kills=false ended the run")
	lob2.queue_free()
	player2.queue_free()
	await _frames(1)


# === (6) geometry-ignoring: a wall protects NOTHING =============================

func _case_wall_ignored(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 8005)
	gs.set_current_depth(4, 4)
	var player := _make_player(Vector2(200, 0))
	var wall := _make_wall(Vector2(100, 0), Vector2(5, 60))   # world wall between them
	var lob := _make_lobber(Vector2.ZERO, player,
		_params({ "fire_period_s": 0.3, "arc_time_s": 0.3, "blast_radius": 48.0,
			"kills": true }))
	if await _await_phase(lob, MortarCycle.Phase.IN_FLIGHT, 30) < 0:
		failures.append("(6) never fired across the wall")
	var mortar := _mortar_of(lob)
	if mortar != null and mortar.marker_point().distance_to(Vector2(200, 0)) > 1.0:
		failures.append("(6) marker did not lock onto the player behind the wall: %s"
			% str(mortar.marker_point()))
	if await _await_phase(lob, MortarCycle.Phase.AIM, 30) < 0:
		failures.append("(6) never impacted")
	await _frames(2)
	if _count_events(&"lobber", &"hit_player") != 1:
		failures.append("(6) the shell did not land through the wall (hit_player %d != 1)"
			% _count_events(&"lobber", &"hit_player"))
	if gs.run_active or not _run_ended_reasons.has(&"death"):
		failures.append("(6) a wall protected the player from the arc (geometry must be ignored)")
	lob.queue_free()
	wall.queue_free()
	player.queue_free()
	await _frames(1)


# === (7) the rain continues (fire-period cycle) =================================

func _case_rain_continues(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 8006)
	gs.set_current_depth(4, 4)
	var player := _make_player(Vector2(600, 0))
	var lob := _make_lobber(Vector2.ZERO, player,
		_params({ "fire_period_s": 0.3, "arc_time_s": 0.2, "blast_radius": 0.0,
			"kills": false }))
	await _frames(80)   # ~2.6 full cycles (0.5s each)
	if _count_events(&"lobber", &"telegraph") < 2:
		failures.append("(7) expected >= 2 telegraph rows over a multi-cycle run, got %d"
			% _count_events(&"lobber", &"telegraph"))
	if _count_events(&"lobber", &"state") < 2:
		failures.append("(7) expected >= 2 impact (state) rows, got %d"
			% _count_events(&"lobber", &"state"))
	if not gs.run_active:
		failures.append("(7) the far-away rain ended the run")
	lob.queue_free()
	player.queue_free()
	await _frames(1)


# === (8) throw-killable, always — and the rain stops ============================

func _case_throw_kill(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 8007)
	gs.set_current_depth(4, 4)
	var player := _make_player(Vector2(600, 0))
	var lob := _make_lobber(Vector2.ZERO, player,
		_params({ "fire_period_s": 0.3, "arc_time_s": 0.2, "blast_radius": 0.0,
			"kills": false }))
	if lob.collision_layer != 16 or not lob.is_in_group(&"hazard"):
		failures.append("(8) Lobber not on layer 16 + 'hazard' group (must ALWAYS be a target)")
	var item := _make_thrown(lob.global_position)
	await _frames(6)
	if not _throw_kills.has(&"lobber"):
		failures.append("(8) a thrown item did not kill the Lobber (throw kinds: %s)"
			% str(_throw_kills))
	if is_instance_valid(lob) and not lob.is_queued_for_deletion():
		failures.append("(8) throw-killed Lobber still alive")
	var telegraphs_at_kill := _count_events(&"lobber", &"telegraph")
	await _frames(30)   # past what would have been the first/next fire
	if _count_events(&"lobber", &"telegraph") != telegraphs_at_kill:
		failures.append("(8) the rain continued after the throw-kill (%d -> %d telegraphs)"
			% [telegraphs_at_kill, _count_events(&"lobber", &"telegraph")])
	if is_instance_valid(item):
		item.queue_free()
	if is_instance_valid(lob):
		lob.queue_free()
	player.queue_free()
	await _frames(1)


# === (9) params flow def < DeckEntry < rc.param_overrides =======================

func _case_params_flow(failures: Array[String]) -> void:
	var def := load(LOBBER_DEF) as OppositionDef
	if def == null:
		failures.append("(9) lobber.tres missing")
		return
	var band := _make_band([16, 25, 25])
	# (a) deck-entry override alone -> the deck value wins over the def's 2.5.
	var fp_deck := _spawned_fire_period(def, band, { "fire_period_s": 1.7 }, {}, failures)
	if not is_equal_approx(fp_deck, 1.7):
		failures.append("(9) deck-entry override: effective fire_period_s %.3f != 1.7" % fp_deck)
	# (b) rc.param_overrides on top -> the rc value wins over both.
	var fp_rc := _spawned_fire_period(def, band, { "fire_period_s": 1.7 },
		{ "lobber": { "fire_period_s": 0.7 } }, failures)
	if not is_equal_approx(fp_rc, 0.7):
		failures.append("(9) rc override: effective fire_period_s %.3f != 0.7 (rc must win)" % fp_rc)


## Spawn ONE lobber through the REAL builder+service (deck wrapped in a DeckEntry
## carrying `deck_ov`; `rc_ov` into rc.param_overrides) and read the ENTITY's
## effective cadence off its MortarCycle (the locked-precedence assertion).
func _spawned_fire_period(def: OppositionDef, band: Band, deck_ov: Dictionary,
		rc_ov: Dictionary, failures: Array[String]) -> float:
	var entry := DeckEntry.new()
	entry.def = def
	entry.param_overrides = deck_ov
	var profile := BandProfile.new()
	profile.id = &"synthetic_band_four"
	profile.band_depth = 4
	var deck: Array[Resource] = [entry]
	profile.opposition_deck = deck
	var rc := RunConfig.new()
	rc.param_overrides = rc_ov
	var container := Node2D.new()
	add_child(container)
	var svc := SpawnService.new()
	svc.begin_band(container, CELL, Vector2.INF, rc)
	EncounterBuilder.new().populate(band, profile, rc, svc)
	var out := -1.0
	var live := svc.live_instances(&"lobber")
	if live.is_empty():
		failures.append("(9) builder+service spawned no lobber on a band-4 deck")
	else:
		var mortar := _mortar_of(live[0])
		if mortar == null:
			failures.append("(9) spawned lobber has no MortarCycle child")
		else:
			out = mortar.fire_period()
	svc.clear_all()
	remove_child(container)
	container.free()
	svc.free()
	return out


# === (10) deterministic placement + caps through the REAL builder + service =====

func _case_deterministic_placement(failures: Array[String]) -> void:
	var def := load(LOBBER_DEF) as OppositionDef
	if def == null:
		failures.append("(10) lobber.tres missing")
		return
	var band := _make_band([16, 25, 25, 25, 25, 25, 25])   # depths 0..6; 6 eligible pieces
	var cells_a := _deck_spawn_cells(def, band, 4, failures)
	var cells_b := _deck_spawn_cells(def, band, 4, failures)
	if cells_a.is_empty():
		failures.append("(10) band-depth-4 deck spawned no lobbers")
	if cells_a.size() != 5:
		failures.append("(10) spawned %d lobbers, expected per_band_cap = 5 to bind" % cells_a.size())
	if cells_a != cells_b:
		failures.append("(10) same band + config twice produced different spawn cells: %s vs %s"
			% [str(cells_a), str(cells_b)])
	# min_band = 4 refuses a band-depth-3 profile entirely (band-4-exclusivity, spawns).
	var cells_low := _deck_spawn_cells(def, band, 3, failures)
	if not cells_low.is_empty():
		failures.append("(10) min_band=4 lobber spawned at band_depth 3 (%d)" % cells_low.size())


func _deck_spawn_cells(def: OppositionDef, band: Band, band_depth: int,
		failures: Array[String]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var profile := BandProfile.new()
	profile.id = &"synthetic_band_four"
	profile.band_depth = band_depth
	var deck: Array[Resource] = [def]
	profile.opposition_deck = deck
	var rc := RunConfig.new()
	var container := Node2D.new()
	add_child(container)
	var svc := SpawnService.new()
	svc.begin_band(container, CELL, Vector2.INF, rc)
	EncounterBuilder.new().populate(band, profile, rc, svc)
	for node in svc.live_instances(&"lobber"):
		if node.get_script() == null \
				or String((node.get_script() as Script).get_global_name()) != "LobberHazard":
			failures.append("(10) service spawned a non-LobberHazard node for &\"lobber\"")
		out.append(svc.spawn_cell_of(node))
	svc.clear_all()
	remove_child(container)
	container.free()
	svc.free()
	return out


# === (11) cadence desync (positional; ctx phase_salt harness override) ==========

func _case_desync(gs: Node, failures: Array[String]) -> void:
	# Two lobbers at DIFFERENT spawn positions (no ctx salt -> positional derivation)
	# fire on DIFFERENT frames.
	_reset_logs()
	gs.start_run(&"test_band", 8008)
	gs.set_current_depth(4, 4)
	var player := _make_player(Vector2(600, 600))
	var pa := _params({ "fire_period_s": 0.5, "arc_time_s": 0.3, "blast_radius": 0.0,
		"kills": false })
	var a := _make_lobber(Vector2(0, 0), player, pa, false)      # positional salt 0
	var b := _make_lobber(Vector2(100, 0), player, pa, false)    # positional salt 3100
	var fa := -1
	var fb := -1
	for i in 90:
		if fa < 0 and a.phase() == MortarCycle.Phase.IN_FLIGHT:
			fa = i
		if fb < 0 and b.phase() == MortarCycle.Phase.IN_FLIGHT:
			fb = i
		if fa >= 0 and fb >= 0:
			break
		await get_tree().physics_frame
	if fa < 0 or fb < 0:
		failures.append("(11) a positional lobber never fired (fa=%d fb=%d)" % [fa, fb])
	elif fa == fb:
		failures.append("(11) two differently-placed lobbers fired in UNISON (frame %d) — "
			% fa + "positional desync failed")
	a.queue_free()
	b.queue_free()
	player.queue_free()
	await _frames(1)

	# The SAME explicit ctx phase_salt twice -> identical fire frame (deterministic;
	# the burrow_cycle.gd:98-101 harness-override mirror, Phase-3 OQ-9 amendment).
	_reset_logs()
	gs.start_run(&"test_band", 8009)
	gs.set_current_depth(4, 4)
	var player2 := _make_player(Vector2(600, 600))
	var c := _make_lobber(Vector2(0, 0), player2, pa, true, 5)
	var d := _make_lobber(Vector2(300, 0), player2, pa, true, 5)   # same salt, diff pos
	var fc := -1
	var fd := -1
	for i in 90:
		if fc < 0 and c.phase() == MortarCycle.Phase.IN_FLIGHT:
			fc = i
		if fd < 0 and d.phase() == MortarCycle.Phase.IN_FLIGHT:
			fd = i
		if fc >= 0 and fd >= 0:
			break
		await get_tree().physics_frame
	if fc < 0 or fd < 0:
		failures.append("(11) a salted lobber never fired (fc=%d fd=%d)" % [fc, fd])
	elif fc != fd:
		failures.append("(11) same phase_salt gave different fire frames (%d vs %d) — "
			% [fc, fd] + "not deterministic")
	c.queue_free()
	d.queue_free()
	player2.queue_free()
	await _frames(1)


# === (12) RNG-free ===============================================================

func _case_rng_free(failures: Array[String]) -> void:
	for path in ["res://scenes/hazards/components/mortar_cycle.gd",
			"res://scenes/hazards/lobber_hazard.gd"]:
		var src := FileAccess.get_file_as_string(path)
		if src.is_empty():
			failures.append("(12) could not read %s for the RNG audit" % path)
		elif "RNG." in src:
			failures.append("(12) %s references the global RNG autoload (must be RNG-free)" % path)


# --- harness plumbing -----------------------------------------------------------

## Fast-cycle test knobs (spawn_ctx["params"] — the deck lane's ctx-merge shape).
func _params(overrides: Dictionary) -> Dictionary:
	var p := {
		"fire_period_s": 0.4, "arc_time_s": 0.3, "blast_radius": 48.0,
		"lead_factor": 0.0, "kills": true,
	}
	for k: Variant in overrides:
		p[k] = overrides[k]
	return p


func _make_player(pos: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.global_position = pos
	add_child(p)
	return p


## use_salt=true adds an explicit ctx phase_salt (deterministic offset for timing
## tests); use_salt=false exercises the positional-derivation path (§5 / OQ-9).
func _make_lobber(pos: Vector2, player: Node2D, params: Dictionary,
		use_salt := true, salt := 0) -> LobberHazard:
	var scn := load(LOBBER_SCENE) as PackedScene
	var lob := scn.instantiate() as LobberHazard
	add_child(lob)
	lob.global_position = pos
	var ctx: Dictionary = { "params": params }
	if use_salt:
		ctx["phase_salt"] = salt
	lob.setup(RunConfig.new(), player, ctx)
	return lob


func _mortar_of(node: Node) -> MortarCycle:
	for child: Node in node.get_children():
		if child is MortarCycle:
			return child as MortarCycle
	return null


func _make_thrown(pos: Vector2) -> ThrownItem:
	var scn := load(THROWN_SCENE) as PackedScene
	var t := scn.instantiate() as ThrownItem
	add_child(t)
	t.global_position = pos
	var item := JunkItem.new()
	item.id = &"test_scrap"
	t.setup(item, Vector2.RIGHT, 0.0, 0.0, 3)   # parked: speed 0, no max-range miss
	return t


func _make_wall(pos: Vector2, half: Vector2) -> StaticBody2D:
	var w := StaticBody2D.new()
	w.collision_layer = 2      # `world` — geometry the arc must IGNORE
	w.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = half * 2.0
	cs.shape = sh
	w.add_child(cs)
	add_child(w)
	w.global_position = pos
	return w


## A graded linear synthetic band (the test_charger/test_burrower shape): piece at
## depth d has areas[d] floor cells in a contiguous block at x base d*100.
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


## Frames until the lobber reports `want` (or -1 after max_frames).
func _await_phase(lob: LobberHazard, want: int, max_frames: int) -> int:
	var n := 0
	while n < max_frames:
		if lob.phase() == want:
			return n
		await get_tree().physics_frame
		n += 1
	return -1 if lob.phase() != want else n


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
