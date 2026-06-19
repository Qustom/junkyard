# Design Deviations Log (active working set)

Append-only record of every place the build departed from `Junkyard_GDD.md`,
`Junkyard_Technical_Design.md`, the role playbooks, or the documented setup — with rationale.
The orchestrator and each dispatched subagent append here whenever a task departs from spec.

**Lifecycle (`CLAUDE.md` → "Wave close-out — deviation assessment"):** this file holds
deviations **awaiting the Director's evaluation**. After each wave, the Director dispositions every
entry **Reviewed** or **Addressed** (Claude only recommends — it never self-dispositions). Per the
verdict, Claude reapplies to the design (usually `design/M1_Tasks/M1_As_Built.md` or
`M1_Design_Decisions.md`), then **moves the entry to `DESIGN_DEVIATIONS_HISTORY.md`**. Between
fully-evaluated waves this file is ideally empty.

Format: `[date] <id/area> — what changed vs. the doc · why · Claude's recommendation`

---

## ⏳ Pending Director evaluation

*None. **M1.1 Wave 1 close-out is complete (2026-06-19):** the 2 orchestrator-level deviations (W1.1-1
`depth_changed` pre-declaration ownership → **Reviewed**; W1.1-2 CFG/BUG3 both edit `main_game.gd` → **Addressed**,
breakdown §6 corrected) were dispositioned by the Director and archived to `DESIGN_DEVIATIONS_HISTORY.md`. All six
wave-1 task agents reported "none" against their specs. This file is empty between waves.*

*Next: **Wave 2** — the four oppositions (R1–R4) in parallel worktrees. Any deviations they surface land here for
the Wave 2 close-out.*
