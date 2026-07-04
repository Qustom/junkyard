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

*Last close-out: **M1.9 Wave 4** (2026-07-03) — 18 entries: **13 Reviewed + 5 Addressed** (S9 deck wrapper ·
FU5 shared host · 23 gloss rows landed · catch_radius trap flag) — reapplied + archived to `DESIGN_DEVIATIONS_HISTORY.md`.*
*Prior: **M1.9 Wave 3** (5: 4+1) · **Wave 2** (8: 7+1) · **Wave 1** (2: 1+1) · **M1.8** (17: 15+2,
verdict record `design/M1_8_Tasks/G4_findings_M1.8.md`) · M1.6/M1.5/M1.4 — all in `DESIGN_DEVIATIONS_HISTORY.md`.*

---
