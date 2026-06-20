# RG1 — M1.3 Playtest Build (density + the fun-default made the default)

**Task id:** RG1 · **Milestone:** M1.3 (Legibility & Density) · **Workstream:** the re-gate · **Wave:** 3 (sequential, after Wave 1 + Wave 2 integrate)
**Assignee:** `general-purpose` (build assembly — already integrated across Waves 1–2) + `qa-playtest-coordinator` (build verification matrix)
**dependsOn:** **BUG6, J1, J5, DLV1, DLV2** (Wave 1) + **J2, J3, J4** (Wave 2) all integrated on `main`
**Companion docs:** `M1.3_Breakdown.md` (§3 RG1 row, §5 Wave 3, §6 contracts, Phase-4 Locked Decisions), `M1_2_Tasks/RG1_playtest_build.md` (the template this mirrors), `M1_Tasks/M1_As_Built.md` (canonical APIs), the M1.3 task specs (`J1_*.md`, `J2_enemy_spread.md`, `J3_per_room_density.md`, `J4_hallway_length.md`, `J5_*.md`, `BUG6_*`, `DLV1`, `DLV2`), `scenes/game/main_game.gd` (the assembled loop)

> **This is the VERIFY + DOCUMENT task, not new gameplay.** Every M1.3 fix (J1–J5, BUG6, DLV1/DLV2) was built and merged in Waves 1–2. RG1 proves the assembled loop boots into the new default play-preset, runs every knob individually + stacked, that the all-off control is still byte-identical to the M1.0/M1.1/M1.2 baseline, that the new `corridor_summary` telemetry row writes clean, and that config-marked telemetry carries all 46 knobs + a real build SHA — then hands the Director a playable build (auto-published to itch via DLV1) + config-sweep guidance for the re-gate.

---

## 1. Goal & design intent

**Goal:** assemble + verify **one runnable M1.3 build** that proves the density/defaults iteration runs end-to-end — the build **boots into the fun config** (the F1 named play-preset), big rooms are **filled with distributed danger** (J2 spread + J3 density), the boring long halls are **biased down** (J4), the depth readout is **fixed** (J5), every enabled opposition **actually fires** (BUG6 trap guard) — and that **config-marked telemetry writes** (with the new `r1_spawn_*`/`r1_*density*`/`lvl_corridor_*` knobs, the additive `corridor_summary` row, and a real build SHA) so the re-gate (RG2/RG3) can analyse it against the M1.0/M1.1/M1.2 baselines.

The loop RG1 must run, unbroken, repeatedly in a session — the **exact M1.2 spine**, now with the M1.3 fixes layered on and the **fun config as the boot default**:

```
main_game  →  Config menu (boots seeded with make_default_play_preset(); tune/Reset)  →  Start
   →  dive (R1 hazards SPREAD across depths + DENSITY fills big rooms · R4 maze · short halls · depth readout = "Depth N / max")
   →  one of four end-causes:  extract  |  death (hazard catch)  |  timeout (clock)  |  lost (burns clock→timeout/death)
   →  bank (extract) OR pockets (fail)  →  sell screen tallies junk→Money
   →  Continue (re-run same config)  OR  Back to Config (switch config)  →  fresh dive
```

**Design intent (one line):** *RG1 is the M1.3 integration + verification capstone, not a new system* — it takes the file-disjoint Wave-1/Wave-2 fixes (J1 default-preset + size re-range, J2 enemy-spread, J3 per-room density, J4 hallway lever + corridor telemetry, J5 depth HUD, BUG6 debounce + config-trap guard, DLV1/DLV2 web delivery) and confirms they (a) compose in the single `main_game` scene without conflict, (b) the build **boots into** the F1 play-preset, (c) each knob individually takes effect, (d) all-off **still** reproduces the M1.0/M1.1/M1.2 baseline EXACTLY (fp=`e943ac9c8bc1`, byte-unmoved), and (e) every run emits a config snapshot carrying all 46 knobs + a **real** build SHA + a `corridor_summary` row + the right opposition event rows. RG1 does **not** answer the fun gate — that is RG2 (analysis) → RG3 (verdict).

What's different from M1.2 RG1: the M1.2 build's most-fun config **was not the default** (the Director had to dial it in), huge rooms were **empty** (one hazard, long boring halls), the depth readout was **wrong**, and two oppositions ran **silently dead** (R3 empty thresholds, R4 lost-proxy 0). M1.3 RG1's job is to prove those are **fixed** in the assembled build — the fun config boots, the rooms are filled with distributed danger, the halls are biased short, the readout is right, BUG6's trap guard surfaces any dead config, and the new corridor-time telemetry (`corridor_frac`) is what RG2 reads for the F3a "time in hallway" question.

---

## 2. What's already wired (the assembled loop — do NOT rebuild)

The M1.3 build assembly was done by the Wave-1/Wave-2 builders; RG1 inherits it. Key seams in `scenes/game/main_game.gd` + `data/run_config/run_config.gd` (verified present by `test_rg1_m13_verify.gd`):

- **`make_default_play_preset()`** (`run_config.gd`) — the named F1 stack: `lvl_enabled` (19 rooms, size 4.0), `r1_enabled` (the most-fun ba745e1 cell verbatim, catch-radius floored to 24px), J2 `even_spread` count 5 / min-depth 1, J3 `r1_per_room_density=1.0` cell-area with a mandatory per-room cap 3 / min-area 64, J4 corridors biased down (`lvl_corridor_weight_mult=0.5` + `lvl_short_corridors=true`), R4 **maze-only** (branching ON, vision/fog/lost OFF — "match what I played"), **R2/R3 OFF**. Built on a fresh `RunConfig.new()` so it **never mutates** the code-level all-off default (the load-bearing M1.3 contract, Breakdown §2). Provably trap-free (`inert_enabled_oppositions()` empty). The CFG rail (`config_menu._ready`) + the no-CFG fallback (`main_game.gd`) seed this.
- **`start_new_run()`** (the single loop entry) resolves `run_cfg` from the CFG menu BEFORE generation, then:
  - **J1/LVL:** picks the catalog by `lvl_enabled`; computes effective px/cell once via `effective_cell_size_px(16)`; feeds `effective_room_count`; the size slider is re-ranged to **[4.0, 40.0]** (`RANGE_MULT`).
  - **R1 + J2 + J3:** `_spawn_r1_hazards(run_cfg, band)` is the single spawn seam. J2's `_hazard_spawn_depths(band, rc)` plans the spread (single_gate / even_spread / curve) and `_hazard_spawn_position(band, depth, index)` places each; J3's `_density_spawn_positions(band, rc)` is the deterministic per-room density plan (area-scaled, per-room cap + band ceiling ≤64, RNG-free). Both budgets are independent; either may be zero; spawn_count 0 AND density 0 = byte-identical to M1.2.
  - **J4:** the corridor-rarity lever lives in `band_generator.gd` (weighted-pick down-weight, `lvl_corridor_weight_mult` + `lvl_short_corridors` dropping `piece_corridor_long_h`). Corridor-time telemetry is in `main_game.gd`: `_accumulate_piece_time`/`_update_player_piece` bucket per-frame time corridor-vs-room (hoisted OUT of the R4 gate so it works R4-off), classified on `RunConfig.CORRIDOR_PIECE_IDS` keyed on `piece_id`; `_on_run_ended` emits `EventBus.corridor_time_summary(corridor_s, room_s)`.
  - **J5:** the depth-counter HUD subscribes to `depth_changed` and reads "Depth N / max" (room `depth_index`, not the static band counter).
  - **BUG6:** `hazard_caught` is one-shot debounced (≤1 per catch); `inert_enabled_oppositions()` (warn-only) surfaces an enabled-but-inert opposition via the CFG warn-line + an additive telemetry flag (never blocks Start).
- **DLV1/DLV2:** the HTML5 web export preset + `tools/push_itch.sh` publish each playtest build to `qusto/the-far-yard:html5`; DLV2's in-game "Export telemetry" button (web-guarded JavaScriptBridge) returns the `.jsonl` from a browser playtest.
- **`SellScreen.continue_pressed → start_new_run`** (door 2) and **`back_to_config_pressed → _on_back_to_config`** (switch-config path).

**The run/meta boundary stays intact:** `RunConfig` (incl. the J2/J3/J4 knobs + the preset) is run-scoped, never persisted; Money + `banked_junk` persist; nothing writes a config to `meta.sav`. The default play-preset is a **separate artifact**, not the code-level all-off default.

---

## 3. Verify matrix (M1.3)

RG1 is **done** only when this matrix passes. It separates **objective build checks** (headless-automatable by `tests/test_rg1_m13_verify.tscn`) from **subjective fun signal** (RG2/RG3 + human). The headless driver mirrors the M1.2 `test_rg1_m12_verify` shape: it instances the REAL `main_game.tscn`, drives each config through the build's own `start_new_run()`, then inspects `user://telemetry/run_log.jsonl`. For J2/J3/J4 it also drives the build's own deterministic spawn-plan/fingerprint helpers directly (the same helpers `start_new_run()` calls) so the spread/density/cap/lever are asserted EXACTLY, not inferred from timing-sensitive runtime rows.

### 3.1 Per-fix isolation (each fix exercised alone)

| # | Config | Expected observable | Headless assertion |
|---|---|---|---|
| **M1 / J1** | `make_default_play_preset()` (the boot config) | The build boots into the F1 stack; LVL+R1 on, R4 maze-only, R2/R3 off; loops end-to-end; trap-free; does not leak into the all-off control. | Preset shape (lvl/r1/r4 on, r2/r3 off, R4 maze-only, J2 even_spread, J3 density+cap, J4 biased-down); `inert_enabled_oppositions()` empty; `RunConfig.new()` still all-off after building the preset; CFG `apply_and_get_config()` at boot is the F1 stack; the driven run loops + emits R1/R4 rows. **HEADLESS PASS.** |
| **M2 / J2** | R1 on, `r1_spawn_distribution=even_spread`, `r1_spawn_count=5`, `r1_spread_min_depth=1`, `r1_catch_kills=true` | Hazards spawn at MULTIPLE distinct depths (the F2 fix), one catches → `death`. | `_hazard_spawn_depths(band, rc)` spans >1 distinct depth for even_spread; `single_gate` collapses to ONE depth (M1.2-equivalent); the driven run awakens a hazard + ends `death`. **HEADLESS PASS.** |
| **M3 / J3** | R1 on, `r1_per_room_density=1.0` cell_area, cap 3, min-area 64 (density-only) | Big rooms get extra density hazards scaled by `floor_cells` area, bounded by the per-room cap + band ceiling ≤64; density 0 → 0 nodes. | `_density_spawn_positions`: density 0 → 0 nodes (M1.2 control); a 200-cell room earns ≥1; worst-case (40 huge rooms × density 4 × cap 8) ≤ `R1_DENSITY_BAND_CEILING` (64); deterministic; the driven run awakens a density hazard. **HEADLESS PASS.** |
| **M4 / J4** | `lvl_corridor_weight_mult=0.25` + `lvl_short_corridors=true` on a level-scaled band | Fewer/shorter corridors; the band fingerprint MOVES for a fixed seed yet stays deterministic; the neutral default is byte-identical. | Neutral lever fp == `e943ac9c8bc1`; `0.25×` mult AND `short_corridors=true` each MOVE the ext-catalog fp for a fixed seed; both deterministic across calls; the driven run loops. **HEADLESS PASS.** Corridor LENGTH/FEEL is **human-deferred**. |
| **J5** | (HUD-only) | The depth readout shows "Depth N / max" tracking the room `depth_index`. | Subscribe/readout LOGIC is covered by the J5 unit suite; the rendered HUD string is **HUMAN-DEFERRED** (no render headless). |

### 3.2 Stacked + baseline control

| # | Config | Expected | Headless assertion |
|---|---|---|---|
| **M5 / all-on** | The default preset + R2 (egress toll on exposure) + R3 climbing, R1 non-fatal | Loop runs end-to-end, no crash/soft-lock; all fixes + all four oppositions compose. | ≥1 row from each opposition family (hazard/R2/R3/R4) in one run; loop survives; `timeout` end-cause. **HEADLESS PASS.** |
| **M0 / baseline** | **All OFF (baseline)** | Loop behaves identically to M1.0/M1.1/M1.2; **no opposition rows**; the generated band is **byte-identical** to the locked baseline. | All-off RunConfig band fp == `e943ac9c8bc1` (== rc-null baseline); zero opposition rows in the all-off run. **HEADLESS PASS — the determinism guard.** |
| **Reset** | "Reset to baseline" (CFG action) | All knobs return to all-off; a run after Reset == M0. | Covered by `test_config_menu` (Reset returns the all-off baseline, 46/46 knobs); **HEADLESS (config-menu suite) + human spot-check.** |

### 3.3 End-cause reachability + telemetry integrity

| # | Check | Expected | Headless |
|---|---|---|---|
| **End-causes** | extract / death / timeout reachable + sell screen + loop continues | All three causes observed in `run_ended` rows; sell screen presents; Continue loops. | **PASS.** |
| **No leak** | Multiple runs/session, **no leaked nodes** | Band/hazard/density/HUD freed on Continue; settled `BandContainer` count stays bounded run-over-run. | **PASS** (settled-count guard ≤2× across 4 default-preset loops). |
| **Snapshot / 46 knobs** | Config snapshot per run carries the **full 46-knob key set incl. the J2/J3/J4 knobs** | Every `run_started.data.run_config` has all `to_flat_dict()` keys + explicitly the new `r1_spawn_*`/`r1_*density*`/`lvl_corridor_*`/`lvl_loot_density_per_area` keys. | **PASS** (asserted as a SET, V13 precedent — not a magic count). |
| **Opposition gating** | ON → rows present; OFF → absent (all-off run has zero opposition rows). | — | **PASS.** |
| **`run_ended` arity intact** | `run_ended(reason, duration_s, depth_reached)` unchanged; M1.0 `data` fields (`cause`/`duration_s`/`banked_total`/`lost_total`/`max_depth`) present; `duration_s > 0` on every run; `max_depth ≥ 1`. | — | **PASS.** |
| **`corridor_summary` row (J4)** | Every run emits **exactly one** `corridor_summary` JSONL row carrying `corridor_s`/`room_s`/`corridor_frac` (frac ∈ [0,1]). | 6 driven runs → 6 rows, each well-formed. | **PASS** (the additive row RG2 reads for F3a). |
| **Schema v1 locked** | No row carries a bumped `SCHEMA_VERSION`. | Every row `v == TelemetrySchema.SCHEMA_VERSION`. | **PASS.** |
| **Build identity REAL** | `run_started.data.build` = `m1-<date>-<sha>` with the live HEAD SHA, **not** the stale `852b6e2`. | **PASS** headless; a RETURNED log's build id + Director `build_tag` is **human-deferred**. |
| **Config carry-forward** | The next run (Continue) still carries the prior preset config (lvl on, even_spread, density on). | — | **PASS.** |

### 3.4 Subjective (NOT RG1 — handed to the human via RG2/RG3)

> "Does danger at multiple depths feel right?", "do the big rooms feel charged not empty?", "are the halls shorter / less dead-time?", "does the depth counter read clearly?", "at size 40 do huge rooms feel like awe or a void?" — RG1 only guarantees the build *lets a human experience and the telemetry capture* these. The fun read is RG3 (Director), backed by RG2's distribution analysis.

---

## 4. Headless verification — what the driver proves vs. what's human-deferred

`tests/test_rg1_m13_verify.tscn` (driver `test_rg1_m13_verify.gd`) runs the matrix and prints `RG1 M1.3 VERIFY OK` on success, exiting non-zero on any failure (CI-gateable).

**Headless-verified (16 rows):** baseline-fp-unmoved (the determinism guard) · build-id-real · default-preset-shape + trap-free + no-leak-into-default (J1) · CFG-boots-the-preset · J2 even_spread spans >1 depth + single_gate single-depth (plan-level) · J3 density 0→0, big-room fill, band-ceiling bound, deterministic (plan-level) · J4 neutral fp byte-match + non-neutral lever moves fp + deterministic · persistent-node wiring · 6 driven configs each with snapshot + event-gating · `corridor_summary` 6-row well-formed · `run_ended` arity + `duration_s>0` on every run · all three end-causes · config carry-forward · repeated runs / no leak · all-off-no-opposition-rows.

**Human-deferred (rendering / felt — on the manual checklist):**
- J1: the build BOOTS into the default play-preset (the CFG rail shows the F1 stack at launch).
- J2: danger at MULTIPLE depths FEELS right (not one gate-wall).
- J3: big rooms feel CHARGED not empty (density fills them).
- J4: the halls feel SHORTER / less dead-time between rooms.
- J5: the depth counter reads "Depth N / max" bottom-left and tracks room depth.
- size-40 "void feel" window: at `lvl_size_mult ~40` do huge rooms read as awe, not emptiness?
- A RETURNED log carries the real `m1-<date>-<sha>` + the Director's `build_tag` (and, for a web playtest, DLV2's export button round-trips the `.jsonl`).

---

## 5. Config-sweep guidance for the Director (the re-gate experiment plan)

The re-gate question (RG3): **now that the fun config is the default and the big rooms are filled with distributed danger, is the loop a "go"?** The build boots into the F1 preset, so the **first sweep is just "play the default."** Then set each config in the Config menu, type a `build_tag`, and run a handful of runs per config (the snapshot self-labels every run, so you don't transcribe knobs). Suggested sweep, in order:

1. **Baseline control (`build_tag: m13-baseline`).** All-off (the menu's **Reset**). A few runs — the permanent M1.0/M1.1/M1.2 control RG2 segments everything against (byte-identical band, fp `e943ac9c8bc1`).

2. **The default preset, as shipped (`build_tag: m13-default`).** Just **Start** from the boot config. This is the headline cell — "is the fun-default actually fun, out of the box?" Several runs for a distribution.

3. **J2 enemy-spread sweep (`build_tag: m13-j2-*`).** Hold the default, vary the spread: `r1_spawn_count` across **{3, 5, 7}** (`m13-j2-count-3` … `-7`), `r1_spawn_distribution` across `single_gate` / `even_spread` / `curve` (`m13-j2-single`, `-even`, `-curve`), and `r1_spread_min_depth` **{0, 1, 2}**. Answers "how much distributed danger, and how shallow does it start?"

4. **J3 density sweep (`build_tag: m13-j3-*`).** Hold the default, vary density: `r1_per_room_density` across **{0.5, 1.0, 2.0}** (`m13-j3-d-0.5` … `-2.0`), `r1_density_per_room_cap` **{2, 3, 5}**, `r1_density_metric` `cell_area` vs `px_area` (`m13-j3-cell`, `m13-j3-px` — px grows with size, watch the band-ceiling), and `r1_density_min_area` to taste. Answers "how full should big rooms be?"

5. **J3 wake-cadence tuning (`build_tag: m13-wake-*`) — CARRIED FORWARD.** With density ON, deep big rooms can become instant-death if every density hazard wakes at once. Sweep the WAKE knobs (not the count): `r1_depth_threshold` **{0, 1, 2}** (how deep before any density hazard stirs) and `r1_linger_seconds` **{0, 4, 8}** (a time-in-band fuse) so deep big rooms read as charged-then-dangerous, not instant-death. Tags `m13-wake-thresh-1`, `m13-wake-linger-8`, etc.

6. **J4 corridor sweep (`build_tag: m13-j4-*`).** Vary the hallway lever: `lvl_corridor_weight_mult` across **{1.0, 0.5, 0.25}** (`m13-j4-mult-1.0` … `-0.25`) and `lvl_short_corridors` on/off (`m13-j4-short-on`, `-off`). **Read `corridor_frac` from the `corridor_summary` row** (lower = less time in halls). Answers F3a "are the halls shorter / less dead-time?" directly.

7. **Mult-40 "void feel" window pass (`build_tag: m13-size-40`).** Push `lvl_size_mult` to the new slider ceiling **40.0** with density ON. The headline question: at the extreme room scale, do the rooms read as **awe** (filled, charged) or as an empty **void**? Compare `m13-size-40` against `m13-size-4` (the default floor) and `m13-size-20` (mid). This is where J3 density and J4 short-halls earn their keep — a 40× room with no density is the M1.2 "empty huge room" failure.

8. **Everything stacked (`build_tag: m13-all-on`).** The default preset + R2 (egress toll on exposure) + R3 climbing. The "is the whole cost axis, with density, fun" cell.

**Pin a seed (`seed_override ≥ 0`) for A/B comparisons** (e.g. `m13-j4-mult-1.0` vs `-0.25` on the same layout); leave it `−1` to vary per loop for distribution data at the fast-replay cadence.

**`build_tag` labelling convention (so RG2 can segment):** prefix every sweep tag with `m13-` (mirrors the M1.1/M1.2 channel convention so M1.3 runs are separable from the older logs), then a short config handle (`m13-j2-even`, `m13-j3-d-1.0`, `m13-size-40`, `m13-all-on`). One distinct tag per config; re-run the same config many times under the same tag for a distribution. The full 46-knob `run_config` snapshot on every `run_started` row is ground truth; `build_tag` is the human-readable handle RG2 groups on.

---

## 6. Telemetry path + build identity (confirmed)

- **Path:** `user://telemetry/run_log.jsonl` (one JSON object per line). On Windows: `%APPDATA%\Godot\app_userdata\THE FAR YARD\telemetry\run_log.jsonl`. Telemetry is **opt-in / default OFF**; the first-run consent modal must be answered Enable for a sweep to log. **Web (DLV1/DLV2):** a browser playtest returns its `.jsonl` via the in-game "Export telemetry" button (DLV2, JavaScriptBridge-guarded).
- **The new `corridor_summary` row (J4):** every run end emits **exactly one** additive `corridor_summary` row carrying `corridor_s`, `room_s`, and `corridor_frac` (∈ [0,1]). **`corridor_frac` is what RG2 reads for the F3a "time in hallway" question** — it is the direct measure of how much of a run was spent in corridors vs. rooms, so the J4 sweep (step 6) and the void-feel pass (step 7) are evaluated on it. This row is **additive** (`data` fields only) — `run_ended` arity is unchanged and `SCHEMA_VERSION` is **not** bumped (still schema v1).
- **Build identity:** the build id is the **real** HEAD SHA — verified headless as `m1-<date>-<sha>` (not the frozen `852b6e2`). For a shipped/exported (incl. web) build, `tools/stamp_build.sh` bakes the exact commit into `systems/build_info_gen.gd`; an un-stamped build legibly reports `0000000`. Confirm the menu's bottom-right build stamp matches before sharing.
- **Schema:** unchanged from M1.2 — `run_ended` arity locked, telemetry schema v1, the only addition is the additive `corridor_summary` row (J4) + BUG6's additive trap-flag field on `run_started`. The J2/J3/J4 knobs ride the existing additive `run_config` snapshot payload.

---

## 7. Acceptance criteria (M1.3, from the breakdown §3/§6)

1. **A fresh build runs the complete M1.3 loop**, boots into the default play-preset, end-to-end, no blockers — `RG1 M1.3 VERIFY OK`.
2. **Each knob takes effect per run from CFG** (J1 preset + size re-range, J2 spread, J3 density, J4 corridor lever, J5 depth HUD) — and **each verifies individually + stacked**.
3. **The all-off control reproduces the M1.0/M1.1/M1.2 baseline exactly** (fp `e943ac9c8bc1` unmoved; the preset never mutates the code-level default).
4. **Telemetry logs config + opposition events** with all 46 knobs in the snapshot, a **real build SHA**, a clean `corridor_summary` row per run (frac ∈ [0,1]), schema v1 + `run_ended` arity unchanged, and `duration_s > 0` on every completed run.
5. **Multiple runs per session, no leaked nodes.**
6. The build + this doc + the updated tester_readme are **ready for the Director's playtest** (auto-published to itch via DLV1; RG2/RG3 follow).

A build that passes the §3 matrix (headless `RG1 M1.3 VERIFY OK` + the human checklist) and ships the updated tester readme satisfies RG1. Done means: the matrix is filled, the worklog names the commit SHA, and the build launches + loops with the fun config as the boot default, the rooms filled, and the corridor-time telemetry writing.
