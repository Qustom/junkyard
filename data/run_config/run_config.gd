class_name RunConfig
extends Resource
## RunConfig — the single run-scoped configuration object for M1.1's cost-axis
## experiment (M1.1 §R0). It holds EVERY opposition's knobs (R1 pursuing hazard,
## R2 costlier return, R3 exposure meter, R4 maze/nav) as typed, sub-grouped
## fields, each opposition fronted by its own `enabled` master toggle, plus a
## small meta block (seed override, build tag passthrough).
##
## This is the ONE object the pre-run Config menu (CFG) writes and every
## opposition system + MainGame reads at run start, via GameState.active_run_config.
##
## RUN/META BOUNDARY (TDD §2/§3, hard rule): a RunConfig is **run-scoped
## configuration** — it is NOT meta-save state and is NEVER persisted to the
## SaveManager schema. The Config menu produces it; GameState holds it for the
## duration of one run; nothing writes it to meta.sav.
##
## ALL-OFF DEFAULT = M1.0 BASELINE. The default `.tres` (and `RunConfig.new()`)
## has every opposition disabled and every magnitude at zero/neutral, so an
## unconfigured run reproduces the M1.0 loop EXACTLY. That all-off config is the
## permanent in-build control the re-gate (RG2) measures every opposition against.
##
## R0 owns only the *container shape* + the all-off default + the wiring. The
## opposition BEHAVIOURS (R1–R4) are separate tasks that read these knobs; this
## file defines no behaviour.

# =============================================================================
# J3 (M1.3) — per-room density constants (shared by run_config + main_game)
# =============================================================================
## Floor-cell area that earns ONE hazard-unit at density 1.0:
##   n_room = floor(r1_per_room_density * area / R1_DENSITY_AREA_UNIT).
## Sized so a chunky room (≈100+ cells) earns ~1 hazard at density 1.0 while corridors
## (≈32 cells) earn 0 — i.e. density "fills rooms," not corridors, at the preset start.
const R1_DENSITY_AREA_UNIT: int = 96
## Belt-and-braces global ceiling on TOTAL density hazards across the whole band (Q E).
## The per-room cap bounds each room; this bounds the band so a mis-set px_area sweep
## (size 40× ≈ 1600× area) can never spawn an unbounded chasing-body count.
const R1_DENSITY_BAND_CEILING: int = 64
## Junk floor-cell area that earns ONE base-count multiple at loot-density 1.0 (the loot
## sub-knob's per-area unit; mirrors R1_DENSITY_AREA_UNIT for the loot axis).
const LVL_LOOT_AREA_UNIT: int = 96


# =============================================================================
# META — run-scoped, not save-state
# =============================================================================
@export_group("Meta")
## Optional explicit seed for the run. -1 means "none" → the caller picks its own
## seed (MainGame's per-run seed policy is unchanged when this is -1).
@export var seed_override: int = -1
## Optional build-tag passthrough so a labelled experiment can carry its build id
## into telemetry. Empty = let Telemetry derive the build tag as it already does.
@export var build_tag: String = ""

# =============================================================================
# R1 — Pursuing / awakening hazard
# =============================================================================
@export_group("R1 Pursuing Hazard", "r1_")
## Master toggle. OFF = no hazard exists; behaviour matches M1.0.
@export var r1_enabled: bool = false
## Within-band depth at/after which the hazard may awaken.
@export var r1_depth_threshold: int = 0
## Seconds of lingering (time-in-band) that also awakens the hazard.
@export var r1_linger_seconds: float = 0.0
## Flat chase speed once awake (px/s, greybox units).
@export var r1_chase_speed: float = 0.0
## Optional additive chase speed per unit of within-band depth.
@export var r1_speed_per_depth: float = 0.0
## Distance at which the hazard "catches" the player. FLOOR: must be >= player_r +
## hazard_r (= 14 + 10 = 24 px with the I2 bodies) or the bodies physically collide
## before the script distance test can ever trip (re-creates M1.1's caught=0). Suggested
## first-sweep value ~32 (I2 §2.3). Default 0.0 = all-off (no hazard spawned anyway).
@export var r1_catch_radius: float = 0.0
## I2 (M1.2, Q3 accepted): additive catch-radius lunge per unit of within-band depth —
## effective = r1_catch_radius + r1_catch_radius_per_depth * depth. Reinforces
## "deeper = more dangerous" on the CATCH axis (the speed axis already has
## r1_speed_per_depth). Default 0.0 = flat radius = M1.0/M1.1 behaviour (all-off control).
@export var r1_catch_radius_per_depth: float = 0.0
## Whether catching kills outright (death end-cause) vs. inflicting a cost.
@export var r1_catch_kills: bool = false
## How many hazard entities spawn.
@export var r1_spawn_count: int = 0
## J2 (M1.3): how the r1_spawn_count hazards are distributed over depth_index.
##   0 = single_gate  → ALL at r1_depth_threshold (M1.2 behaviour — the all-off-equivalent)
##   1 = even_spread  → spread evenly across [r1_spread_min_depth .. band.max_depth] (F2 fix)
##   2 = curve        → weighted deeper via pow(t, 1.6) (built but preset-OFF, §C-Q1)
## Default 0 (single_gate) keeps the all-off control AND the M1.2-comparable cohort
## byte-identical (same node placement; placement is run-state, never feeds fingerprint()).
@export_enum("single_gate", "even_spread", "curve") var r1_spawn_distribution: int = 0
## J2 (M1.3): shallowest depth that may receive a spread hazard. Clamped to [0, max_depth].
## Below this depth stays a safe entry ramp (the "shallow is safe, then it stirs" arc, I2 §2.4).
## Default 0 = no shallow exclusion (M1.2-equivalent; ignored by single_gate mode).
@export var r1_spread_min_depth: int = 0
## J3 (M1.3): EXTRA hazards seeded PER ROOM, scaled by room size, ADDITIVE on top of
## J2's spread budget (so big rooms aren't empty fields, G4 §5 F3b "a hazard per room").
## n_room = floor(r1_per_room_density * area / R1_DENSITY_AREA_UNIT), capped + min-area
## gated. 0 = OFF (M1.2 behaviour: only J2's r1_spawn_count hazards). DETERMINISTIC, no
## RNG (the room's n hazards spread across its OWN floor cells, index-deterministic). The
## preset sets a non-zero sweep value. NEVER mutates the all-off control (default 0).
@export var r1_per_room_density: float = 0.0
## J3: which area metric scales the per-room budget.
##   0 = cell_area   (floor_cells.size(); SIZE-INVARIANT — N per room shape; perf-safe, the
##                    Director's chosen DEFAULT — a 40× room holds a fixed count per shape)
##   1 = px_area     (cell_area * lvl_size_mult^2; grows with lvl_size_mult — N per screenful;
##                    a swept option, MUST be capped or a 40× room explodes — see the cap below)
@export_enum("cell_area", "px_area") var r1_density_metric: int = 0
## J3: only seed density hazards in ROOM pieces (id not piece_corridor*/piece_hall_v),
## never corridors. false = any piece above the area floor is eligible.
@export var r1_density_rooms_only: bool = false
## J3: floor-cell area a piece must exceed before it earns ANY density hazard (so small
## boxes/corridors stay empty until genuinely big). 0 = no floor. Measured in CELL area
## (floor_cells.size()) regardless of metric — the floor is a room-shape gate, not pixels.
@export var r1_density_min_area: int = 0
## J3 hard cap on density hazards per single room (perf + fun guard). 0 = uncapped. The
## preset MUST set this > 0 (mandatory per Q E) — combined with the global band ceiling it
## bounds the worst case (px_area × size 40× × high density) so a sweep can't explode.
@export var r1_density_per_room_cap: int = 0

# =============================================================================
# R2 — Costlier return trip
# =============================================================================
@export_group("R2 Costlier Return", "r2_")
## Master toggle. OFF = walk-back is free (M1.0 behaviour).
@export var r2_enabled: bool = false
## Mechanism select: 0 = lengthen, 1 = decay_behind, 2 = egress_toll.
## (The R2 spec finalises which mechanism(s) it uses; R0 defines the field.)
@export_enum("lengthen", "decay_behind", "egress_toll") var r2_mechanism: int = 0
## Flat magnitude of the return cost.
@export var r2_cost_magnitude: float = 0.0
## Additive cost scaling per unit of within-band depth (uses B3 dist_to_gate).
@export var r2_cost_per_depth: float = 0.0
## Within-band depth at/after which the return cost starts applying.
@export var r2_depth_threshold: int = 0
## If the mechanism is a toll, which resource it taxes (enum placeholder; the R2
## spec assigns meaning, e.g. 0 = clock, 1 = exposure, 2 = dedicated meter).
@export_enum("clock", "exposure", "meter") var r2_toll_resource: int = 0

# =============================================================================
# R3 — Rising instability / exposure meter
# =============================================================================
@export_group("R3 Exposure Meter", "r3_")
## Master toggle. OFF = no meter / no penalty (M1.0 behaviour).
@export var r3_enabled: bool = false
## Base climb rate of the meter (per second) while in-band.
@export var r3_base_climb_rate: float = 0.0
## Additive climb-rate scaling per unit of within-band depth (deeper = faster).
@export var r3_rate_per_depth: float = 0.0
## Threshold meter levels at which penalties fire (ascending). Empty = no levels.
@export var r3_threshold_levels: PackedFloat32Array = PackedFloat32Array()
## Penalty kind applied at a crossed threshold (enum placeholder for the R3 spec).
@export_enum("none", "speed", "vision", "clock") var r3_penalty_kind: int = 0
## Magnitude of the penalty applied at a crossed threshold.
@export var r3_penalty_magnitude: float = 0.0
## Whether reaching the max meter forces a run loss (timeout end-cause).
@export var r3_max_forces_loss: bool = false
## Meter decay-per-second while retreating shallow (0 = no decay).
@export var r3_decay_on_retreat: float = 0.0

# =============================================================================
# R4 — Maze / navigation risk
# =============================================================================
@export_group("R4 Maze / Navigation", "r4_")
## Master toggle. OFF = linear M1.0 spine, full vision.
@export var r4_enabled: bool = false
## Base branch chance fed to the B2 generator (M1.0 spine is 0.0).
@export var r4_branch_chance_base: float = 0.0
## Additive branch-chance scaling per unit of depth.
@export var r4_branch_per_depth: float = 0.0
## Max within-band depth at which branching/dead-ends may still be produced.
@export var r4_max_branch_depth: int = 0
## Vision radius (px). 0 = full vision (no fog limiting).
@export var r4_vision_radius: float = 0.0
## Per-depth tightening of the vision radius (deeper = less visible).
@export var r4_vision_tighten_per_depth: float = 0.0
## Whether fog-of-war is enabled.
@export var r4_fog_enabled: bool = false
## Lost-proxy threshold (backtrack / no-depth-progress metric) for telemetry.
@export var r4_lost_proxy_threshold: float = 0.0


# =============================================================================
# LVL — Level scale (M1.2 I1): room COUNT override + room SIZE multiplier
# =============================================================================
## Two orthogonal spatial levers the Director sweeps independently (I1). NOT an
## opposition — level scale is a presentation/spatial axis, so it is deliberately
## OUTSIDE all_oppositions_disabled() (Resolved E): a bigger-room run with no
## R-toggles is still a meaningful "baseline + scale" cell RG2 segments on.
##
## ALL-OFF DEFAULT == M1.1 BASELINE: lvl_enabled=false, count=-1 (use the
## BandGenConfig target = 12), mult=1.0 (16 px cells, 128x64 px rooms). With the
## defaults the generator grows the unchanged loop bound (fingerprint byte-matches
## M1.1) and materialisation returns 16 px/cell (pixel-identical to today).
@export_group("Level Scale", "lvl_")
## Master toggle. OFF = baseline count + size + the baseline piece catalog
## (M1.1 spine, 16 px cells). ON unlocks the count/size knobs AND swaps in the
## extended piece catalog (the new larger greybox pieces). Out of
## all_oppositions_disabled() on purpose (orthogonal axis, Resolved E).
@export var lvl_enabled: bool = false
## Room-count override. -1 = "use BandGenConfig.target_piece_count" (baseline 12).
## When >= 1 AND lvl_enabled, this REPLACES the generator's grow-loop target.
@export var lvl_room_count: int = -1
## Room-size multiplier applied at MATERIALISATION (px per cell = round(16 * mult)).
## 1.0 = baseline 16 px cells. > 1.0 = bigger rooms + proportionally bigger spacing
## (so the player crosses a 2x band in ~2x the time — player speed is unscaled).
## Snapped to 0.25 steps in CFG so round(16*mult) is always an exact integer, and
## the SAME effective cell size feeds materialise AND JunkPlacer (no doorway seam,
## no loot mis-placement). Layout-invariant: it does NOT change fingerprint().
@export var lvl_size_mult: float = 1.0
## J3 (M1.3): SECONDARY "fill emptiness with reward" sub-knob — scales JunkPlacer's
## per-piece junk count by room area (big rooms get proportionally more interest). 0 =
## OFF (M1.2 behaviour: the depth curve's flat ~2 count only). Rides JunkPlacer's local
## _JUNK_SALT sub-stream (reproducible from seed+config, never the global RNG). Built but
## SHIPS OFF and is NEVER preset-on — it directly contradicts depth_curve.gd's "don't
## flood deep rooms" intent (Director B disposition); a swept lever RG2 segments on only.
@export var lvl_loot_density_per_area: float = 0.0
## J4 (M1.3): the corridor-RARITY lever — multiplies the generator's catalog WEIGHT of the
## corridor pieces (piece_corridor_h/v/l, piece_corridor_long_h, piece_hall_v) by this factor
## so long/dead corridors become rarer/shorter in the weighted piece-pick (Director: GENERATOR
## DOWN-WEIGHT, NOT a materialise re-pack). 1.0 = baseline corridor rarity (M1.2 weight table
## untouched). < 1.0 = fewer corridors, more rooms. Works R4-on (the default preset) since the
## weighted draw runs in both modes. This is a CELL-SPACE change → it MOVES fingerprint() for
## non-neutral configs (allowed under the seed+config contract, like R4 branching); the NEUTRAL
## default (1.0) leaves the weight table byte-identical so the all-off fp stays e943ac9c8bc1.
@export var lvl_corridor_weight_mult: float = 1.0
## J4 (M1.3): bool companion — when true, DROPS the 16-cell long hall (piece_corridor_long_h)
## from the effective catalog by zeroing its weight, forcing only short corridors. false =
## the long hall keeps its catalog weight (M1.2). Also a CELL-SPACE change (moves fingerprint()
## for non-neutral configs); false = neutral = no weight-table change = all-off fp byte-match.
@export var lvl_short_corridors: bool = false


# =============================================================================
# K2 (M1.4) — Per-run quota / roguelite wipe (CONFIG knobs only; the live quota +
# run-number are META-STATE owned by K2's save schema v3, NEVER stored here).
# All-off default = no quota gate, no wipe (M1.3 behaviour). The Director-FINAL
# starting value ($50) + step (+$50/run) live in make_default_play_preset(), NOT
# the code-level default, so the all-off control stays byte-identical.
# =============================================================================
@export_group("K2 Quota", "quota_")
## Master toggle. OFF = no quota gate, no wipe (M1.3 behaviour).
@export var quota_enabled: bool = false
## Starting quota for run #1 (Director FINAL $50 — set in the preset, not the default).
@export var quota_base: int = 0
## How much the quota rises each time it is met (Director FINAL +$50/run — preset).
@export var quota_step: int = 0
## WHEN the quota is checked (Director KEPT this configurable). 0 = on_extract only,
## 1 = every_run_end (Director-FINAL default — set in the preset). Code default 0 is
## the all-off-neutral choice; the preset carries the Director default.
@export_enum("on_extract", "every_run_end") var quota_check_timing: int = 0
## WHAT counts toward "met" (Director KEPT this configurable). 0 = this_run_banked
## (all-off-neutral code default), 1 = cumulative_money (Director FINAL — set in preset).
@export_enum("this_run_banked", "cumulative_money") var quota_basis: int = 0

# =============================================================================
# K3 (M1.4) — Resolution-independent camera (fixed visible world-units). All-off
# default = today's camera (whatever the window shows). Post-generation, never
# fed to fingerprint().
# =============================================================================
@export_group("K3 Camera", "cam_")
## Master toggle. OFF = today's camera (M1.3 behaviour).
@export var cam_enabled: bool = false
## Visible world width (px) the viewport always shows, regardless of resolution.
## 0.0 = use today's behaviour (no fixed-units enforcement).
@export var cam_visible_world_width: float = 0.0
## Zoom policy when window aspect != design aspect:
##   0 = fit_width (lock horizontal units), 1 = fit_height, 2 = contain (letterbox).
@export_enum("fit_width", "fit_height", "contain") var cam_zoom_policy: int = 0

# =============================================================================
# K4 (M1.4) — Configurable dive timer + near-end warning. All-off default = today's
# DiveClockConfig length, no warning (M1.3 behaviour). Post-generation run-state.
# =============================================================================
@export_group("K4 Timer", "timer_")
## Master toggle. OFF = today's DiveClockConfig length, no warning (M1.3 behaviour).
@export var timer_enabled: bool = false
## Dive length (s). 0.0 = use the existing DiveClockConfig default.
@export var timer_length_s: float = 0.0
## Seconds-remaining at which the near-end warning fires ONCE. 0.0 = no warning.
@export var timer_warning_threshold_s: float = 0.0
## Warning channel: 0 = visual_only, 1 = visual+audio (audio gated, M2 stub).
@export_enum("visual_only", "visual_audio") var timer_warning_channel: int = 0

# =============================================================================
# K5a (M1.4) — Ping-pong hazard (bounces off room walls, lethal on contact). The
# spawn-seam knobs (enabled/base_count/count_per_depth/per_room_cap) are read by
# K5i's descriptor table; the type-specific knob (speed) is read by the entity.
# All-off default = no hazard spawned (pure run-state, never feeds fingerprint()).
# =============================================================================
@export_group("K5a Ping-Pong Hazard", "hpp_")
## Master toggle. OFF = no ping-pong hazard exists (M1.3 behaviour).
@export var hpp_enabled: bool = false
## Spawn count at within-band depth 0.
@export var hpp_base_count: int = 0
## Additive count scaling per unit of within-band depth.
@export var hpp_count_per_depth: float = 0.0
## Travel speed (px/s, greybox). Entity-read.
@export var hpp_speed: float = 0.0
## Hard cap on count per room (perf guard). 0 = uncapped (preset MUST set > 0).
@export var hpp_per_room_cap: int = 0

# =============================================================================
# K5b (M1.4) — Bomb hazard (proximity pulse ~2s then explode; kills in radius).
# Spawn-seam knobs read by K5i; the type-specific knobs (proximity/pulse/blast)
# read by the entity. All-off default = no bomb (pure run-state).
# =============================================================================
@export_group("K5b Bomb Hazard", "hbomb_")
## Master toggle. OFF = no bomb hazard exists (M1.3 behaviour).
@export var hbomb_enabled: bool = false
## Spawn count at within-band depth 0.
@export var hbomb_base_count: int = 0
## Additive count scaling per unit of within-band depth.
@export var hbomb_count_per_depth: float = 0.0
## Proximity that starts the pulse (px). Entity-read.
@export var hbomb_proximity_radius: float = 0.0
## Pulse duration before detonation (s; Director ~2s preset). Entity-read.
@export var hbomb_pulse_seconds: float = 0.0
## Lethal radius at detonation (px). Entity-read.
@export var hbomb_blast_radius: float = 0.0
## Hard cap on count per room (perf guard). 0 = uncapped (preset MUST set > 0).
@export var hbomb_per_room_cap: int = 0

# =============================================================================
# K5c (M1.4) — Rotating-spikes hazard (rotates in place, lethal on contact).
# Spawn-seam knobs read by K5i; the type-specific knobs (rotation/arm) read by
# the entity. (Arm count is an in-file const, NOT a knob — Director K5 verdict.)
# All-off default = no spikes (pure run-state).
# =============================================================================
@export_group("K5c Rotating Spikes", "hspike_")
## Master toggle. OFF = no rotating-spikes hazard exists (M1.3 behaviour).
@export var hspike_enabled: bool = false
## Spawn count at within-band depth 0.
@export var hspike_base_count: int = 0
## Additive count scaling per unit of within-band depth.
@export var hspike_count_per_depth: float = 0.0
## Rotation speed (deg/s; signed → direction). Entity-read.
@export var hspike_rotation_speed: float = 0.0
## Reach of the lethal arm (px). Entity-read.
@export var hspike_arm_length: float = 0.0
## Hard cap on count per room (perf guard). 0 = uncapped (preset MUST set > 0).
@export var hspike_per_room_cap: int = 0

# =============================================================================
# K7 (M1.4) — Exit placement rework (random/multiple exits, run-config-keyed for
# determinism via a local sub-stream). All-off default = today's single fixed gate
# at GATE_SPAWN_OFFSET, byte-identical, so the all-off fingerprint never moves.
# K7 enforces determinism (local run_seed ^ salt); K0 only declares the knobs.
# =============================================================================
@export_group("K7 Exits", "exit_")
## Master toggle. OFF = today's single fixed gate (M1.3 behaviour, fp unchanged).
@export var exit_enabled: bool = false
## Base exit count at depth 0. 0 = fall back to the single fixed gate (neutral).
@export var exit_base_count: int = 0
## Additive exit-count scaling per unit of within-band depth.
@export var exit_count_per_depth: float = 0.0
## If true, ONE exit is always pinned at the spawn gate (the rest placed randomly).
@export var exit_keep_one_at_spawn: bool = false
## Hard cap on total exits per band (perf/legibility guard). 0 = uncapped.
@export var exit_max_count: int = 0


## The hardcoded corridor piece-id set (J4) the corridor-rarity lever down-weights and the
## corridor-time telemetry classifies on. Keyed on PlacedPiece.piece_id / ZonePieceData.piece_id
## (the generator-populated id, NOT the pre-_ready size_cells). The aspect-ratio fallback is
## DELIBERATELY DROPPED (Phase-3 correction): the 6×6 L-bend is NOT long-and-thin yet IS a
## corridor, so an aspect rule would mis-classify it as a room. One source of truth, shared by
## band_generator.gd (the weight lever) and main_game.gd (the corridor-time classification).
const CORRIDOR_PIECE_IDS: Dictionary = {
	&"piece_corridor_h": true,
	&"piece_corridor_v": true,
	&"piece_corridor_l": true,
	&"piece_corridor_long_h": true,
	&"piece_hall_v": true,
}
## The single long-hall id lvl_short_corridors drops (the 16-cell corridor — the "boring long
## hallway" the Director named). Kept separate from CORRIDOR_PIECE_IDS so the bool lever targets
## ONLY this piece while the weight-mult down-weights the whole corridor family.
const CORRIDOR_LONG_PIECE_ID: StringName = &"piece_corridor_long_h"


## True iff every opposition master toggle is OFF — i.e. this config reproduces
## the M1.0 baseline. Convenience for callers/tests/telemetry labelling.
## NOTE (I1, Resolved E): lvl_* are deliberately NOT included — level scale is an
## opposition-orthogonal spatial axis. RG2 segments on lvl_size_mult/lvl_room_count
## separately; a "baseline + bigger rooms" run keeps this true.
func all_oppositions_disabled() -> bool:
	return not (r1_enabled or r2_enabled or r3_enabled or r4_enabled)


## The effective px-per-cell for materialisation, snapped to an exact integer.
## ONE place computes it so materialise AND JunkPlacer share the same value (no
## abutting-piece seam / loot mis-placement). With lvl off or mult 1.0 this is the
## baseline px/cell unchanged.
func effective_cell_size_px(base_cell_px: int) -> int:
	if not lvl_enabled:
		return base_cell_px
	return int(round(float(base_cell_px) * lvl_size_mult))


## The effective grow-loop target for the generator: the count override when set,
## else the BandGenConfig baseline (caller passes its cfg.target_piece_count).
func effective_room_count(baseline_count: int) -> int:
	if lvl_enabled and lvl_room_count >= 1:
		return lvl_room_count
	return baseline_count


## Serialize every knob to a flat, JSON-safe Dictionary for TEL to snapshot onto
## the `run_started` row's `data` (additive payload — NOT a schema bump). Flat by
## design: keys are the field names, values are JSON primitives (int/float/bool/
## String/Array of float). TEL wires the call; R0 only provides the method.
func to_flat_dict() -> Dictionary:
	return {
		# meta
		"seed_override": seed_override,
		"build_tag": build_tag,
		# R1
		"r1_enabled": r1_enabled,
		"r1_depth_threshold": r1_depth_threshold,
		"r1_linger_seconds": r1_linger_seconds,
		"r1_chase_speed": r1_chase_speed,
		"r1_speed_per_depth": r1_speed_per_depth,
		"r1_catch_radius": r1_catch_radius,
		"r1_catch_radius_per_depth": r1_catch_radius_per_depth,
		"r1_catch_kills": r1_catch_kills,
		"r1_spawn_count": r1_spawn_count,
		# R1 — J2 (M1.3) depth-spread knobs (additive payload; RG2 reads alongside hazard rows)
		"r1_spawn_distribution": r1_spawn_distribution,
		"r1_spread_min_depth": r1_spread_min_depth,
		# R1 — J3 (M1.3) per-room density knobs (additive payload; RG2 segments density)
		"r1_per_room_density": r1_per_room_density,
		"r1_density_metric": r1_density_metric,
		"r1_density_rooms_only": r1_density_rooms_only,
		"r1_density_min_area": r1_density_min_area,
		"r1_density_per_room_cap": r1_density_per_room_cap,
		# R2
		"r2_enabled": r2_enabled,
		"r2_mechanism": r2_mechanism,
		"r2_cost_magnitude": r2_cost_magnitude,
		"r2_cost_per_depth": r2_cost_per_depth,
		"r2_depth_threshold": r2_depth_threshold,
		"r2_toll_resource": r2_toll_resource,
		# R3
		"r3_enabled": r3_enabled,
		"r3_base_climb_rate": r3_base_climb_rate,
		"r3_rate_per_depth": r3_rate_per_depth,
		"r3_threshold_levels": _packed_to_float_array(r3_threshold_levels),
		"r3_penalty_kind": r3_penalty_kind,
		"r3_penalty_magnitude": r3_penalty_magnitude,
		"r3_max_forces_loss": r3_max_forces_loss,
		"r3_decay_on_retreat": r3_decay_on_retreat,
		# R4
		"r4_enabled": r4_enabled,
		"r4_branch_chance_base": r4_branch_chance_base,
		"r4_branch_per_depth": r4_branch_per_depth,
		"r4_max_branch_depth": r4_max_branch_depth,
		"r4_vision_radius": r4_vision_radius,
		"r4_vision_tighten_per_depth": r4_vision_tighten_per_depth,
		"r4_fog_enabled": r4_fog_enabled,
		"r4_lost_proxy_threshold": r4_lost_proxy_threshold,
		# LVL (M1.2 I1) — level scale (additive payload; RG2 segments on these)
		"lvl_enabled": lvl_enabled,
		"lvl_room_count": lvl_room_count,
		"lvl_size_mult": lvl_size_mult,
		# LVL — J3 (M1.3) loot-per-area sub-knob (additive payload; RG2 segments loot count)
		"lvl_loot_density_per_area": lvl_loot_density_per_area,
		# LVL — J4 (M1.3) corridor-rarity lever (additive payload; RG2 segments corridor_frac)
		"lvl_corridor_weight_mult": lvl_corridor_weight_mult,
		"lvl_short_corridors": lvl_short_corridors,
		# K2 (M1.4) — quota config knobs (additive payload; RG2 segments quota cohorts)
		"quota_enabled": quota_enabled,
		"quota_base": quota_base,
		"quota_step": quota_step,
		"quota_check_timing": quota_check_timing,
		"quota_basis": quota_basis,
		# K3 (M1.4) — camera config knobs
		"cam_enabled": cam_enabled,
		"cam_visible_world_width": cam_visible_world_width,
		"cam_zoom_policy": cam_zoom_policy,
		# K4 (M1.4) — timer + warning config knobs
		"timer_enabled": timer_enabled,
		"timer_length_s": timer_length_s,
		"timer_warning_threshold_s": timer_warning_threshold_s,
		"timer_warning_channel": timer_warning_channel,
		# K5a (M1.4) — ping-pong hazard config knobs
		"hpp_enabled": hpp_enabled,
		"hpp_base_count": hpp_base_count,
		"hpp_count_per_depth": hpp_count_per_depth,
		"hpp_speed": hpp_speed,
		"hpp_per_room_cap": hpp_per_room_cap,
		# K5b (M1.4) — bomb hazard config knobs
		"hbomb_enabled": hbomb_enabled,
		"hbomb_base_count": hbomb_base_count,
		"hbomb_count_per_depth": hbomb_count_per_depth,
		"hbomb_proximity_radius": hbomb_proximity_radius,
		"hbomb_pulse_seconds": hbomb_pulse_seconds,
		"hbomb_blast_radius": hbomb_blast_radius,
		"hbomb_per_room_cap": hbomb_per_room_cap,
		# K5c (M1.4) — rotating-spikes hazard config knobs
		"hspike_enabled": hspike_enabled,
		"hspike_base_count": hspike_base_count,
		"hspike_count_per_depth": hspike_count_per_depth,
		"hspike_rotation_speed": hspike_rotation_speed,
		"hspike_arm_length": hspike_arm_length,
		"hspike_per_room_cap": hspike_per_room_cap,
		# K7 (M1.4) — exit-placement config knobs
		"exit_enabled": exit_enabled,
		"exit_base_count": exit_base_count,
		"exit_count_per_depth": exit_count_per_depth,
		"exit_keep_one_at_spawn": exit_keep_one_at_spawn,
		"exit_max_count": exit_max_count,
	}


## PackedFloat32Array → plain Array[float] so the flat dict is JSON-safe
## (JSON.stringify handles a typed PackedFloat32Array, but a plain Array keeps the
## snapshot portable across any consumer).
func _packed_to_float_array(p: PackedFloat32Array) -> Array:
	var out: Array = []
	for v in p:
		out.append(v)
	return out


# =============================================================================
# BUG6 (M1.3) — config-trap detector (self-contained appended method)
# =============================================================================
## Returns the ids of every opposition whose master toggle is ON but whose
## load-bearing magnitude knob is at its all-off default — i.e. the section reads
## "enabled" yet the mechanism is silently inert. The M1.2 re-gate was invalidated
## precisely because two enabled oppositions ran dead unnoticed (R3 with empty
## thresholds → 0 crossings; R4 with r4_lost_proxy_threshold=0.0 → 0 nav_lost_proxy).
## Surfaced before the run commits via the CFG warn-line (J1 folds it into
## config_menu) AND stamped onto the run_started telemetry row (additive `data`
## field) so a dead-config run is self-identifying in the log and RG2 can filter it.
##
## WARN-ONLY (Director FINAL): a "climb-only R3 cell" or "branching-only R4 cell" is
## a legitimate single-axis experiment, so this never blocks Start — it only reports.
## The all-off control returns [] (no master enabled → nothing inert). Each entry is
## one trap per ROOT CAUSE (r1_catch_radius_too_small is gated on spawn_count>0 so a
## 0-spawn R1 reports r1_no_spawn alone, not both). A future trap is one more line
## here — the single source of truth consumed by both the CFG warning and telemetry.
func inert_enabled_oppositions() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	# R3 — meter climbs but nothing ever crosses (exposure_meter.gd:131-136: the
	# `while _levels_crossed < levels.size()` loop runs 0 iterations on an empty array).
	if r3_enabled and r3_threshold_levels.is_empty():
		out.append("r3_no_thresholds")
	# R4 — warns ONLY when the whole opposition is inert: enabled but the maze does not
	# branch AND vision occlusion is off AND the lost-proxy never fires. A maze-only R4
	# (branching ON, vision/fog/lost OFF) is a LEGITIMATE, Director-blessed config — it IS
	# the M1.3 default play-preset ("match what I played — occlusion off", M1.3 close-out
	# disposition) — so it must NOT be flagged. (Supersedes the M1.2-era separate
	# r4_no_vision / r4_no_lost_proxy traps, which would have nagged on the intended
	# default; the maze still gives R4 a visible effect, so it is not a dead config.)
	var r4_maze_active := r4_max_branch_depth > 0 and (r4_branch_chance_base > 0.0 or r4_branch_per_depth > 0.0)
	if r4_enabled and not r4_maze_active and r4_vision_radius <= 0.0 and r4_lost_proxy_threshold <= 0.0:
		out.append("r4_no_effect")
	# R1 no-spawn — master on but 0 entities ever instantiated (the spawn seam skips it).
	if r1_enabled and r1_spawn_count <= 0:
		out.append("r1_no_spawn")
	# R1 catch radius too small — recreates the M1.1 caught=0 defect: below the 24 px
	# floor (player_r 14 + hazard_r 10, run_config.gd:51-54) the bodies physically
	# collide before the script distance test can ever trip. Constant by design (no new
	# @export knob — CFG 36-knob count pinned). Gated on spawn_count>0 so it does not
	# double-warn with r1_no_spawn (one trap per root cause). r1_catch_radius_per_depth
	# is additive and does not lower the BASE floor, so the check is on the base alone.
	if r1_enabled and r1_spawn_count > 0 and r1_catch_radius < 24.0:
		out.append("r1_catch_radius_too_small")
	return out


# =============================================================================
# J1 (M1.3) — the named default play-preset (the game/CFG boots into THIS)
# =============================================================================
## Builds the Director's most-fun M1.2 stack as a SECOND, named RunConfig — level
## scale ON (~19 rooms, big rooms at the new slider floor 4.0), R1 pursuing hazard
## ON, R4 **maze ON but vision occlusion OFF** (match-what-I-played, M1.3 close-out),
## with R2/R3 deliberately OFF (Director F1, `G4_findings_M1.2.md` §5). This is what the
## CFG rail (`config_menu._ready`) and the no-CFG fallback (`main_game.gd`) seed.
##
## LOAD-BEARING CONTRACT (M1.3 Breakdown §2): this is built ON TOP of a fresh all-off
## `RunConfig.new()`, so it NEVER mutates the code-level all-off default. `RunConfig.new()`
## and `data/run_config/run_config.tres` stay byte-identical (determinism fp=e943ac9c8bc1,
## telemetry comparability) — the all-off config remains the permanent in-build control
## (Reset returns to it). The preset is a separate artifact, not the default.
##
## PROVENANCE (J1 disposition D): the R1/R4 magnitudes are lifted VERBATIM from the
## most-fun M1.2 cell — the dominant `m1-20260619-ba745e1` snapshot in
## `playtest_data/M1.2/run_log_2026-06-19.jsonl` with
## `lvl_room_count=19, lvl_size_mult=4.0, r1_enabled, r1_catch_radius=23.3,
## r1_spawn_count=3, r4_enabled` (the 7-run cell), with R4's maze ON and vision/fog/lost
## OFF — exactly as played. **Only ONE value diverges** from that snapshot:
##   - r1_catch_radius: 23.3 -> 24.0  (clears the player_r+hazard_r=24px physical floor so
##                                     the catch test can trip — the most-fun cell sat 0.7px
##                                     under it; without this the hazard could never catch).
## (Earlier J1 turned R4 occlusion/fog/lost ON per a literal reading of F1 "vision/maze ON";
## the Director's M1.3 close-out call corrected this to "match what I played — occlusion OFF",
## so R4 vision_radius/fog/lost-proxy are back at the played 0. BUG6's r4_no_effect trap was
## refined so this maze-only R4 is not flagged.) The catch-radius floor is sweepable in RG1.
static func make_default_play_preset() -> RunConfig:
	var c := RunConfig.new()                  # starts from the all-off control (NEVER mutated)

	# --- Level scale: ON, ~19 rooms, big rooms (the new slider floor 4.0). ---
	c.lvl_enabled = true
	c.lvl_room_count = 19                      # disposition B: 19 (sweepable)
	c.lvl_size_mult = 4.0                       # the new RANGE_MULT floor / most-fun cell size

	# --- K2 quota (M1.4): the headline stakes — a per-run quota whose miss is a full
	# roguelite wipe. Director FINAL: start $50, +$50/run. Phase-3 locks: checked at
	# every run end (extract/death/timeout) and met by cumulative money (forgiving Act-1
	# reading). The all-off control (quota_enabled=false) keeps these code defaults so
	# an unconfigured run is byte-identical to M1.3.
	c.quota_enabled = true
	c.quota_base = 50                          # run 1's bar (Director FINAL $50)
	c.quota_step = 50                          # +$50 each time the bar is met (Director FINAL)
	c.quota_check_timing = 1                    # every_run_end (Q1 locked: any-run-end)
	c.quota_basis = 1                          # cumulative_money (Q2 locked: cumulative)

	# --- R1 pursuing hazard: the most-fun ba745e1 cell, verbatim (catch_radius floored). ---
	c.r1_enabled = true
	c.r1_depth_threshold = 1
	c.r1_linger_seconds = 8.1
	c.r1_chase_speed = 56.0
	c.r1_speed_per_depth = 3.0                  # K1 (M1.4, was 18.9): flatten the per-depth chase-speed ramp (Director "catch_speed_per_depth → 3.0" maps to this, the only chase-speed-per-depth ramp on R1 — RD-3)
	c.r1_catch_radius = 24.0                    # unchanged — stays at the 24px collision floor so the catch test can trip and the BUG6 r1_catch_radius_too_small trap stays clear
	c.r1_catch_radius_per_depth = 1.0           # K1 (M1.4, was 10.5): flatten the per-depth catch-radius lunge
	c.r1_catch_kills = true
	# J2 (M1.3): F2 fix — spread the hazards across depth instead of one gate. Director
	# starting sweep points (a sweep, NOT a fix): count 5 (≈4–6), even_spread, min-depth 1
	# (≈1–2 — keeps depth 0 a safe entry, the I2 §2.4 "shallow is safe, then it stirs" arc).
	# curve mode (2) is built but preset-OFF (Director: even_spread is the most legible
	# "danger at every depth" for the first gate). single_gate (0) stays the all-off-equivalent
	# reachable via CFG Reset — these preset values never mutate the all-off control default.
	c.r1_spawn_count = 5
	c.r1_spawn_distribution = 1                 # even_spread (F2); 0=single_gate is the M1.2-equivalent
	c.r1_spread_min_depth = 1                   # shallowest depth that may receive a spread hazard

	# --- R1 per-room density (J3, M1.3): fill the big rooms (G4 §5 F3b). ---
	# ADDITIVE on top of the J2 spread above: each big room earns extra hazards from its
	# size. Director chose CELL-AREA (size-invariant, perf-safe — a 40× room holds a fixed
	# count per room-shape). A non-zero density sweep START (1.0), the per-room cap MANDATORY
	# (3) and a non-trivial min-area (64 cells → corridors/small boxes stay empty). px_area is
	# a swept option (metric=1); the loot-per-area sub-knob ships OFF (never preset-on).
	c.r1_per_room_density = 1.0                 # sweep start (≈1 hazard per ~96-cell room)
	c.r1_density_metric = 0                     # cell_area (Director DEFAULT; size-invariant)
	c.r1_density_rooms_only = false             # any piece above the min-area floor is eligible
	c.r1_density_min_area = 64                  # floor-cell area gate: corridors/small boxes earn none
	c.r1_density_per_room_cap = 3               # MANDATORY > 0 (Q E perf guard); sweepable in RG1

	# --- J4 (M1.3): bias toward FEWER/SHORTER corridors (Director Q-F: big rooms + short halls). ---
	# F3a's thesis is "huge rooms good, long hallways boring." The preset down-weights the corridor
	# family so the spine spends less time in dead hallways (sweep start 0.5 — corridors at half their
	# catalog weight) AND drops the 16-cell long hall outright. The CODE-LEVEL all-off default stays
	# neutral (1.0 / false → byte-identical fp); only the named preset biases. Sweepable in RG1/RG2
	# (read corridor_frac to tune). This MOVES fingerprint() for the preset — correct + expected for
	# a non-neutral config (like R4 branching), not the all-off control.
	c.lvl_corridor_weight_mult = 0.5            # corridors at half weight (sweep start)
	c.lvl_short_corridors = true                # drop the 16-cell long hall (the boring long one)

	# --- R4 maze: the most-fun cell VERBATIM — branching ON, vision occlusion OFF. ---
	# Director M1.3 close-out call ("match what I played — occlusion off"): the played fun
	# cell had R4's maze ON but vision/fog/lost-proxy all OFF (config-trapped at 0 in M1.2).
	# The default mirrors that exactly — a deliberate maze-only R4, NOT a dead one (BUG6's
	# r4_no_effect trap blesses maze-only R4). Real occlusion/fog/lost are sweepable M1.3
	# re-gate variants, not the default.
	c.r4_enabled = true
	c.r4_branch_chance_base = 0.43
	c.r4_branch_per_depth = 43.8
	c.r4_max_branch_depth = 5
	c.r4_vision_radius = 0.0                    # occlusion OFF (match played) — node self-disables
	c.r4_vision_tighten_per_depth = 0.0
	c.r4_fog_enabled = false                    # fog OFF (match played)
	c.r4_lost_proxy_threshold = 0.0            # lost-proxy OFF (match played)

	# --- R2 / R3 deliberately OFF (Director F1: "R2 and R3 OFF by default"). ---
	# r2_enabled / r3_enabled stay false (all-off defaults) — do not touch.

	# --- K3 (M1.4): resolution-independent camera ON in the preset (Director disposition,
	# M1.4 Wave-1 close-out: "Addressed"). The fixed visible-world width makes "how far can I
	# see" a controlled variable the re-gate actually exercises, instead of today's window-
	# resolution-dependent FOV. 576 px = today's horizontal FOV (base 1152 / zoom 2), so the
	# default framing is unchanged on a 1152-wide window and only becomes RESOLUTION-INVARIANT.
	# Pure presentation: cam_* never feed fingerprint() — the all-off control is untouched.
	c.cam_enabled = true
	c.cam_visible_world_width = 576.0          # = base 1152 / zoom 2 (today's horizontal FOV), now fixed
	c.cam_zoom_policy = 0                        # fit_width (lock the horizontal sight-line — K3 Resolved Decisions)

	# Provably trap-free: every enabled opposition's load-bearing magnitude is non-inert,
	# so the M1.3 re-gate measures R1+R4 for real (no silent dead-config like M1.2).
	assert(c.inert_enabled_oppositions().is_empty(),
		"make_default_play_preset(): preset has an inert enabled opposition: %s"
			% str(c.inert_enabled_oppositions()))
	return c
