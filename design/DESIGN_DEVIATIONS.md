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

*None. **M1.1 Wave 2 close-out complete (2026-06-19):** 1 deviation — **W2-R4-1** (residual BUG3 seal gap at aggressive
R4 branch rates) → **Addressed**: filed **BUG4** (`TASKS.md` + board), reapplied a safe-envelope note to
`R4_maze_navigation.md` §6, archived to `DESIGN_DEVIATIONS_HISTORY.md`. R1/R2/R3 reported "none." (M1.1 Wave 1 close-out
— W1.1-1 Reviewed, W1.1-2 Addressed — was completed + archived earlier.) This file is empty between waves.*

*Next: **Wave 3** — re-gate (RG1 build + wire R2/R3 nodes → human playtest → RG2 analysis → RG3 verdict). Any
deviations RG1 surfaces land here for a Wave 3 close-out.*
