# Worklog — FBM19 Director playtest feedback fixes (post-SG1)

- **Date:** 2026-07-03
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.9
- **Branch:** general-purpose/FBM19
- **Commit:** 5dec90c391cd19ec22d44a7ca5cf4b2452d4ae5e

## What changed

Three Director-directed fixes from the `m1-20260704-8412732` playtest:

- **FB1 (BUG) — splitter sometimes shed NO children on throw-kill.** Root causes verified in
  code: (a) `spawn_service.gd::_cell_valid()` — the BUG7 entry-safe radius (2.5 cells) bound
  MID-RUN too, so a parent that chased the player back to the band entry and died there got
  BOTH shards refused; (b) `per_room_cap=2` on `splitter_child.tres` refused the second
  same-room brood. Fix: new explicit ctx escape **`"ignore_entry_safety": bool`** on
  `SpawnService.spawn()` (exact mirror of `ignore_room_cap`; skips ONLY the entry-radius
  refusal, never a cap tier; documented in the service header's ctx-key list + S0 doc §10).
  `splitter.gd::_do_split()` now sets `ignore_entry_safety` + `ignore_room_cap` on child ctx —
  a split at the death point is gameplay, not room dressing. The REAL ceilings stay:
  `per_band_cap=8` + the `&"new_hazards"` group cap 48 still refuse with `&"split_refused"`
  telemetry (D-RAT-2 holds).
- **FB2 (BUG/balance) — Wrecker + Splitter never appeared deep.** Verified:
  `encounter_builder.gd::_populate_deck()` walked pieces shallow-first, so the 27-credit
  budget + per-band caps exhausted on shallow pieces and the deep half of The Sump stayed
  empty. Fix: deck lane is now DEF-MAJOR with per-def **even-spread across the eligible piece
  depth range** (the J2 `even_spread` precedent — placement i targets piece
  `round(i/(n-1) * (P-1))`, so t=1 reaches the DEEPEST piece by construction; a single
  placement lands mid-band). Plan size is bounded UP FRONT by budget affordability + the
  def's own `per_band_cap` (load-bearing: an unbounded plan would burn its deep slots on
  refusals and re-cluster shallow). Zero RNG, stable order, per-piece
  `valid_cells`/filter-then-stride discipline kept, neutral cards still skipped, refusals
  still never spend. Legacy lane byte-untouched; all-off + band_greybox controls untouched by
  construction (deck lane only runs on deck bands) — fp `e943ac9c8bc1` re-pinned green.
- **FB3 (DESIGN) — splitter beelined from spawn.** Verified: `splitter.gd:134` ticked
  `tick_chase()` unconditionally. Fix: new schema'd param **`aggro_radius`** (float px, both
  defs): the splitter idles (LethalContact still ticks — bumping a dormant Fault is still a
  catch) until the player FIRST comes within `aggro_radius`, then latches aggro permanently
  (no de-aggro). `aggro_radius = 0` = legacy always-chase. Deterministic run-state distance
  test, no RNG. Auto-surfaced in the Oppositions tab via the schema row + a
  `CFG_GLOSS_SPLITTER_AGGRO` gloss.

**Aggro default reasoning (Director-delegated choice):** parent `aggro_radius = 160.0` px —
matches the charger's existing `aggro_range: 160.0` precedent (the other band-2 predator's
wake distance), and ≈ the vertical half-view (1152×648 window at camera zoom 2 → 576×324 px
world view, half-height 162 px), i.e. "roughly when it comes on screen / the player would
see it"; = 10 cells at 16 px, comfortably outside catch_radius 24. Child `aggro_radius = 0.0`
(legacy always-chase): shards are born of a player-caused split — they have by definition
already "seen you" — and 0 keeps mid-run children behaviourally identical to pre-FBM19.
Both are Director-tunable in the generated Oppositions menu.

## Files touched

- `Game/systems/spawning/spawn_service.gd` — `ignore_entry_safety` ctx escape (spawn() +
  header ctx-key list). Typed, minimal; `can_afford()`/`valid_cells()` untouched.
- `Game/scenes/hazards/splitter.gd` — FB1 child-ctx escapes in `_do_split()`; FB3 aggro
  latch (`_aggro_radius`/`_aggroed`, resolved in `setup()`, gate in `_physics_process`).
- `Game/systems/spawning/encounter_builder.gd` — FB2 `_populate_deck` rewrite (def-major +
  even-spread + up-front plan bounding); header lane doc updated.
- `Game/data/oppositions/splitter.tres` — `aggro_radius: 160.0` param + schema row.
- `Game/data/oppositions/splitter_child.tres` — `aggro_radius: 0.0` param + schema row.
- `Game/ui/config/config_strings.csv` — `CFG_GLOSS_SPLITTER_AGGRO` gloss row.
- `Game/tests/test_spawn_service.gd` — (f) extended: escape skips ONLY entry safety;
  per_band/cap_group/per-room tiers still bind with it set.
- `Game/tests/test_splitter.gd` — new (H) FB1 escapes (entry-radius split sheds 2; same-room
  double-split sheds 4; zero `split_refused`; case (C) still proves cap refusal), new (I)
  FB3 latch (idle outside / latch inside / persists on leave / 0 = legacy), (A) pins the new
  aggro defaults (160 / 0).
- `Game/tests/test_encounter_builder.gd` — case (6) updated to the directed def-major order
  (+ shallow→deep within-def assert); new case (11): REAL band_two deck — charger + splitter
  each place ≥ 2, reach the deepest third of the eligible pieces, do NOT abandon the shallow
  range, and the same (seed + config) twice yields an identical ordered spawn set.
- `design/M1_9_Tasks/S0_spawn_service.md` — §10 as-built amendment recording the new ctx key.

## Checks run

- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] All-off fp `e943ac9c8bc1` byte-identical: `test_bandgen_determinism`,
      `test_corridor_lever`, `test_band_pipeline_parity` — all OK
- [x] `test_spawn_service` OK (new escape case), `test_splitter` OK (H/I cases; pre-existing
      ObjectDB leak warning verified present on the base commit too, exit 0),
      `test_encounter_builder` OK (case 6 def-major + case 11 depth spread)
- [x] `test_charger` OK (def pins + deterministic deck placement, count 4 = per_band_cap),
      `test_deck_entry` OK, `test_band_two_profile` OK (9 seeds),
      `test_opposition_def_schema` OK (7 defs, bijection holds with the new param),
      `test_opposition_components` OK (all 5 golden traces byte-identical),
      `test_config_menu` OK (91/91), `test_def_menu_coverage` OK, `test_run_config` OK
- [x] Full hazard suite OK: `test_new_hazard_spawn`, `test_pingpong_hazard`,
      `test_bomb_hazard`, `test_spike_hazard`, `test_pursuing_hazard`, `test_hazard_spread`
- [x] Integration verifies OK: `test_rg1_m14_verify`, `test_rg1_m15_verify`,
      `test_rg1_loop_verify`
- [x] Definition of done: "fix all three [FB1/FB2/FB3] … all-off fp byte-identical … all
      listed suites green. Import + smoke green." — met (matrix above)

## Design deviations

**none** — all three behaviour changes are Director-directed (FBM19 brief), so they are not
deviations. No departures from the brief itself: the FB2 test-expectation update in
`test_encounter_builder` case (6) (piece-major → def-major order) is the directed
distribution change's direct consequence, and the child def's `aggro_radius = 0.0` default
and the parent's `160.0` are the brief-delegated choices documented above.

## Handoffs / follow-ups

- FB2 changes the deck lane's spawn ORDER vocabulary (def-major). If a future SG-gate doc
  describes the deck walk as piece-major, `encounter_builder.gd`'s header + this worklog are
  the as-built references.
- `aggro_radius` (160/0) is live in the Oppositions tab for Director tuning at the re-gate.
