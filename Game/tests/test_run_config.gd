extends Node
## Headless verification for M1.1 R0 — the RunConfig data model + GameState wiring.
##
## Runs as a headless SCENE (test_run_config.tscn) so the EventBus/RNG/GameState
## autoloads resolve via the live SceneTree (M1_As_Built.md §"Testing constraints").
##
## Asserts the R0 acceptance criteria:
##   - the default RunConfig.tres loads and has EVERY opposition disabled (all-off);
##   - all-off default = M1.0 baseline (all_oppositions_disabled(), seed_override -1);
##   - GameState.active_run_config is populated at run start, and defaults to all-off
##     when no config was staged (existing no-config runs keep M1.0 behavior);
##   - a staged config is adopted at start_run and the staging slot is then cleared;
##   - active_run_config is cleared on run end (run-state boundary);
##   - to_flat_dict() returns a JSON-safe flat dict containing EVERY knob.
## Run: godot --headless res://tests/test_run_config.tscn


func _ready() -> void:
	var failures: Array[String] = []

	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		printerr("R0 FAIL: GameState autoload missing")
		get_tree().quit(1)
		return

	# === Case 1: default .tres loads + is all-off ============================
	var default_cfg: RunConfig = load("res://data/run_config/run_config.tres") as RunConfig
	if default_cfg == null:
		failures.append("default RunConfig.tres failed to load")
	else:
		if not default_cfg.all_oppositions_disabled():
			failures.append("default RunConfig has an opposition enabled (must be all-off)")
		# V3b (M1.12): r1_enabled dropped with the r1_* knob group — only r2/r3/r4 masters remain.
		if default_cfg.r2_enabled or default_cfg.r3_enabled or default_cfg.r4_enabled:
			failures.append("default RunConfig opposition master toggle(s) are ON")
		if default_cfg.seed_override != -1:
			failures.append("default seed_override == %d, expected -1 (none)" % default_cfg.seed_override)

	# A fresh RunConfig.new() must also be all-off (code-default control).
	var fresh := RunConfig.new()
	if not fresh.all_oppositions_disabled():
		failures.append("RunConfig.new() is not all-off")

	# === Case 2: active_run_config defaults to all-off when none staged ======
	gs.start_run(&"near", 1234)
	if gs.active_run_config == null:
		failures.append("active_run_config null after start_run (must be populated)")
	elif not gs.active_run_config.all_oppositions_disabled():
		failures.append("no-config run did not get an all-off config (M1.0 baseline broken)")

	# === Case 3: a staged config is adopted, then the staging slot is cleared =
	# V3b (M1.12): the r1_* knobs are gone — a distinctive pursuer deck override marks the
	# staged config instead (base_count>0 makes the pursuer card non-neutral).
	var staged := RunConfig.new()
	staged.param_overrides["pursuer"] = { "base_count": 1, "chase_speed": 99.0 }
	gs.stage_run_config(staged)
	gs.start_run(&"near", 5678)
	if gs.active_run_config != staged:
		failures.append("staged config was not adopted as active_run_config")
	elif not gs.active_run_config.param_overrides.has("pursuer"):
		failures.append("adopted config lost its staged pursuer override")
	# Next run with nothing staged must fall back to all-off (no leak).
	gs.start_run(&"near", 9012)
	if gs.active_run_config == null or not gs.active_run_config.all_oppositions_disabled():
		failures.append("staged config leaked into a later run (should reset to all-off)")
	elif not gs.active_run_config.param_overrides.is_empty():
		failures.append("staged pursuer override leaked into a later run (should reset to all-off)")

	# === Case 4: active_run_config cleared on run end (run-state boundary) ===
	gs.start_run(&"near", 3456)
	gs.end_run(&"extract", 0.0)
	if gs.active_run_config != null:
		failures.append("active_run_config not cleared on run end (run-state must reset)")

	# === Case 5: to_flat_dict() is flat + JSON-safe + complete ===============
	var flat := fresh.to_flat_dict()
	var expected_keys: Array[String] = [
		"seed_override", "build_tag",
		# V3b (M1.12): the 18 R1 r1_* stamp rows (incl. J2/J3 spread/density) were RETIRED —
		# the pursuer is now deck-driven data; its magnitudes stamp as param_overrides.* rows.
		"r2_enabled", "r2_mechanism", "r2_cost_magnitude", "r2_cost_per_depth",
		"r2_depth_threshold", "r2_toll_resource",
		"r3_enabled", "r3_base_climb_rate", "r3_rate_per_depth", "r3_threshold_levels",
		"r3_penalty_kind", "r3_penalty_magnitude", "r3_max_forces_loss", "r3_decay_on_retreat",
		"r4_enabled", "r4_branch_chance_base", "r4_branch_per_depth", "r4_max_branch_depth",
		"r4_vision_radius", "r4_vision_tighten_per_depth", "r4_fog_enabled", "r4_lost_proxy_threshold",
		# I1 (M1.2) — level-scale knobs (additive payload).
		"lvl_enabled", "lvl_room_count", "lvl_size_mult",
		# J3 (M1.3) loot-per-area sub-knob.
		"lvl_loot_density_per_area",
		# J4 (M1.3) corridor-rarity lever.
		"lvl_corridor_weight_mult", "lvl_short_corridors",
		# K2 (M1.4) — quota config knobs (the two behaviour enums KEPT per the Phase-4 Lock).
		"quota_enabled", "quota_base", "quota_step", "quota_check_timing", "quota_basis",
		# K3 (M1.4) — camera config knobs.
		"cam_enabled", "cam_visible_world_width", "cam_zoom_policy",
		# K4 (M1.4) — timer + warning config knobs.
		"timer_enabled", "timer_length_s", "timer_warning_threshold_s", "timer_warning_channel",
		# V3 (M1.12): the 21 K5a/K5b/K5c hpp_/hbomb_/hspike_ knobs were RETIRED (the three
		# hazards are now deck-driven data; magnitudes ride the play preset's param_overrides).
		# K7 (M1.4) — exit-placement config knobs.
		"exit_enabled", "exit_base_count", "exit_count_per_depth", "exit_keep_one_at_spawn", "exit_max_count",
		# L1 (M1.5) — throwing config knobs.
		"throw_enabled", "throw_speed", "throw_max_range",
		# V3b (M1.12): the L2 r1_spawn_room_only/r1_patrol_speed stamp rows were RETIRED —
		# the pursuer's room-bound patrol magnitudes ride param_overrides["pursuer"].
		# V3 (M1.12): the L5 hpp_kills/hbomb_kills/hspike_kills toggles were RETIRED with the
		# K5 knobs (lethality is now entity-local DEFAULTS.kills + optional param_overrides).
		# S3 (M1.9) — generic opposition levers (plain @export since S4's Wave-4
		# promotion; SG2 segments def sweeps).
		# param_overrides has NO base key: it stamps as flat dotted rows
		# "param_overrides.<def_id>.<param_key>" (Wave-3 close-out, Director 2026-07-03).
		"oppositions_enabled",
	]
	for k in expected_keys:
		if not flat.has(k):
			failures.append("to_flat_dict() missing knob '%s'" % k)
	# Flat: no nested Dictionary values — ABSOLUTE, no exceptions (Wave-3 close-out:
	# the former one-level param_overrides nesting was flattened to dotted rows).
	for k in flat.keys():
		if flat[k] is Dictionary:
			failures.append("to_flat_dict() value for '%s' is nested (must be flat)" % k)
	# S3 neutrality: an all-off config stamps EMPTY lever values (the levers are
	# invisible-neutral on the control), and the two levers round-trip through the stamp.
	if not (flat["oppositions_enabled"] is Array) or not (flat["oppositions_enabled"] as Array).is_empty():
		failures.append("to_flat_dict() all-off 'oppositions_enabled' is not an empty Array: %s"
			% str(flat.get("oppositions_enabled")))
	for k in flat.keys():
		if String(k).begins_with("param_overrides."):
			failures.append("to_flat_dict() all-off stamped an override row '%s' (must stamp none)" % k)
	if flat.has("param_overrides"):
		failures.append("to_flat_dict() still stamps a base 'param_overrides' key (dotted rows only)")
	var levered := RunConfig.new()
	levered.oppositions_enabled = [&"spike", &"charger"]
	levered.param_overrides = { "spike": { "base_count": 2, "rotation_speed": 45.0 } }
	var lever_flat := levered.to_flat_dict()
	if lever_flat.get("oppositions_enabled") != ["spike", "charger"]:
		failures.append("to_flat_dict() 'oppositions_enabled' did not stamp as Strings: %s"
			% str(lever_flat.get("oppositions_enabled")))
	if lever_flat.get("param_overrides.spike.base_count", -1) != 2:
		failures.append("to_flat_dict() dotted override row 'param_overrides.spike.base_count' wrong: %s"
			% str(lever_flat.get("param_overrides.spike.base_count")))
	if lever_flat.get("param_overrides.spike.rotation_speed", -1.0) != 45.0:
		failures.append("to_flat_dict() dotted override row 'param_overrides.spike.rotation_speed' wrong: %s"
			% str(lever_flat.get("param_overrides.spike.rotation_speed")))
	if JSON.parse_string(JSON.stringify(lever_flat)) == null:
		failures.append("to_flat_dict() with S3 levers set did not survive JSON round-trip")
	# JSON-safe round-trip: stringify then parse must not error and must preserve keys.
	var json_str := JSON.stringify(flat)
	var parsed = JSON.parse_string(json_str)
	if parsed == null:
		failures.append("to_flat_dict() did not survive JSON stringify/parse")
	elif not (parsed is Dictionary) or parsed.size() != flat.size():
		failures.append("to_flat_dict() JSON round-trip lost keys (%d -> %d)"
			% [flat.size(), (parsed.size() if parsed is Dictionary else -1)])

	# === Case 6: BUG6 (M1.3) inert_enabled_oppositions() config-trap detector ==
	# All-off control + a fully-populated config both report NO traps; each known
	# trap is detected exactly; r1_catch_radius_too_small is gated on spawn_count>0
	# (one trap per root cause); multiple traps union.
	if not fresh.inert_enabled_oppositions().is_empty():
		failures.append("inert_enabled_oppositions(): all-off control reported a trap (must be [])")

	var full := _populated_config()
	if not full.inert_enabled_oppositions().is_empty():
		failures.append("inert_enabled_oppositions(): fully-populated config reported a trap: %s"
			% str(full.inert_enabled_oppositions()))

	# R3 trap: enabled but empty threshold levels.
	var t_r3 := _populated_config()
	t_r3.r3_threshold_levels = PackedFloat32Array()
	_assert_traps(t_r3.inert_enabled_oppositions(), ["r3_no_thresholds"], "r3 empty thresholds", failures)

	# R4 fully-inert trap (M1.3-refined): enabled, maze NOT branching, vision off, lost off
	# → the whole opposition does nothing. (_populated_config has no maze, so zero vision+lost.)
	var t_r4dead := _populated_config()
	t_r4dead.r4_vision_radius = 0.0
	t_r4dead.r4_fog_enabled = false
	t_r4dead.r4_lost_proxy_threshold = 0.0
	_assert_traps(t_r4dead.inert_enabled_oppositions(), ["r4_no_effect"], "r4 fully inert", failures)

	# Maze-only R4 (branching ON, vision/fog/lost OFF) is the Director-blessed default shape
	# (M1.3 "match what I played — occlusion off") → must NOT be flagged.
	var t_r4maze := _populated_config()
	t_r4maze.r4_vision_radius = 0.0
	t_r4maze.r4_fog_enabled = false
	t_r4maze.r4_lost_proxy_threshold = 0.0
	t_r4maze.r4_branch_chance_base = 0.43
	t_r4maze.r4_max_branch_depth = 5
	_assert_traps(t_r4maze.inert_enabled_oppositions(), [], "r4 maze-only (blessed)", failures)

	# V3b (M1.12): the two R1 traps (r1_no_spawn, r1_catch_radius_too_small) were DROPPED with
	# the r1_* knobs — they are unreachable now that the pursuer is deck-driven data. The
	# catch-radius-too-small concern is now data-driven via pursuer.tres's param_schema
	# trap_if_neutral on catch_radius (covered by test_opposition_def_schema).

	# Union: multiple coexisting traps (R3 empty thresholds + a fully-inert R4).
	var t_multi := _populated_config()
	t_multi.r3_threshold_levels = PackedFloat32Array()
	t_multi.r4_vision_radius = 0.0
	t_multi.r4_lost_proxy_threshold = 0.0
	_assert_traps(t_multi.inert_enabled_oppositions(),
		["r3_no_thresholds", "r4_no_effect"], "multi-trap union", failures)

	# === Case 7: J1 (M1.3) make_default_play_preset() ========================
	# The named default play-preset is the Director's most-fun M1.2 stack, built ON TOP
	# of a fresh all-off RunConfig.new() so it NEVER mutates the control.
	var preset := RunConfig.make_default_play_preset()
	# V3b (M1.12): the pursuer is a deck card — its "on" state is its param_overrides bag,
	# not r1_enabled. A non-neutral pursuer card (base_count or count_per_depth > 0) = ON.
	var po: Dictionary = preset.param_overrides.get("pursuer", {})
	# F1 stack: LVL on, pursuer on (deck), R4 on, R2/R3 off.
	if not preset.lvl_enabled:
		failures.append("preset: lvl_enabled must be true")
	if int(po.get("base_count", 0)) <= 0 and float(po.get("count_per_depth", 0.0)) <= 0.0:
		failures.append("preset: pursuer deck card is neutral — the pursuer must be ON")
	if not preset.r4_enabled:
		failures.append("preset: r4_enabled must be true")
	if preset.r2_enabled or preset.r3_enabled:
		failures.append("preset: R2/R3 must be OFF (Director F1)")
	# M1.5 Director sweep: 30 rooms, size 4.0 (the new slider floor).
	if preset.lvl_room_count != 30:
		failures.append("preset: lvl_room_count == %d, expected 30" % preset.lvl_room_count)
	if not is_equal_approx(preset.lvl_size_mult, 4.0):
		failures.append("preset: lvl_size_mult == %f, expected 4.0" % preset.lvl_size_mult)
	# Match-played shape (M1.3 close-out "occlusion off"): R4 maze ON, vision/fog/lost OFF.
	if preset.r4_max_branch_depth <= 0 or preset.r4_branch_chance_base <= 0.0:
		failures.append("preset: R4 maze must be active (branching) — it is the only non-inert R4 feature")
	if preset.r4_vision_radius > 0.0 or preset.r4_fog_enabled or preset.r4_lost_proxy_threshold > 0.0:
		failures.append("preset: R4 vision/fog/lost must be OFF (Director: match what I played — occlusion off)")
	# Config-trap guard (BUG6 pairing): a maze-only R4 is blessed, so the whole preset is trap-free.
	if not preset.inert_enabled_oppositions().is_empty():
		failures.append("preset: has an inert enabled opposition (must be trap-free): %s"
			% str(preset.inert_enabled_oppositions()))
	# The factory must NOT leak into the code-level default: RunConfig.new() stays all-off.
	var still_off := RunConfig.new()
	if not still_off.all_oppositions_disabled() or still_off.lvl_enabled:
		failures.append("preset factory leaked into RunConfig.new() (the all-off control drifted)")

	# === Case 8: J2 (M1.3) enemy spread — now the pursuer deck spawn budget ===
	# V3b (M1.12): r1_spawn_distribution / r1_spread_min_depth were DROPPED (no deck
	# equivalent). The old "how many pursuers, spread how" is now the pursuer deck card's
	# base_count / count_per_depth demand. The preset carries base_count 2, count_per_depth 0.5.
	if int(po.get("base_count", 0)) != 2:
		failures.append("J2 preset: pursuer base_count == %d, expected 2 (deck spawn budget)" % int(po.get("base_count", 0)))
	if not (float(po.get("count_per_depth", 0.0)) > 0.0):
		failures.append("J2 preset: pursuer count_per_depth must be > 0 (depth-ramped spread)")

	# === Case 9: J3 (M1.3) per-room density + loot sub-knob ==================
	# V3b (M1.12): the r1_per_room_density / r1_density_* knobs were DROPPED — per-room
	# density folded into the pursuer deck's even-spread demand (deck credit budget +
	# per_band_cap), so there is no RunConfig density surface left to assert. Only the
	# lvl_ loot sub-knob (a separate presentation lever) remains.
	if fresh.lvl_loot_density_per_area != 0.0:
		failures.append("J3: all-off lvl_loot_density_per_area == %f, expected 0.0 (OFF)" % fresh.lvl_loot_density_per_area)
	# The loot sub-knob is never preset-on (it contradicts depth_curve.gd's intent).
	if preset.lvl_loot_density_per_area != 0.0:
		failures.append("J3 preset: lvl_loot_density_per_area must be 0.0 (loot sub-knob NEVER preset-on)")

	# === Case 10: J4 (M1.3) corridor-rarity lever knobs ======================
	# All-off control = M1.2: corridor weight mult NEUTRAL (1.0) + short-corridors OFF (false)
	# → the generator's weight table is untouched, so the all-off fingerprint stays e943ac9c8bc1.
	if not is_equal_approx(fresh.lvl_corridor_weight_mult, 1.0):
		failures.append("J4: all-off lvl_corridor_weight_mult == %f, expected 1.0 (neutral)" % fresh.lvl_corridor_weight_mult)
	if fresh.lvl_short_corridors:
		failures.append("J4: all-off lvl_short_corridors must be false (neutral)")
	# The default play-preset BIASES toward fewer/shorter corridors (Director Q-F: big rooms +
	# short halls) — a non-neutral weight mult AND/OR the long-hall drop. The CODE default stays
	# neutral; only the named preset biases.
	if not (preset.lvl_corridor_weight_mult < 1.0 or preset.lvl_short_corridors):
		failures.append("J4 preset: must bias toward fewer/shorter corridors (mult < 1.0 and/or short_corridors)")
	if not flat.has("lvl_corridor_weight_mult"):
		failures.append("J4: to_flat_dict() missing lvl_corridor_weight_mult")
	if not flat.has("lvl_short_corridors"):
		failures.append("J4: to_flat_dict() missing lvl_short_corridors")

	# === Verdict ============================================================
	if failures.is_empty():
		print("R0 OK — RunConfig all-off default verified (M1.0 baseline), active_run_config staged/defaulted/cleared on the run boundary, to_flat_dict() flat+JSON-safe with all %d knobs, BUG6 inert_enabled_oppositions() detects the R3/R4 traps (r3_no_thresholds/r4_no_effect), blesses maze-only R4, and []-clean for all-off + populated, J1 make_default_play_preset() is the F1 stack (LVL/pursuer-deck on, R4 maze-only/occlusion-off, R2/R3 off, 30 rooms, size 4.0), trap-free, and does NOT leak into the all-off control." % expected_keys.size())
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("R0 FAIL: ", f)
		get_tree().quit(1)


## A config with EVERY opposition enabled AND its driver knobs populated above the
## trap floors — the "fully populated, no trap" control for BUG6's detector. Each
## test then zeroes one knob to provoke exactly one trap.
func _populated_config() -> RunConfig:
	var rc := RunConfig.new()
	# V3b (M1.12): the R1 populate block was dropped with the r1_* knobs (the pursuer is now
	# deck-driven data with no RunConfig trap). Only R3/R4 remain trap-detectable here.
	# R3 — has at least one threshold level.
	rc.r3_enabled = true
	rc.r3_threshold_levels = PackedFloat32Array([0.5, 1.0])
	# R4 — vision radius > 0 and lost-proxy threshold > 0.
	rc.r4_enabled = true
	rc.r4_vision_radius = 120.0
	rc.r4_lost_proxy_threshold = 3.0
	return rc


## Assert the trap set equals `expected` (order-independent, exact membership).
func _assert_traps(got: PackedStringArray, expected: Array, label: String, failures: Array[String]) -> void:
	if got.size() != expected.size():
		failures.append("inert_enabled_oppositions() [%s]: expected %s, got %s"
			% [label, str(expected), str(got)])
		return
	for e in expected:
		if not got.has(e):
			failures.append("inert_enabled_oppositions() [%s]: missing '%s' (got %s)"
				% [label, e, str(got)])
