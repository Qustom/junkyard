# Worklog — VG1-fix Scrub 2 stale tests silently passing on a V3b script error

- **Date:** 2026-07-11
- **Subagent:** general-purpose
- **Milestone:** M1.12
- **Branch:** feat/VG1-fix-stale-tests
- **Commit:** `81f92b37d6f8251b0f4d0b8d670fbe440bb3574c`

## What changed
VG1's regression sweep found two tests still calling APIs that V3b (`f4dddff`, the pursuer
deck-migration) deleted from production code. Both tests hit a `SCRIPT ERROR` mid-assertion, but
Godot's headless scene auto-quit still exits 0 afterward, so they read green in CI while actually
verifying nothing past the error line. Both refactors are correct; only the tests were stale.
TEST-ONLY changes — no production `.gd`/`.tres` touched.

**FIX 1 — `Game/tests/test_new_hazard_spawn.gd`:** line 149 called
`MainGame._piece_floor_bounds_world(cells)`, deleted by V3b (its only production caller was
retired with the R1 pursuer machine). Added a local `_floor_bounds_world(cells)` +
`_cell_to_world(cell)` helper pair that reproduces the exact projection the surviving
`EncounterBuilder._floor_bounds_world(cells, svc)` uses (`svc.cell_to_world`, verified against
`systems/spawning/spawn_service.gd:219-221`: `Vector2(cell * cell_size) + Vector2(cell_size,
cell_size) * 0.5`), using the test's own `CELL` const (16, matching `DEFAULT_CELL_SIZE_PX`) instead
of a live `SpawnService` instance. Replaced the dead call at line 149 with `_floor_bounds_world(cells)`.
The K5i ctx-building assertions (vi) downstream of that line now execute for real.

**FIX 2 — `Game/tests/test_rg1_m13_verify.gd`:** `_verify_cfg_boots_default_preset` (lines
329-343) read `working.r1_enabled`, a `RunConfig` property V3b deleted along with the entire
`r1_*` knob group (the pursuer is now a `band_greybox` deck card). Replaced the dead knob read
with the correct post-V3b signal — a non-neutral `working.param_overrides["pursuer"]` bag
(`base_count > 0` or `count_per_depth > 0.0`) — mirroring the identical pattern already used a few
lines above in `_verify_default_preset_shape` (the `po` variable). The J1 "boots into the F1
default play-preset" assertion now actually runs and passes.

**Audit:** grepped all of `Game/tests/` for every stale-symbol pattern named in the task brief.
Found zero other live references to a deleted symbol — every remaining hit is either (a) a
comment/docstring documenting the V3b/V3 deletion (e.g. `_hazard_spawn_depths`,
`_density_spawn_positions`, `.r1_`, `hpp_`/`hbomb_`/`hspike_`, `_evaluate_quota`,
`hazard_pursuer_state`, all mentioned only in `##`/`#` prose), (b) a failure-message *string*
naming the old knob for human readability while the code itself reads the current entity-local
`params["kills"]` bag (`test_bomb_hazard.gd`, `test_pingpong_hazard.gd`, `test_spike_hazard.gd`),
or (c) a live reference to a symbol that is NOT actually deleted (`spawn_weights_by_id` on
`JunkCatalog`, confirmed still exported in `data/junk/junk_catalog.gd:20` and read in
`systems/depth/junk_placer.gd:169` — this is the current symbol, not the retired bare
"spawn_weights" array the brief warned about). No live retired-signal `.connect()` calls found
(`hazard_awoke`/`hazard_caught`/`new_hazard_killed`/`bomb_pulse_started`/`throw_killed_hazard`/
`hazard_pursuer_state` — all already migrated to the generic `opposition_event` /
`opposition_killed_player` signals). `_stage_seed` / `_substream_seed` / `_emit_family`: zero hits
anywhere in `tests/`.

## Files touched
- `Game/tests/test_new_hazard_spawn.gd` — replaced the dead `mg_ctx._piece_floor_bounds_world(cells)`
  call with a new local `_floor_bounds_world` / `_cell_to_world` helper pair
- `Game/tests/test_rg1_m13_verify.gd` — replaced the dead `working.r1_enabled` read in
  `_verify_cfg_boots_default_preset` with a `param_overrides["pursuer"]` non-neutral check

## Checks run
- [x] `godot --headless --path Game --import` clean (ran once at session start; no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0
      architecture spike healthy`
- [x] `godot --headless --path Game res://tests/test_new_hazard_spawn.tscn` — BEFORE: `SCRIPT
      ERROR: Invalid call. Nonexistent function '_piece_floor_bounds_world' in base 'Node2D
      (MainGame)'.` at `test_new_hazard_spawn.gd:149`, exit 0 (silent pass — the "K5i OK" line
      never printed). AFTER: prints `K5i OK — new-hazard spawn seam verified: ...`, ZERO
      `SCRIPT ERROR`/`Invalid call`/`Nonexistent function` lines in stderr, exit 0 (real pass).
- [x] `godot --headless --path Game res://tests/test_rg1_m13_verify.tscn` — BEFORE: `SCRIPT ERROR:
      Invalid access to property or key 'r1_enabled' on a base object of type 'Resource
      (RunConfig)'.` at `test_rg1_m13_verify.gd:338`, exit 0 in 2 of 3 runs (silently printing
      `RG1 M1.3 VERIFY OK ...` despite the mid-run error — exactly the silent-pass regression), and
      exit 1 in the 3rd run purely because of the pre-existing, unrelated BUG-M13FLAKE
      (`nav_branch_taken`/`return_cost_incurred` telemetry-timing race — confirmed present in that
      run's failure text and NOT connected to `r1_enabled`). AFTER (3 repeat runs): ZERO
      `SCRIPT ERROR`/`Invalid call`/`Invalid access`/`Nonexistent function` lines in any run; run 3
      printed a clean `RG1 M1.3 VERIFY OK ...`; runs 1-2 still hit BUG-M13FLAKE (same telemetry
      race, unrelated to this fix, exit 1 for the flake's own reasons — not the r1_enabled error).
- [x] `godot --headless --path Game res://tests/test_band_pipeline_parity.tscn` → `PIPELINE PARITY
      OK — BandPipeline byte-matches BandGenerator across 9 seeds (sample seed 12345 -> 12 pieces,
      fp=e943ac9c8bc1)` — fingerprint unmoved, exit 0.
- [x] `godot --headless --path Game res://tests/test_greybox_deck_equivalence.tscn` → `V3 EQUIV OK
      ...`, exit 0.
- [x] `godot --headless --path Game res://tests/test_pursuer_deck_equivalence.tscn` → `V3b EQUIV OK
      ...`, exit 0.
- [x] Definition of done met: both fixed tests print their real OK line, emit zero script-error
      lines, and exit 0 for the right reason; the audit covered every symbol named in the brief with
      a recorded disposition; no production `.gd`/`.tres` file was touched (`git diff --stat`
      confirms only the 2 test files changed).

## Design deviations
None. This is a test-hygiene fix only — the V3b/V3 refactors it adapts to are correct and
unchanged; no GDD/Technical Design/task-spec departure.

## Handoffs / follow-ups
- BUG-M13FLAKE (the intermittent `nav_branch_taken`/`return_cost_incurred` telemetry-timing race in
  `test_rg1_m13_verify.gd`'s M5/all-on row, ~2/5 runs in this session) is pre-existing and out of
  scope for VG1-fix per the task brief — flagged here again for whoever picks up that flake so it
  isn't rediscovered from scratch.
