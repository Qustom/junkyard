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
*Prior: **M1.12** (2026-07-11) — CLOSED: 5 deviations dispositioned (4 Reviewed + 1 Addressed via V4b), DR-3 signed off — all archived to `DESIGN_DEVIATIONS_HISTORY.md` §M1.12.*
*Prior: **M1.11 Wave 3** (2026-07-08) — U3: 1 Reviewed (archived 2026-07-08).*
*Prior: **M1.11 Wave 2** (2026-07-07) — U1: 3 Reviewed (archived 2026-07-08).*
*Prior: **M1.11 Wave 1** (2026-07-06) — U0: 4 Reviewed (archived 2026-07-07), U2a/U2b: none.*
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
