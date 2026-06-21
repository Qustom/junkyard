class_name PingPongHazard
extends CharacterBody2D
## PingPongHazard (K5a, M1.4) — a throwaway greybox "bouncer": a colored shape that
## travels in a straight line at a constant speed, bounces off walls, and ends the run
## if it touches the player. No state machine, no chase, no awaken — it is live from
## spawn. Confined to its room via wall-bounce + an optional room-rect clamp (OQ-1).
## Mirrors HazardEntity's structure (CharacterBody2D, setup() snapshot, Tell polygon,
## distance-test kill).
##
## Collision: body on layer `hazard` (5), masks `world` (2) ONLY — identical to
## HazardEntity. Walls (the `world` layer) bounce it; it does NOT mask `player`
## (the kill is a script distance test, deterministic) nor `hazard` (bouncers never
## block each other — they pass through, no inter-hazard pinball).
##
## ALL-OFF: with hpp_enabled = false the spawn seam (K5i) never instantiates this node,
## so the M1.0 baseline is byte-for-byte unchanged. This entity NEVER calls the global
## RNG autoload — any per-instance variation (the initial heading) is supplied by K5i
## via spawn_ctx as a deterministic function of spawn index, so the fingerprint is
## never moved (entities are pure run-state at materialisation).

## Greybox tell color — DISTINCT from R1 (grey-blue/red) and the other M1.4 hazards.
## Amber "live projectile" read — "a thing in motion that will hurt you" (OQ-7, the
## final palette is a Director/character-animator call ratified at RG1).
const COLOR_LIVE := Color(0.95, 0.65, 0.15)     # amber

## Contact radius (px): distance at/under which touching the player kills. Self-contained
## greybox constant (NOT a RunConfig knob — keeps the CFG knob count pinned, like
## HazardEntity's NONFATAL_* constants). Floored at the visual body sum so "touch" reads
## honestly: player_r 14 + hazard_r 10 = 24 (run_config.gd:69-71).
const CONTACT_RADIUS := 24.0

## One-shot squash juice on bounce: scale up briefly so each bounce reads as an impact.
## Pure juice — if the tree is paused/headless the color+motion carry the state.
## Scope-safe (no sprite sheets / AnimationTree).
const SQUASH_SCALE := 1.15
const SQUASH_TIME := 0.06

var _cfg: RunConfig                 # snapshot of GameState.active_run_config at setup
var _player: Node2D                 # resolved at setup via the "player" group
var _speed: float = 0.0             # snapshot of hpp_speed (px/s)
var _dir: Vector2 = Vector2.RIGHT   # intended unit heading — the SOURCE OF TRUTH for the bounce.
                                    # BUG8: reflect THIS off wall normals, never the post-slide
                                    # velocity (which move_and_slide projects ALONG the wall —
                                    # feeding it back into the bounce collapsed the heading to
                                    # wall-parallel in corners → grinding/stalling).
var _killed_latched: bool = false   # one-shot telemetry latch (BUG6 pattern) — NOT a fail_run guard
var _spawn_time: float = 0.0        # self-timed run clock for the telemetry run_t_ms (R1 §4 pattern)

# OQ-1 (confinement): the room's world-space bounds, set from spawn_ctx. The empty Rect2
# (no area) == "no clamp" (pure wall-bounce confinement). When non-empty the entity also
# reflects at the rect edges so a bouncer can never leak through a doorway into the next room.
var _room_bounds: Rect2 = Rect2()

@onready var _tell: Polygon2D = $Tell


## Bind config + player + the per-instance spawn context. Called by K5i's spawn seam right
## after add_child (mirrors HazardEntity.setup). LOCKED cross-cutting signature (Phase-3):
## setup(cfg, player, spawn_ctx) — all three M1.4 hazards share it; each reads only its keys.
## ping-pong reads: spawn_ctx["initial_dir"] (Vector2, default RIGHT) and
## spawn_ctx["room_bounds"] (Rect2, default empty = pure-wall confinement). An empty dict
## constructs safely (defaults below) so an unwired instance is still valid.
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_speed = maxf(cfg.hpp_speed, 0.0) if cfg != null else 0.0
	_room_bounds = spawn_ctx.get("room_bounds", Rect2())
	_killed_latched = false
	_spawn_time = 0.0
	var initial_dir: Vector2 = spawn_ctx.get("initial_dir", Vector2.RIGHT)
	_dir = initial_dir.normalized() if initial_dir.length() > 0.001 else Vector2.RIGHT
	velocity = _dir * _speed
	if _tell != null:
		_tell.color = COLOR_LIVE


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return
	_spawn_time += delta

	# --- Travel + bounce ----------------------------------------------------
	# Drive from the intended heading _dir (NOT the post-slide velocity). Each frame:
	#   velocity = _dir * _speed → move_and_slide() → reflect _dir off the wall normal(s).
	# BUG8 FIX: the previous code reflected the POST-move_and_slide velocity, which
	# move_and_slide had already projected ALONG the wall (tangential). In a glancing hit
	# or a corner that tangential vector points nearly wall-parallel, so bounce() couldn't
	# restore the real incoming heading — the bouncer ground along the wall and stalled at
	# a corner. Reflecting the intended heading _dir keeps the ping-pong angle exact and the
	# speed constant forever (the tangential mutation never feeds back into the bounce).
	velocity = _dir * _speed
	move_and_slide()
	var hits := get_slide_collision_count()
	if hits > 0:
		# A corner = two (or more) contacts in one frame. Summing the slide normals (each a
		# unit vector) yields the resultant "away from the corner" normal; reflecting _dir off
		# it reverses the bouncer out of the corner instead of trapping it between two walls.
		var n := Vector2.ZERO
		for i in hits:
			var col := get_slide_collision(i)
			if col != null:
				n += col.get_normal()
		if n.length() > 0.001:
			n = n.normalized()
			# Reflect only when still heading INTO the (resultant) wall (dot < 0), so we never
			# double-flip on a frame where the heading already points away (prevents jitter).
			if _dir.dot(n) < 0.0:
				_dir = _dir.bounce(n).normalized()
				velocity = _dir * _speed
				_squash_on_bounce()

	# --- Room-rect clamp (OQ-1): hard-confine to the room rect as belt-and-braces.
	# Reflect at the rect edges so a bouncer can never leak through a doorway into the
	# next room even when wall-bounce alone would let it. No-op when _room_bounds is the
	# empty Rect2 (pure-wall mode).
	if _room_bounds.has_area():
		_confine_to_room()

	# --- Lethal contact test (deterministic distance test, like HazardEntity) ----
	# CONTACT_RADIUS is fixed; touching the player kills outright. One-shot telemetry
	# latch (BUG6 pattern): emit new_hazard_killed exactly once on the rising edge, but
	# ALWAYS let fail_run run (its _run_ended guard owns run-end idempotency — we never
	# gate the call itself).
	var in_contact: bool = global_position.distance_to(_player.global_position) <= CONTACT_RADIUS
	if in_contact and not _killed_latched:
		_killed_latched = true
		_on_contact()
	elif not in_contact:
		_killed_latched = false


## A lethal touch lands. Emit the K0-declared telemetry row, then route the death through
## the EXISTING fatal path (no new reason, no local "already ended" bool that PREVENTS it).
func _on_contact() -> void:
	var run_t_ms: int = int(_spawn_time * 1000.0)
	var depth: int = GameState.current_depth_index   # live within-band depth (BUG2)
	EventBus.new_hazard_killed.emit(&"pingpong", depth, run_t_ms)
	GameState.fail_run(&"death")   # existing end path; its _run_ended guard de-dupes.


## OQ-1 clamp: if the body crossed a room-rect edge this frame, snap it back inside and
## reflect the perpendicular component. Pure run-state math, no physics — complementary to
## the wall-bounce above (wall-bounce handles concave/L interiors).
## BUG8: flip the perpendicular component of _dir (the heading source of truth), not just
## velocity — velocity is recomputed from _dir at the top of every frame, so a velocity-only
## flip here would be discarded next frame and the bouncer would walk back through the edge.
## velocity is kept synced so it reads consistent within this same frame.
func _confine_to_room() -> void:
	var p := global_position
	if p.x < _room_bounds.position.x or p.x > _room_bounds.end.x:
		_dir.x = -_dir.x
		p.x = clampf(p.x, _room_bounds.position.x, _room_bounds.end.x)
	if p.y < _room_bounds.position.y or p.y > _room_bounds.end.y:
		_dir.y = -_dir.y
		p.y = clampf(p.y, _room_bounds.position.y, _room_bounds.end.y)
	global_position = p
	velocity = _dir * _speed


# --- Greybox tell juice (inline placeholder, no sprite sheets / AnimationTree) ------

## One-shot squash-and-settle on a bounce so the impact reads. Pure juice; the color +
## constant motion already carry the state if the tree is paused/headless.
func _squash_on_bounce() -> void:
	if _tell == null:
		return
	var tw := create_tween()
	tw.tween_property(_tell, "scale", Vector2(SQUASH_SCALE, SQUASH_SCALE), SQUASH_TIME)
	tw.tween_property(_tell, "scale", Vector2.ONE, SQUASH_TIME)
