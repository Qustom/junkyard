class_name BombHazard
extends Node2D
## BombHazard (K5b, M1.4 · componentized S2, M1.9) — a stationary greybox proximity
## bomb. Sits inert showing an idle proximity ring; when the player's centre crosses
## hbomb_proximity_radius it COMMITS and pulses for hbomb_pulse_seconds
## (accelerating throb), then detonates: player within hbomb_blast_radius at the
## detonation frame => death; else it fizzles.
##
## S2 (M1.9): the internals now live in the shared opposition component set —
## ProximityTrigger (the IDLE arm test) + TelegraphFSM (arming throb + blast flash —
## presentation ONLY) + LethalContact (&"on_command": the one-frame blast test +
## emit + L5 hbomb_kills gate) + ThrowInteraction (&"die"). The host keeps the FSM
## SKELETON verbatim per the Q1 binding rule: the State enum, the match, and the
## `_pulse_t` accumulator (detonation is accumulator-driven, NEVER a tween callback
## — headless-safe). OBSERVABLE BEHAVIOR IS BYTE/FRAME-IDENTICAL (golden gated).
##
## COMMITTED, no-defuse (Director-FINAL): once the pulse starts, leaving the
## proximity ring does NOT cancel it — the escape window is the (smaller) BLAST
## radius. Fatal blasts route through the EXISTING GameState.fail_run(&"death");
## fizzles emit nothing. One-shot: frees itself after the explode flash.
##
## ALL-OFF: with hbomb_enabled = false the spawn seam never instantiates this node
## (fp=e943ac9c8bc1 untouched). Placement is pure run-state, never feeds fingerprint().

enum State { IDLE, PULSING, EXPLODED }

## Greybox tell colors (inline placeholder; the R1 palette idiom).
const COLOR_IDLE := Color(0.45, 0.45, 0.55, 0.5)   # dim translucent — "dormant ring"
const COLOR_ARMING := Color(0.95, 0.75, 0.2)        # amber — "pulsing, about to blow"
const COLOR_BLAST := Color(1.0, 0.25, 0.1)          # hot orange-red — "detonation flash"

const _RING_SEGMENTS := 24      # polygon segments approximating the idle proximity ring

var _cfg: RunConfig                  # snapshot of GameState.active_run_config at setup
var _state: int = State.IDLE
var _player: Node2D                  # resolved at setup
var _pulse_t: float = 0.0            # seconds since arming — HOST-side accumulator (Q1):
                                     # drives detonation deterministically
var _time_alive: float = 0.0         # self-timed run clock (host-owned)

var _prox: ProximityTrigger = null
var _fsm: TelegraphFSM = null
var _lethal: LethalContact = null
var _throw: ThrowInteraction = null

@onready var _ring: Polygon2D = $IdleRing     # faint proximity-radius ring (the telegraph)
@onready var _core: Polygon2D = $Core         # the bomb body (throbs while pulsing)


func _ready() -> void:
	_prox = OppositionComponent.acquire(self, ProximityTrigger) as ProximityTrigger
	_fsm = OppositionComponent.acquire(self, TelegraphFSM) as TelegraphFSM
	_lethal = OppositionComponent.acquire(self, LethalContact) as LethalContact
	_throw = OppositionComponent.acquire(self, ThrowInteraction) as ThrowInteraction
	_fsm.tell = _core                  # the throb/flash target (the ring stays host-drawn)


## Bind config + player and seat the IDLE ring sized to the proximity radius.
## spawn_ctx is the LOCKED family signature's third param; the bomb IGNORES it —
## its blast is radial, not room-confined.
func setup(cfg: RunConfig, player: Node2D, _spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_state = State.IDLE
	_pulse_t = 0.0
	_time_alive = 0.0
	var p := _resolve_params(cfg)
	_prox.bind(self, player, p, _spawn_ctx)
	_fsm.bind(self, player, p, _spawn_ctx)
	_lethal.bind(self, player, p, _spawn_ctx)
	_throw.bind(self, player, p, _spawn_ctx)
	if _ring != null:
		_draw_idle_ring(cfg.hbomb_proximity_radius if cfg != null else 0.0)
	_set_tell_idle()


## S2 resolve order: LEGACY KNOBS ONLY (defs mirror inertly; nothing reads params).
func _resolve_params(cfg: RunConfig) -> Dictionary:
	return {
		"proximity_radius": cfg.hbomb_proximity_radius if cfg != null else 0.0,
		"pulse_seconds": cfg.hbomb_pulse_seconds if cfg != null else 0.0,
		"blast_radius": cfg.hbomb_blast_radius if cfg != null else 0.0,
		"kills": cfg.hbomb_kills if cfg != null else true,
		"def_id": &"bomb",
		"lethal_mode": &"on_command",
		"throw_mode": &"die",
	}


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return                                 # the family guard, verbatim
	_time_alive += delta

	match _state:
		State.IDLE:
			# Arm on the RISING edge into the proximity ring (0 radius = inert —
			# ProximityTrigger's code contract). The one-way IDLE→PULSING transition
			# IS the rising-edge latch (the host stops asking once armed).
			if _prox.player_inside():
				_arm()
		State.PULSING:
			# COMMITTED once-armed: leaving the ring does NOT defuse. Detonation is
			# _pulse_t-driven (deterministic, host accumulator — Q1), NOT a tween callback.
			_pulse_t += delta
			if _pulse_t >= _cfg.hbomb_pulse_seconds:
				_detonate()
		State.EXPLODED:
			pass   # one-shot terminal: frees itself after the explode flash


## IDLE -> PULSING once: amber flash + start the accelerating throb, emit the
## generic opposition_event(&"telegraph").
func _arm() -> void:
	_state = State.PULSING
	_pulse_t = 0.0
	_set_tell_arming()
	_fsm.start_throb()                            # juice only — detonation is _pulse_t-driven
	var depth: int = GameState.current_depth_index
	var run_t_ms: int = run_clock_ms()
	EventBus.opposition_event.emit(&"bomb", &"telegraph", depth, run_t_ms)


## PULSING -> EXPLODED: one distance test at the detonation frame (LethalContact
## &"on_command" — pure test, then the flash juice, then the emit+gate resolve, in
## the legacy statement order). A fizzle emits NO kill row. One-shot: frees itself
## after the explode flash so no lingering ring clutter.
func _detonate() -> void:
	_state = State.EXPLODED
	_fsm.stop_throb()
	var hit: bool = _lethal.command_hit()
	_fsm.blast_fade(COLOR_BLAST, 2.2, 0.06, 0.12)   # brief explode flash (juice; runs even if fatal)
	if hit:
		_lethal.resolve_command_hit()   # emit-always + L5 hbomb_kills gate → fail_run
	# One-shot: free after the flash (~0.2s) so the node leaves no lingering ring.
	# Run-state — _clear_band() would also free it on run-end.
	get_tree().create_timer(0.2).timeout.connect(queue_free)


## The host-owned self-timed run clock (both signal families share this timestamp).
func run_clock_ms() -> int:
	return int(_time_alive * 1000.0)


func get_def_id() -> StringName:
	return &"bomb"


func resolve_throw_death(killer_ctx: Dictionary) -> bool:
	return _throw.resolve_throw_death(killer_ctx)


# --- Greybox tells (inline placeholders; character-animator polish deferred) ----

func _set_tell_idle() -> void:
	if _core != null:
		_core.color = COLOR_IDLE
	if _ring != null:
		_ring.color = Color(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, 0.18)   # faint telegraph


func _set_tell_arming() -> void:
	if _core != null:
		_core.color = COLOR_ARMING


## Draw the faint idle ring as a polygon approximating a circle of radius r (the
## telegraph). Greybox — a polygon ring is enough to read the radius.
func _draw_idle_ring(r: float) -> void:
	var pts := PackedVector2Array()
	var rr := maxf(r, 1.0)
	for i: int in _RING_SEGMENTS:
		var a := TAU * float(i) / float(_RING_SEGMENTS)
		pts.append(Vector2(cos(a), sin(a)) * rr)
	_ring.polygon = pts
