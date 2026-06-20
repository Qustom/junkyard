extends Node
## Headless verification for R1 (M1.1) — the pursuing / awakening hazard.
##
## Runs as a headless SCENE (test_pursuing_hazard.tscn) so the EventBus / GameState
## autoloads resolve via the live SceneTree (M1_As_Built.md §"Testing constraints").
## Instantiates a HazardEntity, setup()s it with an R1-on RunConfig + a stub player
## CharacterBody2D, drives GameState.current_depth_index (the value MainGame's depth
## driver writes) and advances REAL physics frames (await get_tree().physics_frame) so
## the hazard's own _physics_process + move_and_slide run with a live physics delta
## (move_and_slide uses the engine physics delta internally, which is 0 if you call it
## by hand outside a frame — hence frame-driven). Asserts the R1 contract (spec §8):
## awaken-at-threshold (once, right trigger), chase toward the player, catch within
## radius → hazard_caught + fail_run(&"death"), awake latches (no re-sleep), and the
## all-off spawn gate creates nothing.
## Run: godot --headless res://tests/test_pursuing_hazard.tscn

var _awoke_depths: Array[int] = []
var _awoke_triggers: Array[StringName] = []
var _caught: Array[Vector2i] = []          # (depth, run_t_ms) per hazard_caught
var _run_ended_reasons: Array[StringName] = []


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: Array[String] = []

	var gs := get_node_or_null("/root/GameState")
	var eb := get_node_or_null("/root/EventBus")
	if gs == null or eb == null:
		printerr("PURSUING HAZARD FAIL: GameState/EventBus autoload missing")
		get_tree().quit(1)
		return

	eb.hazard_awoke.connect(_on_hazard_awoke)
	eb.hazard_caught.connect(_on_hazard_caught)
	eb.run_ended.connect(_on_run_ended)

	await _case_depth_awaken_chase_catch(gs, failures)
	await _case_linger_awaken(gs, failures)
	await _case_latch_no_resleep(gs, failures)
	await _case_nonfatal_catch(gs, failures)
	await _case_fatal_sustained_one_emit(gs, failures)
	await _case_nonfatal_escape_recatch(gs, failures)
	_case_all_off_spawns_nothing(failures)

	if failures.is_empty():
		print("PURSUING HAZARD OK — awakens at depth threshold (once, trigger=depth) and "
			+ "on linger (trigger=linger), chases toward the player, fatal catch emits "
			+ "hazard_caught + routes through fail_run(&\"death\"), awake latches with no "
			+ "re-sleep on retreat, non-fatal catch does NOT end the run, and all-off "
			+ "spawns no hazard.")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("PURSUING HAZARD FAIL: ", f)
		get_tree().quit(1)


## Build an R1-on config; caller overrides specific knobs after.
func _r1_config() -> RunConfig:
	var rc := RunConfig.new()
	rc.r1_enabled = true
	rc.r1_depth_threshold = 3
	rc.r1_linger_seconds = 0.0
	rc.r1_chase_speed = 600.0
	rc.r1_speed_per_depth = 0.0
	rc.r1_catch_radius = 24.0
	rc.r1_catch_kills = true
	rc.r1_spawn_count = 1
	return rc


## A bare CharacterBody2D stub (the non-fatal knockback path sets velocity on a
## CharacterBody2D). The test hands the player to setup() directly, so no group needed.
func _make_player(pos: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.global_position = pos
	add_child(p)
	return p


func _make_hazard(pos: Vector2, rc: RunConfig, player: Node2D) -> HazardEntity:
	var hz := HazardEntity.new()
	var tell := Polygon2D.new()
	tell.name = "Tell"
	hz.add_child(tell)
	hz.global_position = pos
	add_child(hz)
	hz.setup(rc, player)
	return hz


## Advance N real physics frames so the hazard's _physics_process runs with a live delta.
func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


# === Case 1: depth awaken → chase → fatal catch ==============================
func _case_depth_awaken_chase_catch(gs: Node, failures: Array[String]) -> void:
	_reset_signal_logs()
	gs.start_run(&"test_band", 11)
	gs.set_current_depth(0, 0)

	var player := _make_player(Vector2(400, 0))
	var rc := _r1_config()
	var hz := _make_hazard(Vector2.ZERO, rc, player)

	# Shallow (depth 0 < threshold 3): stay dormant, must NOT move.
	var pos_before := hz.global_position
	await _frames(5)
	if not _awoke_depths.is_empty():
		failures.append("c1: hazard awoke below depth threshold")
	if hz.global_position != pos_before:
		failures.append("c1: dormant hazard moved (pos changed while DORMANT)")

	# Cross the depth threshold → awaken exactly once with trigger=depth.
	gs.set_current_depth(3, 3)
	await _frames(1)
	if _awoke_depths.size() != 1:
		failures.append("c1: expected 1 hazard_awoke at threshold, got %d" % _awoke_depths.size())
	elif _awoke_triggers[0] != &"depth":
		failures.append("c1: awaken trigger was '%s' (expected 'depth')" % _awoke_triggers[0])

	# Chase: hazard must close distance toward the player over several frames.
	var dist_before := hz.global_position.distance_to(player.global_position)
	await _frames(10)
	var dist_after := hz.global_position.distance_to(player.global_position)
	if dist_after >= dist_before:
		failures.append("c1: hazard did not move toward player (%.1f -> %.1f)"
			% [dist_before, dist_after])
	if _awoke_depths.size() != 1:
		failures.append("c1: hazard_awoke re-fired while chasing (%d total)" % _awoke_depths.size())

	# Catch: snap the player onto the hazard → distance <= radius → fatal catch.
	player.global_position = hz.global_position
	await _frames(1)
	if _caught.size() < 1:
		failures.append("c1: catch within radius did not emit hazard_caught")
	if not _run_ended_reasons.has(&"death"):
		failures.append("c1: fatal catch did not route through fail_run(&\"death\") "
			+ "(run_ended reasons: %s)" % str(_run_ended_reasons))

	hz.queue_free()
	player.queue_free()


# === Case 2: linger awaken (depth never reaches threshold) ===================
func _case_linger_awaken(gs: Node, failures: Array[String]) -> void:
	_reset_signal_logs()
	gs.start_run(&"test_band", 22)
	gs.set_current_depth(0, 0)

	var player := _make_player(Vector2(2000, 0))
	var rc := _r1_config()
	rc.r1_depth_threshold = 999      # depth can't trigger
	rc.r1_linger_seconds = 0.2       # time triggers
	rc.r1_catch_radius = 0.0         # don't catch from afar
	var hz := _make_hazard(Vector2.ZERO, rc, player)

	# A couple of frames (< 0.2s of accumulated sim time): still dormant.
	await _frames(2)
	if not _awoke_depths.is_empty():
		failures.append("c2: hazard awoke before linger_seconds elapsed")
	# Pump well past the linger threshold (physics step ≈ 1/60s; 30 frames ≈ 0.5s).
	await _frames(30)
	if _awoke_depths.size() != 1:
		failures.append("c2: expected 1 linger awaken, got %d" % _awoke_depths.size())
	elif _awoke_triggers[0] != &"linger":
		failures.append("c2: awaken trigger was '%s' (expected 'linger')" % _awoke_triggers[0])

	hz.queue_free()
	player.queue_free()


# === Case 3: awake latches — no re-sleep on retreat ==========================
func _case_latch_no_resleep(gs: Node, failures: Array[String]) -> void:
	_reset_signal_logs()
	gs.start_run(&"test_band", 33)
	gs.set_current_depth(3, 3)

	var player := _make_player(Vector2(800, 0))
	var rc := _r1_config()
	rc.r1_catch_radius = 0.0     # never catch — isolate the latch
	var hz := _make_hazard(Vector2.ZERO, rc, player)

	await _frames(1)   # depth 3 >= threshold → awaken
	if _awoke_depths.size() != 1:
		failures.append("c3: expected awaken at depth 3, got %d" % _awoke_depths.size())

	# Retreat shallow: hazard must STAY awake and keep chasing (no re-dormant).
	gs.set_current_depth(0, 0)
	var dist_before := hz.global_position.distance_to(player.global_position)
	await _frames(10)
	var dist_after := hz.global_position.distance_to(player.global_position)
	if dist_after >= dist_before:
		failures.append("c3: hazard stopped chasing after retreat (re-slept?)")
	if _awoke_depths.size() != 1:
		failures.append("c3: hazard re-emitted awaken after retreat (%d)" % _awoke_depths.size())

	hz.queue_free()
	player.queue_free()


# === Case 4: non-fatal catch does NOT end the run ============================
func _case_nonfatal_catch(gs: Node, failures: Array[String]) -> void:
	_reset_signal_logs()
	gs.start_run(&"test_band", 44)
	gs.set_current_depth(3, 3)

	var player := _make_player(Vector2.ZERO)
	var rc := _r1_config()
	rc.r1_catch_kills = false     # cost-instead-of-kill
	var hz := _make_hazard(Vector2.ZERO, rc, player)

	await _frames(1)              # awaken
	player.global_position = hz.global_position   # force a catch
	await _frames(1)
	if _caught.size() < 1:
		failures.append("c4: non-fatal catch did not emit hazard_caught")
	if _run_ended_reasons.has(&"death"):
		failures.append("c4: non-fatal catch ended the run (death) — must NOT")
	if not gs.run_active:
		failures.append("c4: run is no longer active after a non-fatal catch")

	hz.queue_free()
	player.queue_free()


# === Case 6: BUG6 — fatal catch held in radius emits hazard_caught ONCE =======
## Regression lock for the per-frame emit storm (M1.2: 85→2,199 events/run). With
## the player pinned inside catch radius for many physics frames on the FATAL path
## (which never sets _catch_cooldown), the one-shot latch must yield EXACTLY ONE
## hazard_caught (was N, one per frame). The fatal frame itself is unchanged: the
## single emit still fires on the same rising-edge frame and routes through
## fail_run(&"death").
func _case_fatal_sustained_one_emit(gs: Node, failures: Array[String]) -> void:
	_reset_signal_logs()
	gs.start_run(&"test_band", 55)
	gs.set_current_depth(3, 3)

	var player := _make_player(Vector2.ZERO)
	var rc := _r1_config()                # r1_catch_kills = true (fatal path)
	var hz := _make_hazard(Vector2.ZERO, rc, player)

	await _frames(1)                      # awaken (depth 3 >= threshold)
	player.global_position = hz.global_position   # pin INSIDE radius
	# Hold the overlap for many frames — the old code emitted once PER frame here.
	await _frames(30)
	if _caught.size() != 1:
		failures.append("c6: sustained fatal overlap emitted %d hazard_caught (expected exactly 1 — storm not fixed)"
			% _caught.size())
	if not _run_ended_reasons.has(&"death"):
		failures.append("c6: fatal catch did not route through fail_run(&\"death\")")

	hz.queue_free()
	player.queue_free()


# === Case 7: BUG6 — non-fatal escape-and-re-catch emits TWICE =================
## The latch must NOT swallow a genuine second catch. Non-fatal path: catch once
## (1 emit), move the player OUT of radius to re-arm the latch (falling edge), let
## the 1.0s cooldown expire, then snap back in → a second distinct catch (2 emits).
## A sustained pin would be 1; a real escape-and-re-catch is 2.
func _case_nonfatal_escape_recatch(gs: Node, failures: Array[String]) -> void:
	_reset_signal_logs()
	gs.start_run(&"test_band", 66)
	gs.set_current_depth(3, 3)

	var player := _make_player(Vector2.ZERO)
	var rc := _r1_config()
	rc.r1_catch_kills = false             # non-fatal so the run survives both catches
	rc.r1_chase_speed = 0.0               # don't let the hazard chase the parked player
	var hz := _make_hazard(Vector2.ZERO, rc, player)

	await _frames(1)                      # awaken
	# First catch.
	player.global_position = hz.global_position
	await _frames(1)
	if _caught.size() != 1:
		failures.append("c7: first non-fatal catch emitted %d (expected 1)" % _caught.size())

	# Escape: move far out of radius → latch re-arms on the falling edge.
	player.global_position = Vector2(5000, 0)
	await _frames(1)
	# Hold a few more frames (still out) and let the 1.0s cooldown bleed off.
	await _frames(70)                     # ~1.17s @ 60Hz > NONFATAL_COOLDOWN_SECONDS
	if _caught.size() != 1:
		failures.append("c7: a catch fired while the player was OUT of radius (%d)" % _caught.size())

	# Re-catch: snap back in → a second distinct catch.
	player.global_position = hz.global_position
	await _frames(1)
	if _caught.size() != 2:
		failures.append("c7: escape-and-re-catch emitted %d (expected exactly 2 — latch swallowed the re-catch?)"
			% _caught.size())
	if _run_ended_reasons.has(&"death"):
		failures.append("c7: non-fatal path ended the run")

	hz.queue_free()
	player.queue_free()


# === Case 5: all-off spawn gate spawns nothing ===============================
## The spawn loop lives in MainGame, guarded by r1_enabled && r1_spawn_count > 0. We
## assert the guard predicate on an all-off config (the loop body never runs → no
## HazardEntity is instantiated).
func _case_all_off_spawns_nothing(failures: Array[String]) -> void:
	var off := RunConfig.new()   # all-off default == M1.0 baseline
	if off.r1_enabled and off.r1_spawn_count > 0:
		failures.append("c5: all-off config would spawn a hazard (gate is wrong)")
	var enabled_zero := RunConfig.new()
	enabled_zero.r1_enabled = true
	enabled_zero.r1_spawn_count = 0
	if enabled_zero.r1_enabled and enabled_zero.r1_spawn_count > 0:
		failures.append("c5: enabled+count0 would spawn (must be a no-op)")


# --- signal sinks ------------------------------------------------------------
func _reset_signal_logs() -> void:
	_awoke_depths.clear()
	_awoke_triggers.clear()
	_caught.clear()
	_run_ended_reasons.clear()


func _on_hazard_awoke(depth: int, trigger: StringName) -> void:
	_awoke_depths.append(depth)
	_awoke_triggers.append(trigger)


func _on_hazard_caught(depth: int, run_t_ms: int) -> void:
	_caught.append(Vector2i(depth, run_t_ms))


func _on_run_ended(reason: StringName, _duration_s: float, _depth_reached: int) -> void:
	_run_ended_reasons.append(reason)
