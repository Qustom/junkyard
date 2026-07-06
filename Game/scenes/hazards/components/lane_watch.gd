class_name LaneWatch
extends OppositionComponent
## LaneWatch (U2b, M1.11) — the ONE new opposition component of the Sentry's
## at-range/projectile proof: a stationary emplacement that watches ONE fixed lane
## (IDLE) → flashes when the player enters it (WINDUP, the authored lead) → fires a
## fast world-blockable BOLT down the lane (FIRE) → can't fire for cooldown_s
## (COOLDOWN) → IDLE. The bolt is a component-owned driven visual with a swept
## kills-gated lethal test (the ChargeLane segment idiom) + a world raycast STOP
## (the burrow_cycle null-safe direct-space idiom) — cover blocks it, which is why
## the sentry is counterable. Everything else is REUSED verbatim:
## kill = LethalContact(&"external"), tells = TelegraphFSM,
## throw-death = ThrowInteraction(&"die").
##
## LANE ACQUISITION (U2b Resolved Decisions A1–A3, binding):
##   - Acquired on the SECOND tick() — the 2D broadphase only reliably reflects
##     bodies added in the spawn frame after the next physics step, so a first-tick
##     ray could miss every wall and silently latch CANDIDATES[0]. Tick 1 does
##     nothing; tick 2 derives + latches; the FSM is gated on _acquired (A1).
##   - The derived clear LENGTH is latched WITH the direction (_lane_len_eff) and
##     drives the strip visual, the crossing test, and the bolt's max travel — a
##     dense-cover spawn degrades to a short, honestly-drawn lane with no fallback
##     machinery (A2). Cover is static in M1, so the latch can never go stale.
##   - Pause halts the host's _physics_process → no tick() → latch untouched;
##     re-setup() resets _ticks/_acquired and re-derives identically from the same
##     static geometry on its next second tick (A3).
##   - lane_dir_deg >= 0 forces an authored heading (socket-corridor future-proof);
##     the effective length is still ray-derived along that heading (A2).
##
## NEVER moves the host, NEVER touches group membership (the sentry is always
## throw-killable), NEVER self-ticks, NEVER emits telemetry (the host does, off
## on_state_changed). Deterministic and RNG-free: the lane derive is a pure function
## of the static world geometry + the seed-deterministic spawn cell; it is run-state
## and never feeds fingerprint().

enum State { IDLE, WINDUP, FIRE, COOLDOWN }

## Player body radius (player.tscn CircleShape2D) — the honest-contact floor; the
## swept kill corridor half-width is lane_width/2 + PLAYER_R (the ChargeLane idiom).
const PLAYER_R := 14.0
## The `world` collision layer (walls + cover footprints) the lane rays mask.
const WORLD_MASK := 2
## The derive candidate set: 8 octants in a FIXED order (strict-> longest pick +
## this order is the deterministic tie-break — OQ-2, 8 octants ratified).
const CANDIDATES: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP,
	Vector2(0.7071067811865476, 0.7071067811865476),
	Vector2(-0.7071067811865476, 0.7071067811865476),
	Vector2(-0.7071067811865476, -0.7071067811865476),
	Vector2(0.7071067811865476, -0.7071067811865476)]

## Reused seams (host-assigned at _ready, the ChargeLane.lethal idiom):
var lethal: LethalContact = null            # &"external"-mode kill sink (bolt sweep)
var on_state_changed: Callable = Callable()  # host paints tells + emits S0 rows here
## LaneWatch-owned sub-nodes (host-assigned; live in sentry.tscn — the breakdown's
## "projectile/marker sub-node lives inside the component's own scene ownership"):
var bolt: Node2D = null         # the $Bolt driven visual (hidden until FIRE)
var lane_vis: Polygon2D = null  # the $Lane strip (geometry owned here; color = host)

# --- snapshotted knobs (bound once via _configure; never re-read mid-run) --------
var _windup_s := 0.0
var _cooldown_s := 0.0
var _bolt_speed := 0.0
var _lane_length := 0.0
var _lane_width := 0.0
var _always_visible := true
var _body_edge := false
var _authored_dir_deg := -1.0

# --- run-state -------------------------------------------------------------------
var _state: int = State.IDLE
var _t := 0.0                     # time-in-state
var _ticks := 0                   # A1: acquisition waits for the SECOND tick
var _acquired := false            # lane derived + latched (FSM gated on this)
var _lane_dir := Vector2.RIGHT    # the LOCKED lane heading (source of truth)
var _lane_len_eff := 0.0          # the LATCHED effective clear length (A2)
var _muzzle := Vector2.ZERO       # bolt origin, captured at FIRE entry
var _bolt_pos := Vector2.ZERO     # bolt head (run-state)


func _configure(p: Dictionary, _ctx: Dictionary) -> void:
	_windup_s = maxf(float(p.get("windup_s", 0.0)), 0.0)
	_cooldown_s = maxf(float(p.get("cooldown_s", 0.0)), 0.0)
	_bolt_speed = maxf(float(p.get("bolt_speed", 0.0)), 0.0)
	_lane_length = maxf(float(p.get("lane_length", 0.0)), 0.0)
	_lane_width = float(p.get("lane_width", 28.0))
	_always_visible = bool(p.get("lane_always_visible", true))
	_body_edge = bool(p.get("fire_on_body_edge", false))
	_authored_dir_deg = float(p.get("lane_dir_deg", -1.0))
	# Re-setup resets the cycle WITHOUT firing the host hook (the family rule); the
	# host seats its own IDLE tell at setup(). Lane re-derived on the next second
	# tick from the same static geometry -> identical latch (A3).
	_state = State.IDLE
	_t = 0.0
	_ticks = 0
	_acquired = false
	_lane_len_eff = 0.0
	if bolt != null:
		bolt.visible = false
	if lane_vis != null:
		lane_vis.visible = false   # hidden until (re-)acquisition redraws it


## Called by the HOST each physics frame (fixed order; components never self-tick).
func tick(delta: float) -> void:
	if host == null or player == null or not is_instance_valid(player):
		return
	_ticks += 1
	if _ticks < 2:
		return                     # A1: broadphase not current on the spawn tick
	if not _acquired:
		_acquire_lane()            # derive + latch ONCE, on the second tick
		_acquired = true
		_update_lane_strip()
	_t += delta
	match _state:
		State.IDLE:
			if _player_in_lane_with_los():
				_enter(State.WINDUP)          # the lane is committed (already fixed)
		State.WINDUP:
			# NON-LETHAL for the whole lead — the bolt is not spawned yet. This is
			# the fairness line: no lethal test runs until FIRE.
			if _t >= _windup_s:
				if _bolt_speed <= 0.0:
					_enter(State.COOLDOWN)    # trap-neutral: 0 = no bolt, no threat
				else:
					_muzzle = host.global_position
					_bolt_pos = _muzzle
					if bolt != null:
						bolt.global_position = _bolt_pos
						bolt.visible = true
					_enter(State.FIRE)
		State.FIRE:
			_advance_bolt(delta)              # move + swept kill + world-block
		State.COOLDOWN:
			if _t >= _cooldown_s:
				_enter(State.IDLE)


# --- queries (host presentation + tests) ---------------------------------------

func get_state() -> int:
	return _state


func get_lane_dir() -> Vector2:
	return _lane_dir


## The latched effective clear length (A2) — strip length == crossing reach ==
## bolt max travel. 0.0 until acquired.
func lane_len_eff() -> float:
	return _lane_len_eff


func is_acquired() -> bool:
	return _acquired


func windup_s() -> float:
	return _windup_s


func always_visible() -> bool:
	return _always_visible


func bolt_position() -> Vector2:
	return _bolt_pos


# --- internals -------------------------------------------------------------------

## Derive the LOCKED lane once (second tick, A1). Authored override forces the
## heading; else pick the longest clear sightline among the 8 fixed candidates
## (strict > + fixed candidate order = deterministic tie-break). Either path latches
## the effective clear LENGTH with the direction (A2) — a dense-cover pocket just
## latches the longest (short) candidate: strictly weaker, never unfair.
func _acquire_lane() -> void:
	if _authored_dir_deg >= 0.0:
		_lane_dir = Vector2.RIGHT.rotated(deg_to_rad(_authored_dir_deg))
		_lane_len_eff = _clear_distance(_lane_dir)
		return
	var best_dir: Vector2 = CANDIDATES[0]
	var best_clear := -1.0
	for dir: Vector2 in CANDIDATES:
		var clear: float = _clear_distance(dir)   # ray vs world, capped at lane_length
		if clear > best_clear:
			best_clear = clear
			best_dir = dir
	_lane_dir = best_dir
	_lane_len_eff = best_clear


## Ray from the muzzle along `dir`; clear distance to the first world hit, capped at
## lane_length. Space-less-safe (a bare harness with no physics space returns the
## full length so it still acquires a lane) — the burrow_cycle null-guard idiom.
func _clear_distance(dir: Vector2) -> float:
	var space := _space()
	if space == null:
		return _lane_length
	var origin: Vector2 = host.global_position
	var q := PhysicsRayQueryParameters2D.create(origin, origin + dir * _lane_length, WORLD_MASK)
	q.collide_with_bodies = true
	q.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return _lane_length
	return origin.distance_to(hit["position"])


## Player is inside the lane strip (within the latched effective length, A2) AND the
## sentry has clear LOS to them. Crossing test is CENTRE by default
## (fire_on_body_edge = false, the DR-4 forgiving read); body-edge adds PLAYER_R.
func _player_in_lane_with_los() -> bool:
	var origin: Vector2 = host.global_position
	var pp: Vector2 = player.global_position
	var along: float = (pp - origin).dot(_lane_dir)
	if along <= 0.0 or along > _lane_len_eff:
		return false                      # behind the muzzle or past the effective lane
	var seg_end: Vector2 = origin + _lane_dir * _lane_len_eff
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(pp, origin, seg_end)
	var half: float = _lane_width * 0.5 + (PLAYER_R if _body_edge else 0.0)
	if pp.distance_to(closest) > half:
		return false                      # not in the strip
	return _los_clear(origin, pp)         # a wall/cover between us suppresses fire


## LOS: no world geometry between the muzzle and the player. Space-less-safe (true).
func _los_clear(a: Vector2, b: Vector2) -> bool:
	var space := _space()
	if space == null:
		return true
	var q := PhysicsRayQueryParameters2D.create(a, b, WORLD_MASK)
	q.collide_with_bodies = true
	q.collide_with_areas = false
	return space.intersect_ray(q).is_empty()


## FIRE: advance the bolt one frame down the locked lane, swept-kill the player over
## the (clipped) travel segment, and STOP at the first world hit (cover blocks it —
## OQ-7: stop-on-first-axis-hit, no pierce) or at the latched _lane_len_eff (A2).
## On stop → falling edge re-arms the BUG6 latch and the FSM enters COOLDOWN.
func _advance_bolt(delta: float) -> void:
	var prev: Vector2 = _bolt_pos
	var next: Vector2 = prev + _lane_dir * _bolt_speed * delta
	var done := false
	# Travel cap FIRST: the bolt can never out-fly its own latched lane (A2 rider).
	if (next - _muzzle).dot(_lane_dir) >= _lane_len_eff:
		next = _muzzle + _lane_dir * _lane_len_eff
		done = true
	# World-block: clip this frame's travel at the first wall/cover hit.
	var space := _space()
	if space != null:
		var q := PhysicsRayQueryParameters2D.create(prev, next, WORLD_MASK)
		q.collide_with_bodies = true
		q.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			next = hit["position"]
			done = true
	# Swept lethal test over THIS frame's (clipped) travel — the ChargeLane idiom,
	# tunnel-proof at any bolt_speed; the reused LethalContact owns emit-always +
	# the L5 kills gate + the BUG6 latch.
	if lethal != null:
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
			player.global_position, prev, next)
		var kill: bool = player.global_position.distance_to(closest) \
			<= _lane_width * 0.5 + PLAYER_R
		lethal.apply_contact(kill, true)
	_bolt_pos = next
	if bolt != null:
		bolt.global_position = next
	if done:
		if bolt != null:
			bolt.visible = false
		if lethal != null:
			lethal.apply_contact(false, true)   # falling edge -> BUG6 re-arm
		_enter(State.COOLDOWN)


## Draw the lane strip at the LATCHED geometry (A2: length = _lane_len_eff — a strip
## drawn through a blocking wall would be a readability lie). Geometry/rotation only;
## per-state color + hot/faint visibility are the HOST's presentation.
func _update_lane_strip() -> void:
	if lane_vis == null:
		return
	var half: float = _lane_width * 0.5
	lane_vis.polygon = PackedVector2Array([
		Vector2(0.0, -half), Vector2(_lane_len_eff, -half),
		Vector2(_lane_len_eff, half), Vector2(0.0, half)])
	lane_vis.rotation = _lane_dir.angle()
	lane_vis.visible = _always_visible


## Null/space-less-safe direct-space access (the burrow_cycle guard idiom).
func _space() -> PhysicsDirectSpaceState2D:
	if host == null or not host.is_inside_tree():
		return null
	var world: World2D = host.get_world_2d()
	if world == null:
		return null
	return world.direct_space_state


func _enter(next: int) -> void:
	_state = next
	_t = 0.0
	if on_state_changed.is_valid():
		on_state_changed.call(next)
