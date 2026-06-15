extends Node
## RNG — the single seeded RNG service (TDD §2: "deterministic, seeded RNG").
##
## All procedural assembly and any gameplay randomness MUST go through this
## service so runs are reproducible for debugging and daily-seed/leaderboard
## modes. Do not call the global randi()/randf() — call RNG.* instead.

var seed_value: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	seed_from(0)

## Reset the stream to a known seed. Call at run start with the run's seed.
func seed_from(value: int) -> void:
	seed_value = value
	_rng.seed = value
	_rng.state = value  # reset state too, so the same seed → the same sequence

func randi() -> int:
	return _rng.randi()

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func randf() -> float:
	return _rng.randf()

func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

## Deterministic pick from a non-empty array.
func pick(arr: Array) -> Variant:
	assert(not arr.is_empty(), "RNG.pick() on an empty array")
	return arr[_rng.randi() % arr.size()]
