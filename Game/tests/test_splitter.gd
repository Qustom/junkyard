extends Node
## Headless acceptance test for S6b (M1.9) — the SPLITTER: the mid-run `svc.spawn`
## client (b) proof. Run as a SCENE (autoloads + a live tree):
##   godot --headless --path Game res://tests/test_splitter.tscn
##
## Drives the REAL defs + host through a directly-armed SpawnService (the
## test_spawn_service harness shape) — no band/builder needed for the split cases;
## the throw-death is exercised at the exact seam ThrownItem calls
## (`resolve_throw_death(killer_ctx) -> bool`, thrown_item.gd:103-108; ThrownItem's
## own dispatch is covered by its golden tests).
##
## Asserts (spec §8 acceptance, as corrected by Resolved Decisions C5/C6):
##   (A) defs: both load, ids/caps/cap_group as ratified; the cross-def reference
##       splitter -> splitter_child resolves; host-contract surface on BOTH scenes
##       (get_def_id() == def.id on a bare instance).
##   (B) split on throw-death ONLY: a resolve_throw_death kill spawns exactly
##       child_count=2 children at the DETERMINISTIC ring cells (independent mirror
##       of _ring_offset), parent freed + deregistered (return true = handled), one
##       &"split" row, central &"spawned" rows for both children, children carry
##       parent_speed x child_speed_mult; a plain removal (queue_free — the only
##       non-throw removal in M1) spawns NOTHING; children (generations 0) do NOT
##       re-split; a repeat split is cell-identical (deterministic-per-split).
##   (C) caps refuse — proven (C5 restatement): (a) per-def per_band_cap=8 refuses
##       the over-cap children (live_count(splitter_child) <= 8) with one
##       &"split_refused" row per refusal; (b) the &"new_hazards" group ceiling
##       binds a live mid-run client; a freed parent RE-OPENS headroom (Wave-1
##       live-registry canon).
##   (D) generation-time fingerprint unaffected by mid-run splits: all-off pipeline
##       fp == e943ac9c8bc1 before AND after a forced split (byte-identical), and
##       the split consumes NOTHING from the global RNG stream.
##   (E) the L5 kills gate holds for children: kills=true catch -> fail_run,
##       run_ended reason &"death" + opposition_killed_player(&"splitter_child");
##       kills=false catch emits &"hit_player" but does NOT end the run.
##   (F) the child_despawn_s mercy knob works when > 0 (ratified default 0 = off).
##   (G) telemetry vocabulary: every generic row seen uses only the S6b vocabulary
##       (&"spawned"/&"split"/&"split_refused"/&"hit_player"), primitives-only.

const CELL := 16
const BASELINE_FP := "e943ac9c8bc1"
const PARENT_DEF_PATH := "res://data/oppositions/splitter.tres"
const CHILD_DEF_PATH := "res://data/oppositions/splitter_child.tres"
const PROFILE_PATH := "res://data/bands/band_greybox.tres"
const NEW_HAZARDS_CEILING := 48   # independent mirror of the K5/S0 group ceiling

var _events: Array[Array] = []        # opposition_event rows
var _killed_rows: Array[Array] = []   # opposition_killed_player rows
var _run_ends: Array[Array] = []      # run_ended rows


func _ready() -> void:
	var code: int = await _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []
	EventBus.opposition_event.connect(_on_opposition_event)
	EventBus.opposition_killed_player.connect(_on_killed_player)
	EventBus.run_ended.connect(_on_run_ended)

	var parent_def := load(PARENT_DEF_PATH) as OppositionDef
	var child_def := load(CHILD_DEF_PATH) as OppositionDef
	if parent_def == null or child_def == null:
		printerr("S6b FAIL: defs do not load as OppositionDef")
		return 1

	_case_defs(parent_def, child_def, failures)
	_case_split_on_throw_death(parent_def, child_def, failures)
	_case_caps(parent_def, child_def, failures)
	_case_fingerprint(parent_def, failures)
	await _case_kills_gate(child_def, failures)
	await _case_despawn_timer(child_def, failures)
	_case_vocabulary(failures)

	EventBus.opposition_event.disconnect(_on_opposition_event)
	EventBus.opposition_killed_player.disconnect(_on_killed_player)
	EventBus.run_ended.disconnect(_on_run_ended)
	if failures.is_empty():
		print("S6b OK — Splitter verified: defs + cross-def reference + host contract, "
			+ "split on throw-death only (2 children at deterministic ring cells, parent "
			+ "handled+freed, one &\"split\"), children terminal (no re-split), plain "
			+ "removal spawns nothing, per_band_cap=8 + &\"new_hazards\" ceiling refusal "
			+ "with &\"split_refused\" rows + freed-parent headroom re-open, all-off fp "
			+ BASELINE_FP + " byte-identical across a forced split with the RNG stream "
			+ "untouched, L5 kills gate (true -> run_ended death + "
			+ "opposition_killed_player; false -> hit_player only), child_despawn_s "
			+ "mercy knob, and the generic telemetry vocabulary.")
		return 0
	for f in failures:
		printerr("S6b FAIL: ", f)
	return 1


# --- (A) defs + cross-def reference + host contract --------------------------------

func _case_defs(parent_def: OppositionDef, child_def: OppositionDef,
		failures: Array[String]) -> void:
	if parent_def.id != &"splitter" or child_def.id != &"splitter_child":
		failures.append("(A) def ids %s/%s wrong" % [parent_def.id, child_def.id])
	if parent_def.cap_group != &"new_hazards" or child_def.cap_group != &"new_hazards":
		failures.append("(A) cap_group must be &\"new_hazards\" on both defs (A4)")
	if parent_def.per_band_cap != 8 or child_def.per_band_cap != 8:
		failures.append("(A) per_band_cap must be 8 on both defs")
	if parent_def.min_band != 2 or child_def.min_band != 2:
		failures.append("(A) min_band must be 2 (band-2-exclusive, D-RAT-2)")
	if child_def.credit_cost != 0:
		failures.append("(A) child credit_cost must be 0 (never deck-drawn)")
	if not parent_def.kills or not child_def.kills:
		failures.append("(A) kills must default true on both defs")
	# Ratified defaults (D-RAT-2): child_count=2, generations=1 (parent) / 0 (child),
	# split_on=throw_death(0), no despawn timer.
	if int(parent_def.params.get("child_count", -1)) != 2 \
			or int(parent_def.params.get("generations", -1)) != 1 \
			or int(parent_def.params.get("split_on", -1)) != 0 \
			or float(parent_def.params.get("child_despawn_s", -1.0)) != 0.0:
		failures.append("(A) parent ratified defaults wrong: %s" % [parent_def.params])
	if int(child_def.params.get("generations", -1)) != 0:
		failures.append("(A) child generations default must be 0 (terminal)")
	# Cross-def reference: the id the host's death hook loads resolves to the child
	# def (a dangling child id would be a fail-loud error).
	var xref := load(SplitterHazard.DEF_PATH_FMT
		% String(SplitterHazard.CHILD_DEF_ID)) as OppositionDef
	if xref == null or xref.id != &"splitter_child":
		failures.append("(A) cross-def reference splitter -> splitter_child does not resolve")
	# Host contract on both scenes (bare instance — the schema-test surface).
	for def: OppositionDef in [parent_def, child_def]:
		var root := def.host_scene.instantiate()
		if root == null:
			failures.append("(A) %s host_scene does not instantiate" % def.id)
			continue
		if not root.is_in_group(&"hazard"):
			failures.append("(A) %s host not in 'hazard' group" % def.id)
		if not root.has_method(&"resolve_throw_death") or not root.has_method(&"get_def_id"):
			failures.append("(A) %s host missing the S2 seam surface" % def.id)
		elif StringName(root.call(&"get_def_id")) != def.id:
			failures.append("(A) %s host get_def_id() != def.id" % def.id)
		root.free()


# --- (B) split on throw-death only --------------------------------------------------

func _case_split_on_throw_death(parent_def: OppositionDef, child_def: OppositionDef,
		failures: Array[String]) -> void:
	var svc := _fresh_service()
	var container := _fresh_container()
	svc.begin_band(container, CELL, Vector2.INF, RunConfig.new())
	svc.set_cap_group(&"new_hazards", NEW_HAZARDS_CEILING)

	var parent_cell := Vector2i(5, 5)
	var parent := svc.spawn(parent_def, parent_cell, { "depth": 2 }) as SplitterHazard
	if parent == null:
		failures.append("(B) parent spawn failed (test mis-set)")
		return
	_events.clear()
	var handled: bool = parent.resolve_throw_death(
		{ "item_id": &"scrap", "kind": &"splitter", "depth": 2, "run_t_ms": 111 })
	if not handled:
		failures.append("(B) resolve_throw_death returned false — thrower would double-free")
	if svc.live_count(&"splitter") != 0:
		failures.append("(B) parent still registered after its throw-death")
	if svc.live_count(&"splitter_child") != 2:
		failures.append("(B) expected 2 children, got %d" % svc.live_count(&"splitter_child"))
	# Deterministic ring cells — independent mirror of _ring_offset(k, 2, 28.0):
	# k=0 -> parent_world + (0, -28); k=1 -> parent_world + (0, +28).
	var pw := svc.cell_to_world(parent_cell)
	var want_cells: Array[Vector2i] = [
		svc.world_to_cell(pw + Vector2(0, -28)),
		svc.world_to_cell(pw + Vector2(0, 28)),
	]
	var got_cells: Array[Vector2i] = []
	for inst in svc.live_instances(&"splitter_child"):
		got_cells.append(svc.spawn_cell_of(inst))
	got_cells.sort()
	want_cells.sort()
	if got_cells != want_cells:
		failures.append("(B) child cells %s != deterministic ring %s" % [got_cells, want_cells])
	if _count(&"splitter", &"split") != 1:
		failures.append("(B) expected exactly one &\"split\" row, got %d"
			% _count(&"splitter", &"split"))
	if _count(&"splitter_child", &"spawned") != 2:
		failures.append("(B) expected 2 central &\"spawned\" child rows, got %d"
			% _count(&"splitter_child", &"spawned"))
	if _count(&"splitter", &"split_refused") != 0:
		failures.append("(B) unexpected &\"split_refused\" under an open cap")
	# Children carry parent_speed x child_speed_mult (55 * 1.6 = 88) and are terminal.
	var kids := svc.live_instances(&"splitter_child")
	if kids.is_empty():
		svc.clear_all()
		return   # already reported above — nothing left to probe
	for inst in kids:
		var kid := inst as SplitterHazard
		if kid == null or not is_equal_approx(kid.current_move_speed(), 55.0 * 1.6):
			failures.append("(B) child speed %s != parent x mult (88.0)"
				% (str(kid.current_move_speed()) if kid != null else "null"))
			break
	# A child does NOT re-split (generations 0 is terminal) — but it handles its own
	# death (frees itself through the service).
	_events.clear()
	var kid0 := kids[0] as SplitterHazard
	if not kid0.resolve_throw_death({ "item_id": &"scrap", "kind": &"splitter_child",
			"depth": 2, "run_t_ms": 222 }):
		failures.append("(B) child resolve_throw_death returned false")
	if svc.live_count(&"splitter_child") != 1:
		failures.append("(B) child throw-death left %d registered, expected 1"
			% svc.live_count(&"splitter_child"))
	if _count(&"splitter_child", &"split") != 0 or _count(&"splitter_child", &"spawned") != 0:
		failures.append("(B) a terminal child split (generations 0 must be a clean kill)")
	# A NON-throw removal spawns nothing (the only other removal in M1 is a plain
	# free — band teardown style).
	_events.clear()
	var parent2 := svc.spawn(parent_def, Vector2i(9, 9), {}) as SplitterHazard
	parent2.free()
	if _count(&"splitter_child", &"spawned") != 0 or _count(&"splitter", &"split") != 0:
		failures.append("(B) a plain (non-throw) removal split — split_on broken")
	# Deterministic-per-split: the same throw at the same cell yields the same cells.
	svc.clear_all()
	svc.set_cap_group(&"new_hazards", NEW_HAZARDS_CEILING)
	var parent3 := svc.spawn(parent_def, parent_cell, { "depth": 2 }) as SplitterHazard
	parent3.resolve_throw_death({ "item_id": &"scrap", "kind": &"splitter",
		"depth": 2, "run_t_ms": 333 })
	var again: Array[Vector2i] = []
	for inst in svc.live_instances(&"splitter_child"):
		again.append(svc.spawn_cell_of(inst))
	again.sort()
	if again != want_cells:
		failures.append("(B) repeat split cells %s != first split %s (non-deterministic)"
			% [again, want_cells])
	_teardown(svc, container)


# --- (C) caps refuse — per-def cap + group ceiling + headroom re-open ----------------

func _case_caps(parent_def: OppositionDef, child_def: OppositionDef,
		failures: Array[String]) -> void:
	# (a) per-def per_band_cap = 8: pre-fill 8 children, then force a split — both
	# child requests must be refused (null) with one &"split_refused" row each.
	var svc := _fresh_service()
	var container := _fresh_container()
	svc.begin_band(container, CELL, Vector2.INF, RunConfig.new())
	svc.set_cap_group(&"new_hazards", NEW_HAZARDS_CEILING)
	for i in 8:
		if svc.spawn(child_def, Vector2i(20 + i, 0), {}) == null:
			failures.append("(C) prefill child %d refused under the cap (test mis-set)" % i)
	var parent := svc.spawn(parent_def, Vector2i(5, 5), {}) as SplitterHazard
	_events.clear()
	parent.resolve_throw_death({ "item_id": &"scrap", "kind": &"splitter",
		"depth": 0, "run_t_ms": 0 })
	if svc.live_count(&"splitter_child") != 8:
		failures.append("(C) per_band_cap=8 breached: %d children live"
			% svc.live_count(&"splitter_child"))
	if _count(&"splitter", &"split_refused") != 2:
		failures.append("(C) expected 2 &\"split_refused\" rows at the per-def cap, got %d"
			% _count(&"splitter", &"split_refused"))
	if _count(&"splitter", &"split") != 1:
		failures.append("(C) the parent must still emit its one &\"split\" row at the cap")
	_teardown(svc, container)   # ONE live service at a time (per-dive node contract)

	# (b) the &"new_hazards" group ceiling binds a live mid-run client — and a freed
	# node RE-OPENS headroom (Wave-1 live-registry canon). Ceiling 2: the live parent
	# occupies 1 at split time, so exactly ONE child fits and one is refused; after
	# the parent's despawn the group is back to 1/2 and a direct spawn succeeds.
	var svc2 := _fresh_service()
	var cont2 := _fresh_container()
	svc2.begin_band(cont2, CELL, Vector2.INF, RunConfig.new())
	svc2.set_cap_group(&"new_hazards", 2)
	var parent2 := svc2.spawn(parent_def, Vector2i(5, 5), {}) as SplitterHazard
	_events.clear()
	parent2.resolve_throw_death({ "item_id": &"scrap", "kind": &"splitter",
		"depth": 0, "run_t_ms": 0 })
	if svc2.live_count(&"splitter_child") != 1:
		failures.append("(C) group ceiling 2: expected exactly 1 child (parent live at "
			+ "split time), got %d" % svc2.live_count(&"splitter_child"))
	if _count(&"splitter", &"split_refused") != 1:
		failures.append("(C) expected 1 &\"split_refused\" at the group ceiling, got %d"
			% _count(&"splitter", &"split_refused"))
	if svc2.spawn(child_def, Vector2i(30, 0), {}) == null:
		failures.append("(C) freed parent did not re-open group headroom (live-registry canon)")
	_teardown(svc2, cont2)


# --- (D) generation fingerprint unmoved by a forced mid-run split --------------------

func _case_fingerprint(parent_def: OppositionDef, failures: Array[String]) -> void:
	var profile := load(PROFILE_PATH) as BandProfile
	if profile == null:
		failures.append("(D) could not load %s" % PROFILE_PATH)
		return
	var pipe := BandPipeline.new()
	var all_off := RunConfig.new()
	var before := pipe.generate(profile, 12345, all_off)
	if before == null or before.fingerprint().substr(0, 12) != BASELINE_FP:
		failures.append("(D) all-off fp %s != baseline %s"
			% [before.fingerprint().substr(0, 12) if before != null else "null", BASELINE_FP])
	var fp_before: String = before.fingerprint() if before != null else ""
	# Force a split mid-"run", proving it consumes NOTHING from the RNG stream.
	RNG.seed_from(777)
	var svc := _fresh_service()
	var container := _fresh_container()
	svc.begin_band(container, CELL, Vector2.INF, all_off)
	svc.set_cap_group(&"new_hazards", NEW_HAZARDS_CEILING)
	var parent := svc.spawn(parent_def, Vector2i(5, 5), {}) as SplitterHazard
	parent.resolve_throw_death({ "item_id": &"scrap", "kind": &"splitter",
		"depth": 0, "run_t_ms": 0 })
	if svc.live_count(&"splitter_child") != 2:
		failures.append("(D) forced split did not produce children (vacuous fp check)")
	var next_draw: int = RNG.randi()
	RNG.seed_from(777)
	if next_draw != RNG.randi():
		failures.append("(D) the split consumed from the global RNG stream")
	# Regenerate: byte-identical fingerprint despite the live split.
	var after := pipe.generate(profile, 12345, all_off)
	if after == null or after.fingerprint() != fp_before:
		failures.append("(D) fp moved across a mid-run split: %s != %s"
			% [after.fingerprint() if after != null else "null", fp_before])
	_teardown(svc, container)
	_free_band(before)
	_free_band(after)


# --- (E) the L5 kills gate holds for children ----------------------------------------

func _case_kills_gate(child_def: OppositionDef, failures: Array[String]) -> void:
	# A player stub must exist BEFORE begin_band (the service resolves it there).
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)

	# kills=false (ctx override — the harness/sweep tier): contact emits, run survives.
	var svc := _fresh_service()
	var container := _fresh_container()
	svc.begin_band(container, CELL, Vector2.INF, RunConfig.new())
	svc.set_cap_group(&"new_hazards", NEW_HAZARDS_CEILING)
	var cell := Vector2i(3, 3)
	player.global_position = svc.cell_to_world(cell)
	_events.clear()
	_killed_rows.clear()
	_run_ends.clear()
	var soft := svc.spawn(child_def, cell, { "kills": false }) as SplitterHazard
	for i in 3:
		await get_tree().physics_frame
	if _count(&"splitter_child", &"hit_player") < 1:
		failures.append("(E) kills=false contact emitted no &\"hit_player\" row")
	if not _killed_rows.is_empty() or not _run_ends.is_empty():
		failures.append("(E) kills=false catch ended the run / emitted killed_player")
	svc.despawn(soft)

	# kills=true (the def default): catch -> fail_run(&"death") + killed_player row.
	GameState.start_run(&"test_band", 4242)
	_events.clear()
	_killed_rows.clear()
	_run_ends.clear()
	var hard := svc.spawn(child_def, cell, {}) as SplitterHazard
	for i in 3:
		await get_tree().physics_frame
	if hard == null:
		failures.append("(E) kills=true child spawn failed")
	if _run_ends.size() != 1 or _run_ends[0][0] != &"death":
		failures.append("(E) kills=true catch did not end the run with &\"death\": %s"
			% [_run_ends])
	var tagged := false
	for row in _killed_rows:
		if row[0] == &"splitter_child":
			tagged = true
	if not tagged:
		failures.append("(E) no opposition_killed_player(&\"splitter_child\") row")
	_teardown(svc, container)
	player.free()   # IMMEDIATE — a queue_freed player would still resolve in the
	                # next case's begin_band group lookup


# --- (F) the child_despawn_s mercy knob ----------------------------------------------

func _case_despawn_timer(child_def: OppositionDef, failures: Array[String]) -> void:
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	player.global_position = Vector2(10_000, 10_000)   # far — no catch, no chase reach
	var svc := _fresh_service()
	var container := _fresh_container()
	svc.begin_band(container, CELL, Vector2.INF, RunConfig.new())
	svc.set_cap_group(&"new_hazards", NEW_HAZARDS_CEILING)
	var timed := svc.spawn(child_def, Vector2i(2, 2), { "params": {
		"move_speed": 0.0, "catch_radius": 0.0, "child_despawn_s": 0.1 } }) as SplitterHazard
	if timed == null:
		failures.append("(F) timed child spawn failed")
	for i in 12:   # ~0.2 s of physics frames at 60 Hz
		await get_tree().physics_frame
	if svc.live_count(&"splitter_child") != 0:
		failures.append("(F) child_despawn_s > 0 did not despawn the child")
	_teardown(svc, container)
	player.free()


# --- (G) generic vocabulary only ------------------------------------------------------

func _case_vocabulary(failures: Array[String]) -> void:
	# Everything recorded across the whole run must use the S6b vocabulary on the
	# generic channel (payloads are primitives by signal signature).
	var allowed: Array[StringName] = [&"spawned", &"split", &"split_refused", &"hit_player"]
	for row in _events:
		if row[0] == &"splitter" or row[0] == &"splitter_child":
			if not allowed.has(row[1]):
				failures.append("(G) unexpected event %s on the generic channel" % [row])
				return


# --- plumbing ---------------------------------------------------------------------

func _on_opposition_event(id: StringName, event: StringName, depth: int, run_t_ms: int) -> void:
	_events.append([id, event, depth, run_t_ms])


func _on_killed_player(id: StringName, depth: int, run_t_ms: int) -> void:
	_killed_rows.append([id, depth, run_t_ms])


func _on_run_ended(reason: StringName, duration_s: float, depth: int) -> void:
	_run_ends.append([reason, duration_s, depth])


func _count(id: StringName, event: StringName) -> int:
	var n := 0
	for row in _events:
		if row[0] == id and row[1] == event:
			n += 1
	return n


## End-of-case teardown: clear the registry, then FREE the service node immediately
## so it leaves the &"spawn_service" group — the host resolves the service by group,
## and production only ever has ONE live service (the per-dive node). The container
## is queue_freed (its remaining children are already queue_freed by clear_all).
func _teardown(svc: SpawnService, container: Node2D) -> void:
	svc.clear_all()
	svc.free()
	container.queue_free()


func _fresh_service() -> SpawnService:
	var svc := SpawnService.new()
	add_child(svc)
	return svc


func _fresh_container() -> Node2D:
	var c := Node2D.new()
	add_child(c)
	return c


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
