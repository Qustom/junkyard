extends Node
## Headless unit test for N1 (M1.7) — PlayerVisual pure helpers.
##
## quantize_dir() and select_state() are PURE static helpers (no node/tree/physics
## access, no side effects), mirroring Player.step_velocity / resolve_aim, so they
## are testable headlessly by calling them directly with no instance. Runs as a
## SCENE (test_player_visual.tscn) per repo convention.
##
## Asserts:
##   - all 8 cardinal/diagonal facing vectors quantize to the right dir suffix
##     (matching N0's SpriteFrames clip-suffix contract);
##   - ZERO facing holds the current dir (never undefined);
##   - angular hysteresis holds the dir across a small boundary jitter, but a clear
##     swing past the band switches;
##   - select_state returns walk/idle across the WALK_SPEED_THRESHOLD;
##   - pickup/throw actions win over walk/idle;
##   - a LOCKED player never reads walk (idle/action only — no walk-in-place).
## Run: godot --headless --path Game res://tests/test_player_visual.tscn


func _ready() -> void:
	var failures: Array[String] = []

	# === quantize_dir: the 8 sectors (facing held current = south so the candidate
	# must clearly win the hysteresis band; each cardinal/diagonal is sector-center,
	# 0° from its own center, so it always beats south). ====================
	# Screen space: +x = east (0°), +y = south (90°, +y down).
	var dir_cases := {
		"east":       Vector2(1, 0),
		"south_east": Vector2(1, 1),
		"south":      Vector2(0, 1),
		"south_west": Vector2(-1, 1),
		"west":       Vector2(-1, 0),
		"north_west": Vector2(-1, -1),
		"north":      Vector2(0, -1),
		"north_east": Vector2(1, -1),
	}
	for want in dir_cases:
		var facing: Vector2 = (dir_cases[want] as Vector2).normalized()
		# Seed `current` with the OPPOSITE-ish dir so hysteresis can't mask a wrong
		# quantization (a sector-center input is 0° from its center, > 10° closer
		# than any neighbor, so it must switch).
		var got: StringName = PlayerVisual.quantize_dir(facing, &"south" if want != "south" else &"north")
		if got != StringName(want):
			failures.append("quantize_dir(%s) expected '%s', got '%s'" % [facing, want, got])

	# === ZERO facing holds current (never undefined) ========================
	if PlayerVisual.quantize_dir(Vector2.ZERO, &"north_west") != &"north_west":
		failures.append("quantize_dir(ZERO) should hold current dir, got '%s'"
			% PlayerVisual.quantize_dir(Vector2.ZERO, &"north_west"))

	# === Hysteresis: a small jitter just past a sector boundary must HOLD the
	# current dir; a clear swing PAST the band must switch. =================
	# Boundary between east(0°) and south_east(45°) is 22.5°. A facing at 24° is in
	# south_east's sector but only 1.5° past the boundary — < 10° hysteresis from
	# east's center perspective should NOT flip away from `east`.
	var jitter := Vector2.from_angle(deg_to_rad(24.0))   # 24° from +x
	if PlayerVisual.quantize_dir(jitter, &"east") != &"east":
		failures.append("hysteresis: 24° jitter from east should HOLD east, got '%s'"
			% PlayerVisual.quantize_dir(jitter, &"east"))
	# A facing well into south_east (40°, near its 45° center) must switch from east.
	var clear := Vector2.from_angle(deg_to_rad(40.0))
	if PlayerVisual.quantize_dir(clear, &"east") != &"south_east":
		failures.append("hysteresis: 40° (clearly south_east) should switch from east, got '%s'"
			% PlayerVisual.quantize_dir(clear, &"east"))

	# === select_state: walk ↔ idle across the threshold =====================
	# Below threshold (8 px/s) → idle.
	if PlayerVisual.select_state(Vector2(0, 5), false, &"") != &"idle":
		failures.append("select_state(5 px/s) expected idle")
	# At threshold exactly (8) is NOT above → idle.
	if PlayerVisual.select_state(Vector2(8, 0), false, &"") != &"idle":
		failures.append("select_state(8 px/s, at threshold) expected idle (strictly above only)")
	# Above threshold → walk.
	if PlayerVisual.select_state(Vector2(50, 0), false, &"") != &"walk":
		failures.append("select_state(50 px/s) expected walk")

	# === select_state: action priority over walk/idle =======================
	if PlayerVisual.select_state(Vector2(200, 0), false, &"pickup") != &"pickup":
		failures.append("select_state: pickup action must win over walk")
	if PlayerVisual.select_state(Vector2.ZERO, false, &"throw") != &"throw":
		failures.append("select_state: throw action must win over idle")

	# === select_state: a LOCKED player never reads walk =====================
	if PlayerVisual.select_state(Vector2(200, 0), true, &"") != &"idle":
		failures.append("select_state(locked, fast, no action) expected idle (never walk-in-place)")
	# Locked WITH an action still shows the action.
	if PlayerVisual.select_state(Vector2(200, 0), true, &"throw") != &"throw":
		failures.append("select_state(locked, action) expected throw")

	if failures.is_empty():
		print("PLAYER_VISUAL OK — quantize_dir (8 sectors + ZERO-hold + 10° hysteresis hold/switch), select_state (walk/idle @8px/s threshold, action priority, locked never walks) verified.")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("PLAYER_VISUAL FAIL: ", f)
		get_tree().quit(1)
