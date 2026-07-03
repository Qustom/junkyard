class_name ChaseMove
extends OppositionComponent
## ChaseMove (S2) — the R1 pursuer's chase movement, transplanted VERBATIM from
## hazard_entity.gd `_chase()` (movement half: live-depth speed scaling, straight
## steer, move_and_slide, and the I2 anti-wall-stick de-pin). The catch test that
## followed it in the original lives in LethalContact — the host calls the two in
## the original order with no intervening work (S2 Resolved Decisions Q1).
##
## Reused by: R1 pursuer; the S6b Splitter (slow pursuit variant).
## Params read: `chase_speed`, `speed_per_depth`. Host must be a CharacterBody2D.

## Greybox-internal feel knob (NOT a RunConfig field) — moved with the block it
## gates (I2 §2.2 (a)): below this fraction of the intended frame displacement
## WHILE touching a wall == "grinding" → arm a de-pin for the next frame.
const STALL_FRACTION := 0.35

var _chase_speed: float = 0.0
var _speed_per_depth: float = 0.0
var _depin_dir: Vector2 = Vector2.ZERO   # if non-zero, NEXT frame steers along this
                                         # wall-tangent instead of straight at the player


func _configure(p: Dictionary, _ctx: Dictionary) -> void:
	_chase_speed = float(p.get("chase_speed", 0.0))
	_speed_per_depth = float(p.get("speed_per_depth", 0.0))
	_depin_dir = Vector2.ZERO            # setup() reset, as the legacy entity did


## The movement block of hazard_entity.gd `_chase()`, operation-for-operation.
## `depth` is the live within-band depth the HOST read this frame (one read per
## frame at the top of the chase, exactly as the original did).
func tick_chase(_delta: float, depth: int) -> void:
	var body := host as CharacterBody2D
	var speed: float = _chase_speed + _speed_per_depth * float(depth)

	var to_player: Vector2 = player.global_position - body.global_position
	var chase_dir: Vector2 = to_player.normalized() if to_player.length() > 0.001 else Vector2.ZERO

	# Anti-wall-stick (§2.2 (a)): if last frame we were grinding a wall, steer along the
	# wall-tangent toward the player THIS frame (walk to the opening, not into the wall);
	# else chase straight. One-shot — consumed each frame, re-armed below if still stuck.
	var dir: Vector2 = _depin_dir if _depin_dir != Vector2.ZERO else chase_dir
	_depin_dir = Vector2.ZERO

	body.velocity = dir * speed
	body.move_and_slide()   # walls (layer `world`) stop it; REFUGE intact — wall-collision kept.

	# Grind detection: barely moved this frame WHILE touching a wall → we're pinned.
	# Arm a de-pin for next frame: tangent along the contacted wall, oriented toward the
	# player. NO pathfinding — uses only move_and_slide's own collision results (§2.2).
	if body.get_slide_collision_count() > 0 \
			and body.get_real_velocity().length() < speed * STALL_FRACTION:
		var col := body.get_last_slide_collision()
		if col != null:
			var n: Vector2 = col.get_normal()
			var tangent: Vector2 = Vector2(-n.y, n.x)          # wall tangent
			if tangent.dot(to_player) < 0.0:
				tangent = -tangent                              # orient toward the player
			if tangent.length() > 0.001:
				_depin_dir = tangent.normalized()
