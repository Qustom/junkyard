extends SceneTree
## Headless unit test for L6 (M1.5) — Player.resolve_aim() device arbitration.
##
## resolve_aim is a PURE helper (no node/tree/physics access, no side effects),
## mirroring step_velocity's split, so it is testable headlessly with a bare Player
## instance and no live input. We exercise the four priority branches from L6 §1:
##   1. right stick above deadzone wins (twin-stick aim);
##   2. mouse aim when the stick is neutral AND a mouse-motion happened (mouse_active);
##   3. hold the previous aim when neither device is active;
##   4. default to the movement direction (else DOWN) on the very first frame.
## Plus: stale mouse is ignored when mouse_active is false, and the deadzone boundary.
## Run: godot --headless --script res://tests/test_resolve_aim.gd

const PLAYER_SCENE := "res://entities/player/player.tscn"
const EPS := 0.0001


func _approx(a: Vector2, b: Vector2) -> bool:
	return a.is_equal_approx(b)


func _initialize() -> void:
	var failures: Array[String] = []

	var packed: PackedScene = load(PLAYER_SCENE)
	if packed == null:
		printerr("AIM FAIL: could not load ", PLAYER_SCENE)
		quit(1)
		return
	# Untyped, like test_player_movement — avoids cross-file class-member quirks
	# when a tool SceneTree reaches into another class_name's members.
	var p: Variant = packed.instantiate()

	# --- CASE 1: right stick above deadzone wins, regardless of mouse -------------
	# Stick points right (mag 1.0 > 0.25 deadzone); a live mouse points the other
	# way and must be ignored. Expect the (normalized) stick direction.
	var r1: Vector2 = p.resolve_aim(
		Vector2(1, 0), Vector2(-3, 4), true, Vector2.ZERO, Vector2.DOWN)
	if not _approx(r1, Vector2.RIGHT):
		failures.append("CASE1: stick-wins expected RIGHT, got %s" % r1)

	# A diagonal stick must be normalized.
	var r1b: Vector2 = p.resolve_aim(
		Vector2(0.5, 0.5), Vector2(10, 0), true, Vector2.ZERO, Vector2.DOWN)
	if not _approx(r1b, Vector2(0.5, 0.5).normalized()):
		failures.append("CASE1b: diagonal stick not normalized, got %s" % r1b)

	# --- CASE 1c: stick BELOW deadzone is treated as neutral ---------------------
	# Stick magnitude 0.2 < 0.25 deadzone → falls through to mouse (active).
	var r1c: Vector2 = p.resolve_aim(
		Vector2(0.2, 0.0), Vector2(0, 5), true, Vector2.ZERO, Vector2.DOWN)
	if not _approx(r1c, Vector2.DOWN):
		failures.append("CASE1c: sub-deadzone stick should defer to mouse DOWN, got %s" % r1c)

	# --- CASE 2: mouse aim when stick neutral AND mouse_active --------------------
	# mouse_dir points up-left; expect its normalization.
	var mdir := Vector2(-4, -3)
	var r2: Vector2 = p.resolve_aim(
		Vector2.ZERO, mdir, true, Vector2.ZERO, Vector2.DOWN)
	if not _approx(r2, mdir.normalized()):
		failures.append("CASE2: mouse-active expected %s, got %s" % [mdir.normalized(), r2])

	# --- CASE 3: stale mouse IGNORED when mouse_active is false -> hold prev ------
	# Stick neutral, mouse not active (controller player never moved the mouse):
	# must hold the previous aim, NOT snap to the cursor.
	var prev := Vector2(0, -1)
	var r3: Vector2 = p.resolve_aim(
		Vector2.ZERO, Vector2(100, 100), false, Vector2.ZERO, prev)
	if not _approx(r3, prev):
		failures.append("CASE3: stale mouse should be ignored; expected prev %s, got %s" % [prev, r3])

	# --- CASE 4: first frame default -> movement direction, else DOWN ------------
	# prev is ZERO (never aimed), no stick, no active mouse, but moving up: aim the
	# movement direction.
	var r4: Vector2 = p.resolve_aim(
		Vector2.ZERO, Vector2.ZERO, false, Vector2(0, -1), Vector2.ZERO)
	if not _approx(r4, Vector2.UP):
		failures.append("CASE4: first-frame moving-up default expected UP, got %s" % r4)

	# prev ZERO, standing still, no device: fall back to DOWN (pre-L6 facing default).
	var r4b: Vector2 = p.resolve_aim(
		Vector2.ZERO, Vector2.ZERO, false, Vector2.ZERO, Vector2.ZERO)
	if not _approx(r4b, Vector2.DOWN):
		failures.append("CASE4b: idle first-frame default expected DOWN, got %s" % r4b)

	# --- CASE 5: hold-last beats movement when prev is set -----------------------
	# An established aim is held even while moving a different way (you keep pointing
	# where you last pointed until a device says otherwise).
	var r5: Vector2 = p.resolve_aim(
		Vector2.ZERO, Vector2.ZERO, false, Vector2(1, 0), Vector2(0, -1))
	if not _approx(r5, Vector2(0, -1)):
		failures.append("CASE5: hold-last should beat movement; expected UP, got %s" % r5)

	p.free()

	if failures.is_empty():
		print("RESOLVE_AIM OK — L6 aim arbitration verified: stick>deadzone wins (+normalized), sub-deadzone defers, mouse-after-motion, stale-mouse ignored (hold last), first-frame move/DOWN default, hold-last beats movement.")
		quit(0)
	else:
		for f in failures:
			printerr("RESOLVE_AIM FAIL: ", f)
		quit(1)
