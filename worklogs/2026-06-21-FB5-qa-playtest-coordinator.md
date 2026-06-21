# Worklog — FB5 verify Director feedback #5 (exits "don't spawn heading further in")

- **Date:** 2026-06-21
- **Subagent:** qa-playtest-coordinator
- **Milestone:** M1.4 (Wave 5)
- **Branch:** worktree-agent-a1ca7b185c1e88515
- **Commit:** 3e1c95be8160720c3a7b529cf6ad7f97df68262c (worklog SHA-line updated in a follow-up commit)

## Verdict

**#5 is NOT a real bug.** Multi-exit placement works correctly. The Director's observation was an
artifact of feedback **#7** (the config-triggered instant-death runs, runs 19–47 of session
`s_384be7`): once `hpp_base_count`/`hspike_base_count` went 0→1, every run instant-died at depth 1
in ~0.01 s and never headed "further in," so no scattered exits were ever encountered.

## What changed

Added a focused headless regression test that proves exits place correctly at the EXACT config the
Director ran (the run-19 snapshot in `G4_findings_M1.4.md`: `exit_enabled=true`, `exit_base_count=2`,
`exit_count_per_depth=2.0`, `exit_keep_one_at_spawn=true`). No production code touched.

## Investigation (code path, end-to-end)

`_place_gate(band, spawn_pos)` (`main_game.gd:935`) with the Director's config, on a depth-3 band:
- `_exit_count_for_depth` = `maxi(2,1) + floor(2.0*3)` = `2 + 6` = **8** gates (no cap).
- `exit_keep_one_at_spawn=true` → 1 pinned at `spawn_pos + GATE_SPAWN_OFFSET`, the other **7** drawn
  from `_exit_placement_positions` → Fisher–Yates over `_exit_candidate_cells` (the stable
  depth-asc/(y,x) pool, entry + spawn-gate cells excluded), `mini(n, pool.size())` distinct cells →
  distinct world positions across multiple graded pieces.
- All-off (`exit_enabled=false` or nil config) short-circuits to exactly ONE gate at the offset.

The code is correct: count floored ≥1, depth-scaled, scattered, distinct. The placement RNG is the
LOCAL sub-stream `run_seed ^ EXITS_RNG_SALT` (never the global RNG), so it does not move
`fingerprint()`.

**Mental-model note (carried to the Director):** exits are placed ONCE per band at band-build time
across that band's graded pieces. Walking "further in" within the SAME band reveals no NEW gates
appearing — they were all placed up front, spread across depths. If the Director expected gates to
*appear as you advance*, that is a different (per-tick/respawn) mechanic explicitly deferred out of
M1.4 (K7 design DR-7). What exists is multi-exit *placement*, not multi-exit *spawning over time*.

## Files touched

- `tests/test_exit_placement_count.gd` — NEW. FB5 regression: asserts (a) enabled count == depth-scaled
  count and >1 at non-trivial depth, (b) gates at distinct positions scattered across multiple pieces
  (exactly 1 pinned at the spawn offset under keep-at-spawn), (c) all-off → exactly 1 gate at the offset.
- `tests/test_exit_placement_count.tscn` — NEW. Scene wrapper so autoloads + a live tree exist.

## Checks run

- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless res://tests/test_exit_placement_count.tscn` → **FB5 OK** (all asserts pass)
- [x] `godot --headless res://tests/test_exit_placement.tscn` → **K7 OK** (existing test still green)
- [x] `godot --headless res://tests/test_rg1_m14_verify.tscn` → **RG1 M1.4 VERIFY OK**, all-off
      fingerprint confirmed `e943ac9c8bc1` (my test does not move the fp — placement is run-state)
- [x] definition of done met: objective checks proving multi-exit placement; determinism (local
      sub-stream) unchanged; verdict answers the gate question (not-a-bug, #7 artifact)

## Design deviations

none. No production code changed; the test asserts the as-built K7 behaviour against the locked
Resolved Decisions (DR-1/DR-2/DR-6).

## Handoffs / follow-ups

- **Recommendation to Director:** treat #5 as resolved (not-a-bug). After the Wave-5 fix removes the
  #7 spawn-kill (entry-cell exclusion in `_spawn_new_hazards`), re-run with `exit_enabled=true` (and
  `hpp/hspike/hbomb base_count` set so runs survive) to *see* the scattered exits while diving deep.
  This new test is the regression guard.
- If the Director actually wants exits to **appear as you advance within a band** (not all placed up
  front), that is a net-new per-tick/respawn feature (K7 DR-7 deferral) → a new task, not a bug fix.
