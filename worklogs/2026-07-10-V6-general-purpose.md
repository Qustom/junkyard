# Worklog — V6 RNG.substream + substream_hashed helpers

- **Date:** 2026-07-10
- **Subagent:** general-purpose
- **Milestone:** M1.12
- **Branch:** feat/V6-rng-substream
- **Commit:** ed003f8e143f011c1d062364a4a99d5dc632eaa6

## What changed
Behavior-preserving refactor: promoted the five hand-rolled deterministic
sub-stream sites (2 idioms, boost hash-combine duplicated in 2 files) into ONE
discoverable surface on the `RNG` autoload — `RNG.substream(base, salt)` (XOR,
sets `.seed` only) and `RNG.substream_hashed(base, salt, index=-1)` (boost
hash-combine, sets `.seed`+`.state`; `index=-1` = single mix, `>=0` = double
mix), backed by a single `RNG._mix`. Migrated all five sites verbatim-equivalent
and adopted the rng-seam for the flavor stages (pipeline builds the rng, stages
receive it). ZERO behavioral change — every fingerprint byte-identical.

## Files touched
- `Game/systems/rng.gd` — added `substream`, `substream_hashed`, `_mix` (+docs).
- `Game/systems/game_state.gd` — pockets (Site 1): `RNG.substream(run_seed, POCKETS_RNG_SALT)`.
- `Game/scenes/game/main_game.gd` — exits (Site 2): `RNG.substream(GameState.run_seed, GameState.EXITS_RNG_SALT)`.
- `Game/systems/depth/junk_placer.gd` — junk (Site 3): `RNG.substream_hashed(band.resolved_seed, _JUNK_SALT)`; deleted `_substream_seed`.
- `Game/systems/bandgen/band_pipeline.gd` — driver call → `RNG.substream_hashed(...)`; deleted `_stage_seed` + `_mix`; updated RNG-discipline doc.
- `Game/systems/bandgen/stages/band_flavor_stage.gd` — `apply(...)` signature int → `RandomNumberGenerator`; updated doc.
- `Game/systems/bandgen/stages/wear_decay.gd` — `apply(...)` takes rng; deleted 3-line build block.
- `Game/systems/bandgen/stages/set_piece_inject.gd` — `apply(...)` takes rng; deleted 3-line build block.
- `Game/tests/test_band_flavors.gd` — re-pointed `BandPipeline._stage_seed(...)` → `RNG.substream_hashed(...)` (byte-identical).
- `Game/tests/test_rng_substream.gd` + `.tscn` — NEW per-site golden-equivalence test (goldens captured from the OLD idioms pre-migration).

## Checks run
- [x] `godot --headless --path Game --import` clean (no script parse errors; only pre-existing unrelated `.translation` load warnings)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK (exit 0)
- [x] `test_rng_substream` (NEW) → ALL GOLDENS PASS (5 derivations byte-identical + Finding-A cross-guard)
- [x] `test_band_pipeline_parity` → PARITY OK, fp=**e943ac9c8bc1** (all-off control unmoved)
- [x] `test_band_two_profile` → BAND_TWO OK
- [x] `test_band_three_profile` → BAND_THREE OK (band_greybox AND band_two byte-identical)
- [x] `test_bandgen_determinism` → BANDGEN OK, sample fp=e943ac9c8bc1
- [x] `test_band_flavors` → BAND FLAVORS OK (F5 re-pointed call verified)
- [x] `test_band_depth` → BAND DEPTH OK, junk plan fp=8f51e4edb126
- [x] `test_junk_catalog_by_id`, `test_junk_pickup` → OK
- [x] `test_exit_placement`, `test_exit_placement_count` → OK (run_seed ^ EXITS_RNG_SALT stream verified)
- [x] `procgen/test_layout_determinism` (GdUnit4, `--ignoreHeadlessMode`) → 7/7 PASSED (junk plan determinism + no-RNG-perturbation)
- [x] Definition of done: "every migrated sub-stream byte-identical; the four control layout fps stay byte-identical; a fingerprint move is a BUG." Met — no fp moved.

### Per-site before/after byte-equality
| Site | Derivation | Proof |
|---|---|---|
| Pockets (XOR, `.seed`-only) | `run_seed ^ POCKETS_RNG_SALT` | NEW golden G1 (randi + randi_range) — the sole guard; no prior pockets test |
| Exits (XOR, `.seed`-only) | `run_seed ^ EXITS_RNG_SALT` | NEW golden G2 + test_exit_placement(_count) |
| Junk (hash single-mix, `.seed`+`.state`) | `mix(resolved_seed, _JUNK_SALT)` | NEW golden G3 + test_band_depth junk fp + layout_determinism |
| Flavor ×2 (hash double-mix, `.seed`+`.state`) | `mix(mix(resolved_seed, salt), index)` | NEW golden G4 + test_band_flavors + band_two/band_three fps |
| Cross-guard (Finding A) | `substream(b,s) != substream_hashed(b,s)` | NEW golden G5: xor first draw 3824113673 ≠ hashed 88 |

Parity fp: **e943ac9c8bc1** (unchanged). band_greybox/band_two/band_three all byte-identical.

## Debt ledger
- **Sub-stream call sites:** 5 (pockets, exits, junk, wear_decay, set_piece_inject), 2 idioms → **1 surface** (2 helper forms), 5 one-line calls.
- **Boost hash-combine `_mix` copies:** 2 verbatim (`junk_placer._substream_seed`, `band_pipeline._mix`) → **1** (`RNG._mix`).
- **Deleted:** `junk_placer._substream_seed`, `band_pipeline._stage_seed` + `_mix`, the two flavor-stage 3-line build blocks (rng-seam, OQ3).
- Net LOC ≈ neutral (+42 in rng.gd incl. docs, −52 across the five sites). Win is discoverability + one-way-to-do-it + duplication collapse.

## Design deviations
None. Ships exactly the two-form surface + one `_mix`, all five sites migrated
verbatim-equivalent, salts left in place (OQ2), rng-seam adopted (OQ3),
mandatory pockets golden + Finding-A cross-guard added (OQ4/OQ5), test re-point
byte-identical. No fingerprint moved. No item required Director review.

## Handoffs / follow-ups
- The GdUnit4 suite `procgen/test_layout_determinism.gd` must be run with
  `--ignoreHeadlessMode` (it refuses headless otherwise; exit 103).
- Startup note for the orchestrator: `git switch -c` must be run inside THIS
  worktree — an initial stray `git switch -c` landed on the shared checkout and
  was reverted (shared restored to `main`, stray branch deleted) before any work.
