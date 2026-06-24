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

**[2026-06-24] L1-F1 — throw telemetry `run_t_ms` uses `Time.get_ticks_msec()`, not a run-elapsed base.**
*What vs. the doc:* the L0/L1 contract declares the throw signals with a `run_t_ms: int` field. `GameState` exposes no public run-elapsed accessor (`_elapsed_s()` is private) and `game_state.gd` was outside L1's single-writer touch set, so L1 stamped `item_thrown`/`throw_missed`/`throw_killed_hazard` with the monotonic `Time.get_ticks_msec()` (shared between `main_game` and the projectile) instead of true run-elapsed ms.
*Why:* avoids widening L1's file scope mid-wave; RG2's use of these rows is in-run ordering, which a monotonic clock preserves. All-off fp unmoved; tests green.
*Claude's recommendation:* **Reviewed** — low-risk telemetry detail, no contract/arity change. If a true run-elapsed base is wanted, file a small follow-up to expose `GameState.run_elapsed_ms()` and switch the three stamps.
