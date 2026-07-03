extends Node
## S2 (M1.9) — golden frame-trace parity harness for the opposition component
## extraction (S2 spec §2.3 + Resolved Decisions "Golden frame-trace parity harness").
##
## THE ONLY ORACLE FOR RISKS 1–3 (frame-order drift / latch divergence / float-path
## drift): the fp check never sees entities, and the semantic hazard tests assert key
## frames, not the trajectory between them. This harness drives each of the four
## shipped hazard entities for N physics frames under a FIXED config + a SCRIPTED
## player-position sequence + a fixed delta, recording per frame:
##   global_position (full precision, var_to_str) · velocity (CharacterBody2D hosts) ·
##   the host FSM state (`_state`, when the host has one) · rotation · the LEGACY
##   emit log (hazard_awoke / hazard_caught / new_hazard_killed / bomb_pulse_started /
##   hazard_pursuer_state, with full args).
##
## WORKFLOW (binding, per the S2 Resolved Decisions): the goldens under
## res://tests/goldens/ were CAPTURED FROM THE PRE-REFACTOR SCRIPTS (the harness'
## first commit proves itself green on the old code); the refactor commits must keep
## every trace byte-identical. If a trace cannot match exactly, that is a DEVIATION
## TO SURFACE to the Director — never a tolerance to widen.
##
## Capture mode: run with the environment variable S2_TRACE_CAPTURE=1 to (re)write
## the goldens. Normal runs compare and fail loud on the first mismatching frame.
##
## Determinism notes (scope guards from the Resolved Decisions):
##   - NO walls in the trace scene — move_and_slide contact math stays trivial;
##     the pingpong trace bounces via its room-rect clamp instead.
##   - Entities have their engine physics callback DISABLED and are ticked MANUALLY
##     by this node's _physics_process (so we are inside a real physics frame —
##     move_and_slide uses the fixed physics delta — but the call order and the
##     per-frame player scripting are exactly controlled).
##   - Only logic state is traced, never tween-animated presentation (scale/color/
##     modulate are juice by contract).
##   - The bomb trace ends 5 frames after its detonation so the wall-clock 0.2 s
##     free timer can never fire inside the traced window.
##   - *_kills is false in every trace (no fail_run — the L5 gate itself is covered
##     by the semantic hazard tests).

const FIXED_DELTA := 1.0 / 60.0
const GOLDEN_DIR := "res://tests/goldens"

var _traces: Array[Dictionary] = []
var _trace_idx: int = -1
var _hz: Node2D = null
var _player: Node2D = null
var _frame: int = 0
var _lines: PackedStringArray = PackedStringArray()
var _frame_emits: PackedStringArray = PackedStringArray()
var _snap: Vector2 = Vector2.ZERO
var _snap_set: bool = false
var _capture: bool = false
var _failures: Array[String] = []
var _done: bool = false


func _ready() -> void:
	_capture = OS.get_environment("S2_TRACE_CAPTURE") == "1"
	_build_traces()
	EventBus.hazard_awoke.connect(_on_hazard_awoke)
	EventBus.hazard_caught.connect(_on_hazard_caught)
	EventBus.new_hazard_killed.connect(_on_new_hazard_killed)
	EventBus.bomb_pulse_started.connect(_on_bomb_pulse_started)
	EventBus.hazard_pursuer_state.connect(_on_hazard_pursuer_state)


## One trace per entity covering its interesting mode (Resolved Decisions):
##   pursuer_chase — dormant → linger-awake → chase → nonfatal catch → stun/cooldown
##                   (incl. a second catch probe INSIDE the cooldown-drift window, the
##                   Q1 stun/cooldown specimen) → falling-edge re-arm → resume chase.
##   pursuer_room  — room-bound mode: awake at spawn → patrol (out) → chase + nonfatal
##                   catch (in) → patrol again (latch re-arm on patrol).
##   pingpong      — travel + room-rect clamp bounces + a mid-trace contact (kills off)
##                   with falling-edge re-arm.
##   bomb          — idle → proximity arm → committed pulse → detonation hit (kills off).
##   spike         — deterministic phase spin + arm sweep hit + PERMANENT latch (arms
##                   keep sweeping the player, exactly one emit).
func _build_traces() -> void:
	var cfg_p1 := RunConfig.new()
	cfg_p1.r1_enabled = true
	cfg_p1.r1_depth_threshold = 99      # depth 0 never triggers — linger is the awakener
	cfg_p1.r1_linger_seconds = 0.5      # awake at ~frame 29
	cfg_p1.r1_chase_speed = 90.0
	cfg_p1.r1_speed_per_depth = 0.0
	cfg_p1.r1_catch_radius = 40.0
	cfg_p1.r1_catch_radius_per_depth = 0.0
	cfg_p1.r1_catch_kills = false       # the nonfatal path (stun + cooldown)
	_traces.append({"id": "pursuer_chase", "scene": "res://scenes/hazards/hazard_entity.tscn",
		"frames": 300, "cfg": cfg_p1, "ctx": {}, "start_pos": Vector2.ZERO, "player_body": true})

	var cfg_p2 := RunConfig.new()
	cfg_p2.r1_enabled = true
	cfg_p2.r1_depth_threshold = 0       # awake on the first frame (trigger=depth)
	cfg_p2.r1_chase_speed = 90.0
	cfg_p2.r1_catch_radius = 40.0
	cfg_p2.r1_catch_kills = false
	cfg_p2.r1_spawn_room_only = true
	cfg_p2.r1_patrol_speed = 30.0
	_traces.append({"id": "pursuer_room", "scene": "res://scenes/hazards/hazard_entity.tscn",
		"frames": 300, "cfg": cfg_p2, "ctx": {"room_bounds": Rect2(-100, -100, 200, 200)},
		"start_pos": Vector2.ZERO, "player_body": true})

	var cfg_pp := RunConfig.new()
	cfg_pp.hpp_enabled = true
	cfg_pp.hpp_speed = 120.0
	cfg_pp.hpp_kills = false
	_traces.append({"id": "pingpong", "scene": "res://scenes/hazards/pingpong_hazard.tscn",
		"frames": 300, "cfg": cfg_pp,
		"ctx": {"initial_dir": Vector2(1, 0.5), "room_bounds": Rect2(-80, -60, 160, 120)},
		"start_pos": Vector2.ZERO, "player_body": false})

	var cfg_b := RunConfig.new()
	cfg_b.hbomb_enabled = true
	cfg_b.hbomb_proximity_radius = 50.0
	cfg_b.hbomb_pulse_seconds = 1.0     # arm at frame 30 → detonate at frame 90
	cfg_b.hbomb_blast_radius = 40.0
	cfg_b.hbomb_kills = false
	_traces.append({"id": "bomb", "scene": "res://scenes/hazards/bomb_hazard.tscn",
		"frames": 96, "cfg": cfg_b, "ctx": {}, "start_pos": Vector2.ZERO, "player_body": false})

	var cfg_s := RunConfig.new()
	cfg_s.hspike_enabled = true
	cfg_s.hspike_rotation_speed = 90.0
	cfg_s.hspike_arm_length = 60.0
	cfg_s.hspike_kills = false
	_traces.append({"id": "spike", "scene": "res://scenes/hazards/spike_hazard.tscn",
		"frames": 300, "cfg": cfg_s, "ctx": {"phase_salt": 1},
		"start_pos": Vector2.ZERO, "player_body": false})


## The scripted player-position sequence per trace. Deterministic function of the
## frame index; the two "snap" placements latch a position derived from the hazard's
## own (traced) position, which stays fully deterministic run-to-run.
func _player_pos(id: String, f: int) -> Vector2:
	match id:
		"pursuer_chase":
			if f < 150:
				return Vector2(300, 40)
			if f < 210:
				return Vector2(150, 20)        # inside catch radius at f150 → nonfatal catch
			if f < 215:
				return Vector2(600, 300)       # leave radius → falling-edge re-arm
			if f == 215 and not _snap_set:
				_snap = _hz.global_position + Vector2(10, 0)   # Q1 specimen: catch attempt
				_snap_set = true               # INSIDE the would-be cooldown-drift window
			return _snap
		"pursuer_room":
			if f < 100:
				return Vector2(500, 500)       # outside the room → patrol
			if f < 200:
				return Vector2(20, 0)          # inside → chase + nonfatal catch
			return Vector2(500, -500)          # outside again → patrol (latch re-arm)
		"pingpong":
			if f < 200:
				return Vector2(400, 400)
			if f == 200 and not _snap_set:
				_snap = _hz.global_position    # contact this frame (kills off) → emit once
				_snap_set = true
			if f < 250:
				return _snap
			return Vector2(400, 400)
		"bomb":
			return Vector2(200, 0) if f < 30 else Vector2(30, 0)
		"spike":
			return Vector2(40, 0)
	return Vector2.ZERO


func _physics_process(_dt: float) -> void:
	if _done:
		return
	if _hz == null:
		_next_trace()
		return
	var t: Dictionary = _traces[_trace_idx]
	if _frame >= int(t["frames"]):
		_finish_trace()
		return
	_player.global_position = _player_pos(String(t["id"]), _frame)
	_frame_emits = PackedStringArray()
	if is_instance_valid(_hz):
		_hz._physics_process(FIXED_DELTA)
	_record_line()
	_frame += 1


func _next_trace() -> void:
	_trace_idx += 1
	if _trace_idx >= _traces.size():
		_done = true
		_summarize_and_quit()
		return
	var t: Dictionary = _traces[_trace_idx]
	if _player != null:
		_player.queue_free()
	_player = CharacterBody2D.new() if bool(t["player_body"]) else Node2D.new()
	add_child(_player)
	_snap = Vector2.ZERO
	_snap_set = false
	_player.global_position = _player_pos(String(t["id"]), 0)
	var scene := load(String(t["scene"])) as PackedScene
	_hz = scene.instantiate() as Node2D
	add_child(_hz)
	_hz.set_physics_process(false)     # the harness ticks it manually — never double-driven
	_hz.global_position = t["start_pos"]
	_hz.setup(t["cfg"], _player, t["ctx"])
	_frame = 0
	_lines = PackedStringArray()


func _record_line() -> void:
	var pos_s := "freed"
	var vel_s := "-"
	var state_s := "-"
	var rot_s := "-"
	if is_instance_valid(_hz):
		pos_s = var_to_str(_hz.global_position)
		if _hz is CharacterBody2D:
			vel_s = var_to_str((_hz as CharacterBody2D).velocity)
		var st: Variant = _hz.get(&"_state")
		if st != null:
			state_s = str(st)
		rot_s = var_to_str(_hz.rotation)
	_lines.append("%d|%s|%s|%s|%s|%s"
		% [_frame, pos_s, vel_s, state_s, rot_s, ";".join(_frame_emits)])


func _finish_trace() -> void:
	var t: Dictionary = _traces[_trace_idx]
	var id := String(t["id"])
	var path := "%s/trace_%s.txt" % [GOLDEN_DIR, id]
	if _capture:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			_failures.append("%s: could not open %s for writing" % [id, path])
		else:
			f.store_string("\n".join(_lines) + "\n")
			f.close()
			print("S2 TRACE CAPTURED: %s (%d frames)" % [path, _lines.size()])
	else:
		_compare_golden(id, path)
	if is_instance_valid(_hz):
		_hz.queue_free()
	_hz = null


func _compare_golden(id: String, path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_failures.append("%s: golden %s missing/empty — run once with S2_TRACE_CAPTURE=1" % [id, path])
		return
	var golden := text.strip_edges(false, true).split("\n")
	if golden.size() != _lines.size():
		_failures.append("%s: frame count %d != golden %d" % [id, _lines.size(), golden.size()])
	var n := mini(golden.size(), _lines.size())
	for i: int in n:
		if _lines[i] != golden[i]:
			_failures.append("%s: FIRST DIVERGENCE at frame %d\n  golden: %s\n  actual: %s"
				% [id, i, golden[i], _lines[i]])
			return
	print("S2 TRACE OK: %s (%d frames byte-identical)" % [id, _lines.size()])


func _summarize_and_quit() -> void:
	if _failures.is_empty():
		if _capture:
			print("S2 GOLDEN CAPTURE COMPLETE — %d traces written to %s" % [_traces.size(), GOLDEN_DIR])
		else:
			print("S2 GOLDEN PARITY OK — all %d entity frame-traces byte-identical to the "
				% _traces.size() + "pre-refactor goldens (position/velocity/state/rotation/emit-log).")
		get_tree().quit(0)
		return
	for f in _failures:
		printerr("S2 GOLDEN PARITY FAIL: ", f)
	get_tree().quit(1)


# --- Legacy emit log (full args — these ARE the golden's telemetry column) --------

func _on_hazard_awoke(depth: int, trigger: StringName) -> void:
	_frame_emits.append("hazard_awoke(%d,%s)" % [depth, trigger])


func _on_hazard_caught(depth: int, run_t_ms: int) -> void:
	_frame_emits.append("hazard_caught(%d,%d)" % [depth, run_t_ms])


func _on_new_hazard_killed(kind: StringName, depth: int, run_t_ms: int) -> void:
	_frame_emits.append("new_hazard_killed(%s,%d,%d)" % [kind, depth, run_t_ms])


func _on_bomb_pulse_started(depth: int, run_t_ms: int) -> void:
	_frame_emits.append("bomb_pulse_started(%d,%d)" % [depth, run_t_ms])


func _on_hazard_pursuer_state(state: StringName, depth: int, run_t_ms: int) -> void:
	_frame_emits.append("hazard_pursuer_state(%s,%d,%d)" % [state, depth, run_t_ms])
