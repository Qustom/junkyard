class_name PieceCatalog
extends Resource
## PieceCatalog — the ordered pool of zone-pieces B2 draws from.
##
## A typed, .tres-authored array so the generator iterates "all available
## pieces" in a FIXED, deterministic order (filesystem scans are not ordered).
## Index 0 is the entry piece (placed first, no RNG). Order is part of the
## determinism contract — do not reorder without re-baking determinism fixtures.

@export var pieces: Array[ZonePieceData] = []
