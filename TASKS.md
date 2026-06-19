# TASKS — THE FAR YARD

The orchestrator's task queue (mirror of GitHub Projects). The orchestrator consumes the
top *unblocked* task, dispatches the assigned subagent(s), and moves it through `STATUS.md`.
Each task carries: **id · milestone · assignee subagent · spec · definition of done · blockedBy**.
Finished tasks move to `TASKS_COMPLETED.md` (this file holds only **active + backlog**).

Format:
```
### <ID> — <title>
- Milestone: M<n>   Assignee: <subagent(s)>   BlockedBy: <ids|none>
- Spec: <path to the design doc>
- Goal: <one sentence>
- Done when: <verifiable acceptance criteria>
```

> A single task may span a programmer + an asset role (see `CLAUDE.md` → Dispatch). The
> primary assignee is listed first; a `(+ role: scope)` note marks the secondary agent.

---

## M1.2 — Legibility & Level Scale (ACTIVE — iterating on the M1.1 playtest ITERATE verdict)

Make the M1.1 cost axis **legible + fair**, then re-gate. Full breakdown, dependency map, wave order, and
cross-cutting contracts: `design/M1_2_Tasks/M1.2_Breakdown.md`. Provenance: `design/M1_Tasks/G4_findings_M1.1.md`.
**Design is LOCKED** — every task's design doc ends with a "Director Disposition (FINAL)". Greybox; all-off `RunConfig`
still reproduces the M1.1 baseline (permanent control); config-marked telemetry; `run_ended` arity stays locked.

### Wave 1 — Spatial & data foundation — ✓ **DONE 2026-06-19** (archived → `TASKS_COMPLETED.md`)

I1 (merged `e67532c`) · BUG4 (merged `eee4418`) · I5 (merged `1fd657e`) — all on `main`, board = Done, close-out swept
(4 deviations, all Director-Reviewed). All-off default still byte-matches the M1.1 baseline (fp=e943ac9c8bc1).

### Wave 2 — Oppositions retuned to the new canvas — ✓ **DONE 2026-06-19** (archived → `TASKS_COMPLETED.md`)

I2 (merged `1966145`) · I3 (merged `9b5d75d`) · I4 (merged `d56674d`) — all on `main`, board = Done. Determinism unmoved
(fp=e943ac9c8bc1). None touched `main_game.gd` (the single-writer concern was moot). Close-out: 0 formal deviations; 1
finding (R2 exposure-toll no-op) → **BUG5** filed below (Director: fix now, before the re-gate).

**BUG5 — ✓ DONE 2026-06-19** (merged `0196713`; archived → `TASKS_COMPLETED.md`). `exposure_meter.add()` added; R2 exposure toll now charges R3 end-to-end.

### Wave 3 — Re-gate  *(sequential; RG2/RG3 after the human playtest)*

**RG1 — ✓ DONE 2026-06-19** (merged `c7e130b`; archived → `TASKS_COMPLETED.md`). Assembled M1.2 build verified (14/20 rows headless, all-off fp unmoved); tester materials + verify matrix ready.

> **⏸ HUMAN GATE — Director playtest required before RG2.** Sweep configs per `tools/playtest/tester_readme.md`; drop the `.jsonl` in `playtest_data/M1.2/`. See STATUS.md for the sweep order + `build_tag` convention.
- Spec: template `design/M1_1_Tasks/RG1_playtest_build.md` (M1.2 doc authored when Wave 3 approaches)
- Goal: assemble the runnable M1.2 loop, verify each fix individually + stacked, config-marked telemetry writes.
- Done when: a fresh build runs the full loop with the fixes; per-run config works; telemetry logs clean; multiple runs/session.

### RG2 — Telemetry analysis vs M1.0/M1.1 baselines
- Milestone: M1.2 (Wave 3)   Assignee: qa-playtest-coordinator   BlockedBy: RG1 + human playtest data
- Spec: template `design/M1_1_Tasks/RG2_telemetry_analysis.md`
- Goal: end-cause / run-length / depth distributions per config, side-by-side vs M1.0 (all-off) and M1.1; did legibility + level scale create a real, felt outcome spread?
- Done when: an analysis artifact comparing distributions across configs + the two baselines, with a clear read.

### RG3 — Re-gate verdict (Director decides)
- Milestone: M1.2 (Wave 3)   Assignee: qa-playtest-coordinator (assembles) → Director (decides)   BlockedBy: RG2
- Spec: template `design/M1_1_Tasks/RG3_regate_verdict.md`
- Goal: record go/iterate/pivot in `design/M1_2_Tasks/G4_findings_M1.2.md` (mirrors M1.1). go → M2; iterate → M1.3 (this template); pivot → design rework.
- Done when: a recorded go/iterate/pivot verdict backed by config-marked telemetry, comparable to the M1.0/M1.1 findings.

---

## M1 follow-ups (deferred tech-debt — non-blocking, backlog)

From the M1 wave-5 close-out (`DESIGN_DEVIATIONS_HISTORY.md` §"M1 wave 5"). Neither blocks M1.2; pick up opportunistically.

### FU1 — GdUnit4 `test_jsonl_writer`
- Milestone: M1 (follow-up)   Assignee: qa-playtest-coordinator   BlockedBy: none
- Spec: `M1_As_Built.md` §Telemetry + `systems/telemetry/jsonl_writer.gd`
- Goal: add the GdUnit4 `test_jsonl_writer` suite G2 deferred — exercise the writer seam (write rows, read back, assert parseable JSON + envelope fields `v, ts, t_ms, run_id, session_id, type, data`).
- Done when: a GdUnit4 suite under `tests/telemetry/` covers `JsonlWriter` round-trip + envelope fields; green headless; test count rises.

### FU2 — Static `EconomyMath` helper
- Milestone: M1 (follow-up)   Assignee: general-purpose   BlockedBy: none
- Spec: `systems/game_state.gd` (`_resolve_pockets`/`_sum_values`/`run_haul_value`)
- Goal: lift the pure economy math out of `GameState` into a static `EconomyMath` helper so it's testable without snapshotting global meta; `GameState` delegates; no behavior change.
- Done when: a static `EconomyMath` owns pockets/sum/haul; `GameState` delegates; G2 economy suites call it directly (no meta snapshot); suite green.

---

## Backlog (M2+)
Pulled forward when M1.x passes its gate. See TDD §7: M2 (vertical slice: full day loop, recipe repair, first enemy, real art for one band), M3 (bands 1–3, currencies/tracks, exposure crises), M4 (Act 3 + endings), M5 (polish/ship). The **economy workbook** `design/economy_model.xlsx` (game-director-designer) is due **before M3**.
