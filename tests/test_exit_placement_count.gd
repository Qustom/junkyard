extends Node
## FB5 (M1.4 Wave 5) — regression guard for Director feedback #5:
##   "When exit configurations are enabled, they don't seem to spawn any while heading
##    further in."
##
## This test exists to PROVE that multi-exit placement is NOT broken, using the EXACT
## config the Director ran (the run-19 snapshot in design/M1_4_Tasks/G4_findings_M1.4.md):
##   exit_enabled = true, exit_base_count = 2, exit_count_per_depth = 2.0,
##   exit_keep_one_at_spawn = true.
##
## Run as a SCENE (autoloads + a live tree) so MainGame's @class_name script resolves and
## ExtractGate._ready()'s EventBus connect fires:
##   godot --headless res://tests/test_exit_placement_count.tscn
##
## Asserts (the FB5 brief's three checks):
##   (a) ENABLED COUNT: at the Director's config, the number of gates PLACED equals
##       _exit_count_for_depth(rc, depth) AND is > 1 at a non-trivial depth (depth >= 1).
##   (b) DISTINCT + SCATTERED: the placed gates sit at DISTINCT world positions spread
##       across MULTIPLE graded pieces (not all stacked at the spawn offset).
##   (c) ALL-OFF CONTROL: exit_enabled = false places EXACTLY ONE gate at the spawn offset.
##
## Determinism note: exit placement uses a LOCAL RNG seeded run_seed ^ EXITS_RNG_SALT, never
## the global RNG autoload, so it is reproducible per run yet never moves fingerprint()
## (placement is run-state, downstream of generation). This test does not touch generation,
## so the all-off fingerprint e943ac9c8bc1 is unaffected.

const MAIN_GAME_SCRIPT := "res://scenes/game/main_game.gd"
const RunConfigScript := preload("res://data/run_config/run_config.gd")

const CELL := 16   # MainGame.DEFAULT_CELL_SIZE_PX (the bare-instance _band_cell_size_px)


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	var mg_script := load(MAIN_GAME_SCRIPT) as GDScript
	if mg_script == null:
		printerr("FB5 FAIL: could not load %s" % MAIN_GAME_SCRIPT)
		return 1

	_test_directors_config_multi_exit(failures)   # (a) + (b)
	_test_all_off_single_gate(failures)            # (c)

	if failures.is_empty():
		print("FB5/EXIT-COUNT OK — exit placement MATH is correct: Director's config "
			+ "(exit_enabled, base=2, per_depth=2.0, keep_one_at_spawn) places the "
			+ "depth-scaled count of DISTINCT gates scattered across multiple pieces "
			+ "(>1 at depth>=1); all-off places exactly ONE gate at the spawn offset. "
			+ "NOTE: the LIVE 'exits never spawn' report was BUG10 (a wiring bug — _place_gate "
			+ "read the cleared GameState.active_run_config instead of the run's resolved config), "
			+ "NOT a placement-math defect; fixed + regression-guarded in test_exit_placement (f).")
		return 0
	for f in failures:
		printerr("FB5 FAIL: ", f)
	return 1


## (a) + (b): the Director's exact config places _exit_count_for_depth gates, > 1 at a
## non-trivial depth, at distinct positions spread over multiple pieces. We exercise a
## small range of depths to show the count scales and is never collapsed to 1.
func _test_directors_config_multi_exit(failures: Array[String]) -> void:
	GameState.run_seed = 0x5EED5   # any fixed seed; placement is reproducible per seed
	var rc := RunConfigScript.new()
	rc.exit_enabled = true
	rc.exit_base_count = 2
	rc.exit_count_per_depth = 2.0
	rc.exit_keep_one_at_spawn = true
	GameState.active_run_config = rc

	# A 4-piece graded band → max_depth = 3 (a "heading further in" band).
	# depth=3 → count = maxi(2,1) + floor(2.0*3) = 2 + 6 = 8 gates.
	var mg := _make_mg()
	var band := _make_band([40, 40, 40, 40])
	var depth: int = band.max_depth
	var expected: int = mg._exit_count_for_depth(rc, depth)
	var spawn_pos := Vector2(8, 8)
	mg._place_gate(band, spawn_pos, rc)

	var n: int = mg._gates.size()

	# (a) count placed == the depth-scaled count, and is > 1 at this non-trivial depth.
	if expected <= 1:
		failures.append("(a) expected count should be > 1 at depth %d, helper returned %d"
			% [depth, expected])
	if n != expected:
		failures.append("(a) placed %d gates, _exit_count_for_depth returned %d (depth %d) — "
			% [n, expected, depth] + "placement does NOT honour the depth-scaled count")
	if n <= 1:
		failures.append("(a) only %d gate(s) placed at depth %d with the Director's config — "
			% [n, depth] + "this WOULD be the reported bug (no multi-exit while heading in)")

	# (b) DISTINCT positions: no two gates stacked.
	var seen := {}
	var distinct := 0
	for g in mg._gates:
		var key := str(g.global_position)
		if not seen.has(key):
			seen[key] = true
			distinct += 1
	if distinct != n:
		failures.append("(b) gates not at distinct positions: %d gates, %d distinct"
			% [n, distinct])

	# (b) SCATTERED across MULTIPLE pieces, not all at the spawn offset. Map each gate's
	# world pos back to a cell, then to which piece's cell-block it belongs to.
	var offset_pos := spawn_pos + GameState.GATE_SPAWN_OFFSET
	var at_offset := 0
	var pieces_hit := {}
	for g in mg._gates:
		if g.global_position == offset_pos:
			at_offset += 1
		var cell: Vector2i = mg._world_to_cell(g.global_position)
		var piece_idx: int = _which_piece(band, cell)
		if piece_idx >= 0:
			pieces_hit[piece_idx] = true
	if at_offset >= n:
		failures.append("(b) all %d gates are stacked at the spawn offset — none scattered "
			% n + "into the level (this IS the reported #5 symptom)")
	# keep_one_at_spawn pins exactly ONE at the offset; the other n-1 are scattered.
	if at_offset != 1:
		failures.append("(b) keep_one_at_spawn=true should pin exactly 1 gate at the spawn "
			+ "offset, found %d" % at_offset)
	# The scattered gates must hit more than one graded piece (spread "around the level").
	if pieces_hit.size() < 2:
		failures.append("(b) gates land in only %d piece(s); a depth-spanning band should "
			% pieces_hit.size() + "scatter exits across multiple pieces")

	_free_band(band)
	mg.free()

	# Belt-and-braces: at a SHALLOW band (depth 1) the count is still > 1 (2 + floor(2.0) = 4),
	# proving the multi-exit isn't gated to deep bands only.
	var mg2 := _make_mg()
	var band2 := _make_band([40, 40])   # max_depth = 1
	var exp2: int = mg2._exit_count_for_depth(rc, band2.max_depth)
	mg2._place_gate(band2, Vector2(8, 8), rc)
	if exp2 <= 1 or mg2._gates.size() != exp2:
		failures.append("(a) shallow band depth %d: placed %d, expected %d (should be > 1)"
			% [band2.max_depth, mg2._gates.size(), exp2])
	_free_band(band2)
	mg2.free()


## (c): the all-off control (exit_enabled = false) places EXACTLY ONE gate at the offset.
func _test_all_off_single_gate(failures: Array[String]) -> void:
	var rc := RunConfigScript.new()   # exit_enabled defaults false
	var mg := _make_mg()
	var band := _make_band([40, 40, 40, 40])
	var spawn_pos := Vector2(8, 8)
	mg._place_gate(band, spawn_pos, rc)
	if mg._gates.size() != 1:
		failures.append("(c) all-off produced %d gates, expected exactly 1" % mg._gates.size())
	elif mg._gates[0].global_position != spawn_pos + GameState.GATE_SPAWN_OFFSET:
		failures.append("(c) all-off gate at %s, expected %s (spawn + GATE_SPAWN_OFFSET)"
			% [str(mg._gates[0].global_position), str(spawn_pos + GameState.GATE_SPAWN_OFFSET)])
	_free_band(band)
	mg.free()


## A MainGame instance wired enough to spawn gates WITHOUT firing MainGame._ready() (which
## needs many @onready scene deps absent on a bare instance). _band_container is injected and
## lives in THIS test's tree so _spawn_gate_at's add_child puts gates in a live tree →
## gate._ready() (EventBus connect) fires. _band_cell_size_px stays at the default 16.
func _make_mg() -> Node:
	var mg = load(MAIN_GAME_SCRIPT).new()
	var container := Node2D.new()
	mg._band_container = container
	add_child(container)
	return mg


## Which graded piece (index into band.pieces) does a band-global cell fall in? Each test
## piece occupies a 20-wide cell block at x = depth_index * 100 (see _make_band).
func _which_piece(band: Band, cell: Vector2i) -> int:
	for i in band.pieces.size():
		var base_x: int = band.pieces[i].offset_cell.x
		if cell.x >= base_x and cell.x < base_x + 20:
			return i
	return -1


## A graded linear band: pieces at depth_index 0..N-1, each with `areas[i]` floor cells in a
## contiguous block (well-separated per piece so the entry cell is unambiguous). max_depth set
## as DepthGrader.grade() would leave it. Mirrors test_exit_placement.gd's builder.
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
