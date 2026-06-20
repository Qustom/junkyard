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
## I1 (M1.2): the EXTENDED piece catalog (baseline pieces + the new larger greybox
## pieces). Used ONLY when lvl_enabled — a config-dependent catalog swap (Resolved G)
## so adding pieces never moves the all-off baseline fingerprint(): with lvl off the
## baseline catalog is used and the band byte-matches M1.0/M1.1. Each catalog is
## fingerprint-tested independently in test_level_scale_determinism.gd.
const PIECE_CATALOG_EXT_PATH := "res://data/piece_catalog_ext.tres"
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
@onready var _dive_clock: DiveClock = $DiveClock
## M1.1 R2/R3: the two cost-axis oppositions live as PERSISTENT children of the dive
## scene (like DiveClock) — they self-gate per run (their _on_run_started reads
## GameState.active_run_config.rN_enabled and go inert when their opposition is off) and
## reset per run, so a single persistent instance is correct (no per-run spawn/free).
## They connect to EventBus.run_started/run_ended in their OWN _ready(), so once parented
## they react to the run lifecycle automatically. RG1 only injects R2's DiveClock ref.
@onready var _return_cost: ReturnCost = $ReturnCost   # R2 (Costlier Return)
@onready var _exposure_meter: ExposureMeter = $ExposureMeter   # R3 (Exposure Meter)
## M1.1 CFG: the pre-run config rail on the main menu. start_new_run() stages its
## working config (ratified shape (a)); if the node is absent we fall back to the
## all-off default at RUN_CONFIG_PATH so the loop still reaches the M1.0 baseline.
@onready var _config_menu: ConfigMenu = %ConfigMenu

# Loaded fixtures (loaded once; pure data, never mutated here).
var _piece_catalog: Array[ZonePieceData] = []          # baseline catalog (lvl OFF)
var _piece_catalog_ext: Array[ZonePieceData] = []      # extended catalog (lvl ON) — I1
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

# G6: true while the first-run consent modal is up; blocks starting a run until answered.
var _consent_pending: bool = false


func _ready() -> void:
	_load_fixtures()
	# R2 (ReturnCost) charges its `clock` toll through DiveClock.modify_light(); inject the
	# persistent DiveClock node so the export is bound (the .tscn NodePath form proved
	# unreliable for the typed export, so we assign it here per the RG1 spec §1). Null-safe:
	# a config that never selects the clock toll simply skips the charge.
	if _return_cost != null:
		_return_cost.dive_clock = _dive_clock
	_version_label.text = "build %s" % BuildVersion.id()
	_start_button.pressed.connect(_on_start_pressed)
	# W4-11: the production SellScreen only announces intent; G3 owns the restart.
	# Continue from the reward beat loops straight back into a fresh dive (door 2 —
	# reuses the menu's config, no menu shown: the config carry-forward of §2.3).
	_sell_screen.continue_pressed.connect(start_new_run)
	# RG1 (§8 Q2): "Back to Config" re-opens the menu so the Director can switch configs
	# mid-session. The next Start (door 1) re-reads ConfigMenu.apply_and_get_config().
	_sell_screen.back_to_config_pressed.connect(_on_back_to_config)
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
	# I1: the extended catalog is OPTIONAL — if it's missing we silently fall back to
	# the baseline catalog even when lvl is on (so a broken/absent ext catalog never
	# breaks the loop; it just means "no bigger pieces this run").
	var pce = load(PIECE_CATALOG_EXT_PATH)
	if pce != null:
		_piece_catalog_ext = pce.pieces
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
	# the M1.1 determinism key is (seed + config).
	# J1 (M1.3): when there's no CFG rail, fall back to the default play-preset (not the
	# all-off .tres) so a CFG-less launch boots into the same fun stack the CFG path does.
	# Tests that want the all-off control stage RunConfig.new()/the .tres explicitly via
	# GameState.stage_run_config, so the determinism baseline is unaffected.
	var run_cfg: RunConfig = _config_menu.apply_and_get_config() if _config_menu != null else RunConfig.make_default_play_preset()

	# 1. Generate + grade + plan (B2 → B3) — pure functions of (seed + config).
	#    I1 (M1.2): pick the catalog by lvl_enabled (Resolved G — config-dependent
	#    catalog so the all-off baseline fingerprint never moves). lvl off → baseline
	#    catalog (byte-matches M1.0/M1.1); lvl on → extended catalog (the new larger
	#    greybox pieces). Falls back to baseline if the ext catalog is absent.
	var catalog := _piece_catalog
	if run_cfg != null and run_cfg.lvl_enabled and not _piece_catalog_ext.is_empty():
		catalog = _piece_catalog_ext
	var generator := BandGenerator.new()
	var band := generator.generate(seed, _cfg, catalog, run_cfg)
	if band == null or band.pieces.is_empty():
		push_error("MainGame: band generation produced no pieces (seed %d)." % seed)
		return
	var grader := DepthGrader.new()
	grader.grade(band)
	grader.compute_return_distance(band)
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
	var plan := placer.plan(band, _depth_curve, _junk_catalog, false, cell_size_px, loot_density)

	# 2. Materialise the band geometry into the world (instances at cell offsets),
	#    scaling each piece + its spacing by the effective cell size.
	_band_cell_size_px = _materialise_band(band, cell_size_px)

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

	# R1 (M1.1): spawn the pursuing hazard(s). Self-contained, fully gated by the run
	# config — r1_enabled == false (or r1_spawn_count == 0) skips the loop entirely so
	# no hazard node is ever instantiated and the all-off control == M1.0 exactly. The
	# config is readable here (staged + start_run bound it as active_run_config above);
	# we read run_cfg, the same object. Hazards spawn dormant at/near the piece at
	# r1_depth_threshold (§9 Q1; clamped to the deepest piece) and go into
	# _band_container so _clear_band() disposes them with the band for free. setup()
	# binds the config snapshot + the player so the hazard never re-reads active_run_config.
	_spawn_r1_hazards(run_cfg, band)


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
			hz.global_position = _hazard_spawn_position(band, depths[i], i)
			hz.setup(rc, player)

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
	for pos in _density_spawn_positions(band, rc):
		var hz := hazard_scene.instantiate() as HazardEntity
		_band_container.add_child(hz)
		hz.global_position = pos
		hz.setup(rc, player)


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
func _density_pieces_sorted(band: Band) -> Array[PlacedPiece]:
	var pieces: Array[PlacedPiece] = []
	for p in band.pieces:
		if p.depth_index < 0:        # ungraded guard (mirrors _build_cell_depth_map)
			continue
		pieces.append(p)
	pieces.sort_custom(func(a: PlacedPiece, b: PlacedPiece) -> bool:
		if a.depth_index != b.depth_index:
			return a.depth_index < b.depth_index
		if a.offset_cell.y != b.offset_cell.y:
			return a.offset_cell.y < b.offset_cell.y
		return a.offset_cell.x < b.offset_cell.x)
	return pieces


## A piece's walkable floor cells in the SAME stable (y, x) order JunkPlacer uses, so the
## density placement draw is reproducible regardless of authored cell order.
func _density_sorted_cells(p: PlacedPiece) -> Array[Vector2i]:
	var cells := p.floor_cells.duplicate()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	return cells


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
	# The SellScreen (a sibling) presents the reward beat over the paused tree and,
	# on Continue, calls start_new_run(). We just freeze the player so it can't keep
	# sliding under the paused overlay edge cases; start_new_run repositions it.
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
			continue
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


## RG1 (§8 Q2): the SellScreen's "Back to Config" path. The sell screen already
## unpaused + hid itself before emitting, so we only re-show the menu (which carries the
## ConfigMenu rail). The Director edits knobs, then Start → start_new_run() rebinds the
## config (door 1). Quick re-run (Continue) and switch-config (this) are the two doors.
func _on_back_to_config() -> void:
	_show_menu()


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
