extends Node
## I5 (M1.2) regression-lock — run_ended.duration_s stays REAL across LOOP RE-ENTRY.
##
## BUG1's test (test_run_duration.gd) covers a single run per cause. I5's added
## coverage is the LOOP-RESTART seam: the playtest zeros came from a binary where a
## re-entered run did not re-stamp _run_start_ms. This drives THREE sequential
## start_run() re-entries — the exact seam SellScreen.continue_pressed → start_new_run
## and Back-to-Config → Start exercise (each calls GameState.start_run, game_state.gd
## :103 audit) — and asserts each end emits a NONZERO, INDEPENDENT duration_s that
## matches that run's OWN measured wall interval (so a stale stamp inherited from a
## prior run is caught, not just a hardcoded 0.0).
##
## Runs as a headless SCENE (test_duration_loop_reentry.tscn) so the EventBus /
## GameState autoloads resolve via the live SceneTree and real wall time can pass
## (M1_As_Built.md §"Testing constraints"; a duration test inherently needs a live
## tree). Telemetry is left OFF — the duration must be self-contained on the
## run_ended signal (BUG1 §8 Decision 3). Exits non-zero on any failure so red CI
## blocks merge.
## Run: godot --headless res://tests/test_duration_loop_reentry.tscn

const FRAME_TOLERANCE_S := 1.0 / 15.0   # generous band vs each run's OWN reference (headless timers jitter)
const WAIT_S := 0.2                       # provably-nonzero interval, well above tolerance

# Captured run_ended payloads, one per re-entry: [reason, duration_s, depth].
var _captured: Array = []
# Per-run wall-clock reference span (t1 - t0), one per re-entry, in seconds. The run's
# duration_s must match its OWN reference — robust to headless timer jitter, and a stale
# stamp inherited from a prior run would diverge from this run's reference.
var _ref_spans: Array = []


func _ready() -> void:
	var failures: Array[String] = []

	var gs := get_node_or_null("/root/GameState")
	var eb := get_node_or_null("/root/EventBus")
	if gs == null or eb == null:
		printerr("DURATION LOOP FAIL: GameState/EventBus autoload missing")
		get_tree().quit(1)
		return

	eb.run_ended.connect(_on_run_ended)

	# --- Run 1: start, wait a real interval, EXTRACT ------------------------
	await _drive(gs, &"extract", 111, eb)
	# --- Run 2: RE-ENTER the loop (the Continue-restart seam), end via TIMEOUT.
	#     A SECOND start_run MUST re-stamp _run_start_ms, so run 2's duration is its
	#     OWN elapsed — not stale from run 1, not zero (the missed-stamp regression).
	await _drive(gs, &"timeout", 222, eb)
	# --- Run 3: re-enter AGAIN, end via DEATH (third cause across re-entry) --
	await _drive(gs, &"death", 333, eb)

	# --- Assert: all three ends have a real, independent, nonzero duration --
	if _captured.size() != 3:
		failures.append("expected exactly 3 run_ended across the loop re-entries, got %d"
			% _captured.size())
	else:
		for i in 3:
			var dur: float = _captured[i][1]
			var ref: float = _ref_spans[i]
			# Hard gate: a missed/stale stamp shows up as 0.0 (the playtest regression).
			if not (dur > 0.0):
				failures.append("run %d (%s): duration_s not > 0 (%.6f) — the missed-stamp regression"
					% [i, _captured[i][0], dur])
			# Independence: each run's duration must match ITS OWN measured wall span,
			# not a prior run's. A stale stamp would diverge from this reference.
			elif absf(dur - ref) > FRAME_TOLERANCE_S:
				failures.append("run %d (%s): duration_s %.4f off its own reference %.4f by > one frame (%.4f) — re-entry did not re-stamp"
					% [i, _captured[i][0], dur, ref, FRAME_TOLERANCE_S])
		# Causes must survive the re-entries in order: extract → timeout → death.
		var causes := [_captured[0][0], _captured[1][0], _captured[2][0]]
		if causes != [&"extract", &"timeout", &"death"]:
			failures.append("end causes out of order across re-entry: %s" % [causes])

	if failures.is_empty():
		print("DURATION LOOP OK — duration_s is real (>0), independent (matches each "
			+ "run's own wall span), and re-stamped on every loop re-entry across "
			+ "extract / timeout / death (telemetry off).")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("DURATION LOOP FAIL: ", f)
		get_tree().quit(1)


## Drive one re-entry: start a fresh run, wait real time, trigger one end cause, and
## record the run's OWN wall-clock reference span for the per-run assertion.
func _drive(gs: Node, cause: StringName, seed: int, eb: Node) -> void:
	var t0 := Time.get_ticks_msec()
	gs.start_run(&"test_band", seed)
	await get_tree().create_timer(WAIT_S).timeout
	match cause:
		&"extract":
			gs.extract_and_end_run()
		&"timeout":
			eb.dive_clock_timeout.emit()
		&"death":
			eb.player_died.emit(&"death")
	var t1 := Time.get_ticks_msec()
	_ref_spans.append(float(t1 - t0) / 1000.0)


func _on_run_ended(reason: StringName, duration_s: float, depth_reached: int) -> void:
	_captured.append([reason, duration_s, depth_reached])
