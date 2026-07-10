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
# J3 (M1.3) — level-scale loot density constant
# V3b (M1.12): the R1 per-room density consts (R1_DENSITY_AREA_UNIT /
# R1_DENSITY_BAND_CEILING) were RETIRED with the main_game R1 pursuer machine —
# the pursuer is now a band_greybox deck card (its body count rides the deck's
# credit budget + per_band_cap, not an area formula). Only the loot-axis unit remains.
# =============================================================================
## Junk floor-cell area that earns ONE base-count multiple at loot-density 1.0 (the loot
## sub-knob's per-area unit).
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
# V3b (M1.12): the 18 bespoke r1_* RunConfig knobs were RETIRED. The pursuer is now a
# pure OppositionDef + deck card like the K5/modern hazards (V3 did the same for K5):
# band_greybox authors it in its opposition_deck, its body count rides the deck credit
# budget (opposition_credits 58) + a per_band_cap (10) on pursuer.tres, and the play
# magnitudes ride the play preset's `param_overrides["pursuer"]` (keyed by def id, read
# by hazard_entity.gd from spawn_ctx["params"]). "Exactly one way to add an opposition"
# — author a def, add a deck row; no special-case knob group, no main_game spawn machine.
# The config surface shrank 70 → 52.
# =============================================================================

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
# K5a/K5b/K5c (M1.4) — Ping-pong / Bomb / Rotating-spikes hazards.
# V3 (M1.12): the 21 bespoke hpp_/hbomb_/hspike_ RunConfig knobs were RETIRED. These
# three hazards are now pure OppositionDef + DeckEntry data like the six modern hazards
# (charger/splitter/…): band_greybox authors them in its opposition_deck, per-room caps
# ride the shared defs (pingpong/bomb 2, spike 1), and the play magnitudes ride the play
# preset's `param_overrides` (see make_default_play_preset). "Exactly one way to add an
# opposition" — author a def, add a deck row; no special-case knob group, no fair-share
# descriptor, no entity cfg.h*_* read. The config surface shrank 91 → 70.
# =============================================================================

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

# =============================================================================
# L1 (M1.5) — Throwing mechanic. Highlight an inventory item (Q/E), then Space
# throws it in the player's facing direction; a hit on a hazard-layer body (the
# R1 pursuer or the K5 ping-pong) kills it + destroys the item; a miss (wall /
# max-range / an in-script lifetime fallback) re-drops the item via the existing
# EventBus.junk_dropped path. All-off default = no throwing (M1.4 behaviour).
# Pure run-state (remove from run_inventory + a transient projectile) — never
# feeds fingerprint(), never persists. L0 only DECLARES these; L1 reads/emits.
# The throw kill-scope is FIXED (any hazard-layer body) — NO scope knob (Phase-4
# lock); the miss-lifetime is an in-script constant, NOT a knob (RD-2).
# =============================================================================
@export_group("L1 Throwing", "throw_")
## Master toggle. OFF = no highlight selector, no throw (M1.4 behaviour).
@export var throw_enabled: bool = false
## Projectile travel speed (px/s, greybox). Entity-read by the thrown projectile.
## Magnitude default is inert while throw_enabled=false (no projectile spawns); the
## preset sets the swept value in L1. Does NOT move the all-off fingerprint.
@export var throw_speed: float = 180.0
## Max travel distance (px) before the throw MISSES and the item re-drops. A hidden
## in-script lifetime is the belt-and-braces fallback (NOT a knob — RD-2). Magnitude
## default is inert while throw_enabled=false; the preset sets the swept value in L1.
@export var throw_max_range: float = 320.0


# =============================================================================
# S3 (M1.9) — generic opposition levers (exploration v2 "RunConfig integration").
# ADDITIVE + neutral-by-default: empty array/dict = no def loaded, no override
# applied — the all-off control and every legacy preset are byte-untouched.
# S3 landed both as @export_storage (invisible to the STORAGE && EDITOR
# reflection net) so the 89-row pin held through Wave 3; S4 (Wave 4) PROMOTED
# both to plain @export + bound sentinel rows in the ConfigMenu — the count
# model is now 89 frozen legacy + 2 levers = 91, and the levers are back inside
# has_full_coverage()'s fail-loud enumeration (S4 §8.1 Q3: a storage-only knob
# class would be a permanent reflection blind spot).
# =============================================================================
@export_group("S3 Opposition Levers")
## ADDITIVE def enable-list (a sweep/debug lever): each listed OppositionDef id
## (res://data/oppositions/<id>.tres) is loaded and appended, id-deduped, to the
## dive's effective opposition deck through the EncounterBuilder's deck machinery
## — on a deck-less band (band 1) it seeds a one-def deck at the def's authored
## spawn card. It never REMOVES a band author's deck entry. Empty = neutral.
@export var oppositions_enabled: Array[StringName] = []
## def_id -> { param_key -> value } sweep overrides, applied to DEF-DRIVEN params
## (deck lane + extras) at ctx-merge time; legacy-knob-driven values stay
## authoritative for the legacy lane in M1.9 (no double-driving — S3 §7.2
## Q6(ii)). String or StringName def-id keys accepted; leaves are primitives.
## Empty = neutral.
@export var param_overrides: Dictionary = {}


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
	# V3b (M1.12): the r1_enabled term was dropped with the r1_* knob group. The pursuer
	# is now a deck card whose all-off state is covered by EncounterBuilder's
	# _deck_all_neutral fast-path (a neutral pursuer card → 0 demand → skipped), so the
	# r2/r3/r4-only predicate is the M1.0-baseline telemetry label. A run with only a
	# neutral deck (no param_overrides) + no r-toggles still reproduces the M1.0 loop.
	return not (r2_enabled or r3_enabled or r4_enabled)


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
## design — ABSOLUTELY: keys are field names, values are JSON primitives (int/
## float/bool/String/Array of float); no value is ever a Dictionary. The
## param_overrides stamp (S3, M1.9 — breakdown amendment 10 as amended at the
## Wave-3 close-out, Director 2026-07-03) is emitted as FLAT dotted rows
## "param_overrides.<def_id>.<param_key>" -> primitive; a neutral config emits
## zero such rows. TEL wires the call; R0 only provides the method.
func to_flat_dict() -> Dictionary:
	var flat: Dictionary = {
		# meta
		"seed_override": seed_override,
		"build_tag": build_tag,
		# V3b (M1.12): the 18 R1 r1_* stamp rows were RETIRED with the knobs — the pursuer
		# is now deck-driven data (band_greybox.opposition_deck + the play preset's
		# param_overrides["pursuer"]), stamped via the param_overrides rows below.
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
		# V3 (M1.12): the 21 K5a/K5b/K5c hpp_/hbomb_/hspike_ stamp rows were RETIRED with
		# the knobs — the K5 hazards are now deck-driven data (band_greybox.opposition_deck
		# + the play preset's param_overrides), stamped via the param_overrides rows below.
		# K7 (M1.4) — exit-placement config knobs
		"exit_enabled": exit_enabled,
		"exit_base_count": exit_base_count,
		"exit_count_per_depth": exit_count_per_depth,
		"exit_keep_one_at_spawn": exit_keep_one_at_spawn,
		"exit_max_count": exit_max_count,
		# L1 (M1.5) — throwing config knobs (additive payload; RG2 segments throw cohorts)
		"throw_enabled": throw_enabled,
		"throw_speed": throw_speed,
		"throw_max_range": throw_max_range,
		# V3b (M1.12): the L2 r1_spawn_room_only/r1_patrol_speed stamp rows were RETIRED
		# with the r1_* knobs — the pursuer's room-bound patrol magnitudes now ride the
		# play preset's param_overrides["pursuer"], stamped via the param_overrides rows.
		# V3 (M1.12): the L5 hpp_kills/hbomb_kills/hspike_kills stamp rows were RETIRED with
		# the knobs — lethality is now entity-local (DEFAULTS.kills = true) + an optional
		# param_overrides["<id>"]["kills"] = false, stamped via the param_overrides rows.
		# S3 (M1.9) — generic opposition levers (additive payload; SG2 segments def
		# sweeps). Neutral configs stamp an empty Array + empty Dictionary.
		"oppositions_enabled": _stringname_array_to_strings(oppositions_enabled),
	}
	var override_rows: Dictionary = _param_override_rows()
	for row_key: String in override_rows:
		flat[row_key] = override_rows[row_key]
	return flat


## Array[StringName] → plain Array of String so the flat dict stays JSON-portable
## (JSON.stringify would coerce StringNames anyway; plain Strings keep the snapshot
## consumer-agnostic, like _packed_to_float_array).
func _stringname_array_to_strings(names: Array[StringName]) -> Array:
	var out: Array = []
	for n in names:
		out.append(String(n))
	return out


## param_overrides → FLAT dotted stamp rows ("param_overrides.<def_id>.<param_key>"
## -> primitive value), keeping to_flat_dict() nesting-free (Wave-3 close-out,
## Director Addressed 2026-07-03). Non-Dictionary entries are dropped (a malformed
## override is a config-authoring error, not a telemetry crash).
func _param_override_rows() -> Dictionary:
	var out: Dictionary = {}
	for def_id: Variant in param_overrides:
		var entry: Variant = param_overrides[def_id]
		if not (entry is Dictionary):
			continue
		for k: Variant in (entry as Dictionary):
			out["param_overrides.%s.%s" % [String(def_id), String(k)]] = (entry as Dictionary)[k]
	return out


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
	# V3b (M1.12): the two R1 traps (r1_no_spawn, r1_catch_radius_too_small) were DROPPED
	# with the r1_* knobs — they are unreachable now that r1_enabled/r1_spawn_count/
	# r1_catch_radius no longer exist on the config surface. The catch-radius-too-small
	# concern is now covered, data-driven, by pursuer.tres's param_schema trap_if_neutral
	# on catch_radius (surfaced via OppositionLint.inert_enabled_defs for enabled defs).
	return out


# =============================================================================
# J1 (M1.3) — the named default play-preset (the game/CFG boots into THIS)
# =============================================================================
## Builds the Director's most-fun stack as a SECOND, named RunConfig — level
## scale ON (~19 rooms, big rooms at the new slider floor 4.0), R1 pursuing hazard
## ON, R4 **maze ON but vision occlusion OFF** (match-what-I-played, M1.3 close-out),
## with R2/R3 deliberately OFF (Director F1, `G4_findings_M1.2.md` §5). This is what the
## CFG rail (`config_menu._ready`) and the no-CFG fallback (`main_game.gd`) seed.
##
## M1.4 (RG1) ADDS the full M1.4 fun stack on top of the M1.3 base: K2 quota (the headline
## roguelite-wipe stake), K3 resolution-independent camera, **K4 dive timer + ~10s near-end
## warning** (60s dive, visual-only), and **all three K5 new hazard types** (ping-pong / bomb /
## rotating-spikes) at RG1 sweep-START magnitudes with a mandatory per-room cap. K7 exits ship
## OFF for a clean re-gate. The K4/K5/quota/camera knobs are pure run-state (never feed
## fingerprint()) so the all-off control stays byte-identical (fp e943ac9c8bc1).
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

	# --- Level scale: ON, 30 rooms, big rooms (the new slider floor 4.0). ---
	c.lvl_enabled = true
	c.lvl_room_count = 30                      # Director sweep (M1.5, was 19): longer dives
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

	# --- R1 pursuer (V3b M1.12): now a band_greybox DECK card, not a knob group. ---
	# The most-fun ba745e1 cell magnitudes (verbatim) + the J2 spawn budget (was count 5 /
	# even_spread) + the J3 density + the L2 room-bound patrol ALL moved to the pursuer's
	# param_overrides bag below (see c.param_overrides["pursuer"]). base_count/count_per_depth
	# drive the deck-lane body count (tuned so the greybox pursuer total ≈ the pre-migration
	# J2+J3 total within ±15% — small 5 / mid 9 / deep 10, per the frozen Step-0 fixture);
	# the behaviour magnitudes (chase_speed/catch_radius/patrol/room_only/catch_kills) are read
	# by hazard_entity.gd from spawn_ctx["params"]. The historical per-room density's big-room
	# clustering folds to the deck's even-spread (D-RAT-3a licensed; per-type TOTAL preserved).

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
	# resolution-dependent FOV. RG1 re-gate (Feedback #1): the Director set the visible-world
	# width to 1000 px — the prior 576 (base 1152 / zoom 2) framed too tight, so the playtester
	# could not see enough of the band ahead. 1000 px zooms the view out to show more world.
	# Pure presentation: cam_* never feed fingerprint() — the all-off control is untouched.
	c.cam_enabled = true
	c.cam_visible_world_width = 1000.0         # RG1 Feedback #1: Director set 1000 px visible-world-width (was 576)
	c.cam_zoom_policy = 0                        # fit_width (lock the horizontal sight-line — K3 Resolved Decisions)

	# --- K4 (M1.4): configurable dive timer + near-end warning. Director FINAL (Phase-3
	# lock): a ~60s dive with a ~10s near-end warning, VISUAL-ONLY for RG1 (audio is M2-gated,
	# so timer_warning_channel stays visual_only). This makes "the clock" a real, legible stake
	# in the re-gate instead of the implicit DiveClockConfig default. Pure run-state: timer_*
	# never feed fingerprint(), so the all-off control (timer_enabled=false) is untouched.
	c.timer_enabled = true
	c.timer_length_s = 300.0                    # Director sweep (M1.5, was 600): 300s (5 min) dive
	c.timer_warning_threshold_s = 60.0          # Director pre-playtest tweak: warn with 60s left
	c.timer_warning_channel = 0                 # visual_only (audio gated to M2 — Phase-3 lock)

	# --- K5 (M1.4 · V3 M1.12): the three greybox hazard types (ping-pong / bomb / spike) ON at
	# the RG1 sweep-start magnitudes. V3 retired the bespoke hpp_/hbomb_/hspike_ knob groups: the
	# hazards are now band_greybox deck cards, so the play magnitudes ride `param_overrides`
	# (keyed by def id), merged over the neutral def params by EncounterBuilder — the SAME surface
	# that drives every modern hazard. base_count/count_per_depth drive the deck-lane spawn counts;
	# speed/proximity_radius/pulse_seconds/blast_radius/rotation_speed/arm_length are read by the
	# entities from spawn_ctx["params"]. Lethality stays true (the entities' DEFAULTS.kills = true,
	# matching the three defs); a non-lethal preset would add "kills": false here. The per-room caps
	# (pingpong/bomb 2, spike 1) live on the SHARED defs; the &"new_hazards" cap-group ceiling (48)
	# + band_greybox.opposition_credits (48) bound all three combined. Pure run-state — never feeds
	# fingerprint(), so the all-off control stays byte-identical (e943ac9c8bc1); an all-off rc has
	# param_overrides = {} → neutral deck → is_inert() true → zero hazards.
	#
	# Worked density (default ~19-room / ~15-depth greybox band, per the frozen K5 equivalence
	# fixture tests/goldens/greybox_k5_legacy_plan.json): pingpong ~16-17, bomb ~16-17, spike ~14,
	# combined = the 48 ceiling — the historical K5 body density, preserved (V3 D-RAT-8).
	c.param_overrides = {
		# K5a ping-pong: base 0 (ramps in with depth), +1 every ~7 depths, 70 px/s greybox travel.
		"pingpong": { "count_per_depth": 0.15, "speed": 70.0 },
		# K5b bomb: base 0, gentle ramp; ~64 px proximity, ~2s Director pulse, 48 px blast.
		"bomb": { "count_per_depth": 0.15, "proximity_radius": 64.0,
			"pulse_seconds": 2.0, "blast_radius": 48.0 },
		# K5c spike: base 1 (RG1 #3 — appears from the first eligible room), gentle ramp (cap 1
		# holds each room to one), 90 deg/s signed rotation, 48 px arm reach.
		"spike": { "base_count": 1, "count_per_depth": 0.1,
			"rotation_speed": 90.0, "arm_length": 48.0 },
		# R1 pursuer (V3b M1.12 — the retired r1_* knob group, now a deck card). base_count 2 +
		# count_per_depth 0.5 tuned against the frozen Step-0 J2+J3 fixture so the greybox pursuer
		# per-type TOTAL lands within ±15% (small 5 / mid 10 / deep 10 vs fixture 5 / 9 / 10);
		# pursuer.tres.per_band_cap (10) + opposition_credits (58 = K5 48 + pursuer 10) reserve its
		# share regardless of deck order. Behaviour = the most-fun ba745e1 cell verbatim
		# (depth_threshold 1 / linger 8.1 / chase 56 / speed_per_depth 5 / catch_radius 24 /
		# catch_radius_per_depth 1 / catch_kills true) + L2 room-bound patrol (spawn_room_only
		# true / patrol 28). Keyed by the pursuer.tres::params key names (catch_radius/catch_kills).
		"pursuer": { "base_count": 2, "count_per_depth": 0.5,
			"depth_threshold": 1, "linger_seconds": 8.1, "chase_speed": 56.0,
			"speed_per_depth": 5.0, "catch_radius": 24.0, "catch_radius_per_depth": 1.0,
			"patrol_speed": 28.0, "spawn_room_only": true, "catch_kills": true },
	}

	# --- K7 (M1.4): exits ON for this playtest (Director pre-playtest tweak, supersedes the
	# earlier Phase-3 "ship exits OFF" lock). Multiple depth-scaled exits scattered across the
	# band, with one gate pinned at spawn. Pure run-state (local run_seed ^ EXITS_RNG_SALT — never
	# the global RNG), so the all-off control fingerprint stays byte-unmoved (e943ac9c8bc1).
	c.exit_enabled = true
	c.exit_base_count = 1                       # Director: 1 at depth 0
	c.exit_count_per_depth = 0.1               # Director: +1 exit every ~10 within-band depths
	c.exit_keep_one_at_spawn = true            # Director: always pin one gate at the spawn offset
	c.exit_max_count = 7                        # Director: cap the band at 7 exits

	# --- L1 (M1.5): throwing mechanic ON — ship the agency verb live for RG1. Highlight
	# an inventory item (Q/E), Space throws it in the facing direction; a hit on a
	# hazard-layer body (the R1 pursuer or the K5 ping-pong) kills it + consumes the item,
	# a miss re-drops it as a grabbable pickup. throw_speed/throw_max_range keep their L0
	# code defaults (180 px/s, 320 px) — sweepable in RG1. Pure run-state: throw_* never
	# feed fingerprint(), so the all-off control (throw_enabled=false) stays byte-identical.
	c.throw_enabled = true

	# Provably trap-free: every enabled opposition's load-bearing magnitude is non-inert,
	# so the M1.3 re-gate measures R1+R4 for real (no silent dead-config like M1.2).
	assert(c.inert_enabled_oppositions().is_empty(),
		"make_default_play_preset(): preset has an inert enabled opposition: %s"
			% str(c.inert_enabled_oppositions()))
	return c
