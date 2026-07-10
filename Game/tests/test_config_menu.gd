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
	#
	# M1.9 (S4) — the pin is now a TWO-PART model (S4 §3.4 Layer 2 / §8.1 Q3) so the
	# historical 89 stays meaningful as exactly the number it always measured:
	#   * the LEGACY exported set (total minus the 2 named S3 generic levers) is FROZEN
	#     at 89 — the M1.1–M1.8 hand-authored surface;
	#   * the removed set is EXACTLY {oppositions_enabled, param_overrides} → total 91.
	# A third generic lever fails loudly twice (set membership + total). Per-def knobs
	# NEVER enter this count (they are not RunConfig @export fields) — new defs change
	# no asserted number; their coverage is the per-def bijection below.
	var generic_levers: Array = ["oppositions_enabled", "param_overrides"]
	var legacy_exported: Array = []
	for f in exported:
		if not generic_levers.has(f):
			legacy_exported.append(f)
	# V3 (M1.12): the 21 K5 hpp_/hbomb_/hspike_ knobs were RETIRED (89 → 68 / 91 → 70).
	# V3b (M1.12): the 18 R1 r1_* knobs were RETIRED too (the pursuer is now deck-driven data),
	# so the frozen legacy surface drops 68 → 50 and the total 70 → 52.
	if legacy_exported.size() != 50:
		failures.append("expected 50 LEGACY exported RunConfig fields (post-V3b surface: was 68, −18 r1_ knobs), got %d"
			% legacy_exported.size())
	for lever in generic_levers:
		if not exported.has(lever):
			failures.append("S4: generic lever '%s' missing from the exported set (promotion to @export failed?)" % lever)
	if exported.size() != 52:
		failures.append("expected 52 exported RunConfig fields total (50 legacy + 2 levers), schema has %d"
			% exported.size())

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

	# --- 1c. M1.9 (S4): the GENERATED Oppositions surface -----------------------
	# COUNT-AGNOSTIC by design (S4 DoD): the menu must build with however many defs
	# are authored (4 at S4 time; 6+ after S6a/S6b land) with ZERO menu edits — so
	# these assertions key off menu._defs, never a hardcoded def count.
	if menu._defs.size() < 4:
		failures.append("S4: expected at least the 4 migrated defs loaded, got %d" % menu._defs.size())

	# The per-def bijection net (params ↔ param_schema ↔ generated rows) is green.
	if not menu.has_full_def_coverage():
		failures.append("S4: has_full_def_coverage() FAILED — per-def params/schema/rows drift")

	# §8.3.3: the generated section order equals the sorted-by-id def list, and each
	# def has a section + a full row ledger.
	var prev_id := ""
	for def in menu._defs:
		var id := String(def.id)
		if prev_id != "" and id < prev_id:
			failures.append("S4: _defs not sorted by id ('%s' after '%s')" % [id, prev_id])
		prev_id = id
		if menu.find_child("DefSection_%s" % id, true, false) == null:
			failures.append("S4: no generated section for def '%s'" % id)
		var rows: Dictionary = menu._def_rows.get(id, {})
		if rows.size() != def.param_schema.size():
			failures.append("S4: def '%s' has %d generated rows for %d schema entries"
				% [id, rows.size(), def.param_schema.size()])

	# The two generic levers are bound via DISTINCT sentinel controls (S4 §8.0.2).
	if not menu._rows.has("oppositions_enabled") or not menu._rows.has("param_overrides"):
		failures.append("S4: lever sentinel bindings missing from _rows")
	elif menu._rows["oppositions_enabled"] == menu._rows["param_overrides"]:
		failures.append("S4: the two lever sentinels must be DISTINCT controls")

	# Staging round-trip: master toggle stages the enable-list; a param widget stages
	# a SPARSE override; returning to the authored default erases it.
	var stage_def: OppositionDef = menu._defs[0]
	var stage_id := String(stage_def.id)
	var def_master: CheckButton = menu._def_masters.get(stage_id, null)
	if def_master == null:
		failures.append("S4: def '%s' has no master CheckButton" % stage_id)
	else:
		def_master.button_pressed = true   # emits toggled → stages enablement
		await get_tree().process_frame
		if not menu.apply_and_get_config().oppositions_enabled.has(stage_def.id):
			failures.append("S4: def master ON did not stage '%s' in oppositions_enabled" % stage_id)
	# Find a numeric schema param to override via its SpinBox (canonical control).
	var num_key := ""
	var num_default := 0.0
	for entry in stage_def.param_schema:
		if String(entry.get("type", "")) == "float":
			num_key = String(entry.get("key", ""))
			num_default = float(stage_def.params.get(num_key, 0.0))
			break
	if num_key == "":
		failures.append("S4: def '%s' has no float schema param to exercise staging" % stage_id)
	else:
		var num_spin := menu._def_rows[stage_id][num_key] as SpinBox
		if num_spin == null:
			failures.append("S4: def '%s' param '%s' control is not a SpinBox" % [stage_id, num_key])
		else:
			num_spin.value = num_default + 7.0     # deviates → sparse override staged
			await get_tree().process_frame
			var po: Dictionary = menu.apply_and_get_config().param_overrides
			var sub: Dictionary = po.get(stage_id, {})
			if not is_equal_approx(float(sub.get(num_key, -12345.0)), num_default + 7.0):
				failures.append("S4: override %s.%s=+7 not staged sparsely (param_overrides=%s)"
					% [stage_id, num_key, str(po)])
			num_spin.value = num_default           # back to the authored default → erased
			await get_tree().process_frame
			po = menu.apply_and_get_config().param_overrides
			if po.has(stage_id):
				failures.append("S4: returning to the authored default did not erase the sparse override (%s)"
					% str(po))
			num_spin.value = num_default + 7.0     # leave one staged so Reset proves the clear
			await get_tree().process_frame

	# --- 2. Edit: a master toggle + a knob set flows to the working config ------
	# V3b (M1.12): the EDIT probe re-pointed from the retired r1_ section to r2_ (still a
	# legacy knob section) — master toggle + a scalar knob + an enum knob, same coverage.
	# Master on.
	var r2_master := menu._rows["r2_enabled"] as CheckButton
	r2_master.button_pressed = true   # emits toggled → menu writes the field
	await get_tree().process_frame
	# A scalar knob: r2_cost_magnitude via its SpinBox (the canonical control).
	var cost_spin := menu._rows["r2_cost_magnitude"] as SpinBox
	cost_spin.value = 40.0            # emits value_changed → menu writes the field
	# An enum knob: r2_mechanism via its OptionButton.
	var mech := menu._rows["r2_mechanism"] as OptionButton
	mech.select(2)
	mech.item_selected.emit(2)        # select() does not emit; fire the bound handler
	await get_tree().process_frame

	var edited := menu.apply_and_get_config()
	if not edited.r2_enabled:
		failures.append("master toggle did not set r2_enabled on the working config")
	if not is_equal_approx(edited.r2_cost_magnitude, 40.0):
		failures.append("knob set did not write r2_cost_magnitude=40 (got %s)" % edited.r2_cost_magnitude)
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
