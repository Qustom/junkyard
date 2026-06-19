class_name ExposureMeter
extends Node
## ExposureMeter (R3, M1.1 Wave 2) — the depth-weighted "rising instability" meter.
##
## A THROWAWAY greybox prototype of the eventual M3 exposure system (R3 spec §0): it
## climbs faster the deeper/longer the player lingers, fires escalating penalties at
## ascending thresholds, and (optionally) forces a timeout loss at the cap. It exists
## only to test whether a lingering cost makes "push deeper vs. extract now" a felt
## gamble. It is NOT meta-state and is NOT balanced — every number is a RunConfig knob.
##
## RUN-STATE, not an autoload (TDD §2). A plain Node placed in the dive scene; RG1/G3
## assembly wires it in (this task builds + unit-tests it standalone, never touches
## main_game.gd). The meter resets to 0 on run_started and is discarded at run end —
## never banked, never saved, never read by SaveManager. The naming collision with the
## persistent meta `GameState.exposure` is deliberate-but-separate: this is disposable.
##
## Decoupling contract (R3 spec §9 D1): R3 NEVER edits event_bus.gd or game_state.gd.
## It only EMITS the six TEL-pre-declared signals, and CALLS the existing public
## GameState.fail_run(&"timeout") for the forced loss. The Player consumes the speed
## mult, the R4 fog consumes the vision mult, the A3 dive clock consumes the clock tax,
## and the greybox HUD reads exposure_meter_changed.

## Fixed internal ceiling (NOT a knob) — gives thresholds/penalties a stable 0–100
## frame so the Director tunes r3_threshold_levels against a known cap (R3 spec §2.1).
const METER_MAX: float = 100.0

## Stacked speed penalties never freeze the player (R3 spec §3.3).
const SPEED_FLOOR: float = 0.35

## Penalty-kind enum values mirror run_config.gd's @export_enum order (no named
## constants there — R3 spec §3.3): 0 none, 1 speed, 2 vision, 3 clock.
const PENALTY_NONE: int = 0
const PENALTY_SPEED: int = 1
const PENALTY_VISION: int = 2
const PENALTY_CLOCK: int = 3

## Vision mult floor (greybox; R4 fog clamps its own radius too). Mirrors §6 pseudocode.
const VISION_FLOOR: float = 0.2

var _cfg: RunConfig             # cached from GameState.active_run_config at run start
var _active: bool = false       # r3_enabled AND inside a run
var _meter: float = 0.0         # run-state scalar, disposable, [0, METER_MAX]
var _live_depth: int = 0        # from EventBus.depth_changed (BUG2)
var _max_depth: int = 0         # running max within-band depth this dive (from BUG2)
var _levels_crossed: int = 0    # highest threshold index fired this dive (one-shot, no re-arm)


func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)
	# BUG2 surface: live within-band depth. depth_changed(depth_index, max_depth) is
	# pre-declared on main and EMITTED by GameState.set_current_depth(). R3 only listens.
	EventBus.depth_changed.connect(_on_depth_changed)
	set_process(false)


# --- Run lifecycle -----------------------------------------------------------

func _on_run_started(_band_id: StringName = &"", _seed: int = 0) -> void:
	_cfg = GameState.active_run_config
	_active = _cfg != null and _cfg.r3_enabled
	_meter = 0.0
	_live_depth = 0
	_max_depth = 0
	_levels_crossed = 0
	set_process(_active)
	if _active:
		_emit_meter_changed()      # HUD shows 0/100 at dive start
		_emit_speed_mult()         # neutral mult (no levels crossed yet → 1.0)


func _on_run_ended(_reason: StringName = &"", _duration_s: float = 0.0, _depth_reached: int = 0) -> void:
	# Inert at run end. Emit a neutral speed mult so a stacked penalty never leaks
	# across runs into the next dive's player (R3 spec §6 _on_run_ended).
	_active = false
	set_process(false)
	_emit_speed_mult_neutral()


func _on_depth_changed(depth_index: int, max_depth: int) -> void:
	_live_depth = depth_index
	_max_depth = max_depth


# --- Per-frame climb / decay / crossings / max-loss --------------------------

func _process(delta: float) -> void:
	if not _active or not GameState.run_active or _cfg == null:
		return

	# --- climb vs. decay (retreating = shallower than this dive's max; §9 D2) ---
	# Stateless: reads the BUG2 surface directly. Standing still at max = climbing;
	# standing still while already shallow (below max) = decaying.
	var retreating: bool = _live_depth < _max_depth
	var new_meter: float
	if retreating and _cfg.r3_decay_on_retreat > 0.0:
		new_meter = _meter - _cfg.r3_decay_on_retreat * delta
	else:
		var climb: float = _cfg.r3_base_climb_rate + _cfg.r3_rate_per_depth * float(_live_depth)
		new_meter = _meter + climb * delta

	# Both per-frame accrual and the R2 exposure toll (add()) funnel the meter
	# mutation + crossing-detection + forced-loss through this single shared helper
	# (BUG5: do NOT create a second divergent crossing path).
	_mutate_meter(new_meter)


## R2's exposure toll (return_cost.gd TOLL_EXPOSURE) injects `amount` into R3's
## run-state meter via this public mutator (BUG5). It routes through the SAME
## crossing/penalty/forced-loss logic as natural accrual, so a toll that pushes past
## an r3_threshold_levels boundary fires the same exposure_crossed / exposure_penalty
## / exposure_meter_changed. Run-state only: mutates the disposable meter, never
## GameState meta. Inert unless R3 is active (R2 only calls it when r3_enabled, but
## we guard defensively so a stray call while inactive is a no-op).
func add(amount: float) -> void:
	if not _active or _cfg == null:
		return
	_mutate_meter(_meter + amount)


## Single source of truth for mutating the run-state meter: clamp to [0, METER_MAX],
## fire edge-triggered one-shot threshold crossings + their penalties, honor the
## max-meter forced loss, and emit the HUD projection. Both _process() accrual and
## add() (R2 exposure toll) funnel through here (BUG5).
func _mutate_meter(value: float) -> void:
	_meter = clampf(value, 0.0, METER_MAX)

	# --- edge-triggered, one-shot threshold crossings (§3.1, §9 D3 no re-arm) ---
	# A crossed threshold stays crossed for the dive; decay below it never un-fires
	# or re-arms. _levels_crossed tracks the highest index fired so far.
	var levels: PackedFloat32Array = _cfg.r3_threshold_levels
	while _levels_crossed < levels.size() and _meter >= levels[_levels_crossed]:
		var idx: int = _levels_crossed
		_levels_crossed += 1
		EventBus.exposure_crossed.emit(idx, _live_depth, _run_t_ms())  # run_t_ms TEL-stamped; 0 ok
		_apply_penalty(idx)
		# exposure_penalty's 2nd arg is a StringName (penalty_kind) per the as-built
		# event_bus.gd declaration — emit the kind name, not the enum int.
		EventBus.exposure_penalty.emit(idx, _penalty_kind_name())

	# --- max-meter forced loss (§3.2, §9 D1) ---
	if _cfg.r3_max_forces_loss and _meter >= METER_MAX:
		_active = false
		set_process(false)
		# Call (not edit) the existing public run-end API. The _run_ended idempotency
		# guard in GameState makes a same-frame extract-vs-max tie safe (extract wins).
		GameState.fail_run(&"timeout")
		return

	_emit_meter_changed()   # HUD projection (every frame while climbing)


# --- Penalty application -----------------------------------------------------

func _apply_penalty(_level_idx: int) -> void:
	match _cfg.r3_penalty_kind:
		PENALTY_NONE:
			pass                    # telemetry-only control
		PENALTY_SPEED:
			_emit_speed_mult()      # player multiplies into stats.max_speed
		PENALTY_VISION:
			_emit_vision_mult()     # R4 fog tightens; no-op on-screen if R4 off (§9 D4)
		PENALTY_CLOCK:
			# A3 dive clock subtracts `seconds` from remaining light (one-shot/crossing).
			EventBus.exposure_clock_tax.emit(_cfg.r3_penalty_magnitude)


## Map the run_config enum int → the StringName the exposure_penalty signal expects.
func _penalty_kind_name() -> StringName:
	match _cfg.r3_penalty_kind:
		PENALTY_SPEED:
			return &"speed"
		PENALTY_VISION:
			return &"vision"
		PENALTY_CLOCK:
			return &"clock"
		_:
			return &"none"


func _emit_speed_mult() -> void:
	# N crossings stack to N× the per-crossing reduction, floored so the player never
	# freezes (R3 spec §3.3).
	var mult: float = maxf(SPEED_FLOOR, 1.0 - _cfg.r3_penalty_magnitude * float(_levels_crossed))
	EventBus.exposure_speed_mult_changed.emit(mult)


func _emit_speed_mult_neutral() -> void:
	EventBus.exposure_speed_mult_changed.emit(1.0)


func _emit_vision_mult() -> void:
	var mult: float = maxf(VISION_FLOOR, 1.0 - _cfg.r3_penalty_magnitude * float(_levels_crossed))
	EventBus.exposure_vision_mult_changed.emit(mult)   # R4 fog reads (no-op if R4 off)


func _emit_meter_changed() -> void:
	EventBus.exposure_meter_changed.emit(_meter, METER_MAX)   # greybox HUD bar reads this


## Run-elapsed ms is TEL-stamped on the exposure_crossed row at log time, so R3 may
## emit a placeholder. Monotonic engine clock keeps it sane if anything reads it.
func _run_t_ms() -> int:
	return Time.get_ticks_msec()


# --- Read-only accessors (tests / debug) -------------------------------------

func get_meter() -> float:
	return _meter


func get_levels_crossed() -> int:
	return _levels_crossed


func is_active() -> bool:
	return _active
