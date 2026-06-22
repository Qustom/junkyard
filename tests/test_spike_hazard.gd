extends Node
## Headless acceptance test for K5c (M1.4) — the rotating-spikes hazard (SpikeHazard).
##
## Run as a SCENE (autoloads + a live tree) so the entity script resolves exactly as in
## the real game:
##   godot --headless res://tests/test_spike_hazard.tscn
##
## K5c is an ANCHORED Node2D hub with ARM_COUNT (=3, const) lethal arms of length
## hspike_arm_length that rotate at hspike_rotation_speed (signed deg/s). The kill is an
## ANALYTIC distance-to-arm-segment test (Geometry2D), not a physics overlap — deterministic.
##
## Asserts (per the K5c spec + its Resolved Decisions):
##   (a) CONSTRUCTS SAFELY with an empty spawn_ctx (phase_salt defaults 0) and with a real
##       spawn_ctx — no crash, snapshots config.
##   (b) DETERMINISTIC initial phase: the SAME phase_salt yields the SAME initial _angle,
##       reproducible across instances; different salts generally differ (variety).
##   (c) The rotating-arm KILL fires when the player is within an arm's swept length, and
##       NOT when the player is clear of every blade.
##   (d) new_hazard_killed(&"spike", depth, run_t_ms) emits on the lethal frame, exactly
##       ONCE (the one-shot latch), and routes death through GameState.fail_run.
##   (e) ARM_COUNT is 3 (locked).

const SPIKE_SCENE := "res://scenes/hazards/spike_hazard.tscn"


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	var scene := load(SPIKE_SCENE) as PackedScene
	if scene == null:
		printerr("K5c FAIL: could not load %s" % SPIKE_SCENE)
		return 1

	# --- (e) ARM_COUNT locked at 3 (read off the class) ----------------------------
	var arm_count: int = SpikeHazard.ARM_COUNT
	if arm_count != 3:
		failures.append("(e) SpikeHazard.ARM_COUNT == %d, expected 3 (locked)" % arm_count)

	# A player stand-in at the origin region; we move it to test the hit geometry.
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)

	# --- (a) constructs safely with an EMPTY spawn_ctx -----------------------------
	var rc := _rc(90.0, 64.0)   # 90 deg/s, 64px arms
	var hz_empty: SpikeHazard = scene.instantiate()
	add_child(hz_empty)
	hz_empty.global_position = Vector2(500, 500)
	hz_empty.setup(rc, player)   # no spawn_ctx → default {} → phase_salt 0
	var angle_empty: float = hz_empty._angle
	# phase_salt 0 ⇒ angle 0.
	if not is_equal_approx(angle_empty, 0.0):
		failures.append("(a) empty spawn_ctx gave _angle %f, expected 0.0 (phase_salt 0)" % angle_empty)

	# --- (f) the Tell ACTUALLY RENDERS: each arm island must triangulate to >0 tris.
	# Guards the invisible-blade bug — a self-intersecting single-outline star triangulated
	# to ZERO triangles (rendered nothing) while the kill still fired.
	var tell: Polygon2D = hz_empty.get_node("Tell")
	if tell == null:
		failures.append("(f) SpikeHazard has no Tell node")
	elif tell.polygons.is_empty():
		failures.append("(f) Tell.polygons is empty — arms not registered as islands")
	else:
		var drawn_tris := 0
		for island in tell.polygons:
			var sub := PackedVector2Array()
			for idx in island:
				sub.append(tell.polygon[idx])
			var tris := Geometry2D.triangulate_polygon(sub)
			if tris.is_empty():
				failures.append("(f) an arm island triangulated to 0 triangles — it would render NOTHING")
			drawn_tris += tris.size() / 3
		if tell.polygons.size() != SpikeHazard.ARM_COUNT:
			failures.append("(f) expected %d arm islands, got %d" % [SpikeHazard.ARM_COUNT, tell.polygons.size()])
		if drawn_tris <= 0:
			failures.append("(f) Tell triangulates to 0 triangles total (invisible blades)")

	# --- (b) deterministic phase: same salt → same angle, reproducible -------------
	var hz_s7a: SpikeHazard = scene.instantiate()
	var hz_s7b: SpikeHazard = scene.instantiate()
	add_child(hz_s7a)
	add_child(hz_s7b)
	hz_s7a.setup(rc, player, {"phase_salt": 7})
	hz_s7b.setup(rc, player, {"phase_salt": 7})
	if not is_equal_approx(hz_s7a._angle, hz_s7b._angle):
		failures.append("(b) same phase_salt 7 gave different angles (%f vs %f) — not deterministic"
			% [hz_s7a._angle, hz_s7b._angle])
	# A different salt should generally produce a different phase (variety, not lock-step).
	var hz_s8: SpikeHazard = scene.instantiate()
	add_child(hz_s8)
	hz_s8.setup(rc, player, {"phase_salt": 8})
	if is_equal_approx(hz_s8._angle, hz_s7a._angle):
		failures.append("(b) salts 7 and 8 produced the same phase (no per-instance variety)")
	# The expected closed form: deg_to_rad(posmod(salt*47, 360)).
	var want_s7: float = deg_to_rad(float(posmod(7 * 47, 360)))
	if not is_equal_approx(hz_s7a._angle, want_s7):
		failures.append("(b) phase_salt 7 angle %f != expected %f" % [hz_s7a._angle, want_s7])

	# --- (c) hit geometry: on a blade ⇒ hit; in the gap ⇒ no hit -------------------
	# Anchor a non-rotating spike (omega 0) at a known hub with a known phase so the arms
	# are fixed and we can place the player precisely. phase_salt 0 ⇒ _angle 0 ⇒ arm 0
	# points along +X. With ARM_COUNT 3 the arms point at 0, 120, 240 degrees.
	var rc_static := _rc(0.0, 64.0)   # omega 0 → arms don't move during this check
	var hz: SpikeHazard = scene.instantiate()
	add_child(hz)
	var hub := Vector2(1000, 1000)
	hz.global_position = hub
	hz.setup(rc_static, player, {"phase_salt": 0})

	# ON arm 0 (+X), well within arm length: player at hub + (40, 0) → on the blade.
	if not hz._is_player_on_any_arm(hub + Vector2(40, 0)):
		failures.append("(c) player ON arm 0 (hub+40,0) was NOT detected as a hit")
	# In a GAP between arms: arm 0 at 0deg, arm 1 at 120deg, arm 2 at 240deg → 60deg is a
	# gap. A point at 60deg, well beyond the kill capsule, must be clear.
	var gap_dir := Vector2(cos(deg_to_rad(60.0)), sin(deg_to_rad(60.0)))
	if hz._is_player_on_any_arm(hub + gap_dir * 50.0):
		failures.append("(c) player in the GAP (60deg, r=50) was wrongly detected as a hit")
	# BEYOND the arm tip (past arm_length on +X) → no hit.
	if hz._is_player_on_any_arm(hub + Vector2(64.0 + 40.0, 0)):
		failures.append("(c) player BEYOND the arm tip (hub+104,0) was wrongly detected as a hit")
	# Right AT the hub → hit (all arms originate there).
	if not hz._is_player_on_any_arm(hub):
		failures.append("(c) player AT the hub was NOT detected as a hit")

	# --- (d) kill emits new_hazard_killed(&"spike",..) ONCE + routes through fail_run ---
	var killed_events: Array = []
	var sink := func(kind: StringName, depth: int, run_t_ms: int) -> void:
		killed_events.append([kind, depth, run_t_ms])
	EventBus.new_hazard_killed.connect(sink)

	# Make sure no prior run-end latch blocks fail_run for this check (clears _run_ended).
	GameState.start_run(&"test_band", 12345)
	var hz_kill: SpikeHazard = scene.instantiate()
	add_child(hz_kill)
	hz_kill.global_position = Vector2(2000, 2000)
	hz_kill.setup(rc_static, player, {"phase_salt": 0})
	# Park the player squarely on arm 0 so the per-frame test fires.
	player.global_position = hz_kill.global_position + Vector2(40, 0)
	# Drive several physics frames; the kill must register and emit exactly once.
	hz_kill._physics_process(0.016)
	hz_kill._physics_process(0.016)
	hz_kill._physics_process(0.016)
	EventBus.new_hazard_killed.disconnect(sink)

	if killed_events.size() != 1:
		failures.append("(d) new_hazard_killed emitted %d times, expected exactly 1 (one-shot latch)"
			% killed_events.size())
	elif killed_events[0][0] != &"spike":
		failures.append("(d) new_hazard_killed kind was %s, expected &\"spike\"" % str(killed_events[0][0]))
	if not GameState._run_ended:
		failures.append("(d) GameState.fail_run did not end the run (player not killed)")

	# --- cleanup -------------------------------------------------------------------
	for n in [hz_empty, hz_s7a, hz_s7b, hz_s8, hz, hz_kill, player]:
		if is_instance_valid(n):
			n.queue_free()

	if failures.is_empty():
		print("K5c OK — SpikeHazard verified: constructs safely with empty/real spawn_ctx, "
			+ "deterministic per-instance phase from phase_salt (same salt → same _angle, RNG-free), "
			+ "analytic rotating-arm kill fires on a blade and not in the gap/beyond the tip, "
			+ "new_hazard_killed(&\"spike\",..) emits exactly once and routes death through fail_run, "
			+ "and ARM_COUNT is locked at 3.")
		return 0
	for f in failures:
		printerr("K5c FAIL: ", f)
	return 1


## A spike-on RunConfig with the K5c knobs set for the entity behaviour under test.
## (Placement/count knobs are K5i's; the entity reads only rotation_speed + arm_length.)
func _rc(rotation_speed: float, arm_length: float) -> RunConfig:
	var rc := RunConfig.new()
	rc.hspike_enabled = true
	rc.hspike_rotation_speed = rotation_speed
	rc.hspike_arm_length = arm_length
	return rc
