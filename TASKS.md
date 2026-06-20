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

## M1.2 — Legibility & Level Scale — ✓ **DONE 2026-06-19** (re-gated → ITERATE → M1.3)

All built + re-gated: Waves 1/2 + BUG5 + RG1 → Director playtest → RG2 → **RG3 verdict ITERATE**. Findings + Director
decisions: `design/M1_2_Tasks/G4_findings_M1.2.md`. All tasks archived → `TASKS_COMPLETED.md`.

---

## M1.3 — Legibility & Density (ACTIVE — iterating on the M1.2 ITERATE verdict)

Make the fun config the default, fill the big rooms with distributed danger, fix the depth readout, and guarantee every
enabled opposition actually fires — then re-gate for a possible "go." Breakdown + dependency map + wave order + locked
decisions: `design/M1_3_Tasks/M1.3_Breakdown.md` (§"Phase 4 — Locked Decisions"). Provenance: `G4_findings_M1.2.md` §5.
**Design is LOCKED** — every task doc ends with a "Director Disposition (FINAL)". Greybox; all-off `RunConfig` stays the
permanent baseline (fp=e943ac9c8bc1); the fun config ships as the `make_default_play_preset()` boot preset.

### Wave 1 — Foundation & correctness — ✓ **DONE 2026-06-19** (archived → `TASKS_COMPLETED.md`)

J5 (`50d8faf`) · BUG6 (`ed176bf`+`25072f6`) · DLV2 (`2b00a09`) · DLV1 (`02ad951`, push human-gated) · J1 (`3159aac`+`25072f6`) — all on
`main`, board=Done; all-off fp byte-identical (e943ac9c8bc1). Close-out: 2 Reviewed + 1 Addressed (preset = match-played R4
occlusion-OFF + maze-aware `r4_no_effect` trap). Default boot preset live. ⚠ butler push human-gated (`tools/push_itch.sh`, SETUP §1a).

### Wave 2 — Density & spatial  *(NEXT — J2→J3 shared spawn seam; J4 telemetry-only, sequenced)*

### J2 — Enemy spread across depths
- Milestone: M1.3 (Wave 2)   Assignee: general-purpose (+ character-animator if a tell needs it)   BlockedBy: J1
- Spec: `design/M1_3_Tasks/J2_enemy_spread.md`
- Goal: `even_spread` distribution of N hazards across depth_index (curve mode built, preset-off); reuse `hazard_awoke/caught`. **Owns the spawn seam; lands before J3.** Determinism untouched (run-state).
- Done when: hazards spread across depths (not one gate); off=M1.0; `even_spread` preset (count 4–6, min-depth 1–2) works.

### J3 — Per-room density (cell-area)
- Milestone: M1.3 (Wave 2)   Assignee: general-purpose   BlockedBy: J2 (additive on J2's spawn seam)
- Spec: `design/M1_3_Tasks/J3_per_room_density.md`
- Goal: **cell-area** hazard budget (`r1_per_room_density`, size-invariant; px-area swept option; per-room cap); hazards primary, loot-per-area off-by-default. Fills huge rooms. Determinism untouched.
- Done when: big rooms get proportional hazards; off=M1.0; cap holds; all-off byte-identical.

### J4 — Hallway-length (generator down-weight) + corridor telemetry
- Milestone: M1.3 (Wave 2)   Assignee: general-purpose   BlockedBy: J1 (sequence after J2/J3 on `main_game.gd`)
- Spec: `design/M1_3_Tasks/J4_hallway_length.md`
- Goal: make long corridors rarer/shorter via the **generator weighted-pick** (Option b/c; config-keyed fp move, all-off byte-identical); corridor-time telemetry via a per-frame piece-keyed accumulator + pre-declared `corridor_time_summary`.
- Done when: the preset yields fewer/shorter corridors; corridor_summary row logs (R4 on/off); all-off fp unmoved.

### Wave 3 — Re-gate  *(sequential; RG2/RG3 after the human playtest)*

### RG1 — M1.3 playtest build + verify
- Milestone: M1.3 (Wave 3)   Assignee: qa-playtest-coordinator   BlockedBy: J1,J2,J3,J4,J5,BUG6,DLV1,DLV2
- Spec: author from `design/M1_1_Tasks/RG1_playtest_build.md` + the M1.2 `RG1_playtest_build.md` template
- Goal: assemble + verify the M1.3 loop (preset boots, every knob fires, traps warn, corridor telemetry, config-marked logs); auto-push via DLV1; DLV2 export available.
- Done when: a fresh build runs the full loop with the fixes; per-run config works; telemetry clean; multiple runs/session.

### RG2 — M1.3 telemetry analysis vs M1.0/M1.1/M1.2
- Milestone: M1.3 (Wave 3)   Assignee: qa-playtest-coordinator   BlockedBy: RG1 + human playtest data
- Spec: template `design/M1_1_Tasks/RG2_telemetry_analysis.md`
- Goal: end-cause / run-length / depth / corridor-fraction distributions per config, side-by-side vs M1.0/M1.1/M1.2; did density + defaults + the fixes land?
- Done when: an analysis artifact comparing distributions across configs + all three baselines, with a clear read.

### RG3 — M1.3 re-gate verdict (Director decides)
- Milestone: M1.3 (Wave 3)   Assignee: qa-playtest-coordinator (assembles) → Director (decides)   BlockedBy: RG2
- Spec: template `design/M1_1_Tasks/RG3_regate_verdict.md`
- Goal: record go/iterate/pivot in `design/M1_3_Tasks/G4_findings_M1.3.md`. go → M2; iterate → M1.4; pivot → design rework.
- Done when: a recorded go/iterate/pivot verdict backed by config-marked telemetry, comparable to the M1.0/M1.1/M1.2 findings.

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
