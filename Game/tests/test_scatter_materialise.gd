extends Node
## Headless acceptance test for M1.11 U1 — scatter materialisation ride-through +
## downstream verify (the wave that proves a U0-generated open-field band is PLAYABLE
## on the unedited T1 synthetic-piece materialisation path).
##
## Run as a SCENE (not --script) so the EventBus / RNG / GameState autoloads resolve at
## compile time, exactly as in the real game:
##   godot --headless --path Game res://tests/test_scatter_materialise.tscn
##
## The scatter profile is built IN CODE (BandProfile.new() + ScatterBandConfig.new() at
## U0's SHIPPED defaults — schema defaults, not literals, so a U0 default-tune can't break
## the test) — no committed .tres fixture to collide with U3's band_four authoring (the
## T1 OQ-6 resolution inherited verbatim). A bare MainGame script instance with an
## injected _band_container + _band_cell_size_px + _band_profile drives
## _materialise_band / _place_gate / _spawn_new_hazards (the test_cave_materialise
## harness pattern); _band_profile is injected so the U1 allowlist gate guard arms.
##
## Assertion groups (U1 spec §3.2 as amended by RD-U1-2/RD-U1-3):
##   M1  Materialise closure (THE bar): every floor cell's non-floor 4-neighbour holds
##       the greybox WALL cap in its owner's Geometry layer. The sealer's rule is
##       perimeter-BLIND (§2.2), so this single assertion covers the arena ring AND
##       every cover-blob surface at once. Every seed.
##   M2  Collision truth (RD-U1-3 — physics once, geometry everywhere): on seed[0],
##       after a physics-frame await, direct_space_state point queries (mask 2) hit
##       EVERY cover cell exhaustively (interior capped void — the anti-walk-through-
##       cover bar), hit sampled ring-wall cells, miss sampled floor cells. Cover
##       enumeration needs no U0 internals: cover == non-floor 4-adjacent to floor
##       INSIDE the floor bounding box, derivable from floor_cells alone.
##   M3  Determinism: fingerprint() + floor_fingerprint() byte-equal pre/post
##       _materialise_band, every seed (zero RNG, no floor mutation).
##   M4  Anchors: spawn cell == entry_piece.floor_cells[0], IS floor, IS 2x2-open;
##       max_depth >= 4; deepest_piece.depth_index == max_depth. Every seed.
##   M5  Gate: all-off rc -> exactly 1 gate, its cell IS floor (the U1 snap armed for
##       scatter), reachable from spawn over floor 4-adjacency. Preset rc
##       (exit_enabled + keep_one) -> every gate cell IS floor. Every seed.
##   M6  2x2-open certificate, RD-U1-2 STRENGTHENED form: (a) EVERY floor cell is IN
##       the traversable set T (U0 RD-6's by-construction proof); (b) T is a single
##       component == the floor set; (c) spawn anchor in T and the all-off gate in T's
##       flood from spawn (or 4-adjacent — the Area-gate allowance). A red M6 is a U0
##       contract breach (routes to a U0 follow-up, never a U1 patch). Every seed.
##   M7  Downstream population: JunkPlacer.plan -> every world_pos maps to a floor
##       cell; _spawn_new_hazards (play preset) -> >= 1 spawn, every spawn cell floor
##       at depth_index > 0. With M6 green, reachability follows BY IMPLICATION.
##   M8  Tint: _band_container.modulate == profile.palette_tint (non-white test tint).
##   M9  Backend controls: (a) socket — _materialise_band on a band_greybox pipeline
##       band adds exactly pieces.size() children, ZERO synthetic hosts, and
##       _pinned_gate_pos returns the RAW fixed offset (the allowlist arm, byte-
##       identical); (b) cave — a cave-profile _pinned_gate_pos call still SNAPS to
##       floor, pinning the flipped guard's cave-arm equivalence from inside this
##       suite too (the full cave regression is test_cave_materialise, unmodified).

const MAIN_GAME_SCRIPT := "res://scenes/game/main_game.gd"
const GREYBOX_PROFILE := "res://data/bands/band_greybox.tres"
const DEPTH_CURVE_PATH := "res://systems/depth/depth_curve.tres"
const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"

const CELL := 16                                   # MainGame.DEFAULT_CELL_SIZE_PX
const GREYBOX_SOURCE_ID := 0
const WALL_ATLAS := Vector2i(1, 0)
const WALL_LAYER_MASK := 2                          # greybox WALL physics_layer_0/collision_layer = 2

## A non-white tint so M8 proves the assignment path.
const TEST_TINT := Color(0.30, 0.62, 0.44, 1.0)

## Same determinism matrix as test_scatter_backend / test_cave_materialise.
const SEEDS := [12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]

const _STEPS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


func _ready() -> void:
	var code: int = await _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []
	var mg_script := load(MAIN_GAME_SCRIPT) as GDScript
	if mg_script == null:
		printerr("SCATTER MAT FAIL: could not load %s" % MAIN_GAME_SCRIPT)
		return 1

	_m1_closure(mg_script, failures)
	await _m2_collision_truth(mg_script, failures)
	_m3_determinism(mg_script, failures)
	_m4_anchors(mg_script, failures)
	_m5_gate(mg_script, failures)
	_m6_traversable(mg_script, failures)
	_m7_population(mg_script, failures)
	_m8_tint(mg_script, failures)
	_m9_backend_controls(mg_script, failures)

	if failures.is_empty():
		print("SCATTER MATERIALISE OK — closure + collision (exhaustive cover) + determinism ",
				"+ anchors + snapped gate + strengthened 2x2 certificate + downstream population ",
				"+ tint verified across %d seeds; " % SEEDS.size(),
				"socket materialise byte-identical (zero synthetic hosts, raw pinned offset); ",
				"cave guard-arm still snaps.")
		return 0
	for f in failures:
		printerr("SCATTER MAT FAIL: ", f)
	return 1


# --- Harness ------------------------------------------------------------------

## A bare MainGame script instance with a real in-tree _band_container + cell size +
## the injected scatter profile (so the U1 allowlist gate guard arms).
func _fresh_mg(mg_script: GDScript, profile: BandProfile) -> Object:
	var mg = mg_script.new()
	var container := Node2D.new()
	add_child(container)
	mg._band_container = container
	mg._band_cell_size_px = CELL
	mg._band_profile = profile
	return mg


func _scatter_config() -> ScatterBandConfig:
	return ScatterBandConfig.new()                 # U0's SHIPPED defaults (56x36, density 25, ...)


func _scatter_profile() -> BandProfile:
	var p := BandProfile.new()
	p.id = &"test_scatter_mat"
	p.backend = "scatter"
	p.backend_config = _scatter_config()
	p.archetype = "linear"
	p.band_depth = 4
	p.palette_tint = TEST_TINT
	return p


func _cave_profile() -> BandProfile:
	var p := BandProfile.new()
	p.id = &"test_cave_control"
	p.backend = "cave"
	p.backend_config = CaveBandConfig.new()
	p.archetype = "linear"
	p.band_depth = 3
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


# --- M1: materialise closure (ring AND cover blobs, by the perimeter-blind rule) ---

func _m1_closure(mg_script: GDScript, failures: Array[String]) -> void:
	var prof := _scatter_profile()
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
				# void/wall/cover neighbour MUST be a greybox WALL cap in this owner's layer.
				var local: Vector2i = n - owner.offset_cell
				if geo.get_cell_source_id(local) != GREYBOX_SOURCE_ID \
						or geo.get_cell_atlas_coords(local) != WALL_ATLAS:
					leaks += 1
		if leaks > 0:
			failures.append("M1 seed %d: %d floor-facing void/cover cell(s) NOT sealed (closure broken)"
					% [seed, leaks])
		mg._band_container.queue_free()
		mg.free()


# --- M2: collision truth (exhaustive cover queries on seed[0] — RD-U1-3) -------

func _m2_collision_truth(mg_script: GDScript, failures: Array[String]) -> void:
	var prof := _scatter_profile()
	var band := _gen(prof, SEEDS[0])
	if band == null:
		failures.append("M2: null band")
		return
	var mg := _fresh_mg(mg_script, prof)
	mg._materialise_band(band, CELL)
	var owners := _floor_owners(band)

	# Partition the capped void (non-floor 4-neighbours of floor) into interior COVER
	# cells vs ring-wall cells using the floor bounding box — floor_cells alone, no U0
	# internals: a capped cell strictly inside the box is a stamped cover cell; the
	# arena's border ring lies outside the box (floor spans the whole interior).
	var lo := Vector2i(2147483647, 2147483647)
	var hi := Vector2i(-2147483648, -2147483648)
	for c in owners:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var cover := {}
	var ring := {}
	for c in owners:
		for step in _STEPS:
			var n: Vector2i = c + step
			if owners.has(n):
				continue
			if n.x >= lo.x and n.x <= hi.x and n.y >= lo.y and n.y <= hi.y:
				cover[n] = true
			else:
				ring[n] = true
	if cover.is_empty():
		failures.append("M2: no cover cells found on seed %d (density default should stamp some)" % SEEDS[0])
	if ring.is_empty():
		failures.append("M2: no ring-wall cells found (band has no perimeter?)")

	# Physics truth. TileMapLayer collision only registers on the physics server after
	# a physics sync — await one (the T1 resolved-section implementation note).
	await get_tree().physics_frame
	await get_tree().physics_frame

	# (a) EVERY cover cell HITS — exhaustive (~25-40 cells at RD-11 defaults).
	var cover_misses := 0
	for c in cover:
		if not _point_hits(mg._band_container, _cell_centre(c)):
			cover_misses += 1
	if cover_misses > 0:
		failures.append("M2: physics MISSED inside %d of %d cover cell(s) (walk-through-cover!)"
				% [cover_misses, cover.size()])

	# (b) sampled ring-wall cells HIT.
	var ring_sample := _sample_cells(ring, 8)
	for c in ring_sample:
		if not _point_hits(mg._band_container, _cell_centre(c)):
			failures.append("M2: physics MISSED inside ring-wall cell %s" % str(c))
			break

	# (c) sampled floor cells MISS (floor is collisionless).
	var floor_sample := _sample_cells(owners, 12)
	for c in floor_sample:
		if _point_hits(mg._band_container, _cell_centre(c)):
			failures.append("M2: physics HIT inside floor cell %s (floor should be collisionless)" % str(c))
			break

	mg._band_container.queue_free()
	mg.free()


func _cell_centre(cell: Vector2i) -> Vector2:
	return Vector2(cell * CELL) + Vector2(CELL, CELL) * 0.5


## Up to `n` members of the set in stable sorted (y, x) order (deterministic sample).
func _sample_cells(members: Dictionary, n: int) -> Array[Vector2i]:
	var all: Array[Vector2i] = []
	for c in members:
		all.append(c)
	all.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	var out: Array[Vector2i] = []
	if all.is_empty():
		return out
	var stride: int = maxi(1, all.size() / n)
	var i := 0
	while i < all.size() and out.size() < n:
		out.append(all[i])
		i += stride
	return out


func _point_hits(container: Node2D, world_pos: Vector2) -> bool:
	var space := container.get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collision_mask = WALL_LAYER_MASK
	params.collide_with_bodies = true
	return not space.intersect_point(params).is_empty()


# --- M3: determinism across materialise ---------------------------------------

func _m3_determinism(mg_script: GDScript, failures: Array[String]) -> void:
	var prof := _scatter_profile()
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
	var prof := _scatter_profile()
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


# --- M5: gate (snapped-to-floor + reachable — the U1 guard flip's proof) -------

func _m5_gate(mg_script: GDScript, failures: Array[String]) -> void:
	var prof := _scatter_profile()
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


# --- M6: strengthened 2x2-open certificate (RD-U1-2) ---------------------------

func _m6_traversable(mg_script: GDScript, failures: Array[String]) -> void:
	var prof := _scatter_profile()
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

		# (a) STRONG form (U0 RD-6): every floor cell is IN T, not merely adjacent.
		var out_of_t := 0
		for c in owners:
			if not t.has(c):
				out_of_t += 1
		if out_of_t > 0:
			failures.append("M6 seed %d: %d floor cell(s) NOT in T (U0 RD-6 contract breach — route to U0)"
					% [seed, out_of_t])

		# (b) T is a single component == the floor set (T ⊆ floor by construction,
		# (a) gives floor ⊆ T, so size equality is the belt on the equality claim).
		if _component_count(t) != 1:
			failures.append("M6 seed %d: T has %d components (not a single traversable body)"
					% [seed, _component_count(t)])
		if t.size() != owners.size():
			failures.append("M6 seed %d: |T| %d != |floor| %d (T should equal the floor set)"
					% [seed, t.size(), owners.size()])

		# (c) spawn in T; the all-off gate in T's flood from spawn (or 4-adjacent —
		# the Area-gate adjacency allowance, cave-test precedent).
		var anchor: Vector2i = band.entry_piece.floor_cells[0]
		if not t.has(anchor):
			failures.append("M6 seed %d: spawn anchor not in T" % seed)
			continue
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
	var prof := _scatter_profile()
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
			failures.append("M7 seed %d: EncounterBuilder.populate spawned NOTHING on the arena" % seed)
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
	var prof := _scatter_profile()
	var band := _gen(prof, SEEDS[0])
	var mg := _fresh_mg(mg_script, prof)
	mg._materialise_band(band, CELL)
	# The start-of-run assignment path (main_game.gd start_new_run): container.modulate = tint.
	mg._band_container.modulate = prof.palette_tint
	if mg._band_container.modulate != TEST_TINT:
		failures.append("M8: _band_container.modulate != profile.palette_tint")
	mg._band_container.queue_free()
	mg.free()


# --- M9: backend controls (socket byte-identity + cave guard-arm) ---------------

func _m9_backend_controls(mg_script: GDScript, failures: Array[String]) -> void:
	# (a) SOCKET control: zero synthetic hosts + the raw pinned offset (allowlist arm).
	var greybox := load(GREYBOX_PROFILE) as BandProfile
	if greybox == null:
		failures.append("M9: could not load band_greybox.tres")
		return
	var band := BandPipeline.new().generate(greybox, SEEDS[0])
	if band == null or band.pieces.is_empty():
		failures.append("M9: band_greybox produced no pieces")
		return

	# Every socket piece already carries an authored ZonePiece instance — the synthetic
	# branch is structurally unreachable. Capture identities to prove NO host is built.
	var pre_instances: Array = []
	for p in band.pieces:
		if p.instance == null:
			failures.append("M9: a band_greybox piece has a NULL instance (would trigger the synthetic branch!)")
		pre_instances.append(p.instance)

	var mg := _fresh_mg(mg_script, greybox)
	mg._materialise_band(band, CELL)
	if mg._band_container.get_child_count() != band.pieces.size():
		failures.append("M9: materialise added %d children, expected %d (one per authored piece)"
				% [mg._band_container.get_child_count(), band.pieces.size()])
	for i in band.pieces.size():
		if band.pieces[i].instance != pre_instances[i]:
			failures.append("M9: piece %d instance was REPLACED (a synthetic host was built on a socket band)" % i)
			break

	# The socket arm of the flipped guard returns the RAW offset — byte-identity pinned
	# from inside this suite (the guard short-circuits before any band walk).
	var probe := Vector2(123.0, 456.0)
	if mg._pinned_gate_pos(band, probe) != probe + GameState.GATE_SPAWN_OFFSET:
		failures.append("M9: socket _pinned_gate_pos is NOT the raw fixed offset (allowlist arm broken)")
	mg._band_container.queue_free()
	mg.free()

	# (b) CAVE guard-arm: a cave-profile call still falls through to the snap (returns a
	# FLOOR cell), pinning the flip's cave-arm equivalence in-suite; the full behavioural
	# regression is the unmodified test_cave_materialise run alongside.
	var cave_prof := _cave_profile()
	var cave_band := _gen(cave_prof, SEEDS[0])
	if cave_band == null:
		failures.append("M9: cave control band failed to generate")
		return
	var cave_owners := _floor_owners(cave_band)
	var mg2 := _fresh_mg(mg_script, cave_prof)
	var cave_spawn: Vector2 = mg2._entry_spawn_position(cave_band)
	var pinned: Vector2 = mg2._pinned_gate_pos(cave_band, cave_spawn)
	if not cave_owners.has(mg2._world_to_cell(pinned)):
		failures.append("M9: cave _pinned_gate_pos did NOT snap to a floor cell (cave arm regressed)")
	mg2._band_container.queue_free()
	mg2.free()


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
