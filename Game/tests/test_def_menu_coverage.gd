extends Node
## Headless verification for S4 (M1.9) — the generated def surface's FAIL-LOUD net +
## the sweep-hygiene telemetry model + the tier-v1 live edit.
##
## test_config_menu.tscn covers the happy path (91-field count model, per-def
## bijection green on the authored defs, staging round-trip, Reset). THIS scene
## covers what that one can't:
##   (A) the per-def bijection net FIRES on a deliberately-broken def (negative test);
##   (B) the menu builds headlessly with ZERO defs (empty fixture folder → placeholder,
##       both coverage assertions still green — §8.3.4 first-class case);
##   (C) sweep hygiene end-to-end through Telemetry: staged levers stamp run_started
##       as FLAT DOTTED rows (param_overrides.<def_id>.<param_key> → primitive, NO
##       base key — the Wave-3 close-out shape), inert_enabled_defs rides beside the
##       legacy BUG6 list, the generic opposition_event / opposition_killed_player
##       rows land (dual-emit: the legacy new_hazard_killed row still lands too),
##       debug_run_dirtied → a debug_dirtied row + debug_dirty:true on run_ended,
##       and a clean second run stamps debug_dirty:false;
##   (D) tier-v1 live edit: _on_respawn_pressed despawns + respawns every live
##       instance AT THE SAME CELL with the merged params bag in ctx, and emits
##       debug_run_dirtied exactly ONCE per press;
##   (E) FBM19b deck-membership surface: deck-listed defs (charger/splitter via
##       band_two's opposition_deck) show the honest IN-DECK chip (never OFF) with
##       the band named in the tooltip, start EXPANDED, while a truly nowhere-
##       spawning def (splitter_child) keeps OFF + collapsed; and the four
##       Director knobs staged via the MENU path (_stage_override) reach the
##       EncounterBuilder deck lane on the real band_two end-to-end (def <
##       deck-entry < rc precedence intact).
##
## Run as a SCENE (autoloads + tr() need a live tree):
##   godot --headless --path Game res://tests/test_def_menu_coverage.tscn

const Schema := preload("res://systems/telemetry/telemetry_schema.gd")
const SettingsScript := preload("res://systems/settings/settings.gd")

const CONFIG_MENU_PATH := "res://ui/config/config_menu.tscn"
const EMPTY_DEFS_DIR := "res://tests/fixtures/oppositions_empty"
const LOG_PATH := "user://telemetry/run_log.jsonl"
const CELL := 16
const BAND_TWO_PATH := "res://data/bands/band_two.tres"

var _dirty_emits: Array[Array] = []   # recorded debug_run_dirtied emissions


## FBM19b (E): the policy-blind recording service (test_deck_entry's pattern) —
## inherits the REAL begin_band/valid_cells, replaces only the spawn mechanism so
## the deck lane's resolved ctx params are probe-able at plan level.
class FakeSpawnService:
	extends SpawnService
	var requests: Array[Dictionary] = []         # ordered successful (id, cell, ctx)
	var _stub_nodes: Array[Node] = []

	func spawn(def: OppositionDef, cell: Vector2i, ctx: Dictionary = {}) -> Node:
		var one: Array[Vector2i] = [cell]
		if valid_cells(one).size() != 1:         # the real BUG7 re-check
			return null
		requests.append({ "id": def.id, "cell": cell, "ctx": ctx })
		var n := Node.new()
		_stub_nodes.append(n)
		return n

	func cleanup() -> void:
		for n in _stub_nodes:
			if is_instance_valid(n):
				n.free()
		_stub_nodes.clear()


func _ready() -> void:
	var code: int = await _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []

	var scene := load(CONFIG_MENU_PATH) as PackedScene
	if scene == null:
		printerr("DEF MENU FAIL: could not load %s" % CONFIG_MENU_PATH)
		return 1

	# =========================================================================
	# (A) The bijection net fires on a broken def — negative test.
	# =========================================================================
	var menu: ConfigMenu = scene.instantiate() as ConfigMenu
	add_child(menu)
	await get_tree().process_frame

	if not menu.has_full_def_coverage():
		failures.append("(A) baseline has_full_def_coverage() should be GREEN on the authored defs")

	# A def whose params/schema disagree BOTH ways: 'orphan_param' has no schema
	# entry (clause a) and schema key 'ghost' names no param (clause b).
	var broken := OppositionDef.new()
	broken.id = &"zz_broken_fixture"
	broken.display_name = "Broken Fixture"
	broken.params = { "real_param": 1.0, "orphan_param": 2.0 }
	# append() into the typed Array[Dictionary] (a bare untyped literal can't assign).
	broken.param_schema.append({ "key": "real_param", "type": "float", "default": 1.0, "min": 0.0, "max": 10.0 })
	broken.param_schema.append({ "key": "ghost", "type": "float", "default": 0.0, "min": 0.0, "max": 1.0 })
	menu._defs.append(broken)
	var holder := VBoxContainer.new()
	add_child(holder)
	menu._build_def_section(holder, broken)   # generates rows for the schema entries
	if menu.has_full_def_coverage():
		failures.append("(A) has_full_def_coverage() did NOT fire on a params/schema mismatch")
	# Restore: the net must go green again once the broken def is removed.
	menu._defs.erase(broken)
	menu._def_rows.erase(String(broken.id))
	holder.queue_free()
	if not menu.has_full_def_coverage():
		failures.append("(A) net still red after removing the broken def (restore failed)")

	# A duplicate-id load error must also fail the net (§8.3.2).
	menu._def_load_error = true
	if menu.has_full_def_coverage():
		failures.append("(A) duplicate-id load error did not fail has_full_def_coverage()")
	menu._def_load_error = false

	# =========================================================================
	# (B) Zero defs: the menu must build headlessly on an empty folder.
	# =========================================================================
	var empty_menu: ConfigMenu = scene.instantiate() as ConfigMenu
	empty_menu.defs_dir = EMPTY_DEFS_DIR   # test hook, set BEFORE add_child
	add_child(empty_menu)
	await get_tree().process_frame
	if not empty_menu._defs.is_empty():
		failures.append("(B) empty fixture dir loaded %d defs" % empty_menu._defs.size())
	if empty_menu.find_child("DefsEmptyPlaceholder", true, false) == null:
		failures.append("(B) zero-defs build shows no placeholder label")
	if not empty_menu.has_full_coverage():
		failures.append("(B) legacy coverage failed with zero defs (lever sentinels must still bind)")
	if not empty_menu.has_full_def_coverage():
		failures.append("(B) per-def coverage failed with zero defs (vacuous case must be green)")
	empty_menu.queue_free()

	# =========================================================================
	# (C) Sweep hygiene through Telemetry (autoloads live in a scene test).
	# =========================================================================
	var bus := get_node_or_null("/root/EventBus")
	var tel := get_node_or_null("/root/Telemetry")
	var gs := get_node_or_null("/root/GameState")
	if bus == null or tel == null or gs == null:
		printerr("DEF MENU FAIL: EventBus / Telemetry / GameState autoload missing")
		return 1

	# Staged levers: spike enabled + one overridden param. spike's authored card is
	# ALL-NEUTRAL (S2), so the generalized trap detector must flag BOTH the schema-
	# flagged arm_length (still 0.0) AND the fully-neutral spawn card.
	var cfg := RunConfig.new()
	cfg.oppositions_enabled = [&"spike"]
	cfg.param_overrides = { "spike": { "rotation_speed": 45.0 } }

	_remove_log()
	gs.active_run_config = cfg
	tel.set_enabled(true)
	if not tel.is_enabled():
		failures.append("(C) set_enabled(true) did not enable telemetry")

	bus.run_started.emit(&"surface", 424242)
	# Generic rows (S4 migration) + a legacy row (dual-emit continuity).
	bus.opposition_event.emit(&"spike", &"spawned", 2, 0)
	bus.opposition_killed_player.emit(&"spike", 2, 0)
	bus.new_hazard_killed.emit(&"spike", 2, 0)
	# A live tweak dirties THIS run.
	bus.debug_run_dirtied.emit(&"respawn_params", 1234)
	bus.run_ended.emit(&"death", 30.0, 2)
	# A second, untouched run must stamp debug_dirty:false (per-run reset).
	bus.run_started.emit(&"surface", 424243)
	bus.run_ended.emit(&"extract", 10.0, 1)
	tel.set_enabled(false)   # flush + close

	var rows := _read_rows(LOG_PATH)
	var by_type := _group_by_type(rows)

	# --- run_started: dotted override rows + lever stamp + inert def traps -------
	if not by_type.has(Schema.RUN_STARTED):
		failures.append("(C) no run_started row")
	else:
		var sdata: Dictionary = ((by_type[Schema.RUN_STARTED] as Array)[0] as Dictionary).get("data", {})
		var snap: Dictionary = sdata.get("run_config", {})
		if snap.get("oppositions_enabled") != ["spike"]:
			failures.append("(C) run_config.oppositions_enabled != [spike]: %s"
				% str(snap.get("oppositions_enabled")))
		# The Wave-3 close-out shape: FLAT dotted rows, primitive leaf, NO base key.
		if not is_equal_approx(float(snap.get("param_overrides.spike.rotation_speed", -1.0)), 45.0):
			failures.append("(C) dotted stamp 'param_overrides.spike.rotation_speed' != 45.0: %s"
				% str(snap.get("param_overrides.spike.rotation_speed")))
		if snap.has("param_overrides"):
			failures.append("(C) run_config snapshot carries a base 'param_overrides' key (dotted rows only)")
		for k in snap.keys():
			if snap[k] is Dictionary:
				failures.append("(C) run_config snapshot value '%s' is nested (flat pin broken)" % k)
		# The generalized trap stamp rides beside the legacy BUG6 list.
		if not sdata.has("inert_enabled_defs"):
			failures.append("(C) run_started.data missing additive 'inert_enabled_defs'")
		else:
			var inert: Variant = sdata["inert_enabled_defs"]
			if not (inert is Array):
				failures.append("(C) inert_enabled_defs is not an Array")
			else:
				if not (inert as Array).has("spike:neutral_card"):
					failures.append("(C) inert_enabled_defs missing 'spike:neutral_card' (enable-alone spawns zero): %s" % str(inert))
				if not (inert as Array).has("spike:arm_length"):
					failures.append("(C) inert_enabled_defs missing 'spike:arm_length' (trap_if_neutral at 0.0): %s" % str(inert))
		if not sdata.has("inert_enabled_oppositions"):
			failures.append("(C) legacy inert_enabled_oppositions stamp disappeared")

	# --- the generic rows landed, primitives-only, beside the legacy row ---------
	for t: String in [Schema.OPPOSITION_EVENT, Schema.OPPOSITION_KILLED_PLAYER, Schema.NEW_HAZARD_KILLED]:
		if not by_type.has(t):
			failures.append("(C) expected a '%s' row, found none" % t)
			continue
		var data: Dictionary = ((by_type[t] as Array)[0] as Dictionary).get("data", {})
		for f in data.keys():
			var v: Variant = data[f]
			if not (v is int or v is float or v is bool or v is String):
				failures.append("(C) %s.data['%s'] is non-primitive" % [t, str(f)])
	if by_type.has(Schema.OPPOSITION_EVENT):
		var oe: Dictionary = ((by_type[Schema.OPPOSITION_EVENT] as Array)[0] as Dictionary).get("data", {})
		if String(oe.get("id", "")) != "spike" or String(oe.get("event", "")) != "spawned":
			failures.append("(C) opposition_event payload wrong: %s" % str(oe))
	if not Schema.ALL_TYPES.has(Schema.OPPOSITION_EVENT) \
			or not Schema.ALL_TYPES.has(Schema.OPPOSITION_KILLED_PLAYER) \
			or not Schema.ALL_TYPES.has(Schema.DEBUG_DIRTIED):
		failures.append("(C) new S4 row types missing from Schema.ALL_TYPES")

	# --- debug_dirtied row + the run_ended debug_dirty stamp ---------------------
	if not by_type.has(Schema.DEBUG_DIRTIED):
		failures.append("(C) no debug_dirtied row for the live tweak")
	else:
		var dd: Dictionary = ((by_type[Schema.DEBUG_DIRTIED] as Array)[0] as Dictionary).get("data", {})
		if String(dd.get("source", "")) != "respawn_params":
			failures.append("(C) debug_dirtied.source != respawn_params: %s" % str(dd))
	var ended: Array = by_type.get(Schema.RUN_ENDED, [])
	if ended.size() != 2:
		failures.append("(C) expected 2 run_ended rows, got %d" % ended.size())
	else:
		var ed1: Dictionary = (ended[0] as Dictionary).get("data", {})
		var ed2: Dictionary = (ended[1] as Dictionary).get("data", {})
		if ed1.get("debug_dirty") != true:
			failures.append("(C) tweaked run's run_ended.debug_dirty != true: %s" % str(ed1.get("debug_dirty")))
		if ed2.get("debug_dirty") != false:
			failures.append("(C) clean run's run_ended.debug_dirty != false (per-run reset broken): %s"
				% str(ed2.get("debug_dirty")))

	# Cleanup C.
	gs.active_run_config = null
	_remove_log()
	SettingsScript.set_telemetry_enabled(false)

	# =========================================================================
	# (D) Tier-v1 live edit: respawn-with-new-params through the real service.
	# =========================================================================
	var svc := SpawnService.new()
	add_child(svc)   # _enter_tree joins &"spawn_service" — the menu group-resolves it
	var container := Node2D.new()
	add_child(container)
	svc.begin_band(container, CELL, Vector2.INF, RunConfig.new())   # unarmed: no exclusion

	var stub_def := OppositionDef.new()
	stub_def.id = &"stub_respawn"
	stub_def.host_scene = _make_stub_scene()
	var cell_a := Vector2i(3, 4)
	var cell_b := Vector2i(9, 2)
	var old_a := svc.spawn(stub_def, cell_a, {})
	var old_b := svc.spawn(stub_def, cell_b, {})
	if old_a == null or old_b == null:
		failures.append("(D) fixture spawns failed (test mis-set)")

	# Stage an override for the stub on the FIRST menu's working config, then press.
	menu._cfg.param_overrides = { "stub_respawn": { "speed": 99.0 } }
	EventBus.debug_run_dirtied.connect(_on_dirty)
	_dirty_emits.clear()
	menu._on_respawn_pressed(stub_def)
	EventBus.debug_run_dirtied.disconnect(_on_dirty)

	if _dirty_emits.size() != 1:
		failures.append("(D) debug_run_dirtied emitted %d times, expected exactly 1 per press"
			% _dirty_emits.size())
	elif StringName(_dirty_emits[0][0]) != &"respawn_params":
		failures.append("(D) debug_run_dirtied source %s != respawn_params" % str(_dirty_emits[0][0]))
	if svc.live_count(stub_def.id) != 2:
		failures.append("(D) live_count after respawn == %d, expected 2" % svc.live_count(stub_def.id))
	# Same cells, new instances, merged params bag in ctx.
	var new_cells: Array[Vector2i] = []
	for node: Node in svc.live_instances(stub_def.id):
		new_cells.append(svc.spawn_cell_of(node))
		if node == old_a or node == old_b:
			failures.append("(D) an OLD instance survived the respawn")
		var calls: Array = node.get("setup_calls")
		if calls.size() != 1:
			failures.append("(D) respawned instance setup() called %d times" % calls.size())
		else:
			var ctx: Dictionary = calls[0]["ctx"]
			var bag: Dictionary = ctx.get("params", {})
			if not is_equal_approx(float(bag.get("speed", -1.0)), 99.0):
				failures.append("(D) respawn ctx params bag missing the staged override: %s" % str(bag))
	new_cells.sort()
	var want_cells: Array[Vector2i] = [cell_a, cell_b]
	want_cells.sort()
	if new_cells != want_cells:
		failures.append("(D) respawn cells %s != original cells %s" % [str(new_cells), str(want_cells)])
	await get_tree().process_frame   # let the despawned nodes actually free
	if is_instance_valid(old_a) or is_instance_valid(old_b):
		failures.append("(D) despawned instances were not freed")

	# =========================================================================
	# (E) FBM19b — deck-spawned defs: honest chip + auto-expand + the four
	#     Director knobs staged via the MENU path reach the deck lane end-to-end.
	# =========================================================================
	await _case_deck_surface(failures, scene)

	if failures.is_empty():
		print("DEF MENU COVERAGE OK — bijection net fires on drift + duplicate ids; "
			+ "zero-defs headless build green; dotted override stamp + inert_enabled_defs + "
			+ "generic opposition rows (dual-emit intact) + debug_dirtied/debug_dirty hygiene verified; "
			+ "tier-v1 respawn keeps cells, merges params, dirties ONCE; "
			+ "FBM19b deck surface honest (IN-DECK chip + tooltip + auto-expand, "
			+ "nowhere-spawners keep OFF+collapsed) and the menu-staged charger/splitter "
			+ "knobs reach band_two's deck lane on top of the deck-entry layer.")
		return 0
	for f in failures:
		printerr("DEF MENU FAIL: ", f)
	return 1


func _on_dirty(source: StringName, run_t_ms: int) -> void:
	_dirty_emits.append([source, run_t_ms])


# --- (E) FBM19b — deck-membership presentation + menu-staged knobs end-to-end ----

func _case_deck_surface(failures: Array[String], scene: PackedScene) -> void:
	var menu: ConfigMenu = scene.instantiate() as ConfigMenu
	add_child(menu)
	await get_tree().process_frame

	var charger: OppositionDef = _def_by_id(menu, &"charger")
	var splitter: OppositionDef = _def_by_id(menu, &"splitter")
	if charger == null or splitter == null:
		failures.append("(E) charger/splitter defs not loaded from data/oppositions (test mis-set)")
		menu.queue_free()
		return

	# Honest chip + auto-expand: deck-listed + not config-enabled → the IN-DECK
	# chip (never OFF), band display name in the tooltip, section EXPANDED at
	# build. charger is band_two-only; splitter is now in band_three's deck too
	# (M1.10 T3 D-RAT-6: [ambusher 6 · burrower 3 · splitter 4 · bomb 1]), so its
	# chip surfaces BOTH bands (band_three listed first). splitter_child spawns
	# nowhere → OFF + collapsed.
	var want_chip_by_id: Dictionary = {
		"charger": tr("CFG_DEF_CHIP_DECK").format({ "bands": "band_two", "n": 0 }),
		"splitter": tr("CFG_DEF_CHIP_DECK").format({ "bands": "band_three, band_two", "n": 0 }),
	}
	for id: String in ["charger", "splitter"]:
		var want_chip: String = want_chip_by_id[id]
		var chip: Label = menu._def_chips.get(id, null)
		if chip == null:
			failures.append("(E) no chip label for deck-listed def '%s'" % id)
			continue
		if chip.text == tr("CFG_CHIP_OFF"):
			failures.append("(E) deck-listed '%s' still shows the misleading OFF chip" % id)
		if chip.text != want_chip:
			failures.append("(E) '%s' chip '%s' != expected deck chip '%s'" % [id, chip.text, want_chip])
		if not chip.tooltip_text.contains("The Sump"):
			failures.append("(E) '%s' chip tooltip does not name the band: '%s'" % [id, chip.tooltip_text])
		if bool(menu._def_folded.get(id, true)):
			failures.append("(E) deck-listed '%s' section defaults FOLDED (knobs invisible)" % id)
		var body: Control = menu._def_bodies.get(id, null)
		if body == null or not body.visible:
			failures.append("(E) deck-listed '%s' body not visible at build" % id)
	var child_chip: Label = menu._def_chips.get("splitter_child", null)
	if child_chip == null:
		failures.append("(E) splitter_child section missing (nowhere-spawning control absent)")
	else:
		if child_chip.text != tr("CFG_CHIP_OFF"):
			failures.append("(E) nowhere-spawning splitter_child chip != OFF: '%s'" % child_chip.text)
		if not bool(menu._def_folded.get("splitter_child", false)):
			failures.append("(E) nowhere-spawning splitter_child should default collapsed")

	# Stage the four Director knobs via the MENU path — WITHOUT enabling the defs.
	menu._stage_override(charger, "aggro_range", 200.0)
	menu._stage_override(charger, "charge_speed", 750.0)
	menu._stage_override(splitter, "aggro_radius", 300.0)
	menu._stage_override(splitter, "move_speed", 120.0)
	var tuned_chip: String = tr("CFG_DEF_CHIP_DECK").format({ "bands": "band_two", "n": 2 })
	var charger_chip: Label = menu._def_chips.get("charger", null)
	if charger_chip != null and charger_chip.text != tuned_chip:
		failures.append("(E) charger chip after staging 2 knobs != '%s': '%s'"
			% [tuned_chip, charger_chip.text])

	var rc: RunConfig = menu.apply_and_get_config()
	if rc.oppositions_enabled.has(&"charger") or rc.oppositions_enabled.has(&"splitter"):
		failures.append("(E) staging params must not enable the defs (deck lane only)")

	# End-to-end: the REAL band_two deck lane resolves the staged values on top of
	# the deck-entry layer (def < deck-entry < rc — test_deck_entry (c)'s seam).
	var profile := load(BAND_TWO_PATH) as BandProfile
	if profile == null:
		failures.append("(E) could not load band_two.tres")
		menu.queue_free()
		return
	var band: Band = BandPipeline.new().generate(profile, 12345, RunConfig.new())
	if band == null:
		failures.append("(E) band_two pipeline returned null")
		menu.queue_free()
		return
	var svc := FakeSpawnService.new()
	var container := Node2D.new()
	add_child(container)
	svc.begin_band(container, CELL, Vector2.INF, rc)
	svc.set_cap_group(&"new_hazards", SpawnService.NEW_HAZARD_BAND_CEILING)
	EncounterBuilder.new().populate(band, profile, rc, svc)

	var want_charger: Dictionary = charger.params.duplicate(true)
	want_charger["throwable_while_charging"] = false   # deck-entry layer (D-RAT-2)
	want_charger["wall_crash_recover_mult"] = 2.0      # deck-entry layer (D-RAT-2)
	want_charger["aggro_range"] = 200.0                # rc layer (menu-staged)
	want_charger["charge_speed"] = 750.0               # rc layer (menu-staged)
	var want_splitter: Dictionary = splitter.params.duplicate(true)
	want_splitter["aggro_radius"] = 300.0              # rc layer (menu-staged)
	want_splitter["move_speed"] = 120.0                # rc layer (menu-staged)

	var charger_n := 0
	var splitter_n := 0
	for r: Dictionary in svc.requests:
		var params: Dictionary = (r["ctx"] as Dictionary).get("params", {})
		if r["id"] == &"charger":
			charger_n += 1
			if params != want_charger:
				failures.append("(E) charger resolved params != def + deck + staged rc: %s" % str(params))
				break
		elif r["id"] == &"splitter":
			splitter_n += 1
			if params != want_splitter:
				failures.append("(E) splitter resolved params != def + staged rc: %s" % str(params))
				break
	if charger_n < 1:
		failures.append("(E) band_two deck lane produced no charger instructions (staging unproven)")
	if splitter_n < 1:
		failures.append("(E) band_two deck lane produced no splitter instructions (staging unproven)")

	svc.cleanup()
	remove_child(container)
	container.free()
	svc.free()
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
	menu.queue_free()


func _def_by_id(menu: ConfigMenu, id: StringName) -> OppositionDef:
	for def: OppositionDef in menu._defs:
		if def.id == id:
			return def
	return null


## A runtime-built stub hazard scene recording setup() calls (the
## test_spawn_service pattern) so the merged params bag is probe-able.
func _make_stub_scene() -> PackedScene:
	var script := GDScript.new()
	script.source_code = """extends Node2D
var setup_calls: Array = []
func setup(cfg, player, spawn_ctx) -> void:
	setup_calls.append({\"cfg\": cfg, \"player\": player, \"ctx\": spawn_ctx})
"""
	script.reload()
	var proto := Node2D.new()
	proto.set_script(script)
	var packed := PackedScene.new()
	packed.pack(proto)
	proto.free()
	return packed


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
