extends Node
## Headless end-to-end check for J4 (M1.3) Part B — confirm a `corridor_summary` JSONL row
## actually emits from a real run, carrying corridor_s / room_s / corridor_frac, WITHOUT touching
## the run_ended row arity or the schema version.
##
## Run as a SCENE (autoloads + the assembled main_game scene):
##   godot --headless res://tests/test_corridor_summary_row.tscn

const MAIN_GAME_PATH := "res://scenes/game/main_game.tscn"
const LOG_PATH := "user://telemetry/run_log.jsonl"
const SettingsScript := preload("res://systems/settings/settings.gd")

var _failures: Array[String] = []
var _game: MainGame = null
var _tel: Node = null
var _gs: Node = null


func _ready() -> void:
	get_tree().quit(await _run())


func _run() -> int:
	_tel = get_node_or_null("/root/Telemetry")
	_gs = get_node_or_null("/root/GameState")
	if _tel == null or _gs == null:
		printerr("J4-ROW FAIL: Telemetry / GameState autoload missing")
		return 1

	var scene := load(MAIN_GAME_PATH) as PackedScene
	_game = scene.instantiate() as MainGame
	add_child(_game)
	await get_tree().process_frame

	_remove_log()
	_tel.set_enabled(true)

	# Drive one full run to extract (the default play-preset, which biases corridors — but the
	# row emits for any config). Nudge depth + a few frames so the accumulator banks some time.
	_game.start_new_run()
	await _idle()
	if not _gs.run_active:
		_failures.append("run not active after start_new_run")
	for d in [1, 2, 3]:
		_gs.set_current_depth(d, d)
		await _idle()
	for _i in 10:
		await get_tree().physics_frame
	_gs.extract_and_end_run()
	await _idle()

	_tel.set_enabled(false)

	# Inspect the JSONL for the corridor_summary row.
	var rows := _read_rows(LOG_PATH)
	var found := false
	var run_ended_arity_ok := true
	for r in rows:
		var t := String(r.get("type", ""))
		if int(r.get("v", -1)) != TelemetrySchema.SCHEMA_VERSION:
			_failures.append("a row carries v=%s != SCHEMA_VERSION %d (schema bumped!)" % [str(r.get("v")), TelemetrySchema.SCHEMA_VERSION])
		if t == "corridor_summary":
			found = true
			var data: Dictionary = r.get("data", {})
			for k in ["corridor_s", "room_s", "corridor_frac"]:
				if not data.has(k):
					_failures.append("corridor_summary row missing '%s'" % k)
			var frac := float(data.get("corridor_frac", -1.0))
			if frac < 0.0 or frac > 1.0:
				_failures.append("corridor_frac out of [0,1]: %f" % frac)
		elif t == "run_ended":
			# Arity unchanged: the M1.0 fields are all present, nothing renamed.
			var ed: Dictionary = r.get("data", {})
			for f in ["cause", "duration_s", "banked_total", "lost_total", "max_depth"]:
				if not ed.has(f):
					run_ended_arity_ok = false
	if not found:
		_failures.append("no corridor_summary row emitted for the run")
	if not run_ended_arity_ok:
		_failures.append("run_ended row arity changed (missing an M1.0 field)")

	_cleanup()

	if _failures.is_empty():
		print("J4-ROW OK — a corridor_summary JSONL row emitted with corridor_s/room_s/corridor_frac "
			+ "(frac in [0,1]); SCHEMA_VERSION unchanged and the run_ended row arity is intact.")
		return 0
	for f in _failures:
		printerr("J4-ROW FAIL: ", f)
	return 1


func _idle() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame


func _read_rows(path: String) -> Array:
	var rows: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return rows
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			rows.append(parsed)
	f.close()
	return rows


func _remove_log() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(LOG_PATH)


func _cleanup() -> void:
	get_tree().paused = false
	_tel.set_enabled(false)
	_remove_log()
	SettingsScript.set_telemetry_enabled(false)
	if _game != null:
		_game.queue_free()
