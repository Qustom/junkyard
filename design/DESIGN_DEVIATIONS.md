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

*Last close-out: **M1.2 Wave 1** (2026-06-19) — 4 deviations, all Reviewed, archived to
`DESIGN_DEVIATIONS_HISTORY.md`.*

---

`[2026-06-19] J2 (M1.3 Wave 2) — curve distribution mode is shallow-biased, not "deeper-biased"` —
The locked J2 spec §B.2 + Director Disposition call mode 2 `curve` "deeper-biased `pow(t,1.6)`"
(spec comment: `# >1 → clusters deep`), but `pow(t, 1.6)` for `t ∈ [0,1]` returns values `<= t`,
so it maps intermediate hazards SHALLOWER and the density actually thins toward the deep end
(opposite of the stated intent). · **Why I shipped it anyway:** the formula is the *locked* spec
pseudocode, and `curve` is **built but preset-OFF** (the booted preset uses `even_spread`), so this
changes no booted/measured experience this gate; building to the literal spec keeps the lock honest
and the deviation visible. · **Recommendation (needs Director review — fun/feel + a 1-line spec-text
fix):** leave the formula as-specced for the M1.3 gate; if/when `curve` is swept on at RG2, flip the
direction — use `pow(t, e<1)` (e.g. `0.6`) or `1 - pow(1 - t, e)` to actually cluster deep — and
correct the spec comment. The `test_hazard_spread.gd` (c) assertion is locked to the real
`pow(t,1.6) <= even` behaviour so the build won't silently drift.
