extends Node
## Headless verification for CFG — the pre-run ConfigMenu (M1.1).
##
## Proves the menu is a faithful, complete surface over the R0 RunConfig schema:
##   1. COVERAGE — every one of RunConfig's exported @export fields has a bound
##      control (the §3.2/§3.6 "no opposition knob is unreachable" net), and the
##      count matches the schema (35 knobs: 32 R0 + 3 I1 lvl_).
##   2. EDIT — toggling a master + setting a knob via its control is reflected in
##      apply_and_get_config() (the working config the run will stage).
##   3. RESET — "Reset to baseline" returns an all-off config equal to the on-disk
##      default (the M1.0 baseline control).
##
## Run as a SCENE so the autoloads + a real tree resolve (the menu builds its UI in
## _ready and reads tr()):
##   godot --headless res://tests/test_config_menu.tscn

const CONFIG_MENU_PATH := "res://ui/config/config_menu.tscn"
const DEFAULT_CFG_PATH := "res://data/run_config/run_config.tres"


func _ready() -> void:
	get_tree().quit(await _run())


func _run() -> int:
	var failures: Array[String] = []

	var scene := load(CONFIG_MENU_PATH) as PackedScene
	if scene == null:
		printerr("CONFIG MENU FAIL: could not load %s" % CONFIG_MENU_PATH)
		return 1
	var menu: ConfigMenu = scene.instantiate() as ConfigMenu
	add_child(menu)
	await get_tree().process_frame   # _ready: build UI + coverage assert + refresh

	# --- 1. Coverage: every exported RunConfig field is bound -------------------
	if not menu.has_full_coverage():
		failures.append("coverage assertion FAILED — a RunConfig knob is unreachable")

	var default_cfg := load(DEFAULT_CFG_PATH) as RunConfig
	var exported := _exported_fields(default_cfg)
	# Sanity vs. the schema's own count (R0: 32 knobs + I1's 3 lvl_ knobs = 35).
	if exported.size() != 35:
		failures.append("expected 35 exported RunConfig fields, schema has %d" % exported.size())

	var bound := menu._rows.keys()   # bound controls; masters are included as CheckButtons
	for f in exported:
		if not bound.has(f):
			failures.append("field '%s' has NO bound control (unreachable knob)" % f)

	# --- 2. Edit: a master toggle + a knob set flows to the working config ------
	# Master on.
	var r1_master := menu._rows["r1_enabled"] as CheckButton
	r1_master.button_pressed = true   # emits toggled → menu writes the field
	await get_tree().process_frame
	# A scalar knob: r1_chase_speed via its SpinBox (the canonical control).
	var speed_spin := menu._rows["r1_chase_speed"] as SpinBox
	speed_spin.value = 40.0           # emits value_changed → menu writes the field
	# An enum knob: r2_mechanism via its OptionButton.
	var mech := menu._rows["r2_mechanism"] as OptionButton
	mech.select(2)
	mech.item_selected.emit(2)        # select() does not emit; fire the bound handler
	await get_tree().process_frame

	var edited := menu.apply_and_get_config()
	if not edited.r1_enabled:
		failures.append("master toggle did not set r1_enabled on the working config")
	if not is_equal_approx(edited.r1_chase_speed, 40.0):
		failures.append("knob set did not write r1_chase_speed=40 (got %s)" % edited.r1_chase_speed)
	if edited.r2_mechanism != 2:
		failures.append("enum set did not write r2_mechanism=2 (got %d)" % edited.r2_mechanism)
	# The same instance is what the run stages.
	if edited != menu.apply_and_get_config():
		failures.append("apply_and_get_config returned a different instance across calls")

	# --- 3. Reset: all-off, equal to the on-disk default -----------------------
	menu._on_reset_pressed()
	await get_tree().process_frame
	var reset_cfg := menu.apply_and_get_config()
	if not reset_cfg.all_oppositions_disabled():
		failures.append("Reset did not return an all-off config")
	# Field-by-field equality against the script/on-disk default (the baseline).
	var fresh := load(DEFAULT_CFG_PATH) as RunConfig
	for f in exported:
		if not _values_equal(reset_cfg.get(f), fresh.get(f)):
			failures.append("Reset field '%s' = %s != default %s"
				% [f, str(reset_cfg.get(f)), str(fresh.get(f))])

	if failures.is_empty():
		print("CONFIG MENU OK — CFG verified (%d/%d knobs bound + reachable, master+knob+enum "
			% [bound.size(), exported.size()]
			+ "edits flow to working config, Reset returns the all-off baseline).")
		return 0
	for fail in failures:
		printerr("CONFIG MENU FAIL: ", fail)
	return 1


# The set of RunConfig @export field names (editor+storage, minus Resource bookkeeping).
func _exported_fields(cfg: RunConfig) -> Array:
	var out: Array = []
	for p in cfg.get_property_list():
		if (int(p.usage) & PROPERTY_USAGE_STORAGE) != 0 and (int(p.usage) & PROPERTY_USAGE_EDITOR) != 0:
			var n: String = p.name
			if n == "script" or n.begins_with("resource_") or n == "Built-in script":
				continue
			out.append(n)
	return out


func _values_equal(a, b) -> bool:
	if a is PackedFloat32Array and b is PackedFloat32Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not is_equal_approx(a[i], b[i]):
				return false
		return true
	if (a is float) and (b is float):
		return is_equal_approx(a, b)
	return a == b
