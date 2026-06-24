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

## M1.3 — Legibility & Density — ✓ **DONE 2026-06-21** (re-gated → ITERATE → M1.4)

All built + re-gated: Waves 1/2 (J1·J2·J3·J4·J5·BUG6·DLV1·DLV2) + RG1 → Director playtest → **RG3 verdict ITERATE**.
Findings + the Director feedback work-order: `design/M1_3_Tasks/G4_findings_M1.3.md`. Tasks archived → `TASKS_COMPLETED.md`.

---

## M1.4 — Stakes, Variety & Legibility — ✓ **DONE 2026-06-21..24** (re-gated → ITERATE → M1.5)

All waves built + re-gated: Waves 1–3 (K0–K7, K5a/b/c/i) + RG1 + Wave-5 bug-wave (BUG7/BUG8/TUNE2/FB5) → Director
playtest → **RG3 verdict ITERATE → M1.5** (`design/M1_4_Tasks/G4_findings_M1.4.md` §RG3). Tasks archived →
`TASKS_COMPLETED.md`.

---

## M1.5 — Agency & Legibility (ACTIVE — iterating on the M1.4 ITERATE verdict)

Give the player agency against danger (throw a highlighted inventory item to kill a pursuer), make the pursuer a
comprehensible room-bound slow patrol, and fix two legibility bugs (money text hidden behind inventory; grab prompt
always on) — then re-gate. Breakdown + dependency map + wave order + locked decisions:
`design/M1_5_Tasks/M1.5_Breakdown.md` (§"Phase 3 Dispositions & Phase 4 Lock"). Provenance: `G4_findings_M1.4.md` §RG3.
**Design is LOCKED** — every task doc carries a "Resolved Decisions (Phase 3)" section; Director dispositioned the fun
calls (throw kills pursuer + ping-pong, no scope knob; pursuer paces between two points). Greybox; all-off `RunConfig`
stays the permanent baseline (fp=e943ac9c8bc1); throw/highlight/pursuer behaviour are pure run-state (no save change);
the fun values ship in `make_default_play_preset()`. Knob count 81 → **89**.

### Wave 1 — Foundation + legibility fixes  *(L0 ∥ L3 ∥ L4 — all file-disjoint, parallel)*

### L0 — Foundation: knob + signal pre-declare
- Milestone: M1.5 (Wave 1)   Assignee: general-purpose   BlockedBy: none
- Spec: `design/M1_5_Tasks/L0_foundation_knobs_signals.md`
- Goal: single-writer pass on `run_config.gd` + `event_bus.gd` + `config_menu.gd`: declare the 8 M1.5 knobs (`throw_enabled`/`throw_speed`/`throw_max_range`; `r1_spawn_room_only`/`r1_patrol_speed`; `hpp_kills`/`hbomb_kills`/`hspike_kills`) at off/neutral (`*_kills`=true) + extend `to_flat_dict()` + declare the 4 new signals (`item_thrown`, `throw_missed`, `throw_killed_hazard`, `hazard_pursuer_state`) + CFG rows/CSV stubs. Unblocks the parallel build.
- Done when: project imports clean; all-off fp byte-identical (e943ac9c8bc1); CFG menu boots; knob-count tests green (81→89); every new knob in `to_flat_dict()`; every new signal declared.

### L3 — Money-text reposition (#8)
- Milestone: M1.5 (Wave 1)   Assignee: ui-ux-designer   BlockedBy: none
- Spec: `design/M1_5_Tasks/L3_money_text_reposition.md`
- Goal: move `HaulValueLabel` from top-left (hidden behind the bottom-right inventory) to below the dive timer (top-right, right-aligned) — pure `.tscn` anchor/offset edit; `_refresh_haul()` untouched. Bug-fix, not knob-gated.
- Done when: money readout sits below the timer, not behind the inventory; import clean; no logic/fp change.

### L4 — Grab-prompt visibility fix (#9)
- Milestone: M1.5 (Wave 1)   Assignee: general-purpose   BlockedBy: none
- Spec: `design/M1_5_Tasks/L4_grab_prompt_fix.md`
- Goal: drive `_prompt.visible` as a per-frame invariant of `_current != null && is_instance_valid(_current) && _current.can_interact()`; default `interaction_prompt.tscn` hidden + clear baked text; add a hide-invariant regression test. Don't refactor the selection/hysteresis loop. Bug-fix, not knob-gated.
- Done when: the grab prompt shows iff a valid grabbable is in focus/range; regression test green; no knob/signal/save/fp change.

### Wave 2 — Agency & threat  *(L1 → L2 sequenced on main_game.gd; L5 parallel)*

### L1 — Throwing mechanic
- Milestone: M1.5 (Wave 2)   Assignee: general-purpose (+ ui-ux-designer highlight selector)   BlockedBy: L0
- Spec: `design/M1_5_Tasks/L1_throwing_mechanic.md`
- Goal: input remap (F=grab/interact incl. gate; Q/E=highlight L/R; Space=throw); a navigable inventory highlight (`highlighted_index()`/`highlighted_item()`, border, clampi-revalidate); Space removes the highlighted item + spawns an `entities/thrown_item` Area2D (mask world|hazard) in `player.facing`; hit a hazard-layer body (pursuer or ping-pong) → kill it + destroy the item; miss → `EventBus.junk_dropped` re-drop. Knob-gated (`throw_enabled` off default, preset on). Pure run-state.
- Done when: Q/E cycle a visible highlight; Space throws in facing dir; hitting pursuer/ping-pong kills it + destroys the item; miss re-drops as grabbable; all-off fp byte-identical; config-marked telemetry clean.

### L2 — Spawn-room pursuer (#6)
- Milestone: M1.5 (Wave 2)   Assignee: general-purpose (+ game-director-designer)   BlockedBy: L0, L1 (single-writer on `main_game.gd`)
- Spec: `design/M1_5_Tasks/L2_spawn_room_pursuer.md`
- Goal: the `HazardEntity` pursuer becomes a room-bound slow patrol (paces between two endpoints at `r1_patrol_speed`), chases only while the player is in its spawn room (`_room_bounds.has_point`), catch only while chasing, immediate re-entry resume. Widen `setup` to the K5 3-arg family + thread `_piece_floor_bounds_world` through both R1 spawn helpers. Knob-gated (`r1_spawn_room_only` off default = today's chase-everywhere). Emits `hazard_pursuer_state`.
- Done when: pursuer patrols + stays room-bound + chases only in-room + catches only while chasing; off = byte-identical today's pursuer; all-off fp unmoved.

### L5 — K5 per-hazard `*_kills` toggles *(M1.4 Wave-5 "Addressed" carry-in)*
- Milestone: M1.5 (Wave 2)   Assignee: general-purpose (+ game-director-designer)   BlockedBy: L0
- Spec: `design/M1_5_Tasks/L5_hazard_kills_toggles.md`
- Goal: guard each K5 hazard's `fail_run(&"death")` with `if cfg.<prefix>_kills:` (mirroring R1's `r1_catch_kills`); default `true` = today's lethal behaviour; emit-always (non-lethal still emits `new_hazard_killed`). Retire `_driven_default_preset()` — the M1.5 verify runs the real preset with the three `*_kills`=false.
- Done when: each K5 hazard is non-lethal iff its `*_kills`=false (kept lethal by default); `_driven_default_preset()` removed; existing K5 tests green + one kills-off case each; all-off fp byte-identical.

### Wave 3 — Re-gate  *(sequential; RG2/RG3 after the human playtest)*

### RG1 — M1.5 playtest build + verify
- Milestone: M1.5 (Wave 3)   Assignee: qa-playtest-coordinator   BlockedBy: L0,L1,L2,L3,L4,L5
- Spec: author from `design/M1_4_Tasks/RG1_playtest_build.md` template
- Goal: assemble + verify the M1.5 loop (preset boots, throw highlights+throws+kills+re-drops, pursuer patrols/room-bounds, money readable below timer, grab prompt context-correct, all-off fp byte-identical, config-marked telemetry clean); **publish to itch** via `bash tools/push_itch.sh`; update `changelog.txt`.
- Done when: a fresh build runs the full loop with the new mechanic + fixes; per-run config works; telemetry clean; build live on `qusto/the-far-yard:html5`.

### RG2 — M1.5 telemetry analysis vs M1.0–M1.4
- Milestone: M1.5 (Wave 3)   Assignee: qa-playtest-coordinator   BlockedBy: RG1 + human playtest data
- Spec: template `design/M1_1_Tasks/RG2_telemetry_analysis.md`
- Goal: end-cause / run-length / depth / throw-kill / throw-miss / pursuer-state distributions per config, side-by-side vs all five prior baselines; did agency + the room-bound pursuer + the legibility fixes land?
- Done when: an analysis artifact comparing distributions across configs + all five baselines, with a clear read.

### RG3 — M1.5 re-gate verdict (Director decides)
- Milestone: M1.5 (Wave 3)   Assignee: qa-playtest-coordinator (assembles) → Director (decides)   BlockedBy: RG2
- Spec: template `design/M1_1_Tasks/RG3_regate_verdict.md`
- Goal: record go/iterate/pivot in `design/M1_5_Tasks/G4_findings_M1.5.md`. go → M2; iterate → M1.6; pivot → design rework.
- Done when: a recorded go/iterate/pivot verdict backed by config-marked telemetry, comparable to the prior findings.

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
