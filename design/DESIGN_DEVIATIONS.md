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

*Last close-out: **M1.9 Wave 5** (2026-07-03) — 1 entry (S8): **1 Reviewed** — build phase S0–S9 fully swept.*
*Prior: **Wave 4** (18: 13+5 — S9 deck wrapper · FU5 shared host · 23 gloss rows · catch_radius trap flag).*
*Prior: **M1.9 Wave 3** (5: 4+1) · **Wave 2** (8: 7+1) · **Wave 1** (2: 1+1) · **M1.8** (17: 15+2,
verdict record `design/M1_8_Tasks/G4_findings_M1.8.md`) · M1.6/M1.5/M1.4 — all in `DESIGN_DEVIATIONS_HISTORY.md`.*

---
[2026-07-05] T0/cave-backend — grid-level carve reads the breakdown's "existing CARVE mode" as a
deterministic *mirror*, not literal reuse. The `ConnectivityGuarantee` CARVE mode is a journal-LIFO
revert of a flavor stage's writes — structurally inapplicable inside a backend with no prior state.
T0 mirrors the carve concept (zero-RNG, sorted-order grid carve) and reuses the stage's real checker
(`is_fully_connected` via `Mode.ASSERT`) as the pipeline invariant. · why: the literal mode cannot
apply; the breakdown's operative intent ("deterministic, never retry-loops on the global stream") is
met. · Rec: **Reviewed** — Phase-3 Q4 already ratified this reading; no design change.

[2026-07-05] T0/cave-backend — `cave_backend.gd` is ~404 code-only lines vs the spec §6 ~255
estimate. · why: the Q8 2×2-open player-scale guarantee is heavier than its ~35-line estimate (needs
T-component detection + connector carving + orphan-widening to satisfy the test-asserted C10 "every
floor cell is member-of-or-adjacent-to-T"), plus `_pick_deepest_piece` (~30 lines, see next entry)
and verbose typed locals. Downstream reuse is still 0 new lines — the scalability headline holds. ·
Rec: **Reviewed** — magnitude note for the cost ledger, not a design change.

[2026-07-05] T0/cave-backend — `deepest_piece` chosen by a chunk-graph BFS (replicating
DepthGrader's adjacency+BFS) rather than spec §3.5's cell-BFS-farthest-cell's-owning-chunk. · why:
§3.5 asks the C4 test to assert `deepest_piece.depth_index == band.max_depth` while admitting
cell/chunk agreement "is not required" — a contradiction; picking the piece at max chunk-hop depth
makes the equality hold by construction (my BFS matches the grader's exactly). Backend-local, within
file scope, ~30 lines. · Rec: **Reviewed** — keep; it makes the spec's own acceptance bar valid.
