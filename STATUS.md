# STATUS — THE FAR YARD

**Resume point — read this first.** Where the orchestrator picks up after any interruption, with no other
context. Holds only *current* work: what's in progress (and how to continue it), what's blocked, the immediate
next action. Full task queue → `TASKS.md`; board mirror → GitHub Projects; completed tasks → `TASKS_COMPLETED.md`;
superseded status history → `STATUS_ARCHIVE.md`. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.0 → M1.1 → M1.2 (DONE → ITERATE) → **M1.3 (Legibility & Density) — design LOCKED (four-phase complete + Director-dispositioned); Wave 1 ready to dispatch.**
**Last updated:** 2026-06-19 (M1.3 four-phase authoring complete: Phase 1 breakdown · Phase 2 (8 task docs incl. new DLV2) · Phase 3 fresh-eyes · Director dispositioned all 4 load-bearing calls → design LOCKED + board wired. Next: Wave 1 build. Breakdown: `design/M1_3_Tasks/M1.3_Breakdown.md`.)

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

## ▶ Next action (start here on a cold restart) — **M1.3 Wave 1: BUG6 → J1, ∥ J5 ∥ DLV1 ∥ DLV2**

M1.3 design is LOCKED (every task doc ends with a "Director Disposition (FINAL)"; board items created, Todo). Dispatch **Wave 1**:

- **BUG6** (general-purpose) — one-shot `hazard_caught` latch + `inert_enabled_oppositions()` 5-trap **warn-only** guard. **Lands its `run_config.gd` method first.** Spec `BUG6_*.md`. **[touch: `hazard_entity.gd`, `run_config.gd` (method), `telemetry.gd` (flag)]**
- **J1** (game-director-designer + general-purpose) — `make_default_play_preset()` (19 rooms, size 4.0, R1+R4 on, `r4_lost_proxy_threshold≈0.5`, R2/R3 off) + `RANGE_MULT=[4.0,40.0]`; all-off stays baseline. **After BUG6** (rebases preset; folds BUG6's CFG warn-line; pre-declares J2/J3 `r1_*` knobs). Spec `J1_*.md`. **[touch: `run_config.gd`, `config_menu.gd`, `config_strings.csv`, `main_game.gd:178`, tests]**
- **J5** (ui-ux-designer) — depth counter → `Depth {depth_index} / {max}` via `depth_changed`. Parallel (HUD-disjoint). Spec `J5_*.md`. **[touch: `decision_hud.gd`, `hud_strings.csv`, `test_decision_hud.gd`]**
- **DLV1** (producer + general-purpose) — butler + 4.6.3 web templates + Web preset + `tools/push_itch.sh` → `qusto/the-far-yard:html5`. Parallel (infra). **Needs network for installs; human prereqs flagged.** Spec `DLV1_*.md`.
- **DLV2** (ui-ux-designer + general-purpose) — in-game JavaScriptBridge "Export telemetry" download (web-guarded). Parallel. Spec `DLV2_*.md`. ⚠ if it edits the same HUD scene as J5, coordinate/sequence.

**Wave 2** (after W1 on `main`): **J2 → J3** (one shared spawn seam, J2 owns + lands first, J3 additive) then **J4** (generator down-weight + corridor telemetry; pre-declare `corridor_time_summary` on `main`). **Wave 3:** re-gate (RG1 → Director playtest → RG2 → RG3 `G4_findings_M1.3.md`).

> **Contracts:** all-off default = permanent baseline (fp=e943ac9c8bc1); fun config = `make_default_play_preset()` boot preset; warn-only config traps; cell-area density; J4 = generator down-weight (not re-pack); web carries data (DLV2). Parallel agents `isolation: worktree`; **verify branch topology before every merge** (qa-agent `git switch` leak — see memory); single-writer-per-`.gd`; push `main` after every merge; board mirror; wave close-out deviation sweep.

> **DLV1/DLV2 env note:** butler + 4.6.3 web templates NOT installed (network needed); itch is **Chromium-only** (Firefox lacks credentialless COEP); human prereqs = itch project/password page + SAB toggle + GH `BUTLER_API_KEY` secret. Never commit APIKEYS.md.

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
