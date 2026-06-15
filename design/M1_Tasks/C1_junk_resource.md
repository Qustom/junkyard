# C1 — Junk as Resource

**Summary:** Define `JunkItem` as a custom `.tres` Resource so all junk content is authored as data files, and author ~6-10 greybox junk items spanning a value range.

- **Parent task:** C1
- **Dependencies:** None (foundational content task; D1, C2, D2 consume this)
- **Acceptance criterion:** New junk is authorable as a `.tres` with no code change; a meaningful range of sell values exists across the authored set.

This is the content-data backbone for M1. Junk must be pure data: a `JunkItem` Resource holds everything the rest of the systems need (identity, slot footprint, economic value, greybox appearance), and designers add new junk by duplicating a `.tres` and editing fields in the Godot inspector. No recompile, diff-friendly, moddable later.

## Assets needed

Feature-first layout under the junk feature:

- `/data/junk/junk_item.gd` — the `JunkItem` Resource class (`class_name JunkItem`), referenced by every `.tres`.
- `/data/junk/items/` — the authored item `.tres` files, one per junk type. Suggested initial set (~8 items across a value curve):
  - `junk_scrap_bolt.tres` — tiny, low value (the floor).
  - `junk_cable_coil.tres` — small, low-mid value.
  - `junk_hubcap.tres` — small/medium, mid value.
  - `junk_car_battery.tres` — medium, mid-high value, heavy footprint.
  - `junk_radiator.tres` — large, high value.
  - `junk_engine_block.tres` — large, top value (the ceiling; forces hard carry choices).
  - `junk_copper_pipe.tres` — small, mid value (clean stack-filler).
  - `junk_circuit_board.tres` — tiny footprint, high value-per-slot (the "greedy" pick).
- `/data/junk/junk_catalog.tres` (optional but recommended) — a `JunkCatalog` Resource holding an `Array[JunkItem]` so the generator (B2) and tooling can pull the spawnable pool from one authored list instead of globbing the directory.

Greybox placeholders are encoded *in the data*, not as art assets: each `JunkItem` carries a `greybox_color: Color` and a `greybox_shape` enum (rect / circle / triangle / diamond). C2's pickup entity and D2's UI both read these to draw a colored shape — so no sprite imports are required for M1.

No scenes are owned by C1. C1 produces only the class script and the `.tres` data.

## Code to generate

A single Resource class plus the authored data. The class should be small, fully typed, inspector-friendly (`@export` on everything), and free of behaviour — it is a data container.

Key design points:
- `id: StringName` — stable machine identity used in EventBus payloads, telemetry, and save data. Decoupled from `display_name` so renames don't break saves.
- Slot footprint is expressed in a way that works whether D1 lands on a grid-spatial or simple-count model (see Open questions): expose both a coarse `slot_size` (number of slots consumed in a count model) and a `grid_footprint: Vector2i` (cells consumed in a spatial model). M1 can read whichever D1 implements; the other field is forward-compatible.
- `containment_flags` — bitmask describing how the item interacts with containers (e.g. can be placed in a container, *is* a container, cannot be nested). Mostly forward-looking for M1 but authored now so data doesn't need migrating.

```gdscript
# /data/junk/junk_item.gd
class_name JunkItem
extends Resource

enum GreyboxShape { RECT, CIRCLE, TRIANGLE, DIAMOND }

enum ContainmentFlag {
    NONE          = 0,
    PLACEABLE     = 1 << 0,  # may be put into the inventory at all
    IS_CONTAINER  = 1 << 1,  # can hold other items (post-M1)
    NO_NEST       = 1 << 2,  # may not be placed inside a container
}

# --- Identity ---
@export var id: StringName = &""            # stable; used in events/telemetry/save
@export var display_name: String = "Junk"

# --- Slot footprint (D1 reads whichever model it implements) ---
@export_range(1, 9) var slot_size: int = 1          # count-model: slots consumed
@export var grid_footprint: Vector2i = Vector2i.ONE # spatial-model: cells (w,h)
@export_flags("Placeable", "Is Container", "No Nest") var containment_flags: int = ContainmentFlag.PLACEABLE

# --- Economy ---
@export var base_sell_value: int = 10       # Money awarded on cash-out

# --- Greybox appearance (no art assets needed in M1) ---
@export var greybox_color: Color = Color.GRAY
@export var greybox_shape: GreyboxShape = GreyboxShape.RECT

# Convenience for the "is it worth the space?" decision surfaced in UI.
func value_per_slot() -> float:
    return float(base_sell_value) / float(maxi(slot_size, 1))
```

Optional catalog resource so content lives in one authored list:

```gdscript
# /data/junk/junk_catalog.gd
class_name JunkCatalog
extends Resource

# Authored spawn pool. B2 generator + tooling read from here.
@export var items: Array[JunkItem] = []
# Optional per-item spawn weight, index-aligned with `items`.
@export var spawn_weights: PackedFloat32Array = PackedFloat32Array()
```

Each authored `.tres` is just the class with field values set, e.g. conceptually:

```
# junk_engine_block.tres
[resource] script = junk_item.gd
id = &"engine_block"
display_name = "Engine Block"
slot_size = 4
grid_footprint = Vector2i(2, 2)
base_sell_value = 120
greybox_color = Color(0.25, 0.25, 0.30)
greybox_shape = RECT
```

Target value spread for the authored set (illustrative, tune in playtest): bolt ~3, cable ~8, copper pipe ~15, hubcap ~20, circuit board ~45 (tiny but rich), battery ~55, radiator ~80, engine block ~120. This gives an ~40x floor-to-ceiling ratio and a deliberate value-per-slot tension between the cheap-and-small and the rich-and-bulky picks.

## Open questions

- **slot_size vs grid_footprint authority:** D1 decides the slot model. If it goes simple-count, `grid_footprint` is dead weight in M1 — do we author it anyway for forward-compat, or strip it until needed? (Current recommendation: author both, cheap insurance.)
  - **Recommendation:** Author both. D1 lands on simple-count for M1, so `slot_size` is the live field, but `grid_footprint` costs nothing to set per `.tres` and lets a future spatial model switch on without re-authoring all content. Treat `grid_footprint` as advisory metadata in M1 (default it to a sensible w×h that roughly matches `slot_size`) and document that it is unread until/unless D1 adopts the spatial variant.
- **Catalog vs directory glob:** should the spawn pool be an explicit `JunkCatalog.tres` (curated, weighted) or auto-discovered by scanning `/data/junk/items/`? Curated is more controllable for M1's tuned value curve; glob is lower-friction for adding content.
  - **Recommendation:** Use the explicit `JunkCatalog.tres`. Beyond M1's need for a hand-tuned value curve and per-item weights, `DirAccess` globbing of `res://` is unreliable in exported builds — imported resources live under `.godot/` and a runtime scan returns `.import`/`.remap` metadata rather than loadable `.tres` paths, so a curated array is also the technically safer choice. If add-content friction ever bites, add an editor tool that repopulates the catalog from the directory at author time, keeping runtime on the explicit list ([source](https://forum.godotengine.org/t/resources-not-export-after-export-with-var-dir-diraccess-open-path/120431)).
- **Spawn weighting ownership:** does spawn rarity live on the `JunkItem` (a `spawn_weight` field) or on the catalog/generator? Putting it on the item couples content to distribution; putting it on the catalog keeps items pure.
  - **Recommendation:** Keep weights on the catalog (the index-aligned `spawn_weights` already sketched), not on `JunkItem`. Rarity is a property of a *spawn context*, not of the item's identity — the same engine block could be common in one band and rare in another, and a future second catalog should be able to reweight the shared item set without editing every `.tres`. This keeps `JunkItem` a pure description of the thing and `JunkCatalog` the description of how the world hands it out.
- **Value as flat int vs ranged/condition:** is `base_sell_value` a single number, or do we want a min/max range or a condition multiplier (rusty vs clean) even in greybox? M1 leans flat int; flag if the economy design wants variance now.
  - **Recommendation:** Flat int for M1. The core "what's worth carrying" decision is sharpest when value is fully legible at pickup — a deterministic `base_sell_value` lets the player reason about value-per-slot exactly, which is the whole point of the carry choice. Condition/ranged variance adds an appraisal mini-system and per-instance state (see the carried-items identity question in D1) that earns its keep only once the economy is real; defer it and keep `base_sell_value` a single authored number.
- **id namespacing:** plain `StringName` ids — do we need a category prefix (`scrap/bolt`) for later modding/collision avoidance, or is a flat id space fine through M1?
  - **Recommendation:** Flat `snake_case` ids through M1 (`scrap_bolt`, `engine_block`), but adopt a one-word category prefix convention now so the namespace is forward-compatible without a schema change — i.e. `junk_engine_block` rather than a slash-delimited path. Slash/colon namespacing (`mymod:junk/...`) is a modding-era concern; reserving a prefix word costs nothing today and avoids a save-breaking id migration later. The only hard rule for M1 is that ids are unique and stable (never renamed once authored, since saves/telemetry key off them).
