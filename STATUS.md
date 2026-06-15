# STATUS — THE FAR YARD

**Resume point — read this first.** This is where the orchestrator picks up after any interruption,
with no other context. It holds only *current* work: what's in progress (and how to continue it),
what's blocked, and the immediate next action. The full task queue lives in `TASKS.md`; the board
mirror lives in GitHub Projects. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M0 ✅ complete → **M1 (Greybox Core Loop)**, in progress.
**Last updated:** 2026-06-15

---

## ▶ Next action (start here on a cold restart)
**M1 waves 1 & 2 done & integrated into `main` (`b9a50f7`)** — A1, B1, C1, A2, A3, B2, D1 (7/19) all
verified green. The next *unblocked* wave (dispatch each in its OWN git worktree; pre-lock any shared
EventBus signals on `main` first, as in wave 2):
- **D2** — Inventory UI (needs D1 ✅) · `ui-ux-designer` · independent → safe to parallelize
- **E1** — Gate node + extract-and-bank (needs A2 ✅, D1 ✅) · `general-purpose` · ~independent (calls existing `GameState.bank_haul`)
- **B3** — Band depth / "push deeper" (needs B2 ✅, C1 ✅) · `general-purpose` (+ game-director-designer: depth value curve)
- **C2** — Junk pickup in the band (needs A2 ✅, B2 ✅, C1 ✅, D1 ✅) · `general-purpose`

> **Sequencing note:** B3 and C2 both shape junk-by-depth (B3 defines the depth→value/density curve;
> C2 consumes it to place pickups). Recommend **B3 before C2** (or share one branch) to avoid colliding
> spawn logic. D2 + E1 are independent of both → run them in parallel with B3.

Then-unblocked (wave 4+): **E2** (E1,B3,D2,A3), **E3** (E1,A3), **F1** (E1) → **F2** (F1,D2) →
**G1/G2** → **G3** build → **G4** the fun gate. Dep map: `design/M1_Tasks/Junkyard_M1_Breakdown.md` §4.

> **PROCESS (locked):** parallel agents run with **`isolation: worktree`**; pre-declare any shared
> EventBus signals on `main` before dispatch so no two agents edit `event_bus.gd`. Both proven in wave 2
> (zero shared-file collisions). See `DESIGN_DEVIATIONS.md`.

## In progress
_(none — waves 1 & 2 complete; wave 3 not yet dispatched)_

## Blocked
| Task | Blocked by | Note |
|---|---|---|
| ElevenLabs/PixelLab live generation | human | Connected; calling them spends paid credits — get human OK before a generation run. |
| `Item` vs `JunkItem` schema reconcile | human/Director | Overlapping content schemas (see `DESIGN_DEVIATIONS.md`). Decide canonical/merge before content volume grows; saves/telemetry key off ids. |

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

_Integrated `main` re-verified after every merge: `--import` clean · **SMOKE OK** · MOVE OK · ZONE PIECES OK · JUNK CATALOG OK · INTERACT OK · DIVE CLOCK OK · BANDGEN OK · INV OK._
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
