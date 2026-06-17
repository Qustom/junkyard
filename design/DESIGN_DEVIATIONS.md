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

## ⏳ Pending Director evaluation — M1 waves 1 & 2

> Claude has attached a **recommended** disposition + reapply target to each. These are
> recommendations only — each needs the Director's explicit **Reviewed / Addressed** verdict before
> it is reapplied and archived. (Recommendations already drafted into `M1_As_Built.md` are marked
> "proposed" there pending these verdicts.)

| # | Deviation | Claude's recommendation |
|---|---|---|
| W1-1 | A1/B1/C1 greybox placeholders stubbed inline (no asset-role dispatch) — specs mandate flat greybox; live gen is human-gated | **Addressed** → `M1_As_Built.md` §Greybox asset norm |
| W1-2 | A1 extracted a pure `step_velocity()` helper for headless testability — behavior byte-identical | **Reviewed** (structural, no design change) |
| W1-3 | B1 fixed spec's `opposite()` sketch (didn't compile) + locked the collision-layer map (incl. `pawn`=6) | **Addressed** → `M1_As_Built.md` §Collision-layer map, §Procedural geometry |
| W1-4 | C1 `engine_block.slot_size = 6` (spec sketch showed 4) to sharpen the bulky-ceiling carry choice | **Addressed** → `M1_As_Built.md` §Tuning dials (revisit at economy workbook / G4) |
| W2-5 | A3 dive clock reuses `run_started`/`run_ended` — no new `dive_started`/`dive_ended` signals | **Addressed** → `M1_As_Built.md` §EventBus dive lifecycle contract |
| W2-6 | A3 greybox dive-clock meter built inline (no `ui-ux-designer` dispatch) | **Addressed** → `M1_As_Built.md` §Greybox asset norm |
| W2-7 | A3 tuning: `max_light=60`, fuel model via `modify_light`, transient per-dive clock | **Addressed** → `M1_Design_Decisions.md` #2 + `M1_As_Built.md` §Tuning dials |
| W2-8 | Open follow-up: `Item` vs `JunkItem` schema overlap | **Addressed** → resolved by Decision #1 (merge); task **C1b** |
| W2-9 | Open follow-up: parallel-dispatch `git switch` collisions in a shared checkout | **Addressed** → process rule in `CLAUDE.md` (worktree isolation + pre-lock signals) |
| W2-10 | B2 RNG API adaptation (`seed_from` + integer weighted pick; spec's `set_seed`/`weighted_pick`/`fork` don't exist) | **Addressed** → `M1_As_Built.md` §RNG |
| W2-11 | B2 flush-edge socket alignment (vs spec's raw seam formula) | **Addressed** → `M1_As_Built.md` §Procedural geometry |
| W2-12 | B2 connectivity = floor-cell adjacency (true walkability) | **Addressed** → `M1_As_Built.md` §Procedural geometry |
| W2-13 | B2 determinism test runs as a headless scene (autoloads don't resolve under `--script`) | **Addressed** → `M1_As_Built.md` §Testing constraints (revisit at G2) |
| W2-14 | D1 integrated with the REAL GameState (not the spec's `banked_money`/`cash_out` excerpt) | **Addressed** → `M1_As_Built.md` §GameState |
| W2-15 | D1 `max_slots` from authored `InventoryConfig.tres` (`base_max_slots=12`) | **Addressed** → `M1_As_Built.md` §Tuning dials |
| W2-16 | D1 `RunInventory` emits via SceneTree-resolved EventBus lookup (testability) | **Addressed** → `M1_As_Built.md` §Testing constraints (revisit at G2) |
| W2-17 | D1 added index-safe `remove_at(index)` alongside `remove(item)` | **Reviewed** (adopts the D1 spec's own recommendation) |

*Full original entries with rationale are preserved in git history (commit `c88f0c6` and earlier).*
