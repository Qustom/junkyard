extends Node
## U3 acceptance (M1.11 Wave 3) — band_four.tres "The Far Field" profile-load +
## scatter determinism + connectivity + control-parity + deck contract + the
## long-sightline identity bar.
##
## Run as a SCENE (not --script) so the autoload globals (EventBus / RNG) resolve
## at compile time, exactly as in the real game:
##   godot --headless --path Game res://tests/test_band_four_profile.tscn
##
## band_four is the M1.11 HEADLINE N=3 scalability proof: a fourth dive band —
## and the FIRST on the third-generation "scatter" backend — authored ENTIRELY as
## data (a "scatter" BandProfile + a tuned ScatterBandConfig + a reward-lifted
## DepthCurve + a ranged-natives-first deck + a non-Euclidean-dark tint) with ZERO
## new production code, riding the U0 ScatterBackend / U1 materialisation / U2a
## Lobber / U2b Sentry machinery unchanged. This test asserts the authored
## resource + its generated arena, and pins ALL THREE prior permanent controls
## (band_greybox + band_two + band_three) byte-identical:
##   C0. profile-load contract: every authored field is what RD-4 says (scatter
##       backend, empty flavors, null piece_pool, RD-11-canonical ScatterBandConfig
##       values, reward-lifted curve, deck ids, the bomb DeckEntry { base_count: 1 })
##   C1. determinism: same seed -> same fingerprint() AND floor_fingerprint()
##       twice; different seeds -> fingerprint variety (U0's order-stable poisson +
##       constructed-lane order-stability, re-asserted on the AUTHORED config)
##   C2. connectivity: is_fully_connected (cell) + is_band_connected (piece) on
##       every seed — cover never disconnects the floor (RD-6 by construction)
##   C3. cover budget (RD-5, replacing band_three's min_floor_cells soft floor —
##       ScatterBandConfig has no retry/undershoot fields): the integer stratum
##       bound cover_cells * (min_cover_spacing + 2)^2 <= 4 * interior_cells
##       (=> floor is >= ~89% of the interior, by construction, non-flaky) AND
##       pieces.size() >= 2 on every seed
##   C4. scatter depth axis: max_depth >= 4 (U1's granularity bar re-pinned on the
##       AUTHORED config), deepest_piece graded at max_depth, entry anchor present
##       and reachable (the extraction gate lands on FLOOR)
##   C5. THREE controls untouched: band_greybox pipeline fp == direct BandGenerator
##       fp; band_two pipeline fp == absolute golden pins; band_three pipeline fp ==
##       absolute golden pins (NEW this version — M1.10's shipped cave band is now
##       itself a permanent control, pinned by captured constants exactly as
##       band_two is, since no direct-generator path exists through either)
##   C6. deck: instability(4)==1.45; floor(24*1.45)==34; every deck def passes the
##       min_band gate at band_depth 4; the two natives (min_band 4) are included;
##       and the deck SPAWNS the deterministic RD-2 outcome lobber 5 / sentry 5 /
##       charger 4 / bomb 6 = 20 through the real EncounterBuilder deck lane at the
##       34-credit budget (budget spends exactly to 0)
##   C10. player-scale: the 2x2-open throat certificate (T non-empty, single
##       component, contains the entry anchor, covers the floor) on the AUTHORED
##       band-four config across the seed matrix (U1's M6 bar on the shipped band)
##   C11. long-sightline identity bar (RD-5): U0's S11(a) extents-independent lane
##       form re-asserted on the AUTHORED band across the matrix — some interior
##       row has an uninterrupted floor run == grid_width - 2 (= 62), the
##       constructed full-width clear lane that makes the field provably read OPEN

const PROFILE_PATH := "res://data/bands/band_four.tres"
const GREYBOX_PATH := "res://data/bands/band_greybox.tres"
const GREYBOX_CONFIG_PATH := "res://data/bandgen_config.tres"
const GREYBOX_CATALOG := "res://data/piece_catalog.tres"
const BAND_TWO_PATH := "res://data/bands/band_two.tres"
const BAND_THREE_PATH := "res://data/bands/band_three.tres"

## The four deck ids band_four references (ranged-natives-first, bomb via DeckEntry).
const DECK_IDS := [&"lobber", &"sentry", &"charger", &"bomb"]

## The RD-2 deterministic deck outcome at the 34-credit (instability 1.45) budget
## with the SHIPPED native cards (lobber cost 2/cap 5; sentry cost 2/cap 5;
## charger cost 2/cap 4 FROZEN; bomb cost 1/uncapped, base_count 1 via DeckEntry —
## the remainder sponge):
##   5*2 + 5*2 + 4*2 + 6*1 = 10 + 10 + 8 + 6 = 34 -> budget spends exactly to 0.
const EXPECT_SPAWNS := { &"lobber": 5, &"sentry": 5, &"charger": 4, &"bomb": 6 }

# Same determinism matrix as the sibling profile suites.
const SEEDS := [12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]

## band_two's frozen-control fingerprints (captured from `main`; parallel to SEEDS).
const BAND_TWO_GOLDEN := [
	"df82b14cb123dea1", "888abc0addb5173d", "ff2f9092d9a6d678", "6c3c7215ea5e8109",
	"e6a59148fd196537", "f9f214a82a96f2e1", "4da0ed9a7e9b1b32", "9c365f5f91500b38",
	"52a4863b579b96e5",
]

## band_three's frozen-control fingerprints, captured from `main` BEFORE U3's change
## (band_three is now a permanent control — these constants are stable). Parallel to
## SEEDS. C5 pins band_three's pipeline fp against these; any drift means U3
## perturbed the cave path (a hard contract violation).
const BAND_THREE_GOLDEN := [
	"d984fd8913bfc22c", "8d5bfe7ee3c4360f", "da99574cd75cd5ad", "8cf39ce2f8dd55b1",
	"8eea309eaeebc65b", "1c499ae32228e9ec", "f6c11c656d0f0845", "6cfc3e64efcb5ecb",
	"ce7c23bb45191e1b",
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
		printerr("BAND_FOUR FAIL: could not load ", PROFILE_PATH, " as BandProfile")
		return 1

	_check_profile_contract(profile, failures)
	_check_determinism(profile, failures)
	_check_connectivity(profile, failures)
	_check_cover_budget(profile, failures)
	_check_scatter_depth(profile, failures)
	_check_controls_untouched(profile, failures)
	_check_deck(profile, failures)
	_check_player_scale(profile, failures)
	_check_sightline(profile, failures)

	if failures.is_empty():
		print("BAND_FOUR OK — 'The Far Field' loads as a scatter band, generates deterministically ",
				"+ stays connected + reaches the depth axis + reads open across %d seeds, keeps " % SEEDS.size(),
				"band_greybox AND band_two AND band_three byte-identical, and its deck spawns the RD-2 ",
				"outcome (lobber 5 / sentry 5 / charger 4 / bomb 6 = 20) at the 34-credit budget.")
		return 0
	for f in failures:
		printerr("BAND_FOUR FAIL: ", f)
	return 1


# --- C0. Profile-load contract ---------------------------------------------------

func _check_profile_contract(profile: BandProfile, failures: Array[String]) -> void:
	if profile.id != &"band_four":
		failures.append("C0: id is '%s', expected &\"band_four\"" % profile.id)
	if profile.display_name != "The Far Field":
		failures.append("C0: display_name is '%s', expected 'The Far Field'" % profile.display_name)
	if profile.backend != "scatter":
		failures.append("C0: backend is '%s', expected 'scatter'" % profile.backend)
	if profile.band_depth != 4:
		failures.append("C0: band_depth is %d, expected 4" % profile.band_depth)

	var problems := profile.validate()
	if not problems.is_empty():
		failures.append("C0: profile.validate() returned problems: %s" % str(problems))

	# Backend config = the tuned RD-11-canonical ScatterBandConfig (RD-4 values).
	var cfg := profile.backend_config as ScatterBandConfig
	if cfg == null:
		failures.append("C0: backend_config is not a ScatterBandConfig")
	else:
		if cfg.grid_width != 64 or cfg.grid_height != 64:
			failures.append("C0: scatter grid is %dx%d, expected 64x64" % [cfg.grid_width, cfg.grid_height])
		if cfg.cover_density_pct != 8:
			failures.append("C0: scatter cover_density_pct %d != 8" % cfg.cover_density_pct)
		if cfg.min_cover_spacing != 4:
			failures.append("C0: scatter min_cover_spacing %d != 4" % cfg.min_cover_spacing)
		if cfg.border_margin != 2:
			failures.append("C0: scatter border_margin %d != 2" % cfg.border_margin)
		if cfg.cover_w_1x1 != 4 or cfg.cover_w_2x1 != 1 or cfg.cover_w_1x2 != 1 or cfg.cover_w_2x2 != 1:
			failures.append("C0: scatter cover weights are %d/%d/%d/%d, expected 4/1/1/1"
					% [cfg.cover_w_1x1, cfg.cover_w_2x1, cfg.cover_w_1x2, cfg.cover_w_2x2])
		if cfg.edge_cover_bias_pct != 60:
			failures.append("C0: scatter edge_cover_bias_pct %d != 60" % cfg.edge_cover_bias_pct)
		if cfg.clear_lane_width != 3:
			failures.append("C0: scatter clear_lane_width %d != 3" % cfg.clear_lane_width)
		if cfg.chunk_cells != 8:
			failures.append("C0: scatter chunk_cells %d != 8" % cfg.chunk_cells)
		if cfg.cell_size_px != 16:
			failures.append("C0: scatter cell_size_px %d != 16" % cfg.cell_size_px)

	# A scatter arena has NO authored pieces — piece_pool + ext are null (the
	# backend emits synthetic scat_ pieces from floor_cells).
	if profile.piece_pool != null:
		failures.append("C0: piece_pool is not null (a scatter arena has no authored pieces)")
	if profile.piece_pool_ext != null:
		failures.append("C0: piece_pool_ext is not null")
	if profile.principles.size() != 0:
		failures.append("C0: principles.size() is %d, expected 0" % profile.principles.size())
	if profile.depth_curve == null:
		failures.append("C0: depth_curve is null (expected the reward-lifted curve)")
	else:
		# Reward-lifted curve: value floor 1.45 / ceiling 2.9, tier floor 4 / ceiling 5.
		var dc := profile.depth_curve
		if not is_equal_approx(snappedf(dc.value_mult(0.0), 0.01), 1.45):
			failures.append("C0: value_mult(0) is %f, expected ~1.45" % dc.value_mult(0.0))
		if not is_equal_approx(snappedf(dc.value_mult(1.0), 0.01), 2.90):
			failures.append("C0: value_mult(1) is %f, expected ~2.90" % dc.value_mult(1.0))
		if dc.min_tier(0.0) != 4:
			failures.append("C0: min_tier(0) is %d, expected 4 (band 4 loot floor)" % dc.min_tier(0.0))
		if dc.min_tier(1.0) != 5:
			failures.append("C0: min_tier(1) is %d, expected 5 (tier ceiling)" % dc.min_tier(1.0))
	if profile.junk_catalog == null:
		failures.append("C0: junk_catalog is null")

	# Non-Euclidean-dark "Far Field" tint (RD-7), NOT the neutral-white control.
	if profile.palette_tint != Color(0.42, 0.46, 0.62, 1):
		failures.append("C0: palette_tint is %s, expected Color(0.42, 0.46, 0.62, 1)" % str(profile.palette_tint))

	# Flavors ship EMPTY on scatter bands (MANDATORY — validate() fail-louds otherwise).
	if profile.flavors.size() != 0:
		failures.append("C0: flavors.size() is %d, expected 0 (scatter bands ship empty flavors)"
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


# --- C3. Cover budget (RD-5: replaces band_three's min_floor_cells soft floor) ---

func _check_cover_budget(profile: BandProfile, failures: Array[String]) -> void:
	var cfg := profile.backend_config as ScatterBandConfig
	var w := cfg.grid_width
	var h := cfg.grid_height
	var interior := (w - 2) * (h - 2)
	var s := cfg.min_cover_spacing + 2
	for seed in SEEDS:
		var band := BandPipeline.new().generate(profile, seed)
		if band == null:
			failures.append("C3 seed %d: null band" % seed)
			continue
		if band.pieces.size() < 2:
			failures.append("C3 seed %d: band has %d pieces < 2 (mega-piece)" % [seed, band.pieces.size()])
		# The integer stratum bound (RD-4/RD-5, non-flaky, by-construction):
		# cover_cells * (min_cover_spacing + 2)^2 <= 4 * interior_cells.
		var cover_cells := _interior_cover_count(band, w, h)
		if cover_cells * s * s > 4 * interior:
			failures.append("C3 seed %d: cover %d * s^2 %d > 4 * interior %d (stratum bound broken)"
					% [seed, cover_cells, s * s, interior])
		_free_band(band)


# --- C4. Scatter depth axis ------------------------------------------------------

func _check_scatter_depth(profile: BandProfile, failures: Array[String]) -> void:
	for seed in SEEDS:
		var band := BandPipeline.new().generate(profile, seed)
		if band == null:
			failures.append("C4 seed %d: null band" % seed)
			continue
		# U1's granularity bar re-pinned on the AUTHORED config (U0's own test
		# only pins it on ScatterBandConfig.new() defaults).
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


# --- C5. THREE controls untouched (greybox + band_two + band_three) --------------

func _check_controls_untouched(_profile: BandProfile, failures: Array[String]) -> void:
	# band_greybox: pipeline fp == direct BandGenerator fp (a live direct-generator
	# path exists for the flavor-less greybox).
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

	# band_two + band_three: absolute golden pins (no direct-generator path exists
	# through band_two's flavor stages nor band_three's cave backend, so both prior
	# permanent controls are pinned by captured constants — U3 must not perturb them).
	_pin_golden(BAND_TWO_PATH, BAND_TWO_GOLDEN, "band_two", failures)
	_pin_golden(BAND_THREE_PATH, BAND_THREE_GOLDEN, "band_three", failures)


func _pin_golden(path: String, golden: Array, tag: String, failures: Array[String]) -> void:
	var prof := load(path) as BandProfile
	if prof == null:
		failures.append("C5: could not load %s" % path)
		return
	for i in SEEDS.size():
		var seed: int = SEEDS[i]
		var piped := BandPipeline.new().generate(prof, seed)
		if piped == null:
			failures.append("C5 %s seed %d: null band" % [tag, seed])
			continue
		var got := piped.fingerprint().substr(0, 16)
		if got != golden[i]:
			failures.append("C5 %s seed %d: fp %s != golden %s (control perturbed!)"
					% [tag, seed, got, golden[i]])
		_free_band(piped)


# --- C6. Deck gating + deterministic spawn outcome -------------------------------

func _check_deck(profile: BandProfile, failures: Array[String]) -> void:
	# Instability + budget arithmetic (band 4 = 1.45 -> floor(24*1.45) = 34).
	if not is_equal_approx(EncounterBuilder.instability(4), 1.45):
		failures.append("C6: instability(4) is %f, expected 1.45" % EncounterBuilder.instability(4))
	var budget := int(floor(float(EncounterBuilder.BASE_CREDITS) * EncounterBuilder.instability(4)))
	if budget != 34:
		failures.append("C6: deck budget is %d, expected 34 (floor(24*1.45))" % budget)

	# min_band gate: every deck def passes at band_depth 4; natives (min_band 4) in.
	var saw_native := 0
	for r in profile.opposition_deck:
		var def := _deck_def(r)
		if def == null:
			continue
		if not (profile.band_depth >= def.min_band):
			failures.append("C6: deck def '%s' (min_band %d) filtered out at band_depth 4"
					% [def.id, def.min_band])
		if def.min_band == 4:
			saw_native += 1
	if saw_native < 2:
		failures.append("C6: expected 2 band-4 natives (lobber + sentry), saw %d" % saw_native)

	# The deterministic RD-2 spawn outcome through the real EncounterBuilder deck
	# lane, on a real generated scatter band, across the seed matrix (budget +
	# per_band_cap bind the counts; demand = eligible pieces never binds).
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
		if total != 20:
			failures.append("C6 seed %d: total deck spawns %d, expected 20 (5/5/4/6)" % [seed, total])
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


# --- C11. Long-sightline identity bar (RD-5: U0's S11(a) extents-independent) -----

func _check_sightline(profile: BandProfile, failures: Array[String]) -> void:
	var cfg := profile.backend_config as ScatterBandConfig
	var w := cfg.grid_width
	var h := cfg.grid_height
	for seed in SEEDS:
		var band := BandPipeline.new().generate(profile, seed)
		if band == null:
			failures.append("C11 seed %d: null band" % seed)
			continue
		var floor_set := {}
		for p in band.pieces:
			for c in p.floor_cells:
				floor_set[c] = true
		# The constructed full-width clear lane: SOME interior row has an
		# uninterrupted E-W floor run == grid_width - 2 (= 62). Extents-independent
		# form of U0's S11(a) — the field provably reads OPEN.
		var best_run := 0
		for y in range(1, h - 1):
			var run := 0
			for x in range(1, w - 1):
				run = run + 1 if floor_set.has(Vector2i(x, y)) else 0
				best_run = maxi(best_run, run)
		if best_run != w - 2:
			failures.append("C11 seed %d: max E-W floor run %d != interior width %d (no full lane)"
					% [seed, best_run, w - 2])
		_free_band(band)


# --- Helpers ---------------------------------------------------------------------

func _deck_def(r: Resource) -> OppositionDef:
	if r is DeckEntry:
		return (r as DeckEntry).def as OppositionDef
	return r as OppositionDef


## Count of interior (border-excluded) cells that are NOT floor — the cover cells.
func _interior_cover_count(band: Band, w: int, h: int) -> int:
	var floor_set := {}
	for p in band.pieces:
		for c in p.floor_cells:
			floor_set[c] = true
	var cover := 0
	for x in range(1, w - 1):
		for y in range(1, h - 1):
			if not floor_set.has(Vector2i(x, y)):
				cover += 1
	return cover


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
