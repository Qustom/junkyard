class_name ExposureReadout
extends Control
## ExposureReadout (R3, M1.1 Wave 2) — the greybox exposure-meter HUD bar.
##
## PURE PROJECTION, mirrors decision_hud.gd (E2) exactly: it owns NO source of truth,
## is signal-driven with no polling, and only reflects the ExposureMeter's run-state
## scalar. The meter (systems/oppositions/exposure_meter.gd) emits
## EventBus.exposure_meter_changed(value, maximum) each frame while climbing; this bar
## sets a ProgressBar fill + a numeric Label from it. The numeric readout is the
## load-bearing channel (colour is never the only channel — E2 readability rule).
##
## Visibility: shown ONLY when GameState.active_run_config.r3_enabled, so an all-off
## run's HUD equals M1.0 (the bar is hidden entirely with R3 off). Visibility is
## re-evaluated on every run boundary because active_run_config is bound at start_run
## and cleared at end_run (run-state). Mounted as a child of the E2 DecisionHUD.

@onready var _bar: ProgressBar = %ExposureBar
@onready var _label: Label = %ExposureLabel


func _ready() -> void:
	EventBus.exposure_meter_changed.connect(_on_meter_changed)
	# Re-evaluate visibility on run edges: the config is bound at start_run and cleared
	# at end_run, so we cannot decide once in _ready (no run is active at HUD load).
	EventBus.run_started.connect(_on_run_boundary)
	EventBus.run_ended.connect(_on_run_boundary)
	_refresh_visibility()


func _on_meter_changed(value: float, maximum: float) -> void:
	_bar.max_value = maximum
	_bar.value = value
	_label.text = tr("HUD_EXPOSURE_FMT").format({"value": int(value), "max": int(maximum)})


func _on_run_boundary(_a = null, _b = null, _c = null) -> void:
	# Variadic-tolerant: run_started(band, seed) / run_ended(reason, dur, depth).
	_refresh_visibility()


## R3 off (or no active config) → hidden, so the HUD equals M1.0. Read-only on the
## config; never mutate it.
func _refresh_visibility() -> void:
	var cfg: RunConfig = GameState.active_run_config
	visible = cfg != null and cfg.r3_enabled
