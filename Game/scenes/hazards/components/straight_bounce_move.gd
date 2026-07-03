class_name StraightBounceMove
extends OppositionComponent
## StraightBounceMove (S2) — the K5a ping-pong bouncer's travel + wall-bounce +
## room-rect clamp, transplanted VERBATIM from pingpong_hazard.gd. Preserves the
## BUG8 heading-source-of-truth semantics exactly: `_dir` (the intended unit
## heading) is what reflects off the SUMMED slide normals — never the post-slide
## velocity, which move_and_slide projects along the wall.
##
## Reused by: pingpong only today — but it is the closest cousin of S6a's dash.
## Params read: `speed`. Ctx read: `initial_dir`, `room_bounds`.
## Host must be a CharacterBody2D. `on_bounce` is the host's juice hook (squash).

var _speed: float = 0.0
var _dir: Vector2 = Vector2.RIGHT   # intended unit heading — the SOURCE OF TRUTH (BUG8)
var _room_bounds: Rect2 = Rect2()

## Host juice hook, invoked on each wall/corner bounce (pure presentation).
var on_bounce: Callable = Callable()


func _configure(p: Dictionary, ctx: Dictionary) -> void:
	_speed = float(p.get("speed", 0.0))
	_room_bounds = ctx.get("room_bounds", Rect2())
	var initial_dir: Vector2 = ctx.get("initial_dir", Vector2.RIGHT)
	_dir = initial_dir.normalized() if initial_dir.length() > 0.001 else Vector2.RIGHT
	(host as CharacterBody2D).velocity = _dir * _speed   # legacy setup() seeded velocity


func tick(_delta: float) -> void:
	var body := host as CharacterBody2D
	# Drive from the intended heading _dir (NOT the post-slide velocity). Each frame:
	#   velocity = _dir * _speed → move_and_slide() → reflect _dir off the wall normal(s).
	# BUG8 FIX preserved: reflecting the intended heading keeps the ping-pong angle exact
	# and the speed constant forever (the tangential mutation never feeds the bounce).
	body.velocity = _dir * _speed
	body.move_and_slide()
	var hits := body.get_slide_collision_count()
	if hits > 0:
		# A corner = two (or more) contacts in one frame. Summing the slide normals (each a
		# unit vector) yields the resultant "away from the corner" normal; reflecting _dir off
		# it reverses the bouncer out of the corner instead of trapping it between two walls.
		var n := Vector2.ZERO
		for i: int in hits:
			var col := body.get_slide_collision(i)
			if col != null:
				n += col.get_normal()
		if n.length() > 0.001:
			n = n.normalized()
			# Reflect only when still heading INTO the (resultant) wall (dot < 0), so we never
			# double-flip on a frame where the heading already points away (prevents jitter).
			if _dir.dot(n) < 0.0:
				_dir = _dir.bounce(n).normalized()
				body.velocity = _dir * _speed
				if on_bounce.is_valid():
					on_bounce.call()

	# Room-rect clamp (OQ-1): hard-confine to the room rect as belt-and-braces. No-op
	# when _room_bounds is the empty Rect2 (pure-wall mode).
	if _room_bounds.has_area():
		_confine_to_room()


## If the body crossed a room-rect edge this frame, snap it back inside and reflect
## the perpendicular component OF _dir (the heading source of truth — BUG8): velocity
## is recomputed from _dir at the top of every frame, so a velocity-only flip would be
## discarded next frame. velocity is kept synced so it reads consistent this frame.
func _confine_to_room() -> void:
	var body := host as CharacterBody2D
	var p := body.global_position
	if p.x < _room_bounds.position.x or p.x > _room_bounds.end.x:
		_dir.x = -_dir.x
		p.x = clampf(p.x, _room_bounds.position.x, _room_bounds.end.x)
	if p.y < _room_bounds.position.y or p.y > _room_bounds.end.y:
		_dir.y = -_dir.y
		p.y = clampf(p.y, _room_bounds.position.y, _room_bounds.end.y)
	body.global_position = p
	body.velocity = _dir * _speed
