# TASKS — THE FAR YARD

The orchestrator's task queue (mirror of GitHub Projects). The orchestrator consumes the
top *unblocked* task, dispatches the assigned subagent(s), and moves it through `STATUS.md`.
Each task carries: **id · milestone · assignee subagent · spec · definition of done · blockedBy**.
Finished tasks move to `TASKS_COMPLETED.md` (this file holds only **active + backlog**).

Format:
```
### <ID> — <title>
- Milestone: M<n>   Assignee: <subagent(s)>   BlockedBy: <ids|none>
- Spec: <path to the design doc>
- Goal: <one sentence>
- Done when: <verifiable acceptance criteria>
```

> A single task may span a programmer + an asset role (see `CLAUDE.md` → Dispatch). The
> primary assignee is listed first; a `(+ role: scope)` note marks the secondary agent.

---

## M1.2 — Legibility & Level Scale — ✓ **DONE 2026-06-19** (re-gated → ITERATE → M1.3)

All built + re-gated: Waves 1/2 + BUG5 + RG1 → Director playtest → RG2 → **RG3 verdict ITERATE**. Findings + Director
decisions: `design/M1_2_Tasks/G4_findings_M1.2.md`. All tasks archived → `TASKS_COMPLETED.md`.

---

## M1.3 — Legibility & Density — ✓ **DONE 2026-06-21** (re-gated → ITERATE → M1.4)

All built + re-gated: Waves 1/2 (J1·J2·J3·J4·J5·BUG6·DLV1·DLV2) + RG1 → Director playtest → **RG3 verdict ITERATE**.
Findings + the Director feedback work-order: `design/M1_3_Tasks/G4_findings_M1.3.md`. Tasks archived → `TASKS_COMPLETED.md`.

---

## M1.4 — Stakes, Variety & Legibility — ✓ **DONE 2026-06-21..24** (re-gated → ITERATE → M1.5)

All waves built + re-gated: Waves 1–3 (K0–K7, K5a/b/c/i) + RG1 + Wave-5 bug-wave (BUG7/BUG8/TUNE2/FB5) → Director
playtest → **RG3 verdict ITERATE → M1.5** (`design/M1_4_Tasks/G4_findings_M1.4.md` §RG3). Tasks archived →
`TASKS_COMPLETED.md`.

---

## M1.5 — Agency & Legibility — ✓ **DONE 2026-06-24..26** (re-gated → ITERATE → M1.6)

All waves built + re-gated: Waves 1–3 (L0–L5 + RG1) + Wave 4 (L6 control rework) + post-RG3 tuning → Director re-test →
**RG3 verdict ITERATE → M1.6** (`design/M1_5_Tasks/G4_findings_M1.5.md` §"RG3 re-test verdict"). Tasks archived →
`TASKS_COMPLETED.md`.

---

## M1.6 — Surface & Staging — ✓ BUILD DONE; RG1 published; RG2/RG3 Director-pending

Build (M0·M1·M2·M4·M3) + RG1 (itch published `m1-20260627-41106de` + FB1–FB4) all on `main`, archived →
`TASKS_COMPLETED.md`. **Open (Director-gated, non-blocking M1.7):** **RG2** (telemetry/flow analysis) + **RG3** verdict
(go/iterate/pivot) in `design/M1_6_Tasks/G4_findings_M1.6.md` — these await the Director's re-test. M1.7 below is
**Director-directed content** opened ahead of that formal verdict.

---

## M1.8 — Hub Art Dressing (ACTIVE — Director-directed; art-only iteration)

Shed the Hub's greybox skin for the placeholder **Layout-A vertical-spine** salvage-yard art
(`art_workshop/map_layouts/`), loop-behaviour unchanged. Breakdown: `design/M1_8_Tasks/M1.8_Breakdown.md`.
**Contracts:** all-off fp `e943ac9c8bc1` + 89/89 held (no knob); no save change; portal/shop
`Interactable` ids + collision + `hub.gd` node paths + wall-bounding invariant; **copy, never move** from
`art_workshop/`. M1.7's RG2/RG3 stay non-blocking.

### Wave 1 — Build  *(H0 → H1, sequential; H1 is the sole `hub.tscn` writer)*

### H0 — Asset import + Hub `TileSet` — ✓ **DONE** (`33f67d5`, 2026-06-28)
- Milestone: M1.8 (Wave 1)   Assignee: environment-artist (+ general-purpose)   BlockedBy: none
- COPIED (not moved) 16 ground tiles + 20 props → `Game/art/hub/{ground,objects}/` (originals intact); built `Game/data/tilesets/hub_ground.tres` (32px, 16 tiles). Import clean. Worklog `…-H0H1-hub-dressing-general-purpose.md`.

### H1 — Dress the Hub scene (Layout-A vertical spine) — ✓ **DONE** (`81a3c13`, 2026-06-28)
- Milestone: M1.8 (Wave 1)   Assignee: general-purpose (+ environment-artist)   BlockedBy: H0
- Re-skinned `hub.tscn`: `HubGround` TileMapLayer spine + `dive_gate`/`portal_glow`/`shack_door`/benches + 15 y-sorted dressing props; all functional contracts invariant. Gate green: import · smoke · fp `e943ac9c8bc1` · 89/89. Integrated `main`@`11b8ff4`. 5 deviations → Director close-out.

### H3 — Street-exit threshold prop (PixelLab) — **DEFERRED (Director-gated, paid credits)**
- Milestone: M1.8   Assignee: environment-artist   BlockedBy: Director OK
- The one missing spec prop (`SS`); not loop-critical (no functional street exit yet). Generate only on explicit Director go.

### Wave 2 — Re-gate  *(after Wave 1 + Director playtest)*

### HG1 — M1.8 playtest build + verify + publish
- Milestone: M1.8 (Wave 2)   Assignee: qa-playtest-coordinator   BlockedBy: H0,H1
- Goal: verify (dressed hub loads, loop unchanged, fp/89/smoke green); update `changelog.txt` (M1.7→M1.8: art-dressed hub); publish to itch (`bash Game/tools/push_itch.sh`).

### HG2 — M1.8 readability check + HG3 — verdict (Director)
- Milestone: M1.8 (Wave 2)   Assignee: qa (assembles) → Director (decides)   BlockedBy: HG1 + human playtest
- Record go/iterate/pivot in `design/M1_8_Tasks/G4_findings_M1.8.md`.

---

## M1.7 — Player Embodiment (ACTIVE — Director-directed; design LOCKED)

Replace the greybox player (teal `ColorRect`+`Nose`) with the **first real character sprite** — the
`player_basic_template` (flannel/hoodie, 8-directional: walk · pickup · throw · idle-from-rotations) — in **both** the Hub
and the Dive, driven entirely off the existing `facing`/`aim`/`velocity`/`junk_picked_up`/`item_thrown` seams; plus a
**debug toggle** to disable the art (fall back to greybox). Breakdown + dependency map + wave order + locked decisions:
`design/M1_7_Tasks/M1.7_Breakdown.md`. **Design is LOCKED** — every task doc carries a `Resolved Decisions` + a
`Director Disposition` section. Director calls: art in BOTH hub+dive (one shared `player.tscn`); pickup/throw use a **brief
movement-lock** (lock on **accepted** pickups only; **clip-driven** duration) — **both exposed as `@export` knobs** on the
visual controller (NOT `RunConfig` fields). **Invariants:** all-off `RunConfig` fp stays `e943ac9c8bc1`; **89-knob count
holds** (the debug art toggle is a view-only switch OUTSIDE the `config_menu` MANIFEST/coverage); **art-OFF = M1.6
byte-for-byte** (greybox retained, no lock); collision r=14 + `player_movement.tres` untouched; frames **COPIED** (never
moved) from `art_workshop/` into `Game/`, filter-off, LFS. Sequential single wave: N0 → N1 → N2.

### Wave 1 — Build  *(N0 → N1 → N2, sequential; one writer per file)*

### N0 — Foundation: art import + `SpriteFrames` + signal seam
- Milestone: M1.7 (Wave 1)   Assignee: character-animator (+ general-purpose)   BlockedBy: none
- Spec: `design/M1_7_Tasks/N0_art_import_spriteframes.md`
- Goal: **copy** (never move) the 152 `player_basic_template` PNGs from `art_workshop/game_art/player_explorations/20260627/player_basic_template/{rotations,move,pickup,throw}` into `res://art/player/…` (hyphens→underscores); `--import` so `.import` inherits the project nearest filter; author `res://entities/player/player_frames.tres` (`SpriteFrames`, 32 clips `<state>_<dir>`: idle 8×1 loop / walk 8×6@10fps loop / pickup 8×5@20fps one-shot / throw 8×7@24fps one-shot); pre-declare the ONE new EventBus signal `debug_player_art_toggled(enabled: bool)` (tooling). Single writer of `event_bus.gd` + the new asset.
- Done when: frames present under `Game/art/player/` (source still in `art_workshop/`); SpriteFrames loads headless with the 32 clips + correct frame counts/loops; import clean; all-off fp byte-identical (e943ac9c8bc1); 89-knob count unchanged; smoke green; signal declared.

### N1 — Player visual state machine (8-way + actions + lock)
- Milestone: M1.7 (Wave 1)   Assignee: general-purpose (+ character-animator)   BlockedBy: N0
- Spec: `design/M1_7_Tasks/N1_player_visual_state_machine.md`
- Goal: rework `entities/player/player.tscn` — add an `AnimatedSprite2D` (from `player_frames.tres`), **retain** the greybox `Visual`/`Nose` hidden-by-default as the art-OFF fallback; new `player_visual.gd` controller with PURE unit-testable helpers `quantize_dir(facing,current)` (8-way, ~10° hysteresis) + `select_state(velocity,locked,action)` (idle↔walk @ ~8px/s; pickup/throw priority); plays pickup on `junk_picked_up` (accepted only, `@export`-gated) + throw on `item_thrown`; **brief movement-lock** by zeroing `input_dir` into the unchanged `step_velocity` (clip-driven, `@export` mode+cap; armed only when art ON). Applies in hub + dive via the shared scene.
- Done when: player shows correct idle/walk per direction + pickup/throw clips in BOTH hub and dive; movement-lock works + is `@export`-tunable; greybox hidden when art on; pure helpers have a headless scene test; collision/movement untouched; all-off fp `e943ac9c8bc1` unmoved; smoke + suite green.

### N2 — Debug "disable player art" toggle
- Milestone: M1.7 (Wave 1)   Assignee: ui-ux-designer (+ general-purpose)   BlockedBy: N1
- Spec: `design/M1_7_Tasks/N2_debug_player_art_toggle.md`
- Goal: add a **non-`RunConfig`** `CheckButton` to the `config_menu` **Meta tab** (label "Player art (debug)", key `CFG_DEBUG_PLAYER_ART`, default checked = art ON, **session-only** — no save write), patterned on the existing Meta-tab telemetry-export button; `toggled` emits `EventBus.debug_player_art_toggled(enabled)`; the player handler swaps `AnimatedSprite2D` ↔ greybox (`Visual`+`Nose`) and disarms the movement-lock when off. The control is NEVER added to `_rows`/MANIFEST.
- Done when: toggling at runtime swaps art↔greybox in hub + dive; default = art ON; `test_config_menu` still reports **89** + coverage assertion green; all-off fp `e943ac9c8bc1` unmoved; no save-schema change.

### Wave 2 — Re-gate  *(sequential; RG2/RG3 after the human playtest)*

### RG1 — M1.7 playtest build + verify + publish
- Milestone: M1.7 (Wave 2)   Assignee: qa-playtest-coordinator   BlockedBy: N0,N1,N2
- Spec: author from `design/M1_6_Tasks/RG1_playtest_build.md` template → `design/M1_7_Tasks/RG1_playtest_build.md`
- Goal: assemble + verify the M1.7 build (8-way idle/walk + pickup/throw in hub AND dive; debug toggle swaps art↔greybox; all-off fp byte-identical `e943ac9c8bc1`; 89-knob coverage; smoke + suite green); **publish to itch** via `bash Game/tools/push_itch.sh`; update `changelog.txt` (M1.6→M1.7 delta: the player is now an animated character + the debug art toggle).
- Done when: a fresh build animates the player correctly in both scenes; the debug toggle works live; verify matrix green; build live on `qusto/the-far-yard:html5`; changelog updated.

### RG2 — M1.7 readability / telemetry check
- Milestone: M1.7 (Wave 2)   Assignee: qa-playtest-coordinator   BlockedBy: RG1 + human playtest data
- Spec: template `design/M1_1_Tasks/RG2_telemetry_analysis.md`
- Goal: light pass (visual change) — confirm no perf regression from the sprite on the web build; telemetry comparable to M1.6; surface any readability friction (8-dir snapping, movement-lock feel) the Director flags.
- Done when: a short analysis artifact + the Director's readability notes assembled for RG3.

### RG3 — M1.7 re-gate verdict (Director decides)
- Milestone: M1.7 (Wave 2)   Assignee: qa-playtest-coordinator (assembles) → Director (decides)   BlockedBy: RG2
- Spec: template `design/M1_1_Tasks/RG3_regate_verdict.md`
- Goal: record go/iterate/pivot in `design/M1_7_Tasks/G4_findings_M1.7.md`. Watch-items: movement-lock feel; 8-direction legibility; the dive-gear-vs-surface-look question.
- Done when: a recorded go/iterate/pivot verdict.

---

## M1 follow-ups (deferred tech-debt — non-blocking, backlog)

From the M1 wave-5 close-out (`DESIGN_DEVIATIONS_HISTORY.md` §"M1 wave 5"). Neither blocks M1.2; pick up opportunistically.

### FU1 — GdUnit4 `test_jsonl_writer`
- Milestone: M1 (follow-up)   Assignee: qa-playtest-coordinator   BlockedBy: none
- Spec: `M1_As_Built.md` §Telemetry + `systems/telemetry/jsonl_writer.gd`
- Goal: add the GdUnit4 `test_jsonl_writer` suite G2 deferred — exercise the writer seam (write rows, read back, assert parseable JSON + envelope fields `v, ts, t_ms, run_id, session_id, type, data`).
- Done when: a GdUnit4 suite under `tests/telemetry/` covers `JsonlWriter` round-trip + envelope fields; green headless; test count rises.

### FU2 — Static `EconomyMath` helper
- Milestone: M1 (follow-up)   Assignee: general-purpose   BlockedBy: none
- Spec: `systems/game_state.gd` (`_resolve_pockets`/`_sum_values`/`run_haul_value`)
- Goal: lift the pure economy math out of `GameState` into a static `EconomyMath` helper so it's testable without snapshotting global meta; `GameState` delegates; no behavior change.
- Done when: a static `EconomyMath` owns pockets/sum/haul; `GameState` delegates; G2 economy suites call it directly (no meta snapshot); suite green.

### FU3 — Repair-or-retire `test_rg1_m13_verify` *(M1.6 W2-F1 — Reviewed)*
- Milestone: M1.6 (follow-up)   Assignee: qa-playtest-coordinator   BlockedBy: none
- Spec: `tests/test_rg1_m13_verify.gd` + `design/DESIGN_DEVIATIONS_HISTORY.md` §"M1.6 Wave 2 close-out"
- Goal: the M1.3 RG-verify scene is stale (fails on M5/all-on opposition-telemetry rows + `timeout` end-cause; verified pre-existing at `536c9ba`, not in the CI gate, last green at M1.3). Either align its preset/telemetry expectations to the current build or retire it in favour of the maintained `m14`/`m15` verifies; if kept, wire it into the standing CI set.
- Done when: m13 either passes green deterministically (and is in the CI gate) or is retired with a one-line rationale; no other RG verify regresses.

### FU4 — Keyboard-only aim tracks movement *(M1.5 L6-F1 — Reviewed)*
- Milestone: M1.6 (follow-up)   Assignee: general-purpose   BlockedBy: none
- Spec: `player.gd` `resolve_aim()` + `design/M1_5_Tasks/L6_control_rework.md`
- Goal: when neither mouse (`_mouse_active`) nor right-stick is active, let the pure-keyboard fallback aim track the movement direction instead of holding the DOWN default, without destabilising controller stick-release or letting a stale cursor hijack aim. Mouse + controller (primary) behaviour unchanged.
- Done when: a keyboard-only player's aim follows movement; controller/mouse aim unchanged; throw tests green; all-off fp `e943ac9c8bc1` unmoved.

---

## Backlog (M2+)
Pulled forward when M1.x passes its gate. See TDD §7: M2 (vertical slice: full day loop, recipe repair, first enemy, real art for one band), M3 (bands 1–3, currencies/tracks, exposure crises), M4 (Act 3 + endings), M5 (polish/ship). The **economy workbook** `design/economy_model.xlsx` (game-director-designer) is due **before M3**.
