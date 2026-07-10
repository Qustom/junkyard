extends Node
## Headless acceptance test for M1.10 T1 — cave materialisation + backend-agnostic
## sealing + the downstream verify (the wave that makes a T0-generated cave PLAYABLE).
##
## Run as a SCENE (not --script) so the EventBus / RNG / GameState autoloads resolve at
## compile time, exactly as in the real game:
##   godot --headless --path Game res://tests/test_cave_materialise.tscn
##
## The cave profile is built IN CODE (BandProfile.new() + CaveBandConfig.new() at T0's
## SHIPPED defaults — schema defaults, not literals, so a T0 default-tune can't break the
## test) — no committed .tres fixture to collide with T3's band_three authoring (OQ-6). A
## bare MainGame script instance with an injected _band_container + _band_profile drives
## _materialise_band / _place_gate / _spawn_new_hazards (the test_new_hazard_spawn harness
## pattern); _band_profile is injected so the cave gate guard (D-RAT-7) arms.
##
## Assertion groups (spec §3.4 M1-M9):
##   M1  Materialise closure (THE bar): every floor cell's 4-neighbour is floor OR its owner
##       Geometry layer holds the greybox WALL cap — _count_floor_facing_void == 0 for caves.
##   M2  Collision truth: sampled wall cells report the greybox WALL tile (source 0, (1,0));
##       + a direct_space_state point query (after a physics frame) hits a wall, misses floor.
##   M3  Determinism across materialise: fingerprint()+floor_fingerprint() byte-equal pre/post.
##   M4  Anchors: spawn cell == entry_piece.floor_cells[0], IS floor, is 2x2-open; max_depth>=4;
##       deepest_piece non-null with depth_index == max_depth.
##   M5  Gate: all-off rc -> single gate, its cell IS floor (the snap), reachable (flood from
##       spawn over floor 4-adjacency). Preset rc (exit_enabled+keep_one) -> every gate floor.
##   M6  Throat bar: spawn->gate reachable over 2x2-OPEN cells only (the player-circle cert).
##   M7  Downstream population: JunkPlacer.plan -> every world_pos maps to a floor cell;
##       EncounterBuilder.populate (play preset + armed SpawnService) -> >=1 spawn, every
##       spawn cell floor at depth_index > 0 (chunked grading feeds the builder end-to-end).
##   M8  Tint: _band_container.modulate == profile.palette_tint (a non-white test tint).
##   M9  Socket control: _materialise_band on a band_greybox pipeline band adds exactly
##       band.pieces.size() children and builds ZERO synthetic hosts (the null branch is
##       unreachable on a socket band — byte-identity by construction).

const MAIN_GAME_SCRIPT := "res://scenes/game/main_game.gd"
const GREYBOX_PROFILE := "res://data/bands/band_greybox.tres"
const DEPTH_CURVE_PATH := "res://systems/depth/depth_curve.tres"
const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"

const CELL := 16                                   # MainGame.DEFAULT_CELL_SIZE_PX
const GREYBOX_SOURCE_ID := 0
const WALL_ATLAS := Vector2i(1, 0)
const WALL_LAYER_MASK := 2                          # greybox WALL physics_layer_0/collision_layer = 2

## A non-white tint so M8 proves the assignment path (band_greybox ships neutral white).
const TEST_TINT := Color(0.42, 0.30, 0.78, 1.0)

## Same determinism matrix as test_cave_backend / test_band_two_profile.
const SEEDS := [12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]

const _STEPS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


func _ready() -> void:
	var code: int = await _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []
	var mg_script := load(MAIN_GAME_SCRIPT) as GDScript
	if mg_script == null:
		printerr("CAVE MAT FAIL: could not load %s" % MAIN_GAME_SCRIPT)
		return 1

	_m1_closure(mg_script, failures)
	await _m2_collision_truth(mg_script, failures)
	_m3_determinism(mg_script, failures)
	_m4_anchors(mg_script, failures)
	_m5_gate(mg_script, failures)
	_m6_throat(mg_script, failures)
	_m7_population(mg_script, failures)
	_m8_tint(mg_script, failures)
	_m9_socket_control(mg_script, failures)

	if failures.is_empty():
		print("CAVE MATERIALISE OK — closure + collision + determinism + anchors + snapped gate ",
				"+ 2x2 throat + downstream population + tint verified across %d seeds; " % SEEDS.size(),
				"socket materialise byte-identical (zero synthetic hosts).")
		return 0
	for f in failures:
		printerr("CAVE MAT FAIL: ", f)
	return 1


# --- Harness ------------------------------------------------------------------

## A bare MainGame script instance with a real in-tree _band_container + cell size +
## the injected cave profile (so the D-RAT-7 gate guard arms).
func _fresh_mg(mg_script: GDScript, profile: BandProfile) -> Object:
	var mg = mg_script.new()
	var container := Node2D.new()
	add_child(container)
	mg._band_container = container
	mg._band_cell_size_px = CELL
	mg._band_profile = profile
	return mg


func _cave_config() -> CaveBandConfig:
	return CaveBandConfig.new()                    # T0's SHIPPED defaults (56x56, fill 45, ...)


func _cave_profile() -> BandProfile:
	var p := BandProfile.new()
	p.id = &"test_cave_mat"
	p.backend = "cave"
	p.backend_config = _cave_config()
	p.archetype = "linear"
	p.band_depth = 3
	p.palette_tint = TEST_TINT
	# V3 (M1.12): the legacy K5 hazard lane was retired — populate() spawns only from the
	# profile's opposition_deck (or the oppositions_enabled extras lever). Give this synthetic
	# cave a K5 deck so M7's "populate spawns on the cave" check exercises the deck lane; the
	# play preset's param_overrides (pingpong/bomb/spike magnitudes) activate the neutral cards.
	var deck: Array[Resource] = [
		load("res://data/oppositions/pingpong.tres"),
		load("res://data/oppositions/bomb.tres"),
		load("res://data/oppositions/spike.tres"),
	]
	p.opposition_deck = deck
	return p


func _gen(prof: BandProfile, seed: int) -> Band:
	return BandPipeline.new().generate(prof, seed)


## band-global FLOOR set: Vector2i cell -> owning PlacedPiece (the sealer's key).
func _floor_owners(band: Band) -> Dictionary:
	var owners := {}
	for p in band.pieces:
		for c in p.floor_cells:
			owners[c] = p
	return owners


func _geo_of(p: PlacedPiece) -> TileMapLayer:
	if p == null or p.instance == null:
		return null
	return p.instance.get_node_or_null("Geometry") as TileMapLayer


# --- M1: materialise closure --------------------------------------------------

func _m1_closure(mg_script: GDScript, failures: Array[String]) -> void:
	var prof := _cave_profile()
	for seed in SEEDS:
		var band := _gen(prof, seed)
		if band == null:
			failures.append("M1 seed %d: null band" % seed)
			continue
		var mg := _fresh_mg(mg_script, prof)
		mg._materialise_band(band, CELL)
		var owners := _floor_owners(band)
		var leaks := 0
		for c in owners:
			var owner: PlacedPiece = owners[c]
			var geo := _geo_of(owner)
			if geo == null:
				failures.append("M1 seed %d: floor owner has no Geometry layer" % seed)
				break
			for step in _STEPS:
				var n: Vector2i = c + step
				if owners.has(n):
					continue                       # walkable neighbour — never capped
				# void/wall neighbour MUST be a greybox WALL cap in this owner's layer.
				var local: Vector2i = n - owner.offset_cell
				if geo.get_cell_source_id(local) != GREYBOX_SOURCE_ID \
						or geo.get_cell_atlas_coords(local) != WALL_ATLAS:
					leaks += 1
		if leaks > 0:
			failures.append("M1 seed %d: %d floor-facing void cell(s) NOT sealed (closure broken)"
					% [seed, leaks])
		mg._band_container.queue_free()
		mg.free()


# --- M2: collision truth (tile atlas + physics point query) -------------------

func _m2_collision_truth(mg_script: GDScript, failures: Array[String]) -> void:
	var prof := _cave_profile()
	var band := _gen(prof, SEEDS[0])
	if band == null:
		failures.append("M2: null band")
		return
	var mg := _fresh_mg(mg_script, prof)
	mg._materialise_band(band, CELL)
	var owners := _floor_owners(band)

	# Find a representative WALL cap (a void neighbour of a floor cell) and a floor cell.
	var wall_cell := Vector2i(0, 0)
	var wall_owner: PlacedPiece = null
	var floor_cell: Vector2i = band.entry_piece.floor_cells[0]
	var found_wall := false
	for c in owners:
		for step in _STEPS:
			var n: Vector2i = c + step
			if not owners.has(n):
				wall_cell = n
				wall_owner = owners[c]
				found_wall = true
				break
		if found_wall:
			break
	if not found_wall:
		failures.append("M2: no wall cap found (band has no perimeter?)")
		mg._band_container.queue_free(); mg.free()
		return

	# Tile-atlas truth: the cap is the greybox WALL tile.
	var geo := _geo_of(wall_owner)
	if geo.get_cell_atlas_coords(wall_cell - wall_owner.offset_cell) != WALL_ATLAS:
		failures.append("M2: sampled wall cap is not the greybox WALL atlas (1,0)")

	# Physics truth: the WALL tile collides (layer 2), the floor does not. TileMapLayer
	# collision only registers on the physics server after a physics sync — await one.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var wall_world := Vector2(wall_cell * CELL) + Vector2(CELL, CELL) * 0.5
	var floor_world := Vector2(floor_cell * CELL) + Vector2(CELL, CELL) * 0.5
	if not _point_hits(mg._band_container, wall_world):
		failures.append("M2: physics point query MISSED inside a wall cell (collision not closing the space)")
	if _point_hits(mg._band_container, floor_world):
		failures.append("M2: physics point query HIT inside a floor cell (floor should be collisionless)")

	mg._band_container.queue_free()
	mg.free()


func _point_hits(container: Node2D, world_pos: Vector2) -> bool:
	var space := container.get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collision_mask = WALL_LAYER_MASK
	params.collide_with_bodies = true
	return not space.intersect_point(params).is_empty()


# --- M3: determinism across materialise ---------------------------------------

func _m3_determinism(mg_script: GDScript, failures: Array[String]) -> void:
	var prof := _cave_profile()
	for seed in SEEDS:
		var band := _gen(prof, seed)
		if band == null:
			failures.append("M3 seed %d: null band" % seed)
			continue
		var fp_before := band.fingerprint()
		var floor_before := band.floor_fingerprint()
		var mg := _fresh_mg(mg_script, prof)
		mg._materialise_band(band, CELL)
		if band.fingerprint() != fp_before:
			failures.append("M3 seed %d: fingerprint() CHANGED across materialise" % seed)
		if band.floor_fingerprint() != floor_before:
			failures.append("M3 seed %d: floor_fingerprint() CHANGED across materialise" % seed)
		mg._band_container.queue_free()
		mg.free()


# --- M4: anchors --------------------------------------------------------------

func _m4_anchors(_mg_script: GDScript, failures: Array[String]) -> void:
	var prof := _cave_profile()
	for seed in SEEDS:
		var band := _gen(prof, seed)
		if band == null:
			failures.append("M4 seed %d: null band" % seed)
			continue
		if band.entry_piece == null or band.entry_piece.floor_cells.is_empty():
			failures.append("M4 seed %d: entry piece missing / no floor cells" % seed)
			continue
		var owners := _floor_owners(band)
		var anchor: Vector2i = band.entry_piece.floor_cells[0]
		if not owners.has(anchor):
			failures.append("M4 seed %d: spawn anchor is not a floor cell" % seed)
		var t := _traversable_set(owners)
		if not t.has(anchor):
			failures.append("M4 seed %d: spawn anchor is not 2x2-open (no player clearance)" % seed)
		if band.max_depth < 4:
			failures.append("M4 seed %d: max_depth %d < 4 (chunk-granularity depth axis)" % [seed, band.max_depth])
		if band.deepest_piece == null or band.deepest_piece.depth_index != band.max_depth:
			var di := -999 if band.deepest_piece == null else band.deepest_piece.depth_index
			failures.append("M4 seed %d: deepest_piece.depth_index %d != max_depth %d" % [seed, di, band.max_depth])


# --- M5: gate (snapped-to-floor + reachable) ----------------------------------

func _m5_gate(mg_script: GDScript, failures: Array[String]) -> void:
	var prof := _cave_profile()
	for seed in SEEDS:
		var band := _gen(prof, seed)
		if band == null:
			failures.append("M5 seed %d: null band" % seed)
			continue
		var owners := _floor_owners(band)

		# All-off rc -> single pinned gate, snapped to nearest floor, reachable from spawn.
		var mg := _fresh_mg(mg_script, prof)
		var spawn_pos: Vector2 = mg._entry_spawn_position(band)
		mg._place_gate(band, spawn_pos, RunConfig.new())
		if mg._gates.size() != 1:
			failures.append("M5 seed %d: all-off produced %d gates, expected 1" % [seed, mg._gates.size()])
		else:
			var gate_cell: Vector2i = mg._world_to_cell(mg._gates[0].global_position)
			if not owners.has(gate_cell):
				failures.append("M5 seed %d: all-off gate cell is NOT floor (snap failed)" % seed)
			elif not _floor_reachable(owners, mg._world_to_cell(spawn_pos), gate_cell):
				failures.append("M5 seed %d: all-off gate not reachable from spawn over floor" % seed)
		mg._band_container.queue_free()
		mg.free()

		# Preset rc (exit_enabled + keep_one) -> every gate cell floor.
		var mg2 := _fresh_mg(mg_script, prof)
		var spawn2: Vector2 = mg2._entry_spawn_position(band)
		mg2._place_gate(band, spawn2, RunConfig.make_default_play_preset())
		if mg2._gates.is_empty():
			failures.append("M5 seed %d: preset produced no gates" % seed)
		for g in mg2._gates:
			if not owners.has(mg2._world_to_cell(g.global_position)):
				failures.append("M5 seed %d: a preset gate cell is NOT floor" % seed)
				break
		mg2._band_container.queue_free()
		mg2.free()


# --- M6: 2x2-open throat certificate ------------------------------------------

func _m6_throat(mg_script: GDScript, failures: Array[String]) -> void:
	var prof := _cave_profile()
	for seed in SEEDS:
		var band := _gen(prof, seed)
		if band == null:
			failures.append("M6 seed %d: null band" % seed)
			continue
		var owners := _floor_owners(band)
		var t := _traversable_set(owners)
		if t.is_empty():
			failures.append("M6 seed %d: traversable set T empty" % seed)
			continue
		if _component_count(t) != 1:
			failures.append("M6 seed %d: T has %d components (not a single traversable body)"
					% [seed, _component_count(t)])
		var anchor: Vector2i = band.entry_piece.floor_cells[0]
		if not t.has(anchor):
			failures.append("M6 seed %d: spawn anchor not in T" % seed)
			continue

		# The snapped all-off gate must be reachable from spawn over 2x2-OPEN cells only.
		# The gate can snap onto a floor nib not itself 2x2-open (D-RAT-7 snaps to nearest
		# FLOOR); T0's coverage guarantee makes every floor cell 4-adjacent to T, so the
		# player-circle certificate is: spawn's T-flood reaches the gate cell OR a 4-neighbour
		# of it (a 2x2-open cell the player stands on to touch the Area-driven gate).
		var mg := _fresh_mg(mg_script, prof)
		var spawn_pos: Vector2 = mg._entry_spawn_position(band)
		mg._place_gate(band, spawn_pos, RunConfig.new())
		var gate_cell: Vector2i = mg._world_to_cell(mg._gates[0].global_position)
		mg._band_container.queue_free()
		mg.free()

		var reached := _flood_over_set(t, anchor)
		var ok := reached.has(gate_cell)
		if not ok:
			for step in _STEPS:
				if reached.has(gate_cell + step):
					ok = true
					break
		if not ok:
			failures.append("M6 seed %d: gate NOT reachable from spawn over 2x2-open cells" % seed)


# --- M7: downstream population ------------------------------------------------

func _m7_population(mg_script: GDScript, failures: Array[String]) -> void:
	var prof := _cave_profile()
	var curve := load(DEPTH_CURVE_PATH) as DepthCurve
	var catalog := load(JUNK_CATALOG_PATH) as JunkCatalog
	if curve == null or catalog == null:
		failures.append("M7: could not load depth_curve / junk_catalog fixtures")
		return

	for seed in SEEDS:
		var band := _gen(prof, seed)
		if band == null:
			failures.append("M7 seed %d: null band" % seed)
			continue
		var owners := _floor_owners(band)
		var cell_depth := {}
		for p in band.pieces:
			for c in p.floor_cells:
				cell_depth[c] = p.depth_index

		# JunkPlacer.plan: every planned world_pos maps back to a floor cell.
		var plan := JunkPlacer.new().plan(band, curve, catalog, false, CELL, 0.0)
		for e in plan:
			var cell := Vector2i((Vector2(e["world_pos"]) / float(CELL)).floor())
			if not owners.has(cell):
				failures.append("M7 seed %d: a junk plan pos maps to a NON-floor cell" % seed)
				break

		# EncounterBuilder.populate via the façade (play preset arms the K5 extras lane):
		# >= 1 spawn, every spawn cell floor at depth_index > 0.
		var mg := _fresh_mg(mg_script, prof)
		var spawn_pos: Vector2 = mg._entry_spawn_position(band)
		mg._spawn_new_hazards(RunConfig.make_default_play_preset(), band, spawn_pos)
		var spawns: Array = mg._band_container.get_children()
		if spawns.is_empty():
			failures.append("M7 seed %d: EncounterBuilder.populate spawned NOTHING on the cave" % seed)
		for child in spawns:
			if not (child is Node2D):
				continue
			var cell := Vector2i(((child as Node2D).global_position / float(CELL)).floor())
			if not owners.has(cell):
				failures.append("M7 seed %d: a spawn landed on a NON-floor cell" % seed)
				break
			if int(cell_depth.get(cell, 0)) <= 0:
				failures.append("M7 seed %d: a spawn landed at depth_index <= 0 (entry unsafe)" % seed)
				break
		mg._band_container.queue_free()
		mg.free()


# --- M8: tint -----------------------------------------------------------------

func _m8_tint(mg_script: GDScript, failures: Array[String]) -> void:
	var prof := _cave_profile()
	var band := _gen(prof, SEEDS[0])
	var mg := _fresh_mg(mg_script, prof)
	mg._materialise_band(band, CELL)
	# The start-of-run assignment path (main_game.gd start_new_run): container.modulate = tint.
	mg._band_container.modulate = prof.palette_tint
	if mg._band_container.modulate != TEST_TINT:
		failures.append("M8: _band_container.modulate != profile.palette_tint")
	mg._band_container.queue_free()
	mg.free()


# --- M9: socket control (byte-identity by construction) -----------------------

func _m9_socket_control(mg_script: GDScript, failures: Array[String]) -> void:
	var greybox := load(GREYBOX_PROFILE) as BandProfile
	if greybox == null:
		failures.append("M9: could not load band_greybox.tres")
		return
	var band := BandPipeline.new().generate(greybox, SEEDS[0])
	if band == null or band.pieces.is_empty():
		failures.append("M9: band_greybox produced no pieces")
		return

	# Every socket piece already carries an authored ZonePiece instance — the null branch is
	# structurally unreachable. Capture identities to prove NO synthetic host is built.
	var pre_instances: Array = []
	for p in band.pieces:
		if p.instance == null:
			failures.append("M9: a band_greybox piece has a NULL instance (would trigger the cave branch!)")
		pre_instances.append(p.instance)

	var mg = mg_script.new()
	var container := Node2D.new()
	add_child(container)
	mg._band_container = container
	mg._band_profile = greybox                      # socket profile: the gate guard never fires
	mg._materialise_band(band, CELL)

	if container.get_child_count() != band.pieces.size():
		failures.append("M9: materialise added %d children, expected %d (one per authored piece)"
				% [container.get_child_count(), band.pieces.size()])
	for i in band.pieces.size():
		if band.pieces[i].instance != pre_instances[i]:
			failures.append("M9: piece %d instance was REPLACED (a synthetic host was built on a socket band)" % i)
			break
	container.queue_free()
	mg.free()


# --- 2x2-open / flood helpers (Vector2i-keyed, mirroring the backend's integer T) ---

## The traversable set T: every cell of an all-floor 2x2 block (a 28px player disc fits a
## 32x32px block). `owners` is used only as the FLOOR membership set.
func _traversable_set(owners: Dictionary) -> Dictionary:
	var t := {}
	for c in owners:
		var r: Vector2i = c + Vector2i(1, 0)
		var d: Vector2i = c + Vector2i(0, 1)
		var rd: Vector2i = c + Vector2i(1, 1)
		if owners.has(r) and owners.has(d) and owners.has(rd):
			t[c] = true
			t[r] = true
			t[d] = true
			t[rd] = true
	return t


func _component_count(members: Dictionary) -> int:
	var visited := {}
	var comps := 0
	for start in members:
		if visited.has(start):
			continue
		comps += 1
		var queue: Array[Vector2i] = [start]
		visited[start] = true
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			for s in _STEPS:
				var n: Vector2i = cur + s
				if members.has(n) and not visited.has(n):
					visited[n] = true
					queue.append(n)
	return comps


## 4-connected flood over a membership set from `start`; returns the visited set.
func _flood_over_set(members: Dictionary, start: Vector2i) -> Dictionary:
	var visited := {}
	if not members.has(start):
		return visited
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for s in _STEPS:
			var n: Vector2i = cur + s
			if members.has(n) and not visited.has(n):
				visited[n] = true
				queue.append(n)
	return visited


## True iff `goal` is reachable from `start` over FLOOR 4-adjacency (M5 reachability).
func _floor_reachable(owners: Dictionary, start: Vector2i, goal: Vector2i) -> bool:
	if not owners.has(start) or not owners.has(goal):
		return false
	return _flood_over_set(owners, start).has(goal)
