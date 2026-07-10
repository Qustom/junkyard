extends Node
## Headless verification for T2b (M1.10 Wave 1) — the Burrower ("Sinkmaw"): the
## phased-vulnerability Phase-E proof (burrower.tres + the ONE new BurrowCycle
## component, everything else reused from the S2 set).
##
## Runs as a headless SCENE (test_burrower.tscn) so the EventBus / GameState autoloads
## resolve via the live SceneTree. Instantiates BurrowerHazard from burrower.tscn,
## setup()s it with a stub player + a spawn_ctx "params" bag (the deck lane's ctx
## merge shape), and advances REAL physics frames so BurrowCycle's host-ticked FSM
## and the intersect_point wall guard run as in-game.
##
## Asserts the T2b DoD (spec §3.4 + Resolved Decisions / corrections):
##  (1) def contract: burrower.tres loads; id &"burrower"; the card (min_band=3,
##      credit_cost=2, cap_group=&"new_hazards", per_room_cap=1, per_band_cap=3,
##      kills); entity params mirror BurrowerHazard.DEFAULTS exactly (kill_radius 34);
##      host contract (root class BurrowerHazard, node "Burrower", &"hazard" group,
##      get_def_id/resolve_throw_death); Decal + Body polygons triangulate to >0.
##      (NO global def-count assert — the coverage net is dir-scanning + count-
##      agnostic; T2a lands 8->9 in the same wave.)
##  (2) all-off gate: &"burrower" in neither RunConfig.new().oppositions_enabled nor
##      the default play preset nor band_greybox/band_two decks; the all-off pipeline
##      fingerprint e943ac9c8bc1 is untouched.
##  (3) cycle timing from params: BURIED ~buried_s, TELEGRAPH ~telegraph_lead_s,
##      SURFACED ~surface_s, back to BURIED. Telemetry: exactly one &"telegraph" per
##      cycle + &"state" on surface/bury; no out-of-vocabulary token (S0 locked set).
##  (4) buried = throw passes through: BURIED body is collision_layer 0 + out of the
##      &"hazard" group; a thrown item over it does NOT kill, is NOT re-dropped, the
##      burrower survives.
##  (5) buried = non-lethal contact: player on the buried body through BURIED+TELEGRAPH
##      → run active, zero &"hit_player" (lethality armed only in SURFACED — the
##      surface-under-the-player-never-kills-inside-the-lead guarantee).
##  (6) dodge frame honored: lock_surface_at_telegraph=true; player steps
##      > kill_radius+PLAYER_R away during TELEGRAPH → at SURFACED zero &"hit_player",
##      run active (a fair dodge).
##  (7) surfaced kill is kills-gated + throw-killable: kills=true player on point →
##      fail_run(&"death") + opposition_killed_player(&"burrower") once +
##      new_hazard_killed once + one &"hit_player" (BUG6 latch); kills=false → contact
##      rows fire, run stays active, no opposition_killed; a thrown item at a SURFACED
##      body kills it (throw_killed_hazard &"burrower").
##  (8) wall-crossing while buried: a world wall between burrower and player; the
##      buried body direct-translates UNDER the wall toward the player. Rider: a body
##      whose buried timer expires while under a wall does NOT telegraph until clear.
##  (9) RNG-free: burrow_cycle.gd + burrower_hazard.gd contain no "RNG." substring.
## (10) positional desync: two burrowers at different spawn positions reach SURFACED
##      at DIFFERENT frames (positional salt); the same explicit phase_salt twice →
##      identical timeline (deterministic, RNG-free).
## (11) deterministic placement through the REAL builder+service: same synthetic
##      band_three-shaped band twice → identical burrower spawn cells; per_band_cap=3
##      binds; min_band=3 refuses a band-depth-2 profile.
## Run: godot --headless --path Game res://tests/test_burrower.tscn

const BURROWER_SCENE := "res://scenes/hazards/burrower.tscn"
const BURROWER_DEF := "res://data/oppositions/burrower.tres"
const THROWN_SCENE := "res://entities/thrown_item/thrown_item.tscn"
const GREYBOX_PROFILE := "res://data/bands/band_greybox.tres"
const BAND_TWO_PROFILE := "res://data/bands/band_two.tres"
const BASELINE_FP := "e943ac9c8bc1"
const CELL := 16
const PLAYER_R := 14.0

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
		printerr("BURROWER FAIL: GameState/EventBus autoload missing")
		get_tree().quit(1)
		return

	eb.opposition_event.connect(_on_opposition_event)
	eb.opposition_killed_player.connect(_on_opposition_killed)
	eb.run_ended.connect(_on_run_ended)
	eb.throw_missed.connect(_on_throw_missed)
	eb.junk_dropped.connect(_on_junk_dropped)

	_case_def_contract(failures)
	_case_all_off_gate(failures)
	await _case_cycle_timing(gs, failures)
	await _case_buried_passthrough(gs, failures)
	await _case_buried_nonlethal(gs, failures)
	await _case_dodge_frame(gs, failures)
	await _case_surfaced_kill(gs, failures)
	await _case_wall(gs, failures)
	_case_rng_free(failures)
	await _case_desync(gs, failures)
	_case_deterministic_placement(failures)

	if failures.is_empty():
		print("T2b OK — Burrower verified: def card locked (min_band 3 / cost 2 / caps 1+3, "
			+ "params mirror DEFAULTS incl kill_radius 34), all-off gate holds (fp " + BASELINE_FP
			+ ", burrower in no default lever/preset/band_greybox/band_two deck), the "
			+ "BURIED->TELEGRAPH->SURFACED cycle times out on the S0-locked telemetry "
			+ "vocabulary, a buried body passes a throw clean through + is non-lethal, the "
			+ "dodge frame is honored (locked decal, stepping off the lead is safe), the surfaced "
			+ "catch is kills-gated + throw-killable with the BUG6 latch firing exactly once, the "
			+ "buried body crosses under walls + never surfaces inside one, BurrowCycle is RNG-free, "
			+ "co-located burrowers desync by position, and deck placement is deterministic with "
			+ "per_band_cap/min_band enforced by the real service.")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("BURROWER FAIL: ", f)
		get_tree().quit(1)


# === (1) def contract ==========================================================

func _case_def_contract(failures: Array[String]) -> void:
	var def := load(BURROWER_DEF) as OppositionDef
	if def == null:
		failures.append("(1) burrower.tres does not load as OppositionDef")
		return
	if def.id != &"burrower":
		failures.append("(1) def id %s != &\"burrower\"" % def.id)
	if def.min_band != 3:
		failures.append("(1) min_band %d != 3 (band-3 hard gate)" % def.min_band)
	if def.credit_cost != 2:
		failures.append("(1) credit_cost %d != 2" % def.credit_cost)
	if def.cap_group != &"new_hazards":
		failures.append("(1) cap_group %s != &\"new_hazards\"" % def.cap_group)
	if def.per_room_cap != 1:
		failures.append("(1) per_room_cap %d != 1" % def.per_room_cap)
	if def.per_band_cap != 3:
		failures.append("(1) per_band_cap %d != 3" % def.per_band_cap)
	if not def.kills:
		failures.append("(1) typed kills field is false (ships lethal)")
	if float(def.params.get("kill_radius", 0.0)) != 34.0:
		failures.append("(1) def default kill_radius != 34.0 (Phase-3 physics correction)")
	# Entity-read params mirror the host's code fallbacks exactly (no drift).
	for key: String in BurrowerHazard.DEFAULTS:
		if not def.params.has(key):
			failures.append("(1) def params missing entity key '%s'" % key)
		elif def.params[key] != BurrowerHazard.DEFAULTS[key]:
			failures.append("(1) def params['%s'] = %s != BurrowerHazard.DEFAULTS %s"
				% [key, str(def.params[key]), str(BurrowerHazard.DEFAULTS[key])])
	# Only the builder-read spawn-card keys may exist beyond the entity keys.
	for k: Variant in def.params.keys():
		var ks := String(k)
		if not BurrowerHazard.DEFAULTS.has(ks) and ks != "base_count" and ks != "count_per_depth":
			failures.append("(1) unexpected def param '%s' (not entity-read, not spawn-card)" % ks)
	# Per-def params<->param_schema bijection (the 9th def; count-agnostic — assert the
	# burrower's OWN bijection, never a global def count).
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
	if script == null or String(script.get_global_name()) != "BurrowerHazard":
		failures.append("(1) host root class != BurrowerHazard")
	if String(root.name) != "Burrower":
		failures.append("(1) host root node name '%s' != 'Burrower'" % root.name)
	if not root.is_in_group(&"hazard"):
		failures.append("(1) host root not in the 'hazard' group at author time")
	if not root.has_method(&"resolve_throw_death") or not root.has_method(&"get_def_id"):
		failures.append("(1) host root missing the S2 throw/def-id seams")
	elif StringName(root.call(&"get_def_id")) != &"burrower":
		failures.append("(1) get_def_id() != &\"burrower\"")
	# Decal + Body must actually render (invisible-hazard guard).
	var decal: Polygon2D = root.get_node_or_null("Decal")
	if decal == null or Geometry2D.triangulate_polygon(decal.polygon).is_empty():
		failures.append("(1) Decal polygon triangulates to 0 triangles — renders NOTHING")
	var body: Polygon2D = root.get_node_or_null("Body")
	if body == null or Geometry2D.triangulate_polygon(body.polygon).is_empty():
		failures.append("(1) Body polygon triangulates to 0 triangles — renders NOTHING")
	root.free()


# === (2) all-off gate ==========================================================

func _case_all_off_gate(failures: Array[String]) -> void:
	if RunConfig.new().oppositions_enabled.has(&"burrower"):
		failures.append("(2) all-off RunConfig lists &\"burrower\" in oppositions_enabled")
	if RunConfig.make_default_play_preset().oppositions_enabled.has(&"burrower"):
		failures.append("(2) the default play preset lists &\"burrower\"")
	for prof_path in [GREYBOX_PROFILE, BAND_TWO_PROFILE]:
		var profile := load(prof_path) as BandProfile
		if profile == null:
			continue   # band_two may not exist yet in this worktree; skip silently
		for r in profile.opposition_deck:
			var d := r as OppositionDef
			if d != null and d.id == &"burrower":
				failures.append("(2) %s's deck lists the burrower (band-3-exclusive)" % prof_path)
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


# === (3) cycle timing + locked telemetry vocabulary ============================

func _case_cycle_timing(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 7001)
	gs.set_current_depth(3, 3)
	# Player far away → surfacing never contacts (kill_radius irrelevant); track_speed
	# low so it stays put over the short window.
	var player := _make_player(Vector2(600, 0))
	var bur := _make_burrower(Vector2.ZERO, player,
		_params({ "buried_s": 0.3, "telegraph_lead_s": 0.2, "surface_s": 0.3,
			"track_speed": 0.0, "kills": false }))

	# BURIED (~18f) → TELEGRAPH (~12f) → SURFACED (~18f) → BURIED again.
	var to_tele := await _await_phase(bur, BurrowCycle.Phase.TELEGRAPH, 40)
	if to_tele < 0:
		failures.append("(3) never entered TELEGRAPH")
	elif to_tele < 12 or to_tele > 26:
		failures.append("(3) BURIED lasted %d frames, expected ~18 (0.3s)" % to_tele)
	var to_surf := await _await_phase(bur, BurrowCycle.Phase.SURFACED, 30)
	if to_surf < 0:
		failures.append("(3) never entered SURFACED")
	elif to_surf < 7 or to_surf > 18:
		failures.append("(3) TELEGRAPH lasted %d frames, expected ~12 (0.2s)" % to_surf)
	var to_bury := await _await_phase(bur, BurrowCycle.Phase.BURIED, 40)
	if to_bury < 0:
		failures.append("(3) never re-buried")
	elif to_bury < 12 or to_bury > 26:
		failures.append("(3) SURFACED lasted %d frames, expected ~18 (0.3s)" % to_bury)

	# Telemetry vocabulary: exactly one &"telegraph", &"state" on surface + bury.
	if _count_events(&"burrower", &"telegraph") != 1:
		failures.append("(3) expected exactly 1 telegraph row, got %d"
			% _count_events(&"burrower", &"telegraph"))
	if _count_events(&"burrower", &"state") < 2:
		failures.append("(3) expected >= 2 state rows (surface + bury), got %d"
			% _count_events(&"burrower", &"state"))
	for e: Array in _opp_events:
		if e[0] == &"burrower" and not [&"telegraph", &"state", &"hit_player"].has(e[1]):
			failures.append("(3) out-of-vocabulary opposition_event '%s' (S0 locked set)" % e[1])
	if not gs.run_active:
		failures.append("(3) the far-away cycle ended the run")
	bur.queue_free()
	player.queue_free()
	await _frames(1)


# === (4) buried = throw passes clean through ===================================

func _case_buried_passthrough(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 7002)
	gs.set_current_depth(3, 3)
	var player := _make_player(Vector2(600, 0))
	# Long buried window, stationary → the body sits at origin, buried, the whole test.
	var bur := _make_burrower(Vector2.ZERO, player,
		_params({ "buried_s": 4.0, "track_speed": 0.0, "kills": false }))
	await _frames(4)   # settle into BURIED
	if bur.phase() != BurrowCycle.Phase.BURIED:
		failures.append("(4) test mis-timed: burrower not BURIED")
	if bur.collision_layer != 0:
		failures.append("(4) buried body collision_layer %d != 0 (throw must pass through)"
			% bur.collision_layer)
	if bur.is_in_group(&"hazard"):
		failures.append("(4) buried body still in the 'hazard' group")
	# Park a thrown item directly on the buried body.
	var item := _make_thrown(bur.global_position)
	await _frames(15)
	if not _throw_kills.is_empty():
		failures.append("(4) a throw killed a BURIED burrower (must pass through): %s" % str(_throw_kills))
	if not is_instance_valid(bur) or bur.is_queued_for_deletion():
		failures.append("(4) BURIED burrower was destroyed by a passing throw")
	if _junk_drops != 0 or _throw_misses != 0:
		failures.append("(4) the throw re-dropped at the buried body's feet (drops=%d misses=%d)"
			% [_junk_drops, _throw_misses])
	if is_instance_valid(item):
		item.queue_free()
	bur.queue_free()
	player.queue_free()
	await _frames(1)


# === (5) buried = non-lethal contact ===========================================

func _case_buried_nonlethal(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 7003)
	gs.set_current_depth(3, 3)
	# Player parked ON the (stationary) buried body through BURIED + TELEGRAPH.
	var player := _make_player(Vector2.ZERO)
	var bur := _make_burrower(Vector2.ZERO, player,
		_params({ "buried_s": 0.3, "telegraph_lead_s": 0.3, "surface_s": 0.5,
			"track_speed": 0.0, "kills": true }))
	# Every frame until it surfaces must be non-lethal (the dodge frame guarantee).
	var reached_surface := false
	for _i in 60:
		if bur.phase() == BurrowCycle.Phase.SURFACED:
			reached_surface = true
			break
		if not gs.run_active:
			failures.append("(5) a BURIED/TELEGRAPH burrower killed the player on it")
			break
		if _count_events(&"burrower", &"hit_player") != 0:
			failures.append("(5) a &\"hit_player\" fired before SURFACED (lethality leaked)")
			break
		await get_tree().physics_frame
	if not reached_surface:
		failures.append("(5) burrower never reached SURFACED (test mis-timed)")
	bur.queue_free()
	player.queue_free()
	await _frames(1)


# === (6) dodge frame honored ===================================================

func _case_dodge_frame(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 7004)
	gs.set_current_depth(3, 3)
	# lock=true, player on the tracked point at telegraph start, steps clear during
	# the lead. kill_radius 34 → clearing 34 + PLAYER_R = 48 px is a guaranteed dodge.
	var player := _make_player(Vector2.ZERO)
	var bur := _make_burrower(Vector2.ZERO, player,
		_params({ "buried_s": 0.3, "telegraph_lead_s": 0.4, "surface_s": 0.5,
			"track_speed": 0.0, "kill_radius": 34.0, "lock_surface_at_telegraph": true,
			"kills": true }))
	if await _await_phase(bur, BurrowCycle.Phase.TELEGRAPH, 40) < 0:
		failures.append("(6) never telegraphed")
	player.global_position = Vector2(0, 60)   # 60 > 48 — well clear of the LOCKED point
	if await _await_phase(bur, BurrowCycle.Phase.SURFACED, 40) < 0:
		failures.append("(6) never surfaced")
	await _frames(3)
	if _count_events(&"burrower", &"hit_player") != 0:
		failures.append("(6) a dodge off the LOCKED decal was still hit")
	if not gs.run_active:
		failures.append("(6) the dodged surfacing ended the run")
	bur.queue_free()
	player.queue_free()
	await _frames(1)


# === (7) surfaced kill: kills-gated + throw-killable ===========================

func _case_surfaced_kill(gs: Node, failures: Array[String]) -> void:
	# (a) kills=true, player stays on the point → death, each channel exactly once.
	_reset_logs()
	gs.start_run(&"test_band", 7005)
	gs.set_current_depth(3, 3)
	var player := _make_player(Vector2.ZERO)
	var bur := _make_burrower(Vector2.ZERO, player,
		_params({ "buried_s": 0.3, "telegraph_lead_s": 0.2, "surface_s": 0.6,
			"track_speed": 0.0, "kill_radius": 34.0, "kills": true }))
	# Reach + confirm the FIRST surface's kill; stop before any re-surface (a second
	# surface would re-arm + re-fire the gated pair).
	if await _await_phase(bur, BurrowCycle.Phase.SURFACED, 45) < 0:
		failures.append("(7a) never surfaced")
	await _frames(4)
	if not _run_ended_reasons.has(&"death"):
		failures.append("(7a) on-point player not killed via fail_run(&\"death\")")
	if gs.run_active:
		failures.append("(7a) run still active after a fatal surface")
	if _opp_killed.count(&"burrower") != 1:
		failures.append("(7a) opposition_killed_player(&\"burrower\") fired %d times, expected 1"
			% _opp_killed.count(&"burrower"))
	if _killed_kinds.count(&"burrower") != 1:
		failures.append("(7a) new_hazard_killed(&\"burrower\") fired %d times, expected 1 (BUG6)"
			% _killed_kinds.count(&"burrower"))
	if _count_events(&"burrower", &"hit_player") != 1:
		failures.append("(7a) hit_player rows %d, expected exactly 1 (latch)"
			% _count_events(&"burrower", &"hit_player"))
	bur.queue_free()
	player.queue_free()
	await _frames(1)

	# (b) kills=false, same geometry → contact rows fire, run survives, no gated pair.
	_reset_logs()
	gs.start_run(&"test_band", 7006)
	gs.set_current_depth(3, 3)
	var player2 := _make_player(Vector2.ZERO)
	var bur2 := _make_burrower(Vector2.ZERO, player2,
		_params({ "buried_s": 0.3, "telegraph_lead_s": 0.2, "surface_s": 0.6,
			"track_speed": 0.0, "kill_radius": 34.0, "kills": false }))
	if await _await_phase(bur2, BurrowCycle.Phase.SURFACED, 45) < 0:
		failures.append("(7b) never surfaced")
	await _frames(4)
	if _count_events(&"burrower", &"hit_player") != 1:
		failures.append("(7b) kills=false contact rows %d, expected exactly 1 (emit-always + latch)"
			% _count_events(&"burrower", &"hit_player"))
	if not _opp_killed.is_empty():
		failures.append("(7b) kills=false emitted opposition_killed_player (must be gated)")
	if _run_ended_reasons.has(&"death") or not gs.run_active:
		failures.append("(7b) kills=false ended the run")
	bur2.queue_free()
	player2.queue_free()
	await _frames(1)

	# (c) a thrown item at a SURFACED body kills it (throw-killable while surfaced).
	_reset_logs()
	gs.start_run(&"test_band", 7007)
	gs.set_current_depth(3, 3)
	var player3 := _make_player(Vector2(600, 0))   # far → the lethal test never contacts
	var bur3 := _make_burrower(Vector2.ZERO, player3,
		_params({ "buried_s": 0.3, "telegraph_lead_s": 0.2, "surface_s": 0.8,
			"track_speed": 0.0, "kills": false }))
	if await _await_phase(bur3, BurrowCycle.Phase.SURFACED, 45) < 0:
		failures.append("(7c) never surfaced")
	if bur3.collision_layer != 16 or not bur3.is_in_group(&"hazard"):
		failures.append("(7c) surfaced body not restored to layer 16 + 'hazard' group")
	var item := _make_thrown(bur3.global_position)
	await _frames(6)
	if not _throw_kills.has(&"burrower"):
		failures.append("(7c) SURFACED throw did not kill (throw_killed_hazard kinds: %s)"
			% str(_throw_kills))
	if is_instance_valid(bur3) and not bur3.is_queued_for_deletion():
		failures.append("(7c) throw-killed burrower still alive")
	if is_instance_valid(item):
		item.queue_free()
	if is_instance_valid(bur3):
		bur3.queue_free()
	player3.queue_free()
	await _frames(1)


# === (8) wall-crossing while buried + the wall-surface guard ====================

func _case_wall(gs: Node, failures: Array[String]) -> void:
	# (a) the buried body direct-translates UNDER a world wall toward the player.
	_reset_logs()
	gs.start_run(&"test_band", 7008)
	gs.set_current_depth(3, 3)
	var player := _make_player(Vector2(200, 0))
	var wall := _make_wall(Vector2(50, 0), Vector2(5, 60))   # spans x [45,55]
	var bur := _make_burrower(Vector2.ZERO, player,
		_params({ "buried_s": 10.0, "track_speed": 300.0, "kills": false }))
	await _frames(30)   # 0.5s @ 300px/s ≈ 150px (clamped short of the 200px player)
	if bur.phase() != BurrowCycle.Phase.BURIED:
		failures.append("(8a) burrower left BURIED during the long buried window")
	if bur.global_position.x <= 60.0:
		failures.append("(8a) buried body did not cross under the wall (x=%.1f, wall face 55)"
			% bur.global_position.x)
	bur.queue_free()
	wall.queue_free()
	player.queue_free()
	await _frames(1)

	# (b) a body whose buried timer expires UNDER a wall must NOT telegraph until clear.
	_reset_logs()
	gs.start_run(&"test_band", 7009)
	gs.set_current_depth(3, 3)
	var player2 := _make_player(Vector2(200, 0))
	var wall2 := _make_wall(Vector2.ZERO, Vector2(30, 30))   # covers the origin
	var bur2 := _make_burrower(Vector2.ZERO, player2,
		_params({ "buried_s": 0.3, "track_speed": 0.0, "kills": false }))
	await _frames(30)   # well past buried_s (18f) — but stuck under the wall
	if bur2.phase() != BurrowCycle.Phase.BURIED:
		failures.append("(8b) burrower surfaced INSIDE a wall (guard failed) — phase %d"
			% bur2.phase())
	# Clear the wall → the guard releases and it telegraphs.
	wall2.queue_free()
	await _frames(6)
	if bur2.phase() == BurrowCycle.Phase.BURIED:
		failures.append("(8b) burrower stayed buried after the wall cleared (guard stuck)")
	bur2.queue_free()
	player2.queue_free()
	await _frames(1)


# === (9) RNG-free ===============================================================

func _case_rng_free(failures: Array[String]) -> void:
	for path in ["res://scenes/hazards/components/burrow_cycle.gd",
			"res://scenes/hazards/burrower_hazard.gd"]:
		var src := FileAccess.get_file_as_string(path)
		if src.is_empty():
			failures.append("(9) could not read %s for the RNG audit" % path)
		elif "RNG." in src:
			failures.append("(9) %s references the global RNG autoload (must be RNG-free)" % path)


# === (10) positional desync ====================================================

func _case_desync(gs: Node, failures: Array[String]) -> void:
	# Two burrowers at DIFFERENT spawn positions (no ctx salt → positional derivation)
	# reach SURFACED at DIFFERENT frames.
	_reset_logs()
	gs.start_run(&"test_band", 7010)
	gs.set_current_depth(3, 3)
	var player := _make_player(Vector2(600, 600))
	var pa := _params({ "buried_s": 0.5, "telegraph_lead_s": 0.2, "surface_s": 0.5,
		"track_speed": 0.0, "kill_radius": 0.0, "kills": false })
	var a := _make_burrower(Vector2(0, 0), player, pa, false)      # positional salt 0
	var b := _make_burrower(Vector2(100, 0), player, pa, false)    # positional salt 3100
	var fa := -1
	var fb := -1
	for i in 90:
		if fa < 0 and a.phase() == BurrowCycle.Phase.SURFACED:
			fa = i
		if fb < 0 and b.phase() == BurrowCycle.Phase.SURFACED:
			fb = i
		if fa >= 0 and fb >= 0:
			break
		await get_tree().physics_frame
	if fa < 0 or fb < 0:
		failures.append("(10) a positional burrower never surfaced (fa=%d fb=%d)" % [fa, fb])
	elif fa == fb:
		failures.append("(10) two co-located-position burrowers popped in UNISON (frame %d) — "
			% fa + "positional desync failed")
	a.queue_free()
	b.queue_free()
	player.queue_free()
	await _frames(1)

	# The SAME explicit phase_salt twice → identical surface frame (deterministic).
	_reset_logs()
	gs.start_run(&"test_band", 7011)
	gs.set_current_depth(3, 3)
	var player2 := _make_player(Vector2(600, 600))
	var c := _make_burrower(Vector2(0, 0), player2, pa, true, 5)
	var d := _make_burrower(Vector2(300, 0), player2, pa, true, 5)   # same salt, diff pos
	var fc := -1
	var fd := -1
	for i in 90:
		if fc < 0 and c.phase() == BurrowCycle.Phase.SURFACED:
			fc = i
		if fd < 0 and d.phase() == BurrowCycle.Phase.SURFACED:
			fd = i
		if fc >= 0 and fd >= 0:
			break
		await get_tree().physics_frame
	if fc < 0 or fd < 0:
		failures.append("(10) a salted burrower never surfaced (fc=%d fd=%d)" % [fc, fd])
	elif fc != fd:
		failures.append("(10) same phase_salt gave different surface frames (%d vs %d) — "
			% [fc, fd] + "not deterministic")
	c.queue_free()
	d.queue_free()
	player2.queue_free()
	await _frames(1)


# === (11) deterministic placement through the REAL builder + service ===========

func _case_deterministic_placement(failures: Array[String]) -> void:
	var def := load(BURROWER_DEF) as OppositionDef
	if def == null:
		failures.append("(11) burrower.tres missing")
		return
	var band := _make_band([16, 25, 25, 25, 25, 25, 25])   # depths 0..6; 6 eligible pieces
	var cells_a := _deck_spawn_cells(def, band, 3, failures)
	var cells_b := _deck_spawn_cells(def, band, 3, failures)
	if cells_a.is_empty():
		failures.append("(11) band-depth-3 deck spawned no burrowers")
	if cells_a.size() != 3:
		failures.append("(11) spawned %d burrowers, expected per_band_cap = 3 to bind" % cells_a.size())
	if cells_a != cells_b:
		failures.append("(11) same band + config twice produced different spawn cells: %s vs %s"
			% [str(cells_a), str(cells_b)])
	# min_band = 3 refuses a band-depth-2 profile entirely (band-3-exclusivity).
	var cells_low := _deck_spawn_cells(def, band, 2, failures)
	if not cells_low.is_empty():
		failures.append("(11) min_band=3 burrower spawned at band_depth 2 (%d)" % cells_low.size())


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
	for node in svc.live_instances(&"burrower"):
		if node.get_script() == null or String((node.get_script() as Script).get_global_name()) != "BurrowerHazard":
			failures.append("(11) service spawned a non-BurrowerHazard node for &\"burrower\"")
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
		"buried_s": 0.3, "surface_s": 0.3, "track_speed": 80.0,
		"telegraph_lead_s": 0.2, "kill_radius": 34.0,
		"lock_surface_at_telegraph": true, "kills": true,
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
## tests); use_salt=false exercises the positional-derivation path (§5 / correction 1).
func _make_burrower(pos: Vector2, player: Node2D, params: Dictionary,
		use_salt := true, salt := 0) -> BurrowerHazard:
	var scn := load(BURROWER_SCENE) as PackedScene
	var bur := scn.instantiate() as BurrowerHazard
	add_child(bur)
	bur.global_position = pos
	var ctx: Dictionary = { "params": params }
	if use_salt:
		ctx["phase_salt"] = salt
	bur.setup(RunConfig.new(), player, ctx)
	return bur


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
	w.collision_layer = 2      # `world` — the layer the burrower's surface guard masks
	w.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = half * 2.0
	cs.shape = sh
	w.add_child(cs)
	add_child(w)
	w.global_position = pos
	return w


## A graded linear synthetic band (the test_charger shape): piece at depth d has
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


## Frames until the burrower reports `want` (or -1 after max_frames).
func _await_phase(bur: BurrowerHazard, want: int, max_frames: int) -> int:
	var n := 0
	while n < max_frames:
		if bur.phase() == want:
			return n
		await get_tree().physics_frame
		n += 1
	return -1 if bur.phase() != want else n


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
