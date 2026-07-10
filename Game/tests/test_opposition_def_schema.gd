extends Node
## S2 (M1.9) — OppositionDef params ↔ param_schema contract test (S2 spec §3.4 +
## Resolved Decisions schema-entry shape). Run as a SCENE:
##   godot --headless res://tests/test_opposition_def_schema.tscn
##
## For EVERY .tres under res://data/oppositions/:
##  (1) BIJECTION: Set(def.params.keys()) == Set(schema entries' `key`) — no
##      unschema'd param, no orphan schema row (the config_menu 89-row coverage
##      invariant, generalized per-def; fail-loud, per def, listing keys).
##  (2) TYPE/RANGE SANITY: typeof(params[key]) matches entry.type; default ==
##      params[key] (in S2 the authored value IS the default); min <= default <= max
##      for numeric types (min/max REQUIRED numeric-only — a bool row carrying them
##      fails); only the locked schema-entry fields exist (unknown extras fail loud);
##      `options` only on enum rows; `trap_if_neutral`, `step`, `gloss` optional +
##      type-checked when present.
##  (3) MIRROR PARITY (lives for all of M1.9 — Resolved Decisions Q2): params
##      defaults == the matching RunConfig.new() code-default knob values, and the
##      typed `kills` field == the matching *_kills default — so the unused def
##      surface cannot drift from the live knob surface while the legacy knobs
##      still drive band-1 behavior.
##  (4) HOST CONTRACT: def.host_scene loads; its root keeps the expected class_name
##      + the "hazard" group (guards thrown_item.gd's typed-kind continuity) + the
##      S2 seam surface (resolve_throw_death / get_def_id, with get_def_id() == id).
##
## Plus the S2 trap flags: exactly one `trap_if_neutral` per def, on the
## mechanism-critical magnitude ratified in the Resolved Decisions.

const DEFS_DIR := "res://data/oppositions"

## The locked schema-entry shape (Resolved Decisions — unknown extras fail loud).
const REQUIRED_FIELDS: Array[String] = ["key", "type", "default"]
const OPTIONAL_FIELDS: Array[String] = ["min", "max", "step", "gloss", "options", "trap_if_neutral"]
const VALID_TYPES: Array[String] = ["bool", "int", "float", "enum"]

## Mirror map (§3.3 tables as corrected): def id → { param_key: RunConfig property }.
## V3 (M1.12): pingpong/bomb/spike DROPPED from the mirror — their bespoke RunConfig
## knobs (hpp_/hbomb_/hspike_) were retired; they are now pure deck-driven data whose
## params mirror NO RunConfig field (magnitudes ride the play preset's param_overrides).
## The pursuer stays (the R1 machine + its r1_* knobs survive until V3b).
const MIRROR := {
	&"pursuer": {
		"depth_threshold": "r1_depth_threshold",
		"linger_seconds": "r1_linger_seconds",
		"chase_speed": "r1_chase_speed",
		"speed_per_depth": "r1_speed_per_depth",
		"catch_radius": "r1_catch_radius",
		"catch_radius_per_depth": "r1_catch_radius_per_depth",
		"spawn_room_only": "r1_spawn_room_only",
		"patrol_speed": "r1_patrol_speed",
	},
}

## The typed `kills` def field mirrors the legacy L5 gate knob (def id → knob). V3
## (M1.12): only the pursuer's r1_catch_kills survives; the K5 defs' `kills` no longer
## mirrors a RunConfig knob (it is entity-local — the entities' DEFAULTS.kills = true).
const KILLS_MIRROR := {
	&"pursuer": "r1_catch_kills",
}

## Per-def trap_if_neutral flag (exactly one, on the mechanism-critical magnitude).
const TRAP_FLAG := {
	&"pursuer": "catch_radius",
	&"pingpong": "speed",
	&"bomb": "proximity_radius",
	&"spike": "arm_length",
}

## Host-contract root class per def id (typed-root continuity, thrown_item.gd).
const HOST_CLASS := {
	&"pursuer": "HazardEntity",
	&"pingpong": "PingPongHazard",
	&"bomb": "BombHazard",
	&"spike": "SpikeHazard",
}


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []
	var rc := RunConfig.new()

	var dir := DirAccess.open(DEFS_DIR)
	if dir == null:
		printerr("DEF SCHEMA FAIL: cannot open ", DEFS_DIR)
		return 1
	var def_files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".tres"):
			def_files.append(f)
	def_files.sort()
	if def_files.size() < 4:
		failures.append("expected >= 4 defs in %s, found %d" % [DEFS_DIR, def_files.size()])

	var seen_ids: Array[StringName] = []
	for f in def_files:
		var def := load("%s/%s" % [DEFS_DIR, f]) as OppositionDef
		if def == null:
			failures.append("%s: does not load as OppositionDef" % f)
			continue
		seen_ids.append(def.id)
		_check_def(def, f, rc, failures)

	for want: StringName in MIRROR.keys():
		if not seen_ids.has(want):
			failures.append("expected def id %s not found among %s" % [want, str(seen_ids)])

	if failures.is_empty():
		print("DEF SCHEMA OK — %d defs: params<->param_schema bijection, locked entry " % def_files.size()
			+ "shape (type/range/default==params, unknown-field fail-loud), mirror-parity vs "
			+ "RunConfig.new() code defaults (params + typed kills), one trap_if_neutral per def "
			+ "on the ratified magnitude, and the host contract (scene loads, expected root "
			+ "class_name, 'hazard' group, resolve_throw_death/get_def_id seam, id continuity).")
		return 0
	for msg in failures:
		printerr("DEF SCHEMA FAIL: ", msg)
	return 1


func _check_def(def: OppositionDef, f: String, rc: RunConfig, failures: Array[String]) -> void:
	# --- (1) bijection ----------------------------------------------------------
	var param_keys: Array[String] = []
	for k: Variant in def.params.keys():
		param_keys.append(String(k))
	var schema_keys: Array[String] = []
	for entry: Dictionary in def.param_schema:
		schema_keys.append(String(entry.get("key", "")))
	for k in param_keys:
		if not schema_keys.has(k):
			failures.append("%s: param '%s' has no schema row (bijection)" % [f, k])
	for k in schema_keys:
		if not param_keys.has(k):
			failures.append("%s: schema row '%s' has no param (orphan row)" % [f, k])
	if schema_keys.size() != def.param_schema.size():
		failures.append("%s: schema rows with missing/duplicate keys" % f)

	# --- (2) locked entry shape + type/range sanity ------------------------------
	var trap_keys: Array[String] = []
	for entry: Dictionary in def.param_schema:
		var key := String(entry.get("key", ""))
		var where := "%s[%s]" % [f, key]
		for req in REQUIRED_FIELDS:
			if not entry.has(req):
				failures.append("%s: missing required schema field '%s'" % [where, req])
		for ek: Variant in entry.keys():
			var eks := String(ek)
			if not REQUIRED_FIELDS.has(eks) and not OPTIONAL_FIELDS.has(eks):
				failures.append("%s: unknown schema field '%s' (fail-loud discipline)" % [where, eks])
		var t := String(entry.get("type", ""))
		if not VALID_TYPES.has(t):
			failures.append("%s: invalid type '%s'" % [where, t])
			continue
		if not def.params.has(key):
			continue   # already reported by (1)
		var value: Variant = def.params[key]
		var dflt: Variant = entry.get("default")
		# typeof(params[key]) matches entry.type; default == params[key].
		var want_type := TYPE_NIL
		match t:
			"bool": want_type = TYPE_BOOL
			"int": want_type = TYPE_INT
			"float": want_type = TYPE_FLOAT
			"enum": want_type = TYPE_INT
		if typeof(value) != want_type:
			failures.append("%s: params value type %s != schema type '%s'"
				% [where, type_string(typeof(value)), t])
		if typeof(dflt) != want_type or dflt != value:
			failures.append("%s: schema default %s != params value %s (S2: authored value IS the default)"
				% [where, str(dflt), str(value)])
		# min/max: REQUIRED for numeric types, FORBIDDEN otherwise; min<=default<=max.
		var numeric := t == "int" or t == "float"
		if numeric:
			if not entry.has("min") or not entry.has("max"):
				failures.append("%s: numeric row missing min/max" % where)
			else:
				var mn: Variant = entry["min"]
				var mx: Variant = entry["max"]
				if typeof(mn) != want_type or typeof(mx) != want_type:
					failures.append("%s: min/max type mismatch vs '%s'" % [where, t])
				elif not (float(mn) <= float(dflt) and float(dflt) <= float(mx)):
					failures.append("%s: default %s outside [%s, %s]" % [where, str(dflt), str(mn), str(mx)])
		else:
			if entry.has("min") or entry.has("max"):
				failures.append("%s: non-numeric row carries min/max" % where)
		if entry.has("step") and typeof(entry["step"]) != TYPE_FLOAT:
			failures.append("%s: step must be float" % where)
		if entry.has("gloss") and typeof(entry["gloss"]) != TYPE_STRING:
			failures.append("%s: gloss must be a String CSV key" % where)
		if entry.has("options") and t != "enum":
			failures.append("%s: options only valid on enum rows" % where)
		if t == "enum" and not entry.has("options"):
			failures.append("%s: enum row missing options" % where)
		if entry.has("trap_if_neutral"):
			if typeof(entry["trap_if_neutral"]) != TYPE_BOOL:
				failures.append("%s: trap_if_neutral must be bool" % where)
			elif bool(entry["trap_if_neutral"]):
				trap_keys.append(key)

	# --- trap flags: exactly one per def, on the ratified magnitude ---------------
	if TRAP_FLAG.has(def.id):
		var want_trap := String(TRAP_FLAG[def.id])
		if trap_keys != [want_trap]:
			failures.append("%s: trap_if_neutral flags %s != expected ['%s']"
				% [f, str(trap_keys), want_trap])

	# --- (3) mirror parity vs RunConfig.new() code defaults -----------------------
	if MIRROR.has(def.id):
		var mmap: Dictionary = MIRROR[def.id]
		for pk: Variant in mmap.keys():
			var pks := String(pk)
			if not def.params.has(pks):
				failures.append("%s: mirror param '%s' missing from params" % [f, pks])
				continue
			var knob := String(mmap[pk])
			var rc_val: Variant = rc.get(knob)
			if typeof(def.params[pks]) != typeof(rc_val) or def.params[pks] != rc_val:
				failures.append("%s: params['%s'] = %s != RunConfig.new().%s = %s (mirror parity)"
					% [f, pks, str(def.params[pks]), knob, str(rc_val)])
		for pk in param_keys:
			if not mmap.has(pk):
				failures.append("%s: param '%s' has no legacy-knob mirror mapping (S2 params "
					% [f, pk] + "must mirror today's knobs exactly)")
	if KILLS_MIRROR.has(def.id):
		var kills_knob := String(KILLS_MIRROR[def.id])
		var rc_kills: bool = rc.get(kills_knob)
		if def.kills != rc_kills:
			failures.append("%s: typed kills field %s != RunConfig.new().%s = %s"
				% [f, str(def.kills), kills_knob, str(rc_kills)])

	# --- (4) host contract ---------------------------------------------------------
	if def.host_scene == null:
		failures.append("%s: host_scene missing" % f)
		return
	var root := def.host_scene.instantiate()
	if root == null:
		failures.append("%s: host_scene does not instantiate" % f)
		return
	if HOST_CLASS.has(def.id):
		var want_cls := String(HOST_CLASS[def.id])
		var script: Script = root.get_script()
		var got_cls := script.get_global_name() if script != null else &""
		if String(got_cls) != want_cls:
			failures.append("%s: host root class '%s' != expected '%s' (typed-kind continuity)"
				% [f, got_cls, want_cls])
	if not root.is_in_group(&"hazard"):
		failures.append("%s: host root not in the 'hazard' group" % f)
	if not root.has_method(&"resolve_throw_death"):
		failures.append("%s: host root missing resolve_throw_death (S2 throw seam)" % f)
	if not root.has_method(&"get_def_id"):
		failures.append("%s: host root missing get_def_id (S2 telemetry-kind seam)" % f)
	else:
		var got_id := StringName(root.call(&"get_def_id"))
		if got_id != def.id:
			failures.append("%s: get_def_id() %s != def.id %s (id continuity)" % [f, got_id, def.id])
	root.free()
