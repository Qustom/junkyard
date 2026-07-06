class_name MortarCycle
extends OppositionComponent
## MortarCycle (U2a, M1.11) — the ONE new component of the Lobber proof: the first
## INDIRECT, player-targeted, area-of-effect threat on a flight-time telegraph (all
## shipped defs are contact-lethal). A fire-period FSM that arcs a shell onto the
## player's ground position, IGNORING geometry (cover never protects — moving does):
##   AIM (fire_period_s)   — read the LIVE player pos at fire time (+ optional
##                           velocity lead), LOCK the landing marker, reveal it.
##   IN-FLIGHT (arc_time_s)— marker shown + FROZEN (the dodge window); NON-LETHAL.
##   IMPACT (one frame)    — hit = marker_pos.distance_to(player) <= blast_radius
##                           (centre-in-radius, the bomb's shipped AoE contract), fed
##                           to the REUSED LethalContact &"external" (emit-always +
##                           L5 kills gate + BUG6 latch); then re-arm and cycle.
## Everything else is REUSED: kill/telemetry = LethalContact &"external" (NOT
## &"on_command" — command_hit tests the HOST's position, and the shell lands away
## from the body); fire tell = TelegraphFSM; throw death = ThrowInteraction &"die".
##
## FAIRNESS (spec §1.4, binding): the blast test runs ONLY at IMPACT — never during
## the flight — and the marker LOCKS at fire time (no re-track), so stepping
## blast_radius off the frozen point before the last frame is a guaranteed dodge.
## The marker is shown for the full arc_time_s (the authored dodge window).
##
## This component NEVER moves the host (the Lobber is static), never toggles
## collision/group membership (the Lobber is ALWAYS a valid throw target), never
## runs a body-contact kill, and emits no telemetry itself (the host does, off the
## on_state_changed hook).
##
## RNG-FREE and deterministic: no global RNG reference anywhere. The per-instance
## cadence desync is a PURE function of the spawn position (the BurrowCycle
## correction-1 idiom — the builder stamps no phase_salt for &"lobber"; a ctx
## "phase_salt" key is kept only as a test-harness override, burrow_cycle.gd:98-101).
## The FSM is real-time run-state and never feeds fingerprint().

enum Phase { AIM, IN_FLIGHT }

## Irrational multiplier for the RNG-free per-instance desync hash (golden ratio
## conjugate — the BurrowCycle.DESYNC_PHI constant, mirrored).
const DESYNC_PHI := 0.6180339887
## Segments approximating the marker circle (the bomb _RING_SEGMENTS idiom).
const RING_SEGMENTS := 24

## Reused seams, assigned by the HOST at _ready (the BurrowCycle.lethal idiom).
var lethal: LethalContact = null            # &"external" gated kill sink
var on_state_changed: Callable = Callable() # host paints tells + emits S0 rows here
## The world-positioned landing-marker root (top_level = true in the scene, so its
## transform is world-absolute, independent of the host). Assigned by the host.
var marker_root: Node2D = null
var marker_ring: Polygon2D = null           # the danger circle drawn at blast_radius
var marker_fill: Polygon2D = null           # inner disc that grows over the flight (juice)

# --- snapshotted knobs (bound once via _configure; never re-read mid-run) ---------
var _fire_period := 0.0
var _arc_time := 0.0
var _blast_radius := 0.0
var _lead_factor := 0.0

# --- run-state ---------------------------------------------------------------------
var _phase: int = Phase.AIM
var _t := 0.0                               # time-in-phase
var _fire_offset := 0.0                     # per-instance cadence desync (positional)
var _marker_pos := Vector2.ZERO             # the FROZEN landing point (locked at fire)
var _prev_player_pos := Vector2.ZERO        # finite-difference velocity sample
var _player_vel := Vector2.ZERO             # px/s (decoupled from player internals)


func _configure(p: Dictionary, ctx: Dictionary) -> void:
	_fire_period = maxf(float(p.get("fire_period_s", 0.0)), 0.01)
	_arc_time = maxf(float(p.get("arc_time_s", 0.0)), 0.0)
	_blast_radius = maxf(float(p.get("blast_radius", 0.0)), 0.0)
	_lead_factor = clampf(float(p.get("lead_factor", 0.0)), 0.0, 4.0)
	# Per-instance cadence desync: a PURE function of the spawn POSITION (no RNG, no
	# EncounterBuilder edit — legacy_ctx gives &"lobber" the empty default arm). The
	# ctx "phase_salt" key is a test-harness override ONLY (the burrow_cycle.gd:98-101
	# escape hatch, mirrored verbatim per the Phase-3 OQ-9 binding amendment).
	var default_salt: int = int(host.global_position.x) * 31 + int(host.global_position.y) \
		if host != null else 0
	var salt: int = int(ctx.get("phase_salt", default_salt))
	_fire_offset = fmod(float(salt) * DESYNC_PHI, 1.0) * _fire_period
	# Re-setup seats AIM (family re-setup reset) WITHOUT firing the host hook — the
	# host seats its own idle tell at setup() (the BurrowCycle _configure idiom).
	_phase = Phase.AIM
	_t = _fire_offset
	_marker_pos = Vector2.ZERO
	_prev_player_pos = player.global_position if player != null else Vector2.ZERO
	_player_vel = Vector2.ZERO
	_size_marker(_blast_radius)
	_hide_marker()


## Called by the HOST each physics frame (fixed order; components never self-tick).
func tick(delta: float) -> void:
	if host == null or player == null or not is_instance_valid(player):
		return
	if delta > 0.0:
		_player_vel = (player.global_position - _prev_player_pos) / delta
	_t += delta
	match _phase:
		Phase.AIM:
			if _t >= _fire_period:
				_fire()                          # capture + LOCK the marker, reveal it
				_enter(Phase.IN_FLIGHT)
		Phase.IN_FLIGHT:
			# Marker is FROZEN (locked at fire). Grow the inner fill toward impact for
			# readability — pure juice; the accumulator drives the actual IMPACT.
			_grow_marker(clampf(_t / maxf(_arc_time, 0.0001), 0.0, 1.0))
			if _t >= _arc_time:
				_impact()                        # the ONE-frame blast distance test
				_hide_marker()
				if lethal != null:
					lethal.apply_contact(false, true)   # falling edge → re-arm next shell
				_enter(Phase.AIM)
	_prev_player_pos = player.global_position


# --- queries (host presentation + tests) --------------------------------------------

func get_phase() -> int:
	return _phase


## The FROZEN landing point of the shell in flight (test/inspection seam).
func marker_point() -> Vector2:
	return _marker_pos


## The snapshotted cadence (test/inspection seam — the params-flow assertion reads
## the entity's EFFECTIVE value here, not the def's).
func fire_period() -> float:
	return _fire_period


# --- internals ------------------------------------------------------------------------

## AIM→IN-FLIGHT: read the LIVE player pos, optionally lead by the measured velocity
## (px/s × lead_factor seconds of prediction), LOCK the marker at that world point —
## frozen for the whole flight (the dodge contract; there is no re-track in v1).
func _fire() -> void:
	_marker_pos = player.global_position + _player_vel * _lead_factor
	if marker_root != null:
		marker_root.global_position = _marker_pos    # top_level → world-absolute
	_show_marker()


## IMPACT (one frame): geometry-IGNORING distance test at the frozen marker vs the
## LIVE player centre. Fed to the reused LethalContact &"external" — emit-always +
## L5 kills gate + BUG6 latch fire exactly once on the rising edge. NO raycast /
## LOS / occlusion: a wall between marker and player changes nothing (the identity).
## blast_radius 0 = inert (trap_if_neutral — never kills, mirrors the bomb).
func _impact() -> void:
	if lethal == null or _blast_radius <= 0.0:
		return
	var hit: bool = _marker_pos.distance_to(player.global_position) <= _blast_radius
	lethal.apply_contact(hit, true)


func _enter(next: int) -> void:
	_phase = next
	_t = 0.0
	if on_state_changed.is_valid():
		on_state_changed.call(next)


# --- marker presentation (greybox; headless-safe — the accumulator carries the state,
# --- these only touch visibility/scale/alpha; colors stay scene-authored) -------------

## Build the marker circle polygons at radius r (the bomb _draw_idle_ring idiom).
## The Ring IS the lethal radius — the honest "get your centre out" contract.
func _size_marker(r: float) -> void:
	var pts := PackedVector2Array()
	var rr := maxf(r, 1.0)
	for i: int in RING_SEGMENTS:
		var a := TAU * float(i) / float(RING_SEGMENTS)
		pts.append(Vector2(cos(a), sin(a)) * rr)
	if marker_ring != null:
		marker_ring.polygon = pts
	if marker_fill != null:
		marker_fill.polygon = pts
		marker_fill.scale = Vector2.ZERO


func _show_marker() -> void:
	if marker_root != null:
		marker_root.visible = true
	if marker_fill != null:
		marker_fill.scale = Vector2.ZERO


func _hide_marker() -> void:
	if marker_root != null:
		marker_root.visible = false


## Inner fill grows 0→1 across the flight (the shell closing in — pure juice).
func _grow_marker(t: float) -> void:
	if marker_fill != null:
		marker_fill.scale = Vector2(t, t)
