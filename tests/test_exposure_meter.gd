extends Node
## Headless verification for R3 (M1.1 Wave 2) — the ExposureMeter + its penalty/HUD
## seams. Runs as a headless SCENE (test_exposure_meter.tscn) so the EventBus /
## GameState autoloads resolve via the live SceneTree (M1_As_Built.md §"Testing
## constraints"; mirrors test_within_band_depth / test_decision_hud).
##
## The meter's _process(delta) is called DIRECTLY with fixed deltas so the climb is
## deterministic (no reliance on real frame timing). A RunConfig is built in-code,
## staged, and adopted by start_run so r3_enabled etc. take effect.
##
## Asserts:
##   1. climbs faster at depth (depth term adds to base term, additively);
##   2. decays on retreat (live_depth < max_depth) when r3_decay_on_retreat > 0;
##   3. edge-triggered one-shot crossings emit exposure_crossed + exposure_penalty
##      (no re-arm after decay below a crossed level);
##   4. r3_max_forces_loss + meter >= MAX → GameState.fail_run(&"timeout");
##   5. speed mult emitted (1.0 at run start, < 1.0 after a speed crossing);
##   6. all-off (r3_enabled=false) → fully inert (no process, no meter signals).
## Optionally projects through the real HUD readout (EXPOSURE HUD OK).
## Run: godot --headless res://tests/test_exposure_meter.tscn

const HUD_SCENE := "res://ui/hud/decision_hud.tscn"

var _crossed: Array[Vector2i] = []         # (level, depth) per exposure_crossed
var _penalties: Array[Dictionary] = []     # {level, kind} per exposure_penalty
var _speed_mults: Array[float] = []        # every exposure_speed_mult_changed
var _meter_emits: int = 0
var _last_meter_value: float = -1.0
var _last_run_ended_reason: StringName = &""


func _ready() -> void:
	var failures: Array[String] = []

	var gs := get_node_or_null("/root/GameState")
	var eb := get_node_or_null("/root/EventBus")
	if gs == null or eb == null:
		printerr("EXPOSURE METER FAIL: GameState/EventBus autoload missing")
		get_tree().quit(1)
		return

	eb.exposure_crossed.connect(_on_exposure_crossed)
	eb.exposure_penalty.connect(_on_exposure_penalty)
	eb.exposure_speed_mult_changed.connect(_on_speed_mult)
	eb.exposure_meter_changed.connect(_on_meter_changed)
	eb.run_ended.connect(_on_run_ended)

	var meter := ExposureMeter.new()
	add_child(meter)   # _ready() connects its EventBus subscriptions

	# === Case 1: climbs faster at depth (additive base + per_depth*depth) =====
	# base 2.0/s, +1.0/s per depth, no thresholds, no decay, penalty=none.
	_reset_listeners()
	gs.stage_run_config(_cfg({
		"r3_enabled": true,
		"r3_base_climb_rate": 2.0,
		"r3_rate_per_depth": 1.0,
	}))
	gs.start_run(&"test_band", 111)
	if not is_equal_approx(meter.get_meter(), 0.0):
		failures.append("meter not reset to 0 at run start (%f)" % meter.get_meter())
	# At depth 0: climb = 2.0/s. 1s → 2.0.
	meter._process(1.0)
	var at_depth0: float = meter.get_meter()
	if not is_equal_approx(at_depth0, 2.0):
		failures.append("depth-0 climb wrong: meter=%f expected 2.0" % at_depth0)
	# Go to depth 3: climb = 2.0 + 1.0*3 = 5.0/s. 1s → +5.0.
	gs.set_current_depth(3, 3)
	meter._process(1.0)
	var delta_at_depth3: float = meter.get_meter() - at_depth0
	if not is_equal_approx(delta_at_depth3, 5.0):
		failures.append("depth-3 climb wrong: delta=%f expected 5.0 (faster than depth-0's 2.0)"
			% delta_at_depth3)
	if not (delta_at_depth3 > 2.0):
		failures.append("deeper did NOT climb faster (%f <= 2.0)" % delta_at_depth3)
	gs.end_run(&"abandon", 0.0)

	# === Case 2: decays on retreat (live_depth < max_depth) ==================
	_reset_listeners()
	gs.stage_run_config(_cfg({
		"r3_enabled": true,
		"r3_base_climb_rate": 5.0,
		"r3_decay_on_retreat": 10.0,
	}))
	gs.start_run(&"test_band", 222)
	gs.set_current_depth(4, 4)   # max becomes 4
	meter._process(2.0)          # climb 5/s * 2 = 10.0 (at depth 4, base only here)
	var peak: float = meter.get_meter()
	if not (peak > 0.0):
		failures.append("case2: meter did not climb at max depth (%f)" % peak)
	gs.set_current_depth(1, 4)   # retreat: live 1 < max 4 → decay
	meter._process(0.5)          # decay 10/s * 0.5 = 5.0
	var after_retreat: float = meter.get_meter()
	if not (after_retreat < peak):
		failures.append("case2: meter did not decay on retreat (peak=%f after=%f)"
			% [peak, after_retreat])
	if not is_equal_approx(after_retreat, peak - 5.0):
		failures.append("case2: decay magnitude wrong (peak=%f after=%f, expected -5.0)"
			% [peak, after_retreat])
	gs.end_run(&"abandon", 0.0)

	# === Case 3: edge-triggered one-shot crossings, speed penalty, no re-arm ==
	_reset_listeners()
	gs.stage_run_config(_cfg({
		"r3_enabled": true,
		"r3_base_climb_rate": 10.0,
		"r3_threshold_levels": PackedFloat32Array([20.0, 40.0]),
		"r3_penalty_kind": 1,            # speed
		"r3_penalty_magnitude": 0.2,
		"r3_decay_on_retreat": 100.0,
	}))
	gs.start_run(&"test_band", 333)
	# Speed mult must be neutral (1.0) at run start.
	if _speed_mults.is_empty() or not is_equal_approx(_speed_mults[0], 1.0):
		failures.append("case3: speed mult not 1.0 at run start (%s)" % str(_speed_mults))
	# Climb to 30 → crosses level 0 (20) only.
	meter._process(3.0)   # 10/s * 3 = 30.0
	if _crossed != [Vector2i(0, 0)]:
		failures.append("case3: expected one crossing of level 0, got %s" % str(_crossed))
	if _penalties.size() != 1 or _penalties[0]["level"] != 0 or _penalties[0]["kind"] != &"speed":
		failures.append("case3: penalty row wrong: %s" % str(_penalties))
	# After 1 speed crossing: mult = max(0.35, 1 - 0.2*1) = 0.8.
	var last_mult: float = _speed_mults[_speed_mults.size() - 1]
	if not is_equal_approx(last_mult, 0.8):
		failures.append("case3: speed mult after 1 crossing = %f (expected 0.8)" % last_mult)
	# Climb to 50 → crosses level 1 (40). Two total.
	meter._process(2.0)   # +20 → 50
	if _crossed != [Vector2i(0, 0), Vector2i(1, 0)]:
		failures.append("case3: expected crossings [0,1], got %s" % str(_crossed))
	# 2 speed crossings: mult = max(0.35, 1 - 0.2*2) = 0.6.
	last_mult = _speed_mults[_speed_mults.size() - 1]
	if not is_equal_approx(last_mult, 0.6):
		failures.append("case3: speed mult after 2 crossings = %f (expected 0.6)" % last_mult)
	# Now decay below level 1 (retreat) and re-climb: must NOT re-fire (one-shot, no re-arm).
	gs.set_current_depth(5, 5)
	gs.set_current_depth(2, 5)   # retreat: live 2 < max 5 → decay
	meter._process(0.2)          # decay 100/s*0.2 = 20 → 30 (below 40)
	gs.set_current_depth(5, 5)   # back to max → climb again
	meter._process(2.0)          # climb back over 40
	if _crossed.size() != 2:
		failures.append("case3: a crossed level RE-FIRED after decay/re-climb (got %d crossings)"
			% _crossed.size())
	gs.end_run(&"abandon", 0.0)

	# === Case 4: r3_max_forces_loss → fail_run(&"timeout") ===================
	_reset_listeners()
	gs.stage_run_config(_cfg({
		"r3_enabled": true,
		"r3_base_climb_rate": 1000.0,    # blow past MAX in one tick
		"r3_max_forces_loss": true,
	}))
	gs.start_run(&"test_band", 444)
	meter._process(1.0)   # meter clamps at 100 → forces loss
	if _last_run_ended_reason != &"timeout":
		failures.append("case4: max meter did not force a timeout run end (got '%s')"
			% _last_run_ended_reason)
	if meter.is_active():
		failures.append("case4: meter still active after forced loss")
	# run already ended by fail_run; no extra end_run needed.

	# === Case 5: all-off (r3_enabled=false) → fully inert ====================
	_reset_listeners()
	gs.stage_run_config(_cfg({"r3_enabled": false, "r3_base_climb_rate": 50.0}))
	gs.start_run(&"test_band", 555)
	if meter.is_active():
		failures.append("case5: meter active with r3_enabled=false")
	_meter_emits = 0
	meter._process(1.0)   # process guards on _active → no-op
	if not is_equal_approx(meter.get_meter(), 0.0):
		failures.append("case5: meter climbed while disabled (%f)" % meter.get_meter())
	if _meter_emits != 0:
		failures.append("case5: exposure_meter_changed emitted while disabled (%d)" % _meter_emits)
	if not _crossed.is_empty():
		failures.append("case5: crossings fired while disabled (%s)" % str(_crossed))
	gs.end_run(&"abandon", 0.0)

	meter.queue_free()

	if not failures.is_empty():
		for f in failures:
			printerr("EXPOSURE METER FAIL: ", f)
		get_tree().quit(1)
		return

	print("EXPOSURE METER OK — climbs faster at depth, decays on retreat, edge-triggered "
		+ "one-shot crossings emit crossed+penalty (no re-arm), max forces timeout loss, "
		+ "speed mult emitted, all-off inert.")

	# === Optional: HUD projection check ======================================
	_check_hud(gs, eb, failures)
	if failures.is_empty():
		print("EXPOSURE HUD OK — readout hidden with R3 off, visible + tracking the meter with R3 on.")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("EXPOSURE HUD FAIL: ", f)
		get_tree().quit(1)


func _check_hud(gs: Node, eb: Node, failures: Array[String]) -> void:
	var hud := (load(HUD_SCENE) as PackedScene).instantiate()
	add_child(hud)
	# _ready connects + reads active_run_config (none active now → hidden).
	var readout: Control = hud.get_node("Root/ExposureReadout")
	var bar: ProgressBar = readout.get_node("ExposureBar")
	var label: Label = readout.get_node("ExposureLabel")

	# R3 off → hidden.
	gs.stage_run_config(_cfg({"r3_enabled": false}))
	gs.start_run(&"test_band", 666)
	if readout.visible:
		failures.append("HUD readout visible with R3 off")
	gs.end_run(&"abandon", 0.0)

	# R3 on → visible and tracks exposure_meter_changed.
	gs.stage_run_config(_cfg({"r3_enabled": true}))
	gs.start_run(&"test_band", 777)
	if not readout.visible:
		failures.append("HUD readout hidden with R3 on")
	eb.exposure_meter_changed.emit(42.0, 100.0)
	if not is_equal_approx(bar.value, 42.0) or not is_equal_approx(bar.max_value, 100.0):
		failures.append("HUD bar did not mirror exposure_meter_changed(42,100): v=%s max=%s"
			% [bar.value, bar.max_value])
	var want := tr("HUD_EXPOSURE_FMT").format({"value": 42, "max": 100})
	if label.text != want:
		failures.append("HUD label '%s' != expected '%s'" % [label.text, want])
	gs.end_run(&"abandon", 0.0)
	hud.queue_free()


# --- Helpers -----------------------------------------------------------------

## Build a RunConfig with the given overrides applied over the all-off default.
func _cfg(overrides: Dictionary) -> RunConfig:
	var cfg := RunConfig.new()
	for key in overrides:
		cfg.set(key, overrides[key])
	return cfg


func _reset_listeners() -> void:
	_crossed.clear()
	_penalties.clear()
	_speed_mults.clear()
	_meter_emits = 0
	_last_meter_value = -1.0
	_last_run_ended_reason = &""


func _on_exposure_crossed(level: int, depth: int, _run_t_ms: int) -> void:
	_crossed.append(Vector2i(level, depth))


func _on_exposure_penalty(level: int, penalty_kind: StringName) -> void:
	_penalties.append({"level": level, "kind": penalty_kind})


func _on_speed_mult(mult: float) -> void:
	_speed_mults.append(mult)


func _on_meter_changed(value: float, _maximum: float) -> void:
	_meter_emits += 1
	_last_meter_value = value


func _on_run_ended(reason: StringName, _duration_s: float, _depth_reached: int) -> void:
	_last_run_ended_reason = reason
