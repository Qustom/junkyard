extends Node
## S8 acceptance — hub→dive band routing + telemetry band-stamp (M1.9 Wave 5, spec §5.2).
##
## Run as a SCENE (not --script) so the EventBus / GameState autoloads resolve:
##   godot --headless --path Game res://tests/test_band_routing.tscn
##
## The routing contract under test (S8 §RD Q1/Q2 — reuse dive_requested, no new
## signal): a portal emits dive_requested(route_key) → GameState self-subscribes and
## stages it (_pending_dive_band, consume-on-read) → main_game._resolve_band_profile()
## consumes the key, maps it through BAND_ROUTES (&"near" → band_greybox, &"band_two"
## → band_two; unknown/empty → the greybox control) and tags start_run/enter_band
## with the ROUTE key, which telemetry stamps verbatim on the run_started row.
##
##   C1. staging: dive_requested(&"band_two") stages; consume returns it ONCE
##       (a second consume returns &"" — a stale choice cannot leak)
##   C2. default: nothing staged -> _resolve_band_profile() == band_greybox,
##       route key &"near" (byte-for-byte the historical start_run tag)
##   C3. unknown key: &"band_bogus" staged -> greybox control (fail-safe)
##   C4. routing lands: &"band_two" staged -> the band_two profile; its pipeline
##       fingerprint is deterministic (same seed twice) AND != greybox's same-seed fp
##   C5. stamp (full assembled scene): drive main_game.tscn — a portal-2-style
##       emission yields run_started band_id &"band_two"; an unstaged restart yields
##       &"near". (Telemetry mirrors the signal arg verbatim, telemetry.gd:149 —
##       asserting the signal asserts the JSONL row's source.)
##   C6. wipe isolation: a staged key survives GameState.wipe_meta() (wipe is
##       meta-only; the staging slot is neither run-state nor meta)

const MAIN_GAME_PATH := "res://scenes/game/main_game.tscn"
const GREYBOX_PATH := "res://data/bands/band_greybox.tres"
const BAND_TWO_PATH := "res://data/bands/band_two.tres"
const SEED := 12345

var _failures: Array[String] = []
var _run_started_band_ids: Array[StringName] = []


func _ready() -> void:
	get_tree().quit(await _run())


func _run() -> int:
	_check_staging()          # C1
	_check_default()          # C2
	_check_unknown_key()      # C3
	_check_routing_lands()    # C4
	await _check_stamp()      # C5 (full scene — async)
	_check_wipe_isolation()   # C6

	if _failures.is_empty():
		print("BAND_ROUTING OK — staging consume-on-read, &\"near\"/unknown -> greybox ",
				"control, &\"band_two\" -> The Sump (deterministic, distinct fp), ",
				"run_started band_id == the route key for both routes, wipe-isolated")
		return 0
	for f in _failures:
		printerr("BAND_ROUTING FAIL: ", f)
	return 1


# --- C1. Staging + consume-on-read --------------------------------------------------

func _check_staging() -> void:
	EventBus.dive_requested.emit(&"band_two")
	var first: StringName = GameState.consume_pending_dive_band()
	if first != &"band_two":
		_failures.append("C1: consume after dive_requested(&\"band_two\") returned '%s'" % first)
	var second: StringName = GameState.consume_pending_dive_band()
	if second != &"":
		_failures.append("C1: SECOND consume returned '%s', expected &\"\" (stale leak)" % second)


# --- C2. Default (nothing staged) -> greybox control ---------------------------------

func _check_default() -> void:
	GameState.consume_pending_dive_band()   # ensure the slot is clean
	var mg := MainGame.new()
	var profile: BandProfile = mg._resolve_band_profile()
	if profile == null or profile.id != &"band_greybox":
		_failures.append("C2: unstaged resolve returned '%s', expected band_greybox"
				% (profile.id if profile != null else &"<null>"))
	if mg._band_route_key != &"near":
		_failures.append("C2: unstaged route key is '%s', expected &\"near\"" % mg._band_route_key)
	mg.free()


# --- C3. Unknown key -> greybox control (fail-safe) ----------------------------------

func _check_unknown_key() -> void:
	EventBus.dive_requested.emit(&"band_bogus")
	var mg := MainGame.new()
	var profile: BandProfile = mg._resolve_band_profile()
	if profile == null or profile.id != &"band_greybox":
		_failures.append("C3: unknown-key resolve returned '%s', expected band_greybox"
				% (profile.id if profile != null else &"<null>"))
	if mg._band_route_key != &"near":
		_failures.append("C3: unknown-key route key is '%s', expected &\"near\"" % mg._band_route_key)
	mg.free()


# --- C4. Routing lands in band_two, deterministically --------------------------------

func _check_routing_lands() -> void:
	EventBus.dive_requested.emit(&"band_two")
	var mg := MainGame.new()
	var profile: BandProfile = mg._resolve_band_profile()
	if profile == null or profile.id != &"band_two":
		_failures.append("C4: staged &\"band_two\" resolved '%s', expected band_two"
				% (profile.id if profile != null else &"<null>"))
		mg.free()
		return
	if mg._band_route_key != &"band_two":
		_failures.append("C4: route key is '%s', expected &\"band_two\"" % mg._band_route_key)
	mg.free()

	# The resolved profile generates deterministically and is a DIFFERENT band than
	# the control for the same seed (the "new band is reachable as content" proof).
	var a := BandPipeline.new().generate(profile, SEED)
	var b := BandPipeline.new().generate(profile, SEED)
	var greybox := load(GREYBOX_PATH) as BandProfile
	var g := BandPipeline.new().generate(greybox, SEED)
	if a == null or b == null or g == null:
		_failures.append("C4: null band from the pipeline (band_two or greybox)")
	else:
		if a.fingerprint() != b.fingerprint():
			_failures.append("C4: band_two fp NOT deterministic (%s vs %s)"
					% [a.fingerprint().substr(0, 12), b.fingerprint().substr(0, 12)])
		if a.fingerprint() == g.fingerprint():
			_failures.append("C4: band_two fp == band_greybox fp for seed %d (routes indistinct)"
					% SEED)
	_free_band(a)
	_free_band(b)
	_free_band(g)


# --- C5. Stamp: the assembled scene tags run_started with the route key --------------

func _check_stamp() -> void:
	EventBus.run_started.connect(_on_run_started)
	# All-off control config for both drives (light + deterministic; the routing
	# seam is config-independent).
	GameState.stage_dive_config(RunConfig.new())

	# Portal-2-style emission (the portal's exact call: dive_requested with its
	# exported band_id), then the router-equivalent scene entry: main_game self-starts.
	EventBus.dive_requested.emit(&"band_two")
	var scene := load(MAIN_GAME_PATH) as PackedScene
	if scene == null:
		_failures.append("C5: could not load %s" % MAIN_GAME_PATH)
		EventBus.run_started.disconnect(_on_run_started)
		GameState.stage_dive_config(null)
		return
	var game := scene.instantiate() as MainGame
	add_child(game)
	await get_tree().process_frame   # _ready -> start_new_run -> start_run/run_started

	if _run_started_band_ids.size() != 1 or _run_started_band_ids[0] != &"band_two":
		_failures.append("C5: portal-2 dive run_started band_id(s) %s, expected [&\"band_two\"]"
				% str(_run_started_band_ids))
	if game._band_profile == null or game._band_profile.id != &"band_two":
		_failures.append("C5: portal-2 dive generated profile '%s', expected band_two"
				% (game._band_profile.id if game._band_profile != null else &"<null>"))

	# End the run, then an UNSTAGED restart (direct start_new_run — the test/menu
	# path) must fall back to the control band and tag &"near".
	GameState.extract_and_end_run()
	await get_tree().process_frame
	_run_started_band_ids.clear()
	game.start_new_run()
	await get_tree().process_frame
	if _run_started_band_ids.size() != 1 or _run_started_band_ids[0] != &"near":
		_failures.append("C5: unstaged dive run_started band_id(s) %s, expected [&\"near\"]"
				% str(_run_started_band_ids))
	if game._band_profile == null or game._band_profile.id != &"band_greybox":
		_failures.append("C5: unstaged dive generated profile '%s', expected band_greybox"
				% (game._band_profile.id if game._band_profile != null else &"<null>"))

	# Teardown: end the run and free the scene (leave GameState quiescent for C6).
	GameState.extract_and_end_run()
	await get_tree().process_frame
	EventBus.run_started.disconnect(_on_run_started)
	GameState.stage_dive_config(null)
	game.queue_free()
	await get_tree().process_frame


func _on_run_started(band_id: StringName, _seed: int) -> void:
	_run_started_band_ids.append(band_id)


# --- C6. Wipe isolation ---------------------------------------------------------------

func _check_wipe_isolation() -> void:
	EventBus.dive_requested.emit(&"band_two")
	GameState.wipe_meta()   # meta-only: must NOT touch the staging slot
	var key: StringName = GameState.consume_pending_dive_band()
	if key != &"band_two":
		_failures.append("C6: staged key after wipe_meta() is '%s', expected &\"band_two\"" % key)


# --- Helpers ---------------------------------------------------------------------------

func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
