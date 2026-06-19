class_name MainGame
extends Node2D
## MainGame (G3) — the assembled M1 playable loop. The first scene that wires the
## whole loop, built+tested in isolation through waves 1–4, into ONE thing a human
## can actually play end to end:
##
##   main menu → start run → spawn in a generated greybox band → pick up junk →
##   read the clock (push vs extract) → extract (bank) OR die/timeout (pockets) →
##   sell screen tallies junk → Money → repeat.
##
## ORCHESTRATION ONLY (run/meta boundary, signal-driven decoupling per TDD §2):
## this node owns no game-state truth. It assembles the world (band geometry +
## pickups + gate + player), drives the run lifecycle through GameState's locked
## API, and listens on EventBus to know when a run ended. The HUD, sell screen,
## dive clock, telemetry, and inventory are all independent EventBus consumers — we
## just put them in the tree together. The single new seam G3 owns is the
## `start_new_run()` loop entry, subscribed to SellScreen.continue_pressed (W4-11).
##
## Greybox norm: the band pieces, junk, gate and player are existing greybox scenes;
## the main menu is a minimal default-theme Control. No art is authored here.

const PIECE_CATALOG_PATH := "res://data/piece_catalog.tres"
const BANDGEN_CONFIG_PATH := "res://data/bandgen_config.tres"
const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"
const DEPTH_CURVE_PATH := "res://systems/depth/depth_curve.tres"
const GATE_SCENE_PATH := "res://entities/gate/extract_gate.tscn"
## M1.1 R0: the default (all-off) run config. CFG will later swap this for the
## menu-built config; for now we stage the all-off default so the wiring is
## exercised and the loop stays at the M1.0 baseline.
const RUN_CONFIG_PATH := "res://data/run_config/run_config.tres"

## G6: first-run telemetry consent prompt (Director-ratified G3 #1 → Addressed). Shown
## once over the menu before gameplay so the G4 cohort actually opts in; telemetry stays
## opt-in / default OFF.
const ConsentPromptScript := preload("res://systems/settings/telemetry_consent_prompt.gd")

## The band id GameState tags the run with. M1 has a single greybox band.
const BAND_ID := &"near"

## Spawn-piece fallback cell size if a piece doesn't report one (B1 authored 16).
const DEFAULT_CELL_SIZE_PX := 16

@onready var _band_container: Node2D = $BandContainer
@onready var _player: Player = $Player
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _menu: CanvasLayer = $MainMenu
@onready var _start_button: Button = %StartButton
@onready var _version_label: Label = %VersionLabel
@onready var _sell_screen: SellScreen = $SellScreen
## M1.1 CFG: the pre-run config rail on the main menu. start_new_run() stages its
## working config (ratified shape (a)); if the node is absent we fall back to the
## all-off default at RUN_CONFIG_PATH so the loop still reaches the M1.0 baseline.
@onready var _config_menu: ConfigMenu = %ConfigMenu

# Loaded fixtures (loaded once; pure data, never mutated here).
var _piece_catalog: Array[ZonePieceData] = []
var _cfg: BandGenConfig
var _junk_catalog: JunkCatalog
var _depth_curve: DepthCurve

# Per-run scene plumbing.
var _gate: ExtractGate = null
var _spawner: JunkSpawner = null
var _run_count: int = 0
var _band_cell_size_px: int = DEFAULT_CELL_SIZE_PX

# BUG2 (M1.1): the depth driver. The graded Band is a throwaway local in
# start_new_run(); we flatten its depth model into a per-cell lookup that outlives
# it, then resolve the player's live within-band depth on a throttle and feed it to
# GameState.set_current_depth(). Built once per run from the graded band.
# Vector2i band-global floor cell -> Vector2i(depth_index, dist_to_gate) (Decision 4).
var _cell_to_depth: Dictionary = {}
var _depth_tick_accum: float = 0.0

# R4 (M1.1): junction-entry detection for nav_branch_taken. Built per run from the
# graded band alongside _cell_to_depth. Maps each band-global FLOOR cell to
# Vector2i(piece_index, junction_degree) where junction_degree = the count of
# distinct neighbouring pieces this piece connects to (≥2 = a real fork). We emit
# nav_branch_taken once per junction-entry by tracking the player's current piece
# index and firing on a change into a piece with junction_degree ≥ 2. Reuses the
# same per-cell resolution as the BUG2 depth driver — no second spatial system.
var _cell_to_junction: Dictionary = {}
var _player_piece_index: int = -1
## R4 vision/fog node packed scene (Lever 2). Spawned per dive; inert when R4 off.
const VISION_FOG_SCENE_PATH := "res://entities/dive/vision_fog.tscn"
## BUG2: throttle for the live-depth resolution (~every 9 physics frames). Pure
## perf/responsiveness knob — correctness is throttle-independent (we emit on change,
## not on tick), so it is safe to tune (ratified Decision 2).
@export var depth_tick_interval := 0.15

# G6: true while the first-run consent modal is up; blocks starting a run until answered.
var _consent_pending: bool = false


func _ready() -> void:
	_load_fixtures()
	_version_label.text = "build %s" % BuildVersion.id()
	_start_button.pressed.connect(_on_start_pressed)
	# W4-11: the production SellScreen only announces intent; G3 owns the restart.
	# Continue from the reward beat loops straight back into a fresh dive.
	_sell_screen.continue_pressed.connect(start_new_run)
	# A finished run (extract OR fail) hands the player back to a safe state; the
	# SellScreen presents over the paused tree, so we don't need to act here beyond
	# parking the player. The sell screen + continue drive the loop forward.
	EventBus.run_ended.connect(_on_run_ended)
	_show_menu()
	# G6: first-run only — surface the telemetry consent modal over the menu and block
	# starting a run until the player answers. After the first answer it never re-shows.
	_maybe_show_consent_prompt()


func _load_fixtures() -> void:
	var pc = load(PIECE_CATALOG_PATH)
	if pc != null:
		_piece_catalog = pc.pieces
	_cfg = load(BANDGEN_CONFIG_PATH) as BandGenConfig
	_junk_catalog = load(JUNK_CATALOG_PATH) as JunkCatalog
	_depth_curve = load(DEPTH_CURVE_PATH) as DepthCurve
	if _piece_catalog.is_empty() or _cfg == null or _junk_catalog == null or _depth_curve == null:
		push_error("MainGame: missing fixtures; cannot generate bands.")


# --- The loop entry point (G3-owned) -----------------------------------------

## Start a fresh dive. The SINGLE place a run begins — both the menu's Start button
## and SellScreen.continue_pressed call this. Tears down any previous band, builds a
## new seeded one, repositions the player at the entry, and starts the run lifecycle
## (which resets run-state: a fresh bag, a reset clock, depth 0). Meta-state (money,
## banked_junk) persists across calls — the run/meta boundary is GameState's job; we
## only ever touch run-state through start_run(). Safe to call repeatedly per session.
func start_new_run() -> void:
	_hide_menu()
	_clear_band()

	_run_count += 1
	var seed: int = _next_seed()

	# M1.1 CFG / R4: resolve the run config BEFORE generation so R4's depth-scaled
	# branching (Lever 1) can read it inside generate(). We stage this SAME config
	# object onto GameState in step 6, so generation and the run share one config —
	# the M1.1 determinism key is (seed + config). Fall back to the all-off default
	# if the CFG rail is missing so behaviour is identical either way.
	var run_cfg: RunConfig = _config_menu.apply_and_get_config() if _config_menu != null else (load(RUN_CONFIG_PATH) as RunConfig)

	# 1. Generate + grade + plan (B2 → B3) — pure functions of (seed + config).
	var generator := BandGenerator.new()
	var band := generator.generate(seed, _cfg, _piece_catalog, run_cfg)
	if band == null or band.pieces.is_empty():
		push_error("MainGame: band generation produced no pieces (seed %d)." % seed)
		return
	var grader := DepthGrader.new()
	grader.grade(band)
	grader.compute_return_distance(band)
	# BUG2: capture the depth model before `band` (a throwaway local) is discarded.
	_build_cell_depth_map(band)
	var placer := JunkPlacer.new()
	var plan := placer.plan(band, _depth_curve, _junk_catalog)

	# 2. Materialise the band geometry into the world (instances at cell offsets).
	_band_cell_size_px = _materialise_band(band)

	# 3. Spawn the interactive junk pickups from the plan (C2).
	_spawner = JunkSpawner.new()
	_band_container.add_child(_spawner)
	_spawner.populate(plan, _band_container)

	# 4. Place the gate at the fixed offset from the entry spawn (E1 decision #8).
	var spawn_pos := _entry_spawn_position(band)
	_place_gate(spawn_pos)

	# 5. Put the player at the entry and let the camera find it.
	_player.global_position = spawn_pos
	_player.velocity = Vector2.ZERO
	if _camera != null:
		_camera.make_current()
		_camera.reset_smoothing()

	# 6. Start the run lifecycle. This resets ALL run-state (fresh bag, clock reset
	#    via run_started, depth 0, _run_ended guard cleared) and emits run_started,
	#    which the DiveClock / HUD / Telemetry all react to. enter_band advances to
	#    depth 1 so the player reads "in the band" rather than depth 0 at the gate.
	# M1.1 R0/CFG: stage the SAME run config we generated with (resolved at the top of
	# start_new_run) BEFORE start_run, so GameState binds it as active_run_config for
	# this run and generation + run agree. start_run resets run-state; if run_cfg were
	# null start_run falls back to its own all-off default, so behaviour is identical.
	GameState.stage_run_config(run_cfg)
	GameState.start_run(BAND_ID, seed)
	GameState.enter_band(BAND_ID)
	# BUG2: resolve once immediately so frame-0 within-band depth is correct (the
	# player is at the entry → depth 0) before the throttled driver takes over.
	_depth_tick_accum = 0.0
	_resolve_player_depth()

	# R4 (M1.1): instantiate the run-state vision/fog + lost-proxy nodes for this dive.
	# Both no-op internally when R4 is off (vision: no overlay; lost-proxy: set_process
	# false), so the all-off control path adds inert nodes only. Added under the band
	# container so _clear_band() frees them with the band (run-state, never persisted).
	_spawn_r4_nodes()


# --- Run-end handling --------------------------------------------------------

func _on_run_ended(_reason: StringName, _duration_s: float, _depth_reached: int) -> void:
	# The SellScreen (a sibling) presents the reward beat over the paused tree and,
	# on Continue, calls start_new_run(). We just freeze the player so it can't keep
	# sliding under the paused overlay edge cases; start_new_run repositions it.
	if _player != null:
		_player.velocity = Vector2.ZERO


# --- Band materialisation ----------------------------------------------------

## Add each placed piece's instance to the world at its integer cell offset (pixels
## only here, at instance time — the layout itself stayed in integer-cell space).
## Returns the band cell size for world-space math.
func _materialise_band(band: Band) -> int:
	var cell_size := DEFAULT_CELL_SIZE_PX
	for p in band.pieces:
		if p.instance == null:
			continue
		if p.instance.cell_size_px > 0:
			cell_size = p.instance.cell_size_px
		p.instance.position = Vector2(p.offset_cell * cell_size)
		_band_container.add_child(p.instance)
	# BUG3: seal every unmated socket so the band is a closed play space (the player
	# can't walk through an uncapped opening into off-map void). Runs AFTER pieces are
	# parented, reading the already-final deterministic band — adds only WALL collision
	# geometry, no pieces, no RNG, so band.fingerprint() is untouched.
	SocketSealer.new().seal_unused_sockets(band, cell_size)
	return cell_size


# --- R4 (M1.1): run-state nav nodes ------------------------------------------

## Instantiate the R4 vision/fog (Lever 2) + lost-proxy (§3) nodes for this dive.
## Both read GameState.active_run_config in their _ready() and self-disable when R4
## is off (vision: no overlay, set_process false; lost-proxy: set_process false), so
## with the all-off control they are inert. Parented under the band container so they
## are torn down with the band each run (run-state only, never persisted). Keeping
## this in one helper keeps the R4 edits localized for R1's later sequential merge.
func _spawn_r4_nodes() -> void:
	var vision_scene := load(VISION_FOG_SCENE_PATH) as PackedScene
	if vision_scene != null:
		_band_container.add_child(vision_scene.instantiate())
	else:
		push_warning("MainGame: R4 vision/fog scene missing at %s." % VISION_FOG_SCENE_PATH)
	_band_container.add_child(LostProxy.new())


# --- BUG2: live within-band depth driver -------------------------------------

## Flatten the graded band's depth model into a per-cell lookup that outlives the
## throwaway `band` local. Each band-global FLOOR cell maps to BOTH metrics
## (depth_index + dist_to_gate, Decision 4) so one lookup yields both. floor_cells
## (walkable) only — the player can only stand on floor; walls map to no depth.
func _build_cell_depth_map(band: Band) -> void:
	_cell_to_depth.clear()
	for p in band.pieces:
		if p.depth_index < 0:        # ungraded guard
			continue
		for cell in p.floor_cells:   # band-global floor cells (B3)
			_cell_to_depth[cell] = Vector2i(p.depth_index, p.dist_to_gate)
	# R4: build the parallel junction map (piece_index, junction_degree per cell).
	_build_junction_map(band)
	_player_piece_index = -1


## R4 (M1.1): flatten per-piece junction degree into a per-cell lookup. A piece's
## junction_degree = the number of DISTINCT neighbouring pieces it connects to via a
## walkable doorway (FLOOR cells 4-adjacent across a piece boundary) — the same
## adjacency the generator's is_band_connected uses. 2 = pass-through corridor,
## ≥3 = a real branch/intersection. Used only to emit nav_branch_taken on entry.
func _build_junction_map(band: Band) -> void:
	_cell_to_junction.clear()
	# Map every FLOOR cell -> owning piece index.
	var cell_owner := {}
	for i in band.pieces.size():
		for c in band.pieces[i].floor_cells:
			cell_owner[c] = i
	# Per-piece distinct-neighbour count via 4-adjacent floor doorways.
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var degree: Array[int] = []
	degree.resize(band.pieces.size())
	for i in band.pieces.size():
		var seen := {}
		for c in band.pieces[i].floor_cells:
			for step in steps:
				var n: Vector2i = c + step
				if cell_owner.has(n):
					var j: int = cell_owner[n]
					if j != i:
						seen[j] = true
		degree[i] = seen.size()
	# Project the degree back onto every floor cell, keyed with the piece index so the
	# driver can detect a true piece-to-piece entry (not just a cell move).
	for i in band.pieces.size():
		for c in band.pieces[i].floor_cells:
			_cell_to_junction[c] = Vector2i(i, degree[i])


## Throttled driver: while a run is active, resolve the player's live within-band
## depth every depth_tick_interval seconds (correctness is throttle-independent —
## set_current_depth emits on change only).
func _physics_process(delta: float) -> void:
	if not GameState.run_active:
		return
	_depth_tick_accum += delta
	if _depth_tick_accum < depth_tick_interval:
		return
	_depth_tick_accum = 0.0
	_resolve_player_depth()


## Resolve the player's band-global cell → owning piece → (depth_index, dist_to_gate)
## and push it into GameState. Pieces materialise at offset_cell * cell_size, so
## band-global cell space and world space share the origin (no per-piece transform).
## Decision 6: if the cell is in no piece's floor_cells (wall edge / mid-doorway
## rounding) KEEP the last known depth — never snap to 0 (no spurious depth_changed).
func _resolve_player_depth() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	var cell := Vector2i((player.global_position / float(_band_cell_size_px)).floor())
	if _cell_to_depth.has(cell):
		var d: Vector2i = _cell_to_depth[cell]
		GameState.set_current_depth(d.x, d.y)   # (depth_index, dist_to_gate)
	# R4 (M1.1): junction-entry detection for nav_branch_taken. Reuse the same cell
	# resolution: when the player crosses into a NEW piece whose junction_degree ≥ 2
	# (a real fork), emit once. Only fires while R4 is enabled.
	_maybe_emit_branch_taken(cell)


## R4: emit nav_branch_taken(depth, junction_degree) exactly once per junction-entry.
## A junction-entry = the player's owning piece changed to a piece with ≥2 distinct
## neighbouring pieces (a fork/intersection). Tracks the last owning piece index so
## staying within a piece (or re-resolving the same cell) never re-emits.
func _maybe_emit_branch_taken(cell: Vector2i) -> void:
	var rc := GameState.active_run_config
	if rc == null or not rc.r4_enabled:
		return
	if not _cell_to_junction.has(cell):
		return
	var meta: Vector2i = _cell_to_junction[cell]   # (piece_index, junction_degree)
	var piece_index := meta.x
	if piece_index == _player_piece_index:
		return   # same piece — no new entry
	_player_piece_index = piece_index
	var junction_degree := meta.y
	if junction_degree >= 2:
		EventBus.nav_branch_taken.emit(GameState.current_depth_index, junction_degree)


## World position the player spawns at: the centre of the entry piece's first floor
## cell. Falls back to the band origin if the entry has no floor cells.
func _entry_spawn_position(band: Band) -> Vector2:
	var entry := band.entry_piece
	if entry != null and not entry.floor_cells.is_empty():
		var cell: Vector2i = entry.floor_cells[0]
		return Vector2(cell * _band_cell_size_px) \
			+ Vector2(_band_cell_size_px, _band_cell_size_px) * 0.5
	return Vector2.ZERO


## Instance the gate at the fixed hand-authored offset from spawn (decision #8,
## GameState.GATE_SPAWN_OFFSET). The gate is dumb: it just calls extract_and_end_run.
func _place_gate(spawn_pos: Vector2) -> void:
	var gate_scene := load(GATE_SCENE_PATH) as PackedScene
	if gate_scene == null:
		push_error("MainGame: gate scene missing at %s." % GATE_SCENE_PATH)
		return
	_gate = gate_scene.instantiate() as ExtractGate
	_band_container.add_child(_gate)
	_gate.global_position = spawn_pos + GameState.GATE_SPAWN_OFFSET


## Tear down the previous band, gate, spawner and pickups. The player + HUD + sell
## screen persist (they are loop-level, not per-band). Run-state is GameState's to
## reset in start_run; this is pure scene cleanup so old geometry never stacks up.
func _clear_band() -> void:
	_gate = null
	_spawner = null
	for child in _band_container.get_children():
		child.queue_free()


# --- Menu --------------------------------------------------------------------

func _on_start_pressed() -> void:
	# G6: while the first-run consent modal is up, the menu is blocked — ignore Start.
	if _consent_pending:
		return
	start_new_run()


# --- G6: first-run telemetry consent ----------------------------------------

## Show the consent modal exactly once (first launch / wiped profile). Blocks the
## Start button until the player answers; after any answer the asked-flag is set so
## this never shows again. No-op when already asked.
func _maybe_show_consent_prompt() -> void:
	if not ConsentPromptScript.should_show():
		return
	_consent_pending = true
	_start_button.disabled = true
	var prompt: TelemetryConsentPrompt = ConsentPromptScript.new()
	prompt.choice_made.connect(_on_consent_choice)
	add_child(prompt)


func _on_consent_choice(_enabled: bool) -> void:
	# Either choice unblocks the menu. The prompt itself persisted the choice + the
	# asked-flag and (on Enable) toggled Telemetry; we only restore the menu here.
	_consent_pending = false
	_start_button.disabled = false
	_start_button.grab_focus()


func _show_menu() -> void:
	_menu.visible = true
	_start_button.grab_focus()


func _hide_menu() -> void:
	_menu.visible = false


# --- Seeding -----------------------------------------------------------------

## A fresh seed per run so each dive is a different layout, while staying
## reproducible within a process (run index + a session base). Deterministic enough
## for a playtest; a real meta layer will own seed policy later.
func _next_seed() -> int:
	return (Time.get_unix_time_from_system() as int) * 31 + _run_count * 2654435761
