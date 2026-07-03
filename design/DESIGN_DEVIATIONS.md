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

## M1.9 Wave 4 — active (awaiting Director disposition)

- **[2026-07-03] S7 / band_two deck ships 4 entries, not 6** — spec S7 §6 DoD item 4 says
  `opposition_deck.size() == 6`; in this file-disjoint worktree `charger.tres`/`splitter.tres`
  (S6a/S6b) do not exist, so `band_two.tres` ships the 4 shipped defs (`pursuer`/`pingpong`/`bomb`/
  `spike`) and the two band-2 predators are appended at the S8/SG1 merge integration (the exact
  two-line diff is recorded in the S7 worklog). **Why:** an ExtResource to a nonexistent file fails
  the whole resource load, breaking band_two's own contract test — degrading gracefully to 4 is the
  brief's "author rows that degrade gracefully in YOUR worktree + flag the integration check."
  **Claude's recommendation: Reviewed** — this is the anticipated parallel-merge state, not a design
  change; the deck completes to 6 (with the correct order `[pursuer, pingpong, bomb, spike, charger,
  splitter]` and `min_band=2` gating on the two predators) at S8/SG1. No design edit needed.

- **[2026-07-03] S7 / tint-only visual identity, no retoned tileset** — spec S7 §4 offered a Tier-2
  retoned `greybox_band_two.tres` tileset + a `tileset` BandProfile field; per **D-RAT-4** (art
  budget = tint-only, no PixelLab, `tileset` field deferred), `band_two.tres` ships only
  `palette_tint = Color(0.82, 0.66, 0.42, 1)` (sepia-amber Sump) and no tileset file/field.
  **Claude's recommendation: Reviewed** — this is the Director's ratified call (D-RAT-4), recorded
  here only for the wave-4 audit trail; the design already matches (no reapply needed).

---

*Last close-out: **M1.9 Wave 2** (2026-07-03) — 8 entries (S2×4 + S5×4): **7 Reviewed + 1 Addressed**
(run-clock seam → typed injected Callable, fixed at close-out) — reapplied + archived to `DESIGN_DEVIATIONS_HISTORY.md`.*
*Prior: **M1.9 Wave 1** (2026-07-02) — 2 entries: 1 Reviewed + 1 Addressed. **M1.8** (2026-07-02) — 17 entries:
15 Reviewed + 2 Addressed (verdict record `design/M1_8_Tasks/G4_findings_M1.8.md`).*
*Prior close-outs: M1.6 Wave 2 (3 Reviewed), M1.5 (2), M1.4 Wave 5 (3), Wave 3 (1 Addressed), Wave 1 (2+1) — all in
`DESIGN_DEVIATIONS_HISTORY.md`.*

---

*Last close-out: **M1.9 Wave 3** (2026-07-03) — 5 entries (S3): **4 Reviewed + 1 Addressed**
(param_overrides stamp → flat dotted rows, fixed at close-out) — reapplied + archived to `DESIGN_DEVIATIONS_HISTORY.md`.*
*Prior: **M1.9 Wave 2** (2026-07-03) — 8 entries: 7 Reviewed + 1 Addressed. **Wave 1** (2026-07-02) — 2 entries.
**M1.8** (2026-07-02) — 17 entries: 15 Reviewed + 2 Addressed (`design/M1_8_Tasks/G4_findings_M1.8.md`).*
*Prior close-outs: M1.6 Wave 2 (3), M1.5 (2), M1.4 (2+1+3) — all in `DESIGN_DEVIATIONS_HISTORY.md`.*

---
