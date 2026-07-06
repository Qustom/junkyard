class_name BandProfile
extends Resource
## BandProfile — a band-as-biome authored as data (M1.9 S1, band Phase A).
##
## One .tres per band; `data/bands/` holds them. The BandPipeline consumes it.
## The Dead-Cells model transposed: backend/backend_config/archetype ≈ the
## biome's concept graph, piece_pool ≈ the biome's dedicated room pool,
## opposition_deck ≈ the biome's spawn rules.
##
## Phase-A binding: backend / backend_config / archetype / piece_pool drive
## generation; depth_curve / junk_catalog / opposition_deck / band_depth /
## palette_tint are authored now, consumed by S3 (call-site switch +
## EncounterBuilder) and S7 (band_two tint). principles/flavors stay empty
## until S5 lands the stage contract (the pipeline fail-louds on them).

## Stable identity — telemetry/routing/save-safe key. NOT the filename.
## NOTE (Q4c, resolved): the run row's telemetry `band_id` stays the ROUTE key
## (&"near" for this band's dive) — `id` is the CONTENT identity only.
@export var id: StringName = &""
@export var display_name: String = ""

# --- Which BACKEND builds the raw floor/occupancy -------------------------
## All three declared backends are wired: "socket" (M1.9), "cave" (M1.10 T0),
## "scatter" (M1.11 U0). Each carries its own backend_config type, checked by
## validate() below.
@export_enum("socket", "cave", "scatter") var backend: String = "socket"
## The backend's own config Resource. For "socket": a BandGenConfig; for
## "cave": a CaveBandConfig; for "scatter": a ScatterBandConfig.
@export var backend_config: Resource = null

# --- Base ARCHETYPE (topology the backend grows toward) -------------------
## Phase A (Q1, resolved: option a): declarative + validated, NOT dispatched —
## the socket backend's grow loop IS linear/branchy, keyed off
## backend_config.branch_chance and/or the RunConfig r4_* levers. A branchy
## band = a BandGenConfig with branch_chance > 0. validate() push_warns when
## the declared archetype and the config's branch_chance disagree.
@export_enum("linear", "branchy", "hub", "grid", "lanes") var archetype: String = "linear"
@export var archetype_params: Dictionary = {}

# --- Content the backend draws from ---------------------------------------
@export var piece_pool: PieceCatalog = null   # the biome's dedicated pieces
## OPTIONAL extended pool for the I1 lvl_enabled catalog swap (S3, per S1 §10.1 Q3 /
## S3 §7.2 Q6(iv)): when a RunConfig with lvl_enabled reaches the pipeline AND this is
## set (non-null, non-empty), it REPLACES piece_pool for that run — the exact
## config-dependent swap main_game.gd used to do at the call site (Resolved G), so
## adding pieces never moves the all-off baseline fingerprint. Null = no swap (lvl-on
## runs use piece_pool — the old "ext catalog absent" fallback).
@export var piece_pool_ext: PieceCatalog = null

# --- ORGANIZING PRINCIPLES / FLAVOR passes (ordered stage lists) -----------
## Empty in every Phase-A profile. S5 defines the stage Resource contract
## (apply/decorate(build, profile, stage_seed) + per-stage salt). Typed
## Array[Resource] until the stage base class exists (S5 may tighten).
@export var principles: Array[Resource] = []
@export var flavors: Array[Resource] = []

# --- Depth + population (documentary in Phase A — bound at S3) -------------
@export var depth_curve: DepthCurve = null
@export var junk_catalog: JunkCatalog = null
## Typed Array[Resource], NOT Array[OppositionDef] (Q5, resolved): OppositionDef
## is authored by S0 in a PARALLEL Wave-1 worktree — a class_name dependency
## here would break S1's branch in isolation. Retightening is a noted
## post-integration follow-up, not an M1.9 must.
@export var opposition_deck: Array[Resource] = []

# --- Band-depth placement (bands-as-biomes ordering) -----------------------
@export var band_depth: int = 1   # dive tier; drives Instability I at S3

# --- Visual identity (tier-1 art treatment, breakdown amendment 9 / D-RAT-4) -
## Whole-band modulate tint applied at materialisation (S3/S7 consume it).
## White = untinted baseline — band_greybox ships neutral.
@export var palette_tint: Color = Color(1, 1, 1, 1)


## Fail-loud self-check the pipeline runs before generating. Returns problem
## strings; empty = valid. Kept schema-local so tests/tools can reuse it.
## Also emits the Q1 consistency push_warning (warning, never error: RunConfig
## r4 levers can legitimately make a linear-declared profile branch in a sweep).
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("BandProfile: id is empty")
	if backend == "socket":
		if backend_config == null or not (backend_config is BandGenConfig):
			problems.append("BandProfile '%s': socket backend needs a BandGenConfig backend_config" % id)
		if piece_pool == null or piece_pool.pieces.is_empty():
			problems.append("BandProfile '%s': socket backend needs a non-empty piece_pool" % id)
		if archetype != "linear" and archetype != "branchy":
			problems.append("BandProfile '%s': archetype '%s' is not wired for the socket backend in M1.9" % [id, archetype])
		# Q1 consistency guard: declarative metadata that lies is worse than none.
		if backend_config is BandGenConfig:
			var cfg := backend_config as BandGenConfig
			if archetype == "linear" and cfg.branch_chance > 0.0:
				push_warning("BandProfile '%s': archetype 'linear' but backend_config.branch_chance = %f > 0" % [id, cfg.branch_chance])
			elif archetype == "branchy" and cfg.branch_chance <= 0.0:
				push_warning("BandProfile '%s': archetype 'branchy' but backend_config.branch_chance = %f" % [id, cfg.branch_chance])
	elif backend == "cave":
		# M1.10 T0: cave backend needs a CaveBandConfig; NO piece_pool (there are
		# no pieces to draw) — a non-null piece_pool is legal-but-inert.
		if backend_config == null or not (backend_config is CaveBandConfig):
			problems.append("BandProfile '%s': cave backend needs a CaveBandConfig backend_config" % id)
		else:
			for p in (backend_config as CaveBandConfig).validate():
				problems.append("BandProfile '%s': %s" % [id, p])
		# Flavors ship EMPTY on cave bands (M1.10 breakdown; the cave IS the flavor).
		# SetPieceInject/WearDecay are socket-built — a flavor-bearing cave profile is
		# an authoring error until a cave-aware stage exists. This is the SINGLE
		# location for the cave+flavors fail-loud (Phase-3 amendment 1).
		if not flavors.is_empty():
			problems.append("BandProfile '%s': cave backend does not support flavor stages in M1.10 (flavors must be empty)" % id)
		# The archetype field has no cave-honest value; the CA IS the topology, so
		# it is an ignored don't-care (warn, never error — Q6 option a).
		if archetype != "linear":
			push_warning("BandProfile '%s': archetype '%s' is ignored by the cave backend (the CA IS the topology)" % [id, archetype])
	elif backend == "scatter":
		# M1.11 U0: scatter backend needs a ScatterBandConfig; NO piece_pool
		# (there are no pieces to draw) — a non-null piece_pool is legal-but-inert.
		if backend_config == null or not (backend_config is ScatterBandConfig):
			problems.append("BandProfile '%s': scatter backend needs a ScatterBandConfig backend_config" % id)
		else:
			for p in (backend_config as ScatterBandConfig).validate():
				problems.append("BandProfile '%s': %s" % [id, p])
		# Flavors ship EMPTY on scatter bands (M1.11 breakdown / U0 RD-10; the
		# M1.10 rule carries — SetPieceInject/WearDecay are socket-built). This
		# is the SINGLE location for the scatter+flavors fail-loud.
		if not flavors.is_empty():
			problems.append("BandProfile '%s': scatter backend does not support flavor stages in M1.11 (flavors must be empty)" % id)
		# The archetype field has no scatter-honest value (the arena IS the
		# topology) — ignored don't-care (warn, never error).
		if archetype != "linear":
			push_warning("BandProfile '%s': archetype '%s' is ignored by the scatter backend (the arena IS the topology)" % [id, archetype])
	if band_depth < 1:
		problems.append("BandProfile '%s': band_depth must be >= 1" % id)
	return problems
