# Worklog — V8 CI suite wall-clock + wire catalog check

- **Date:** 2026-07-10
- **Subagent:** qa-playtest-coordinator
- **Milestone:** M1.12 (Scaling Debt Paydown), Wave 1
- **Branch:** feat/V8-ci-wallclock
- **Commit:** c4d9c9c6ecd73d0f811a8ac0cbad91ac01617ee6

## What changed

Instrumentation-only change to `.github/workflows/ci.yml` and `.github/workflows/nightly.yml`
per `design/M1_12_Tasks/V8_ci_wallclock.md`'s locked "Resolved Decisions (Phase 3)":

- Wrapped every existing headless-test `run:` step in both workflows with a `date +%s`
  before/after pair. Each wrapped command line is **byte-identical** to what it was before —
  only bash timing/logging scaffolding (`_t0`/`_t1`/`_dur`/`exit $_rc`) surrounds it, so
  pass/fail gating is provably unchanged.
- Each wrapped step emits a `wallclock <step> Ns` line to the job log (`tee -a
  /tmp/ci_wallclock.log`) AND a `| step | Ns |` row to `$GITHUB_STEP_SUMMARY` (both destinations,
  per Resolved Decision #3 — log-grep and job-summary-table both stay useful).
- Added a final `Report suite wall-clock (V8 — instrumentation only, non-gating)` step,
  `if: always()`, that never fails the job (`|| true` / `|| echo` guards) and prints/sums a
  `TOTAL headless suite wallclock: Ns` line, plus a **TOTAL** row in the summary table.
- **V1-Q4b (delegated to V8 as workflow-file owner):** added a new `Validate junk catalog (CI
  gate)` step in both workflows, immediately after the `Import project` step, running
  `godot --headless --path Game --script res://tools/check_junk_catalog.gd` (working-directory:
  Game, so `res://` resolves as usual) — this DOES gate the build (non-wrapped-behavior
  preserved: `exit $_rc` propagates the script's real exit code). Wrapped in the same timing
  scaffolding as every other step.
- Created `Game/tests/README.md` (new file) documenting: the two test populations (63
  self-quitting scene tests vs. 4 GdUnit4 logic suites), what CI's curated subset actually runs,
  the wall-clock metric's purpose/location, and the deferred-sharding follow-up (trigger:
  CI's curated subset on `ci.yml` exceeding 5 minutes total wall-clock), per the design doc's
  Resolved Decision #4 filing.

No test was added, removed, or reordered. No concurrency was introduced (each workflow's steps
remain strictly serial — the `godot-headless-test-invocation` memory's deadlock constraint is
respected by construction, since this only adds bash around already-serial steps).

## Files touched
- `.github/workflows/ci.yml` — wrapped Import/junk-catalog(new)/smoke/save-migration/duration-loop-reentry/GdUnit4 steps in timing; added final wall-clock summary step.
- `.github/workflows/nightly.yml` — same wrap on the `test:` job's Import/junk-catalog(new)/smoke/save-migration/duration-loop-reentry/loop-drive/main-game-integration/GdUnit4 steps; added final wall-clock summary step. `export-and-publish` job (a separate, non-test job) left untouched.
- `Game/tests/README.md` — new file; test-suite orientation + wall-clock metric + deferred-sharding follow-up note.

## Checks run
- [x] `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml')); yaml.safe_load(open('.github/workflows/nightly.yml')); print('YAML OK')"` → `YAML OK`
- [x] `godot --headless --path Game --import` clean (no parse errors; ran to completion on this worktree, exit 0)
- [x] `godot --headless --path Game --script res://tools/check_junk_catalog.gd` → `JUNK CATALOG OK`, exit 0 (confirms the existing, not-yet-V1-strengthened checker still passes on the current valid catalog — the command this task wires into CI is proven locally green)
- [x] Manual review: every wrapped command line's actual `godot ...` invocation text is unchanged character-for-character from the pre-V8 version (diffed against `git diff` — confirmed only surrounding bash added)
- [x] Definition of done (task brief): "no change to WHICH tests run or their pass/fail; the smoke gate is unaffected" — met; "YAML well-formed" — met; "check_junk_catalog.gd command runs locally green" — met

## Debt ledger
Instrumentation only — no runner restructuring, no concurrency, no behavior change to which
tests run or their pass/fail. Net LOC added is a small `date`/`echo` wrap per existing CI step
+ one new summary step + one new gating step (the catalog check, delegated from V1-Q4b) + one
new `Game/tests/README.md`. Net LOC removed is zero. Payoff: a previously-invisible CI boot-cost
trend becomes visible in every run's job log/summary before it needs the deferred-sharding
follow-up (`design/M1_12_Tasks/V8_ci_wallclock.md` Resolved Decision #4), and the junk-catalog
validator (already written, task V1) is now actually wired into the gate instead of sitting
unused.

## Design deviations
None. Implementation follows `design/M1_12_Tasks/V8_ci_wallclock.md`'s locked "Resolved
Decisions (Phase 3)" section exactly: per-suite + total timing (Decision 1), CI-log-only (no
committed trend file) (Decision 2), both plain-log AND `$GITHUB_STEP_SUMMARY` output (Decision
3), the deferred-sharding filing text reused verbatim in `Game/tests/README.md` (Decision 4),
and `if: always()` / never-fails-the-job semantics on the summary step (Decision 5). The
V1-Q4b catalog-check wiring was explicitly delegated to this task by the dispatch brief (task
V1's strengthening of the checker itself is a separate, not-yet-landed task on this branch —
per the brief, "on your worktree branch V1's strengthening isn't present, but the existing
checker must still exit 0 on the current valid catalog," which was confirmed).

## Handoffs / follow-ups
- The deferred "Shard or GdUnit4-fold the scene-test suite" task (LOW priority / effort-M,
  trigger: CI's curated subset on `ci.yml` exceeding 5 minutes total wall-clock) is filed in
  `design/M1_12_Tasks/V8_ci_wallclock.md` Resolved Decision #4 and restated in
  `Game/tests/README.md`. Not created as a live backlog task by this worklog — per the design
  doc's own framing, that's a recommendation for whoever opens the next iteration's backlog.
- Once task V1 lands its strengthened `check_junk_catalog.gd` on `main` (same wave, different
  branch/worktree per the dispatch brief), the CI step this task adds will exercise the
  strengthened version automatically — no further workflow-file change needed, since the step
  invokes the script by path, not by embedding its logic.
