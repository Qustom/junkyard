class_name PingPongHazard
extends CharacterBody2D
## PingPongHazard (K5a, M1.4 · componentized S2, M1.9) — a throwaway greybox
## "bouncer": a colored shape that travels in a straight line at a constant speed,
## bounces off walls, and ends the run if it touches the player. No state machine,
## no chase, no awaken — it is live from spawn.
##
## S2 (M1.9): the internals now live in the shared opposition component set —
## StraightBounceMove (BUG8 heading-source-of-truth travel/bounce/clamp, verbatim) +
## LethalContact (&"radius" mode: fixed CONTACT_RADIUS distance test, BUG6 latch,
## emit-always, L5 hpp_kills gate) + ThrowInteraction (&"die"). The host keeps the
## family skeleton unchanged: the per-frame guard, the self-timed run clock, the
## fixed component tick order, and the config snapshot. OBSERVABLE BEHAVIOR IS
## BYTE/FRAME-IDENTICAL to the pre-component entity (golden frame-trace gated).
##
## Collision: body on layer `hazard` (5), masks `world` (2) ONLY — identical to
## HazardEntity. Walls (the `world` layer) bounce it; it does NOT mask `player`
## (the kill is a script distance test, deterministic) nor `hazard`.
##
## ALL-OFF: with hpp_enabled = false the spawn seam never instantiates this node,
## so the M1.0 baseline is byte-for-byte unchanged. This entity NEVER calls the
## global RNG autoload — any per-instance variation (the initial heading) is
## supplied via spawn_ctx as a deterministic function of spawn index.

## Greybox tell color — DISTINCT from R1 (grey-blue/red) and the other M1.4 hazards.
## Amber "live projectile" read — "a thing in motion that will hurt you".
const COLOR_LIVE := Color(0.95, 0.65, 0.15)     # amber

## Contact radius (px): distance at/under which touching the player kills.
## Self-contained greybox constant (NOT a RunConfig knob — keeps the CFG knob count
## pinned; S2 Resolved Decisions Q7: feel constants move with their block, never
## into params). Floored at the visual body sum: player_r 14 + hazard_r 10 = 24.
const CONTACT_RADIUS := 24.0

## One-shot squash juice on bounce: pure presentation (headless/paused-safe).
const SQUASH_SCALE := 1.15
const SQUASH_TIME := 0.06

var _cfg: RunConfig                 # snapshot of GameState.active_run_config at setup
var _player: Node2D                 # resolved at setup via setup()'s arg
var _spawn_time: float = 0.0        # self-timed run clock for run_t_ms (host-owned)

var _move: StraightBounceMove = null
var _lethal: LethalContact = null
var _throw: ThrowInteraction = null

@onready var _tell: Polygon2D = $Tell


func _ready() -> void:
	# Q4: adopt .tscn-declared components when present, instance defaults otherwise.
	# The refs below fix the tick order regardless of child declaration order.
	_move = OppositionComponent.acquire(self, StraightBounceMove) as StraightBounceMove
	_lethal = OppositionComponent.acquire(self, LethalContact) as LethalContact
	_throw = OppositionComponent.acquire(self, ThrowInteraction) as ThrowInteraction
	_move.on_bounce = _squash_on_bounce


## Bind config + player + the per-instance spawn context (LOCKED family signature —
## setup(cfg, player, spawn_ctx); each entity reads only its keys). ping-pong reads:
## spawn_ctx["initial_dir"] (Vector2, default RIGHT) and spawn_ctx["room_bounds"]
## (Rect2, default empty = pure-wall confinement). An empty dict constructs safely.
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_spawn_time = 0.0
	var p := _resolve_params(cfg)
	_move.bind(self, player, p, spawn_ctx)     # seeds velocity = dir * speed (legacy setup)
	_lethal.bind(self, player, p, spawn_ctx)   # resets the BUG6 latch (re-setup safe)
	_throw.bind(self, player, p, spawn_ctx)
	if _tell != null:
		_tell.color = COLOR_LIVE


## S2 resolve order: LEGACY KNOBS ONLY (the no-double-driving contract — defs mirror
## inertly; nothing reads OppositionDef.params at runtime in M1.9's legacy lane).
func _resolve_params(cfg: RunConfig) -> Dictionary:
	return {
		"speed": maxf(cfg.hpp_speed, 0.0) if cfg != null else 0.0,
		"contact_radius": CONTACT_RADIUS,
		"kills": cfg.hpp_kills if cfg != null else true,
		"def_id": &"pingpong",
		"emit_family": &"new_hazard_killed",
		"lethal_mode": &"radius",
		"latch_rearm": true,
		"throw_mode": &"die",
	}


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return                                 # the family guard, verbatim
	_spawn_time += delta
	_move.tick(delta)      # velocity=_dir*_speed → move_and_slide → BUG8 reflect → clamp
	_lethal.tick(delta)    # radius test → BUG6 latch → emit-always → kills-gated fail_run


## The host-owned self-timed run clock (both signal families share this timestamp).
func run_clock_ms() -> int:
	return int(_spawn_time * 1000.0)


## Stable telemetry/def id (Q5 rider — service-spawned nodes never fall back to the
## auto-uniquified node name).
func get_def_id() -> StringName:
	return &"pingpong"


## The thrown-item death seam (Q5 locked shape). Mode &"die" returns false — the
## thrower performs the free, byte-identical to the pre-seam behaviour.
func resolve_throw_death(killer_ctx: Dictionary) -> bool:
	return _throw.resolve_throw_death(killer_ctx)


# --- Greybox tell juice (inline placeholder, no sprite sheets / AnimationTree) ------

## One-shot squash-and-settle on a bounce so the impact reads. Pure juice; the color +
## constant motion already carry the state if the tree is paused/headless.
func _squash_on_bounce() -> void:
	if _tell == null:
		return
	var tw := create_tween()
	tw.tween_property(_tell, "scale", Vector2(SQUASH_SCALE, SQUASH_SCALE), SQUASH_TIME)
	tw.tween_property(_tell, "scale", Vector2.ONE, SQUASH_TIME)
