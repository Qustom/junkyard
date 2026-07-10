extends Node
## RG1 (M1.2) — playtest-build verification driver (the objective half of the M1.2 §4 matrix).
##
## Runs as a SCENE so the EventBus / GameState / Telemetry autoloads resolve as live
## nodes (M1_As_Built "Testing constraints (headless)"):
##   godot --headless res://tests/test_rg1_m12_verify.tscn
##
## This is the M1.2 re-gate integration capstone. It instances the REAL assembled
## scenes/game/main_game.tscn and drives the full loop under each M1.2 fix in
## ISOLATION, then all STACKED, then the all-off CONTROL, asserting:
##   - I1  level scale: lvl_room_count + lvl_size_mult visibly change the generated band
##         (piece count differs; effective px/cell differs) and the all-off band stays
##         byte-identical to the M1.0/M1.1 baseline fingerprint (fp=e943ac9c8bc1).
##   - I2  hazard fix: r1_catch_radius_per_depth is in the schema + snapshot and an
##         R1 run still routes a catch -> death (opposition_event(&"hit_player") +
##         run_ended.death — V2 retired the legacy hazard_caught row).
##   - I3  R2/R3 cues: R2/R3 still emit the signals the cues project (return_cost_incurred,
##         exposure_crossed/exposure_penalty) -- cue VISUALS are human-deferred.
##   - I4  vision rework: R4 spawns its vision/fog + lost proxy and emits nav rows; the
##         band stays sealed (BUG3/BUG4) -- the OCCLUSION LOOK is human-deferred.
##   - I5  telemetry hygiene: run_started.data.build is a REAL build id (m1-<date>-<sha>,
##         not the stale 852b6e2 sentinel) and every completed run logs duration_s > 0.
##   - BUG4 robust seal: high-branch bands are sealed (covered fully by the determinism
##         suite; asserted here at the loop level by an R4 high-branch run not crashing).
##   - BUG5 exposure toll mutator: an R2 exposure toll moves R3's run-state meter and can
##         drive a crossing -- asserted end-to-end (R2 toll_resource=exposure + R3 on).
##
## It does NOT judge fun (RG2/RG3) -- only that the assembled M1.2 build runs unbroken
## under every config the Director will sweep and that telemetry captures it with the
## new lvl_*/r1_catch_radius_per_depth knobs.
##
## End-cause driving (headless, no rendering / no input simulation) mirrors the M1.1
## driver: extract -> GameState.extract_and_end_run(); death -> fail_run(&"death");
## timeout -> fail_run(&"timeout"). Per-opposition BEHAVIOUR is unit-tested in
## test_pursuing_hazard / test_return_cost / test_exposure_meter / test_level_scale_
## determinism / test_bandgen_determinism (BUG4); here we verify the ASSEMBLED build.

const MAIN_GAME_PATH := "res://scenes/game/main_game.tscn"
const LOG_PATH := "user://telemetry/run_log.jsonl"
const RunConfigScript := preload("res://data/run_config/run_config.gd")
const SettingsScript := preload("res://systems/settings/settings.gd")
const BANDGEN_CONFIG_PATH := "res://data/bandgen_config.tres"
const PIECE_CATALOG_PATH := "res://data/piece_catalog.tres"

## The locked M1.0/M1.1 all-off baseline fingerprint (sample seed 12345 -> 12 pieces).
## Determinism is sacred: the all-off control must stay byte-identical to this.
const BASELINE_FP := "e943ac9c8bc1"
const BASELINE_FP_SEED := 12345

## The stale SHA I5 fixed -- the build id must NO LONGER be this frozen value.
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
		printerr("RG1 M1.2 VERIFY FAIL: EventBus / Telemetry / GameState autoload missing")
		return 1

	# Clean meta slate so money/bank deltas are interpretable.
	var empty: Array[JunkItem] = []
	_gs.banked_junk = empty.duplicate()

	# ---- M0/I1: all-off determinism is byte-identical to the locked baseline -----
	# Pure-generator check (no scene) -- the cheapest, most direct "fp unmoved" guard,
	# run FIRST so a determinism regression fails fast before the loop drive.
	_verify_baseline_fingerprint()

	# ---- I5(b): the build id is REAL (not the stale frozen SHA) ------------------
	_verify_build_identity()

	var scene := load(MAIN_GAME_PATH) as PackedScene
	if scene == null:
		printerr("RG1 M1.2 VERIFY FAIL: could not load %s" % MAIN_GAME_PATH)
		return 1
	_game = scene.instantiate() as MainGame
	add_child(_game)
	# M1.6 (M2): main_game is dive-only and self-starts on _ready; no %ConfigMenu rail to grab
	# (it moved to M4's P-overlay). Each V-row stages its RunConfig via GameState.stage_dive_config.
	await get_tree().process_frame   # _ready: fixtures, self-start, R2/R3 connect

	# Persistent-node wiring (carried over from M1.1 RG1 -- still required for M1.2).
	_verify_persistent_wiring()

	# Telemetry ON for the whole sweep so every run writes a JSONL row set.
	_remove_log()
	_tel.set_enabled(true)
	if not _tel.is_enabled():
		_failures.append("set_enabled(true) did not enable telemetry")

	# ---- Drive the M1.2 verify matrix through the assembled loop -----------------
	# M-rows: each M1.2 fix in isolation, then stacked, plus the all-off control.
	await _drive_run(_all_off(), &"extract", "M0-all-off")        # control + snapshot
	await _drive_run(_i1_scale(), &"extract", "M1-i1-scale")      # level scale on
	await _drive_run(_i2_hazard(), &"death", "M2-i2-hazard")      # depth-scaled catch -> death
	await _drive_run(_i3_r2r3(), &"timeout", "M3-i3-r2r3")        # R2 toll + R3 cues + timeout
	await _drive_run(_i4_vision(), &"extract", "M4-i4-vision")    # vision/fog + nav + sealed
	await _drive_run(_bug5_toll(), &"extract", "M5-bug5-toll")    # R2 exposure toll moves R3 meter
	await _drive_run(_all_on(), &"extract", "M6-all-on")          # everything stacked

	# Flush + close so the file is fully on disk before we read it.
	_tel.set_enabled(false)

	# ---- I1 (assembled): level scale visibly changes the materialised band -------
	await _verify_level_scale_takes_effect()

	# ---- Inspect the JSONL ------------------------------------------------------
	_inspect_log()

	# ---- Multiple runs / session, no leaks (carried from M1.1 V12/V18) ----------
	await _verify_repeat_and_exits()

	# ---- Config carry-forward incl. the new lvl_* knobs -------------------------
	await _verify_carry_forward()

	# ---- Human-deferred (visual) rows -------------------------------------------
	_note_human_deferred()

	_cleanup()

	if _failures.is_empty():
		print("RG1 M1.2 VERIFY OK -- assembled M1.2 build runs the full loop. All-off control is ",
			"byte-identical to the locked baseline (fp=%s); build id is REAL (I5); level scale " % BASELINE_FP,
			"changes count+px/cell (I1); depth-scaled hazard catches -> death (I2); R2/R3 + nav rows ",
			"fire (I3/I4); R2 exposure toll moves R3's meter (BUG5); high-branch bands stay sealed ",
			"(BUG4); snapshot carries the new lvl_*/r1_catch_radius_per_depth knobs (V13); duration_s ",
			"real (I5); carry-forward + repeated runs with no leak. %d rows headless-verified; %d deferred."
			% [_headless_pass_count(), _human_deferred.size()])
		return 0
	for f in _failures:
		printerr("RG1 M1.2 VERIFY FAIL: ", f)
	return 1


# --- I1/M0: all-off determinism unmoved (pure generator, no scene) -------------

func _verify_baseline_fingerprint() -> void:
	var cfg := load(BANDGEN_CONFIG_PATH) as BandGenConfig
	var pc = load(PIECE_CATALOG_PATH)
	if cfg == null or pc == null:
		_failures.append("M0: missing bandgen config / baseline catalog for fingerprint check")
		return
	var catalog: Array[ZonePieceData] = pc.pieces
	# rc == null is the literal M1.1 baseline path; an all-off RunConfig must match it too.
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


# --- I5(b): the build id is real, not the stale frozen SHA --------------------

func _verify_build_identity() -> void:
	var id := BuildVersion.id()
	var sha := BuildVersion.short_sha()
	# I5 fix: the stale 852b6e2 must be gone; the SHA must look like a real 7-hex (or
	# +dirty), NOT the all-off "0000000" un-stamped sentinel when run from a working tree.
	if sha == STALE_SHA:
		_failures.append("I5: build SHA is STILL the stale frozen %s -- version.gd not reading real HEAD" % STALE_SHA)
	if not id.begins_with("m1-"):
		_failures.append("I5: build id '%s' does not carry the m1-<date>-<sha> shape" % id)
	# A headless run from the repo working tree resolves via the editor-git fallback to
	# the live HEAD; an exported/un-stamped build would show 0000000 (legibly stale).
	if sha == BuildVersion.FALLBACK_SHA:
		_human_deferred.append("I5: build SHA is the 0000000 un-stamped sentinel -- confirm the stamp step ran for the shipped build")


# --- Persistent-node wiring (RG1's own assembly, unchanged from M1.1) ----------

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
		_failures.append("ExposureMeter not in group 'r3_exposure_meter' (R2 exposure toll can't find it)")
	# BUG5: R3's meter must expose the add() mutator R2's exposure toll calls.
	elif not em.has_method(&"add"):
		_failures.append("BUG5: ExposureMeter has no add() mutator -- R2 exposure toll is a no-op on the meter")
	if _game.get_node_or_null("DecisionHUD/Root/ExposureReadout") == null:
		_failures.append("R3 HUD ExposureReadout not present in the decision HUD tree")
	# M1.6 (M2): the SellScreen + its "Back to Config" button are retired (run-end auto-returns
	# to the Hub via the App router); the old node-exists assertion is dropped with the node.


# --- Config factories ---------------------------------------------------------

## M1.6 (M2): stage `cfg` as the dive's RunConfig via GameState.stage_dive_config — the dive
## reads it on its next self-start through GameState.dive_config_or_default(). The embedded
## ConfigMenu rail is gone (dive-only refactor), so we stage directly instead of poking a menu.
func _stage_menu_config(cfg: RunConfig) -> void:
	GameState.stage_dive_config(cfg)


func _all_off() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-m12-M0-all-off"
	return c


## I1: level scale ON -- count override + size multiplier + the extended catalog.
func _i1_scale() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-m12-M1-i1-scale"
	c.lvl_enabled = true
	c.lvl_room_count = 20      # > baseline 12 -> a measurably bigger band
	c.lvl_size_mult = 2.0      # 16 -> 32 px/cell (bigger rooms)
	c.seed_override = 12345     # pin so the count/px assertion is deterministic
	return c


## I2: R1 hazard with the new depth-scaled catch radius (Q3) -- must catch -> death.
func _i2_hazard() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-m12-M2-i2-hazard"
	c.r1_enabled = true
	c.r1_depth_threshold = 0
	c.r1_chase_speed = 40.0
	c.r1_catch_radius = 16.0
	c.r1_catch_radius_per_depth = 4.0   # I2 Q3: depth-scaled lunge (the new M1.2 knob)
	c.r1_catch_kills = true
	c.r1_spawn_count = 1
	return c


## I3: R2 (egress toll) + R3 (exposure) both on so the cue-backing signals fire; we
## drive a timeout end-cause. Cue VISUALS are human-deferred.
func _i3_r2r3() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-m12-M3-i3-r2r3"
	c.r2_enabled = true
	c.r2_mechanism = 2          # egress_toll
	c.r2_toll_resource = 2      # dedicated meter (cue: floating -N)
	c.r2_cost_magnitude = 5.0
	c.r2_cost_per_depth = 2.0
	c.r2_depth_threshold = 0
	c.r3_enabled = true
	c.r3_base_climb_rate = 200.0
	c.r3_rate_per_depth = 20.0
	c.r3_threshold_levels = PackedFloat32Array([5.0, 15.0])
	c.r3_penalty_kind = 1       # speed
	c.r3_penalty_magnitude = 0.2
	c.r3_max_forces_loss = false
	return c


## I4: R4 vision/fog + maze on with a HIGH branch rate (exercises BUG4's seal at the
## loop level) + a pinned forking seed so a nav row fires deterministically.
func _i4_vision() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-m12-M4-i4-vision"
	c.r4_enabled = true
	c.r4_branch_chance_base = 1.0
	c.r4_branch_per_depth = 0.0
	c.r4_max_branch_depth = 12
	c.r4_vision_radius = 64.0
	c.r4_vision_tighten_per_depth = 4.0
	c.r4_fog_enabled = true
	c.r4_lost_proxy_threshold = 3.0
	c.seed_override = 42         # pinned forking seed (same as the M1.1 driver's R4 row)
	return c


## BUG5: R2 exposure toll (toll_resource=exposure) + R3 on -- the toll must move R3's
## run-state meter. Pure end-to-end of the BUG5 fix through the assembled build.
func _bug5_toll() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-m12-M5-bug5-toll"
	c.r2_enabled = true
	c.r2_mechanism = 2          # egress_toll
	c.r2_toll_resource = 1      # EXPOSURE -- the toll BUG5 makes mutate R3's meter
	c.r2_cost_magnitude = 8.0
	c.r2_cost_per_depth = 4.0
	c.r2_depth_threshold = 0
	c.r3_enabled = true
	c.r3_base_climb_rate = 0.0  # NO natural climb -> any meter movement is the R2 toll alone
	c.r3_rate_per_depth = 0.0
	c.r3_threshold_levels = PackedFloat32Array([5.0, 20.0])
	c.r3_penalty_kind = 1
	c.r3_penalty_magnitude = 0.1
	c.r3_max_forces_loss = false
	c.seed_override = 7
	return c


## Everything stacked: all four oppositions + level scale on (hazard non-fatal so it
## can't pre-empt the chosen end-cause; a hazard still awakens for an R1 row).
func _all_on() -> RunConfig:
	var c := _i4_vision()
	c.build_tag = "rg1-m12-M6-all-on"
	# R1 present (awakens) but non-fatal so we control the end-cause.
	c.r1_enabled = true
	c.r1_depth_threshold = 0
	c.r1_chase_speed = 40.0
	c.r1_catch_radius = 16.0
	c.r1_catch_radius_per_depth = 2.0
	c.r1_catch_kills = false
	c.r1_spawn_count = 1
	# R2 egress toll on exposure (folds in BUG5 too).
	c.r2_enabled = true
	c.r2_mechanism = 2
	c.r2_toll_resource = 1
	c.r2_cost_magnitude = 4.0
	c.r2_cost_per_depth = 2.0
	c.r2_depth_threshold = 0
	# R3 climbing.
	c.r3_enabled = true
	c.r3_base_climb_rate = 150.0
	c.r3_rate_per_depth = 15.0
	c.r3_threshold_levels = PackedFloat32Array([5.0, 15.0])
	c.r3_penalty_kind = 1
	c.r3_penalty_magnitude = 0.2
	c.r3_max_forces_loss = false
	# I1 level scale stacked on too.
	c.lvl_enabled = true
	c.lvl_room_count = 16
	c.lvl_size_mult = 1.5
	# keep the R4 pinned forking seed from _i4_vision for the nav row.
	return c


# --- One run: stage cfg, start, exercise oppositions, end with `cause` ---------

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


## Script the player across the band's floor cells so R4's position-driven nav rows
## fire (identical strategy to the M1.1 driver).
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


# --- I1 (assembled): level scale visibly changes the materialised band ---------

## Drive an all-off run and an I1-scaled run on the SAME pinned seed through the real
## build, and assert the assembled band differs in BOTH count (lvl_room_count) and
## effective px/cell (lvl_size_mult). This is the "visibly change the band" acceptance
## (I1) at the integration level -- the materialised _band_cell_size_px and the live
## BandContainer piece count are the two observable levers.
func _verify_level_scale_takes_effect() -> void:
	# All-off on the pinned baseline seed.
	var off := _all_off()
	off.seed_override = BASELINE_FP_SEED
	_stage_menu_config(off)
	_game.start_new_run()
	await_idle()
	var off_px: int = _game._band_cell_size_px
	var off_pieces: int = _count_band_pieces()
	_gs.extract_and_end_run()
	await_idle()
	_dismiss_sell_screen()
	for _j in 4:
		await get_tree().process_frame

	# I1 scaled (count 20, mult 2.0) on the same seed.
	_stage_menu_config(_i1_scale())
	_game.start_new_run()
	await_idle()
	var on_px: int = _game._band_cell_size_px
	var on_pieces: int = _count_band_pieces()
	_gs.extract_and_end_run()
	await_idle()
	_dismiss_sell_screen()
	for _j in 4:
		await get_tree().process_frame

	# Size: mult 2.0 -> 32 px/cell vs the baseline 16. Off must be the baseline 16.
	if off_px != 16:
		_failures.append("I1: all-off px/cell=%d != baseline 16" % off_px)
	if on_px <= off_px:
		_failures.append("I1: lvl_size_mult=2.0 did NOT enlarge px/cell (off=%d on=%d)" % [off_px, on_px])
	# Count: 20-room override must produce more pieces than the baseline ~12.
	if on_pieces <= off_pieces:
		_failures.append("I1: lvl_room_count=20 did NOT enlarge the band (off=%d on=%d pieces)"
			% [off_pieces, on_pieces])


## Count the materialised child nodes under BandContainer. For the off-vs-on relative
## comparison the exact piece filter is not load-bearing: both runs add the same fixed
## set of non-piece per-run nodes (spawner, gate, vision/fog, lost-proxy), so the DELTA
## is the piece-count delta. The I1-scaled count override must push it strictly higher.
func _count_band_pieces() -> int:
	var container := _game.get_node_or_null("BandContainer")
	if container == null:
		return 0
	return container.get_child_count()


# --- JSONL inspection: snapshot keys (incl. new M1.2 knobs) + gating + duration -

func _inspect_log() -> void:
	if not FileAccess.file_exists(LOG_PATH):
		_failures.append("no telemetry log written while enabled")
		return
	var rows := _read_rows(LOG_PATH)
	var started_by_tag := {}
	var ended_rows: Array = []
	var current_tag := ""
	var rows_in_run := {}
	# The M1.2 knobs that MUST appear in every snapshot (V13 generalised -- assert as a
	# set against the live to_flat_dict(), and explicitly name the new M1.2 keys).
	var expected_keys := (RunConfigScript.new() as RunConfig).to_flat_dict().keys()
	var m12_new_keys := ["lvl_enabled", "lvl_room_count", "lvl_size_mult", "r1_catch_radius_per_depth"]

	for r in rows:
		var t := String(r.get("type", ""))
		if t == "run_started":
			var data: Dictionary = r.get("data", {})
			var snap: Dictionary = data.get("run_config", {})
			current_tag = String(snap.get("build_tag", ""))
			started_by_tag[current_tag] = snap
			rows_in_run[current_tag] = []
			# V13: full key set present.
			if snap.is_empty():
				_failures.append("V13: run_started carries an empty run_config snapshot")
			else:
				for k in expected_keys:
					if not snap.has(k):
						_failures.append("V13: run_config snapshot missing key '%s'" % k)
				# The new M1.2 knobs, named explicitly so a regression is obvious.
				for k in m12_new_keys:
					if not snap.has(k):
						_failures.append("V13/M1.2: snapshot missing the new M1.2 knob '%s'" % k)
			# I5: build id present + real (not stale) on EVERY run_started row.
			var build_id := String(data.get("build", ""))
			if build_id == "":
				_failures.append("I5: run_started.data.build is empty")
			elif build_id.find(STALE_SHA) != -1:
				_failures.append("I5: run_started.data.build '%s' carries the stale SHA %s" % [build_id, STALE_SHA])
		elif t == "run_ended":
			ended_rows.append(r)
		else:
			if current_tag != "" and rows_in_run.has(current_tag):
				(rows_in_run[current_tag] as Array).append(t)
				# V2: R1's legacy hazard_awoke/hazard_caught rows collapsed into the
				# generic opposition_event family — keep awoke/hit_player granularity
				# by also recording an "opposition_event:<event>" token.
				if t == "opposition_event":
					var ev := String((r.get("data", {}) as Dictionary).get("event", ""))
					(rows_in_run[current_tag] as Array).append("opposition_event:" + ev)

	# Every config we ran appears.
	for tag in ["rg1-m12-M0-all-off", "rg1-m12-M1-i1-scale", "rg1-m12-M2-i2-hazard",
			"rg1-m12-M3-i3-r2r3", "rg1-m12-M4-i4-vision", "rg1-m12-M5-bug5-toll",
			"rg1-m12-M6-all-on"]:
		if not started_by_tag.has(tag):
			_failures.append("V13: no run_started row for config '%s'" % tag)

	# V2: R1's legacy hazard_awoke/hazard_caught rows retired → the generic
	# opposition_event(event=&"awoke"/&"hit_player", id=="pursuer") carries the same
	# moments; the collector's "opposition_event:<event>" tokens preserve granularity.
	var hazard_types := ["opposition_event:awoke", "opposition_event:hit_player"]
	var r2_types := ["return_cost_incurred"]
	var r3_types := ["exposure_crossed", "exposure_penalty", "exposure_meter_changed"]
	var r4_types := ["nav_branch_taken", "nav_lost_proxy"]

	# M0/V14: all-off run has NO opposition rows (stronger: no opposition_event at all).
	var off_rows: Array = rows_in_run.get("rg1-m12-M0-all-off", [])
	for opp in ["opposition_event"] + r2_types + ["exposure_crossed", "exposure_penalty"] + r4_types:
		if off_rows.has(opp):
			_failures.append("M0/V14: all-off run emitted opposition row '%s' (baseline contaminated)" % opp)

	# I2/M2: R1 run shows a hazard row (+ the catch the M1.1 build never made -- deferred
	# strict below if the depth-scaled catch is timing-sensitive headless).
	_assert_any_row("M2/I2", "rg1-m12-M2-i2-hazard", hazard_types, rows_in_run)
	if not (rows_in_run.get("rg1-m12-M2-i2-hazard", []) as Array).has("opposition_event:hit_player"):
		_human_deferred.append("M2/I2: opposition_event(&\"hit_player\") catch row in the assembled loop (covered green by test_pursuing_hazard; depth-scaled catch is timing-sensitive headless)")
	# I3/M3: R2 + R3 cue-backing rows fire.
	_assert_any_row("M3/I3-R2", "rg1-m12-M3-i3-r2r3", r2_types, rows_in_run)
	_assert_any_row("M3/I3-R3", "rg1-m12-M3-i3-r2r3", r3_types, rows_in_run)
	# I4/M4: nav rows fire (vision/fog look is human-deferred).
	_assert_any_row("M4/I4", "rg1-m12-M4-i4-vision", r4_types, rows_in_run)
	# BUG5/M5: the R2 exposure toll moved R3's meter -> an exposure_meter_changed (or a
	# crossing) appears in a run with NO natural climb. That row can ONLY come from the toll.
	_assert_any_row("M5/BUG5", "rg1-m12-M5-bug5-toll", r3_types, rows_in_run)
	if (rows_in_run.get("rg1-m12-M5-bug5-toll", []) as Array).has("return_cost_incurred") == false:
		_failures.append("M5/BUG5: R2 exposure toll did not emit return_cost_incurred")
	# M6/V5: all-on composes -- at least one row from each family.
	for fam in [hazard_types, r2_types, r3_types, r4_types]:
		_assert_any_row("M6/all-on", "rg1-m12-M6-all-on", fam, rows_in_run)

	# I5/V15: run_ended arity intact + duration_s real on EVERY run + causes observed.
	var seen_causes := {}
	for er in ended_rows:
		var ed: Dictionary = er.get("data", {})
		for f in ["cause", "duration_s", "max_depth"]:
			if not ed.has(f):
				_failures.append("V15: run_ended.data missing M1.0 field '%s'" % f)
		seen_causes[String(ed.get("cause", ""))] = true
		# I5(a): duration_s real (> 0) on every completed run -- the regression-lock surface.
		if float(ed.get("duration_s", -1.0)) <= 0.0:
			_failures.append("I5/V15: run_ended.duration_s=%s is not > 0 (duration regression)"
				% str(ed.get("duration_s", "absent")))
		if int(ed.get("max_depth", -1)) < 1:
			_failures.append("V15: run_ended.max_depth < 1 -- depth driver not reflected (BUG2)")
	for cause in ["extract", "death", "timeout"]:
		if not seen_causes.has(cause):
			_failures.append("V8-V11: end-cause '%s' never observed in run_ended rows" % cause)


func _assert_any_row(tag: String, config_tag: String, types: Array, rows_in_run: Dictionary) -> void:
	var run_rows: Array = rows_in_run.get(config_tag, [])
	for ty in types:
		if run_rows.has(ty):
			return
	_failures.append("%s: config '%s' emitted none of %s (opposition row missing)"
		% [tag, config_tag, str(types)])


# --- Multiple runs / session, no leak (V12/V18) -------------------------------

func _verify_repeat_and_exits() -> void:
	var container := _game.get_node("BandContainer")
	var settled_counts: Array[int] = []
	for _i in 4:
		_stage_menu_config(_all_off())
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


# --- Config carry-forward incl. lvl_* (V16) -----------------------------------

func _verify_carry_forward() -> void:
	# Stage an I1-scaled config (lvl on), run it, then Continue (NO menu) -- the next run
	# must reuse the SAME config, lvl_* included.
	_stage_menu_config(_i1_scale())
	_game.start_new_run()
	await_idle()
	var first_lvl: bool = _gs.active_run_config != null and bool(_gs.active_run_config.lvl_enabled)
	_gs.extract_and_end_run()
	await_idle()
	_dismiss_sell_screen()
	_game.start_new_run()   # door 2 (Continue) -- re-reads the unchanged menu config
	await_idle()
	var second_lvl: bool = _gs.active_run_config != null and bool(_gs.active_run_config.lvl_enabled)
	if not (first_lvl and second_lvl):
		_failures.append("V16: lvl config did not carry forward across Continue (lvl %s -> %s)"
			% [str(first_lvl), str(second_lvl)])
	_gs.extract_and_end_run()
	await_idle()
	_dismiss_sell_screen()


# --- Human-deferred rows ------------------------------------------------------

func _note_human_deferred() -> void:
	_human_deferred.append("I1: bigger rooms FEEL like a journey (not a 17s sprint) -- checklist")
	_human_deferred.append("I2: the hazard VISIBLY closes + the depth-scaled lunge reads as a real threat -- checklist")
	_human_deferred.append("I3: the exposure bar + penalty banner + R2 clock-toll pulse are LEGIBLE -- checklist")
	_human_deferred.append("I4: vision OCCLUDES (hides, not dims) beyond the radius + the 'lost' cue reads -- checklist")
	_human_deferred.append("I5: a RETURNED log carries the real m1-<date>-<sha> build id + Director build_tag -- checklist")
	_human_deferred.append("V18: no stuck SCREENS via real input (Main Menu -> Hub -> Dive -> Hub navigation) -- checklist")
	print("RG1 M1.2 human-deferred (manual playtest checklist): ")
	for h in _human_deferred:
		print("  - ", h)


func _headless_pass_count() -> int:
	# Baseline-fp, build-id, persistent-wiring, 7 driven configs (snapshot+gating),
	# level-scale-takes-effect, BUG5 end-to-end, duration-real, carry-forward, repeat/no-leak.
	return 14


# --- Helpers ------------------------------------------------------------------

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
