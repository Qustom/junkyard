extends Node
## Headless verification for CFG — the pre-run ConfigMenu (M1.1).
##
## Proves the menu is a faithful, complete surface over the R0 RunConfig schema:
##   1. COVERAGE — every one of RunConfig's exported @export fields has a bound
##      control (the §3.2/§3.6 "no opposition knob is unreachable" net), and the
##      count matches the schema (46 knobs: 32 R0 + 1 I2 r1_catch_radius_per_depth + 3 I1 lvl_
##      + 2 J2 r1_spawn_distribution/r1_spread_min_depth + 5 J3 r1_density_* + 1 J3 lvl_loot_density_per_area
##      + 2 J4 lvl_corridor_weight_mult/lvl_short_corridors).
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
	# Sanity vs. the schema's own count (R0: 32 + I2's 1 r1_ + I1's 3 lvl_ + J2's 2 r1_
	# + J3's 5 r1_density_* + J3's 1 lvl_loot_density_per_area + J4's 2 lvl_corridor_* = 46;
	# + M1.4's K2 5 quota_ (enabled/base/step/check_timing/basis — the two enums KEPT per the
	# Phase-4 Lock) + K3 3 cam_ + K4 4 timer_ + K5a 5 hpp_ + K5b 7 hbomb_ + K5c 6 hspike_
	# + K7 5 exit_ = 35 → 46 + 35 = 81;
	# + M1.5's L1 3 throw_ (throw_enabled/throw_speed/throw_max_range) + L2 2 r1_
	# (r1_spawn_room_only/r1_patrol_speed) + L5 3 *_kills (hpp_kills/hbomb_kills/hspike_kills)
	# = 8 → 81 + 8 = 89. (The M1.5 lock's "88" was an off-by-one: 81 + 8 = 89; the actual
	# pre-L0 schema is 72 @export var + 9 @export_enum = 81, +8 new @export var = 80+9 = 89.)
	if exported.size() != 89:
		failures.append("expected 89 exported RunConfig fields, schema has %d" % exported.size())

	var bound := menu._rows.keys()   # bound controls; masters are included as CheckButtons
	for f in exported:
		if not bound.has(f):
			failures.append("field '%s' has NO bound control (unreachable knob)" % f)

	# --- 1b. M1.7 (Player tab): the debug Player tab holds the MOVED art toggle + 5 -----
	# anim-lock controls, all NON-FIELD / view-only. Each MUST render under the Player
	# tab's "Section_player_debug" panel, default to player_visual.gd's @export defaults,
	# and stay OUT of _rows (so none inflate coverage past 89 or move the fingerprint).

	# The Player tab page exists (its tab label is tr("CFG_TAB_PLAYER")).
	var player_section := menu.find_child("Section_player_debug", true, false)
	if player_section == null:
		failures.append("M1.7: Section_player_debug (the Player tab body) not found")

	# The art toggle MOVED to the Player tab (under Section_player_debug), default UNCHECKED
	# (art OFF / greybox is the shipped default; the animated character is opt-in — 2026-06-28).
	var art_toggle := menu.find_child("DebugPlayerArtToggle", true, false) as CheckButton
	if art_toggle == null:
		failures.append("M1.7: DebugPlayerArtToggle not found on the Player tab")
	else:
		if art_toggle.button_pressed:
			failures.append("M1.7: DebugPlayerArtToggle must default UNCHECKED (art OFF / greybox)")
		if player_section != null and not player_section.is_ancestor_of(art_toggle):
			failures.append("M1.7: the art toggle must render under the Player tab, not Meta")

	# Lock on pickup — CheckButton, default CHECKED (= lock_on_pickup true).
	var lop_cb := menu.find_child("PlayerLockOnPickup", true, false) as CheckButton
	if lop_cb == null:
		failures.append("M1.7: PlayerLockOnPickup control not found")
	elif not lop_cb.button_pressed:
		failures.append("M1.7: PlayerLockOnPickup must default CHECKED (lock_on_pickup=true)")

	# Animate pickup on reject — CheckButton, default UNCHECKED (= play_pickup_on_reject false).
	var rej_cb := menu.find_child("PlayerPickupOnReject", true, false) as CheckButton
	if rej_cb == null:
		failures.append("M1.7: PlayerPickupOnReject control not found")
	elif rej_cb.button_pressed:
		failures.append("M1.7: PlayerPickupOnReject must default UNCHECKED (play_pickup_on_reject=false)")

	# Lock mode — OptionButton, default selected id 0 = Clip-driven (= CLIP_DRIVEN).
	var mode_opt := menu.find_child("PlayerLockMode", true, false) as OptionButton
	if mode_opt == null:
		failures.append("M1.7: PlayerLockMode control not found")
	elif mode_opt.get_selected_id() != 0:
		failures.append("M1.7: PlayerLockMode must default to Clip-driven (id 0), got id %d" % mode_opt.get_selected_id())

	# Pickup lock (s) — SpinBox, default 0.25 (= pickup_lock_s).
	var pickup_spin := menu.find_child("PlayerPickupLock", true, false) as SpinBox
	if pickup_spin == null:
		failures.append("M1.7: PlayerPickupLock control not found")
	elif not is_equal_approx(pickup_spin.value, 0.25):
		failures.append("M1.7: PlayerPickupLock must default 0.25 (got %s)" % pickup_spin.value)

	# Throw lock (s) — SpinBox, default 0.30 (= throw_lock_s).
	var throw_spin := menu.find_child("PlayerThrowLock", true, false) as SpinBox
	if throw_spin == null:
		failures.append("M1.7: PlayerThrowLock control not found")
	elif not is_equal_approx(throw_spin.value, 0.30):
		failures.append("M1.7: PlayerThrowLock must default 0.30 (got %s)" % throw_spin.value)

	# NONE of the 6 Player-tab debug controls may leak into _rows (would trip coverage).
	var player_debug_controls := [art_toggle, lop_cb, rej_cb, mode_opt, pickup_spin, throw_spin]
	for k in menu._rows.keys():
		if menu._rows[k] in player_debug_controls:
			failures.append("M1.7: a Player-tab debug control leaked into _rows (field '%s') — it would trip coverage" % str(k))

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
