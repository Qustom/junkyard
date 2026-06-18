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

---

## M1 wave 3 (C1b, E1, D2, B3, C2) — Director-evaluated 2026-06-17

Every entry below was dispositioned by the Director on 2026-06-17 (Claude assembled + recommended; the
Director ruled). **21 Reviewed, 3 Addressed.** The recurring themes are unchanged from waves 1 & 2:
the specs' **idealized API sketches** (now `JunkItem`/`base_sell_value`, real `RNG` surface) and the
**headless-test autoload constraint** (tests run as `.tscn`) — both already canonical in
`M1_As_Built.md`. The new structural fact is the **B3↔C2 seam** (B3 plans, C2 spawns), also folded in.
No Reviewed item was a revert; all 3 Addressed items were reapplied (one as a build change, two as new tasks).

| # | Deviation | Verdict | Reapplied to |
|---|---|---|---|
| W3-1 | C1b folded `Item`'s useful fields into `JunkItem`; retired `Item` | **Reviewed** | `M1_As_Built.md` §Junk schema (executes ratified decision #1) |
| W3-2 | C1b deleted `sample_junk.tres` (not converted) | **Reviewed** | — (curated catalog is the real content) |
| W3-3 | C1b repointed the smoke test's load-as-data step to a real catalog `JunkItem` | **Reviewed** | — (CI guarantee preserved) |
| W3-4 | E1 reused `run_ended`+`haul_banked` instead of a new `run_end(cause,payload)` | **Reviewed** | `M1_As_Built.md` §EventBus / §GameState (tracks decision #6) |
| W3-5 | E1 `banked_junk` persists as ids, rehydrated from catalog (objects-OFF save) | **Reviewed** | `M1_As_Built.md` §Save schema |
| W3-6 | E1 real signature `save_meta(slot)`; `extract_and_end_run()` hardcodes slot 0 | **Reviewed** | `M1_As_Built.md` §GameState (slot-routing is a later follow-up) |
| W3-7 | E1 meta schema bump 1→2 with no QA migration fixture yet | **Addressed** | New task **G5** (v1→v2 meta save-migration fixture) + `M1_As_Built.md` §Save schema |
| W3-8 | D2 panel also listens to `run_started`/`run_ended` (start builds / end clears the bag) | **Reviewed** | — (still pure-projection / EventBus-only) |
| W3-9 | D2 drop gesture is right-click only (spec allowed right-click or hold-to-drop) | **Reviewed** | — (deliberate gesture; hold-to-drop deferrable) |
| W3-10 | D2 cell rebuild uses `queue_free()`+hide vs synchronous `free()` | **Reviewed** | — (engine-correctness; rebuild can fire from a cell's own signal) |
| W3-11 | D2 added a "No active dive" idle state for `run_inventory == null` | **Reviewed** | — (additive; needed for an always-on HUD) |
| W3-12 | D2 authored no `theme.tres` (spec marked it optional) | **Reviewed** | — (per-cell overrides sufficed; deferred to human visual pass) |
| W3-13 | D2 committed generated `inventory_strings.en.translation` (binary build product) | **Addressed** | Gitignored `*.translation` + untracked the file; regenerated from `.csv` on import (verified). `.gitignore` updated |
| W3-14 | B3 used a local `RandomNumberGenerator` sub-stream (no `RNG.fork`); autoload RNG untouched | **Reviewed** | `M1_As_Built.md` §RNG (deterministic sub-streams — canonical pattern) |
| W3-15 | B3 consumed `JunkItem`/`base_sell_value` from catalog (no `junk_pool.tres`) | **Reviewed** | `M1_As_Built.md` §Junk schema |
| W3-16 | B3 produces a placement *plan* + debug overlay only; added only `junk_spawned` | **Reviewed** | `M1_As_Built.md` §B3↔C2 seam |
| W3-17 | B3 acceptance test runs as `.tscn` (needs autoloads) | **Reviewed** | `M1_As_Built.md` §Testing constraints (revisit at G2) |
| W3-18 | B3 real reverse-BFS return distance; curves near-linear value / stepped tier / flat density | **Reviewed** | `M1_As_Built.md` §Junk schema (depth axis) |
| W3-19 | C2 `JunkSpawner` is a pure consumer of B3's plan (no own weighting / no `RNG.stream`) | **Reviewed** | `M1_As_Built.md` §B3↔C2 seam |
| W3-20 | C2 spawner invoked directly after generation, not via a signal | **Reviewed** | — (per spec recommendation: hard ordering + data dependency) |
| W3-21 | C2 `junk_picked_up(...,slot_size,...)` + `band_populated` + `junk_dropped` signals | **Reviewed** | `M1_As_Built.md` §EventBus (Telemetry watch-list confirm = G1 scope) |
| W3-22 | C2 `base_sell_value` + reject UX keyed off the same `can_accept()`/`is_full()` D2 reads | **Reviewed** | `M1_As_Built.md` §B3↔C2 seam |
| W3-23 | C2 acceptance test runs as `.tscn` (needs autoloads) | **Reviewed** | `M1_As_Built.md` §Testing constraints (revisit at G2) |
| W3-24 | C2 drop-to-swap re-spawn wired on spawner side but dormant until D2 emits `junk_dropped` | **Addressed** | New task **D3** (D2 emits `junk_dropped` to activate it) |

**New tasks from this assessment:** **G5** (W3-7, meta save-migration fixture) and **D3** (W3-24, activate
drop-to-swap re-spawn) — both added to `TASKS.md` and the GitHub Projects board (Todo). W3-13 was actioned
directly (translation gitignored). W3-6 slot-routing and W3-21 Telemetry watch-list fold into later tasks
(save/slot layer; **G1**).
