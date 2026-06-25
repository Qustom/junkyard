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
## `facing` is exposed read-only so A2 can add a facing bias to its nearest-
## interactable search without a refactor. The camera is level-owned (PhantomCamera2D
## lives in the dive scene, not here) so this entity stays reusable.
##
## L6 (M1.5) control rework: aim is DECOUPLED from movement. `aim` is where the
## player points (mouse direction on KB/M, right-stick direction on a controller);
## movement (left stick / WASD) is unchanged. The nose and `facing` follow `aim`,
## and the throw seam (main_game) reads `aim` for the projectile direction. Device
## arbitration lives in the pure resolve_aim() helper so it is unit-testable.

## Movement tuning, data-authored. Assigned in player.tscn to
## res://data/player/player_movement.tres.
@export var stats: PlayerMovementStats

## Where the player points (normalized). Read-only for the throw seam (main_game
## reads it for the projectile direction) + A2's facing bias. Mouse direction on
## KB/M, right-stick direction on a controller — see resolve_aim(). Defaults to
## DOWN so a freshly-spawned player has a defined aim before any device is used.
var aim: Vector2 = Vector2.DOWN

## Alias kept in sync with `aim` so existing `facing` readers (the nose visual, any
## future A2 bias) keep working. L6 retires "last movement direction" as the facing
## source — facing now follows where you POINT, not where you move.
var facing: Vector2 = Vector2.DOWN

## Right-stick deadzone for aim (mirrors the aim_* action deadzone in project.godot).
## Below this magnitude the right stick is treated as neutral so a resting stick does
## not pin the aim — arbitration then falls back to mouse / last-aim / movement.
const AIM_STICK_DEADZONE: float = 0.25

## Set true once a real mouse-motion event arrives this run, false again when the
## right stick takes over. Gates mouse aim so a stale cursor position never hijacks
## the aim on a controller (the player never moved the mouse). Toggled in _input().
var _mouse_active: bool = false

## R3 (M1.1) exposure speed penalty seam. The ExposureMeter emits
## EventBus.exposure_speed_mult_changed(mult) when its thresholds inflict a `speed`
## penalty; we cache it and scale max_speed by it in step_velocity. Defaults to 1.0
## (no penalty) so the player is unaffected with R3 off — M1.0 movement exactly.
## The meter re-emits 1.0 on every run boundary so a penalty never leaks across runs.
var _exposure_speed_mult: float = 1.0

@onready var _nose: Node2D = get_node_or_null("Nose")


func _ready() -> void:
	EventBus.exposure_speed_mult_changed.connect(_on_exposure_speed_mult_changed)


func _on_exposure_speed_mult_changed(mult: float) -> void:
	_exposure_speed_mult = mult


func _physics_process(delta: float) -> void:
	# get_vector returns a deadzone-applied, length-clamped vector — identical
	# for digital keys (unit vector) and analog stick. Already normalized for
	# diagonals, so we must NOT normalize again before scaling by max_speed.
	var input_dir: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down")

	velocity = step_velocity(velocity, input_dir, delta)

	# L6: aim is decoupled from movement. Gather both candidate aim sources — the
	# right stick (deadzoned via Input.get_vector on the aim_* actions) and the
	# direction from the player to the mouse — then let the pure resolver arbitrate.
	var stick: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var mouse_dir: Vector2 = get_global_mouse_position() - global_position
	var move_dir: Vector2 = input_dir.normalized() if input_dir != Vector2.ZERO else Vector2.ZERO
	# When the right stick takes over, drop mouse-active so a resting cursor can't
	# fight the stick on the next neutral-stick frame (cleared here, not in the pure
	# resolver, so resolve_aim stays free of side effects + headlessly testable).
	if stick.length() > AIM_STICK_DEADZONE:
		_mouse_active = false
	aim = resolve_aim(stick, mouse_dir, _mouse_active, move_dir, aim)
	facing = aim   # keep the existing facing alias in sync with where we point

	move_and_slide()
	_update_facing_visual()


## Mark the mouse as the active aim device the moment it moves, so KB/M aim engages
## on real cursor motion (not a stale position). The right-stick branch in
## resolve_aim() out-prioritises this and clears the flag, so a controller player who
## never touches the mouse is never hijacked by the cursor's resting position.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_active = true


## Pure aim arbitration (no node/tree/physics access, no side effects — unit-testable
## headlessly, mirroring step_velocity's split). Priority (L6 §1):
##   1. Right stick when its magnitude exceeds the deadzone → twin-stick aim wins.
##   2. Else mouse direction, but ONLY after a mouse-motion event (mouse_active) —
##      so a stale cursor never overrides a controller that left the stick neutral.
##   3. Else hold the previous aim (no device input this frame).
##   4. First frame / never aimed (prev is zero): default to the movement direction,
##      falling back to DOWN when standing still — matches the pre-L6 facing default.
## Reads the AIM_STICK_DEADZONE instance const, so it is a regular (non-static) method.
func resolve_aim(stick: Vector2, mouse_dir: Vector2, mouse_active: bool,
		move_dir: Vector2, prev: Vector2) -> Vector2:
	if stick.length() > AIM_STICK_DEADZONE:
		return stick.normalized()
	if mouse_active and mouse_dir.length() > 0.0:
		return mouse_dir.normalized()
	if prev != Vector2.ZERO:
		return prev
	if move_dir != Vector2.ZERO:
		return move_dir.normalized()
	return Vector2.DOWN


## Pure movement integration: returns the next velocity given the current
## velocity, the (already deadzone-applied, length-clamped) input direction, and
## delta. Accelerates toward input_dir * max_speed when there is input; applies
## friction toward zero otherwise. Kept separate from _physics_process so it is
## unit-testable headlessly without a physics space — see tests/.
func step_velocity(current: Vector2, input_dir: Vector2, delta: float) -> Vector2:
	if input_dir != Vector2.ZERO:
		# R3 seam: scale top speed by the cached exposure penalty mult (1.0 = no
		# penalty). Acceleration is left untouched; only the speed cap changes.
		var target: Vector2 = input_dir * (stats.max_speed * _exposure_speed_mult)
		return current.move_toward(target, stats.acceleration * delta)
	return current.move_toward(Vector2.ZERO, stats.friction * delta)


func _update_facing_visual() -> void:
	# Greybox only: point the optional "nose" marker along the aim (facing tracks
	# aim post-L6, so the nose now turns toward the mouse / right stick, not the
	# movement direction). No-op until a directional sprite exists; null-guarded.
	if _nose != null:
		_nose.rotation = aim.angle()
