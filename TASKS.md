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

### Wave 1 — Foundations  *(R0 first & solo → BUG1 then BUG2 sequential [both touch `game_state.gd`] → CFG / TEL / BUG3 in parallel)*

### R0 — Run-config data model
- Milestone: M1.1   Assignee: game-director-designer (schema) + general-purpose (run-start wiring)   BlockedBy: none
- Spec: `design/M1_1_Tasks/M1.1_Breakdown.md` §R0
- Goal: one `RunConfig` Resource holding every opposition's knobs (per-opposition `enabled` master + seed override); `GameState` holds the active config per run and exposes it read-only; all-off default reproduces M1.0 exactly.
- Done when: a `RunConfig.tres` loads; `GameState.active_run_config` is populated at run start; all-off = M1.0 behavior; the config serializes to a flat dict for telemetry.

The three G4 bug-fixes below are **M1.1 Wave-1 foundations** (the cost axis is depth-scaled, so depth + duration must be real; R4 needs a sealed map). Provenance: `design/M1_Tasks/G4_findings.md`.

### BUG1 — `run_ended.duration_s` always 0
- Milestone: M1.1 (Wave 1)   Assignee: general-purpose   BlockedBy: R0 (sequential, shares `game_state.gd`)
- Spec: `design/M1_1_Tasks/BUG1_duration_s.md` (expanded design + pseudocode + ratified decisions)
- Goal: `run_ended(reason, duration_s, depth_reached)` emits `duration_s = 0.0` on every run (confirmed across 32 completed runs; real lengths were only recoverable from Telemetry's `t_ms`). Compute/pass the actual elapsed run time so the gate's core run-length metric is real. Likely `GameState.end_run`/`extract_and_end_run`/`fail_run` passing 0 instead of the elapsed time since `start_run`.
- Done when: a completed run emits a nonzero `duration_s` matching wall-clock (±tolerance) in `run_log.jsonl`; a headless check asserts it; suite stays green.

### BUG2 — within-band depth not tracked (telemetry depth stuck at 1)
- Milestone: M1.1 (Wave 1)   Assignee: general-purpose   BlockedBy: BUG1 (sequential, shares `game_state.gd`)
- Spec: `design/M1_1_Tasks/BUG2_within_band_depth.md` (expanded design + pseudocode + ratified decisions)
- Goal: `band_depth_reached`/`current_depth` only ever report 1 because `current_depth` is a band-entry counter, not within-band progress. The B3 depth axis (`depth_index`/`dist_to_gate` per `PlacedPiece`) exists but the player's position is never mapped to a "depth reached." Track how deep within the band the player travels (e.g. max `depth_index` of the piece they occupy) and feed it to telemetry so "how far did they push" is measurable. (NOTE: even fixed, the G4 finding stands — depth carries no *risk*; see G4_findings.md.)
- Done when: moving deeper in the band raises a tracked depth value and `band_depth_reached` fires for new maxima > 1; headless check; suite green.

### BUG3 — zone pieces have open sockets/exits into off-map void
- Milestone: M1.1 (Wave 1)   Assignee: general-purpose (+ environment-artist: piece geometry)   BlockedBy: R0 (parallel-safe; disjoint files)
- Spec: `design/M1_1_Tasks/BUG3_open_sockets.md` (expanded design + pseudocode + ratified decisions); background: `B1_zone_piece_format.md` / `B2_room_graph_generator.md` + `M1_As_Built.md` §Procedural geometry
- Goal: rooms have openings leading into areas outside the playable map (unused sockets left as gaps). After stitching, every socket that wasn't mated to a neighbor must be wall-capped (closed collision + floor edge) so the band is sealed.
- Done when: a generated band has no open sockets to the void (all unmated sockets capped); the player cannot walk off-map; headless/visual check; determinism preserved.

### CFG — Pre-run Config menu
- Milestone: M1.1 (Wave 1)   Assignee: ui-ux-designer (layout) + general-purpose (binding)   BlockedBy: R0
- Spec: `design/M1_1_Tasks/CFG_config_menu.md` (expanded design + pseudocode + ratified decisions); contract: `M1.1_Breakdown.md` §CFG
- Goal: a `Control` menu next to the Start Run menu in `scenes/game/main_game.tscn` exposing 100% of `RunConfig`'s knobs (per-opposition section w/ on/off + sliders/fields), writing them into the active config on Start; "reset to M1.0 baseline (all off)" action.
- Done when: the Director can toggle each opposition + set every knob before Start; the run reflects them; reset returns all-off; no knob is unreachable.

### TEL — Telemetry config-marking + opposition events
- Milestone: M1.1 (Wave 1)   Assignee: qa-playtest-coordinator   BlockedBy: R0  · **[edits `event_bus.gd` — sole editor; pre-declares ALL opposition signals up front]**
- Spec: `design/M1_1_Tasks/TEL_telemetry_config_marking.md` (expanded design — authoritative `event_bus.gd` pre-declared signal list + ratified decisions); contract: `M1.1_Breakdown.md` §TEL
- Goal: snapshot the active `RunConfig` flat dict onto the `run_started` row (additive `data` field, not a schema bump) so runs are comparable; pre-declare + log the per-opposition events (hazard_awoke/caught, return_cost_incurred, exposure_crossed/penalty, nav_branch_taken/lost_proxy) + `depth_changed`. Do NOT widen the locked `run_ended` arity.
- Done when: `run_started` carries the config snapshot; enabled oppositions' rows appear (disabled → absent); `run_ended` arity unchanged; schema handled.

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
