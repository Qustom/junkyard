# STATUS — THE FAR YARD

**Resume point — read this first.** Where the orchestrator picks up after any interruption, with no other
context. Holds only *current* work: what's in progress (and how to continue it), what's blocked, the immediate
next action. Full task queue → `TASKS.md`; board mirror → GitHub Projects; completed tasks → `TASKS_COMPLETED.md`;
superseded status history → `STATUS_ARCHIVE.md`. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.0 → M1.1 → M1.2 → M1.3 (DONE → ITERATE) → **M1.4 (Stakes, Variety & Legibility) — design LOCKED (Phases 0–4 done); build NOT started; next = dispatch Wave 1 (K0 first).**
**Last updated:** 2026-06-21 (M1.3 re-gated → **ITERATE → M1.4**. M1.4 authored via the full four-phase process: breakdown + 10 per-task designs + fresh-eyes resolution + Director dispositions, all in `design/M1_4_Tasks/`. Design LOCKED. Next: **dispatch M1.4 Wave 1 — K0 foundation first (alone), then K3+K6 ∥ K4.** Breakdown + locks: `design/M1_4_Tasks/M1.4_Breakdown.md` §"Phase 3 Dispositions & Phase 4 Lock".)

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

## ▶ Next action (start here on a cold restart) — **M1.4 Wave 4: re-gate (RG1 build+verify → Director playtest → RG2 → RG3)**

Waves 1–3 done (K0,K1,K2,K3,K4,K5*,K6,K7). **Wave 4 = the re-gate** (`design/M1_4_Tasks/` RG1 spec / M1.1 RG1 template). **RG1** (`general-purpose` + `qa`): author the M1.4 RG1 build+verify doc, set `make_default_play_preset()` to the M1.4 fun stack, assemble the runnable loop, verify each feature individually + stacked, confirm config-marked telemetry, **publish to itch** (`bash tools/push_itch.sh`, `BUTLER=/mnt/c/wsl-libraries/butler/butler` — human-gated on real network, Chromium-only). **RG1 carry-forward (OQ-3 action 2): measure worst-case ~112-body (R1's 64 + new 48) headless tick-time on the web build — don't assume it.** Then **RG2/RG3 are HUMAN-GATED**: Director plays a config sweep, `qa` analyses telemetry vs the M1.0/M1.1/M1.2/M1.3 baselines, Director records go/iterate/pivot in `G4_findings_M1.4.md`.

> ⏸ **BUILD HELD after Wave 3 at the Director's request (2026-06-21).** All M1.4 features (Waves 1–3) are integrated + pushed; nothing mid-flight. **Resume by dispatching RG1** (the step above) on the Director's go.

> **Wave-3 close-out DONE (2026-06-21).** 1 deviation **W3-F1** → Director: **Addressed** — guarded the K5b test cleanup with `is_instance_valid` (`tests/test_bomb_hazard.gd`); `test_bomb_hazard` now runs clean (`BOMB HAZARD OK`, exit 0, **0 SCRIPT ERROR**). Archived → `DESIGN_DEVIATIONS_HISTORY.md`. `DESIGN_DEVIATIONS.md` empty between waves. Deferred (RG1 sweep/Director-taste, no action now): `NEW_HAZARD_BAND_CEILING=48` value; OQ-4 deterministic-vs-sub-stream striping; K7 preset `exit_*` (ship OFF); worst-case ~112-body tick-time check → RG1 checklist.

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
