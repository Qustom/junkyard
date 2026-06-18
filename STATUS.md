# STATUS — THE FAR YARD

**Resume point — read this first.** This is where the orchestrator picks up after any interruption,
with no other context. It holds only *current* work: what's in progress (and how to continue it),
what's blocked, and the immediate next action. The full task queue lives in `TASKS.md`; the board
mirror lives in GitHub Projects. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M0 ✅ complete → **M1 (Greybox Core Loop)**, in progress.
**Last updated:** 2026-06-17 (wave 4a integrated; 16/16 M1 tasks done)

---

## ▶ Next action (start here on a cold restart) — **dispatch WAVE 4b: F1 → F2**
Wave 4a (E2, E3, D3, G5) is integrated + green on `main` (`0d6c484`). **16/19 M1 tasks done.**
Remaining: **F1** (Money sell) → **F2** (sell screen) → **G1** (telemetry, needs E3✅) →
**G2** (logic tests, needs E3✅+F1) → **G3** (build) → **G4** (fun gate).

**Dispatch F1 next** (general-purpose, worktree). Key brief notes from the as-built read:
- `GameState.money` **already exists and already persists** (schema is already v2) — so F1 needs **no schema bump**; it's smaller than its spec. The real new work is **`sell_banked_junk()`** (converts `banked_junk` → Money at `base_sell_value`, clears the bank, `save_meta(0)`, returns a per-item breakdown for F2) + **reuse the existing `add_currency(&"money", amt, source)`** (which already emits `currency_changed`) instead of adding a parallel `credit_money`/`money_changed`.
- F1 **writes `game_state.gd`** — it branches off this main which already has E3's changes, so no conflict. Solo dispatch (no other agent touches game_state.gd in 4b until F2, which is UI-only).
- Then **F2** (ui-ux-designer): post-extract sell screen consuming `sell_banked_junk()`'s breakdown; per E3+F1 recs, route **failed runs through the same screen** ("RUN LOST — kept N"). Needs F1 + D2 (✅).

**Wave-4 close-out (after F1/F2 land):** Director must disposition the wave-4a deviations now in
`design/DESIGN_DEVIATIONS.md` — the one real call is **E3 pockets `0.15` value-fraction-to-Money →
`0.20` whole-item-to-bank** (Claude recommends Addressed + update GDD §6); the rest are reconciliations
or close already-Addressed wave-3 items (D3 closes `C2/dropwiring`, G5 closes `E1/schema`).

---

## (archived) ▶ prior next-action
**M1 wave 3a done & integrated into `main` (`061c6aa`)** — C1b, D2, E1 merged + verified green (10/19
total: A1, B1, C1, A2, A3, B2, D1, C1b, E1, D2). Wave-3a deviations recorded in
`design/DESIGN_DEVIATIONS.md` **awaiting Director evaluation at the wave-3 close-out** (after 3b).

**Wave 3 COMPLETE + close-out DONE** — C1b, E1, D2, B3, C2 merged + verified (12/19 M1 tasks).
Director dispositioned all 24 wave-3 deviations on 2026-06-17 (**21 Reviewed, 3 Addressed**); reapplied
to `M1_As_Built.md` + archived to `DESIGN_DEVIATIONS_HISTORY.md`. The 3 Addressed: translation
gitignored (done); **G5** (meta save-migration fixture) + **D3** (activate drop-to-swap) added to
`TASKS.md` + board. `DESIGN_DEVIATIONS.md` is now empty (between-waves).

**NEXT ACTION: dispatch wave 4.** Candidates (check `Junkyard_M1_Breakdown.md` §4 for the exact order):**
- **E2** — death/timeout end-run + haul loss (needs E1 ✅, B3 ✅, D2 ✅, A3 ✅)
- **E3** — respawn/return-to-surface (needs E1 ✅, A3 ✅)
- **F1** — surface scene + sell screen / `banked_junk`→Money (needs E1 ✅) → **F2** sell UI (F1, D2 ✅)
- Two recommended new tasks surfaced by wave-3 deviations (pending Director): a **v1→v2 meta save-migration QA fixture** (E1/schema), and a **D2 `junk_dropped` emit** to activate drop-to-swap re-spawn (C2/dropwiring).
- Dep map: `design/M1_Tasks/Junkyard_M1_Breakdown.md` §4.

Then-unblocked (wave 4+): **E2** (E1,B3,D2,A3), **E3** (E1,A3), **F1** (E1) → **F2** (F1,D2) →
**G1/G2** → **G3** build → **G4** the fun gate. Dep map: `design/M1_Tasks/Junkyard_M1_Breakdown.md` §4.

> **PROCESS (locked):** parallel agents run with **`isolation: worktree`**; pre-declare any shared
> EventBus signals on `main` before dispatch so no two agents edit `event_bus.gd`; push `main` after every
> commit; mirror task status to GitHub Projects. All proven in wave 2. See `CLAUDE.md` orchestrator loop.

## In progress — nothing dispatched (wave 4a integrated; ready to dispatch wave 4b = F1→F2)
No subagent running. Wave 4a (E2, E3, D3, G5) merged to `main` (`0d6c484`) and re-verified — full
16-check suite green. Next: dispatch **F1** (see ▶ Next action above), then **F2**.

## Blocked
| Task | Blocked by | Note |
|---|---|---|
| ElevenLabs/PixelLab live generation | human | Connected; calling them spends paid credits — get human OK before a generation run. |

> **M1 design decisions resolved by the human Director (2026-06-15)** — recorded in
> `design/M1_Tasks/M1_Design_Decisions.md`. Both prior human-judgment items are now decided:
> `Item`→`JunkItem` **merge** (became the schema task below); `max_light = 60` confirmed.

## Done (M1 — Greybox Core Loop)
| Task | Proof |
|---|---|
| A1 — Player scene + top-down movement | merged `a6503fc`; `test_player_movement.gd` → **MOVE OK** (cardinal=diagonal=91.7px); worklog `worklogs/2026-06-15-A1-programmer.md` (impl `a0a485d`) |
| B1 — Zone-piece authoring format (6 pieces) | merged `2e46681`; `tools/zone_piece_check.gd` → **ZONE PIECES OK** (6 load, sockets tagged, walkable); worklog `worklogs/2026-06-15-B1-programmer.md` (impl `81057c3`) |
| C1 — `JunkItem` resource + 8-item catalog | integrated `24280f8`; `tools/check_junk_catalog.gd` → **JUNK CATALOG OK** (40× value spread); worklog `worklogs/2026-06-15-C1-game-director-designer.md` (impl `e32e286`) |
| A2 — Interaction component | merged `5f9bbc3`; `tests/test_interaction.gd` → **INTERACT OK** (focus/nearest, `interaction_requested`, hysteresis, enabled-guard); worklog `worklogs/2026-06-15-A2-general-purpose.md` (impl `b8f60e3`) |
| A3 — In-dive clock + greybox meter | merged `744d6f5`; `tests/test_dive_clock.gd` → **DIVE CLOCK OK** (drains to 0, `dive_clock_timeout` once, run_ended stops, modify_light clamps); worklog `worklogs/2026-06-15-A3-general-purpose.md` (impl `55088e5`) |
| B2 — Seeded room-graph generator | merged `869274b`; `tests/test_bandgen_determinism.tscn` → **BANDGEN OK** (9 seeds: same→identical fp, diff→differ, connected/walkable); worklog `worklogs/2026-06-15-B2-general-purpose.md` (impl `c060d6b`) |
| D1 — Run-state slot inventory model | merged `b9a50f7`; `tests/test_run_inventory.gd` → **INV OK** (capacity reject, full blocks, pure can_accept, PLACEABLE gate, run-state-only); worklog `worklogs/2026-06-15-D1-general-purpose.md` (impl `987c23f`) |
| C1b — Junk schema consolidation (`Item`→`JunkItem` + `tier`) | merged `ce85b55`; `Item` retired, `tier` 1–5 authored on all 8 items, `check_junk_catalog.gd` → **JUNK CATALOG OK**, smoke repointed; worklog `worklogs/2026-06-15-C1b-game-director-designer.md` (impl `202fb65`) |
| E1 — Gate node + extract-and-bank | merged `ce85b55`; `tests/test_extract_bank.gd` → **EXTRACT OK** (banks ids to `banked_junk`, wipes run-state, `haul_banked`+`run_ended[extract]`, no Money credit, zero-haul valid, persists by id); schema 1→2 + migration; worklog `worklogs/2026-06-15-E1-general-purpose.md` (impl `9b18d83`) |
| D2 — Inventory UI (greybox) | merged `061c6aa`; `tests/test_inventory_ui.gd` → **INV UI OK** (pure projection, signal-driven rebuild, item+free-slot cell count, capacity label, BAG FULL state, drop gesture); worklog `worklogs/2026-06-17-D2-ui-ux-designer.md` (impl `0681894`) |
| B3 — Band depth / "push deeper" | merged `f78aff7`; `tests/test_band_depth.tscn` → **BAND DEPTH OK** (depth BFS, depth-scaled value $31.9→$121.6, tier gate, plan determinism, no RNG cross-talk, duplicate isolation); worklog `worklogs/2026-06-17-B3-general-purpose.md` (impl `ffbe875`) |
| C2 — Junk pickup in the band | merged `aa9a610`; `tests/test_junk_pickup.tscn` → **JUNK PICKUP OK** (24 pickups from B3 plan, interact adds+frees, full-bag reject leaves it in-world, `junk_picked_up` fires, drop re-spawn via `spawn_one`); worklog `worklogs/2026-06-17-C2-general-purpose.md` (impl `5adacac`) |
| E3 — Death/timeout drops haul | merged `1f18910`; `tests/test_death_drop.gd` → **DEATH DROP OK** (whole-item pockets @ `floor(value*0.20)` highest_value, banks kept items to `banked_junk`, empty-bag valid, cheapest-exceeds-budget edge, `_run_ended` idempotency, extract-wins-tie, one `run_ended`); `run_rules.tres`; `debug_kill` key K; worklog `worklogs/2026-06-17-E3-programmer.md` (impl `9f23851`) |
| E2 — Push/cash-out decision HUD | merged `43284f5`; `tests/test_decision_hud.gd` → **DECISION HUD OK** (Holding=`run_haul_value`, clock bar/tint green→amber→red off `dive_clock_changed`, Depth=`current_depth`, gate-only extract prompt w/ live value); composes D2 panel; worklog `worklogs/2026-06-17-E2-ui-ux.md` (impl `7e0eb0a`) |
| D3 — Activate drop-to-swap re-spawn | merged `923a815`; `tests/test_drop_swap.tscn` → **DROP SWAP OK** (drop removes from bag + emits `junk_dropped(item, player_pos)`, C2 spawner re-instantiates pickup); closes wave-3 `C2/dropwiring`; worklog `worklogs/2026-06-17-D3-ui-ux.md` (impl `e188a50`) |
| G5 — Meta save-migration fixture (v1→v2) | merged `0d6c484`; `tests/test_save_migration.tscn` → **SAVE MIGRATION OK** (binary `meta_v1.sav` fixture migrates to v2, `banked_junk`→`[]`, fields intact, round-trip + `.bak`); CI-wired; closes wave-3 `E1/schema`; worklog `worklogs/2026-06-17-G5-qa.md` (impl `8655454`) |

_Integrated `main` re-verified after every merge (full suite green): `--import` clean · **SMOKE OK** · MOVE OK · ZONE PIECES OK · JUNK CATALOG OK · INTERACT OK · DIVE CLOCK OK · BANDGEN OK · INV OK · EXTRACT OK · INV UI OK · BAND DEPTH OK · JUNK PICKUP OK · DEATH DROP OK · DECISION HUD OK · DROP SWAP OK · SAVE MIGRATION OK (16 checks)._
_Open test-hygiene nit (QA): B2's determinism scene leaks "2 resources still in use at exit" (un-freed PackedScene instances) — cosmetic, non-failing; tidy when GdUnit4 is vendored (G2)._

## Done (M0 — Pre-production & Tech Foundations)
| Task | Proof |
|---|---|
| Toolchain installed (Godot 4.6.3, git-lfs 3.7.1, gh 2.94.0, pip/Pillow/numpy, uv) | `~/.local/bin`; `godot --version` |
| Repo scaffolding: LFS, `.gitattributes`, `.gitignore`, folders, `.godot-version` | LFS round-trip smoke test passed |
| Godot M0 spike: autoloads + EventBus + RNG + GameState + SaveManager + Telemetry + AudioDirector | `tools/ci_smoke_test.gd` → **SMOKE OK** |
| Data-as-Resources pattern (`data/item.gd` + sample `.tres`) | loads headless |
| 8 role subagents installed + `Role_Playbooks/` authored | cross-ref check: 0 missing |
| MCP servers fal-ai / elevenlabs / pixellab | `claude mcp list` → all ✔ Connected |
| Orchestration system (this file, `TASKS.md`, worklogs, deviations log, CI) | files present |

**M0 feedback gate:** internal tech review — *Is the architecture sound and iterable?* → ready for human sign-off.

---

## Legend
`Backlog → In progress → (Verify) → Done` · or `→ Blocked`. A task is **Done** only with a worklog naming a real commit and its definition of done met.
