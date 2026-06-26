# STATUS — THE FAR YARD

**Resume point — read this first.** Where the orchestrator picks up after any interruption, with no other
context. Holds only *current* work: what's in progress (and how to continue it), what's blocked, the immediate
next action. Full task queue → `TASKS.md`; board mirror → GitHub Projects; completed tasks → `TASKS_COMPLETED.md`;
superseded status history → `STATUS_ARCHIVE.md`. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.6 (Surface & Staging) — **design LOCKED + wired; build NOT started.** Main menu + walkable hub (sell+buy shop replacing SellScreen) + P-key tabbed debug menu, under a Menu→Hub→Dive→Hub `App` router. **Next = dispatch Wave 1 (M0 foundation).**
**Last updated:** 2026-06-26 (M1.5 re-test → **RG3 ITERATE → M1.6**; four-phase authoring DONE: breakdown + M0–M4 per-task designs + fresh-eyes Resolved Decisions on `main`, pushed. Director dispositioned the scope calls: buy = **persistent → META v3→v4 save bump**; telemetry-export → P-debug Meta tab; New-Game-over-save = wipe-with-confirm; Settings = placeholder. Router = persistent root `App` node; `main_game.tscn` → dive-only; clock dive-only; 89-knob count holds, fp `e943ac9c8bc1` unmoved. `TASKS.md`/board/`STATUS.md` wired for M1.6; M1.5 archived.)

---

## ▶ Next action (start here on a cold restart) — M1.6 WAVE 2 (M1 ∥ M2 ∥ M4) IN PROGRESS

> **✓ Wave 1 (M0) DONE (2026-06-26)** — `main`@`52d6e17`, pushed, board=Done. Persistent root `App` router (new
> `run/main_scene`) swapping Menu/Hub/Dive + persistent DebugOverlay; 8 EventBus signals; neutral `GameState` economy surface
> (`owned_items`/`purchase`/`owns`) + `evaluate_quota_on_return()` + `stage_dive_config()`/`dive_config_or_default()` +
> `App.goto_hub()`/`current_state` (router exposed via group `&"app_router"`, not a signal/autoload); v3→v4 migration skeleton
> (META_SCHEMA_VERSION stays **3** — M3 bumps); `debug_menu_toggle`=P; greybox menu/hub stubs; `test_app_router`. Gate green:
> import · smoke · router · run_config 89 · config_menu 89/89 · fp `e943ac9c8bc1` unmoved. Worklog `…-M0-…`. 0 deviations.
> **M0 seam-notes for M2:** router loads `main_game.tscn` as-is and does NOT auto-start; M2 strips the embedded
> MainMenu/Start/ConfigMenu, self-starts `_ready`→`start_new_run` reading `GameState.dive_config_or_default()` via
> `stage_run_config()`, removes the SellScreen auto-present, keeps the programmatic `start_new_run()` the RG tests drive; the
> Hub-return controller reads `returned_to_hub(reason)` → `evaluate_quota_on_return()` (+ `wipe_meta()` on miss) before re-arming the portal.

> **In progress (2026-06-26):** **Wave 2** dispatched — **M1** (`scenes/menu/*`, replaces stub), **M2** (`scenes/hub/*` +
> `main_game.*` dive-only refactor + run-end→hub quota/wipe routing + test fallout), **M4** (`ui/config/config_menu.*`:
> P-overlay + 7 tabs + r4_ vision split + telemetry-export Meta tab). File-disjoint parallel worktrees; board=In Progress.
> On each return: verify branch topology (qa git-switch leak) → gate (import · smoke · router · 89/89 · fp `e943ac9c8bc1`) →
> merge → push → board Done. Then **Wave 3 (M3)**.

Design is **locked + wired** (breakdown `design/M1_6_Tasks/M1.6_Breakdown.md` §"Phase 3 Dispositions & Phase 4 Lock"; every
task doc carries a "Resolved Decisions (Phase 3)" section; Director verdicts folded in). `TASKS.md` carries the M1.6 queue;
board items exist (Todo). Begin the build:

1. **Claim + dispatch M0** (`general-purpose`, Wave 1, solo — single-writer of `game_state.gd`/`event_bus.gd`/`project.godot`/
   new `scenes/app/app.*`). Set M0 → **In Progress** on the board (`PVTI_lAHOAAXnOs4BasyMzgw7Dvk`). Spec:
   `design/M1_6_Tasks/M0_foundation_router_economy.md`. Builds the persistent root `App` router (new `run/main_scene`), the 8
   new EventBus signals, the neutral `GameState` economy surface + quota-decouple + staged-config accessor + `App.current_state`,
   the `debug_menu_toggle`=P input, and throwaway greybox `main_menu`/`hub` stubs so `main` stays bootable. **No save bump in M0**
   (M3 lands v3→v4). **No RunConfig knob** → fp `e943ac9c8bc1` + 89-knob count must stay intact.
2. **Verify + integrate M0**, then **Wave 2 parallel** (file-disjoint worktrees): **M1** (`scenes/menu/*`) ∥ **M2**
   (`scenes/hub/*` + `main_game.*` dive-only refactor + run-end→hub quota/wipe routing + test fallout) ∥ **M4**
   (`ui/config/config_menu.*`: P-overlay + 7 tabs + r4_ vision split + telemetry-export Meta tab). Verify branch topology
   before each merge (qa git-switch leak).
3. **Wave 3** (sequential): **M3** (Shop sell+buy + `ShopItem`/`ShopCatalog` `.tres` + META v3→v4 bump/migration/fixture +
   retire `ui/sell/*`, mounted into the Wave-2 Hub). Then **Wave 4 re-gate** (RG1 build+verify+publish → Director playtest →
   RG2 → RG3).

> **Standing contracts (M1.6):** all-off `RunConfig` default = permanent baseline (fp `e943ac9c8bc1`); **89-knob count holds**
> (M1.6 adds no lever knob; M4 regroups only); Money/owned purchases are meta, in-dive haul is run-state; save bump v3→v4 lands
> in M3 (migration + `meta_v3.sav` fixture); `run_ended` arity locked (the router observes it, never changes it); M0 is the sole
> writer of `game_state.gd`/`event_bus.gd`/`project.godot`/`app.*`; clock is dive-only; verify branch topology before every merge
> (qa git-switch leak); push + board mirror after every merge; wave close-out deviation sweep.

## ✓ M1.5 — Agency & Legibility — DONE 2026-06-24..26 (re-gated → ITERATE → M1.6)

All waves built + re-gated (L0–L6 + RG1 + post-RG3 tuning): agency-throw + room-bound pursuer + legibility fixes + the L6
mouse-aim/twin-stick control rework. Director re-test → **RG3 ITERATE → M1.6**. Detailed in-progress notes archived →
`STATUS_ARCHIVE.md`; tasks → `TASKS_COMPLETED.md`; re-gate provenance → `design/M1_5_Tasks/G4_findings_M1.5.md`. **L6-F1**
(keyboard-only-no-mouse aims DOWN) carried to the M1.6 backlog (mouse + controller unaffected; non-blocking).

---

## ✓ Wave 2 (Oppositions retuned to the new canvas) — DONE (2026-06-19)

All three integrated on `main`, verified, pushed, board = Done. Determinism unmoved (fp=e943ac9c8bc1); none touched `main_game.gd`.
- **I2** hazard refuge fix (shrink body r10 + anti-wall-stick + depth-scaled catch + `r1_catch_radius_per_depth` knob, CFG 36/36) — merge `1966145`.
- **I3** R2/R3 cues (exposure ramp+ticks+penalty banner; return-cost pulse+floating −N; optional shake; all-off=M1.0 HUD) — merge `9b5d75d`.
- **I4** vision/fog rework (radial-dark occlusion ~0.94 + 3-state fog + lost edge-pulse/"DISORIENTED"; R4-off=M1.0) — merge `d56674d`.

Close-out: 0 formal deviations; 1 finding (W2.2-F1: R2 `exposure` toll fired its cue but didn't charge R3's meter — no `add()` on `exposure_meter.gd`) → Director: **fix now** → **BUG5** filed + dispatched.

---

## ✓ M1.2 DONE — re-gated, verdict ITERATE (2026-06-19)

Director playtested the RG1 build (33 runs, `ba745e1`). RG2 (`design/M1_2_Tasks/G4_findings_M1.2.md`): run-length ~2×
M1.1 (26.4s median), depth to 17, three-way end-causes (real hazard deaths), `duration_s` clean (I5 works). RG3 verdict:
**ITERATE → M1.3.** Director decisions + new issues (BUG6 hazard-spam, R3/R4 config traps) recorded in §5 of that doc.

## ✓ M1.3 Wave 1 (Foundation & correctness) — DONE (2026-06-19)

All 5 on `main`, verified, pushed, board=Done; all-off fp byte-identical (e943ac9c8bc1). Close-out: 2 Reviewed + 1 Addressed (history).
- **J5** depth counter → `Depth {depth_index} / {max}` via `depth_changed` — `50d8faf`.
- **BUG6** `hazard_caught` one-shot latch + `inert_enabled_oppositions()` warn-only traps — `ed176bf`; refined to maze-aware `r4_no_effect` (`25072f6`).
- **DLV2** in-game `JavaScriptBridge` telemetry-export button on the sell screen (web-guarded) — `2b00a09`.
- **DLV1** itch HTML5 delivery (Web preset + `push_itch.sh` + web templates + nightly slugs) — `02ad951`. ⚠ **real butler push human-gated** (sandbox can't reach `broth.itch.ovh`; run `tools/push_itch.sh` per SETUP §1a).
- **J1** `make_default_play_preset()` (19 rooms, size 4.0, R1 on, **R4 maze-only / occlusion OFF = match-played**, R2/R3 off) + `RANGE_MULT=[4.0,40.0]` — `3159aac` (+ `25072f6`).

## ✓ M1.4 Wave 1 — DONE (2026-06-21)

K0 + K3/K6 + K4 all on `main`, pushed, board=Done; all-off fp byte-identical (`e943ac9c8bc1`); 81 knobs.
- **K0** foundation (`74034bc`+`02b8a00`): 35 new knobs off/neutral + `to_flat_dict()` + 7 new signals + removed dead `light_low()` + CFG rows (46→81) + K1 retune (`r1_speed_per_depth→3.0`, `r1_catch_radius_per_depth→1.0`). Worklog `worklogs/2026-06-21-K0-general-purpose.md`. **Deviation for close-out:** K0 doc RD-1/RD-6 dropped the two quota enums (would be 79) but the Phase-4 Lock KEPT them → 81 as-built (reconcile the doc).
- **K3+K6** camera + jitter (`f3147d2`): `[display]` (canvas_items/integer/expand, base 1152×648) + `[physics]` `physics_interpolation=true`; camera reparented off the player to a level-owned `CameraRig`/`CameraView` (`entities/dive/camera_view.gd`) driving fixed visible-world-width from `cam_*`. Default-off = today's framing byte-for-byte. **Deferred check:** jitter-gone + fixed-FOV *look* are render-time, confirm in RG1 playtest on >60Hz hardware.
- **K4** timer + warning (`878fe1f`): `timer_length_s` override + one-shot `dive_clock_warning` latch + HUD visual cue + gated audio stub. All-off = today's clock.

## ✓ M1.4 Wave 2 (Stakes & spatial) — DONE (2026-06-21)

K2 + K7 both on `main`, pushed, board=Done; all-off fp byte-identical (**e943ac9c8bc1**); 81 knobs (0 new RunConfig fields — K0 pre-declared both groups). Wave-2 close-out: **0 deviations** (swept → `DESIGN_DEVIATIONS.md` empty).
- **K2** quota + roguelite wipe (merge `65a6cdf`): per-run quota (preset $50 +$50/run, every-run-end × cumulative-money, both swept knobs), miss = full **9-field meta wipe**; save META **v2→v3** + migration + `meta_v2.sav` fixture; HUD quota readout + SellScreen "QUOTA MISSED" + MainGame Continue→`wipe_meta()`→fresh start; Q8 `run_started` quota stamp. Verified: v1→v3 & v2→v3 migrations green, `test_quota_system` green. Worklog `worklogs/2026-06-21-K2-general-purpose.md`.
- **K7** exit placement (merge `8d9c884`): single fixed gate → 1..N gates, depth-scaled count, Strategy-A local-sub-stream random placement (`run_seed ^ EXITS_RNG_SALT`), `exit_keep_one_at_spawn` pin. Pure run-state — **no save/schema change**. Default/preset = today's single fixed gate (exits OFF). `test_exit_placement` green. Worklog `worklogs/2026-06-21-K7-general-purpose.md`.
- *qa git-switch leak recurred on BOTH builds; agents self-cleaned; topology verified clean before each merge (qa-agent-git-switch-leak memory holds).* 

## ✓ M1.4 Wave 3 (Danger variety) — DONE (2026-06-21)

K5a + K5b + K5c (parallel) + K5i (integration) all on `main`, pushed, board=Done; all-off fp byte-identical (**e943ac9c8bc1**); each entity RNG-free; node counts bounded by `NEW_HAZARD_BAND_CEILING=48`. All three ran as clean parallel worktrees (zero file overlap). qa git-switch leak recurred on each; agents self-cleaned; topology verified clean before every merge.
- **K5a** ping-pong bouncer (merge in `50ba1a7` chain): `CharacterBody2D`, straight travel + wall-reflect within `room_bounds`, distance kill, amber tell. `res://scenes/hazards/pingpong_hazard.tscn`. Worklog `2026-06-21-K5a-general-purpose.md`.
- **K5b** committed proximity bomb: proximity-arm (no-defuse) → pulse → detonate within `hbomb_blast_radius`; idle/amber/orange-red tells. `res://scenes/hazards/bomb_hazard.tscn`. Worklog `2026-06-21-K5b-general-purpose.md`. *(test emits harmless `queue_free`-on-freed stderr → **W3-F1**, awaiting Director disposition.)*
- **K5c** anchored rotating spikes: 3 arms (const), analytic point-to-segment kill (no CollisionShape2D), deterministic phase from `spawn_ctx.phase_salt`, steel/cyan tell. `res://scenes/hazards/spike_hazard.tscn`. Worklog `2026-06-21-K5c-general-purpose.md`.
- **K5i** spawn-seam integration (merge `91be51f`): `_spawn_new_hazards` sibling of `_spawn_r1_hazards`, descriptor table (pingpong→bomb→spike starvation order), per-room count `base+floor(per_depth*depth)` capped per-room + shared 48 ceiling, per-kind `spawn_ctx`, pure-deterministic; R1's `_density_spawn_positions` untouched (golden-guard added). `test_new_hazard_spawn` green. Worklog `2026-06-21-K5i-general-purpose.md`.

## ✓ M1.4 Wave 4 — RG1 build+verify — DONE (2026-06-21)

RG1 on `main` (merge `0da631f`; build commits `183d19f`/`aa58a99`), pushed, board=Done. **Director lifted the Wave-4 hold → RG1 built + verified + published to itch.**
- **Preset = M1.4 fun stack:** `make_default_play_preset()` now layers **K4** timer (60s dive / 10s near-end warning / visual-only) + **all three K5 hazards** (hpp/hbomb/hspike ON at RG1 sweep-START magnitudes, each with a mandatory `per_room_cap=2`, balanced ~9/9/9 under the 48 ceiling so all three spawn) on top of the M1.3 base + K2 quota + K3 camera. **K7 exits ship OFF** (Phase-3 lock). All-off code defaults untouched.
- **Headless `test_rg1_m14_verify`** (run as a SCENE: `godot --headless res://tests/test_rg1_m14_verify.tscn`) → **`RG1 M1.4 VERIFY OK`, exit 0**: preset shape, all-off fp byte-identical **`e943ac9c8bc1`**, no-leak into the control, `to_flat_dict()` carries all 81 knobs incl. K4/K5/K7, K5i spawn helper spawns ≥1 of each kind bounded by cap + 48 ceiling, extract/timeout end-causes reachable. 11 rows headless / 7 human-deferred.
- Gates re-run by orchestrator: import clean · smoke OK · run_config 81 · config_menu 81/81.
- Verify doc `design/M1_4_Tasks/RG1_playtest_build.md`; `loop_smoke_checklist.md` + `tester_readme.md` updated. Worklog `worklogs/2026-06-21-RG1-general-purpose.md`.
- **itch published:** `qusto/the-far-yard:html5 @ m1-20260621-...` (Chromium-only, password-gated). *(Re-published post-merge so the live build matches final `main`.)*

> **Board drift flagged (2026-06-21):** the GitHub Project only carries items through M1.1 (R0/CFG); the M1.2/M1.3/M1.4 `J*`/`K*` tasks were never added despite STATUS marking them "board=Done." RG1 item created + set Done (`PVTI_lAHOAAXnOs4BasyMzgwZAFk`); back-filling the ~20 missing items is a Director call (surfaced, not silently done).

> **Wave-4 RG1 close-out (2026-06-21):** 1 deviation flagged by the build agent → **RG1-F1** (the K5 sweep-start magnitudes — chose modest base 0 / per_depth 0.15 / cap 2 so all three hazards spawn rather than pingpong starving spikes at the shared 48 ceiling; the load-bearing constraint "every type must spawn in the default" was held; values are an explicit RG1 sweep the Director delegated). **Awaiting Director disposition** (recommend **Reviewed**). `DESIGN_DEVIATIONS.md` carries it.

## ✓ M1.4 Wave 5 (RG1-feedback bug-fixes) — DONE (2026-06-21)

Director playtested the RG1 itch/desktop build → **RG3 verdict = ITERATE, packaged as an M1.4 bug-wave + re-gate**
(not a full M1.5). RG2 telemetry analysis + 6-item triage in `design/M1_4_Tasks/G4_findings_M1.4.md`. Four file-disjoint
tasks ran as parallel worktrees; all merged to `main`, all-off fp **byte-identical e943ac9c8bc1**, board=Done. Full
suite green (import · smoke · run_config 81 · config_menu 81/81 · rg1_m14_verify · new_hazard_spawn · pingpong · spike ·
exit_placement(_count)).
- **BUG7** (`main_game.gd`, merge `5bcc89b`; fix `a5b1b57`) — **feedback #7 (CRITICAL)**: `_spawn_new_hazards` skips the
  depth-0 entry piece + filters cells within `NEW_HAZARD_SPAWN_SAFE_CELLS=2.5` of the entry-spawn (mirrors
  `_exit_candidate_cells`). `base_count ≥ 1` no longer spawn-kills at frame 0. Telemetry root-cause: `s_384be7` runs 19–47.
- **BUG8** (`pingpong_hazard.gd`, merge `8c2f283`; fix `b11571c`) — **feedback #2**: tracks intended heading `_dir` and
  reflects IT (summed normals at corners), so `move_and_slide`'s tangential mutation never feeds the bounce → no wall-stick.
- **TUNE2** (`run_config.gd` preset + `test_rg1_m14_verify.gd`, merge `17b0e72`; fix `7854ddd`) — **#1** cam 576→**1000**;
  **#3** spikes `base 0→1` / `cap 2→1` so a spike reliably spawns at shallow depth (≈37 hazards combined < 48 ceiling, spikes
  not starved). Added `_driven_default_preset()` (K5 off for the driven end-cause matrix only; full preset still shape-checked).
- **FB5** (new `test_exit_placement_count`, merge `73530d5`; `3e1c95b`) — **#5 VERDICT: NOT a bug.** Multi-exit placement is
  correct (depth-scaled distinct gates scattered across pieces); the Director saw it during the #7 instant-death runs that never
  left depth 1. Regression test added. *Note for Director: exits are placed once per band at build time across its pieces — no
  NEW gates appear as you walk deeper within one band (that'd be a net-new "progressive spawn" feature, K7 DR-7 deferred).*

**#6** (spawn-room-only pursuer) is **deferred to M1.5**, semantics LOCKED by the Director: **slow patrol** — the pursuer
keeps patrolling within its spawn room but never chases the player outside it; chases only while the player is in that room.

### ▶ Next action (start here on a cold restart) — re-publish RG1 to itch, then re-gate

1. **Re-publish the fixed build to itch** (standing playtest-gate step): `bash tools/push_itch.sh` with
   `BUTLER=/mnt/c/wsl-libraries/butler/butler` (Chromium-only, password-gated; SETUP §1a). Human-gated on a real network.
2. **Director re-gate playtest** of the Wave-5 build (camera 1000, spikes now visible, no auto-end, ping-pong unsticks);
   export telemetry; record **go → M2 / iterate → M1.5** in `design/M1_4_Tasks/G4_findings_M1.4.md`.
3. **Wave-5 close-out deviation sweep** (below) — Director dispositions before any M1.5 work.

> **Wave-5 close-out — for Director disposition:** (a) **TUNE2 `_driven_default_preset()`** — the verify driver now
> disables the three K5 hazards for its scripted end-cause matrix because shallow spikes kill the driven player (no
> per-hazard `kills` toggle like R1's `r1_catch_kills`); shape-checks + spawn-checks still run the full preset. Recommend
> **Reviewed** (test-harness accommodation, not a design change) — or Addressed if a `*_kills` toggle is wanted on the K5
> family. (b) **Stale `.tscn` UID drift** — 11 scene files showed pre-existing local UID-regen at session start; current
> `--import` does NOT reproduce them and HEAD builds/tests clean, so they were set aside in `git stash@{0}` (not reapplied,
> not dropped). Recommend dropping the stash unless the Director wants those UIDs investigated.

---

## (superseded) ▶ M1.4 RG2/RG3 re-gate — Director played → ITERATE (see Wave 5 above)

RG1 is done + published. The re-gate now hands off to the **Director**:
1. **Director playtest** — play the itch build (and/or a desktop config sweep) across the M1.4 fun stack + variants; export telemetry (in-game "Export telemetry" button on web; `user://telemetry/run_log.jsonl` on desktop).
2. **RG2 (`qa`)** — analyse the returned telemetry: per-config distributions side-by-side across **M1.0/M1.1/M1.2/M1.3/M1.4**; did stakes (quota+wipe), variety (3 new hazards), and the legibility fixes (camera/timer/jitter) land? **OQ-3 carry-forward:** confirm worst-case ~112-body (R1 64 + new 48) tick-time on the web build is acceptable.
3. **RG3 (Director)** — record **go → M2 / iterate → M1.5 / pivot** in `design/M1_4_Tasks/G4_findings_M1.4.md`. Claude assembles + recommends; the human plays + decides.

Also pending the Director: **RG1-F1 disposition** (above) and the **board back-fill** call.

> **Standing contracts (M1.4):** all-off `RunConfig` default = permanent baseline (fp e943ac9c8bc1); fun values only in `make_default_play_preset()`; config-marked telemetry; `run_ended` arity locked; single-writer-per-`.gd`-file per wave; parallel agents `isolation: worktree`; verify branch topology before every merge (qa git-switch leak — memory); push + board mirror after every merge; wave close-out deviation sweep.

> **Wave-1 close-out sweep DONE (2026-06-21).** 3 deviations dispositioned → archived to `DESIGN_DEVIATIONS_HISTORY.md`:
> K0 count (Reviewed, as-built 81 per Lock) · K3/K6 render-time deferred-checks (Reviewed → RG1 matrix) · **camera now
> ENABLED in the preset** (Addressed: `make_default_play_preset()` → `cam_enabled=true`, `cam_visible_world_width=576`,
> `cam_zoom_policy=fit_width`; smoke OK, all-off fp `e943ac9c8bc1` unchanged).

> ⏸ **BUILD PAUSED after Wave 1 at the Director's request (2026-06-21).** Resume by dispatching **K2** (the first Wave-2
> task) per the step above. Design is locked, Wave 1 is integrated + pushed; nothing is mid-flight.

> **Contracts (M1.4):** all-off `RunConfig` default = permanent baseline (fp=e943ac9c8bc1); fun values ship in
> `make_default_play_preset()`; quota = every-run-end × cumulative-money, miss = full wipe (Director FINAL); config-marked
> telemetry (every knob → `to_flat_dict()` + test counts); `run_ended` arity locked; K0 pre-declares ALL new signals up front;
> single-writer-per-`.gd`-file per wave; parallel agents `isolation: worktree`; **verify branch topology before every merge**
> (qa-agent `git switch` leak — memory); push after every merge; board mirror; wave close-out deviation sweep.

> **Carry-over (non-blocking):** wire `tests/test_rg1_m13_verify.tscn` into the CI test set when convenient; butler push
> stays human-gated on a real network (SETUP §1a, Chromium-only) — relevant again at M1.4 RG1.

---

## ✓ M1.3 — Legibility & Density — DONE 2026-06-21 (re-gated → ITERATE → M1.4)

Waves 1/2 (J1·J2·J3·J4·J5·BUG6·DLV1·DLV2) + RG1 all on `main`; all-off fp byte-identical (e943ac9c8bc1). RG1 (`d9138c7`)
verified (`test_rg1_m13_verify` → **RG1 M1.3 VERIFY OK**), published-gate human. Director playtested → **RG3 verdict ITERATE**;
feedback work-order → M1.4 (`design/M1_3_Tasks/G4_findings_M1.3.md`). Detailed Wave-1/2 in-progress notes archived → `STATUS_ARCHIVE.md`.

---

## ✓ Wave 1 (Spatial & data foundation) — DONE (2026-06-19)

All three integrated on `main`, verified, pushed, board = Done. All-off default still byte-matches the M1.1 baseline (fp=e943ac9c8bc1).
- **I1** configurable level scale (count override + size mult + 4 new larger greybox pieces behind a config-dependent ext catalog) — merge `e67532c`. Worklog `worklogs/2026-06-19-I1-general-purpose.md`. *Empirical: linear spine reached requested count up to 60 — no count ceiling in the realistic range; run-time is the binding constraint (RG1/RG2 tuning).*
- **BUG4** geometry-keyed branch-rate-independent seal — merge `eee4418`. 508 void cells → 0 across 36 high-branch bands; fingerprint byte-identical. Worklog `worklogs/2026-06-19-BUG4-general-purpose.md`.
- **I5** telemetry hygiene (duration loop-re-entry regression-lock + real HEAD-SHA bake, `+dirty`) — merge `1fd657e`. Worklog `worklogs/2026-06-19-I5-qa-playtest-coordinator.md`.

Close-out: 4 deviations (I1-1, I1-2, + 2 lingering M1.1 RG1 entries), **all Director-Reviewed**, reapplied (`M1_As_Built.md` socket-width rule; `RG1`/`CFG` magic-count prose) + archived → `DESIGN_DEVIATIONS_HISTORY.md`. `DESIGN_DEVIATIONS.md` empty between waves.

---

## ▶ Next action (start here on a cold restart) — **finish BUG5, then dispatch Wave 3 (RG1)**

Waves 1 & 2 are on `main` (new spatial canvas + clean telemetry + retuned/legible oppositions). **BUG5 is in flight** (the
last build fix before the re-gate — makes R2's `exposure` toll actually charge R3). When BUG5 returns:
1. **Verify + integrate BUG5** (verify topology first — the Wave-1 stray-`git switch` lesson), push, board=Done, run its mini close-out.
2. **Dispatch Wave 3 — RG1** (`general-purpose` + `qa-playtest-coordinator`): author the M1.2 RG1 build+verify doc from the
   `design/M1_1_Tasks/RG1_playtest_build.md` template; assemble the runnable M1.2 loop; verify each fix individually + stacked;
   confirm config-marked telemetry writes; multiple runs/session. **BlockedBy: I1, BUG4, I5, I2, I4, I3 (all done) + BUG5.**
3. **RG2/RG3 are HUMAN-GATED** — RG1 hands off to a **Director playtest** (sweep configs on a dev machine), then `qa` analyses
   the telemetry vs the M1.0 (all-off) + M1.1 baselines (RG2), and the Director records the go/iterate/pivot verdict in
   `design/M1_2_Tasks/G4_findings_M1.2.md` (RG3). Claude assembles + recommends; the human plays + decides.

> **Collision note for Wave 3:** RG1 is largely additive scene-assembly + a verify test; it touches `main_game.gd` (loop
> wiring) + a new RG1 verify test. It's sequential (single task), so no parallel-collision management needed. Confirm no new
> `event_bus.gd` signal is required (the M1.1 RG1 needed none).

> **Standing process (locked):** parallel agents in `isolation: worktree`; pre-declare any new `event_bus.gd` signal on `main` before a parallel wave; single-writer-per-`.gd`-file; push `main` after every merge; mirror task status to the board; run the **wave close-out deviation sweep** after each wave (Director dispositions). See `CLAUDE.md` orchestrator loop.

**Also open (independent, Todo, non-blocking):** FU1 `test_jsonl_writer` · FU2 `EconomyMath`.

---

## Blocked
| Task | Blocked by | Note |
|---|---|---|
| ElevenLabs/PixelLab live generation | human | Connected; calling them spends paid credits — get human OK before a generation run. |

---

## History (not here — see)
- **Completed tasks** (M0, M1, M1.1, with proof/commits): `TASKS_COMPLETED.md`.
- **Superseded status sections** (M1/M1.1 Done tables, prior next-actions, playtest-gate notes): `STATUS_ARCHIVE.md`.
- **Design history**: `design/` (per-version `M<n>_*_Tasks/`), `DESIGN_DEVIATIONS_HISTORY.md`, `design/M1_Tasks/M1_As_Built.md`.

## Legend
`Backlog → In progress → (Verify) → Done` · or `→ Blocked`. A task is **Done** only with a worklog naming a real commit and its definition of done met.
