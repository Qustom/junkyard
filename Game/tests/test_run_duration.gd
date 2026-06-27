extends Node
## Headless verification for BUG1 (M1.1) — real run_ended.duration_s.
##
## Runs as a headless SCENE (test_run_duration.tscn) so the EventBus / GameState
## autoloads resolve via the live SceneTree and we can await real wall time pass
## (M1_As_Built.md §"Testing constraints"; the duration test inherently needs a
## live tree, so the scene-host form is required — see BUG1 §6).
##
## Asserts, for each of the three end-causes (extract / death / timeout):
##   - run_ended fires with the triggered reason,
##   - duration_s > 0.0 (the bug was a hardcoded 0.0 on every path),
##   - duration_s matches a direct Time.get_ticks_msec() reference within a frame
##     (telemetry NOT forced on — the authoritative cross-check, BUG1 §8 Decision 3).
## Run: godot --headless res://tests/test_run_duration.tscn

const FRAME_TOLERANCE_S := 1.0 / 30.0   # one frame at the headless tick (BUG1 §6)
const WAIT_S := 0.2                       # comfortably above the frame tolerance

var _last_reason: StringName = &""
var _last_duration_s: float = -1.0
var _ended_count: int = 0


func _ready() -> void:
	var failures: Array[String] = []

	var gs := get_node_or_null("/root/GameState")
	var eb := get_node_or_null("/root/EventBus")
	if gs == null or eb == null:
		printerr("RUN DURATION FAIL: GameState/EventBus autoload missing")
		get_tree().quit(1)
		return

	eb.run_ended.connect(_on_run_ended)

	# --- Case: extract ------------------------------------------------------
	await _run_case(gs, eb, &"extract", failures)
	# --- Case: death (player_died → fail_run(&"death")) ---------------------
	await _run_case(gs, eb, &"death", failures)
	# --- Case: timeout (dive_clock_timeout → fail_run(&"timeout")) ----------
	await _run_case(gs, eb, &"timeout", failures)

	if failures.is_empty():
		print("RUN DURATION OK — duration_s is real (>0) and within a frame of the "
			+ "direct clock reference for extract / death / timeout (telemetry off).")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("RUN DURATION FAIL: ", f)
		get_tree().quit(1)


## Drive one end-cause: start a run, wait real time, trigger the cause, then assert
## the captured run_ended.duration_s against the test's own monotonic reference.
func _run_case(gs: Node, eb: Node, cause: StringName, failures: Array[String]) -> void:
	_last_reason = &""
	_last_duration_s = -1.0
	var ended_before := _ended_count

	var t0 := Time.get_ticks_msec()
	gs.start_run(&"test_band", 12345)

	await get_tree().create_timer(WAIT_S).timeout

	match cause:
		&"extract":
			gs.extract_and_end_run()
		&"death":
			eb.player_died.emit(&"death")
		&"timeout":
			eb.dive_clock_timeout.emit()

	var t1 := Time.get_ticks_msec()
	var expected_s := float(t1 - t0) / 1000.0

	if _ended_count != ended_before + 1:
		failures.append("%s: run_ended fired %d times (expected exactly 1)"
			% [cause, _ended_count - ended_before])
		return
	if _last_reason != cause:
		failures.append("%s: run_ended reason was '%s'" % [cause, _last_reason])
	if not (_last_duration_s > 0.0):
		failures.append("%s: duration_s not > 0 (%.6f) — the BUG1 regression"
			% [cause, _last_duration_s])
	if absf(_last_duration_s - expected_s) > FRAME_TOLERANCE_S:
		failures.append("%s: duration_s %.4f off reference %.4f by > one frame (%.4f)"
			% [cause, _last_duration_s, expected_s, FRAME_TOLERANCE_S])


func _on_run_ended(reason: StringName, duration_s: float, _depth_reached: int) -> void:
	_last_reason = reason
	_last_duration_s = duration_s
	_ended_count += 1
