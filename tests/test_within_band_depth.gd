extends Node
## Headless verification for BUG2 (M1.1) — live within-band depth tracking.
##
## Runs as a headless SCENE (test_within_band_depth.tscn) so the EventBus /
## GameState autoloads resolve via the live SceneTree (M1_As_Built.md §"Testing
## constraints"; BUG2 §8). Drives GameState.set_current_depth() directly with a
## known {depth_index, dist_to_gate} sequence (the same call MainGame's driver
## makes after resolving the player's cell), so the test is pure integer logic
## with no scene geometry needed.
##
## Asserts:
##   1. current_depth_index / current_dist_to_gate track the driven values;
##   2. depth_changed fires EDGE-TRIGGERED — once per crossing into a new depth,
##      NOT on same-depth ticks;
##   3. max_depth_reached ratchets — retreating does not lower it;
##   4. run_ended.depth_reached == max_depth_reached for all three end-causes.
## Run: godot --headless res://tests/test_within_band_depth.tscn

var _depth_changes: Array[Vector2i] = []   # (depth_index, max_depth) per emit
var _last_run_ended_depth: int = -1
var _last_run_ended_reason: StringName = &""


func _ready() -> void:
	var failures: Array[String] = []

	var gs := get_node_or_null("/root/GameState")
	var eb := get_node_or_null("/root/EventBus")
	if gs == null or eb == null:
		printerr("WITHIN BAND DEPTH FAIL: GameState/EventBus autoload missing")
		get_tree().quit(1)
		return

	eb.depth_changed.connect(_on_depth_changed)
	eb.run_ended.connect(_on_run_ended)

	# === Case 1: tracking + edge-triggered emit + ratchet ====================
	_depth_changes.clear()
	gs.start_run(&"test_band", 111)

	if gs.current_depth_index != 0 or gs.max_depth_reached != 0 or gs.current_dist_to_gate != 0:
		failures.append("start_run did not reset depth members to 0 (idx=%d max=%d dist=%d)"
			% [gs.current_depth_index, gs.max_depth_reached, gs.current_dist_to_gate])

	# Sequence: 0 (entry, same as reset — no emit), 0 (same-piece tick — no emit),
	# 1, 2, 2 (same-piece — no emit), 1 (retreat — emits but does NOT lower max),
	# 3 (deeper — bumps max to 3).
	# On the linear spine dist_to_gate == depth_index; drive them equal here.
	gs.set_current_depth(0, 0)   # same as reset → no emit
	gs.set_current_depth(0, 0)   # same-piece tick → no emit
	gs.set_current_depth(1, 1)   # emit (0→1), max 1
	gs.set_current_depth(2, 2)   # emit (1→2), max 2
	gs.set_current_depth(2, 2)   # same-piece tick → no emit
	gs.set_current_depth(1, 1)   # emit (2→1) retreat, max STAYS 2
	gs.set_current_depth(3, 3)   # emit (1→3), max 3

	# Expect exactly 4 edge-triggered emits: 1, 2, 1, 3.
	var expected_emits: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(3, 3),
	]
	if _depth_changes != expected_emits:
		failures.append("depth_changed edges wrong: got %s expected %s"
			% [str(_depth_changes), str(expected_emits)])

	if gs.current_depth_index != 3:
		failures.append("current_depth_index=%d (expected 3)" % gs.current_depth_index)
	if gs.current_dist_to_gate != 3:
		failures.append("current_dist_to_gate=%d (expected 3)" % gs.current_dist_to_gate)
	if gs.max_depth_reached != 3:
		failures.append("max_depth_reached=%d (expected 3, ratchet)" % gs.max_depth_reached)

	# dist_to_gate must refresh even on a same-depth tick (R2/R4 read it live).
	gs.set_current_depth(3, 7)   # depth unchanged → no emit, but dist updates
	if gs.current_dist_to_gate != 7:
		failures.append("current_dist_to_gate did not refresh on same-depth tick (%d)"
			% gs.current_dist_to_gate)
	if _depth_changes.size() != 4:
		failures.append("same-depth tick emitted a spurious depth_changed (%d emits)"
			% _depth_changes.size())

	# === Cases 2-4: run_ended.depth_reached == max, all three end-causes =====
	_check_end_cause(gs, eb, &"extract", failures)
	_check_end_cause(gs, eb, &"death", failures)
	_check_end_cause(gs, eb, &"timeout", failures)

	if failures.is_empty():
		print("WITHIN BAND DEPTH OK — current_depth_index/max_depth_reached track, "
			+ "depth_changed is edge-triggered (4 emits, none on same-piece ticks), "
			+ "max ratchets on retreat, and run_ended.depth_reached == max for "
			+ "extract/death/timeout.")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("WITHIN BAND DEPTH FAIL: ", f)
		get_tree().quit(1)


## Push the player to depth 2 then to a deeper max of 5, retreat, and end via
## `cause`; run_ended.depth_reached must equal the ratcheted max (5), not the
## current depth at end time.
func _check_end_cause(gs: Node, eb: Node, cause: StringName, failures: Array[String]) -> void:
	_last_run_ended_depth = -1
	_last_run_ended_reason = &""
	gs.start_run(&"test_band", 222)
	gs.set_current_depth(2, 2)
	gs.set_current_depth(5, 5)   # deepest this run
	gs.set_current_depth(1, 1)   # retreat toward gate before ending
	match cause:
		&"extract":
			gs.extract_and_end_run()
		&"death":
			eb.player_died.emit(&"death")
		&"timeout":
			eb.dive_clock_timeout.emit()
	if _last_run_ended_reason != cause:
		failures.append("%s: run_ended reason was '%s'" % [cause, _last_run_ended_reason])
	if _last_run_ended_depth != 5:
		failures.append("%s: run_ended.depth_reached=%d (expected 5 = max, ratcheted)"
			% [cause, _last_run_ended_depth])


func _on_depth_changed(depth_index: int, max_depth: int) -> void:
	_depth_changes.append(Vector2i(depth_index, max_depth))


func _on_run_ended(reason: StringName, _duration_s: float, depth_reached: int) -> void:
	_last_run_ended_reason = reason
	_last_run_ended_depth = depth_reached
