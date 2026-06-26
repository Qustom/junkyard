class_name ShopCatalog
extends Resource
## ShopCatalog (M1.6 M3) — the authored set of buyable ShopItems for the Hub shop
## (TDD §2: "Data as Resources"). The Shop BUY tab reads its buyable list from this
## curated Resource rather than globbing the items directory (DirAccess scans of res://
## are unreliable in exported builds), mirroring JunkCatalog.
##
## Simpler than JunkCatalog: it carries NO spawn_weights — the Shop lists every item in
## author order, there is no weighted random draw (RD-7).

# Authored buyable set. The Shop BUY tab iterates this in author order.
@export var items: Array[ShopItem] = []
