extends Node
## Headless verification for R2 (M1.1) — ReturnCost costlier-return-trip toll.
##
## Runs as a headless SCENE (test_return_cost.tscn) so the EventBus / GameState
## autoloads resolve via the live SceneTree (M1_As_Built.md §"Testing constraints").
## ReturnCost + a DiveClock are added as real children so their _ready() wires the
## EventBus listeners exactly as the live dive scene would; the test injects the
## clock into ReturnCost the way RG1 will.
##
## A retreat is simulated the same way MainGame's driver drives BUG2: stage a
## RunConfig, start_run, then call GameState.set_current_depth(idx, dist_to_gate)
## with a {depth_index, dist_to_gate} sequence. Decreasing dist_to_gate == retreat;
## ReturnCost reads GameState.current_dist_to_gate live off depth_changed.
##
## Asserts:
##   1. all-off (r2_enabled=false): no return_cost_incurred rows, no clock drain;
##   2. egress_toll/clock: retreating from deep d costs MORE than from d=1;
##   3. threshold honored: no charge while dist_to_gate <= threshold;
##   4. return_cost_incurred fires with cost_kind=&"clock" and the right magnitude;
##   5. the clock actually drains by the charged amount;
##   6. mag charged once, per charged each taxed hop (marginal-per-hop, §9 D6).
## Run: godot --headless res://tests/test_return_cost.tscn

const RETURN_COST_PATH := "res://systems/oppositions/return_cost.gd"
const DIVE_CLOCK_PATH := "res://systems/dive_clock.gd"
const DIVE_CLOCK_CONFIG_PATH := "res://data/dive/dive_clock_config.gd"
const RUN_CONFIG_PATH := "res://data/run_config/run_config.gd"

# RunConfig enum int values (RunConfig uses plain @export_enum ints).
const MECH_EGRESS_TOLL := 2
const TOLL_CLOCK := 0
const TOLL_METER := 2

var _cost_rows: Array = []   # [depth:int, kind:StringName, magnitude:float] per emit

var _gs: Node
var _eb: Node


func _ready() -> void:
	var failures: Array[String] = []

	_gs = get_node_or_null("/root/GameState")
	_eb = get_node_or_null("/root/EventBus")
	if _gs == null or _eb == null:
		printerr("RETURN COST FAIL: GameState/EventBus autoload missing")
		get_tree().quit(1)
		return

	_eb.return_cost_incurred.connect(_on_cost)

	# Build a DiveClock with NO passive drain (drain_per_second = 0) and a big
	# budget, so the ONLY light change is R2's toll — isolating the cost engine.
	var config_script: Variant = load(DIVE_CLOCK_CONFIG_PATH)
	var config: Variant = config_script.new()
	config.max_light = 1000.0
	config.start_light = 1000.0
	config.drain_per_second = 0.0

	var clock_script: Variant = load(DIVE_CLOCK_PATH)
	var clock: Variant = clock_script.new()
	clock.config = config
	add_child(clock)   # _ready() wires its EventBus listeners

	var rc_script: Variant = load(RETURN_COST_PATH)
	var rc: Variant = rc_script.new()
	rc.dive_clock = clock   # injection RG1 will do
	add_child(rc)      # _ready() wires depth_changed/run_started/run_ended

	# === Case 1: all-off (r2_enabled = false) → free walk-back =================
	_cost_rows.clear()
	var off_cfg: Variant = _make_cfg(false, MECH_EGRESS_TOLL, TOLL_CLOCK, 2.0, 1.5, 1)
	_gs.stage_run_config(off_cfg)
	_gs.start_run(&"test_band", 111)
	var light_after_start: float = clock.get_light()
	# Descend deep, then retreat all the way home.
	_drive_descend_then_retreat(8)
	if not _cost_rows.is_empty():
		failures.append("all-off produced %d return_cost_incurred rows (expected 0)" % _cost_rows.size())
	if not is_equal_approx(clock.get_light(), light_after_start):
		failures.append("all-off drained the clock (%.2f -> %.2f)" % [light_after_start, clock.get_light()])
	_gs.end_run(&"extract", 0.0)

	# === Case 2: egress_toll/clock — deep retreat costs MORE than shallow ======
	# Config: mag=2.0, per=1.5, threshold=1. Descend to d=8, retreat to gate.
	# Marginal-per-hop: total = mag (once) + per * (hops above threshold).
	# Retreat 8->0 taxes hops departing from d=8..2 (d>1): 7 taxed hops.
	#   expected total = 2.0 + 1.5*7 = 12.5
	_cost_rows.clear()
	var deep_cfg: Variant = _make_cfg(true, MECH_EGRESS_TOLL, TOLL_CLOCK, 2.0, 1.5, 1)
	_gs.stage_run_config(deep_cfg)
	_gs.start_run(&"test_band", 222)
	var light_before_deep: float = clock.get_light()
	_drive_descend_then_retreat(8)
	var deep_total_charged: float = light_before_deep - clock.get_light()
	var deep_rows_sum: float = _sum_rows()
	if _cost_rows.is_empty():
		failures.append("deep egress_toll produced NO return_cost_incurred rows")
	if not _is_approx(deep_total_charged, 12.5):
		failures.append("deep retreat charged %.3f light, expected 12.5" % deep_total_charged)
	if not _is_approx(deep_rows_sum, 12.5):
		failures.append("deep return_cost_incurred magnitudes sum to %.3f, expected 12.5" % deep_rows_sum)
	for row in _cost_rows:
		if row[1] != &"clock":
			failures.append("deep row cost_kind = %s, expected &\"clock\"" % row[1])
			break
	_gs.end_run(&"extract", 0.0)

	# Shallow retreat: descend only to d=1, retreat to 0. Threshold=1 means the
	# single hop departs from d=1 (NOT > thr) → 0 taxed hops → 0 cost.
	_cost_rows.clear()
	var shallow_cfg: Variant = _make_cfg(true, MECH_EGRESS_TOLL, TOLL_CLOCK, 2.0, 1.5, 1)
	_gs.stage_run_config(shallow_cfg)
	_gs.start_run(&"test_band", 333)
	var light_before_shallow: float = clock.get_light()
	_drive_descend_then_retreat(1)
	var shallow_total_charged: float = light_before_shallow - clock.get_light()
	if not is_equal_approx(shallow_total_charged, 0.0):
		failures.append("shallow retreat (d=1, thr=1) charged %.3f, expected 0 (threshold)" % shallow_total_charged)
	if not _cost_rows.is_empty():
		failures.append("shallow retreat at threshold produced %d rows (expected 0)" % _cost_rows.size())
	_gs.end_run(&"extract", 0.0)

	if not (deep_total_charged > shallow_total_charged):
		failures.append("deep retreat (%.2f) did not cost MORE than shallow (%.2f)"
			% [deep_total_charged, shallow_total_charged])

	# === Case 3: threshold > deepest → wholly free =============================
	# threshold=10, deepest d=8 → every hop departs from d<=8 <= thr → no charge.
	_cost_rows.clear()
	var high_thr_cfg: Variant = _make_cfg(true, MECH_EGRESS_TOLL, TOLL_CLOCK, 2.0, 1.5, 10)
	_gs.stage_run_config(high_thr_cfg)
	_gs.start_run(&"test_band", 444)
	var light_before_hi: float = clock.get_light()
	_drive_descend_then_retreat(8)
	if not is_equal_approx(clock.get_light(), light_before_hi):
		failures.append("high threshold (10 > maxdepth 8) still charged (%.2f -> %.2f)"
			% [light_before_hi, clock.get_light()])
	if not _cost_rows.is_empty():
		failures.append("high threshold produced %d rows (expected 0)" % _cost_rows.size())
	_gs.end_run(&"extract", 0.0)

	# === Case 4: meter toll — fills R2's own meter, emits &"meter" =============
	_cost_rows.clear()
	var meter_cfg: Variant = _make_cfg(true, MECH_EGRESS_TOLL, TOLL_METER, 2.0, 1.5, 1)
	_gs.stage_run_config(meter_cfg)
	_gs.start_run(&"test_band", 555)
	_drive_descend_then_retreat(8)
	if not _is_approx(rc.get_meter(), 12.5):
		failures.append("meter toll filled %.3f, expected 12.5" % rc.get_meter())
	var meter_kind_ok := true
	for row in _cost_rows:
		if row[1] != &"meter":
			meter_kind_ok = false
			break
	if not meter_kind_ok:
		failures.append("meter toll emitted a non-meter cost_kind")
	if _cost_rows.is_empty():
		failures.append("meter toll produced no rows")
	_gs.end_run(&"extract", 0.0)

	rc.queue_free()
	clock.queue_free()

	if failures.is_empty():
		print("RETURN COST OK — deep retreat costs more than shallow, threshold honored, ",
			"return_cost_incurred fires with right kind+magnitude, clock drains, off-config free")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("RETURN COST FAIL: ", f)
		get_tree().quit(1)


## Drive a descend (dist_to_gate 0..max) then a full retreat (max..0), simulating
## MainGame's BUG2 driver. On the linear spine depth_index == dist_to_gate, so we
## pass them equal. Descending does NOT charge (d increasing); only the retreat does.
func _drive_descend_then_retreat(max_d: int) -> void:
	for i in range(1, max_d + 1):
		_gs.set_current_depth(i, i)       # deeper: dist_to_gate increases
	for i in range(max_d - 1, -1, -1):
		_gs.set_current_depth(i, i)       # retreat: dist_to_gate decreases → charges


func _make_cfg(enabled: bool, mech: int, toll: int, mag: float, per: float, thr: int) -> Variant:
	var cfg: Variant = load(RUN_CONFIG_PATH).new()
	cfg.r2_enabled = enabled
	cfg.r2_mechanism = mech
	cfg.r2_toll_resource = toll
	cfg.r2_cost_magnitude = mag
	cfg.r2_cost_per_depth = per
	cfg.r2_depth_threshold = thr
	return cfg


func _sum_rows() -> float:
	var total: float = 0.0
	for row in _cost_rows:
		total += float(row[2])
	return total


func _is_approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _on_cost(depth: int, kind: StringName, magnitude: float) -> void:
	_cost_rows.append([depth, kind, magnitude])
