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

*Last close-out: **M1.4 Wave 2** (2026-06-21) — K2 (quota) + K7 (exits): **0 deviations** (both agents "none";
the as-built K0 API matched each design's reconciled contract — quota signals/knobs and exit knobs/signal all
pre-existed with the locked names). K7's DR-3/DR-4/DR-7 Director flags were already settled at the Phase-4 lock
(preset ships exits OFF). Nothing to disposition. This file is empty between waves.*
*Prior close-out: **M1.4 Wave 1** (2026-06-21) — 3 deviations: 2 Reviewed + 1 Addressed (camera enabled in preset),
archived to `DESIGN_DEVIATIONS_HISTORY.md`.*

---

*(empty — no un-assessed deviations)*
