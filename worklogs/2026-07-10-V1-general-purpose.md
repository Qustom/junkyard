# Worklog — V1 Kill the index-aligned spawn weights (by-id map)

- **Date:** 2026-07-10
- **Subagent:** general-purpose
- **Milestone:** M1.12 (Wave 1)
- **Branch:** feat/V1-by-id-weights
- **Commit:** 17d35d28875e5f6ac2b917f4fe030810c83fd3f7

## What changed
Replaced `JunkCatalog.spawn_weights: PackedFloat32Array` (index-aligned with `items`)
with a by-**id** typed map `spawn_weights_by_id: Dictionary[StringName, float]`, per
D-RAT-2 / V1 Resolved Decisions. The one weighted read site (`JunkPlacer._weighted_pick`)
now looks up each item's weight BY ID while still iterating `indices` in stable
catalog-array order, so the RNG draw sequence — and the junk `plan_fingerprint` — is
byte-identical. The catalog CI check went from a size-only alignment assert (which could
not catch a mis-positioned insert) to semantic id-coverage + no-orphans + non-negative
mapping assertions. Added a logic-only mid-list-insert regression test.

Junk `plan_fingerprint` verified byte-identical before/after across 5 seeds (see Checks).

## Files touched
- `Game/data/junk/junk_catalog.gd` — swapped the `PackedFloat32Array` field for
  `Dictionary[StringName, float] spawn_weights_by_id` (+ docstring explaining by-id keying).
- `Game/data/junk/junk_catalog.tres` — regenerated: dropped the positional
  `spawn_weights` vector, added the 8-entry by-id map with the exact current values
  {scrap_bolt:40, cable_coil:30, copper_pipe:18, hubcap:14, circuit_board:4,
  car_battery:8, radiator:5, engine_block:2}. Header (uids, load_steps, ext_resources)
  left byte-for-byte unchanged for a minimal diff.
- `Game/systems/depth/junk_placer.gd` — `_weighted_pick` now resolves each eligible
  index's weight via `spawn_weights_by_id.get(id, 1.0)` (same maxf clamp, same
  SCALE=1000 round, same >=1 floor, same single `randi_range` draw). Determinism comment
  forbids iterating the map keys; docstring updated from "index-aligned" to "by-id".
- `Game/tools/check_junk_catalog.gd` — removed the meaningless size-only assert; added
  id-coverage (every item id has a weight), no-orphans (every weight key is a real item
  id), and non-negative assertions; annotated the existing duplicate-id walk as now also
  guarding the map. Still `quit(1)` on any failure. Docstring updated.
- `Game/tests/test_junk_catalog_by_id.gd` (+ `.tscn`, `.uid`) — **new** logic-only scene
  test: mid-list insert leaves every original weight unshifted (with an explicit contrast
  proving the old index model WOULD have shifted), inserted item resolves to the 1.0
  default, id-coverage flags the missing entry, and plan_fingerprint is invariant to map
  hash/insertion order (Q2 belt-and-suspenders).

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK (exit 0)
- [x] `godot --headless --path Game --script res://tools/check_junk_catalog.gd` → JUNK CATALOG OK (exit 0)
- [x] Checker EXITS NON-ZERO on failure — proven: temporarily dropped one weight entry →
      `JUNK CATALOG FAIL: item 'junk_scrap_bolt' has no spawn_weights_by_id entry`, exit=1;
      restored.
- [x] `res://tests/test_junk_catalog_by_id.tscn` → JUNK BY-ID OK (exit 0) — the new regression test
- [x] `res://tests/test_junk_pickup.tscn` → JUNK PICKUP OK (exit 0) — determinism/placement path unbroken
- [x] **Byte-identity proof:** captured junk `plan_fingerprint` for seeds {12345,777,2026,99,5150}
      BEFORE and AFTER the change (throwaway harness on the real `plan()`); all 5 fingerprints
      AND plan sizes identical:
      - 12345 → `8f51e4ed…f3f9` (n=24) — equal
      - 777 → `72fd0c0c…bd09` (n=26) — equal
      - 2026 → `f0e56390…bace` (n=26) — equal
      - 99 → `12c31a96…fe67` (n=25) — equal
      - 5150 → `0e79ddd0…b6bf` (n=27) — equal
- [x] definition of done met: "by-id weights resolve to the exact current values; catalog
      validation asserts id-coverage + no-orphans; inserting a test item mid-list does not
      misalign (regression test); junk plan_fingerprint byte-identical."

## Debt ledger
- **Fragility retired:** one positional-coupling invariant DELETED — an 8-element
  `PackedFloat32Array` hand-bound by index to `Array[JunkItem]`; any insert/remove/reorder
  silently transposed weights. Weights are now self-describing by id and cannot misalign by
  construction (class of bug eliminated, not mitigated). CI detection of the misalignment
  class went from ~0% (size-only count check) to 100% (id-coverage + no-orphans mapping check).
- **Net LOC:** +218 / −12 (≈ +206 net), of which the new regression test is ~175 lines. The
  non-test surface is ~neutral-to-slightly-positive (+3 gd, +7 tres net, +1 placer, +8 checker)
  — expected and correct for V1: its value is a retired invariant + strengthened gate, not
  deleted lines (the breakdown frames R2 as "net-neutral LOC but removes a whole class of
  silent-misalignment bug").

## Design deviations
none — implemented exactly per the V1 Resolved Decisions (by-id `Dictionary[StringName, float]`
on the catalog, clean rename no shim, array-order iteration in `_weighted_pick`, semantic
checker, dedicated regression test).

Note (not a deviation): CI wiring of `check_junk_catalog.gd` into `.github/workflows/`
(V1-Q4b in the breakdown) was explicitly REASSIGNED to task V8 by the orchestrator brief —
this task leaves the workflows untouched and only makes the checker correct + non-zero-on-failure.

## Handoffs / follow-ups
- V8 owns adding the `--script res://tools/check_junk_catalog.gd` step to `ci.yml` +
  `nightly.yml` (per D-RAT-2 / V1-Q4b). The strengthened checker is ready and green; it is
  inert until V8 wires it.
- V6 (Wave 2) also touches `junk_placer.gd`'s sub-stream — sequenced after V1 per the
  breakdown's cross-wave file-sequencing.
