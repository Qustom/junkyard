class_name SpikeHazard
extends Node2D
## SpikeHazard (K5c, M1.4 · componentized S2, M1.9) — the greybox "rotating spikes"
## hazard: an ANCHORED hub that spins at a constant angular velocity, with ARM_COUNT
## lethal arms of length `hspike_arm_length` radiating from it. Lethal on contact:
## an ANALYTIC distance-to-arm-segment test each frame (deterministic, NO physics
## overlap). The rotation IS the telegraph.
##
## S2 (M1.9): the internals now live in the shared opposition component set —
## SpinMove (constant-omega rotation + deterministic phase from spawn_ctx
## ["phase_salt"], verbatim) + LethalContact (&"arm_segments" mode reading SpinMove's
## live angle; the PERMANENT latch via latch_rearm=false — RD-3, deliberately unlike
## the pingpong latch) + ThrowInteraction (&"die"). The host keeps the family
## skeleton: guard, self-clock, fixed tick order, config snapshot, and the tell
## geometry. OBSERVABLE BEHAVIOR IS BYTE/FRAME-IDENTICAL (golden frame-trace gated).
##
## Stationary — NO collision shape, NO collision mask; the kill is pure geometry.
## ALL-OFF: with hspike_enabled == false the spawn seam never instantiates this
## node. The per-instance start phase is derived deterministically from
## spawn_ctx["phase_salt"], NEVER from the global RNG autoload.

# --- Greybox-feel constants (NOT RunConfig knobs — Q7: they move with their block,
# never into params; the Director edits them in-file). ---------------------------
const COLOR_SPIKE := Color(0.55, 0.70, 0.80)   # cool steel-cyan "blades"
const ARM_COUNT := 3                            # spike arms radiating from the hub (LOCKED)
const ARM_HALF_WIDTH := 6.0                     # px half-thickness of a greybox blade
## Lethal kill radius around the arm SEGMENT = player body radius + blade half-width.
const PLAYER_RADIUS := 14.0
const KILL_PAD := ARM_HALF_WIDTH               # contact slack ⇒ kill radius = 14 + 6 = 20px

var _cfg: RunConfig                  # snapshot of the run config at setup
var _player: Node2D                  # resolved player (handed in by the spawn seam)
var _alive_time: float = 0.0         # self-timed run clock (host-owned)
var _arm_length: float = 0.0         # snapshotted reach — the TELL geometry input
                                     # (LethalContact holds its own resolved copy)

var _spin: SpinMove = null
var _lethal: LethalContact = null
var _throw: ThrowInteraction = null

## Legacy-visible spin angle (radians) — reads through to SpinMove (test surface +
## debugging continuity; the component owns the value).
var _angle: float:
	get:
		return _spin.spin_angle() if _spin != null else 0.0

@onready var _tell: Polygon2D = $Tell


func _ready() -> void:
	_spin = OppositionComponent.acquire(self, SpinMove) as SpinMove
	_lethal = OppositionComponent.acquire(self, LethalContact) as LethalContact
	_throw = OppositionComponent.acquire(self, ThrowInteraction) as ThrowInteraction
	_lethal.spin = _spin               # arm_segments mode reads SpinMove's live angle


## Bind the run config + player + deterministic initial phase (LOCKED family
## signature). spawn_ctx["phase_salt"] is a DETERMINISTIC per-instance offset the
## spawn seam derives from spawn order/cell. An empty dict (default) ⇒ phase_salt 0
## ⇒ a fixed phase; the entity must construct safely with no spawn_ctx at all.
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_alive_time = 0.0
	_arm_length = cfg.hspike_arm_length if cfg != null else 0.0
	var p := _resolve_params(cfg)
	_spin.bind(self, player, p, spawn_ctx)     # sets the phase + host rotation (legacy setup)
	_lethal.bind(self, player, p, spawn_ctx)   # resets the (permanent) latch for a re-setup
	_throw.bind(self, player, p, spawn_ctx)
	if _tell != null:
		_rebuild_tell()          # draw the N-arm star once at setup
		_tell.color = COLOR_SPIKE


## S2 resolve order: LEGACY KNOBS ONLY (defs mirror inertly; nothing reads params).
func _resolve_params(cfg: RunConfig) -> Dictionary:
	return {
		"rotation_speed_deg": cfg.hspike_rotation_speed if cfg != null else 0.0,
		"arm_length": cfg.hspike_arm_length if cfg != null else 0.0,
		"arm_count": ARM_COUNT,
		"kill_radius": PLAYER_RADIUS + KILL_PAD,
		"kills": cfg.hspike_kills if cfg != null else true,
		"def_id": &"spike",
		"emit_family": &"new_hazard_killed",
		"lethal_mode": &"arm_segments",
		"latch_rearm": false,          # RD-3: the spike latch is PERMANENT (no re-arm)
		"throw_mode": &"die",
	}


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return                                 # the family guard, verbatim
	_alive_time += delta
	_spin.tick(delta)      # rotate (constant angular velocity — the telegraph itself)
	_lethal.tick(delta)    # analytic arm test → permanent latch → emit-always → L5 gate


## The host-owned self-timed run clock (both signal families share this timestamp).
func run_clock_ms() -> int:
	return int(_alive_time * 1000.0)


func get_def_id() -> StringName:
	return &"spike"


func resolve_throw_death(killer_ctx: Dictionary) -> bool:
	return _throw.resolve_throw_death(killer_ctx)


## Pure hit test (legacy test surface): true iff `point` is within the lethal
## capsule radius of ANY of the ARM_COUNT rotating arm segments at the CURRENT
## angle. Delegates to LethalContact's arm_segments geometry (the owning block).
func _is_player_on_any_arm(point: Vector2) -> bool:
	return _lethal.point_on_any_arm(point)


## Build the greybox blades: ARM_COUNT solid constant-width bars radiating from the
## hub. Each arm is its OWN convex quad, registered as a separate island in
## Polygon2D.polygons so each is triangulated INDEPENDENTLY (the invisible-blade
## fix: a single self-intersecting outline ear-clips to ZERO triangles). Drawn in
## LOCAL space (the node's rotation spins it); pure presentation — the lethal test
## uses angle math, not this polygon.
func _rebuild_tell() -> void:
	var verts := PackedVector2Array()
	var islands: Array = []
	for i: int in ARM_COUNT:
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
