# Worklog — I5 Telemetry hygiene (`duration_s = 0` + real build SHA)

- **Date:** 2026-06-19
- **Subagent:** qa-playtest-coordinator
- **Milestone:** M1.2 (Wave 1, Foundations)
- **Branch:** qa/I5 (isolated worktree)
- **Commit:** 86907ee9c8f30f2dc2acda6ad32061e93fb6985e

## What changed
Two M1.1-playtest telemetry-hygiene defects, both fixed per the LOCKED spec + Director disposition.

**(a) Duration regression-lock (NO game-code change).** The `duration_s=0` rows were a stale
pre-BUG1-fix binary (confirmed in spec §1 / Resolved-Q5: the live `game_state.gd` loop already
re-stamps `_run_start_ms` on every `start_run`, including every loop re-entry). So I5(a) is a CI
regression-lock, not a duration-path edit. Added `tests/test_duration_loop_reentry.gd` (+ `.tscn`
host): drives **three sequential `start_run` re-entries** (extract → timeout → death), asserting
each `run_ended.duration_s` is nonzero and matches that run's OWN measured wall span (so a stale
stamp inherited across re-entry is caught, not just a hardcoded 0.0), telemetry OFF. Wired into
both CI gates (`ci.yml`, `nightly.yml` test job). `game_state.gd` was NOT touched.

**(b) Real build SHA.** Rewrote `BuildVersion.short_sha()` to the chain: git-ignored baked artifact
(`systems/build_info_gen.gd` `const SHORT_SHA`) → editor live `git rev-parse --short HEAD` →
neutral `FALLBACK_SHA="0000000"` sentinel (was the lying `852b6e2`). New `tools/stamp_build.sh`
writes the artifact, appending `+dirty` when the tree is uncommitted. Removed the stale
`config/build_sha="852b6e2"` line from `project.godot` entirely (dropped the ProjectSettings
indirection — Resolved Q4). Added the artifact to `.gitignore`. Swapped `nightly.yml`'s
`sed`-into-`project.godot` bake for a `tools/stamp_build.sh` call *before* `--import`/export so the
generated script compiles into and ships inside the export pack.

## Files touched
- `systems/version.gd` — new resolution chain (artifact → editor-git → neutral sentinel); `FALLBACK_SHA` now `"0000000"`; dropped the `SHA_SETTING`/ProjectSettings read.
- `tools/stamp_build.sh` (new, +x) — bakes `git rev-parse --short HEAD` (+`+dirty`) into the git-ignored `systems/build_info_gen.gd`; callable locally + from CI.
- `project.godot` — removed the stale `config/build_sha="852b6e2"` line.
- `.gitignore` — ignore `systems/build_info_gen.gd` (+ `.uid`) build artifact.
- `.github/workflows/nightly.yml` — stamp step now calls `tools/stamp_build.sh` (before import); added the duration loop-reentry test step.
- `.github/workflows/ci.yml` — added the duration loop-reentry test step as a merge gate.
- `tests/test_duration_loop_reentry.gd` + `.tscn` (new) — the §3a regression-lock.

**NOT touched (per guardrails):** `systems/game_state.gd` (no missed-stamp path exists), `telemetry.gd`/`telemetry_schema.gd` (no row-shape/schema change — `TELEMETRY_SCHEMA_VERSION` stays 1, `ENVELOPE_KEYS` untouched, `run_ended` arity unchanged), all Wave-1 sibling files.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `tests/test_duration_loop_reentry.tscn` → DURATION LOOP OK (stable across 5 consecutive runs — no flake)
- [x] BUG1 single-run `tests/test_run_duration.tscn` → RUN DURATION OK (still passes)
- [x] telemetry tests (`test_telemetry_jsonl`, `test_telemetry_config_marking`) → OK (BuildVersion.id consumers unaffected)
- [x] full GdUnit4 logic suite (`-a res://tests`) → 30/30 PASSED, exit 0
- [x] SHA resolution verified: no artifact → editor-git fallback returns real HEAD `6fe0522`; after `tools/stamp_build.sh` → artifact returns `6fe0522+dirty`; `id()` → `m1-20260619-6fe0522+dirty`; artifact confirmed git-ignored (`git check-ignore` matches, absent from `git status`).
- [x] definition of done met: every completed run logs a real `duration_s` (asserted via the 3-re-entry loop test, telemetry off, red blocks merge); `run_started.data.build` reflects actual HEAD SHA in editor/local-headless/exported builds with `+dirty`/neutral-sentinel surfacing unstamped/dirty builds; no `run_ended` arity change / no schema bump / no new row; suite + smoke green.

## Design deviations
none. All Phase-3 Resolved Decisions + the Director's FINAL disposition were followed exactly:
const `.gd` artifact (Q2), neutral `0000000` sentinel + drop ProjectSettings key (Q4), visible
`+dirty` suffix (Q3), no source-side duration floor (Q1), no `game_state.gd` change (Q5).

One implementation note (within the locked contract, not a deviation): the editor-git fallback
returns the bare SHA without `+dirty` — `+dirty` is applied only by `tools/stamp_build.sh` at the
stamp step, which is the authoritative build-time marker. An un-stamped editor run is inherently a
dev convenience, not a distributable build, so the dirty mark belongs at stamp time. The
`short_sha()` artifact read uses `GDScript.get_script_constant_map()` to read `SHORT_SHA` (the
reliable way to read a const off a loaded script class).

## Handoffs / follow-ups
- The generated `systems/build_info_gen.gd` is git-ignored; any local headless/editor run that has
  not run `tools/stamp_build.sh` will report the real SHA via the editor-git fallback (in editor)
  or the `0000000` sentinel (a true non-editor export with no stamp). RG2 cohort partitioning by
  build SHA is now possible.
- The 4 unmatched `run_started` rows and the abandonment funnel remain out of scope for I5 (spec
  Resolved Q6) — flagged for RG2's abandonment analysis (partition by build SHA, now feasible).
