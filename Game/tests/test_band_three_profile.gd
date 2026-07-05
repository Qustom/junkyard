extends Node
## T3 acceptance (M1.10 Wave 3) — band_three.tres "The Warren" profile-load +
## cave determinism + connectivity + control-parity + deck contract.
##
## Run as a SCENE (not --script) so the autoload globals (EventBus / RNG) resolve
## at compile time, exactly as in the real game:
##   godot --headless --path Game res://tests/test_band_three_profile.tscn
##
## band_three is the M1.10 HEADLINE scalability proof: a third dive band authored
## ENTIRELY as data (a "cave" BandProfile + a tuned CaveBandConfig + a reward-
## lifted DepthCurve + a natives-first deck + a blue-violet tint) with ZERO new
## production code, riding the T0 CaveBackend / T1 materialisation / T2a Ambusher /
## T2b Burrower machinery unchanged. This test asserts the authored resource +
## its generated cave, and pins BOTH permanent socket controls byte-identical:
##   C0. profile-load contract: every authored field is what the spec says (cave
##       backend, empty flavors, null piece_pool, CaveBandConfig values, deck ids,
##       the bomb DeckEntry wrapper carrying { base_count: 1 })
##   C1. determinism: same seed -> same fingerprint() AND floor_fingerprint()
##       twice; different seeds -> fingerprint variety (T0's sorted-region +
##       deterministic-CARVE order-stability, re-asserted on the AUTHORED config)
##   C2. connectivity: is_fully_connected (cell) + is_band_connected (piece) on
##       every seed — single FLOOR component post keep-largest + CARVE
##   C3. soft floor: total floor cells >= min_floor_cells and pieces >= 2 on
##       every seed (cave analog of band_two's soft_floor)
##   C4. cave depth axis: max_depth >= 4 (T1's M4 granularity bar re-pinned on
##       T3's tuned instance), deepest_piece graded at max_depth, entry anchor
##       present and reachable (the extraction gate lands on FLOOR)
##   C5. controls untouched: band_greybox pipeline fp == direct BandGenerator fp
##       AND band_two pipeline fp == absolute golden pins (no direct-generator
##       path exists through band_two's flavor stages, so band_two is pinned by
##       captured constants — it is a frozen control this task must not perturb)
##   C6. deck: instability(3)==1.30; floor(24*1.30)==31; every deck def passes the
##       min_band gate at band_depth 3; the natives (min_band 3) are included; and
##       the deck SPAWNS the deterministic D-RAT-6 outcome ambusher 6 / burrower 3
##       / splitter 4 / bomb 1 = 14 through the real EncounterBuilder deck lane at
##       the 31-credit budget (budget spends exactly to 0)
##   C10. player-scale: the 2x2-open throat certificate (T non-empty, single
##       component, contains the entry anchor, covers the floor) on the AUTHORED
##       band-three config across the seed matrix (T1's M6 bar on the shipped band,
##       not just T0's defaults)

const PROFILE_PATH := "res://data/bands/band_three.tres"
const GREYBOX_PATH := "res://data/bands/band_greybox.tres"
const GREYBOX_CONFIG_PATH := "res://data/bandgen_config.tres"
const GREYBOX_CATALOG := "res://data/piece_catalog.tres"
const BAND_TWO_PATH := "res://data/bands/band_two.tres"

## The four deck ids band_three references (natives-first, bomb via DeckEntry).
const DECK_IDS := [&"ambusher", &"burrower", &"splitter", &"bomb"]

## The D-RAT-6 deterministic deck outcome at the 31-credit (instability 1.30)
## budget with T2a/T2b's authored cards (ambusher cost 2/cap 6; burrower cost
## 2/cap 3; splitter cost 3/cap 8; bomb cost 1/uncapped, budget-bound to 1):
##   6*2 + 3*2 + 4*3 + 1*1 = 12 + 6 + 12 + 1 = 31 -> budget spends exactly to 0.
const EXPECT_SPAWNS := { &"ambusher": 6, &"burrower": 3, &"splitter": 4, &"bomb": 1 }

# Same determinism matrix as test_cave_backend / test_band_two_profile.
const SEEDS := [12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]

## band_two's frozen-control fingerprints, captured from `main` BEFORE T3's change
## (band_two is a permanent control — these constants are stable). Parallel to
## SEEDS. C5 pins band_two's pipeline fp against these; any drift means T3
## perturbed the socket path (a hard contract violation).
const BAND_TWO_GOLDEN := [
	"df82b14cb123dea1", "888abc0addb5173d", "ff2f9092d9a6d678", "6c3c7215ea5e8109",
	"e6a59148fd196537", "f9f214a82a96f2e1", "4da0ed9a7e9b1b32", "9c365f5f91500b38",
	"52a4863b579b96e5",
]

const CELL := 16


## The policy-blind recording service (test_deck_entry / test_encounter_builder
## pattern): inherits the REAL begin_band / valid_cells, replaces only the spawn
## mechanism so the builder's ordered plan is captured without instantiating any
## host scene. The builder itself applies budget + per_band_cap in n_plan, so the
## recorded per-id counts ARE the deterministic deck outcome.
class FakeSpawnService:
	extends SpawnService
	var counts: Dictionary = {}
	var _stub_nodes: Array[Node] = []

	func spawn(def: OppositionDef, cell: Vector2i, _ctx: Dictionary = {}) -> Node:
		var one: Array[Vector2i] = [cell]
		if valid_cells(one).size() != 1:          # the real BUG7 re-check
			return null
		counts[def.id] = int(counts.get(def.id, 0)) + 1
		var n := Node.new()
		_stub_nodes.append(n)
		return n

	func cleanup() -> void:
		for n in _stub_nodes:
			if is_instance_valid(n):
				n.free()
		_stub_nodes.clear()


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	var profile := load(PROFILE_PATH) as BandProfile
	if profile == null:
		printerr("BAND_THREE FAIL: could not load ", PROFILE_PATH, " as BandProfile")
		return 1

	_check_profile_contract(profile, failures)
	_check_determinism(profile, failures)
	_check_connectivity(profile, failures)
	_check_soft_floor(profile, failures)
	_check_cave_depth(profile, failures)
	_check_controls_untouched(profile, failures)
	_check_deck(profile, failures)
	_check_player_scale(profile, failures)

	if failures.is_empty():
		print("BAND_THREE OK — 'The Warren' loads as a cave band, generates deterministically ",
				"+ stays connected + reaches the depth axis across %d seeds, keeps band_greybox " % SEEDS.size(),
				"AND band_two byte-identical, and its deck spawns the D-RAT-6 outcome ",
				"(ambusher 6 / burrower 3 / splitter 4 / bomb 1 = 14) at the 31-credit budget.")
		return 0
	for f in failures:
		printerr("BAND_THREE FAIL: ", f)
	return 1


# --- C0. Profile-load contract ---------------------------------------------------

func _check_profile_contract(profile: BandProfile, failures: Array[String]) -> void:
	if profile.id != &"band_three":
		failures.append("C0: id is '%s', expected &\"band_three\"" % profile.id)
	if profile.display_name != "The Warren":
		failures.append("C0: display_name is '%s', expected 'The Warren'" % profile.display_name)
	if profile.backend != "cave":
		failures.append("C0: backend is '%s', expected 'cave'" % profile.backend)
	if profile.band_depth != 3:
		failures.append("C0: band_depth is %d, expected 3" % profile.band_depth)

	var problems := profile.validate()
	if not problems.is_empty():
		failures.append("C0: profile.validate() returned problems: %s" % str(problems))

	# Backend config = the tuned CaveBandConfig (breakdown amendment #4 values).
	var cfg := profile.backend_config as CaveBandConfig
	if cfg == null:
		failures.append("C0: backend_config is not a CaveBandConfig")
	else:
		if cfg.grid_width != 56 or cfg.grid_height != 56:
			failures.append("C0: cave grid is %dx%d, expected 56x56" % [cfg.grid_width, cfg.grid_height])
		if cfg.fill_pct != 45:
			failures.append("C0: cave fill_pct %d != 45" % cfg.fill_pct)
		if cfg.smooth_passes != 4:
			failures.append("C0: cave smooth_passes %d != 4" % cfg.smooth_passes)
		if cfg.wall_threshold != 5:
			failures.append("C0: cave wall_threshold %d != 5" % cfg.wall_threshold)
		if cfg.min_region_cells != 24:
			failures.append("C0: cave min_region_cells %d != 24" % cfg.min_region_cells)
		# T0-defaulted fields set explicitly for pin-ability.
		if cfg.carve_width != 2:
			failures.append("C0: cave carve_width %d != 2" % cfg.carve_width)
		if cfg.chunk_cells != 8:
			failures.append("C0: cave chunk_cells %d != 8" % cfg.chunk_cells)
		if cfg.min_floor_cells != 300:
			failures.append("C0: cave min_floor_cells %d != 300" % cfg.min_floor_cells)
		if cfg.max_attempts != 8:
			failures.append("C0: cave max_attempts %d != 8" % cfg.max_attempts)
		if cfg.cell_size_px != 16:
			failures.append("C0: cave cell_size_px %d != 16" % cfg.cell_size_px)

	# A cave has NO authored pieces — piece_pool + ext are null (the cave backend
	# emits synthetic pieces from floor_cells).
	if profile.piece_pool != null:
		failures.append("C0: piece_pool is not null (a cave has no authored pieces)")
	if profile.piece_pool_ext != null:
		failures.append("C0: piece_pool_ext is not null")
	if profile.principles.size() != 0:
		failures.append("C0: principles.size() is %d, expected 0" % profile.principles.size())
	if profile.depth_curve == null:
		failures.append("C0: depth_curve is null (expected the reward-lifted curve)")
	else:
		# Reward-lifted curve: value floor 1.30 / ceiling 2.5, tier floor 3 / ceiling 5.
		var dc := profile.depth_curve
		if not is_equal_approx(snappedf(dc.value_mult(0.0), 0.01), 1.30):
			failures.append("C0: value_mult(0) is %f, expected ~1.30" % dc.value_mult(0.0))
		if not is_equal_approx(snappedf(dc.value_mult(1.0), 0.01), 2.50):
			failures.append("C0: value_mult(1) is %f, expected ~2.50" % dc.value_mult(1.0))
		if dc.min_tier(0.0) != 3:
			failures.append("C0: min_tier(0) is %d, expected 3 (band 3 loot floor)" % dc.min_tier(0.0))
		if dc.min_tier(1.0) != 5:
			failures.append("C0: min_tier(1) is %d, expected 5 (tier ceiling)" % dc.min_tier(1.0))
	if profile.junk_catalog == null:
		failures.append("C0: junk_catalog is null")

	# Blue-violet "impossible color" tint (D-RAT-5), NOT the neutral-white control.
	if profile.palette_tint == Color(1, 1, 1, 1):
		failures.append("C0: palette_tint is neutral white — the Warren tint is missing")

	# Flavors ship EMPTY on cave bands (MANDATORY — validate() fail-louds otherwise).
	if profile.flavors.size() != 0:
		failures.append("C0: flavors.size() is %d, expected 0 (cave bands ship empty flavors)"
				% profile.flavors.size())

	# Deck: exactly the 4 authored rows; every id resolves; the bomb row is a
	# DeckEntry carrying exactly { base_count: 1 }; the other three are plain refs.
	if profile.opposition_deck.size() != 4:
		failures.append("C0: opposition_deck.size() is %d, expected 4" % profile.opposition_deck.size())
	var deck_ids: Array = []
	for r in profile.opposition_deck:
		var d := _deck_def(r)
		if d == null:
			failures.append("C0: a deck entry is neither an OppositionDef nor a DeckEntry wrapping one")
			continue
		deck_ids.append(d.id)
	for want in DECK_IDS:
		if not deck_ids.has(want):
			failures.append("C0: deck missing def id '%s'" % want)

	# EXACTLY the bomb row is a DeckEntry, carrying EXACTLY { base_count: 1 };
	# every other row stays a plain def ref (mixed-array back-compat).
	var bomb_wrapped := 0
	for r in profile.opposition_deck:
		if not (r is DeckEntry):
			continue
		var entry := r as DeckEntry
		var d := entry.def as OppositionDef
		if d == null or d.id != &"bomb":
			failures.append("C0: unexpected DeckEntry wrapper on '%s' (only the bomb row is wrapped)"
					% (str(d.id) if d != null else "<broken def>"))
			continue
		bomb_wrapped += 1
		if int(entry.param_overrides.get("base_count", -1)) != 1:
			failures.append("C0: bomb DeckEntry base_count is %s, expected 1"
					% str(entry.param_overrides.get("base_count")))
		if entry.param_overrides.size() != 1:
			failures.append("C0: bomb DeckEntry carries %d overrides, expected exactly 1 (base_count)"
					% entry.param_overrides.size())
	if bomb_wrapped != 1:
		failures.append("C0: bomb DeckEntry wrapper count is %d, expected 1" % bomb_wrapped)


# --- C1. Determinism -------------------------------------------------------------

func _check_determinism(profile: BandProfile, failures: Array[String]) -> void:
	var fps := {}
	for seed in SEEDS:
		var a := BandPipeline.new().generate(profile, seed)
		var b := BandPipeline.new().generate(profile, seed)
		if a == null or b == null:
			failures.append("C1 seed %d: null band" % seed)
			_free_band(a); _free_band(b)
			continue
		if a.fingerprint() != b.fingerprint():
			failures.append("C1 seed %d: fingerprint() NOT deterministic (%s vs %s)"
					% [seed, a.fingerprint().substr(0, 12), b.fingerprint().substr(0, 12)])
		if a.floor_fingerprint() != b.floor_fingerprint():
			failures.append("C1 seed %d: floor_fingerprint() NOT deterministic" % seed)
		fps[a.fingerprint()] = true
		_free_band(a)
		_free_band(b)
	if fps.size() < 2:
		failures.append("C1: all seeds produced the SAME fingerprint (no seed variety)")


# --- C2. Connectivity ------------------------------------------------------------

func _check_connectivity(profile: BandProfile, failures: Array[String]) -> void:
	var conn := ConnectivityGuarantee.new()
	var gen := BandGenerator.new()
	for seed in SEEDS:
		var band := BandPipeline.new().generate(profile, seed)
		if band == null:
			failures.append("C2 seed %d: null band" % seed)
			continue
		if not conn.is_fully_connected(band):
			failures.append("C2 seed %d: cell-level connectivity lost (stranded floor)" % seed)
		if not gen.is_band_connected(band):
			failures.append("C2 seed %d: piece-level is_band_connected FALSE" % seed)
		_free_band(band)


# --- C3. Soft floor (cave sizing) ------------------------------------------------

func _check_soft_floor(profile: BandProfile, failures: Array[String]) -> void:
	var cfg := profile.backend_config as CaveBandConfig
	for seed in SEEDS:
		var band := BandPipeline.new().generate(profile, seed)
		if band == null:
			failures.append("C3 seed %d: null band" % seed)
			continue
		if band.pieces.size() < 2:
			failures.append("C3 seed %d: band has %d pieces < 2 (mega-piece)" % [seed, band.pieces.size()])
		var floor_total := 0
		for p in band.pieces:
			floor_total += p.floor_cells.size()
		if floor_total < cfg.min_floor_cells:
			failures.append("C3 seed %d: %d floor cells < min_floor_cells %d"
					% [seed, floor_total, cfg.min_floor_cells])
		_free_band(band)


# --- C4. Cave depth axis ---------------------------------------------------------

func _check_cave_depth(profile: BandProfile, failures: Array[String]) -> void:
	for seed in SEEDS:
		var band := BandPipeline.new().generate(profile, seed)
		if band == null:
			failures.append("C4 seed %d: null band" % seed)
			continue
		# T1's M4 granularity bar re-pinned on the AUTHORED config (T1's own test
		# only pins it on CaveBandConfig.new() defaults).
		if band.max_depth < 4:
			failures.append("C4 seed %d: max_depth %d < 4 on the authored config" % [seed, band.max_depth])
		if band.deepest_piece == null or band.deepest_piece.depth_index != band.max_depth:
			var di := -999 if band.deepest_piece == null else band.deepest_piece.depth_index
			failures.append("C4 seed %d: deepest_piece.depth_index %d != max_depth %d"
					% [seed, di, band.max_depth])
		# Entry anchor present + reachable (extraction gate lands on FLOOR).
		if band.entry_piece == null or band.entry_piece.floor_cells.is_empty():
			failures.append("C4 seed %d: entry piece missing / no floor cells" % seed)
		if band.deepest_piece != null and band.deepest_piece.depth_index >= band.pieces.size():
			failures.append("C4 seed %d: deepest_piece (extraction anchor) unreachable" % seed)
		_free_band(band)


# --- C5. Both socket controls untouched ------------------------------------------

func _check_controls_untouched(_profile: BandProfile, failures: Array[String]) -> void:
	# band_greybox: pipeline fp == direct BandGenerator fp (verbatim from band_two's
	# C5 — a live direct-generator path exists for the flavor-less greybox).
	var greybox := load(GREYBOX_PATH) as BandProfile
	if greybox == null:
		failures.append("C5: could not load band_greybox.tres")
	else:
		var gen := BandGenerator.new()
		var cfg := load(GREYBOX_CONFIG_PATH) as BandGenConfig
		var catalog: Array[ZonePieceData] = (load(GREYBOX_CATALOG) as PieceCatalog).pieces
		for seed in SEEDS:
			var direct := gen.generate(seed, cfg, catalog)
			var piped := BandPipeline.new().generate(greybox, seed)
			if direct == null or piped == null:
				failures.append("C5 greybox seed %d: null band" % seed)
			elif direct.fingerprint() != piped.fingerprint():
				failures.append("C5 greybox seed %d: pipeline fp != direct fp (%s vs %s)"
						% [seed, piped.fingerprint().substr(0, 12), direct.fingerprint().substr(0, 12)])
			_free_band(direct)
			_free_band(piped)

	# band_two: absolute golden pins (no direct-generator path exists through its
	# flavor stages, so the second socket control is pinned by captured constants).
	var band_two := load(BAND_TWO_PATH) as BandProfile
	if band_two == null:
		failures.append("C5: could not load band_two.tres")
	else:
		for i in SEEDS.size():
			var seed: int = SEEDS[i]
			var piped := BandPipeline.new().generate(band_two, seed)
			if piped == null:
				failures.append("C5 band_two seed %d: null band" % seed)
				continue
			var got := piped.fingerprint().substr(0, 16)
			if got != BAND_TWO_GOLDEN[i]:
				failures.append("C5 band_two seed %d: fp %s != golden %s (control perturbed!)"
						% [seed, got, BAND_TWO_GOLDEN[i]])
			_free_band(piped)


# --- C6. Deck gating + deterministic spawn outcome -------------------------------

func _check_deck(profile: BandProfile, failures: Array[String]) -> void:
	# Instability + budget arithmetic (band 3 = 1.30 -> floor(24*1.30) = 31).
	if not is_equal_approx(EncounterBuilder.instability(3), 1.30):
		failures.append("C6: instability(3) is %f, expected 1.30" % EncounterBuilder.instability(3))
	var budget := int(floor(float(EncounterBuilder.BASE_CREDITS) * EncounterBuilder.instability(3)))
	if budget != 31:
		failures.append("C6: deck budget is %d, expected 31 (floor(24*1.30))" % budget)

	# min_band gate: every deck def passes at band_depth 3; natives (min_band 3) in.
	var saw_native := 0
	for r in profile.opposition_deck:
		var def := _deck_def(r)
		if def == null:
			continue
		if not (profile.band_depth >= def.min_band):
			failures.append("C6: deck def '%s' (min_band %d) filtered out at band_depth 3"
					% [def.id, def.min_band])
		if def.min_band == 3:
			saw_native += 1
	if saw_native < 2:
		failures.append("C6: expected 2 band-3 natives (ambusher + burrower), saw %d" % saw_native)

	# The deterministic D-RAT-6 spawn outcome through the real EncounterBuilder deck
	# lane, on a real generated cave band, across the seed matrix (budget + per_band_cap
	# bind the counts; demand = eligible pieces never binds on a chunked cave).
	for seed in SEEDS:
		var band := BandPipeline.new().generate(profile, seed)
		if band == null:
			failures.append("C6 seed %d: null band" % seed)
			continue
		var rc := RunConfig.new()
		var svc := _fresh_fake(rc)
		EncounterBuilder.new().populate(band, profile, rc, svc)
		var counts: Dictionary = svc.counts
		var total := 0
		for id in EXPECT_SPAWNS:
			var got := int(counts.get(id, 0))
			total += got
			if got != EXPECT_SPAWNS[id]:
				failures.append("C6 seed %d: '%s' spawned %d, expected %d"
						% [seed, id, got, EXPECT_SPAWNS[id]])
		# No unexpected extra ids in the plan.
		for id in counts:
			if not EXPECT_SPAWNS.has(id):
				failures.append("C6 seed %d: unexpected deck spawn id '%s' (%d)" % [seed, id, counts[id]])
		if total != 14:
			failures.append("C6 seed %d: total deck spawns %d, expected 14 (6/3/4/1)" % [seed, total])
		_free_fake(svc)
		_free_band(band)


# --- C10. Player-scale (2x2-open) certificate on the AUTHORED config --------------

func _check_player_scale(profile: BandProfile, failures: Array[String]) -> void:
	for seed in SEEDS:
		var band := BandPipeline.new().generate(profile, seed)
		if band == null:
			continue
		var floor_set := {}
		for p in band.pieces:
			for c in p.floor_cells:
				floor_set[c] = true
		var t := _traversable_set(floor_set)
		if t.is_empty():
			failures.append("C10 seed %d: traversable 2x2-open set T is EMPTY" % seed)
			_free_band(band); continue
		if _component_count(t) != 1:
			failures.append("C10 seed %d: T has %d components (not single)" % [seed, _component_count(t)])
		if not t.has(band.entry_piece.floor_cells[0]):
			failures.append("C10 seed %d: entry anchor not in T (not player-scale)" % seed)
		if not _floor_covered_by_t(floor_set, t):
			failures.append("C10 seed %d: a floor cell is > 1 cell from T (isolated non-standable)" % seed)
		_free_band(band)


# --- Helpers ---------------------------------------------------------------------

func _deck_def(r: Resource) -> OppositionDef:
	if r is DeckEntry:
		return (r as DeckEntry).def as OppositionDef
	return r as OppositionDef


func _fresh_fake(rc: RunConfig) -> FakeSpawnService:
	var svc := FakeSpawnService.new()
	var container := Node2D.new()
	add_child(container)
	svc.begin_band(container, CELL, Vector2.INF, rc)   # INF = unarmed (no entry filter)
	svc.set_cap_group(&"new_hazards", SpawnService.NEW_HAZARD_BAND_CEILING)
	return svc


func _free_fake(svc: FakeSpawnService) -> void:
	svc.cleanup()
	var container: Node2D = svc._container
	if container != null and is_instance_valid(container):
		remove_child(container)
		container.free()
	svc.free()


func _traversable_set(floor_set: Dictionary) -> Dictionary:
	var t := {}
	for c in floor_set:
		var r: Vector2i = c + Vector2i(1, 0)
		var d: Vector2i = c + Vector2i(0, 1)
		var rd: Vector2i = c + Vector2i(1, 1)
		if floor_set.has(r) and floor_set.has(d) and floor_set.has(rd):
			t[c] = true
			t[r] = true
			t[d] = true
			t[rd] = true
	return t


func _component_count(members: Dictionary) -> int:
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
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
			for s in steps:
				var n: Vector2i = cur + s
				if members.has(n) and not visited.has(n):
					visited[n] = true
					queue.append(n)
	return comps


func _floor_covered_by_t(floor_set: Dictionary, t: Dictionary) -> bool:
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for c in floor_set:
		if t.has(c):
			continue
		var adj := false
		for s in steps:
			if t.has(c + s):
				adj = true
				break
		if not adj:
			return false
	return true


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
