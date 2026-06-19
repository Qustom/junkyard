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

## ⏳ Pending Director evaluation — M1.1 Wave 2 (accumulating; close-out after R1 lands)

`[date] <id/area> — what changed vs. the doc · why · Claude's recommendation`

- **[2026-06-19] W2-R4-1 / BUG3 seal gap surfaces at aggressive R4 branch rates.** R4's deeper branching exercises
  the map far harder than the M1.0 spine, and exactly as R4 §6 predicted, it surfaced a **residual BUG3 gap**: at
  `r4_branch_per_depth ≳ 0.12`, some seeds leave **2–6 floor cells facing off-map void even after `SocketSealer`** — a
  branchy socket-opening edge that isn't in `band.open_sockets` (so the wave-1 sealer, which caps only the retained
  unmated frontier, never sees it). · *Why it's bounded:* the Director's **recommended presets seal cleanly** — S1
  (`branch_per_depth=0.06`, cap 8) and S3 (`0.05`, cap 8) produce **0 leaks across all 9 sweep seeds**; the determinism
  test pins an S1-class curve, so R4's realistic playtest envelope is shippable. The gap only appears past ~2× the
  recommended branch rate. R4 did **not** fix it (BUG3/`socket_sealer.gd` is another task's file) and flagged it here. ·
  **Claude's recommendation: Addressed — file a small BUG3 follow-up task** (cap *all* outward-facing perimeter floor
  edges, not just `open_sockets`, so the seal is branch-rate-independent) **and** optionally a CFG soft-cap note on
  `r4_branch_per_depth`. Low urgency (recommended presets are clean), but it should be a tracked task before any
  high-branch-rate playtest sweep. *(Provenance: `worklogs/2026-06-19-R4-general-purpose.md` deviation #4.)*

*(R2, R3 reported "none." R1 (batch B) may add entries. Disposition the full set at the Wave 2 close-out once R1 lands.)*

---

## (archived-pending-move) M1.1 Wave 1 close-out

*Done. **M1.1 Wave 1 close-out (2026-06-19):** the 2 orchestrator-level deviations (W1.1-1
`depth_changed` pre-declaration ownership → **Reviewed**; W1.1-2 CFG/BUG3 both edit `main_game.gd` → **Addressed**,
breakdown §6 corrected) were dispositioned by the Director and archived to `DESIGN_DEVIATIONS_HISTORY.md`. All six
wave-1 task agents reported "none" against their specs. This file is empty between waves.*

*Next: **Wave 2** — the four oppositions (R1–R4) in parallel worktrees. Any deviations they surface land here for
the Wave 2 close-out.*
