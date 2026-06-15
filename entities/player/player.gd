extends CharacterBody2D
class_name Player
## Player — top-down 8-direction movement (A1, M1 greybox prototype).
##
## Movement reads named Input Map actions via Input.get_vector, which applies the
## stick deadzone and clamps length so diagonal speed equals cardinal speed and
## keyboard and controller produce identical motion. Velocity moves toward a
## target (accel when input present, friction when not) then move_and_slide()
## applies it. Raw movement emits no EventBus traffic; A2 owns `interact`.
##
## `facing` is exposed read-only (last non-zero input direction) so A2 can add a
## facing bias to its nearest-interactable search without a refactor. The camera
## is level-owned (PhantomCamera2D lives in the dive scene, not here) so this
## entity stays reusable.

## Movement tuning, data-authored. Assigned in player.tscn to
## res://data/player/player_movement.tres.
@export var stats: PlayerMovementStats

## Last non-zero movement direction (normalized). Read-only for A2 / facing
## visuals. Defaults to DOWN so a freshly-spawned player has a defined facing.
var facing: Vector2 = Vector2.DOWN

@onready var _nose: Node2D = get_node_or_null("Nose")


func _physics_process(delta: float) -> void:
	# get_vector returns a deadzone-applied, length-clamped vector — identical
	# for digital keys (unit vector) and analog stick. Already normalized for
	# diagonals, so we must NOT normalize again before scaling by max_speed.
	var input_dir: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down")

	velocity = step_velocity(velocity, input_dir, delta)
	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()

	move_and_slide()
	_update_facing_visual()


## Pure movement integration: returns the next velocity given the current
## velocity, the (already deadzone-applied, length-clamped) input direction, and
## delta. Accelerates toward input_dir * max_speed when there is input; applies
## friction toward zero otherwise. Kept separate from _physics_process so it is
## unit-testable headlessly without a physics space — see tests/.
func step_velocity(current: Vector2, input_dir: Vector2, delta: float) -> Vector2:
	if input_dir != Vector2.ZERO:
		var target: Vector2 = input_dir * stats.max_speed
		return current.move_toward(target, stats.acceleration * delta)
	return current.move_toward(Vector2.ZERO, stats.friction * delta)


func _update_facing_visual() -> void:
	# Greybox only: point the optional "nose" marker along `facing`. No-op until
	# a directional sprite exists. Guard the null so the script runs without it.
	if _nose != null:
		_nose.rotation = facing.angle()
