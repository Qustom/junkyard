class_name BandGenConfig
extends Resource
## BandGenConfig — tuning knobs for the B2 modular room-graph generator.
##
## Data-as-Resources (TDD §2): the band shape is authored in a .tres, not code,
## so designers can retune length / branching without touching the algorithm.
##
## Determinism note: only INTEGER-comparable fields feed branch-affecting
## decisions. `branch_chance` is the sole float, and for M1 it defaults to 0.0
## (strictly linear spine) so it never participates in a randf() comparison on
## the layout path. Flip it >0 in a later milestone to enable forks; the
## generator already routes through the dormant branch code.

## Target number of pieces in the band (including the entry). ~12 for M1.
@export var target_piece_count: int = 12

## Fork probability per growth step. 0.0 = pure linear spine (M1 default).
## Kept as a live field so branching is a config change, not a rewrite.
@export var branch_chance: float = 0.0

## Candidate pieces tried per frontier socket before the socket is retired.
@export var max_place_attempts: int = 16

## Cyclic-loop stub. 0 for M1 (no loop logic). >0 later closes loops using
## the Band's retained occupancy set + open sockets. Field kept so the data
## contract is stable across milestones.
@export var loop_back_count: int = 0

## Soft floor for whole-band retry: if a finished band has fewer than
## ceil(target * soft_floor_ratio) pieces, discard and retry with a derived
## seed. Expressed as a percent (integer) to keep the comparison on int math.
@export var soft_floor_percent: int = 80

## Max whole-band retries (each with a deterministically derived seed) before
## the generator gives up and emits band_generation_failed.
@export var max_band_attempts: int = 8
