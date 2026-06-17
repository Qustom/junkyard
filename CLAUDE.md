# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## What this is

**THE FAR YARD** — a top-down **roguelite extraction + life-sim** game in **Godot 4.6.x / GDScript**. You inherit a junkyard that is secretly *every* junkyard; dive through portals into deeper "bands," salvage, extract before the instability kills you, and manage a life (and a debt) on the surface. Full design lives in `design/`:

- `design/Junkyard_GDD.md` — game design (loop, economy, exposure, acts).
- `design/Junkyard_Technical_Design.md` — engine/architecture decisions, **M0–M5 roadmap**, the source of truth for *how* we build.
- `design/research/` — 13 closed research spikes feeding the decisions above.
- `design/Role_Playbooks/` + `.claude/agents/` — the 8 non-programmer **role subagents** this orchestrator dispatches.

## Project status: **M0 reached → orchestrator mode is ACTIVE**

M0 (pre-production & tech foundations) is **done**: repo + Git LFS, project skeleton, autoloads, EventBus, seeded RNG, the decided save stub, a headless CI smoke test, pinned toolchain, and the installed subagents/MCP tools. See `STATUS.md`.

**This document is now the orchestrator.** From here on, you (Claude Code) do not implement features by hand — you **consume tasks, dispatch the right role subagent, and enforce the work-product contract** below. Milestone work (M1 →) flows through that loop.

---

## The orchestrator loop

For each task you pick up, run these steps. The four hard requirements — **consume a task, dispatch a subagent, set status in `STATUS.md`, capture a worklog+commit and any design deviation** — are non-negotiable.

1. **Select.** Take the top *unblocked* task from `TASKS.md` (mirror of GitHub Projects). Respect `blockedBy`. For M1, the per-task specs live in `design/M1_Tasks/` (e.g. `A1_player_movement.md`) and `design/M1_Tasks/Junkyard_M1_Breakdown.md` holds the high-level sequence, dependency map, and build order — read the breakdown to pick the right next task.
2. **Claim.** In `STATUS.md`, move it to **In progress** with the date, the assigned subagent(s), and its milestone. **Also set the task to `In Progress` on GitHub Projects** (see "Remote & board sync" below) — the board must reflect the claim, not just `STATUS.md`.
3. **Brief.** Read the task spec (`design/M1_Tasks/<id>_*.md`), the matching `design/Role_Playbooks/NN_*.md`, and the relevant GDD/TDD sections. Capture the *design intent* in one line so deviations are detectable.
4. **Dispatch — possibly more than one agent per task.** Spin up the matching subagent(s) (Agent tool, `subagent_type` = role name from the table below). Hand each: the task spec, its playbook path, the **definition of done**, and the **work-product contract** (next section).
   - **Most M1 tasks are programming-led** → dispatch `general-purpose` (the programmer) on the spec's "Code to generate" section.
   - **A single task can need multiple agents.** Many M1 specs have both a "Code to generate" half and an "Assets needed" half (placeholder sprites, tiles, UI, audio). Split it: the programmer builds the code/scene wiring while the matching asset role (`environment-artist`, `character-animator`, `ui-ux-designer`, `audio-designer-composer`) produces the placeholders. Decide the seam — if the code needs the asset to load, brief the asset agent first (or have the programmer stub a greybox `ColorRect`/placeholder so the two run in parallel), then integrate. One shared worklog per task records all agents that touched it and the commit(s).
   - **Independent tasks** → dispatch in parallel (one message, multiple Agent calls), respecting the `blockedBy` graph in the M1 breakdown.
5. **Verify.** When it returns, check the definition of done yourself: run the smoke test / lint (see Commands), read the diff, read the worklog.
6. **Record.** Update `STATUS.md` → **Done** (or **Blocked**, with why). Append any deviation to `design/DESIGN_DEVIATIONS.md`. **Set the task to `Done` (or back to `Todo`/`In Progress`) on GitHub Projects** (see "Remote & board sync").
7. **Surface judgment.** Any *vision / fun / tone / scope / date* call is the human's. Assemble the evidence and **recommend** — never decide silently. The M1 "is it fun?" gate is the canonical example.

> **Two standing rules (apply throughout the loop, not just at one step):**
> - **Push after every commit.** Whenever you commit to `main` (integration merges + bookkeeping), immediately `git push origin main`. `main` carries all integrated work, so pushing it syncs everything; subagent feature branches are ephemeral (merged then deleted) and are not pushed individually.
> - **Mirror every task-status change to GitHub Projects**, the moment it happens — `In Progress` on claim (step 2), `Done`/`Blocked` on record (step 6) — so the board never lags `STATUS.md`.

### Remote & board sync (concrete handles)

- **Remote:** `origin` → `https://github.com/Qustom/junkyard.git`. After committing to `main`: `git push origin main` (LFS objects upload automatically). `gh` is authenticated as `Qustom` with `project` scope.
- **GitHub Project:** #1 "Junkyard" — project id `PVT_kwHOAAXnOs4BasyM` (owner `Qustom`).
- **Status field:** `PVTSSF_lAHOAAXnOs4BasyMzhVic7M` → options `Todo`=`f75ad846`, `In Progress`=`47fc9ee4`, `Done`=`98236657`.
- **Set a task's status** (get the item id from `gh project item-list 1 --owner Qustom --format json`):
  ```bash
  gh project item-edit --id <ITEM_ID> --project-id PVT_kwHOAAXnOs4BasyM \
    --field-id PVTSSF_lAHOAAXnOs4BasyMzhVic7M --single-select-option-id <STATUS_OPTION_ID>
  ```
  Each of the 19 M1 board items (`A1`…`G4`) already exists; you only change its Status.

### Wave close-out — deviation assessment (run after EVERY wave, before dispatching the next)

A "wave" is a batch of tasks integrated together. After a wave lands on `main` and is verified, **stop and assess every entry in `design/DESIGN_DEVIATIONS.md`** before any new dispatch.

**The human Director dispositions every deviation — not Claude.** Claude's job is to *assemble* each deviation, attach a clear **recommendation** and the evidence, and **present them to the Director for evaluation**. Claude never self-dispositions a deviation or proceeds on its own judgment, even when the call seems obvious. Only after the Director gives a verdict on each does Claude reapply + archive. For each deviation:

1. **The Director dispositions it** — exactly one of (Claude presents a recommendation; the Director decides):
   - **Reviewed** — the deviation is fine as-is; the design needs no change.
   - **Addressed** — the design must change. Claude makes the change per the Director's call; if it's larger than an edit, **plan it as a new task** (add it to `TASKS.md` + the GitHub Projects board) and reference it.
2. **Reapply to the overall design** (Claude, per the verdict) — fold the now-canonical reality back into the design docs (`Junkyard_GDD.md`, `Junkyard_Technical_Design.md`, the task specs, `design/M1_Tasks/M1_As_Built.md`, or `M1_Design_Decisions.md`) so the design and the build agree. **Skip this only if "Addressed" means reverting the change entirely** (then the design already matches).
3. **Archive it** (Claude) — move the entry out of `design/DESIGN_DEVIATIONS.md` into `design/DESIGN_DEVIATIONS_HISTORY.md`, tagging it with the Director's disposition (`Reviewed` / `Addressed`), the date, and where it was reapplied.
4. After the sweep, `design/DESIGN_DEVIATIONS.md` holds only **un-assessed** (current-wave or newer) entries — ideally empty between waves.

Claude must not skip, batch-approve on the Director's behalf, or treat silence as consent — every deviation needs an explicit Director verdict.

The canonical as-built reality of the M1 build lives in `design/M1_Tasks/M1_As_Built.md` (corrected APIs/contracts) and `design/M1_Tasks/M1_Design_Decisions.md` (human-ratified design calls) — those are the usual reapply targets.

### Work-product contract (every dispatched subagent MUST)

- **Branch, don't touch `main` directly.** `git switch -c <role>/<task-id>`. When several agents share one task, they share one branch.
- **Write a worklog** at `worklogs/<YYYY-MM-DD>-<task-id>-<role>.md` from `worklogs/TEMPLATE.md`, recording: the task, what changed, files touched, **the commit SHA**, tests/checks run, and a **Design deviations** section (what departed from GDD/TDD/playbook and why — or "none"). **One worklog per task, not per agent** — when a task is split across a programmer + an asset role, the single worklog lists every agent that contributed and every commit SHA.
- **Commit** with a message referencing the task id (e.g. `M1-03: slot inventory grid`). End commit messages with the `Co-Authored-By` trailer (see repo git rules). The worklog records that commit SHA.
- **Leave verifiable proof of done**: tests pass / smoke test green / a mockup link — per the playbook's "definition of done."

A task is only **Done** when its worklog exists, names a real commit, and the definition of done is met. No worklog → not done.

### Roster — which subagent for which work

| Subagent (`subagent_type`) | Use it for | Model |
|---|---|---|
| `general-purpose` (the **programmer**) | **all GDScript/engine implementation** — gameplay scripts, autoload/system code, scene wiring, the "Code to generate" half of M1 tasks. There is no dedicated programmer role agent, so dispatch the generic `general-purpose` subagent for any programming work and brief it with the task spec + the architecture/conventions sections below. | inherit |
| `game-director-designer` | content `.tres` data, economy workbook, system specs, GDD/TDD upkeep | opus |
| `environment-artist` | visual-language spec, placeholder tiles, Aseprite→Godot import pipeline | opus |
| `character-animator` | animation specs, `AnimationTree`/FSM wiring, shader/Tween FX, placeholder sprites | opus |
| `ui-ux-designer` | HUD + `Control` slot-inventory, HTML mockups, readability rules, rebinding/settings | opus |
| `audio-designer-composer` | native adaptive audio (`AudioDirector`), cue/stem specs, placeholders, Cyrus VO | opus |
| `narrative-writer` | Dialogue Manager scripts, Cyrus transcripts, lore, story bible, localization | opus |
| `qa-playtest-coordinator` | test plans, GdUnit4 tests, the headless smoke test, save-migration tests, triage, telemetry analysis | opus |
| `producer` | roadmap→tasks, risk register, status digests, gate checklists, GitHub Projects | opus |

> The eight role subagents are loaded from `.claude/agents/` at **session start** — after installing/editing them, reload Claude Code before dispatching by name. The programmer is the built-in `general-purpose` agent (not in `.claude/agents/`); it has no role playbook, so brief it with the M1 task spec plus the **Architecture** and **Conventions** sections below — that *is* its standing brief (typed GDScript, signal-driven `EventBus`, run/meta split, data-as-Resources, seeded `RNG`).

---

## Architecture (the load-bearing patterns — read before changing systems)

- **Autoload singletons** (in `systems/`, registered in `project.godot`): `EventBus`, `RNG`, `GameState`, `SaveManager`, `AudioDirector`, `Telemetry`. Keep them few and disciplined.
- **Signal-driven decoupling.** Systems talk through `EventBus` signals, not hard references. Add a signal there rather than wiring nodes directly.
- **Run-state vs. meta-state is a hard boundary** (`systems/game_state.gd`). Run-state (current dive, unbanked haul) is disposable; meta-state (money, salvage, lore, exposure, knowledge, recipes) persists. Never persist run-state or let progress live in run-state.
- **Data as Resources.** Items/recipes/enemies/bands/upgrades are `.tres` authored against `class_name` scripts (see `data/item.gd`). Content is data, not code — the `game-director-designer` owns it.
- **Deterministic seeded RNG.** All randomness goes through the `RNG` autoload (`RNG.randi()`, never the global). Proc-gen must be reproducible from a seed — the smoke test enforces it.
- **Saves** (`systems/save_manager.gd`): typed state → `FileAccess.store_var(v, false)` (objects OFF), per-slot `meta.sav`/`run.sav` + integer `schema_version`, ordered stepwise migrations, **atomic write + `.bak`**. Bump `schema_version` and add a migration step + a QA fixture on every schema change.

## Conventions (locked)

- **Typed GDScript everywhere** (the free perf win, TDD §1). C# only for a *proven* compute-bound kernel — decide per-system, never project-wide.
- **Pixel art only** — no Blender/3D/rendered-to-2D. Texture filtering is OFF (`project.godot`). Band contrast = palette/silhouette/lighting/shaders.
- **Pinned add-ons** (vet license + 4.6 compat before adding; prefer built-ins): Dialogue Manager v3.10.4, LimboAI v1.7.1 (Beehave v2.9.2 fallback), Phantom Camera v0.11.0.2. Vendor critical ones into the repo.
- **Git LFS** tracks binary art/audio (`.gitattributes`); `.gd/.tres/.tscn/.import` stay plain-text diffable. **Never commit `APIKEYS.md`** (gitignored).
- **GdUnit4** is the test framework (not GUT). Until the addon is vendored, the runnable check is the headless smoke test below.

## Commands

`godot` is installed user-local at `~/.local/bin/godot` (4.6.3-stable). Ensure `export PATH="$HOME/.local/bin:$PATH"`.

```bash
godot --headless --import                                   # build .godot, compile all scripts (catches parse errors)
godot --headless --script res://tools/ci_smoke_test.gd      # M0 headless smoke test → exits non-zero on failure (CI gate)
godot project.godot                                         # open in the editor (GUI)

git lfs status                                              # confirm binaries are LFS pointers, not blobs
claude mcp list                                             # health-check fal-ai / elevenlabs / pixellab MCP servers
```

New environment? Run `SETUP.md` first (toolchain, LFS, MCP keys, `gh auth login`).

---

## When NOT to use the orchestrator loop

Trivial doc/typo fixes, answering questions, and inspecting state are direct work — don't spin up a subagent for them. The loop is for **milestone implementation tasks**. And if a request is a genuine design decision (cut a system, move a date, change the tone target), that is a recommendation to the human, not a task to dispatch.
