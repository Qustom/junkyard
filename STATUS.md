# STATUS — THE FAR YARD

**Resume point — read this first.** Where the orchestrator picks up after any interruption, with no other
context. Holds only *current* work: what's in progress (and how to continue it), what's blocked, the immediate
next action. Full task queue → `TASKS.md`; board mirror → GitHub Projects; completed tasks → `TASKS_COMPLETED.md`;
superseded status history → `STATUS_ARCHIVE.md`. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.0 → M1.1 (both built; M1.1 playtested → **ITERATE**) → **M1.2 (Legibility & Level Scale)** — **design LOCKED; Wave 1 ready to dispatch.**
**Last updated:** 2026-06-19 (M1.2 four-phase authoring complete + Director-dispositioned → design locked. Next: Wave 1 build. Breakdown: `design/M1_2_Tasks/M1.2_Breakdown.md`.)

---

## ▶ Next action (start here on a cold restart) — **M1.2 Wave 1: I1 ∥ BUG4 ∥ I5**

**M1.2 (Legibility & Level Scale)** is the iteration on M1.1's playtest (verdict ITERATE — the cost axis half-landed but
wasn't legible/fair: tiny levels, hazard never caught, R2/R3/R4 fired invisibly). The **four-phase authoring process**
(`CLAUDE.md`) ran end-to-end and the **design is LOCKED** (Phase 1 breakdown · Phase 2 six per-task design docs · Phase 3
fresh-eyes resolution · Director dispositioned all flagged items · Phase 4 wire-up = this update).

**Key Director verdicts (folded into the design docs, each ends with a "Director Disposition (FINAL)"):**
- **I1** = room-size multiplier **+** room-count knob **+ newly authored larger greybox pieces** (scope expanded; adds an `environment-artist` builder).
- **I2** hazard = **refuge** (walls block; shrink the body + anti-wall-stick steering — walls become a hiding place).
- **I3 / I4 / I5 / I2-polish** = all resolver defaults accepted (sweepable): occlusion ~0.94 via a radial world mask, fog cool-ghost, lost = edge-pulse + HUD word, optional penalty shake, `+dirty` build SHA, duration regression-lock.

**▶ Wave 1 — Spatial & data foundation (dispatch next; parallel `isolation: worktree`, file-disjoint):**
- **I1** (general-purpose + environment-artist) — `lvl_` `RunConfig` knobs (count + size mult) + generator threading + `junk_placer.gd` loot-scale fix + CFG/TEL pickup **+ new larger greybox pieces** (B1 sockets). Spec: `design/M1_2_Tasks/I1_level_scale.md`. **[touch: `run_config.gd`, `band_generator.gd`, `main_game.gd`, `junk_placer.gd`, new piece scenes]**
- **BUG4** (general-purpose) — geometry-keyed seal (cap every outward non-floor perimeter neighbour); fingerprint-safe. Spec: `BUG4_robust_seal.md`. **[touch: `socket_sealer.gd`]**
- **I5** (qa-playtest-coordinator) — `duration_s` CI regression-lock + bake real HEAD SHA (drop stale `config/build_sha`). Spec: `I5_telemetry_hygiene.md`. **[touch: `telemetry.gd`, `version.gd`, `project.godot`]**

**Wave 2** (after Wave 1 on `main`): **I2** hazard ∥ **I4** vision ∥ **I3** cues — ⚠ **watch the I2/I4 `main_game.gd` collision** (the W1.1-2 lesson: single-writer-per-`.gd`-file; if both edit the dive-scene wiring, sequence them). I3 is HUD-disjoint.
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
