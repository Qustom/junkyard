class_name SpikeHazard
extends Node2D
## SpikeHazard (K5c, M1.4) — the greybox "rotating spikes" hazard: an ANCHORED hub
## that spins at a constant angular velocity, with ARM_COUNT lethal arms of length
## `hspike_arm_length` radiating from it. Lethal on contact: the kill is an ANALYTIC
## distance-to-arm-segment test against the player each frame (deterministic, NO physics
## overlap — the R1 convention, hazard_entity.gd:143-147). The rotation IS the telegraph;
## the player learns the rhythm and threads the gap between the blades.
##
## THROWAWAY GREYBOX, not the M2 enemy slice. No combat, no health, no pathfinding.
## Stationary, so (unlike R1) it has NO collision shape and NO collision mask — it never
## moves, never blocks anything, and its kill is pure geometry (OQ-1/OQ-6, Node2D).
##
## READS ONLY (R1's contract): reads its hspike_* knobs (snapshotted at setup); reads
## GameState.current_depth_index live for the telemetry depth; EMITS the pre-declared
## EventBus.new_hazard_killed (never edits event_bus.gd); routes a fatal hit through the
## EXISTING GameState.fail_run(&"death") — no new end path, no local _run_ended guard.
##
## ALL-OFF: with hspike_enabled == false the spawn seam (K5i) never instantiates this node,
## so the M1.0 baseline is byte-for-byte unchanged (no node, no telemetry, no behaviour).
## Placement is pure run-state (never feeds fingerprint()); the per-instance start phase is
## derived deterministically from spawn_ctx["phase_salt"], NEVER from the global RNG.

# --- Greybox-feel constants (NOT RunConfig knobs — the magnitude knobs live in RunConfig,
# the feel knobs live here, like hazard_entity.gd:32-57). The Director edits these in-file. -
# Tell color: steel / grey-cyan (Phase-3 Director-ratified palette separation) — the cool
# rotating blades are hue-separated from the warm amber/orange ping-pong (K5a) + bomb (K5b),
# not just shape-separated by the multi-arm star silhouette.
const COLOR_SPIKE := Color(0.55, 0.70, 0.80)   # cool steel-cyan "blades"
const ARM_COUNT := 3                            # spike arms radiating from the hub (LOCKED at 3, OQ-2)
const ARM_HALF_WIDTH := 6.0                     # px half-thickness of an arm (the greybox blade is a thin bar)
# Lethal kill radius around the arm SEGMENT = the player's body radius (14, player.tscn:8)
# plus the arm's half-thickness, so the kill fires when the player's circle touches the blade.
const PLAYER_RADIUS := 14.0
const KILL_PAD := ARM_HALF_WIDTH               # contact slack ⇒ kill radius = 14 + 6 = 20px

var _cfg: RunConfig                  # snapshot of the run config at setup
var _player: Node2D                  # resolved player (handed in by K5i's spawn loop)
var _alive_time: float = 0.0         # seconds since setup (self-timed run clock, R1 §4)
var _angle: float = 0.0              # current rotation (radians); rotation += omega * delta
var _omega: float = 0.0              # angular velocity (rad/s), signed → direction (from deg/s knob)
var _arm_length: float = 0.0         # snapshotted reach of each lethal arm (px)
var _killed_emitted: bool = false    # one-shot telemetry latch (R1 _caught_latched precedent);
                                     # does NOT guard fail_run (GameState._run_ended owns that)

@onready var _tell: Polygon2D = $Tell


## Bind the run config + player + deterministic initial phase. Called by K5i's spawn loop
## right after add_child, uniform with HazardEntity.setup (the LOCKED family signature
## setup(cfg, player, spawn_ctx) — Phase-3 cross-cutting lock). Snapshots the config.
##
## spawn_ctx["phase_salt"] is a DETERMINISTIC per-instance offset K5i derives from spawn
## order/cell (K5i builds depth_index * 131 + k), NOT global RNG — so a field of spikes
## reads as a chaotic blade-garden rather than lock-step while staying reproducible from
## (seed+config). An empty dict (default) ⇒ phase_salt 0 ⇒ a fixed phase; the entity must
## construct safely with no spawn_ctx at all.
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_alive_time = 0.0
	_killed_emitted = false
	_omega = deg_to_rad(cfg.hspike_rotation_speed)   # signed deg/s → signed rad/s (direction baked in)
	_arm_length = cfg.hspike_arm_length
	# Deterministic per-instance phase (OQ-5): a pure function of the salt — reproducible
	# run-to-run, never touches RNG. * 47 spreads adjacent salts around the circle.
	var phase_salt: int = int(spawn_ctx.get("phase_salt", 0))
	_angle = deg_to_rad(float(posmod(phase_salt * 47, 360)))
	rotation = _angle
	if _tell != null:
		_rebuild_tell()          # draw the N-arm star once at setup
		_tell.color = COLOR_SPIKE


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return
	_alive_time += delta

	# --- Rotate (constant angular velocity — the telegraph itself) -----------
	_angle = wrapf(_angle + _omega * delta, 0.0, TAU)
	rotation = _angle          # spins the Tell Polygon2D with the node (greybox blades)

	# --- Analytic lethal test: is the player within KILL of ANY arm segment? --
	# Each arm is the segment from the hub (global_position) out to
	# hub + arm_length * (unit vector at _angle + i * (TAU / ARM_COUNT)).
	# Geometry2D.get_closest_point_to_segment is closed-form — deterministic, no overlap.
	if _is_player_on_any_arm(_player.global_position):
		# One-shot kill (R1 idempotency): emit telemetry ONCE, route death through the
		# EXISTING end path. fail_run's _run_ended guard absorbs dupes across all hazards.
		if not _killed_emitted:
			_killed_emitted = true
			var depth: int = GameState.current_depth_index
			var run_t_ms: int = int(_alive_time * 1000.0)
			EventBus.new_hazard_killed.emit(&"spike", depth, run_t_ms)
			GameState.fail_run(&"death")   # single source of run-end truth; no local guard


## Pure hit test (deterministic, no physics): true iff `point` is within the lethal capsule
## radius of ANY of the ARM_COUNT rotating arm segments, given the CURRENT _angle/_arm_length.
## Trivially unit-testable — a pure function of (_angle, _arm_length, global_position, point).
func _is_player_on_any_arm(point: Vector2) -> bool:
	var kill: float = PLAYER_RADIUS + KILL_PAD
	var hub: Vector2 = global_position
	for i in ARM_COUNT:
		var a: float = _angle + float(i) * (TAU / float(ARM_COUNT))
		var tip: Vector2 = hub + Vector2(cos(a), sin(a)) * _arm_length
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, hub, tip)
		if point.distance_to(closest) <= kill:
			return true
	return false


## Build the greybox blades: ARM_COUNT solid constant-width bars radiating from the hub.
## Each arm is its OWN convex quad, registered as a separate island in Polygon2D.polygons
## so each is triangulated INDEPENDENTLY. The previous version traced all three arms as a
## SINGLE outline weaving through the hub, which is self-intersecting — Geometry2D's
## ear-clipping returns ZERO triangles for it, so the whole Tell rendered NOTHING (the
## blades were invisible while the analytic kill still fired). Per-arm quads can't
## self-intersect, so each blade always renders. Drawn in LOCAL space (the node's rotation
## spins it); pure presentation — the lethal test above uses _angle math, not this polygon.
func _rebuild_tell() -> void:
	var verts := PackedVector2Array()
	var islands: Array = []
	for i in ARM_COUNT:
		var a: float = float(i) * (TAU / float(ARM_COUNT))
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x) * ARM_HALF_WIDTH
		var tip := dir * _arm_length
		var base: int = i * 4
		verts.append(perp)             # hub, one side
		verts.append(tip + perp)       # tip, same side
		verts.append(tip - perp)       # tip, other side
		verts.append(-perp)            # hub, other side
		islands.append(PackedInt32Array([base, base + 1, base + 2, base + 3]))
	_tell.polygon = verts
	_tell.polygons = islands
