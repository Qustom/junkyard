# RG1 — M1.4 Playtest Build (Stakes, Variety & Legibility — the fun stack made the default)

**Task id:** RG1 · **Milestone:** M1.4 (Stakes, Variety & Legibility) · **Workstream:** the re-gate · **Wave:** 4 (sequential, after Waves 1–3 integrate)
**Assignee:** `general-purpose` (build assembly — integrated across Waves 1–3) + the verify matrix
**dependsOn:** **K0, K1** (Wave 1) + **K3, K6, K4** (Wave 1) + **K2, K7** (Wave 2) + **K5a, K5b, K5c, K5i** (Wave 3) all integrated on `main`
**Companion docs:** `M1.4_Breakdown.md` (§"Phase 3 Dispositions & Phase 4 Lock" — the Director's FINAL decisions), `M1_3_Tasks/RG1_playtest_build.md` (the template this mirrors), `M1_1_Tasks/RG1_playtest_build.md` (the original verify-matrix shape), `M1_Tasks/M1_As_Built.md` (canonical APIs), the M1.4 task specs (`K2_*`, `K3_*`, `K4_*`, `K5a/b/c_*`, `K5i_*`, `K7_*`), `scenes/game/main_game.gd` (the assembled loop + the `_spawn_new_hazards` K5i seam), `data/run_config/run_config.gd` (`make_default_play_preset()`)

> **This is the VERIFY + DOCUMENT + TUNE task, not new gameplay.** Every M1.4 system (K0–K7) was built and merged in Waves 1–3. RG1 (a) sets `make_default_play_preset()` to the full M1.4 fun stack, (b) proves the assembled loop boots into it and runs every feature individually + stacked, (c) confirms the all-off control is still byte-identical to the M1.0–M1.3 baseline (fp `e943ac9c8bc1`), (d) confirms config-marked telemetry carries all 81 knobs, and then (e) hands the Director a playable build (published to itch) + config-sweep guidance for the re-gate (RG2/RG3).

---

## 1. Goal & design intent

**Goal:** assemble + verify **one runnable M1.4 build** that proves the Stakes/Variety/Legibility iteration runs end-to-end — the build **boots into the fun config** (the M1.4 named play-preset): the **roguelite quota** is the headline stake (K2), the **resolution-independent camera** fixes the FOV (K3), the **dive timer + ~10s near-end warning** make the clock a real stake (K4), the **three new greybox hazard types** (ping-pong / bomb / rotating-spikes — K5a/b/c via the K5i spawn seam) add danger variety, **physics interpolation** removes jitter (K6), and **exits ship OFF** for a clean re-gate (K7) — and that **config-marked telemetry writes** (all 81 knobs in the snapshot, the new EventBus signals firing) so the re-gate can analyse it against the M1.0–M1.3 baselines.

The loop RG1 must run, unbroken, repeatedly in a session — the **exact M1.3 spine**, now with the M1.4 systems layered on and the **fun config as the boot default**:

```
main_game  →  Config menu (boots seeded with make_default_play_preset(); tune/Reset)  →  Start
   →  dive (R1 hazards + DENSITY · R4 maze · NEW hazards: ping-pong / bomb / spikes · 60s dive clock w/ ~10s warning · fixed-FOV camera)
   →  one of four end-causes:  extract  |  death (hazard catch / new-hazard kill)  |  timeout (clock)  |  lost
   →  QUOTA CHECK at every run end (cumulative money ≥ target?) — MISS = full roguelite WIPE
   →  bank (extract) OR pockets (fail)  →  sell screen tallies junk→Money
   →  Continue (re-run same config)  OR  Back to Config (switch config)  →  fresh dive
```

**Design intent (one line):** *RG1 is the M1.4 integration + verification + fun-preset-tune capstone, not a new system* — it takes the file-disjoint Wave-1/2/3 systems (K0 config schema, K1 retune, K2 quota+wipe, K3 camera, K4 timer, K5a/b/c+K5i hazards, K6 jitter fix, K7 exits) and confirms they (a) compose in the single `main_game` scene without conflict, (b) the build **boots into** the M1.4 fun preset, (c) each system individually takes effect, (d) all-off **still** reproduces the M1.0–M1.3 baseline EXACTLY (fp=`e943ac9c8bc1`, byte-unmoved), and (e) every run emits a config snapshot carrying all 81 knobs + the right opposition/event rows. RG1 does **not** answer the fun gate — that is RG2 (analysis) → RG3 (verdict, `G4_findings_M1.4.md`).

---

## 2. What's already wired (Waves 1–3 — do NOT rebuild)

The M1.4 build assembly was done by the Wave-1/2/3 builders; RG1 inherits it. Key seams (verified present by `tests/test_rg1_m14_verify.gd` + the per-K unit suites):

- **K0 config schema** (`run_config.gd`) — all new knobs declared with all-off-neutral code defaults: K2 `quota_*` (5), K3 `cam_*` (3), K4 `timer_*` (4), K5a `hpp_*` (5), K5b `hbomb_*` (7), K5c `hspike_*` (6), K7 `exit_*` (5). `to_flat_dict()` serialises every one; the knob count is **81** (`test_run_config` + `test_config_menu` pin it). The CFG menu MANIFEST/SECTIONS/FIELD_RANGE rows + CSV stubs exist for every new knob.
- **K0 EventBus signals** — `quota_evaluated`, `quota_advanced`, `meta_wiped(prev_run_number)`; `dive_clock_warning(seconds_remaining, maximum)` (dead `light_low()` removed); `camera_view_set`; `bomb_pulse_started(depth, run_t_ms)`; the shared `new_hazard_killed(kind, depth, run_t_ms)`.
- **K2 quota + wipe** (`game_state.gd` + save schema v2→v3 + migration + `meta_v2.sav` fixture) — quota is META-state; checked at EVERY run end; "met" basis is cumulative money ≥ target; a miss = FULL roguelite wipe. The CONFIG knobs (`quota_enabled/base/step/check_timing/basis`) are run-scoped; the live quota + run-number are meta.
- **K3 camera + K6 jitter** (`project.godot` + a level-owned camera rig) — `physics_interpolation` on; the camera reparented to a rig; `cam_*` gives a fixed visible-world width (resolution-independent FOV). Pure presentation: `cam_*` never feed `fingerprint()`.
- **K4 dive timer + warning** (dive-clock + HUD) — `timer_length_s` overrides the DiveClockConfig length; `timer_warning_threshold_s` fires `dive_clock_warning` ONCE near the end; `timer_warning_channel` = visual_only (audio M2-gated).
- **K5a/b/c entities** (`scenes/hazards/pingpong_hazard.gd`, `bomb_hazard.gd`, `spike_hazard.gd`) — greybox `Polygon2D` tells, analytic per-frame lethal tests (the R1 convention), each emitting `new_hazard_killed` + routing death through `GameState.fail_run(&"death")`. Bomb is committed/no-defuse; spikes = 3 arms (in-file const); steel/cyan tell vs the warm hazards.
- **K5i spawn seam** (`main_game.gd` `_spawn_new_hazards`) — one descriptor per type (kind/path/enabled/base/per_depth/cap), dispatched over the SAME J3 cell helpers (`_density_pieces_sorted`/`_density_sorted_cells`/`_density_cell_to_world`). FULLY GATED: all `*_enabled` false → no scene loaded, no node → all-off byte-identical (fp UNMOVED). A SINGLE band-wide accumulator (`NEW_HAZARD_BAND_CEILING = 48`) bounds K5a+K5b+K5c COMBINED, in the documented **starvation order pingpong → bomb → spike** (later types get fewer when the budget runs low). Placement is pure run-state (no RNG, never feeds fingerprint()).
- **K7 exits** (`main_game.gd`) — `exit_*` random local-sub-stream placement (deterministic via `run_seed ^ salt`). All-off default = today's single fixed gate at `GATE_SPAWN_OFFSET`, byte-identical.

**The run/meta boundary stays intact:** `RunConfig` (incl. every M1.4 knob + the preset) is run-scoped, never persisted; Money + `banked_junk` + the quota/run-number persist (K2's meta schema v3); the default play-preset is a **separate artifact** built on a fresh `RunConfig.new()`, not the code-level all-off default.

---

## 3. RG1 deliverable: the M1.4 fun preset (`make_default_play_preset()`)

RG1 ADDS the M1.4 fun stack on top of the M1.3 base preset (LVL+R1+R4 maze-only, R2/R3 off, K2 quota, K3 camera — already present). The exact values set (per the Phase-3 Director dispositions):

| System | Knobs set in the preset | Source |
|---|---|---|
| **K4 timer** | `timer_enabled=true`, `timer_length_s=60.0`, `timer_warning_threshold_s=10.0`, `timer_warning_channel=0` (visual_only) | Director FINAL: "~10s warning on a 60s dive, visual-only for RG1 (audio M2-gated)". |
| **K5a ping-pong** | `hpp_enabled=true`, `hpp_base_count=0`, `hpp_count_per_depth=0.15`, `hpp_speed=70.0`, `hpp_per_room_cap=2` | sweep-START magnitudes; cap MANDATORY > 0. |
| **K5b bomb** | `hbomb_enabled=true`, `hbomb_base_count=0`, `hbomb_count_per_depth=0.15`, `hbomb_proximity_radius=64.0`, `hbomb_pulse_seconds=2.0`, `hbomb_blast_radius=48.0`, `hbomb_per_room_cap=2` | committed/no-defuse; ~2s pulse (Director); sweep-START. |
| **K5c spikes** | `hspike_enabled=true`, `hspike_base_count=0`, `hspike_count_per_depth=0.15`, `hspike_rotation_speed=90.0`, `hspike_arm_length=48.0`, `hspike_per_room_cap=2` | 3 arms (const); sweep-START. |
| **K7 exits** | `exit_enabled=false` (untouched) | Director: "preset ships exits OFF for a clean re-gate." |
| (K2 quota / K3 camera) | already in the M1.3-base preset (quota $50 +$50/run, cumulative, every-run-end; camera 576px fit_width) | unchanged. |

**Sweep-start tuning note (a real RG1 finding, documented here):** the three new hazard types share a single 48-body band ceiling in starvation order (pingpong → bomb → spike). On the default deep band (19 rooms, ~15 depths), an aggressive magnitude (e.g. `base_count=1`, `count_per_depth=0.5`, `per_room_cap=2`) lets **pingpong alone saturate the 48 ceiling and starve spikes to ZERO** — the Director could never evaluate spikes in the default. The shipped preset therefore uses **modest** sweep-starts (`base_count=0`, `count_per_depth=0.15`, `per_room_cap=2`), which yield a balanced **≈9 / 9 / 9** (total ≈27, comfortably under 48) so the re-gate sees all three. Pushing the magnitudes up is a valid RG1 sweep, but the SHIPPED default must let every type spawn. (Asserted by `test_rg1_m14_verify`: ≥1 of each kind under the preset.)

**Invariants held:** the preset is built on a fresh `RunConfig.new()` and never mutates the code-level all-off default (all K4/K5/K7 masters stay OFF and caps stay 0 on a fresh config); the all-off band fingerprint stays `e943ac9c8bc1`; `inert_enabled_oppositions()` stays empty (the new hazards are not R-oppositions and the preset values are provably non-inert). K4/K5/quota/camera/exit knobs are pure run-state and never feed `fingerprint()`.

---

## 4. Verify matrix (M1.4)

RG1 is **done** only when this matrix passes. It separates **objective build checks** (headless-automatable by `tests/test_rg1_m14_verify.tscn`) from **subjective fun signal** (RG2/RG3 + human). The headless driver mirrors the M1.3 `test_rg1_m13_verify` shape: it instances the REAL `main_game.tscn`, drives configs through the build's own `start_new_run()`, and also drives the build's own deterministic K5i spawn-plan math directly so the spawn counts + caps + ceiling are asserted EXACTLY.

### 4.1 Per-feature isolation

| # | Feature | Expected observable | Headless assertion |
|---|---|---|---|
| **K2 quota + wipe** | quota ON, cumulative, every-run-end | A missed quota at run end WIPES meta (run resets to 1, target 0); a met quota advances. | Quota LOGIC + the v2→v3 migration are covered by the K2 unit suite + the `meta_v2.sav` fixture; the WIPE *felt* moment is **human-deferred** (checklist). |
| **K3 camera** | `cam_enabled`, fixed 576px width, fit_width | The visible world width is constant regardless of window resolution. | `test_camera_view` covers the view math; the rendered FOV is **human-deferred** (no render headless). |
| **K4 timer warning** | 60s dive, `dive_clock_warning` fires once at ~10s | The HUD shows a near-end warning ~10s before timeout. | Preset shape (timer ON, length 60, warning 10, visual_only) asserted; the visible warning cue is **human-deferred**. |
| **K5a/b/c hazards** | all three ON, spawn + kill | ping-pong bounces, bomb pulses then explodes, spikes rotate; each lethal on contact. | `_spawn_new_hazards` / the K5i descriptor path spawns ≥1 of EACH kind under the preset; bounded by per_room_cap + the 48 band ceiling; deterministic; the assembled scene materialises real `PingPongHazard`/`BombHazard`/`SpikeHazard` nodes in `BandContainer`. **HEADLESS PASS.** Visual tells + kills are **human-deferred**. |
| **K6 jitter** | physics_interpolation on, camera on a rig | Motion is smooth, no camera jitter. | `project.godot` flag + rig wiring covered by the K6 merge; the *felt* smoothness is **human-deferred**. |
| **K7 exits** | preset ships exits OFF | Today's single fixed gate; fp unmoved. | Preset `exit_enabled=false` asserted; `test_exit_placement` covers the ON path; the all-off fp stays `e943ac9c8bc1`. |

### 4.2 Stacked + baseline control

| # | Config | Expected | Headless assertion |
|---|---|---|---|
| **Default preset** | `make_default_play_preset()` (the boot config) | The build boots into the full M1.4 fun stack; loops end-to-end; trap-free; does not leak into the all-off control. | Preset shape (M1.3 base + K4 + K5×3 + K7-off); `inert_enabled_oppositions()` empty; `RunConfig.new()` still all-off after building the preset; CFG `apply_and_get_config()` at boot is the M1.4 stack. **HEADLESS PASS.** |
| **All-off baseline** | **All OFF** | Loop behaves identically to M1.0–M1.3; the generated band is **byte-identical** to the locked baseline. | All-off RunConfig band fp == `e943ac9c8bc1` (== rc-null baseline); building the preset does not move it. **HEADLESS PASS — the determinism guard.** |
| **Reset** | "Reset to baseline" (CFG) | All 81 knobs return to all-off. | Covered by `test_config_menu` (Reset returns the all-off baseline, 81/81 knobs). |

### 4.3 End-cause reachability + telemetry integrity

| # | Check | Expected | Headless |
|---|---|---|---|
| **End-causes** | extract / death / timeout (+ quota_fail wipe) reachable | extract + timeout observed in `run_ended` rows (death/new-hazard kills exercised by the per-K suites); sell screen presents; Continue loops. | **PASS.** quota_fail reuses the locked `run_ended` arity (wipe is a separate meta op). |
| **Snapshot / 81 knobs** | Config snapshot per run carries the **full 81-knob key set incl. the K2/K3/K4/K5/K7 knobs** | Every `run_started.data.run_config` has all `to_flat_dict()` keys + explicitly the new M1.4 keys. | **PASS** (asserted as a SET, not a magic count — the 81 count is pinned by `test_run_config`/`test_config_menu`). |
| **`run_ended` arity intact** | M1.0 `data` fields present; `duration_s > 0` on every run. | — | **PASS.** |
| **Schema locked** | No row carries a bumped telemetry `SCHEMA_VERSION`. | Every row `v == TelemetrySchema.SCHEMA_VERSION`. | **PASS.** (K2's META save schema bumps to v3 — that is the SAVE schema, NOT the telemetry schema.) |

### 4.4 Subjective (NOT RG1 — handed to the human via RG2/RG3)

> "Does the quota wipe feel like a real stake (not punishing-then-tedious)?", "is the ~10s warning legible?", "do the three new hazards read distinctly + teach their telegraph?", "is the combined danger fun or chaotic?", "is the motion smooth (K6)?" — RG1 only guarantees the build *lets a human experience and the telemetry capture* these. The fun read is RG3 (Director), backed by RG2's distribution analysis.

---

## 5. Headless verification — proven vs. human-deferred

`tests/test_rg1_m14_verify.tscn` (driver `test_rg1_m14_verify.gd`) runs the matrix and prints `RG1 M1.4 VERIFY OK` on success, exiting non-zero on any failure (CI-gateable).

**Headless-verified (11 rows):** baseline-fp-unmoved (the determinism guard) + preset-does-not-move-it · default-preset-shape (M1.3 base + K4 60s/10s/visual-only + all three K5 on with per_room_cap>0 + K7 off) · trap-free + no-leak-into-default · `to_flat_dict()` carries every K-knob · K5i spawn-plan (≥1 of each kind, bounded by per_room_cap + the 48 ceiling, deterministic) · CFG-boots-the-preset · assembled-spawn (real `PingPongHazard`/`BombHazard`/`SpikeHazard` nodes in `BandContainer`) · 3 driven configs each with snapshot + gating · extract + timeout end-causes · `run_ended` arity + `duration_s>0`.

**Human-deferred (rendering / felt — on the manual checklist):**
- K2: a missed quota WIPES meta (the run resets) — the headline stake.
- K3: the camera shows a fixed FOV regardless of window size.
- K4: the ~10s near-end timer warning fires VISUALLY on a 60s dive.
- K5a/b/c: ping-pong / bomb-pulse / rotating-spikes read distinctly + kill on contact.
- K6: motion is smooth (physics_interpolation), no camera jitter.
- K7: exits ship OFF (single fixed gate) for this re-gate build.
- OQ-3 perf (carry-forward): the worst-case combined-body band holds frame rate (see §7).

---

## 6. Config-sweep guidance for the Director (the re-gate experiment plan)

The re-gate question (RG3): **now that the quota stake, the dive clock, and the three new hazards are in the default, is the loop a "go"?** The build boots into the M1.4 preset, so the **first sweep is just "play the default."** Then set each config in the Config menu, type a `build_tag`, and run a handful of runs per config (the snapshot self-labels every run). Suggested sweep, in order:

1. **Baseline control (`build_tag: m14-baseline`).** All-off (the menu's **Reset**). A few runs — the permanent M1.0–M1.3 control RG2 segments everything against (byte-identical band, fp `e943ac9c8bc1`).
2. **The default preset, as shipped (`build_tag: m14-default`).** Just **Start** from the boot config. The headline cell — "is the M1.4 stack fun out of the box?" Several runs.
3. **K2 quota sweep (`build_tag: m14-quota-*`).** Vary `quota_base` {25, 50, 100}, `quota_step` {25, 50}, `quota_check_timing` (on_extract vs every_run_end), `quota_basis` (this_run_banked vs cumulative). Answers "is the wipe a stake or a wall?"
4. **K4 timer sweep (`build_tag: m14-timer-*`).** Vary `timer_length_s` {45, 60, 90} and `timer_warning_threshold_s` {5, 10, 15}. Answers "is the clock pressure right; is the warning legible?"
5. **K5 hazard sweep (`build_tag: m14-haz-*`).** Vary per-type `*_count_per_depth` {0.15, 0.3, 0.5}, `*_per_room_cap` {1, 2, 3}, and each type's signature knob (`hpp_speed`, `hbomb_proximity_radius`/`blast_radius`, `hspike_rotation_speed`/`arm_length`). **Watch the 48 band ceiling** — pushing any type up starves the later types in the starvation order (pingpong → bomb → spike). Toggle types off one at a time to read each in isolation.
6. **K7 exits sweep (`build_tag: m14-exit-*`).** Turn `exit_enabled` on and vary `exit_base_count`/`exit_count_per_depth`/`exit_max_count`/`exit_keep_one_at_spawn`. (Shipped OFF; this is the "do multiple exits help legibility" probe.)
7. **Everything stacked (`build_tag: m14-all-on`).** The default preset + R2/R3 + aggressive hazards. The "is the whole stack, maxed, fun or chaotic" cell.

**Pin a seed (`seed_override ≥ 0`) for A/B comparisons**; leave it `−1` to vary per loop for distribution data. **`build_tag` convention:** prefix every sweep tag with `m14-`, then a short config handle. The full 81-knob `run_config` snapshot on every `run_started` row is ground truth; `build_tag` is the human-readable handle RG2 groups on.

---

## 7. OQ-3 carry-forward — combined-body worst-case perf

OQ-3 (Director-flagged): the worst case stacks R1's density budget (`R1_DENSITY_BAND_CEILING = 64`) with the new-hazard budget (`NEW_HAZARD_BAND_CEILING = 48`) for **up to ~112 `_physics_process` bodies** in one band. Each is a lightweight analytic-distance test (no physics overlap, no pathfinding), but the combined per-frame cost is the perf question.

- The two ceilings are independent and BOTH enforced (R1 keeps its 64; the new hazards share 48), so the count is bounded by construction — it cannot exceed 112 regardless of the magnitude sweeps.
- **Headless tick-time probe:** a headless `--headless` run cannot measure true frame pacing (it has no render/vsync loop), so a precise worst-case ms-per-tick figure is **a Director-playtest check**, not a headless number. The build self-reports `duration_s` per run and the telemetry captures the run, so a perf regression in a 112-body run would surface as a long/janky run in the log. **Recommended Director check:** run the `m14-all-on` cell at `lvl_size_mult 40` with aggressive hazard magnitudes (max out both budgets) and confirm the frame rate holds; if it dips, lower the per-type caps (the budgets are the throttle).

---

## 8. Acceptance criteria (M1.4)

1. **A fresh build runs the complete M1.4 loop**, boots into the default play-preset, end-to-end, no blockers — `RG1 M1.4 VERIFY OK`.
2. **Each system takes effect** (K2 quota+wipe, K3 camera, K4 timer warning, K5a/b/c hazards, K6 jitter, K7 exits) — verified individually + stacked (headless where possible, human-deferred for the felt/rendered).
3. **The all-off control reproduces the M1.0–M1.3 baseline exactly** (fp `e943ac9c8bc1` unmoved; the preset never mutates the code-level default).
4. **Telemetry logs config + events** with all 81 knobs in the snapshot, schema v1 (telemetry) intact, `run_ended` arity locked, `duration_s > 0` on every completed run.
5. **Multiple runs per session, no leaked nodes.**
6. The build + this doc + the updated tester_readme are **ready for the Director's playtest** (published to itch; RG2/RG3 follow).

A build that passes the §4 matrix (headless `RG1 M1.4 VERIFY OK` + the human checklist) and ships the updated tester readme satisfies RG1. Done means: the matrix is filled, the worklog names the commit SHA, the build launches + loops with the M1.4 fun stack as the boot default, all three new hazards spawn, and the config-marked telemetry writes.

---

## 9. Resolved Decisions (pointer)

The Director's FINAL dispositions for M1.4 are in `M1.4_Breakdown.md` §"Phase 3 Dispositions & Phase 4 Lock (2026-06-21 — design LOCKED)". RG1 honours them verbatim: quota = full wipe / every-run-end / cumulative; camera expand+fit_width default-off-FOV; jitter physics_interpolation + camera rig; timer ~10s/60s visual-only; hazards committed-bomb / 3-arm-spikes / magnitudes-are-RG1-sweeps; exits ship OFF. The one RG1-authored call — the **specific** sweep-start hazard magnitudes — was chosen to fit all three types under the shared 48 ceiling (§3 tuning note); the magnitudes themselves remain Director sweeps.
