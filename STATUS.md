# STATUS — THE FAR YARD

**Resume point — read this first.** This is where the orchestrator picks up after any interruption,
with no other context. It holds only *current* work: what's in progress (and how to continue it),
what's blocked, and the immediate next action. The full task queue lives in `TASKS.md`; the board
mirror lives in GitHub Projects. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.0 ✅ built (G4 verdict = ITERATE) → **M1.1 (Greybox Cost Axis)** — **Wave 1 ✅ COMPLETE; Wave 2 (R1–R4) ready to dispatch.**
**Last updated:** 2026-06-19 (M1.1 **Wave 1 done + merged** — R0 `30e41b9`, BUG1+BUG2 `33eb786`, TEL+BUG3 `c940ae4`, CFG `62e16b9`; close-out sweep done. **Next: Wave 2 — R1/R2/R3/R4 in 4 parallel worktrees.** Plan: `design/M1_1_Tasks/M1.1_Breakdown.md`.)

---

## ▶ Next action (start here on a cold restart) — **M1.1 Wave 1: R0 first, then BUG1→BUG2, then CFG/TEL/BUG3**
**M1.1 (Greybox Cost Axis)** is the approved iteration on M1.0's G4 ITERATE verdict. Plan + wave order + the
configurable-knob & telemetry contracts: `design/M1_1_Tasks/M1.1_Breakdown.md`. Goal: add a depth-scaled
**cost/risk axis** (4 configurable oppositions) so push-vs-extract is a real gamble, then re-run the gate.

**Wave 1 — Foundations (in order):**
1. **R0** (run-config data model) — **first & solo** ([GS], defines the `RunConfig` schema everyone reads; all-off = M1.0 baseline). Merge to `main` before opening the rest.
2. **BUG1** (`duration_s` real) → **BUG2** (within-band depth) — **sequential** (both touch `game_state.gd`).
3. **Before the parallel fan-out:** pre-declare on `main` (via TEL) the new `event_bus.gd` signals — `depth_changed` + all 7 opposition signals (hazard_awoke/caught, return_cost_incurred, exposure_crossed/penalty, nav_branch_taken/lost_proxy) — so wave-2 agents never touch `event_bus.gd`.
4. **CFG / TEL / BUG3** — parallel worktrees (disjoint files).

**Wave 2:** R1/R2/R3/R4 in 4 parallel worktrees (each reads `active_run_config` + live depth, emits pre-declared signals; none edit `event_bus.gd`/`game_state.gd`). Each opposition's first sub-step = its `game-director-designer` spec (`design/M1_1_Tasks/R<n>_*.md`). **R2's mechanism (lengthen/decay-behind/egress-toll): the R2 spec proposes, Director reviews before build.**

**Wave 3:** RG1 build → *(human playtest)* → RG2 analysis vs M1.0 baseline → RG3 verdict.

Run the **wave close-out deviation sweep** after Wave 1 and after Wave 2 (Director dispositions each).
**Also open (independent, Todo):** FU1 `test_jsonl_writer` · FU2 `EconomyMath`.

## (archived) ▶ prior next-action — Director chose path A (iterate); M1.1 planned + approved 2026-06-19
The **M1 feedback gate (G4) has run** (2026-06-19, 34 runs over 3 sessions). **Verdict: ITERATE.** Full
evidence + recommendation: `design/M1_Tasks/G4_findings.md`. Headline: the greybox loop is engaging
(11 runs/session, run length median ~18s right in the target window) and the carry/capacity decision works, **but
the core push-your-luck tension does not exist** — 30 extract / 2 death / **0 timeout**; the Director's read:
"no risk … the optimal strategy is to go as far as possible, fill up, and run back … nothing prevents going
deeper (no maze complexity, no hazards, no enemies)." M1 deferred every risk source to M2/M3, so the loop has a
reward axis but no cost axis. The gate did its job — it caught this before M2 breadth.

**Director's call needed — pick the iterate path:**
- **A (recommended)** — a focused **M1.5 iteration**: add the minimum greybox risk that scales with depth
  (a pursuing/awakening hazard; a costlier/longer return the deeper you go; a rising instability/exposure meter;
  clock-that-bites + return cost — pick 1–2, greybox), then **re-run G4**. De-risk the core before breadth.
- **B** — proceed to **M2** (vertical slice already includes the first enemy + real systems) and validate the
  tension there; log M1's gate as "mechanically sound, tension unproven." Faster, but spends M2 effort on an
  unproven core.

Once the Director picks A or B, plan it (tasks + board) and dispatch.

**Open bug backlog (filed from G4, Todo):** BUG1 `duration_s`=0 · BUG2 within-band depth untracked · BUG3
open sockets to off-map void. **Tech-debt follow-ups (Todo):** FU1 `test_jsonl_writer` · FU2 `EconomyMath`.
These are independent of the A/B call and can be picked up anytime (BUG1/BUG2 improve the next G4's telemetry).

## (archived) ▶ prior next-action — wave-5 close-out + G4 (both now done)
**G1 + G2 + G3 are merged + verified green** (2026-06-18). The **full M1 loop is playable** for the first time:
`scenes/game/main_game.tscn` is `run/main_scene`; spawn → dive → pick up junk → decide push/extract →
bank (extract) or lose-but-pockets (death/timeout) → sell screen tallies junk→Money → restart, repeatedly in one
session (verified by `LOOP OK` + `MAIN GAME OK` headless drives). Telemetry JSONL is live (opt-in); GdUnit4 30/30.
**21/22 M1 tasks done.** All programmable M1 work is complete — the two remaining items are **both human calls:**

1. **Wave-5 close-out (Director dispositions deviations).** `DESIGN_DEVIATIONS.md` holds **15 wave-5 entries**
   (G1 ×5, G2 ×5, G3 ×5). Claude recommends **Reviewed** for all 15, but **two need a genuine Director call**
   because they affect future scope, not just as-built reconciliation:
   - **G1 #2** — telemetry opt-in lives in `user://settings.cfg`, NOT the SaveManager meta schema (the acceptance
     criterion said "via SaveManager"). Keep ConfigFile, or plan a v2→v3 schema bump + migration + fixture?
   - **G3 #1** — no in-build first-run telemetry **consent prompt** (shipped README + settings toggle instead).
     The G3 spec wanted the prompt; without it, G4 telemetry capture risks being empty. Plan a small
     `ui-ux-designer` follow-up to add the prompt **before** the G4 cohort runs, or accept README-only?
   After the Director verdicts, Claude reapplies (likely `M1_As_Built.md` + the G1 schema doc note + playbook 07
   `events.jsonl`→`run_log.jsonl`) and archives all 15 to `DESIGN_DEVIATIONS_HISTORY.md`.

2. **G4 — the M1 feedback gate (the whole point of M1).** *Is the push/cash-out tension fun in 30s of
   decision-making?* This **requires a human**: run the internal playtest (≥ a few testers on the greybox build),
   then record an explicit **go / iterate / pivot** verdict. Claude's role: analyze the G1 telemetry
   (run-length histograms vs the 15-min tier, mid-run abandonment, runs/session > 1.5) and assemble evidence +
   a recommendation — the Director decides. **Claude cannot self-run this gate.**
   - To get the build to *remote* testers, the **publish pipeline is human-gated**: provision a studio itch.io
     project + `BUTLER_API_KEY` repo secret + the real channel slug in `nightly.yml`'s `ITCH_TARGET`, and install
     the Godot 4.6.3 Windows export templates. For an *internal* playtest on the dev machine, none of that is
     needed — run `godot project.godot` and play `main_game.tscn` directly.

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

## ▶ Next action — M1.2 design LOCKED; dispatch Wave 1 build (I1 / BUG4 / I5)
**M1.2 (Legibility & Level Scale)** is the iteration on M1.1's playtest. The **three-phase authoring process** (CLAUDE.md)
ran end-to-end: Phase 1 breakdown (`design/M1_2_Tasks/M1.2_Breakdown.md`), Phase 2 six per-task design docs
(I1/BUG4/I5/I2/I4/I3 — research + pseudocode + open questions), Phase 3 fresh-eyes resolution (different role than each
author; caught real blind spots: I1 loot mis-placement under scaling, I5 stale-binary root cause, I2 body==hall geometry,
I4 non-compositing mechanism). **Director dispositioned all flagged items 2026-06-19 → design LOCKED.**

**Key Director verdicts folded into the docs:** I1 = size multiplier **+** count knob **+ newly authored larger greybox
pieces** (scope expanded; +environment-artist builder) · I2 hazard = **refuge** (walls block, shrink + better steering) ·
all I3/I4/I5/I2-polish defaults accepted (sweepable). Each `design/M1_2_Tasks/<id>_*.md` ends with a "Director Disposition (FINAL)".

**▶ Wave 1 — Spatial & data foundation (dispatch next, parallel worktrees, file-disjoint):**
- **I1** (general-purpose + environment-artist) — `lvl_` RunConfig knobs (count + size mult) + generator threading +
  `junk_placer.gd` loot-scale fix + CFG/TEL pickup **+ new larger greybox pieces** (B1 sockets). Spec: `I1_level_scale.md`.
- **BUG4** (general-purpose) — geometry-keyed seal (cap every outward non-floor neighbour); fingerprint-safe. `BUG4_robust_seal.md`.
- **I5** (qa) — CI regression-lock for `duration_s` + bake real HEAD SHA (drop stale `config/build_sha`). `I5_telemetry_hygiene.md`.
Watch: I1 owns `run_config.gd` + `band_generator.gd` + `main_game.gd` (size-mult materialise) — confirm BUG4/I5 are disjoint (they are: `socket_sealer.gd` / `telemetry.gd`+`version.gd`).

**Then Wave 2** (I2 hazard ∥ I4 vision ∥ I3 cues — watch the I2/I4 `main_game.gd` collision), **Wave 3** re-gate
(RG1 build → playtest → RG2 → RG3). Run the wave close-out deviation sweep after each wave.

---

## (M1.1 done) HUMAN PLAYTEST GATE — M1.1 build complete; playtested → ITERATE → M1.2
**M1.1 is BUILT.** Wave 1 (foundations) + Wave 2 (the four oppositions R1–R4) + RG1 (playtest build) are all on `main`
(`c4c71b8`), verified green. The depth-scaled **cost axis is live, configurable, and config-marked in telemetry**;
all-off reproduces the M1.0 baseline exactly (the permanent control). RG1's verify driver passed 16/18 matrix rows headless.

**▶ NEXT = the Director plays the build (Claude cannot self-run this).**
Run it on the dev machine: `godot project.godot` → play `scenes/game/main_game.tscn` (it's `run/main_scene`).
- The **Config menu** (side rail on the main menu) toggles R1–R4 + every knob; "reset to baseline (all off)" = M1.0 control.
- Set a `build_tag` label per sweep; **enable telemetry** at the first-run consent prompt so runs are captured.
- Sweep configs (the R-specs' suggested presets are starting points): R1-only, R2-only (egress_toll/clock S1–S3),
  R3-only (soft A / hard B), R4-only (S1 branchy / S2 foggy / S3 maze), then stacked. Use "Back to Config" on the sell
  screen to switch configs mid-session; Continue to quick-re-run the same config.
- Telemetry JSONL lands at `user://telemetry/run_log.jsonl`. Full how-to: `tools/playtest/tester_readme.md`;
  manual matrix + subjective checklist: `tools/playtest/loop_smoke_checklist.md`.

**Then Claude resumes (RG2 → RG3):**
- **RG2** — analyze the playtest JSONL: end-cause / run-length / max-depth distributions **per config**, per-opposition
  event frequencies, side-by-side vs the all-off M1.0 baseline; does the cost axis create a real outcome spread?
- **RG3** — assemble RG2's evidence + a **recommendation** into `G4_findings_M1.1.md`; the **Director records the
  go/iterate/pivot verdict** (go→M2; iterate→M1.2 via this template; pivot→design rework).

**Open (independent, Todo):** BUG4 (SocketSealer branch-rate-independent seal — non-blocking, before any high-branch
sweep) · FU1 `test_jsonl_writer` · FU2 `EconomyMath`. **Wave 3 close-out** (disposition W3-RG1-1/2 + any RG2/RG3 findings)
runs after the re-gate.

**Shared as-built contract briefed to all four** (specs predate BUG2 merge — these are the real names):
live depth = `GameState.current_depth_index`; max = `GameState.max_depth_reached`; dist home = `GameState.current_dist_to_gate`
(NOT `current_depth` — that's the stuck band-entry counter); `EventBus.depth_changed(depth_index, max_depth)`; player is
already in the `"player"` group; `RunConfig` enums are plain `@export_enum` **ints (no named consts)**; `run_t_ms` on
hazard_caught/exposure_crossed is TEL-stamped (emit 0); all opposition/penalty signals pre-declared (emit only, never edit
`event_bus.gd`); run-end via existing `fail_run(&"death"|&"timeout")` (call, never edit `game_state.gd`).

**After Batch A+B integrate:** Wave 2 close-out deviation sweep (Director dispositions), then **Wave 3** re-gate
(RG1 build → human playtest → RG2 analysis vs M1.0 baseline → RG3 verdict). RG1 wires R2/R3 run-state nodes into the dive scene.

**Wave-5 close-out — COMPLETE (2026-06-18).** All 16 wave-5 deviations (G1×5, G2×5, G3×5, G6×1) dispositioned by
the Director: **1 Addressed** (G3 #1 → built G6, the in-build consent prompt) / **15 Reviewed**. Reapplied to
`M1_As_Built.md` (new **§Telemetry (G1/G6)** + scope bumped to wave 5) and **Playbook 07** (`events.jsonl`→
`run_log.jsonl`, GdUnit4 runner note); all 16 archived to `DESIGN_DEVIATIONS_HISTORY.md`. `DESIGN_DEVIATIONS.md`
is empty (between-waves). Two optional follow-ups now tracked as **FU1** (GdUnit4 `test_jsonl_writer`) + **FU2** (static `EconomyMath`
helper) in `TASKS.md` §M1 follow-ups + board (Todo). (The Butler/itch publish pipeline stays a human-provisioning
note in the archive, not a tracked task — Director's call 2026-06-19.)

**Then G4** = the human fun-gate (internal playtest on the dev machine: `godot project.godot` → play
`main_game.tscn`). Claude preps `tools/playtest/loop_smoke_checklist.md` + analyzes telemetry after, recommends a
go/iterate/pivot verdict; the Director decides.

## Blocked
| Task | Blocked by | Note |
|---|---|---|
| ElevenLabs/PixelLab live generation | human | Connected; calling them spends paid credits — get human OK before a generation run. |

> **M1 design decisions resolved by the human Director (2026-06-15)** — recorded in
> `design/M1_Tasks/M1_Design_Decisions.md`. Both prior human-judgment items are now decided:
> `Item`→`JunkItem` **merge** (became the schema task below); `max_light = 60` confirmed.

## Done (M1.1 — Greybox Cost Axis)
| Task | Proof |
|---|---|
| RG1 — Playtest build (risk active) | merged `c4c71b8`; `tests/test_rg1_loop_verify.tscn` → **RG1 BUILD VERIFY OK** (16/18 matrix rows headless: V1–V4 isolation, V5 stacked, V6/V7 all-off=M1.0, V8–V11 four end-causes, V12–V16/V18 loop+telemetry integrity; 6 deferred to human checklist); R2 `ReturnCost` + R3 `ExposureMeter` wired as persistent self-gating nodes (DiveClock injected); "Back to Config" sell-screen button; `tools/playtest/{loop_smoke_checklist,tester_readme}.md` updated; worklog `worklogs/2026-06-19-RG1-general-purpose.md` (impl `6013c07`) |
| R1 — Pursuing/awakening hazard | merged `0c80622`; `tests/test_pursuing_hazard.tscn` → **PURSUING HAZARD OK** (`scenes/hazards/hazard_entity.{tscn,gd}` `CharacterBody2D` on `hazard` layer; DORMANT→AWAKE latch on depth/linger, no re-sleep; toward-player `move_and_slide` chase; distance catch → `fail_run(&"death")` or non-fatal cost; emits `hazard_awoke`/`hazard_caught`); additive spawn seam in `main_game.gd:start_new_run` gated by `r1_enabled` (left R4/BUG2/BUG3 intact); worklog `worklogs/2026-06-19-R1-general-purpose.md` (impl `023c346`) |
| R2 — Costlier return trip | merged `b0566c2`; `tests/test_return_cost.tscn` → **RETURN COST OK** (`systems/oppositions/return_cost.gd` run-state node; marginal-per-hop egress toll off live `current_dist_to_gate`; clock/exposure/meter resources via existing public surfaces; decay_behind behind reachability guard + linear self-downgrade; all-off free); RG1 wires the node; worklog `worklogs/2026-06-19-R2-general-purpose.md` (impl `5c1f2a9`) |
| R3 — Exposure meter | merged `b0566c2`; `tests/test_exposure_meter.tscn` → **EXPOSURE METER OK** + **EXPOSURE HUD OK** (`systems/oppositions/exposure_meter.gd`; depth-weighted climb, retreat decay, one-shot crossings, max→`fail_run(&"timeout")`; penalty seams via pre-declared signals: `player.gd` speed-mult + `dive_clock.gd` clock-tax + R4-fog vision-mult; greybox HUD bar in `decision_hud.tscn`); RG1 wires the meter node; worklog `worklogs/2026-06-19-R3-general-purpose.md` (impl `87d2628`) |
| R4 — Maze/navigation risk | merged `b0566c2`; `tests/test_bandgen_determinism.tscn` → **R4 NAV OK** + BANDGEN/SEAL OK (depth-scaled integer branch roll in `band_generator.gd`, contract `fingerprint(seed+config)`, all-off byte-matches M1.0 `e943ac9c8bc1`; `entities/dive/{vision_fog,lost_proxy}.gd` run-state; `nav_branch_taken`/`nav_lost_proxy`); **flagged W2-R4-1** BUG3 seal gap at high branch rates; worklog `worklogs/2026-06-19-R4-general-purpose.md` (impl `b810aa0`) |
| (pre-decl) `depth_changed` on `main` | orchestrator pre-declaration `2450cde` (BUG2 §3 sequencing); EventBus `signal depth_changed(depth_index, max_depth)` — emitted by BUG2, declared once so wave-1/2 agents never edit `event_bus.gd` for it |
| R0 — Run-config data model | merged `30e41b9`; `RunConfig` Resource + `GameState.active_run_config`; all-off default = M1.0 baseline; worklog `worklogs/2026-06-19-R0-*.md` |
| BUG1 — `run_ended.duration_s` real | merged `33eb786`; `tests/test_run_duration.tscn` → **RUN DURATION OK** (`_run_start_ms`+`_elapsed_s()`; >0 & within a frame of direct `Time.get_ticks_msec()` ref for extract/death/timeout, telemetry off); worklog `worklogs/2026-06-19-BUG1-BUG2-general-purpose.md` (impl `cf7e342`) |
| BUG2 — within-band depth tracked | merged `33eb786`; `tests/test_within_band_depth.tscn` → **WITHIN BAND DEPTH OK** (`current_depth_index`/`max_depth_reached`/`current_dist_to_gate` run-state; `set_current_depth()` edge-triggered emit of `depth_changed`; `main_game.gd` cell→depth driver; `run_ended.depth_reached`=max for all 3 end-causes; ratchets on retreat); shared worklog w/ BUG1 (impl `cf7e342`) |
| TEL — Telemetry config-marking + opposition signals | merged `c940ae4`; `tests/test_telemetry_config_marking.tscn` → **TEL CONFIG MARKING OK** (`run_started.data.run_config` snapshot; 7 opposition EventTypes logged, envelope `v=1` no bump, primitives-only; `run_ended` arity unchanged; TEL self-stamps `run_t_ms`); **sole `event_bus.gd` editor** — added the 11 opposition/penalty signals (not `depth_changed`, already on main); worklog `worklogs/2026-06-19-TEL-qa.md` (impl `66ec131`) |
| BUG3 — sealed band (no walk-off-void) | merged `c940ae4`; `tests/test_bandgen_determinism.tscn` → **BUG3 SOCKET SEAL OK** + **BANDGEN OK** (fingerprint byte-identical with/without seal across 9 seeds; no floor cell faces void after seal; non-vacuity guard); new `systems/bandgen/socket_sealer.gd` (RefCounted, zero RNG); 1-line call in `main_game.gd:_materialise_band`; reuses existing WALL tile (no new asset); worklog `worklogs/2026-06-19-BUG3-general-purpose.md` (impl `f0baeae`) |

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
| F1 — Money ledger (`sell_banked_junk`) | merged via F1 branch; `tests/test_money_ledger.gd` → **MONEY LEDGER OK** (sells `banked_junk`→Money at `base_sell_value`, empties bank, one `currency_changed`, source-tagged sell/pockets, empty-bag no-op, persists round-trip); reused existing v2 schema + `add_currency` (no schema bump); worklog `worklogs/2026-06-17-F1-programmer.md` (impl `54f4f59`) |
| F2 — Placeholder sell screen | merged `ce9f51b`; `tests/test_sell_screen.gd` → **SELL SCREEN OK** (presents on `run_ended` extract/death/timeout, "EXTRACTED"/"RUN LOST — kept N", itemized rows, count-up to live `GameState.money`, zero-haul valid); Continue emits `continue_pressed` (G3 wires restart); worklog `worklogs/2026-06-17-F2-ui-ux.md` (impl `ce9f51b`) |
| G1 — Wire M1 telemetry events | merged via `Merge G1`; `tests/test_telemetry_jsonl.tscn` → **TELEMETRY OK** (opt-in respected — no file when off; enabled run wrote 9 parseable JSONL rows w/ duration, end cause, depth, haul banked + dedicated amount-lost-on-fail row); `systems/telemetry/{telemetry,telemetry_schema,jsonl_writer}.gd` + opt-in `settings.cfg`; no `event_bus.gd`/`game_state.gd` edits; worklog `worklogs/2026-06-18-G1-qa.md` (impl `c0c2268`) |
| G2 — Determinism & logic tests (GdUnit4) | merged via `Merge G2`; GdUnit4 v6.1.3 vendored at `addons/gdUnit4/`; `tools/run_gdunit.sh` → **30 test cases · 0 failures · PASSED** (proc-gen determinism, inventory capacity, banking math, death-drop pockets @ 0.20 highest_value); CI gate wired in `.github/workflows/ci.yml` (non-zero exit on failure verified); worklog `worklogs/2026-06-18-G2-qa.md` (impl `3f57f38`) |
| G4 — M1 feedback gate (internal playtest) | **run 2026-06-19** — 34 runs / 3 sessions, build `852b6e2`; verdict **ITERATE** recorded in `design/M1_Tasks/G4_findings.md` (engaging + mechanically sound, but no risk opposes pushing deeper → degenerate dominant strategy; gate caught it pre-M2). Telemetry analyzed from `run_log.jsonl`; surfaced BUG1–3. DoD #6 (recorded go/iterate/pivot verdict) met. *Caveat: single tester — widen cohort if confirmation wanted before iterating.* |
| G6 — In-build telemetry consent prompt (Addressed from G3 #1) | merged via `Merge G6`; `tests/test_telemetry_consent.tscn` → **CONSENT OK** (fresh profile prompts once; Enable→telemetry writes + asked set; Not now→OFF, no file; never re-shows); `systems/settings/telemetry_consent_prompt.gd` + `Settings.get/set_telemetry_asked()`; shown once at `main_game` launch before gameplay, default OFF; worklog `worklogs/2026-06-18-G6-ui-ux.md` (impl `835a97a`) |
| G3 — Greybox playtest build | merged via `Merge G3`; `scenes/game/main_game.tscn` set as `run/main_scene` (first full-loop assembly); `tests/test_loop_drive.tscn` → **LOOP OK** (3 runs/session, run-state resets + meta persists, extract & death paths) + `tests/test_main_game_loop.tscn` → **MAIN GAME OK** (assembled scene: band+pickups+gate, group-based player, interaction pickup + gate extract → sell → clean restart); `start_new_run()` loop entry wires `SellScreen.continue_pressed` (W4-11); player `"player"` group + `get_first_node_in_group` (W4-6); build-id `systems/version.gd` on telemetry `run_started`; `tools/playtest/{loop_smoke_checklist,tester_readme}.md`; `export_presets.cfg` (Win64) + scaffolded `nightly.yml` (**publish human-gated: BUTLER_API_KEY + itch project + export templates**); worklog `worklogs/2026-06-18-G3-programmer.md` (impl `9107a2a`) |

_Integrated `main` re-verified after every merge (full suite green): `--import` clean · **SMOKE OK** · MOVE OK · ZONE PIECES OK · JUNK CATALOG OK · INTERACT OK · DIVE CLOCK OK · BANDGEN OK · INV OK · EXTRACT OK · INV UI OK · BAND DEPTH OK · JUNK PICKUP OK · DEATH DROP OK · DECISION HUD OK · DROP SWAP OK · SAVE MIGRATION OK · MONEY LEDGER OK · SELL SCREEN OK (18 legacy checks) · **TELEMETRY OK** · **GdUnit4 30/30** (G1+G2)._
_Open test-hygiene nit (QA): B2's determinism scene leaks "2 resources still in use at exit" (un-freed PackedScene instances) — cosmetic, non-failing; now that GdUnit4 is vendored (G2), tidy by porting that scene to a GdUnitTestSuite._

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
