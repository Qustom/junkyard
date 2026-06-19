# Worklog — BUG4 Branch-rate-independent socket seal

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.2 (Wave 1)
- **Branch:** gp/BUG4
- **Commit:** 8018c447aaf992db273aab21a4ddbfe60ec54c9a

## What changed
Generalised `SocketSealer.seal_unused_sockets` from **frontier-keyed** (capping only
`band.open_sockets`) to **geometry-keyed**: build ONE band-global FLOOR set across all pieces
(`Vector2i -> PlacedPiece owner`, from each `PlacedPiece.floor_cells`), then for every floor
cell cap each outward 4-neighbour that is not itself floor (writing a WALL via the unchanged
`_place_wall_cap`). The `floor_set.has(n)` guard automatically protects mated doorways (a
doorway's outward neighbour is another piece's floor, hence in the global set), so the pass is
the exact inverse of the test's `_count_floor_facing_void` leak condition → 0 void-facing cells
by construction, independent of branch rate. Replaced (deleted) the old `open_sockets` loop and
the now-dead `_opening_lane_cells` helper (Resolved Q1: the geometry pass is a strict superset).
Kept `_place_wall_cap`, `GREYBOX_SOURCE_ID`, `WALL_ATLAS` verbatim; no public API change; the
`main_game.gd` call site is unchanged. Updated the class doc comment to the generalised
perimeter-floor (not frontier-only) contract.

Extended `tests/test_bandgen_determinism.gd` with a BUG4 high-branch sweep
(`_run_bug4_high_branch_checks`) across `r4_branch_per_depth` ∈ {0.12, 0.15, 0.18, 0.20} ×
9 seeds (past the W2-R4-1 failure point, `max_branch_depth=64` so forks span the band): asserts
`_count_floor_facing_void == 0` after sealing on every (rate, seed); fingerprint byte-identical
pre/post seal; connectivity holds before AND after sealing (no doorway capped); plus a
non-vacuous guard that fails unless at least one UNSEALED band actually leaked at
`branch_per_depth ≥ 0.12` (and at least one band branched).

## Files touched
- `systems/bandgen/socket_sealer.gd` — geometry-keyed global-floor-set perimeter seal; deleted
  `_opening_lane_cells` and the `open_sockets` loop; updated class doc.
- `tests/test_bandgen_determinism.gd` — added BUG4 high-branch sweep (checks #8–#11) + helpers
  `_run_bug4_high_branch_checks`, `_make_high_branch_config`, `BUG4_BRANCH_RATES`.

## Checks run
- [x] `godot --headless --import` clean (no parse/script errors; pre-existing `.translation`
  missing-file warnings are unrelated, import exit 0)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy` (exit 0)
- [x] `godot --headless res://tests/test_bandgen_determinism.tscn` → BANDGEN OK / BUG3 SOCKET
  SEAL OK / R4 NAV OK / **BUG4 BRANCH-RATE-INDEPENDENT SEAL OK** (exit 0)
- [x] Diagnostic sweep (throwaway, since removed) confirmed non-vacuity: across
  {0.12,0.15,0.18,0.20} × 9 seeds the UNSEALED bands leaked 4–24 void-facing cells each
  (508 total), and ALL went to 0 after sealing, with 0 fingerprint mismatches.
- [x] Definition of done met (quoted below)

**Definition of done (quoted):** "A determinism+seal sweep at high branch rates
(`branch_per_depth` 0.12–0.20) shows 0 void-facing cells on every seed; fingerprint
byte-identical pre/post and unchanged vs baseline; no doorway regressions (connectivity
flood-fill still passes); existing seal/determinism tests + smoke green." — met: post-seal leak
count 0 on every (rate, seed); fingerprint byte-identical pre/post and the all-off control still
byte-matches the M1.0 baseline (R4.1 still green); `is_band_connected` passes pre AND post seal;
BUG3/R4/smoke all green.

## Design deviations
none — implemented exactly per `design/M1_2_Tasks/BUG4_robust_seal.md` §2 and its Resolved
Decisions (REPLACE the `open_sockets` pass, ONE global floor set, exact doorway guard, stays in
`socket_sealer.gd`, visible greybox WALL cap, `_cell_size_px` ignored).

## Handoffs / follow-ups
- BUG4's high-branch sweep uses `r4_max_branch_depth = 64` (branch anywhere) to maximise branchy
  perimeter; this surfaces far more leaks (4–24/seed) than W2-R4-1's depth-8-capped 2–6/seed, so
  it is a strictly stronger stressor. No action needed.
- The sweep does NOT yet cover I1's enlarged room presets specifically (I1 is parallel in
  Wave 1). At integration, if I1 lands a larger room-count/size ceiling, extend the BUG4 sweep's
  config to that ceiling (the pass is O(total cells) and scale-correct in cell space, so no
  algorithmic change is anticipated — Resolved Q4).
