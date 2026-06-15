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
**M1 wave 1 done & integrated into `main`** — A1, B1, C1 (the three M0-only foundations) verified
green and merged. The next *unblocked* wave (dispatch in parallel, each in its OWN git worktree —
see process note below):
- **A2** — Interaction component (needs A1 ✅) · `general-purpose`
- **A3** — In-dive clock (needs A1 ✅) · `general-purpose` (+ ui-ux-designer: meter readout)
- **B2** — Room-graph generator (needs B1 ✅) · `general-purpose`
- **D1** — Slot inventory data model (needs C1 ✅) · `general-purpose`

Still blocked: **C2** (needs A2,B2,C1,D1), **B3** (needs B2,C1), **E1** (needs A2,D1). Build order &
dep map: `design/M1_Tasks/Junkyard_M1_Breakdown.md` §4. Per-task specs in `design/M1_Tasks/`.

> **PROCESS FIX (mandatory for parallel dispatch):** wave 1 ran 3 agents in ONE shared checkout →
> `git switch` collisions; agents clobbered each other's untracked files and C1's commit swept in
> stale A1 files (caught & excluded at integration). From now on dispatch parallel agents with
> **`isolation: worktree`** (or serialize same-tree work). Logged in `DESIGN_DEVIATIONS.md`.

## In progress — M1 wave 2 (each agent in its OWN git worktree)
EventBus signal contract for all four pre-locked on `main` (`a180f75`) so none edit `event_bus.gd`.
Only **D1** edits `game_state.gd`; only **A2** edits `player.tscn`. → no shared-file merge conflicts expected.

| Task | Agent(s) | Branch | Started | State / next step |
|---|---|---|---|---|
| A2 — Interaction component | general-purpose | `general-purpose/A2-interaction` | 2026-06-15 | Dispatched (worktree). Verify: prompt near interactable; `interact` fires `interaction_requested` naming target. |
| A3 — In-dive clock | general-purpose (meter folded in) | `general-purpose/A3-dive-clock` | 2026-06-15 | Dispatched (worktree). Keys off existing `run_started`/`run_ended` (NOT new dive_started). Verify: meter depletes; zero → `dive_clock_timeout` once. |
| B2 — Room-graph generator | general-purpose | `general-purpose/B2-band-generator` | 2026-06-15 | Dispatched (worktree). Real RNG API (`seed_from`, integer weighted pick). Verify: same seed → identical layout (test); connected/walkable. |
| D1 — Slot inventory model | general-purpose | `general-purpose/D1-inventory` | 2026-06-15 | Dispatched (worktree). SOLE editor of `game_state.gd`; integrates with existing `start_run`/`unbanked_value`. Verify: accept/reject by capacity; full blocks; run-state only. |

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

_Integrated `main` re-verified after merge: `--import` clean · **SMOKE OK** · MOVE OK · ZONE PIECES OK · JUNK CATALOG OK._

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
