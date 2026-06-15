# STATUS — THE FAR YARD

The orchestrator's single source of truth for task state. Mirror of GitHub Projects.
Updated every time a task is claimed, blocked, or finished. See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M0 ✅ complete → **M1 (Greybox Core Loop)** next.
**Last updated:** 2026-06-15

---

## In progress
_(none — M1 not yet dispatched)_

## Blocked
| Task | Blocked by | Note |
|---|---|---|
| `gh` GitHub Projects sync | human | Needs interactive `gh auth login -s project` (see `SETUP.md`). |
| ElevenLabs/PixelLab live generation | — | Connected; calling them spends paid credits — get human OK before a generation run. |

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
