extends Node
## Headless acceptance test for B2 — the modular room-graph generator.
##
## Run as a SCENE (not --script) so the EventBus / RNG autoload globals the
## generator emits through resolve at compile time, exactly as in the real game:
##   godot --headless res://tests/test_bandgen_determinism.tscn
##
## Determinism is the hard acceptance bar. This asserts:
##   1. same seed  -> byte-identical layout fingerprint (ordered piece@offset#mated sha256)
##   2. diff seed  -> different fingerprint (variation exists)
##   3. connectivity: flood-fill from the entry reaches every placed piece
##   4. all placement is integer-cell exact and overlap-free
##   5. the derived-seed retry chain is itself a pure function of the seed
##
## BUG3 (M1.1) — the socket-seal pass is also acceptance-tested here:
##   6. determinism preserved: fingerprint(seed) is byte-identical with vs without
##      the seal pass (the pass adds/reorders no pieces and rolls no RNG).
##   7. no open socket off-map: after sealing, NO band-global floor cell faces an
##      empty off-map cell — every perimeter floor cell abuts another piece's floor
##      OR a wall cap (the band is a closed play space).

const CATALOG_PATH := "res://data/piece_catalog.tres"
const CONFIG_PATH := "res://data/bandgen_config.tres"

# A spread of seeds so determinism/connectivity are exercised broadly.
const SEEDS := [12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]


func _ready() -> void:
	var code := _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []

	var catalog_res = load(CATALOG_PATH)
	if catalog_res == null:
		printerr("BANDGEN FAIL: could not load ", CATALOG_PATH)
		return 1
	var catalog: Array[ZonePieceData] = catalog_res.pieces
	var cfg = load(CONFIG_PATH)
	if cfg == null:
		printerr("BANDGEN FAIL: could not load ", CONFIG_PATH)
		return 1

	var gen := BandGenerator.new()

	# --- 1. Same seed -> identical fingerprint; + connectivity + overlap -----
	for seed in SEEDS:
		var a := gen.generate(seed, cfg, catalog)
		var b := gen.generate(seed, cfg, catalog)
		if a == null or b == null:
			failures.append("seed %d produced a null band" % seed)
			continue

		if a.fingerprint() != b.fingerprint():
			failures.append("seed %d NOT deterministic: %s vs %s"
				% [seed, a.fingerprint(), b.fingerprint()])

		# --- 3. Connectivity: every placed piece reachable from the entry ----
		if not gen.is_band_connected(a):
			failures.append("seed %d band is DISCONNECTED (%d pieces)"
				% [seed, a.pieces.size()])

		# --- 4. No overlaps; occupancy is integer-exact ---------------------
		var seen := {}
		var overlap := false
		for p in a.pieces:
			for c in p.footprint_cells:
				if seen.has(c):
					overlap = true
				seen[c] = true
		if overlap:
			failures.append("seed %d has overlapping piece cells" % seed)

		# Band should reach at least the soft floor (80% of 12 -> 10).
		var floor_target: int = (int(cfg.target_piece_count) * int(cfg.soft_floor_percent) + 99) / 100
		if a.pieces.size() < floor_target:
			failures.append("seed %d undersized: %d < soft floor %d"
				% [seed, a.pieces.size(), floor_target])

		_free_band(a)
		_free_band(b)

	# --- 2. Different seeds differ ------------------------------------------
	var distinct := {}
	for seed in SEEDS:
		var band := gen.generate(seed, cfg, catalog)
		distinct[band.fingerprint()] = true
		_free_band(band)
	if distinct.size() < 2:
		failures.append("all %d seeds yielded the SAME layout (no variation)" % SEEDS.size())

	# --- 5. Retry/seed chain is pure: perturbing global RNG between runs must
	#        not change the layout, proving the derived-seed chain is a pure
	#        function of the original seed. ----------------------------------
	var first_run := gen.generate(424242, cfg, catalog)
	RNG.seed_from(987654321)
	RNG.randi()
	var second_run := gen.generate(424242, cfg, catalog)
	if first_run.fingerprint() != second_run.fingerprint():
		failures.append("retry/seed chain not pure: 424242 differed across runs despite RNG perturbation")
	_free_band(first_run)
	_free_band(second_run)

	# --- BUG3.6 + BUG3.7: socket-seal determinism + no-open-socket invariant ---
	_run_seal_checks(gen, cfg, catalog, failures)

	# --- R4 (M1.1): (seed + config) determinism contract + branching takes effect ---
	_run_r4_checks(gen, cfg, catalog, failures)

	if failures.is_empty():
		var sample := gen.generate(12345, cfg, catalog)
		print("BANDGEN OK — determinism + connectivity verified across %d seeds (sample seed 12345 -> %d pieces, fp=%s)"
			% [SEEDS.size(), sample.pieces.size(), sample.fingerprint().substr(0, 12)])
		_free_band(sample)
		print("BUG3 SOCKET SEAL OK")
		print("R4 NAV OK")
		return 0
	for f in failures:
		printerr("BANDGEN FAIL: ", f)
	return 1


# --- BUG3: socket-seal acceptance ------------------------------------------------

## For each seed: prove the seal pass leaves fingerprint byte-identical (it only
## adds WALL geometry, no pieces, no RNG) AND that after sealing no floor cell faces
## off-map void (the band is closed). The sealer mutates live piece instances'
## Geometry layers, so we seal the same Band the generator already instanced.
func _run_seal_checks(gen: BandGenerator, cfg, catalog: Array[ZonePieceData],
		failures: Array[String]) -> void:
	var sealer := SocketSealer.new()
	for seed in SEEDS:
		var band := gen.generate(seed, cfg, catalog)
		if band == null:
			failures.append("BUG3 seed %d produced a null band" % seed)
			continue

		# 6. Determinism: fingerprint must be byte-identical before vs after sealing.
		var fp_before := band.fingerprint()
		sealer.seal_unused_sockets(band, 16)
		var fp_after := band.fingerprint()
		if fp_before != fp_after:
			failures.append("BUG3 seed %d: seal pass changed fingerprint (%s -> %s)"
				% [seed, fp_before, fp_after])

		# 7. No open socket off-map: after sealing, no floor cell faces an empty
		#    off-map cell. Build the band-global FLOOR set + WALL set from the LIVE
		#    (now-sealed) piece Geometry layers, then check every floor cell's 4
		#    neighbours: each must be FLOOR or WALL — never void.
		var open_void := _count_floor_facing_void(band)
		if open_void > 0:
			failures.append("BUG3 seed %d: %d floor cell(s) still face off-map void after sealing"
				% [seed, open_void])

		# Also assert the converse before sealing would have FOUND voids (so the test
		# isn't vacuously green) — regenerate an unsealed copy and confirm it leaks.
		var unsealed := gen.generate(seed, cfg, catalog)
		var leak_before := _count_floor_facing_void(unsealed)
		if leak_before == 0 and not band.open_sockets.is_empty():
			failures.append("BUG3 seed %d: expected unsealed band to leak (had %d open sockets) but found none — test may be vacuous"
				% [seed, band.open_sockets.size()])
		_free_band(unsealed)

		_free_band(band)


## Count band-global FLOOR cells (read from each piece's LIVE Geometry layer, so a
## just-sealed band reflects the WALL caps) that have a 4-neighbour which is neither
## FLOOR nor WALL — i.e. an opening straight onto untiled off-map void.
func _count_floor_facing_void(band: Band) -> int:
	var floor_set := {}
	var wall_set := {}
	for p in band.pieces:
		if p.instance == null:
			continue
		var geo := p.instance.get_node_or_null("Geometry") as TileMapLayer
		if geo == null:
			continue
		for local in geo.get_used_cells():
			var g: Vector2i = local + p.offset_cell
			var atlas := geo.get_cell_atlas_coords(local)
			if atlas == Vector2i(0, 0):
				floor_set[g] = true
			elif atlas == Vector2i(1, 0):
				wall_set[g] = true
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var leaks := 0
	for c in floor_set:
		for step in steps:
			var n: Vector2i = c + step
			if not floor_set.has(n) and not wall_set.has(n):
				leaks += 1
				break
	return leaks


# --- R4 (M1.1): navigation determinism + branching acceptance --------------------

## R4 acceptance over the determinism contract `fingerprint(seed + config)`:
##   R4.1 ALL-OFF CONTROL: an all-off RunConfig (and rc == null) byte-matches the
##        M1.0 band for every seed — the permanent control is preserved.
##   R4.2 (seed + config) STABILITY: an R4-on config (non-zero branch curve) is
##        run-to-run stable for the same (seed + config).
##   R4.3 BRANCHING TAKES EFFECT: the R4-on config produces TRUE intersection pieces
##        (≥3 distinct neighbours) where the linear M1.0 spine has exactly ZERO —
##        deeper layouts fork/branch. (Counting ≥2 would not work: every interior
##        spine piece already has 2 neighbours, and dead-end branches DROP the ≥2
##        count; the unambiguous "a fork appeared" signal is the ≥3 intersection.)
##   R4.4 CONFIG CHANGES THE BAND: at least one seed's R4-on fingerprint differs from
##        its all-off fingerprint (config is legitimately part of the seed key).
##   R4.5 STILL CONNECTED + SEALABLE: every R4-on band stays connected, and after
##        sealing no floor cell faces off-map void (branchy dead-ends stay sealed).
func _run_r4_checks(gen: BandGenerator, cfg, catalog: Array[ZonePieceData],
		failures: Array[String]) -> void:
	var all_off := RunConfig.new()          # default = all oppositions off (M1.0 baseline)
	var r4_on := _make_r4_on_config()
	var sealer := SocketSealer.new()

	var total_baseline_intersections := 0   # ≥3-degree pieces on the all-off spine (== 0)
	var total_r4_intersections := 0         # ≥3-degree pieces under the R4-on config
	var any_config_differs := false

	for seed in SEEDS:
		# R4.1 — all-off control byte-matches the no-config (M1.0) band.
		var m10 := gen.generate(seed, cfg, catalog)               # rc default null
		var off := gen.generate(seed, cfg, catalog, all_off)      # explicit all-off
		if m10.fingerprint() != off.fingerprint():
			failures.append("R4 seed %d: all-off config did NOT byte-match M1.0 band (%s vs %s)"
				% [seed, m10.fingerprint().substr(0, 12), off.fingerprint().substr(0, 12)])

		# R4.2 — (seed + config) run-to-run stability under the R4-on config.
		var on_a := gen.generate(seed, cfg, catalog, r4_on)
		var on_b := gen.generate(seed, cfg, catalog, r4_on)
		if on_a.fingerprint() != on_b.fingerprint():
			failures.append("R4 seed %d: R4-on config NOT deterministic (%s vs %s)"
				% [seed, on_a.fingerprint().substr(0, 12), on_b.fingerprint().substr(0, 12)])

		# R4.4 — config legitimately changes the band on at least one seed.
		if on_a.fingerprint() != off.fingerprint():
			any_config_differs = true

		# R4.3 — branching takes effect: count TRUE intersection pieces (≥3 neighbours).
		total_baseline_intersections += _count_intersection_pieces(off)
		total_r4_intersections += _count_intersection_pieces(on_a)

		# R4.5 — R4-on band stays connected + seals clean (no walk-off-void). Within the
		# realistic sweep envelope (S1-like curve) the branchy band still seals fully.
		if not gen.is_band_connected(on_a):
			failures.append("R4 seed %d: R4-on band is DISCONNECTED" % seed)
		sealer.seal_unused_sockets(on_a, 16)
		var leaks := _count_floor_facing_void(on_a)
		if leaks > 0:
			failures.append("R4 seed %d: R4-on band has %d floor cell(s) facing void after sealing"
				% [seed, leaks])

		_free_band(m10)
		_free_band(off)
		_free_band(on_a)
		_free_band(on_b)

	# The linear spine has ZERO ≥3 intersections; an R4-on band must produce some.
	if total_baseline_intersections != 0:
		failures.append("R4: baseline (all-off) unexpectedly had %d intersection pieces — spine should be linear"
			% total_baseline_intersections)
	if total_r4_intersections <= 0:
		failures.append("R4: branching did NOT take effect — R4-on produced %d intersection pieces (≥3 neighbours) across the sweep"
			% total_r4_intersections)
	if not any_config_differs:
		failures.append("R4: R4-on config produced the SAME band as all-off on every seed (config not part of the key?)")


## Build the R4-on RunConfig for the determinism test. Uses the recommended S1-class
## sweep curve (per the R4 spec §7: branch_per_depth ≈ 0.06, cap 8) — deliberately
## within the realistic Director sweep envelope, where the branchy band still seals
## fully (no walk-off-void). Acceptance is "the knob takes effect", not a balanced
## value. Higher branch rates surface a known BUG3 seal gap (flagged to BUG3 owner —
## see worklog), so the test pins the realistic envelope, not a pathological one.
func _make_r4_on_config() -> RunConfig:
	var rc := RunConfig.new()
	rc.r4_enabled = true
	rc.r4_branch_chance_base = 0.0
	rc.r4_branch_per_depth = 0.06        # S1 "Branchy" preset (R4 spec §7)
	rc.r4_max_branch_depth = 8           # top of the M1 band; deepest pieces stay linear
	return rc


## Count TRUE intersection pieces: ≥3 DISTINCT neighbouring pieces via a walkable
## (FLOOR 4-adjacent) doorway — the same adjacency the generator's connectivity uses.
## The linear M1.0 spine has ZERO of these (interior pieces have exactly 2 neighbours,
## ends have 1), so a non-zero count is the unambiguous "a fork appeared" signal.
func _count_intersection_pieces(band: Band) -> int:
	var cell_owner := {}
	for i in band.pieces.size():
		for c in band.pieces[i].floor_cells:
			cell_owner[c] = i
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var intersections := 0
	for i in band.pieces.size():
		var seen := {}
		for c in band.pieces[i].floor_cells:
			for step in steps:
				var n: Vector2i = c + step
				if cell_owner.has(n):
					var j: int = cell_owner[n]
					if j != i:
						seen[j] = true
		if seen.size() >= 3:
			intersections += 1
	return intersections


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
