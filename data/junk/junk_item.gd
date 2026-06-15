class_name JunkItem
extends Resource
## JunkItem — the M1 junk-specific content Resource (TDD §2: "Data as Resources").
##
## A pure data container describing one type of salvageable junk: identity, slot
## footprint, economic value, and greybox appearance. Designers add new junk by
## duplicating a `.tres` and editing fields in the inspector — no recompile.
##
## NOTE: This is intentionally SEPARATE from the generic `Item` class (data/item.gd).
## C1 introduces JunkItem as the M1 junk backbone; the Item/JunkItem overlap is a
## known follow-up to reconcile post-M1 (see worklog).

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
