class_name ChargeLane
extends OppositionComponent
## ChargeLane (S6a, M1.9) — the ONE new opposition component of the Phase-E proof:
## a telegraph → locked-vector lethal dash → recover FSM (the genre's three-beat
## rhythm: readable wind-up, committed straight dash, punishable recovery).
##
## Mounted on the Charger Actor host (CharacterBody2D) and ticked by it (S2 base
## contract §3.1 — no _physics_process of its own). Everything around it is REUSED:
##   - wake test        → the S2 ProximityTrigger (host maps aggro_range →
##                        proximity_radius); the trigger is stateless, so the cycle's
##                        re-arm is just this FSM returning to DORMANT.
##   - contact/kill     → the S2 LethalContact in &"external" mode: THIS component
##                        computes the swept contact boolean each CHARGE frame and
##                        hands it to apply_contact(hit, true) — the emit-always +
##                        L5 kills gate + BUG6 rising-edge latch machinery runs
##                        unchanged (S6a Resolved Decisions OQ-1).
##   - tells            → the S2 TelegraphFSM, driven by the HOST off the
##                        on_state_changed hook (colors stay host consts — S2 rule).
##   - throw death      → the S2 ThrowInteraction (&"die"), untouched.
##
## FSM (S6a spec §2.2, cooldown folded into DORMANT per the Phase-3 nit):
##   DORMANT   — inert, visible, learnable. After a cycle, re-aggro is gated by
##               cooldown_s. Wakes when the player enters aggro_range.
##   TELEGRAPH — velocity zero for telegraph_s. The lane is LOCKED toward the player
##               at telegraph START when lock_at_telegraph_start (fair: dodge the
##               shown lane — OQ-3), else re-aimed every frame and locked at END.
##   CHARGE    — committed dash along the locked lane at charge_speed. The ONLY
##               lethal state: a SWEPT segment test (this frame's travel vs the
##               player, corridor = lane_width/2 + PLAYER_R) feeds LethalContact —
##               tunnel-proof at any charge_speed. Ends on a wall hit
##               (get_slide_collision_count() > 0) or at charge_max_dist.
##   RECOVER   — stunned for recover_s (× wall_crash_recover_mult on a wall crash —
##               the D-RAT-2 bait-into-wall bonus-stun knob), always throw-killable.
##
## Dash-invulnerability (throwable_while_charging = false, D-RAT-2's band_two deck
## override): on CHARGE entry the host leaves the &"hazard" GROUP (collision_layer
## unchanged, so ThrownItem's body_entered still fires and resolves as a MISS →
## re-drop) and rejoins it on CHARGE exit. Pure stock group membership — zero
## thrown_item.gd edits (S6a adjudication #4).
##
## RNG-FREE and deterministic: no global RNG reference anywhere; the lane direction
## is a pure function of the live player position (reactive run-state, like R1's
## chase) and never feeds fingerprint(). Geometry2D.get_closest_point_to_segment is
## a pure function.

enum State { DORMANT, TELEGRAPH, CHARGE, RECOVER }

## Player body radius (player.tscn CircleShape2D). A feel constant that lives with
## its block (S2 Resolved Decisions Q7), not a RunConfig knob — the swept kill
## corridor half-width is lane_width/2 + PLAYER_R (the R1/K5 honest-contact floor).
const PLAYER_R := 14.0

## Reused component seams, assigned by the HOST at _ready (the LethalContact.spin
## idiom): the wake trigger and the &"external"-mode contact sink.
var prox: ProximityTrigger = null
var lethal: LethalContact = null
## Host presentation/telemetry hook: called (state: int, wall_crash: bool) on every
## transition AFTER the state seats. The host paints tells + emits the S0 generic
## rows there (S2 emit-site discipline — this component never touches EventBus).
var on_state_changed: Callable = Callable()

# --- snapshotted knobs (bound once via _configure; never re-read mid-run) -------
var _aggro_range := 0.0
var _telegraph_s := 0.0
var _charge_speed := 0.0
var _charge_max_dist := 0.0
var _recover_s := 0.0
var _cooldown_s := 0.0
var _lane_width := 0.0
var _lock_at_start := true
var _throwable_while_charging := true
var _wall_crash_mult := 1.0

# --- run-state -------------------------------------------------------------------
var _body: CharacterBody2D = null
var _state: int = State.DORMANT
var _t := 0.0                        # time-in-state
var _lane_dir := Vector2.RIGHT       # the LOCKED dash heading (source of truth)
var _dist_charged := 0.0
var _recover_len := 0.0              # this cycle's recovery (recover_s × crash mult)
var _cooldown_left := 0.0            # DORMANT re-aggro guard after a full cycle


func _configure(p: Dictionary, _ctx: Dictionary) -> void:
	_aggro_range = float(p.get("aggro_range", 0.0))
	_telegraph_s = float(p.get("telegraph_s", 0.0))
	_charge_speed = maxf(float(p.get("charge_speed", 0.0)), 0.0)
	_charge_max_dist = float(p.get("charge_max_dist", 0.0))
	_recover_s = float(p.get("recover_s", 0.0))
	_cooldown_s = float(p.get("cooldown_s", 0.0))
	_lane_width = float(p.get("lane_width", 28.0))
	_lock_at_start = bool(p.get("lock_at_telegraph_start", true))
	_throwable_while_charging = bool(p.get("throwable_while_charging", true))
	_wall_crash_mult = maxf(float(p.get("wall_crash_recover_mult", 1.0)), 1.0)
	_body = host as CharacterBody2D
	# Re-setup resets the cycle (the family re-setup rule) WITHOUT firing the host
	# hook — the host seats its own dormant tell at setup().
	_state = State.DORMANT
	_t = 0.0
	_lane_dir = Vector2.RIGHT
	_dist_charged = 0.0
	_recover_len = 0.0
	_cooldown_left = 0.0
	_set_throwable(true)               # undo a mid-dash group toggle from a prior bind


## Called by the HOST each physics frame (fixed order; components never self-tick).
func tick(delta: float) -> void:
	if _body == null or player == null:
		return
	_t += delta
	match _state:
		State.DORMANT:
			_body.velocity = Vector2.ZERO
			if _cooldown_left > 0.0:
				_cooldown_left -= delta          # post-cycle breathing room (cooldown_s)
			elif prox != null and prox.player_inside():
				_lock_lane()                     # lock at telegraph START (OQ-3 default)
				_enter(State.TELEGRAPH)
		State.TELEGRAPH:
			_body.velocity = Vector2.ZERO
			if not _lock_at_start:
				_lock_lane()                     # re-aim every frame → locks at END
			if _t >= _telegraph_s:
				_dist_charged = 0.0
				_set_throwable(_throwable_while_charging)
				_enter(State.CHARGE)
		State.CHARGE:
			var prev: Vector2 = _body.global_position
			_body.velocity = _lane_dir * _charge_speed
			_body.move_and_slide()
			_dist_charged += _body.global_position.distance_to(prev)
			_test_lethal_sweep(prev, _body.global_position)
			var crashed: bool = _body.get_slide_collision_count() > 0
			if crashed or _dist_charged >= _charge_max_dist:
				_recover_len = _recover_s * (_wall_crash_mult if crashed else 1.0)
				_set_throwable(true)             # ALWAYS vulnerable in recovery
				if lethal != null:
					lethal.apply_contact(false, true)   # falling edge → BUG6 re-arm
				_enter(State.RECOVER, crashed)
		State.RECOVER:
			_body.velocity = Vector2.ZERO
			if _t >= _recover_len:
				_cooldown_left = _cooldown_s
				_enter(State.DORMANT)


# --- queries (host presentation + tests) -------------------------------------------

func get_state() -> int:
	return _state


func get_lane_dir() -> Vector2:
	return _lane_dir


## 0→1 progress through the wind-up (the host's amber→red escalation ramp).
func telegraph_progress() -> float:
	return clampf(_t / _telegraph_s, 0.0, 1.0) if _telegraph_s > 0.0 else 1.0


func dist_charged() -> float:
	return _dist_charged


# --- internals ----------------------------------------------------------------------

func _lock_lane() -> void:
	var to_p: Vector2 = player.global_position - host.global_position
	_lane_dir = to_p.normalized() if to_p.length() > 0.001 else Vector2.RIGHT


## Swept lethal test (tunnel-proof): perpendicular distance from the player to the
## segment travelled THIS frame ≤ lane_width/2 + PLAYER_R → contact. The ACTUAL kill
## (emit-always &"hit_player" + L5 kills gate → fail_run + BUG6 latch) is the reused
## LethalContact's &"external" seam — contact math supplied, machinery unchanged.
func _test_lethal_sweep(a: Vector2, b: Vector2) -> void:
	if lethal == null:
		return
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
		player.global_position, a, b)
	var hit: bool = player.global_position.distance_to(closest) \
		<= _lane_width * 0.5 + PLAYER_R
	lethal.apply_contact(hit, true)


## Dash-invulnerability = pure group membership (adjudication #4): out of the
## &"hazard" group a ThrownItem resolves _miss() (re-drop, item kept); the body
## stays on collision_layer hazard so body_entered still fires. No-op when the def
## ships throwable_while_charging = true (never leaves the group).
func _set_throwable(on: bool) -> void:
	if host == null:
		return
	if on:
		if not host.is_in_group(&"hazard"):
			host.add_to_group(&"hazard")
	elif host.is_in_group(&"hazard"):
		host.remove_from_group(&"hazard")


func _enter(next: int, wall_crash: bool = false) -> void:
	_state = next
	_t = 0.0
	if on_state_changed.is_valid():
		on_state_changed.call(next, wall_crash)
