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
	# R4 lost-proxy — never accumulates (lost_proxy.gd:40 self-disables when
	# r4_lost_proxy_threshold <= 0.0 → set_process(false); no nav_lost_proxy emitted).
	if r4_enabled and r4_lost_proxy_threshold <= 0.0:
		out.append("r4_no_lost_proxy")
	# R4 vision — the ENTIRE vision overlay is inert (vision_fog.gd:138 self-disables
	# when r4_vision_radius <= 0.0). NOT gated on r4_fog_enabled: r4_fog_enabled is a
	# separate knob inside the already-active overlay, so radius 0 kills vision
	# regardless (Phase-3 Correction 1 — the most common M1.2 dead-R4 case).
	if r4_enabled and r4_vision_radius <= 0.0:
		out.append("r4_no_vision")
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
## ON, R4 vision/maze ON (non-inert so the M1.3 re-gate actually exercises it), with
## R2/R3 deliberately OFF (Director F1, `G4_findings_M1.2.md` §5). This is what the
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
## r1_spawn_count=3, r4_enabled` (the 7-run cell). Four values DIVERGE from that
## snapshot to make the preset trap-free (BUG6 pairing) and to honour F1's "R4
## vision/maze ON" (M1.2 ran R4's disorientation config-disabled):
##   - r4_lost_proxy_threshold: 0.0 -> 0.5   (disposition D; M1.2 ran the trap 0.0)
##   - r4_vision_radius:        0.0 -> 64.0  (F1 "vision ON"; 64.0 is a Director-played
##                                            value from the vision-on ba745e1 variant)
##   - r4_fog_enabled:        false -> true  (F1 "vision/maze ON"; matches that variant)
##   - r1_catch_radius:        23.3 -> 24.0  (clears the player_r+hazard_r=24px physical
##                                            floor so the catch test can trip — the most-
##                                            fun cell sat 0.7px under it)
## These four are flagged in the J1 worklog and are sweepable in the first M1.3 re-gate.
static func make_default_play_preset() -> RunConfig:
	var c := RunConfig.new()                  # starts from the all-off control (NEVER mutated)

	# --- Level scale: ON, ~19 rooms, big rooms (the new slider floor 4.0). ---
	c.lvl_enabled = true
	c.lvl_room_count = 19                      # disposition B: 19 (sweepable)
	c.lvl_size_mult = 4.0                       # the new RANGE_MULT floor / most-fun cell size

	# --- R1 pursuing hazard: the most-fun ba745e1 cell, verbatim (catch_radius floored). ---
	c.r1_enabled = true
	c.r1_depth_threshold = 1
	c.r1_linger_seconds = 8.1
	c.r1_chase_speed = 56.0
	c.r1_speed_per_depth = 18.9
	c.r1_catch_radius = 24.0                    # was 23.3 in-log; floored to clear the 24px collision floor
	c.r1_catch_radius_per_depth = 10.5
	c.r1_catch_kills = true
	c.r1_spawn_count = 3

	# --- R4 vision/maze: the most-fun cell's branching, made NON-INERT (F1 + BUG6). ---
	c.r4_enabled = true
	c.r4_branch_chance_base = 0.43
	c.r4_branch_per_depth = 43.8
	c.r4_max_branch_depth = 5
	c.r4_vision_radius = 64.0                   # was 0.0 (trapped) -> non-inert, Director-played value
	c.r4_vision_tighten_per_depth = 0.0
	c.r4_fog_enabled = true                     # F1: vision/maze ON
	c.r4_lost_proxy_threshold = 0.5            # was 0.0 (trapped) -> non-inert (disposition D)

	# --- R2 / R3 deliberately OFF (Director F1: "R2 and R3 OFF by default"). ---
	# r2_enabled / r3_enabled stay false (all-off defaults) — do not touch.

	# Provably trap-free: every enabled opposition's load-bearing magnitude is non-inert,
	# so the M1.3 re-gate measures R1+R4 for real (no silent dead-config like M1.2).
	assert(c.inert_enabled_oppositions().is_empty(),
		"make_default_play_preset(): preset has an inert enabled opposition: %s"
			% str(c.inert_enabled_oppositions()))
	return c
