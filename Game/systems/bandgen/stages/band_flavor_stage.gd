class_name BandFlavorStage
extends RefCounted
## BandFlavorStage — the M1.9 flavor-stage contract (S5, spec §2.1).
##
## One small RefCounted per flavor, one method: apply(band, profile,
## stage_seed) mutating the post-assembly Band in place. Phase A deliberately
## has no BandBuild — the Band IS the build state (§10 Q1); when a later
## non-socket backend introduces one, stages port by swapping the first
## parameter (internals speak only floor-cell/socket geometry).
##
## TRAITS (pipeline-enforced, never authored — §10 Q7): the pipeline re-grades
## after a stage whose mutates_pieces() is true, and runs the connectivity
## invariant after EVERY stage — CARVE mode (journal revert) when
## reshapes_floor() is true, ASSERT mode otherwise. Expressed as overridable
## methods because GDScript cannot shadow a base-class const (the spec's
## MUTATES_PIECES / RESHAPES_FLOOR consts, same contract).
##
## RNG DISCIPLINE (spec §0): a stage draws ONLY from the local
## RandomNumberGenerator the pipeline hands it — derived via
## RNG.substream_hashed(resolved_seed, salt, index) (the JunkPlacer sub-stream
## pattern, V6). No stage ever touches the RNG autoload.


## Pipeline re-grades (DepthGrader) after this stage when true.
func mutates_pieces() -> bool:
	return false


## Pipeline runs ConnectivityGuarantee in CARVE mode (with journal()) after
## this stage when true; ASSERT mode when false.
func reshapes_floor() -> bool:
	return false


## The stage's committed-op journal (CARVE revert surface). Empty for stages
## that never reshape floor.
func journal() -> Array:
	return []


func apply(_band: Band, _profile: BandProfile, _rng: RandomNumberGenerator) -> void:
	pass
