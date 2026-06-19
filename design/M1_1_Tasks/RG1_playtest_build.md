# RG1 — Playtest Build (the full loop with risk active)

**Task id:** RG1 · **Milestone:** M1.1 (Greybox Cost Axis) · **Workstream:** (c) the re-gate · **Wave:** 3 (sequential, after all of (b) integrates)
**Assignee:** `general-purpose` (build assembly + loop wiring) + `qa-playtest-coordinator` (build verification matrix)
**dependsOn:** **R1, R2, R3, R4 all integrated on `main`** + **TEL** (config snapshot + opposition event rows) + R0/CFG/BUG1/BUG2/BUG3 (transitively, via wave 1)
**Companion docs:** `M1.1_Breakdown.md` (§4 RG1, §6 wave 3), `M1_Tasks/G3_playtest_build.md` (the M1.0 build this mirrors), `M1_Tasks/M1_As_Built.md` (§"M1 UI / HUD & loop wiring" — the `continue_pressed → start_new_run` seam, sell screen on all 3 end-causes, Telemetry + consent), `scenes/game/main_game.gd` (the assembled loop), `data/run_config/run_config.gd` (R0 `RunConfig` + `stage_run_config`), `TEL_telemetry_config_marking.md` (the config snapshot + event rows)

> **This is a DESIGN / PLAN doc, not implementation.** It defines what RG1 assembles and how the verification runs; the programmer builds against it once R1–R4 are on `main`. No game code is written here.

---

## 1. Goal & design intent

**Goal:** assemble **one runnable greybox build** that proves the full M1.1 loop runs end-to-end **with the cost axis active**, and that **config-marked telemetry writes** so the re-gate (RG2/RG3) can analyse it.

The loop RG1 must run, unbroken, repeatedly in a session:

```
main_game  →  Config menu (CFG: pick/​tune oppositions)  →  Start
   →  dive (R1–R4 read the config; hazard chases / return costs / exposure climbs / maze+fog)
   →  one of four end-causes:  extract  |  death (hazard)  |  timeout (exposure)  |  lost (burns clock→timeout/​death)
   →  bank (extract) OR pockets (fail)  →  sell screen tallies junk→Money
   →  Continue  →  back to a fresh dive (config carry-forward, see §2)
```

**Design intent (one line):** *RG1 is the integration + verification task, not a new system* — it takes the four file-disjoint oppositions that were each built and verified **in isolation** in wave-2 worktrees, stacks them into the single `main_game` scene, and proves they (a) compose without conflict, (b) are each individually toggleable per run from CFG, (c) all-off still reproduces the M1.0 baseline exactly, and (d) every run emits a config snapshot + the right opposition event rows. RG1 carries forward G3's proven loop spine (`continue_pressed → start_new_run()`); it adds **only** the per-run config-rebind seam, not new gameplay.

RG1's deliverable is **a build a human can sit down and play**, plus a **filled verification matrix** (§4) proving the loop is unblocked under every opposition combination the Director will sweep. It does **not** itself answer the fun gate — that is RG2 (analysis) → RG3 (verdict).

---

## 2. Integration design — how it all wires together

### 2.1 The existing spine (already on `main`, unchanged by RG1)

The M1.0/G3 loop spine in `scenes/game/main_game.gd` already provides:

- **`start_new_run()`** — the single loop entry point (`main_game.gd` line 103). Both the menu's Start button and `SellScreen.continue_pressed` call it. It tears down the prior band, generates+grades+plans a new seeded band (B2→B3), materialises geometry, spawns junk (C2), places the gate, repositions the player, then `stage_run_config(...)` → `GameState.start_run()` → `enter_band()`.
- **`SellScreen.continue_pressed → start_new_run`** (line 73) — the G3-owned loop carry-forward. The sell screen presents on **all three** end-causes (extract / death / timeout — `M1_As_Built.md` §Sell screen) over the paused tree; Continue unpauses and loops.
- **`stage_run_config(...)` → `GameState.start_run()`** (lines 150–151) — R0 already wired the config-staging seam. **Today `main_game` hardcodes `load(RUN_CONFIG_PATH)`** (the all-off default `.tres`). **RG1's job is to replace that hardcoded load with the CFG-menu-built config** (see §2.3).
- **Telemetry + consent** — `Telemetry` autoload + the G6 first-run consent modal are already in `_ready()` (lines 79–81). RG1 keeps them; TEL already snapshots `GameState.active_run_config.to_flat_dict()` onto `run_started`.

### 2.2 The opposition seam (added by wave-2 R1–R4, integrated before RG1)

Each opposition reads `GameState.active_run_config` and emits its pre-declared TEL signals. By design (§6 of the breakdown) **none edit `event_bus.gd` or `game_state.gd`** — so stacking them is additive. RG1 inherits their integration but **owns spawning/parenting each opposition node into the dive scene** at `start_new_run` time (see §3). The four:

- **R1 pursuing hazard** — a hazard scene/script spawned into the band; awakens at depth/linger, chases the player, catch → `fail_run(&"death")`.
- **R2 costlier return** — a run-state system (+ a generator decay-behind hook); applies egress cost scaling with `dist_to_gate`.
- **R3 exposure meter** — a run-state meter + HUD readout; climbs with depth, crossings fire penalties, max → `fail_run(&"timeout")`.
- **R4 maze/nav** — a generator `branch_chance` hook + a vision/fog node; deep areas branch, vision tightens, emits a lost-proxy. Requires BUG3's sealed map.

### 2.3 The new RG1 seam — config rebind at run start

This is the **one genuinely new wiring** RG1 adds. The flow:

```
CFG menu writes its sliders/toggles into a RunConfig  (CFG owns this)
        │
        ▼  (on Start, OR on a "re-run same config" path — see §8)
MainGame holds the chosen RunConfig as `_active_menu_config`
        │
start_new_run():
   GameState.stage_run_config(_active_menu_config)   ← replaces the hardcoded load()
   GameState.start_run(BAND_ID, seed)                 ← binds it as GameState.active_run_config
        │
   R1–R4 read GameState.active_run_config at run start; TEL snapshots to_flat_dict() onto run_started
```

**The key design question — does the Config menu re-show each loop, or only at session start? — is RESOLVED (Director-ratified 2026-06-19, §8 Q1): the loop persists the last config; the menu is NOT forced between runs.** Rationale:

- The Director sweeps **one config across many runs** (the breakdown's whole experiment model: a config is a *labelled experiment*, run repeatedly to get a distribution). Forcing the menu every loop would make a clean 10-run sweep of one config tedious and error-prone (easy to mis-set a knob mid-sweep and pollute the sample).
- G3's loop is "Continue → straight back into a fresh dive" — re-showing the menu each loop breaks that proven fast-replay cadence (11 runs/session in M1.0 came from frictionless restart).
- So: **the menu is the explicit configuration step at session start (and any time the Director chooses to re-open it); between runs the loop reuses `_active_menu_config` unchanged.** A new band seed still varies each run; only the *config* persists.

Concretely the loop has **two entry doors into `start_new_run()`**:
1. **From the Config menu (Start button)** — applies the freshly-edited config, then dives. This is how a sweep *begins* (and how the Director switches to a different config).
2. **From `SellScreen.continue_pressed`** — reuses `_active_menu_config` (no menu shown), new seed. This is how a sweep *continues*.

To switch configs mid-session the Director needs a way back to the menu — **RG1 ships a "Back to Config" button on the sell screen** (Director-ratified 2026-06-19, §8 Q2: a sell-screen button, not a hotkey, for discoverability), so the Director can change configs without quitting the session. Continue (door 2) remains the quick re-run; "Back to Config" is the explicit switch-config path. All-off (baseline) is reachable from the menu's existing "reset to M1.0 baseline" action (CFG acceptance), so the in-build control is always one click away.

### 2.4 Run/meta boundary (unchanged, must stay intact)

`RunConfig` is **run-scoped, never persisted** (R0 doc-comment; TDD §2/§3). RG1 holds the active menu config in `MainGame` (a run-level orchestrator node) — **not** in meta-save state. Money + `banked_junk` persist across the loop as before; the config does not touch `meta.sav`. RG1 must not introduce any path that writes a `RunConfig` to `SaveManager`.

---

## 3. Build / scene assembly — what RG1 adds vs. what already exists

| Concern | Already exists (do not rebuild) | RG1 adds / changes |
|---|---|---|
| Loop entry `start_new_run()` | `main_game.gd` line 103 (G3) | Swap the hardcoded `load(RUN_CONFIG_PATH)` for `_active_menu_config` (§2.3). |
| `continue_pressed → start_new_run` | `main_game.gd` line 73 (G3) | Unchanged — reuses `_active_menu_config` (no menu). |
| Config menu (CFG) | CFG built it as a `Control` next to Start Run in `main_game.tscn` | Wire CFG's "config built" output into `MainGame._active_menu_config`; route Start through it. |
| Telemetry config snapshot | TEL wired `to_flat_dict()` onto `run_started` | Verify it fires per run (matrix §4), no new code. |
| R1 hazard node | R1 worktree built the scene/script | **Spawn it into `_band_container` in `start_new_run` when `r1_enabled`** (see §3.1). |
| R2 return-cost system | R2 worktree built the run-state system + generator hook | **Instantiate/activate it for the run when `r2_enabled`**; it reads `dist_to_gate`. |
| R3 exposure meter + HUD | R3 worktree built the meter + HUD readout | **Activate the meter for the run when `r3_enabled`**; ensure the HUD readout is in the tree. |
| R4 maze/fog | R4 worktree built the generator hook + vision/fog node | **Feed `r4_branch_chance*` into the generator before `generate()`; spawn the fog/vision node when `r4_enabled`.** Needs BUG3 sealed map. |
| Band generation | `BandGenerator.generate(seed, _cfg, ...)` (line 112) | R4's branch-chance must reach the generator — **R4 owns the hook; RG1 confirms the config value flows in** (the `_cfg: BandGenConfig` is loaded once; R4 either reads `active_run_config` inside the generator or RG1 passes the per-run branch params). Confirm the seam at integration (§6, dep note). |
| Player group | D3 follow-up noted: add player to `"player"` group | Add `_player` to group `"player"` so R1's chase + R3/R4 can locate the player via `get_first_node_in_group("player")` (G3 follow-up in `M1_As_Built.md` §Drop-to-swap). |
| Back-to-config affordance | — | **New:** a "Back to Config" **button on the sell screen** (ratified §8 Q2), so the Director can switch configs mid-session (§2.3). |

### 3.1 Where each opposition node gets spawned into the dive scene

The dive world is rebuilt every `start_new_run()` inside `_band_container` (torn down by `_clear_band()`). The opposition nodes are **per-run, run-state-scoped**, so they live under `_band_container` (or a sibling per-run container) and are freed with the band — never under the loop-level nodes (`_player`, `SellScreen`, HUD), which persist:

- **R1 hazard** → spawned under `_band_container` after the band materialises + player is positioned (so it can target the player and read entry geometry). Spawn `r1_spawn_count` instances when `r1_enabled`.
- **R2 return-cost** → a run-state system node; either a child of `_band_container` or activated via `GameState` run-state. It needs the graded band (`dist_to_gate`), so activate **after** `grader.compute_return_distance(band)` (line 118).
- **R3 exposure meter** → the meter is run-state; its **HUD readout** is a loop-level HUD element (persists), but the **meter instance/activation** is per-run (reset each dive via `start_run`). Activate when `r3_enabled`.
- **R4 fog/vision node** → spawned under `_band_container` (or as a CanvasLayer child scoped to the run) when `r4_enabled` or `r4_fog_enabled`; the **branch-chance** is applied to the generator *before* `generate()` (line 112), so it must be set at the top of `start_new_run`.

**Ordering inside `start_new_run` (additions in bold):**
1. `_hide_menu()`, `_clear_band()`, `_run_count += 1`, seed.
2. **Read `_active_menu_config`; if `r4_enabled`, apply branch-chance params to the generator inputs.**
3. `generator.generate(...)` → `grader.grade` → `compute_return_distance` → `placer.plan`.
4. Materialise band, spawn junk, place gate, position player, **add player to `"player"` group**.
5. **If `r2_enabled`: activate the return-cost system (reads graded `dist_to_gate`).**
6. **If `r3_enabled`: activate the exposure meter (HUD readout already in tree).**
7. **If `r1_enabled`: spawn `r1_spawn_count` hazard(s) under `_band_container`.**
8. **If `r4_enabled`/`r4_fog_enabled`: spawn the fog/vision node.**
9. `stage_run_config(_active_menu_config)` → `start_run()` → `enter_band()`.

> Steps 5–8 are gated by the per-opposition `enabled` master toggles — that is **what makes all-off reproduce M1.0 exactly**: every opposition spawn is skipped, leaving the unmodified M1.0 dive.

---

## 4. Verification matrix

RG1 is **done** only when this matrix passes. It separates **objective build checks** (automatable / observable, RG1 owns) from **subjective fun signal** (RG2/RG3 + human — out of RG1 scope). Run on the integrated build before handing it to playtesters.

### 4.1 Per-opposition isolation (each ON alone, the other three OFF)

| # | Config | Expected observable | Telemetry expected |
|---|---|---|---|
| V1 | **R1 only** | Hazard awakens per `r1_depth_threshold`/`r1_linger_seconds`, visibly chases, can catch → run ends `death`. | `run_config.r1_enabled=true`; `hazard_awoke`, `hazard_caught` rows present; `run_ended.reason="death"` reachable. |
| V2 | **R2 only** | Retreating from depth `d` costs measurably more than from depth 1 (in-game effect per `r2_mechanism`). | `return_cost_incurred(depth, cost_kind, magnitude)` rows; `cost_kind` matches mechanism. |
| V3 | **R3 only** | Meter climbs faster at depth, crossings fire penalties, max → run ends `timeout`; greybox readout visible. | `exposure_crossed`, `exposure_penalty` rows; `run_ended.reason="timeout"` reachable. |
| V4 | **R4 only** | Deep areas branch / vision limited per config; band stays **sealed** (BUG3, no walk-off-map); lost-proxy logs. | `nav_branch_taken`, `nav_lost_proxy` rows; band `fingerprint()` deterministic per seed+config. |

### 4.2 Stacked + baseline

| # | Config | Expected |
|---|---|---|
| V5 | **All four ON** | Loop runs end-to-end with no crash/soft-lock; oppositions compose (hazard + return cost + exposure + maze all active in one dive); every end-cause still reachable; telemetry carries all four config flags + interleaved event rows. |
| V6 | **All OFF (baseline)** | Loop behaves **identically to M1.0**: linear spine, full vision, free walk-back, no hazard, no meter. `run_config.all_oppositions_disabled` snapshot = all-false. This is the in-build control — confirm it matches the M1.0 G4 baseline behaviour. |
| V7 | **"Reset to baseline" action** | The CFG reset returns all knobs to all-off; a run launched after reset = V6. |

### 4.3 End-cause reachability (every terminal state reachable + sells)

| # | End-cause | How reached | Expected post-state |
|---|---|---|---|
| V8 | **extract** | Reach gate, interact. | `run_ended.reason="extract"`; sell screen titled "EXTRACTED"; banked junk → Money; loop continues. |
| V9 | **death (hazard)** | R1 hazard catches player. | `run_ended.reason="death"`; sell screen "RUN LOST — kept N" (pockets fraction); loop continues. |
| V10 | **timeout (exposure / clock)** | R3 max-meter OR dive clock expiry. | `run_ended.reason="timeout"`; sell screen "RUN LOST — kept N"; loop continues. |
| V11 | **lost (R4)** | Get lost in maze/fog → burn clock/exposure → resolves to `timeout` (or `death` if a hazard is also on). | "lost" is **not its own end-cause** (ratified §8 Q5 — `run_ended` arity unchanged) — it manifests as `timeout`/`death`; `nav_lost_proxy` rows distinguish it in analysis. Confirm the proxy logs and the run terminates (no soft-lock / no stuck-forever). |

### 4.4 Loop + telemetry integrity

| # | Check | Expected |
|---|---|---|
| V12 | **Multiple runs per session** | Start → end → sell → Continue → new dive, repeatable ≥ 3× with no degradation, no leaked nodes (old band/hazard/fog fully freed by `_clear_band`). |
| V13 | **Config snapshot per run** | Every `run_started` JSONL row carries `data.run_config` = the full `to_flat_dict()` key set (asserted generically, NOT by a magic count — 35 keys as of M1.2 I1); empty `{}` only if config truly absent. |
| V14 | **Opposition event gating** | With an opposition ON its event rows appear; with it OFF they do not (no stray hazard/exposure/nav rows in an all-off run). |
| V15 | **`run_ended` arity intact** | `run_ended(reason, duration_s, depth_reached)` unchanged; `duration_s` real (BUG1), `depth_reached` = max within-band depth (BUG2), not 1. |
| V16 | **Config carry-forward** | After Continue, the next run's `run_started.run_config` equals the prior run's (config persists across the loop, §2.3); a new seed differs. |
| V17 | **Build identity** | `run_started.data.build` carries `m1-<date>-<sha>`; `run_config.build_tag` records the Director-typed sweep label (ratified §8 Q3 — `build_tag` is the committed human-readable handle). |
| V18 | **No blockers / soft-locks** | Every state has an exit; no stuck screens; menu reachable; consent prompt (first run) answered then never re-shows. |

### 4.5 Subjective (NOT RG1 — handed to the human via RG2/RG3)

> "Does the gamble feel tense?", "is push-vs-extract a real decision now?" — RG1 only guarantees the build *lets a human experience and the telemetry capture* these. The fun read is RG3 (Director), backed by RG2's distribution analysis.

---

## 5. Pseudocode — loop-restart + config-rebind flow

> Illustrative only (not the as-built API). Shows where the active config is chosen and which config a new run uses. `_active_menu_config` defaults to the all-off baseline so a Start-without-touching-the-menu run = M1.0.

```gdscript
# MainGame — RG1 additions to the existing G3 spine.

var _active_menu_config: RunConfig = null   # the config the loop currently sweeps

func _ready() -> void:
    # ... existing G3 _ready (fixtures, version, sell-screen connect, run_ended, menu, consent) ...
    _active_menu_config = load(RUN_CONFIG_PATH) as RunConfig   # all-off baseline default
    if _active_menu_config == null:
        _active_menu_config = RunConfig.new()                  # belt-and-suspenders all-off
    _cfg_menu.config_applied.connect(_on_config_applied)       # CFG hands us its built config
    # G3: continue_pressed already → start_new_run (reuses _active_menu_config, no menu)

# CFG's Start path: the Director edited knobs, pressed Start → apply + dive.
func _on_config_applied(built: RunConfig) -> void:
    _active_menu_config = built          # this config now sweeps until the Director changes it
    start_new_run()                      # door 1: from the menu

# Door 2 is SellScreen.continue_pressed → start_new_run (NO menu; reuses _active_menu_config).
# Optional "Back to Config" affordance returns to the menu instead of looping:
func _on_back_to_config_pressed() -> void:
    _show_menu()                         # Director re-opens CFG; next Start rebinds the config

func start_new_run() -> void:
    _hide_menu()
    _clear_band()
    _run_count += 1
    var seed := _resolve_seed()          # config.seed_override if >=0, else per-run seed policy
    var cfg := _active_menu_config       # THE config this run uses (carry-forward unless rebound)

    # R4: branch-chance reaches the generator BEFORE generate()
    var gen_inputs := _bandgen_inputs(cfg)   # applies r4_branch_* when r4_enabled, else M1.0 spine
    var band := BandGenerator.new().generate(seed, gen_inputs, _piece_catalog)
    # ... grade, compute_return_distance, plan, materialise, spawn junk, place gate ...
    _player.add_to_group("player")        # so R1 chase / R3 / R4 can find the player

    # Per-opposition spawn, each gated by its master toggle (all-off ⇒ M1.0 dive):
    if cfg.r2_enabled: _activate_return_cost(band, cfg)     # reads dist_to_gate
    if cfg.r3_enabled: _activate_exposure_meter(cfg)        # HUD readout already in tree
    if cfg.r1_enabled: _spawn_hazards(cfg)                  # r1_spawn_count under _band_container
    if cfg.r4_enabled or cfg.r4_fog_enabled: _spawn_fog(cfg)

    # Bind the config + start the run lifecycle (TEL snapshots cfg.to_flat_dict() on run_started).
    GameState.stage_run_config(cfg)
    GameState.start_run(BAND_ID, seed)
    GameState.enter_band(BAND_ID)

func _resolve_seed() -> int:
    if _active_menu_config != null and _active_menu_config.seed_override >= 0:
        return _active_menu_config.seed_override   # reproducible labelled experiment
    return (Time.get_unix_time_from_system() as int) * 31 + _run_count * 2654435761
```

**Which config the new run uses (the load-bearing rule):** a run **always** uses `_active_menu_config`. It is set once from the menu (door 1) and **persists across every `continue_pressed` loop (door 2)** until the Director re-opens the menu and applies a different config. `seed_override` lets the Director pin a layout for an apples-to-apples opposition comparison; left at `-1` (the **ratified default**, §8 Q4 — vary seed per loop), each loop gets a fresh seed (the M1.0 fast-replay cadence).

---

## 6. Files to touch

**Dive-scene assembly + loop wiring (RG1's own edits):**
- `scenes/game/main_game.gd` — add `_active_menu_config`; replace the hardcoded `load(RUN_CONFIG_PATH)` (line 150) with `_active_menu_config`; connect CFG's "config applied" signal; add per-opposition spawn/activation gated by the `enabled` toggles (§3.1); add `_player` to the `"player"` group; add the "Back to Config" affordance.
- `scenes/game/main_game.tscn` — ensure the CFG menu (Control), R3 HUD readout, and any per-run opposition containers are wired in the scene tree; add the "Back to Config" button **to the sell screen** (ratified §8 Q2).

**Verification artifacts (RG1's QA half — `qa-playtest-coordinator`):**
- `tools/playtest/loop_smoke_checklist.md` — **update the G3 checklist** to add the §4 matrix rows (per-opposition isolation, stacked, baseline equivalence, all four end-causes, config-snapshot + event-gating telemetry checks). This is the manual pass run on the integrated build before sharing.
- `tools/playtest/tester_readme.md` — **update** with how to set a config in the menu; per ratified §8 Q3 the **`run_config` snapshot on every `run_started` row is ground truth** for which config ran, with the Director-typed **`RunConfig.build_tag`** sweep label (e.g. `"R1-only-fast"`) as the human-readable handle — the readme tells the human to set the label, NOT to hand-transcribe knob values. Also document where the JSONL lives (`user://telemetry/run_log.jsonl`).

**Read-only dependencies (must already be on `main` — do NOT edit here):**
- `data/run_config/run_config.gd` + `.tres` (R0), `systems/game_state.gd` (`stage_run_config`/`active_run_config`/`fail_run`/`extract_and_end_run`), `systems/telemetry/*` (TEL), the R1–R4 scenes/scripts/systems, `event_bus.gd` (TEL pre-declared all opposition signals).

**Dependency note (hard gate):** RG1 **cannot start** until **R1, R2, R3, R4 are all integrated and green on `main`** and TEL's config snapshot + event rows are live. If any opposition's generator/HUD seam (notably **R4's branch-chance reaching `BandGenerator.generate`** and **R3's HUD readout placement**) wasn't fully wired in its worktree, RG1 closes that seam at integration — flag it at brief time. RG1 also depends on BUG3 (sealed map) for V4/V11 to be fair.

---

## 7. Acceptance criteria

Restated from `M1.1_Breakdown.md` §4 RG1:

1. **A fresh build runs the complete loop** with oppositions on, end-to-end, no blockers.
2. **Each opposition can be toggled per run from the menu** (CFG → `_active_menu_config` → R1–R4 read it).
3. **Telemetry logs config + opposition events** — `run_started.data.run_config` snapshot present every run; opposition event rows appear when ON, absent when OFF; `run_ended` arity unchanged.
4. **Multiple runs per session possible** — Continue loops back into a fresh dive (config carry-forward).
5. (Implicit, from §1/§4) **all-off reproduces the M1.0 baseline exactly** (V6/V7), and **each opposition verifies individually (V1–V4) and stacked (V5)**, with **all four end-causes reachable** (V8–V11).

A build that passes the §4 matrix (V1–V18) and ships the updated smoke checklist + tester readme satisfies RG1. Done means: the matrix is filled, the worklog names the integration commit SHA, and the build launches and loops with risk active.

---

## 8. Resolved Decisions (Director-ratified 2026-06-19 — apply-all-recommendations)

The Director ratified **every** recommendation below as a committed decision (apply-all). Each is now binding on the RG1 build and is propagated into the body (§2.3, §3, §5, §6, §4 matrix) above.

**Q1 — Does the Config menu reappear between runs, or persist the last config?**
**Decision: persist `_active_menu_config` across the loop; do NOT force the Config menu between runs.** The menu is the explicit configuration step at session start and on demand; a sweep is "set config once, Continue-loop N runs." *Rationale:* preserves G3's fast-replay cadence and prevents accidental mid-sweep knob changes from polluting a one-config sample. (Propagated: §2.3, §5 carry-forward rule, V16.)

**Q2 — Should a "quick re-run same config" path AND a "switch config" path both exist?**
**Decision: yes — Continue (door 2) is the quick re-run; add a "Back to Config" button on the sell screen as the switch-config path.** *Rationale:* the carry-forward already gives frictionless re-run; a sell-screen button (chosen over a hotkey for discoverability) lets the Director switch configs mid-session without restarting the app. (Propagated: §2.3, §3 table, §3.1 / pseudocode `_on_back_to_config_pressed`, §6.)

**Q3 — How does a playtester record which config they ran?**
**Decision: the `run_config` snapshot on every `run_started` row is ground truth; the Director-typed `RunConfig.build_tag` sweep label (e.g. `"R1-only-fast"`) is the human-readable handle. The playtester does NOT hand-transcribe knob values.** *Rationale:* the snapshot already carries the full `to_flat_dict()` key set authoritatively (asserted as a set, not a count); `build_tag` rides telemetry alongside the auto build SHA for human-readable labelling; hand-transcription is error-prone. (Propagated: V13, V17, §6 tester_readme.)

**Q4 — Seed policy for comparison: pin or vary?**
**Decision: default to varying seed per loop (`seed_override == -1`); expose `seed_override` for the Director to pin one layout for controlled A/B comparison.** *Rationale:* varying seeds give distribution data at the M1.0 cadence, while pin-on-demand supports apples-to-apples opposition comparison on the same map. (Propagated: §5 `_resolve_seed` + seed-policy note.)

**Q5 — "Lost" end-cause representation.**
**Decision: keep "lost" as `timeout`/`death` distinguished by `nav_lost_proxy` rows; do NOT widen the locked `run_ended` arity.** *Rationale:* RG2 classifies "lost" runs by proxy thresholds in analysis; preserving the arity keeps the telemetry contract stable. (Propagated: V11, V15.)

**Q6 — Does RG1's build ship through the G3 nightly/Butler pipeline, or local-only?**
**Decision: reuse the existing G3 nightly/Butler pipeline; mark M1.1 builds with a distinct channel/build-tag so M1.1 runs are separable from M1.0 baseline runs in returned logs.** *Rationale:* config-marked telemetry returns through the same proven path, and the channel/build-tag convention keeps M1.1 vs M1.0 logs distinguishable. (Propagated: §6 + V17 build identity.)
