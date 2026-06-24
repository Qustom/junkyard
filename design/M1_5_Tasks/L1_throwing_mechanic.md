# L1 — Throwing Mechanic · Per-task Design (Phase 2)

**Milestone / iteration:** M1.5 (Agency & Legibility), Wave 2.
**Stable id:** L1. **Role(s):** `general-purpose` (programmer, owns the projectile + input + throw seam) + `ui-ux-designer` (the highlight selector view).
**Blocked by:** L0 (reads the `throw_*` knobs L0 freezes; emits the throw signals L0 pre-declares).
**Authored:** 2026-06-24 (Phase 2). Status: **draft — Open Questions unresolved** (Phase 3 fresh-eyes + Director dispositions pending).

> **The one thing L1 must prove:** the player can *answer* danger, not only flee it — highlight a carried item (Q/E), **Space** to throw it in the facing direction, **hit the pursuer → it dies + the item is consumed**, **miss → the item re-drops as a grabbable pickup**. All pure run-state, knob-gated, all-off baseline byte-identical.

---

## (a) Research on the premise

### Why agency-against-danger matters (the playtest finding)

The M1.4 post-Wave-5 playtest verdict was **ITERATE** (`design/M1_4_Tasks/G4_findings_M1.4.md` §RG3). The headline gap: the danger (the R1 pursuer, `scenes/hazards/hazard_entity.gd`) reads as **"something you can only run from, never answer."** The pursuer wakes, chases in a straight line, and the only player verbs against it are *move away* and *break line-of-sight on a wall* (the I2 "refuge" behaviour, `hazard_entity.gd:43-57`). There is no offensive verb in the run loop at all — the inventory is a pure *keep/drop economy surface* (`ui/inventory/inventory_panel.gd`), never a *toolbox*.

L1 adds the missing verb: **spend a carried item to kill a pursuer.** This does three things the gate wanted:
1. **Turns the inventory into a decision under pressure** — every carried item is now *both* sale value (the D1/D2 economy) *and* a potential weapon. Throwing a high-value item to survive is a real push-your-luck cost (you lose the sale), which is exactly the tension the GDD's extraction loop is built on.
2. **Makes the pursuer a beatable obstacle**, complementing L2 (which makes it *comprehensible* — room-bound). Together: a threat you understand and can answer.
3. **Reuses the existing drop-to-swap reversibility** — a *missed* throw is just the existing `EventBus.junk_dropped` re-spawn (`systems/spawning/junk_spawner.gd:73`), so the item is never destroyed on a miss; it lands where it fell and is re-grabbable. No new world-entity lifecycle to invent.

### What this builds on in-repo (cited)

**Player facing (the throw direction).** `entities/player/player.gd:22` declares `var facing: Vector2 = Vector2.DOWN`, updated each physics frame from the movement input at `player.gd:50-51` (`if input_dir != Vector2.ZERO: facing = input_dir.normalized()`). It is documented as "exposed read-only" for downstream consumers. **The throw reads `player.facing` for the projectile direction** — no refactor needed; defaults to DOWN so a stationary fresh player still throws in a defined direction.

**Run inventory (the source the throw removes from).** `systems/inventory/run_inventory.gd` is the run-state truth: `var items: Array[JunkItem]` (`run_inventory.gd:25`), `max_slots` (`:24`), index-safe `remove_at(index) -> JunkItem` (`:80-86`, returns the removed item or null on bad index), and instance-safe `remove(item) -> bool` (`:93-101`). Every mutation calls `_emit_changed()` (`:33-38`), which fires `EventBus.run_inventory_changed(used, max)`. **The throw is `remove_at(highlighted_index)` → spawn a projectile with the returned item.** It is RefCounted run-state, wiped each run (`clear_run()`, `:105-107`) — never persisted, never banked (`run_inventory.gd:11-13` boundary note). This is exactly the contract L1 needs: throwing is pure run-state.

**Inventory UI (where the highlight selector lives).** `ui/inventory/inventory_panel.gd` is a **pure view** that rebuilds cells on every `EventBus.run_inventory_changed` (`inventory_panel.gd:32-33,42-45`) via full clear-and-repopulate (`_rebuild_cells`, `:83-100`). It builds one `InventoryCell` per item at array index `i` (`:87-93`, `cell.set_item(item, i)`) plus `free_slots()` empty placeholder cells. `ui/inventory/inventory_cell.gd` is the per-cell view: it holds `_index` and `_item` (`inventory_cell.gd:29-30`), draws a greybox shape via `_draw_greybox` bound to the `$VBox/Greybox` child's `draw` signal (`:33-38, 100-138`), and already has a drop gesture (`drop_requested(index)` on right-click, `:80-87`). **The highlight selector adds a highlighted-index to the panel, a `highlight(on)` call on the cell, and Q/E navigation** — re-using the panel's existing rebuild hook so the selector re-validates when the inventory shrinks. The cell's `.tscn` is a `PanelContainer` (`inventory_cell.tscn:5`); the highlight is a draw/stylebox treatment on it (see Open Questions).

**JunkPickup (the greybox look + the re-drop target).** `entities/junk_pickup/junk_pickup.gd` is an `Area2D` (`:2`) with a `setup(item)` initializer (`:52-58`), a `$Greybox` Node2D that draws the item's shape via `_draw_greybox(canvas)` (`:115-136`, RECT/CIRCLE/TRIANGLE/DIAMOND from `item.greybox_shape`/`greybox_color`, half-extent `r=10.0`), and an `$Interactable` Area2D child on `collision_layer=4` (bit 3 = `interactable`) with `interactable_id=&"junk"` (`junk_pickup.tscn:19-25`). **The thrown projectile reuses the same `_draw_greybox` look** (copy the draw, or extract a shared helper) so a thrown item visually reads as the item it is. **A miss re-spawns a real `JunkPickup`** via the existing path — see below.

**The miss → re-drop path (REUSE, do not reinvent).** `EventBus.junk_dropped(item: JunkItem, world_pos: Vector2)` (`systems/event_bus.gd:66`) is already wired: `JunkSpawner._on_junk_dropped` (`junk_spawner.gd:73-77`) calls `spawn_one(item, world_pos, _drop_container)` whenever it fires, re-spawning an ordinary re-grabbable `JunkPickup` at the position — *identical to a planned pickup, no special dropped-state* (`junk_spawner.gd:71-72`). The `_drop_container` is the band container, registered in `populate()` (`junk_spawner.gd:39`). **So a missed throw is literally `EventBus.junk_dropped.emit(thrown_item, landing_pos)` and the spawner does the rest** — the item lands where it stopped and is grabbable again. This is the same mechanism D2's drop gesture uses (`inventory_panel.gd:127-141`).

**HazardEntity (the kill target).** `scenes/hazards/hazard_entity.gd` is a `CharacterBody2D` (`:2`), `class_name HazardEntity`, in group `"hazard"` (`hazard_entity.tscn:8`), on **`collision_layer=16` (bit 5 = `hazard`), `collision_mask=2` (bit 2 = `world`)** (`hazard_entity.tscn:9-10`). It has **no health** — the catch is a distance test (`hazard_entity.gd:143-159`) and a fatal catch just routes through `GameState.fail_run(&"death")`. **A throw-kill is therefore `hazard.queue_free()`** (greybox: no death anim required). It already emits `EventBus.hazard_caught`; a *throw*-kill wants its own telemetry (see (c) + the L0 signal).

**Collision-layer bits (`project.godot:115-122`):** `layer_1=player`, `layer_2=world`, `layer_3=interactable`, `layer_4=enemy`, `layer_5=hazard`, `layer_6=pawn`. So mask values: `world`=2, `interactable`=4, `hazard`=16. The pursuer (R1) and the K5 ping-pong are CharacterBody2D bodies on layer `hazard` (16); **the K5 bomb and spike are plain `Node2D` with NO physics body** (`bomb_hazard.tscn:5` / `spike_hazard.tscn:5` are `type="Node2D"`, distance-based, no collision shape on any layer). This is load-bearing for the throw-vs-K5 scope question (see (c)).

**Input map (`project.godot:52-109`) — current state.** `interact` = physical **E** (keycode 69) + **Space** (keycode 32) + joypad button 0; `extract` = physical **Q** (keycode 81) + joypad button 1. **Crucial finding:** the `extract` action is **dead in gameplay code** — `grep` over `entities/ components/ scenes/ systems/ ui/` shows the *only* reader of `"interact"` is `InteractionDetector._unhandled_input` (`interaction_detector.gd:64`) and `interaction_prompt.gd` (label hint, `:56-58`); **nothing reads `"extract"` at all.** Both the `JunkPickup` and the `ExtractGate` fire off the SAME `EventBus.interaction_requested` signal, which the detector emits for the single focused interactable on the `interact` action (`interaction_detector.gd:63-69`); the gate (`extract_gate.gd:40-51`) and pickup (`junk_pickup.gd:63-68`) each filter by `interactable_id` (`&"gate"` vs `&"junk"`). **So "grab" and "extract/descend" are already one action (`interact`) disambiguated by which interactable is focused — not by two separate keys.** The Director's "F = grab AND extract/descend (one key, contextual)" is *already the architecture*; L1's remap just renames the key and frees Q/E/Space for the selector + throw (see the disambiguation note in (c)).

**Knob house style (`data/run_config/run_config.gd`).** Levers are contiguous-prefix `@export var` groups defaulting off/neutral: `r1_enabled: bool = false` (`:59`), `r1_chase_speed: float = 0.0` (`:65`), `r1_catch_kills: bool = false` (`:79`), etc. There are currently **72 `@export var`** knobs; `to_flat_dict()` mirrors every one (e.g. `"r1_enabled": r1_enabled`) into the flat telemetry/coverage dict. `make_default_play_preset()` is the separate "fun" artifact. **L0 (not L1) pre-declares the `throw_*` group + extends `to_flat_dict()` + bumps the knob-count tests** (M1.5 Breakdown §3 L0 row, §6); L1 only *reads* the frozen knobs. The proposed throw group is in (c) Open Question 6.

---

## (b) Pseudocode (illustrative, against the real as-built APIs)

> All snippets are illustrative. The real knob names/defaults are frozen by **L0**; the signal names below are pre-declared by **L0** (L1 only emits them).

### 1. Input-map remap (`project.godot [input]`) — owned by L1, no other M1.5 task touches input

```ini
# F = grab/interact AND extract/descend (one contextual action — already the architecture:
#     the focused Interactable's id, not the key, picks grab-vs-gate). Replaces E+Space on interact.
interact  = { events: [ Key(physical F / keycode 70), JoypadButton 0 ] }     # was E + Space + btn0
# extract stays declared (telemetry/schema reference it as a *cause*, never as an input) but is
# REBOUND off Q so Q is free for the selector. Option: drop the Q keyboard event, keep btn1.
extract   = { events: [ JoypadButton 1 ] }                                   # was Q + btn1
# NEW — highlight selector (run inventory):
highlight_left  = { events: [ Key(physical Q / keycode 81) ] }
highlight_right = { events: [ Key(physical E / keycode 69) ] }
# NEW — throw the highlighted item:
throw           = { events: [ Key(Space / keycode 32) ] }
```

*(`interaction_prompt.gd:_derive_key_hint()` reads the first keyboard event of `interact` and will now display `[F]` automatically — no code change, `interaction_prompt.gd:53-65`.)*

### 2. Highlight-index state machine — in `inventory_panel.gd` (the ui-ux half)

The panel already rebuilds on `run_inventory_changed`. We add a single integer of selector state and re-validate it in `_refresh()`.

```gdscript
# --- L1 highlight selector state (run-state view only; never touches the model truth) ---
var _highlight_index: int = -1   # index into RunInventory.items; -1 == nothing highlighted

## Public read seam the throw uses (Open Q 2 decides direct-ref vs signal).
func highlighted_index() -> int:
    return _highlight_index

func highlighted_item() -> JunkItem:
    var inv := GameState.run_inventory
    if inv == null or _highlight_index < 0 or _highlight_index >= inv.items.size():
        return null
    return inv.items[_highlight_index]

func _refresh() -> void:
    ...                                  # existing clear/rebuild/capacity
    _revalidate_highlight()              # NEW: clamp/wrap after the inventory changed
    _apply_highlight_visual()

## Re-validate after any inventory change (throw/pickup shrank or grew items).
func _revalidate_highlight() -> void:
    var inv := GameState.run_inventory
    var n := 0 if inv == null else inv.items.size()
    if n == 0:
        _highlight_index = -1            # empty bag: nothing highlighted (Open Q 5)
    elif _highlight_index < 0:
        _highlight_index = 0             # first non-empty: default to slot 0
    else:
        _highlight_index = _highlight_index % n   # clamp into range (a throw shrank it)

func _move_highlight(step: int) -> void: # +1 = right (E), -1 = left (Q); WRAPS
    var inv := GameState.run_inventory
    var n := 0 if inv == null else inv.items.size()
    if n == 0:
        _highlight_index = -1
        return
    _highlight_index = ((_highlight_index + step) % n + n) % n   # wrap both directions
    _apply_highlight_visual()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("highlight_left"):  _move_highlight(-1)
    elif event.is_action_pressed("highlight_right"): _move_highlight(+1)

func _apply_highlight_visual() -> void:
    # Tell each item cell whether it is the highlighted one (panel knows index→cell:
    # cells are appended in items order, so child[i] over the item cells maps to index i).
    var item_cells := _item_cells()          # the non-empty cells, in items order
    for i in item_cells.size():
        item_cells[i].set_highlighted(i == _highlight_index)
```

`inventory_cell.gd` gains a tiny view method (no truth):

```gdscript
var _highlighted: bool = false
func set_highlighted(on: bool) -> void:
    _highlighted = on
    queue_redraw()        # or toggle a StyleBox / border overlay (Open Q 5)
```

### 3. Throw-request seam — signal-driven (conventions: decouple via EventBus)

The throw lives where input + player + band are all reachable: **`main_game.gd`** (it already owns the band container and resolves the player). It listens for a `throw` press, asks the panel for the highlighted item, removes it from the model, and spawns the projectile. Whether it asks the panel *directly* or via a signal is **Open Q 2**; the recommended decoupled shape:

```gdscript
# --- in main_game.gd (or a small ThrowController node it owns) ---
func _unhandled_input(event: InputEvent) -> void:
    if not GameState.run_active: return
    if event.is_action_pressed("throw"):
        _try_throw()

func _try_throw() -> void:
    var cfg := GameState.active_run_config
    if cfg == null or not cfg.throw_enabled: return        # knob gate (all-off => no-op)
    var idx := _inventory_panel.highlighted_index()        # direct ref (Open Q 2 recommended)
    if idx < 0: return                                     # empty bag: nothing to throw
    var inv := GameState.run_inventory
    var item := inv.remove_at(idx)                         # fires run_inventory_changed → panel re-validates
    if item == null: return                                # raced/stale index — abort cleanly
    _spawn_thrown_item(item, _player.global_position, _player.facing)

func _spawn_thrown_item(item: JunkItem, origin: Vector2, dir: Vector2) -> void:
    var proj := THROWN_ITEM_SCENE.instantiate() as ThrownItem
    _band_container.add_child(proj)                        # cleared with the band (run-state)
    proj.global_position = origin
    proj.setup(item, dir.normalized(), cfg.throw_speed, cfg.throw_max_range)
    EventBus.item_thrown.emit(item.id, GameState.current_depth_index, _run_t_ms())  # L0 signal
```

### 4. The projectile — `entities/thrown_item/thrown_item.gd` + `.tscn` (programmer half)

Recommended: **`Area2D`** (no physics-body sliding; pure overlap detection — the simplest greybox shape that detects both the hazard body and the world wall). Travels by integrating position each frame; **kills on hazard overlap, re-drops on wall overlap / max-range / lifetime.**

```gdscript
class_name ThrownItem
extends Area2D
## L1 (M1.5): a transient thrown inventory item. PURE RUN-STATE — never persisted,
## never feeds fingerprint(). Reuses JunkPickup's greybox look. Hit a hazard → kill it
## + self-destroy; miss (wall / max-range / lifetime) → re-drop via EventBus.junk_dropped.

var _item: JunkItem
var _dir: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _start: Vector2
var _max_range: float = 0.0
var _spent: bool = false          # one-shot guard: kill/redrop resolve exactly once

@onready var _greybox: Node2D = $Greybox

func setup(item: JunkItem, dir: Vector2, speed: float, max_range: float) -> void:
    _item = item; _dir = dir; _speed = speed; _max_range = max_range
    _start = global_position
    _greybox.queue_redraw()        # same _draw_greybox as JunkPickup (shared look)

func _physics_process(delta: float) -> void:
    if _spent: return
    global_position += _dir * _speed * delta
    if global_position.distance_to(_start) >= _max_range:
        _miss()                    # reached max range → re-drop here

func _on_body_entered(body: Node) -> void:        # masks `hazard`(16) + `world`(2)
    if _spent: return
    if body.is_in_group(&"hazard"):                # the R1 pursuer (and ping-pong, if in scope)
        _hit_hazard(body)
    else:                                          # world wall
        _miss()

func _hit_hazard(hazard: Node) -> void:
    _spent = true
    var depth := GameState.current_depth_index
    EventBus.thrown_item_hit.emit(_item.id, &"pursuer", depth, _run_t_ms())   # L0 signal
    if hazard is HazardEntity:                      # R1: no health → just free it
        hazard.queue_free()
    _item = null                                    # item consumed on a hit (NOT re-dropped)
    queue_free()

func _miss() -> void:
    _spent = true
    EventBus.thrown_item_missed.emit(_item.id, GameState.current_depth_index)  # L0 signal
    EventBus.junk_dropped.emit(_item, global_position)   # REUSE: JunkSpawner re-spawns a pickup
    queue_free()
```

`thrown_item.tscn`: `Area2D` root, `collision_layer = 0` (it is not a target of anything), `collision_mask = 18` (`world`=2 + `hazard`=16), a `CollisionShape2D` (small CircleShape2D ~6-8px), and a `Greybox` Node2D child whose `draw` is bound to `_draw_greybox` (copied/shared from `junk_pickup.gd:115-136`). A lifetime fallback can be a one-shot `SceneTreeTimer` in `setup()` that calls `_miss()` (belt-and-braces if it somehow never hits anything — Open Q 4).

> **Parenting:** the projectile is added under `_band_container` (`main_game.gd:49`, the same container hazards/pickups/R4 nodes use, `main_game.gd:455,532,558,791`) so `_clear_band()` disposes it with the band on run end — run-state, never leaked. **This means L1 writes `main_game.gd`** (the throw seam + parenting) — see Open Q 7 for the parallelism implication with L2.

---

## (c) Open Questions

> Items tagged **[Director]** need a vision/fun/scope verdict (not self-resolvable on technical merit). Phase-3 fresh-eyes resolve the rest and fold answers into a `Resolved Decisions` section.

**OQ-1 — Projectile node type + exact collision layer/mask.**
Trade-offs: **Area2D** (recommended) — pure overlap, no slide/bounce, simplest greybox; integrate position by hand; `collision_layer=0`, `collision_mask=18` (`world|hazard`). vs **CharacterBody2D** — `move_and_slide` gives "stops at wall" for free but adds sliding/penetration semantics we don't want for a thrown object and is heavier. **Recommendation: Area2D, mask `world`(2)+`hazard`(16), layer 0.** *Resolvable by fresh-eyes (technical).*

**OQ-2 — The throw-request seam: direct reference vs EventBus signal.**
The convention is signal-driven decoupling, but the *throw* needs three things atomically (the highlighted index, the model `remove_at`, the band container to parent into) — all of which live around `main_game`/the panel, not a far-flung listener. Options: (a) `main_game` holds a ref to the `InventoryPanel` and calls `highlighted_index()` directly (simple, one reader); (b) the panel emits `EventBus.throw_requested(index)` on the `throw` action and `main_game` listens (decoupled, but the panel — a *pure view* — would be reading input, which breaks its "holds no truth / never reads input" character); (c) `main_game` reads input and the panel exposes `highlighted_index()` as a query (a *read seam*, not a command — the panel stays a view, `main_game` stays the orchestrator). **Recommendation: (c)** — input + model mutation stay in `main_game` (the orchestrator), the panel exposes only a getter (consistent with it being a projection). The L0-declared signals (`item_thrown`/`thrown_item_hit`/`thrown_item_missed`) are *telemetry/notification* emits, not the command path. *Resolvable by fresh-eyes (architecture); confirm the panel-as-pure-view boundary holds.*

**OQ-3 — Does Space-throw kill ONLY the R1 pursuer, or also the K5 ping-pong / bomb / spike hazards?** **[Director]**
The Director feedback names the **"pursuer"** specifically. Critically, the *architecture* already biases this: the R1 pursuer and the K5 ping-pong are CharacterBody2D bodies on layer `hazard` (16) and **would be hit by a mask-`hazard` projectile**, but the **K5 bomb and spike are plain Node2D with no physics body** (`bomb_hazard.tscn`/`spike_hazard.tscn`) and would be **physically un-hittable by an overlap projectile** without bespoke distance-test code. So the natural fall line is: *throw hits whatever has a hazard-layer body* = pursuer **and** ping-pong, but **not** bomb/spike (which would each need their own opt-in). **Recommendation for RG1: pursuer-only is the *named* goal; the cheapest correct scope is "kills any `hazard`-group body it overlaps" (= pursuer + ping-pong for free), with bomb/spike explicitly out of scope this build (they have no body to hit).** Two sub-decisions for the Director: (i) is killing the ping-pong (a free side-effect of the layer choice) desired, or should the projectile filter to *only* `HazardEntity` (`if body is HazardEntity`)? (ii) is a future `throw_kills_*` scope knob (mirroring L5's per-hazard `*_kills`) wanted, or is "pursuer-only / body-only" fine? **Flag for Director.** Note: the L0 knob list (OQ-6) should reserve room for this — recommend L0 *not* pre-declare a `throw_kills_*` group yet (avoid dead knobs) unless the Director wants the ping-pong toggleable now.

**OQ-4 — Miss resolution: max-range vs lifetime (vs both)?**
A thrown item must terminate on a miss. Options: **max-range** (distance from origin — deterministic, reads as "it fell short", recommended primary); **lifetime** (seconds — simpler but couples distance to `throw_speed`); **both** (range as the gameplay rule + a generous lifetime as a belt-and-braces so a projectile that somehow never overlaps anything can't live forever). **Recommendation: max-range as the design rule (`throw_max_range` knob), plus a hidden generous lifetime fallback constant in the script (not a knob) for safety** — mirrors how `hazard_entity.gd` keeps feel constants (`NONFATAL_*`, `STALL_FRACTION`) in-script rather than as RunConfig fields. *Resolvable by fresh-eyes; the Director only weighs in if range *values* need sweeping (those are preset values, not this design).*

**OQ-5 — Highlight visual treatment + default/empty cases.** **[Director — tone/readability, recommendation attached]**
The cell is a `PanelContainer` greybox (`inventory_cell.tscn:5`) whose colour cues are *all* backed by a non-colour channel (playbook readability rule, `inventory_cell.gd:9-16`). Options: **(a) a bright border/outline** drawn around the highlighted cell (non-colour: it's a *frame*, reads without hue — consistent with the existing dashed empty-cell outline at `inventory_cell.gd:140-143`); **(b) a tint/brightness lift** on the cell (colour channel — weaker, risks clashing with the reject-flash red). **Recommendation: (a) a 2-3px highlight border** (e.g. a bright outline drawn in the cell, or a `StyleBoxFlat` border override) — a distinct channel from fill colour and the reject flash. **Default:** on first non-empty inventory, highlight index 0 (the pseudocode's `_revalidate_highlight`). **Empty bag:** `_highlight_index = -1`, no cell highlighted, `throw` is a no-op (nothing to throw). After a throw shrinks the bag, the index wraps/clamps into range (so the selector never points at a freed slot). *Director confirms the border treatment reads; ui-ux implements.*

**OQ-6 — The `throw_*` knob set (L0 pre-declares; L1 only reads — listed here so L0 can freeze it).**
Proposed contiguous-prefix group, all defaulting off/neutral (so the all-off baseline `e943ac9c8bc1` is byte-identical — throwing is inert with `throw_enabled=false`):
- `throw_enabled: bool = false` — master gate (preset: `true`).
- `throw_speed: float = 0.0` — projectile px/s (preset: a brisk value, Director-swept).
- `throw_max_range: float = 0.0` — px before a miss re-drop (preset value Director-swept).
- *(reserved, pending OQ-3)* `throw_kills_pingpong: bool` / scope knob — **recommend NOT declaring until the Director rules OQ-3** (no dead knobs; L0 can add it in the same single-writer pass if the Director wants it).
Each joins `to_flat_dict()` + the CFG coverage assertion; L0 bumps the knob count (72 `@export var` today; the breakdown's "81" count includes prior CFG-menu rows — L0 reconciles the exact delta across the throw group + the L2 `r1_*` group + the L5 `*_kills` toggles). *Fresh-eyes sanity-check the names against house style; the **values** are preset/Director territory, not this design.*

**OQ-7 — The `main_game.gd` parenting seam (drives L1/L2 Wave-2 parallelism).** **[orchestrator/Director scheduling call]**
L1 **does write `main_game.gd`** — it adds the `throw` input handler, the throw seam (`_try_throw`/`_spawn_thrown_item`), the `InventoryPanel` reference, and parents the projectile into `_band_container`. Per the Breakdown §4, L2 *may also* need `main_game.gd` (to pass the pursuer its spawn-room bounds), *or* may be containable entirely in `hazard_entity.gd` if the bounds are already reachable. **If both write `main_game.gd`, they cannot run as parallel worktrees** — they must single-write that file (sequence **L1 → L2**, or assign one owner who lands both edits). **Recommendation: sequence L1 → L2 on `main_game.gd` as the safe default** (L1's seam is small and lands first; L2 rebases on it), unless L2's Phase-2 design confirms it needs no `main_game.gd` edit (then L1/L2/L5 all parallelize). *Confirm against L2's Phase-2 design; orchestrator schedules accordingly.*

**OQ-8 — The single-F-at-a-gate "fires both actions" concern (largely a non-issue — documented for the record).**
The Breakdown §7 worries that binding F to *both* `interact` and `extract` could fire both at a gate. **Finding: this is not a risk as architected.** The `extract` *action* is **never read by any gameplay code** (only `interact` is — `interaction_detector.gd:64`; grep confirms no `is_action_pressed("extract")` anywhere). Grab-vs-extract is *already* disambiguated by the **focused interactable's id** (`&"junk"` → `JunkPickup._try_pickup`; `&"gate"` → `GameState.extract_and_end_run`), not by two keys. So the Director's "F = grab AND extract/descend (one contextual key)" is satisfied by binding **F to `interact` only**; `extract` need not even keep a keyboard binding. **Recommendation: bind F to `interact`; drop the Q keyboard event from `extract` (keep its joypad button if desired); leave `extract` declared only because telemetry/schema reference `&"extract"` as a run-end *cause* (`telemetry_schema.gd:98`), not as an input.** Confirm no consumer relied on `extract` as an input (grep says none) and no consumer relied on Q/E/Space pre-remap (grep: only the detector's `interact` Space binding — which moves to F; the demo scenes `decision_hud_demo.gd`/`sell_screen_demo.gd` use `ui_select`/`ui_accept`, not these actions). *Resolvable by fresh-eyes (already verified by grep).*

---

## Carried contracts (restated for the builder)

- **Pure run-state:** the throw mutates only `RunInventory` (run-state) and spawns a transient projectile parented under `_band_container`; it **never** persists, never feeds `fingerprint()`, never bumps `schema_version`. The all-off baseline (`throw_enabled=false`) is byte-identical — `_try_throw` early-returns, no projectile scene loads, no behaviour change → fp `e943ac9c8bc1` unmoved.
- **Knob-gated, all-off default:** `throw_enabled` defaults `false`; the fun value ships in `make_default_play_preset()`, never by changing the code-level default.
- **Signals are L0-declared/additive:** `item_thrown` / `thrown_item_hit` / `thrown_item_missed` are pre-declared by L0 (primitives-only payloads for the config-marked re-gate telemetry — a thrown / kill / miss event per RG2); L1 only **emits** them, never edits `event_bus.gd`. The miss re-drop reuses the **existing** `EventBus.junk_dropped` (no new spawn path).
- **`run_ended` arity locked; telemetry additive only.**
