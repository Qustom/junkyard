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
## M1.9 wires "socket" ONLY (scope guardrail). "cave"/"scatter" are declared so
## the schema is stable across the exploration's Phase D, but the pipeline
## fail-louds on them.
@export_enum("socket", "cave", "scatter") var backend: String = "socket"
## The backend's own config Resource. For "socket": a BandGenConfig.
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
	if band_depth < 1:
		problems.append("BandProfile '%s': band_depth must be >= 1" % id)
	return problems
