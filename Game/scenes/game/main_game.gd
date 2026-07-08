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

## M1.9 (S3): the band is now generated from a BandProfile through BandPipeline (the S1
## orchestrator). The default profile IS today's baseline as data — band_greybox.tres
## references the LIVE bandgen_config/piece_catalog(+ext)/depth_curve/junk_catalog .tres
## (same cached objects, never copies), so the all-off fingerprint (e943ac9c8bc1) is
## byte-identical through the pipeline (test_band_pipeline_parity). The I1 lvl_enabled
## ext-catalog swap lives INSIDE the pipeline now (profile.piece_pool_ext — S3 §7.2
## Q6(iv)); the legacy generation consts/fixtures this replaced are deleted.
const DEFAULT_BAND_PROFILE_PATH := "res://data/bands/band_greybox.tres"
const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"
const DEPTH_CURVE_PATH := "res://systems/depth/depth_curve.tres"
const GATE_SCENE_PATH := "res://entities/gate/extract_gate.tscn"
## M1.10 (T1): the greybox tileset a synthetic cave piece's runtime Geometry layer
## reuses (its WALL atlas (1,0) carries the physics polygon the sealer caps with, and
## its FLOOR atlas (0,0) is collisionless). load()ed LAZILY inside _build_synthetic_piece
## — a socket dive never builds a synthetic piece, so it never loads this here, and the
## all-off/socket materialise path stays byte-identical.
const GREYBOX_TILESET_PATH := "res://data/tilesets/greybox.tres"
## M1.1 R0: the default (all-off) run config. CFG will later swap this for the
## menu-built config; for now we stage the all-off default so the wiring is
## exercised and the loop stays at the M1.0 baseline.
const RUN_CONFIG_PATH := "res://data/run_config/run_config.tres"

## The DEFAULT route key — the band id GameState tags the control run with.
## &"near" is the legacy M1.6 key portal 1 has always emitted; telemetry cohort
## continuity (every M1.6–M1.8 run_started row says "near") depends on it.
const BAND_ID := &"near"

## S8 (M1.9): the dive routing table. Route KEY (what the hub portals emit via
## dive_requested, and what start_run/enter_band tag the run + telemetry with)
## → BandProfile id under BAND_PROFILE_DIR. Keys are DECOUPLED from profile file
## names so portal 1 keeps its historical &"near" (scene byte-identical, telemetry
## vocabulary continuous — S8 §RD Q2). Unknown/empty keys fall back to BAND_ID.
const BAND_PROFILE_DIR := "res://data/bands/"
const BAND_ROUTES: Dictionary = {
	&"near": &"band_greybox",
	&"band_two": &"band_two",
	&"band_three": &"band_three",   # T4 (M1.10): the cave band — T3's "The Warren" profile.
	&"band_four": &"band_four",     # U4 (M1.11): the open-field band — U3's "The Far Field" profile.
}

## Spawn-piece fallback cell size if a piece doesn't report one (B1 authored 16).
const DEFAULT_CELL_SIZE_PX := 16

@onready var _band_container: Node2D = $BandContainer
@onready var _player: Player = $Player
## K6 (M1.4): the camera is now on a LEVEL-OWNED follow rig (not a child of the
## player body), matching player.gd's documented intent and making the camera
## interpolation-clean. The rig copies the player position on the physics tick
## (_physics_process below); physics interpolation (project.godot [physics]) smooths
## the render. K3 (M1.4): the camera is a CameraView that drives a fixed visible
## world-width from the cam_* run-config knobs (default-off => today's (2,2) framing).
@onready var _camera_rig: Node2D = $CameraRig
@onready var _camera: CameraView = $CameraRig/CameraView
@onready var _dive_clock: DiveClock = $DiveClock
## M1.1 R2/R3: the two cost-axis oppositions live as PERSISTENT children of the dive
## scene (like DiveClock) — they self-gate per run (their _on_run_started reads
## GameState.active_run_config.rN_enabled and go inert when their opposition is off) and
## reset per run, so a single persistent instance is correct (no per-run spawn/free).
## They connect to EventBus.run_started/run_ended in their OWN _ready(), so once parented
## they react to the run lifecycle automatically. RG1 only injects R2's DiveClock ref.
@onready var _return_cost: ReturnCost = $ReturnCost   # R2 (Costlier Return)
@onready var _exposure_meter: ExposureMeter = $ExposureMeter   # R3 (Exposure Meter)
## L1 (M1.5): the HUD inventory panel — the throw seam reads its highlighted_index()
## as a PURE GETTER (the panel stays a view; main_game owns the model mutation + the
## projectile spawn). Resolved by path off the DecisionHUD instance.
@onready var _inventory_panel: InventoryPanel = get_node_or_null("DecisionHUD/Root/InventoryPanel")

## L1 (M1.5): the thrown-item projectile scene. load()ed lazily on the first throw so
## an all-off run (throw_enabled=false → _try_throw early-returns) never loads it and
## stays byte-identical to M1.4.
const THROWN_ITEM_SCENE_PATH := "res://entities/thrown_item/thrown_item.tscn"

# Loaded fixtures (loaded once; pure data, never mutated here). M1.9 (S3): kept only as
# null-fallbacks — the profile's depth_curve/junk_catalog (same live .tres objects for
# band_greybox) are the bound source now.
var _junk_catalog: JunkCatalog
var _depth_curve: DepthCurve

## M1.9 (S3): the dive's resolved BandProfile (run-state; re-resolved every
## start_new_run). The _spawn_new_hazards façade reads it so the builder sees the SAME
## profile the band was generated from (bare-instance test harnesses, which never run
## start_new_run, fall back to _resolve_band_profile()).
var _band_profile: BandProfile = null

## S8 (M1.9): the resolved ROUTE key for this dive (run-state; set by
## _resolve_band_profile alongside _band_profile, re-resolved every start_new_run).
## start_run/enter_band tag the run with it, so telemetry's run_started band_id IS
## the route key (&"near" control / &"band_two" — never the profile id). Defaults
## to the control key for harness paths that never resolve.
var _band_route_key: StringName = BAND_ID

# Per-run scene plumbing.
# K7 (M1.4): one OR MORE extract gates per band (was the single var _gate). The all-off
# control still produces exactly one gate at GATE_SPAWN_OFFSET; enabled exits append more.
var _gates: Array[ExtractGate] = []
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

# J4 (M1.3): corridor-time telemetry. _piece_kind_by_index maps piece_index -> is_corridor
# (bool), built once per run alongside _build_junction_map from the hardcoded
# RunConfig.CORRIDOR_PIECE_IDS set keyed on PlacedPiece.piece_id (NOT size_cells — that's an
# @export recomputed in _ready, not authoritative pre-tree). _corridor_time_s / _room_time_s
# accumulate wall-clock seconds the player spends in corridor vs. room pieces (reset on
# run_started, emitted on run end via EventBus.corridor_time_summary). The accumulation rides
# the existing per-piece tracking (_player_piece_index) — no new spatial system.
var _piece_kind_by_index: Dictionary = {}   # int piece_index -> bool is_corridor
var _corridor_time_s: float = 0.0
var _room_time_s: float = 0.0
## R4 vision/fog node packed scene (Lever 2). Spawned per dive; inert when R4 off.
const VISION_FOG_SCENE_PATH := "res://entities/dive/vision_fog.tscn"
## R1 (M1.1): the pursuing-hazard greybox scene. Instantiated per dive ONLY when
## r1_enabled && r1_spawn_count > 0; otherwise never loaded (all-off = M1.0).
const HAZARD_SCENE_PATH := "res://scenes/hazards/hazard_entity.tscn"
## BUG2: throttle for the live-depth resolution (~every 9 physics frames). Pure
## perf/responsiveness knob — correctness is throttle-independent (we emit on change,
## not on tick), so it is safe to tune (ratified Decision 2).
@export var depth_tick_interval := 0.15


func _ready() -> void:
	_load_fixtures()
	# R2 (ReturnCost) charges its `clock` toll through DiveClock.modify_light(); inject the
	# persistent DiveClock node so the export is bound (the .tscn NodePath form proved
	# unreliable for the typed export, so we assign it here per the RG1 spec §1). Null-safe:
	# a config that never selects the clock toll simply skips the charge.
	if _return_cost != null:
		_return_cost.dive_clock = _dive_clock
	# M1.6 (M2): main_game is DIVE-ONLY now. The Main Menu (M1) owns the title / Start /
	# Version / first-run telemetry consent; the Hub (M2) is the between-runs surface; the
	# P-debug overlay (M4) owns the config rail. Entering this scene == diving, so on
	# run_ended we route back to the Hub (the App router auto-returns) instead of presenting
	# a SellScreen. We only keep the dive's own run-end handler (corridor summary + freeze).
	EventBus.run_ended.connect(_on_run_ended)
	# Self-start the dive: the portal already gated the player's choice to dive (RD-3), so
	# the dive scene starts its run on entry. start_new_run() resolves its RunConfig via
	# GameState.dive_config_or_default() (M4's staged config if the Director set one, else
	# make_default_play_preset()) — no menu-embedded ConfigMenu rail anymore.
	start_new_run()


func _load_fixtures() -> void:
	# M1.9 (S3): the generation fixtures (bandgen config + piece catalogs) moved onto the
	# BandProfile (band_greybox.tres references the same live .tres objects); only the
	# loot-plan fallbacks remain here.
	_junk_catalog = load(JUNK_CATALOG_PATH) as JunkCatalog
	_depth_curve = load(DEPTH_CURVE_PATH) as DepthCurve
	if _junk_catalog == null or _depth_curve == null:
		push_error("MainGame: missing fixtures; cannot plan loot.")


# --- The loop entry point (G3-owned) -----------------------------------------

# M1.6 (M2): _on_continue_pressed (the old SellScreen.continue_pressed handler, which ran
# the MISS-wipe before looping into a fresh dive) is DELETED. The dive no longer loops
# through a SellScreen — on run_ended the App router auto-returns to the Hub, and the
# Hub-return beat (hub.gd) owns the quota eval + roguelite MISS-wipe (decoupled from
# selling, GameState.evaluate_quota_on_return). The wipe is therefore guaranteed on every
# return, even if the player never visits M3's Shop to sell — closing the roguelite hole.

## Start a fresh dive. The SINGLE place a run begins — called from _ready() on entry
## (M1.6 M2: the dive self-starts; the portal already gated the choice) and re-callable by
## the RG verify tests directly. Tears down any previous band, builds a
## new seeded one, repositions the player at the entry, and starts the run lifecycle
## (which resets run-state: a fresh bag, a reset clock, depth 0). Meta-state (money,
## banked_junk) persists across calls — the run/meta boundary is GameState's job; we
## only ever touch run-state through start_run(). Safe to call repeatedly per session.
func start_new_run() -> void:
	_clear_band()

	_run_count += 1
	var seed: int = _next_seed()

	# M1.1 CFG / R4: resolve the run config BEFORE generation so R4's depth-scaled
	# branching (Lever 1) can read it inside generate(). We stage this SAME config
	# object onto GameState in step 6, so generation and the run share one config —
	# the M1.1 determinism key is (seed + config).
	# M1.6 (M2): the embedded ConfigMenu rail is gone (dive-only refactor). Resolve the
	# RunConfig from the GameState dive-staged slot: M4's P-debug overlay writes it
	# (stage_dive_config) when the Director sets a config; otherwise dive_config_or_default()
	# returns make_default_play_preset() (the same fun stack the old CFG-less fallback used,
	# preserving the J1 "CFG-less launch boots the fun preset" contract). Tests that want the
	# all-off control stage a RunConfig.new()/the .tres explicitly via GameState.stage_dive_config
	# (or stage_run_config), so the determinism baseline is unaffected. Never null.
	var run_cfg: RunConfig = GameState.dive_config_or_default()

	# 1. Generate + grade (B2 → B3) — pure functions of (profile + seed + config).
	#    M1.9 (S3): THE band-gen call-site switch — the profile-driven BandPipeline (S1)
	#    replaces the direct BandGenerator call. The pipeline owns backend selection, the
	#    I1 lvl_enabled ext-catalog swap (profile.piece_pool_ext, §7.2 Q6(iv) — same
	#    config-dependent swap as before, so the all-off fp never moves), the S5 flavor
	#    stages (band_greybox has none → the byte-identical parity path), and grading +
	#    return distance. rc threads the legacy levers (r4_*, lvl_*, corridor weights) to
	#    the generator's interior hooks unchanged (test_band_pipeline_parity P5). The
	#    profile comes from the routing seam (_resolve_band_profile — S8 rewires the key
	#    map in Wave 5); the SocketSealer stays at materialisation (it needs parented
	#    pieces).
	_band_profile = _resolve_band_profile()
	if _band_profile == null:
		push_error("MainGame: no band profile at %s; cannot generate." % DEFAULT_BAND_PROFILE_PATH)
		return
	var band := BandPipeline.new().generate(_band_profile, seed, run_cfg)
	if band == null or band.pieces.is_empty():
		push_error("MainGame: band generation produced no pieces (seed %d)." % seed)
		return
	# BUG2: capture the depth model before `band` (a throwaway local) is discarded.
	_build_cell_depth_map(band)

	# I1 (M1.2): the single effective px-per-cell for THIS run, derived once from the
	# size multiplier and shared by EVERY pixel-space consumer — materialise, the junk
	# planner, and (via _band_cell_size_px) spawn/gate/hazard/depth/vision. Deriving it
	# once is what guarantees abutting pieces never gap and loot lands inside scaled
	# rooms (Resolved F + the Phase-3 junk-seam fix). lvl off / mult 1.0 → DEFAULT (16).
	var cell_size_px := DEFAULT_CELL_SIZE_PX
	if run_cfg != null:
		cell_size_px = run_cfg.effective_cell_size_px(DEFAULT_CELL_SIZE_PX)

	# Plan loot AGAINST the same effective cell size (the Phase-3 build-breaking fix):
	# JunkPlacer computes world coords from the piece export (16) unless overridden, and
	# pickups are NOT children of the scaled piece nodes, so without this they cluster at
	# 1x coords and land outside/atop scaled rooms.
	var placer := JunkPlacer.new()
	# J3 (M1.3): the loot-per-area sub-knob (OFF by default / never preset-on). At 0.0 the
	# planner draws byte-for-byte as M1.2; > 0 scales per-piece junk count by room area.
	var loot_density: float = run_cfg.lvl_loot_density_per_area if run_cfg != null else 0.0
	# M1.9 (S3): depth curve + junk catalog bind from the PROFILE (band_greybox references
	# the same live .tres objects the old fixtures loaded → byte-identical plan); the
	# fixture members remain as null-fallbacks only.
	var depth_curve: DepthCurve = _band_profile.depth_curve \
		if _band_profile.depth_curve != null else _depth_curve
	var junk_catalog: JunkCatalog = _band_profile.junk_catalog \
		if _band_profile.junk_catalog != null else _junk_catalog
	var plan := placer.plan(band, depth_curve, junk_catalog, false, cell_size_px, loot_density)

	# 2. Materialise the band geometry into the world (instances at cell offsets),
	#    scaling each piece + its spacing by the effective cell size.
	_band_cell_size_px = _materialise_band(band, cell_size_px)
	# M1.9 (S3): tier-1 band identity (D-RAT-4) — the profile's whole-band modulate tint.
	# band_greybox ships neutral white == zero visual change; S7's band_two authors a
	# real tint. Render-only: never feeds fingerprint().
	_band_container.modulate = _band_profile.palette_tint

	# 3. Spawn the interactive junk pickups from the plan (C2).
	_spawner = JunkSpawner.new()
	_band_container.add_child(_spawner)
	_spawner.populate(plan, _band_container)

	# 4. Place the exit gate(s). All-off (exit_enabled=false) = today's single fixed gate
	#    at the offset from spawn (E1 decision #8); K7 passes `band` for the candidate pool.
	var spawn_pos := _entry_spawn_position(band)
	# BUG10: pass the freshly-resolved run_cfg, NOT GameState.active_run_config — the latter
	# is still null here (end_run() cleared it; start_run() doesn't re-stage it until step 6
	# below), so reading it placed a single all-off gate REGARDLESS of the exit config.
	_place_gate(band, spawn_pos, run_cfg)

	# 5. Put the player at the entry and let the camera find it.
	_player.global_position = spawn_pos
	# M1.7 interp-ghost fix: physics_interpolation is ON — reset so the player doesn't render
	# one frame interpolated between its last position and the dive-start spawn (the dive-start
	# player ghost). Render-only: no gameplay/RNG change.
	_player.reset_physics_interpolation()
	_player.velocity = Vector2.ZERO
	# K6 (M1.4): the camera rig is level-owned now (not a child of the player), so it
	# must be re-centred on the player at run start before make_current/reset_smoothing
	# — otherwise the camera would snap from its last run's position. The per-tick
	# follow (_physics_process) keeps it locked thereafter; interpolation smooths it.
	if _camera_rig != null:
		_camera_rig.global_position = spawn_pos
		# M1.7 interp-ghost fix: reset so the rig doesn't render one frame interpolated from its
		# last run's position to the new spawn (the dive-start camera ghost). Render-only.
		_camera_rig.reset_physics_interpolation()
	if _camera != null:
		_camera.make_current()
		_camera.reset_smoothing()
		# K3 (M1.4): apply the resolution-independent camera config AFTER make_current
		# (so the camera is current before its first zoom recompute, K3 OQ-6). Default-off
		# (cam_enabled=false) leaves zoom at BASE_ZOOM=(2,2) => today's framing exactly.
		_camera.apply_from_config(run_cfg)

	# 6. Start the run lifecycle. This resets ALL run-state (fresh bag, clock reset
	#    via run_started, depth 0, _run_ended guard cleared) and emits run_started,
	#    which the DiveClock / HUD / Telemetry all react to. enter_band advances to
	#    depth 1 so the player reads "in the band" rather than depth 0 at the gate.
	# M1.1 R0/CFG: stage the SAME run config we generated with (resolved at the top of
	# start_new_run) BEFORE start_run, so GameState binds it as active_run_config for
	# this run and generation + run agree. start_run resets run-state; if run_cfg were
	# null start_run falls back to its own all-off default, so behaviour is identical.
	GameState.stage_run_config(run_cfg)
	# S8 (M1.9): tag the run with the resolved ROUTE key (set by _resolve_band_profile
	# in step 1). Unstaged/control dives resolve to BAND_ID (&"near") — byte-for-byte
	# the historical call — so the telemetry cohort label never forks; portal-2 dives
	# tag &"band_two". run_started then stamps this key on the JSONL row (telemetry.gd).
	GameState.start_run(_band_route_key, seed)
	GameState.enter_band(_band_route_key)
	# BUG2: resolve once immediately so frame-0 within-band depth is correct (the
	# player is at the entry → depth 0) before the throttled driver takes over.
	_depth_tick_accum = 0.0
	_resolve_player_depth()

	# R4 (M1.1): instantiate the run-state vision/fog + lost-proxy nodes for this dive.
	# Both no-op internally when R4 is off (vision: no overlay; lost-proxy: set_process
	# false), so the all-off control path adds inert nodes only. Added under the band
	# container so _clear_band() frees them with the band (run-state, never persisted).
	_spawn_r4_nodes()

	# R1 (M1.1): spawn the pursuing hazard(s). Self-contained, fully gated by the run
	# config — r1_enabled == false (or r1_spawn_count == 0) skips the loop entirely so
	# no hazard node is ever instantiated and the all-off control == M1.0 exactly. The
	# config is readable here (staged + start_run bound it as active_run_config above);
	# we read run_cfg, the same object. Hazards spawn dormant at/near the piece at
	# r1_depth_threshold (§9 Q1; clamped to the deepest piece) and go into
	# _band_container so _clear_band() disposes them with the band for free. setup()
	# binds the config snapshot + the player so the hazard never re-reads active_run_config.
	_spawn_r1_hazards(run_cfg, band)
	# K5i (M1.4): spawn the three new M1.4 hazard types (ping-pong / bomb / spikes) into the
	# same graded band, each with a per-type depth-scaled count placed through the SAME J3
	# cell helpers (no duplicated placement math). Fully gated: with every *_enabled false
	# (the K0 default) no descriptor is enabled → no scene loaded, no node built → all-off is
	# byte-identical to M1.3 (fp e943ac9c8bc1 UNMOVED). Sibling of _spawn_r1_hazards.
	# BUG7: thread spawn_pos so the seam can exclude the player's entry cell + a safe radius
	# around it (the player is already AT spawn_pos by this call → no frame-0 spawn-kill).
	_spawn_new_hazards(run_cfg, band, spawn_pos)


# --- K5i (M1.4): new-hazard spawn seam (ping-pong / bomb / spikes) ------------
# M1.9 (S3): the POLICY half (descriptor table, fair-share split, depth-scaled counts,
# per-kind ctx) moved into EncounterBuilder (systems/spawning/encounter_builder.gd);
# the MECHANISM half moved into SpawnService in S0. What remains here is the thin
# façade (_spawn_new_hazards — kept-signature, the golden harness drives it), the
# profile-resolution seam, two re-export consts and a ctx forwarder for the committed
# golden tests.

## K5i: band-wide ceiling across ALL THREE new hazard types COMBINED (OQ-3, Director-flagged
## value 48; RG1 must measure the worst-case combined tick time). SEPARATE from R1's
## R1_DENSITY_BAND_CEILING (R1 keeps its own 64 budget); this bounds K5a+K5b+K5c together so
## three stacked per-depth budgets can't flood the band with _physics_process nodes. L6-followup
## (M1.5): the ceiling is split FAIR-SHARE across the enabled types (each gets an equal slice;
## the descriptor order only decides who absorbs the integer remainder), so a dense early type can
## no longer starve a later one — see _spawn_new_hazards. When a type's demand is under its slice
## the split never binds, so low-density bands are unaffected.
## M1.9 (S0): the const RELOCATED to SpawnService (the mechanism owns the cap group); this
## is a FORWARDING re-export so the committed golden tests (test_new_hazard_spawn.gd:44,
## test_rg1_m14_verify.gd:299/:403) keep reading it off the MainGame script unmodified.
const NEW_HAZARD_BAND_CEILING: int = SpawnService.NEW_HAZARD_BAND_CEILING

## BUG7 (M1.4 Wave-5): no new hazard may spawn on or dangerously near the player's entry.
## The player is placed AT _entry_spawn_position(band) BEFORE _spawn_new_hazards runs, so a
## hazard at base_count >= 1 in the depth-0 entry piece could land on the spawn cell → instant
## frame-0 lethal contact (feedback #7, session s_384be7 runs 19–47). Belt-and-braces alongside
## skipping the depth-0 entry piece: any candidate cell whose world centre is within this many
## CELL-WIDTHS of spawn_pos is excluded — a couple of cells clears the largest hazard kill
## radius. Pure run-state, NO RNG (never feeds fingerprint(), like the rest of the seam).
## M1.9 (S0): the value RELOCATED to SpawnService.SPAWN_SAFE_CELLS (the exclusion
## ENFORCEMENT lives with the placement validation now — SpawnService.valid_cells());
## this is a FORWARDING re-export so the golden harness (test_new_hazard_spawn.gd:172)
## keeps reading it off the MainGame script unmodified.
const NEW_HAZARD_SPAWN_SAFE_CELLS: float = SpawnService.SPAWN_SAFE_CELLS

## M1.9 (S0): the per-dive SpawnService — the policy-free spawn MECHANISM (instantiate /
## validate / registry / caps / lifecycle / setup handshake / &"spawned" emit). Created
## LAZILY as a child of THIS node (never _band_container: _clear_band() frees the
## container's children and the golden harness counts them), so the all-off path — which
## returns before _ensure_spawn_service() — never creates it and the all-off scene tree
## stays byte-identical. Group-resolved via &"spawn_service" for mid-run clients (S6b,
## the debug menu). Run-state only; torn down with the dive scene.
var _spawn_service: SpawnService = null


## Lazily create (or return) the per-dive SpawnService. Works on a bare out-of-tree
## MainGame script instance too (the golden-harness path): add_child on an out-of-tree
## parent is legal, and the service resolves the player off the BAND CONTAINER's tree.
func _ensure_spawn_service() -> SpawnService:
	if _spawn_service == null or not is_instance_valid(_spawn_service):
		_spawn_service = SpawnService.new()
		_spawn_service.name = "SpawnService"
		add_child(_spawn_service)
	return _spawn_service


## M1.9 (S3 seam, S8 rewired): resolve the dive's BandProfile off the routing seam.
## The route key comes from GameState's staging slot (dive_requested(band_id) →
## GameState self-subscribes and stages → consume-on-read here, so a stale choice can
## never leak into a later run). BAND_ROUTES maps key → profile id (&"near" →
## band_greybox, &"band_two" → band_two); &"" (nothing staged — tests, direct
## start_new_run callers) and any unknown key fall back to the greybox control,
## byte-identical to the pre-S8 path. The resolved KEY is kept on _band_route_key for
## the start_run/enter_band tags (telemetry run_started band_id == the route key).
## CONSUME-ON-READ: call this at most once per run start — a second call inside one
## start falls back to the default (the seam is already consumed). A missing profile
## file fail-safes to the control band (never a null return while band_greybox exists).
func _resolve_band_profile() -> BandProfile:
	var key: StringName = GameState.consume_pending_dive_band()
	if key == &"" or not BAND_ROUTES.has(key):
		key = BAND_ID
	var profile_id: StringName = BAND_ROUTES[key]
	var profile := load(BAND_PROFILE_DIR + String(profile_id) + ".tres") as BandProfile
	if profile == null:
		push_error("MainGame: band profile '%s' missing under %s; falling back to the control band."
				% [profile_id, BAND_PROFILE_DIR])
		key = BAND_ID
		profile = load(DEFAULT_BAND_PROFILE_PATH) as BandProfile
	_band_route_key = key
	return profile


## K5i (M1.4) — M1.9 (S3): THE THIN FAÇADE. Kept-signature (the golden harness
## test_new_hazard_spawn.gd drives this in 8 places, §7.1 C2): resolve the BUG7 entry
## position (recompute from topology when the caller didn't thread it — test :184 relies
## on the recompute), arm the per-dive SpawnService, register the shared K5 cap group,
## and delegate ALL policy (descriptor table, fair-share, depth-scaled counts, deck +
## extras lanes) to EncounterBuilder.populate(). FULLY GATED: rc == null or an
## all-off/neutral config returns BEFORE _ensure_spawn_service() — no def, no scene,
## NO service node → all-off is byte-identical (fp UNMOVED), exactly as pre-S3.
func _spawn_new_hazards(rc: RunConfig, band: Band, spawn_pos: Vector2 = Vector2.INF) -> void:
	if rc == null:
		return
	# The builder sees the SAME profile the band was generated from (start_new_run set
	# _band_profile); a bare-instance harness call (no start_new_run) resolves the
	# default greybox profile here — empty deck → the pure legacy parity lane.
	var profile: BandProfile = _band_profile if _band_profile != null \
		else _resolve_band_profile()
	var builder := EncounterBuilder.new()
	if builder.is_inert(profile, rc):
		return   # all-off: zero policy work → zero mechanism (S0's loads-nothing rule)
	var entry_pos: Vector2 = spawn_pos if spawn_pos != Vector2.INF else _entry_spawn_position(band)
	var svc := _ensure_spawn_service()
	svc.begin_band(_band_container, _band_cell_size_px, entry_pos, rc)
	svc.set_cap_group(&"new_hazards", SpawnService.NEW_HAZARD_BAND_CEILING)
	builder.populate(band, profile, rc, svc)


## M1.9 (S3): thin forwarder — the per-kind ctx builder RELOCATED to
## EncounterBuilder.legacy_ctx (with the golden-angle const). Kept, same
## signature/arity, because the golden harness calls it directly off the mg instance
## (test_new_hazard_spawn.gd:152/:158/:164 — §7.1 C2). NOTE the corrected doc (§7.1):
## `index` is the CROSS-TYPE band-wide accumulator (spawned_total), not a per-type
## index; `k` is the within-room index.
func _new_hazard_spawn_ctx(kind: StringName, p: PlacedPiece, k: int, index: int,
		room_bounds: Rect2) -> Dictionary:
	return EncounterBuilder.legacy_ctx(kind, p, k, index, room_bounds)


## K5i (M1.4): the encompassing Rect2 of a piece's floor cells, projected to WORLD space via
## the SAME _density_cell_to_world projection used for placement (so the ping-pong reflects
## within the real room in world coordinates). Pure topology, NO RNG. Returns an empty Rect2
## for an empty cell list (the ping-pong then falls back to pure-wall confinement).
func _piece_floor_bounds_world(cells: Array[Vector2i]) -> Rect2:
	if cells.is_empty():
		return Rect2()
	var bounds := Rect2(_density_cell_to_world(cells[0]), Vector2.ZERO)
	for c in cells:
		bounds = bounds.expand(_density_cell_to_world(c))
	return bounds


# --- R1 (M1.1): pursuing hazard spawn ----------------------------------------

## Instantiate r1_spawn_count HazardEntity nodes when R1 is on. Fully gated: with
## r1_enabled == false (or r1_spawn_count == 0) nothing is loaded/instantiated, so the
## all-off control is byte-for-byte the M1.0 loop. J2 (M1.3): the hazards are now
## DISTRIBUTED across depth_index per rc.r1_spawn_distribution (single_gate keeps the
## M1.2 placement; even_spread/curve scatter them) — STEP 1 decides each hazard's depth,
## STEP 2 places one hazard at that depth. Placement is pure run-state on the ALREADY-
## GRADED band (no RNG, never feeds fingerprint()); nodes go into _band_container so
## _clear_band() frees them. setup() binds the run config snapshot + the player (resolved
## via the "player" group — the player is already grouped in player.tscn).
func _spawn_r1_hazards(rc: RunConfig, band: Band) -> void:
	# Gate: R1 off → nothing. With R1 on, the J2 spread (r1_spawn_count) AND the J3 density
	# (r1_per_room_density) are independent budgets — either may be zero. All-off-equivalent
	# (spawn_count 0 AND density 0) instantiates NO node and is byte-identical to M1.2.
	if rc == null or not rc.r1_enabled:
		return
	var spawn_count: int = maxi(rc.r1_spawn_count, 0)
	var density_on: bool = rc.r1_per_room_density > 0.0
	if spawn_count <= 0 and not density_on:
		return
	var hazard_scene := load(HAZARD_SCENE_PATH) as PackedScene
	if hazard_scene == null:
		push_error("MainGame: R1 hazard scene missing at %s." % HAZARD_SCENE_PATH)
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D

	# J2 — the spread budget: N hazards distributed across depth_index. Unchanged from J2;
	# skipped entirely (no node) when r1_spawn_count == 0 so density-only runs stay clean.
	if spawn_count > 0:
		# STEP 1 — decide the depth for each of the N hazards (the spread concern).
		var depths: Array[int] = _hazard_spawn_depths(band, rc)   # length == r1_spawn_count
		# STEP 2 — place one hazard at each chosen depth. _hazard_spawn_position(band, depth,
		# index) is the stable per-depth placement helper J3 reuses (§A.4 shared-seam contract).
		for i in spawn_count:
			var hz := hazard_scene.instantiate() as HazardEntity
			_band_container.add_child(hz)
			var pos: Vector2 = _hazard_spawn_position(band, depths[i], i)
			hz.global_position = pos
			# M1.7 interp-ghost fix: reset so the hazard doesn't render one interpolated frame
			# from origin to its spawn position (hazard spawn ghost). Render-only.
			hz.reset_physics_interpolation()
			# L2 (M1.5): thread the pursuer's spawn-room bounds (the owning piece's floor-cell
			# bbox in world space) so r1_spawn_room_only can confine its patrol + gate its chase.
			# Resolved from the placed position (the J2 path discards the chosen cell). Empty
			# Rect2 when no owning piece is found → the entity falls back to chase-everywhere.
			hz.setup(rc, player, { "room_bounds": _piece_bounds_at_world(band, pos) })

	# J3 — the per-room density budget: extra hazards seeded per room, scaled by room size.
	# Additive on top of J2's population. Skipped entirely (no node) when density is off.
	if density_on:
		_populate_room_density(band, rc, hazard_scene, player)


# --- J3 (M1.3): per-room size-scaled hazard density --------------------------

## Seed EXTRA hazards per room, scaled by each room's size, additively on top of J2's
## spread budget (G4 §5 F3b "a hazard per room" — big rooms aren't empty fields). For each
## eligible piece: n = floor(r1_per_room_density * area / R1_DENSITY_AREA_UNIT), capped per
## room and band-wide, placed across THAT room's own floor cells. DETERMINISTIC — walks
## pieces depth-sorted then stable cell order, integer-index, NO RNG (same band+rc → byte-
## identical positions). These are ordinary HazardEntities (reuse _hazard_spawn_position for
## floor-cell selection); a density hazard wakes by the same depth/linger rules as any R1
## hazard (no new wake rule — Q F). Nodes go into _band_container so _clear_band() frees them.
func _populate_room_density(band: Band, rc: RunConfig, hazard_scene: PackedScene, player: Node2D) -> void:
	# Instantiate one HazardEntity per planned world position. The PLAN is a pure,
	# deterministic function of (band, rc) (see _density_spawn_positions) — this loop is the
	# only impure half (scene-tree mutation), so the budget/placement logic stays unit-testable.
	# L2 (M1.5): _density_spawn_bounds returns the owning piece's room bounds PARALLEL to the
	# position plan (same iteration / order / length) so the J3 golden-position contract
	# (test_per_room_density.gd (f2)) stays byte-identical — the positions list is untouched.
	var positions: Array[Vector2] = _density_spawn_positions(band, rc)
	var bounds: Array[Rect2] = _density_spawn_bounds(band, rc)
	for i in positions.size():
		var hz := hazard_scene.instantiate() as HazardEntity
		_band_container.add_child(hz)
		hz.global_position = positions[i]
		# M1.7 interp-ghost fix: reset so the density hazard doesn't render one interpolated
		# frame from origin to its spawn position (hazard spawn ghost). Render-only.
		hz.reset_physics_interpolation()
		# L2: thread this density hazard's spawn-room bounds (empty Rect2 if the parallel
		# plan came up short → entity falls back to chase-everywhere — never crashes).
		var rb: Rect2 = bounds[i] if i < bounds.size() else Rect2()
		hz.setup(rc, player, { "room_bounds": rb })


## L2 (M1.5): the per-room density room-bounds PLAN — one Rect2 (the owning piece's floor-
## cell bbox in world space) PARALLEL to _density_spawn_positions (same iteration order +
## length), so position[i] and bounds[i] describe the same hazard. Kept SEPARATE from
## _density_spawn_positions (rather than merging the return) so that helper's byte-frozen
## Array[Vector2] golden contract (test_per_room_density.gd) is untouched. Pure run-state,
## NO RNG (mirrors the position plan exactly). Re-walks the same loop; each room contributes
## its single _piece_floor_bounds_world(cells) once per hazard it spawns.
func _density_spawn_bounds(band: Band, rc: RunConfig) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if rc == null or rc.r1_per_room_density <= 0.0:
		return out
	var per_room_cap: int = rc.r1_density_per_room_cap
	var min_area: int = maxi(rc.r1_density_min_area, 0)
	var spawned_total: int = 0
	for p in _density_pieces_sorted(band):
		if spawned_total >= RunConfig.R1_DENSITY_BAND_CEILING:
			break
		if rc.r1_density_rooms_only and _is_corridor(p.piece_id):
			continue
		var cell_area: int = p.floor_cells.size()
		if cell_area <= min_area:
			continue
		var area: float = _density_area(p, rc)
		var n: int = int(floor(rc.r1_per_room_density * area / float(RunConfig.R1_DENSITY_AREA_UNIT)))
		if per_room_cap > 0:
			n = mini(n, per_room_cap)
		n = mini(n, RunConfig.R1_DENSITY_BAND_CEILING - spawned_total)
		if n <= 0:
			continue
		# The whole room's bbox (one value, repeated for each of this room's n hazards) —
		# every density hazard in this room shares its room's bounds. Computed from the SAME
		# sorted cells the position plan strides, so it is the real room rect in world space.
		var room_bounds: Rect2 = _piece_floor_bounds_world(_density_sorted_cells(p))
		for _k in n:
			out.append(room_bounds)
			spawned_total += 1
	return out


## L2 (M1.5): resolve the spawn-room bounds for a hazard placed at `world_pos` (the J2
## spread path, which discards the chosen cell). Finds the piece whose floor_cells contain
## the band-global cell under `world_pos` and returns its floor-cell bbox in world space
## (the SAME _piece_floor_bounds_world projection the J3 + K5i seams use). Returns an empty
## Rect2 if no owning piece is found → the entity falls back to chase-everywhere (RD-4).
## Pure topology, NO RNG (never feeds fingerprint()).
func _piece_bounds_at_world(band: Band, world_pos: Vector2) -> Rect2:
	var cell := Vector2i((world_pos / float(_band_cell_size_px)).floor())
	for p in band.pieces:
		if p.depth_index < 0:
			continue
		if p.floor_cells.has(cell):
			return _piece_floor_bounds_world(_density_sorted_cells(p))
	return Rect2()


## The deterministic per-room density PLAN: the ordered world positions of every density
## hazard for (band, rc), with NO RNG and NO node state — so the same (band, rc) yields a
## byte-identical list every call (the J3 determinism contract). For each eligible piece it
## computes n = floor(r1_per_room_density * area / R1_DENSITY_AREA_UNIT), applies the per-room
## cap + the band-wide ceiling, and strides the n hazards across THAT room's own sorted floor
## cells. Mirrors J2's _hazard_spawn_depths split (pure plan + thin instantiate loop) so the
## J3 test drives this directly against a hand-built graded band (test_per_room_density.gd).
func _density_spawn_positions(band: Band, rc: RunConfig) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if rc == null or rc.r1_per_room_density <= 0.0:
		return out
	var per_room_cap: int = rc.r1_density_per_room_cap   # 0 = uncapped
	var min_area: int = maxi(rc.r1_density_min_area, 0)   # CELL-area floor (room-shape gate)
	var spawned_total: int = 0                            # band-wide ceiling accumulator (Q E)

	# Walk pieces in a stable, depth-sorted then piece-order sequence so placement (and the
	# band-ceiling truncation) is reproducible run-to-run, independent of band.pieces order.
	for p in _density_pieces_sorted(band):
		if spawned_total >= RunConfig.R1_DENSITY_BAND_CEILING:
			break
		# Optional corridor exclusion (rooms_only): skip piece_corridor*/piece_hall_v.
		if rc.r1_density_rooms_only and _is_corridor(p.piece_id):
			continue
		# Min-area gate is always on CELL area (a room-shape gate, not pixels), so corridors
		# and small boxes stay empty until genuinely big regardless of the metric.
		var cell_area: int = p.floor_cells.size()
		if cell_area <= min_area:
			continue
		var area: float = _density_area(p, rc)            # cell_area or px_area per the metric
		var n: int = int(floor(rc.r1_per_room_density * area / float(RunConfig.R1_DENSITY_AREA_UNIT)))
		if per_room_cap > 0:
			n = mini(n, per_room_cap)
		# Band-wide ceiling truncation: never exceed the global cap even mid-room.
		n = mini(n, RunConfig.R1_DENSITY_BAND_CEILING - spawned_total)
		if n <= 0:
			continue
		# Spread the room's n hazards across ITS OWN floor cells, index-deterministic — even
		# fractions across the sorted cells (no RNG). Reuses the same stable (y, x) cell order
		# JunkPlacer + _hazard_spawn_position use, so the placement is reproducible.
		var cells: Array[Vector2i] = _density_sorted_cells(p)
		var stride: int = maxi(cells.size() / maxi(n, 1), 1)
		for k in n:
			var cell: Vector2i = cells[(k * stride) % cells.size()]
			out.append(_density_cell_to_world(cell))
			spawned_total += 1
	return out


## The area scalar that scales the per-room budget. cell_area (default) is floor_cells.size()
## — SIZE-INVARIANT (a 40× room holds a fixed count per room-shape, the Director's choice).
## px_area multiplies by lvl_size_mult^2 so density grows with the on-screen room size (a
## swept option; the per-room + band caps keep it bounded). lvl_size_mult is a pure pixel
## projection (it does NOT change floor_cells.size()), so px_area is the correct screen-area.
func _density_area(p: PlacedPiece, rc: RunConfig) -> float:
	var cells := float(p.floor_cells.size())
	if rc.r1_density_metric == 1:                         # px_area
		var m := rc.lvl_size_mult if rc.lvl_enabled else 1.0
		return cells * m * m
	return cells                                          # cell_area (size-invariant)


## True iff `id` is a corridor piece (piece_corridor*/piece_hall_v) — used by rooms_only to
## exclude corridors from density. Matches the ext-catalog corridor id prefixes (J3 §(a)).
func _is_corridor(id: StringName) -> bool:
	return String(id).begins_with("piece_corridor") or id == &"piece_hall_v"


## Pieces in a stable, deterministic order for density placement: depth_index ascending, then
## by offset_cell (y, x) as a tiebreak so two pieces at the same depth keep a fixed order.
## (The band-ceiling truncation then bites the deepest/last pieces, reproducibly.)
## M1.9 (S3): thin forwarder — the SINGLE copy lives in EncounterBuilder (§2.6.d: the
## builder's K5 walk and the retained R1/J2/J3 lanes must not drift apart on two sort
## lambdas). Kept, same signature, so the R1 lane + the committed golden tests
## (test_per_room_density / test_new_hazard_spawn / test_rg1_m13_verify) call one
## implementation unmodified.
func _density_pieces_sorted(band: Band) -> Array[PlacedPiece]:
	return EncounterBuilder.pieces_depth_sorted(band)


## A piece's walkable floor cells in the SAME stable (y, x) order JunkPlacer uses, so the
## density placement draw is reproducible regardless of authored cell order.
## M1.9 (S3): thin forwarder to the hoisted single copy (see _density_pieces_sorted).
func _density_sorted_cells(p: PlacedPiece) -> Array[Vector2i]:
	return EncounterBuilder.piece_sorted_cells(p)


## Band-global cell → world pixel, centred (same projection as _hazard_spawn_position).
func _density_cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * _band_cell_size_px) \
		+ Vector2(_band_cell_size_px, _band_cell_size_px) * 0.5


## J2 (M1.3): the list of depths (one per hazard, length == rc.r1_spawn_count) the N
## hazards spawn at. DETERMINISTIC — a pure function of band topology (depth_index /
## band.max_depth) + the config, NO RNG. This is what makes the spread comparable run-to-
## run AND keeps it physically downstream of fingerprint() (it reads the graded band; it
## never writes the generator). single_gate reproduces the M1.2 single-threshold placement
## exactly so the all-off control + M1.2-comparable cohort stay byte-identical.
func _hazard_spawn_depths(band: Band, rc: RunConfig) -> Array[int]:
	var max_depth := _band_max_depth(band)
	var out: Array[int] = []
	var n: int = rc.r1_spawn_count
	match rc.r1_spawn_distribution:
		1:  # even_spread (F2) — spread N across [min .. max] inclusive, as evenly as possible.
			var lo: int = clampi(rc.r1_spread_min_depth, 0, max_depth)
			var span: int = maxi(max_depth - lo, 0)
			for i in n:
				# Even fractional placement across the inclusive [lo, max] span, rounded.
				var t: float = 0.5 if n <= 1 else float(i) / float(n - 1)
				out.append(lo + int(round(t * float(span))))
		2:  # curve (built but preset-OFF, §C-Q1) — bias deeper via pow(t, 1.6).
			var lo2: int = clampi(rc.r1_spread_min_depth, 0, max_depth)
			var span2: int = maxi(max_depth - lo2, 0)
			for i in n:
				var t2: float = 0.0 if n <= 1 \
					else pow(float(i) / float(n - 1), 1.6)   # exponent > 1 → clusters deep
				out.append(lo2 + int(round(t2 * float(span2))))
		_:  # 0 = single_gate (default) — M1.2 behaviour: every hazard at the clamped threshold.
			var d: int = clampi(rc.r1_depth_threshold, 0, max_depth)
			for _i in n:
				out.append(d)
	return out


## J2 (M1.3, Phase-3 Q3): the band's deepest graded depth. DepthGrader.grade() sets
## band.max_depth (depth_grader.gd:47) during generation, well before this spawn seam runs
## — it is the single source of truth and equals the old local band.pieces scan. Reading it
## here keeps the helper cheap and removes a duplicate scan.
func _band_max_depth(band: Band) -> int:
	return band.max_depth


## World position to spawn hazard `index` at: a floor cell on the piece(s) at `depth`
## (clamped to the deepest graded piece if it exceeds the band's max depth). Band-global
## cell space shares the world origin (pieces materialise at offset_cell * cell_size), so
## cell → world is a flat scale. Falls back to the entry spawn if no graded floor cell is
## found. J2 (M1.3): the middle arg is now a concrete `depth` (was `depth_threshold`) so
## _hazard_spawn_depths can target any depth; the within-depth index%cells wrap is unchanged
## (two hazards landing on the same depth still spread across that depth's floor cells). This
## signature is the stable internal API J3 (per-room density) reuses (§A.4 shared-seam).
func _hazard_spawn_position(band: Band, depth: int, index: int) -> Vector2:
	var target_depth: int = clampi(depth, 0, _band_max_depth(band))
	# Collect floor cells of pieces at the target depth (in piece order for determinism).
	var cells: Array[Vector2i] = []
	for p in band.pieces:
		if p.depth_index == target_depth:
			for c in p.floor_cells:
				cells.append(c)
	if cells.is_empty():
		return _entry_spawn_position(band)
	# Spread multiple hazards across the available floor cells (wrap on overflow).
	var cell: Vector2i = cells[index % cells.size()]
	return Vector2(cell * _band_cell_size_px) \
		+ Vector2(_band_cell_size_px, _band_cell_size_px) * 0.5


# --- Run-end handling --------------------------------------------------------

func _on_run_ended(_reason: StringName, _duration_s: float, _depth_reached: int) -> void:
	# J4 (M1.3): emit the corridor-time summary for this run (corridor vs. room seconds) so
	# Telemetry writes a dedicated additive `corridor_summary` JSONL row (no run_ended arity
	# change, no schema bump). Fires on EVERY run end (extract/death/timeout) — run_ended is
	# the single resolve point for all three. The accumulators reset on the next run's
	# _build_cell_depth_map (run-state, never persisted).
	EventBus.corridor_time_summary.emit(_corridor_time_s, _room_time_s)
	# M1.6 (M2): the run is over → the App router observes this same run_ended and
	# AUTO-RETURNS to the Hub (app.gd:_on_run_ended, deferred one frame), where the
	# Hub-return beat (hub.gd) evaluates the quota off the held bank and wipes on a MISS.
	# main_game does NOT emit returned_to_hub itself (the router is the single owner of
	# the return — a second emit would double-fire it) and no longer presents a SellScreen
	# (sell moved to M3's Shop; the haul is held-banked in meta until then). We just freeze
	# the player so it can't keep sliding in the frame before the scene swaps.
	if _player != null:
		_player.velocity = Vector2.ZERO


# --- Band materialisation ----------------------------------------------------

## Add each placed piece's instance to the world at its integer cell offset (pixels
## only here, at instance time — the layout itself stayed in integer-cell space).
## Returns the band cell size for world-space math.
##
## I1 (M1.2): `cell_size` is the EFFECTIVE px-per-cell (= round(16 * lvl_size_mult),
## resolved by the caller from the run config). It does TWO things at once: re-spaces
## pieces at offset_cell * cell_size AND scales each piece's visuals/collision to match
## (p.instance.scale = mult) so a piece authored at 16 px/cell fills its scaled lane.
## The cell-space `band` and band.fingerprint() are untouched — this is pure pixel
## projection. The SocketSealer needs NOTHING extra: it seals in cell space inside each
## piece's own Geometry layer, so its WALL caps inherit p.instance.scale for free
## (Resolved "moot"). With lvl off / mult 1.0, cell_size == DEFAULT and scale == 1.
func _materialise_band(band: Band, cell_size: int = DEFAULT_CELL_SIZE_PX) -> int:
	# The per-piece authored base cell size (16 in B1). The scale factor is the ratio of
	# the effective cell size to the authored one, so collision + visuals match the lane.
	for p in band.pieces:
		if p.instance == null:
			# M1.10 (T1): a synthetic (cave-backend) piece carries floor_cells but NO
			# authored scene (backend is deliberately scene-free so the pipeline tests stay
			# headless-pure). Build its greybox instance HERE at materialise time — a runtime
			# ZonePiece host + generated Geometry TileMapLayer with FLOOR tiles only; the
			# SocketSealer below then writes the WALL shell (§2.2/§3.2, D-RAT-8). Socket bands
			# NEVER hit this branch (BandGenerator always instantiates a ZonePiece scene, so
			# p.instance != null on every socket piece), so the legacy path is byte-identical.
			if p.floor_cells.is_empty():
				continue                              # defensive: the legacy null-skip, kept
			p.instance = _build_synthetic_piece(p)    # the ONLY new statement on the piece walk
		var base_cell := p.instance.cell_size_px if p.instance.cell_size_px > 0 else DEFAULT_CELL_SIZE_PX
		var mult := float(cell_size) / float(base_cell)
		p.instance.position = Vector2(p.offset_cell * cell_size)
		p.instance.scale = Vector2.ONE * mult
		_band_container.add_child(p.instance)
	# BUG3: seal every unmated socket so the band is a closed play space (the player
	# can't walk through an uncapped opening into off-map void). Runs AFTER pieces are
	# parented, reading the already-final deterministic band — adds only WALL collision
	# geometry, no pieces, no RNG, so band.fingerprint() is untouched. The seal is in
	# cell space inside each owner piece, so the cap inherits the piece's scale; the
	# px arg is informational only (the sealer ignores it).
	SocketSealer.new().seal_unused_sockets(band, cell_size)
	return cell_size


## M1.10 (T1): build the runtime greybox host for ONE synthetic (cave) piece. The node
## contract mirrors an authored ZonePiece scene EXACTLY — a "Geometry" TileMapLayer child
## (the name SocketSealer._place_wall_cap / WearDecay._write_cell key on) plus an empty
## "Sockets" holder (silences ZonePiece._ready's warning) — so the unedited sealer, the
## I1 scale path, and (later) the flavor write/revert stages all work verbatim over it.
## Writes FLOOR tiles ONLY (atlas (0,0), collisionless); the SocketSealer contributes the
## entire WALL shell after parenting (§2.2/§3.2). Pure function of the piece's cell data:
## no RNG, no floor_cells mutation — so Band.fingerprint()/floor_fingerprint() are byte-
## stable across materialise, exactly as the sealer's own determinism discipline requires.
func _build_synthetic_piece(p: PlacedPiece) -> ZonePiece:
	var host := ZonePiece.new()                     # typed slot: PlacedPiece.instance is ZonePiece
	host.piece_id = p.piece_id                       # @export defaults to &"unnamed" — must overwrite
	host.cell_size_px = DEFAULT_CELL_SIZE_PX         # authored-base 16; the caller's mult scales it
	var geo := TileMapLayer.new()
	geo.name = "Geometry"                            # the name every geometry writer keys on
	geo.tile_set = load(GREYBOX_TILESET_PATH)
	for cell in p.floor_cells:                        # band-global -> piece-local (the offset_cell invariant)
		geo.set_cell(cell - p.offset_cell,
				ConnectivityGuarantee.GREYBOX_SOURCE_ID, ConnectivityGuarantee.FLOOR_ATLAS)
	host.add_child(geo)
	var sockets := Node2D.new()
	sockets.name = "Sockets"                          # empty holder: no sockets in a cave
	host.add_child(sockets)
	return host


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
	# J4 (M1.3): reset the per-run corridor/room time accumulators (run-state, like
	# Telemetry's bookkeeping). _build_junction_map already populated _piece_kind_by_index.
	_corridor_time_s = 0.0
	_room_time_s = 0.0


## R4 (M1.1): flatten per-piece junction degree into a per-cell lookup. A piece's
## junction_degree = the number of DISTINCT neighbouring pieces it connects to via a
## walkable doorway (FLOOR cells 4-adjacent across a piece boundary) — the same
## adjacency the generator's is_band_connected uses. 2 = pass-through corridor,
## ≥3 = a real branch/intersection. Used only to emit nav_branch_taken on entry.
func _build_junction_map(band: Band) -> void:
	_cell_to_junction.clear()
	# J4 (M1.3): classify each piece's kind (corridor vs. room) ONCE here, in the same pass,
	# keyed by piece index. Hardcoded RunConfig.CORRIDOR_PIECE_IDS on PlacedPiece.piece_id (the
	# generator-populated id; NO aspect-ratio fallback — it mis-classifies the 6×6 L-bend, and
	# size_cells isn't authoritative pre-_ready). One source of truth shared with the weight lever.
	_piece_kind_by_index.clear()
	for i in band.pieces.size():
		_piece_kind_by_index[i] = RunConfig.CORRIDOR_PIECE_IDS.has(band.pieces[i].piece_id)
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
	# K6 (M1.4): level-owned camera follow. The rig copies the player's position on the
	# physics tick (the same clock the player integrates on); physics interpolation
	# (project.godot [physics]) smooths the render between ticks, which — together with the
	# camera no longer being a child of the physics body — is the jitter fix. Done every
	# tick (not gated on run_active) so the view tracks the player exactly as the old
	# child-of-body camera did. Camera2D position_smoothing (kept @8.0, K6 RD-4) still
	# applies the trail feel on top, now smoothing an interpolated transform.
	if _camera_rig != null and _player != null:
		_camera_rig.global_position = _player.global_position
	if not GameState.run_active:
		return
	# J4 (M1.3): accumulate corridor/room time EVERY frame (exact, NOT a tick-sampled
	# approximation), keyed by the player's current piece kind. Runs BEFORE the depth-tick
	# throttle so it captures every frame. Guards _player_piece_index < 0 (frame 0 / mid-
	# doorway) → attributed to neither bucket, which is fine (corridor_frac is a ratio).
	_accumulate_piece_time(delta)
	_depth_tick_accum += delta
	if _depth_tick_accum < depth_tick_interval:
		return
	_depth_tick_accum = 0.0
	_resolve_player_depth()


## J4 (M1.3): add `delta` to the corridor or room bucket for the player's current piece. The
## piece-kind lookup uses _piece_kind_by_index (built in _build_junction_map); _player_piece_index
## is kept current by _update_player_piece (hoisted OUT of the R4 gate so this works R4-off too).
func _accumulate_piece_time(delta: float) -> void:
	if _player_piece_index < 0:
		return   # not yet resolved into a piece (frame 0 / mid-doorway) — attribute to neither
	if bool(_piece_kind_by_index.get(_player_piece_index, false)):
		_corridor_time_s += delta
	else:
		_room_time_s += delta


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
	# J4 (M1.3): update "which piece am I in" UNCONDITIONALLY (the hoist) so corridor-time
	# works with R4 off (the all-off control + the M1.0/M1.1/M1.2 baseline all run R4 off).
	# This used to live inside the R4-gated _maybe_emit_branch_taken; now ONE source of truth
	# tracks the piece, and only the nav_branch_taken EMIT stays R4-gated.
	var entered_new_piece := _update_player_piece(cell)
	# R4 (M1.1): junction-entry detection for nav_branch_taken — when the player crosses into a
	# NEW piece whose junction_degree ≥ 2 (a real fork), emit once. Only fires while R4 enabled.
	_maybe_emit_branch_taken(cell, entered_new_piece)


## J4 (M1.3): update _player_piece_index from the player's current cell, UNCONDITIONALLY (no R4
## gate). Returns true iff the player crossed into a NEW piece this resolve (so the R4 emit can
## fire exactly once per piece-entry). Off-floor cells (mid-doorway / wall edge) are not in
## _cell_to_junction → keep the last known piece (never spuriously reset), like the depth driver.
func _update_player_piece(cell: Vector2i) -> bool:
	if not _cell_to_junction.has(cell):
		return false
	var piece_index: int = _cell_to_junction[cell].x
	if piece_index == _player_piece_index:
		return false   # same piece — no new entry
	_player_piece_index = piece_index
	return true


## R4: emit nav_branch_taken(depth, junction_degree) exactly once per junction-entry.
## A junction-entry = the player's owning piece changed (entered_new_piece, resolved by
## _update_player_piece) to a piece with ≥2 distinct neighbouring pieces (a fork/intersection).
## Only the EMIT is R4-gated now (J4 hoisted the piece-index tracking out); staying within a
## piece never re-emits because _update_player_piece returns false then.
func _maybe_emit_branch_taken(cell: Vector2i, entered_new_piece: bool) -> void:
	var rc := GameState.active_run_config
	if rc == null or not rc.r4_enabled:
		return
	if not entered_new_piece:
		return
	if not _cell_to_junction.has(cell):
		return
	var junction_degree: int = _cell_to_junction[cell].y
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


## M1.10 (T1, D-RAT-7) / M1.11 (U1): the pinned/near-spawn gate position. Guard is
## ALLOWLIST-form (was denylist `!= "cave"` in the two-backend world): socket bands —
## whose authored entry pieces make the fixed offset historically safe — and the
## null-profile harness paths return EXACTLY today's fixed offset spawn_pos +
## GATE_SPAWN_OFFSET; the guard short-circuits before any band walk, so byte-identity is
## by inspection and the untouched suites prove it. EVERY synthetic backend (cave +
## scatter + future) falls through to the SNAP to the NEAREST floor cell — the offset
## cell can be wall/void/cover on generated layouts — deterministic tie-break
## (dist², y, x) via Vector3i's lexicographic <, pure geometry over floor_cells, ZERO RNG,
## run-state only (never enters fingerprint()). gate-at-deepest would invert the extraction
## loop on the play preset (the pinned gate is likely the only gate) — snap keeps the "way
## home near where you came in" contract uniform across backends. When the offset cell IS
## floor the snap degenerates to the identical cell centre (d2 == 0), so it only acts on
## layouts that would otherwise softlock.
func _pinned_gate_pos(band: Band, spawn_pos: Vector2) -> Vector2:
	var want := spawn_pos + GameState.GATE_SPAWN_OFFSET
	if _band_profile == null or _band_profile.backend == "socket":
		return want                                  # socket / harness path: today's exact value
	var want_cell := _world_to_cell(want)
	var best := want_cell
	var best_key := Vector3i(2147483647, 0, 0)
	var found := false
	for piece in band.pieces:
		for c in piece.floor_cells:
			var d2: int = (c - want_cell).length_squared()
			var key := Vector3i(d2, c.y, c.x)        # dist², then (y, x) — a total order, seed-stable
			if not found or key < best_key:
				best = c
				best_key = key
				found = true
	return _density_cell_to_world(best) if found else want


## K7 (M1.4): place ONE OR MORE extract gates. The all-off control (exit_enabled=false,
## or no active config) is byte-identical to M1.3 — a single gate at spawn_pos +
## GATE_SPAWN_OFFSET. With exit_enabled, the count scales with band depth and gates are
## placed across the band's floor cells via a LOCAL sub-stream (run-state, no global RNG →
## fingerprint() is untouched). `band` supplies the floor-cell candidate pool. The gate is
## dumb: each instance just calls extract_and_end_run on interact (first-to-resolve wins).
func _place_gate(band: Band, spawn_pos: Vector2, rc: RunConfig) -> void:
	# rc is passed in (BUG10) — caller hands the run's resolved config, since
	# GameState.active_run_config is not staged yet when this runs during start_new_run.

	# --- All-off control: exactly today's single fixed gate (no RNG, no candidate pool). ---
	if rc == null or not rc.exit_enabled:
		_spawn_gate_at(_pinned_gate_pos(band, spawn_pos))   # synthetic backends: snap-to-floor (D-RAT-7); socket: today's value
		EventBus.exits_placed.emit(1, _band_max_depth(band))
		return

	# --- exit_enabled: depth-scaled count of gates placed across the level. ---
	var depth: int = _band_max_depth(band)                       # band.max_depth (band.gd:37)
	var count: int = _exit_count_for_depth(rc, depth)            # >= 1

	var positions: Array[Vector2] = []

	# exit_keep_one_at_spawn: pin ONE gate at the legacy offset, place the rest in the level.
	if rc.exit_keep_one_at_spawn:
		positions.append(_pinned_gate_pos(band, spawn_pos))   # synthetic backends: snap-to-floor (D-RAT-7); socket: today's value

	var remaining: int = count - positions.size()
	if remaining > 0:
		positions.append_array(_exit_placement_positions(band, rc, remaining, spawn_pos))

	for pos in positions:
		_spawn_gate_at(pos)
	EventBus.exits_placed.emit(positions.size(), depth)


## Thin instantiate helper (the body of the old _place_gate). One ExtractGate, into
## _band_container, at a world position. Every gate keeps interactable_id = &"gate" (DR-6):
## same-id gates do NOT cross-fire — each acts only when the focused Interactable is its own
## child (the node-identity guard at extract_gate.gd:45), and the first to resolve wins via
## GameState._run_ended. Do NOT introduce per-gate ids — the shared id is not a bug.
func _spawn_gate_at(world_pos: Vector2) -> void:
	var gate_scene := load(GATE_SCENE_PATH) as PackedScene
	if gate_scene == null:
		push_error("MainGame: gate scene missing at %s." % GATE_SCENE_PATH)
		return
	var gate := gate_scene.instantiate() as ExtractGate
	_band_container.add_child(gate)
	gate.global_position = world_pos
	# M1.7 interp-ghost fix: reset so the gate doesn't render one interpolated frame from
	# origin to its placed world position (gate spawn ghost). Render-only.
	gate.reset_physics_interpolation()
	_gates.append(gate)


## K7: how many exits at this band's depth (DR-2). base + per-depth ramp, FLOORED AT 1
## (a band must ALWAYS have at least one exit — you can never strand the player), capped by
## exit_max_count when > 0, then re-floored at 1 so the cap can never clamp below one. Pure
## read, no RNG. depth = band.max_depth (per-band scaling, not per-piece).
func _exit_count_for_depth(rc: RunConfig, depth: int) -> int:
	var base: int = maxi(rc.exit_base_count, 1)                  # 0 base → treat as 1 (never zero exits)
	var raw: int = base + int(floor(rc.exit_count_per_depth * float(depth)))
	raw = maxi(raw, 1)
	if rc.exit_max_count > 0:
		raw = mini(raw, rc.exit_max_count)
	return maxi(raw, 1)                                          # DR-2: re-floor at 1 AFTER the cap


## K7 Strategy A (DR-1): pick `n` distinct floor cells at random via a LOCAL RNG seeded
## run_seed ^ EXITS_RNG_SALT (B3/E3 pattern — game_state.gd:_resolve_pockets). Reproducible
## per run, NEVER the global RNG autoload (so fingerprint() is untouched). Fisher–Yates over
## a COPY of the stable candidate pool spreads exits across ALL graded pieces, not clustered.
## If the pool is empty (degenerate band) fall back to one fixed gate at the spawn offset; if
## pool.size() < n, return pool.size() distinct cells — do NOT re-sample to force n (would
## stack gates).
func _exit_placement_positions(band: Band, rc: RunConfig, n: int, spawn_pos: Vector2) -> Array[Vector2]:
	var pool: Array[Vector2i] = _exit_candidate_cells(band, spawn_pos)   # stable order, entry/spawn excluded
	if pool.is_empty():
		return [spawn_pos + GameState.GATE_SPAWN_OFFSET]                  # degenerate band → one fixed gate

	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.run_seed ^ GameState.EXITS_RNG_SALT              # local sub-stream, like POCKETS/JUNK
	# Fisher–Yates over a COPY, then take the first n (distinct cells, no global RNG).
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	var out: Array[Vector2] = []
	for k in mini(n, pool.size()):
		out.append(_density_cell_to_world(pool[k]))
	return out


## K7: the band's floor cells eligible to host an exit, in the J3 stable order (depth asc,
## then (y,x)). Excludes the entry-spawn cell and the spawn-offset cell so a gate never lands
## on the player's start or doubles the pinned spawn gate. Deterministic — pure topology.
func _exit_candidate_cells(band: Band, spawn_pos: Vector2) -> Array[Vector2i]:
	var entry_cell: Vector2i = _world_to_cell(spawn_pos)
	# Exclude the SNAPPED pinned cell on caves (same helper the placement uses), the fixed
	# offset cell on socket bands — the guard inside _pinned_gate_pos makes them agree there.
	var spawn_gate_cell: Vector2i = _world_to_cell(_pinned_gate_pos(band, spawn_pos))
	var out: Array[Vector2i] = []
	for p in _density_pieces_sorted(band):                  # depth asc, then (y,x)
		for cell in _density_sorted_cells(p):               # stable (y, x) order
			if cell == entry_cell or cell == spawn_gate_cell:
				continue
			out.append(cell)
	return out


## K7: world position → band-global cell, the inverse of _density_cell_to_world.
func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i((world_pos / float(_band_cell_size_px)).floor())


## Tear down the previous band, gates, spawner and pickups. The player + HUD + sell
## screen persist (they are loop-level, not per-band). Run-state is GameState's to
## reset in start_run; this is pure scene cleanup so old geometry never stacks up.
## The _band_container free disposes the gate nodes; we just reset the list.
func _clear_band() -> void:
	_gates.clear()
	_spawner = null
	# M1.9 (S0): reset the SpawnService's registry + cap accounting with the band. Order-
	# insensitive alongside the container-child free below — both paths queue_free and the
	# service guards with is_instance_valid, so double-freeing is impossible.
	if _spawn_service != null and is_instance_valid(_spawn_service):
		_spawn_service.clear_all()
	for child in _band_container.get_children():
		child.queue_free()


# --- L1 (M1.5): throwing mechanic --------------------------------------------

## Edge-latch for the `throw` action. An analog trigger (RT, L6) bound to the action
## emits a STREAM of InputEventJoypadMotion events while held, each of which reads as
## is_action_pressed — without this latch a single held trigger throws the whole bag in
## a burst. We throw only on the rising edge (press) and re-arm on release. Digital
## inputs (LMB, Space) already fire one press event, so this is a no-op for them.
var _throw_held: bool = false

## Read the `throw` action (Space / LMB / RT — L6). main_game owns the input + the model
## mutation + the projectile spawn so InventoryPanel stays a pure view (it exposes only
## the highlighted_index()/highlighted_item() getters). Inert unless a run is active.
func _unhandled_input(event: InputEvent) -> void:
	if not GameState.run_active:
		return
	if event.is_action_pressed(&"throw"):
		if not _throw_held:
			_throw_held = true
			_try_throw()
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"throw"):
		_throw_held = false


## Throw the highlighted inventory item in the player's aim direction (L6: where the
## player points — mouse / right stick — not the movement direction). Knob-gated:
## with throw_enabled=false this early-returns BEFORE loading the projectile scene, so
## the all-off control is byte-identical to M1.4 (no scene load, no behaviour). Removes
## the item from RunInventory (run-state) — which fires run_inventory_changed → the panel
## re-validates its selector — and spawns a transient projectile under _band_container.
func _try_throw() -> void:
	var cfg: RunConfig = GameState.active_run_config
	if cfg == null or not cfg.throw_enabled:
		return
	if _inventory_panel == null:
		return
	var idx: int = _inventory_panel.highlighted_index()
	if idx < 0:
		return   # empty bag: nothing highlighted → nothing to throw
	var inv: RunInventory = GameState.run_inventory
	if inv == null:
		return
	var item: JunkItem = inv.remove_at(idx)   # fires run_inventory_changed → panel re-validates
	if item == null:
		return   # raced/stale index — abort cleanly (nothing removed)
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		# No player in the tree → re-drop nothing exists to throw from; put the item back.
		inv.try_add(item)
		return
	# L6: throw in the AIM direction (where the player points — mouse / right stick),
	# not the movement direction. player.aim is the decoupled aim vector.
	_spawn_thrown_item(item, player.global_position, player.aim, cfg)
	EventBus.item_thrown.emit(item.id, GameState.current_depth_index, _throw_run_t_ms())


## Instantiate the thrown-item projectile under _band_container (cleared with the band,
## so it's run-state and never leaks). The projectile owns its own travel + hit/miss
## resolution; main_game only spawns + positions it.
func _spawn_thrown_item(item: JunkItem, origin: Vector2, dir: Vector2, cfg: RunConfig) -> void:
	var scene := load(THROWN_ITEM_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("MainGame: thrown-item scene missing at %s." % THROWN_ITEM_SCENE_PATH)
		# Scene missing — don't lose the item: re-drop it where the player stands.
		EventBus.junk_dropped.emit(item, origin)
		return
	var proj := scene.instantiate() as ThrownItem
	_band_container.add_child(proj)
	proj.global_position = origin
	# M1.7 interp-ghost fix: reset so the projectile doesn't render one interpolated frame from
	# origin to the throw start (the thrown-item ghost). Render-only.
	proj.reset_physics_interpolation()
	proj.setup(item, dir, cfg.throw_speed, cfg.throw_max_range, GameState.current_depth_index)


## Monotonic ms for the item_thrown telemetry row (same engine clock the projectile
## uses for its kill/miss rows, so the three rows of one throw share a time base).
func _throw_run_t_ms() -> int:
	return Time.get_ticks_msec()


# --- Menu / consent / sell-loop: DELETED (M1.6 M2 dive-only refactor) ---------
# The Main Menu (M1, scenes/menu/*) now owns the title / Start / Version / first-run
# telemetry consent; the P-debug overlay (M4, ui/config/*) owns the config rail; the
# Hub (M2, scenes/hub/*) is the between-runs surface entered via the App router. So
# main_game no longer has a MainMenu CanvasLayer, a Start button, a ConsentPrompt, or a
# SellScreen — _on_start_pressed / _on_back_to_config / _maybe_show_consent_prompt /
# _on_consent_choice / _show_menu / _hide_menu are all removed. The dive self-starts in
# _ready (start_new_run) and routes to the Hub on run_ended (via the router auto-return).


# --- Seeding -----------------------------------------------------------------

## A fresh seed per run so each dive is a different layout, while staying
## reproducible within a process (run index + a session base). Deterministic enough
## for a playtest; a real meta layer will own seed policy later.
func _next_seed() -> int:
	return (Time.get_unix_time_from_system() as int) * 31 + _run_count * 2654435761
