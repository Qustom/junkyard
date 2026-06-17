# M1 — As-Built Corrections (canonical)

The M1 task specs (`design/M1_Tasks/<id>_*.md`) were written before implementation and carry
**idealized code sketches** that differ from the real autoload APIs. This doc is the **canonical,
as-built reality** — when a spec sketch and this doc disagree, *this doc wins*. It is the reapply
target for `Addressed` design deviations (see `CLAUDE.md` → "Wave close-out"). Companion to
`M1_Design_Decisions.md` (human-ratified design calls).

**Scope:** reflects `main` through **M1 wave 2** (A1, B1, C1, A2, A3, B2, D1). Wave-3 additions
(C1b's `tier`, E1's `banked_junk`, …) are folded in as those waves integrate.

---

## Autoload APIs (real surface)

### `RNG` (`systems/rng.gd`)
Real methods: `seed_from(value:int)`, `randi()`, `randi_range(from,to)`, `randf()`, `randf_range(from,to)`, `pick(arr)`.
**There is NO `set_seed`, `weighted_pick`, or `fork`** (several specs reference these — they don't exist).
- Seed a deterministic pass with `RNG.seed_from(seed)` once at the top.
- For weighted selection, implement it: integer cumulative weights vs `RNG.randi_range(0, total-1)` (scale float weights to ints once). Keep every branch-affecting decision on integer math for cross-build determinism.

### `GameState` (`systems/game_state.gd`)
Real members (the specs' `banked_money`/`cash_out`/idealized `start_run()` excerpts are NOT real):
- **meta-state:** `money`, `salvage`, `lore`, `exposure`, `knowledge_level`, `unlocked_recipes`.
- **run-state:** `run_active`, `run_seed`, `current_band`, `current_depth`, `unbanked_value`, `run_inventory: RunInventory` (D1).
- **methods:** `start_run(band_id, seed)`, `enter_band(band_id)`, `bank_haul()` (banks `unbanked_value`→`money`), `end_run(reason, duration_s)`, `add_currency(kind, delta, source)`, `add_exposure(delta)`. Death pockets logic in `_on_player_died`.
- Run/meta boundary is enforced here; new run-state is reset in `start_run`, cleared on run end.

### `EventBus` (`systems/event_bus.gd`) — dive lifecycle contract
- **The canonical dive lifecycle signals are `run_started(band_id, seed)` and `run_ended(reason, duration_s, depth_reached)`.** There are **no** `dive_started`/`dive_ended` signals — the A3 dive clock and any future per-dive system **reuse `run_started`/`run_ended`**. `GameState` is the sole emitter.
- Wave-2 signals added (orchestrator-locked before dispatch, so no agent edits `event_bus.gd` in parallel): `interaction_requested`, `interactable_focused`, `interactable_unfocused` (A2); `dive_clock_changed`, `dive_clock_timeout` (A3); `band_generation_started`, `band_generated`, `band_generation_failed` (B2); `run_inventory_changed` (D1).
- Pattern: **pre-declare any new signals on `main` before a parallel wave** so `event_bus.gd` is never edited by two agents at once.

## Collision-layer map (locked)
`2d_physics`: layer 1 = `player`, 2 = `world`, 3 = `interactable`, 4 = `enemy`, 5 = `hazard`, 6 = `pawn` (B1 debug). Reference names, never raw bits. Interactables sit on layer 3; the player body does NOT mask interactables (they're non-blocking Areas).

## Procedural geometry (B1 ↔ B2)
- B1 greybox pieces are solid-walled rects; the **socket `Marker2D` is inset one floor cell** from the edge (on the last interior floor cell, centered on the 2-cell opening).
- Because of that inset, B2 mates pieces by **flush-edge alignment** (candidate placed flush against the host footprint edge on the facing axis, socket lanes aligned on the perpendicular axis) — NOT the specs' raw `cand_cell == sock_cell + dir` formula (which double-counts the inset and overlaps by two columns).
- "Connected AND walkable" = **floor-cell adjacency** (a shared perimeter wall is not a link).
- All placement is integer `Vector2i` cells; pixels only at `cell * cell_size_px` (16). Default `branch_chance = 0.0` (strictly linear spine for M1).

## Testing constraints (headless)
- Autoload globals (`EventBus`, `RNG`, `GameState`) **do not resolve as compile-time globals under `godot --headless --script`**. Tests that touch them must run as a **headless scene** (`.tscn` with an attached script that `quit()`s), or the class under test resolves the autoload via the SceneTree (`Engine.get_main_loop().root.get_node("EventBus")`) — see `RunInventory._emit_changed`.
- This is a workaround for the un-vendored test framework; **revisit when GdUnit4 is vendored (task G2)** — it provides a proper headless harness with autoloads.

## M1 tuning dials (placeholders — revisit at the G4 fun gate / economy workbook)
- Dive clock: `max_light = 60`, `start_light = 0` (→ full), `drain_per_second = 1.0` (60s linear). *(Decision #2 — the most playtest-sensitive M1 number.)*
- Inventory: `base_max_slots = 12` (authored on `InventoryConfig.tres`).
- Junk: `engine_block.slot_size = 6` (bulky ceiling, value/slot ≈ 20). 8-item value spread 3→120 (40×). Tiers 1–5 track value (added in wave-3 C1b).

## Greybox asset norm (M1)
For flat greybox (a `ColorRect`, two flat-color tiles, data-driven shapes from `greybox_color`/`greybox_shape`), the implementing agent **stubs the placeholder inline** rather than dispatching an asset-role subagent. PixelLab/ElevenLabs generation is human-gated (paid credits) and reserved for real assets post-M1.
