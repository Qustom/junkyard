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


# --- Deterministic salted sub-streams (V6 / R7) ------------------------------
## Derive a LOCAL RandomNumberGenerator whose stream is a determinism-preserving
## sub-stream of `base`, salted by `salt`. Never touches this autoload's own
## generator, so sub-stream rolls neither perturb nor are perturbed by the
## layout/placement stream that fingerprint() pins. THE way to roll salted,
## reproducible randomness off a known base seed without desyncing generation.
##
## `base` is ALWAYS an explicit parameter — it is run_seed for pockets/exits and
## band.resolved_seed for placement/flavor, and is generally NOT seed_value (the
## autoload reseeds mid-run). Never default it to seed_value.

## XOR form — reproduces the pockets & exit-gate sub-streams BYTE-IDENTICALLY.
## Seed math: base ^ salt. Protocol: sets .seed ONLY (matches the two XOR sites,
## which never set .state — see V6 design Finding A: .seed-only and .seed+.state
## are DIFFERENT PCG streams; do not normalise the two forms).
func substream(base: int, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = base ^ salt          # .seed only — do NOT set .state here
	return rng

## Boost hash-combine form — reproduces the junk placer (index omitted) & the
## flavor stages (index given) BYTE-IDENTICALLY.
## Seed math: index < 0 -> mix(base, salt); index >= 0 -> mix(mix(base, salt), index).
## Protocol: sets .seed AND .state (matches junk_placer & both flavor stages).
## Real indices are array indices (>= 0); -1 is the safe "no index mix" sentinel.
func substream_hashed(base: int, salt: int, index: int = -1) -> RandomNumberGenerator:
	var h := _mix(base, salt)
	if index >= 0:
		h = _mix(h, index)
	var rng := RandomNumberGenerator.new()
	rng.seed = h
	rng.state = h                   # .seed AND .state — matches the three hash sites
	return rng

## The boost-style 64-bit hash-combine (formerly written verbatim in
## junk_placer._substream_seed and band_pipeline._mix — V6 Finding B). ONE
## definition now. Masked to a valid 63-bit int (mirrors the generator's mix).
func _mix(h: int, v: int) -> int:
	var mixed := (v + 0x9E3779B9 + ((h << 6) & 0x7FFFFFFFFFFFFFFF) + (h >> 2))
	return (h ^ mixed) & 0x7FFFFFFFFFFFFFFF
