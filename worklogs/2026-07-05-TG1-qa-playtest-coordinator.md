# Worklog — TG1 M1.10 playtest build + verify + changelog

- **Date:** 2026-07-05
- **Subagent:** qa-playtest-coordinator
- **Milestone:** M1.10
- **Branch:** worktree-agent-a55256d7a61f69599 (isolated TG1 worktree; NOT main)
- **Commit:** 8308120f0479fb7e93e3d343cd70258d1fd12df4 (TG1 deliverables; worklog-SHA stamped in the immediate follow-up)

## What changed
Ran the full M1.10 verify matrix (import · smoke · three permanent controls byte-exact ·
cave determinism + materialisation · 9-def bijection + 91 knobs · all-three-portal routing ·
The Warren deck outcome · T2b binding riders · rg1 preset parity) and recorded every row in
`design/M1_10_Tasks/TG1_playtest_build.md`. Authored the TG1 build-verify doc (mirroring the
SG1 template, incl. the Director playtest checklist §5). Prepended the M1.10 — "The Warren"
feature-delta block to `changelog.txt`. Caught and corrected ONE red row — a stale test
expectation in `test_def_menu_coverage` (a T3 side-effect, not a product bug — see deviations).
Did NOT publish to itch (no `APIKEYS.md` in the worktree — orchestrator runs it from main) and
did NOT merge to main.

## Files touched
- `design/M1_10_Tasks/TG1_playtest_build.md` — NEW: the TG1 build-verify doc + filled verify
  matrix + Director playtest checklist.
- `changelog.txt` — prepended the M1.10 "The Warren" block (M1.9→M1.10 feature delta).
- `Game/tests/test_def_menu_coverage.gd` — corrected a STALE test expectation (test-only, no
  product change): splitter's IN-DECK chip now correctly surfaces BOTH `band_three` + `band_two`
  decks after T3 added splitter to The Warren's deck (D-RAT-6). See Design deviations.
- `worklogs/2026-07-05-TG1-qa-playtest-coordinator.md` — this worklog.

## Checks run
- [x] `godot --headless --path Game --import` clean (exit 0, no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → "SMOKE OK — M0 architecture spike healthy" (exit 0)
- [x] Three permanent controls byte-exact: all-off fp `e943ac9c8bc1` (test_run_config, test_bandgen_determinism, test_band_pipeline_parity, all rg1 verifies); `band_greybox` + `band_two` byte-identical (test_band_three_profile asserts both)
- [x] Cave: test_cave_backend ("CAVE BACKEND OK", fp `d984fd8913bf`, 49 pieces, max_depth 12) · test_cave_materialise ("CAVE MATERIALISE OK", socket materialise byte-identical)
- [x] Oppositions: test_ambusher ("T2a OK") · test_burrower ("T2b OK", incl. kill_radius-34 surfacing-frame + wall-clear surfacing riders) · test_opposition_def_schema ("DEF SCHEMA OK — 9 defs", bijection green)
- [x] Routing: test_hub_contract ("HUB_CONTRACT OK — 4 interactables", 3 portals: near/band_two/band_three) · test_band_routing ("BAND_ROUTING OK", all 3 routes distinct fp, band_id == route key)
- [x] Coverage: test_config_menu ("CONFIG MENU OK — 91/91 knobs") · test_def_menu_coverage ("DEF MENU COVERAGE OK" after the stale-expectation fix)
- [x] Deck outcome: test_band_three_profile ("BAND_THREE OK", ambusher 6 / burrower 3 / splitter 4 / bomb 1 = 14 at the 31-credit budget)
- [x] Preset parity: test_rg1_loop_verify · test_rg1_m12/m13/m14/m15_verify all green (fp `e943ac9c8bc1`; BUG-M13FLAKE did not trip)
- [x] Save schema unchanged: META v4 / RUN v1 (no M1.10 save-code touch)
- [x] Definition of done met: "verify matrix run + recorded (all green, or any red flagged loudly); changelog.txt M1.10 block written; TG1_playtest_build.md authored (incl. Director playtest checklist §); commit referencing TG1 on the worktree branch (not main); worklog written." — all satisfied; itch publish + merge correctly left to the orchestrator (main-only).

## Design deviations
1. **Corrected a stale test expectation in `test_def_menu_coverage.gd` (test-only, no product
   change).** First-pass run was RED (exit 1): `'splitter' chip 'IN DECK: band_three, band_two ·
   0 tuned' != expected 'IN DECK: band_two · 0 tuned'`. Root cause: the FBM19b deck-membership
   test hard-coded splitter's IN-DECK chip as band_two-only, but T3 correctly added splitter to
   The Warren's deck (D-RAT-6: `[ambusher 6 · burrower 3 · splitter 4 · bomb 1]`). The debug
   menu's chip now *correctly* surfaces splitter in BOTH decks — the product behavior is right;
   the T3 wave simply didn't update this test's hard-coded expectation. Fix: replaced the single
   shared `want_chip` with a per-id map (charger → `band_two`; splitter → `band_three, band_two`).
   Re-run green ("DEF MENU COVERAGE OK"). This is a QA-lane test-fixture correction, not a design
   departure; flagged here for the wave close-out sweep. Recommend: Reviewed (the test now matches
   the correct, ratified deck).

## Handoffs / follow-ups
- **Orchestrator to publish from `main`** after merging this worktree (changelog + doc + the
  test-fixture fix). This worktree lacks `APIKEYS.md`, so `Game/tools/push_itch.sh` cannot run
  here. Fill TG1 §6.1 (build id / stamp / butler confirmation) at publish time.
- **TG2** (telemetry / balance analysis) is unblocked once the Director playtests the published
  build: three-band comparison off the `band_id` stamp, Ambusher-tell / Burrower-telegraph
  fairness (deaths-per-first-encounter vs Wrecker/Splitter baselines), cave time-to-gate vs band
  2 (does it disorient productively), 1.30-budget sanity, web perf with the cave's wall-collision
  geometry, `debug_dirty` runs filtered.
- **Watch-items surfaced to the Director on the TG1 build (per §5 + the breakdown DR notes):**
  portal-3 plaza composition + the spawn→portal-2 transit-prompt caveat (D-RAT-9); the cave-teal
  glow reading deeper cyan-blue (retone); cave depth-signposting (lost vs pressured).
