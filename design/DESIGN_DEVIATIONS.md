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

*Last close-out: **M1.10 Wave 2** (2026-07-05) — **T1: 0 deviations** — clean wave, no Director gate.*
*Prior: **M1.10 Wave 1** (2026-07-05) — 3 entries (T0): 3 Reviewed — archived to `DESIGN_DEVIATIONS_HISTORY.md`. T2a/T2b: none.*
*Prior: **M1.9 Wave 5** (2026-07-03) — 1 entry (S8): 1 Reviewed — build phase S0–S9 fully swept.*
*Prior: **M1.9 Wave 4** (18: 13+5) · **Wave 3** (5: 4+1) · **Wave 2** (8: 7+1) · **Wave 1** (2: 1+1) ·
**M1.8** (17: 15+2, verdict `design/M1_8_Tasks/G4_findings_M1.8.md`) · M1.6/M1.5/M1.4 — all in `DESIGN_DEVIATIONS_HISTORY.md`.*

---

*(empty — M1.10 Wave 1 fully swept; next entries land at the Wave-2 (T1) close-out.)*
