# Worklog — B3 Band Depth / "Push Deeper" Structure

- **Date:** 2026-06-17
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1
- **Branch:** general-purpose/B3-band-depth
- **Commit:** ffbe8752418235dcfeb2c8ca365029976a859496

## What changed
Added the band **depth axis** on top of B2's connected band: every `PlacedPiece`
now carries `depth_index` (BFS hops from the entry gate), `depth_norm` (0..1),
and `dist_to_gate` (independent reverse BFS). A `DepthGrader` computes these as a
pure graph function over B2's FLOOR-cell adjacency (same definition B2 uses for
connectivity, so depth and traversability agree). A `DepthCurve` resource
(`depth_curve.tres`) holds the authored risk/reward tuning, and a `JunkPlacer`
turns a graded band + curve + `JunkCatalog` into a **deterministic placement
plan** (`Array` of `{ world_pos, item, depth }`) where each `item` is a
`duplicate(true)` with `base_sell_value` scaled by the depth value curve and tier
>= the depth's tier gate. A debug overlay draws per-piece depth/return-distance/
value and value-scaled junk markers. M1 stays linear (B2 `branch_chance = 0.0`),
so on the spine `depth_index`, `dist_to_gate`, and placement order coincide.

## Files touched
- `systems/bandgen/placed_piece.gd` — added `depth_index` / `depth_norm` / `dist_to_gate` (default-safe pre-grading).
- `systems/bandgen/band.gd` — added `max_depth` (set by the grader).
- `systems/depth/depth_grader.gd` — NEW. BFS depth + reverse-BFS return distance; pure, no RNG.
- `systems/depth/depth_curve.gd` — NEW. `DepthCurve` resource (value/density/tier_threshold Curves) + sampling helpers.
- `systems/depth/depth_curve.tres` — NEW. Authored M1 curves (shapes below). Generated via `ResourceSaver` for engine-correct format.
- `systems/depth/junk_placer.gd` — NEW. Deterministic depth-scaled placement planner; local RNG sub-stream.
- `entities/debug/depth_debug_overlay.gd` — NEW. Node2D debug viz (labels + value-scaled markers). Visualisation only — NOT the C2 pickup.
- `systems/event_bus.gd` — added `signal junk_spawned(item_id: StringName, depth: int)` (placement/telemetry; NOT `junk_picked_up`, which is C2's).
- `tests/test_band_depth.gd` + `tests/test_band_depth.tscn` — NEW. Headless acceptance test (scene-run, mirrors the B2 harness).

## DepthCurve shapes authored (`depth_curve.tres`)
- **value_curve** (per-item value multiplier vs `depth_norm`): near-linear rising, points `(0, 1.0) (0.5, 1.4) (1.0, 1.8)`. Applied as `base_sell_value * sample`.
- **density_curve** (expected items per piece): held roughly flat, points `(0, 2.0) (1, 2.3)`. A seeded probabilistic round turns the fractional expectation into an integer count.
- **tier_threshold_curve** (min unlocked tier vs depth): STEPPED, plateaus floored to ints — `depth_norm <0.25 → tier≥1`, `<0.5 → ≥2`, `<0.75 → ≥3`, else `≥4`.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless res://tests/test_band_depth.tscn` → `BAND DEPTH OK` (exit 0)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK` (exit 0)
- [x] `godot --headless res://tests/test_bandgen_determinism.tscn` → `BANDGEN OK` (exit 0; B2 not regressed)
- [x] definition of done met (all 6 assertions pass: grading correctness, plan determinism, value-rises-with-depth, tier gate, no RNG cross-talk, `duplicate(true)` isolation)

### Captured outputs
```
BAND DEPTH OK — graded 12 pieces (max_depth=11), planned 24 junk items; value rises with depth (shallow $31.9 -> deep $121.6), tier gate + plan determinism + no RNG cross-talk verified across 7 seeds (sample fp=8f51e4edb126)
SMOKE OK — M0 architecture spike healthy
BANDGEN OK — determinism + connectivity verified across 9 seeds (sample seed 12345 -> 12 pieces, fp=e943ac9c8bc1)
```
(`test_band_depth` exits 0; the only stderr is a benign "2 resources still in use at exit" cleanup notice from leftover loaded `.tres`, identical in spirit to the B2 harness — exit code is 0.)

## Design deviations
1. **RNG sub-stream instead of `RNG.fork("junk")` (spec skeleton).** The real `RNG`
   autoload (`systems/rng.gd`) has no `fork`/`set_seed`/`weighted_pick`/`stream`.
   `JunkPlacer` draws junk rolls from a **local `RandomNumberGenerator`** seeded
   from `band.resolved_seed` hash-combined with a fixed salt (`_JUNK_SALT`), and
   never touches the global autoload. This preserves both spec guarantees: same
   seed → same plan, and junk rolls never perturb the layout stream (verified by
   test #5: generate → plan → regenerate yields the same `band.fingerprint()`).
   *Per the briefing — recorded as required, low risk.*
2. **`JunkItem` / `base_sell_value`, not the spec's `Junk` / `base_value`.** The
   spec skeleton predates C1; the real junk Resource is `JunkItem` with
   `base_sell_value: int` and `tier: int` (`data/junk/junk_item.gd`). There is no
   `junk_pool.tres` — junk is sourced from `data/junk/junk_catalog.tres`
   (`JunkCatalog.items` + index-aligned `spawn_weights`), filtered by `tier` in
   code. *Naming/API alignment only; no behavioural change.*
3. **B3 produces a PLAN; C2 spawns it (scope seam).** Per the briefing, `JunkPlacer`
   returns an `Array` of `{ world_pos, item, depth }` rather than instantiating
   pickups. The interactive `JunkPickup` entity, A2 interaction wiring, inventory
   `try_add`, and `junk_picked_up` are **C2's** and were NOT built. No
   `entities/junk_pickup/` was created; the only entity added is a debug overlay
   (`entities/debug/`). EventBus gained `junk_spawned` (placement/telemetry), not
   `junk_picked_up`.
4. **Test runs as a SCENE (`.tscn`), not `--script`.** The DoD listed
   `godot --headless --script res://tests/test_band_depth.gd`, but `BandGenerator`
   emits through the `EventBus`/`RNG` autoloads, which are **not loaded under
   `--script`** (verified: "Identifier not found: RNG"). The existing B2 harness
   has the identical constraint and ships as a `.tscn`; this test mirrors that, so
   the runnable command is `godot --headless res://tests/test_band_depth.tscn`.
   *Harness mechanics only; all assertions are unchanged and pass.*
5. **`compute_return_distance` is a real reverse BFS, not the `= depth_index`
   shortcut.** Per the briefing recommendation, so divergent-branch return
   distances are already correct when B2's `branch_chance` goes > 0. On the linear
   M1 spine it provably equals `depth_index` (asserted by test #1).

## Handoffs / follow-ups
- **C2** consumes `JunkPlacer.plan(band, curve, catalog)` to spawn interactive
  `JunkPickup` entities at each `world_pos` carrying `item`, and owns
  `junk_picked_up` + inventory `try_add`. The plan's `world_pos` is the cell
  centre in band-pixel space (`cell * cell_size_px + cell_size/2`).
- The debug overlay (`DepthDebugOverlay.setup(band, plan, cell_size_px)`) is
  available for the "is the rise visible?" smoke check once a dive scene exists.
