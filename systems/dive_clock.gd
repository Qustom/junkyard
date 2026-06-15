class_name DiveClock
extends Node
## DiveClock — the in-dive "light" resource (A3). Single source of truth for the
## depleting time-pressure meter that drives the push-your-luck dive loop.
##
## RUN-STATE, not an autoload (TDD §2: run-state vs meta-state). The clock is
## created/destroyed per dive — a fresh node always starts with its guards reset,
## so there is no double-emit path across dives. It writes NOTHING to meta-state.
##
## Lifecycle is driven entirely through EventBus, so the clock is decoupled from
## the dive flow. Per the orchestrator-locked wave-2 contract it keys off the
## EXISTING run lifecycle signals (GameState is the sole emitter):
##   - run_started(band_id, seed) -> reset & start draining (once per run)
##   - run_ended(reason, duration_s, depth_reached) -> stop draining, no timeout
## (The A3 spec's hypothetical dive_started/dive_ended were folded into these.)
##
## While active it drains `drain_per_second * delta` each idle frame, emits
## EventBus.dive_clock_changed every frame for the passive meter UI, and emits
## EventBus.dive_clock_timeout EXACTLY ONCE when light crosses zero, then
## deactivates. Timeout *handling* is out of scope (task E3 listens).
##
## process_mode is PROCESS_MODE_PAUSABLE (default) so the drain freezes whenever
## get_tree().paused is true — pause menus / inventory screens stop the clock for
## free without any extra code here.

@export var config: DiveClockConfig

var _current: float = 0.0
var _active: bool = false
var _fired_timeout: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)


## Reset and begin draining for a new dive. Args come from run_started's
## signature (band_id, seed); unused here — the clock only needs the start edge.
func _on_run_started(_band_id: StringName = &"", _seed: int = 0) -> void:
	if config == null:
		push_error("DiveClock: no config assigned; cannot start.")
		return
	_current = config.start_light if config.start_light > 0.0 else config.max_light
	_active = true
	_fired_timeout = false
	EventBus.dive_clock_changed.emit(_current, config.max_light)


## Stop draining on extract/death/timeout-handling. Args come from run_ended's
## signature (reason, duration_s, depth_reached); unused. No timeout is fired —
## the run ended for some other reason.
func _on_run_ended(_reason: StringName = &"", _duration_s: float = 0.0, _depth_reached: int = 0) -> void:
	_active = false


func _process(delta: float) -> void:
	if not _active:
		return
	modify_light(-config.drain_per_second * delta)


## The single guarded mutator for light — covers both drain (negative) and
## refuel (positive). Clamps to [0, max_light], emits dive_clock_changed, and
## fires dive_clock_timeout exactly once if light crosses to zero. Left wired but
## unused by M1 gameplay so descending-costs-light / extract-refuels can drop in
## later without touching the core loop.
func modify_light(amount: float) -> void:
	if config == null:
		return
	_current = clampf(_current + amount, 0.0, config.max_light)
	EventBus.dive_clock_changed.emit(_current, config.max_light)
	if _current <= 0.0 and not _fired_timeout:
		_fired_timeout = true
		_active = false
		EventBus.dive_clock_timeout.emit()


## Read-only accessors (for HUD/telemetry/tests that want authoritative state).
func get_light() -> float:
	return _current


func get_max_light() -> float:
	return config.max_light if config != null else 0.0


func is_active() -> bool:
	return _active
