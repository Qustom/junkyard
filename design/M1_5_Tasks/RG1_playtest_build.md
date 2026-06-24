# RG1 — M1.5 Playtest Build (Agency & Legibility — the player can fight back, the threat is place-bound)

**Task id:** RG1 · **Milestone:** M1.5 (Agency & Legibility) · **Workstream:** the re-gate · **Wave:** 3 (sequential, after Waves 1–2 integrate)
**Assignee:** `qa-playtest-coordinator` (build assembly — integrated across Waves 1–2) + the verify matrix
**dependsOn:** **L0** (Wave 1) + **L3, L4** (Wave 1) + **L1, L2, L5** (Wave 2) all integrated on `main`
**Companion docs:** `M1.5_Breakdown.md` (§"Phase 3 Dispositions & Phase 4 Lock" — the Director's FINAL decisions), `M1_4_Tasks/RG1_playtest_build.md` (the template this mirrors), `M1_Tasks/M1_As_Built.md` (canonical APIs), the M1.5 task specs (`L0_*`, `L1_throwing_mechanic`, `L2_spawn_room_pursuer`, `L3_*`, `L4_*`, `L5_hazard_kills_toggles`), `scenes/game/main_game.gd` (the assembled loop + the L1 throw seam `_try_throw`/`_spawn_thrown_item` + the L2 spawn-room-bounds plumbing), `entities/thrown_item/thrown_item.gd` (the projectile), `scenes/hazards/hazard_entity.gd` (the room-bound pursuer), `data/run_config/run_config.gd` (`make_default_play_preset()`)

> **This is the VERIFY + DOCUMENT + PUBLISH task, not new gameplay.** Every M1.5 system (L0–L5) was built and merged in Waves 1–2. RG1 (a) confirms `make_default_play_preset()` ships the M1.5 levers ON, (b) proves the assembled loop boots into it and runs every feature, (c) confirms the all-off control is still byte-identical to the M1.0–M1.4 baseline (fp `e943ac9c8bc1`), (d) confirms config-marked telemetry carries all **89** knobs, and then (e) hands the Director a playable build (published to itch) + config-sweep guidance for the re-gate (RG2/RG3).

---

## 1. Goal & design intent

**Goal:** assemble + verify **one runnable M1.5 build** that proves the Agency/Legibility iteration runs end-to-end — the build **boots into the fun config** (the M1.5 named play-preset): the full **M1.4 fun stack** (quota K2, camera K3, dive timer K4, three new hazards K5a/b/c, jitter K6, exits K7) PLUS the three **M1.5 levers** — **throwing** (`throw_enabled=true`: highlight an inventory item with Q/E, throw with Space; a hit on a hazard-layer body kills it + consumes the item, a miss re-drops it), the **room-bound slow-patrol pursuer** (`r1_spawn_room_only=true`, `r1_patrol_speed=28.0`: the R1 pursuer paces its spawn room and chases only while the player is inside it), and the two **legibility bug-fixes** (L3 money-text below the timer, L4 grab-prompt context-correct — not knob-gated) — and that **config-marked telemetry writes** (all 89 knobs in the snapshot, the new EventBus signals firing) so the re-gate can analyse it against the M1.0–M1.4 baselines.

The loop RG1 must run, unbroken, repeatedly in a session — the **exact M1.4 spine**, now with the M1.5 systems layered on and the **fun config as the boot default**:

```
main_game  →  Config menu (boots seeded with make_default_play_preset(); tune/Reset)  →  Start
   →  dive (M1.4 stack: R1 pursuer + density + maze + K5 hazards + 600s clock + camera + exits
            · PLUS L1 throwing (Q/E highlight, Space throw, hit=kill+consume, miss=re-drop)
            · PLUS L2 room-bound pursuer (patrols spawn room, chases iff player in room)
            · PLUS L3 money-below-timer + L4 context-correct grab prompt)
   →  one of four end-causes:  extract  |  death (hazard catch / kill)  |  timeout (clock)  |  lost
   →  QUOTA CHECK at every run end (cumulative money ≥ target?) — MISS = full roguelite WIPE
   →  bank (extract) OR pockets (fail)  →  sell screen tallies junk→Money
   →  Continue (re-run same config)  OR  Back to Config (switch config)  →  fresh dive
```

**Design intent (one line):** *RG1 is the M1.5 integration + verification + publish capstone, not a new system* — it takes the file-disjoint Wave-1/2 systems (L0 knob/signal foundation, L1 throwing, L2 spawn-room pursuer, L3 money-text, L4 grab-prompt, L5 K5 kill toggles) and confirms they (a) compose in the single `main_game` scene without conflict, (b) the build **boots into** the M1.5 fun preset, (c) each system individually takes effect, (d) all-off **still** reproduces the M1.0–M1.4 baseline EXACTLY (fp=`e943ac9c8bc1`, byte-unmoved — the M1.5 levers are pure run-state and never feed `fingerprint()`), and (e) every run emits a config snapshot carrying all 89 knobs + the right new event rows. RG1 does **not** answer the fun gate — that is RG2 (analysis) → RG3 (verdict, `G4_findings_M1.5.md`).

---

## 2. What's already wired (Waves 1–2 — do NOT rebuild)

The M1.5 build assembly was done by the Wave-1/2 builders; RG1 inherits it. Key seams (verified present by `tests/test_rg1_m15_verify.gd` + the per-L unit suites):

- **L0 config schema** (`run_config.gd`) — the 8 new M1.5 knobs declared with all-off-neutral code defaults (the lone exception is the L5 `*_kills` toggles, which default `true` = today's lethal behaviour, a contract-*preserving* non-`false` default): throw group `throw_enabled=false` / `throw_speed=180.0` / `throw_max_range=320.0`; pursuer group `r1_spawn_room_only=false` / `r1_patrol_speed=0.0`; L5 `hpp_kills=true` / `hbomb_kills=true` / `hspike_kills=true`. `to_flat_dict()` serialises every one; the knob count is **89** (= M1.4's 81 + 8; `test_run_config` + `test_config_menu` pin it). The CFG menu MANIFEST/SECTIONS/FIELD_RANGE rows + CSV stubs exist for every new knob.
- **L0 EventBus signals** — `item_thrown(item_id, depth, run_t_ms)`, `throw_missed(item_id, depth, run_t_ms)`, `throw_killed_hazard(item_id, kind, depth, run_t_ms)` (a DEDICATED kill signal — NOT a reuse of `new_hazard_killed`, which would invert the kill direction and poison RG2's death-by-hazard counts), and `hazard_pursuer_state(state, depth, run_t_ms)` (cheap, additive — RG2 wants pursuer-state counts). L5 declares no signal (a non-lethal K5 hazard still emits `new_hazard_killed`; only `fail_run` is gated).
- **L1 throwing** (`main_game.gd` `_unhandled_input`/`_try_throw`/`_spawn_thrown_item` + `entities/thrown_item/thrown_item.gd` + `.tscn`) — `main_game` reads the `throw` action (Space) and owns the input + the model mutation + the projectile spawn; `inventory_panel.gd` stays a pure view exposing `highlighted_index()`/`highlighted_item()`. The selector navigates Q/E (modulo wrap), re-validates with `clampi` after a throw shrinks the bag, defaults index 0, empty bag → `-1` no-op. The projectile is an **Area2D**, `collision_layer=0`, `collision_mask = world|hazard (=18)`, `body_entered`-driven, one-shot `_spent` guard, hand-integrated motion, parented under `_band_container` so `_clear_band()` disposes it. Hit a `hazard`-group body → `queue_free` it (kill) + consume the item + emit `throw_killed_hazard`; miss (wall / max-range / 5s lifetime fallback) → re-drop via `EventBus.junk_dropped` (the existing JunkSpawner re-spawn path) + emit `throw_missed`. Throw scope (Director-locked) = the R1 pursuer + the K5 ping-pong (any `hazard`-layer body); the bodiless bomb + spike stay un-throw-killable.
- **L1 input remap** (`project.godot` `[input]`) — `interact` = F(70) + joypad-btn0 (E/Space dropped); new `highlight_left`=Q(81), `highlight_right`=E(69), `throw`=Space(32). The `extract` action stays DECLARED (telemetry references `&"extract"` as a run-end cause) but needs no key (gameplay uses only `interact`, disambiguated by interactable id).
- **L2 spawn-room pursuer** (`scenes/hazards/hazard_entity.gd` + `main_game.gd` spawn plumbing) — `HazardEntity.setup` widened to the K5 3-arg family `setup(cfg, player, spawn_ctx := {})` (back-compatible); `main_game` threads `_piece_bounds_at_world`/`_density_spawn_bounds` through **both** R1 spawn helpers (the J2 spread loop AND the J3 density loop) so each pursuer learns its spawn-room `Rect2`. When `r1_spawn_room_only` is ON and the entity has a real room rect, the AWAKE behaviour splits: **chase only while the player is inside the room** (`_room_bounds.has_point`), else **slow patrol** between two RNG-free endpoints (left-mid ↔ right-mid, inset 12px) at `r1_patrol_speed`; catch fires ONLY inside the chase branch. Empty/unknown bounds OR `r1_spawn_room_only` OFF ⇒ today's chase-everywhere behaviour, byte-identical. `hazard_pursuer_state` is emitted on the rising edge of each patrol↔chase transition (no per-frame storm).
- **L3 money-text** (`decision_hud.tscn`) — `HaulValueLabel` repositioned to sit below the dive timer (top-right, right-aligned, anchors 1.0/1.0, offset_top 70); `_refresh_haul()` logic untouched; the "Holding:" text kept verbatim (`tr("HUD_HOLDING")`). Pure `.tscn` layout edit (does not touch generation → no fingerprint move).
- **L4 grab-prompt** (interaction-detector) — `_prompt.visible` driven as a per-frame invariant of `_current != null && is_instance_valid(_current) && _current.can_interact()`; the prompt scene defaults hidden + its baked text cleared; a regression test guards the hide invariant. The nearest+hysteresis selection loop is unchanged. Bug-fix (not knob-gated).
- **L5 K5 kill toggles** (`pingpong_hazard.gd`/`bomb_hazard.gd`/`spike_hazard.gd`) — `hpp_kills`/`hbomb_kills`/`hspike_kills` (default `true` = today's lethal behaviour) mirror R1's `r1_catch_kills`, so a non-lethal preset is expressible. A non-lethal hazard still SPAWNS + behaves + emits `new_hazard_killed`; only the `fail_run(&"death")` call is gated. `_driven_default_preset()` is RETIRED — the verify driver now runs the REAL preset with the K5 kills off for its end-cause matrix.

**The run/meta boundary stays intact:** `RunConfig` (incl. every M1.5 knob + the preset) is run-scoped, never persisted; **no save-schema change in M1.5** (no new persisted meta — throwing, the highlight selector, and the pursuer behaviour are all pure run-state). The default play-preset is a **separate artifact** built on a fresh `RunConfig.new()`, not the code-level all-off default.

---

## 3. RG1 deliverable: the M1.5 fun preset (`make_default_play_preset()`)

RG1 ships the M1.5 fun stack on top of the full M1.4 preset (level scale, quota, R1 pursuer + density, R4 maze, camera, dive timer, three K5 hazards, exits — all already present). The exact M1.5 values set (per the Phase-3 Director dispositions):

| System | Knobs set in the preset | Source |
|---|---|---|
| **L1 throwing** | `throw_enabled=true` (`throw_speed`/`throw_max_range` keep their L0 code defaults 180 px/s / 320 px — sweepable in RG1) | Director FINAL: "ship the agency verb live for RG1." Throw scope = pursuer + ping-pong, no scope knob. |
| **L2 room-bound pursuer** | `r1_spawn_room_only=true`, `r1_patrol_speed=28.0` (≈ half of `r1_chase_speed` 56) | Director-locked (#6): slow patrol within the spawn room, chase iff the player is in the room; pace between two endpoints; `r1_patrol_speed=0` collapses to idle-pivot. Sweepable in RG1. |
| **L5 K5 kill toggles** | `hpp_kills=true`, `hbomb_kills=true`, `hspike_kills=true` (untouched — the preset is LETHAL) | The shipped preset keeps the K5 hazards lethal; only the verify-driver's DRIVEN copy turns them off so a scripted end-cause is reachable. |
| (M1.4 stack) | quota $50 +$50/run cumulative every-run-end; camera 1000px fit_width; timer 600s/60s-left/visual-only; K5×3 at sweep-start magnitudes; exits base 1 / per_depth 0.1 / keep-one / cap 7 | unchanged from the M1.4 preset. |

**Invariants held:** the preset is built on a fresh `RunConfig.new()` and never mutates the code-level all-off default (`throw_enabled`/`r1_spawn_room_only` stay OFF and `r1_patrol_speed` stays 0.0 on a fresh config; the `*_kills` toggles stay `true`, their contract-preserving default); the all-off band fingerprint stays `e943ac9c8bc1`; `inert_enabled_oppositions()` stays empty (the throw/pursuer levers are not R-oppositions and the preset values are provably non-inert). The L1/L2 levers are pure run-state and never feed `fingerprint()`; building the preset must NOT move the all-off fp.

---

## 4. Verify matrix (M1.5)

RG1 is **done** only when this matrix passes. It separates **objective build checks** (headless-automatable by `tests/test_rg1_m15_verify.tscn`) from **subjective fun signal** (RG2/RG3 + human). The headless driver mirrors the M1.4 `test_rg1_m14_verify` shape: it instances the REAL `main_game.tscn`, drives configs through the build's own `start_new_run()`, and exercises the L1 throw seam + the L2 pursuer spawn end-to-end.

### 4.1 Per-feature isolation

| # | Feature | Expected observable | Headless assertion |
|---|---|---|---|
| **L1 throwing** | throw ON; Q/E highlight wraps + re-validates; Space throws in facing dir; hit-pursuer kills + consumes; miss re-drops via `junk_dropped` | A highlighted item is thrown; a hit kills the hazard + destroys the item; a miss re-drops it as a grabbable. F=grab/extract input remap reads at a gate. | The ThrownItem scene loads as an Area2D (layer 0 / mask 18), exposes `setup`; `main_game` declares `_try_throw`/`_spawn_thrown_item`; the assembled seam, driven, spawns a real `ThrownItem` under BandContainer that flies. **HEADLESS PASS.** Q/E highlight + the kill/miss FELT moments are **human-deferred**. |
| **L2 room-bound pursuer** | `r1_spawn_room_only` ON, slow patrol within the spawn room, chase iff player in room | The pursuer paces its spawn room and chases only while you're inside; leave the room = safe. | The assembled build spawns ≥1 `HazardEntity`; `setup(cfg, player, {room_bounds})` threads the spawn-room rect; the patrol/chase branch logic is unit-covered by `test_pursuing_hazard`. **HEADLESS PASS (spawn + bounds plumbing).** The patrol/chase FELT behaviour is **human-deferred**. |
| **L3 money-text** | run-haul money below the dive timer (top-right), right-aligned, legible | The money readout no longer hides behind the inventory. | Pure `.tscn` layout; the repositioned `HaulValueLabel` is covered by the L3 merge. The rendered placement is **human-deferred** (no render headless). |
| **L4 grab-prompt** | prompt visible iff a grabbable is in focus/range | The grab prompt is no longer always on screen. | The hide invariant has a regression test (L4 merge); the rendered prompt is **human-deferred**. |
| **L5 K5 kill toggles** | `*_kills` default `true` (preset lethal); a non-lethal config lets a hazard touch without killing | A `*_kills=false` config lets a hazard touch the player without ending the run. | The shipped preset asserts all `*_kills==true`; the driven verify run sets them `false` and reaches extract/timeout. **HEADLESS PASS.** The felt non-lethal touch is **human-deferred**. |

### 4.2 Stacked + baseline control

| # | Config | Expected | Headless assertion |
|---|---|---|---|
| **Default preset** | `make_default_play_preset()` (the boot config) | The build boots into the full M1.4 stack + the M1.5 levers; loops end-to-end; trap-free; does not leak into the all-off control. | Preset shape (M1.4 stack ON + `throw_enabled=true` + `r1_spawn_room_only=true` + `r1_patrol_speed=28.0` + `*_kills==true`); `inert_enabled_oppositions()` empty; `RunConfig.new()` still all-off after building the preset; CFG `apply_and_get_config()` at boot is the M1.5 stack. **HEADLESS PASS.** |
| **All-off baseline** | **All OFF** | Loop behaves identically to M1.0–M1.4; the generated band is **byte-identical** to the locked baseline. | All-off RunConfig band fp == `e943ac9c8bc1` (== rc-null baseline); building the preset does not move it. **HEADLESS PASS — the determinism guard.** |
| **Reset** | "Reset to baseline" (CFG) | All 89 knobs return to all-off. | Covered by `test_config_menu` (Reset returns the all-off baseline, 89/89 knobs). |

### 4.3 End-cause reachability + telemetry integrity

| # | Check | Expected | Headless |
|---|---|---|---|
| **End-causes** | extract / timeout (+ death via hazards) reachable | extract + timeout observed in `run_ended` rows; the driven run uses `*_kills=false` so a shallow K5 hazard can't pre-empt the scripted cause. | **PASS.** death/kills exercised by the per-L suites + the K5 suites. |
| **Snapshot / 89 knobs** | Config snapshot per run carries the **full 89-knob key set incl. the 8 M1.5 knobs** | Every `run_started.data.run_config` has all `to_flat_dict()` keys + explicitly the new M1.5 keys (`throw_*`, `r1_spawn_room_only`, `r1_patrol_speed`, `h*_kills`). | **PASS** (asserted as a SET, not a magic count — the 89 count is pinned by `test_run_config`/`test_config_menu`). |
| **`run_ended` arity intact** | M1.0 `data` fields present; `duration_s > 0` on every run. | — | **PASS.** |
| **Schema locked** | No row carries a bumped telemetry `SCHEMA_VERSION`. | Every row `v == TelemetrySchema.SCHEMA_VERSION`. | **PASS.** (No save-schema change in M1.5 either.) |

### 4.4 Subjective (NOT RG1 — handed to the human via RG2/RG3)

> "Does throwing feel like real agency (you can answer the danger, not just run)?", "is the highlight selector legible + quick to drive?", "does a thrown item's kill / re-drop read clearly?", "does the room-bound pursuer read as a comprehensible, escapable threat (vs the old always-on chaser)?", "is the money readout now legible below the timer?", "is the grab prompt unobtrusive now?" — RG1 only guarantees the build *lets a human experience and the telemetry capture* these. The fun read is RG3 (Director), backed by RG2's distribution analysis.

---

## 5. Headless verification — proven vs. human-deferred

`tests/test_rg1_m15_verify.tscn` (driver `test_rg1_m15_verify.gd`) runs the matrix and prints `RG1 M1.5 VERIFY OK` on success, exiting non-zero on any failure (CI-gateable).

**Headless-verified (12 rows):** baseline-fp-unmoved (the determinism guard) + preset-does-not-move-it · default-preset-shape (M1.4 stack ON + `throw_enabled=true` + `r1_spawn_room_only=true` + `r1_patrol_speed=28.0` slow-patrol + `*_kills==true` lethal) · trap-free (inert_enabled_oppositions empty) · no-leak-into-default (`RunConfig.new()` stays all-off; the M1.5 levers stay off/neutral) · `to_flat_dict()` carries every M1.5 knob · L1 throw-seam-static (the ThrownItem scene loads as an Area2D layer-0/mask-18 with `setup`; `main_game` declares `_try_throw`/`_spawn_thrown_item`) · CFG-boots-the-preset (the M1.5 stack) · L1 throw-assembled (a real `ThrownItem` spawns + flies under BandContainer through the driven seam) · L2 pursuer-assembled (≥1 `HazardEntity` spawns under the preset; the spawn-room-bounds path is reachable) · 3 driven configs each with snapshot + gating · extract + timeout end-causes (K5 kills off) · `run_ended` arity + `duration_s>0`.

**Human-deferred (rendering / felt — on the manual checklist):**
- L1: Q/E highlight an inventory cell (selector wraps + re-validates); Space throws in the facing direction.
- L1: a thrown item KILLS the pursuer (or ping-pong) on hit + is consumed; a MISS re-drops it as a grabbable.
- L1: F = grab/interact AND extract/descend (the input remap reads correctly at a gate).
- L2: the pursuer PATROLS its spawn room + chases ONLY while the player is inside it (leave the room = safe).
- L3: the run-haul money readout sits BELOW the dive timer (top-right), legible, not behind the inventory.
- L4: the grab prompt shows ONLY when a grabbable interactable is in focus/range.
- L5: a non-lethal preset (`h*_kills=false`) lets a hazard touch the player without ending the run.

---

## 6. Config-sweep guidance for the Director (the re-gate experiment plan)

The re-gate question (RG3): **now that the player can throw to fight back and the pursuer is a room-bound, comprehensible threat (and the two legibility nags are fixed), is the loop a "go"?** The build boots into the M1.5 preset, so the **first sweep is just "play the default."** Then set each config in the Config menu, type a `build_tag`, and run a handful of runs per config (the snapshot self-labels every run). Suggested sweep, in order:

1. **Baseline control (`build_tag: m15-baseline`).** All-off (the menu's **Reset**). A few runs — the permanent M1.0–M1.4 control RG2 segments everything against (byte-identical band, fp `e943ac9c8bc1`).
2. **The default preset, as shipped (`build_tag: m15-default`).** Just **Start** from the boot config. The headline cell — "is the M1.5 stack (agency + room-bound threat + the fixes) fun out of the box?" Several runs.
3. **L1 throw sweep (`build_tag: m15-throw-*`).** Vary `throw_speed` {120, 180, 260} and `throw_max_range` {240, 320, 480}. Answers "does the throw feel responsive + is the miss-range fair?" Toggle `throw_enabled` off for an explicit "no-agency" comparison cell.
4. **L2 pursuer sweep (`build_tag: m15-pursuer-*`).** Vary `r1_patrol_speed` {0 (idle-pivot), 28, 42} and toggle `r1_spawn_room_only` off (the old chase-everywhere pursuer) as an A/B. Answers "is the room-bound patrol the right legibility / is a slow patrol escapable + readable?"
5. **L5 lethality sweep (`build_tag: m15-haz-*`).** Toggle `hpp_kills`/`hbomb_kills`/`hspike_kills` to read each K5 hazard's contribution to deaths in isolation (a non-lethal hazard still spawns + telegraphs, just can't kill).
6. **The carried M1.4 sweeps** (quota, timer, K5 magnitudes, exits) remain valid — see `M1_4_Tasks/RG1_playtest_build.md` §6.
7. **Everything stacked (`build_tag: m15-all-on`).** The default preset + R2/R3 + aggressive hazards + fast throw + the old chase-everywhere pursuer. The "is the whole stack, maxed, fun or chaotic" cell.

**Pin a seed (`seed_override ≥ 0`) for A/B comparisons**; leave it `−1` to vary per loop for distribution data. **`build_tag` convention:** prefix every sweep tag with `m15-`, then a short config handle. The full 89-knob `run_config` snapshot on every `run_started` row is ground truth; `build_tag` is the human-readable handle RG2 groups on.

**New telemetry RG2 should read:** `item_thrown` / `throw_missed` / `throw_killed_hazard` (throw-kill vs miss-redrop counts — did agency land?), and `hazard_pursuer_state` (patrol↔chase transition counts — is the pursuer actually room-bound + escapable in practice?).

---

## 7. Acceptance criteria (M1.5)

1. **A fresh build runs the complete M1.5 loop**, boots into the default play-preset, end-to-end, no blockers — `RG1 M1.5 VERIFY OK`.
2. **Each system takes effect** (L1 throwing, L2 room-bound pursuer, L3 money-text, L4 grab-prompt, L5 K5 kill toggles) — verified individually + stacked (headless where possible, human-deferred for the felt/rendered).
3. **The all-off control reproduces the M1.0–M1.4 baseline exactly** (fp `e943ac9c8bc1` unmoved; the preset never mutates the code-level default; the M1.5 levers never feed `fingerprint()`).
4. **Telemetry logs config + events** with all 89 knobs in the snapshot, schema v1 (telemetry) intact, `run_ended` arity locked, `duration_s > 0` on every completed run, and the new L1/L2 signals available.
5. **Multiple runs per session, no leaked nodes.**
6. The build + this doc + the updated changelog are **ready for the Director's playtest** (published to itch; RG2/RG3 follow).

A build that passes the §4 matrix (headless `RG1 M1.5 VERIFY OK` + the human checklist) and ships the updated changelog satisfies RG1. Done means: the matrix is filled, the worklog names the commit SHA, the build launches + loops with the M1.5 fun stack as the boot default, throwing + the room-bound pursuer wire up, and the config-marked telemetry writes.

---

## 8. Resolved Decisions (pointer)

The Director's FINAL dispositions for M1.5 are in `M1.5_Breakdown.md` §"Phase 3 Dispositions & Phase 4 Lock (2026-06-24 — design LOCKED)". RG1 honours them verbatim: throw scope = pursuer + ping-pong (no scope knob); pursuer = pace-between-two-endpoints at `r1_patrol_speed` (≈ half chase), chase iff player in spawn room; ship `hazard_pursuer_state`; "Holding:" haul text kept verbatim; grab prompt stays up during a rejected-pickup flash. Knob count 81 → **89**. The throw projectile is a new Area2D `entities/thrown_item/thrown_item.gd` (layer 0 / mask 18); the input remap binds F to `interact` (and `extract` stays a keyless declared action), Q/E to highlight, Space to throw.
