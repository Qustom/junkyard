extends Node
## Headless verification for G1 — telemetry JSONL run log.
##
## Runs as a SCENE (not --script) so the EventBus / GameState / Telemetry autoloads
## resolve as live nodes, per M1_As_Built "Testing constraints (headless)":
##   godot --headless res://tests/test_telemetry_jsonl.tscn
##
## This is the lightweight acceptance check the G1 task asks for; the fuller
## GdUnit4 unit test of the JsonlWriter seam is G2's job.
##
## Asserts:
##   1. Opt-in respected: with telemetry DISABLED, driving a full run writes NO
##      file (privacy default).
##   2. With telemetry ENABLED, a full run (started → pickups → bank → ended)
##      writes the log; every line is parseable JSON carrying the envelope keys.
##   3. The acceptance fields exist: run duration, end cause, band depth reached,
##      and haul banked/lost — including a dedicated amount-lost-on-fail row.

const Schema := preload("res://systems/telemetry/telemetry_schema.gd")
const SettingsScript := preload("res://systems/settings/settings.gd")

const LOG_PATH := "user://telemetry/run_log.jsonl"


func _ready() -> void:
	var code := _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []

	var bus := get_node_or_null("/root/EventBus")
	var tel := get_node_or_null("/root/Telemetry")
	if bus == null or tel == null:
		printerr("TELEMETRY FAIL: EventBus or Telemetry autoload missing")
		return 1

	# --- Phase 0: clean slate -----------------------------------------------
	_remove_log()

	# --- Phase 1: DISABLED → no file written --------------------------------
	tel.set_enabled(false)
	if tel.is_enabled():
		failures.append("set_enabled(false) did not disable telemetry")
	_drive_run(bus, &"death")
	if FileAccess.file_exists(LOG_PATH):
		failures.append("opt-in violated: a file was written while telemetry was DISABLED")
	_remove_log()

	# --- Phase 2: ENABLED → a fail run is logged ----------------------------
	tel.set_enabled(true)
	if not tel.is_enabled():
		failures.append("set_enabled(true) did not enable telemetry")
	_drive_run(bus, &"death")
	tel.set_enabled(false)  # flush+close so the file is fully on disk to read back

	if not FileAccess.file_exists(LOG_PATH):
		printerr("TELEMETRY FAIL: no log written while telemetry was ENABLED")
		_cleanup(tel)
		return 1

	var rows := _read_rows(LOG_PATH)
	if rows.is_empty():
		failures.append("log file exists but contained no parseable JSON rows")

	# --- Assert envelope on every row ---------------------------------------
	for i in rows.size():
		var r: Dictionary = rows[i]
		for key in Schema.ENVELOPE_KEYS:
			if not r.has(key):
				failures.append("row %d missing envelope key '%s'" % [i, key])
		if r.get("v") != Schema.SCHEMA_VERSION:
			failures.append("row %d has schema v=%s, expected %d" % [i, str(r.get("v")), Schema.SCHEMA_VERSION])
		if not Schema.ALL_TYPES.has(String(r.get("type", ""))):
			failures.append("row %d has unknown type '%s'" % [i, str(r.get("type"))])

	# --- Assert the acceptance-criterion event types are present ------------
	var by_type := _group_by_type(rows)
	for required in [Schema.RUN_STARTED, Schema.BAND_DEPTH_REACHED, Schema.JUNK_PICKED_UP, Schema.JUNK_BANKED, Schema.RUN_ENDED]:
		if not by_type.has(required):
			failures.append("expected at least one '%s' row, found none" % required)

	# run_ended carries duration + cause + depth + banked/lost
	if by_type.has(Schema.RUN_ENDED):
		var ended: Dictionary = (by_type[Schema.RUN_ENDED] as Array)[0]
		var data: Dictionary = ended.get("data", {})
		for f in ["cause", "duration_s", "banked_total", "lost_total", "max_depth"]:
			if not data.has(f):
				failures.append("run_ended.data missing '%s'" % f)
		if String(data.get("cause", "")) != "death":
			failures.append("run_ended.cause == %s, expected 'death'" % str(data.get("cause")))

	# Dedicated amount-lost-on-fail row (the G1-owned E3 seam)
	if not by_type.has(Schema.JUNK_LOST):
		failures.append("expected a junk_lost (amount-lost-on-fail) row on a death run, found none")
	else:
		var lost: Dictionary = (by_type[Schema.JUNK_LOST] as Array)[0]
		var ld: Dictionary = lost.get("data", {})
		if not (ld.has("value") and ld.has("cause") and ld.has("depth")):
			failures.append("junk_lost.data missing value/cause/depth")

	# band_depth_reached carries a depth
	if by_type.has(Schema.BAND_DEPTH_REACHED):
		var depth_row: Dictionary = (by_type[Schema.BAND_DEPTH_REACHED] as Array)[0]
		if not (depth_row.get("data", {}) as Dictionary).has("depth"):
			failures.append("band_depth_reached.data missing 'depth'")

	_cleanup(tel)

	if failures.is_empty():
		print("TELEMETRY OK — opt-in respected (no file when off); enabled run wrote %d parseable JSONL rows with run duration, end cause, band depth, haul banked + amount-lost-on-fail." % rows.size())
		return 0
	for f in failures:
		printerr("TELEMETRY FAIL: ", f)
	return 1


## Drive a full run through EventBus the way the real systems would: start, descend
## two bands (each fires band_entered → depth), grab two junk (one accepted), bank
## a kept subset, then end with `cause`. We emit the raw signals directly rather
## than route through GameState so the test stays a pure Telemetry-listener check.
func _drive_run(bus: Node, cause: StringName) -> void:
	bus.run_started.emit(&"surface", 774411)
	bus.band_entered.emit(&"surface", 1)
	bus.junk_picked_up.emit(&"scrap_coil", 12, 1, Vector2.ZERO, true)
	bus.band_entered.emit(&"deep", 2)
	bus.junk_picked_up.emit(&"engine_block", 40, 6, Vector2.ZERO, true)
	# A failed run keeps a "pockets" subset; haul_banked carries the KEPT value.
	bus.haul_banked.emit(10)
	bus.currency_changed.emit(&"money", 10, &"pockets")
	bus.run_ended.emit(cause, 32.5, 2)


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
		else:
			rows.append({"__unparseable__": line})
	f.close()
	return rows


func _group_by_type(rows: Array) -> Dictionary:
	var out: Dictionary = {}
	for r in rows:
		if r is Dictionary and r.has("type"):
			var t := String(r["type"])
			if not out.has(t):
				out[t] = []
			(out[t] as Array).append(r)
	return out


func _remove_log() -> void:
	for p in [LOG_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _cleanup(tel: Node) -> void:
	tel.set_enabled(false)
	_remove_log()
	# Restore the persisted preference to its safe default so we leave nothing on.
	SettingsScript.set_telemetry_enabled(false)
