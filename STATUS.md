# STATUS — THE FAR YARD

**Resume point — read this first.** Where the orchestrator picks up after any interruption, with no other
context. Holds only *current* work: what's in progress (and how to continue it), what's blocked, the immediate
next action. Full task queue → `TASKS.md`; board mirror → GitHub Projects; completed tasks → `TASKS_COMPLETED.md`;
superseded status history → `STATUS_ARCHIVE.md`. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.0 → M1.1 (both built; M1.1 playtested → **ITERATE**) → **M1.2 (Legibility & Level Scale)** — **all build work DONE (Waves 1+2+BUG5); Wave 3 RG1 in progress, then HUMAN-GATED playtest.**
**Last updated:** 2026-06-19 (BUG5 integrated `0196713`; all M1.2 fixes on `main`. Wave 3 RG1 dispatched (build+verify+tester materials). Next: RG1 lands → **Director playtest** → RG2 analysis → RG3 verdict. Breakdown: `design/M1_2_Tasks/M1.2_Breakdown.md`.)

---

## ✓ Wave 2 (Oppositions retuned to the new canvas) — DONE (2026-06-19)

All three integrated on `main`, verified, pushed, board = Done. Determinism unmoved (fp=e943ac9c8bc1); none touched `main_game.gd`.
- **I2** hazard refuge fix (shrink body r10 + anti-wall-stick + depth-scaled catch + `r1_catch_radius_per_depth` knob, CFG 36/36) — merge `1966145`.
- **I3** R2/R3 cues (exposure ramp+ticks+penalty banner; return-cost pulse+floating −N; optional shake; all-off=M1.0 HUD) — merge `9b5d75d`.
- **I4** vision/fog rework (radial-dark occlusion ~0.94 + 3-state fog + lost edge-pulse/"DISORIENTED"; R4-off=M1.0) — merge `d56674d`.

Close-out: 0 formal deviations; 1 finding (W2.2-F1: R2 `exposure` toll fired its cue but didn't charge R3's meter — no `add()` on `exposure_meter.gd`) → Director: **fix now** → **BUG5** filed + dispatched.

---

## In progress — Wave 3 RG1 (dispatched 2026-06-19, `isolation: worktree`)

- **RG1** (qa-playtest-coordinator) — assemble + verify the M1.2 playtest build: author `design/M1_2_Tasks/RG1_playtest_build.md` (M1.2 verify matrix from the M1.1 template), a headless verify test, and updated `tools/playtest/{loop_smoke_checklist,tester_readme}.md` with the Director's config-sweep guidance. Verifies each fix individually + stacked, all-off=baseline, config-marked telemetry + real build SHA. Board = In Progress. **BlockedBy: I1/BUG4/I5/I2/I4/I3/BUG5 (all done).**

**BUG5 — ✓ DONE** (merged `0196713`): `exposure_meter.add()` routed through the shared crossing/penalty helper; R2 `exposure` toll now moves R3's meter end-to-end (integration test: taxed retreat raises meter by 6.5). All-off unchanged; determinism unmoved.

> **After RG1 lands → HUMAN GATE.** RG2 (telemetry analysis vs M1.0/M1.1) needs a Director playtest first; RG3 (go/iterate/pivot verdict) is the Director's call, recorded in `design/M1_2_Tasks/G4_findings_M1.2.md`. Claude assembles + recommends; the human plays + decides.

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
