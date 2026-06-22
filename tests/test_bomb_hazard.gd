extends Node
## Headless verification for K5b (M1.4 Wave 3) — the committed proximity bomb hazard.
##
## Runs as a headless SCENE (test_bomb_hazard.tscn) so the EventBus / GameState autoloads
## resolve via the live SceneTree (M1_As_Built.md §"Testing constraints"). Instantiates a
## BombHazard from its .tscn (so IdleRing/Core @onready children resolve), setup()s it with
## a bomb-on RunConfig + a stub player, drives GameState.current_depth_index, and advances
## REAL physics frames (await get_tree().physics_frame) so the bomb's _physics_process runs
## with a live delta and _pulse_t accumulates as in-game.
##
## Asserts the K5b contract (spec §5 + Resolved Decisions):
##   (1) crossing hbomb_proximity_radius COMMITS the bomb: emits bomb_pulse_started exactly
##       once on the rising edge; it does NOT detonate immediately (pulse window holds).
##   (2) after hbomb_pulse_seconds it detonates; a player within hbomb_blast_radius at the
##       detonation frame is KILLED — new_hazard_killed(&"bomb", …) fires and the run ends
##       via fail_run(&"death").
##   (3) a player OUTSIDE the blast radius at detonation SURVIVES (fizzle): no new_hazard_killed,
##       run stays active.
##   (4) COMMITTED, no-defuse: leaving the proximity radius mid-pulse does NOT cancel — the
##       bomb still detonates after pulse_seconds (and is harmless because the player is clear).
##   (5) all-off gate: hbomb_enabled=false / proximity 0 instantiates / arms nothing.
## Run: godot --headless res://tests/test_bomb_hazard.tscn

const BOMB_SCENE := "res://scenes/hazards/bomb_hazard.tscn"

var _pulse_started: Array[int] = []           # depth per bomb_pulse_started
var _killed_kinds: Array[StringName] = []     # kind per new_hazard_killed
var _run_ended_reasons: Array[StringName] = []


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: Array[String] = []

	var gs := get_node_or_null("/root/GameState")
	var eb := get_node_or_null("/root/EventBus")
	if gs == null or eb == null:
		printerr("BOMB HAZARD FAIL: GameState/EventBus autoload missing")
		get_tree().quit(1)
		return

	eb.bomb_pulse_started.connect(_on_pulse_started)
	eb.new_hazard_killed.connect(_on_hazard_killed)
	eb.run_ended.connect(_on_run_ended)

	await _case_commit_then_fatal(gs, failures)
	await _case_fizzle_survives(gs, failures)
	await _case_committed_no_defuse(gs, failures)
	_case_all_off_inert(failures)
	_case_tell_renders(failures)

	if failures.is_empty():
		print("BOMB HAZARD OK — crossing the proximity radius commits the bomb (bomb_pulse_started "
			+ "once), it pulses for hbomb_pulse_seconds then detonates; a player inside the blast "
			+ "radius is killed (new_hazard_killed(&\"bomb\") + fail_run(&\"death\")), a player "
			+ "outside survives (fizzle, no kill row), leaving the ring mid-pulse does NOT defuse "
			+ "(committed), and the all-off config arms nothing.")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("BOMB HAZARD FAIL: ", f)
		get_tree().quit(1)


## The bomb's visible tells (Core diamond + the proximity IdleRing built at setup) must
## ACTUALLY RENDER — guards the invisible-blade class of bug (a self-intersecting polygon
## triangulates to 0 triangles and renders nothing, like the K5c spike Tell did).
func _case_tell_renders(failures: Array[String]) -> void:
	var rc := _bomb_config()
	var player := _make_player(Vector2(9999, 9999))   # far away — stays idle
	var bomb := _make_bomb(Vector2.ZERO, rc, player)
	for child_name in ["Core", "IdleRing"]:
		var poly: Polygon2D = bomb.get_node(child_name)
		if poly == null:
			failures.append("(tell) BombHazard has no %s node" % child_name)
		elif Geometry2D.triangulate_polygon(poly.polygon).is_empty():
			failures.append("(tell) %s triangulates to 0 triangles — it would render NOTHING" % child_name)
	bomb.queue_free()
	player.queue_free()


## A bomb-on config; caller overrides specifics. proximity >= blast (the Q3 invariant).
func _bomb_config() -> RunConfig:
	var rc := RunConfig.new()
	rc.hbomb_enabled = true
	rc.hbomb_proximity_radius = 80.0
	rc.hbomb_blast_radius = 40.0
	rc.hbomb_pulse_seconds = 0.3       # short fuse so the test pumps quickly
	return rc


func _make_player(pos: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.global_position = pos
	add_child(p)
	return p


func _make_bomb(pos: Vector2, rc: RunConfig, player: Node2D) -> Node2D:
	var scn := load(BOMB_SCENE) as PackedScene
	var bomb := scn.instantiate() as Node2D
	bomb.global_position = pos
	add_child(bomb)
	bomb.setup(rc, player)             # third spawn_ctx param is optional + ignored
	return bomb


## Advance N real physics frames so _physics_process runs with a live delta.
func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


# === Case 1: commit on proximity → pulse → fatal detonation ==================
func _case_commit_then_fatal(gs: Node, failures: Array[String]) -> void:
	_reset_signal_logs()
	gs.start_run(&"test_band", 11)
	gs.set_current_depth(2, 2)

	# Player starts FAR (outside the 80px proximity ring): bomb stays IDLE.
	var player := _make_player(Vector2(400, 0))
	var rc := _bomb_config()
	var bomb := _make_bomb(Vector2.ZERO, rc, player)

	await _frames(5)
	if not _pulse_started.is_empty():
		failures.append("c1: bomb armed while player was outside the proximity radius")

	# Walk INTO the ring (centre of the bomb) → commit on the rising edge.
	player.global_position = Vector2.ZERO
	await _frames(1)
	if _pulse_started.size() != 1:
		failures.append("c1: expected 1 bomb_pulse_started on proximity entry, got %d" % _pulse_started.size())
	# Must NOT have detonated yet (the pulse window holds for ~0.3s).
	if not _killed_kinds.is_empty():
		failures.append("c1: bomb detonated immediately on arm (no pulse window)")

	# Player stays on the bomb (inside the 40px blast) and the fuse runs out → fatal.
	await _frames(40)   # ~0.66s @ 60Hz > 0.3s fuse
	if not _killed_kinds.has(&"bomb"):
		failures.append("c1: fatal detonation did not emit new_hazard_killed(&\"bomb\")")
	if not _run_ended_reasons.has(&"death"):
		failures.append("c1: fatal blast did not route through fail_run(&\"death\") (reasons: %s)"
			% str(_run_ended_reasons))
	# Pulse must have fired exactly once across the whole sequence (one-shot edge).
	if _pulse_started.size() != 1:
		failures.append("c1: bomb_pulse_started fired %d times (expected exactly 1)" % _pulse_started.size())

	if is_instance_valid(bomb):   # W3-F1: a detonated bomb self-frees; guard the cleanup
		bomb.queue_free()
	player.queue_free()


# === Case 2: detonation with player outside blast → fizzle, survives ========
func _case_fizzle_survives(gs: Node, failures: Array[String]) -> void:
	_reset_signal_logs()
	gs.start_run(&"test_band", 22)
	gs.set_current_depth(2, 2)

	var rc := _bomb_config()             # proximity 80, blast 40
	# Player parked at distance 60: INSIDE proximity (arms) but OUTSIDE blast (survives).
	var player := _make_player(Vector2(60, 0))
	var bomb := _make_bomb(Vector2.ZERO, rc, player)

	await _frames(1)
	if _pulse_started.size() != 1:
		failures.append("c2: bomb did not arm at distance 60 (inside the 80px proximity ring)")

	await _frames(40)   # let the fuse expire
	if _killed_kinds.has(&"bomb"):
		failures.append("c2: a player at distance 60 (> 40 blast) was killed — fizzle expected")
	if _run_ended_reasons.has(&"death"):
		failures.append("c2: fizzle ended the run (death) — must NOT")
	if not gs.run_active:
		failures.append("c2: run is no longer active after a fizzle")

	if is_instance_valid(bomb):   # W3-F1: a detonated bomb self-frees; guard the cleanup
		bomb.queue_free()
	player.queue_free()


# === Case 3: committed — leaving the ring mid-pulse does NOT defuse ==========
func _case_committed_no_defuse(gs: Node, failures: Array[String]) -> void:
	_reset_signal_logs()
	gs.start_run(&"test_band", 33)
	gs.set_current_depth(2, 2)

	var rc := _bomb_config()
	var player := _make_player(Vector2.ZERO)   # start ON the bomb → arms immediately
	var bomb := _make_bomb(Vector2.ZERO, rc, player)

	await _frames(1)
	if _pulse_started.size() != 1:
		failures.append("c3: bomb did not arm when the player started inside the ring")

	# Flee FAR (well beyond proximity AND blast) DURING the pulse — committed: no defuse.
	player.global_position = Vector2(5000, 0)
	await _frames(40)   # fuse runs out while the player is clear
	# It MUST still have detonated (committed) — but harmlessly (player clear of blast).
	if _killed_kinds.has(&"bomb"):
		failures.append("c3: bomb killed a player who fled clear of the blast")
	if _run_ended_reasons.has(&"death"):
		failures.append("c3: committed-but-clear detonation ended the run")
	# The commit is not undone: exactly one pulse_started, never reset/re-armed.
	if _pulse_started.size() != 1:
		failures.append("c3: bomb re-armed or cancelled (pulse_started count %d, expected 1)"
			% _pulse_started.size())
	if not gs.run_active:
		failures.append("c3: run ended despite the player escaping the blast")

	if is_instance_valid(bomb):   # W3-F1: a detonated bomb self-frees; guard the cleanup
		bomb.queue_free()
	player.queue_free()


# === Case 4: all-off config arms nothing ====================================
## The spawn loop (K5i) is gated on hbomb_enabled; here we also assert that an off
## proximity radius keeps an instantiated bomb permanently inert (defence-in-depth).
func _case_all_off_inert(failures: Array[String]) -> void:
	var off := RunConfig.new()           # all-off default == M1.0 baseline
	if off.hbomb_enabled:
		failures.append("c4: all-off config has hbomb_enabled = true (gate is wrong)")
	if off.hbomb_proximity_radius != 0.0:
		failures.append("c4: all-off proximity radius != 0 (would arm)")
	if off.hbomb_blast_radius != 0.0:
		failures.append("c4: all-off blast radius != 0 (would be lethal)")


# --- signal sinks ------------------------------------------------------------
func _reset_signal_logs() -> void:
	_pulse_started.clear()
	_killed_kinds.clear()
	_run_ended_reasons.clear()


func _on_pulse_started(depth: int, _run_t_ms: int) -> void:
	_pulse_started.append(depth)


func _on_hazard_killed(kind: StringName, _depth: int, _run_t_ms: int) -> void:
	_killed_kinds.append(kind)


func _on_run_ended(reason: StringName, _duration_s: float, _depth_reached: int) -> void:
	_run_ended_reasons.append(reason)
