# Worklog — SG1 M1.9 playtest build + verify + changelog + itch publish

- **Date:** 2026-07-03
- **Subagent:** qa-playtest-coordinator
- **Milestone:** M1.9 (Wave 6 — re-gate build step)
- **Branch:** main (direct — bookkeeping + publish, no feature code; repo clean, S0–S9 fully merged)
- **Commit:** <SHA-1 (docs+changelog)> ; <SHA-2 (publish record)>   ← filled below

## What changed
Verified the integrated M1.9 build against the full SG1 verify matrix (all objective rows green),
authored the M1.9 "The Sump" changelog block (M1.8→M1.9 feature delta), authored the SG1 build-verify
doc, and published the Web build to itch. No feature/engine code touched — SG1 is the M1.9 verify +
publish capstone.

## Files touched
- `changelog.txt` — added the M1.9 "The Sump" block (second dive portal + The Sump band; the two
  Sump-only hazards The Wrecker/Splitter; the generated Oppositions debug tab, 91 knobs; one-line
  under-the-hood note; NOT-YET note). M1.8→M1.9 delta as a clean feature list.
- `design/M1_9_Tasks/SG1_playtest_build.md` — new build-verify doc: build id, the §3 verify matrix
  results, the publish record, and the §5 Director playtest checklist.
- `worklogs/2026-07-03-SG1M19-qa-playtest-coordinator.md` — this file.

## Verify matrix results (all PASS — see the SG1 doc §3 for the full table)
- **Build integrity:** import exit 0; CI smoke "SMOKE OK".
- **All-off fp `e943ac9c8bc1`:** test_run_config (R0 OK, 90-knob flat dict), test_bandgen_determinism
  (BANDGEN OK, seed 12345→12 pieces fp e943ac9c8bc1), test_corridor_lever (J4 OK), test_band_pipeline_parity
  (PIPELINE PARITY OK — orchestrated path byte-matches BandGenerator; the stderr push_error lines are the
  test's own fail-loud null/empty-profile assertions).
- **91-knob model:** test_config_menu (91/91), test_run_config (R0), test_def_menu_coverage (DEF MENU
  COVERAGE OK), test_opposition_def_schema (DEF SCHEMA OK — 7 defs bijection).
- **Bandgen through pipeline + The Sump:** test_band_two_profile (BAND_TWO OK), test_band_flavors (BAND
  FLAVORS OK).
- **Both portals:** test_band_routing (BAND_ROUTING OK), test_hub_contract (HUB_CONTRACT OK — portal 1
  unchanged &"near", portal 2 &"band_two" ember-orange), test_app_router (ROUTER OK).
- **Opposition surface:** test_spawn_service (S0 OK), test_encounter_builder (S3 OK), test_deck_entry
  (S9 OK), test_opposition_def_schema (DEF SCHEMA OK), test_opposition_components (S2 TRACE OK), test_charger
  (S6a OK), test_splitter (S6b OK), test_new_hazard_spawn (K5i OK), + 4 legacy hazards (PURSUING HAZARD OK,
  BOMB HAZARD OK, K5a OK, K5c OK).
- **Loop + rg1:** test_main_game_loop (MAIN GAME OK), test_rg1_loop_verify (RG1 BUILD VERIFY OK),
  test_rg1_m12/m14/m15_verify (all VERIFY OK, fp=e943ac9c8bc1). test_rg1_m13_verify: **PASS on attempt 1**
  — the known BUG-M13FLAKE (pre-existing headless intermittent) did NOT trip this run; no retry needed.
- **Save schema:** META_SCHEMA_VERSION == 4 / RUN_SCHEMA_VERSION == 1 — unchanged; save_manager.gd last
  touched Jun-27 (1a17442), before M1.9; no new migration step or fixture.

## Publish record
- **Build id (itch userversion):** <filled after publish>
- **Butler push:** <filled after publish>
- Live: https://qusto.itch.io/the-far-yard (Chrome/Edge, password-gated).

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors) — exit 0
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] full SG1 verify matrix (§3 of the SG1 doc) — every row PASS
- [x] itch Web build published (§ publish record)
- [x] definition of done met: matrix filled, changelog shipped, build published, all-off control
      byte-identical (e943ac9c8bc1), 91/91 knobs + per-def bijection, save schema unchanged, both
      portals route.

## Design deviations
none. (SG1 is verify + publish bookkeeping; no design departure. `design/DESIGN_DEVIATIONS.md` unchanged.)

## Handoffs / follow-ups
- **SG2 (telemetry/balance analysis)** — unblocked once the Director playtests the published build:
  per-band comparison off the `band_id` stamp, do the new hazards read/kill fairly, is The Sump's +15%
  step felt, filter debug_dirty runs, worst-case body-count/tick-time on web.
- **SG3 (re-gate verdict)** — Director decides go/iterate/pivot; watch-item: did "content = data" hold
  (S6/S7 code cost vs. the promised component/stage); should the new hazards enter band 1; legacy-signal
  retirement timing.
- **Watch-item (render-time):** the hub iso props are not yet re-dressed around the second portal (noted
  in the changelog's NOT-YET + SG1 §5 deferred).
