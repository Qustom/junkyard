extends Node
## RG1 (M1.4) — playtest-build verification driver (the objective half of the M1.4 §3 matrix).
##
## Runs as a SCENE so the EventBus / GameState / Telemetry autoloads resolve as live
## nodes (M1_As_Built "Testing constraints (headless)"):
##   godot --headless res://tests/test_rg1_m14_verify.tscn
##
## This is the M1.4 re-gate integration capstone. It instances the REAL assembled
## scenes/game/main_game.tscn and drives the full loop under the new M1.4 default
## play-preset + each M1.4 feature in ISOLATION, then all STACKED, then the all-off
## CONTROL, asserting (on top of carrying forward the whole M1.3 baseline guard set —
## fp / build-id / duration / end-cause / no-leak / 81-knob snapshot):
##   - RG1 default play-preset: make_default_play_preset() is the M1.4 fun stack
##         (M1.3 base: LVL+R1+quota+camera on, R4 maze-only, R2/R3 off; PLUS K4 timer ON
##         (300s / 60s-left warning / visual_only), all three K5 hazards ON with per_room_cap>0
##         and non-inert magnitudes, K7 exits ON: base 1 / per_depth 0.1 / keep-one / cap 7), is trap-free
##         (inert_enabled_oppositions empty), loops end-to-end, and does NOT leak into the
##         all-off control (RunConfig.new() stays the byte-identical baseline).
##   - all-off control byte-identical: the all-off RunConfig band fp == e943ac9c8bc1 (the
##         permanent determinism guard); building the preset never moves RunConfig.new().
##   - config-marked telemetry: to_flat_dict() carries every knob (asserted as a SET) incl.
##         the K4/K5/K7 keys; the 81-knob count tests still pass (verified separately).
##   - new-hazard spawn: driving the build's own deterministic spawn helper
##         (_spawn_new_hazards / the K5i descriptor path) under the preset spawns >=1 of each
##         new hazard kind, bounded by per_room_cap + NEW_HAZARD_BAND_CEILING (48).
##
## It does NOT judge fun (RG2/RG3) -- only that the assembled M1.4 build runs unbroken under
## every config the Director will sweep and that telemetry captures it with the new K-knobs.
##
## End-cause driving (headless, no rendering / no input simulation) mirrors the M1.3 driver:
## extract -> GameState.extract_and_end_run(); death/timeout -> fail_run(<cause>). Per-feature
## LOGIC is unit-tested in the K-suites (test_camera_view, test_bomb_hazard, test_exit_placement,
## test_run_config, test_config_menu); here we verify the ASSEMBLED M1.4 build end-to-end.

const MAIN_GAME_PATH := "res://scenes/game/main_game.tscn"
const MAIN_GAME_SCRIPT := "res://scenes/game/main_game.gd"
const LOG_PATH := "user://telemetry/run_log.jsonl"
const RunConfigScript := preload("res://data/run_config/run_config.gd")
const SettingsScript := preload("res://systems/settings/settings.gd")
const BANDGEN_CONFIG_PATH := "res://data/bandgen_config.tres"
const PIECE_CATALOG_PATH := "res://data/piece_catalog.tres"

## The locked M1.0..M1.3 all-off baseline fingerprint (sample seed 12345 -> 12 pieces).
## Determinism is sacred: the all-off control must stay byte-identical to this.
const BASELINE_FP := "e943ac9c8bc1"
const BASELINE_FP_SEED := 12345

var _failures: Array[String] = []
var _human_deferred: Array[String] = []
var _game: MainGame = null
var _tel: Node = null
var _gs: Node = null
var _bus: Node = null


func _ready() -> void:
	get_tree().quit(await _run())


func _run() -> int:
	_bus = get_node_or_null("/root/EventBus")
	_tel = get_node_or_null("/root/Telemetry")
	_gs = get_node_or_null("/root/GameState")
	if _bus == null or _tel == null or _gs == null:
		printerr("RG1 M1.4 VERIFY FAIL: EventBus / Telemetry / GameState autoload missing")
		return 1

	# Clean meta slate so money/bank deltas are interpretable.
	var empty: Array[JunkItem] = []
	_gs.banked_junk = empty.duplicate()

	# ---- M0: all-off determinism is byte-identical to the locked baseline --------
	_verify_baseline_fingerprint()

	# ---- RG1: the default play-preset is the M1.4 fun stack, trap-free, baseline-safe ---
	_verify_default_preset_shape()

	# ---- config-marked telemetry: to_flat_dict carries every K-knob -------------
	_verify_flat_dict_keys()

	# ---- new-hazard spawn plan (pure descriptor path, deterministic, no scene) ---
	_verify_new_hazard_spawn_plan()

	var scene := load(MAIN_GAME_PATH) as PackedScene
	if scene == null:
		printerr("RG1 M1.4 VERIFY FAIL: could not load %s" % MAIN_GAME_PATH)
		return 1
	_game = scene.instantiate() as MainGame
	add_child(_game)
	# M1.6 (M2): main_game is dive-only and self-starts on _ready; no %ConfigMenu rail to grab
	# (it moved to M4's P-overlay). Each V-row stages its RunConfig via GameState.stage_dive_config.
	await get_tree().process_frame

	# RG1 (assembled): the CFG rail boots seeded with the default play-preset, NOT all-off.
	_verify_cfg_boots_default_preset()

	# ---- new-hazard spawn THROUGH the assembled build (real nodes in BandContainer) ---
	await _verify_new_hazards_spawn_assembled()

	# Telemetry ON for the whole sweep so every run writes a JSONL row set.
	_remove_log()
	_tel.set_enabled(true)
	if not _tel.is_enabled():
		_failures.append("set_enabled(true) did not enable telemetry")

	# ---- Drive the M1.4 verify matrix through the assembled loop -----------------
	await _drive_run(_all_off(), &"extract", "M0-all-off")            # control + snapshot
	await _drive_run(_default_preset(), &"extract", "M1-default-preset")  # real preset, K5 kills off (L5)
	await _drive_run(_all_off(), &"timeout", "M2-timeout")            # timeout end-cause reachable

	_tel.set_enabled(false)

	# ---- Inspect the JSONL ------------------------------------------------------
	_inspect_log()

	_note_human_deferred()
	_cleanup()

	if _failures.is_empty():
		print("RG1 M1.4 VERIFY OK -- assembled M1.4 build runs the full loop. All-off control is ",
			"byte-identical to the locked baseline (fp=%s); the default play-preset is the M1.4 " % BASELINE_FP,
			"fun stack (M1.3 base + K4 timer 300s/60s-left/visual-only + all three K5 hazards on with ",
			"per_room_cap>0 + K7 exits ON: base1/per_depth0.1/keep-one/cap7), is trap-free (inert_enabled_oppositions empty), and ",
			"does NOT leak into the all-off control; to_flat_dict() carries every knob incl. the ",
			"K4/K5/K7 keys; the K5i spawn helper spawns >=1 of each new hazard kind bounded by the ",
			"per-room cap + the 48 band ceiling; extract/timeout end-causes reachable; the run_config ",
			"snapshot carries all 81 knobs. %d rows headless-verified; %d deferred."
			% [_headless_pass_count(), _human_deferred.size()])
		return 0
	for f in _failures:
		printerr("RG1 M1.4 VERIFY FAIL: ", f)
	return 1


# --- M0: all-off determinism unmoved (pure generator, no scene) ----------------

func _verify_baseline_fingerprint() -> void:
	var cfg := load(BANDGEN_CONFIG_PATH) as BandGenConfig
	var pc = load(PIECE_CATALOG_PATH)
	if cfg == null or pc == null:
		_failures.append("M0: missing bandgen config / baseline catalog for fingerprint check")
		return
	var catalog: Array[ZonePieceData] = pc.pieces
	var gen := BandGenerator.new()
	var baseline := gen.generate(BASELINE_FP_SEED, cfg, catalog)
	var all_off_band := BandGenerator.new().generate(BASELINE_FP_SEED, cfg, catalog, _all_off())
	var fp_baseline := baseline.fingerprint().substr(0, 12)
	var fp_all_off := all_off_band.fingerprint().substr(0, 12)
	if fp_baseline != BASELINE_FP:
		_failures.append("M0/DETERMINISM: baseline (rc=null) fp=%s != locked %s -- determinism moved!"
			% [fp_baseline, BASELINE_FP])
	if fp_all_off != BASELINE_FP:
		_failures.append("M0/DETERMINISM: all-off RunConfig fp=%s != locked %s -- all-off control drifted!"
			% [fp_all_off, BASELINE_FP])
	# Building the preset must NOT mutate the code-level all-off default.
	RunConfigScript.make_default_play_preset()
	var after := BandGenerator.new().generate(BASELINE_FP_SEED, cfg, catalog, _all_off()).fingerprint().substr(0, 12)
	if after != BASELINE_FP:
		_failures.append("M0/DETERMINISM: all-off fp=%s != locked %s AFTER building the preset -- preset leaked!"
			% [after, BASELINE_FP])


# --- RG1: default play-preset shape (the M1.4 fun stack) + baseline-safety contract --

func _verify_default_preset_shape() -> void:
	var preset := RunConfigScript.make_default_play_preset() as RunConfig
	if preset == null:
		_failures.append("RG1: make_default_play_preset() returned null")
		return

	# --- M1.3 base carried forward: LVL + R1 + R4 on, R2/R3 OFF, quota + camera ON. ---
	if not preset.lvl_enabled:
		_failures.append("RG1: default preset lvl_enabled is false (M1.3 base wants level scale ON)")
	if not preset.r1_enabled:
		_failures.append("RG1: default preset r1_enabled is false (M1.3 base wants the pursuing hazard ON)")
	if not preset.r4_enabled:
		_failures.append("RG1: default preset r4_enabled is false (M1.3 base wants the maze ON)")
	if preset.r2_enabled or preset.r3_enabled:
		_failures.append("RG1: default preset has R2/R3 ON (must be OFF by default)")
	if not preset.quota_enabled:
		_failures.append("RG1/K2: default preset quota_enabled is false (the headline stake must be ON)")
	if not preset.cam_enabled:
		_failures.append("RG1/K3: default preset cam_enabled is false (camera must be ON)")

	# --- K4 timer ON: 300s dive, 60s-left warning, visual_only. ---
	if not preset.timer_enabled:
		_failures.append("RG1/K4: default preset timer_enabled is false (the dive timer must be ON)")
	if not is_equal_approx(preset.timer_length_s, 300.0):
		_failures.append("RG1/K4: default preset timer_length_s=%f, expected 300.0" % preset.timer_length_s)
	if not is_equal_approx(preset.timer_warning_threshold_s, 60.0):
		_failures.append("RG1/K4: default preset timer_warning_threshold_s=%f, expected 60.0"
			% preset.timer_warning_threshold_s)
	if preset.timer_warning_channel != 0:
		_failures.append("RG1/K4: default preset timer_warning_channel=%d, expected 0 (visual_only — audio M2-gated)"
			% preset.timer_warning_channel)

	# --- K5: all three new hazard types ON, each non-inert, each with per_room_cap > 0. ---
	_assert_hazard_on(preset, "hpp", preset.hpp_enabled, preset.hpp_base_count,
		preset.hpp_count_per_depth, preset.hpp_per_room_cap)
	_assert_hazard_on(preset, "hbomb", preset.hbomb_enabled, preset.hbomb_base_count,
		preset.hbomb_count_per_depth, preset.hbomb_per_room_cap)
	_assert_hazard_on(preset, "hspike", preset.hspike_enabled, preset.hspike_base_count,
		preset.hspike_count_per_depth, preset.hspike_per_room_cap)
	# Type-specific knobs must be non-inert (the entities read them).
	if preset.hpp_speed <= 0.0:
		_failures.append("RG1/K5a: default preset hpp_speed<=0 (ping-pong would not move)")
	if preset.hbomb_pulse_seconds <= 0.0 or preset.hbomb_blast_radius <= 0.0 or preset.hbomb_proximity_radius <= 0.0:
		_failures.append("RG1/K5b: default preset bomb proximity/pulse/blast not all > 0 (bomb inert)")
	if preset.hspike_arm_length <= 0.0 or is_zero_approx(preset.hspike_rotation_speed):
		_failures.append("RG1/K5c: default preset spike arm_length/rotation_speed inert")
	# L5: the shipped preset is LETHAL — the three K5 *_kills toggles must default true. Only the
	# driven copy (_default_preset) turns them off; the real make_default_play_preset() never does.
	if not preset.hpp_kills:
		_failures.append("RG1/K5a: default preset hpp_kills is false (the shipped preset must kill)")
	if not preset.hbomb_kills:
		_failures.append("RG1/K5b: default preset hbomb_kills is false (the shipped preset must kill)")
	if not preset.hspike_kills:
		_failures.append("RG1/K5c: default preset hspike_kills is false (the shipped preset must kill)")

	# --- K7 exits ON (Director pre-playtest tweak): enabled, base 1 / per_depth 0.1 /
	# keep-one-at-spawn / cap 7. ---
	if not preset.exit_enabled:
		_failures.append("RG1/K7: default preset exit_enabled is false (the preset must ship exits ON)")
	if preset.exit_base_count != 1 or not is_equal_approx(preset.exit_count_per_depth, 0.1) \
			or not preset.exit_keep_one_at_spawn or preset.exit_max_count != 7:
		_failures.append("RG1/K7: preset exit knobs != base 1 / per_depth 0.1 / keep_one true / max 7 (got %d/%f/%s/%d)"
			% [preset.exit_base_count, preset.exit_count_per_depth, str(preset.exit_keep_one_at_spawn), preset.exit_max_count])

	# --- Trap-free: every enabled R-opposition's load-bearing magnitude is non-inert. ---
	var inert := preset.inert_enabled_oppositions()
	if not inert.is_empty():
		_failures.append("RG1/BUG6: default preset has an inert enabled opposition: %s" % str(inert))

	# --- The preset never mutates the code-level all-off default. ---
	var fresh := RunConfigScript.new() as RunConfig
	if not fresh.all_oppositions_disabled():
		_failures.append("RG1: RunConfig.new() is NOT all-off after make_default_play_preset() -- the preset leaked!")
	# The new K4/K5/K7 knobs must stay at their all-off code defaults on a fresh config.
	if fresh.timer_enabled or fresh.hpp_enabled or fresh.hbomb_enabled or fresh.hspike_enabled or fresh.exit_enabled:
		_failures.append("RG1: a fresh RunConfig.new() has a K4/K5/K7 master ON (baseline contaminated)")
	if fresh.hpp_per_room_cap != 0 or fresh.hbomb_per_room_cap != 0 or fresh.hspike_per_room_cap != 0:
		_failures.append("RG1: a fresh RunConfig.new() has a non-zero K5 per_room_cap (baseline contaminated)")


func _assert_hazard_on(preset: RunConfig, name: String, enabled: bool, base: int,
		per_depth: float, cap: int) -> void:
	if not enabled:
		_failures.append("RG1/K5: default preset %s_enabled is false (all three K5 hazards must be ON)" % name)
	# Non-inert: enabled but base 0 AND per_depth 0 means no node ever spawns (the spawn loop
	# skips it). The preset MUST pick provably non-inert magnitudes (per K5i: base>0 OR per_depth>0).
	if base <= 0 and per_depth <= 0.0:
		_failures.append("RG1/K5: default preset %s is enabled-but-inert (base=%d AND per_depth=%f)"
			% [name, base, per_depth])
	# Mandatory per-room cap (the K5i perf guard; the all-off default is 0/uncapped).
	if cap <= 0:
		_failures.append("RG1/K5: default preset %s_per_room_cap=%d <= 0 (the per-room cap is MANDATORY)"
			% [name, cap])


# --- config-marked telemetry: to_flat_dict carries every K-knob -----------------

func _verify_flat_dict_keys() -> void:
	var flat := (RunConfigScript.new() as RunConfig).to_flat_dict()
	var required := [
		# K2 quota
		"quota_enabled", "quota_base", "quota_step", "quota_check_timing", "quota_basis",
		# K3 camera
		"cam_enabled", "cam_visible_world_width", "cam_zoom_policy",
		# K4 timer
		"timer_enabled", "timer_length_s", "timer_warning_threshold_s", "timer_warning_channel",
		# K5a/b/c hazards
		"hpp_enabled", "hpp_base_count", "hpp_count_per_depth", "hpp_speed", "hpp_per_room_cap",
		"hbomb_enabled", "hbomb_base_count", "hbomb_count_per_depth", "hbomb_proximity_radius",
		"hbomb_pulse_seconds", "hbomb_blast_radius", "hbomb_per_room_cap",
		"hspike_enabled", "hspike_base_count", "hspike_count_per_depth", "hspike_rotation_speed",
		"hspike_arm_length", "hspike_per_room_cap",
		# K7 exits
		"exit_enabled", "exit_base_count", "exit_count_per_depth", "exit_keep_one_at_spawn", "exit_max_count",
	]
	for k in required:
		if not flat.has(k):
			_failures.append("config-telemetry: to_flat_dict() missing the M1.4 knob '%s'" % k)


# --- new-hazard spawn plan (pure descriptor path, deterministic, no scene) -------

## Mirror the K5i count math from _spawn_new_hazards EXACTLY (descriptor → per-piece
## n = base + floor(per_depth*depth), bounded by per_room_cap then the shared 48 ceiling)
## over a real graded band under the preset, asserting >=1 of each kind can spawn and the
## combined total is bounded by NEW_HAZARD_BAND_CEILING. This is the deterministic plan-level
## form of the matrix "new hazards spawn" row (stronger than reading runtime rows).
func _verify_new_hazard_spawn_plan() -> void:
	var band := _graded_band(BASELINE_FP_SEED)
	if band == null:
		_failures.append("K5i: could not build a graded band for the spawn-plan check")
		return
	var preset := RunConfigScript.make_default_play_preset() as RunConfig
	var mg = (load(MAIN_GAME_SCRIPT) as GDScript).new()
	var ceiling: int = mg.NEW_HAZARD_BAND_CEILING
	mg.free()

	var pieces_sorted := _pieces_depth_sorted(band)
	var per_kind := _plan_counts(preset, pieces_sorted, ceiling)
	for kind in ["pingpong", "bomb", "spike"]:
		# bomb has base 0 in the preset (ramps in with depth) — it still earns >=1 from
		# count_per_depth on a graded band with depth>=1, so all three should produce >=1.
		if int(per_kind.get(kind, 0)) < 1:
			_failures.append("K5i: spawn plan produced %d %s hazards under the preset -- expected >=1"
				% [int(per_kind.get(kind, 0)), kind])
	var total: int = int(per_kind.get("pingpong", 0)) + int(per_kind.get("bomb", 0)) + int(per_kind.get("spike", 0))
	if total > ceiling:
		_failures.append("K5i: combined new-hazard plan spawned %d > the %d band ceiling (perf guard breached)"
			% [total, ceiling])
	# Determinism: same band + rc → same plan.
	var per_kind2 := _plan_counts(preset, pieces_sorted, ceiling)
	if str(per_kind) != str(per_kind2):
		_failures.append("K5i: new-hazard spawn plan is not deterministic")


## Replicate _spawn_new_hazards' count math (descriptor order pingpong→bomb→spike with the
## SHARED band-ceiling starvation accumulator + the per_room_cap) without instancing scenes.
func _plan_counts(rc: RunConfig, pieces_sorted: Array, ceiling: int) -> Dictionary:
	var out := {"pingpong": 0, "bomb": 0, "spike": 0}
	var descs := [
		["pingpong", rc.hpp_enabled, rc.hpp_base_count, rc.hpp_count_per_depth, rc.hpp_per_room_cap],
		["bomb", rc.hbomb_enabled, rc.hbomb_base_count, rc.hbomb_count_per_depth, rc.hbomb_per_room_cap],
		["spike", rc.hspike_enabled, rc.hspike_base_count, rc.hspike_count_per_depth, rc.hspike_per_room_cap],
	]
	var spawned_total := 0
	for d in descs:
		var kind: String = d[0]
		if not d[1]:
			continue
		if spawned_total >= ceiling:
			break
		var base: int = d[2]
		var per_depth: float = d[3]
		var per_room_cap: int = d[4]
		if base <= 0 and per_depth <= 0.0:
			continue
		for p in pieces_sorted:
			if spawned_total >= ceiling:
				break
			var depth: int = p.depth_index
			var n: int = base + int(floor(per_depth * float(depth)))
			if per_room_cap > 0:
				n = mini(n, per_room_cap)
			n = mini(n, ceiling - spawned_total)
			if n <= 0:
				continue
			var cells: Array = _piece_cells(p)
			if cells.is_empty():
				continue
			out[kind] = int(out[kind]) + n
			spawned_total += n
	return out


# --- RG1 (assembled): the CFG rail boots seeded with the default play-preset ------

## M1.6 (M2): the dive resolves its config via GameState.dive_config_or_default() — which
## returns make_default_play_preset() when nothing is staged. Clear any staged config and
## assert the default-resolved config is the M1.4 fun stack (the boot contract unchanged).
func _verify_cfg_boots_default_preset() -> void:
	GameState.stage_dive_config(null)
	var working: RunConfig = GameState.dive_config_or_default()
	if working == null:
		_failures.append("RG1: GameState.dive_config_or_default() returned null at boot")
		return
	if working.all_oppositions_disabled():
		_human_deferred.append("RG1: CFG booted all-off rather than the default play-preset -- confirm config_menu seeds make_default_play_preset() (deferred: may be a fixture-mode boot)")
	elif not (working.lvl_enabled and working.r1_enabled and working.r4_enabled
			and working.timer_enabled and working.hpp_enabled and working.hbomb_enabled
			and working.hspike_enabled and working.exit_enabled):
		_failures.append("RG1: CFG boot config is not the M1.4 fun stack (lvl=%s r1=%s r4=%s timer=%s hpp=%s hbomb=%s hspike=%s exit=%s)"
			% [str(working.lvl_enabled), str(working.r1_enabled), str(working.r4_enabled),
				str(working.timer_enabled), str(working.hpp_enabled), str(working.hbomb_enabled),
				str(working.hspike_enabled), str(working.exit_enabled)])


# --- new-hazard spawn THROUGH the assembled build (real nodes) -------------------

## Drive the assembled scene under the preset and confirm REAL hazard nodes of each new kind
## land in BandContainer, bounded by the 48 band ceiling. This is the end-to-end form of the
## matrix "new hazards spawn" row (complements the plan-level deterministic check above).
func _verify_new_hazards_spawn_assembled() -> void:
	var cfg := _default_preset()
	cfg.r1_catch_kills = false   # keep R1 non-fatal so nothing pre-empts the spawn snapshot
	_stage_menu_config(cfg)
	_game.start_new_run()
	await await_idle()
	var container := _game.get_node_or_null("BandContainer")
	if container == null:
		_failures.append("K5i-assembled: BandContainer missing after start_new_run")
		return
	var counts := {"PingPongHazard": 0, "BombHazard": 0, "SpikeHazard": 0}
	_count_hazards_recursive(container, counts)
	var total: int = int(counts["PingPongHazard"]) + int(counts["BombHazard"]) + int(counts["SpikeHazard"])
	for cls in counts.keys():
		if int(counts[cls]) < 1:
			_failures.append("K5i-assembled: 0 %s nodes spawned under the preset (expected >=1)" % cls)
	var mg_script = load(MAIN_GAME_SCRIPT) as GDScript
	var ceiling: int = mg_script.new().NEW_HAZARD_BAND_CEILING
	if total > ceiling:
		_failures.append("K5i-assembled: %d new-hazard nodes spawned > the %d band ceiling" % [total, ceiling])
	# End this exploratory run cleanly so the telemetry sweep below starts fresh.
	_gs.extract_and_end_run()
	await await_idle()
	_dismiss_sell_screen()
	await await_idle()


func _count_hazards_recursive(node: Node, counts: Dictionary) -> void:
	for c in node.get_children():
		var cn := c.get_class()
		# get_class() returns the base ("CharacterBody2D"/"Node2D"); use the script class via `is`.
		if c is PingPongHazard:
			counts["PingPongHazard"] += 1
		elif c is BombHazard:
			counts["BombHazard"] += 1
		elif c is SpikeHazard:
			counts["SpikeHazard"] += 1
		if c.get_child_count() > 0:
			_count_hazards_recursive(c, counts)


# --- Config factories ----------------------------------------------------------

## M1.6 (M2): stage `cfg` as the dive's RunConfig via GameState.stage_dive_config — the dive
## reads it on its next self-start through GameState.dive_config_or_default().
func _stage_menu_config(cfg: RunConfig) -> void:
	GameState.stage_dive_config(cfg)


func _all_off() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-m14-M0-all-off"
	return c


func _default_preset() -> RunConfig:
	var c := RunConfigScript.make_default_play_preset() as RunConfig
	c.build_tag = "rg1-m14-M1-default-preset"
	c.seed_override = 12345
	# Keep R1 non-fatal for the driven run so the hazard can't pre-empt our chosen end-cause.
	c.r1_catch_kills = false
	# L5: keep the three K5 hazards non-lethal for the driven end-cause matrix. The entities
	# now SPAWN and behave (hpp/hbomb/hspike_enabled stay TRUE — the real preset), they just
	# cannot end the run, so the scripted extract/timeout cause wins. This retires the old
	# _driven_default_preset() which disabled the entities entirely; the driven run now
	# exercises the REAL K5 spawn. The lethal-preset guarantee is asserted by
	# _verify_default_preset_shape (the shipped make_default_play_preset() keeps *_kills TRUE).
	c.hpp_kills = false
	c.hbomb_kills = false
	c.hspike_kills = false
	return c


# --- One run: stage cfg, start, exercise oppositions, end with `cause` ----------

func _drive_run(cfg: RunConfig, cause: StringName, tag: String) -> void:
	_stage_menu_config(cfg)
	_game.start_new_run()
	await await_idle()

	if not _gs.run_active:
		_failures.append("%s: run not active after start_new_run" % tag)
		return

	for d in [1, 2, 3, 4, 5]:
		_gs.set_current_depth(d, d)
		await await_idle()
	for _i in 10:
		await get_tree().process_frame

	match cause:
		&"extract":
			_gs.extract_and_end_run()
		&"death":
			_gs.fail_run(&"death")
		&"timeout":
			_gs.fail_run(&"timeout")
		_:
			_failures.append("%s: unknown end-cause %s" % [tag, str(cause)])
	await await_idle()

	if _gs.run_active:
		_failures.append("%s: run_active still true after end-cause %s" % [tag, str(cause)])

	_dismiss_sell_screen()
	await await_idle()


func await_idle() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame


# M1.6 (M2): the SellScreen is retired (run-end auto-returns to the Hub via the App router).
# Kept as a no-op (belt-and-braces unpause) so the V-row call sites need no churn.
func _dismiss_sell_screen() -> void:
	get_tree().paused = false


# --- JSONL inspection: snapshot keys (incl. K-knobs) + end-causes ----------------

func _inspect_log() -> void:
	if not FileAccess.file_exists(LOG_PATH):
		_failures.append("no telemetry log written while enabled")
		return
	var rows := _read_rows(LOG_PATH)
	var started_by_tag := {}
	var ended_rows: Array = []
	var expected_keys := (RunConfigScript.new() as RunConfig).to_flat_dict().keys()
	var m14_new_keys := ["timer_enabled", "timer_length_s", "timer_warning_threshold_s",
		"timer_warning_channel", "hpp_enabled", "hbomb_enabled", "hspike_enabled",
		"hpp_per_room_cap", "exit_enabled", "exit_max_count"]

	for r in rows:
		var t := String(r.get("type", ""))
		if int(r.get("v", -1)) != TelemetrySchema.SCHEMA_VERSION:
			_failures.append("a row carries v=%s != SCHEMA_VERSION %d (schema bumped!)"
				% [str(r.get("v")), TelemetrySchema.SCHEMA_VERSION])
		if t == "run_started":
			var data: Dictionary = r.get("data", {})
			var snap: Dictionary = data.get("run_config", {})
			started_by_tag[String(snap.get("build_tag", ""))] = snap
			if snap.is_empty():
				_failures.append("run_started carries an empty run_config snapshot")
			else:
				for k in expected_keys:
					if not snap.has(k):
						_failures.append("run_config snapshot missing key '%s'" % k)
				for k in m14_new_keys:
					if not snap.has(k):
						_failures.append("snapshot missing the new M1.4 knob '%s'" % k)
		elif t == "run_ended":
			ended_rows.append(r)

	for tag in ["rg1-m14-M0-all-off", "rg1-m14-M1-default-preset"]:
		if not started_by_tag.has(tag):
			_failures.append("no run_started row for config '%s'" % tag)

	var seen_causes := {}
	for er in ended_rows:
		var ed: Dictionary = er.get("data", {})
		for f in ["cause", "duration_s", "banked_total", "lost_total", "max_depth"]:
			if not ed.has(f):
				_failures.append("run_ended.data missing M1.0 field '%s' (arity changed)" % f)
		seen_causes[String(ed.get("cause", ""))] = true
		if float(ed.get("duration_s", -1.0)) <= 0.0:
			_failures.append("run_ended.duration_s=%s is not > 0 (duration regression)"
				% str(ed.get("duration_s", "absent")))
	for cause in ["extract", "timeout"]:
		if not seen_causes.has(cause):
			_failures.append("end-cause '%s' never observed in run_ended rows" % cause)


# --- Human-deferred rows -------------------------------------------------------

func _note_human_deferred() -> void:
	_human_deferred.append("K2: a missed quota WIPES meta (run resets) -- the headline stake -- checklist")
	_human_deferred.append("K3: the camera shows a fixed FOV regardless of window size -- checklist")
	_human_deferred.append("K4: the 60s-left timer warning fires VISUALLY on a 300s dive -- checklist")
	_human_deferred.append("K5a/b/c: ping-pong / bomb-pulse / rotating-spikes read distinctly + kill -- checklist")
	_human_deferred.append("K6: motion is smooth (physics_interpolation), no camera jitter -- checklist")
	_human_deferred.append("K7: exits ON (base 1 / per_depth 0.1 / keep-one-at-spawn / cap 7) -- confirm multiple gates spawn + extract works -- checklist")
	_human_deferred.append("OQ-3 perf: worst-case ~112-body band (R1 64 + new 48) holds frame rate -- Director playtest")
	print("RG1 M1.4 human-deferred (manual playtest checklist): ")
	for h in _human_deferred:
		print("  - ", h)


func _headless_pass_count() -> int:
	# baseline-fp-unmoved · preset-shape(M1.3 base + K4 + K5×3 + K7-off) · trap-free ·
	# no-leak-into-default · to_flat_dict K-knobs · spawn-plan(>=1 each + ceiling + determinism) ·
	# CFG-boots-preset · assembled-spawn(real nodes) · 3 driven configs(snapshot+gating) ·
	# end-causes(extract+timeout) · run_ended-arity+duration.
	return 11


# --- Helpers -------------------------------------------------------------------

func _graded_band(seed: int) -> Band:
	var cfg := load(BANDGEN_CONFIG_PATH) as BandGenConfig
	var pc = load(PIECE_CATALOG_PATH)
	if cfg == null or pc == null:
		return null
	var catalog: Array[ZonePieceData] = pc.pieces
	var band := BandGenerator.new().generate(seed, cfg, catalog)
	var grader := DepthGrader.new()
	grader.grade(band)
	return band


## Pieces in the J3 stable depth-asc, then (y,x) order (mirrors _density_pieces_sorted).
func _pieces_depth_sorted(band: Band) -> Array:
	var pieces: Array = band.pieces.duplicate()
	pieces.sort_custom(func(a, b):
		if a.depth_index != b.depth_index:
			return a.depth_index < b.depth_index
		return a.offset_cell.y < b.offset_cell.y \
			or (a.offset_cell.y == b.offset_cell.y and a.offset_cell.x < b.offset_cell.x))
	return pieces


func _piece_cells(p) -> Array:
	return p.floor_cells


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


func _remove_log() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(LOG_PATH)


func _cleanup() -> void:
	get_tree().paused = false
	_tel.set_enabled(false)
	_gs.active_run_config = null
	var empty: Array[JunkItem] = []
	_gs.banked_junk = empty.duplicate()
	_remove_log()
	SettingsScript.set_telemetry_enabled(false)
	if _game != null:
		_game.queue_free()
