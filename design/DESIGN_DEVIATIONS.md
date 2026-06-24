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

*Last close-out: **M1.4 Wave 5** (2026-06-24, at the M1.5 re-gate) — 3 items: RG1-F1 (**Reviewed**), TUNE2
`_driven_default_preset()` (**Addressed** → new task M1.5 `L5`), stale `.tscn` UID drift (**Reviewed**/no action) —
all archived to `DESIGN_DEVIATIONS_HISTORY.md`.*
*Prior close-outs: **Wave 3** (1 Addressed), **Wave 2** (0), **Wave 1** (2 Reviewed + 1 Addressed) — all in `DESIGN_DEVIATIONS_HISTORY.md`.*

---

**[2026-06-24] L0-F1 — M1.5 final knob count is 89, not the breakdown's stated 88.**
*What vs. the doc:* the M1.5 Phase-4 lock states "current 81 + 8 new = final 88," but 81 + 8 = **89**. The as-built schema is verifiably 80 `@export var` + 9 `@export_enum` = 89 exported fields (was 72 var + 9 enum = 81 pre-L0). L0 declared exactly the locked knob SET (names/types/defaults) and all 4 signals — only the breakdown's *sum digit* was wrong.
*Why:* arithmetic slip in the orchestrator-authored breakdown lock; the knob list itself was correct. L0 set the knob-count tests to the load-bearing reality (89); `test_run_config` (R0 OK, 89) + `test_config_menu` (89/89) green; all-off fp unmoved (`e943ac9c8bc1`).
*Claude's recommendation:* **Reviewed** — a derived-count typo, not a design change. Docs (breakdown lock, TASKS.md, STATUS.md) already corrected to 89; nothing to reapply beyond that.
