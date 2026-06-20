# Worklog — RG1 M1.3 playtest build + verify

- **Date:** 2026-06-20
- **Subagent:** qa-playtest-coordinator
- **Milestone:** M1.3 (Wave 3 — re-gate)
- **Branch:** worktree-agent-a8902b739b5485731 (worktree; logical name `qa/RG1-m13-verify`)
- **Commit:** ddc330ba4474292ba4a142cf712dc778fcf2a8f3 (driver + doc + readme; this worklog SHA-fix
  follows in the next commit on the branch)

## What changed

RG1 is verify + document (NOT new gameplay). Authored the M1.3 headless verify driver and
the RG1 playtest-build doc, and added the M1.3 human-deferred items to the tester readme.

1. **`tests/test_rg1_m13_verify.gd` (+ `.tscn` + `.uid`)** — the M1.3 re-gate verification
   capstone, mirroring `test_rg1_m12_verify`'s structure (instance the REAL `main_game.tscn`,
   drive configs through the build's own `start_new_run()`, inspect `user://telemetry/run_log.jsonl`).
   Carries forward the full M1.2 baseline guard set (all-off fp byte-match, build-id real,
   duration_s>0, end-cause reachability, no-node-leak, V13 snapshot key SET) and adds the
   M1.3-specific assertions: J1 default-preset shape + trap-free + no-leak-into-default +
   CFG-boots-the-preset; J2 even_spread spans >1 depth while single_gate stays single-depth;
   J3 density 0→0 / big-room fill / band-ceiling≤64 / deterministic; J4 neutral fp byte-match +
   non-neutral lever moves fp + deterministic; the new `corridor_summary` row (exactly one per
   run, `corridor_frac`∈[0,1]); schema v1 + `run_ended` arity unchanged; all 46 knobs in the
   snapshot. Prints `RG1 M1.3 VERIFY OK`, exits non-zero on any failure (CI-gateable).
   16 rows headless-verified, 6 human-deferred.
2. **`design/M1_3_Tasks/RG1_playtest_build.md`** — the RG1 doc, authored from the M1.2 RG1
   template: goal/intent, what's-already-wired (the M1.3 seams), the §3 verify matrix (per-fix
   isolation J1–J5 + stacked + baseline control + end-cause/telemetry integrity, each row marked
   HEADLESS PASS or human-deferred), §4 headless-vs-human-deferred split (16/6), §5 config-sweep
   guidance for the Director (J2/J3/J4 sweeps + the carried-forward J3 wake-cadence tuning + the
   mult-40 void-feel pass, every tag `m13-`), §6 telemetry path + build identity (the new
   `corridor_summary`/`corridor_frac` is what RG2 reads for F3a), §7 acceptance criteria.
3. **`tools/playtest/tester_readme.md`** — added a light "New in M1.3" block with the four
   human-deferred watch items (J2 multi-depth danger, J3 charged big rooms, J4 shorter halls,
   J5 "Depth N / max" readout) + the `m13-` tag convention. Did not rewrite the M1.2 body.

## Files touched
- `tests/test_rg1_m13_verify.gd` — NEW: the M1.3 headless verify driver.
- `tests/test_rg1_m13_verify.tscn` — NEW: scene wrapper (autoloads resolve as live nodes).
- `tests/test_rg1_m13_verify.gd.uid` — NEW: script uid.
- `design/M1_3_Tasks/RG1_playtest_build.md` — NEW: the RG1 verify+document doc.
- `tools/playtest/tester_readme.md` — added the M1.3 human-deferred watch items + `m13-` tags.

No gameplay/system code touched (RG1 is verify+document). Test + docs only.

## Checks run
- [x] `godot --headless --import` clean (no parse errors; the only output is the pre-existing
      first-pass `.translation` not-yet-built notices, which resolve on the settle pass).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK` (exit 0).
- [x] `godot --headless res://tests/test_rg1_m13_verify.tscn` → `RG1 M1.3 VERIFY OK -- ...
      16 rows headless-verified; 6 deferred.` (exit 0).
- [x] Pre-existing suites still green (all exit 0):
      `test_rg1_m12_verify` (`RG1 M1.2 VERIFY OK`, fp `e943ac9c8bc1`),
      `test_run_config` (all 46 knobs), `test_config_menu` (46/46 knobs),
      `test_hazard_spread` (J2), `test_per_room_density` (J3),
      `test_corridor_lever` (J4, neutral fp `e943ac9c8bc1`), `test_corridor_summary_row` (J4 row).
- [x] Definition of done met: "Tests run as scenes; smoke is --script. (1) import clean,
      (2) smoke exits 0, (3) the M1.3 driver prints `RG1 M1.3 VERIFY OK` + exits 0, (4) the
      pre-existing tests still pass, (5) the RG1 doc exists, filled per the M1.2 template with
      the verify matrix marked." All five satisfied.

## Headless vs human-deferred
- **16 headless-verified rows:** baseline-fp-unmoved · build-id-real · default-preset-shape +
  trap-free + no-leak (J1) · CFG-boots-preset · J2-spread-plan · J3-density-plan · J4-corridor-lever ·
  persistent-wiring · 6 driven configs (snapshot+gating) · corridor_summary 6-row · duration-real ·
  carry-forward · repeat/no-leak · all-off-no-opposition · end-cause reachability.
- **6 human-deferred (rendering / felt):** J1 boot-into-preset look · J2 multi-depth FEEL ·
  J3 big-rooms-charged FEEL · J4 halls-shorter FEEL · J5 "Depth N / max" readout · size-40 void-feel.

## Findings (real integration bugs)
**None.** The assembled M1.3 loop runs unbroken under every driven config (the default preset,
each fix in isolation, all stacked, the all-off control). The all-off control stays byte-identical
(fp `e943ac9c8bc1`); schema v1 + `run_ended` arity are unchanged; the only telemetry addition is
the additive `corridor_summary` row. No gameplay patch needed.

## Design deviations
**None.** RG1 is verify+document; no gameplay/system code changed. The driver, doc, and
tester-readme touch-up are all on-spec with the RG1 task brief and the M1.2 template.

## Handoffs / follow-ups
- The build is ready for the Director's playtest. Per the standing playtest-gate step,
  publish it to itch (`bash tools/push_itch.sh`, `BUTLER=/mnt/c/wsl-libraries/butler/butler`)
  so the Director can play in-browser, then RG2 (telemetry analysis) → RG3 (verdict).
- Add `tests/test_rg1_m13_verify.tscn` to the CI test set alongside the M1.2 driver so the
  M1.3 matrix gates merges going forward.
