# RG1 — M1.2 Playtest Build (legibility + level scale, the cost axis made fair)

**Task id:** RG1 · **Milestone:** M1.2 (Legibility & Level Scale) · **Workstream:** (c) the re-gate · **Wave:** 3 (sequential, after all of Wave 1 + Wave 2 integrate)
**Assignee:** `general-purpose` (build assembly — already integrated) + `qa-playtest-coordinator` (build verification matrix)
**dependsOn:** **I1, BUG4, I5** (Wave 1) + **I2, I4, I3** (Wave 2) + **BUG5** (Wave-2 close-out) all integrated on `main`
**Companion docs:** `M1.2_Breakdown.md` (§3 waves, §4 RG1, §7 DoD), `M1_1_Tasks/RG1_playtest_build.md` (the template this mirrors), `M1_Tasks/M1_As_Built.md` (canonical APIs), the six M1.2 task specs (`I1_level_scale.md`, `I2_hazard_fix.md`, `I3_r2_r3_cues.md`, `I4_vision_rework.md`, `I5_telemetry_hygiene.md`, `BUG4_robust_seal.md`, `BUG5_exposure_toll_mutator.md`), `scenes/game/main_game.gd` (the assembled loop)

> **This is the VERIFY + DOCUMENT task, not new gameplay.** All six M1.2 fixes (+ BUG5) were each built and merged in Waves 1–2. RG1 proves the assembled loop runs every fix individually + stacked, that the all-off control is still byte-identical to the M1.0/M1.1 baseline, and that config-marked telemetry writes clean with the new knobs + a real build SHA — then hands the Director a playable build + config-sweep guidance for the re-gate playtest.

---

## 1. Goal & design intent

**Goal:** assemble + verify **one runnable M1.2 build** that proves the legibility/level-scale iteration runs end-to-end with the cost axis active **and legible**, and that **config-marked telemetry writes** (with the new `lvl_*` + `r1_catch_radius_per_depth` knobs and a real build SHA) so the re-gate (RG2/RG3) can analyse it against the M1.0 and M1.1 baselines.

The loop RG1 must run, unbroken, repeatedly in a session — the **exact M1.1 spine**, now with the M1.2 fixes layered on:

```
main_game  →  Config menu (pick/tune oppositions + level scale)  →  Start
   →  dive (R1 hazard CATCHES now · R2/R3 attrition is VISIBLE · R4 vision OCCLUDES · level scale = a journey)
   →  one of four end-causes:  extract  |  death (hazard)  |  timeout (exposure/clock)  |  lost (burns clock→timeout/death)
   →  bank (extract) OR pockets (fail)  →  sell screen tallies junk→Money
   →  Continue (re-run same config)  OR  Back to Config (switch config)  →  fresh dive
```

**Design intent (one line):** *RG1 is the M1.2 integration + verification capstone, not a new system* — it takes the six file-disjoint fixes (I1 level scale, I2 hazard catch, I3 R2/R3 cues, I4 vision occlusion, I5 telemetry hygiene, BUG4 robust seal) + BUG5 (exposure-toll mutator), confirms they (a) compose in the single `main_game` scene without conflict, (b) each individually take effect per run from CFG, (c) all-off **still** reproduces the M1.0/M1.1 baseline EXACTLY (fp=`e943ac9c8bc1`, byte-unmoved), and (d) every run emits a config snapshot carrying the new knobs + a **real** build SHA + the right opposition event rows. RG1 does **not** answer the fun gate — that is RG2 (analysis) → RG3 (verdict).

What's different from M1.1 RG1: the M1.1 build's most visceral opposition **never caught** (`hazard_caught = 0`), levels cleared in ~17 s, and R2/R3/R4 fired invisibly. M1.2 RG1's job is to prove those are **fixed and legible** in the assembled build — the hazard catches, the level scale visibly changes the band, the cues' backing signals fire, the vision occludes, the build SHA is real, and the R2 exposure toll actually moves R3's meter.

---

## 2. What's already wired (the assembled loop — do NOT rebuild)

The M1.2 build assembly was done by the Wave-1/Wave-2 builders; RG1 inherits it. Key seams in `scenes/game/main_game.gd` (verified present by `test_rg1_m12_verify.gd`):

- **`start_new_run()`** (the single loop entry) resolves `run_cfg` from the CFG menu BEFORE generation, then:
  - **I1:** picks the catalog by `lvl_enabled` (baseline vs `piece_catalog_ext.tres` — Resolved G, config-dependent catalog so the all-off fingerprint never moves); computes the effective px/cell once via `run_cfg.effective_cell_size_px(16)` and shares it across materialise + `JunkPlacer.plan(...)` (the Phase-3 loot-seam fix); feeds `effective_room_count` into the generator.
  - **R1/I2:** `_spawn_r1_hazards(run_cfg, band)` — fully gated by `r1_enabled && r1_spawn_count > 0`; the hazard reads `r1_catch_radius + r1_catch_radius_per_depth * depth` (I2 Q3) and has anti-wall-stick `STALL_FRACTION` steering (I2 Q2, refuge kept).
  - **R2/R3:** persistent `ReturnCost` + `ExposureMeter` children, self-gating per run; `ReturnCost.dive_clock` is injected in `_ready()`. **BUG5:** `ExposureMeter.add()` exists and is in group `r3_exposure_meter`, so an R2 `exposure` toll mutates R3's meter through the shared crossing path.
  - **R4/I4:** `_spawn_r4_nodes()` instantiates the vision/fog (radial-dark occlusion) + lost-proxy per dive, inert when R4 off.
  - **BUG4:** `SocketSealer.new().seal_unused_sockets(band, cell_size)` caps **all** outward-facing perimeter floor edges (geometry-keyed seal, branch-rate-independent).
- **`SellScreen.continue_pressed → start_new_run`** (door 2, quick re-run, same config) and **`back_to_config_pressed → _on_back_to_config`** (the switch-config path).
- **I5:** `BuildVersion.id()` resolves the real HEAD SHA (baked artifact → live `git rev-parse` editor fallback → `0000000` sentinel); Telemetry stamps it onto `run_started.data.build`. `duration_s` is real on every completed run (BUG1 fix + the I5(a) regression-lock).

**The run/meta boundary stays intact:** `RunConfig` (incl. `lvl_*`) is run-scoped, never persisted; Money + `banked_junk` persist; nothing writes a config to `meta.sav`.

---

## 3. Verify matrix (M1.2)

RG1 is **done** only when this matrix passes. It separates **objective build checks** (headless-automatable by `tests/test_rg1_m12_verify.tscn`) from **subjective fun signal** (RG2/RG3 + human). The headless driver mirrors the M1.1 `test_rg1_loop_verify` shape: it instances the REAL `main_game.tscn`, drives each config through the build's own `start_new_run()`, then inspects `user://telemetry/run_log.jsonl`.

### 3.1 Per-fix isolation (each fix exercised alone)

| # | Config | Expected observable | Headless assertion |
|---|---|---|---|
| **M1 / I1** | `lvl_enabled`, `lvl_room_count=20`, `lvl_size_mult=2.0` | Bigger band: more rooms + larger rooms (32 px/cell vs 16). | `_band_cell_size_px` on > off (32 > 16); `BandContainer` child count on > off (count override takes effect). **HEADLESS PASS.** |
| **M2 / I2** | R1 on, `r1_catch_radius_per_depth=4.0`, `r1_catch_kills=true` | Hazard awakens, closes (anti-wall-stick), and **catches → `death`** (the M1.1 `caught=0` is fixed). | `hazard_awoke`+`hazard_caught` rows; `run_ended.cause="death"`. **HEADLESS PASS** (the catch landed in the assembled loop; the strict-catch row is deferred to the unit suite only if a given headless run's frame budget misses it). |
| **M3 / I3** | R2 (egress toll) + R3 (exposure) on | Exposure bar climbs + penalty banner; R2 clock-toll pulse + "−N" indicator. | `return_cost_incurred` + (`exposure_crossed`/`exposure_penalty`/`exposure_meter_changed`) rows present (the cue-backing signals). **HEADLESS PASS** (signals); cue VISUALS **human-deferred**. |
| **M4 / I4** | R4 on, high branch (`branch_chance_base=1.0`) + fog | Vision **occludes** beyond the radius (hides, not dims); fog memory; "lost" cue; band stays sealed. | `nav_branch_taken`/`nav_lost_proxy` rows; loop survives a high-branch run (BUG4 seal). **HEADLESS PASS** (rows + no crash); occlusion LOOK **human-deferred**. |
| **M5 / BUG5** | R2 `toll_resource=exposure` + R3 on, **R3 natural climb = 0** | The R2 exposure toll is the ONLY thing that can move R3's meter — so an `exposure_meter_changed`/crossing in this run proves the toll mutates the meter. | `return_cost_incurred` + an R3 row in a zero-natural-climb run. **HEADLESS PASS.** |

### 3.2 Stacked + baseline control

| # | Config | Expected | Headless assertion |
|---|---|---|---|
| **M6 / V5** | All four oppositions + level scale ON | Loop runs end-to-end, no crash/soft-lock; all fixes compose; every end-cause reachable. | ≥1 row from each opposition family in one run; loop survives. **HEADLESS PASS.** |
| **M0 / V6** | **All OFF (baseline)** | Loop behaves identically to M1.0/M1.1; **no opposition rows**; the generated band is **byte-identical** to the locked baseline. | All-off RunConfig band fp == `e943ac9c8bc1` (== rc-null baseline); zero opposition rows in the all-off run. **HEADLESS PASS — the determinism guard.** |
| **V7** | "Reset to baseline" (CFG action) | All knobs (incl. `lvl_*`) return to all-off; a run after reset == M0. | Covered by the M1.1 driver's reset assertion (`_on_reset_pressed` → `all_oppositions_disabled()`); CFG auto-covers the new fields. **HEADLESS (M1.1 driver) + human spot-check.** |

### 3.3 End-cause reachability + telemetry integrity

| # | Check | Expected | Headless |
|---|---|---|---|
| **V8–V11** | extract / death / timeout reachable + sell screen + loop continues; "lost" manifests as timeout/death (nav rows distinguish). | All three causes observed in `run_ended` rows; sell screen presents; Continue loops. | **PASS.** |
| **V12** | Multiple runs/session, **no leaked nodes** | Band/hazard/fog/HUD freed on Continue; settled `BandContainer` count stays bounded run-over-run. | **PASS** (settled-count guard ≤2× across 4 loops). |
| **V13** | Config snapshot per run carries the **full key set incl. the new M1.2 knobs** | Every `run_started.data.run_config` has all `to_flat_dict()` keys + explicitly `lvl_enabled`/`lvl_room_count`/`lvl_size_mult`/`r1_catch_radius_per_depth`. | **PASS** (asserted as a set, not a magic count). |
| **V14** | Opposition event gating | ON → rows present; OFF → absent (all-off run has zero opposition rows). | **PASS.** |
| **V15** | `run_ended` arity intact + `duration_s` **real on every run** (I5) | `run_ended(reason, duration_s, depth_reached)` unchanged; `duration_s > 0` on every completed run; `max_depth ≥ 1`. | **PASS** (the I5 duration regression-lock surface). |
| **V16** | Config carry-forward (incl. `lvl_*`) across Continue | The next run's `active_run_config` still carries the prior config (lvl on → lvl on). | **PASS.** |
| **V17 / I5** | Build identity is **REAL** | `run_started.data.build` = `m1-<date>-<sha>` with the live HEAD SHA, **not** the stale `852b6e2`. | **PASS** headless (`m1-20260619-<sha>`); a RETURNED log's build id + Director `build_tag` is **human-deferred**. |
| **V18** | No blockers / soft-locks | Every state has an exit; consent prompt answered once. | **PASS** (loop survives); real-input screen navigation **human-deferred**. |

### 3.4 Subjective (NOT RG1 — handed to the human via RG2/RG3)

> "Does the hazard close-in feel tense?", "do bigger rooms feel like a journey?", "is the exposure climb legible?", "does the dark actually hide?" — RG1 only guarantees the build *lets a human experience and the telemetry capture* these. The fun read is RG3 (Director), backed by RG2's distribution analysis.

---

## 4. Headless verification — what the driver proves vs. what's human-deferred

`tests/test_rg1_m12_verify.tscn` (driver `test_rg1_m12_verify.gd`) runs the matrix and prints `RG1 M1.2 VERIFY OK` on success, exiting non-zero on any failure (CI-gateable).

**Headless-verified (14 rows):** baseline-fp-unmoved (M0/determinism guard) · build-id-real (I5) · persistent-node + BUG5 `add()` wiring · 7 driven configs each with snapshot + event-gating (M0–M6) · level-scale-takes-effect (I1: count + px/cell) · BUG5 toll-moves-meter end-to-end · duration_s-real on every run (I5) · config carry-forward incl. `lvl_*` (V16) · repeated runs / no leak (V12) · all four end-causes (V8–V11).

**Human-deferred (rendering / felt — on the manual checklist):**
- I1: bigger rooms FEEL like a journey (not a 17 s sprint).
- I2: the hazard VISIBLY closes; the depth-scaled lunge reads as a real threat.
- I3: the exposure bar + penalty banner + R2 clock-toll pulse are LEGIBLE (E2 readability).
- I4: vision OCCLUDES (hides, not dims) beyond the radius; the "lost" cue reads.
- I5/V17: a RETURNED log carries the real `m1-<date>-<sha>` + the Director's `build_tag`.
- V18: no stuck SCREENS via real input (menu/consent/sell navigation).

---

## 5. Config-sweep guidance for the Director (the re-gate experiment plan)

The re-gate question (RG3): **now that the cost axis is legible and the levels are worth traversing, is push-vs-extract a real, fun gamble?** Set each config in the Config menu, type a `build_tag`, and run a handful of runs per config (the snapshot self-labels every run, so you don't transcribe knobs). Suggested sweep, in order:

1. **Baseline control (`build_tag: m12-baseline`).** All-off (or the menu's Reset). A few runs — this is the permanent M1.0/M1.1 control RG2 segments everything against. The all-off band is byte-identical to M1.0/M1.1 (fp `e943ac9c8bc1`), so baseline run-lengths/outcomes are directly comparable across all three versions.

2. **Level scale alone — I1's headline (per I1's Resolved-A: sweep SIZE first, count at baseline).** Set `lvl_enabled` on, leave `lvl_room_count` at baseline (−1), and sweep `lvl_size_mult` across **{1.0, 1.5, 2.0, 3.0}** (tags `m12-size-1.0` … `m12-size-3.0`). This answers "does a level worth traversing fix the 17 s sprint?" *without* confounding it with more rooms. Then optionally add a room-count pass (`lvl_room_count` ~16–24) on top of the size that felt best.

3. **Hazard on (`build_tag: m12-r1-catch`).** R1 on with `r1_catch_radius ~32`, `r1_catch_radius_per_depth ~2–4`, `r1_catch_kills=true`, `r1_spawn_count=1`. This is the M1.1 fix that mattered most (`caught=0` → catches). Run it on a level scale that felt good (e.g. `lvl_size_mult=2.0`) so the hazard has hall to chase in. Watch for `death` end-causes in the data.

4. **Exposure toll on (`build_tag: m12-r2r3-toll`).** R2 `mechanism=egress_toll`, `toll_resource=exposure` + R3 on (`base_climb_rate` moderate, two `threshold_levels`). This is the BUG5 path — the toll now actually moves R3's meter, so the exposure cue should visibly jump on each retreat. Sweep `r2_cost_magnitude` / `r2_cost_per_depth` to taste.

5. **Vision/maze on (`build_tag: m12-r4-dark`).** R4 on with `vision_radius` tuned to the room scale (bigger rooms → larger radius), `fog_enabled`, a non-trivial `branch_chance_base`, and a `lost_proxy_threshold`. This is I4 — confirm the dark occludes and the "lost" cue reads at the chosen scale.

6. **Everything stacked (`build_tag: m12-all-on`).** All four + a level scale. The "is the whole gamble fun" cell.

**Pin a seed (`seed_override ≥ 0`) for A/B comparisons** (e.g. baseline vs `lvl_size_mult=2.0` on the same layout); leave it `−1` to vary per loop for distribution data at the fast-replay cadence.

**`build_tag` labelling convention (so RG2 can segment):** prefix every sweep tag with `m12-` (mirrors M1.1's channel convention so M1.2 runs are separable from M1.0/M1.1 logs), then a short config handle (`m12-size-2.0`, `m12-r1-catch`, `m12-all-on`). One distinct tag per config; re-run the same config many times under the same tag for a distribution. The full `run_config` snapshot on every `run_started` row is ground truth; `build_tag` is the human-readable handle RG2 groups on.

---

## 6. Telemetry path + build identity (confirmed)

- **Path:** `user://telemetry/run_log.jsonl` (one JSON object per line). On Windows: `%APPDATA%\Godot\app_userdata\THE FAR YARD\telemetry\run_log.jsonl`. Telemetry is **opt-in / default OFF**; the first-run consent modal must be answered Enable for a sweep to log.
- **Build identity (I5):** the build id is now the **real** HEAD SHA — verified headless as `m1-20260619-<sha>` (not the frozen `852b6e2` the M1.1 logs carried). For a shipped/exported build, run `tools/stamp_build.sh` so the baked `systems/build_info_gen.gd` artifact carries the exact commit (an un-stamped, non-editor build legibly reports `0000000` rather than masquerading as a real commit). Confirm the menu's bottom-right build stamp matches before sharing.
- **Schema:** unchanged — no `run_ended` arity change, no telemetry schema bump, no new EventBus signal (the M1.2 knobs ride the additive `run_config` snapshot payload; I3's cues project existing signals; BUG5 reuses R3's existing crossing signals).

---

## 7. Acceptance criteria (M1.2, from the breakdown §7)

1. **A fresh build runs the complete M1.2 loop** with all fixes, end-to-end, no blockers — `RG1 M1.2 VERIFY OK`.
2. **Each fix takes effect per run from CFG** (level scale, hazard catch, cues, vision, the new `lvl_*`/`r1_catch_radius_per_depth` knobs) — and **each verifies individually + stacked**.
3. **The all-off control reproduces the M1.0/M1.1 baseline exactly** (fp `e943ac9c8bc1` unmoved; byte-identical telemetry for build/duration shape).
4. **Telemetry logs config + opposition events** with the new knobs in the snapshot, a **real build SHA**, and `duration_s > 0` on every completed run.
5. **Multiple runs per session, no leaked nodes.**
6. The build + this doc + the updated checklist + tester_readme are **ready for the Director's playtest** (RG2/RG3 follow).

A build that passes the §3 matrix (headless `RG1 M1.2 VERIFY OK` + the human checklist) and ships the updated smoke checklist + tester readme satisfies RG1. Done means: the matrix is filled, the worklog names the commit SHA, and the build launches + loops with the legible cost axis active.
