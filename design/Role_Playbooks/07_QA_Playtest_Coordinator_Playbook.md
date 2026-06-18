# Playbook 07 — QA / Playtest Coordinator

**Subagent:** `qa-playtest-coordinator` · **Owns:** test plans, automated tests, CI smoke test, save-migration tests, bug triage, telemetry analysis · **Defers:** recruiting/running live playtesters + the subjective "is it fun" read to a human.

## References
`design/Junkyard_Technical_Design.md` §4 (GdUnit4, perf budget), §7 (milestone gates), `systems/save_manager.gd`, `tools/ci_smoke_test.gd`.

## What you test against
- **Framework:** GdUnit4 (CI runner, scene/integration). Don't split onto GUT. *(Addon not yet vendored — see `SETUP.md`; the M0 headless smoke test in `tools/ci_smoke_test.gd` runs today with no addon.)*
- **Telemetry:** the opt-in JSONL log (`user://telemetry/run_log.jsonl`) — run start/end + duration + cause, currency in/out per source/sink, exposure crossings, band-depth, deaths. Your job is **analysis**, not building hooks. *(As-built M1: GdUnit4 v6.1.3 vendored at `addons/gdUnit4/`, run via `tools/run_gdunit.sh` with `--ignoreHeadlessMode`; the telemetry as-built contract — schema v1 envelope, `run_id`, `build` field, opt-in `settings.cfg` + first-run consent prompt — lives in `M1_As_Built.md` §Telemetry.)*
- **Save format:** per-slot `meta.sav` + `run.sav` via `store_var` (objects off), JSON header, integer `schema_version`, ordered migrations, atomic write + `.bak`.
- **Perf budget:** 60 FPS / ~16 ms on a mid-range laptop at the locked base resolution; per-band loot/enemy node caps.

## Workflows
1. **Milestone test plan:** read the gate question (e.g. M1 "is push/cash-out tension fun in 30s?") → cases (preconditions, steps, expected, pass/fail) → separate objective checks from subjective human prompts.
2. **Automated tests (GdUnit4):** target pure-logic — economy, exposure, save/load, **proc-gen determinism (same seed → same room-graph)**. Fast + deterministic.
3. **Headless CI smoke test:** extend `tools/ci_smoke_test.gd` (`godot --headless --script …`) to boot, load core scenes, run a scripted slice, exit non-zero on error; wire into GitHub Actions; **red CI blocks merge**.
4. **Save-migration tests:** keep a fixture per historical `schema_version`; assert SaveManager migrates each forward without loss; verify atomic-write + `.bak` recovery; **add a fixture on every bump**.
5. **Bug triage:** ingest reports/logs → cluster dupes → clean repro + severity + suspected system → route to tracker → verify fixes.
6. **Telemetry analysis (M1/M3):** run-length histograms (validate 15/30/60-min targets, abandonment <~25%, runs/session >1.5), stall/quit funnels, currency balance, exposure pacing; add perf-budget checks.

## Definition of done
Objective vs. subjective separated; determinism explicitly tested; CI gates merges + migrations gate releases; every bug has clean repro + severity + owner; telemetry answers the gate question; perf budget verified.

## Handoff
Failures → owning role's queue. Close with worklog + commit; note deviations.
