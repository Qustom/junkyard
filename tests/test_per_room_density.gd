extends Node
## Headless acceptance test for J3 (M1.3) — per-room size-scaled hazard density.
##
## Run as a SCENE (autoloads + a live tree) so MainGame's script resolves exactly as in
## the real game:
##   godot --headless res://tests/test_per_room_density.tscn
##
## J3 seeds EXTRA hazards per room, scaled by each room's size, ADDITIVELY on top of J2's
## depth-spread budget (G4 §5 F3b "a hazard per room" — big rooms aren't empty fields). The
## per-room budget + placement is a PURE function of (band, rc) — MainGame._density_spawn_
## positions(band, rc) — with NO RNG and NO node state. This test drives that helper directly
## against hand-built graded bands (mirroring test_hazard_spread.gd's J2 approach).
##
## Asserts (per the Director Disposition + the J3 spec §(b) / Resolved Decisions):
##   (a) ALL-OFF: r1_per_room_density == 0 → ZERO density positions (the M1.2 control; no node).
##   (b) SCALES WITH ROOM SIZE: a bigger room (more floor_cells) earns >= as many density
##       hazards as a smaller one, and a genuinely big room earns >= 1 (cell_area metric).
##   (c) BUDGET MATH: n == floor(density * cell_area / R1_DENSITY_AREA_UNIT), capped.
##   (d) CAP honoured: r1_density_per_room_cap bounds the per-room count.
##   (e) MIN-AREA + ROOMS-ONLY filters: pieces at/below the area floor and (rooms_only)
##       corridors earn zero density hazards.
##   (f) DETERMINISM: same (band, rc) → byte-identical position list every call (no RNG).
##   (g) px_area metric scales by lvl_size_mult^2 (and the band ceiling bounds the worst case).
##   (h) BAND CEILING: total density hazards never exceed R1_DENSITY_BAND_CEILING.

const MAIN_GAME_SCRIPT := "res://scenes/game/main_game.gd"
const RunConfigScript := preload("res://data/run_config/run_config.gd")


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	var mg_script := load(MAIN_GAME_SCRIPT) as GDScript
	if mg_script == null:
		printerr("J3 FAIL: could not load %s" % MAIN_GAME_SCRIPT)
		return 1
	var mg = mg_script.new()

	var unit := RunConfigScript.R1_DENSITY_AREA_UNIT
	var ceiling := RunConfigScript.R1_DENSITY_BAND_CEILING

	# --- (a) all-off → zero density positions --------------------------------------
	var band := _make_band([32, 96, 200])   # corridor-ish, mid, big
	var rc_off := _rc(0.0)                   # density OFF (M1.2 control)
	var off: Array = mg._density_spawn_positions(band, rc_off)
	if off.size() != 0:
		failures.append("(a) all-off produced %d density positions, expected 0" % off.size())

	# --- (b)+(c) budget math + scales with room size (cell_area, uncapped) ----------
	# density 1.0, no min-area, no cap. Each room earns floor(1.0 * cells / unit).
	var rc1 := _rc(1.0)
	var p1: Array = mg._density_spawn_positions(band, rc1)
	var want_total := 0
	for cells in [32, 96, 200]:
		want_total += int(floor(1.0 * float(cells) / float(unit)))
	if p1.size() != want_total:
		failures.append("(c) density 1.0 produced %d positions, expected %d (sum of floor(cells/unit))" % [p1.size(), want_total])
	# The big room (200 cells) alone must earn >= 1 at density 1.0 (unit 96 → floor(200/96)=2).
	var big_only := _make_band([200])
	var big_n: Array = mg._density_spawn_positions(big_only, _rc(1.0))
	var big_expect := int(floor(1.0 * 200.0 / float(unit)))
	if big_n.size() != big_expect:
		failures.append("(b) big 200-cell room earned %d, expected %d" % [big_n.size(), big_expect])
	if big_n.size() < 1:
		failures.append("(b) big room earned 0 density hazards (huge rooms must fill)")
	# Monotonic: a bigger room earns >= a smaller one (same density, no cap).
	var small_n: Array = mg._density_spawn_positions(_make_band([96]), _rc(1.0))
	if big_n.size() < small_n.size():
		failures.append("(b) bigger room earned FEWER hazards than smaller (%d < %d) — not size-scaled" % [big_n.size(), small_n.size()])

	# --- (d) per-room cap honoured -------------------------------------------------
	# A massive room (2000 cells) at density 1.0 would earn ~20; cap to 3.
	var huge := _make_band([2000])
	var rc_cap := _rc(1.0)
	rc_cap.r1_density_per_room_cap = 3
	var capped: Array = mg._density_spawn_positions(huge, rc_cap)
	if capped.size() != 3:
		failures.append("(d) per-room cap 3 produced %d (cap not honoured)" % capped.size())

	# --- (e) min-area + rooms-only filters -----------------------------------------
	# min-area 100: only the 200-cell room qualifies (32 and 96 are <= 100).
	var rc_min := _rc(1.0)
	rc_min.r1_density_min_area = 100
	var filtered: Array = mg._density_spawn_positions(band, rc_min)
	var want_filtered := int(floor(1.0 * 200.0 / float(unit)))   # only the 200-cell room
	if filtered.size() != want_filtered:
		failures.append("(e) min-area 100 produced %d, expected %d (only the >100-cell room)" % [filtered.size(), want_filtered])
	# rooms_only: corridors earn none. Build a corridor + a room, both above the unit.
	var mixed := _make_band_ids([
		["piece_corridor_long_h", 200],   # corridor — excluded by rooms_only
		["piece_room_xl", 200],            # room — included
	])
	var rc_rooms := _rc(1.0)
	rc_rooms.r1_density_rooms_only = true
	var rooms_only: Array = mg._density_spawn_positions(mixed, rc_rooms)
	var want_rooms := int(floor(1.0 * 200.0 / float(unit)))      # only the room piece
	if rooms_only.size() != want_rooms:
		failures.append("(e) rooms_only produced %d, expected %d (corridor excluded)" % [rooms_only.size(), want_rooms])
	# Without rooms_only BOTH pieces earn density (corridor included).
	var rc_both := _rc(1.0)
	var both: Array = mg._density_spawn_positions(mixed, rc_both)
	if both.size() != 2 * want_rooms:
		failures.append("(e) without rooms_only produced %d, expected %d (both pieces)" % [both.size(), 2 * want_rooms])

	# --- (f) determinism: same (band, rc) → byte-identical positions ---------------
	var a: Array = mg._density_spawn_positions(band, rc1)
	var b: Array = mg._density_spawn_positions(band, rc1)
	if a != b:
		failures.append("(f) density positions not deterministic across calls (%s vs %s)" % [str(a), str(b)])

	# --- (g) px_area metric scales by lvl_size_mult^2 ------------------------------
	# cell_area: a 96-cell room at density 1.0 earns floor(96/96)=1.
	# px_area at lvl_size_mult 2.0: area = 96 * 4 = 384 → floor(384/96)=4 (but capped below).
	var px_band := _make_band([96])
	var rc_px := _rc(1.0)
	rc_px.r1_density_metric = 1          # px_area
	rc_px.lvl_enabled = true
	rc_px.lvl_size_mult = 2.0
	rc_px.r1_density_per_room_cap = 16   # high cap so the metric difference shows
	var px: Array = mg._density_spawn_positions(px_band, rc_px)
	var rc_cell := _rc(1.0)
	rc_cell.r1_density_per_room_cap = 16
	var cell: Array = mg._density_spawn_positions(px_band, rc_cell)
	if not (px.size() > cell.size()):
		failures.append("(g) px_area (%d) did not exceed cell_area (%d) at lvl_size_mult 2.0" % [px.size(), cell.size()])
	var want_px := int(floor(1.0 * 96.0 * 4.0 / float(unit)))   # 96 cells * 2^2 = 384
	if px.size() != want_px:
		failures.append("(g) px_area produced %d, expected %d (cell_area * mult^2)" % [px.size(), want_px])

	# --- (h) band-wide ceiling caps the total -------------------------------------
	# Many huge rooms, uncapped per-room, px_area at high mult → would explode without the
	# band ceiling. Assert the total never exceeds R1_DENSITY_BAND_CEILING.
	var areas: Array = []
	for _i in 40:
		areas.append(2000)
	var explode := _make_band(areas)
	var rc_explode := _rc(4.0)
	rc_explode.r1_density_metric = 1
	rc_explode.lvl_enabled = true
	rc_explode.lvl_size_mult = 40.0
	# r1_density_per_room_cap left 0 (uncapped per-room) → only the band ceiling protects us.
	var exploded: Array = mg._density_spawn_positions(explode, rc_explode)
	if exploded.size() > ceiling:
		failures.append("(h) band ceiling breached: %d density hazards > ceiling %d" % [exploded.size(), ceiling])
	if exploded.size() != ceiling:
		failures.append("(h) worst-case did not saturate the ceiling (got %d, expected %d)" % [exploded.size(), ceiling])

	mg.free()
	_free_band(band)
	_free_band(big_only)
	_free_band(huge)
	_free_band(mixed)
	_free_band(px_band)
	_free_band(explode)

	if failures.is_empty():
		print("J3 OK — per-room density verified: all-off → 0 nodes (M1.2 control), budget = "
			+ "floor(density * area / unit) scales with floor_cells.size(), per-room cap + min-area "
			+ "+ rooms-only filters honoured, px_area scales by lvl_size_mult^2, placement RNG-free + "
			+ "deterministic, and the band-wide ceiling (%d) bounds the worst case (size 40× × density 4)." % ceiling)
		return 0
	for f in failures:
		printerr("J3 FAIL: ", f)
	return 1


## An R1-on RunConfig with the J3 density knob set (cell_area default, no min-area, uncapped).
func _rc(density: float) -> RunConfig:
	var rc := RunConfig.new()
	rc.r1_enabled = true
	rc.r1_per_room_density = density
	rc.r1_density_metric = 0       # cell_area (default)
	rc.r1_density_min_area = 0
	rc.r1_density_per_room_cap = 0
	return rc


## A graded linear band: pieces at depth_index 0..N-1, each with `areas[i]` floor cells laid
## out in a contiguous block (so floor_cells.size() == the requested area). band.max_depth set
## as DepthGrader.grade() would leave it. Generic room ids (piece_room_<i>) — not corridors.
func _make_band(areas: Array) -> Band:
	var ids: Array = []
	for i in areas.size():
		ids.append(["piece_room_%d" % i, areas[i]])
	return _make_band_ids(ids)


## Like _make_band but with explicit [piece_id, area] pairs, so corridor-classified ids
## (piece_corridor*/piece_hall_v) can be tested against the rooms_only filter.
func _make_band_ids(id_area_pairs: Array) -> Band:
	var band := Band.new()
	var max_depth: int = id_area_pairs.size() - 1
	for d in id_area_pairs.size():
		var pair: Array = id_area_pairs[d]
		var piece_id: String = pair[0]
		var area: int = pair[1]
		var p := PlacedPiece.new()
		p.piece_id = StringName(piece_id)
		p.offset_cell = Vector2i(d * 100, 0)
		p.depth_index = d
		p.depth_norm = float(d) / float(max_depth) if max_depth > 0 else 0.0
		# `area` distinct floor cells in a contiguous strip starting at the piece offset.
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
