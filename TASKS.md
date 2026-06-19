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

### Wave 2 — Oppositions retuned to the new canvas  *(NEXT — parallel; ⚠ watch the I2/I4 `main_game.gd` collision)*

### I2 — Hazard fix (size, navigation, catch)
- Milestone: M1.2 (Wave 2)   Assignee: general-purpose (+ character-animator: greybox tell)   BlockedBy: I1 (tune to new room scale)
- Spec: `design/M1_2_Tasks/I2_hazard_fix.md`
- Goal: M1.1 `hazard_caught=0` (body 32px == 32px hall → wall-stick; catch radius 24 < 30px contact → impossible). **Refuge** (Director): keep wall collision, shrink the body (~r10), raise catch radius above combined contact, add anti-wall-stick steering (next-frame tangent), add depth-scaled `r1_catch_radius_per_depth`, retune awaken to I1's depths. Kill via existing `fail_run(&"death")`.
- Done when: with R1 on the hazard visibly closes + **catches → `death`** at a fair rate; off = M1.0; knobs take effect; `hazard_caught` rows appear.

### I4 — Vision/fog rework (real occlusion + legible fog/lost)
- Milestone: M1.2 (Wave 2)   Assignee: general-purpose (+ environment-artist: greybox look)   BlockedBy: I1 (radius vs scale)
- Spec: `design/M1_2_Tasks/I4_vision_rework.md`
- Goal: M1.1 vision only *dims*. Make it **occlude** (hide beyond the radius) via a node-based **radial-dark world mask** (darkness ~0.94, anti-blindness floor; no shader); three-state fog (never-seen / cool-ghost remembered / live); a legible **"lost" cue** (screen-edge pulse + HUD word) tied to `lost_proxy_threshold`. Cosmetic-only; radius tuned to I1.
- Done when: beyond the radius geometry is hidden (not faintly visible); fog + lost cue legible; off = full M1.0 vision; determinism/seal intact; knobs take effect.

### I3 — R2/R3 visual cues
- Milestone: M1.2 (Wave 2)   Assignee: ui-ux-designer   BlockedBy: none (R2/R3 already emit)
- Spec: `design/M1_2_Tasks/I3_r2_r3_cues.md`
- Goal: R2/R3 fire invisibly. R3 = colour-ramped exposure bar + threshold ticks + penalty banner on `exposure_crossed`/`exposure_penalty` (keyed on the confirmed `penalty_kind` StringNames `speed`/`vision`/`clock`/`none`); R2 = clock-bar pulse + floating "−N {unit}" on `return_cost_incurred`; optional small penalty screen-shake. Pure HUD projection, non-colour channel, no new EventBus signal; invisible when the opposition is off.
- Done when: the player sees exposure climbing + each penalty + each retreat toll; off = M1.0 HUD; honors E2 readability rules.

### Wave 3 — Re-gate  *(sequential; RG2/RG3 after the human playtest)*

### RG1 — M1.2 playtest build + verify
- Milestone: M1.2 (Wave 3)   Assignee: general-purpose + qa-playtest-coordinator   BlockedBy: I1, BUG4, I5, I2, I4, I3
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
