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

## M1.4 — Stakes, Variety & Legibility (ACTIVE — iterating on the M1.3 ITERATE verdict)

Give the run real stakes (a per-run quota whose miss wipes you), triple the danger vocabulary (ping-pong, bomb, rotating
spikes), make the camera's visible area + the timer controlled-and-configurable, randomize/multiply the exit, and fix the
movement jitter — then re-gate for a possible "go." Breakdown + dependency map + wave order + locked decisions:
`design/M1_4_Tasks/M1.4_Breakdown.md` (§"Phase 3 Dispositions & Phase 4 Lock"). Provenance: `G4_findings_M1.3.md`.
**Design is LOCKED** — every task doc carries a "Resolved Decisions (Phase 3)" section; Director dispositioned the fun
calls (full wipe; quota = every-run-end × cumulative-money). Greybox; all-off `RunConfig` stays the permanent baseline
(fp=e943ac9c8bc1); the fun values ship in `make_default_play_preset()`.

### Wave 1 — Foundation + low-risk  *(K0 first & alone, then K3+K6 ∥ K4)*

### K0 — Foundation: knob + signal pre-declare (+ K1 retune)
- Milestone: M1.4 (Wave 1)   Assignee: general-purpose   BlockedBy: none
- Spec: `design/M1_4_Tasks/K0_foundation_knobs_signals.md`
- Goal: single-writer pass on `run_config.gd` + `event_bus.gd` + `config_menu.gd`: declare all 35 M1.4 knobs (off/neutral) + extend `to_flat_dict()` + declare the new signals + CFG rows/CSV stubs; apply the **K1** preset retune (`r1_speed_per_depth→3.0`, `r1_catch_radius_per_depth→1.0`); remove dead `light_low()`. Unblocks the parallel build.
- Done when: project imports clean; all-off fp byte-identical (e943ac9c8bc1); CFG menu boots; knob-count tests green (46→81); every new knob in `to_flat_dict()`.

### K3+K6 — Resolution-independent camera + jitter fix
- Milestone: M1.4 (Wave 1)   Assignee: general-purpose (+ character-animator for K6 feel)   BlockedBy: K0
- Spec: `design/M1_4_Tasks/K3_resolution_independent_camera.md` + `design/M1_4_Tasks/K6_movement_jitter.md`
- Goal: ONE combined `project.godot` (`[display]` `canvas_items`/integer/`expand` + `[physics]` `physics_interpolation=true`) + camera change (reparent off the body to a level-owned rig; `CameraView` driving fixed visible world-units from `cam_*` knobs). Default-off reproduces today's FOV + framing; render-time only (fp unaffected).
- Done when: visible world-units are window-resolution-invariant; jitter gone; default-off = byte-identical M1.3 look; all-off fp unmoved.

### K4 — Configurable timer + near-end warning
- Milestone: M1.4 (Wave 1)   Assignee: general-purpose (+ ui-ux for HUD cue)   BlockedBy: K0
- Spec: `design/M1_4_Tasks/K4_configurable_timer_warning.md`
- Goal: `timer_length_s` RunConfig override (`0.0`⇒`DiveClockConfig.max_light`); a one-shot near-end `dive_clock_warning(seconds_remaining, maximum)` (latched like `_fired_timeout`) + a HUD visual cue (~10s default, audio gated/M2-stub). Drop dead `light_low()` connect.
- Done when: timer length is configurable; the warning fires once near the end with a HUD cue; all-off = today's clock; fp unmoved.

### Wave 2 — Stakes & spatial  *(K2 → K7 sequential; both touch main_game/game_state)*

### K2 — Quota system + roguelite wipe
- Milestone: M1.4 (Wave 2)   Assignee: general-purpose (+ game-director-designer economy, ui-ux HUD/Game-Over, qa fixture)   BlockedBy: K0
- Spec: `design/M1_4_Tasks/K2_quota_system.md`
- Goal: per-run quota (start $50, +$50/run, configurable); meet → run-number++ + quota++; **miss = full meta wipe** (Director FINAL). Checked **every run end**, met by **cumulative money** (both swept knobs, these defaults). Save META v2→v3 + migration + `meta_v2.sav` fixture; HUD quota readout; Game-Over → wipe → fresh start.
- Done when: quota gates every run end; miss wipes meta (verified); run-number/quota escalate + reset-on-wipe; migration + fixture green; all-off (`quota_enabled=false`) = M1.3 byte-identical; fp unmoved.

### K7 — Exit placement rework
- Milestone: M1.4 (Wave 2)   Assignee: general-purpose (+ game-director-designer)   BlockedBy: K0 (sequence after K2 on `main_game.gd`)
- Spec: `design/M1_4_Tasks/K7_exit_placement.md`
- Goal: random local-sub-stream (`run_seed ^ EXITS_RNG_SALT`) exit placement; multiple exits; configurable count + depth-scaling; `exit_keep_one_at_spawn` toggle. Default = today's single fixed gate (byte-identical). Preset ships exits OFF.
- Done when: exits place randomly/multiply per config; default = single fixed gate; multi-gate extract safe; all-off fp byte-identical.

### Wave 3 — Danger variety  *(K5a ∥ K5b ∥ K5c → K5i)*

### K5a — Ping-pong hazard
- Milestone: M1.4 (Wave 3)   Assignee: general-purpose (+ character-animator tell)   BlockedBy: K0
- Spec: `design/M1_4_Tasks/K5a_pingpong_hazard.md`
- Goal: greybox bouncer confined to its room (rect-clamp + wall-bounce via `velocity.bounce(n)`), lethal on contact (`fail_run(&"death")`); `hpp_*` config; depth-scaled count (K5i). `setup(cfg, player, spawn_ctx)`.
- Done when: bounces + stays in room + kills on contact; off=M1.0; placement run-state (fp unmoved).

### K5b — Bomb hazard
- Milestone: M1.4 (Wave 3)   Assignee: general-purpose (+ character-animator FX)   BlockedBy: K0
- Spec: `design/M1_4_Tasks/K5b_bomb_hazard.md`
- Goal: `Node2D` proximity bomb: enter `hbomb_trigger_radius` → pulse ~2s (committed) → explode, kills if inside `hbomb_blast_radius`; one-shot; emits `bomb_pulse_started` + shared `new_hazard_killed(&"bomb",…)`; `hbomb_*` config; depth-scaled count (K5i).
- Done when: IDLE→PULSE→EXPLODE works; kills only if inside blast at detonation; off=M1.0; placement run-state (fp unmoved).

### K5c — Rotating-spikes hazard
- Milestone: M1.4 (Wave 3)   Assignee: general-purpose (+ character-animator rotation)   BlockedBy: K0
- Spec: `design/M1_4_Tasks/K5c_rotating_spikes_hazard.md`
- Goal: `Node2D` rotating spikes (3 arms const), analytic distance-to-arm lethal test (`fail_run(&"death")`); steel/cyan tell; `hspike_*` config; deterministic per-instance phase; depth-scaled count (K5i).
- Done when: rotates + kills on arm contact; off=M1.0; placement+phase run-state deterministic (fp unmoved).

### K5i — New-hazard spawn-seam integration
- Milestone: M1.4 (Wave 3)   Assignee: general-purpose   BlockedBy: K5a,K5b,K5c
- Spec: `design/M1_4_Tasks/K5i_hazard_spawn_integration.md`
- Goal: single-writer on the `main_game.gd` spawn seam: descriptor-table dispatch spawning each enabled hazard at a per-room depth-scaled count, reusing the J3 cell helpers; one shared `NEW_HAZARD_BAND_CEILING` (perf). Pure run-state.
- Done when: all 3 hazards spawn depth-scaled per config; combined perf ceiling holds; off=M1.0; all-off fp byte-identical; spawn-seam tests updated.

### Wave 4 — Re-gate  *(sequential; RG2/RG3 after the human playtest)*

### RG1 — M1.4 playtest build + verify
- Milestone: M1.4 (Wave 4)   Assignee: qa-playtest-coordinator   BlockedBy: K0,K2,K3,K4,K5a,K5b,K5c,K5i,K6,K7
- Spec: author from `design/M1_3_Tasks/RG1_playtest_build.md` template
- Goal: assemble + verify the M1.4 loop (preset boots, quota+wipe works, 3 new hazards spawn+kill, exits place, camera fixed, jitter gone, timer warning, config-marked telemetry clean, combined-hazard perf check); **publish to itch** via `bash tools/push_itch.sh`.
- Done when: a fresh build runs the full loop with the fixes; per-run config works; telemetry clean; build live on `qusto/the-far-yard:html5`.

### RG2 — M1.4 telemetry analysis vs M1.0–M1.3
- Milestone: M1.4 (Wave 4)   Assignee: qa-playtest-coordinator   BlockedBy: RG1 + human playtest data
- Spec: template `design/M1_1_Tasks/RG2_telemetry_analysis.md`
- Goal: end-cause / run-length / depth / quota-fail-rate / hazard-kind distributions per config, side-by-side vs all four prior baselines; did stakes + variety + the fixes land?
- Done when: an analysis artifact comparing distributions across configs + all four baselines, with a clear read.

### RG3 — M1.4 re-gate verdict (Director decides)
- Milestone: M1.4 (Wave 4)   Assignee: qa-playtest-coordinator (assembles) → Director (decides)   BlockedBy: RG2
- Spec: template `design/M1_1_Tasks/RG3_regate_verdict.md`
- Goal: record go/iterate/pivot in `design/M1_4_Tasks/G4_findings_M1.4.md`. go → M2; iterate → M1.5; pivot → design rework.
- Done when: a recorded go/iterate/pivot verdict backed by config-marked telemetry, comparable to the prior findings.

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

---

## Backlog (M2+)
Pulled forward when M1.x passes its gate. See TDD §7: M2 (vertical slice: full day loop, recipe repair, first enemy, real art for one band), M3 (bands 1–3, currencies/tracks, exposure crises), M4 (Act 3 + endings), M5 (polish/ship). The **economy workbook** `design/economy_model.xlsx` (game-director-designer) is due **before M3**.
