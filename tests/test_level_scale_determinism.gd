extends Node
## Headless acceptance test for I1 (M1.2) — configurable level scale.
##
## Run as a SCENE (not --script) so the EventBus / RNG autoloads the generator
## emits through resolve at compile time, exactly as in the real game:
##   godot --headless res://tests/test_level_scale_determinism.tscn
##
## COLLISION GUARD: this is a NEW file. BUG4 owns test_bandgen_determinism.gd this
## wave — I1's new assertions live here so the two parallel tasks never touch the
## same file.
##
## Asserts (per the I1 spec Director-LOCKED scope + Resolved Decisions):
##   (a) ALL-OFF CONTROL: an all-off RunConfig (lvl_enabled=false, count=-1, mult=1.0)
##       AND rc==null both byte-match the M1.1 baseline fingerprint() on the BASELINE
##       catalog — the permanent control is unchanged by adding the lvl_ knobs.
##   (b) COUNT STABILITY: a pinned lvl_room_count gives a run-to-run stable fingerprint
##       (seed + config), and actually grows toward the requested count.
##   (c) SIZE IS LAYOUT-INVARIANT: lvl_size_mult does NOT change fingerprint() — size is
##       pure pixel presentation applied after generation (same layout, different zoom).
##   (d) PER-CATALOG STABILITY: each catalog (baseline / extended) fingerprints stably
##       run-to-run, stays connected, and seals clean (the new larger pieces stitch).
##   (e) NO BASELINE DRIFT FROM THE EXT CATALOG: the extended catalog is a SUPERSET that
##       only matters when lvl is on; the baseline catalog + all-off is byte-identical to
##       a band generated with the same (baseline catalog, no rc) — i.e. adding the ext
##       catalog file moves nothing for the control.

const CATALOG_PATH := "res://data/piece_catalog.tres"
const CATALOG_EXT_PATH := "res://data/piece_catalog_ext.tres"
const CONFIG_PATH := "res://data/bandgen_config.tres"

const SEEDS := [12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]

const DEFAULT_CELL_SIZE_PX := 16


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	var catalog_res = load(CATALOG_PATH)
	var catalog_ext_res = load(CATALOG_EXT_PATH)
	var cfg = load(CONFIG_PATH)
	if catalog_res == null or cfg == null:
		printerr("LVL FAIL: missing baseline catalog or config")
		return 1
	if catalog_ext_res == null:
		printerr("LVL FAIL: missing extended catalog at ", CATALOG_EXT_PATH)
		return 1
	var catalog: Array[ZonePieceData] = catalog_res.pieces
	var catalog_ext: Array[ZonePieceData] = catalog_ext_res.pieces

	var gen := BandGenerator.new()
	var sealer := SocketSealer.new()

	# --- (a) ALL-OFF CONTROL: lvl knobs off byte-matches the no-config baseline ----
	var all_off := RunConfig.new()   # lvl_enabled=false, lvl_room_count=-1, lvl_size_mult=1.0
	if all_off.lvl_enabled or all_off.lvl_room_count != -1 or not is_equal_approx(all_off.lvl_size_mult, 1.0):
		failures.append("all-off RunConfig defaults are not the baseline (lvl_enabled=%s count=%d mult=%s)"
			% [all_off.lvl_enabled, all_off.lvl_room_count, all_off.lvl_size_mult])
	for seed in SEEDS:
		var baseline := gen.generate(seed, cfg, catalog)          # rc == null (M1.1 path)
		var off := gen.generate(seed, cfg, catalog, all_off)      # explicit all-off
		if baseline.fingerprint() != off.fingerprint():
			failures.append("(a) seed %d: all-off lvl config did NOT byte-match the M1.1 baseline (%s vs %s)"
				% [seed, baseline.fingerprint().substr(0, 12), off.fingerprint().substr(0, 12)])
		_free_band(baseline)
		_free_band(off)

	# --- (b) COUNT STABILITY + takes effect ----------------------------------------
	var count_cfg := RunConfig.new()
	count_cfg.lvl_enabled = true
	count_cfg.lvl_room_count = 20
	for seed in SEEDS:
		var a := gen.generate(seed, cfg, catalog, count_cfg)
		var b := gen.generate(seed, cfg, catalog, count_cfg)
		if a.fingerprint() != b.fingerprint():
			failures.append("(b) seed %d: pinned count NOT deterministic (%s vs %s)"
				% [seed, a.fingerprint().substr(0, 12), b.fingerprint().substr(0, 12)])
		_free_band(a)
		_free_band(b)
	# The override should grow MORE than the baseline 12 on at least one seed (a higher
	# count yields a longer spine where geometry allows it).
	var grew := false
	for seed in SEEDS:
		var base_b := gen.generate(seed, cfg, catalog)
		var more_b := gen.generate(seed, cfg, catalog, count_cfg)
		if more_b.pieces.size() > base_b.pieces.size():
			grew = true
		_free_band(base_b)
		_free_band(more_b)
	if not grew:
		failures.append("(b) count override never grew the band beyond baseline on any seed")

	# --- (b') COUNT PREFIX INVARIANCE: a longer count is a prefix-superset of baseline.
	# The first N pieces of a count-20 band match the count-12 band on the same seed
	# (the extra pieces are appended; the RNG sequence prefix is identical). We assert
	# the count-12-equivalent override reproduces the baseline exactly.
	var count12 := RunConfig.new()
	count12.lvl_enabled = true
	count12.lvl_room_count = int(cfg.target_piece_count)
	for seed in SEEDS:
		var base_b := gen.generate(seed, cfg, catalog)               # rc null, target 12
		var pin12 := gen.generate(seed, cfg, catalog, count12)       # explicit 12
		if base_b.fingerprint() != pin12.fingerprint():
			failures.append("(b') seed %d: count override == baseline (12) did NOT byte-match (%s vs %s)"
				% [seed, base_b.fingerprint().substr(0, 12), pin12.fingerprint().substr(0, 12)])
		_free_band(base_b)
		_free_band(pin12)

	# --- (c) SIZE IS LAYOUT-INVARIANT: mult never changes fingerprint() -------------
	for mult in [1.0, 1.5, 2.0, 3.0]:
		var size_cfg := RunConfig.new()
		size_cfg.lvl_enabled = true
		size_cfg.lvl_size_mult = mult
		for seed in SEEDS:
			var base_b := gen.generate(seed, cfg, catalog)            # rc null
			var sized := gen.generate(seed, cfg, catalog, size_cfg)   # only size differs
			if base_b.fingerprint() != sized.fingerprint():
				failures.append("(c) seed %d mult %s: size multiplier CHANGED fingerprint (must be layout-invariant): %s vs %s"
					% [seed, mult, base_b.fingerprint().substr(0, 12), sized.fingerprint().substr(0, 12)])
			# Also assert the effective px-per-cell is an exact integer multiple of 16.
			var eff := size_cfg.effective_cell_size_px(DEFAULT_CELL_SIZE_PX)
			if eff != int(round(DEFAULT_CELL_SIZE_PX * mult)) or eff <= 0:
				failures.append("(c) mult %s: effective_cell_size_px not integer-exact (%d)" % [mult, eff])
			_free_band(base_b)
			_free_band(sized)

	# --- (d) PER-CATALOG STABILITY + connectivity + seal (baseline & extended) ------
	var lvl_on := RunConfig.new()
	lvl_on.lvl_enabled = true
	lvl_on.lvl_room_count = 16
	for pair in [["baseline", catalog, RunConfig.new()], ["extended", catalog_ext, lvl_on]]:
		var label: String = pair[0]
		var cat: Array[ZonePieceData] = pair[1]
		var rc: RunConfig = pair[2]
		var distinct := {}
		for seed in SEEDS:
			var a := gen.generate(seed, cfg, cat, rc)
			var b := gen.generate(seed, cfg, cat, rc)
			if a == null or b == null:
				failures.append("(d) %s seed %d: null band" % [label, seed])
				continue
			if a.fingerprint() != b.fingerprint():
				failures.append("(d) %s seed %d: NOT deterministic (%s vs %s)"
					% [label, seed, a.fingerprint().substr(0, 12), b.fingerprint().substr(0, 12)])
			if not gen.is_band_connected(a):
				failures.append("(d) %s seed %d: band DISCONNECTED (%d pieces)" % [label, seed, a.pieces.size()])
			sealer.seal_unused_sockets(a, DEFAULT_CELL_SIZE_PX)
			var leaks := _count_floor_facing_void(a)
			if leaks > 0:
				failures.append("(d) %s seed %d: %d floor cell(s) face off-map void after sealing" % [label, seed, leaks])
			distinct[b.fingerprint()] = true
			_free_band(a)
			_free_band(b)
		if distinct.size() < 2:
			failures.append("(d) %s: all seeds yielded the SAME layout (no variation)" % label)

	# --- (e) EXT CATALOG IS A SUPERSET: its first 6 ids == the baseline catalog ids,
	# so a lvl-off run on the ext catalog grows the same prefix where geometry allows.
	# (The real loop never feeds the ext catalog when lvl is off; this just documents the
	# superset contract that keeps the ext catalog a strict extension.)
	if catalog_ext.size() <= catalog.size():
		failures.append("(e) extended catalog is not larger than baseline (%d <= %d)"
			% [catalog_ext.size(), catalog.size()])
	else:
		for i in catalog.size():
			if catalog_ext[i].piece_id != catalog[i].piece_id:
				failures.append("(e) ext catalog index %d id %s != baseline %s (ordering broken)"
					% [i, catalog_ext[i].piece_id, catalog[i].piece_id])

	if failures.is_empty():
		var sample := gen.generate(12345, cfg, catalog_ext, lvl_on)
		print("LVL OK — count + size + per-catalog determinism verified across %d seeds (ext sample seed 12345 -> %d pieces, fp=%s)"
			% [SEEDS.size(), sample.pieces.size(), sample.fingerprint().substr(0, 12)])
		_free_band(sample)
		return 0
	for f in failures:
		printerr("LVL FAIL: ", f)
	return 1


## Count band-global FLOOR cells (read from each LIVE Geometry layer) with a 4-neighbour
## that is neither FLOOR nor WALL — an opening onto untiled off-map void. Mirrors the
## bandgen test's invariant. The seal pass should drive this to 0.
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
