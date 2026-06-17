# Design Deviations Log (active working set)

Append-only record of every place the build departed from `Junkyard_GDD.md`,
`Junkyard_Technical_Design.md`, the role playbooks, or the documented setup — with rationale.
The orchestrator and each dispatched subagent append here whenever a task departs from spec.

**Lifecycle (`CLAUDE.md` → "Wave close-out — deviation assessment"):** this file holds only
**un-assessed** deviations from the current (or a not-yet-closed) wave. After each wave lands and is
verified, every entry here is dispositioned **Reviewed** or **Addressed**, reapplied to the design
(usually `design/M1_Tasks/M1_As_Built.md` or `M1_Design_Decisions.md`), then **moved to
`DESIGN_DEVIATIONS_HISTORY.md`**. Between waves this file is ideally empty.

Format: `[date] <id/area> — what changed vs. the doc · why · sign-off?`

---

## Open (un-assessed) deviations

*None. M1 waves 1 & 2 assessed and archived to `DESIGN_DEVIATIONS_HISTORY.md` on 2026-06-17.*

*Wave 3 (C1b, D2, E1, …) deviations land here as those tasks integrate, then get assessed at the wave-3 close-out.*
