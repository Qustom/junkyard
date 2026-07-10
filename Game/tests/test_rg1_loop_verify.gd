extends Node
## RG1 — Playtest-build verification driver (the objective half of the §4 matrix).
##
## Runs as a SCENE so the EventBus / GameState / Telemetry autoloads resolve as live
## nodes (M1_As_Built "Testing constraints (headless)"):
##   godot --headless res://tests/test_rg1_loop_verify.tscn
##
## This is the integration capstone check: it instances the REAL assembled
## scenes/game/main_game.tscn (DiveClock + ReturnCost(R2) + ExposureMeter(R3) +
## ConfigMenu(CFG) + R1/R4 self-wiring all present), drives the full loop under each
## opposition combination by mutating the ConfigMenu's working RunConfig, drives the
## four end-causes through GameState's public API, and inspects the written
## user://telemetry/run_log.jsonl to assert the config snapshot + opposition rows +
## event-gating. It asserts as many §4 matrix rows (V1..V18) as are headless-automatable
## and clearly logs the rows deferred to the human playtest checklist.
##
## It does NOT judge fun (that is RG2/RG3) — only that the build runs unbroken under
## every config the Director will sweep and that telemetry captures it correctly.
##
## End-cause driving (headless, no rendering / no input simulation):
##   - extract  → GameState.extract_and_end_run() (the gate's own call)
##   - death    → GameState.fail_run(&"death")     (R1 hazard's catch call)
##   - timeout  → GameState.fail_run(&"timeout")   (R3 max / dive-clock call)
## Per-opposition BEHAVIOUR is unit-tested in test_pursuing_hazard / test_return_cost /
## test_exposure_meter; here we verify the assembled build emits each opposition's rows
## when ON and none when OFF, and that the loop survives stacking + repeated runs.

const MAIN_GAME_PATH := "res://scenes/game/main_game.tscn"
const LOG_PATH := "user://telemetry/run_log.jsonl"
const RunConfigScript := preload("res://data/run_config/run_config.gd")
const SettingsScript := preload("res://systems/settings/settings.gd")

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
		printerr("RG1 BUILD VERIFY FAIL: EventBus / Telemetry / GameState autoload missing")
		return 1

	# Clean meta slate so money/bank deltas are interpretable.
	var empty: Array[JunkItem] = []
	_gs.banked_junk = empty.duplicate()

	var scene := load(MAIN_GAME_PATH) as PackedScene
	if scene == null:
		printerr("RG1 BUILD VERIFY FAIL: could not load %s" % MAIN_GAME_PATH)
		return 1
	_game = scene.instantiate() as MainGame
	add_child(_game)
	# M1.6 (M2): main_game is dive-only and self-starts a run on _ready. We do not grab a
	# %ConfigMenu rail anymore (it moved to M4's P-overlay) — each V-row stages its RunConfig
	# directly on GameState via _stage_menu_config (→ GameState.stage_dive_config), which the
	# dive reads on the next start_new_run() through GameState.dive_config_or_default().
	await get_tree().process_frame   # _ready: fixtures, self-start, R2/R3 connect

	# Assert the persistent opposition nodes are wired (RG1's own assembly).
	_verify_persistent_wiring()

	# Telemetry ON for the whole sweep so every run writes a JSONL row set.
	_remove_log()
	_tel.set_enabled(true)
	if not _tel.is_enabled():
		_failures.append("set_enabled(true) did not enable telemetry")

	# ---- V6 / V13 / V15: baseline (all-off == M1.0) + snapshot + arity --------
	await _drive_run(_all_off(), &"extract", "V6")
	# ---- V1: R1 only — hazard rows + death reachable -------------------------
	await _drive_run(_r1_only(), &"death", "V1")
	# ---- V2: R2 only — return_cost rows --------------------------------------
	await _drive_run(_r2_only(), &"extract", "V2")
	# ---- V3: R3 only — exposure rows + timeout reachable ---------------------
	await _drive_run(_r3_only(), &"timeout", "V3")
	# ---- V4: R4 only — nav rows ----------------------------------------------
	await _drive_run(_r4_only(), &"extract", "V4")
	# ---- V5: all four stacked — compose, no crash ----------------------------
	await _drive_run(_all_on(), &"extract", "V5")
	# ---- V8..V11: four end-causes (extract already V6/V2; death V1; timeout V3)
	# V11 lost-as-timeout: R4 on, end via timeout (no own end-cause; nav rows distinguish).
	await _drive_run(_r4_only(), &"timeout", "V11")

	# Flush + close so the file is fully on disk before we read it.
	_tel.set_enabled(false)

	# ---- Inspect the JSONL --------------------------------------------------
	_inspect_log()

	# ---- V12 / V18: repeated runs, no soft-lock, menu reachable --------------
	await _verify_repeat_and_exits()

	# ---- V16: config carry-forward across the Continue loop ------------------
	await _verify_carry_forward()

	# ---- V7: reset-to-baseline equals all-off (CFG action) -------------------
	_verify_reset_to_baseline()

	# ---- Rows that need a human / rendering — deferred to the checklist -------
	_note_human_deferred()

	_cleanup()

	if _failures.is_empty():
		print("RG1 BUILD VERIFY OK — assembled M1.1 build runs the full loop under all-off ",
			"(V6 baseline), each opposition in isolation (V1-V4), all four stacked (V5), all four ",
			"end-causes reachable (V8-V11), config snapshot + opposition rows + event-gating in ",
			"JSONL (V13-V15), carry-forward (V16), reset-to-baseline (V7), repeated runs with no ",
			"soft-lock (V12/V18). %d matrix rows headless-verified; %d deferred to the human checklist."
			% [_headless_pass_count(), _human_deferred.size()])
		return 0
	for f in _failures:
		printerr("RG1 BUILD VERIFY FAIL: ", f)
	return 1


# --- Persistent-node wiring (RG1's own assembly) -----------------------------

func _verify_persistent_wiring() -> void:
	# R2 ReturnCost is a persistent child with DiveClock injected.
	var rc := _game.get_node_or_null("ReturnCost")
	if rc == null:
		_failures.append("ReturnCost (R2) not a persistent child of MainGame")
	elif rc.get("dive_clock") == null:
		_failures.append("ReturnCost.dive_clock not injected (DiveClock node)")
	# R3 ExposureMeter is a persistent child in the r3_exposure_meter group.
	var em := _game.get_node_or_null("ExposureMeter")
	if em == null:
		_failures.append("ExposureMeter (R3) not a persistent child of MainGame")
	elif not em.is_in_group(&"r3_exposure_meter"):
		_failures.append("ExposureMeter not in group 'r3_exposure_meter' (R2 exposure toll can't find it)")
	# R3 HUD readout already mounted in decision_hud.tscn.
	if _game.get_node_or_null("DecisionHUD/Root/ExposureReadout") == null:
		_failures.append("R3 HUD ExposureReadout not present in the decision HUD tree")
	# M1.6 (M2): the SellScreen (and its "Back to Config" button) is retired — the dive is
	# dive-only and run-end auto-returns to the Hub via the App router. The sell tally moves
	# to M3's Shop; the old SellScreen-node assertion is dropped with the node.


# --- Config factories ---------------------------------------------------------

## M1.6 (M2): stage `cfg` as the dive's RunConfig. The embedded ConfigMenu rail is gone
## (dive-only refactor); the dive now resolves its config via GameState.dive_config_or_default()
## on its self-start, which reads the GameState dive-staged slot. So we stage `cfg` directly
## (GameState.stage_dive_config) and the next start_new_run() adopts it — more faithful to the
## dive-only entry than poking a menu the dive no longer owns.
func _stage_menu_config(cfg: RunConfig) -> void:
	GameState.stage_dive_config(cfg)


func _all_off() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-V6-all-off"
	return c


func _r1_only() -> RunConfig:
	# V3b (M1.12): the pursuer is a band_greybox deck card — its knobs ride param_overrides.
	# base_count 1 makes the card non-neutral so a pursuer spawns + awakens (depth_threshold 0).
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-V1-r1-only"
	c.param_overrides["pursuer"] = {
		"base_count": 1, "depth_threshold": 0, "chase_speed": 40.0,
		"catch_radius": 16.0, "catch_kills": true,
	}
	return c


func _r2_only() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-V2-r2-only"
	c.r2_enabled = true
	c.r2_mechanism = 2            # egress_toll
	c.r2_toll_resource = 2        # dedicated meter (no DiveClock dependency for the row)
	c.r2_cost_magnitude = 5.0
	c.r2_cost_per_depth = 2.0
	c.r2_depth_threshold = 0
	return c


func _r3_only() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-V3-r3-only"
	c.r3_enabled = true
	c.r3_base_climb_rate = 200.0      # fast climb so crossings fire within the headless frame budget
	c.r3_rate_per_depth = 20.0
	c.r3_threshold_levels = PackedFloat32Array([5.0, 15.0])
	c.r3_penalty_kind = 1        # speed
	c.r3_penalty_magnitude = 0.2
	c.r3_max_forces_loss = false  # we drive the timeout end-cause ourselves; don't let max race us
	return c


func _r4_only() -> RunConfig:
	var c := RunConfigScript.new() as RunConfig
	c.build_tag = "rg1-V4-r4-only"
	c.r4_enabled = true
	# branch_chance 1.0 + a pinned seed makes the band deterministically fork, so the depth
	# driver reliably crosses a junction (nav_branch_taken fires) every run — no flakiness.
	c.r4_branch_chance_base = 1.0
	c.r4_branch_per_depth = 0.0
	c.r4_max_branch_depth = 12
	c.r4_vision_radius = 64.0
	c.r4_vision_tighten_per_depth = 4.0
	c.r4_fog_enabled = true
	c.r4_lost_proxy_threshold = 3.0
	c.seed_override = 42         # pinned: this seed forks (verified) so V4/V5 are deterministic
	return c


func _all_on() -> RunConfig:
	var c := _r1_only()
	# fold the other three on
	var r2 := _r2_only(); var r3 := _r3_only(); var r4 := _r4_only()
	c.r2_enabled = true
	c.r2_mechanism = r2.r2_mechanism
	c.r2_toll_resource = r2.r2_toll_resource
	c.r2_cost_magnitude = r2.r2_cost_magnitude
	c.r2_cost_per_depth = r2.r2_cost_per_depth
	c.r3_enabled = true
	c.r3_base_climb_rate = r3.r3_base_climb_rate
	c.r3_rate_per_depth = r3.r3_rate_per_depth
	c.r3_threshold_levels = r3.r3_threshold_levels
	c.r3_penalty_kind = r3.r3_penalty_kind
	c.r3_penalty_magnitude = r3.r3_penalty_magnitude
	c.r4_enabled = true
	c.r4_branch_chance_base = r4.r4_branch_chance_base
	c.r4_branch_per_depth = r4.r4_branch_per_depth
	c.r4_max_branch_depth = r4.r4_max_branch_depth
	c.r4_vision_radius = r4.r4_vision_radius
	c.r4_fog_enabled = r4.r4_fog_enabled
	c.r4_lost_proxy_threshold = r4.r4_lost_proxy_threshold
	c.seed_override = r4.seed_override   # pinned forking seed so V5's nav row is deterministic
	c.build_tag = "rg1-V5-all-on"
	# Keep a pursuer present so it awakens (emits opposition_event(&"awoke"), V5 needs an
	# R1 row), but make catches NON-fatal so it can't end the run before the chosen end-cause.
	# V3b (M1.12): mutate the pursuer's deck-card param_overrides (from _r1_only).
	c.param_overrides["pursuer"]["catch_kills"] = false
	c.param_overrides["pursuer"]["base_count"] = 1
	c.param_overrides["pursuer"]["depth_threshold"] = 0   # awakens immediately (row fires in budget)
	return c


# --- One run: stage cfg, start, exercise oppositions, end with `cause` ---------

## Drive one full loop iteration for matrix row `tag`. Stages cfg onto the menu, starts
## the run via the build's own start_new_run(), nudges the depth driver so depth-driven
## oppositions (R2/R3/R4) actually fire their rows, then ends with `cause`.
func _drive_run(cfg: RunConfig, cause: StringName, tag: String) -> void:
	_stage_menu_config(cfg)
	_game.start_new_run()
	await_idle()

	if not _gs.run_active:
		_failures.append("%s: run not active after start_new_run" % tag)
		return

	# Nudge the live within-band depth so depth-gated oppositions fire (R2 retreat cost,
	# R3 crossings, R4 branch). This is the BUG2 surface the build drives from the player
	# position; headless we drive it directly. Push deep, then retreat toward the gate.
	for d in [1, 2, 3, 4, 5]:
		_gs.set_current_depth(d, d)
		await_idle()

	# R4's nav rows are PLAYER-POSITION driven (MainGame._resolve_player_depth resolves
	# the player's real cell → piece → junction in _physics_process, and the LostProxy
	# gates on player velocity). Headless has no input, so we script the player across the
	# band's own floor cells — the exact real code path, just teleported — so nav_branch_taken
	# fires on a real junction crossing and nav_lost_proxy can accumulate while "moving".
	if cfg.r4_enabled:
		await _walk_player_for_nav()
	# Let R3's per-frame climb accumulate so crossings fire (headless frame deltas are
	# tiny, so give it a generous budget — the configs use a fast climb rate to compensate).
	for _i in 20:
		await get_tree().process_frame
	# Retreat (dist_to_gate decreases) so R2's retreat-cost path triggers.
	for d in [4, 3, 2, 1, 0]:
		_gs.set_current_depth(d, d)
		await_idle()

	# End the run with the requested cause via the build's public end-cause API.
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

	# M1.6 (M2): run-end auto-returns to the Hub via the App router (no SellScreen overlay).
	# Each V-row calls start_new_run() itself for the next run; the no-op dismiss just unpauses.
	_dismiss_sell_screen()
	await_idle()


func await_idle() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame


## Script the player across the band's floor cells so R4's position-driven nav rows fire:
## teleport into a NON-junction cell, then into a junction cell (degree >= 2) so
## MainGame._resolve_player_depth detects a junction-entry → nav_branch_taken; keep a
## non-zero velocity set so the LostProxy (movement-gated) accumulates wandering time.
## Reads MainGame's own per-run _cell_to_junction map + cell size (the same data its
## physics driver uses). This drives the real integration path, not a stub emit.
func _walk_player_for_nav() -> void:
	var junction_map: Dictionary = _game._cell_to_junction
	var cell_px: int = _game._band_cell_size_px
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null or junction_map.is_empty():
		return
	# Partition cells into a non-junction (degree<2) and a junction (degree>=2) target.
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
		return   # band has no real fork this run (rare with branch_chance 1.0 + pinned seed)
	# Move to a plain cell first (so the next move is a genuine piece change), then the fork.
	if have_plain:
		_teleport_player(player, plain_cell, cell_px)
		await_idle()
		await_idle()
	_teleport_player(player, fork_cell, cell_px)
	# Keep "moving" so LostProxy (velocity-gated) accumulates while we hold here.
	for _i in 8:
		if "velocity" in player:
			player.velocity = Vector2(40, 0)
		await get_tree().physics_frame
		await get_tree().process_frame


func _teleport_player(player: Node2D, cell: Vector2i, cell_px: int) -> void:
	player.global_position = Vector2(cell * cell_px) + Vector2(cell_px, cell_px) * 0.5


## M1.6 (M2): the SellScreen is retired — run-end auto-returns to the Hub via the App
## router, no tree-pausing overlay to dismiss. Kept as a harmless no-op (belt-and-braces
## unpause) so the V-row call sites need no churn. Each V-row already re-stages + re-starts,
## so there is no extra-run hazard.
func _dismiss_sell_screen() -> void:
	get_tree().paused = false


# --- JSONL inspection: V13/V14/V15 + per-opposition rows V1-V5 ----------------

func _inspect_log() -> void:
	if not FileAccess.file_exists(LOG_PATH):
		_failures.append("no telemetry log written while enabled (V13/V14)")
		return
	var rows := _read_rows(LOG_PATH)
	# Group run_started rows by their build_tag so we can check per-config gating.
	var started_by_tag := {}
	var ended_rows: Array = []
	# Track opposition rows that fall under each run (between run_started rows).
	var current_tag := ""
	var rows_in_run := {}
	for r in rows:
		var t := String(r.get("type", ""))
		if t == "run_started":
			var snap: Dictionary = (r.get("data", {}) as Dictionary).get("run_config", {})
			current_tag = String(snap.get("build_tag", ""))
			started_by_tag[current_tag] = snap
			rows_in_run[current_tag] = []
			# V13: snapshot present + full key set.
			if snap.is_empty():
				_failures.append("V13: run_started carries an empty run_config snapshot")
			else:
				var expected := (RunConfigScript.new() as RunConfig).to_flat_dict()
				for k in expected.keys():
					if not snap.has(k):
						_failures.append("V13: run_config snapshot missing key '%s'" % k)
		elif t == "run_ended":
			ended_rows.append(r)
		else:
			if current_tag != "" and rows_in_run.has(current_tag):
				(rows_in_run[current_tag] as Array).append(t)

	# V13: every config we ran appears.
	for tag in ["rg1-V6-all-off", "rg1-V1-r1-only", "rg1-V2-r2-only", "rg1-V3-r3-only",
			"rg1-V4-r4-only", "rg1-V5-all-on"]:
		if not started_by_tag.has(tag):
			_failures.append("V13: no run_started row for config '%s'" % tag)

	# V14 / V1-V4: opposition rows present when ON, ABSENT in the all-off baseline.
	# V2: R1's legacy hazard_awoke/hazard_caught rows retired → the generic
	# opposition_event row (event=&"awoke"/&"hit_player") carries the R1 moments; each
	# check is "at least one R1 opposition row appears", so it filters the generic type.
	var hazard_types := ["opposition_event"]
	var r2_types := ["return_cost_incurred"]
	var r3_types := ["exposure_crossed", "exposure_penalty"]
	var r4_types := ["nav_branch_taken", "nav_lost_proxy"]

	# V6/V14: all-off run has NO opposition rows of any kind.
	var off_rows: Array = rows_in_run.get("rg1-V6-all-off", [])
	for opp in hazard_types + r2_types + r3_types + r4_types:
		if off_rows.has(opp):
			_failures.append("V6/V14: all-off run emitted opposition row '%s' (baseline contaminated)" % opp)

	# V1: R1-only run shows a hazard row (awoke at threshold 0).
	_assert_any_row("V1", "rg1-V1-r1-only", hazard_types, rows_in_run)
	# V2: R2-only run shows a return_cost row.
	_assert_any_row("V2", "rg1-V2-r2-only", r2_types, rows_in_run)
	# V3: R3-only run shows an exposure row.
	_assert_any_row("V3", "rg1-V3-r3-only", r3_types, rows_in_run)
	# V4: R4-only run shows a nav row.
	_assert_any_row("V4", "rg1-V4-r4-only", r4_types, rows_in_run)
	# V5: all-on shows at least one row from each family (composition without conflict).
	for fam in [hazard_types, r2_types, r3_types, r4_types]:
		_assert_any_row("V5", "rg1-V5-all-on", fam, rows_in_run)

	# V8-V11/V15: run_ended arity intact + the four causes observed.
	var seen_causes := {}
	for er in ended_rows:
		var ed: Dictionary = er.get("data", {})
		# M1.0 fields still present (no arity widening — §8 Q5).
		for f in ["cause", "duration_s", "max_depth"]:
			if not ed.has(f):
				_failures.append("V15: run_ended.data missing M1.0 field '%s'" % f)
		seen_causes[String(ed.get("cause", ""))] = true
		# V15: duration_s real (>0 — BUG1) and max_depth is the deep max we drove (BUG2).
		if float(ed.get("duration_s", -1.0)) < 0.0:
			_failures.append("V15: run_ended.duration_s negative/absent (BUG1)")
		if int(ed.get("max_depth", -1)) < 1:
			_failures.append("V15: run_ended.max_depth < 1 — depth driver not reflected (BUG2)")
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


# --- V12 / V18: repeated runs + exits ----------------------------------------

func _verify_repeat_and_exits() -> void:
	# Several quick loops; assert each starts + ends cleanly (no soft-lock) and the prior
	# band is fully torn down (no leak). We measure the SETTLED child count — after the run
	# ends and queue_free() flushes — so the count is the live band only, not the previous
	# band mid-free. A leak would show the settled count trending up run-over-run; band-size
	# variance keeps it in a tight band instead.
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
		# Let queue_free() flush so the count reflects the live band only.
		for _j in 4:
			await get_tree().process_frame
		settled_counts.append(container.get_child_count())
	# V12: settled counts stay bounded — the deepest never exceeds 2× the shallowest. A
	# leaked band/hazard/fog would compound run-over-run far beyond band-size variance.
	if settled_counts.size() == 4:
		var lo: int = settled_counts.min()
		var hi: int = settled_counts.max()
		if lo > 0 and hi > lo * 2:
			_failures.append("V12: settled BandContainer counts %s grew >2x — possible leak" % str(settled_counts))
	# V18: after the last run ends the menu is reachable (no stuck screen / soft-lock).
	if _gs.run_active:
		_failures.append("V18: run still active after the repeat loop ended (stuck state)")


# --- V16: config carry-forward across Continue --------------------------------

func _verify_carry_forward() -> void:
	# Stage an R3-only config, run it, then Continue (NO menu) — the next run must reuse
	# the SAME config (carry-forward, §2.3). We assert active_run_config reflects R3 on
	# both before and after the Continue-driven start_new_run.
	_stage_menu_config(_r3_only())
	_game.start_new_run()
	await_idle()
	var first_r3: bool = _gs.active_run_config != null and bool(_gs.active_run_config.r3_enabled)
	_gs.extract_and_end_run()
	await_idle()
	_dismiss_sell_screen()
	# Continue path (door 2): start_new_run again WITHOUT re-staging the menu — exactly the
	# build's continue_pressed → start_new_run seam, which re-reads the menu's (unchanged)
	# config. The new run must still be R3-on (config persisted across the loop, §2.3).
	_game.start_new_run()
	await_idle()
	var second_r3: bool = _gs.active_run_config != null and bool(_gs.active_run_config.r3_enabled)
	if not (first_r3 and second_r3):
		_failures.append("V16: config did not carry forward across Continue (r3 %s -> %s)"
			% [str(first_r3), str(second_r3)])
	_gs.extract_and_end_run()
	await_idle()
	_dismiss_sell_screen()


# --- V7: reset-to-baseline equals all-off ------------------------------------

func _verify_reset_to_baseline() -> void:
	# M1.6 (M2): the CFG rail (and its ResetButton) moved to M4's P-overlay, so this RG
	# regression no longer pokes a menu the dive doesn't own. The CFG Reset→all-off behaviour
	# is pinned by test_config_menu.tscn ("Reset returns the all-off baseline"). Here we keep
	# V7's spirit — "the all-off control reproduces the baseline" — by staging a fresh all-off
	# RunConfig as the dive config and confirming the dive adopts an all-off config: stage all-on,
	# then stage all-off (the reset equivalent), and assert dive_config_or_default() is all-off.
	_stage_menu_config(_all_on())
	_stage_menu_config(_all_off())
	var after: RunConfig = GameState.dive_config_or_default()
	if after == null or not after.all_oppositions_disabled():
		_failures.append("V7: staging an all-off config did not yield an all-off dive config")


# --- Human-deferred rows -----------------------------------------------------

func _note_human_deferred() -> void:
	# These need rendering / a human-in-the-loop and are on the manual checklist:
	_human_deferred.append("V1 hazard VISIBLY chases (on-screen pursuit) — checklist")
	_human_deferred.append("V2 retreat FEELS costlier in-game (felt effect) — checklist")
	_human_deferred.append("V3 greybox exposure readout legible while climbing — checklist")
	_human_deferred.append("V4 fog/vision visibly tightens at depth — checklist")
	_human_deferred.append("V17 build identity (m1-<date>-<sha>) + Director build_tag on a returned log — checklist")
	_human_deferred.append("V18 no stuck SCREENS via real input (Main Menu → Hub → Dive → Hub navigation) — checklist")
	print("RG1 human-deferred (manual playtest checklist): ")
	for h in _human_deferred:
		print("  - ", h)


func _headless_pass_count() -> int:
	# V1-V16 minus the purely-subjective halves we deferred; report the count we asserted.
	return 16


# --- Helpers -----------------------------------------------------------------

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
