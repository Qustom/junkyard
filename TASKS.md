# TASKS — THE FAR YARD

The orchestrator's task queue (mirror of GitHub Projects). The orchestrator consumes the
top *unblocked* task, dispatches the assigned subagent(s), and moves it through `STATUS.md`.
Each task carries: **id · milestone · assignee subagent · spec · definition of done · blockedBy**.

Format:
```
### <ID> — <title>
- Milestone: M<n>   Assignee: <subagent(s)>   BlockedBy: <ids|none>
- Spec: <path to the full design/M1_Tasks spec>
- Goal: <one sentence>
- Done when: <verifiable acceptance criteria>
```

> A single task may span a programmer + an asset role (see `CLAUDE.md` → Dispatch). The
> primary assignee is listed first; a `(+ role: scope)` note marks the secondary agent.
> `BlockedBy: none` means its only dependency was M0, which is complete.

---

## M1.1 — Greybox Cost Axis (ACTIVE — iterating on the G4 ITERATE verdict)

Add a depth-scaled **cost/risk axis** so push-vs-extract becomes a real gamble, then re-run the gate.
Full breakdown, dependency map, wave order, and the configurable-knob + telemetry contracts:
`design/M1_1_Tasks/M1.1_Breakdown.md`. All greybox; every opposition is configurable via a pre-run menu and
config-marked in telemetry; the all-off `RunConfig` reproduces the M1.0 baseline (the permanent in-build control).

### Wave 1 — Foundations — ✅ **COMPLETE (2026-06-19)**
R0 · BUG1 · BUG2 · TEL · BUG3 · CFG all done + merged (R0 `30e41b9`; BUG1+BUG2 `33eb786`; TEL+BUG3 `c940ae4`; CFG `62e16b9`) and verified green (SMOKE OK · RUN DURATION OK · WITHIN BAND DEPTH OK · TEL CONFIG MARKING OK · BUG3 SOCKET SEAL OK · CONFIG MENU OK · MAIN GAME OK · GdUnit4 30/30). Close-out deviation sweep done (W1.1-1 Reviewed, W1.1-2 Addressed). Specs + proof archived to `TASKS_COMPLETED.md`. `depth_changed` + 11 opposition/penalty signals are on `main`; the band is sealed; telemetry config-marks every run.

### Wave 2 — The four oppositions — ✅ **COMPLETE (2026-06-19)**
R1 · R2 · R3 · R4 all done + merged (`b0566c2` R2/R3/R4; `0c80622` R1) and verified green (PURSUING HAZARD OK · RETURN COST OK · EXPOSURE METER OK · EXPOSURE HUD OK · R4 NAV OK · BANDGEN/SEAL OK · MAIN GAME OK · GdUnit 30/30; all-off fingerprint `e943ac9c8bc1` = M1.0 control). Each reads `active_run_config` + live within-band depth, emits TEL's pre-declared signals, edits neither `event_bus.gd` nor `game_state.gd`. **R2's `ReturnCost` + R3's `ExposureMeter` are built standalone and await RG1 dive-scene wiring.** Specs + proof archived to `TASKS_COMPLETED.md`. **Wave 2 close-out pending:** Director dispositions W2-R4-1 (BUG3 seal gap at high branch rates); R1/R2/R3 = none.

### Wave 3 — Re-gate  *(sequential; RG2/RG3 after the human playtest)*

### RG1 — Playtest build (risk active)
- Milestone: M1.1 (Wave 3)   Assignee: general-purpose + qa-playtest-coordinator (verification)   BlockedBy: R1, R2, R3, R4, TEL
- Spec: `design/M1_1_Tasks/RG1_playtest_build.md` (expanded design + verification matrix + ratified decisions)
- Goal: assemble the runnable M1.1 loop (Config menu → dive with risk → push/extract/die/timeout/lost → bank/lose → sell → repeat); verify each opposition individually + all stacked; config-marked telemetry writes.
- Done when: a fresh build runs the full loop with oppositions on; per-run menu toggling works; telemetry logs config + opposition events; multiple runs/session.

### RG2 — Telemetry analysis + M1.0 comparison
- Milestone: M1.1 (Wave 3)   Assignee: qa-playtest-coordinator   BlockedBy: RG1 + playtest data
- Spec: `design/M1_1_Tasks/RG2_telemetry_analysis.md` (expanded design + metrics + ratified decisions)
- Goal: analyze end-cause / run-length / max-depth distributions per config, per-opposition event frequencies, side-by-side vs the all-off M1.0 baseline; surface which oppositions broke the dominant strategy.
- Done when: an analysis artifact comparing distributions across configs and against M1.0, with a clear read on whether the cost axis created a real outcome spread.

### RG3 — Re-gate verdict (Director decides)
- Milestone: M1.1 (Wave 3)   Assignee: qa-playtest-coordinator (assembles) → Director (decides)   BlockedBy: RG2
- Spec: `design/M1_1_Tasks/RG3_regate_verdict.md` (expanded gate design + criteria + ratified decisions)
- Goal: re-run G4's question against M1.1; record a go/iterate/pivot verdict in `design/M1_1_Tasks/G4_findings_M1.1.md` (mirrors M1.0's). go → M2; iterate → M1.2 (this template); pivot → Director design rework.
- Done when: a recorded go/iterate/pivot verdict backed by config-marked telemetry, comparable to the M1.0 G4 finding.

## M1.1 follow-ups (from wave close-outs)

### BUG4 — SocketSealer misses branchy perimeter edges at high R4 branch rates
- Milestone: M1.1 (follow-up)   Assignee: general-purpose   BlockedBy: none (R4 + BUG3 on `main`)
- Spec: `systems/bandgen/socket_sealer.gd` + `design/M1_1_Tasks/R4_maze_navigation.md` §6; origin = Wave-2 close-out **W2-R4-1** (Director: Addressed, 2026-06-19)
- Goal: at `r4_branch_per_depth ≳ 0.12` some seeds leave 2–6 floor cells facing off-map void after `SocketSealer`, because the sealer caps only `band.open_sockets` (unmated frontier) and misses branchy socket-opening edges not in that set. Cap **all** outward-facing perimeter floor edges (any floor cell whose outward neighbour is neither floor nor a mated doorway) so the seal is **branch-rate-independent**. Also add a CFG soft-cap note on `r4_branch_per_depth`.
- Done when: a determinism+seal sweep at high branch rates (e.g. `branch_per_depth` 0.12–0.20) shows **0 void-facing cells** on every seed; `band.fingerprint()` unchanged (geometry-only pass, no RNG/piece changes); existing seal + determinism tests stay green.
- Note: **non-blocking** for Wave 3 — the recommended playtest presets (S1=0.06, S3=0.05) already seal cleanly (0 leaks/9 seeds). Needed before any high-branch-rate sweep.

## M1 follow-ups (deferred tech-debt — non-blocking; from the wave-5 close-out)

Small, optional cleanups surfaced as `Reviewed` deviations at the M1 wave-5 close-out (2026-06-18) and
ratified for tracking by the Director (2026-06-19). Neither blocks G4 or M1 sign-off; pick up opportunistically.
Provenance: `DESIGN_DEVIATIONS_HISTORY.md` §"M1 wave 5" (W5-G2-3, W5-G2-5).

### FU1 — GdUnit4 `test_jsonl_writer`
- Milestone: M1 (follow-up)   Assignee: qa-playtest-coordinator   BlockedBy: none (G1+G2 on `main`)
- Spec: `M1_As_Built.md` §Telemetry + `systems/telemetry/jsonl_writer.gd`; origin = close-out W5-G2-3
- Goal: add the GdUnit4 `test_jsonl_writer` suite that G2 deferred (G1's `JsonlWriter` was on a parallel branch at the time; both are now on `main`). Exercise the writer seam directly — write rows, read back, assert parseable JSON + required envelope fields (`v, ts, t_ms, run_id, session_id, type, data`).
- Done when: a GdUnit4 suite under `tests/telemetry/` covers `JsonlWriter` round-trip + envelope field presence; green in headless (`tools/run_gdunit.sh`); test count rises from 30.

### FU2 — Static `EconomyMath` helper
- Milestone: M1 (follow-up)   Assignee: general-purpose   BlockedBy: none
- Spec: `systems/game_state.gd` (`_resolve_pockets`/`_sum_values`/`run_haul_value`); origin = close-out W5-G2-5
- Goal: lift the pure economy math out of `GameState` into a static `EconomyMath` helper so it's testable without snapshotting global meta (G2's economy suites currently save/restore `money`/`banked_junk`/`run_rules` around each test). `GameState` then calls the helper; no behavior change.
- Done when: a static `EconomyMath` (or similar) owns the pockets/sum/haul math; `GameState` delegates to it; the G2 economy suites are refactored to call the helper directly (no global-meta snapshot/restore); full suite stays green (GdUnit4 + legacy + SMOKE).

## Backlog (M2+)
Pulled forward when M1 passes its gate. See TDD §7 for M2 (vertical slice: full day loop, recipe repair, first enemy, real art for one band), M3 (bands 1–3, currencies/tracks, exposure crises), M4 (Act 3 + endings), M5 (polish/ship). The **economy workbook** `design/economy_model.xlsx` (game-director-designer) is due **before M3**.
