extends Resource
class_name Item
## Item — data-authored content (TDD §2: "Data as Resources").
##
## Items, recipes, enemies, bands, zone-pieces and upgrades are all custom
## Resources (.tres) so content is authored as data — no recompile, diff-friendly,
## moddable. This is the schema the game-director-designer subagent authors against.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

## Which depth band this item originates from (GDD §4 "junkyard-ness" gradient).
@export_enum("surface", "near", "temporal", "lateral", "far") var origin_band: String = "surface"

## Base sell value in Money before repair (GDD §8 economy).
@export var base_value: int = 0

## Slot footprint in the slot-based inventory (GDD §6). Deep/anomalous items > 1.
@export var slot_size: int = 1

## Whether the item needs an anomaly-containment slot (deep bands).
@export var needs_containment: bool = false
