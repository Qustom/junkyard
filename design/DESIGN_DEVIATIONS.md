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

*Current: **M1.10 Wave 5** (TG1) — 1 entry (test-fixture), rec Reviewed — awaiting Director disposition (non-blocking; TG2 is human-gated behind the playtest anyway).*
*Prior: **M1.10 Wave 4** (2026-07-05) — T4: 0 deviations — build complete (T0–T4); portal 3 for 1 bespoke line.*
*Prior: **Wave 3** T3: 0 dev (band 3 = 0 lines) · **Wave 2** T1: 0 dev · **Wave 1** T0: 3 Reviewed (archived), T2a/T2b: none.*
*Prior: **M1.9 Wave 5** (2026-07-03) — 1 entry (S8): 1 Reviewed — build phase S0–S9 fully swept.*
*Prior: **M1.9 Wave 4** (18: 13+5) · **Wave 3** (5: 4+1) · **Wave 2** (8: 7+1) · **Wave 1** (2: 1+1) ·
**M1.8** (17: 15+2, verdict `design/M1_8_Tasks/G4_findings_M1.8.md`) · M1.6/M1.5/M1.4 — all in `DESIGN_DEVIATIONS_HISTORY.md`.*

---

[2026-07-05] TG1/def-menu-coverage-test — `test_def_menu_coverage.gd` hard-coded the splitter IN-DECK
chip as `"IN DECK: band_two"` (an FBM19b-era expectation); T3's D-RAT-6 deck correctly added splitter to
band_three, so the chip now correctly reads `"band_three, band_two"`. TG1 updated the stale test
expectation to a per-id map (charger → band_two; splitter → band_three, band_two). · why: the PRODUCT
behavior is correct (the menu surfaces true deck membership); only the test's expectation was stale and
not updated in the T3 wave. Test-only change; no production `.gd`/`.tres` touched. · Rec: **Reviewed** —
test caught up to ratified product behavior; no design change.

---

*Current also: **M1.11 Wave 1** (2026-07-06) — U0: 4 entries below (all rec Reviewed), U2a/U2b: none.
Integrated on `main` (merges `bd24204`/`7cbe50f`/`4ff5c49` + CSV `fb3435d`); verify ALL GREEN.*

[2026-07-06] U0/entry-anchor — the scatter entry anchor's tie-break is **lane-aligned** (prefers the
clear-lane row) rather than the cave's pure min-y "west-most" rule. · why: U0 RD-2 (BINDING) ratified
lane-alignment so the spawn always sits on the guaranteed highway; the M1.10 amendment-2 wording
("west-most 2×2-open, min-y tie-break") predates the scatter lane concept. Flagged because the
breakdown's "entry anchor contract … Scatter inherits all three bars unchanged" reads stricter than
the RD. · Rec: **Reviewed** — RD-2 is the design; the breakdown's "unchanged" wording should be read
per-backend (reapply: one clarifying line in the breakdown anchor section at close-out).

[2026-07-06] U0/no-carve — the scatter backend ships **no carve fallback at all**; connectivity +
2×2 passability hold by construction (RD-6 proof). The breakdown's determinism guardrail says
"connectivity … by construction **or by deterministic CARVE**". · why: RD-6 (BINDING, adversarially
re-derived by the Phase-3 resolver) proved the carve arm dead code at every legal knob value; teeth
live in the pipeline ASSERT + S-suite. · Rec: **Reviewed** — the "or CARVE" clause is satisfied by
election of the first arm; no design change.

[2026-07-06] U0/S10-strong-form — `test_scatter_backend` S10 asserts the **strong** passability form
(EVERY floor cell ∈ the 2×2-open set) rather than the spec body's "cave-verbatim" weaker bar (in or
adjacent). · why: the RD-6 proof yields the strong form for free and U1's M6 asserts the same form —
matching bars end-to-end. Strictly tighter, never looser. · Rec: **Reviewed** — stronger assertion,
no design change.

[2026-07-06] U0/RD-16-test-comments — comment-only staleness edits to `test_band_pipeline_parity.gd`
(P7) + `test_cave_backend.gd` (C8) landed as their own commit (`d2a8a34`): the comments claimed
"scatter is not wired" while the assertions (which survive byte-identical in behavior) now exercise
the validate()-null path. · why: RD-16 authorized comment-only touch-ups in a separate commit;
assertion lines untouched, both suites re-run green pre/post. · Rec: **Reviewed** — comment hygiene
on T0-owned files; no design change.
