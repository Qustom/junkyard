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

### Wave 2 — The four oppositions  *(four parallel worktrees; each reads `active_run_config` + live depth, emits TEL's pre-declared signals; none edit `event_bus.gd`/`game_state.gd`. Each opposition's first sub-step is its `game-director-designer` spec at `design/M1_1_Tasks/R<n>_*.md`.)*

### R1 — Pursuing / awakening hazard
- Milestone: M1.1 (Wave 2)   Assignee: general-purpose + game-director-designer (spec) + character-animator (greybox tell)   BlockedBy: R0, BUG2
- Spec: `design/M1_1_Tasks/R1_pursuing_hazard.md` (expanded spec + pseudocode + ratified decisions)
- Goal: a greybox entity that awakens past a depth/linger threshold and chases the player; catching → existing `fail_run(&"death")`. Crude steering, no combat. Fully configurable; emits `hazard_awoke`/`hazard_caught`.
- Done when: with R1 on it awakens per threshold, chases, can end a run as death; off = M1.0; knobs take effect from the menu; events log.

### R2 — Costlier return trip
- Milestone: M1.1 (Wave 2)   Assignee: general-purpose + game-director-designer (spec proposes the mechanism — Director reviews)   BlockedBy: R0, BUG2
- Spec: `design/M1_1_Tasks/R2_costlier_return.md` (expanded spec + pseudocode + ratified decisions — `egress_toll`+`clock` ratified as the primary mechanism)
- Goal: make the way back scale with how deep you pushed (mechanism — lengthen / decay-behind / egress-toll — proposed by the R2 spec, Director-approved; reads B3 `dist_to_gate`). Configurable; emits `return_cost_incurred`.
- Done when: retreating from depth d costs measurably more than from depth 1 per the configured curve; off = free walk-back (M1.0); knobs take effect.

### R3 — Rising instability / exposure meter
- Milestone: M1.1 (Wave 2)   Assignee: general-purpose + game-director-designer (spec) + ui-ux-designer (HUD readout)   BlockedBy: R0, BUG2
- Spec: `design/M1_1_Tasks/R3_exposure_meter.md` (expanded spec + pseudocode + ratified decisions — penalties applied via TEL-declared `exposure_*` signals)
- Goal: a run-state meter that climbs faster at depth and punishes lingering; thresholds inflict penalties; max → `run_ended.reason = timeout`. Disposable prototype of the M3 exposure system (NOT wired to meta `exposure`). Configurable; emits `exposure_crossed`/`exposure_penalty`.
- Done when: meter rises faster at depth, crossings fire penalties, (if configured) max ends run as timeout; greybox readout shows it; off = M1.0; knobs take effect.

### R4 — Maze / navigation risk
- Milestone: M1.1 (Wave 2)   Assignee: general-purpose + environment-artist (branching/fog) + game-director-designer (spec)   BlockedBy: R0, BUG2, BUG3
- Spec: `design/M1_1_Tasks/R4_maze_navigation.md` (expanded spec + pseudocode + ratified decisions — determinism contract is now `fingerprint(seed + config)`)
- Goal: deeper = harder to navigate — raise B2 `branch_chance` with depth (dead-ends) and/or limited vision/fog; needs BUG3 (sealed map). Emit a lost-proxy (backtracking/no-progress). Configurable; emits `nav_branch_taken`/`nav_lost_proxy`.
- Done when: deep areas branch and/or vision is limited per config; band stays sealed + deterministic per seed+config; off = linear M1.0 spine, full vision; knobs take effect.

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
