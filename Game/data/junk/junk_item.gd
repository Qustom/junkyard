class_name JunkItem
extends Resource
## JunkItem — the M1 junk-specific content Resource (TDD §2: "Data as Resources").
##
## A pure data container describing one type of salvageable junk: identity, slot
## footprint, economic value, and greybox appearance. Designers add new junk by
## duplicating a `.tres` and editing fields in the inspector — no recompile.
##
## C1b consolidation: this is now the SINGLE canonical content Resource for junk.
## The former generic `Item` class (data/item.gd) was merged into JunkItem and
## retired — its useful fields (`description`, `origin_band`) live here now;
## `Item.needs_containment` is subsumed by `containment_flags`. (See worklog C1b.)

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
@export_multiline var description: String = ""   # folded from Item; flavor / inspector text

# --- Provenance (folded from Item) ---
## Which depth band this junk originates from (GDD §4 "junkyard-ness" gradient).
@export_enum("surface", "near", "temporal", "lateral", "far") var origin_band: String = "surface"

## Depth / rarity tier (1–5). B3's depth curve gates higher tiers behind deeper
## dives; tracks the value curve so "deeper unlocks higher tiers" reads honestly.
@export_range(1, 5) var tier: int = 1

# --- Slot footprint (D1 reads whichever model it implements) ---
@export_range(1, 9) var slot_size: int = 1          # count-model: slots consumed
@export var grid_footprint: Vector2i = Vector2i.ONE # spatial-model: cells (w,h), advisory in M1
@export_flags("Placeable", "Is Container", "No Nest") var containment_flags: int = ContainmentFlag.PLACEABLE

# --- Economy ---
@export var base_sell_value: int = 10       # Money awarded on cash-out

# --- Greybox appearance (no art assets needed in M1) ---
@export var greybox_color: Color = Color.GRAY
@export var greybox_shape: GreyboxShape = GreyboxShape.RECT


## Convenience for the "is it worth the space?" decision surfaced in UI.
func value_per_slot() -> float:
	return float(base_sell_value) / float(maxi(slot_size, 1))
