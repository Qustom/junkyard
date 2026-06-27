class_name ShopItem
extends Resource
## ShopItem (M1.6 M3) — one buyable entry in the Hub shop catalog (TDD §2:
## "Data as Resources"). Mirrors the JunkItem idiom (data/junk/junk_item.gd): a pure
## data container authored as a `.tres` and listed in a ShopCatalog. The buy catalog
## is DATA, not code — designers add upgrades by duplicating a `.tres`, no recompile.
##
## M1.6 is configurable-not-balanced greybox: `effect_kind = &"none"` makes a purchase
## a STUB SPEND (Money debits, the id is recorded as owned, persists across runs — but
## no gameplay effect applies). Owning the thing is the proof the meta-spend loop closes
## (RD-3). The `effect_kind` field is authored now so a later milestone wires real effects
## (a next-run RunConfig modifier or a passive meta stat) WITHOUT a schema change.

# --- Identity ---
@export var id: StringName = &""             # stable; the key in GameState.owned_items + events + save
@export var display_name: String = "Item"
@export_multiline var description: String = ""

# --- Economy ---
@export var cost: int = 50                    # Money price (configurable-not-balanced greybox)

# --- Ownership / effect ---
## true = owned across runs once bought (the M1.6 catalog is all-persistent → exercises
## the META v3->v4 save bump). false = consumable (re-buyable; no owned-greyout). M1.6
## ships persistent-only.
@export var persistent: bool = true
## Greybox stub marker. &"none" = no gameplay effect (the spend + ownership is the proof).
## A future task branches GameState/_apply on this without a schema change (RD-3).
@export var effect_kind: StringName = &"none"

# --- Greybox appearance (no art assets needed in M1.6) ---
@export var greybox_color: Color = Color.LIGHT_GREEN
