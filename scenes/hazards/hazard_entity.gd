class_name HazardEntity
extends CharacterBody2D
## HazardEntity (R1, M1.1) — the greybox "pursuing / awakening hazard": a throwaway
## colored shape that wakes up the deeper or longer the player goes and chases them,
## ending the run if it catches them.
##
## THROWAWAY GREYBOX, not the M2 enemy-AI slice (R1 spec §0). No combat, no health,
## no pathfinding/navmesh/behaviour-tree/steering library — just a CharacterBody2D
## that lerps straight at the player via move_and_slide() (walls stop it; getting
## stuck behind geometry is a *feature*, a partial refuge — R1 §2.3).
##
## READS ONLY, never widens locked contracts (R1 §0):
##   - reads GameState.active_run_config (R0) for its r1_* knobs (snapshotted at setup);
##   - reads GameState.current_depth_index (BUG2) live for the awaken trigger + speed math;
##   - EMITS the pre-declared EventBus.hazard_awoke / hazard_caught (never edits event_bus.gd);
##   - routes a fatal catch through the EXISTING GameState.fail_run(&"death") — no new
##     end path, no local "already ended" guard (GameState's _run_ended guard owns
##     idempotency across hazards + extract; R1 §2.4 / §5 idempotency note).
##
## ALL-OFF: with r1_enabled = false the spawn seam never instantiates this node, so
## the M1.0 baseline is byte-for-byte unchanged (no node, no telemetry, no behaviour).
##
## Collision: body on layer `hazard` (5), masks `world` (2) ONLY — walls stop it; it
## does NOT mask `player` (catch is a script distance test, deterministic — §9 Q3) and
## does NOT mask `hazard` (multiple hazards never collide/block each other — §9 Q3).

enum State { DORMANT, AWAKE }

## Greybox tell colors (character-animator inline contribution, R1 §3). Cool/desaturated
## when dormant → hot/alarm-red the frame it wakes. A hard color flip is acceptable; we
## add a one-shot wake-flash scale Tween on top so the awaken beat reads.
const COLOR_DORMANT := Color(0.35, 0.4, 0.5)    # dim grey-blue, "asleep"
const COLOR_AWAKE := Color(0.9, 0.2, 0.2)       # alarm red, "hunting"

# --- Non-fatal catch tuning (r1_catch_kills = false path, §2.5 / §9 Q2) -------
# Self-contained constants — NOT RunConfig knobs (R0's schema has no non-fatal-cost
# fields; adding them is an out-of-scope R0 follow-up, §9). Knockback + brief stun +
# short cooldown, no other-system coupling.
const NONFATAL_KNOCKBACK_SPEED := 220.0   # px/s impulse pushed onto the player away from us
const NONFATAL_STUN_SECONDS := 0.35       # hazard freezes (doesn't chase) briefly after a hit
const NONFATAL_COOLDOWN_SECONDS := 1.0    # min seconds between catches (also stops per-frame re-fire)

# --- Anti-wall-stick closing (I2, §2.2 option (a) — REFUGE, Director FINAL) ----
# The hazard KEEPS wall collision (collision_mask `world`): walls are a deliberate
# partial hiding place — the player can break line-of-sight to escape. The fix for
# the M1.1 "wall-grind forever" bug (catch never fired) is a cheap de-pin: when the
# body barely moves while touching a wall, it is grinding it, so the NEXT frame we
# steer along the wall toward the player's side (walk to the opening) instead of
# grinding into it. NO pathfinding/navmesh — pure local move_and_slide collision math.
# Coupled with the r10 body shrink (.tscn), plain slide already mostly closes; this
# only handles the corner/perpendicular-grind residual.
#
# Greybox-internal feel knob (NOT a RunConfig field — like the non-fatal constants
# above; the Director edits it here). Below this fraction of the intended frame
# displacement WHILE touching a wall == "grinding" → trigger a de-pin. Too high →
# false de-pins in open rooms; too low → never de-pins (§2.2, Phase-3 correction 2).
const STALL_FRACTION := 0.35

# --- L2 (M1.5): spawn-room-bound patrol (Director-LOCKED) ----------------------
# When r1_spawn_room_only is ON and the entity learned its spawn-room bounds (via
# spawn_ctx["room_bounds"]), the AWAKE behaviour splits: CHASE only while the player
# is inside that room (_room_bounds.has_point), else SLOW PATROL — pace between two
# deterministic endpoints inside the room at r1_patrol_speed. Catch fires ONLY inside
# _chase() (no catch while patrolling). Empty/unknown bounds OR r1_spawn_room_only OFF
# ⇒ today's chase-everywhere behaviour, byte-identical. RNG-FREE endpoints (pure run-
# state determinism, like pingpong_hazard.gd:16-19). Knob default off = baseline parity.

## Inset (px) from the room rect's left/right edge for the patrol endpoints, so the
## pacer doesn't grind the wall it would otherwise reach. Greybox-internal constant
## (NOT a RunConfig knob — like the NONFATAL_* / STALL_FRACTION constants above).
const PATROL_EDGE_MARGIN := 12.0
## Arrival epsilon (px): within this of the current endpoint, flip to the other leg.
const PATROL_ARRIVE_EPS := 6.0

var _cfg: RunConfig                  # snapshot of GameState.active_run_config at setup
var _state: int = State.DORMANT
var _time_in_band: float = 0.0       # seconds since setup (≈ band entry ≈ run start in M1)
var _player: Node2D                  # resolved at setup via the "player" group
var _pending_trigger: StringName = &"depth"   # which condition fired the awaken (telemetry)
var _catch_cooldown: float = 0.0     # >0 → can't catch again yet (non-fatal path)
var _stun: float = 0.0               # >0 → frozen, doesn't chase (non-fatal path)
var _depin_dir: Vector2 = Vector2.ZERO   # I2: if non-zero, NEXT AWAKE frame steers along this
                                          # wall-tangent (toward the player) instead of straight
                                          # at the player — the anti-wall-stick de-pin (§2.2 (a)).
var _caught_latched: bool = false    # BUG6 (M1.3): true while the player is CONTINUOUSLY inside
                                          # catch radius. One-shot emit gate — hazard_caught fires once
                                          # on the rising edge into radius, re-arms on the falling edge
                                          # (player leaves). Kills the per-frame emit storm (was 85→2,199
                                          # events/run) WITHOUT moving the fatal-catch frame. Complements
                                          # GameState._run_ended run-end idempotency: that de-dupes the
                                          # run-end, this de-dupes the telemetry emit.

# L2 (M1.5): the spawn-room rect in WORLD space, set from spawn_ctx["room_bounds"]
# (mirrors pingpong_hazard.gd:52). Empty Rect2 (no area) == "no room known" → the
# r1_spawn_room_only gate falls back to chase-everywhere (RD-4, never freeze/crash).
var _room_bounds: Rect2 = Rect2()
# L2: the two RNG-free patrol endpoints (left-mid ↔ right-mid of _room_bounds, inset
# by PATROL_EDGE_MARGIN), derived once at setup from the bounds; _patrol_leg picks the
# active target. Pure deterministic function of _room_bounds (RD-7).
var _patrol_endpoints: Array[Vector2] = []
var _patrol_leg: int = 0
# L2: rising-edge latch for the hazard_pursuer_state telemetry mark (BUG6 pattern —
# emit once per patrol↔chase transition, no per-frame storm). Empty == no state emitted
# yet; the first AWAKE frame in room-bound mode emits the initial state.
var _last_pursuer_state: StringName = &""

@onready var _tell: Polygon2D = $Tell


## Bind the run config + player and seat the dormant tell. Called by the spawn seam
## (MainGame.start_new_run) right after add_child. Snapshots the config so a later
## active_run_config clear on run-end can't null it mid-frame.
##
## L2 (M1.5): widened to the K5 3-arg family signature setup(cfg, player, spawn_ctx)
## — back-compatible (an empty dict / a 2-arg call still works exactly as before). The
## entity reads spawn_ctx["room_bounds"] (a Rect2, default empty) to learn its spawn
## room, exactly as pingpong_hazard.gd:67 does. Empty bounds OR r1_spawn_room_only=false
## ⇒ today's chase-everywhere behaviour, byte-identical (the AWAKE branch falls through).
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_state = State.DORMANT
	_time_in_band = 0.0
	_depin_dir = Vector2.ZERO
	_caught_latched = false   # BUG6: a pooled/respawned hazard starts un-latched.
	_room_bounds = spawn_ctx.get("room_bounds", Rect2())
	_last_pursuer_state = &""
	_build_patrol_endpoints()
	if _tell != null:
		_set_tell_dormant()


## L2 (M1.5): derive the two patrol endpoints from _room_bounds — left-mid ↔ right-mid,
## inset PATROL_EDGE_MARGIN from each side. PURE deterministic function of the rect (NO
## RNG — RD-7), recomputed at setup. Empty rect → no endpoints (patrol collapses to the
## idle-pivot fallback in _patrol). The margin is clamped so a thin room never inverts
## the endpoints (left stays ≤ right).
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
	# walks the full beat (purely cosmetic; deterministic — no RNG).
	if global_position.distance_to(left) < global_position.distance_to(right):
		_patrol_leg = 1


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return
	_time_in_band += delta

	if _state == State.DORMANT:
		if _should_awaken():
			_awaken()
		return   # dormant: no movement, no catch test

	# --- AWAKE ---------------------------------------------------------------
	if _catch_cooldown > 0.0:
		_catch_cooldown -= delta
	if _stun > 0.0:
		# Briefly frozen after a non-fatal hit: bleed off any residual velocity, no chase.
		_stun -= delta
		velocity = velocity.move_toward(Vector2.ZERO, NONFATAL_KNOCKBACK_SPEED * delta)
		move_and_slide()
		return

	# L2 (M1.5): spawn-room-bound mode. ON only when r1_spawn_room_only AND we learned a
	# real room rect (RD-4: empty bounds fall back to chase-everywhere — never freeze). The
	# player IN the room → chase (today's exact chase+catch); OUT → slow patrol, no catch.
	# Immediate re-entry resume (RD-3). The rising-edge state mark (RD-5) tracks the flip.
	if _cfg.r1_spawn_room_only and _room_bounds.has_area():
		var in_room: bool = _room_bounds.has_point(_player.global_position)
		_emit_pursuer_state(&"chase" if in_room else &"patrol")
		if in_room:
			_chase(delta)
		else:
			_patrol(delta)
		return

	# r1_spawn_room_only OFF (or no bounds) → today's exact chase-everywhere code,
	# byte-identical to the M1.4 baseline (the all-off control + every prior cohort).
	_chase(delta)


## L2 (M1.5): today's chase+catch behaviour, factored out unchanged so the room-bound
## mode can gate it. CATCH lives ONLY here (RD-2) — a patrolling pursuer never runs the
## distance/latch test, so a player just outside the room rect is never caught.
func _chase(delta: float) -> void:
	var depth: int = GameState.current_depth_index   # BUG2 live within-band depth
	var speed: float = _cfg.r1_chase_speed + _cfg.r1_speed_per_depth * float(depth)

	var to_player: Vector2 = _player.global_position - global_position
	var chase_dir: Vector2 = to_player.normalized() if to_player.length() > 0.001 else Vector2.ZERO

	# Anti-wall-stick (§2.2 (a)): if last frame we were grinding a wall, steer along the
	# wall-tangent toward the player THIS frame (walk to the opening, not into the wall);
	# else chase straight. One-shot — consumed each frame, re-armed below if still stuck.
	var dir: Vector2 = _depin_dir if _depin_dir != Vector2.ZERO else chase_dir
	_depin_dir = Vector2.ZERO

	velocity = dir * speed
	move_and_slide()   # walls (layer `world`) stop it; REFUGE intact — wall-collision kept.

	# Grind detection: barely moved this frame WHILE touching a wall → we're pinned.
	# Arm a de-pin for next frame: tangent along the contacted wall, oriented toward the
	# player. NO pathfinding — uses only move_and_slide's own collision results (§2.2).
	if get_slide_collision_count() > 0 \
			and get_real_velocity().length() < speed * STALL_FRACTION:
		var col := get_last_slide_collision()
		if col != null:
			var n: Vector2 = col.get_normal()
			var tangent: Vector2 = Vector2(-n.y, n.x)          # wall tangent
			if tangent.dot(to_player) < 0.0:
				tangent = -tangent                              # orient toward the player
			if tangent.length() > 0.001:
				_depin_dir = tangent.normalized()

	# Catch test: distance-based, deterministic, no physics overlap needed (§2.4).
	# Effective radius = flat r1_catch_radius + optional depth-scaled lunge (Q3 accepted,
	# Director FINAL). r1_catch_radius_per_depth defaults 0.0 → flat (all-off baseline).
	var catch_r: float = _cfg.r1_catch_radius + _cfg.r1_catch_radius_per_depth * float(depth)
	var in_range: bool = global_position.distance_to(_player.global_position) <= catch_r
	# BUG6 one-shot latch: emit hazard_caught exactly once on the RISING edge into catch
	# range and re-arm only on the FALLING edge (player leaves radius). The rising-edge
	# condition is the SAME conjunction as before (in-range AND cooldown clear), so the
	# fatal catch still fires on the identical frame — death timing / duration_s is
	# byte-identical for a given seed. A sustained pin in radius = ONE catch (kills the
	# per-frame storm); a genuine escape-and-re-catch still logs the second catch.
	if in_range and not _caught_latched and _catch_cooldown <= 0.0:
		_caught_latched = true
		_on_catch(depth)
	elif not in_range:
		_caught_latched = false   # re-arm only after the player has left the radius


## L2 (M1.5): slow patrol while the player is OUTSIDE the spawn room. Paces between the
## two RNG-free endpoints (left-mid ↔ right-mid of _room_bounds) at r1_patrol_speed. NO
## catch test runs here (RD-2) — patrol is pure locomotion. r1_patrol_speed == 0 (or no
## endpoints) ⇒ idle-pivot: stand still, no translation (still gates chase, just doesn't
## wander). Walls (layer `world`) still stop it via move_and_slide; a _confine_to_room
## clamp (RD-7) is belt-and-braces against move_and_slide drift past the rect edges.
func _patrol(_delta: float) -> void:
	# Patrolling re-arms the catch latch so a re-entry's first in-room frame can catch
	# cleanly (no stale latch carried out of the room).
	_caught_latched = false
	if _cfg.r1_patrol_speed <= 0.0 or _patrol_endpoints.size() < 2:
		velocity = Vector2.ZERO   # idle-pivot fallback — no roaming, still gates chase.
		move_and_slide()
		return
	var target: Vector2 = _patrol_endpoints[_patrol_leg]
	if global_position.distance_to(target) <= PATROL_ARRIVE_EPS:
		_patrol_leg = 1 - _patrol_leg            # flip to the other endpoint
		target = _patrol_endpoints[_patrol_leg]
	var to_t: Vector2 = target - global_position
	var dir: Vector2 = to_t.normalized() if to_t.length() > 0.001 else Vector2.ZERO
	velocity = dir * _cfg.r1_patrol_speed
	move_and_slide()
	_confine_to_room()                           # belt-and-braces clamp (RD-7)


## L2 (M1.5): clamp the body back inside _room_bounds if move_and_slide drifted it past
## an edge (mirrors pingpong_hazard.gd:148-157, minus the heading reflect — the pacer's
## heading is recomputed each frame from the endpoint, so a position clamp suffices).
func _confine_to_room() -> void:
	if not _room_bounds.has_area():
		return
	global_position = Vector2(
		clampf(global_position.x, _room_bounds.position.x, _room_bounds.end.x),
		clampf(global_position.y, _room_bounds.position.y, _room_bounds.end.y))


## L2 (M1.5): rising-edge-only telemetry mark for the patrol↔chase flip (RD-5, BUG6
## latch pattern — no per-frame storm). Self-times run_t_ms from _time_in_band exactly
## as _on_catch does (hazard_entity.gd self-clock — never invents a new clock). Only
## emitted in room-bound mode (the caller); the chase-everywhere path never marks state.
func _emit_pursuer_state(state: StringName) -> void:
	if state == _last_pursuer_state:
		return
	_last_pursuer_state = state
	var run_t_ms: int = int(_time_in_band * 1000.0)
	EventBus.hazard_pursuer_state.emit(state, GameState.current_depth_index, run_t_ms)


## Awaken when depth threshold is reached OR linger time elapses — first to fire.
## Latches awake for the run (called only from the DORMANT branch).
func _should_awaken() -> bool:
	if GameState.current_depth_index >= _cfg.r1_depth_threshold:
		_pending_trigger = &"depth"
		return true
	if _cfg.r1_linger_seconds > 0.0 and _time_in_band >= _cfg.r1_linger_seconds:
		_pending_trigger = &"linger"
		return true
	return false


## Transition dormant → awake ONCE: flip the tell hot (+ wake flash) and emit
## hazard_awoke. No re-sleep — once awake it stays awake the whole run (§9 Q4).
func _awaken() -> void:
	_state = State.AWAKE
	_set_tell_awake()
	EventBus.hazard_awoke.emit(GameState.current_depth_index, _pending_trigger)


## A catch lands. Always emit hazard_caught (fatal or non-fatal). Fatal → call the
## EXISTING GameState.fail_run(&"death") and let its _run_ended guard absorb dupes
## (no local "already ended" bool that PREVENTS the call — §5 idempotency note).
func _on_catch(depth: int) -> void:
	# run_t_ms: BUG1's run clock isn't exposed read-only off GameState/Telemetry, so
	# per §4 / §9 Q5 we self-time from spawn (≈ band entry ≈ run start in single-band M1).
	var run_t_ms: int = int(_time_in_band * 1000.0)
	EventBus.hazard_caught.emit(depth, run_t_ms)
	if _cfg.r1_catch_kills:
		GameState.fail_run(&"death")   # existing end path; its _run_ended guard is the
		                                # single source of truth for run-end idempotency.
	else:
		_apply_nonfatal_catch()


## Non-fatal cost (§2.5 / §9 Q2): knock the player back, briefly stun ourselves, and
## go on a short cooldown so we can't re-catch every frame. Fully self-contained — NO
## fail_run, NO item drop / clock / exposure coupling (that would entangle R1 with
## R2/R3/R4 and muddy the single-variable test). The chase then resumes.
func _apply_nonfatal_catch() -> void:
	var away: Vector2 = (_player.global_position - global_position)
	away = away.normalized() if away.length() > 0.001 else Vector2.RIGHT
	# `velocity` is the standard CharacterBody2D field — setting it on the player is a
	# read/write of an engine member, not an edit to player.gd. The player's own
	# move_and_slide carries the impulse; friction bleeds it off next frame.
	if _player is CharacterBody2D:
		(_player as CharacterBody2D).velocity = away * NONFATAL_KNOCKBACK_SPEED
	_stun = NONFATAL_STUN_SECONDS
	_catch_cooldown = NONFATAL_COOLDOWN_SECONDS


# --- Greybox tell (inline placeholder, no sprite sheets / AnimationTree) ------

func _set_tell_dormant() -> void:
	if _tell != null:
		_tell.color = COLOR_DORMANT


func _set_tell_awake() -> void:
	if _tell == null:
		return
	_tell.color = COLOR_AWAKE
	# One-shot "wake" flash: a quick scale-up-and-settle so the player registers the
	# beat. Over-scope-safe — if the tree is paused/headless the color flip already
	# carries the state; the Tween is pure juice.
	var tw := create_tween()
	tw.tween_property(_tell, "scale", Vector2(1.4, 1.4), 0.08)
	tw.tween_property(_tell, "scale", Vector2.ONE, 0.12)
