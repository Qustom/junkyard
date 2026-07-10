class_name JunkCatalog
extends Resource
## JunkCatalog — the authored spawn pool of JunkItems (TDD §2: "Data as Resources").
##
## The B2 generator and tooling read the spawnable junk set from this curated,
## weighted list rather than globbing the items directory (DirAccess scans of
## res:// are unreliable in exported builds). Spawn rarity lives HERE, not on the
## JunkItem — rarity is a property of a spawn context, not of the item's identity,
## so a future second catalog can reweight the shared item set without editing
## every `.tres`.

# Authored spawn pool. B2 generator + tooling read from here.
@export var items: Array[JunkItem] = []

## Per-item spawn weight, keyed by JunkItem.id (higher = more common). By-id, NOT
## index-aligned: inserting/removing/reordering `items` can never misalign a weight.
## Rarity stays a spawn-context property of THIS catalog (see class docstring), so a
## second catalog can reweight the shared item set by authoring a different map.
## An item with no entry defaults to weight 1.0 at pick time (JunkPlacer).
@export var spawn_weights_by_id: Dictionary[StringName, float] = {}
