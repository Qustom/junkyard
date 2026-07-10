extends Node
## RG1 (M1.3) — playtest-build verification driver (the objective half of the M1.3 §3 matrix).
##
## Runs as a SCENE so the EventBus / GameState / Telemetry autoloads resolve as live
## nodes (M1_As_Built "Testing constraints (headless)"):
##   godot --headless res://tests/test_rg1_m13_verify.tscn
##
## This is the M1.3 re-gate integration capstone. It instances the REAL assembled
## scenes/game/main_game.tscn and drives the full loop under the new M1.3 default
## play-preset + each M1.3 fix in ISOLATION, then all STACKED, then the all-off
## CONTROL, asserting (on top of carrying forward the whole M1.2 baseline guard set —
## fp / build-id / duration / end-cause / no-leak):
##   - J1  default play-preset: RunConfig.make_default_play_preset() is the F1 stack
##         (LVL+R1 on, R4 maze-only/occlusion-off, R2/R3 off; J2 even_spread; J3 density
##         on with cap; J4 corridors biased down), is trap-free (inert_enabled_oppositions
##         empty), loops end-to-end through start_new_run(), and does NOT leak into the
##         all-off control (RunConfig.new() stays the byte-identical baseline).
##   - J2  enemy spread: even_spread + r1_spawn_count>=4 spawns hazards at MULTIPLE
##         distinct depth_index values (the spawn-depth PLAN spans >1 depth); single_gate
##         reproduces the M1.2 single-depth placement.
##   - J3  per-room density: r1_per_room_density>0 seeds extra hazards in big rooms scaled
##         by floor_cells area, bounded by the per-room cap + band ceiling (<=64); all-off
##         (density 0) → 0 density nodes (M1.2 control).
##   - J4  corridor lever: a non-neutral lvl_corridor_weight_mult / lvl_short_corridors
##         MOVES the band fingerprint for a fixed seed (fewer/shorter corridors) while
##         staying deterministic; the NEUTRAL default leaves the band byte-identical.
##   - corridor_summary: every run emits exactly one corridor_summary JSONL row carrying
##         corridor_s / room_s / corridor_frac (frac in [0,1]); SCHEMA_VERSION unchanged;
##         run_ended arity unchanged (the only telemetry addition is this additive row).
##   - all-off baseline byte-identical: the all-off RunConfig band fp == e943ac9c8bc1 (the
##         permanent determinism guard); zero opposition rows in the all-off run.
##   - snapshot carries all 46 knobs incl. the J2/J3/J4 keys (asserted as a SET, V13 precedent).
##
## It does NOT judge fun (RG2/RG3) -- only that the assembled M1.3 build runs unbroken
## under every config the Director will sweep and that telemetry captures it with the
## new r1_spawn_*/r1_*density*/lvl_corridor_* knobs + the corridor_summary row.
##
## End-cause driving (headless, no rendering / no input simulation) mirrors the M1.2
## driver: extract -> GameState.extract_and_end_run(); death -> fail_run(&"death");
## timeout -> fail_run(&"timeout"). Per-knob LOGIC is unit-tested in test_hazard_spread
## (J2), test_per_room_density (J3), test_corridor_lever / test_corridor_summary_row (J4),
## test_run_config / test_config_menu (J1 preset + 46-knob coverage); here we verify the
## ASSEMBLED M1.3 build end-to-end.

const MAIN_GAME_PATH := "res://scenes/game/main_game.tscn"
const MAIN_GAME_SCRIPT := "res://scenes/game/main_game.gd"
const LOG_PATH := "user://telemetry/run_log.jsonl"
const RunConfigScript := preload("res://data/run_config/run_config.gd")
const SettingsScript := preload("res://systems/settings/settings.gd")
const BANDGEN_CONFIG_PATH := "res://data/bandgen_config.tres"
const PIECE_CATALOG_PATH := "res://data/piece_catalog.tres"
const PIECE_CATALOG_EXT_PATH := "res://data/piece_catalog_ext.tres"

## The locked M1.0/M1.1/M1.2 all-off baseline fingerprint (sample seed 12345 -> 12 pieces).
## Determinism is sacred: the all-off control must stay byte-identical to this.
const BASELINE_FP := "e943ac9c8bc1"
const BASELINE_FP_SEED := 12345

## The stale SHA M1.2's I5 fixed -- the build id must NO LONGER be this frozen value.
const STALE_SHA := "852b6e2"

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
		printerr("RG1 M1.3 VERIFY FAIL: EventBus / Telemetry / GameState autoload missing")
		return 1

	# Clean meta slate so money/bank deltas are interpretable.
	var empty: Array[JunkItem] = []
	_gs.banked_junk = empty.duplicate()

	# ---- M0: all-off determinism is byte-identical to the locked baseline --------
	# Pure-generator check (no scene), run FIRST so a determinism regression fails fast.
	_verify_baseline_fingerprint()

	# ---- Build identity is REAL (carried from M1.2 I5) ---------------------------
	_verify_build_identity()

	# ---- J1: the default play-preset is the F1 stack, trap-free, baseline-safe ---
	# Pure-config checks (no scene) — assert the preset shape + that it never mutates
	# the code-level all-off default (the load-bearing M1.3 contract, Breakdown §2).
	_verify_default_preset_shape()

	# ---- J2/J3 plan-level + J4 corridor lever (pure generator/plan, no loop) ------
	# Build + grade a REAL band and drive the assembled build's own spawn-plan helpers,
	# exactly as the J2/J3 unit suites do, so the multi-depth spread + density + cap are
	# asserted EXACTLY (deterministic), not inferred from timing-sensitive runtime rows.
	_verify_j2_spread_plan()
	_verify_j3_density_plan()
	_verify_j4_corridor_lever()

	var scene := load(MAIN_GAME_PATH) as PackedScene
	if scene == null:
		printerr("RG1 M1.3 VERIFY FAIL: could not load %s" % MAIN_GAME_PATH)
		return 1
	_game = scene.instantiate() as MainGame
	add_child(_game)
	# M1.6 (M2): main_game is dive-only and self-starts on _ready; no %ConfigMenu rail to grab
	# (it moved to M4's P-overlay). Each V-row stages its RunConfig via GameState.stage_dive_config.
	await get_tree().process_frame   # _ready: fixtures, self-start, R2/R3 connect

	# Persistent-node wiring (carried over from M1.2 RG1 — still required for M1.3).
	_verify_persistent_wiring()

	# J1 (assembled): the CFG rail boots seeded with the default play-preset, NOT all-off.
	_verify_cfg_boots_default_preset()

	# Telemetry ON for the whole sweep so every run writes a JSONL row set.
	_remove_log()
	_tel.set_enabled(true)
	if not _tel.is_enabled():
		_failures.append("set_enabled(true) did not enable telemetry")

	# ---- Drive the M1.3 verify matrix through the assembled loop -----------------
	# M-rows: the all-off control, the default preset (the boot config), each fix in
	# isolation, then everything stacked.
	await _drive_run(_all_off(), &"extract", "M0-all-off")            # control + snapshot
	await _drive_run(_default_preset(), &"extract", "M1-default-preset")  # the F1 boot stack
	await _drive_run(_j2_spread(), &"death", "M2-j2-spread")          # even_spread hazards -> death
	await _drive_run(_j3_density(), &"extract", "M3-j3-density")      # per-room density fills rooms
	await _drive_run(_j4_corridors(), &"extract", "M4-j4-corridors")  # corridor lever biased down
	await _drive_run(_all_on(), &"timeout", "M5-all-on")             # everything stacked

	# Flush + close so the file is fully on disk before we read it.
	_tel.set_enabled(false)

	# ---- Inspect the JSONL ------------------------------------------------------
	_inspect_log()

	# ---- Multiple runs / session, no leaks (carried from M1.2 V12/V18) ----------
	await _verify_repeat_and_exits()

	# ---- Config carry-forward incl. the default-preset knobs --------------------
	await _verify_carry_forward()

	# ---- Human-deferred (visual / felt) rows ------------------------------------
	_note_human_deferred()

	_cleanup()

	if _failures.is_empty():
		print("RG1 M1.3 VERIFY OK -- assembled M1.3 build runs the full loop. All-off control is ",
			"byte-identical to the locked baseline (fp=%s); build id is REAL; the default " % BASELINE_FP,
			"play-preset is the trap-free F1 stack (LVL+R1 on, R4 maze-only, R2/R3 off) and does ",
			"NOT leak into the all-off control (J1); even_spread spawns hazards at MULTIPLE depths ",
			"while single_gate reproduces the M1.2 single-depth placement (J2); per-room density ",
			"fills big rooms scaled by area, bounded by the per-room cap + band ceiling<=64 (J3); ",
			"the corridor lever MOVES the band fp for a fixed seed yet the neutral default stays ",
			"byte-identical + deterministic (J4); every run emits one corridor_summary row with ",
			"corridor_frac in [0,1], SCHEMA_VERSION + run_ended arity unchanged; the snapshot ",
			"carries all 46 knobs incl. the J2/J3/J4 keys; duration_s real; carry-forward + ",
			"repeated runs with no leak. %d rows headless-verified; %d deferred."
			% [_headless_pass_count(), _human_deferred.size()])
		return 0
	for f in _failures:
		printerr("RG1 M1.3 VERIFY FAIL: ", f)
	return 1


# --- M0: all-off determinism unmoved (pure generator, no scene) ----------------

func _verify_baseline_fingerprint() -> void:
	var cfg := load(BANDGEN_CONFIG_PATH) as BandGenConfig
	var pc = load(PIECE_CATALOG_PATH)
	if cfg == null or pc == null:
		_failures.append("M0: missing bandgen config / baseline catalog for fingerprint check")
		return
	var catalog: Array[ZonePieceData] = pc.pieces
	# rc == null is the literal M1.x baseline path; an all-off RunConfig must match it too.
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


# --- Build identity is real, not the stale frozen SHA (carried from M1.2 I5) ----

func _verify_build_identity() -> void:
	var id := BuildVersion.id()
	var sha := BuildVersion.short_sha()
	if sha == STALE_SHA:
		_failures.append("build SHA is STILL the stale frozen %s -- version.gd not reading real HEAD" % STALE_SHA)
	if not id.begins_with("m1-"):
		_failures.append("build id '%s' does not carry the m1-<date>-<sha> shape" % id)
	if sha == BuildVersion.FALLBACK_SHA:
		_human_deferred.append("build SHA is the 0000000 un-stamped sentinel -- confirm the stamp step ran for the shipped build")


# --- J1: default play-preset shape + the load-bearing baseline-safety contract --

## The default play-preset must be (a) the F1 stack, (b) provably trap-free, and (c)
## a SEPARATE artifact that never mutates the code-level all-off default. This is the
## load-bearing M1.3 contract (Breakdown §2): make_default_play_preset() builds on a
## fresh RunConfig.new(), so RunConfig.new() stays byte-identical to the baseline.
func _verify_default_preset_shape() -> void:
	var preset := RunConfigScript.make_default_play_preset() as RunConfig
	if preset == null:
		_failures.append("J1: make_default_play_preset() returned null")
		return
	# (a) The F1 stack: LVL + R1 on, R4 maze-only (occlusion off), R2/R3 OFF.
	if not preset.lvl_enabled:
		_failures.append("J1: default preset lvl_enabled is false (F1 wants level scale ON)")
	if not preset.r1_enabled:
		_failures.append("J1: default preset r1_enabled is false (F1 wants the pursuing hazard ON)")
	if not preset.r4_enabled:
		_failures.append("J1: default preset r4_enabled is false (F1 wants the maze ON)")
	if preset.r2_enabled or preset.r3_enabled:
		_failures.append("J1: default preset has R2/R3 ON (F1 = R2 and R3 OFF by default)")
	# R4 is maze-only: branching on, but vision/fog/lost-proxy OFF (match-what-I-played).
	if preset.r4_vision_radius > 0.0 or preset.r4_fog_enabled or preset.r4_lost_proxy_threshold > 0.0:
		_failures.append("J1: default preset R4 occlusion/fog/lost is ON (must be maze-only / occlusion OFF)")
	if not (preset.r4_max_branch_depth > 0 and (preset.r4_branch_chance_base > 0.0 or preset.r4_branch_per_depth > 0.0)):
		_failures.append("J1: default preset R4 maze is not actually branching (maze-only means branching ON)")
	# J2 wired into the preset: even_spread, count >= 4, a non-zero spread-min-depth.
	if preset.r1_spawn_distribution != 1:
		_failures.append("J1/J2: default preset r1_spawn_distribution != even_spread (got %d)" % preset.r1_spawn_distribution)
	if preset.r1_spawn_count < 4:
		_failures.append("J1/J2: default preset r1_spawn_count=%d < 4 (spread wants several hazards)" % preset.r1_spawn_count)
	# J3 wired into the preset: density on with a MANDATORY per-room cap.
	if preset.r1_per_room_density <= 0.0:
		_failures.append("J1/J3: default preset r1_per_room_density<=0 (density must be ON in the preset)")
	if preset.r1_density_per_room_cap <= 0:
		_failures.append("J1/J3: default preset r1_density_per_room_cap<=0 (the per-room cap is MANDATORY)")
	# J4 wired into the preset: corridors biased DOWN (non-neutral).
	if preset.lvl_corridor_weight_mult >= 1.0 and not preset.lvl_short_corridors:
		_failures.append("J1/J4: default preset does not bias corridors down (mult=%f, short=%s)"
			% [preset.lvl_corridor_weight_mult, str(preset.lvl_short_corridors)])
	# (b) Trap-free: every enabled opposition's load-bearing magnitude is non-inert.
	var inert := preset.inert_enabled_oppositions()
	if not inert.is_empty():
		_failures.append("J1/BUG6: default preset has an inert enabled opposition: %s" % str(inert))
	# (c) The preset never mutates the code-level all-off default.
	var fresh := RunConfigScript.new() as RunConfig
	if not fresh.all_oppositions_disabled():
		_failures.append("J1: RunConfig.new() is NOT all-off after make_default_play_preset() -- the preset leaked into the default!")
	if not (is_equal_approx(fresh.lvl_corridor_weight_mult, 1.0) and not fresh.lvl_short_corridors
			and is_equal_approx(fresh.lvl_size_mult, 1.0) and fresh.r1_spawn_count == 0):
		_failures.append("J1: RunConfig.new() defaults moved after building the preset (baseline contaminated)")


# --- J2 (plan-level): even_spread spawns at MULTIPLE distinct depths -------------

## Build + grade a REAL band, then drive the assembled build's own _hazard_spawn_depths
## plan (the same helper start_new_run() calls) and assert that:
##   - even_spread with count>=4 spans >1 distinct depth_index (the F2 fix), and
##   - single_gate collapses to ONE depth (the M1.2-equivalent placement).
## This is the EXACT, deterministic form of the matrix "J2 spread takes effect" row —
## stronger than reading timing-sensitive runtime opposition_event(&"awoke") depths.
func _verify_j2_spread_plan() -> void:
	var band := _graded_band(BASELINE_FP_SEED)
	if band == null:
		_failures.append("J2: could not build a graded band for the spread-plan check")
		return
	var mg = (load(MAIN_GAME_SCRIPT) as GDScript).new()

	# even_spread, count 5, min-depth 1 — the preset's J2 shape.
	var even := RunConfigScript.new() as RunConfig
	even.r1_enabled = true
	even.r1_spawn_count = 5
	even.r1_spawn_distribution = 1   # even_spread
	even.r1_spread_min_depth = 1
	var ev: Array = mg._hazard_spawn_depths(band, even)
	if ev.size() != 5:
		_failures.append("J2: even_spread produced %d depths, expected 5 (== r1_spawn_count)" % ev.size())
	var distinct := {}
	for d in ev:
		distinct[d] = true
	if distinct.size() <= 1:
		_failures.append("J2: even_spread collapsed to a single depth %s (the F2 spread did NOT take effect)" % str(ev))

	# single_gate, count 5 — the M1.2-equivalent: ALL at the one threshold depth.
	var single := RunConfigScript.new() as RunConfig
	single.r1_enabled = true
	single.r1_spawn_count = 5
	single.r1_spawn_distribution = 0   # single_gate
	single.r1_depth_threshold = 2
	var sg: Array = mg._hazard_spawn_depths(band, single)
	var sg_distinct := {}
	for d in sg:
		sg_distinct[d] = true
	if sg_distinct.size() != 1:
		_failures.append("J2: single_gate spread across %s -- it must reproduce the M1.2 single-depth placement" % str(sg))

	mg.free()
	_free_band(band)


# --- J3 (plan-level): per-room density fills big rooms, bounded by the caps ------

## Drive the assembled build's _density_spawn_positions plan on graded bands:
##   - density 0  → 0 nodes (the M1.2 control), and
##   - density > 0 → extra hazards in big rooms scaled by floor_cells area, and
##   - the per-room cap + band ceiling (<=64) bound the worst case.
func _verify_j3_density_plan() -> void:
	var mg = (load(MAIN_GAME_SCRIPT) as GDScript).new()

	# A real graded band: density OFF must yield zero density nodes (M1.2 control).
	var band := _graded_band(BASELINE_FP_SEED)
	var rc_off := RunConfigScript.new() as RunConfig
	rc_off.r1_enabled = true
	rc_off.r1_per_room_density = 0.0
	var off: Array = mg._density_spawn_positions(band, rc_off)
	if off.size() != 0:
		_failures.append("J3: r1_per_room_density=0 produced %d density nodes -- must be 0 (M1.2 control)" % off.size())

	# Density ON: a big room must earn >= 1 density hazard scaled by its floor-cell area.
	var big := _make_graded_band([200])   # one 200-cell room
	var rc_on := RunConfigScript.new() as RunConfig
	rc_on.r1_enabled = true
	rc_on.r1_per_room_density = 1.0
	rc_on.r1_density_metric = 0          # cell_area
	rc_on.r1_density_per_room_cap = 3
	var on_big: Array = mg._density_spawn_positions(big, rc_on)
	# floor(1.0 * 200 / 96) = 2, capped at 3 → expect >= 1 (rooms get filled).
	if on_big.size() < 1:
		_failures.append("J3: a 200-cell room earned %d density hazards at density 1.0 -- expected >=1 (rooms not filled)" % on_big.size())

	# The band ceiling bounds the worst case: many huge rooms × high density, capped per room,
	# must never exceed RunConfig.R1_DENSITY_BAND_CEILING (64).
	var huge_areas: Array = []
	for _i in 40:
		huge_areas.append(400)
	var huge := _make_graded_band(huge_areas)
	var rc_explode := RunConfigScript.new() as RunConfig
	rc_explode.r1_enabled = true
	rc_explode.r1_per_room_density = 4.0
	rc_explode.r1_density_metric = 0
	rc_explode.r1_density_per_room_cap = 8
	var exploded: Array = mg._density_spawn_positions(huge, rc_explode)
	if exploded.size() > RunConfigScript.R1_DENSITY_BAND_CEILING:
		_failures.append("J3: worst-case density spawned %d nodes > the %d band ceiling (perf guard breached)"
			% [exploded.size(), RunConfigScript.R1_DENSITY_BAND_CEILING])

	# Determinism: the plan is a pure function of (band, rc) — same inputs, same output.
	var d1: Array = mg._density_spawn_positions(big, rc_on)
	var d2: Array = mg._density_spawn_positions(big, rc_on)
	if str(d1) != str(d2):
		_failures.append("J3: density plan not deterministic (same band+rc gave different positions)")

	mg.free()
	_free_band(band)
	_free_band(big)
	_free_band(huge)


# --- J4: the corridor lever moves the band fp; the neutral default stays identical -

func _verify_j4_corridor_lever() -> void:
	var cfg := load(BANDGEN_CONFIG_PATH) as BandGenConfig
	var pc = load(PIECE_CATALOG_PATH)
	var pce = load(PIECE_CATALOG_EXT_PATH)
	if cfg == null or pc == null or pce == null:
		_failures.append("J4: missing bandgen config / catalogs for the corridor-lever check")
		return
	var baseline_catalog: Array[ZonePieceData] = pc.pieces
	var ext_catalog: Array[ZonePieceData] = pce.pieces

	# (a) NEUTRAL lever → fp byte-identical to the locked baseline.
	var neutral := RunConfigScript.new() as RunConfig   # mult 1.0, short false
	var fp_neutral := BandGenerator.new().generate(BASELINE_FP_SEED, cfg, baseline_catalog, neutral).fingerprint().substr(0, 12)
	if fp_neutral != BASELINE_FP:
		_failures.append("J4: neutral corridor lever fp=%s != locked %s -- the lever moved the all-off control!"
			% [fp_neutral, BASELINE_FP])

	# (b) NON-NEUTRAL lever MOVES the band (fixed seed) yet stays deterministic. Use the EXT
	# catalog (it holds the long hall + the full corridor family the preset sweeps).
	var ext_seed := 777
	var fp_ext_neutral := _fp(cfg, ext_catalog, _corridor_rc(1.0, false), ext_seed)
	var fp_mult := _fp(cfg, ext_catalog, _corridor_rc(0.25, false), ext_seed)
	if fp_mult == fp_ext_neutral:
		_failures.append("J4: lvl_corridor_weight_mult=0.25 did NOT change the band (lever inert)")
	if fp_mult != _fp(cfg, ext_catalog, _corridor_rc(0.25, false), ext_seed):
		_failures.append("J4: lvl_corridor_weight_mult=0.25 not deterministic")
	var fp_short := _fp(cfg, ext_catalog, _corridor_rc(1.0, true), ext_seed)
	if fp_short == fp_ext_neutral:
		_failures.append("J4: lvl_short_corridors=true did NOT change the band (lever inert)")
	if fp_short != _fp(cfg, ext_catalog, _corridor_rc(1.0, true), ext_seed):
		_failures.append("J4: lvl_short_corridors=true not deterministic")


# --- Persistent-node wiring (carried from M1.2 RG1) ----------------------------

func _verify_persistent_wiring() -> void:
	var rc := _game.get_node_or_null("ReturnCost")
	if rc == null:
		_failures.append("ReturnCost (R2) not a persistent child of MainGame")
	elif rc.get("dive_clock") == null:
		_failures.append("ReturnCost.dive_clock not injected (DiveClock node)")
	var em := _game.get_node_or_null("ExposureMeter")
	if em == null:
		_failures.append("ExposureMeter (R3) not a persistent child of MainGame")
	elif not em.is_in_group(&"r3_exposure_meter"):
		_failures.append("ExposureMeter not in group 'r3_exposure_meter'")
	# M1.6 (M2): the SellScreen + its "Back to Config" button are retired (run-end auto-returns
	# to the Hub via the App router); the old node-exists assertion is dropped with the node.


# --- J1 (assembled): the dive resolves the default play-preset with no config staged ----

## M1.6 (M2): the build must boot the F1 stack, not all-off. With the embedded ConfigMenu
## gone, the dive resolves its config via GameState.dive_config_or_default() — which returns
## make_default_play_preset() when nothing is staged. We clear any staged dive config (stage
## null) and assert the default-resolved config is the F1 stack, the J1 contract unchanged.
func _verify_cfg_boots_default_preset() -> void:
	GameState.stage_dive_config(null)
	var working: RunConfig = GameState.dive_config_or_default()
	if working == null:
		_failures.append("J1: GameState.dive_config_or_default() returned null at boot")
		return
	# The boot config must be a real play config, not the all-off control.
	if working.all_oppositions_disabled():
		_human_deferred.append("J1: CFG booted all-off rather than the default play-preset -- confirm config_menu seeds make_default_play_preset() (deferred: may be a fixture-mode boot)")
	elif not (working.lvl_enabled and working.r1_enabled and working.r4_enabled
			and not working.r2_enabled and not working.r3_enabled):
		_failures.append("J1: CFG boot config is not the F1 stack (lvl=%s r1=%s r4=%s r2=%s r3=%s)"
			% [str(working.lvl_enabled), str(working.r1_enabled), str(working.r4_enabled),
				str(working.r2_enabled), str(working.r3_enabled)])


# --- Config factories ----------------------------------------------------------

## M1.6 (M2): stage `cfg` as the dive's RunConfig via GameState.stage_dive_config — the dive
## reads it on its next self-start through GameState.dive_config_or_default(). The embedded
## ConfigMenu rail is gone (dive-only refactor), so we stage directly instead of poking a menu.
func _stage_menu_config(cfg: RunConfig) -> void:
	GameState.stage_dive_config(cfg)


func _all_off() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-m13-M0-all-off"
	return c


## J1: the named default play-preset (the F1 boot stack), tagged for the sweep.
func _default_preset() -> RunConfig:
	var c := RunConfigScript.make_default_play_preset() as RunConfig
	c.build_tag = "rg1-m13-M1-default-preset"
	c.seed_override = 12345   # pin so the run is reproducible
	# r1_catch_kills=true in the preset; keep it OFF for the driven run so the hazard can't
	# pre-empt our chosen extract end-cause -- we control the end-cause explicitly.
	c.r1_catch_kills = false
	return c


## J2 isolation: R1 on, even_spread, count 5 (>=4), min-depth 1 -- the F2 fix, fatal so
## the catch routes a death end-cause in the assembled loop.
func _j2_spread() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-m13-M2-j2-spread"
	c.r1_enabled = true
	c.r1_depth_threshold = 0
	c.r1_chase_speed = 40.0
	c.r1_catch_radius = 24.0            # clears the 24px physical floor so it can catch
	c.r1_catch_radius_per_depth = 4.0
	c.r1_catch_kills = true
	c.r1_spawn_count = 5
	c.r1_spawn_distribution = 1         # even_spread (F2)
	c.r1_spread_min_depth = 1
	return c


## J3 isolation: R1 on, per-room density on with the mandatory cap (no J2 spread budget --
## density-only), so density alone fills rooms. Non-fatal so we control the end-cause.
func _j3_density() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-m13-M3-j3-density"
	c.r1_enabled = true
	c.r1_depth_threshold = 0
	c.r1_chase_speed = 30.0
	c.r1_catch_radius = 24.0
	c.r1_catch_kills = false            # non-fatal: density is about filling, not killing here
	c.r1_spawn_count = 0                # density-only (no J2 spread budget)
	c.r1_per_room_density = 1.0
	c.r1_density_metric = 0             # cell_area
	c.r1_density_per_room_cap = 3       # mandatory cap
	c.r1_density_min_area = 64
	# Bigger rooms so density has something to fill.
	c.lvl_enabled = true
	c.lvl_room_count = 16
	c.lvl_size_mult = 4.0
	c.seed_override = 12345
	return c


## J4 isolation: the corridor lever biased down (non-neutral) on a level-scaled band.
func _j4_corridors() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-m13-M4-j4-corridors"
	c.lvl_enabled = true
	c.lvl_room_count = 16
	c.lvl_size_mult = 4.0
	c.lvl_corridor_weight_mult = 0.25   # corridors at quarter weight
	c.lvl_short_corridors = true        # drop the 16-cell long hall
	c.seed_override = 777
	return c


## Everything stacked: the default preset + R2/R3 added on top (non-fatal R1 so we can
## drive a timeout end-cause), so all M1.3 seams compose in one run.
func _all_on() -> RunConfig:
	var c := RunConfigScript.make_default_play_preset() as RunConfig
	c.build_tag = "rg1-m13-M5-all-on"
	c.r1_catch_kills = false            # non-fatal so the chosen end-cause wins
	c.seed_override = 4242
	# R2 + R3 on (the preset leaves them off): exercise the full opposition set together.
	c.r2_enabled = true
	c.r2_mechanism = 2                  # egress_toll
	c.r2_toll_resource = 1              # exposure (also exercises the BUG5 path)
	c.r2_cost_magnitude = 4.0
	c.r2_cost_per_depth = 2.0
	c.r2_depth_threshold = 0
	c.r3_enabled = true
	c.r3_base_climb_rate = 150.0
	c.r3_rate_per_depth = 15.0
	c.r3_threshold_levels = PackedFloat32Array([5.0, 15.0])
	c.r3_penalty_kind = 1
	c.r3_penalty_magnitude = 0.2
	c.r3_max_forces_loss = false
	return c


# --- One run: stage cfg, start, exercise oppositions, end with `cause` ----------

func _drive_run(cfg: RunConfig, cause: StringName, tag: String) -> void:
	_stage_menu_config(cfg)
	_game.start_new_run()
	await_idle()

	if not _gs.run_active:
		_failures.append("%s: run not active after start_new_run" % tag)
		return

	# Nudge the live within-band depth so depth-gated oppositions fire.
	for d in [1, 2, 3, 4, 5]:
		_gs.set_current_depth(d, d)
		await_idle()

	# R4 nav rows are player-position driven -- script the player across real floor cells.
	if cfg.r4_enabled:
		await _walk_player_for_nav()
	# Let R3's per-frame climb accumulate so crossings fire.
	for _i in 20:
		await get_tree().process_frame
	# Retreat (dist_to_gate decreases) so R2's retreat-cost path triggers.
	for d in [4, 3, 2, 1, 0]:
		_gs.set_current_depth(d, d)
		await_idle()

	match cause:
		&"extract":
			_gs.extract_and_end_run()
		&"death":
			_gs.fail_run(&"death")
		&"timeout":
			_gs.fail_run(&"timeout")
		_:
			_failures.append("%s: unknown end-cause %s" % [tag, str(cause)])
	await_idle()

	if _gs.run_active:
		_failures.append("%s: run_active still true after end-cause %s" % [tag, str(cause)])

	_dismiss_sell_screen()
	await_idle()


func await_idle() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame


## Script the player across the band's floor cells so R4's position-driven nav rows fire
## (identical strategy to the M1.2 driver).
func _walk_player_for_nav() -> void:
	var junction_map: Dictionary = _game._cell_to_junction
	var cell_px: int = _game._band_cell_size_px
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null or junction_map.is_empty():
		return
	var plain_cell: Vector2i = Vector2i(0, 0)
	var fork_cell: Vector2i = Vector2i(0, 0)
	var have_plain := false
	var have_fork := false
	for cell in junction_map.keys():
		var meta: Vector2i = junction_map[cell]
		if meta.y >= 2 and not have_fork:
			fork_cell = cell
			have_fork = true
		elif meta.y < 2 and not have_plain:
			plain_cell = cell
			have_plain = true
		if have_plain and have_fork:
			break
	if not have_fork:
		return
	if have_plain:
		_teleport_player(player, plain_cell, cell_px)
		await_idle()
		await_idle()
	_teleport_player(player, fork_cell, cell_px)
	for _i in 8:
		if "velocity" in player:
			player.velocity = Vector2(40, 0)
		await get_tree().physics_frame
		await get_tree().process_frame


func _teleport_player(player: Node2D, cell: Vector2i, cell_px: int) -> void:
	player.global_position = Vector2(cell * cell_px) + Vector2(cell_px, cell_px) * 0.5


# M1.6 (M2): the SellScreen is retired (run-end auto-returns to the Hub via the App router).
# Kept as a no-op (belt-and-braces unpause) so the V-row call sites need no churn.
func _dismiss_sell_screen() -> void:
	get_tree().paused = false


# --- JSONL inspection: snapshot keys (incl. J2/J3/J4) + gating + corridor_summary -

func _inspect_log() -> void:
	if not FileAccess.file_exists(LOG_PATH):
		_failures.append("no telemetry log written while enabled")
		return
	var rows := _read_rows(LOG_PATH)
	var started_by_tag := {}
	var ended_rows: Array = []
	var corridor_rows: Array = []
	var current_tag := ""
	var rows_in_run := {}
	# The full key set MUST appear in every snapshot (V13 generalised -- assert as a SET
	# against the live to_flat_dict(), and explicitly name the new M1.3 keys).
	var expected_keys := (RunConfigScript.new() as RunConfig).to_flat_dict().keys()
	var m13_new_keys := ["r1_spawn_distribution", "r1_spread_min_depth", "r1_per_room_density",
		"r1_density_metric", "r1_density_rooms_only", "r1_density_min_area", "r1_density_per_room_cap",
		"lvl_corridor_weight_mult", "lvl_short_corridors", "lvl_loot_density_per_area"]

	for r in rows:
		var t := String(r.get("type", ""))
		# Schema v1 is locked: NO row may carry a bumped schema version.
		if int(r.get("v", -1)) != TelemetrySchema.SCHEMA_VERSION:
			_failures.append("a row carries v=%s != SCHEMA_VERSION %d (schema bumped!)"
				% [str(r.get("v")), TelemetrySchema.SCHEMA_VERSION])
		if t == "run_started":
			var data: Dictionary = r.get("data", {})
			var snap: Dictionary = data.get("run_config", {})
			current_tag = String(snap.get("build_tag", ""))
			started_by_tag[current_tag] = snap
			rows_in_run[current_tag] = []
			# V13: full key set present (all 46 knobs as a SET, not a magic count).
			if snap.is_empty():
				_failures.append("V13: run_started carries an empty run_config snapshot")
			else:
				for k in expected_keys:
					if not snap.has(k):
						_failures.append("V13: run_config snapshot missing key '%s'" % k)
				for k in m13_new_keys:
					if not snap.has(k):
						_failures.append("V13/M1.3: snapshot missing the new M1.3 knob '%s'" % k)
			# Build id present + real (not stale) on EVERY run_started row.
			var build_id := String(data.get("build", ""))
			if build_id == "":
				_failures.append("run_started.data.build is empty")
			elif build_id.find(STALE_SHA) != -1:
				_failures.append("run_started.data.build '%s' carries the stale SHA %s" % [build_id, STALE_SHA])
		elif t == "run_ended":
			ended_rows.append(r)
		elif t == "corridor_summary":
			corridor_rows.append(r)
		else:
			if current_tag != "" and rows_in_run.has(current_tag):
				(rows_in_run[current_tag] as Array).append(t)

	# Every config we ran appears.
	for tag in ["rg1-m13-M0-all-off", "rg1-m13-M1-default-preset", "rg1-m13-M2-j2-spread",
			"rg1-m13-M3-j3-density", "rg1-m13-M4-j4-corridors", "rg1-m13-M5-all-on"]:
		if not started_by_tag.has(tag):
			_failures.append("V13: no run_started row for config '%s'" % tag)

	# V2: R1's legacy hazard_awoke/hazard_caught rows retired → the generic
	# opposition_event row (event=&"awoke"/&"hit_player") carries the R1 moments; each
	# check here is "at least one R1 opposition row appears", so it filters on the
	# generic type directly.
	var hazard_types := ["opposition_event"]
	var r2_types := ["return_cost_incurred"]
	var r3_types := ["exposure_crossed", "exposure_penalty", "exposure_meter_changed"]
	var r4_types := ["nav_branch_taken", "nav_lost_proxy"]

	# M0: all-off run has NO opposition rows (the baseline-contamination guard).
	var off_rows: Array = rows_in_run.get("rg1-m13-M0-all-off", [])
	for opp in hazard_types + r2_types + ["exposure_crossed", "exposure_penalty"] + r4_types:
		if off_rows.has(opp):
			_failures.append("M0: all-off run emitted opposition row '%s' (baseline contaminated)" % opp)

	# M1/default-preset: R1 + R4 rows fire (the F1 stack runs for real).
	_assert_any_row("M1/default-preset-R1", "rg1-m13-M1-default-preset", hazard_types, rows_in_run)
	_assert_any_row("M1/default-preset-R4", "rg1-m13-M1-default-preset", r4_types, rows_in_run)

	# M2/J2: the spread hazards awaken (a hazard row fires; the catch->death is the end-cause).
	_assert_any_row("M2/J2", "rg1-m13-M2-j2-spread", hazard_types, rows_in_run)

	# M3/J3: density-only R1 still awakens a hazard (density nodes are real hazards).
	_assert_any_row("M3/J3", "rg1-m13-M3-j3-density", hazard_types, rows_in_run)

	# M5/all-on: every opposition family composes -- at least one row from each.
	for fam in [hazard_types, r2_types, r3_types, r4_types]:
		_assert_any_row("M5/all-on", "rg1-m13-M5-all-on", fam, rows_in_run)

	# corridor_summary: EXACTLY one per run (6 driven runs → 6 rows), each well-formed.
	if corridor_rows.size() != 6:
		_failures.append("corridor_summary: expected exactly 6 rows (one per driven run), got %d" % corridor_rows.size())
	for cr in corridor_rows:
		var cd: Dictionary = cr.get("data", {})
		for k in ["corridor_s", "room_s", "corridor_frac"]:
			if not cd.has(k):
				_failures.append("corridor_summary row missing '%s'" % k)
		var frac := float(cd.get("corridor_frac", -1.0))
		if frac < 0.0 or frac > 1.0:
			_failures.append("corridor_summary corridor_frac out of [0,1]: %f" % frac)

	# run_ended arity intact + duration_s real on EVERY run + causes observed.
	var seen_causes := {}
	for er in ended_rows:
		var ed: Dictionary = er.get("data", {})
		# Arity unchanged: the M1.0 fields are all present, nothing renamed.
		for f in ["cause", "duration_s", "banked_total", "lost_total", "max_depth"]:
			if not ed.has(f):
				_failures.append("run_ended.data missing M1.0 field '%s' (arity changed)" % f)
		seen_causes[String(ed.get("cause", ""))] = true
		if float(ed.get("duration_s", -1.0)) <= 0.0:
			_failures.append("run_ended.duration_s=%s is not > 0 (duration regression)"
				% str(ed.get("duration_s", "absent")))
		if int(ed.get("max_depth", -1)) < 1:
			_failures.append("run_ended.max_depth < 1 -- depth driver not reflected")
	for cause in ["extract", "death", "timeout"]:
		if not seen_causes.has(cause):
			_failures.append("end-cause '%s' never observed in run_ended rows" % cause)


func _assert_any_row(tag: String, config_tag: String, types: Array, rows_in_run: Dictionary) -> void:
	var run_rows: Array = rows_in_run.get(config_tag, [])
	for ty in types:
		if run_rows.has(ty):
			return
	_failures.append("%s: config '%s' emitted none of %s (opposition row missing)"
		% [tag, config_tag, str(types)])


# --- Multiple runs / session, no leak (carried from M1.2 V12/V18) ---------------

func _verify_repeat_and_exits() -> void:
	var container := _game.get_node("BandContainer")
	var settled_counts: Array[int] = []
	for _i in 4:
		_stage_menu_config(_default_preset())   # the boot config, repeated
		_game.start_new_run()
		await_idle()
		if not _gs.run_active:
			_failures.append("V12/V18: a repeated run failed to start (soft-lock)")
		_gs.extract_and_end_run()
		await_idle()
		_dismiss_sell_screen()
		for _j in 4:
			await get_tree().process_frame
		settled_counts.append(container.get_child_count())
	if settled_counts.size() == 4:
		var lo: int = settled_counts.min()
		var hi: int = settled_counts.max()
		if lo > 0 and hi > lo * 2:
			_failures.append("V12: settled BandContainer counts %s grew >2x -- possible leak" % str(settled_counts))
	if _gs.run_active:
		_failures.append("V18: run still active after the repeat loop ended (stuck state)")


# --- Config carry-forward incl. the default-preset knobs (V16) ------------------

func _verify_carry_forward() -> void:
	# Stage the default preset (lvl + r1 + r4 on), run it, then Continue (NO menu) -- the
	# next run must reuse the SAME config, the M1.3 knobs included.
	_stage_menu_config(_default_preset())
	_game.start_new_run()
	await_idle()
	var first_ok: bool = _gs.active_run_config != null \
		and bool(_gs.active_run_config.lvl_enabled) \
		and _gs.active_run_config.r1_spawn_distribution == 1 \
		and _gs.active_run_config.r1_per_room_density > 0.0
	_gs.extract_and_end_run()
	await_idle()
	_dismiss_sell_screen()
	_game.start_new_run()   # door 2 (Continue) -- re-reads the unchanged menu config
	await_idle()
	var second_ok: bool = _gs.active_run_config != null \
		and bool(_gs.active_run_config.lvl_enabled) \
		and _gs.active_run_config.r1_spawn_distribution == 1 \
		and _gs.active_run_config.r1_per_room_density > 0.0
	if not (first_ok and second_ok):
		_failures.append("V16: the M1.3 preset config did not carry forward across Continue (first=%s second=%s)"
			% [str(first_ok), str(second_ok)])
	_gs.extract_and_end_run()
	await_idle()
	_dismiss_sell_screen()


# --- Human-deferred rows -------------------------------------------------------

func _note_human_deferred() -> void:
	_human_deferred.append("J1: the build BOOTS into the default play-preset (not all-off) -- visible in the CFG rail at launch -- checklist")
	_human_deferred.append("J2: danger at MULTIPLE depths feels right (not one gate-wall) -- checklist")
	_human_deferred.append("J3: big rooms feel CHARGED not empty (density fills them) -- checklist")
	_human_deferred.append("J4: the halls feel SHORTER / less dead-time between rooms -- checklist")
	_human_deferred.append("J5: the depth counter reads 'Depth N / max' bottom-left and tracks room depth -- checklist")
	_human_deferred.append("size-40 'void feel' window: at lvl_size_mult ~40 do huge rooms read as awe, not emptiness? -- checklist")
	print("RG1 M1.3 human-deferred (manual playtest checklist): ")
	for h in _human_deferred:
		print("  - ", h)


func _headless_pass_count() -> int:
	# baseline-fp · build-id · default-preset-shape (J1) · J2-spread-plan · J3-density-plan ·
	# J4-corridor-lever · persistent-wiring · CFG-boots-preset · 6 driven configs (snapshot+gating)
	# · corridor_summary 6-row · duration-real · carry-forward · repeat/no-leak · all-off-no-opp.
	return 16


# --- Helpers -------------------------------------------------------------------

## Build a REAL graded band for the spawn-plan checks: generate from the baseline catalog,
## then grade (sets depth_index + band.max_depth) exactly as main_game._build_band does.
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


## A graded linear band with the given per-piece floor-cell areas (mirrors the J3 unit
## suite's _make_band: pieces at depth 0..N-1, generic room ids, band.max_depth set).
func _make_graded_band(areas: Array) -> Band:
	var band := Band.new()
	var max_depth: int = areas.size() - 1
	for d in areas.size():
		var area: int = areas[d]
		var p := PlacedPiece.new()
		p.piece_id = StringName("piece_room_%d" % d)
		p.offset_cell = Vector2i(d * 100, 0)
		p.depth_index = d
		p.depth_norm = float(d) / float(max_depth) if max_depth > 0 else 0.0
		var cells: Array[Vector2i] = []
		for k in area:
			cells.append(Vector2i(d * 100 + (k % 20), k / 20))
		p.floor_cells = cells
		band.pieces.append(p)
	band.max_depth = max_depth
	return band


func _corridor_rc(mult: float, short_corridors: bool) -> RunConfig:
	var rc := RunConfigScript.new() as RunConfig
	rc.lvl_corridor_weight_mult = mult
	rc.lvl_short_corridors = short_corridors
	return rc


func _fp(cfg: BandGenConfig, catalog: Array[ZonePieceData], rc: RunConfig, seed: int) -> String:
	var band := BandGenerator.new().generate(seed, cfg, catalog, rc)
	return band.fingerprint().substr(0, 12)


## Band / PlacedPiece are ref-counted Resources -- no explicit free needed; this is a
## readability hook mirroring the M1.2 driver so the call sites read symmetrically.
func _free_band(_band: Band) -> void:
	pass


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
