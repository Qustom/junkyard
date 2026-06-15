# D1 — Slot inventory data model

**Summary:** Implement the data-driven slot inventory in GameState run-state. Items occupy slots by size/containment flags, and capacity is enforced so a full inventory blocks pickup.

- **Parent task:** D1
- **Dependencies:** C1 (`JunkItem` resource). Consumed by C2 (pickup) and D2 (UI).
- **Acceptance criterion:** Inventory accepts/rejects items by size and capacity; a full inventory blocks pickup; the inventory lives in run-state (not meta-state).

This is the heart of the M1 push/cash-out tension. The bag is small, junk varies in footprint, and the player must choose what to carry out. D1 owns the truth of "what is currently carried" and the rules for whether one more thing fits.

## Assets needed

- `/systems/inventory/run_inventory.gd` — the `RunInventory` class (`RefCounted` or `Resource`), holding the carried items and the add/reject/capacity logic. This is the model; it has no UI and no scene.
- GameState autoload (`/autoload/game_state.gd`) gains a `run_inventory: RunInventory` field. Critical separation: `run_inventory` is **run-state** — wiped on run end, never banked. Banked Money / meta totals live in a separate meta-state section of GameState and are untouched by D1.
- EventBus additions (existing autoload): an inventory-changed signal so D2 and Telemetry react without a hard reference to the model.
- No `.tres` (the model is constructed at run start, not authored). Capacity values *could* be authored on a small `InventoryConfig.tres` if we want designers to tune bag size without code — see Open questions.

The model is deliberately UI-agnostic and entity-agnostic: it knows about `JunkItem` (data) and nothing about `JunkPickup` (world) or the grid Control (view). Everyone else reaches it through `GameState.run_inventory` and reacts to the EventBus signal.

## Code to generate

The model exposes a small, total API: `try_add`, `can_accept`, `remove`, plus capacity queries. It enforces capacity by summing item `slot_size` against a `max_slots` budget (the simple-count model recommended for M1; the grid-spatial variant is an Open question, and `JunkItem` already carries `grid_footprint` for forward-compat).

Containment flags are honored at the gate: an item without the `PLACEABLE` flag is rejected outright (defensive — all M1 junk is placeable, but the rule belongs here).

### EventBus signal

```gdscript
# in EventBus autoload
signal run_inventory_changed(used_slots: int, max_slots: int)
# Emitted after any successful add/remove. D2 refreshes from this; Telemetry logs it.
```

### The model

```gdscript
# /systems/inventory/run_inventory.gd
class_name RunInventory
extends RefCounted

var max_slots: int = 12
var items: Array[JunkItem] = []   # carried junk (run-state truth)

func used_slots() -> int:
    var total: int = 0
    for it in items:
        total += it.slot_size
    return total

func free_slots() -> int:
    return max_slots - used_slots()

func is_full() -> bool:
    return free_slots() <= 0

# Pure predicate — no mutation, no side effects. Safe for UI/AI to ask.
func can_accept(item: JunkItem) -> bool:
    if item == null:
        return false
    if not (item.containment_flags & JunkItem.ContainmentFlag.PLACEABLE):
        return false
    return item.slot_size <= free_slots()

# Mutating add. Returns whether the item was accepted.
# C2's pickup calls this and only removes the world entity on `true`.
func try_add(item: JunkItem) -> bool:
    if not can_accept(item):
        return false
    items.append(item)
    EventBus.run_inventory_changed.emit(used_slots(), max_slots)
    return true

func remove(item: JunkItem) -> bool:
    var idx: int = items.find(item)
    if idx == -1:
        return false
    items.remove_at(idx)
    EventBus.run_inventory_changed.emit(used_slots(), max_slots)
    return true

func clear_run() -> void:
    items.clear()
    EventBus.run_inventory_changed.emit(0, max_slots)
```

### GameState wiring (run-state vs meta-state)

```gdscript
# /autoload/game_state.gd  (excerpt)
# --- RUN-STATE (volatile; reset every run) ---
var run_inventory: RunInventory

# --- META-STATE (persistent; banked across runs) ---
var banked_money: int = 0          # NOT touched by D1

func start_run() -> void:
    run_inventory = RunInventory.new()   # fresh bag each run

func cash_out() -> void:
    # Convert carried junk -> banked Money, then wipe run-state.
    for it in run_inventory.items:
        banked_money += it.base_sell_value
    run_inventory.clear_run()
```

The accept/reject flow end-to-end: C2's `JunkPickup._on_interacted()` calls `GameState.run_inventory.try_add(item)`; on `false` the junk stays in the world (full bag blocks pickup — acceptance criterion); on `true` the entity frees itself and `run_inventory_changed` fires, which D2's grid listens to. Because the bag is reconstructed fresh in `start_run()` and only `banked_money` survives, the run-state / meta-state separation is structurally enforced.

## Open questions

- **Slot model: simple-count vs grid-spatial.** Recommended M1 model is count-based (`used_slots <= max_slots`), which is what the pseudocode implements and is enough to deliver the carry-choice tension. Grid-spatial (Tetris-style placement using `grid_footprint`) is richer but much more UI and validation work. Decide before D2, since it dictates the grid's interaction model. `JunkItem` carries both fields so the model can switch without content migration.
  - **Recommendation:** Lock in simple-count for M1. Summing `slot_size` against `max_slots` already delivers the entire "what's worth carrying" decision the milestone exists to prove, while the Tetris/spatial variant (occupied-cell 2D arrays, rotation, fit-search, drag-placement) is a large UI and validation cost that does not sharpen that decision — it adds a *packing* puzzle on top of the *value* puzzle. Spatial placement is a real design lever (Tarkov/RE4 prove it), but it is a deliberate later choice, not an M1 prerequisite; defer it and rely on `grid_footprint` already being authored so the switch needs no content migration ([source](https://mobiuscode.dev/posts/Drag-&-Drop-Tetris-Inventory-System-in-Godot/)).
- **Containment / nesting in M1.** `containment_flags` and `IS_CONTAINER` exist in the data but D1's logic ignores nesting. Do we implement any container-in-bag behavior in M1, or treat all junk as flat top-level slots and defer nesting?
  - **Recommendation:** Flat top-level slots only in M1 — defer all nesting. D1 should still *honor the gate* (reject items lacking `PLACEABLE`, as the pseudocode does) so the flags are authored and meaningful, but it should not implement any container-in-bag logic. Nesting multiplies capacity-validation complexity (recursive fit, per-container budgets) for zero benefit to M1's single-bag carry tension; keeping the data fields lets it be added later without content migration.
- **Where does `max_slots` come from?** Hard-coded constant, an authored `InventoryConfig.tres`, or upgradeable via meta-progression later? If meta-progression touches bag size, the *value* is meta-derived but the *live inventory* must still be run-state — worth pinning the boundary now.
  - **Recommendation:** Author it on a small `InventoryConfig.tres` (a single `base_max_slots` field, suggest 12 for M1), and have `start_run()` read that value when constructing the fresh `RunInventory`. A `.tres` keeps bag size designer-tunable without a recompile during the heavy M1 playtest-tuning of the capacity/value curve — exactly the lever most worth iterating. Pin the boundary now: bag *capacity value* is meta/config-derived (later, meta-progression can add a bonus to `base_max_slots` at run start), but the *live `RunInventory`* stays run-state, reconstructed each `start_run()` and never banked. So the read happens once at run start; the inventory instance itself remains volatile.
- **Stacking identical junk.** Do two `scrap_bolt`s each consume a slot, or stack into one slot with a count? Stacking changes `used_slots()` math and the UI representation. M1 leans no-stack for simplicity; flag if economy wants stacks.
  - **Recommendation:** No stacking in M1 — each piece of junk occupies its own slot(s). Stacking would *soften* the carry tension (cheap small junk becomes near-free to hoard), which runs against M1's whole point of making "what's worth the space" a real decision; the floor item (`scrap_bolt`) should cost a slot like everything else. It also keeps `used_slots()` a plain sum and the UI one-cell-per-item. If the economy later wants stacks, reintroduce them deliberately as a designed convenience, not a default.
- **Drop / discard from a full bag.** D1 has `remove()` but no policy for "swap this rich item for that bulky one." Is mid-band reshuffling a player action (couples to D2 + C2 re-spawn), or is the bag commit-only until cash-out?
  - **Recommendation:** Make drop a real player action in M1, not commit-only. The push/cash-out tension is incomplete without the inverse choice: hitting a full bag and *deciding to swap* a low-value piece for the engine block on the ground is the most interesting moment the bag produces, and a commit-only bag turns "full" into a dead end. D1 already has `remove()`; the policy is simply "player may drop any carried item," which D2 surfaces (cell drop affordance) and C2 honors (re-instantiate the dropped `JunkPickup` so it can be re-grabbed). No automatic swap logic — the player drops, then picks up; D1 stays a plain add/remove model.
- **Ordering / identity of carried items.** Items are stored as Resource refs in an `Array`. If the same `.tres` is picked up twice, are they distinct instances or shared refs? Matters for `remove(item)` correctness and for any per-instance state (condition, etc.) later.
  - **Recommendation:** Treat carried items as shared refs to the catalog `.tres` for M1 (no per-instance state exists yet, so two `scrap_bolt`s pointing at the same Resource is correct and memory-cheap), but make `remove()` index/instance-safe rather than relying on value identity. Concretely, prefer removing by array index (the cell the player clicked maps to a position) instead of `items.find(item)`, since `find` on duplicate shared refs removes the *first* match, not necessarily the intended one — harmless for identical bolts but wrong the moment per-instance state arrives. This keeps M1 simple while making the later switch to per-instance items (call `item.duplicate()` on pickup when condition/wear lands) a localized change.
