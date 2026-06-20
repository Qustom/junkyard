class_name DecisionHUD
extends CanvasLayer
## DecisionHUD (E2) — the push-vs-extract decision surface, the centrepiece of the
## M1 "is it fun?" gate. PURE PROJECTION: it owns NO source of truth. It reflects
## A3 (clock), B3/GameState (depth), and D1 (haul value), making the three decision
## quantities — what you HAVE, the TIME-cost of pushing, the DEPTH-cost of pushing —
## simultaneously legible so the trade reads inside the ~30s dive window.
##
## Signal-driven, no polling (playbook + TDD §2):
##   - Holding value  ← EventBus.run_inventory_changed → GameState.run_haul_value()
##   - Clock bar/time ← EventBus.dive_clock_changed(current, maximum)
##   - Depth          ← GameState.current_depth_index / .max_depth_reached, refreshed
##                       on EventBus.depth_changed (the BUG2/M1.1 signal, edge-triggered
##                       in GameState.set_current_depth), plus run boundaries for the
##                       reset-to-0 paint depth_changed doesn't emit. (J5, M1.3 — was
##                       wrongly reading the band counter current_depth on inventory/band edges.)
## The clock bar tints green→amber→red as it drains (cost-of-pushing made visceral),
## and under a single urgency threshold the Holding label pulses ("this is what you'd
## walk away with"). Juice is intentionally MINIMAL — no vignette / slow-mo / heartbeat;
## those are post-playtest dial-up knobs (spec Open-question #2).
##
## Greybox only: plain Labels + a default-theme ProgressBar. A human owns the visual pass.
## All player-facing strings go through tr() against ui/hud/hud_strings.csv.
##
## M1.2 I3 (R2 cues): this surface ALSO renders R2's egress toll — a clock-bar pulse
## (the toll IS a DiveClock.modify_light(-cost) drain, so flashing the bar the player
## already watches is the causally-truthful cue) plus a floating "-N {unit}" indicator
## spawned near the clock. Both project the already-emitted return_cost_incurred —
## NO new EventBus signal, NO game state. An optional subtle HUD-space screen-shake on
## an R3 penalty (driven from this CanvasLayer's own Root, never the game camera) makes
## the bite land; it is small, brief, and never the only channel. All R2/R3 cues are
## gated on their opposition: with R2/R3 off the HUD is byte-for-byte the M1.0 baseline.

## Fraction of the clock at/below which urgency cues engage (pulse on Holding).
## Single tunable — the playtest-tightening knob (spec Open-question #2: start ~25%).
@export var urgency_fraction: float = 0.25

## Pulse speed (Hz-ish) for the Holding label under the urgency threshold.
@export var pulse_speed: float = 6.0

## I3: duration of the clock-bar toll pulse (motion channel for an R2 charge).
@export var clock_pulse_seconds: float = 0.35

## I3: lifetime of a floating "-N {unit}" cost indicator (rise + fade).
@export var cost_indicator_seconds: float = 1.1

## I3: subtle HUD-space screen-shake on an R3 penalty. Small/brief and never the only
## channel (Q5 accepted, accessibility-friendly). Set 0 to disable; M5 owns a global toggle.
@export var penalty_shake_pixels: float = 5.0
@export var penalty_shake_seconds: float = 0.22

# Off-ladder, colourblind-aware clock ramp. Backed by the numeric "Ns" readout and
# the bar fill itself, so colour is never the only channel (readability rule).
const CLOCK_GREEN := Color(0.30, 0.85, 0.35)
const CLOCK_AMBER := Color(0.95, 0.80, 0.20)
const CLOCK_RED := Color(0.92, 0.26, 0.24)

# Off-ladder pulse colour for the R2 clock-toll punch (a hot amber-white spike that
# settles back to the bar's ramp colour). Distinct from the steady ramp so the toll
# reads as a discrete bite, not background drain. The number drop is the redundant channel.
const CLOCK_TOLL_PULSE := Color(1.0, 0.95, 0.55)

# Legibility layer: the at-risk number stays high-contrast regardless of band styling.
const HOLDING_COLOR := Color(1, 1, 1)

# return_cost_incurred cost_kind StringName → unit tr() key (confirmed against
# return_cost.gd: &"clock"/&"exposure"/&"meter"/&"decay"). &"decay" has no number.
const _COST_UNIT_KEYS := {
	&"clock": "HUD_COST_LIGHT",
	&"exposure": "HUD_COST_EXPOSURE",
	&"meter": "HUD_COST_METER",
	&"decay": "HUD_COST_DECAY",
}

@onready var _root: Control = $Root
@onready var _haul_value_label: Label = %HaulValueLabel
@onready var _clock_bar: ProgressBar = %ClockBar
@onready var _clock_label: Label = %ClockLabel
@onready var _depth_label: Label = %DepthLabel
@onready var _cost_anchor: Control = %CostIndicatorAnchor

var _clock_fraction: float = 1.0
var _pulse_t: float = 0.0

# I3 transient-cue budgets (one at a time; re-trigger rather than stack).
var _clock_pulse_tween: Tween
var _shake_tween: Tween
var _root_home: Vector2 = Vector2.ZERO


func _ready() -> void:
	EventBus.run_inventory_changed.connect(_on_run_inventory_changed)
	EventBus.dive_clock_changed.connect(_on_dive_clock_changed)
	EventBus.band_entered.connect(_on_band_entered)
	# J5: depth_changed is the signal that actually broadcasts ROOM depth
	# (depth_index, max_depth). Edge-triggered in GameState.set_current_depth — fires
	# exactly when the player crosses into a piece of a different depth_index.
	EventBus.depth_changed.connect(_on_depth_changed)
	# A run boundary swaps the bag / resets depth without a run_inventory_changed,
	# so re-project on those edges too (mirrors the D2 panel's boundary handling).
	# It also paints "Depth 0 / 0" at run start — set_current_depth(0,…) early-returns
	# at entry, so depth_changed does NOT fire then (J5).
	EventBus.run_started.connect(_on_run_boundary)
	EventBus.run_ended.connect(_on_run_boundary)
	# I3: R2 toll cues + the optional R3-penalty shake. Both already-emitted signals;
	# both gated on their opposition so an all-off run stays the M1.0 HUD.
	EventBus.return_cost_incurred.connect(_on_return_cost)
	EventBus.exposure_penalty.connect(_on_exposure_penalty)
	_root_home = _root.position
	_refresh_haul()
	_refresh_depth()


func _process(delta: float) -> void:
	# Pulse runs only under the urgency threshold; otherwise the label sits steady
	# at full-contrast white. This is the ONLY per-frame work (no polling of state).
	if _clock_fraction <= urgency_fraction and _clock_fraction > 0.0:
		_pulse_t += delta * pulse_speed
		var a: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(_pulse_t))
		_haul_value_label.modulate = Color(HOLDING_COLOR.r, HOLDING_COLOR.g, HOLDING_COLOR.b, a)
	else:
		_pulse_t = 0.0
		_haul_value_label.modulate = HOLDING_COLOR


# --- Signal handlers (projection only) ---------------------------------------

func _on_run_inventory_changed(_used_slots: int, _max_slots: int) -> void:
	# Holding is the at-risk number. (Depth is no longer refreshed here — it has its
	# own edge, EventBus.depth_changed; inventory has nothing to do with room depth. J5.)
	_refresh_haul()


## J5: the room depth changed — the player crossed into a piece of a new depth_index.
## Pure projection of the already-emitted depth_changed(depth_index, max_depth); the
## payload carries both numbers but we delegate to _refresh_depth() so the initial
## paint and the signal paint share one code path (re-reads GameState).
func _on_depth_changed(_depth_index: int, _max_depth: int) -> void:
	_refresh_depth()


func _on_dive_clock_changed(current: float, maximum: float) -> void:
	_clock_fraction = (current / maximum) if maximum > 0.0 else 0.0
	_clock_bar.max_value = maximum
	_clock_bar.value = current
	_clock_bar.modulate = _urgency_color(_clock_fraction)
	_clock_label.text = tr("HUD_CLOCK_TIME").format({"seconds": "%d" % ceili(current)})


func _on_band_entered(_band_id: StringName, _depth: int) -> void:
	# J5: band entry no longer touches the depth readout — the readout is room-based
	# (current_depth_index), driven by depth_changed, not the band counter. Kept
	# subscribed for future band-aware HUD work; a no-op for depth in M1.
	pass


func _on_run_boundary(_a = null, _b = null, _c = null) -> void:
	# Variadic-tolerant: run_started(band, seed) / run_ended(reason, dur, depth).
	_refresh_haul()
	_refresh_depth()


# --- Refresh helpers ----------------------------------------------------------

func _refresh_haul() -> void:
	_haul_value_label.text = tr("HUD_HOLDING").format({"value": GameState.run_haul_value()})


## J5: project the ROOM depth (current_depth_index) and the deepest reached
## (max_depth_reached, the gate metric reported as run_ended.depth_reached), NOT the
## band counter current_depth. depth_index is the value run_config thresholds + the
## gate all speak in, so the player's progress readout now matches the game's own
## depth language. HUD-only: reads GameState, mutates nothing, emits nothing.
func _refresh_depth() -> void:
	_depth_label.text = tr("HUD_DEPTH").format({
		"depth": GameState.current_depth_index,
		"max": GameState.max_depth_reached,
	})


## 1.0 → green, ~0.5 → amber, 0.0 → red. Off-ladder ramp (not the rarity ladder);
## the numeric readout + bar fill are the redundant non-colour channels.
func _urgency_color(frac: float) -> Color:
	var f: float = clampf(frac, 0.0, 1.0)
	if f > 0.5:
		return CLOCK_AMBER.lerp(CLOCK_GREEN, (f - 0.5) * 2.0)
	return CLOCK_RED.lerp(CLOCK_AMBER, f * 2.0)


# --- M1.2 I3: R2 egress-toll cues (clock pulse + floating "-N {unit}") ---------

## Projects the already-emitted return_cost_incurred. Gated on r2_enabled so an
## R2-off run never shows these cues (= M1.0 HUD). The clock pulse only fires for the
## clock toll (the only kind that actually drained the clock); every kind gets the
## floating indicator naming HOW MUCH and WHICH resource (text + number channels).
func _on_return_cost(_depth: int, cost_kind: StringName, magnitude: float) -> void:
	if not _r2_enabled():
		return
	if cost_kind == &"clock":
		_pulse_clock_bar()  # motion channel on the bar the toll actually drained
	_spawn_cost_indicator(cost_kind, magnitude)


## Motion channel: a hot punch on the clock bar settling back to its ramp colour, so
## the toll's clock drop reads as a discrete bite. Re-triggers rather than stacks.
func _pulse_clock_bar() -> void:
	if _clock_pulse_tween != null and _clock_pulse_tween.is_valid():
		_clock_pulse_tween.kill()
	_clock_bar.modulate = CLOCK_TOLL_PULSE
	_clock_pulse_tween = create_tween()
	_clock_pulse_tween.tween_property(_clock_bar, "modulate",
		_urgency_color(_clock_fraction), clock_pulse_seconds)


## Text + number channel: a short-lived "-N {unit}" that rises and fades near the
## clock (its causal home). &"decay" carries no number (its magnitude is a link count).
func _spawn_cost_indicator(cost_kind: StringName, magnitude: float) -> void:
	var unit_key: String = _COST_UNIT_KEYS.get(cost_kind, "HUD_COST_LIGHT")
	var unit: String = tr(unit_key)
	var text: String
	if cost_kind == &"decay":
		text = unit  # "route collapsed" — no number
	else:
		text = tr("HUD_RETREAT_COST").format({"amount": int(round(magnitude)), "unit": unit})

	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Legibility layer: high-contrast number regardless of band styling.
	label.add_theme_color_override(&"font_color", Color(1, 0.55, 0.45))
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override(&"outline_size", 5)
	label.add_theme_font_size_override(&"font_size", 20)
	label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label.position = Vector2(-212.0, 0.0)
	label.custom_minimum_size = Vector2(196, 26)
	_cost_anchor.add_child(label)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(label, "position:y", -28.0, cost_indicator_seconds)
	t.tween_property(label, "modulate:a", 0.0, cost_indicator_seconds)
	t.chain().tween_callback(label.queue_free)


# --- M1.2 I3: optional subtle HUD-space shake on an R3 penalty -----------------

## Drives a tiny, brief positional shake of THIS HUD's own Root (never the game
## camera — I3 owns no camera/main_game.gd). Gated on r3_enabled + a non-zero
## amplitude knob; never the only channel (the bar flash + banner carry the penalty).
## penalty_kind &"none" → no shake (the telemetry-only control stays silent).
func _on_exposure_penalty(_level: int, penalty_kind: StringName) -> void:
	if penalty_shake_pixels <= 0.0 or penalty_shake_seconds <= 0.0:
		return
	if penalty_kind == &"none":
		return
	if not _r3_enabled():
		return
	_shake_root()


func _shake_root() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		_root.position = _root_home
	_shake_tween = create_tween()
	var steps: int = 5
	for i in range(steps):
		var decay: float = 1.0 - float(i) / float(steps)
		var off := Vector2(
			(RNG.randf() * 2.0 - 1.0) * penalty_shake_pixels * decay,
			(RNG.randf() * 2.0 - 1.0) * penalty_shake_pixels * decay)
		_shake_tween.tween_property(_root, "position", _root_home + off,
			penalty_shake_seconds / float(steps))
	_shake_tween.tween_property(_root, "position", _root_home,
		penalty_shake_seconds / float(steps))


# --- Opposition gates (read-only on the run config; never mutate it) -----------

func _r2_enabled() -> bool:
	var cfg: RunConfig = GameState.active_run_config
	return cfg != null and cfg.r2_enabled


func _r3_enabled() -> bool:
	var cfg: RunConfig = GameState.active_run_config
	return cfg != null and cfg.r3_enabled
