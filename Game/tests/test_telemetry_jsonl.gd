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

	# opposition_event row: a K5a/b/c fatal hit is attributable by kind (== id).
	# V2 equivalence: legacy new_hazard_killed retired → the generic
	# opposition_event(event=&"hit_player") fires at the identical site/moment; the
	# hazard kind rides as `id`, so the death is attributable exactly as before.
	if not by_type.has(Schema.OPPOSITION_EVENT):
		failures.append("expected an opposition_event row on a hazard-death run, found none")
	else:
		var nhk: Dictionary = (by_type[Schema.OPPOSITION_EVENT] as Array)[0]
		var nhkd: Dictionary = nhk.get("data", {})
		for f in ["id", "event", "depth", "run_t_ms"]:
			if not nhkd.has(f):
				failures.append("opposition_event.data missing '%s'" % f)
		if String(nhkd.get("event", "")) != "hit_player":
			failures.append("opposition_event.event == %s, expected 'hit_player'" % str(nhkd.get("event")))
		if String(nhkd.get("id", "")) != "spike":
			failures.append("opposition_event.id == %s, expected 'spike'" % str(nhkd.get("id")))

	# debug_kill row: the K-key kill is self-identifying (precedes the death run_ended)
	if not by_type.has(Schema.DEBUG_KILL):
		failures.append("expected a debug_kill row on a player_died run, found none")
	else:
		var dk: Dictionary = (by_type[Schema.DEBUG_KILL] as Array)[0]
		var dkd: Dictionary = dk.get("data", {})
		for f in ["cause", "depth", "run_t_ms"]:
			if not dkd.has(f):
				failures.append("debug_kill.data missing '%s'" % f)
		if String(dkd.get("cause", "")) != "death":
			failures.append("debug_kill.cause == %s, expected 'death'" % str(dkd.get("cause")))

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
	# A new-hazard (K5a/b/c) fatal hit emits opposition_event(&"hit_player") before
	# death; mirror it (V2: replaces the retired new_hazard_killed drive — same moment).
	if cause == &"death":
		bus.opposition_event.emit(&"spike", &"hit_player", 2, 0)
	# The K-key debug_kill fires player_died(&"death") just before the run ends; emit it
	# here so the death run mirrors the real flow (debug_kill → player_died → fail_run).
	if cause == &"death":
		bus.player_died.emit(&"death")
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
