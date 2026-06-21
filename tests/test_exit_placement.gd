extends Node
## Headless acceptance test for K7 (M1.4) — configurable random/multiple exit placement.
##
## Run as a SCENE (autoloads + a live tree) so MainGame's script resolves exactly as in
## the real game, and so ExtractGate._ready()'s EventBus connect works:
##   godot --headless res://tests/test_exit_placement.tscn
##
## K7 replaces the single hand-offset extract gate with one-to-many gates placed across the
## band's floor cells. The all-off control (exit_enabled=false) reproduces M1.3 exactly:
## a single gate at spawn_pos + GATE_SPAWN_OFFSET (so fingerprint() is structurally
## untouched — placement is run-state, downstream of generation). Enabled exits scale with
## depth and are placed via a LOCAL sub-stream seeded run_seed ^ EXITS_RNG_SALT (NEVER the
## global RNG autoload), so they are reproducible per run yet random across seeds.
##
## Asserts (per the K7 spec §D + Resolved Decisions DR-1..DR-7):
##   (a) ALL-OFF IDENTITY: RunConfig.new() (or no config) → exactly ONE gate at
##       spawn_pos + GATE_SPAWN_OFFSET (the M1.3 control; _gates.size() == 1).
##   (b) REPRODUCIBILITY (Strategy A): same run_seed + same exit_* config → identical gate
##       positions across two independent builds (local sub-stream determinism).
##   (c) DEPTH SCALING: _exit_count_for_depth = clamp(maxi(base,1) + floor(per_depth*depth),
##       1, max_or_inf), re-floored at 1 after the cap.
##   (d) KEEP-AT-SPAWN: exit_keep_one_at_spawn=true → one gate exactly at the spawn offset,
##       the rest elsewhere (none on the entry cell).
##   (e) MULTI-GATE EXTRACT SAFETY: with N gates, interacting any one ends the run exactly
##       once (run_ended fires once; the GameState._run_ended guard holds; same-id gates do
##       not cross-fire — node-identity guard at extract_gate.gd:45).

const MAIN_GAME_SCRIPT := "res://scenes/game/main_game.gd"
const GATE_SCENE_PATH := "res://entities/gate/extract_gate.tscn"
const RunConfigScript := preload("res://data/run_config/run_config.gd")

const CELL := 16   # MainGame.DEFAULT_CELL_SIZE_PX (the bare-instance _band_cell_size_px)


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	var mg_script := load(MAIN_GAME_SCRIPT) as GDScript
	if mg_script == null:
		printerr("K7 FAIL: could not load %s" % MAIN_GAME_SCRIPT)
		return 1

	# --- (a) ALL-OFF IDENTITY: one gate at spawn_pos + GATE_SPAWN_OFFSET ------------
	_test_all_off(mg_script, failures)
	# Belt-and-braces: nil active_run_config short-circuits to the same single fixed gate.
	_test_no_config(mg_script, failures)

	# --- (c) DEPTH SCALING (pure helper, no tree needed) ---------------------------
	_test_depth_scaling(mg_script, failures)

	# --- (b) REPRODUCIBILITY (Strategy A local sub-stream) -------------------------
	_test_reproducibility(mg_script, failures)

	# --- (d) KEEP-AT-SPAWN ---------------------------------------------------------
	_test_keep_at_spawn(mg_script, failures)

	# --- (e) MULTI-GATE EXTRACT SAFETY ---------------------------------------------
	_test_multi_gate_extract(failures)

	if failures.is_empty():
		print("K7 OK — exit placement verified: all-off → exactly 1 gate at GATE_SPAWN_OFFSET "
			+ "(M1.3 control, fp untouched), enabled count = clamp(maxi(base,1)+floor(per_depth*depth),"
			+ "1,max) re-floored at 1, Strategy-A placement reproducible per seed via run_seed ^ "
			+ "EXITS_RNG_SALT (no global RNG), keep-at-spawn pins one gate at the offset (none on entry), "
			+ "and N same-id gates end the run exactly once (node-identity guard + _run_ended).")
		return 0
	for f in failures:
		printerr("K7 FAIL: ", f)
	return 1


## A MainGame instance wired enough to spawn gates WITHOUT firing MainGame._ready() (which
## needs many @onready scene deps absent on a bare instance). We keep `mg` out of the tree
## and inject a _band_container that IS in THIS test's tree, so _spawn_gate_at's
## _band_container.add_child(gate) puts each gate in a live tree → gate._ready() (EventBus
## connect) fires. _band_cell_size_px stays at the default 16 on the bare instance.
func _make_mg() -> Node:
	var mg = load(MAIN_GAME_SCRIPT).new()
	var container := Node2D.new()
	mg._band_container = container
	add_child(container)   # container (not mg) goes in the tree
	return mg


func _test_all_off(mg_script: GDScript, failures: Array[String]) -> void:
	var mg := _make_mg()
	GameState.active_run_config = RunConfigScript.new()   # exit_enabled defaults false
	var band := _make_band([4, 4, 4])
	var spawn_pos := Vector2(8, 8)
	mg._place_gate(band, spawn_pos)
	if mg._gates.size() != 1:
		failures.append("(a) all-off produced %d gates, expected exactly 1" % mg._gates.size())
	elif mg._gates[0].global_position != spawn_pos + GameState.GATE_SPAWN_OFFSET:
		failures.append("(a) all-off gate at %s, expected %s (spawn + GATE_SPAWN_OFFSET)"
			% [str(mg._gates[0].global_position), str(spawn_pos + GameState.GATE_SPAWN_OFFSET)])
	_free_band(band)
	mg.free()


func _test_no_config(mg_script: GDScript, failures: Array[String]) -> void:
	var mg := _make_mg()
	GameState.active_run_config = null
	var band := _make_band([4, 4])
	var spawn_pos := Vector2(8, 8)
	mg._place_gate(band, spawn_pos)
	if mg._gates.size() != 1:
		failures.append("(a) nil-config produced %d gates, expected exactly 1" % mg._gates.size())
	elif mg._gates[0].global_position != spawn_pos + GameState.GATE_SPAWN_OFFSET:
		failures.append("(a) nil-config gate not at GATE_SPAWN_OFFSET")
	_free_band(band)
	mg.free()


func _test_depth_scaling(mg_script: GDScript, failures: Array[String]) -> void:
	var mg = mg_script.new()   # bare instance — _exit_count_for_depth is a pure read

	# base 1, per_depth 0 → always 1, regardless of depth.
	var rc0 := RunConfigScript.new()
	rc0.exit_base_count = 1
	rc0.exit_count_per_depth = 0.0
	if mg._exit_count_for_depth(rc0, 0) != 1 or mg._exit_count_for_depth(rc0, 10) != 1:
		failures.append("(c) base 1, per_depth 0 should be 1 at any depth, got d0=%d d10=%d"
			% [mg._exit_count_for_depth(rc0, 0), mg._exit_count_for_depth(rc0, 10)])

	# base 0 floors to 1 at depth 0 (never zero exits).
	var rcz := RunConfigScript.new()
	rcz.exit_base_count = 0
	rcz.exit_count_per_depth = 0.0
	if mg._exit_count_for_depth(rcz, 0) != 1:
		failures.append("(c) base 0 should floor to 1 at depth 0, got %d" % mg._exit_count_for_depth(rcz, 0))

	# base 2 + 0.5/depth at depth 6 → 2 + floor(3.0) = 5.
	var rc1 := RunConfigScript.new()
	rc1.exit_base_count = 2
	rc1.exit_count_per_depth = 0.5
	var got6: int = mg._exit_count_for_depth(rc1, 6)
	if got6 != 5:
		failures.append("(c) base 2 + 0.5*6 should be 5, got %d" % got6)
	# at depth 0 it's just base (2).
	if mg._exit_count_for_depth(rc1, 0) != 2:
		failures.append("(c) base 2 at depth 0 should be 2, got %d" % mg._exit_count_for_depth(rc1, 0))

	# exit_max_count caps: base 2 + 1.0*10 = 12, capped to 3.
	var rc2 := RunConfigScript.new()
	rc2.exit_base_count = 2
	rc2.exit_count_per_depth = 1.0
	rc2.exit_max_count = 3
	var capped: int = mg._exit_count_for_depth(rc2, 10)
	if capped != 3:
		failures.append("(c) exit_max_count 3 should cap 12 to 3, got %d" % capped)

	# DR-2: re-floor at 1 after the cap — a max_count of 1 with high ramp still yields >= 1.
	var rc3 := RunConfigScript.new()
	rc3.exit_base_count = 5
	rc3.exit_count_per_depth = 2.0
	rc3.exit_max_count = 1
	if mg._exit_count_for_depth(rc3, 9) != 1:
		failures.append("(c) exit_max_count 1 should clamp to exactly 1, got %d"
			% mg._exit_count_for_depth(rc3, 9))

	mg.free()


func _test_reproducibility(mg_script: GDScript, failures: Array[String]) -> void:
	# Strategy A is reproducible per (run_seed, config). Drive _place_gate twice on two
	# independent builds with the SAME seed + config → identical gate positions.
	GameState.run_seed = 0xC0FFEE
	var rc := RunConfigScript.new()
	rc.exit_enabled = true
	rc.exit_base_count = 4
	rc.exit_count_per_depth = 0.0
	rc.exit_keep_one_at_spawn = false
	GameState.active_run_config = rc

	var pos_a := _build_positions(mg_script, [60, 60, 60], Vector2(8, 8))
	var pos_b := _build_positions(mg_script, [60, 60, 60], Vector2(8, 8))
	if pos_a != pos_b:
		failures.append("(b) Strategy A not reproducible for same seed+config: %s vs %s"
			% [str(pos_a), str(pos_b)])
	if pos_a.size() != 4:
		failures.append("(b) expected 4 gates (base 4), got %d" % pos_a.size())

	# A different seed should generally produce a DIFFERENT layout (random across seeds).
	GameState.run_seed = 0xBADF00D
	var pos_c := _build_positions(mg_script, [60, 60, 60], Vector2(8, 8))
	if pos_c == pos_a:
		failures.append("(b) different seed produced identical layout — not seed-varied")


func _test_keep_at_spawn(mg_script: GDScript, failures: Array[String]) -> void:
	GameState.run_seed = 0x1234
	var rc := RunConfigScript.new()
	rc.exit_enabled = true
	rc.exit_base_count = 3
	rc.exit_count_per_depth = 0.0
	rc.exit_keep_one_at_spawn = true
	GameState.active_run_config = rc

	var spawn_pos := Vector2(8, 8)
	var mg := _make_mg()
	var band := _make_band([60, 60, 60])
	mg._place_gate(band, spawn_pos)

	var n: int = mg._gates.size()
	if n != 3:
		failures.append("(d) keep-at-spawn base 3 produced %d gates, expected 3" % n)

	var offset_pos := spawn_pos + GameState.GATE_SPAWN_OFFSET
	var entry_pos: Vector2 = mg._density_cell_to_world(mg._world_to_cell(spawn_pos))
	var at_offset := 0
	var on_entry := 0
	for g in mg._gates:
		if g.global_position == offset_pos:
			at_offset += 1
		if g.global_position == entry_pos:
			on_entry += 1
	if at_offset != 1:
		failures.append("(d) expected exactly 1 gate at the spawn offset, got %d" % at_offset)
	if on_entry != 0:
		failures.append("(d) a gate landed on the entry cell (%d) — entry must be excluded" % on_entry)

	_free_band(band)
	mg.free()


func _test_multi_gate_extract(failures: Array[String]) -> void:
	# Spawn N real ExtractGates (same id) and confirm interacting any one ends the run
	# exactly once. Uses the live EventBus + GameState the gates listen on.
	var gate_scene := load(GATE_SCENE_PATH) as PackedScene
	if gate_scene == null:
		failures.append("(e) gate scene missing at %s" % GATE_SCENE_PATH)
		return

	# Put GameState into an active run so extract_and_end_run() has a run to end.
	GameState.start_run(&"test_band", 123)

	var gates: Array = []
	for i in 4:
		var g = gate_scene.instantiate()
		add_child(g)
		gates.append(g)

	var ended := {"count": 0}
	# run_ended(reason: StringName, duration_s: float, depth_reached: int) — match arity.
	var on_ended := func(_reason: StringName, _dur: float, _depth: int) -> void:
		ended["count"] += 1
	EventBus.run_ended.connect(on_ended)

	# Interact the FIRST gate: focus its own child Interactable so the node-identity guard
	# (extract_gate.gd:45) passes for that gate only.
	var first: Node = gates[0]
	var focus_target: Node = _interactable_child(first)
	EventBus.interaction_requested.emit(&"gate", focus_target)

	# A SECOND interact (a different gate, or a re-press) must NOT end the run again.
	var second: Node = gates[1]
	EventBus.interaction_requested.emit(&"gate", _interactable_child(second))
	EventBus.interaction_requested.emit(&"gate", focus_target)

	if ended["count"] != 1:
		failures.append("(e) run_ended fired %d times across N-gate interacts, expected exactly 1"
			% ended["count"])

	EventBus.run_ended.disconnect(on_ended)
	for g in gates:
		g.queue_free()


## Find a gate's child Interactable node so the emitted request passes the node-identity
## guard (target.get_parent() == the gate). Falls back to the gate itself if none found.
func _interactable_child(gate: Node) -> Node:
	for c in gate.get_children():
		if String(c.name).to_lower().contains("interactable"):
			return c
	# Any child whose parent is the gate satisfies the guard; pick the first child.
	if gate.get_child_count() > 0:
		return gate.get_child(0)
	return gate


## Build the placed gate world positions for the current GameState config/seed.
func _build_positions(mg_script: GDScript, areas: Array, spawn_pos: Vector2) -> Array[Vector2]:
	var mg := _make_mg()
	var band := _make_band(areas)
	mg._place_gate(band, spawn_pos)
	var out: Array[Vector2] = []
	for g in mg._gates:
		out.append(g.global_position)
	_free_band(band)
	mg.free()
	return out


## A graded linear band: pieces at depth_index 0..N-1, each with `areas[i]` floor cells in a
## contiguous block. band.max_depth set as DepthGrader.grade() would leave it. Cells are laid
## out in well-separated per-piece blocks so the entry cell is unambiguous.
func _make_band(areas: Array) -> Band:
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
	band.entry_piece = band.pieces[0]
	band.deepest_piece = band.pieces[band.pieces.size() - 1]
	band.max_depth = max_depth
	return band


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
