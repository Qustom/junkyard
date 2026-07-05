# Worklog — T0 CaveBackend: CA caverns generator + CaveBandConfig + pipeline backend dispatch

- **Date:** 2026-07-05
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.10 (Wave 1)
- **Branch:** worktree-agent-a8c1cc41010079646 (isolated worktree; `general-purpose/T0` role)
- **Commit:** f7d44d2cf4408c5fbf7329e1ac6af36006c02cbf (T0 code + tests + this worklog)

## What changed
Built the second generation backend behind the `BandPipeline` seam: a cellular-automata
caverns generator (`CaveBackend`) plus its integer-only config Resource (`CaveBandConfig`),
replacing the pipeline's `backend == "cave"` fail-loud with real dispatch and adding the
`BandProfile.validate()` cave branch. The CA produces genuinely irregular floor (seeded fill%
→ N smoothing passes → keep-largest flood region → deterministic carve of secondary regions →
2×2-open player-scale pass → west-most entry anchor), then partitions the kept floor into
grid-aligned chunks emitted as synthetic `PlacedPiece`s with content-hashed ids — so `Band`'s
data shape and `fingerprint()` stay backend-agnostic and the ENTIRE downstream stack
(DepthGrader / JunkPlacer / EncounterBuilder / ConnectivityGuarantee / materialisation seal) is
reused unchanged. All randomness is one block (`RNG.seed_from` then one fill roll per interior
cell in fixed scan order); everything after is a pure integer function of the grid.

## Files touched
- `Game/systems/bandgen/cave_backend.gd` — NEW. The CA backend (§3 + Phase-3 §10 amendments).
- `Game/data/bands/cave_band_config.gd` — NEW. Integer-only config schema + `validate()` (§2).
- `Game/systems/bandgen/band_pipeline.gd` — MOD. Backend dispatch replaces the cave fail-loud;
  socket path statements kept verbatim; cave-only post-backend connectivity ASSERT.
- `Game/data/bands/band_profile.gd` — MOD. `validate()` cave branch (needs CaveBandConfig, no
  piece_pool required; flavors-must-be-empty fail-loud lives here per Phase-3 amendment 1;
  archetype warn-not-error).
- `Game/tests/test_cave_backend.gd` + `.tscn` — NEW. Acceptance harness C1–C10.
- `Game/tests/test_band_pipeline_parity.gd` — MOD (the one allowed edit). P7 fixture: "unwired
  backend" case moves to `scatter`; the cave case now pins "cave profile with no CaveBandConfig
  → null" (fail-loud moved from wiring guard to `validate()`).

## Checks run
- [x] `godot --headless --path Game --import` clean (CaveBandConfig + CaveBackend registered; the
  only errors are pre-existing `*_strings.en.translation` generated-file artifacts, unrelated).
- [x] `godot --headless --path Game res://tests/test_cave_backend.tscn` → **CAVE BACKEND OK**
  (C1–C10 green across the 9-seed matrix; sample seed 12345 → 49 pieces, max_depth=12).
- [x] `test_band_pipeline_parity.tscn` → **PIPELINE PARITY OK**, sample fp `e943ac9c8bc1`.
- [x] `test_bandgen_determinism.tscn` → **BANDGEN OK** (+ BUG3/R4/BUG4), sample fp `e943ac9c8bc1`
  (the all-off control fingerprint is UNMOVED).
- [x] `test_band_depth.tscn` / `test_band_flavors.tscn` / `test_band_two_profile.tscn` → all OK
  (band_greybox + band_two socket paths byte-identical; also pinned in-suite by C9).
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK**.
- [x] Scope audit: diff touches only the §6 create/edit list (+ `.uid`s).
- [x] Definition of done met: "same seed → same fp twice; diff seed → diff fp; single connected
  FLOOR component via `is_band_connected`; region-keep + carve determinism across a seed matrix;
  2×2-open throat C10; rc-invariance C7; band_greybox+band_two byte-identical; all-off fp
  `e943ac9c8bc1` unmoved; existing bandgen suite + smoke green."

Note: `tests/procgen/test_layout_determinism.gd` is a GdUnit4 suite (un-vendored runner, not the
headless-scene path) exercising only `BandGenerator`/`JunkPlacer` — both untouched by T0.

## Bespoke-code ledger (M1.10 scalability evidence)
Non-data, non-test bespoke code needed for the second backend:

| File | Total lines | Code-only (non-blank, non-comment) |
|---|---|---|
| `cave_backend.gd` (the backend) | 544 | 404 |
| `cave_band_config.gd` (config schema + validate) | 96 | 44 |
| `band_pipeline.gd` dispatch diff | +16 code lines | +16 |
| `band_profile.gd` validate() cave branch | +11 code lines | +11 |
| **Total bespoke** | — | **~475 code lines** |

Test code (not counted): `test_cave_backend.gd` ~430 lines; parity P7 fixture +15.
**Everything downstream (grade, return-distance, junk, encounters, seal, telemetry) is 0 new
lines — reused verbatim.** That reuse is the scalability headline: a genuinely different
generator (no pieces, no sockets) slotted behind the one `BandPipeline` interface with the whole
post-backend stack untouched.

The backend came in above the spec's ~255-line estimate (see Deviation 2): the drivers are the
Q8 player-scale pass (component-connect loop + orphan-widening + `_flood_set`/`_compute_
traversable`/`_find_orphans`/`_widen_2x2`), the robust chunk-BFS `_pick_deepest_piece`, and
verbose typed locals + small single-purpose helpers (`_set_floor`, `_nearest_cell`, `_carve_l`).

## Design deviations
1. **Grid-level carve reads the breakdown's "existing CARVE mode" as a deterministic mirror, not
   a literal reuse** (Phase-3 Q4 ratifies this). The `ConnectivityGuarantee` CARVE mode is a
   journal-LIFO revert of a flavor stage's tile writes — structurally inapplicable inside a
   backend with no prior state. T0 mirrors the carve *concept* (zero-RNG, sorted-order grid
   carve) and *reuses* the stage's real checker (`is_fully_connected` via `Mode.ASSERT`) as the
   pipeline invariant. Flagged per the doc; no Director sign-off needed (technical, ratified).
2. **`cave_backend.gd` is ~404 code lines vs the spec's ~255 estimate.** Not gold-plating — the
   overage is real algorithm: the Q8 2×2-open guarantee is heavier than the ~35-line estimate
   (it needs T-component detection, connector carving, AND orphan-widening to satisfy the
   test-asserted C10 "every floor cell is member-of-or-adjacent-to-T"), and `_pick_deepest_piece`
   (~30 lines) is a beyond-spec robustness choice (see Deviation 3). Surfaced for the Wave-1
   close-out sweep as a magnitude note, not a design change.
3. **`deepest_piece` is chosen by a chunk-graph BFS (replicating DepthGrader's adjacency+BFS)
   rather than the spec's cell-BFS-farthest-cell's-owning-chunk.** The spec §3.5 asks the test to
   assert `deepest_piece.depth_index == band.max_depth` while itself admitting cell/chunk
   agreement "is not required" — a contradiction. Choosing the piece at maximum *chunk-hop* depth
   makes the equality hold by construction (my BFS matches the grader's exactly), so C4's
   assertion is sound. Backend-local, within file scope; ~30 lines recorded in the ledger.
   Recommend: keep (it makes the spec's own acceptance bar valid). No Director call needed.

All three appended to `design/DESIGN_DEVIATIONS.md` for the Wave-1 close-out sweep.

## Handoffs / follow-ups
- **T1 (materialisation):** T0 guarantees data-level enclosure (forced WALL border ring; every
  non-floor interior cell WALL; C4 asserts no floor on the ring) and touches no sealer code.
  Per Phase-3 Q3, T1 builds Geometry-bearing runtime instances writing FLOOR tiles only; the
  UNEDITED `SocketSealer` runs verbatim as the cave wall-writer. `entry_piece.floor_cells[0]` is
  the west-most 2×2-open anchor (Phase-3 amendment 2/Q10) — T1's `_entry_spawn_position` reads it
  unchanged. `cell_size_px` default 16 agrees with JunkPlacer's null-instance fallback.
- **T3 (band_three.tres):** author the config at `data/bands/cave_config_band_three.tres` with
  T0's integer knobs (56×56 · fill 45 · smooth 4 · wall_threshold 5 · min_region_cells 24 +
  defaults); no float `nook_roughness` (dropped per amendment 4). The default `CaveBandConfig`
  already ships 56×56; T3 re-pins `max_depth >= 4` + gate-reachability on its authored set.
- `CaveBackend.last_region_count` / `last_throat_carve_count` are public test-only stats fields
  (Q9) — read by C6/C10 non-vacuity; harmless in production.
