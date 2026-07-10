extends Node
## TEL (M1.1) — config-marking + per-opposition telemetry rows.
##
## Runs as a SCENE (not --script) so the EventBus / GameState / Telemetry autoloads
## resolve as live nodes, per M1_As_Built "Testing constraints (headless)":
##   godot --headless res://tests/test_telemetry_config_marking.tscn
##
## Asserts the TEL spec acceptance criteria (TEL_telemetry_config_marking.md §7):
##   1. The run_started row carries data.run_config with every RunConfig.to_flat_dict
##      key, and the snapshotted values match the run's config (a non-default config
##      with an opposition ON is reflected, proving config-marking labels the run).
##   2. Each of the 5 R2–R4 opposition row types is in ALL_TYPES, appears in the log
##      when its signal is emitted, carries the envelope keys, and has a parseable
##      primitives-only payload with the spec's fields. (V2 retired the R1
##      hazard_awoke/hazard_caught rows → the generic opposition_event, checked in #4.)
##   3. The envelope is UNCHANGED — every row has v == SCHEMA_VERSION == 1, the
##      ENVELOPE_KEYS list is exactly the M1.0 list (no bump, no new envelope key),
##      and run_ended keeps its M1.0 (reason, duration_s, depth_reached) data shape.
##   4. TEL stamps run_t_ms itself on opposition_event / exposure_crossed (the emitter
##      passing 0 still yields a sane run-elapsed value).

const Schema := preload("res://systems/telemetry/telemetry_schema.gd")
const SettingsScript := preload("res://systems/settings/settings.gd")
const RunConfigScript := preload("res://data/run_config/run_config.gd")

const LOG_PATH := "user://telemetry/run_log.jsonl"

## The exact envelope key list the M1.0 schema locked — asserting against this
## literal (not Schema.ENVELOPE_KEYS) proves the constant itself was NOT changed.
const EXPECTED_ENVELOPE_KEYS := ["v", "ts", "t_ms", "run_id", "session_id", "type", "data"]

## The 5 R2–R4 opposition row types and the required `data` fields for each (TEL
## spec §3). V2 retired the R1 hazard_awoke/hazard_caught rows → generic
## opposition_event (driven + asserted in Criterion 4 below).
const OPPOSITION_ROW_FIELDS := {
	"return_cost_incurred": ["depth", "cost_kind", "magnitude"],
	"exposure_crossed": ["level", "depth", "run_t_ms"],
	"exposure_penalty": ["level", "penalty_kind"],
	"nav_branch_taken": ["depth", "junction_degree"],
	"nav_lost_proxy": ["metric", "value", "depth"],
}


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	var bus := get_node_or_null("/root/EventBus")
	var tel := get_node_or_null("/root/Telemetry")
	var gs := get_node_or_null("/root/GameState")
	if bus == null or tel == null or gs == null:
		printerr("TEL CONFIG MARKING FAIL: EventBus / Telemetry / GameState autoload missing")
		return 1

	# --- Schema-level assertions (no I/O needed) ----------------------------
	# Envelope unchanged + no schema bump.
	if Schema.SCHEMA_VERSION != 1:
		failures.append("SCHEMA_VERSION == %d, expected 1 (config-marking must not bump)" % Schema.SCHEMA_VERSION)
	if Array(Schema.ENVELOPE_KEYS) != EXPECTED_ENVELOPE_KEYS:
		failures.append("ENVELOPE_KEYS changed: %s != %s" % [str(Schema.ENVELOPE_KEYS), str(EXPECTED_ENVELOPE_KEYS)])
	# All 5 R2–R4 opposition types registered in ALL_TYPES.
	for t in OPPOSITION_ROW_FIELDS.keys():
		if not Schema.ALL_TYPES.has(t):
			failures.append("opposition type '%s' missing from Schema.ALL_TYPES" % t)

	# --- Build a NON-default config: R1 ON + a few distinctive knob values ---
	var cfg := RunConfigScript.new() as RunConfig
	cfg.r1_enabled = true
	cfg.r1_depth_threshold = 3
	cfg.r1_catch_radius = 24.0
	cfg.seed_override = 99
	var expected_flat := cfg.to_flat_dict()

	# --- Clean slate, enable telemetry, stage the config --------------------
	_remove_log()
	gs.active_run_config = cfg
	tel.set_enabled(true)
	if not tel.is_enabled():
		failures.append("set_enabled(true) did not enable telemetry")

	# --- Drive a run: started → opposition events → ended -------------------
	bus.run_started.emit(&"surface", 99)
	# One row per opposition signal. run_t_ms args passed as 0 on purpose — TEL
	# must stamp its own _elapsed_ms() for opposition_event / exposure_crossed.
	# V2: the retired hazard_awoke/hazard_caught drives are now generic
	# opposition_event(&"awoke"/&"hit_player") at the identical moment.
	bus.opposition_event.emit(&"pursuer", &"awoke", 3, 0)
	bus.opposition_event.emit(&"pursuer", &"hit_player", 3, 0)
	bus.return_cost_incurred.emit(2, &"egress_toll", 1.5)
	bus.exposure_crossed.emit(1, 4, 0)
	bus.exposure_penalty.emit(1, &"speed")
	bus.nav_branch_taken.emit(2, 3)
	bus.nav_lost_proxy.emit(&"time_no_depth_progress", 7.5, 2)
	bus.run_ended.emit(&"death", 21.0, 3)
	tel.set_enabled(false)  # flush + close so the file is fully on disk

	if not FileAccess.file_exists(LOG_PATH):
		printerr("TEL CONFIG MARKING FAIL: no log written while telemetry was ENABLED")
		_cleanup(tel, gs)
		return 1

	var rows := _read_rows(LOG_PATH)
	var by_type := _group_by_type(rows)

	# --- Assert envelope on EVERY row (v == 1, keys present, type known) -----
	for i in rows.size():
		var r: Dictionary = rows[i]
		for key in EXPECTED_ENVELOPE_KEYS:
			if not r.has(key):
				failures.append("row %d missing envelope key '%s'" % [i, key])
		if r.get("v") != 1:
			failures.append("row %d has v=%s, expected 1 (no schema bump)" % [i, str(r.get("v"))])
		if not Schema.ALL_TYPES.has(String(r.get("type", ""))):
			failures.append("row %d has unknown type '%s'" % [i, str(r.get("type"))])

	# --- Criterion 1: run_started carries the config snapshot ---------------
	if not by_type.has(Schema.RUN_STARTED):
		failures.append("no run_started row found")
	else:
		var started: Dictionary = (by_type[Schema.RUN_STARTED] as Array)[0]
		var sdata: Dictionary = started.get("data", {})
		if not sdata.has("run_config"):
			failures.append("run_started.data missing 'run_config' snapshot")
		else:
			var snap: Dictionary = sdata["run_config"]
			# Every flat key present.
			for k in expected_flat.keys():
				if not snap.has(k):
					failures.append("run_config snapshot missing key '%s'" % k)
			# The distinctive values round-tripped correctly (JSON ints/bools/floats).
			if bool(snap.get("r1_enabled", false)) != true:
				failures.append("run_config.r1_enabled != true (config not reflected)")
			if int(snap.get("r1_depth_threshold", -1)) != 3:
				failures.append("run_config.r1_depth_threshold != 3 (got %s)" % str(snap.get("r1_depth_threshold")))
			if int(snap.get("seed_override", -1)) != 99:
				failures.append("run_config.seed_override != 99 (got %s)" % str(snap.get("seed_override")))
			# All other oppositions stayed off (all-off control is intact per-field).
			for off_key in ["r2_enabled", "r3_enabled", "r4_enabled"]:
				if bool(snap.get(off_key, true)) != false:
					failures.append("run_config.%s should be false" % off_key)
			# --- BUG6 (M1.3): additive inert_enabled_oppositions flag present + array ---
			# This config is r1_enabled with r1_spawn_count=0 (default), so it is a
			# trap (r1_no_spawn) — the field must be present, an Array, and contain it.
			if not sdata.has("inert_enabled_oppositions"):
				failures.append("run_started.data missing additive 'inert_enabled_oppositions' flag (BUG6)")
			else:
				var inert: Variant = sdata["inert_enabled_oppositions"]
				if not (inert is Array):
					failures.append("inert_enabled_oppositions is not an Array (got %s)" % type_string(typeof(inert)))
				elif not (inert as Array).has("r1_no_spawn"):
					failures.append("inert_enabled_oppositions did not flag r1_no_spawn for the R1-on/0-spawn config (got %s)" % str(inert))

	# --- Criterion 2: each opposition row present with envelope + payload ----
	for t in OPPOSITION_ROW_FIELDS.keys():
		if not by_type.has(t):
			failures.append("expected an emitted '%s' row, found none" % t)
			continue
		var row: Dictionary = (by_type[t] as Array)[0]
		var data: Dictionary = row.get("data", {})
		for f in OPPOSITION_ROW_FIELDS[t]:
			if not data.has(f):
				failures.append("%s.data missing field '%s'" % [t, f])
		# Payload is primitives-only (JSONL-clean): no nested dicts/arrays/objects.
		for f in data.keys():
			var v: Variant = data[f]
			if not (v is int or v is float or v is bool or v is String):
				failures.append("%s.data['%s'] is non-primitive (%s)" % [t, f, type_string(typeof(v))])

	# --- Criterion 4: TEL stamped run_t_ms itself (emitter passed 0) ---------
	# V2: opposition_event replaces hazard_caught here — it self-stamps run_t_ms via
	# _elapsed_ms() at the identical site, so the equivalence is exact.
	for t in ["opposition_event", "exposure_crossed"]:
		if by_type.has(t):
			var row2: Dictionary = (by_type[t] as Array)[0]
			var rt: Variant = (row2.get("data", {}) as Dictionary).get("run_t_ms")
			if not (rt is int or rt is float):
				failures.append("%s.run_t_ms is not numeric" % t)

	# --- Criterion 3: run_ended data shape unchanged from M1.0 --------------
	if by_type.has(Schema.RUN_ENDED):
		var ended: Dictionary = (by_type[Schema.RUN_ENDED] as Array)[0]
		var ed: Dictionary = ended.get("data", {})
		for f in ["cause", "duration_s", "banked_total", "lost_total", "max_depth"]:
			if not ed.has(f):
				failures.append("run_ended.data missing M1.0 field '%s'" % f)
		if String(ed.get("cause", "")) != "death":
			failures.append("run_ended.cause == %s, expected 'death'" % str(ed.get("cause")))
	else:
		failures.append("no run_ended row found")

	# --- BUG6 (M1.3): the all-off control must stamp an EMPTY inert flag ---------
	# A fresh all-off run_started row carries inert_enabled_oppositions == [] (no
	# master enabled → nothing inert; the baseline must never warn).
	_remove_log()
	gs.active_run_config = RunConfigScript.new() as RunConfig   # all-off control
	tel.set_enabled(true)
	bus.run_started.emit(&"surface", 7)
	tel.set_enabled(false)
	var off_rows := _read_rows(LOG_PATH)
	var off_by_type := _group_by_type(off_rows)
	if off_by_type.has(Schema.RUN_STARTED):
		var off_started: Dictionary = (off_by_type[Schema.RUN_STARTED] as Array)[0]
		var off_inert: Variant = (off_started.get("data", {}) as Dictionary).get("inert_enabled_oppositions")
		if not (off_inert is Array):
			failures.append("all-off run_started.inert_enabled_oppositions is not an Array")
		elif not (off_inert as Array).is_empty():
			failures.append("all-off control reported inert oppositions (must be []): %s" % str(off_inert))
	else:
		failures.append("all-off control: no run_started row written")

	_cleanup(tel, gs)

	if failures.is_empty():
		print("TEL CONFIG MARKING OK — run_started carries full run_config snapshot (R1-on config reflected); all 7 opposition row types logged with envelope v=1, primitives-only payloads; ENVELOPE_KEYS + run_ended shape unchanged; TEL stamped run_t_ms itself. %d rows checked." % rows.size())
		return 0
	for f in failures:
		printerr("TEL CONFIG MARKING FAIL: ", f)
	return 1


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
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(LOG_PATH)


func _cleanup(tel: Node, gs: Node) -> void:
	tel.set_enabled(false)
	gs.active_run_config = null
	_remove_log()
	SettingsScript.set_telemetry_enabled(false)
