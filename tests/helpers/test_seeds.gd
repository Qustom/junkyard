class_name TestSeeds
extends RefCounted
## Shared canonical seeds + RNG factory for the GdUnit4 determinism suites (G2).
##
## Two jobs:
##   1. A stable, named list of seeds every determinism test draws from, so the
##      whole suite exercises the same spread and "did seed X regress?" is legible.
##   2. A factory that builds a *fresh, local* RandomNumberGenerator from a seed
##      WITHOUT touching the `RNG` autoload — the as-built sub-stream pattern
##      (M1_As_Built "Deterministic sub-streams"). Tests that need their own
##      reproducible stream use this; they never reseed the global autoload, which
##      would perturb layout/placement determinism across the suite.
##
## NOTE on the autoload: BandGenerator.generate() reseeds the global `RNG` autoload
## internally (RNG.seed_from(seed) at the top of each attempt) — that is its real,
## as-built contract and the determinism property holds *because* of it (proven by
## test_layout_determinism's interleave + perturbation cases). This helper's local
## RNG is for tests that roll their own values (e.g. building random item sets),
## not for driving the generator.

## Canonical spread — mirrors the ad-hoc test_bandgen_determinism scene's seeds so
## the GdUnit4 suite and the legacy scene cover the same ground. Includes a
## negative and a large prime to catch sign/overflow assumptions.
const CANONICAL: int = 12345
const ALL: Array[int] = [12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]

## A second seed guaranteed distinct from CANONICAL, for "different seed differs".
const OTHER: int = 99999


## Fresh local RNG seeded deterministically — never touches the `RNG` autoload.
## Mirrors RNG.seed_from(): set both seed and state so the same seed yields the
## same sequence regardless of prior global state.
static func make_rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	rng.state = seed
	return rng
