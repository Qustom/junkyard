# Worklog — BUG7 new-hazard frame-0 spawn-kill on the entry cell

- **Date:** 2026-06-21
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.4 (Wave 5 — bug fixes)
- **Branch:** worktree-agent-a51d13ea6ef40ac6e
- **Commit:** 8d7abc012a96fc1d053b0636578f09a426046910

## What changed
Feedback #7 (CRITICAL, confirmed via telemetry session `s_384be7` runs 19–47): with the new
M1.4 hazards' `*_base_count >= 1`, `_spawn_new_hazards()` placed a hazard in EVERY graded piece
including the **depth-0 entry piece**, at a strided floor cell that could be the player's entry/
spawn cell. The player is placed AT `_entry_spawn_position(band)` BEFORE `_spawn_new_hazards`
runs, so a hazard landed on top of the player → instant lethal contact on frame 0 → every run
ended `cause=death duration_s≈0.01 depth=1`.

Fix (mirrors the existing `_exit_candidate_cells` entry-exclusion pattern; pure run-state, NO RNG):
1. **Skip the depth-0 entry piece entirely** for new-hazard placement (`if depth <= 0: continue`).
   Keeps the "shallow entry is safe, then it stirs" arc (I2 §2.4); deeper rooms still populate.
2. **Belt-and-braces radius filter** — drop any candidate cell whose world centre is within
   `NEW_HAZARD_SPAWN_SAFE_CELLS` (2.5 cell-widths = 40px at the default 16px cell, clearing the
   largest hazard kill radius) of the entry-spawn position. Catches deep pieces that straddle the
   entry in world space.
3. Threaded `spawn_pos` from `start_new_run()` into `_spawn_new_hazards(rc, band, spawn_pos)`
   (defaulted to a `Vector2.INF` sentinel → recomputed from band topology when not supplied, so
   the headless seam test path still applies the exclusion). Deterministic; never feeds `fingerprint()`.

The all-off control path (rc == null / every type disabled / neutral knobs) returns before any
placement, so it is untouched — fp stays `e943ac9c8bc1`.

## Files touched
- `scenes/game/main_game.gd` — added `NEW_HAZARD_SPAWN_SAFE_CELLS` const; threaded `spawn_pos`
  from `start_new_run` into `_spawn_new_hazards`; skip the depth-0 entry piece + filter cells
  within the safe radius of the entry spawn.
- `tests/test_new_hazard_spawn.gd` — updated (ii) base=1 over 3 rooms 3→2 and (iii) per-room cap
  6→4 to reflect the entry-piece exclusion; added assertion (vii) BUG7: with all three types
  base-heavy, ZERO hazards land in the depth-0 entry room and the nearest hazard is >= the safe
  radius from the entry spawn.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK (exit 0)
- [x] `godot --headless res://tests/test_new_hazard_spawn.tscn` → K5i OK (exit 0), incl. new (vii) BUG7 assertion
- [x] `godot --headless res://tests/test_rg1_m14_verify.tscn` → RG1 M1.4 VERIFY OK (exit 0); all-off control byte-identical, **fp=e943ac9c8bc1** UNMOVED; K5i still spawns >=1 of each new hazard kind
- [x] Definition of done met: "After the fix, `base_count >= 1` must spawn hazards in the band's other rooms but NEVER spawn-kill the player at frame 0." Verified by the spawn test ((ii) deeper rooms still populated) + (vii) (entry room empty, nearest hazard clear of the safe radius). All-off fp unchanged.

## Design deviations
None. The fix mirrors the established `_exit_candidate_cells` entry-exclusion pattern and the
I2 §2.4 "shallow entry is safe, then it stirs" arc. No knobs, scene contracts, or fingerprint paths
changed. Did not touch `run_config.gd`, `pingpong_hazard.gd`, or `test_rg1_m14_verify.gd` (other
Wave-5 agents own those).

## Handoffs / follow-ups
None. Orchestrator integrates (no merge/push performed here).
