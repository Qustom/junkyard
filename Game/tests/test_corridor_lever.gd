extends Node
## Headless acceptance test for J4 (M1.3) — corridor-rarity generator lever + corridor-time
## telemetry seam.
##
## Run as a SCENE (autoloads + a live tree) so the RNG autoload + MainGame's script resolve
## exactly as in the real game:
##   godot --headless res://tests/test_corridor_lever.tscn
##
## J4 ships (A) a GENERATOR DOWN-WEIGHT/DROP corridor lever (Director Disposition: NOT a
## materialise re-pack) and (B) a per-frame corridor-time telemetry accumulator. This test
## drives the unit-testable cores directly:
##
##   (a) NEUTRAL default → fingerprint() byte-identical to the locked M1.2 baseline (e943ac9c8bc1).
##       The all-off / neutral corridor lever (mult 1.0, short false) MUST leave the weight table
##       untouched, so the all-off control fp is unchanged.
##   (b) NON-NEUTRAL lever (lvl_corridor_weight_mult < 1.0 and/or lvl_short_corridors) MOVES the
##       band for a fixed seed (proving the lever bites) while staying DETERMINISTIC (same
##       seed+config → same fp). Allowed under the (seed+config) contract, like R4 branching.
##   (c) lvl_short_corridors genuinely DROPS the 16-cell long hall (piece_corridor_long_h never
##       appears in the band) — the weight-zero path makes it unpickable.
##   (d) the corridor-time accumulator (_accumulate_piece_time) attributes delta to the right
##       bucket given a _piece_kind_by_index, and the _player_piece_index < 0 guard banks neither.
##   (e) _update_player_piece runs with R4 OFF (the mandatory hoist) — it updates the piece index
##       off _cell_to_junction[cell].x regardless of the run config / R4 gate.
##   (f) the corridor classification keys on piece_id via RunConfig.CORRIDOR_PIECE_IDS, with NO
##       aspect-ratio fallback — the 6×6 L-bend (piece_corridor_l) classifies as a CORRIDOR.

const MAIN_GAME_SCRIPT := "res://scenes/game/main_game.gd"
const BANDGEN_CONFIG_PATH := "res://data/bandgen_config.tres"
const PIECE_CATALOG_PATH := "res://data/piece_catalog.tres"
const PIECE_CATALOG_EXT_PATH := "res://data/piece_catalog_ext.tres"

## The locked M1.0/M1.1/M1.2 all-off baseline fingerprint (sample seed 12345).
const BASELINE_FP := "e943ac9c8bc1"
const BASELINE_FP_SEED := 12345


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []

	var cfg := load(BANDGEN_CONFIG_PATH) as BandGenConfig
	var pc = load(PIECE_CATALOG_PATH)
	var pce = load(PIECE_CATALOG_EXT_PATH)
	if cfg == null or pc == null or pce == null:
		printerr("J4 FAIL: missing bandgen config / catalogs")
		return 1
	var baseline_catalog: Array[ZonePieceData] = pc.pieces
	var ext_catalog: Array[ZonePieceData] = pce.pieces

	# --- (a) NEUTRAL lever → fp byte-identical to the locked baseline --------------
	# rc == null is the literal baseline; a neutral RunConfig (mult 1.0, short false) must match.
	var fp_null := BandGenerator.new().generate(BASELINE_FP_SEED, cfg, baseline_catalog).fingerprint().substr(0, 12)
	if fp_null != BASELINE_FP:
		failures.append("(a) rc=null baseline fp=%s != locked %s" % [fp_null, BASELINE_FP])
	var neutral := RunConfig.new()   # all-off: lvl_corridor_weight_mult 1.0, lvl_short_corridors false
	var fp_neutral := BandGenerator.new().generate(BASELINE_FP_SEED, cfg, baseline_catalog, neutral).fingerprint().substr(0, 12)
	if fp_neutral != BASELINE_FP:
		failures.append("(a) neutral RunConfig fp=%s != locked %s — corridor lever moved the all-off control!" % [fp_neutral, BASELINE_FP])

	# --- (b) NON-NEUTRAL lever MOVES the band (fixed seed) yet stays deterministic --
	# Use the EXT catalog (it holds the long hall + the full corridor family the preset sweeps).
	var ext_seed := 777
	var fp_ext_neutral := _fp(cfg, ext_catalog, _rc(1.0, false), ext_seed)
	# Weight-mult lever: corridors at 0.25× → a different weighted-pick sequence → a different band.
	var fp_mult := _fp(cfg, ext_catalog, _rc(0.25, false), ext_seed)
	if fp_mult == fp_ext_neutral:
		failures.append("(b) lvl_corridor_weight_mult=0.25 did NOT change the band (lever inert)")
	# Determinism: same seed+config → identical fp across calls.
	var fp_mult_again := _fp(cfg, ext_catalog, _rc(0.25, false), ext_seed)
	if fp_mult != fp_mult_again:
		failures.append("(b) lvl_corridor_weight_mult=0.25 not deterministic (%s vs %s)" % [fp_mult, fp_mult_again])
	# Short-corridors bool lever: dropping the long hall also moves the band.
	var fp_short := _fp(cfg, ext_catalog, _rc(1.0, true), ext_seed)
	if fp_short == fp_ext_neutral:
		failures.append("(b) lvl_short_corridors=true did NOT change the band (lever inert)")
	var fp_short_again := _fp(cfg, ext_catalog, _rc(1.0, true), ext_seed)
	if fp_short != fp_short_again:
		failures.append("(b) lvl_short_corridors=true not deterministic (%s vs %s)" % [fp_short, fp_short_again])

	# --- (c) lvl_short_corridors genuinely DROPS the 16-cell long hall -------------
	# Across several seeds, a short-corridors band must NEVER contain piece_corridor_long_h, while a
	# neutral band on the same ext catalog CAN (sanity: it appears at least once).
	var long_id := RunConfig.CORRIDOR_LONG_PIECE_ID
	var long_seen_neutral := false
	var long_seen_short := false
	for s in [1, 7, 13, 42, 99, 100, 500, 12345]:
		var b_neu := BandGenerator.new().generate(s, cfg, ext_catalog, _rc(1.0, false))
		var b_sho := BandGenerator.new().generate(s, cfg, ext_catalog, _rc(1.0, true))
		for p in b_neu.pieces:
			if p.piece_id == long_id:
				long_seen_neutral = true
		for p in b_sho.pieces:
			if p.piece_id == long_id:
				long_seen_short = true
		_free_band(b_neu)
		_free_band(b_sho)
	if not long_seen_neutral:
		failures.append("(c) sanity: neutral band never placed the long hall across the seed set (test seeds too narrow)")
	if long_seen_short:
		failures.append("(c) lvl_short_corridors=true placed piece_corridor_long_h — the drop did NOT make it unpickable")

	# --- MainGame telemetry-core drives (no tree needed for these helpers) ---------
	var mg_script := load(MAIN_GAME_SCRIPT) as GDScript
	var mg = mg_script.new()

	# --- (d) corridor-time accumulator attributes delta to the right bucket --------
	# Drive _accumulate_piece_time directly with a hand-built _piece_kind_by_index.
	mg._piece_kind_by_index = {0: true, 1: false}   # piece 0 = corridor, piece 1 = room
	mg._corridor_time_s = 0.0
	mg._room_time_s = 0.0
	mg._player_piece_index = -1
	mg._accumulate_piece_time(0.5)                  # not yet in a piece → neither bucket
	if not (is_equal_approx(mg._corridor_time_s, 0.0) and is_equal_approx(mg._room_time_s, 0.0)):
		failures.append("(d) _player_piece_index < 0 banked time (corridor=%f room=%f)" % [mg._corridor_time_s, mg._room_time_s])
	mg._player_piece_index = 0                      # in the corridor piece
	mg._accumulate_piece_time(0.5)
	mg._accumulate_piece_time(0.25)
	if not is_equal_approx(mg._corridor_time_s, 0.75):
		failures.append("(d) corridor bucket = %f, expected 0.75" % mg._corridor_time_s)
	mg._player_piece_index = 1                      # in the room piece
	mg._accumulate_piece_time(1.0)
	if not is_equal_approx(mg._room_time_s, 1.0):
		failures.append("(d) room bucket = %f, expected 1.0" % mg._room_time_s)
	if not is_equal_approx(mg._corridor_time_s, 0.75):
		failures.append("(d) corridor bucket drifted to %f after a room tick" % mg._corridor_time_s)
	# An index with no kind entry defaults to room (false) — never crashes.
	mg._player_piece_index = 9
	mg._accumulate_piece_time(0.5)
	if not is_equal_approx(mg._room_time_s, 1.5):
		failures.append("(d) unknown piece index did not default to the room bucket (%f)" % mg._room_time_s)

	# --- (e) _update_player_piece runs with R4 OFF (the hoist) ---------------------
	# GameState.active_run_config is null/all-off here (R4 off) — the piece index must STILL update.
	mg._cell_to_junction = {
		Vector2i(0, 0): Vector2i(0, 1),   # cell -> (piece_index 0, junction_degree 1)
		Vector2i(5, 0): Vector2i(2, 3),   # cell -> (piece_index 2, junction_degree 3)
	}
	mg._player_piece_index = -1
	var entered_a: bool = mg._update_player_piece(Vector2i(0, 0))
	if mg._player_piece_index != 0 or not entered_a:
		failures.append("(e) _update_player_piece did NOT set piece index with R4 off (idx=%d entered=%s)" % [mg._player_piece_index, str(entered_a)])
	var entered_same: bool = mg._update_player_piece(Vector2i(0, 0))
	if entered_same:
		failures.append("(e) _update_player_piece reported a NEW entry for the same piece")
	var entered_b: bool = mg._update_player_piece(Vector2i(5, 0))
	if mg._player_piece_index != 2 or not entered_b:
		failures.append("(e) _update_player_piece did NOT cross into piece 2 (idx=%d entered=%s)" % [mg._player_piece_index, str(entered_b)])
	# An off-floor cell (not in _cell_to_junction) keeps the last piece, returns false.
	var entered_void: bool = mg._update_player_piece(Vector2i(99, 99))
	if entered_void or mg._player_piece_index != 2:
		failures.append("(e) off-floor cell reset the piece index (idx=%d entered=%s)" % [mg._player_piece_index, str(entered_void)])

	# --- (f) classification keys on piece_id; the L-bend is a CORRIDOR -------------
	if not RunConfig.CORRIDOR_PIECE_IDS.has(&"piece_corridor_l"):
		failures.append("(f) piece_corridor_l (the 6×6 L-bend) is NOT in CORRIDOR_PIECE_IDS — it would mis-classify as a room")
	for cid in [&"piece_corridor_h", &"piece_corridor_v", &"piece_corridor_l", &"piece_corridor_long_h", &"piece_hall_v"]:
		if not RunConfig.CORRIDOR_PIECE_IDS.has(cid):
			failures.append("(f) corridor id %s missing from CORRIDOR_PIECE_IDS" % String(cid))
	for rid in [&"piece_box_small", &"piece_box_large", &"piece_room_hub", &"piece_room_xl", &"piece_chamber"]:
		if RunConfig.CORRIDOR_PIECE_IDS.has(rid):
			failures.append("(f) room id %s wrongly classified as a corridor" % String(rid))

	mg.free()

	if failures.is_empty():
		print("J4 OK — corridor-rarity lever + corridor-time seam verified: neutral default fp byte-matches "
			+ "the locked baseline (%s); lvl_corridor_weight_mult / lvl_short_corridors MOVE the band for " % BASELINE_FP
			+ "a fixed seed yet stay deterministic; short_corridors genuinely drops the 16-cell long hall; "
			+ "the per-frame accumulator banks corridor/room time by piece kind (guarding index < 0); "
			+ "_update_player_piece runs with R4 OFF (the hoist); and the L-bend classifies as a corridor "
			+ "(piece_id set, no aspect-ratio fallback).")
		return 0
	for f in failures:
		printerr("J4 FAIL: ", f)
	return 1


## A RunConfig with ONLY the J4 corridor knobs set (everything else all-off / neutral).
func _rc(weight_mult: float, short_corridors: bool) -> RunConfig:
	var rc := RunConfig.new()
	rc.lvl_corridor_weight_mult = weight_mult
	rc.lvl_short_corridors = short_corridors
	return rc


## Generate + fingerprint (12-char) for (cfg, catalog, rc, seed), freeing the throwaway band.
func _fp(cfg: BandGenConfig, catalog: Array[ZonePieceData], rc: RunConfig, seed: int) -> String:
	var band := BandGenerator.new().generate(seed, cfg, catalog, rc)
	var fp := band.fingerprint().substr(0, 12)
	_free_band(band)
	return fp


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
