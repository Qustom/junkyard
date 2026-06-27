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

1. **Select.** Take the top *unblocked* task from `TASKS.md` (mirror of GitHub Projects). Respect `blockedBy`. **Completed tasks are archived to `TASKS_COMPLETED.md`** — `TASKS.md` holds only active + backlog. Per-task specs + the milestone breakdown live in **per-milestone folders `design/M<n>_Tasks/`** (e.g. `design/M1_Tasks/A1_player_movement.md`); an **iteration sub-version** gets its own folder `design/M<n>_<k>_Tasks/` (e.g. `design/M1_1_Tasks/`). The breakdown (`*_Breakdown.md` — e.g. `Junkyard_M1_Breakdown.md`, `M1.1_Breakdown.md`) holds the sequence, dependency map, and wave/build order — read it to pick the right next task. See "Milestone iteration loop" below.
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
  The M1.0 board items (`A1`…`G6`, `G4`) already exist (now `Done`). For **new** tasks (M1.1's `R0`…`RG3`, bugs, follow-ups, and future milestones) **create the board item** with `gh project item-create 1 --owner Qustom --title "<id> — <title>" --body "<...>"`, then set its Status. Mirror every status change here the moment it happens.

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

### Milestone iteration loop (build → playtest gate → iterate)

Each milestone runs as a **build phase** (waves of tasks) followed by a **playtest feedback gate** that records an explicit **go / iterate / pivot** verdict. The verdict is the human Director's call — Claude assembles the evidence (telemetry + analysis) and **recommends**; it never decides (the canonical example is M1.0's G4 gate, `design/M1_Tasks/G4_findings.md`). The verdict drives what happens next:

> **Publish every playtest build to itch (standing step of the playtest gate).** When the re-gate's playtest build is produced (the RG1-style "build + verify" task), **publish it to itch.io** so the Director (and any tester) can play it in-browser: from the repo root run `bash Game/tools/push_itch.sh` (the script self-locates to `Game/`; stamp → export the Web preset → `butler push qusto/the-far-yard:html5`). If `butler` is a shell alias (it's at `/mnt/c/wsl-libraries/butler/butler`), pass `BUTLER=/mnt/c/wsl-libraries/butler/butler` — scripts can't see aliases. Live page: `https://qusto.itch.io/the-far-yard` (password-gated; **Chrome/Edge only** — Firefox lacks the SharedArrayBuffer COEP itch serves). Desktop stays the telemetry vehicle; web telemetry returns via the in-game "Export telemetry" button. Prereqs + the harmless godot export-exit crash are documented in `Game/tools/playtest/tester_readme.md` ("Publishing a playtest build") and `SETUP.md §1a`.

> **Generate the build's changelog (standing step of the playtest gate — do this WITH the publish).** Every playtest-ready build ships **alongside an updated `changelog.txt`** so the Director/testers know what changed. Before (or with) the itch publish, update `changelog.txt` for that build and commit it. **Scope rule:** the changelog documents the **delta from the *previous* shipped version** (e.g. M1.3 → M1.4) as a clean *feature* list — what's new/changed for a player coming from the last version. **Do NOT list intra-version bug-fixes or tweaks to features that are themselves new in this version** (a fix to an M1.4-new hazard is not a separate entry — just describe the feature in its final, working state). Mid-version tweaks (e.g. a Director config change) update the relevant *feature's description* in place rather than adding a "FIXED/CHANGED" entry. Keep a short "NOT YET IN THIS BUILD" note for known deferred follow-ups. The changelog is provided to the Director with the playtest build.

- **go** → advance to the next milestone.
- **iterate** → **bump a sub-version** (`Mx.0 → Mx.1 → Mx.2 …`) and run another build-phase + re-gate. Each sub-version gets its **own breakdown**, authored from the previous one as a **template** — the first such iteration is `design/M1_1_Tasks/M1.1_Breakdown.md`, spawned by M1.0's ITERATE verdict.
- **pivot** → a Director-level design rework.

**This loop applies to every milestone** — M2 and beyond iterate the same way after their initial tasks land. Standing conventions for it:

- **Per-milestone task-spec folders.** Specs + the breakdown live in `design/M<n>_Tasks/`; an iteration sub-version gets `design/M<n>_<k>_Tasks/` (e.g. `design/M1_1_Tasks/`).
- **Comparable experiments.** Make each iteration measurable against its predecessor: a **data-driven config** (e.g. M1.1's `RunConfig`) whose **all-off default reproduces the prior baseline** as a permanent in-build control, plus **config-marked telemetry** so the gate compares versions on the same metrics. Record each version's verdict in a `G4_findings*.md`-style doc.
- **Completed-task archive.** `TASKS.md` holds only **active + backlog**; finished tasks move to `TASKS_COMPLETED.md` (completion proof stays in `STATUS.md` §Done + the worklogs) to keep the active queue readable.

### Version breakdown authoring — the four-phase process (run BEFORE any build wave)

Every milestone and every iteration sub-version is **authored the same way** before a single line of feature code is written. This runs when an `iterate` verdict bumps a sub-version (`Mx.k → Mx.(k+1)`) or when a new milestone's task set begins. **Do not skip to dispatching build tasks** — the breakdown + per-task designs + resolved open questions are the prerequisite that makes the build phase parallelizable and unambiguous (this is the proven M1.1 shape: every `R<n>_*.md` had research + pseudocode + a Director-ratified "Resolved Decisions" section).

- **Phase 0 — Folder.** Every version gets **its own folder** under `design/`. The base milestone is `design/M<n>_Tasks/`; each iteration sub-version is `design/M<n>_<k>_Tasks/`. The sequence is `design/M1_Tasks/` → `design/M1_1_Tasks/` → **`design/M1_2_Tasks/`** → … (and `design/M2_Tasks/` → `design/M2_1_Tasks/` → …). Create the folder first; everything for that version lives in it.

- **Phase 1 — Breakdown (the task list).** Author **one** `M<n>.<k>_Breakdown.md` in that folder, using the previous version's breakdown as a **template**. It holds: the one thing this version must prove, the scope guardrails, the **task list (stable ids)**, the **dependency map**, the **wave / build order**, and the cross-cutting contracts (e.g. the configurable-knob + config-marked-telemetry contract whose all-off default reproduces the prior baseline). This is the single source for *which* tasks exist and *in what order* — nothing more granular yet.

- **Phase 2 — Per-task design (fan-out: one subagent per task).** For **every** task in the breakdown, dispatch a subagent (the matching role — usually `game-director-designer` for a design spec, the relevant asset role for an asset-led task) to expand that task into **its own design doc** `design/M<n>_<k>_Tasks/<id>_*.md`. Each design doc MUST contain: **(a) research on the premise** — why this task, what already exists in-repo it builds on (cite real files/APIs), relevant prior art / GDD-TDD grounding; **(b) pseudocode** — illustrative, against the real as-built APIs; **(c) an explicit `Open Questions` section** — every unresolved design call, stated as a question with the trade-offs. These run in **parallel** (they're file-disjoint — each writes only its own doc). The breakdown sets the contract; the design doc sets the internals.

- **Phase 3 — Fresh-eyes open-question resolution (fan-out: NEW subagents).** Once the Phase-2 designs are written, dispatch a **separate set of subagents — fresh eyes, NOT the authors of those designs** — to read each design and **evaluate + resolve its Open Questions** to the best of their ability, folding the answers back into the doc as a **`Resolved Decisions` section** (mirroring M1.1's "Resolved Decisions (ratified)" blocks). Fresh eyes matter: a different agent than the author catches the author's blind spots. The resolver resolves what it can on technical/design merit; **anything that genuinely needs human judgment — a vision / fun / tone / scope / date call — is NOT self-resolved. It is explicitly flagged "needs Director review" with a recommendation**, and surfaced to the human (per step 7 of the orchestrator loop). The Director dispositions those, Claude folds the verdicts in, and the design is then "locked."

- **Phase 4 — Wire-up & hygiene (the orchestrator, after the design is locked — NOT a fan-out).** Once the design is locked, ready the tracking surface for the build phase. This is bookkeeping the orchestrator does directly:
  - **Hook the new version's tasks into `TASKS.md`** — add each task (stable id · milestone · assignee · spec path · definition of done · `blockedBy`) under a version heading, and create its **GitHub Projects board item** (per "Remote & board sync"). `TASKS.md` now carries the new version's active queue.
  - **Archive finished tasks into `TASKS_COMPLETED.md`** — move the **previous** version's completed task specs (and any other now-done tasks lingering in `TASKS.md`) into `TASKS_COMPLETED.md`, so `TASKS.md` holds **only active + backlog** (the standing "Completed-task archive" rule, applied at the version boundary).
  - **Clean up `STATUS.md` for the new version** — reset the top **"▶ Next action"** to point at the new version's first build wave, and trim the verbose in-progress/next-action prose of the version that just closed down to a one-line "done → archived" pointer. `STATUS.md` stays the lean cold-restart resume point.
  - **Archive past statuses into `STATUS_ARCHIVE.md`** — move the closed version's superseded `STATUS.md` sections (old "(archived) ▶ prior next-action" blocks, finished-wave in-progress notes, completed Done tables once they're also in `TASKS_COMPLETED.md`) out of `STATUS.md` into **`STATUS_ARCHIVE.md`** (append-only, newest at the bottom). The detailed history lives there; `STATUS.md` keeps only the current version's live state + a pointer to the archive.

> **Gate:** the build phase (waves of implementation tasks) begins **only after** Phase 4 completes (design locked + Director dispositions folded in + `TASKS.md`/board/`STATUS.md` wired for the new version). A locked + wired version = breakdown + per-task designs whose open questions are all resolved-or-Director-ratified, with the task queue and status surface ready. This is what lets the build waves run as clean parallel worktrees with no mid-build design churn or tracking drift.

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

> **The Godot project lives in `Game/`** (repo-root holds only design/docs/meta — `design/`, `worklogs/`, `*.md`, etc.).
> Pass `--path Game` to every `godot` invocation (or `cd Game` first). **`res://` paths are unchanged** — they resolve against
> `Game/project.godot`, so every `res://…` reference in code/tests/docs stays valid. Headless tests still run as SCENES.

`godot` is installed user-local at `~/.local/bin/godot` (4.6.3-stable). Ensure `export PATH="$HOME/.local/bin:$PATH"`.

```bash
godot --headless --path Game --import                              # build Game/.godot, compile all scripts (parse errors)
godot --headless --path Game --script res://tools/ci_smoke_test.gd # M0 headless smoke test → non-zero on failure (CI gate)
godot --headless --path Game res://tests/<name>.tscn               # run a verify/knob test (as a SCENE, never --script)
godot Game/project.godot                                           # open in the editor (GUI)

git lfs status                                              # confirm binaries are LFS pointers, not blobs (run from repo root)
claude mcp list                                             # health-check fal-ai / elevenlabs / pixellab MCP servers
```

New environment? Run `SETUP.md` first (toolchain, LFS, MCP keys, `gh auth login`).

---

## When NOT to use the orchestrator loop

Trivial doc/typo fixes, answering questions, and inspecting state are direct work — don't spin up a subagent for them. The loop is for **milestone implementation tasks**. And if a request is a genuine design decision (cut a system, move a date, change the tone target), that is a recommendation to the human, not a task to dispatch.
