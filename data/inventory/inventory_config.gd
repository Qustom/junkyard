class_name InventoryConfig
extends Resource
## InventoryConfig — designer-tunable bag capacity (D1, Open questions).
##
## The bag's *capacity value* is config-derived; the live RunInventory it sizes is
## run-state. start_run() reads base_max_slots once when constructing the fresh
## RunInventory, so designers can tune bag size during M1 capacity/value-curve
## playtesting without a recompile. Later, meta-progression can add a bonus to
## base_max_slots at run start — but the live inventory instance stays volatile.

@export var base_max_slots: int = 12
