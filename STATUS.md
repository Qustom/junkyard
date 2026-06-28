# STATUS — THE FAR YARD

**Resume point — read this first.** Where the orchestrator picks up after any interruption, with no other
context. Holds only *current* work: what's in progress (and how to continue it), what's blocked, the immediate
next action. Full task queue → `TASKS.md`; board mirror → GitHub Projects; completed tasks → `TASKS_COMPLETED.md`;
superseded status history → `STATUS_ARCHIVE.md`. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.7 (Player Embodiment) — **DESIGN LOCKED (Phases 0–4 done); build NOT started.** Replace the greybox player with the `player_basic_template` sprite (8-dir walk/pickup/throw/idle) in Hub + Dive + a debug toggle to disable the art. **Next = dispatch N0 (art import + SpriteFrames + signal).** *(M1.6 build+RG1 done; its RG2/RG3 re-gate is Director-pending, non-blocking — M1.7 is Director-directed content opened ahead of that verdict.)*
**Last updated:** 2026-06-27 (M1.7 authored: breakdown + N0/N1/N2 per-task designs + fresh-eyes resolution + Director dispositions folded; `TASKS.md`/`STATUS.md` wired. Ready for the build wave.)

> **⚙ Repo layout (since 2026-06-27):** the **Godot project is under `Game/`**; repo root holds only design/docs/meta
> (`design/`, `worklogs/`, `*.md`, `changelog.txt`, `.github/`, dotfiles). Run godot with **`--path Game`** (or `cd Game`);
> `res://…` paths are unchanged. Publish: `bash Game/tools/push_itch.sh` (self-locates). CI uses `working-directory: Game`.
> Design-doc/worklog filesystem paths written before this date gain a `Game/` prefix (e.g. `systems/…` → `Game/systems/…`);
> their `res://…` references are still valid as-is.

---

## ▶ Next action (start here on a cold restart) — M1.7 WAVE 1: ✓N0 ✓N1 → **N2 (next)** → RG1

> **M1.7 (Player Embodiment) — design LOCKED; N0+N1 built+integrated; N2 is the last build task.** Director-directed: the
> `player_basic_template` art (8-dir walk/pickup/throw + idle-from-rotations) is now on the player, driven off the existing
> `facing`/`aim`/`velocity`/`junk_picked_up`/`item_thrown` seams. Breakdown `design/M1_7_Tasks/M1.7_Breakdown.md`; per-task
> designs `N0/N1/N2_*.md` (LOCKED, with `Resolved Decisions` + `Director Disposition`). **Invariants (held through N1):**
> all-off fp `e943ac9c8bc1` unmoved · 89-knob count holds · art-OFF = M1.6 byte-for-byte · collision r=14 +
> `player_movement.tres` untouched · art COPIED not moved · filter-off pixel art, LFS.
>
> **▶ Dispatch N2** (`design/M1_7_Tasks/N2_debug_player_art_toggle.md`): a view-only "Player art (debug)" `CheckButton` on the
> `config_menu` **Meta tab** (default checked = art ON, session-only) → emits `EventBus.debug_player_art_toggled` → the N1
> `PlayerVisual._on_art_toggled` swaps `AnimatedSprite2D` ↔ greybox. **NEVER added to `_rows`/MANIFEST** (keeps 89-knob
> coverage + fp). Then **RG1** build + verify + itch publish + changelog → Director playtest → RG2 → RG3 in
> `design/M1_7_Tasks/G4_findings_M1.7.md`.
>
> **✓ N0 DONE (2026-06-27)** — `main`@`07edb77`. 152 PNGs copied `art_workshop`→`Game/art/player/` (source intact) +
> `player_frames.tres` (32 clips) + EventBus `debug_player_art_toggled`. Worklog `…-N0-general-purpose.md`.
> **✓ N1 DONE (2026-06-27)** — `main`@`47ab9a8`. `PlayerVisual` child + `AnimatedSprite2D` (scale 0.45, y=-18, z=10);
> greybox `Visual`/`Nose` retained hidden; 8-way FSM (`quantize_dir`+`select_state` pure helpers, `test_player_visual` green);
> accepted-only clip-driven movement-lock with `@export` knobs (`lock_on_pickup`/`play_pickup_on_reject`/`lock_mode`/
> `lock_duration_cap_s`/`fixed_lock_s`). DoD green: helper test · scene-loads(32 clips) · smoke · fp `e943ac9c8bc1` · 89/89 ·
> movement test. **RG1 manual item:** confirm on-screen anim in BOTH scenes + lock-feel + scale/offset seat (headless can't).
> Worklog `…-N1-general-purpose.md`. 0 deviations.

---

## (Director-pending, non-blocking) M1.6 re-gate — RG2 → RG3

> **RG1 feedback fixes (2026-06-27, applied direct — gate green, re-published `m1-20260627-a1097fd`):** Director playtest
> surfaced 3 items → fixed on `main`@`a1097fd`. **FB1** the "[F] extract" prompt was hidden behind the gate door — lifted the
> world `InteractionPrompt` above geometry (`z_index=100`, `z_as_relative=false`) + made the HUD `ExtractPrompt` derive its
> glyph from the real `interact` binding (stale "E"→"F"). **FB2** quota always MISSED — the `cumulative_money` basis read
> `money` only, but M1.6 holds the haul unsold until the Shop and `evaluate_quota_on_return()` fires pre-sale → `achieved=0`;
> fix: cumulative basis = `money + _held_haul_value()` (0 on the sell path, unchanged there) + new quota Case 7 regression.
> **FB3** current quota not visible — the K2 `QuotaLabel` was anchored bottom-right with `have=money` only; moved it top-right
> **under the Holding label** and made `have = money + run_haul_value()` (live, matches what banks toward the quota).
> **FB4** added an on-screen **controls list** to the hub HUD (move/aim/throw/cycle/interact-extract/pause/debug-menu,
> kb+mouse+controller) + **updated `changelog.txt`** (THE HUB: controls list + HUD quota readout note). Latest build
> `m1-20260627-41106de`. Gate green: fp `e943ac9c8bc1` · 89/89 · router/loop/save-v4/shop/m15/quota/smoke. Worklog
> `…-RG1FB-claude.md`. **Re-test the new build.**

> **✓ RG1 DONE + PUBLISHED (2026-06-26)** — `main`@`aea0bb7`, board=Done. Build-verify doc
> `design/M1_6_Tasks/RG1_playtest_build.md` + M1.6 changelog block; full verify matrix green (router · shop · save v1/v2/v3→**v4**
> · m15 preset fp `e943ac9c8bc1` · 89/89 · loop). No new test (existing suite covers the gate — QA call). **Published to itch:**
> `qusto/the-far-yard:html5 @ m1-20260626-aea0bb7` (Chrome/Edge, password-gated: https://qusto.itch.io/the-far-yard).
>
> **▶ DIRECTOR PLAYTEST (human-gated — headless can't drive mouse/keyboard/the felt loop).** Play the published build:
> Main Menu (New wipe-confirm / Continue gated / Settings placeholder / first-run consent) · walk the Hub (no clock) ·
> portal→dive→auto-return · quota-miss wipe-on-return notice · Shop SELL tally + BUY spend + owned/can't-afford + **persistence
> across quit/relaunch** · P-overlay in all 3 states + in-dive pause + 7 tabs + Vision split + Meta-tab Export-telemetry · and
> the gate question: **does it read as a game now?** Export telemetry (in-game button on web). Watch-items: shop upgrade effects
> are stubs (do testers buy with no visible effect?); Settings is a placeholder. Full checklist: `RG1_playtest_build.md` §4.5.
>
> Then **RG2** (qa telemetry/flow analysis vs M1.0–M1.5) → **RG3** verdict (go → M2 milestone / iterate → M1.7 / pivot) in
> `design/M1_6_Tasks/G4_findings_M1.6.md`. Claude assembles + recommends; the Director plays + decides.

> **✓ M1.6 BUILD COMPLETE (2026-06-26)** — all 5 build tasks (M0·M1·M2·M4·M3) integrated on `main`@`f47d8fc`, pushed,
> board=Done. The full surface loop runs: **boot → Main Menu (New/Continue/Quit/Settings) → walkable Hub → Shop (sell+buy)
> + departure portal → Dive → auto-return to Hub**; clock dive-only; P-key 7-tab debug menu (Vision split out); persistent
> upgrades (META **v4**). Integrated gate green: import · smoke · router · config_menu **89/89** · run_config 89 · fp
> **`e943ac9c8bc1`** byte-match · save-migration **v1/v2/v3→v4** (`owned_items` round-trips) · shop_economy · quota · loop ·
> 4 RG verifies. **Wave-3 (M3) close-out: 0 deviations.** Watch-items (non-blocking): shop upgrade effects are stubs
> (`effect_kind=&"none"` — RG2 watch DR-M3-2: do testers buy with no visible effect?); orphan `ui/sell/sell_strings` locale
> entry left in `project.godot` (CSV kept; harmless; minor tech-debt). Follow-ups filed: **FU3** (repair/retire m13),
> **FU4** (keyboard-only aim).

> **▶ Wave 4 = RE-GATE.** **RG1** (qa): author `design/M1_6_Tasks/RG1_playtest_build.md` from the M1.5 template; update
> `changelog.txt` (M1.5→M1.6 delta: main menu, walkable hub, sell+buy shop, P-tab debug menu); run the full M1.6 verify
> matrix; **publish to itch** `BUTLER=/mnt/c/wsl-libraries/butler/butler bash tools/push_itch.sh` (Chrome/Edge, password-gated;
> network/human-gated). Then **Director playtest** the surface loop → **RG2** telemetry/flow analysis → **RG3** verdict
> (go → M2 milestone / iterate → M1.7 / pivot) in `design/M1_6_Tasks/G4_findings_M1.6.md`.

---

## (archived) M1.6 build waves — done (full detail in worklogs + `DESIGN_DEVIATIONS_HISTORY.md`)

- **Wave 1 (M0, `52d6e17`)** — persistent root `App` router (new `run/main_scene`) + 8 EventBus signals + neutral `GameState`
  economy surface + quota-decouple + staged-config accessor + `debug_menu_toggle`=P + greybox stubs. 0 deviations.
- **Wave 2 (M1 ∥ M2 ∥ M4, `40d328d`)** — Main Menu (`bbc61ff`) · walkable Hub + `main_game` dive-only refactor + hub-return
  quota/wipe (`7c5391e`) · P-tab debug menu + Vision split, 89-coverage byte-identical (`1d0c0dc`). Parallel worktrees,
  file-disjoint, conflict-free. Close-out: 3 items all **Reviewed** (W2-F1 m13 stale→FU3, W2-F2 quota banner→M3, L6-F1→FU4).
- **Wave 3 (M3, `f47d8fc`)** — Hub Shop sell+buy + 3-item persistent catalog + META **v3→v4** (migration + `meta_v3.sav`
  fixture) + SellScreen retired + quota-MISS notice. Close-out: 0 deviations.

---

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
