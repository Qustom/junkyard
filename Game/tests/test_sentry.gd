extends Node
## Headless verification for U2b (M1.11 Wave 1) — the Sentry ("Gate-Sentry"): the
## at-range / projectile-emission Phase-E proof (sentry.tres + the ONE new LaneWatch
## component, everything else reused from the S2 set).
##
## Runs as a headless SCENE (test_sentry.tscn) so the EventBus / GameState autoloads
## resolve via the live SceneTree. Instantiates SentryHazard from sentry.tscn,
## setup()s it with a stub player + a spawn_ctx "params" bag (the deck lane's ctx
## merge shape), and advances REAL physics frames so LaneWatch's host-ticked FSM,
## the second-tick lane acquisition (A1), and the bolt's ray queries run as in-game.
##
## Asserts the U2b DoD (spec §3 + Resolved Decisions A1-A4 as amended by the
## breakdown's Phase-3 cross-task amendment 1):
##  (1) def contract: sentry.tres loads; id &"sentry"; the final spawn card
##      (min_band=4, credit_cost=2, cap_group=&"new_hazards", per_room_cap=1,
##      per_band_cap=5, kills); entity params mirror SentryHazard.DEFAULTS exactly;
##      per-def params<->param_schema bijection (count-agnostic — NO global def-count
##      assert, the M1.10 amendment-8 lesson); host contract (root class
##      SentryHazard, node "Sentry", &"hazard" group, get_def_id/resolve_throw_death);
##      Lane + Body + Bolt polygons triangulate to >0 (invisible-hazard guard).
##  (2) all-off gate: &"sentry" in neither RunConfig.new().oppositions_enabled nor
##      the default play preset nor band_greybox/band_two/band_three decks; the
##      all-off pipeline fingerprint e943ac9c8bc1 is untouched.
##  (3) lane geometry (A1/A2): authored lane_dir_deg=90 -> DOWN at full length;
##      derived pick = the single clear octant (walls close on the other 7), latched
##      on the SECOND tick; all-clear derive tie-breaks to CANDIDATES[0] (RIGHT);
##      a forced heading into a wall latches a SHORT _lane_len_eff, the strip visual
##      is drawn at that length (readability honesty), and a player beyond the
##      effective lane never triggers.
##  (4) windup lead honored (the fairness line): player in the lane -> exactly one
##      &"telegraph"; WINDUP holds ~windup_s; ZERO &"hit_player" and no visible bolt
##      before FIRE — the bolt NEVER fires before the authored flash elapses. All
##      &"sentry" rows stay inside the S0 locked vocabulary.
##  (5) bolt kill kills-gated: kills=true player on the lane axis -> fail_run
##      (&"death") + opposition_killed_player(&"sentry") once + new_hazard_killed
##      once + one &"hit_player" (BUG6); kills=false same geometry -> one contact
##      row, run stays active, no gated pair.
##  (6) bolt stopped by a wall: a world wall between muzzle and a player beyond it
##      -> zero &"hit_player", run active, bolt final position at/before the wall
##      face, FSM reaches COOLDOWN (stop-on-first-hit, no pierce — OQ-7).
##  (7) LOS suppresses fire: a wall between sentry and an in-strip player -> IDLE
##      never winds up (no &"telegraph"); the latched lane does NOT re-derive
##      (A2/A3); clearing the wall releases the windup.
##  (8) cooldown gap crossable (the fairness bar): authored cooldown_s >=
##      (lane_width + 2*PLAYER_R)/200 straight off the def; behaviourally COOLDOWN
##      holds ~cooldown_s, a player crossing the strip inside the gap takes no hit
##      and triggers no windup, and the sentry stays throw-killable (hazard group).
##  (9) throw-kill disables permanently: a thrown item at an IDLE sentry ->
##      throw_killed_hazard(&"sentry"), the sentry is freed, and no further windup
##      ever fires. The host never leaves the &"hazard" group in any state.
## (10) body never contact-lethal + trap-neutral: bolt_speed=0 with the player
##      parked point-blank in the lane -> full cycles run (telegraphs, cooldowns),
##      run stays active, zero &"hit_player" — only the bolt kills, and 0 = no bolt.
## (11) deterministic placement through the REAL builder+service: same synthetic
##      band_four-shaped band twice -> identical sentry spawn cells; per_band_cap=5
##      binds; min_band=4 refuses a band-depth-3 profile entirely.
## (12) RNG-free + structural: lane_watch.gd + sentry_hazard.gd contain no global
##      RNG-autoload reference; LaneWatch never touches group membership or the
##      host collision layer (always throw-killable, the simplest new-def shape).
## Run: godot --headless --path Game res://tests/test_sentry.tscn

const SENTRY_SCENE := "res://scenes/hazards/sentry.tscn"
const SENTRY_DEF := "res://data/oppositions/sentry.tres"
const THROWN_SCENE := "res://entities/thrown_item/thrown_item.tscn"
const GREYBOX_PROFILE := "res://data/bands/band_greybox.tres"
const BAND_TWO_PROFILE := "res://data/bands/band_two.tres"
const BAND_THREE_PROFILE := "res://data/bands/band_three.tres"
const BASELINE_FP := "e943ac9c8bc1"
const CELL := 16
const PLAYER_R := 14.0
const PLAYER_SPEED := 200.0

var _opp_events: Array = []                    # [id, event] pairs per opposition_event
var _opp_killed: Array[StringName] = []        # id per opposition_killed_player
var _killed_kinds: Array[StringName] = []      # kind per new_hazard_killed
var _run_ended_reasons: Array[StringName] = []
var _throw_kills: Array[StringName] = []       # kind per throw_killed_hazard


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: Array[String] = []

	var gs := get_node_or_null("/root/GameState")
	var eb := get_node_or_null("/root/EventBus")
	if gs == null or eb == null:
		printerr("SENTRY FAIL: GameState/EventBus autoload missing")
		get_tree().quit(1)
		return

	eb.opposition_event.connect(_on_opposition_event)
	eb.opposition_killed_player.connect(_on_opposition_killed)
	eb.new_hazard_killed.connect(_on_hazard_killed)
	eb.run_ended.connect(_on_run_ended)
	eb.throw_killed_hazard.connect(_on_throw_killed)

	_case_def_contract(failures)
	_case_all_off_gate(failures)
	await _case_lane_geometry(gs, failures)
	await _case_windup_lead(gs, failures)
	await _case_bolt_kill_gated(gs, failures)
	await _case_wall_blocks_bolt(gs, failures)
	await _case_los_suppression(gs, failures)
	await _case_cooldown_gap(gs, failures)
	await _case_throw_disable(gs, failures)
	await _case_body_nonlethal(gs, failures)
	_case_deterministic_placement(failures)
	_case_rng_free_structural(failures)

	if failures.is_empty():
		print("U2b OK — Sentry verified: def card locked (min_band 4 / cost 2 / caps 1+5, "
			+ "params mirror DEFAULTS), all-off gate holds (fp " + BASELINE_FP
			+ ", sentry in no default lever/preset/bands-1-3 deck), the lane is acquired on "
			+ "the SECOND tick with direction AND effective length latched (authored override, "
			+ "longest-sightline derive, fixed tie-break, short-lane honesty), the windup lead "
			+ "is honored (no bolt, no contact before the flash elapses), the bolt kill is "
			+ "kills-gated with the BUG6 latch firing exactly once, a world wall stops the "
			+ "bolt (no pierce) and a wall suppresses the windup (LOS gate), the cooldown gap "
			+ "is crossable at the authored numbers, a throw pops the always-hazard-group "
			+ "sentry permanently, the body is never contact-lethal (bolt_speed 0 = inert), "
			+ "deck placement is deterministic with per_band_cap/min_band enforced by the real "
			+ "service, and LaneWatch is RNG-free and never touches membership/collision.")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("SENTRY FAIL: ", f)
		get_tree().quit(1)


# === (1) def contract ==========================================================

func _case_def_contract(failures: Array[String]) -> void:
	var def := load(SENTRY_DEF) as OppositionDef
	if def == null:
		failures.append("(1) sentry.tres does not load as OppositionDef")
		return
	if def.id != &"sentry":
		failures.append("(1) def id %s != &\"sentry\"" % def.id)
	if def.min_band != 4:
		failures.append("(1) min_band %d != 4 (band-4 hard gate)" % def.min_band)
	if def.credit_cost != 2:
		failures.append("(1) credit_cost %d != 2 (A4/amendment-1 final card)" % def.credit_cost)
	if def.cap_group != &"new_hazards":
		failures.append("(1) cap_group %s != &\"new_hazards\"" % def.cap_group)
	if def.per_room_cap != 1:
		failures.append("(1) per_room_cap %d != 1 (anti-marker-soup, OQ-6)" % def.per_room_cap)
	if def.per_band_cap != 5:
		failures.append("(1) per_band_cap %d != 5 (A4: raised 4->5 for the U3 deck pin)" % def.per_band_cap)
	if not def.kills:
		failures.append("(1) typed kills field is false (ships lethal)")
	# Entity-read params mirror the host's code fallbacks exactly (no drift).
	for key: String in SentryHazard.DEFAULTS:
		if not def.params.has(key):
			failures.append("(1) def params missing entity key '%s'" % key)
		elif def.params[key] != SentryHazard.DEFAULTS[key]:
			failures.append("(1) def params['%s'] = %s != SentryHazard.DEFAULTS %s"
				% [key, str(def.params[key]), str(SentryHazard.DEFAULTS[key])])
	# Only the builder-read spawn-card keys may exist beyond the entity keys.
	for k: Variant in def.params.keys():
		var ks := String(k)
		if not SentryHazard.DEFAULTS.has(ks) and ks != "base_count" and ks != "count_per_depth":
			failures.append("(1) unexpected def param '%s' (not entity-read, not spawn-card)" % ks)
	# Per-def params<->param_schema bijection (the 11th def; count-agnostic — assert
	# the sentry's OWN bijection, never a global def count).
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
	if script == null or String(script.get_global_name()) != "SentryHazard":
		failures.append("(1) host root class != SentryHazard")
	if String(root.name) != "Sentry":
		failures.append("(1) host root node name '%s' != 'Sentry'" % root.name)
	if not root.is_in_group(&"hazard"):
		failures.append("(1) host root not in the 'hazard' group at author time")
	if not root.has_method(&"resolve_throw_death") or not root.has_method(&"get_def_id"):
		failures.append("(1) host root missing the S2 throw/def-id seams")
	elif StringName(root.call(&"get_def_id")) != &"sentry":
		failures.append("(1) get_def_id() != &\"sentry\"")
	# Lane + Body + Bolt must actually render (invisible-hazard guard).
	for node_name in ["Lane", "Body", "Bolt"]:
		var poly: Polygon2D = root.get_node_or_null(node_name)
		if poly == null or Geometry2D.triangulate_polygon(poly.polygon).is_empty():
			failures.append("(1) %s polygon triangulates to 0 triangles — renders NOTHING" % node_name)
	root.free()


# === (2) all-off gate ==========================================================

func _case_all_off_gate(failures: Array[String]) -> void:
	if RunConfig.new().oppositions_enabled.has(&"sentry"):
		failures.append("(2) all-off RunConfig lists &\"sentry\" in oppositions_enabled")
	if RunConfig.make_default_play_preset().oppositions_enabled.has(&"sentry"):
		failures.append("(2) the default play preset lists &\"sentry\"")
	for prof_path in [GREYBOX_PROFILE, BAND_TWO_PROFILE, BAND_THREE_PROFILE]:
		var profile := load(prof_path) as BandProfile
		if profile == null:
			continue
		for r in profile.opposition_deck:
			var raw: Resource = r
			if r is DeckEntry:
				raw = (r as DeckEntry).def
			var d := raw as OppositionDef
			if d != null and d.id == &"sentry":
				failures.append("(2) %s's deck lists the sentry (band-4-exclusive)" % prof_path)
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


# === (3) lane geometry: override, derive, tie-break, effective length (A1/A2) ===

func _case_lane_geometry(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 8001)
	gs.set_current_depth(4, 4)
	var player := _make_player(Vector2(5000, 5000))   # far — geometry only, no triggers

	# (a) authored override: lane_dir_deg = 90 -> DOWN, full length in a clear field.
	var s1 := _make_sentry(Vector2.ZERO, player, _params({ "lane_dir_deg": 90.0 }))
	await _frames(4)   # A1: acquisition on the SECOND tick — >= 2 physics frames
	if not s1.lane_acquired():
		failures.append("(3a) lane not acquired after 4 frames (A1 second-tick latch)")
	if s1.lane_dir().distance_to(Vector2.DOWN) > 0.001:
		failures.append("(3a) lane_dir_deg=90 gave dir %s, expected DOWN" % str(s1.lane_dir()))
	if absf(s1.lane_len_eff() - 300.0) > 0.5:
		failures.append("(3a) clear-field override lane_len_eff %.1f != lane_length 300" % s1.lane_len_eff())
	s1.queue_free()
	await _frames(1)

	# (b) derived longest-sightline: walls close on 7 octants, LEFT alone clear.
	var walls: Array[StaticBody2D] = []
	for wp: Vector2 in [Vector2(60, 0), Vector2(0, 60), Vector2(0, -60),
			Vector2(42, 42), Vector2(-42, 42), Vector2(-42, -42), Vector2(42, -42)]:
		walls.append(_make_wall(wp, Vector2(10, 10)))
	await _frames(2)   # walls into the broadphase BEFORE the sentry derives
	var s2 := _make_sentry(Vector2.ZERO, player, _params({ "lane_dir_deg": -1.0 }))
	await _frames(4)
	if s2.lane_dir().distance_to(Vector2.LEFT) > 0.001:
		failures.append("(3b) derived dir %s, expected LEFT (the single clear octant)" % str(s2.lane_dir()))
	if absf(s2.lane_len_eff() - 300.0) > 0.5:
		failures.append("(3b) derived clear lane_len_eff %.1f != 300" % s2.lane_len_eff())
	s2.queue_free()
	for w in walls:
		w.queue_free()
	await _frames(1)

	# (c) all-clear derive tie-breaks deterministically to CANDIDATES[0] (RIGHT).
	var s3 := _make_sentry(Vector2(2000, 2000), player, _params({ "lane_dir_deg": -1.0 }))
	await _frames(4)
	if s3.lane_dir().distance_to(Vector2.RIGHT) > 0.001:
		failures.append("(3c) all-clear derive gave %s, expected RIGHT (fixed tie-break)" % str(s3.lane_dir()))
	s3.queue_free()
	await _frames(1)

	# (d) forced heading into a wall: SHORT honest lane latched (A2) — the strip is
	# drawn at _lane_len_eff and a player beyond the effective lane never triggers.
	var wall := _make_wall(Vector2(6100, 0), Vector2(5, 40))   # face at x = 6095
	await _frames(2)
	var s4 := _make_sentry(Vector2(6000, 0), player, _params({ "lane_dir_deg": 0.0 }))
	await _frames(4)
	if s4.lane_len_eff() < 60.0 or s4.lane_len_eff() > 101.0:
		failures.append("(3d) wall at 95px gave lane_len_eff %.1f (expected ~95, A2 latch)" % s4.lane_len_eff())
	var strip: Polygon2D = s4.get_node_or_null("Lane")
	if strip == null:
		failures.append("(3d) Lane strip node missing")
	else:
		var max_x := 0.0
		for v: Vector2 in strip.polygon:
			max_x = maxf(max_x, v.x)
		if absf(max_x - s4.lane_len_eff()) > 0.5:
			failures.append("(3d) strip drawn to %.1f != lane_len_eff %.1f (readability lie)"
				% [max_x, s4.lane_len_eff()])
	player.global_position = Vector2(6150, 0)   # in the 300px strip, beyond the 95px lane
	await _frames(15)
	if s4.watch_state() != LaneWatch.State.IDLE or _count_events(&"sentry", &"telegraph") != 0:
		failures.append("(3d) a player BEYOND the effective lane triggered a windup")
	s4.queue_free()
	wall.queue_free()
	player.queue_free()
	await _frames(1)


# === (4) windup lead honored (the fairness line) ================================

func _case_windup_lead(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 8002)
	gs.set_current_depth(4, 4)
	var player := _make_player(Vector2(100, 0))    # parked in the lane
	var sen := _make_sentry(Vector2.ZERO, player,
		_params({ "windup_s": 0.5, "cooldown_s": 2.0, "kills": false }))
	if await _await_state(sen, LaneWatch.State.WINDUP, 12) < 0:
		failures.append("(4) never entered WINDUP with a player in the lane")
	if not sen.is_in_group(&"hazard"):
		failures.append("(4) sentry left the 'hazard' group in WINDUP (must never)")
	# Hold WINDUP ~0.5s (~30f): NO bolt, NO contact before FIRE.
	var bolt: Polygon2D = sen.get_node_or_null("Bolt")
	var windup_frames := 0
	while sen.watch_state() == LaneWatch.State.WINDUP and windup_frames < 60:
		if bolt != null and bolt.visible:
			failures.append("(4) bolt visible DURING the windup (fired before the flash)")
			break
		if _count_events(&"sentry", &"hit_player") != 0:
			failures.append("(4) a &\"hit_player\" fired during WINDUP (lethality leaked)")
			break
		await get_tree().physics_frame
		windup_frames += 1
	if windup_frames < 24 or windup_frames > 40:
		failures.append("(4) WINDUP held %d frames, expected ~30 (0.5s)" % windup_frames)
	if sen.watch_state() != LaneWatch.State.FIRE and sen.watch_state() != LaneWatch.State.COOLDOWN:
		failures.append("(4) WINDUP did not hand into FIRE")
	if _count_events(&"sentry", &"telegraph") != 1:
		failures.append("(4) expected exactly 1 telegraph row, got %d"
			% _count_events(&"sentry", &"telegraph"))
	await _frames(20)   # let the bolt finish
	for e: Array in _opp_events:
		if e[0] == &"sentry" and not [&"telegraph", &"state", &"hit_player"].has(e[1]):
			failures.append("(4) out-of-vocabulary opposition_event '%s' (S0 locked set)" % e[1])
	sen.queue_free()
	player.queue_free()
	await _frames(1)


# === (5) bolt kill kills-gated ===================================================

func _case_bolt_kill_gated(gs: Node, failures: Array[String]) -> void:
	# (a) kills=true, player on the lane axis at bolt range -> death, each channel once.
	_reset_logs()
	gs.start_run(&"test_band", 8003)
	gs.set_current_depth(4, 4)
	var player := _make_player(Vector2(150, 0))
	var sen := _make_sentry(Vector2.ZERO, player,
		_params({ "windup_s": 0.2, "cooldown_s": 2.0, "kills": true }))
	var died := false
	for _i in 60:
		if not gs.run_active:
			died = true
			break
		await get_tree().physics_frame
	if not died:
		failures.append("(5a) on-axis player not killed by the bolt")
	if not _run_ended_reasons.has(&"death"):
		failures.append("(5a) run did not end via fail_run(&\"death\")")
	if _opp_killed.count(&"sentry") != 1:
		failures.append("(5a) opposition_killed_player(&\"sentry\") fired %d times, expected 1"
			% _opp_killed.count(&"sentry"))
	if _killed_kinds.count(&"sentry") != 1:
		failures.append("(5a) new_hazard_killed(&\"sentry\") fired %d times, expected 1 (BUG6)"
			% _killed_kinds.count(&"sentry"))
	if _count_events(&"sentry", &"hit_player") != 1:
		failures.append("(5a) hit_player rows %d, expected exactly 1 (latch)"
			% _count_events(&"sentry", &"hit_player"))
	sen.queue_free()
	player.queue_free()
	await _frames(1)

	# (b) kills=false, same geometry -> one contact row, run survives, no gated pair.
	_reset_logs()
	gs.start_run(&"test_band", 8004)
	gs.set_current_depth(4, 4)
	var player2 := _make_player(Vector2(150, 0))
	var sen2 := _make_sentry(Vector2.ZERO, player2,
		_params({ "windup_s": 0.2, "cooldown_s": 3.0, "kills": false }))
	if await _await_state(sen2, LaneWatch.State.COOLDOWN, 60) < 0:
		failures.append("(5b) never completed a fire cycle")
	if _count_events(&"sentry", &"hit_player") != 1:
		failures.append("(5b) kills=false contact rows %d, expected exactly 1 (emit-always + latch)"
			% _count_events(&"sentry", &"hit_player"))
	if not _opp_killed.is_empty():
		failures.append("(5b) kills=false emitted opposition_killed_player (must be gated)")
	if _run_ended_reasons.has(&"death") or not gs.run_active:
		failures.append("(5b) kills=false ended the run")
	sen2.queue_free()
	player2.queue_free()
	await _frames(1)


# === (6) bolt stopped by a wall (stop-on-first-hit, no pierce) ===================

func _case_wall_blocks_bolt(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 8005)
	gs.set_current_depth(4, 4)
	var player := _make_player(Vector2(240, 0))
	# Slow bolt + long windup: the wall is inserted DURING the windup, after the lane
	# (full 400px, clear at acquisition) is latched — the mid-flight block test.
	var sen := _make_sentry(Vector2.ZERO, player,
		_params({ "windup_s": 0.6, "bolt_speed": 400.0, "lane_length": 400.0,
			"cooldown_s": 2.0, "kills": true }))
	if await _await_state(sen, LaneWatch.State.WINDUP, 12) < 0:
		failures.append("(6) never wound up")
	var wall := _make_wall(Vector2(120, 0), Vector2(5, 40))   # face at x = 115
	if await _await_state(sen, LaneWatch.State.COOLDOWN, 90) < 0:
		failures.append("(6) bolt cycle never completed against the wall")
	if _count_events(&"sentry", &"hit_player") != 0:
		failures.append("(6) the bolt hit a player BEHIND a wall (pierced cover)")
	if not gs.run_active:
		failures.append("(6) a wall-blocked bolt ended the run")
	if sen.bolt_position().x > 121.0:
		failures.append("(6) bolt stopped at x=%.1f, expected at/before the wall face ~115"
			% sen.bolt_position().x)
	sen.queue_free()
	wall.queue_free()
	player.queue_free()
	await _frames(1)


# === (7) LOS suppresses fire (and the latch never re-derives) ====================

func _case_los_suppression(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 8006)
	gs.set_current_depth(4, 4)
	var player := _make_player(Vector2(150, 200))   # out of the lane at acquisition
	var sen := _make_sentry(Vector2.ZERO, player, _params({ "kills": false }))
	await _frames(4)   # acquire (A1) with a clear field -> lane_len_eff = 300
	if absf(sen.lane_len_eff() - 300.0) > 0.5:
		failures.append("(7) clear-field acquisition lane_len_eff %.1f != 300" % sen.lane_len_eff())
	var wall := _make_wall(Vector2(80, 0), Vector2(5, 40))
	await _frames(2)   # wall into the broadphase
	player.global_position = Vector2(150, 0)        # in the strip, LOS blocked
	await _frames(20)
	if sen.watch_state() != LaneWatch.State.IDLE:
		failures.append("(7) sentry wound up on a player behind a wall (LOS gate failed)")
	if _count_events(&"sentry", &"telegraph") != 0:
		failures.append("(7) a telegraph fired with LOS blocked")
	if absf(sen.lane_len_eff() - 300.0) > 0.5:
		failures.append("(7) latched lane re-derived after the wall appeared (%.1f) — A2/A3 broken"
			% sen.lane_len_eff())
	wall.queue_free()
	await _frames(4)   # wall gone -> LOS clear -> windup releases
	if _count_events(&"sentry", &"telegraph") != 1:
		failures.append("(7) clearing the wall did not release the windup (telegraphs=%d)"
			% _count_events(&"sentry", &"telegraph"))
	sen.queue_free()
	player.queue_free()
	await _frames(1)


# === (8) cooldown gap crossable (the fairness bar) ===============================

func _case_cooldown_gap(gs: Node, failures: Array[String]) -> void:
	# Static: the authored def numbers satisfy the crossable bar.
	var def := load(SENTRY_DEF) as OppositionDef
	if def != null:
		var bar: float = (float(def.params["lane_width"]) + 2.0 * PLAYER_R) / PLAYER_SPEED
		if float(def.params["cooldown_s"]) < bar:
			failures.append("(8) authored cooldown_s %.2f < crossable bar %.2f"
				% [float(def.params["cooldown_s"]), bar])

	# Behavioural: COOLDOWN holds ~cooldown_s; a cross inside the gap takes no hit.
	_reset_logs()
	gs.start_run(&"test_band", 8007)
	gs.set_current_depth(4, 4)
	var player := _make_player(Vector2(100, 0))
	var sen := _make_sentry(Vector2.ZERO, player,
		_params({ "windup_s": 0.2, "cooldown_s": 1.0, "bolt_speed": 900.0,
			"lane_length": 200.0, "kills": false }))
	if await _await_state(sen, LaneWatch.State.COOLDOWN, 60) < 0:
		failures.append("(8) never reached COOLDOWN")
	if _count_events(&"sentry", &"hit_player") != 1:
		failures.append("(8) expected exactly 1 hit from the first bolt, got %d"
			% _count_events(&"sentry", &"hit_player"))
	if not sen.is_in_group(&"hazard"):
		failures.append("(8) sentry left the 'hazard' group in COOLDOWN (must never)")
	var telegraphs_before: int = _count_events(&"sentry", &"telegraph")
	player.global_position = Vector2(100, 150)      # step out of the strip
	# Cross the strip inside the gap: in at ~frame 10, out at ~frame 25 (of ~60).
	var cooldown_frames := 0
	while sen.watch_state() == LaneWatch.State.COOLDOWN and cooldown_frames < 90:
		if cooldown_frames == 10:
			player.global_position = Vector2(100, 0)
		if cooldown_frames == 25:
			player.global_position = Vector2(100, 150)
		await get_tree().physics_frame
		cooldown_frames += 1
	if cooldown_frames < 48 or cooldown_frames > 75:
		failures.append("(8) COOLDOWN held %d frames, expected ~60 (1.0s)" % cooldown_frames)
	if _count_events(&"sentry", &"hit_player") != 1:
		failures.append("(8) a player crossing inside the cooldown gap was hit")
	if _count_events(&"sentry", &"telegraph") != telegraphs_before:
		failures.append("(8) a windup fired DURING the cooldown gap")
	await _frames(6)   # back in IDLE, player out of lane -> stays IDLE
	if sen.watch_state() != LaneWatch.State.IDLE:
		failures.append("(8) did not settle back to IDLE with an empty lane")
	sen.queue_free()
	player.queue_free()
	await _frames(1)


# === (9) throw-kill disables permanently =========================================

func _case_throw_disable(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 8008)
	gs.set_current_depth(4, 4)
	var player := _make_player(Vector2(600, 0))   # beyond the 300px lane — stays IDLE
	var sen := _make_sentry(Vector2.ZERO, player, _params({ "kills": false }))
	await _frames(4)
	if sen.watch_state() != LaneWatch.State.IDLE:
		failures.append("(9) test mis-timed: sentry not IDLE")
	if not sen.is_in_group(&"hazard"):
		failures.append("(9) IDLE sentry not in the 'hazard' group (must always be throw-killable)")
	var item := _make_thrown(sen.global_position)
	await _frames(6)
	if not _throw_kills.has(&"sentry"):
		failures.append("(9) a thrown item did not kill the sentry (throw_killed_hazard kinds: %s)"
			% str(_throw_kills))
	if is_instance_valid(sen) and not sen.is_queued_for_deletion():
		failures.append("(9) throw-killed sentry still alive (permanent disable, DR-4)")
	# Permanently open: a player in the old lane never draws a new windup.
	player.global_position = Vector2(150, 0)
	await _frames(15)
	if _count_events(&"sentry", &"telegraph") != 0:
		failures.append("(9) a telegraph fired after the throw-kill (lane not opened)")
	if is_instance_valid(item):
		item.queue_free()
	if is_instance_valid(sen):
		sen.queue_free()
	player.queue_free()
	await _frames(1)


# === (10) body never contact-lethal + trap-neutral bolt_speed 0 ==================

func _case_body_nonlethal(gs: Node, failures: Array[String]) -> void:
	_reset_logs()
	gs.start_run(&"test_band", 8009)
	gs.set_current_depth(4, 4)
	# Player parked point-blank in the lane, hugging the body; bolt_speed 0 = no bolt
	# (trap_if_neutral) -> the FSM still cycles but NOTHING is ever lethal.
	var player := _make_player(Vector2(20, 0))
	var sen := _make_sentry(Vector2.ZERO, player,
		_params({ "windup_s": 0.2, "cooldown_s": 0.3, "bolt_speed": 0.0, "kills": true }))
	var saw_cooldown := false
	for _i in 80:
		if sen.watch_state() == LaneWatch.State.COOLDOWN:
			saw_cooldown = true
		if not gs.run_active:
			failures.append("(10) a boltless sentry killed a player hugging the body")
			break
		if _count_events(&"sentry", &"hit_player") != 0:
			failures.append("(10) a &\"hit_player\" fired with bolt_speed 0 (body lethality leaked)")
			break
		await get_tree().physics_frame
	if not saw_cooldown:
		failures.append("(10) trap-neutral cycle never reached COOLDOWN (FSM stuck)")
	if _count_events(&"sentry", &"telegraph") < 2:
		failures.append("(10) expected >= 2 windup cycles in ~1.3s, got %d telegraphs"
			% _count_events(&"sentry", &"telegraph"))
	sen.queue_free()
	player.queue_free()
	await _frames(1)


# === (11) deterministic placement through the REAL builder + service ============

func _case_deterministic_placement(failures: Array[String]) -> void:
	var def := load(SENTRY_DEF) as OppositionDef
	if def == null:
		failures.append("(11) sentry.tres missing")
		return
	var band := _make_band([16, 25, 25, 25, 25, 25, 25])   # depths 0..6; 6 eligible pieces
	var cells_a := _deck_spawn_cells(def, band, 4, failures)
	var cells_b := _deck_spawn_cells(def, band, 4, failures)
	if cells_a.is_empty():
		failures.append("(11) band-depth-4 deck spawned no sentries")
	if cells_a.size() != 5:
		failures.append("(11) spawned %d sentries, expected per_band_cap = 5 to bind" % cells_a.size())
	if cells_a != cells_b:
		failures.append("(11) same band + config twice produced different spawn cells: %s vs %s"
			% [str(cells_a), str(cells_b)])
	# min_band = 4 refuses a band-depth-3 profile entirely (band-4-exclusivity).
	var cells_low := _deck_spawn_cells(def, band, 3, failures)
	if not cells_low.is_empty():
		failures.append("(11) min_band=4 sentry spawned at band_depth 3 (%d)" % cells_low.size())


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
	for node in svc.live_instances(&"sentry"):
		if node.get_script() == null or String((node.get_script() as Script).get_global_name()) != "SentryHazard":
			failures.append("(11) service spawned a non-SentryHazard node for &\"sentry\"")
		out.append(svc.spawn_cell_of(node))
	svc.clear_all()
	remove_child(container)
	container.free()
	svc.free()
	return out


# === (12) RNG-free + structural (no membership / collision touch) ================

func _case_rng_free_structural(failures: Array[String]) -> void:
	for path in ["res://scenes/hazards/components/lane_watch.gd",
			"res://scenes/hazards/sentry_hazard.gd"]:
		var src := FileAccess.get_file_as_string(path)
		if src.is_empty():
			failures.append("(12) could not read %s for the source audit" % path)
			continue
		if "RNG." in src:
			failures.append("(12) %s references the global RNG autoload (must be RNG-free)" % path)
		if "remove_from_group" in src or "add_to_group" in src:
			failures.append("(12) %s touches group membership (the sentry must ALWAYS be throw-killable)" % path)
		if "collision_layer =" in src:
			failures.append("(12) %s reassigns collision_layer (no hittability cycling)" % path)


# --- harness plumbing -----------------------------------------------------------

## Fast-cycle test knobs (spawn_ctx["params"] — the deck lane's ctx-merge shape).
## lane_dir_deg defaults to 0 (forced RIGHT) so most cases have a known lane;
## geometry cases pass -1.0 to exercise the derive.
func _params(overrides: Dictionary) -> Dictionary:
	var p := {
		"windup_s": 0.2, "cooldown_s": 0.6, "bolt_speed": 700.0,
		"lane_length": 300.0, "lane_width": 28.0, "lane_always_visible": true,
		"fire_on_body_edge": false, "lane_dir_deg": 0.0, "kills": true,
	}
	for k: Variant in overrides:
		p[k] = overrides[k]
	return p


func _make_player(pos: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.global_position = pos
	add_child(p)
	return p


func _make_sentry(pos: Vector2, player: Node2D, params: Dictionary) -> SentryHazard:
	var scn := load(SENTRY_SCENE) as PackedScene
	var sen := scn.instantiate() as SentryHazard
	add_child(sen)
	sen.global_position = pos
	sen.setup(RunConfig.new(), player, { "params": params })
	return sen


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
	w.collision_layer = 2      # `world` — the layer LaneWatch's rays mask
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


## Frames until the sentry reports `want` (or -1 after max_frames).
func _await_state(sen: SentryHazard, want: int, max_frames: int) -> int:
	var n := 0
	while n < max_frames:
		if sen.watch_state() == want:
			return n
		await get_tree().physics_frame
		n += 1
	return -1 if sen.watch_state() != want else n


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


func _on_opposition_killed(id: StringName, _depth: int, _ms: int) -> void:
	_opp_killed.append(id)


func _on_hazard_killed(kind: StringName, _depth: int, _ms: int) -> void:
	_killed_kinds.append(kind)


func _on_run_ended(reason: StringName, _duration_s: float, _depth_reached: int) -> void:
	_run_ended_reasons.append(reason)


func _on_throw_killed(_item_id: StringName, kind: StringName, _depth: int, _ms: int) -> void:
	_throw_kills.append(kind)
