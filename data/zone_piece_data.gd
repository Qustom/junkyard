class_name ZonePieceData
extends Resource
## ZonePieceData — catalog entry for a zone-piece (B1, consumed by B2).
##
## A .tres-authored registry record so B2's seeded assembly can iterate "all
## available pieces" without scanning the filesystem (which would not be
## deterministically ordered). Data-as-Resources per TDD §2.

## The authored piece scene (root = ZonePiece).
@export var scene: PackedScene

## Stable identifier; should match the scene root's piece_id.
@export var piece_id: StringName = &""

## Selection weight for B2's seeded pick (higher = picked more often).
@export var weight: float = 1.0
