class_name SetPieceInjectConfig
extends Resource
## SetPieceInjectConfig — authored config for the SetPieceInject flavor stage
## (M1.9 S5). Lives in BandProfile.flavors (a .tres can only hold Resources,
## so the flavors array holds stage-config Resources; the pipeline maps
## config-type -> RefCounted stage — spec §2.2).
##
## LAYOUT-AFFECTING under the (seed + config) determinism contract: a
## non-empty entries pool appends pieces and legitimately MOVES the band
## fingerprint(), deterministically — same seed + same profile always
## reproduces the same fp (spec §1.4). The injection draws ride a local
## sub-stream (resolved_seed ⊕ salt ⊕ index), never the RNG autoload, so the
## underlying spine draw sequence is untouched and the control layout is a
## strict prefix of the flavored one.

## The set-piece pool this band may inject from (per-band authoring, the
## Dead Cells biome-pool model).
@export var entries: Array[SetPieceEntry] = []

## Injection slots attempted per band (each slot picks one eligible entry).
@export var max_total: int = 1

## Per-stage sub-seed salt ("SETP"). Mixed with band.resolved_seed and the
## stage's flavors-array index (spec §2.2).
@export var salt: int = 0x53455450
