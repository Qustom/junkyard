# Game/tests/

This folder holds two distinct test populations (see `design/M1_12_Tasks/V8_ci_wallclock.md`
for the full research this note summarizes):

- **~63 top-level self-quitting scene tests** (e.g. `test_ambusher.tscn`, `test_lobber.tscn`,
  the `test_rg1_*_verify.tscn` per-milestone capstones): a `Node`-rooted `.tscn` pairing an
  `ext_resource` script that runs assertions in `_ready()`/over a few physics frames, then calls
  `get_tree().quit()`. None of these `extends GdUnitTestSuite` — they are CLAUDE.md's
  "verify/knob test" idiom, booted individually and *manually* per task:
  `godot --headless --path Game res://tests/<name>.tscn` (never `--script` — that idiom is for
  headless `SceneTree`-only tools like `ci_smoke_test.gd`/`check_junk_catalog.gd`, not these).
- **4 GdUnit4 logic suites** under `economy/`, `inventory/`, `procgen/`
  (`extends GdUnitTestSuite`) — a separate, small, single-process population booted together via
  the GdUnit4 CLI runner (`-a res://tests` picks up all suites in one Godot boot).

CI (`.github/workflows/ci.yml` / `nightly.yml`) does **not** run the full 63 — it runs a small
curated subset directly as pipeline steps (import, junk-catalog check, smoke test,
save-migration test, duration loop-reentry test, plus `nightly.yml`'s extra loop-drive +
main-game integration drives) followed by the full GdUnit4 sweep. The remaining scene tests are
run on demand by whoever is verifying a specific task.

## Suite wall-clock (M1.12 V8)

CI prints each step's wall-clock and a suite total to the job log on every run — look for
`wallclock <step> Ns` lines and the final `TOTAL headless suite wallclock: Ns` line
(`gh run view --log`, or the raw log in the Actions UI). The same numbers also render as a
markdown table in the run's Job Summary (`$GITHUB_STEP_SUMMARY`), visible without opening any
individual step.

This instrumentation exists to make the serial-boot-cost trend **visible** as more scene tests
and RG capstones accrete (every `godot --headless <script-or-scene>` invocation pays a fixed
engine-boot + project-import-resolve cost before its own logic runs, and CI's steps run serially
by construction — the project forbids concurrent headless Godot instances against one project,
see the `godot-headless-test-invocation` memory/deadlock constraint). **It does not gate merges
and does not change which tests run or their pass/fail** — it is instrumentation only.

**Deferred follow-up (post-M1.12, not filed as a task yet — see
`design/M1_12_Tasks/V8_ci_wallclock.md` Resolved Decisions #4 for the full filing):** "Shard or
GdUnit4-fold the scene-test suite." Trigger: once V8's wall-clock data shows CI's own curated
subset exceeding **5 minutes total wall-clock on `ci.yml`** (the PR-blocking path). Scope: (a)
audit which of the 63 scene tests are pure-logic and could be rewritten as GdUnit4 suites,
folding them into the existing single-process sweep and eliminating their per-test boot cost;
(b) for tests that genuinely need a live booted scene (autoload/physics-dependent, e.g.
`test_ambusher.tscn`), shard via parallel CI **jobs**, each with its own checkout + import
cache — explicitly NOT concurrent processes against one shared project directory (which the
deadlock constraint forbids).
