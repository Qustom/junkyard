extends Node
## S7 acceptance — band_two.tres "The Sump" profile-load + determinism +
## connectivity contract (M1.9 Wave 4, spec §6).
##
## Run as a SCENE (not --script) so the autoload globals resolve at compile
## time, exactly as in the real game:
##   godot --headless --path Game res://tests/test_band_two_profile.tscn
##
## band_two is the band-side "content = data" proof: a distinct biome authored
## as a BandProfile .tres (branchy socket layout + SetPieceInject + WearDecay
## flavors + a reward-lifted curve + a min_band-gated deck + a sepia tint),
## with ZERO new generator code. This test asserts the authored resource:
##   C0. profile-load contract: every authored field is what the spec says
##   C1. determinism: same seed -> same fingerprint() AND floor_fingerprint()
##       twice; different seeds -> fingerprint variety (the (seed+config) bar)
##   C2. connectivity through WearDecay: is_fully_connected on EVERY seed — the
##       S5 Stage-5 guarantee proven for band_two's authored decay budgets
##   C3. soft floor: band reaches ceil(target*soft_floor) pieces on every seed
##   C4. set-piece deep + non-vacuous: band_two's authored SetPieceInject config
##       injects room_xl at a host depth_norm >= 0.6, at least once in the matrix
##   C5. control untouched: band_greybox pipeline fp == direct BandGenerator fp
##   C6. deck gating: instability(1)=1.0 / instability(2)=1.15; every authored
##       deck def passes the min_band gate at band_depth 2
##
## S9 amendment (D-RAT-2 delivery): the charger deck row is a DeckEntry wrapper
## carrying { throwable_while_charging=false, wall_crash_recover_mult=2.0 };
## C0/C6 unwrap wrappers via _deck_def() and C0 pins the wrapper's contents.
## The merge/precedence behavior itself is test_deck_entry's job.
##
## PARALLEL-MERGE NOTE: charger.tres / splitter.tres (S6a/S6b) do NOT exist in
## this worktree, so band_two's deck ships 4 shipped defs here; the two band-2
## predators are appended + integration-checked at S8/SG1 (deck.size 4 -> 6).
## The full-populate spawn (needs a live SpawnService + player) is likewise an
## S8/SG1 integration check; this test proves the STATIC deck contract only.

const PROFILE_PATH := "res://data/bands/band_two.tres"
const GREYBOX_PATH := "res://data/bands/band_greybox.tres"
const GREYBOX_CONFIG_PATH := "res://data/bandgen_config.tres"
const GREYBOX_CATALOG_PATH := "res://data/piece_catalog.tres"

## The existing large piece band_two reuses as its deep set-piece (D-RAT-3: no
## bespoke landmark). Must match band_two.tres's SetPieceEntry.piece.
const VAULT_PIECE_ID := &"piece_room_xl"

## The 4 shipped-hazard deck ids present in THIS worktree (charger/splitter join
## at S8/SG1 integration).
const SHIPPED_DECK_IDS := [&"pursuer", &"pingpong", &"bomb", &"spike"]

# Same spread as test_bandgen_determinism.gd (the determinism matrix).
const SEEDS := [12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]


func _ready() -> void:
	var code := _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []

	var profile := load(PROFILE_PATH) as BandProfile
	if profile == null:
		printerr("BAND_TWO FAIL: could not load ", PROFILE_PATH, " as BandProfile")
		return 1

	_check_profile_contract(profile, failures)
	_check_determinism(profile, failures)
	_check_connectivity(profile, failures)
	_check_soft_floor(profile, failures)
	_check_set_piece(profile, failures)
	_check_control_untouched(failures)
	_check_deck_gating(profile, failures)

	if failures.is_empty():
		print("BAND_TWO OK — 'The Sump' profile loads, generates deterministically, ",
				"stays connected through WearDecay, injects its deep vault, and gates its deck ",
				"across %d seeds" % SEEDS.size())
		return 0
	for f in failures:
		printerr("BAND_TWO FAIL: ", f)
	return 1


# --- C0. Profile-load contract ---------------------------------------------------

func _check_profile_contract(profile: BandProfile, failures: Array[String]) -> void:
	if profile.id != &"band_two":
		failures.append("C0: id is '%s', expected &\"band_two\"" % profile.id)
	if profile.display_name != "The Sump":
		failures.append("C0: display_name is '%s', expected 'The Sump'" % profile.display_name)
	if profile.backend != "socket":
		failures.append("C0: backend is '%s', expected 'socket'" % profile.backend)
	if profile.archetype != "branchy":
		failures.append("C0: archetype is '%s', expected 'branchy'" % profile.archetype)
	if profile.band_depth != 2:
		failures.append("C0: band_depth is %d, expected 2" % profile.band_depth)

	var problems := profile.validate()
	if not problems.is_empty():
		failures.append("C0: profile.validate() returned problems: %s" % str(problems))

	# Backend config = the branchy tuning (target 16 / branch 0.15).
	var cfg := profile.backend_config as BandGenConfig
	if cfg == null:
		failures.append("C0: backend_config is not a BandGenConfig")
	else:
		if cfg.target_piece_count != 16:
			failures.append("C0: backend_config.target_piece_count %d != 16" % cfg.target_piece_count)
		if not is_equal_approx(cfg.branch_chance, 0.15):
			failures.append("C0: backend_config.branch_chance %f != 0.15" % cfg.branch_chance)

	if profile.piece_pool == null or profile.piece_pool.pieces.size() != 10:
		failures.append("C0: piece_pool is not the 10-piece extended catalog")
	if profile.depth_curve == null:
		failures.append("C0: depth_curve is null (expected the reward-lifted curve)")
	if profile.junk_catalog == null:
		failures.append("C0: junk_catalog is null")

	# Sepia-amber Sump tint (D-RAT-1), NOT the neutral-white control.
	if profile.palette_tint == Color(1, 1, 1, 1):
		failures.append("C0: palette_tint is neutral white — the Sump tint is missing")

	# Flavors: exactly [SetPieceInject, WearDecay] in that order.
	if profile.flavors.size() != 2:
		failures.append("C0: flavors.size() is %d, expected 2" % profile.flavors.size())
	else:
		if not (profile.flavors[0] is SetPieceInjectConfig):
			failures.append("C0: flavors[0] is not a SetPieceInjectConfig")
		if not (profile.flavors[1] is WearDecayConfig):
			failures.append("C0: flavors[1] is not a WearDecayConfig")
		else:
			var wd := profile.flavors[1] as WearDecayConfig
			if wd.state != &"flooded":
				failures.append("C0: WearDecay.state is '%s', expected &\"flooded\"" % wd.state)

	# Deck: the 4 shipped defs present (charger/splitter join at S8/SG1). Rows are
	# plain OppositionDefs OR S9 DeckEntry wrappers — unwrap before the id checks.
	if profile.opposition_deck.size() < 4:
		failures.append("C0: opposition_deck.size() is %d, expected >= 4 shipped defs"
				% profile.opposition_deck.size())
	var deck_ids: Array = []
	for r in profile.opposition_deck:
		var d := _deck_def(r)
		if d == null:
			failures.append("C0: a deck entry is neither an OppositionDef nor a "
					+ "DeckEntry wrapping one")
			continue
		deck_ids.append(d.id)
	for want in SHIPPED_DECK_IDS:
		if not deck_ids.has(want):
			failures.append("C0: deck missing shipped def id '%s'" % want)

	# S9 (D-RAT-2 delivery): EXACTLY the charger row is a DeckEntry, carrying
	# EXACTLY the two ratified deck-only overrides; every other row stays a plain
	# def ref (mixed-array back-compat).
	var charger_wrapped := 0
	for r in profile.opposition_deck:
		if not (r is DeckEntry):
			continue
		var entry := r as DeckEntry
		var d := entry.def as OppositionDef
		if d == null or d.id != &"charger":
			failures.append("C0/S9: unexpected DeckEntry wrapper on '%s' (only the charger row is rewrapped)"
					% (str(d.id) if d != null else "<broken def>"))
			continue
		charger_wrapped += 1
		if entry.param_overrides.get("throwable_while_charging", true) != false:
			failures.append("C0/S9: charger DeckEntry missing throwable_while_charging=false")
		if float(entry.param_overrides.get("wall_crash_recover_mult", 0.0)) != 2.0:
			failures.append("C0/S9: charger DeckEntry wall_crash_recover_mult is %s, expected 2.0"
					% str(entry.param_overrides.get("wall_crash_recover_mult")))
		if entry.param_overrides.size() != 2:
			failures.append("C0/S9: charger DeckEntry carries %d overrides, expected exactly the 2 D-RAT-2 values"
					% entry.param_overrides.size())
	if charger_wrapped != 1:
		failures.append("C0/S9: charger DeckEntry wrapper count is %d, expected 1" % charger_wrapped)


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


# --- C2. Connectivity through WearDecay ------------------------------------------

func _check_connectivity(profile: BandProfile, failures: Array[String]) -> void:
	var conn := ConnectivityGuarantee.new()
	for seed in SEEDS:
		var band := BandPipeline.new().generate(profile, seed)
		if band == null:
			failures.append("C2 seed %d: null band" % seed)
			continue
		if not conn.is_fully_connected(band):
			failures.append("C2 seed %d: WearDecay stranded floor cells (connectivity lost)" % seed)
		# No DepthGrader unreachable sentinel; extraction anchor reachable.
		if band.deepest_piece != null and band.deepest_piece.depth_index >= band.pieces.size():
			failures.append("C2 seed %d: deepest_piece (extraction anchor) unreachable" % seed)
		_free_band(band)


# --- C3. Soft floor --------------------------------------------------------------

func _check_soft_floor(profile: BandProfile, failures: Array[String]) -> void:
	var cfg := profile.backend_config as BandGenConfig
	var floor_pieces: int = int(ceil(float(cfg.target_piece_count)
			* float(cfg.soft_floor_percent) / 100.0))
	for seed in SEEDS:
		var band := BandPipeline.new().generate(profile, seed)
		if band == null:
			failures.append("C3 seed %d: null band" % seed)
			continue
		if band.pieces.size() < floor_pieces:
			failures.append("C3 seed %d: band has %d pieces < soft floor %d"
					% [seed, band.pieces.size(), floor_pieces])
		_free_band(band)


# --- C4. Set-piece deep + non-vacuous --------------------------------------------
# Isolate band_two's AUTHORED SetPieceInject config: compare a control (band_two
# minus flavors) against an inject-only variant (band_two with only flavors[0]).
# The strict-prefix + deep-host + room_xl-suffix checks then prove the authored
# vault lands deep. (The full [inject, decay] path's connectivity is C2.)

func _check_set_piece(profile: BandProfile, failures: Array[String]) -> void:
	var empty: Array[Resource] = []
	var inject_only: Array[Resource] = [profile.flavors[0]]
	var control_profile := _clone_profile(profile, empty)
	var inject_profile := _clone_profile(profile, inject_only)

	var total_injected := 0
	for seed in SEEDS:
		var control := BandPipeline.new().generate(control_profile, seed)
		var a := BandPipeline.new().generate(inject_profile, seed)
		if control == null or a == null:
			failures.append("C4 seed %d: null band" % seed)
			_free_band(control); _free_band(a)
			continue

		# Strict prefix: control layout is a prefix of the injected one.
		if a.pieces.size() < control.pieces.size():
			failures.append("C4 seed %d: injected band SHORTER than control" % seed)
		else:
			for i in control.pieces.size():
				var cp := control.pieces[i]
				var fp := a.pieces[i]
				if cp.piece_id != fp.piece_id or cp.offset_cell != fp.offset_cell \
						or cp.mated_socket_index != fp.mated_socket_index:
					failures.append("C4 seed %d: control not a strict prefix at piece %d" % [seed, i])
					break

		var injected := a.pieces.size() - control.pieces.size()
		if injected > 1:
			failures.append("C4 seed %d: %d pieces injected > max_total 1" % [seed, injected])
		if injected > 0:
			total_injected += injected
			# Injected suffix is the authored vault piece.
			for i in range(control.pieces.size(), a.pieces.size()):
				if a.pieces[i].piece_id != VAULT_PIECE_ID:
					failures.append("C4 seed %d: injected piece id '%s' != '%s'"
							% [seed, a.pieces[i].piece_id, VAULT_PIECE_ID])
			# Host depth gate: a prefix piece adjacent to the vault satisfied
			# min_depth_norm 0.6 against the provisional (control-shaped) grade.
			if control.max_depth > 0:
				for i in range(control.pieces.size(), a.pieces.size()):
					if not _has_deep_adjacent_host(a, i, control.pieces.size(),
							control.max_depth, 0.6):
						failures.append("C4 seed %d: vault attached to a host below depth_norm 0.6" % seed)
			# Injection never disconnects.
			if not ConnectivityGuarantee.new().is_fully_connected(a):
				failures.append("C4 seed %d: injected band NOT fully connected" % seed)

		_free_band(control)
		_free_band(a)

	if total_injected <= 0:
		failures.append("C4: band_two's SetPieceInject config never injected across the matrix "
				+ "(min_depth_norm 0.6 may be unreachable for this band shape — vacuous proof)")


# --- C5. Control (band_greybox) untouched ----------------------------------------

func _check_control_untouched(failures: Array[String]) -> void:
	var greybox := load(GREYBOX_PATH) as BandProfile
	if greybox == null:
		failures.append("C5: could not load band_greybox.tres")
		return
	var gen := BandGenerator.new()
	var cfg := load(GREYBOX_CONFIG_PATH) as BandGenConfig
	var catalog: Array[ZonePieceData] = (load(GREYBOX_CATALOG_PATH) as PieceCatalog).pieces
	for seed in SEEDS:
		var direct := gen.generate(seed, cfg, catalog)
		var piped := BandPipeline.new().generate(greybox, seed)
		if direct == null or piped == null:
			failures.append("C5 seed %d: null band" % seed)
		elif direct.fingerprint() != piped.fingerprint():
			failures.append("C5 seed %d: band_greybox pipeline fp != direct fp (%s vs %s)"
					% [seed, piped.fingerprint().substr(0, 12), direct.fingerprint().substr(0, 12)])
		_free_band(direct)
		_free_band(piped)


# --- C6. Deck gating (static contract) -------------------------------------------

func _check_deck_gating(profile: BandProfile, failures: Array[String]) -> void:
	# Instability normalization (breakdown amendment 7): band 1 = 1.0, band 2 = 1.15.
	if not is_equal_approx(EncounterBuilder.instability(1), 1.0):
		failures.append("C6: instability(1) is %f, expected 1.0" % EncounterBuilder.instability(1))
	if not is_equal_approx(EncounterBuilder.instability(2), 1.15):
		failures.append("C6: instability(2) is %f, expected 1.15" % EncounterBuilder.instability(2))
	# Every authored deck def passes the min_band gate at band_depth 2 (S9: rows
	# may be DeckEntry wrappers — the gate reads the UNWRAPPED def, so unwrap here).
	for r in profile.opposition_deck:
		var def := _deck_def(r)
		if def == null:
			continue
		if not (profile.band_depth >= def.min_band):
			failures.append("C6: deck def '%s' (min_band %d) filtered out at band_depth 2"
					% [def.id, def.min_band])


# --- Helpers ---------------------------------------------------------------------

## Unwrap one opposition_deck row to its def: a plain OppositionDef passes
## through; an S9 DeckEntry yields its wrapped def; anything else -> null.
func _deck_def(r: Resource) -> OppositionDef:
	if r is DeckEntry:
		return (r as DeckEntry).def as OppositionDef
	return r as OppositionDef

## A band_two-shaped profile with a chosen flavors list (for C4 isolation).
func _clone_profile(base: BandProfile, flavors: Array[Resource]) -> BandProfile:
	var p := BandProfile.new()
	p.id = &"band_two_test_clone"
	p.backend = base.backend
	p.backend_config = base.backend_config
	p.archetype = base.archetype
	p.piece_pool = base.piece_pool
	p.flavors = flavors
	p.band_depth = base.band_depth
	return p


## True when some ORIGINAL (prefix) piece 4-adjacent (floor-floor) to injected
## piece `idx` passed the provisional depth gate (mirrors test_band_flavors).
func _has_deep_adjacent_host(band: Band, idx: int, prefix_n: int,
		control_max_depth: int, gate: float) -> bool:
	var cell_owner := {}
	for i in prefix_n:
		for c in band.pieces[i].floor_cells:
			cell_owner[c] = i
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for c in band.pieces[idx].floor_cells:
		for step in steps:
			var n: Vector2i = c + step
			if cell_owner.has(n):
				var host: int = cell_owner[n]
				var norm := float(band.pieces[host].depth_index) / float(control_max_depth)
				if norm >= gate - 0.0001:
					return true
	return false


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
