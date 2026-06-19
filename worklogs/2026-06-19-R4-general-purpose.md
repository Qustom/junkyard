# Worklog — R4 Maze / Navigation Risk

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.1 (Wave 2 — the four oppositions)
- **Branch:** general-purpose/R4
- **Commit:** b810aa08c858bd20f9ae9036547a2ddb56f7c24e (all R4 code + this worklog)

## What changed

Built R4 — the two navigation-friction levers plus the lost-proxy, per `design/M1_1_Tasks/R4_maze_navigation.md` (§5 pseudocode → §9 acceptance, all §10 Q1–Q6 ratified decisions applied):

- **Lever 1 — depth-scaled branching (generator):** `BandGenerator._select_frontier_index` now takes the active `RunConfig` and computes a depth-scaled fork chance `r4_branch_chance_base + r4_branch_per_depth * grow_depth` (clamped, only while `grow_depth <= r4_max_branch_depth`; above the cap forced linear so deep pieces still chain). `grow_depth` is the deepest frontier socket's **placement-order index** (`OpenSocket.depth`, §10 Q6) — NOT `DepthGrader.depth_index` (unassigned at grow time). The roll is an **integer compare on the RNG autoload** (`RNG.randi_range(0, 9999) < int(round(chance*10000))`), gated on `chance > 0` exactly as M1.0 gated `branch_chance > 0` — so with R4 off the draw never fires and the M1.0 RNG sequence + linear spine are byte-identical. `RunConfig` threaded through `generate()` → `_generate_once()` → `_select_frontier_index()` as an optional trailing arg (default null = M1.0).
- **Lever 2 — limited vision / fog:** new `entities/dive/vision_fog.{gd,tscn}` — a run-state `Node2D` that builds a `CanvasModulate` dark overlay + a player `PointLight2D` (procedural radial gradient texture, no art asset). Radius = `effective_radius(depth) = max(24, r4_vision_radius - r4_vision_tighten_per_depth*current_depth_index)`. Subscribes `EventBus.exposure_vision_mult_changed(mult)` and **multiplies** it into the radius then re-floors (§10 Q4, multiply-don't-add; default 1.0 when R3 off). `r4_fog_enabled` keeps a low-res `revealed` cell `Dictionary` of faint `ColorRect` tints. Cosmetic only — never touches collision/geometry/RNG. `r4_vision_radius == 0` (or R4 off) → no overlay = full M1.0 vision.
- **Lost-proxy:** new `entities/dive/lost_proxy.gd` — Proxy A (time-without-depth-progress, movement-gated, §10 Q1). Accumulates `seconds_wandering` while `player.velocity.length() > 8` and `max_depth_reached` hasn't increased; resets on a new max-depth or on `run_ended` (gate/extract). At `>= r4_lost_proxy_threshold` emits `nav_lost_proxy(&"time_no_depth_progress", seconds_wandering, current_depth_index)`, rate-limited with an escalating `_emit_floor`.
- **`nav_branch_taken`:** emitted from `main_game.gd` once per junction-entry — when the player crosses into a NEW piece with junction_degree ≥ 2. Reuses the BUG2 per-cell depth resolution: a parallel `_cell_to_junction` map (built in `_build_cell_depth_map`) stores `(piece_index, junction_degree)` per floor cell; `_resolve_player_depth` tracks the last owning piece index and fires once on entry. No second spatial system.
- **Dive-scene wiring (`main_game.gd`):** resolved the `RunConfig` ONCE at the top of `start_new_run` and threaded it into `generate()` (was resolved later for staging; now the same object is reused for both generation and `stage_run_config`, so the determinism key is genuinely `(seed + config)`). Added `_spawn_r4_nodes()` (vision/fog + lost-proxy under `_band_container`, so `_clear_band()` frees them — run-state only). All R4 edits kept grouped under clearly-marked `# R4 (M1.1)` blocks for R1's later sequential merge.

## Files touched
- `systems/bandgen/band_generator.gd` — Lever 1: `generate()`/`_generate_once()`/`_select_frontier_index()` take optional `RunConfig`; depth-scaled integer branch roll; `_R4_BRANCH_SCALE` const.
- `entities/dive/vision_fog.gd` (+ `.tscn`, `.uid`) — Lever 2 vision/fog node (run-state, cosmetic).
- `entities/dive/lost_proxy.gd` (+ `.uid`) — Proxy A lost-proxy tracker (run-state).
- `scenes/game/main_game.gd` — thread `RunConfig` into generation; `_spawn_r4_nodes()`; `_cell_to_junction` map + `_maybe_emit_branch_taken()` junction-entry emit; reset `_player_piece_index` per run.
- `tests/test_bandgen_determinism.gd` — extended with `_run_r4_checks` (R4.1 all-off control byte-matches M1.0; R4.2 (seed+config) run-to-run stability; R4.3 branching produces ≥3-degree intersections the linear spine has zero of; R4.4 config legitimately changes the band; R4.5 R4-on stays connected + seals clean). Prints `R4 NAV OK`.

## Checks run
- [x] `godot --headless --import` clean (exit 0, no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK**
- [x] `godot --headless res://tests/test_bandgen_determinism.tscn` → **BANDGEN OK** (all-off control fp `e943ac9c8bc1` unchanged) + **BUG3 SOCKET SEAL OK** + **R4 NAV OK** (exit 0)
- [x] `godot --headless res://tests/test_main_game_loop.tscn` → **MAIN GAME OK** (my main_game.gd edits didn't break the loop)
- [x] `bash tools/run_gdunit.sh` → **30/30 PASSED** (incl. `tests/procgen/test_layout_determinism.gd` — the all-off generator path is unchanged)
- [x] Definition of done (§9): branching takes effect (R4.3) · vision/fog takes effect (Lever 2, off ⇒ no overlay) · lost-proxy + nav_branch_taken log with R4 on, neither fires off · sealed + deterministic under `fingerprint(seed+config)` with all-off byte-matching M1.0 · knobs read from config · `event_bus.gd`/`game_state.gd` NOT edited, `run_ended` arity unchanged.

## Design deviations

1. **As-built name corrections (spec predates the BUG2/TEL merge) — no design change, just used the real live members.** The R4 spec §5b/§5c pseudocode uses `GameState.current_depth` / `max_depth` / `band.fingerprint(seed)`; the real live members are **`GameState.current_depth_index`** and **`GameState.max_depth_reached`**, and the determinism contract is `fingerprint(seed + config)`. Built against the real names. (Pre-flagged in the brief; recording for the As-Built doc.)

2. **`nav_branch_taken` junction-entry seam — reused the BUG2 depth resolver, not a new Area2D.** The spec (§5 note) left the emit site open ("dive-scene piece-entry tracking OR a tiny Area2D-per-piece"). I chose piece-entry tracking off the existing BUG2 `_resolve_player_depth` cell lookup (a parallel `_cell_to_junction` map) — no second spatial system, no new collision. On-spec intent; recording the chosen seam.

3. **Determinism-test "branching took effect" metric = ≥3-degree intersection pieces (not ≥2 junctions).** §9.1 says "more junctions deeper". A ≥2-neighbour count does NOT work as the signal: every interior linear-spine piece already has exactly 2 neighbours, and dead-end branches DROP the ≥2 count (so a branchy band can score LOWER). The unambiguous "a fork appeared" signal is the **≥3-degree intersection**, which the linear M1.0 spine has exactly **zero** of. The test asserts baseline == 0 intersections and R4-on > 0. On-spec intent, sharper metric.

4. **⚠ BUG3 SEAL GAP surfaced by R4 branching — FLAGGED TO BUG3 OWNER, not fixed (out of my file scope).** Exactly the gap §6 predicted ("R4 is the system that will surface any remaining BUG3 gap — flag any unsealed dead-end found back to the BUG3 owner"). Finding: at **high** branch rates (`branch_per_depth ≳ 0.12`, or the aggressive 0.35/cap64), some seeds produce **2–6 floor cells facing off-map void even AFTER `SocketSealer.seal_unused_sockets`** — a branchy placement creates a socket-opening edge that is NOT in `band.open_sockets`, so the sealer never caps it (the fix lives in `systems/bandgen/socket_sealer.gd` / the B2 mating, both other owners' files). **The recommended Director sweep presets (S1 `0.06`/cap8, S3 `0.05`/cap8) seal CLEANLY (0 leaks across all 9 test seeds)** and still produce true intersections (9 and 5 ≥3-degree pieces respectively), so R4's realistic envelope is sealed-and-shippable; the determinism test therefore pins the S1-class curve. **Recommendation:** before the Director runs aggressive sweeps (>~0.1 per-depth), the BUG3 owner should extend the sealer to cap ALL outward-facing perimeter floor edges (not only `open_sockets` lanes), OR R4's `r4_branch_per_depth` should be soft-capped in CFG. Repro: `r4_enabled=true, r4_branch_per_depth=0.35, r4_max_branch_depth=64`, seeds 7/808/424242 → 2 leaks each.

> NOTE on DESIGN_DEVIATIONS.md: per the wave close-out process the orchestrator assembles
> deviation entries from this worklog at Wave 2 close-out; I did not edit the shared
> `design/DESIGN_DEVIATIONS.md` from this worktree. Deviation 4 above is the one needing a
> Director verdict (BUG3 follow-up task vs. CFG soft-cap).

## Handoffs / follow-ups
- **BUG3 owner:** seal-gap on aggressive branching (deviation 4) — recommend a follow-up task to cap all outward perimeter floor edges, or bound `r4_branch_per_depth` in CFG. Not blocking R4's acceptance (realistic sweep seals clean).
- **R1 (hazard spawn):** edits `main_game.gd` AFTER me, sequentially. My R4 edits are grouped under `# R4 (M1.1)` markers (`_spawn_r4_nodes`, `_cell_to_junction`/`_maybe_emit_branch_taken`, the early `run_cfg` resolve) to keep R1's merge clean.
- **TEL:** confirmed `nav_branch_taken(depth, junction_degree)` and `nav_lost_proxy(metric, value, depth)` arities match the pre-declared `event_bus.gd` signals; emit-only, never edited EventBus. `nav_lost_proxy.metric` carries the committed id `&"time_no_depth_progress"`.
- **Confirmed NOT edited:** `systems/event_bus.gd`, `systems/game_state.gd`, `entities/player/player.gd`, `systems/dive/dive_clock.gd`, `ui/hud/`.
