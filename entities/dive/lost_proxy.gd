class_name LostProxy
extends Node
## LostProxy (R4, M1.1 §3) — the navigation lost-proxy tracker. RATIFIED §10 Q1:
## Proxy A (time-without-depth-progress, movement-gated). It accumulates
## `seconds_wandering` while the player is actively MOVING but is making no forward
## depth progress (max_depth_reached hasn't increased), and emits the pre-declared
## EventBus.nav_lost_proxy when the threshold is crossed (rate-limited, escalating).
##
## WHY movement-gated: a player parked on a junk pickup isn't lost (false positive);
## a player wandering corridors without getting deeper IS the fun-relevant friction
## ("burning clock, not getting anywhere"). The velocity gate removes the false
## positive (§3, Proxy A's one weakness).
##
## RESET on real forward progress (max_depth_reached increases) or run-end (reaching
## the gate / extracting ends the run, so a deliberate successful retreat is never
## logged as lost). Run-state: created per dive, freed with the band.
##
## COSMETIC/READ-ONLY: reads GameState.max_depth_reached / current_depth_index +
## player velocity; emits one EventBus signal; writes NOTHING to meta/save/game_state
## and never edits EventBus.

## px/s — below this the player is "parked" (looting), not wandering.
const MOVE_EPS := 8.0

## Committed stable proxy id (RATIFIED §10 Q1) so a later proxy swap is
## distinguishable in the telemetry analysis.
const PROXY_ID := &"time_no_depth_progress"

var _rc: RunConfig
var _player: Node2D
var _seconds_wandering := 0.0
var _last_max_depth := 0
var _emit_floor := 0.0   # next seconds_wandering value at which we may emit again
var _active := false


func _ready() -> void:
	_rc = GameState.active_run_config
	_player = get_tree().get_first_node_in_group(&"player")
	_active = _rc != null and _rc.r4_enabled and _rc.r4_lost_proxy_threshold > 0.0
	set_process(_active)
	if not _active:
		return
	_last_max_depth = GameState.max_depth_reached   # BUG2
	_emit_floor = _rc.r4_lost_proxy_threshold
	# Reaching the gate / extracting / any run-end resets the episode so a successful
	# retreat is never logged as lost. The node is freed with the band, but guard
	# anyway in case run_ended fires before teardown.
	EventBus.run_ended.connect(_on_run_ended)


func _process(dt: float) -> void:
	if _player == null:
		return
	var max_d: int = GameState.max_depth_reached
	if max_d > _last_max_depth:            # real forward progress ⇒ reset the episode
		_last_max_depth = max_d
		_seconds_wandering = 0.0
		_emit_floor = _rc.r4_lost_proxy_threshold
		return

	# Only accumulate while actually moving (the false-positive gate, §3 Proxy A).
	var vel: Vector2 = _player.velocity if "velocity" in _player else Vector2.ZERO
	if vel.length() > MOVE_EPS:
		_seconds_wandering += dt
		if _seconds_wandering >= _emit_floor:
			EventBus.nav_lost_proxy.emit(
				PROXY_ID, _seconds_wandering, GameState.current_depth_index)
			# Rate-limit: one emission per additional threshold of wandering, so a
			# single long lost-episode logs as escalating events, not a flood.
			_emit_floor += _rc.r4_lost_proxy_threshold


func _on_run_ended(_reason: StringName, _duration_s: float, _depth_reached: int) -> void:
	_seconds_wandering = 0.0
	_emit_floor = _rc.r4_lost_proxy_threshold
	set_process(false)
