class_name PatrolMove
extends OppositionComponent
## PatrolMove (S2) — the R1 pursuer's L2 spawn-room-bound slow patrol, transplanted
## VERBATIM from hazard_entity.gd `_patrol()` / `_build_patrol_endpoints()` /
## `_confine_to_room()`. RNG-FREE endpoints (left-mid ↔ right-mid of the room rect,
## inset PATROL_EDGE_MARGIN — pure deterministic function of the rect, RD-7).
##
## The catch-latch re-arm that was the original `_patrol()`'s FIRST line stays a
## HOST-orchestrated call (`_lethal.rearm_latch()` immediately before tick_patrol)
## so the statement order is preserved line-for-line (Resolved Decisions Q1).
##
## Reused by: R1 room-bound mode; candidate S6b Splitter idle.
## Params read: `patrol_speed`. Ctx read: `room_bounds`. Host must be a CharacterBody2D.

## Inset (px) from the room rect's left/right edge for the patrol endpoints, so the
## pacer doesn't grind the wall it would otherwise reach. Greybox-internal constant.
const PATROL_EDGE_MARGIN := 12.0
## Arrival epsilon (px): within this of the current endpoint, flip to the other leg.
const PATROL_ARRIVE_EPS := 6.0

var _patrol_speed: float = 0.0
var _room_bounds: Rect2 = Rect2()
var _patrol_endpoints: Array[Vector2] = []
var _patrol_leg: int = 0


func _configure(p: Dictionary, ctx: Dictionary) -> void:
	_patrol_speed = float(p.get("patrol_speed", 0.0))
	_room_bounds = ctx.get("room_bounds", Rect2())
	_build_patrol_endpoints()


## Derive the two patrol endpoints from _room_bounds — left-mid ↔ right-mid, inset
## PATROL_EDGE_MARGIN from each side. PURE deterministic function of the rect (NO
## seeded-stream draw — RD-7), recomputed at bind. Empty rect → no endpoints (patrol
## collapses to the idle-pivot fallback in tick_patrol). The margin is clamped so a
## thin room never inverts the endpoints (left stays ≤ right).
func _build_patrol_endpoints() -> void:
	_patrol_endpoints.clear()
	_patrol_leg = 0
	if not _room_bounds.has_area():
		return
	var cy := _room_bounds.get_center().y
	var margin := minf(PATROL_EDGE_MARGIN, _room_bounds.size.x * 0.5)
	var left := Vector2(_room_bounds.position.x + margin, cy)
	var right := Vector2(_room_bounds.end.x - margin, cy)
	_patrol_endpoints = [left, right]
	# Start toward whichever endpoint is farther, so a hazard spawned near one edge
	# walks the full beat (purely cosmetic; deterministic).
	if host.global_position.distance_to(left) < host.global_position.distance_to(right):
		_patrol_leg = 1


## Slow patrol while the player is OUTSIDE the spawn room. NO catch test runs here
## (RD-2) — patrol is pure locomotion. patrol_speed == 0 (or no endpoints) ⇒
## idle-pivot: stand still, no translation (still gates chase, just doesn't wander).
func tick_patrol(_delta: float) -> void:
	var body := host as CharacterBody2D
	if _patrol_speed <= 0.0 or _patrol_endpoints.size() < 2:
		body.velocity = Vector2.ZERO   # idle-pivot fallback — no roaming, still gates chase.
		body.move_and_slide()
		return
	var target: Vector2 = _patrol_endpoints[_patrol_leg]
	if body.global_position.distance_to(target) <= PATROL_ARRIVE_EPS:
		_patrol_leg = 1 - _patrol_leg            # flip to the other endpoint
		target = _patrol_endpoints[_patrol_leg]
	var to_t: Vector2 = target - body.global_position
	var dir: Vector2 = to_t.normalized() if to_t.length() > 0.001 else Vector2.ZERO
	body.velocity = dir * _patrol_speed
	body.move_and_slide()
	_confine_to_room()                           # belt-and-braces clamp (RD-7)


## Clamp the body back inside _room_bounds if move_and_slide drifted it past an edge
## (position clamp only — the pacer's heading is recomputed each frame from the
## endpoint, so no heading reflect is needed).
func _confine_to_room() -> void:
	if not _room_bounds.has_area():
		return
	host.global_position = Vector2(
		clampf(host.global_position.x, _room_bounds.position.x, _room_bounds.end.x),
		clampf(host.global_position.y, _room_bounds.position.y, _room_bounds.end.y))
