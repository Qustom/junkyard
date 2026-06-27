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

# K4 (M1.4): near-end warning + configurable length. All gated so timer_enabled=false
# reproduces the M1.0/M1.3 clock byte-for-byte — see _on_run_started.
var _fired_warning: bool = false      # one-shot warning latch, mirrors _fired_timeout
var _warning_threshold: float = 0.0   # resolved seconds-remaining; 0.0 => no warning this run
var _effective_max: float = 0.0       # config.max_light OR the timer_length_s override


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)
	# R3 (M1.1) clock-tax seam: when the ExposureMeter's `clock` penalty fires it emits
	# exposure_clock_tax(seconds); we subtract it from remaining light via the existing
	# guarded mutator. No-op with R3 off (the meter never emits). modify_light clamps to
	# 0 and fires dive_clock_timeout once if the tax empties the clock.
	EventBus.exposure_clock_tax.connect(_on_exposure_clock_tax)


## Reset and begin draining for a new dive. Args come from run_started's
## signature (band_id, seed); unused here — the clock only needs the start edge.
func _on_run_started(_band_id: StringName = &"", _seed: int = 0) -> void:
	if config == null:
		push_error("DiveClock: no config assigned; cannot start.")
		return
	# K4: resolve the EFFECTIVE length + warning threshold from the run config. All-off
	# default (timer_enabled=false / no config) keeps _effective_max = config.max_light and
	# _warning_threshold = 0.0 => M1.0/M1.3 behaviour exactly, no warning ever fires.
	# Mirrors the effective_room_count() override precedent (run_config.gd:400).
	_effective_max = config.max_light
	_warning_threshold = 0.0
	var cfg: RunConfig = GameState.active_run_config  # same accessor decision_hud uses
	if cfg != null and cfg.timer_enabled:
		if cfg.timer_length_s > 0.0:
			_effective_max = cfg.timer_length_s        # 0.0 => keep DiveClockConfig.max_light
		_warning_threshold = cfg.timer_warning_threshold_s  # 0.0 => still no warning
	# "full" now means the EFFECTIVE max (start_light > 0 still starts at the authored value).
	_current = config.start_light if config.start_light > 0.0 else _effective_max
	_active = true
	_fired_timeout = false
	_fired_warning = false
	# Edge case: if the dive STARTS at/below the threshold (a tiny timer_length_s, or a low
	# start_light), pre-arm the latch so we never warn on frame 0 — the warning is a
	# "running low" cue, not a "you start low" cue.
	if _warning_threshold > 0.0 and _current <= _warning_threshold:
		_fired_warning = true
	EventBus.dive_clock_changed.emit(_current, _effective_max)


## Stop draining on extract/death/timeout-handling. Args come from run_ended's
## signature (reason, duration_s, depth_reached); unused. No timeout is fired —
## the run ended for some other reason.
func _on_run_ended(_reason: StringName = &"", _duration_s: float = 0.0, _depth_reached: int = 0) -> void:
	_active = false


func _process(delta: float) -> void:
	if not _active:
		return
	modify_light(-config.drain_per_second * delta)


## R3 clock-tax consumer: subtract `seconds` of remaining light when the exposure
## meter taxes the clock (r3_penalty_kind = clock). Inert when the clock is not active
## (between dives) — modify_light early-returns on a null config and otherwise only
## affects an in-progress dive.
func _on_exposure_clock_tax(seconds: float) -> void:
	if not _active:
		return
	modify_light(-seconds)


## The single guarded mutator for light — covers both drain (negative) and
## refuel (positive). Clamps to [0, max_light], emits dive_clock_changed, and
## fires dive_clock_timeout exactly once if light crosses to zero. Left wired but
## unused by M1 gameplay so descending-costs-light / extract-refuels can drop in
## later without touching the core loop.
func modify_light(amount: float) -> void:
	if config == null:
		return
	_current = clampf(_current + amount, 0.0, _effective_max)
	EventBus.dive_clock_changed.emit(_current, _effective_max)
	# K4: near-end warning — fire EXACTLY ONCE as remaining light crosses the threshold.
	# Latched with _fired_warning (reset only at _on_run_started), mirroring _fired_timeout,
	# so per-frame drain below the threshold never re-fires it. Ordered BEFORE the timeout
	# block so a single mutation that blows past the threshold straight to zero still emits
	# the warning before the timeout ("almost -> gone"). Inert when _warning_threshold == 0.0
	# (all-off control), so an all-off run is byte-identical to M1.0/M1.3.
	if _warning_threshold > 0.0 and not _fired_warning and _current <= _warning_threshold:
		_fired_warning = true
		EventBus.dive_clock_warning.emit(_current, _effective_max)
	if _current <= 0.0 and not _fired_timeout:
		_fired_timeout = true
		_active = false
		EventBus.dive_clock_timeout.emit()


## Read-only accessors (for HUD/telemetry/tests that want authoritative state).
func get_light() -> float:
	return _current


func get_max_light() -> float:
	# K4: report the EFFECTIVE max (the timer_length_s override when applied at run start,
	# else the authored config.max_light). _effective_max is 0.0 before the first run starts,
	# so fall back to the config value until then — preserves the pre-run accessor contract.
	if _effective_max > 0.0:
		return _effective_max
	return config.max_light if config != null else 0.0


func is_active() -> bool:
	return _active
