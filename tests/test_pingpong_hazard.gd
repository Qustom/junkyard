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
	cfg.hpp_enabled = true
	cfg.hpp_speed = 100.0

	# --- (a) SAFE CONSTRUCTION with an empty spawn_ctx -----------------------
	var hz_a := scene.instantiate() as PingPongHazard
	add_child(hz_a)
	hz_a.global_position = Vector2.ZERO
	player.global_position = Vector2(1000, 1000)   # far away — no kill
	hz_a.setup(cfg, player)                        # empty dict (default)
	if not hz_a.velocity.is_equal_approx(Vector2.RIGHT * 100.0):
		failures.append("(a) empty spawn_ctx: velocity %s != default RIGHT * speed" % str(hz_a.velocity))

	# --- (b) INITIAL HEADING from spawn_ctx ---------------------------------
	var hz_b := scene.instantiate() as PingPongHazard
	add_child(hz_b)
	hz_b.global_position = Vector2.ZERO
	hz_b.setup(cfg, player, {"initial_dir": Vector2(1, 1)})
	var want_v := Vector2(1, 1).normalized() * 100.0
	if not hz_b.velocity.is_equal_approx(want_v):
		failures.append("(b) initial_dir (1,1): velocity %s != normalized*speed %s" % [str(hz_b.velocity), str(want_v)])

	# --- (c) ROOM-RECT CLAMP reflects velocity at the rect edge --------------
	# Drive the entity inside a small room rect heading RIGHT, position it just past the
	# right edge, step one physics frame, and assert velocity.x flipped and x snapped in.
	var room := Rect2(Vector2(-50, -50), Vector2(100, 100))   # x in [-50, 50]
	var hz_c := scene.instantiate() as PingPongHazard
	add_child(hz_c)
	hz_c.setup(cfg, player, {"initial_dir": Vector2.RIGHT, "room_bounds": room})
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
	EventBus.new_hazard_killed.connect(_on_new_hazard_killed)
	GameState.start_run(&"test_band", 12345)
	if not GameState.run_active:
		failures.append("(d) setup: GameState.run_active false after start_run")

	var hz_d := scene.instantiate() as PingPongHazard
	add_child(hz_d)
	hz_d.global_position = Vector2(500, 500)
	player.global_position = Vector2(500, 500)   # ON TOP — well within CONTACT_RADIUS (24)
	# No room bounds (pure-wall mode) so the clamp can't move the body off the player.
	hz_d.setup(cfg, player, {})
	# Step a couple physics frames so the contact test trips.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if GameState.run_active:
		failures.append("(d) kill: GameState.run_active still true after contact (fatal path did not fire)")
	if _killed_events.size() != 1:
		failures.append("(d) kill: new_hazard_killed fired %d times, expected exactly 1 (BUG6 latch)" % _killed_events.size())
	elif _killed_events[0][0] != &"pingpong":
		failures.append("(d) kill: new_hazard_killed kind %s != &\"pingpong\"" % str(_killed_events[0][0]))
	EventBus.new_hazard_killed.disconnect(_on_new_hazard_killed)

	# --- (e) NO global-RNG call in the entity source ------------------------
	var src := FileAccess.get_file_as_string(PINGPONG_SCRIPT_PATH)
	if src.is_empty():
		failures.append("(e) could not read entity source for RNG audit")
	elif "RNG." in src:
		failures.append("(e) entity source references the global RNG autoload (must be RNG-free)")

	if failures.is_empty():
		print("K5a OK — PingPongHazard verified: empty spawn_ctx constructs safely (default RIGHT heading), "
			+ "spawn_ctx initial_dir sets velocity, room_bounds clamp reflects + snaps back inside, the "
			+ "distance-test kill ends the run via fail_run(&\"death\") and emits new_hazard_killed(&\"pingpong\") "
			+ "EXACTLY once (BUG6 latch), and the entity makes no global-RNG call.")
		return 0
	for f in failures:
		printerr("K5a FAIL: ", f)
	return 1


func _on_new_hazard_killed(kind: StringName, depth: int, run_t_ms: int) -> void:
	_killed_events.append([kind, depth, run_t_ms])
