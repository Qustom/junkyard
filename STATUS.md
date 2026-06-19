# STATUS — THE FAR YARD

**Resume point — read this first.** Where the orchestrator picks up after any interruption, with no other
context. Holds only *current* work: what's in progress (and how to continue it), what's blocked, the immediate
next action. Full task queue → `TASKS.md`; board mirror → GitHub Projects; completed tasks → `TASKS_COMPLETED.md`;
superseded status history → `STATUS_ARCHIVE.md`. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.0 → M1.1 (both built; M1.1 playtested → **ITERATE**) → **M1.2 (Legibility & Level Scale)** — **Wave 1 DONE; Wave 2 DISPATCHED (in progress).**
**Last updated:** 2026-06-19 (M1.2 Wave 2 dispatched: I2 ∥ I4 ∥ I3 in parallel worktrees, ownership-split so `main_game.gd` has a single writer. Board items created + In Progress. Breakdown: `design/M1_2_Tasks/M1.2_Breakdown.md`.)

---

## In progress — M1.2 Wave 2 (dispatched 2026-06-19; parallel `isolation: worktree`, ownership-split)

| Task | Agent(s) | Owns (sole writer this wave) | Board |
|---|---|---|---|
| **I2** Hazard refuge fix | general-purpose (+ character-animator: greybox tell) | `scenes/hazards/hazard_entity.gd/.tscn`, `run_config.gd`, `config_menu.gd`, `config_strings.csv` (+ `test_run_config.gd`/`test_config_menu.gd` knob counts). **Must NOT touch `main_game.gd`** | In Progress |
| **I4** Vision/fog rework | general-purpose (+ environment-artist: greybox look) | `vision_fog.gd/.tscn`, **`scenes/game/main_game.gd` (sole writer)**, its own lost-cue overlay. **Must NOT touch `decision_hud.gd`** | In Progress |
| **I3** R2/R3 cues | ui-ux-designer | `decision_hud.gd/.tscn`, `exposure_readout.gd`, `hud_strings.csv` | In Progress |

**Collision plan:** `main_game.gd` → I4 only (I2's spawn seam already works; if I2 finds it truly needs a `main_game.gd` tweak it flags it for the orchestrator to apply post-merge). HUD: `decision_hud.gd` → I3 only (I4 keeps its lost-cue word in its own overlay). `run_config.gd`+CFG → I2 only. No `event_bus.gd` signal needed by any task (all three subscribe to already-declared, already-emitted signals).

---

## ✓ Wave 1 (Spatial & data foundation) — DONE (2026-06-19)

All three integrated on `main`, verified, pushed, board = Done. All-off default still byte-matches the M1.1 baseline (fp=e943ac9c8bc1).
- **I1** configurable level scale (count override + size mult + 4 new larger greybox pieces behind a config-dependent ext catalog) — merge `e67532c`. Worklog `worklogs/2026-06-19-I1-general-purpose.md`. *Empirical: linear spine reached requested count up to 60 — no count ceiling in the realistic range; run-time is the binding constraint (RG1/RG2 tuning).*
- **BUG4** geometry-keyed branch-rate-independent seal — merge `eee4418`. 508 void cells → 0 across 36 high-branch bands; fingerprint byte-identical. Worklog `worklogs/2026-06-19-BUG4-general-purpose.md`.
- **I5** telemetry hygiene (duration loop-re-entry regression-lock + real HEAD-SHA bake, `+dirty`) — merge `1fd657e`. Worklog `worklogs/2026-06-19-I5-qa-playtest-coordinator.md`.

Close-out: 4 deviations (I1-1, I1-2, + 2 lingering M1.1 RG1 entries), **all Director-Reviewed**, reapplied (`M1_As_Built.md` socket-width rule; `RG1`/`CFG` magic-count prose) + archived → `DESIGN_DEVIATIONS_HISTORY.md`. `DESIGN_DEVIATIONS.md` empty between waves.

---

## ▶ Next action (start here on a cold restart) — **M1.2 Wave 2: I2 ∥ I4 ∥ I3**

Wave 1 is on `main` (the new spatial canvas + clean telemetry). **Wave 2 retunes the oppositions to that canvas.** Author the
build briefs from the locked specs (each ends with a "Director Disposition (FINAL)") and dispatch in parallel worktrees, but
**⚠ sequence I2 and I4 if they both edit `scenes/game/main_game.gd`** (the dive-scene wiring) — single-writer-per-`.gd`-file
(the W1.1-2 lesson). I3 is HUD-disjoint and can run fully parallel.

- **I2** (general-purpose + character-animator: greybox tell) — hazard **refuge** fix: keep wall collision, shrink body (~r10) + anti-wall-stick steering, raise catch radius above combined contact, depth-scaled `r1_catch_radius_per_depth`, retune awaken to I1's depths; kill via `fail_run(&"death")`. **Tune to I1's new room scale.** Spec: `design/M1_2_Tasks/I2_hazard_fix.md`. **BlockedBy: I1 (done).** **[touch: `main_game.gd` + hazard scene/script]**
- **I4** (general-purpose + environment-artist: greybox look) — vision/fog rework: node-based **radial-dark world mask** (occlude beyond radius, ~0.94 darkness, anti-blindness floor, no shader), three-state fog (never-seen / cool-ghost / live), legible "lost" cue (edge-pulse + HUD word) on `lost_proxy_threshold`; radius tuned to I1. Spec: `design/M1_2_Tasks/I4_vision_rework.md`. **BlockedBy: I1 (done).** **[touch: `main_game.gd` + vision/fog nodes]** ⚠ shares `main_game.gd` with I2.
- **I3** (ui-ux-designer) — R2/R3 visual cues: R3 colour-ramped exposure bar + threshold ticks + penalty banner on `exposure_crossed`/`exposure_penalty` (keys `penalty_kind` `speed`/`vision`/`clock`/`none`); R2 clock-bar pulse + floating "−N {unit}" on `return_cost_incurred`; optional penalty shake. Pure HUD projection, no new EventBus signal. Spec: `design/M1_2_Tasks/I3_r2_r3_cues.md`. **BlockedBy: none.** **[touch: HUD scenes/scripts only]**

> **Collision plan for Wave 2:** read I2's and I4's specs' "Files to touch" first. If both edit `main_game.gd`, dispatch I3 (HUD-disjoint) + one of I2/I4 in parallel worktrees, then the other after the first merges (or have one stub the shared seam). Pre-declare any new `event_bus.gd` signal on `main` before dispatch (I3 needs none; confirm for I2/I4).

**Wave 3** re-gate: RG1 build + verify → **human playtest** → RG2 analysis vs M1.0/M1.1 baselines → RG3 verdict (`G4_findings_M1.2.md`).

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
