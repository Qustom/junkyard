# Worklog — RG1 M1.2 playtest build + verify

- **Date:** 2026-06-19
- **Subagent:** qa-playtest-coordinator
- **Milestone:** M1.2 (Legibility & Level Scale) — Wave 3 (re-gate)
- **Branch:** qa/RG1
- **Commit:** <filled at commit>

## What changed
RG1 is the M1.2 verify + document task (not new gameplay): all six M1.2 fixes (I1/BUG4/I5/I2/I4/I3)
+ BUG5 were already integrated on `main`. I authored the M1.2 RG1 verify matrix doc, a headless
verify driver that exercises each fix individually + stacked + the all-off control through the REAL
assembled `main_game.tscn`, and updated the tester materials (checklist + readme) with the M1.2
config-sweep guidance. No wiring gap found — the assembled loop already reaches every fix.

## Files touched
- `tests/test_rg1_m12_verify.gd` (new) — headless verify driver mirroring `test_rg1_loop_verify`.
  Instances the real `main_game.tscn`, drives 7 configs (M0 all-off, M1 I1 scale, M2 I2 hazard,
  M3 I3 R2/R3, M4 I4 vision, M5 BUG5 exposure toll, M6 all-on), inspects `run_log.jsonl`. Asserts:
  all-off fingerprint == locked `e943ac9c8bc1` (determinism guard); build id real (not stale
  `852b6e2`); level scale changes count + px/cell (I1); R1 hazard catch → death with the new
  `r1_catch_radius_per_depth` knob (I2); R2/R3/nav cue-backing rows fire (I3/I4); R2 exposure toll
  moves R3's meter in a zero-natural-climb run (BUG5); snapshot carries the new lvl_*/
  r1_catch_radius_per_depth keys (V13); `duration_s > 0` on every run (I5); config carry-forward
  incl. lvl_*; repeated runs with no leak (V12). Prints `RG1 M1.2 VERIFY OK`, exits non-zero on fail.
- `tests/test_rg1_m12_verify.tscn` (new) — scene wrapper so the autoloads resolve as live nodes.
- `design/M1_2_Tasks/RG1_playtest_build.md` (new) — the M1.2 verify-matrix doc (authored from the
  M1.1 template): goal/intent, the assembled-loop seam inventory, the M0–M6 + V8–V18 matrix
  (headless-pass vs human-deferred), the headless-driver summary, the Director's config-sweep
  guidance (size {1.0,1.5,2.0,3.0} first per I1 Resolved-A, then hazard/toll/vision/all-on), the
  `m12-` build_tag labelling convention, the telemetry path + real-SHA confirmation, acceptance.
- `tools/playtest/loop_smoke_checklist.md` — added the M1.2 per-fix manual pass (I1/I2/I3/I4/I5/BUG5
  felt/on-screen rows) + the `test_rg1_m12_verify.tscn` headless driver reference.
- `tools/playtest/tester_readme.md` — retitled to M1.2; documents what changed (hazard catches,
  level scale, visible attrition, occluding dark, real SHA), the Level Scale section knobs, the
  `m12-` build_tag convention, and the suggested sweep order.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `godot --headless res://tests/test_rg1_m12_verify.tscn` → `RG1 M1.2 VERIFY OK` (14 rows
      headless-verified; 6 human-deferred), exit 0
- [x] `test_rg1_loop_verify.tscn` (M1.1 RG1) → `RG1 BUILD VERIFY OK` (no regression)
- [x] `test_bandgen_determinism.tscn` → fp=e943ac9c8bc1 (all-off baseline UNMOVED) + BUG3/BUG4 seal OK
- [x] `test_level_scale_determinism.tscn` → LVL OK (all-off byte-matches baseline; ext fp d7c249c3584b)
- [x] `test_run_duration.tscn` + `test_duration_loop_reentry.tscn` → DURATION OK (I5 duration real)
- [x] `test_exposure_meter.tscn` → EXPOSURE METER OK incl. add()/BUG5 toll-moves-meter end-to-end
- [x] `test_return_cost.tscn` → RETURN COST OK
- [x] `test_pursuing_hazard.tscn` → PURSUING HAZARD OK (catch → fail_run death)
- [x] `test_decision_hud.gd` (--script) → DECISION HUD OK
- [x] definition of done met (quote): "A fresh build runs the full M1.2 loop with all fixes; each
      fix verified individually + stacked (headless where possible, human-deferred rows clearly
      listed); per-run config works incl. the new knobs; config-marked telemetry logs clean to a
      fresh path with a real build SHA; all-off = M1.0/M1.1 baseline (fp unmoved); multiple
      runs/session, no leaks; tester_readme + checklist + RG1 doc ready for the Director's playtest."

## Design deviations
none. No `run_ended` arity change, no telemetry schema bump, no new EventBus signal. The assembled
loop already wired every M1.2 fix reachably, so no `main_game.gd` edit was needed. The verify
driver mirrors the M1.1 RG1 approach (drive via GameState's public end-cause API; inspect the
JSONL) — no new test framework, no GUT. `r1_catch_radius_per_depth` and `lvl_*` snapshot keys are
asserted as a generic set against `to_flat_dict()` (no magic count), per the M1.1 V13 convention.

## Handoffs / follow-ups
- The build is ready for the Director's playtest. After the playtest, RG2 (telemetry analysis vs
  M1.0/M1.1 baselines) → RG3 (go/iterate/pivot verdict in `G4_findings_M1.2.md`).
- For a SHIPPED/exported build, run `tools/stamp_build.sh` so `systems/build_info_gen.gd` bakes the
  exact commit (an un-stamped non-editor build legibly reports `0000000`). Headless from the working
  tree resolves the real HEAD via the editor-git fallback (verified `m1-20260619-<sha>`).
- 6 human-deferred (rendering/felt) rows are listed in the RG1 doc §4 + the checklist: I1 "feels
  like a journey", I2 visible close-in, I3 cue legibility, I4 occlusion look + lost cue, I5 returned-
  log build id, V18 real-input screen navigation. These are the RG3 subjective read, not RG1's.
