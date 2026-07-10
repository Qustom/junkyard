extends Node
## Headless acceptance test for K5i (M1.4) — new-hazard spawn-seam integration.
##
## Run as a SCENE (autoloads + a live tree) so MainGame's script resolves exactly as in
## the real game:
##   godot --headless res://tests/test_new_hazard_spawn.tscn
##
## K5i wires the three M1.4 hazard types (ping-pong / bomb / spikes) into the existing hazard
## spawn seam with per-type DEPTH-SCALED counts placed through the SAME J3 cell helpers, under
## a SHARED band-wide ceiling (NEW_HAZARD_BAND_CEILING). The spawn entry MainGame._spawn_new_
## hazards(rc, band) mutates the scene tree (instantiates hazard nodes into _band_container),
## so this test gives a bare MainGame script instance a real _band_container + cell size, runs
## the seam against hand-built graded bands (mirroring test_per_room_density.gd), and inspects
## the spawned children. Placement is a PURE function of (band, rc) — NO RNG, NO node state.
##
## Asserts (per the K5i Resolved Decisions + the Definition of Done):
##   (i)   ALL-OFF: every *_enabled false (or base=0,per_depth=0) → ZERO nodes / empty plan
##         (the M1.3 control; nothing loaded, fingerprint UNMOVED).
##   (ii)  DEPTH SCALING: a deeper room earns >= a shallower one when per_depth > 0, and
##         base > 0 puts a hazard in every eligible room.
##   (iii) PER-ROOM CAP bounds the per-room count.
##   (iv)  SHARED BAND CEILING: the total across ALL three types never exceeds the ceiling.
##   (v)   DETERMINISM: two builds produce byte-identical position lists.
##   (vi)  per-kind spawn_ctx is built correctly (ping-pong gets a non-empty room_bounds +
##         an initial_dir; spikes a deterministic phase_salt; bomb empty).

const MAIN_GAME_SCRIPT := "res://scenes/game/main_game.gd"
const RunConfigScript := preload("res://data/run_config/run_config.gd")
const CELL := 16   # MainGame.DEFAULT_CELL_SIZE_PX — fixed cell size for cell→world projection


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	var mg_script := load(MAIN_GAME_SCRIPT) as GDScript
	if mg_script == null:
		printerr("K5i FAIL: could not load %s" % MAIN_GAME_SCRIPT)
		return 1

	var ceiling: int = mg_script.NEW_HAZARD_BAND_CEILING

	# --- (i) all-off (every type disabled) → ZERO nodes -----------------------------
	var band3 := _make_band([4, 9, 16])   # three eligible rooms at depth 0..2
	var mg_off := _fresh_mg(mg_script)
	var rc_off := _rc()                    # everything off/neutral (K0 default)
	mg_off._spawn_new_hazards(rc_off, band3)
	var off_n: int = mg_off._band_container.get_child_count()
	if off_n != 0:
		failures.append("(i) all-off produced %d nodes, expected 0" % off_n)
	# all-off via neutral param_overrides (base=0, per_depth=0) also → 0 (V3: the deck cards
	# are present in band_greybox but a neutral override keeps their demand 0 → skipped).
	var rc_neutral := _rc()
	rc_neutral.param_overrides = {
		"pingpong": {"base_count": 0, "count_per_depth": 0.0},
		"bomb": {"base_count": 0, "count_per_depth": 0.0},
		"spike": {"base_count": 0, "count_per_depth": 0.0},
	}
	var mg_neu := _fresh_mg(mg_script)
	mg_neu._spawn_new_hazards(rc_neutral, band3)
	if mg_neu._band_container.get_child_count() != 0:
		failures.append("(i) enabled-but-neutral knobs produced %d nodes, expected 0"
			% mg_neu._band_container.get_child_count())

	# --- (ii) base>0 puts a hazard in every eligible room ---------------------------
	# BUG7: the depth-0 ENTRY piece is excluded from new-hazard placement (the player spawns
	# there), so bomb base 1, no depth scaling → one per ELIGIBLE room = the 2 deeper rooms.
	# (V3: only bomb is overridden non-neutral → pingpong/spike stay neutral → don't spawn.)
	var rc_base := _rc()
	rc_base.param_overrides = {"bomb": {"base_count": 1, "count_per_depth": 0.0}}
	var mg_base := _fresh_mg(mg_script)
	mg_base._spawn_new_hazards(rc_base, band3)
	if mg_base._band_container.get_child_count() != 2:
		failures.append("(ii) base=1 bomb over 3 rooms (entry excluded) produced %d nodes, expected 2"
			% mg_base._band_container.get_child_count())

	# --- (ii) DEPTH SCALING: a deeper room earns >= a shallower one (per_depth > 0) --
	# V3: pingpong only (per_room_cap 2 on its def, so the ramp is visible up to 2), base 0,
	# per_depth 1.0 → the deck's even-spread places more in the deeper room: depth 1 → 1,
	# depth 2 → 2 (the FBM19 even-spread reaches deeper by construction — DR-3a). (spike's
	# def cap is 1, so it can't show a per-room ramp; pingpong's cap-2 def can.)
	var rc_scale := _rc()
	rc_scale.param_overrides = {"pingpong": {"base_count": 0, "count_per_depth": 1.0}}
	var per_room := _count_per_room(mg_script, rc_scale, _make_band([16, 16, 16]))
	if per_room.size() == 3:
		if not (per_room[0] <= per_room[1] and per_room[1] <= per_room[2]):
			failures.append("(ii) depth scaling not monotonic: %s" % str(per_room))
		if per_room[2] <= per_room[0]:
			failures.append("(ii) deepest room (%d) did not exceed shallowest (%d)"
				% [per_room[2], per_room[0]])
	else:
		failures.append("(ii) expected 3 rooms, got %d depth buckets" % per_room.size())

	# --- (iii) PER-ROOM CAP bounds the per-room count -------------------------------
	# V3: pingpong base 10 (huge demand), and the pingpong DEF carries per_room_cap 2, enforced
	# service-side (a refused over-cap spawn does not spend). BUG7: the depth-0 entry room is
	# excluded, so 2 eligible rooms (depths 1,2) → 4 total (2 per room). The per-room cap now
	# lives on the shared def, not a RunConfig knob (V3 OQ-F resolution).
	var rc_cap := _rc()
	rc_cap.param_overrides = {"pingpong": {"base_count": 10, "count_per_depth": 0.0}}
	var mg_cap := _fresh_mg(mg_script)
	mg_cap._spawn_new_hazards(rc_cap, _make_band([16, 16, 16]))
	if mg_cap._band_container.get_child_count() != 4:
		failures.append("(iii) per-room cap 2 over 3 rooms (entry excluded) produced %d nodes, expected 4"
			% mg_cap._band_container.get_child_count())

	# --- (iv) SHARED BAND CEILING bounds the total across ALL three types -----------
	# Many big rooms, all three types base-heavy, uncapped per-room → only the ceiling protects.
	var areas: Array = []
	for _i in 40:
		areas.append(400)
	var explode := _make_band(areas)
	var rc_explode := _rc()
	rc_explode.param_overrides = {
		"pingpong": {"base_count": 50}, "bomb": {"base_count": 50}, "spike": {"base_count": 50},
	}
	var mg_exp := _fresh_mg(mg_script)
	mg_exp._spawn_new_hazards(rc_explode, explode)
	var total: int = mg_exp._band_container.get_child_count()
	if total > ceiling:
		failures.append("(iv) band ceiling breached: %d nodes > ceiling %d" % [total, ceiling])
	if total != ceiling:
		failures.append("(iv) worst-case did not saturate the ceiling (got %d, expected %d)"
			% [total, ceiling])

	# --- (v) DETERMINISM: two builds → byte-identical positions ---------------------
	var rc_det := _rc()
	rc_det.param_overrides = {
		"pingpong": {"base_count": 2},
		"bomb": {"base_count": 1},
		"spike": {"base_count": 1, "count_per_depth": 0.5},
	}
	var pos_a := _positions(mg_script, rc_det, _make_band([16, 25, 36]))
	var pos_b := _positions(mg_script, rc_det, _make_band([16, 25, 36]))
	if pos_a != pos_b:
		failures.append("(v) spawn positions not deterministic across builds")
	if pos_a.is_empty():
		failures.append("(v) determinism case produced no nodes (test mis-set)")

	# --- (vi) per-kind spawn_ctx is built correctly ---------------------------------
	# ping-pong: non-empty room_bounds (Rect2 with area) + a non-zero initial_dir.
	var mg_ctx := _fresh_mg(mg_script)
	var bnd := _make_band([40])   # one 2-row room (cells span 2 rows) so its bbox has area
	var p0: Object = bnd.pieces[0]
	var cells: Array[Vector2i] = mg_ctx._density_sorted_cells(p0)
	var room_bounds: Rect2 = mg_ctx._piece_floor_bounds_world(cells)
	var pp_ctx: Dictionary = mg_ctx._new_hazard_spawn_ctx(&"pingpong", p0, 0, 3, room_bounds)
	if not pp_ctx.has("room_bounds") or not (pp_ctx["room_bounds"] as Rect2).has_area():
		failures.append("(vi) ping-pong spawn_ctx room_bounds missing or zero-area")
	if not pp_ctx.has("initial_dir") or (pp_ctx["initial_dir"] as Vector2).length() < 0.001:
		failures.append("(vi) ping-pong spawn_ctx initial_dir missing or zero")
	# spikes: deterministic phase_salt == depth_index * 131 + k.
	var sp_ctx: Dictionary = mg_ctx._new_hazard_spawn_ctx(&"spike", p0, 2, 5, room_bounds)
	var want_salt: int = p0.depth_index * 131 + 2
	if int(sp_ctx.get("phase_salt", -1)) != want_salt:
		failures.append("(vi) spike phase_salt == %s, expected %d"
			% [str(sp_ctx.get("phase_salt", null)), want_salt])
	# bomb: empty dict.
	var bm_ctx: Dictionary = mg_ctx._new_hazard_spawn_ctx(&"bomb", p0, 0, 0, room_bounds)
	if not bm_ctx.is_empty():
		failures.append("(vi) bomb spawn_ctx should be empty, got %s" % str(bm_ctx))

	# --- (vii) BUG7: no new hazard spawns on/near the player's entry-spawn cell -----
	# Feedback #7 (CRITICAL): with base_count >= 1 the seam placed a hazard on the entry cell
	# → frame-0 spawn-kill. Assert that with ALL three types base-heavy the nearest spawned
	# hazard is still clear of the entry by the safe radius (and the entry depth-0 room is empty).
	var safe_cells: float = mg_script.NEW_HAZARD_SPAWN_SAFE_CELLS
	var bug7_band := _make_band([16, 16, 16])   # entry at depth 0, two deeper rooms
	var entry_cell: Vector2i = bug7_band.entry_piece.floor_cells[0]
	var entry_pos: Vector2 = Vector2(entry_cell * CELL) + Vector2(CELL, CELL) * 0.5
	var rc_bug7 := _rc()
	rc_bug7.param_overrides = {
		"pingpong": {"base_count": 3}, "bomb": {"base_count": 3}, "spike": {"base_count": 3},
	}
	var mg_bug7 := _fresh_mg(mg_script)
	mg_bug7._spawn_new_hazards(rc_bug7, bug7_band)   # spawn_pos recomputed from band topology
	var safe_px: float = safe_cells * float(CELL)
	var min_dist: float = INF
	var entry_room_x_base: int = bug7_band.entry_piece.offset_cell.x   # depth-0 room x base
	var entry_room_hits: int = 0
	for child in mg_bug7._band_container.get_children():
		if child is Node2D:
			var gp: Vector2 = (child as Node2D).global_position
			min_dist = minf(min_dist, gp.distance_to(entry_pos))
			# A node whose cell x falls in the entry room's x-strip is in the depth-0 room.
			if int(gp.x / float(CELL)) / 100 == entry_room_x_base / 100:
				entry_room_hits += 1
	if mg_bug7._band_container.get_child_count() == 0:
		failures.append("(vii) BUG7 case produced no nodes (test mis-set — can't prove safety)")
	if entry_room_hits != 0:
		failures.append("(vii) BUG7: %d hazard(s) landed in the depth-0 entry room (expected 0)"
			% entry_room_hits)
	if min_dist < safe_px:
		failures.append(("(vii) BUG7: a hazard landed %.1fpx from the entry spawn (< safe radius "
			+ "%.1fpx) — frame-0 spawn-kill risk") % [min_dist, safe_px])
	mg_bug7._band_container.queue_free()
	mg_bug7.free()
	_free_band(bug7_band)

	for m in [mg_off, mg_neu, mg_base, mg_cap, mg_exp, mg_ctx]:
		if m._band_container != null and is_instance_valid(m._band_container):
			m._band_container.queue_free()
		m.free()
	_free_band(band3)
	_free_band(explode)
	_free_band(bnd)

	if failures.is_empty():
		print(("K5i OK — new-hazard spawn seam verified: all-off → 0 nodes (M1.3 control), "
			+ "depth-scaled per-room count, per-room cap honoured, shared band ceiling (%d) "
			+ "bounds K5a+K5b+K5c combined, placement deterministic (no RNG), and the per-kind "
			+ "spawn_ctx (ping-pong room_bounds/initial_dir, spike phase_salt, bomb empty) "
			+ "is built correctly.") % ceiling)
		return 0
	for f in failures:
		printerr("K5i FAIL: ", f)
	return 1


## A fresh MainGame SCRIPT instance with a real _band_container + the default cell size, so
## _spawn_new_hazards can add hazard nodes and _density_cell_to_world projects correctly. The
## bare script instance is NOT added to the tree (its _ready() wires menu/HUD @onready nodes
## that don't exist here, exactly like test_per_room_density's bare-instance approach); instead
## the _band_container is parented under THIS test node (which IS in the tree), so the seam's
## tree access (player-group lookup via _band_container.get_tree()) resolves cleanly.
func _fresh_mg(mg_script: GDScript) -> Object:
	var mg = mg_script.new()
	var container := Node2D.new()
	add_child(container)   # the container is the in-tree owner of spawned hazard nodes
	mg._band_container = container
	mg._band_cell_size_px = CELL
	return mg


## Run the seam and return the per-depth-room spawn count (one entry per piece, in depth order),
## by reading each spawned node's global_position back to its owning room.
func _count_per_room(mg_script: GDScript, rc: RunConfig, band: Band) -> Array[int]:
	var mg := _fresh_mg(mg_script)
	mg._spawn_new_hazards(rc, band)
	# Map each spawned node to a depth bucket via its x cell range (rooms are laid out in
	# contiguous x-strips by _make_band, one per depth: depth d at x in [d*100, ...]).
	var counts: Array[int] = []
	counts.resize(band.pieces.size())
	counts.fill(0)
	for child in mg._band_container.get_children():
		if child is Node2D:
			var cx := int((child.global_position.x / float(CELL)))
			var d := cx / 100   # _make_band strips depth d at x base d*100
			if d >= 0 and d < counts.size():
				counts[d] += 1
	mg.free()
	return counts


## Run the seam and return the spawned nodes' global positions in spawn order (for determinism).
func _positions(mg_script: GDScript, rc: RunConfig, band: Band) -> Array[Vector2]:
	var mg := _fresh_mg(mg_script)
	mg._spawn_new_hazards(rc, band)
	var out: Array[Vector2] = []
	for child in mg._band_container.get_children():
		if child is Node2D:
			out.append((child as Node2D).global_position)
	mg.free()
	_free_band(band)
	return out


## An all-off RunConfig (K0 default) — every new-hazard knob off/neutral.
func _rc() -> RunConfig:
	return RunConfigScript.new()


## A graded linear band: pieces at depth_index 0..N-1, each with `areas[i]` floor cells laid
## out in a contiguous block (so floor_cells.size() == the requested area), at x base d*100
## (so a spawned node's x identifies its room). Mirrors test_per_room_density._make_band.
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
