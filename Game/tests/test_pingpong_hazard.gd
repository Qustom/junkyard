extends Node
## Headless acceptance test for K5a (M1.4) — the PingPongHazard greybox bouncer entity.
##
## Run as a SCENE (autoloads + a live tree) so GameState/EventBus resolve as in the real
## game and the entity's _physics_process / move_and_slide have a real tree:
##   godot --headless res://tests/test_pingpong_hazard.tscn
##
## Asserts (per the K5a spec §7 test hooks + the Resolved Decisions):
##   (a) SAFE CONSTRUCTION: setup(cfg, player) with an EMPTY spawn_ctx constructs without
##       error — velocity points along the default RIGHT heading, no clamp engaged. An
##       unwired instance (K5i hands an empty dict) is still valid.
##   (b) INITIAL HEADING: spawn_ctx["initial_dir"] sets velocity = dir.normalized() * speed
##       (deterministic, RNG-free — the heading is supplied, never drawn).
##   (c) ROOM-RECT CLAMP (OQ-1): a body pushed past a room_bounds edge is reflected (the
##       perpendicular velocity component flips) and snapped back inside the rect.
##   (d) DISTANCE-TEST KILL: with the player inside CONTACT_RADIUS, one physics step ends
##       the run via the existing fatal path (GameState.run_active flips false, cause death),
##       and new_hazard_killed(&"pingpong", depth, run_t_ms) fires EXACTLY ONCE (BUG6 latch).
##   (e) NO RNG: the entity script source contains no global RNG autoload call (determinism).

const PINGPONG_SCENE_PATH := "res://scenes/hazards/pingpong_hazard.tscn"
const PINGPONG_SCRIPT_PATH := "res://scenes/hazards/pingpong_hazard.gd"
const COMPONENTS_DIR := "res://scenes/hazards/components"

var _killed_events: Array = []


func _ready() -> void:
	get_tree().quit(await _run())


func _run() -> int:
	var failures: Array[String] = []

	var scene := load(PINGPONG_SCENE_PATH) as PackedScene
	if scene == null:
		printerr("K5a FAIL: could not load %s" % PINGPONG_SCENE_PATH)
		return 1

	# A player stand-in: a Node2D in the "player" group (the entity resolves it directly
	# from setup's arg, so any Node2D works as the distance-test target).
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)

	var cfg := RunConfig.new()
	# V3 (M1.12): the K5 entities read magnitudes from spawn_ctx["params"] (the deck lane's
	# ctx-merged def knob bag) — the retired cfg.hpp_* knobs no longer exist. Speed rides the
	# params channel (the charger unit-test pattern); cfg is just the run-config snapshot guard.
	var pp_speed := 100.0
	var pp_params := {"speed": pp_speed}

	# --- (a) SAFE CONSTRUCTION with a params-only spawn_ctx ------------------
	var hz_a := scene.instantiate() as PingPongHazard
	add_child(hz_a)
	hz_a.global_position = Vector2.ZERO
	player.global_position = Vector2(1000, 1000)   # far away — no kill
	hz_a.setup(cfg, player, {"params": pp_params})
	if not hz_a.velocity.is_equal_approx(Vector2.RIGHT * 100.0):
		failures.append("(a) empty spawn_ctx: velocity %s != default RIGHT * speed" % str(hz_a.velocity))

	# --- (a2) the Tell ACTUALLY RENDERS (guards the invisible-blade class of bug:
	# a self-intersecting Tell triangulates to 0 triangles and renders nothing). ---
	var pp_tell: Polygon2D = hz_a.get_node("Tell")
	if pp_tell == null:
		failures.append("(a2) PingPongHazard has no Tell node")
	elif Geometry2D.triangulate_polygon(pp_tell.polygon).is_empty():
		failures.append("(a2) Tell triangulates to 0 triangles — it would render NOTHING")

	# --- (b) INITIAL HEADING from spawn_ctx ---------------------------------
	var hz_b := scene.instantiate() as PingPongHazard
	add_child(hz_b)
	hz_b.global_position = Vector2.ZERO
	hz_b.setup(cfg, player, {"initial_dir": Vector2(1, 1), "params": pp_params})
	var want_v := Vector2(1, 1).normalized() * 100.0
	if not hz_b.velocity.is_equal_approx(want_v):
		failures.append("(b) initial_dir (1,1): velocity %s != normalized*speed %s" % [str(hz_b.velocity), str(want_v)])

	# --- (c) ROOM-RECT CLAMP reflects velocity at the rect edge --------------
	# Drive the entity inside a small room rect heading RIGHT, position it just past the
	# right edge, step one physics frame, and assert velocity.x flipped and x snapped in.
	var room := Rect2(Vector2(-50, -50), Vector2(100, 100))   # x in [-50, 50]
	var hz_c := scene.instantiate() as PingPongHazard
	add_child(hz_c)
	hz_c.setup(cfg, player, {"initial_dir": Vector2.RIGHT, "room_bounds": room, "params": pp_params})
	# Place it past the right edge so the clamp reflects this frame.
	hz_c.global_position = Vector2(80, 0)
	# Step a physics frame so _physics_process runs (move_and_slide + _confine_to_room).
	await get_tree().physics_frame
	await get_tree().physics_frame
	if hz_c.velocity.x >= 0.0:
		failures.append("(c) room clamp: velocity.x %f did not flip negative after crossing right edge" % hz_c.velocity.x)
	if hz_c.global_position.x > room.end.x + 0.001:
		failures.append("(c) room clamp: x %f not snapped back inside rect end %f" % [hz_c.global_position.x, room.end.x])

	# --- (d) DISTANCE-TEST KILL ends the run + emits new_hazard_killed once --
	# Establish an active run so fail_run has a run to end.
	_killed_events.clear()
	EventBus.opposition_event.connect(_on_opposition_hit)
	GameState.start_run(&"test_band", 12345)
	if not GameState.run_active:
		failures.append("(d) setup: GameState.run_active false after start_run")

	var hz_d := scene.instantiate() as PingPongHazard
	add_child(hz_d)
	hz_d.global_position = Vector2(500, 500)
	player.global_position = Vector2(500, 500)   # ON TOP — well within CONTACT_RADIUS (24)
	# No room bounds (pure-wall mode) so the clamp can't move the body off the player.
	hz_d.setup(cfg, player, {"params": pp_params})
	# Step a couple physics frames so the contact test trips.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if GameState.run_active:
		failures.append("(d) kill: GameState.run_active still true after contact (fatal path did not fire)")
	if _killed_events.size() != 1:
		failures.append("(d) kill: new_hazard_killed fired %d times, expected exactly 1 (BUG6 latch)" % _killed_events.size())
	elif _killed_events[0][0] != &"pingpong":
		failures.append("(d) kill: new_hazard_killed kind %s != &\"pingpong\"" % str(_killed_events[0][0]))
	EventBus.opposition_event.disconnect(_on_opposition_hit)

	# --- (g) KILLS-OFF (L5): hpp_kills=false => contact does NOT end the run, but still emits --
	# Mirrors (d) but with the L5 toggle off: the bouncer behaves identically (emits the contact
	# row) yet fail_run is gated, so the run stays active. Proves the *_kills knob.
	_killed_events.clear()
	EventBus.opposition_event.connect(_on_opposition_hit)
	GameState.start_run(&"test_band", 12345)
	var cfg_g := RunConfig.new()
	# V3 (M1.12): kills is entity-local (DEFAULTS.kills), overridden via params["kills"].
	var hz_g := scene.instantiate() as PingPongHazard
	add_child(hz_g)
	hz_g.global_position = Vector2(700, 700)
	player.global_position = Vector2(700, 700)   # ON TOP — within CONTACT_RADIUS
	hz_g.setup(cfg_g, player, {"params": {"speed": pp_speed, "kills": false}})
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not GameState.run_active:
		failures.append("(g) kills-off: run ended despite hpp_kills=false (fail_run was not gated)")
	if _killed_events.size() != 1:
		failures.append("(g) kills-off: new_hazard_killed fired %d times, expected exactly 1 (emit-always)" % _killed_events.size())
	EventBus.opposition_event.disconnect(_on_opposition_hit)
	hz_g.queue_free()
	GameState.fail_run(&"death")   # tidy: end the still-active run before the next case

	# --- (f) WALL/CORNER ANTI-STALL (BUG8) ----------------------------------
	# Build an L-corner of static walls on the `world` layer (bit 2 = value 2, the only
	# layer the bouncer masks) and aim a bouncer diagonally INTO the inside corner. The old
	# code reflected the post-move_and_slide (tangential) velocity, so a corner collapsed the
	# heading to wall-parallel and the bouncer ground to a halt parked against the wall. The
	# fix reflects the intended heading _dir off the summed normals, reversing it out of the
	# corner. Assert: after N frames it still moves at ~_speed AND has moved away from the
	# corner (it is not parked at the wall).
	player.global_position = Vector2(-5000, -5000)   # park the player far away — no kill interference
	var corner := Vector2(2000, 2000)                # an isolated test corner, away from everything
	var wall_thick := 40.0
	var wall_len := 400.0
	# Bottom wall (a horizontal slab whose TOP edge sits at corner.y) and right wall (a
	# vertical slab whose LEFT edge sits at corner.x): together an inside corner opening
	# up-left, so a bouncer heading down-right (1,1) drives straight into the vertex.
	var bottom_wall := _make_wall(Vector2(corner.x - wall_len * 0.5, corner.y + wall_thick * 0.5),
		Vector2(wall_len, wall_thick))
	var right_wall := _make_wall(Vector2(corner.x + wall_thick * 0.5, corner.y - wall_len * 0.5),
		Vector2(wall_thick, wall_len))
	add_child(bottom_wall)
	add_child(right_wall)

	var hz_f := scene.instantiate() as PingPongHazard
	add_child(hz_f)
	# Start just inside the corner, heading down-right INTO the vertex.
	hz_f.global_position = corner - Vector2(60, 60)
	hz_f.setup(cfg, player, {"initial_dir": Vector2(1, 1), "params": pp_params})
	var start_pos := hz_f.global_position
	# Step many physics frames so it hits the corner and (must) bounce back out.
	for _i in 90:
		await get_tree().physics_frame
	# Still travelling at ~constant speed (never stalled / ground to a halt).
	var spd := hz_f.velocity.length()
	if not is_equal_approx(spd, pp_speed):
		failures.append("(f) corner anti-stall: speed %f != _speed %f after 90 frames (stalled/ground down)" % [spd, pp_speed])
	# It must NOT be parked AT the corner vertex — it has to have bounced away from it.
	if hz_f.global_position.distance_to(corner) <= 30.0:
		failures.append("(f) corner anti-stall: parked at corner (dist %f <= 30) — did not bounce out" % hz_f.global_position.distance_to(corner))
	# And it must have moved a meaningful distance overall (not frozen at the wall).
	if hz_f.global_position.distance_to(start_pos) <= 20.0:
		failures.append("(f) corner anti-stall: barely moved (dist %f <= 20) — looks stuck on the wall" % hz_f.global_position.distance_to(start_pos))
	bottom_wall.queue_free()
	right_wall.queue_free()
	hz_f.queue_free()

	# --- (e) NO global-RNG call in the entity source ------------------------
	# S2 (M1.9): the entity's behavior now lives in the shared component scripts,
	# so the source scan sweeps them too (the one sanctioned S2 test-side addition —
	# S2 spec §2.3 / §4: "the script-source grep must now also sweep the component
	# scripts"). Same rule, wider net: no script in the set may call the global RNG
	# autoload — per-instance variation is spawn_ctx-supplied, deterministic.
	var rng_scan_paths: Array[String] = [PINGPONG_SCRIPT_PATH]
	var comp_dir := DirAccess.open(COMPONENTS_DIR)
	if comp_dir == null:
		failures.append("(e) could not open %s for the component RNG sweep" % COMPONENTS_DIR)
	else:
		var comp_files := comp_dir.get_files()
		var comp_count := 0
		for cf in comp_files:
			if cf.ends_with(".gd"):
				rng_scan_paths.append("%s/%s" % [COMPONENTS_DIR, cf])
				comp_count += 1
		if comp_count < 9:
			failures.append("(e) component sweep found only %d component scripts (expected >= 9)" % comp_count)
	for path in rng_scan_paths:
		var src := FileAccess.get_file_as_string(path)
		if src.is_empty():
			failures.append("(e) could not read %s for RNG audit" % path)
		elif "RNG." in src:
			failures.append("(e) %s references the global RNG autoload (must be RNG-free)" % path)

	if failures.is_empty():
		print("K5a OK — PingPongHazard verified: empty spawn_ctx constructs safely (default RIGHT heading), "
			+ "spawn_ctx initial_dir sets velocity, room_bounds clamp reflects + snaps back inside, the "
			+ "distance-test kill ends the run via fail_run(&\"death\") and emits new_hazard_killed(&\"pingpong\") "
			+ "EXACTLY once (BUG6 latch), it bounces cleanly OUT of a wall corner without stalling (BUG8), "
			+ "and the entity makes no global-RNG call.")
		return 0
	for f in failures:
		printerr("K5a FAIL: ", f)
	return 1


## Build a static wall on the `world` layer (bit 2 = value 2) — the only layer the bouncer
## masks. `top_left` is the rect's top-left corner in world px; `size` its extent.
func _make_wall(top_left: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 2   # world (bit 2)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	# A RectangleShape2D is centred on the CollisionShape2D's origin; offset so its top-left
	# sits at top_left.
	shape.position = top_left + size * 0.5
	body.add_child(shape)
	return body


func _on_opposition_hit(id: StringName, event: StringName, depth: int, run_t_ms: int) -> void:
	# V2: legacy new_hazard_killed retired → filter the generic family on &"hit_player"
	# (identical site/moment; id == the hazard kind).
	if event == &"hit_player":
		_killed_events.append([id, depth, run_t_ms])
