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
		if default_cfg.r1_enabled or default_cfg.r2_enabled or default_cfg.r3_enabled or default_cfg.r4_enabled:
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
	var staged := RunConfig.new()
	staged.r1_enabled = true
	staged.r1_chase_speed = 99.0
	gs.stage_run_config(staged)
	gs.start_run(&"near", 5678)
	if gs.active_run_config != staged:
		failures.append("staged config was not adopted as active_run_config")
	elif not gs.active_run_config.r1_enabled:
		failures.append("adopted config lost its r1_enabled=true")
	# Next run with nothing staged must fall back to all-off (no leak).
	gs.start_run(&"near", 9012)
	if gs.active_run_config == null or not gs.active_run_config.all_oppositions_disabled():
		failures.append("staged config leaked into a later run (should reset to all-off)")

	# === Case 4: active_run_config cleared on run end (run-state boundary) ===
	gs.start_run(&"near", 3456)
	gs.end_run(&"extract", 0.0)
	if gs.active_run_config != null:
		failures.append("active_run_config not cleared on run end (run-state must reset)")

	# === Case 5: to_flat_dict() is flat + JSON-safe + complete ===============
	var flat := fresh.to_flat_dict()
	var expected_keys: Array[String] = [
		"seed_override", "build_tag",
		"r1_enabled", "r1_depth_threshold", "r1_linger_seconds", "r1_chase_speed",
		"r1_speed_per_depth", "r1_catch_radius", "r1_catch_radius_per_depth", "r1_catch_kills", "r1_spawn_count",
		"r2_enabled", "r2_mechanism", "r2_cost_magnitude", "r2_cost_per_depth",
		"r2_depth_threshold", "r2_toll_resource",
		"r3_enabled", "r3_base_climb_rate", "r3_rate_per_depth", "r3_threshold_levels",
		"r3_penalty_kind", "r3_penalty_magnitude", "r3_max_forces_loss", "r3_decay_on_retreat",
		"r4_enabled", "r4_branch_chance_base", "r4_branch_per_depth", "r4_max_branch_depth",
		"r4_vision_radius", "r4_vision_tighten_per_depth", "r4_fog_enabled", "r4_lost_proxy_threshold",
		# I1 (M1.2) — level-scale knobs (additive payload).
		"lvl_enabled", "lvl_room_count", "lvl_size_mult",
	]
	for k in expected_keys:
		if not flat.has(k):
			failures.append("to_flat_dict() missing knob '%s'" % k)
	# Flat: no nested Dictionary values.
	for k in flat.keys():
		if flat[k] is Dictionary:
			failures.append("to_flat_dict() value for '%s' is nested (must be flat)" % k)
	# JSON-safe round-trip: stringify then parse must not error and must preserve keys.
	var json_str := JSON.stringify(flat)
	var parsed = JSON.parse_string(json_str)
	if parsed == null:
		failures.append("to_flat_dict() did not survive JSON stringify/parse")
	elif not (parsed is Dictionary) or parsed.size() != flat.size():
		failures.append("to_flat_dict() JSON round-trip lost keys (%d -> %d)"
			% [flat.size(), (parsed.size() if parsed is Dictionary else -1)])

	# === Verdict ============================================================
	if failures.is_empty():
		print("R0 OK — RunConfig all-off default verified (M1.0 baseline), active_run_config staged/defaulted/cleared on the run boundary, to_flat_dict() flat+JSON-safe with all %d knobs." % expected_keys.size())
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("R0 FAIL: ", f)
		get_tree().quit(1)
