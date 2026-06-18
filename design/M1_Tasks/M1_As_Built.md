# M1 — As-Built Corrections (canonical)

The M1 task specs (`design/M1_Tasks/<id>_*.md`) were written before implementation and carry
**idealized code sketches** that differ from the real autoload APIs. This doc is the **canonical,
as-built reality** — when a spec sketch and this doc disagree, *this doc wins*. It is the reapply
target for `Addressed` design deviations (see `CLAUDE.md` → "Wave close-out"). Companion to
`M1_Design_Decisions.md` (human-ratified design calls).

**Scope:** reflects `main` through **M1 wave 3** (A1, B1, C1, A2, A3, B2, D1 + C1b, E1, D2, B3, C2).

> ✅ **Status: canonical** (Director-ratified 2026-06-17, wave-3 folded in 2026-06-17). When a task
> spec's code sketch and this doc disagree, **this doc wins**. Provenance for each item:
> `DESIGN_DEVIATIONS_HISTORY.md` (M1 waves 1 & 2, and wave 3).

---

## Autoload APIs (real surface)

### `RNG` (`systems/rng.gd`)
Real methods: `seed_from(value:int)`, `randi()`, `randi_range(from,to)`, `randf()`, `randf_range(from,to)`, `pick(arr)`.
**There is NO `set_seed`, `weighted_pick`, or `fork`** (several specs reference these — they don't exist).
- Seed a deterministic pass with `RNG.seed_from(seed)` once at the top.
- For weighted selection, implement it: integer cumulative weights vs `RNG.randi_range(0, total-1)` (scale float weights to ints once). Keep every branch-affecting decision on integer math for cross-build determinism.
- **Deterministic sub-streams (B3 pattern, canonical):** since the autoload has no `fork`/`stream`, a system that needs an independent reproducible stream (so its rolls don't perturb — and aren't perturbed by — the layout RNG) creates a **local `RandomNumberGenerator`** seeded from the band's `resolved_seed` combined with a fixed integer salt. **Do NOT reseed the global `RNG` autoload mid-pass.** B3's `JunkPlacer` uses this; verified that planning leaves `band.fingerprint()` unchanged.

### `GameState` (`systems/game_state.gd`)
Real members (the specs' `banked_money`/`cash_out`/idealized `start_run()` excerpts are NOT real):
- **meta-state:** `money`, `salvage`, `lore`, `exposure`, `knowledge_level`, `unlocked_recipes`, **`banked_junk: Array[JunkItem]`** (E1 — extracted-but-unsold haul; the meta source of truth for itemized junk until F2's sell screen converts it to Money).
- **run-state:** `run_active`, `run_seed`, `current_band`, `current_depth`, `unbanked_value`, `run_inventory: RunInventory` (D1).
- **methods:** `start_run(band_id, seed)`, `enter_band(band_id)`, `bank_haul()` (banks `unbanked_value`→`money`), **`extract_and_end_run()`** (E1 — banks `run_inventory` item *identities* into `banked_junk`, emits `haul_banked(value)`, persists meta, then `end_run(&"extract", ...)`; **no Money credit here** per decision #6; zero-haul extract is valid), `end_run(reason, duration_s)`, `add_currency(kind, delta, source)`, `add_exposure(delta)`. Death pockets logic in `_on_player_died` (drops haul, banks nothing — extract and death paths diverge intentionally).
- Run/meta boundary is enforced here; new run-state is reset in `start_run`, cleared on run end.

### `EventBus` (`systems/event_bus.gd`) — dive lifecycle contract
- **The canonical dive lifecycle signals are `run_started(band_id, seed)` and `run_ended(reason, duration_s, depth_reached)`.** There are **no** `dive_started`/`dive_ended` signals — the A3 dive clock and any future per-dive system **reuse `run_started`/`run_ended`**. `GameState` is the sole emitter.
- Wave-2 signals added (orchestrator-locked before dispatch, so no agent edits `event_bus.gd` in parallel): `interaction_requested`, `interactable_focused`, `interactable_unfocused` (A2); `dive_clock_changed`, `dive_clock_timeout` (A3); `band_generation_started`, `band_generated`, `band_generation_failed` (B2); `run_inventory_changed` (D1).
- Wave-3 signals added: `haul_banked(value)` (E1 — emitted by `extract_and_end_run`); `junk_spawned(item_id, depth)` (B3 — placement/telemetry); `junk_picked_up(item_id, value, slot_size, world_pos, accepted)` (C2 — primitives-only, value snapshotted at pickup, `accepted=false` logs a full-bag rejection); `band_populated(count)` (C2 — Telemetry hook); `junk_dropped(item, world_pos)` (C2 — drop-to-swap re-spawn; see seam note below).
- Pattern: **pre-declare any new signals on `main` before a *parallel* wave** so `event_bus.gd` is never edited by two agents at once. **Sequential** solo dispatches (e.g. wave-3b B3→C2) may edit `event_bus.gd` directly on their branch, since no other agent touches it concurrently.

## Collision-layer map (locked)
`2d_physics`: layer 1 = `player`, 2 = `world`, 3 = `interactable`, 4 = `enemy`, 5 = `hazard`, 6 = `pawn` (B1 debug). Reference names, never raw bits. Interactables sit on layer 3; the player body does NOT mask interactables (they're non-blocking Areas).

## Procedural geometry (B1 ↔ B2)
- B1 greybox pieces are solid-walled rects; the **socket `Marker2D` is inset one floor cell** from the edge (on the last interior floor cell, centered on the 2-cell opening).
- Because of that inset, B2 mates pieces by **flush-edge alignment** (candidate placed flush against the host footprint edge on the facing axis, socket lanes aligned on the perpendicular axis) — NOT the specs' raw `cand_cell == sock_cell + dir` formula (which double-counts the inset and overlaps by two columns).
- "Connected AND walkable" = **floor-cell adjacency** (a shared perimeter wall is not a link).
- All placement is integer `Vector2i` cells; pixels only at `cell * cell_size_px` (16). Default `branch_chance = 0.0` (strictly linear spine for M1).

## Junk schema (C1b — canonical) & depth-scaled placement (B3 ↔ C2)
- **`JunkItem` is the single canonical junk Resource** (`data/junk/junk_item.gd`). The generic `Item` (`data/item.gd`) is **retired** — do not resurrect it; a future non-junk item type is its own purpose-built Resource. Value field is **`base_sell_value: int`** (specs that say `Junk`/`base_value` are stale). Other fields: `id: StringName`, `display_name`, `description` (folded from `Item`), `origin_band` (`surface`→`far`), **`tier: int` 1–5**, `slot_size`, `grid_footprint` (advisory in M1), `containment_flags`, `greybox_color`, `greybox_shape` (`{RECT,CIRCLE,TRIANGLE,DIAMOND}`), `value_per_slot()`. Catalog: `data/junk/junk_catalog.tres` (`JunkCatalog`: `items` + index-aligned `spawn_weights`). There is **no** `junk_pool.tres`.
- **Depth axis (B3):** `PlacedPiece` gains `depth_index` (BFS hops from `band.entry_piece`), `depth_norm` (0..1), `dist_to_gate` (real reverse BFS — equals `depth_index` on the linear spine but survives branching); `Band` gains `max_depth`. `DepthGrader.grade(band)` + `compute_return_distance(band)` must run before placement. Tuning lives in `systems/depth/depth_curve.tres` (`DepthCurve`: near-linear `value_curve` 1.0→1.8, **stepped** `tier_threshold_curve`, ~flat `density_curve`).
- **B3↔C2 seam (canonical):** **B3 decides *what/where/how-much*** — `JunkPlacer.plan(band, curve, catalog, emit_events=false) -> Array[{world_pos, item, depth}]`, a deterministic plan where each `item` is a depth-scaled `duplicate(true)` (only the scalar `base_sell_value` mutated; isolated per-pickup). **C2 decides *spawn & interaction*** — `JunkSpawner.populate(plan, container)` instantiates one `JunkPickup` per plan entry (it is a **pure consumer**: no own weighting, no second RNG roll), plus `spawn_one(item, world_pos, container)` shared with the drop-to-swap path. `JunkPickup` (Area2D) mirrors the gate's A2 owner-pattern (listens to `interaction_requested`, matches its `interactable_id`+focused target); on interact it calls `GameState.run_inventory.try_add(item)`, frees itself only on accept, flashes + stays on reject (full-bag truth shared with D2's panel via `can_accept()`/`is_full()`).

## Save schema (E1)
- **Meta `schema_version` is 2** (E1 bumped 1→2 to add `banked_junk`). Migration step v1→v2 defaults `banked_junk` to `[]` for old saves.
- `banked_junk` **persists as junk `id` strings** (`store_var(.., false)` is objects-OFF) and is **rehydrated from `junk_catalog.tres`** on load; unknown ids (retired `.tres`) are skipped with a warning, not a crash.
- Per the TDD save rule, a schema bump needs a QA migration fixture — tracked as a follow-up task (a v1→v2 meta fixture; the M0 smoke test currently exercises `_migrate_meta` inline only).

## Testing constraints (headless)
- Autoload globals (`EventBus`, `RNG`, `GameState`) **do not resolve as compile-time globals under `godot --headless --script`**. Tests that touch them must run as a **headless scene** (`.tscn` with an attached script that `quit()`s), or the class under test resolves the autoload via the SceneTree (`Engine.get_main_loop().root.get_node("EventBus")`) — see `RunInventory._emit_changed`.
- This is a workaround for the un-vendored test framework; **revisit when GdUnit4 is vendored (task G2)** — it provides a proper headless harness with autoloads.

## M1 tuning dials (placeholders — revisit at the G4 fun gate / economy workbook)
- Dive clock: `max_light = 60`, `start_light = 0` (→ full), `drain_per_second = 1.0` (60s linear). *(Decision #2 — the most playtest-sensitive M1 number.)*
- Inventory: `base_max_slots = 12` (authored on `InventoryConfig.tres`).
- Junk: `engine_block.slot_size = 6` (bulky ceiling, value/slot ≈ 20). 8-item value spread 3→120 (40×). Tiers 1–5 track value (added in wave-3 C1b).

## Greybox asset norm (M1)
For flat greybox (a `ColorRect`, two flat-color tiles, data-driven shapes from `greybox_color`/`greybox_shape`), the implementing agent **stubs the placeholder inline** rather than dispatching an asset-role subagent. PixelLab/ElevenLabs generation is human-gated (paid credits) and reserved for real assets post-M1.
