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
##   - Depth          ← GameState.current_depth, refreshed on run_inventory_changed /
##                       band_entered (no depth_changed signal exists in M1).
## The clock bar tints green→amber→red as it drains (cost-of-pushing made visceral),
## and under a single urgency threshold the Holding label pulses ("this is what you'd
## walk away with"). Juice is intentionally MINIMAL — no vignette / slow-mo / heartbeat;
## those are post-playtest dial-up knobs (spec Open-question #2).
##
## Greybox only: plain Labels + a default-theme ProgressBar. A human owns the visual pass.
## All player-facing strings go through tr() against ui/hud/hud_strings.csv.

## Fraction of the clock at/below which urgency cues engage (pulse on Holding).
## Single tunable — the playtest-tightening knob (spec Open-question #2: start ~25%).
@export var urgency_fraction: float = 0.25

## Pulse speed (Hz-ish) for the Holding label under the urgency threshold.
@export var pulse_speed: float = 6.0

# Off-ladder, colourblind-aware clock ramp. Backed by the numeric "Ns" readout and
# the bar fill itself, so colour is never the only channel (readability rule).
const CLOCK_GREEN := Color(0.30, 0.85, 0.35)
const CLOCK_AMBER := Color(0.95, 0.80, 0.20)
const CLOCK_RED := Color(0.92, 0.26, 0.24)

# Legibility layer: the at-risk number stays high-contrast regardless of band styling.
const HOLDING_COLOR := Color(1, 1, 1)

@onready var _haul_value_label: Label = %HaulValueLabel
@onready var _clock_bar: ProgressBar = %ClockBar
@onready var _clock_label: Label = %ClockLabel
@onready var _depth_label: Label = %DepthLabel

var _clock_fraction: float = 1.0
var _pulse_t: float = 0.0


func _ready() -> void:
	EventBus.run_inventory_changed.connect(_on_run_inventory_changed)
	EventBus.dive_clock_changed.connect(_on_dive_clock_changed)
	EventBus.band_entered.connect(_on_band_entered)
	# A run boundary swaps the bag / resets depth without a run_inventory_changed,
	# so re-project on those edges too (mirrors the D2 panel's boundary handling).
	EventBus.run_started.connect(_on_run_boundary)
	EventBus.run_ended.connect(_on_run_boundary)
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
	# Holding is the at-risk number; refresh depth alongside it so the cost-of-pushing
	# stays in sync without a dedicated depth_changed signal.
	_refresh_haul()
	_refresh_depth()


func _on_dive_clock_changed(current: float, maximum: float) -> void:
	_clock_fraction = (current / maximum) if maximum > 0.0 else 0.0
	_clock_bar.max_value = maximum
	_clock_bar.value = current
	_clock_bar.modulate = _urgency_color(_clock_fraction)
	_clock_label.text = tr("HUD_CLOCK_TIME").format({"seconds": "%d" % ceili(current)})


func _on_band_entered(_band_id: StringName, _depth: int) -> void:
	_refresh_depth()


func _on_run_boundary(_a = null, _b = null, _c = null) -> void:
	# Variadic-tolerant: run_started(band, seed) / run_ended(reason, dur, depth).
	_refresh_haul()
	_refresh_depth()


# --- Refresh helpers ----------------------------------------------------------

func _refresh_haul() -> void:
	_haul_value_label.text = tr("HUD_HOLDING").format({"value": GameState.run_haul_value()})


func _refresh_depth() -> void:
	_depth_label.text = tr("HUD_DEPTH").format({"depth": GameState.current_depth})


## 1.0 → green, ~0.5 → amber, 0.0 → red. Off-ladder ramp (not the rarity ladder);
## the numeric readout + bar fill are the redundant non-colour channels.
func _urgency_color(frac: float) -> Color:
	var f: float = clampf(frac, 0.0, 1.0)
	if f > 0.5:
		return CLOCK_AMBER.lerp(CLOCK_GREEN, (f - 0.5) * 2.0)
	return CLOCK_RED.lerp(CLOCK_AMBER, f * 2.0)
