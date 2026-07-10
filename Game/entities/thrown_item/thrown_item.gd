class_name ThrownItem
extends Area2D
## ThrownItem (L1, M1.5) — a transient thrown inventory item projectile.
##
## PURE RUN-STATE: it carries a JunkItem removed from RunInventory and flies in a
## straight line in the player's facing direction. It never persists, never feeds
## fingerprint(), and is parented under MainGame's _band_container so _clear_band()
## disposes it with the band (no leak).
##
## Collision (Phase-4 lock): Area2D, collision_layer = 0 (it is no one's target),
## collision_mask = world(2) | hazard(16) = 18, body_entered-driven.
##   - Hit a `hazard`-group body (the R1 HazardEntity pursuer OR the K5 ping-pong
##     CharacterBody2D): queue_free() the body (kill) + destroy the projectile +
##     CONSUME the item (NOT re-dropped). Emits EventBus.opposition_event(&"killed_by_throw").
##   - Miss (a `world` body/wall, OR travel reaches max_range, OR a hidden in-script
##     lifetime fallback expires): re-drop the item via EventBus.junk_dropped (the
##     existing JunkSpawner re-spawn path → a grabbable pickup) + EventBus.throw_missed.
##
## One-shot `_spent` guard: a kill/miss resolves EXACTLY once (body_entered can fire
## the same frame max_range is exceeded). Reuses JunkPickup's greybox look so a thrown
## item visually reads as the item it is.

## The carried item. Nulled on a kill (consumed); handed to junk_dropped on a miss.
var _item: JunkItem = null
var _dir: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _max_range: float = 0.0
var _start: Vector2 = Vector2.ZERO
var _depth: int = 0
var _spent: bool = false

## Belt-and-braces in-script lifetime so a projectile that somehow overlaps nothing
## can't live forever (RD-3). NOT a RunConfig knob — an in-script feel/safety constant
## (mirrors hazard_entity.gd's NONFATAL_*/STALL_FRACTION). max_range is the design rule.
const MAX_LIFETIME_S := 5.0
var _age_s: float = 0.0

@onready var _greybox: Node2D = $Greybox


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if _greybox != null:
		_greybox.connect("draw", _draw_greybox.bind(_greybox))
		_greybox.queue_redraw()


## Initialise the projectile. `dir` is the throw direction (player.aim — L6), `speed`/
## `max_range` come from the throw_* knobs, `depth` is the current within-band depth
## stamped onto the telemetry rows. Called by MainGame right after add_child + setting
## global_position to the player's position.
func setup(item: JunkItem, dir: Vector2, speed: float, max_range: float, depth: int) -> void:
	_item = item
	_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	_speed = speed
	_max_range = max_range
	_depth = depth
	_start = global_position
	if _greybox == null:
		_greybox = get_node_or_null("Greybox")
	if _greybox != null:
		_greybox.queue_redraw()


func _physics_process(delta: float) -> void:
	if _spent:
		return
	global_position += _dir * _speed * delta
	_age_s += delta
	# Max-range is the gameplay miss rule; the lifetime is the safety fallback.
	if (_max_range > 0.0 and global_position.distance_to(_start) >= _max_range) \
			or _age_s >= MAX_LIFETIME_S:
		_miss()


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	if body != null and body.is_in_group(&"hazard"):
		_hit_hazard(body)
	else:
		_miss()   # a `world` wall body (the only other thing in mask 18)


## Hit a hazard-layer body → kill it + destroy the item (consumed, NOT re-dropped).
## kind = the body's type for the telemetry row (&"pursuer" for the R1 HazardEntity,
## &"pingpong" for the K5 bouncer, else the node name lower-cased as a fallback).
##
## S2 (M1.9, Resolved Decisions Q5 — the LOCKED delegation seam): the generic
## opposition_event(&"killed_by_throw") emit is FIRST (V2 retired the legacy
## throw_killed_hazard signal; the &"killed_by_throw" event carries the hazard kind
## as its id — the throwing item_id is no longer on the signal payload but still
## rides the local killer_ctx below), then the duck-typed death dispatch: a body
## implementing `resolve_throw_death(killer_ctx) -> bool` may handle its own death
## (true = "do not free me again" — S6b's Splitter splits then frees itself);
## false/absent = today's queue_free(), verbatim, same frame, same call order.
func _hit_hazard(body: Node) -> void:
	_spent = true
	var item_id: StringName = _item.id if _item != null else &""
	var kind: StringName = _hazard_kind(body)
	EventBus.opposition_event.emit(kind, &"killed_by_throw", _depth, _run_t_ms())
	var handled := false
	if body.has_method(&"resolve_throw_death"):
		handled = body.resolve_throw_death({
			"item_id": item_id, "kind": kind,
			"depth": _depth, "run_t_ms": _run_t_ms()})   # primitives-only killer_ctx
	if not handled:
		body.queue_free()    # R1/ping-pong have no health → free outright (kill)
	_item = null             # consumed on a kill
	queue_free()


## Miss → re-drop the item via the existing junk_dropped path + emit throw_missed.
func _miss() -> void:
	_spent = true
	var item_id: StringName = _item.id if _item != null else &""
	EventBus.throw_missed.emit(item_id, _depth, _run_t_ms())
	if _item != null:
		# REUSE: JunkSpawner._on_junk_dropped re-spawns a grabbable JunkPickup here.
		EventBus.junk_dropped.emit(_item, global_position)
	queue_free()


## The telemetry `kind` for a killed hazard body. Typed checks first (the locked
## scope: pursuer + ping-pong — byte-identical results for the legacy hazards), then
## the S2 duck-typed def-id check (Q5 rider: service-spawned nodes get auto-
## uniquified sibling names, so the raw-name fallback would log a mangled kind like
## &"@splitter@3" — get_def_id() gives S6a/S6b stable telemetry kinds for free),
## then the name fallback so any other body still logs a sensible kind.
func _hazard_kind(body: Node) -> StringName:
	if body is HazardEntity:
		return &"pursuer"
	if body is PingPongHazard:
		return &"pingpong"
	if body.has_method(&"get_def_id"):
		return StringName(body.call(&"get_def_id"))
	return StringName(String(body.name).to_lower())


## Monotonic ms timestamp for the telemetry rows. Time.get_ticks_msec() is the same
## engine clock GameState brackets the run with; RG2 only needs in-run ordering.
func _run_t_ms() -> int:
	return Time.get_ticks_msec()


## Greybox look — copied from JunkPickup._draw_greybox so a thrown item reads as the
## item it is (RECT/CIRCLE/TRIANGLE/DIAMOND, half-extent 10px). No reject-flash here.
func _draw_greybox(canvas: Node2D) -> void:
	if _item == null:
		return
	var col: Color = _item.greybox_color
	var r := 10.0
	match _item.greybox_shape:
		JunkItem.GreyboxShape.CIRCLE:
			canvas.draw_circle(Vector2.ZERO, r, col)
		JunkItem.GreyboxShape.TRIANGLE:
			var tri := PackedVector2Array([
				Vector2(0, -r), Vector2(r, r), Vector2(-r, r)])
			canvas.draw_colored_polygon(tri, col)
		JunkItem.GreyboxShape.DIAMOND:
			var dia := PackedVector2Array([
				Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
			canvas.draw_colored_polygon(dia, col)
		_:  # RECT (default)
			canvas.draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), col)
