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

*None. M1 waves 1 & 2, wave 3, wave 4, and **wave 5** (G1, G2, G3, G6 — 16 deviations, Director-evaluated 2026-06-18: 1 Addressed / 15 Reviewed) have all been dispositioned and moved to `DESIGN_DEVIATIONS_HISTORY.md`. This file is empty between waves.*

*The only remaining M1 task is **G4** (the human internal-playtest fun-gate); any deviations it surfaces land here for a G4 close-out.*
