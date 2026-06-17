# Design Deviations — History (archive)

Resolved design deviations, moved here from `DESIGN_DEVIATIONS.md` during each wave's close-out
assessment (`CLAUDE.md` → "Wave close-out — deviation assessment"). An entry only lands here **after
the Director has dispositioned it** — Claude assembles and recommends, the Director evaluates. Each
entry is tagged with the Director's verdict:

- **Reviewed** — fine as-is; the design needed no change.
- **Addressed** — the design was changed; the "Reapplied to" note says where the now-canonical
  reality was folded back into the design (or names the new task that was planned).

Append-only. Newest wave at the bottom.

---

## M1 waves 1 & 2 — Director-evaluated 2026-06-17

Every entry below was dispositioned by the Director and reapplied to the design. The two recurring
themes — the specs' **idealized API sketches** and the **headless-test autoload constraint** — are
now canonical in `design/M1_Tasks/M1_As_Built.md` (which supersedes the spec sketches on conflict).
No deviation was a revert; all `Addressed` items were reapplied. The Group-B tuning values
(`engine_block.slot_size=6`, `max_light=60`, `base_max_slots=12`) were accepted as playtest dials
(not reverted), to be retuned at the G4 fun gate / economy workbook.

| # | Deviation | Verdict | Reapplied to |
|---|---|---|---|
| W1-1 | A1/B1/C1 greybox placeholders stubbed inline (no asset-role dispatch) | **Addressed** | `M1_As_Built.md` §Greybox asset norm |
| W1-2 | A1 extracted a pure `step_velocity()` helper for headless testability | **Reviewed** | — (structural; behavior byte-identical) |
| W1-3 | B1 fixed spec's `opposite()` sketch + locked collision-layer map (incl. `pawn`=6) | **Addressed** | `M1_As_Built.md` §Collision-layer map, §Procedural geometry |
| W1-4 | C1 `engine_block.slot_size = 6` (spec sketch showed 4) | **Addressed** | `M1_As_Built.md` §Tuning dials (kept as dial; revisit economy workbook / G4) |
| W2-5 | A3 dive clock reuses `run_started`/`run_ended` — no new `dive_started`/`dive_ended` | **Addressed** | `M1_As_Built.md` §EventBus dive lifecycle contract |
| W2-6 | A3 greybox dive-clock meter built inline (no `ui-ux-designer` dispatch) | **Addressed** | `M1_As_Built.md` §Greybox asset norm |
| W2-7 | A3 tuning: `max_light=60`, fuel model via `modify_light`, transient per-dive clock | **Addressed** | `M1_Design_Decisions.md` #2 + `M1_As_Built.md` §Tuning dials |
| W2-8 | Open follow-up: `Item` vs `JunkItem` schema overlap | **Addressed** | Decision #1 (merge); planned as task **C1b** (in progress) |
| W2-9 | Open follow-up: parallel-dispatch `git switch` collisions in a shared checkout | **Addressed** | Process rule in `CLAUDE.md` (worktree isolation + pre-lock signals) |
| W2-10 | B2 RNG API adaptation (`seed_from` + integer weighted pick; spec's `set_seed`/`weighted_pick`/`fork` don't exist) | **Addressed** | `M1_As_Built.md` §RNG |
| W2-11 | B2 flush-edge socket alignment (vs spec's raw seam formula) | **Addressed** | `M1_As_Built.md` §Procedural geometry |
| W2-12 | B2 connectivity = floor-cell adjacency (true walkability) | **Addressed** | `M1_As_Built.md` §Procedural geometry |
| W2-13 | B2 determinism test runs as a headless scene (autoloads don't resolve under `--script`) | **Addressed** | `M1_As_Built.md` §Testing constraints (revisit at G2) |
| W2-14 | D1 integrated with the REAL GameState (not the spec's `banked_money`/`cash_out` excerpt) | **Addressed** | `M1_As_Built.md` §GameState |
| W2-15 | D1 `max_slots` from authored `InventoryConfig.tres` (`base_max_slots=12`) | **Addressed** | `M1_As_Built.md` §Tuning dials (kept as dial) |
| W2-16 | D1 `RunInventory` emits via SceneTree-resolved EventBus lookup (testability) | **Addressed** | `M1_As_Built.md` §Testing constraints (revisit at G2) |
| W2-17 | D1 added index-safe `remove_at(index)` alongside `remove(item)` | **Reviewed** | — (adopts the D1 spec's own recommendation) |

**New tasks from this assessment:** none beyond existing — W2-8 → **C1b** (on the board, in progress); W2-9 → standing worktree process rule; W2-13/16 "revisit" already scoped under **G2** (vendor GdUnit4).
