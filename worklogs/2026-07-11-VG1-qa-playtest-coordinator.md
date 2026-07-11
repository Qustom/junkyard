# Worklog — VG1 M1.12 regression verify matrix + changelog

- **Date:** 2026-07-11
- **Subagent:** qa-playtest-coordinator
- **Milestone:** M1.12 (Wave 5)
- **Branch:** feat/VG1-regression-verify
- **Commit:** <filled in after commit below>

## What changed
Ran the full M1.12 regression/equivalence verify matrix (import + smoke + catalog check + all 67
`Game/tests/*.tscn` scene tests), using full-stderr `SCRIPT ERROR`/`Invalid call`/
`Nonexistent function`/`Invalid access` scanning (not exit-code-only) per the lesson from the prior
VG1 run's two silent-pass regressions (fixed in `81f92b3`, already merged to `main` before this
task started). All 67 tests + import + smoke + catalog check are GREEN with zero script-error hits.
Produced the gate artifacts: an M1.11→M1.12 `changelog.txt` block (honest "no player-facing change,
internal architecture cleanup" note per the changelog scope rule) and
`design/M1_12_Tasks/VG1_regression_build.md` (the full verify matrix + debt ledger + control-fp
confirmation + publish-skip note). **Director directive: NO itch publish this cycle** (CI/CD
stopped for a GitHub LFS bandwidth limit) — no `push_itch.sh`/`butler` was run.

## Files touched
- `changelog.txt` — added the M1.12 "Under the Hood" block (stability/internal-architecture-cleanup
  note, no player-facing feature list, per the changelog scope rule for a no-player-change version)
- `design/M1_12_Tasks/VG1_regression_build.md` — new: the full regression verify matrix (all
  green, stderr-clean column), the 4-control-fp confirmation (`e943ac9c8bc1` unmoved), confirmation
  the 2 VG1-fix-scrubbed tests emit zero SCRIPT ERROR, the consolidated debt ledger (EventBus
  60→54, RNG 5 sites→1 surface, GameState 752→467+251+96, config 91→52, all 3 greybox spawn
  machines→deck lane), the V3/V3b equivalence re-confirmation, and the "PUBLISH: SKIPPED per
  Director directive" note

No production `.gd`/`.tres`/scene file was touched — verify + docs only, per the task's hard
contract.

## Checks run
- [x] `godot --headless --path Game --import` → clean, 0 script/parse errors (confirmed via
      explicit grep for `SCRIPT ERROR|Invalid call|Nonexistent function|Invalid access` — no hits)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0
      architecture spike healthy`, stderr-clean
- [x] `godot --headless --path Game --script res://tools/check_junk_catalog.gd` → `JUNK CATALOG
      OK`, stderr-clean
- [x] All 67 `Game/tests/*.tscn` scene tests run individually (one headless instance at a time, no
      concurrency — the documented no-concurrent-headless deadlock constraint), full stdout+stderr
      captured per test, each grepped for the SCRIPT-ERROR pattern set. **67/67 PASS, 0 exit-code
      failures, 0 SCRIPT ERROR/Invalid call/Nonexistent function/Invalid access hits anywhere** —
      confirmed both per-test and via a final `grep -lriE` sweep across the whole captured-log
      directory (zero matches, `grep -l` exit 1).
- [x] The 4 permanent control fingerprints confirmed byte-identical: `test_band_pipeline_parity`
      prints `fp=e943ac9c8bc1` (unmoved from M1.0–M1.11); `test_band_two_profile` /
      `test_band_three_profile` / `test_encounter_builder` each explicitly assert byte-identity
      against `band_greybox`/`band_two`/the pinned all-off fp.
- [x] `test_new_hazard_spawn` and `test_rg1_m13_verify` (the two VG1-fix-scrubbed tests)
      re-confirmed: both print their real assertion line (`K5i OK …` / `RG1 M1.3 VERIFY OK …`)
      with **zero** SCRIPT ERROR hits in the full captured log — `test_rg1_m13_verify` passed
      clean on the first run (no BUG-M13FLAKE hit this pass, so no re-run was needed).
- [x] `test_greybox_deck_equivalence` (V3 K5 equivalence) and `test_pursuer_deck_equivalence` (V3b
      R1 equivalence) both green — every band/type row within the Director-ratified ±15% bar
      (K5: exact Δ%=+0.0 on every row; R1/pursuer: +0.0/+0.0/+11.1).
- [x] `test_save_migration` → all 3 historical fixtures (v1/v2/v3→v4) migrate clean, meta stays
      v4, no schema bump this version (consistent with the "no save-schema change" scope guardrail).
- [x] `test_config_menu` → `CONFIG MENU OK — 52/52 knobs bound + reachable` (matches the V3+V3b
      91→52 knob-count debt ledger entry).
- [x] Definition of done met: full regression matrix all-green with stderr-clean verification (not
      exit-code-only); changelog updated with an honest no-feature delta; the build-verify doc
      records the matrix, the debt ledger, the fp confirmation, and the publish-skip note; no
      production code changed.

## Design deviations
None. This task is verify + documentation only, per its hard contract (change no production code).
One pre-existing, non-blocking observation surfaced (not a deviation, not fixed here, since it's
out of the verify-only scope): `test_run_config` reports "51 knobs" via `to_flat_dict()` while
`test_config_menu` reports "52/52" bound in the UI — the two tests measure slightly different
surfaces (flat-dict serialization vs. UI-reachable knobs) and were both touched during V3/V3b;
flagged in the build-verify doc §1 for whoever next touches `RunConfig`/`ConfigMenu` to reconcile.
Also observed: `test_config_menu` prints two benign `push_warning`s ("… did not load as a
BandProfile — skipped for deck-membership display") for `cave_config_band_three.tres` /
`scatter_config_band_four.tres` — a pre-existing cosmetic display-path warning, not a `SCRIPT
ERROR`, not a regression, and not touched under this verify-only task.

## Handoffs / follow-ups
- VG2 (regression/equivalence analysis) and VG3 (Director go/iterate/pivot verdict) can proceed
  from this doc's evidence.
- The M1.12 V3b/stale-test-silent-pass deviation entry in `design/DESIGN_DEVIATIONS.md` is marked
  ADDRESSED (via `81f92b3`) but noted as "archive at M1.12 final close" — that archival move (into
  `DESIGN_DEVIATIONS_HISTORY.md`) is left for the VG3 close-out, per that file's own note, not done
  here (out of this task's verify-only scope).
- The itch.io page still serves the last-published M1.11 build (`m1-20260708-69446d5`) — no publish
  was attempted this cycle per the Director's directive. When CI/CD resumes and a publish is
  explicitly authorized, re-run `bash Game/tools/push_itch.sh` (with `BUTLER=` set) as a separate,
  explicitly-authorized step.
- The minor `test_run_config` (51 knobs) vs. `test_config_menu` (52/52 knobs) count-terminology
  mismatch noted above is worth a one-line reconciling comment next time either file is touched.
