class_name OppositionDef
extends Resource
## OppositionDef — one opposition type as DATA (M1.9 S0, exploration v2 §data layer).
## The "content is data, not code" pattern data/item.gd establishes, applied to
## oppositions (hazards now; the umbrella covers M2 enemies / Fields / Fixtures later).
## Authored as .tres in res://data/oppositions/ — ids MUST equal the legacy telemetry
## kinds (new_hazard_killed / throw_killed_hazard vocabulary) so opposition_event ids
## are continuous with historical telemetry.
##
## Phase A (S0): id / host_scene / cap_group are load-bearing (read by SpawnService);
## the spawn-card fields are authored neutral and unread until S3's EncounterBuilder;
## params / param_schema are completed by S2 (components) and reflected by S4 (menu).
## Lazy-load discipline: host_scene is an ExtResource, so loading a def loads its
## scene — defs are therefore lazy-loaded exactly where scenes are lazy-loaded today
## (only for an enabled + non-neutral type; all-off loads NOTHING).

@export var id: StringName                       # &"pingpong" — MUST equal the legacy
                                                 # telemetry kind so historical rows join.
@export var display_name: String = ""
@export_enum("actor", "field", "fixture") var archetype: String = "actor"
@export var host_scene: PackedScene              # the CURRENT hazard .tscn, unchanged

# --- Spawn card (read by the S3 builder, NOT the service; authored neutral in S0) ---
@export var credit_cost: int = 1
@export var spawn_weight: float = 1.0
@export var min_band: int = 0

# --- Hard caps (read by the SERVICE) -------------------------------------------------
@export var cap_group: StringName = &""          # shared ceiling pool; &"new_hazards" for K5
@export var per_room_cap: int = 0                # 0 = no service-side per-room refusal
                                                 # (Phase A: the policy count-math cap
                                                 # still applies where it does today)
@export var per_band_cap: int = 0                # 0 = defer to cap_group / global

# --- Component knob bag + schema (S2 completes; S4 reflects) --------------------------
@export var params: Dictionary = {}
@export var param_schema: Array[Dictionary] = []

# --- Lethality declaration (informational until S2 moves the *_kills read here) -------
@export_enum("lethal", "chip", "knockback", "steal", "none") var lethality: String = "lethal"
@export var kills: bool = true
