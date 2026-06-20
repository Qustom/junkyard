# STATUS — THE FAR YARD

**Resume point — read this first.** Where the orchestrator picks up after any interruption, with no other
context. Holds only *current* work: what's in progress (and how to continue it), what's blocked, the immediate
next action. Full task queue → `TASKS.md`; board mirror → GitHub Projects; completed tasks → `TASKS_COMPLETED.md`;
superseded status history → `STATUS_ARCHIVE.md`. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.0 → M1.1 → M1.2 (DONE → ITERATE) → **M1.3 (Legibility & Density) — Wave 1 DONE; Wave 2 IN PROGRESS (J2 ✓ J3 ✓ → J4 next/last).**
**Last updated:** 2026-06-20 (M1.3 Wave 2: **J2 + J3 integrated** on `main` — `4140d9f`, `4d54487`. Hazards distributed across `depth_index` (J2) + per-room cell-area density (J3, cap+ceiling); preset fills big rooms; loot-per-area built OFF. All-off fp byte-identical (`e943ac9c8bc1` via `test_rg1_m12_verify`); 44/44 knobs. Next: **J4** (hallway length + corridor telemetry — last Wave-2 task). Breakdown: `design/M1_3_Tasks/M1.3_Breakdown.md`.)

---

## ✓ Wave 2 (Oppositions retuned to the new canvas) — DONE (2026-06-19)

All three integrated on `main`, verified, pushed, board = Done. Determinism unmoved (fp=e943ac9c8bc1); none touched `main_game.gd`.
- **I2** hazard refuge fix (shrink body r10 + anti-wall-stick + depth-scaled catch + `r1_catch_radius_per_depth` knob, CFG 36/36) — merge `1966145`.
- **I3** R2/R3 cues (exposure ramp+ticks+penalty banner; return-cost pulse+floating −N; optional shake; all-off=M1.0 HUD) — merge `9b5d75d`.
- **I4** vision/fog rework (radial-dark occlusion ~0.94 + 3-state fog + lost edge-pulse/"DISORIENTED"; R4-off=M1.0) — merge `d56674d`.

Close-out: 0 formal deviations; 1 finding (W2.2-F1: R2 `exposure` toll fired its cue but didn't charge R3's meter — no `add()` on `exposure_meter.gd`) → Director: **fix now** → **BUG5** filed + dispatched.

---

## ✓ M1.2 DONE — re-gated, verdict ITERATE (2026-06-19)

Director playtested the RG1 build (33 runs, `ba745e1`). RG2 (`design/M1_2_Tasks/G4_findings_M1.2.md`): run-length ~2×
M1.1 (26.4s median), depth to 17, three-way end-causes (real hazard deaths), `duration_s` clean (I5 works). RG3 verdict:
**ITERATE → M1.3.** Director decisions + new issues (BUG6 hazard-spam, R3/R4 config traps) recorded in §5 of that doc.

## ✓ M1.3 Wave 1 (Foundation & correctness) — DONE (2026-06-19)

All 5 on `main`, verified, pushed, board=Done; all-off fp byte-identical (e943ac9c8bc1). Close-out: 2 Reviewed + 1 Addressed (history).
- **J5** depth counter → `Depth {depth_index} / {max}` via `depth_changed` — `50d8faf`.
- **BUG6** `hazard_caught` one-shot latch + `inert_enabled_oppositions()` warn-only traps — `ed176bf`; refined to maze-aware `r4_no_effect` (`25072f6`).
- **DLV2** in-game `JavaScriptBridge` telemetry-export button on the sell screen (web-guarded) — `2b00a09`.
- **DLV1** itch HTML5 delivery (Web preset + `push_itch.sh` + web templates + nightly slugs) — `02ad951`. ⚠ **real butler push human-gated** (sandbox can't reach `broth.itch.ovh`; run `tools/push_itch.sh` per SETUP §1a).
- **J1** `make_default_play_preset()` (19 rooms, size 4.0, R1 on, **R4 maze-only / occlusion OFF = match-played**, R2/R3 off) + `RANGE_MULT=[4.0,40.0]` — `3159aac` (+ `25072f6`).

## ▶ Next action (start here on a cold restart) — **M1.3 Wave 2: J4 IN PROGRESS (last Wave-2 task) → then Wave-2 close-out + Wave 3 re-gate**

`corridor_time_summary` signal pre-declared on `main` (`12e8932`). J4 dispatched in a worktree (branch from `main` post-J3).

- **J3** (general-purpose) — ✅ **DONE (2026-06-20, merge `4d54487`, board=Done, worklog `worklogs/2026-06-19-J3-general-purpose.md`).** Additive `_populate_room_density`/`_density_spawn_positions` on J2's seam; cell-area default (px-area capped option), per-room cap 3 + band ceiling 64; hazards primary, `lvl_loot_density_per_area` built OFF (never preset-on, disjoint `junk_placer.gd`). 44/44 knobs; all-off fp `e943ac9c8bc1` byte-identical. Perf: preset=14 density hazards, px-area@40×=42, worst-case clamped to 64. **Deviation: none functional** (`_density_sorted_cells` per-room stable y,x sort instead of calling `_hazard_spawn_position` directly — within spec allowance); **Q F observation surfaced for Director** (density hazards in deep rooms may wake immediately → R1 threshold/linger tuning at RG1, not a J3 change) → Wave-2 close-out.
- **J4** (general-purpose) — 🔄 **IN PROGRESS (claimed 2026-06-20, board=In Progress, worktree branch).** Configurable hallway length via **generator down-weight/drop** (NOT materialise re-pack; config-keyed → moves fp for non-default config, all-off byte-identical) + **per-frame corridor-time telemetry**. `corridor_time_summary` pre-declared on `main` (`12e8932`); hoist `_player_piece_index` out of the R4 gate; emit → additive `corridor_summary` JSONL row (no schema bump, no `run_ended` arity change); hardcoded corridor piece-id classification (no aspect-ratio fallback; L-bend just a corridor for classification). Adds its own `run_config.gd` knob(s) + preset wiring. Telemetry-only `main_game.gd` footprint. Spec `J4_hallway_length.md`.

Wave 2 is **sequential on the shared spawn seam + `main_game.gd`** (single-writer):
- **J2** (general-purpose) — ✅ **DONE (2026-06-19, merge `4140d9f`, board=Done, worklog `worklogs/2026-06-19-J2-general-purpose.md`).** N hazards distributed across depth_index (single_gate/even_spread/curve); owns `_spawn_r1_hazards`/`_hazard_spawn_position(band, depth, index)` (the stable helper J3 reuses); added `r1_spawn_distribution`+`r1_spread_min_depth`, preset = even_spread/count 5/min-depth 1; 38/38 knobs; all-off fp `e943ac9c8bc1` byte-identical. **1 deviation logged (curve `pow(t,1.6)` biases shallower not deeper — harmless, preset-OFF) → for Wave-2 close-out sweep.**
- **J3** (general-purpose) — **after J2 on `main`**: additive per-room **cell-area** density (`r1_per_room_density` + cap; px-area swept option; loot off-by-default) reusing J2's per-depth helper; adds its own knobs + preset wiring. Spec `J3_per_room_density.md`.
- **J4** (general-purpose) — **after J3 (or parallel iff main_game.gd disjoint)**: hallway-length via **generator down-weight** (NOT materialise re-pack); corridor-time telemetry (per-frame piece-keyed accumulator; **pre-declare `corridor_time_summary` on `main`** first; hoist `_player_piece_index` out of the R4 gate). Spec `J4_hallway_length.md`.
- Then **Wave 3** re-gate: RG1 build+verify → Director playtest → RG2 → RG3 (`G4_findings_M1.3.md`).

> **Each Wave-2 task adds its own `run_config.gd` knobs + wires them into `make_default_play_preset()`** (the breakdown's "J1 pre-declares" was superseded — Wave 2 is sequential, no parallel run_config collision). Update `test_run_config.gd`/`test_config_menu.gd` knob counts per task.

> **Contracts:** all-off default = permanent baseline (fp=e943ac9c8bc1); fun preset = `make_default_play_preset()`; warn-only traps (maze-only R4 is blessed); cell-area density; J4 = generator down-weight; web carries data (DLV2). Parallel agents `isolation: worktree`; **verify branch topology before every merge** (qa-agent `git switch` leak — memory); single-writer-per-`.gd`; push after every merge; board mirror; wave close-out deviation sweep.

> **Human action queued (before the itch playtest, not before Wave 2):** install butler + run `tools/push_itch.sh` once on a real network (SETUP §1a). itch web build is **Chromium-only**. Director-confirmed: itch project/password page + SAB toggle + GH `BUTLER_API_KEY` already set up.

---

## ✓ Wave 1 (Spatial & data foundation) — DONE (2026-06-19)

All three integrated on `main`, verified, pushed, board = Done. All-off default still byte-matches the M1.1 baseline (fp=e943ac9c8bc1).
- **I1** configurable level scale (count override + size mult + 4 new larger greybox pieces behind a config-dependent ext catalog) — merge `e67532c`. Worklog `worklogs/2026-06-19-I1-general-purpose.md`. *Empirical: linear spine reached requested count up to 60 — no count ceiling in the realistic range; run-time is the binding constraint (RG1/RG2 tuning).*
- **BUG4** geometry-keyed branch-rate-independent seal — merge `eee4418`. 508 void cells → 0 across 36 high-branch bands; fingerprint byte-identical. Worklog `worklogs/2026-06-19-BUG4-general-purpose.md`.
- **I5** telemetry hygiene (duration loop-re-entry regression-lock + real HEAD-SHA bake, `+dirty`) — merge `1fd657e`. Worklog `worklogs/2026-06-19-I5-qa-playtest-coordinator.md`.

Close-out: 4 deviations (I1-1, I1-2, + 2 lingering M1.1 RG1 entries), **all Director-Reviewed**, reapplied (`M1_As_Built.md` socket-width rule; `RG1`/`CFG` magic-count prose) + archived → `DESIGN_DEVIATIONS_HISTORY.md`. `DESIGN_DEVIATIONS.md` empty between waves.

---

## ▶ Next action (start here on a cold restart) — **finish BUG5, then dispatch Wave 3 (RG1)**

Waves 1 & 2 are on `main` (new spatial canvas + clean telemetry + retuned/legible oppositions). **BUG5 is in flight** (the
last build fix before the re-gate — makes R2's `exposure` toll actually charge R3). When BUG5 returns:
1. **Verify + integrate BUG5** (verify topology first — the Wave-1 stray-`git switch` lesson), push, board=Done, run its mini close-out.
2. **Dispatch Wave 3 — RG1** (`general-purpose` + `qa-playtest-coordinator`): author the M1.2 RG1 build+verify doc from the
   `design/M1_1_Tasks/RG1_playtest_build.md` template; assemble the runnable M1.2 loop; verify each fix individually + stacked;
   confirm config-marked telemetry writes; multiple runs/session. **BlockedBy: I1, BUG4, I5, I2, I4, I3 (all done) + BUG5.**
3. **RG2/RG3 are HUMAN-GATED** — RG1 hands off to a **Director playtest** (sweep configs on a dev machine), then `qa` analyses
   the telemetry vs the M1.0 (all-off) + M1.1 baselines (RG2), and the Director records the go/iterate/pivot verdict in
   `design/M1_2_Tasks/G4_findings_M1.2.md` (RG3). Claude assembles + recommends; the human plays + decides.

> **Collision note for Wave 3:** RG1 is largely additive scene-assembly + a verify test; it touches `main_game.gd` (loop
> wiring) + a new RG1 verify test. It's sequential (single task), so no parallel-collision management needed. Confirm no new
> `event_bus.gd` signal is required (the M1.1 RG1 needed none).

> **Standing process (locked):** parallel agents in `isolation: worktree`; pre-declare any new `event_bus.gd` signal on `main` before a parallel wave; single-writer-per-`.gd`-file; push `main` after every merge; mirror task status to the board; run the **wave close-out deviation sweep** after each wave (Director dispositions). See `CLAUDE.md` orchestrator loop.

**Also open (independent, Todo, non-blocking):** FU1 `test_jsonl_writer` · FU2 `EconomyMath`.

---

## Blocked
| Task | Blocked by | Note |
|---|---|---|
| ElevenLabs/PixelLab live generation | human | Connected; calling them spends paid credits — get human OK before a generation run. |

---

## History (not here — see)
- **Completed tasks** (M0, M1, M1.1, with proof/commits): `TASKS_COMPLETED.md`.
- **Superseded status sections** (M1/M1.1 Done tables, prior next-actions, playtest-gate notes): `STATUS_ARCHIVE.md`.
- **Design history**: `design/` (per-version `M<n>_*_Tasks/`), `DESIGN_DEVIATIONS_HISTORY.md`, `design/M1_Tasks/M1_As_Built.md`.

## Legend
`Backlog → In progress → (Verify) → Done` · or `→ Blocked`. A task is **Done** only with a worklog naming a real commit and its definition of done met.
