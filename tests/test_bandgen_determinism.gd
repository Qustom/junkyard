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

	if failures.is_empty():
		var sample := gen.generate(12345, cfg, catalog)
		print("BANDGEN OK — determinism + connectivity verified across %d seeds (sample seed 12345 -> %d pieces, fp=%s)"
			% [SEEDS.size(), sample.pieces.size(), sample.fingerprint().substr(0, 12)])
		_free_band(sample)
		return 0
	for f in failures:
		printerr("BANDGEN FAIL: ", f)
	return 1


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
