class_name WearDecayConfig
extends Resource
## WearDecayConfig — authored config for the WearDecay flavor stage (M1.9 S5).
##
## Decay takes the SAME layout and decides, per seed, how ruined it is (e5):
## breaches (perimeter wall -> floor shortcuts) and blocks (doorway floor ->
## wall detours), on a local sub-stream. OFF-FINGERPRINT but layout-touching:
## the piece list is untouched (fingerprint() byte-stable) while the walkable
## graph changes — Band.floor_fingerprint() is the wear-aware determinism bar
## (spec §1.4 / §6.1).
##
## Deferred from e5's knob list (spec §4.1): rubble_density (needs props),
## destructible_in_run (a new player verb — Director/M2), Exposure coupling
## (no Exposure system in M1; depth_bias is the M1.9-shaped stand-in, §10 Q6).

## Names the ruin fiction + the greybox tint on decay-touched pieces
## (&"collapsed" = warm grey-brown, &"flooded" = blue-green — D-RAT-1: band
## two authors &"flooded"). The op budgets below stay the authored knobs.
@export var state: StringName = &"collapsed"

## e5's master knob, 0..1 — scales both op budgets (ceil(budget * level)).
@export var decay_level: float = 0.5

## Max breaches attempted at decay_level 1.0. Breaches run FIRST (hardcoded,
## §4.2): on the as-built tree bands every doorway is a bridge, so blocks can
## only land where a prior breach created a cycle.
@export var breach_budget: int = 2

## Max blocks attempted at decay_level 1.0. Each block is tentative:
## reject-on-disconnect (e5's non-negotiable) reverts any block that strands.
@export var block_budget: int = 2

## > 0 -> deeper pieces preferentially decayed (depth_norm-weighted block pick).
@export var depth_bias: float = 0.0

## Breach opening width in cells. 2 = the canonical socket/doorway width,
## guaranteed player-traversable (§10 Q9 — ships as default, knob exposed).
@export var breach_width: int = 2

## Per-stage sub-seed salt ("WEAR"). Mixed with band.resolved_seed and the
## stage's flavors-array index (spec §2.2).
@export var salt: int = 0x57454152
