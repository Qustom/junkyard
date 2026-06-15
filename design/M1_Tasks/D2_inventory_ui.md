# D2 — Inventory UI (greybox)

**Summary:** A Control-based grid that shows the carried junk and remaining capacity, updating in real time. Greybox styling is fine, but readability is the priority because the player makes the keep/drop decision here.

- **Parent task:** D2
- **Dependencies:** D1 (run inventory model), C1 (`JunkItem` greybox color/shape). Reacts to C2 pickups indirectly via EventBus.
- **Acceptance criterion:** The grid reflects the inventory in real time; capacity and fullness are legible at a glance.

D2 is the player's decision surface. When the bag is filling and a rich-but-bulky engine block is on the ground, the UI is where "is it worth the space?" gets answered. So even in greybox, the fullness state and per-item value/footprint must read instantly.

## Assets needed

- `/ui/inventory/inventory_panel.tscn` — the inventory view. Suggested tree:
  - `InventoryPanel` (`Control`, script below) — root, subscribes to EventBus.
    - `CapacityHeader` (`HBoxContainer`)
      - `CapacityLabel` (`Label`) — e.g. `"8 / 12 slots"`.
      - `CapacityBar` (`ProgressBar`) — fullness at a glance; tints toward red as it fills.
    - `Grid` (`GridContainer`) — holds one cell per slot (count model) or a cell grid (spatial model).
- `/ui/inventory/inventory_cell.tscn` — one slot cell.
  - `InventoryCell` (`PanelContainer` or `Control`) — fixed-size box with a border.
    - `Greybox` (`Control` drawing via `_draw`, or a `Polygon2D`) — renders the item's `greybox_color` + `greybox_shape`.
    - `ValueLabel` (`Label`) — small value / value-per-slot readout for the keep/drop call.
- `/ui/inventory/inventory_panel.gd`, `/ui/inventory/inventory_cell.gd` — scripts.
- No `.tres`. The UI reads appearance straight from each `JunkItem` (C1). A small `theme.tres` is optional for consistent greybox borders/fonts.

The UI holds **no inventory truth** — it is a pure projection of `GameState.run_inventory`, rebuilt/updated whenever D1 emits `run_inventory_changed`. This keeps it decoupled (architecture: systems talk via EventBus, not hard refs).

## Code to generate

Two scripts: the panel (subscribes, refreshes) and the cell (renders one item from data). The refresh is driven entirely by the D1 signal so there's no per-frame polling and no risk of UI/model drift.

### Panel

```gdscript
# /ui/inventory/inventory_panel.gd
class_name InventoryPanel
extends Control

@export var cell_scene: PackedScene   # inventory_cell.tscn
@onready var grid: GridContainer = $Grid
@onready var capacity_label: Label = $CapacityHeader/CapacityLabel
@onready var capacity_bar: ProgressBar = $CapacityHeader/CapacityBar

func _ready() -> void:
    EventBus.run_inventory_changed.connect(_on_inventory_changed)
    _refresh()   # paint initial state (empty bag at run start)

func _on_inventory_changed(used: int, max_slots: int) -> void:
    _refresh()

func _refresh() -> void:
    var inv: RunInventory = GameState.run_inventory
    if inv == null:
        return
    _rebuild_cells(inv)
    _update_capacity(inv.used_slots(), inv.max_slots)

func _rebuild_cells(inv: RunInventory) -> void:
    # Greybox-simple approach: clear and repopulate. Cheap at M1 item counts.
    for child in grid.get_children():
        child.queue_free()
    # One cell per item (count model). Item spanning >1 slot can show its
    # slot_size, or render N cells — see Open questions.
    for item in inv.items:
        var cell := cell_scene.instantiate()
        grid.add_child(cell)
        cell.set_item(item)
    # Fill remaining capacity with empty cells so "free space" is visible.
    for _i in range(inv.free_slots()):
        var empty := cell_scene.instantiate()
        grid.add_child(empty)
        empty.set_empty()

func _update_capacity(used: int, max_slots: int) -> void:
    capacity_label.text = "%d / %d slots" % [used, max_slots]
    capacity_bar.max_value = max_slots
    capacity_bar.value = used
    # Legibility: shift toward red as the bag fills; flash full state.
    var t: float = float(used) / float(maxi(max_slots, 1))
    capacity_bar.modulate = Color(0.4, 0.9, 0.4).lerp(Color(0.95, 0.3, 0.3), t)
```

### Cell

```gdscript
# /ui/inventory/inventory_cell.gd
class_name InventoryCell
extends PanelContainer

@onready var greybox: Control = $Greybox
@onready var value_label: Label = $ValueLabel

var _item: JunkItem

func set_item(item: JunkItem) -> void:
    _item = item
    value_label.text = "$%d" % item.base_sell_value   # decision info
    greybox.queue_redraw()                              # repaint shape/color

func set_empty() -> void:
    _item = null
    value_label.text = ""
    greybox.queue_redraw()

# Greybox child draws the item's shape in its color; empty = faint outline.
func _draw_greybox() -> void:
    if _item == null:
        # draw dim empty-slot outline
        return
    match _item.greybox_shape:
        JunkItem.GreyboxShape.RECT:     ... # filled rect in _item.greybox_color
        JunkItem.GreyboxShape.CIRCLE:   ...
        JunkItem.GreyboxShape.TRIANGLE: ...
        JunkItem.GreyboxShape.DIAMOND:  ...
```

Real-time behavior, end to end: C2 picks up junk → D1 `try_add` succeeds → `run_inventory_changed` fires → panel `_refresh()` rebuilds cells and updates the capacity bar. The same path runs on `remove`/`clear_run`, so cash-out visibly empties the grid. Because the panel always reads from `GameState.run_inventory` rather than caching, it cannot drift from the model.

Legibility checklist for greybox (acceptance leans on this): the `N / M slots` label and a color-shifting fullness bar give instant capacity read; empty cells are drawn (not omitted) so remaining space is spatially obvious; each item shows its `$value` for the keep/drop call; the bar going red signals "you must choose now."

## Open questions

- **Cell-per-item vs cell-per-slot for big junk.** A 4-slot engine block: one big cell labeled "x4", or four occupied cells? Depends on D1's slot model. Spatial model needs proper footprint rendering; count model can fake it with a label. Decide alongside D1.
  - **Recommendation:** With D1 confirmed simple-count, use **one cell per item** and label its footprint (the cell shows the greybox shape, `$value`, and a small slot-cost badge e.g. "4 slots"). This keeps the cell↔item mapping one-to-one (clean for the drop affordance — a click maps to exactly one item) and avoids faking a spatial grid the model does not have. For the "free space is visible" cue (which the legibility checklist values), still render `free_slots()` empty placeholder cells after the item cells — they communicate remaining room spatially even though they no longer map one-to-one onto multi-slot items. The item cell's slot-cost badge reconciles the two readings (one cell can cost more than one empty cell). (If D1 ever adopts the spatial model, this question reopens and cells become true footprint regions.)
- **Drop / discard affordance.** Should clicking a cell drop that item (to swap for something better on the ground)? That requires a D1 `remove` call and a C2 decision about re-spawning the dropped junk in the world. If yes, the UI needs a confirm/hold-to-drop interaction even in greybox.
  - **Recommendation:** Yes — ship a drop affordance in M1, since D1 and C2 are both committed to drop-to-swap being part of the core tension. To avoid accidental discards, use a deliberate gesture rather than a bare click: right-click or hold-to-drop on a cell, which calls `GameState.run_inventory.remove(item)` (by the cell's index, per D1) and lets C2 re-instantiate the `JunkPickup` at the player. Keep it greybox-simple (no modal confirm dialog; the gesture itself is the confirmation), but make the gesture non-trivial so a stray click never dumps a valuable item.
- **Rebuild vs in-place update.** `_rebuild_cells` clears and repopulates every change — trivial at M1 counts but causes flicker/loses focus. Worth diffing cells if drag-drop or selection lands.
  - **Recommendation:** Keep the full clear-and-repopulate rebuild for M1 — at this item count it is well within "rebuilds are fast enough" and the simplicity is worth it. The known downsides (flicker, lost focus/selection) only bite once there is persistent selection or drag state to preserve; the chosen drop gesture is a discrete action with no held selection, so it does not need diffing. Revisit (move to in-place per-cell updates that touch only changed slots) only if a later feature introduces persistent selection or drag-placement ([source](https://medium.com/@thrivevolt/making-a-grid-inventory-system-with-godot-727efedb71f7)).
- **Value readout: flat value vs value-per-slot.** The genuinely useful decision metric is `value_per_slot` (C1 exposes it). Show `$value`, `$/slot`, or both? Both is more honest but busier — playtest the legibility tradeoff.
  - **Recommendation:** Show flat `$value` as the always-on primary readout, with `$/slot` available secondarily (on hover/focus, or as a smaller subordinate line) rather than both at equal weight. `$value` is what the player most directly cares about ("how much is this worth?") and reads cleanly on a small greybox cell; `$/slot` is the sharper *comparison* metric but adds clutter if shown at full prominence on every cell. Defaulting to `$value` primary + `$/slot` on demand keeps cells legible while still exposing the honest decision metric — then playtest whether `$/slot` deserves promotion to always-on.
- **Persistent panel vs toggled.** Is the grid always on-screen (HUD) or opened on a key? Always-on supports moment-to-moment carry decisions; toggled reduces clutter. Affects layout and where it sits in the scene tree.
  - **Recommendation:** Persistent HUD panel for M1. The carry decision happens *in the moment* — when standing over junk with a near-full bag — so the capacity bar and contents must be visible without a keypress; toggling would hide exactly the information the core tension depends on. Keep it compact and docked (a corner panel) to limit clutter, living under the main HUD CanvasLayer. A toggle/expand for a detailed view can come later, but the at-a-glance fullness read stays always-on.
- **Full-bag signaling.** Beyond the red bar, do we want an explicit "BAG FULL" state in the UI that ties to C2's pickup-rejected feedback, so the two surfaces agree?
  - **Recommendation:** Yes — add an explicit "BAG FULL" state, driven from the same D1 truth as C2's rejected-pickup feedback so the two surfaces never disagree. Concretely: when `is_full()` (or, better, when the nearby ground item fails `can_accept()`), the capacity label flips to a "FULL" treatment and the bar pins red, matching C2's prompt flip ("Bag full — won't fit") and reject flash. Both surfaces reading the same predicate is the point — it makes "you must choose now" legible whether the player is looking at the bag or at the junk on the ground.
