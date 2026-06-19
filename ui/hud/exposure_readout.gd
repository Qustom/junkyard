class_name ExposureReadout
extends Control
## ExposureReadout (R3, M1.1 Wave 2 · extended by M1.2 I3) — the greybox exposure
## HUD: a colour-ramped meter bar, read-only threshold ticks, a threshold-cross
## flash, and a penalty banner.
##
## PURE PROJECTION, mirrors decision_hud.gd (E2) exactly: it owns NO source of truth,
## is signal-driven with no polling, and only reflects the ExposureMeter's run-state.
## It subscribes to four already-declared, already-emitted EventBus signals — it
## adds NO new signal and NO game state:
##   - exposure_meter_changed(value, maximum) → bar fill + colour ramp + numeric label
##   - exposure_crossed(level, depth, run_t_ms) → spend the crossed tick + flash (motion)
##   - exposure_penalty(level, penalty_kind)   → penalty banner naming the kind (text)
##   - run_started / run_ended                 → visibility + rebuild ticks per run
##
## I3 SPLIT (Resolved F2): the threshold-cross FLASH + TICK-SPEND ride exposure_crossed;
## the penalty BANNER rides exposure_penalty. The two fire same-frame, paired — we do
## NOT react to both for the flash, or it would double-punch.
##
## READABILITY (E2 rule — every colour cue has a redundant non-colour channel):
##   - bar colour ramp  ← backed by the numeric "N / 100" label + the bar fill length
##   - threshold ticks  ← non-colour: tick POSITION (telegraph) + spent/unspent SHAPE
##   - threshold cross  ← non-colour: a MOTION punch (flash) + the tick changing state
##   - penalty          ← non-colour: a TEXT banner (tr()) + the flash MOTION
## The at-risk number (the exposure value) stays high-contrast (white + outline).
##
## Visibility: shown ONLY when GameState.active_run_config.r3_enabled, so an all-off
## run's HUD equals M1.0 (every I3 node is hidden / inert with R3 off). Visibility is
## re-evaluated on every run boundary because active_run_config is bound at start_run
## and cleared at end_run (run-state). Mounted as a child of the E2 DecisionHUD.

# Shared off-ladder ramp — SAME constants/shape as decision_hud.gd's clock ramp, so
# R2/R3/clock read from one severity language (the readability "one source of truth"
# rule). Climbing exposure inverts the clock's draining sense: low = green (safe),
# high = red (danger now).
const RAMP_GREEN := Color(0.30, 0.85, 0.35)
const RAMP_AMBER := Color(0.95, 0.80, 0.20)
const RAMP_RED := Color(0.92, 0.26, 0.24)

# Greybox tick styling (a human owns the visual pass). Unspent = neutral upcoming
# threshold; spent = a thicker, darker mark so "this penalty already bit" reads as a
# SHAPE/STATE change, never colour alone.
const TICK_WIDTH_UNSPENT := 2.0
const TICK_WIDTH_SPENT := 4.0
const TICK_COLOR_UNSPENT := Color(1, 1, 1, 0.75)
const TICK_COLOR_SPENT := Color(0.15, 0.15, 0.15, 1.0)

# Penalty-kind StringName → banner tr() key (Resolved: keys confirmed against
# exposure_meter.gd _penalty_kind_name()). &"none" → no banner (telemetry-only).
const _BANNER_KEYS := {
	&"speed": "HUD_PENALTY_SPEED",
	&"vision": "HUD_PENALTY_VISION",
	&"clock": "HUD_PENALTY_CLOCK",
}

## Minimum on-screen time floor for the penalty banner (Resolved Q7: latest-wins with
## a floor; a fast double-crossing re-pulses the SAME run-constant message, never thrashes).
@export var banner_hold_seconds: float = 0.9

## Flash punch duration (the motion channel for a crossing).
@export var flash_seconds: float = 0.35

@onready var _bar: ProgressBar = %ExposureBar
@onready var _label: Label = %ExposureLabel
@onready var _ticks: Control = %ExposureTicks
@onready var _flash: ColorRect = %ExposureFlash
@onready var _banner: Label = %ExposurePenaltyBanner

# One shared flash budget (Resolved Q3): a new punch re-triggers rather than stacks.
var _flash_tween: Tween
var _banner_tween: Tween
# Tick rects, indexed by threshold level so exposure_crossed(level) can spend the right one.
var _tick_rects: Array[ColorRect] = []
# Stack count for the banner (Resolved Q7 nice-to-have): "Slowed x2" conveys escalation.
var _crossings_this_run: int = 0
var _last_penalty_kind: StringName = &""


func _ready() -> void:
	EventBus.exposure_meter_changed.connect(_on_meter_changed)
	# I3: threshold telegraph + penalty feedback (both signals already emitted by R3).
	EventBus.exposure_crossed.connect(_on_crossed)
	EventBus.exposure_penalty.connect(_on_penalty)
	# Re-evaluate visibility on run edges: the config is bound at start_run and cleared
	# at end_run, so we cannot decide once in _ready (no run is active at HUD load).
	EventBus.run_started.connect(_on_run_boundary)
	EventBus.run_ended.connect(_on_run_boundary)
	_refresh_visibility()
	_rebuild_ticks()


func _on_meter_changed(value: float, maximum: float) -> void:
	_bar.max_value = maximum
	_bar.value = value
	var frac: float = (value / maximum) if maximum > 0.0 else 0.0
	_bar.modulate = _ramp(frac)  # colour channel
	# numeric channel (load-bearing): the value is the truth, colour only reinforces it.
	_label.text = tr("HUD_EXPOSURE_FMT").format({"value": int(value), "max": int(maximum)})


## Drive the flash (motion) + tick-spend (shape state) off exposure_crossed ONLY
## (Resolved F2: crossed + penalty fire paired same-frame; reacting to both double-punches).
func _on_crossed(level: int, _depth: int, _run_t_ms: int) -> void:
	if not _is_r3_enabled():
		return
	_crossings_this_run += 1
	_mark_tick_spent(level)
	_punch_flash()


## Penalty banner (text channel) off exposure_penalty. penalty_kind is a StringName
## and is RUN-CONSTANT (Resolved F1): every crossing in a run carries the same kind,
## so latest-wins only ever re-asserts the same message (re-pulses, never thrashes).
func _on_penalty(_level: int, penalty_kind: StringName) -> void:
	if not _is_r3_enabled():
		return
	if not _BANNER_KEYS.has(penalty_kind):
		return  # &"none" (or unknown) → telemetry-only, no banner; the flash already fired.
	_last_penalty_kind = penalty_kind
	var base: String = tr(_BANNER_KEYS[penalty_kind])
	# Stack count conveys escalation (each crossing stacks the penalty in R3).
	_banner.text = base if _crossings_this_run <= 1 else "%s x%d" % [base, _crossings_this_run]
	_pulse_banner()


func _on_run_boundary(_a = null, _b = null, _c = null) -> void:
	# Variadic-tolerant: run_started(band, seed) / run_ended(reason, dur, depth).
	_crossings_this_run = 0
	_last_penalty_kind = &""
	_reset_cues()
	_refresh_visibility()
	_rebuild_ticks()


## R3 off (or no active config) → hidden, so the HUD equals M1.0. Read-only on the
## config; never mutate it.
func _refresh_visibility() -> void:
	visible = _is_r3_enabled()


func _is_r3_enabled() -> bool:
	var cfg: RunConfig = GameState.active_run_config
	return cfg != null and cfg.r3_enabled


# --- Threshold ticks (read-only projection of r3_threshold_levels) -------------

## Rebuild the tick marks from active_run_config.r3_threshold_levels, read ONCE per
## run on the boundary (Resolved Q6: read-only, no signal). Positioned at
## level / METER_MAX across the bar; METER_MAX is the bar's max_value (100.0, the
## fixed const in exposure_meter.gd — not a config field).
func _rebuild_ticks() -> void:
	for child in _ticks.get_children():
		child.queue_free()
	_tick_rects.clear()
	var cfg: RunConfig = GameState.active_run_config
	if cfg == null or not cfg.r3_enabled:
		return
	var levels: PackedFloat32Array = cfg.r3_threshold_levels
	var maximum: float = _bar.max_value if _bar.max_value > 0.0 else 100.0
	var bar_w: float = _bar_width()
	var bar_h: float = _bar_height()
	for i in range(levels.size()):
		var frac: float = clampf(levels[i] / maximum, 0.0, 1.0)
		var tick := ColorRect.new()
		tick.color = TICK_COLOR_UNSPENT
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.size = Vector2(TICK_WIDTH_UNSPENT, bar_h)
		tick.position = Vector2(frac * bar_w - TICK_WIDTH_UNSPENT * 0.5, 0.0)
		# Anchor by fraction so the tick tracks the bar if it is resized later.
		tick.set_meta(&"frac", frac)
		_ticks.add_child(tick)
		_tick_rects.append(tick)


## Switch a crossed tick to the spent SHAPE/STATE (wider + darker), telegraphing how
## many penalties remain — a non-colour channel behind the colour ramp.
func _mark_tick_spent(level: int) -> void:
	if level < 0 or level >= _tick_rects.size():
		return
	var tick: ColorRect = _tick_rects[level]
	var frac: float = float(tick.get_meta(&"frac", 0.0))
	tick.color = TICK_COLOR_SPENT
	tick.size = Vector2(TICK_WIDTH_SPENT, _bar_height())
	tick.position = Vector2(frac * _bar_width() - TICK_WIDTH_SPENT * 0.5, 0.0)


func _bar_width() -> float:
	var w: float = _bar.size.x
	return w if w > 0.0 else _bar.custom_minimum_size.x


func _bar_height() -> float:
	var h: float = _bar.size.y
	return h if h > 0.0 else _bar.custom_minimum_size.y


# --- Flash + banner (Tween-driven; one shared budget each) ---------------------

## Motion channel: a brief white overlay punch back to rest. Re-triggers (kills the
## prior) rather than stacking, so rapid crossings never pile additive alpha (Q3).
func _punch_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.modulate.a = 0.55
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, flash_seconds)


## Text channel: fade the banner in, hold for the floor duration, fade out. Latest-
## wins single instance (Q7); a re-pulse restarts the same banner with a fresh floor.
func _pulse_banner() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(banner_hold_seconds)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)


## Hard reset all transient cues at a run boundary so nothing leaks across runs.
func _reset_cues() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	if _flash != null:
		_flash.modulate.a = 0.0
	if _banner != null:
		_banner.modulate.a = 0.0
		_banner.text = ""
	if _bar != null:
		_bar.modulate = _ramp(0.0)


## Low = green (safe), high = red (danger). Inverts the clock ramp's draining sense;
## same severity language, off-ladder. Numeric label + bar fill are the non-colour channels.
func _ramp(frac: float) -> Color:
	var f: float = clampf(frac, 0.0, 1.0)
	if f < 0.5:
		return RAMP_GREEN.lerp(RAMP_AMBER, f * 2.0)
	return RAMP_AMBER.lerp(RAMP_RED, (f - 0.5) * 2.0)
