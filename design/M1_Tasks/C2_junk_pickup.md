# C2 — Junk pickup in the band

**Summary:** Spawn junk pickups into the proc-gen band via seeded RNG, and let the player's interaction component pick them up — removing them from the world, adding them to run inventory, and firing a telemetry-able EventBus event.

- **Parent task:** C2
- **Dependencies:** A2 (interaction component), B2 (band generator), C1 (`JunkItem` resource), D1 (run-state inventory model)
- **Acceptance criterion:** Junk spawns in the generated band; interacting picks it up, removes it from the world, and adds it to run inventory; a pickup event fires on EventBus (and is therefore visible to Telemetry).

This is the integration task that ties content (C1), generation (B2), interaction (A2), and inventory (D1) together into the core loop's first half: find junk → grab junk → fill your limited bag.

## Assets needed

- `/entities/junk_pickup/junk_pickup.tscn` — the world entity for a single piece of junk. Suggested node tree:
  - `JunkPickup` (`Area2D`, script below) — interactable body.
    - `Collision` (`CollisionShape2D`) — interaction/overlap region.
    - `Greybox` (`Polygon2D` or a `Node2D` that draws via `_draw`) — renders the `JunkItem.greybox_color` + `greybox_shape`. No sprite asset; shape is data-driven.
    - `Interactable` (the A2 interaction component, instanced) — exposes a `prompt` and an `interact()` entry point so the player's interaction component can drive it.
- `/entities/junk_pickup/junk_pickup.gd` — the entity script.
- `/systems/spawning/junk_spawner.gd` — system that, given a generated band region + seeded RNG + the C1 catalog, instances `junk_pickup.tscn` at chosen positions. Owned by C2; consumes B2's output.
- No new `.tres` (uses C1's items / catalog).
- EventBus additions (see below) live in the existing `EventBus` autoload, not a new file.

The spawner is a system, not a node baked into the band scene, so generation logic stays out of the scene tree and can be unit-reasoned. It listens for / is called after B2 emits "band generated".

## Code to generate

Three pieces: an EventBus signal contract, the pickup entity, and the spawner.

### EventBus signals

Add a single junk-picked-up signal. Payload carries the item id (not the Resource ref) so Telemetry can serialize it straight to JSONL, plus enough context to be analytically useful.

```gdscript
# in EventBus autoload
signal junk_picked_up(item_id: StringName, value: int, world_pos: Vector2, accepted: bool)
# `accepted == false` means inventory rejected it (full / no fit) — still logged.
```

Telemetry already subscribes generically to EventBus signals and writes JSONL, so no Telemetry code is needed beyond confirming this signal is in its watch list.

### Pickup entity

The entity is initialized from a `JunkItem`, draws itself from the greybox data, and on interact delegates the accept/reject decision to D1's inventory (via GameState run-state). It only removes itself from the world if the inventory *accepted* the item — a full bag must leave the junk lying there (this is the capacity tension made physical).

```gdscript
# /entities/junk_pickup/junk_pickup.gd
class_name JunkPickup
extends Area2D

var item: JunkItem

func setup(p_item: JunkItem) -> void:
    item = p_item
    _apply_greybox()   # set color + shape on the Greybox child from item data

func _on_interacted() -> void:
    # Called by the A2 interaction component when the player interacts.
    var accepted: bool = GameState.run_inventory.try_add(item)  # D1 API
    EventBus.junk_picked_up.emit(item.id, item.base_sell_value, global_position, accepted)
    if accepted:
        queue_free()        # remove from world only on success
    else:
        _flash_rejected()   # greybox feedback: bag full / no fit
```

### Spawner

Driven entirely by the seeded RNG autoload so a given run seed reproduces the same junk layout. It pulls candidate items from the C1 catalog (weighted), and positions from the B2 band's spawn anchors (or sampled within the band region). The spawner does not own world-state truth — it just instances entities.

```gdscript
# /systems/spawning/junk_spawner.gd
class_name JunkSpawner
extends Node

@export var pickup_scene: PackedScene          # junk_pickup.tscn
@export var catalog: JunkCatalog               # C1 spawn pool

# Called after B2 emits its "band generated" signal.
func populate(band: BandRegion, container: Node) -> void:
    var rng := RNG.stream("junk_spawn")        # seeded, deterministic sub-stream
    var spawn_points: Array[Vector2] = band.get_junk_anchors()  # from B2
    for pos in spawn_points:
        if not _should_spawn_here(rng):
            continue
        var item: JunkItem = _pick_weighted(rng, catalog)
        var pickup: JunkPickup = pickup_scene.instantiate()
        container.add_child(pickup)
        pickup.global_position = pos
        pickup.setup(item)

func _pick_weighted(rng: RandomNumberGenerator, cat: JunkCatalog) -> JunkItem:
    # weighted draw using cat.spawn_weights (fallback: uniform)
    ...
    return cat.items[index]
```

Note the deterministic-RNG discipline: the spawner asks RNG for a named sub-stream (`"junk_spawn"`) so its draws don't desync other systems that also pull from the seeded RNG. If B2 already places anchors deterministically, the spawner only adds the item-selection randomness on top.

## Open questions

- **Spawn distribution shape:** uniform random across the band, density tied to a "depth/danger" gradient, or anchor-driven (B2 hands explicit junk-spawn points)? Affects how `populate` consumes B2's output. Recommendation: B2 emits anchors, C2 decides what/whether — clean separation.
  - **Recommendation:** Confirm the stated split: B2 owns *where junk can go* (deterministic anchors from the band layout), C2 owns *whether and what* (per-anchor spawn roll + weighted item draw from the catalog). For M1 keep C2's per-anchor decision simple — a flat spawn probability plus the catalog weights — and do not yet wire a depth/danger gradient. A gradient is a good push/cash-out amplifier (richer junk deeper in), but it depends on B2 exposing a depth scalar per anchor; treat it as a fast follow once that scalar exists, since the seam (anchor carries optional metadata C2 may read) is already clean.
- **Spawner trigger:** does the spawner subscribe to a B2 EventBus signal, or does the band scene call it directly after generating? Signal keeps it decoupled per the architecture; direct call is simpler if ordering matters.
  - **Recommendation:** Direct call after generation, not an EventBus signal. Spawning has a hard ordering dependency (the band geometry and anchors must exist before junk is placed) and a data dependency (the spawner needs the concrete `BandRegion`/container references), which a fire-and-forget signal models poorly — you would end up passing the band through the payload anyway and racing on order. Reserve EventBus for the *outcome* (the existing `junk_picked_up`, plus an optional `band_populated` notification for Telemetry), and let the band's generation step explicitly invoke `JunkSpawner.populate(band, container)` as a sequenced sub-step. This keeps the decoupling where it pays (observers) without faking decoupling on a step that is genuinely sequential.
- **Reject UX on full bag:** what does "couldn't pick up, bag full" feel like? Just a flash + the junk stays? A prompt change ("Bag full")? This is where the cash-out tension surfaces in moment-to-moment play — worth a deliberate affordance even in greybox.
  - **Recommendation:** Do both, on two surfaces, even in greybox: (1) the interaction prompt flips proactively — when the player is in range of junk that won't fit, the prompt reads "Bag full — won't fit" instead of "Pick up", so the player learns the constraint *before* committing; and (2) on a rejected interact, the pickup `_flash_rejected()` pulses (e.g. red flash) and the junk stays in the world. Keep the rejection distinguishable from a successful grab by feedback only (no inventory change). This is also where C2 and D2 must agree (see D2's full-bag signaling question), so the prompt's "full" state and D2's red capacity bar should trip from the same `is_full()`/`can_accept()` truth in D1.
- **Value/id in payload:** is `value` in the event the snapshot at pickup time (recommended, so telemetry survives later value-tuning), or re-derived on read? And do we also want the slot footprint in the payload for capacity analytics?
  - **Recommendation:** Snapshot at pickup time — `value` is `base_sell_value` as it was when grabbed, baked into the JSONL row so a later value-tuning pass cannot retroactively rewrite historical telemetry. Yes, add `slot_size` to the payload too: pickups are exactly where capacity-pressure analytics live ("what value-per-slot do players actually pick up vs. leave?"), and it is one cheap int. Extend the signal to `junk_picked_up(item_id, value, slot_size, world_pos, accepted)`. Keep the payload primitives-only (no `JunkItem` ref) so Telemetry serializes straight to JSONL.
- **Re-pickup after drop:** if D2 lets the player drop junk, does it re-instantiate a `JunkPickup` in the world (so it can be re-grabbed) or vanish? Couples to D2's drop interaction.
  - **Recommendation:** Tie this to D1/D2's drop decision: M1 should ship drop-to-swap, and a dropped item must re-instantiate a `JunkPickup` at the player's position (re-grabbable), not vanish. Vanishing drops break the core "trade the bulky thing for the rich thing" loop — the player needs to be able to reconsider. Give the spawner a small public `spawn_one(item, pos, container)` entry point so the drop path (driven from D2 → D1.remove → world) reuses the same instantiation code rather than duplicating it. Dropped pickups carry no special state; they are ordinary `JunkPickup`s.
- **Determinism across save/reload:** if a run is saved mid-band and reloaded, are already-spawned/already-grabbed pickups restored from saved world-state, or re-derived from seed + a "collected ids" set? Touches SaveManager scope for M1.
  - **Recommendation:** Out of scope for M1 — do not implement mid-band save/reload of world pickups now. M1 is greybox proving the core loop; mid-run persistence is a SaveManager feature to scope later. When it does land, prefer re-derive-from-seed plus a collected-set rather than serializing every world entity: because spawning is fully deterministic from `RNG.stream("junk_spawn")` + the band seed, reload can replay the same layout and then subtract a saved set of consumed/dropped anchor states. That keeps the save tiny and leans on the determinism discipline already built in. The only thing to do *now* is keep spawning a pure function of seed (no off-stream randomness) so this option stays open.
