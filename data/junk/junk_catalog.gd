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
# Per-item spawn weight, index-aligned with `items` (higher = more common).
@export var spawn_weights: PackedFloat32Array = PackedFloat32Array()
