extends SceneTree
## Headless verification for A1 player movement.
##
## Input cannot be injected in --headless, and a raw SceneTree --script run has
## no stepped physics space (so move_and_slide() is a no-op). So we test the
## player's *own* movement math directly: Player.step_velocity() — the exact
## function _physics_process() calls — for all 8 directions, integrating position
## with Euler. This proves:
##   - all 8 directions move the body the right way,
##   - diagonal speed == cardinal speed (input vectors are pre-normalized), and
##   - the .tres stats load and drive the math.
## Run: godot --headless --script res://tests/test_player_movement.gd
##
## This is the automated stand-in for the manual in-editor keyboard+controller
## check (a human still confirms once that both input devices feel identical).

const PLAYER_SCENE := "res://entities/player/player.tscn"

# Unit input vectors as Input.get_vector() returns for each of the 8 directions
# (diagonals already normalized to length 1, matching get_vector's output).
const INV_SQRT2 := 0.70710678
const DIRS := {
	"up": Vector2(0, -1),
	"down": Vector2(0, 1),
	"left": Vector2(-1, 0),
	"right": Vector2(1, 0),
	"up_left": Vector2(-INV_SQRT2, -INV_SQRT2),
	"up_right": Vector2(INV_SQRT2, -INV_SQRT2),
	"down_left": Vector2(-INV_SQRT2, INV_SQRT2),
	"down_right": Vector2(INV_SQRT2, INV_SQRT2),
}


func _initialize() -> void:
	var failures: Array[String] = []

	var packed: PackedScene = load(PLAYER_SCENE)
	if packed == null:
		printerr("MOVE FAIL: could not load ", PLAYER_SCENE)
		quit(1)
		return

	# Untyped: avoids cross-file class-member resolution quirks when a SceneTree
	# tool script reaches into another class_name's exported members.
	var player: Variant = packed.instantiate()
	if player.stats == null:
		printerr("MOVE FAIL: player.stats not assigned from .tres")
		player.free()
		quit(1)
		return

	var max_speed: float = player.stats.max_speed
	var cardinal_dist := -1.0
	var diagonal_dist := -1.0
	var delta := 1.0 / 60.0

	for dir_name in DIRS:
		var input_dir: Vector2 = DIRS[dir_name]
		var velocity := Vector2.ZERO
		var pos := Vector2.ZERO
		var facing := Vector2.DOWN

		# Replicate one tick exactly as _physics_process does, then Euler-
		# integrate position (no physics space available headless). 30 ticks ~0.5s.
		for _i in range(30):
			velocity = player.step_velocity(velocity, input_dir, delta)
			if input_dir != Vector2.ZERO:
				facing = input_dir.normalized()
			pos += velocity * delta

		var dist: float = pos.length()

		# Body must have moved.
		if dist < 1.0:
			failures.append("%s: body did not move (dist=%.2f)" % [dir_name, dist])
		# Movement must be along the input direction (dot ~ +1 with unit dirs).
		elif pos.normalized().dot(input_dir) < 0.99:
			failures.append("%s: moved off-axis (dir=%s)" % [dir_name, pos.normalized()])

		# Steady-state speed must reach max_speed (200) — snappy accel.
		if velocity.length() < max_speed - 1.0:
			failures.append("%s: did not reach max_speed (%.1f < %.1f)"
				% [dir_name, velocity.length(), max_speed])

		# facing must track the input direction.
		if not facing.is_equal_approx(input_dir.normalized()):
			failures.append("%s: facing wrong (%s)" % [dir_name, facing])

		# Capture one cardinal and one diagonal distance to compare speeds.
		if dir_name == "right":
			cardinal_dist = dist
		elif dir_name == "down_right":
			diagonal_dist = dist

	player.free()

	# Diagonal speed must equal cardinal speed (no faster diagonals).
	if cardinal_dist > 0.0 and diagonal_dist > 0.0:
		if absf(cardinal_dist - diagonal_dist) > 1.0:
			failures.append("diagonal speed != cardinal (%.2f vs %.2f)"
				% [diagonal_dist, cardinal_dist])

	if failures.is_empty():
		print("MOVE OK — 8-direction movement verified (cardinal=%.1fpx diagonal=%.1fpx over 0.5s, max_speed=%.0f)"
			% [cardinal_dist, diagonal_dist, max_speed])
		quit(0)
	else:
		for f in failures:
			printerr("MOVE FAIL: ", f)
		quit(1)
