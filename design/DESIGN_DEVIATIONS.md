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

## ⏳ Pending Director evaluation — M1.1 Wave 1 close-out (2 entries)

All six wave-1 task agents (R0, BUG1, BUG2, TEL, BUG3, CFG) reported **"none"** against their specs — the
implementations matched the ratified designs. The two entries below are **orchestrator-level departures from the
M1.1 plan docs** (the breakdown's wave structure and TEL's signal-ownership decision), surfaced for the Director.

`[date] <id/area> — what changed vs. the doc · why · Claude's recommendation`

- **[2026-06-19] W1.1-1 / `depth_changed` declaration ownership (TEL spec §8 Decision 3).** The TEL spec ratified
  that **TEL** declares `signal depth_changed` in its single wave-1 `event_bus.gd` edit, with BUG2 only emitting it.
  In practice the **orchestrator pre-declared** `depth_changed` on `main` (commit `2450cde`) **before** TEL ran,
  because the combined BUG1+BUG2 `game_state.gd` pass (which *emits* it) was sequenced ahead of TEL and needed the
  signal to exist to compile. · *Why:* BUG2 §3's own sequencing rule ("the declaration must exist on `main` before
  any emitter ships") forced the declaration earlier than TEL's task; orchestrator pre-declaration of shared signals
  is the standing M1 process. Outcome is **functionally identical** to the decision's intent — exactly one declaration
  of the line, exactly one author of `event_bus.gd`'s `depth_changed` (the orchestrator instead of TEL), zero parallel
  collision; TEL correctly skipped re-declaring it (verified: `grep -c "^signal depth_changed"` == 1). · **Claude's
  recommendation: Reviewed** — the ratified *intent* (one declaration, no collision) holds; only the declaring actor
  moved, which is immaterial and already documented in the `event_bus.gd` comment + STATUS. No design change needed
  beyond a one-line note in the TEL spec / `M1_As_Built.md` that the orchestrator owns pre-declared foundation signals.

- **[2026-06-19] W1.1-2 / Wave-1 fan-out was NOT fully parallel — CFG + BUG3 share `main_game.gd`.** `M1.1_Breakdown.md`
  §6 states the rest of wave 1 (CFG, TEL, BUG3) "then run in parallel (CFG = `main_game.tscn` + new UI scene; TEL =
  `telemetry/` + `event_bus.gd`; BUG3 = generator/zone-piece geometry — disjoint files)". In fact **both CFG and BUG3
  edit `scenes/game/main_game.gd`** (CFG = the `stage_run_config` seam in `start_new_run`; BUG3 = the
  `seal_unused_sockets` call in `_materialise_band`) — the breakdown's file list omitted CFG's `main_game.gd` seam and
  mislabeled CFG as touching only `main_game.tscn`. · *Why:* the breakdown's disjointness claim was inaccurate; running
  CFG and BUG3 in parallel worktrees would have produced a `main_game.gd` merge conflict. The orchestrator ran
  **TEL + BUG3 in parallel** (genuinely disjoint), then **CFG sequentially after BUG3** — both `main_game.gd` edits are
  small and in different functions, and all three landed green. · **Claude's recommendation: Addressed (doc-only)** —
  correct `M1.1_Breakdown.md` §6 to note CFG also edits `main_game.gd:start_new_run`, so this milestone's wave-1
  parallelism is "TEL ∥ BUG3, then CFG" (and the same single-writer-per-`.gd`-file rule that governs `event_bus.gd`
  applies to `main_game.gd`). No code change — the as-built execution was correct; only the plan doc needs the fix.

*(After disposition: reapply per the verdict, then archive both to `DESIGN_DEVIATIONS_HISTORY.md`. The remaining
pre-Wave-2 gate is this sweep — Wave 2 (R1–R4 parallel) does not dispatch until the Director dispositions these.)*
