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

	if failures.is_empty():
		var sample := gen.generate(12345, cfg, catalog)
		print("BANDGEN OK — determinism + connectivity verified across %d seeds (sample seed 12345 -> %d pieces, fp=%s)"
			% [SEEDS.size(), sample.pieces.size(), sample.fingerprint().substr(0, 12)])
		_free_band(sample)
		print("BUG3 SOCKET SEAL OK")
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


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
