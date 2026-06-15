# A2 — Reusable Interaction Component

**Summary:** An Area-based, composition-first `InteractionDetector` component placed on the player that tracks nearby `Interactable` nodes, surfaces a "nearest" target with an on-screen prompt, and on `interact` press fires an EventBus signal naming that target — serving both junk pickup and the gate.

- **Parent task:** A2 (M1 greybox prototype — interaction layer)
- **Dependencies:** A1 (Player scene; the `interact` Input Map action and the player root to host the detector). EventBus autoload must exist with the relevant signals. Junk and gate entities consume this in later tasks but a stub `Interactable` is needed here to test.
- **Acceptance criterion:** A prompt shows when the player is near an interactable; pressing `interact` fires an EventBus signal naming the target.

## Assets needed

Composition uses two complementary nodes — a **detector** on the player and an **Interactable** marker on each usable entity:

Player side (`/entities/player/` or `/components/interaction/`):
- `components/interaction/interaction_detector.tscn` — `Area2D` named `InteractionDetector`, added as a child of `Player` in `player.tscn`.
  - `CollisionShape2D` — `CircleShape2D` (~36px radius) defining interaction reach.
  - Configured so it only detects on the **interactable collision layer** (mask), not world/enemy layers.

Interactable side (`/components/interaction/`):
- `components/interaction/interactable.tscn` (+ `interactable.gd`, `class_name Interactable`) — a small reusable node added to junk/gate scenes. Implemented as an `Area2D` (so the detector's `area_entered`/`area_exited` see it) OR a node carrying its own small `Area2D` child. Exposes:
  - `interactable_id: StringName` (e.g. `&"junk"`, `&"gate"`) and/or `display_name: String`.
  - `prompt_text: String` (e.g. "Grab", "Descend").
  - `enabled: bool`.

UI (`/ui/`):
- `ui/interaction_prompt.tscn` (+ `interaction_prompt.gd`) — minimal greybox prompt: a `Control`/`PanelContainer` with a `Label` showing `prompt_text` + key hint ("[E] Grab"). M1 can render it as a world-space `Node2D`+`Label` floating above the target, or a screen-anchored CanvasLayer label. Floating world-space is clearer for "which thing".

Input actions: reuses `interact` from A1 (no new actions).

Collision layers: define an `interactable` layer bit (coordinate with A1's layer plan) so the detector's mask matches Interactable bodies/areas exclusively.

EventBus signals to add (`/systems/event_bus.gd`):
```gdscript
signal interaction_requested(interactable_id: StringName, target: Node)
signal interactable_focused(target: Node)     # nearest changed (for UI/audio)
signal interactable_unfocused(target: Node)
```

## Code to generate

Two scripts. `interaction_detector.gd` (`class_name InteractionDetector extends Area2D`) maintains a set of in-range `Interactable`s, recomputes the nearest each frame (cheap; list is tiny), drives the prompt via EventBus focus signals, and on `interact` emits `interaction_requested` naming the target — it does **not** perform the pickup or open the gate itself (that logic lives on the Interactable's owner / in later tasks). `interactable.gd` is mostly data + a thin `can_interact()` guard.

Selecting "nearest" uses distance to the player; an optional facing bias (dot product with `Player.facing` from A1) can break ties. For M1, pure nearest-by-distance is sufficient.

```gdscript
class_name Interactable
extends Area2D

@export var interactable_id: StringName = &"junk"
@export var display_name: String = "Junk"
@export var prompt_text: String = "Grab"
@export var enabled: bool = true

func can_interact() -> bool:
    return enabled
```

```gdscript
class_name InteractionDetector
extends Area2D

@export var prompt_scene: PackedScene  # ui/interaction_prompt.tscn

var _in_range: Array[Interactable] = []
var _current: Interactable = null
var _prompt: Node = null

func _ready() -> void:
    area_entered.connect(_on_area_entered)
    area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
    var it := area as Interactable
    if it and not _in_range.has(it):
        _in_range.append(it)

func _on_area_exited(area: Area2D) -> void:
    var it := area as Interactable
    if it:
        _in_range.erase(it)

func _process(_delta: float) -> void:
    _refresh_current()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and _current and _current.can_interact():
        EventBus.interaction_requested.emit(_current.interactable_id, _current)
        get_viewport().set_input_as_handled()

func _refresh_current() -> void:
    var best: Interactable = null
    var best_d: float = INF
    var origin: Vector2 = global_position
    for it in _in_range:
        if not it.can_interact():
            continue
        var d: float = origin.distance_squared_to(it.global_position)
        if d < best_d:
            best_d = d
            best = it

    if best == _current:
        return
    # Focus changed -> update prompt + notify.
    if _current:
        EventBus.interactable_unfocused.emit(_current)
    _current = best
    if _current:
        EventBus.interactable_focused.emit(_current)
        _show_prompt(_current)
    else:
        _hide_prompt()

func _show_prompt(it: Interactable) -> void:
    if _prompt == null and prompt_scene:
        _prompt = prompt_scene.instantiate()
        add_child(_prompt)  # or a UI layer; world-space follows target
    if _prompt:
        _prompt.set_target(it)  # prompt reads prompt_text + positions itself
        _prompt.visible = true

func _hide_prompt() -> void:
    if _prompt:
        _prompt.visible = false
```

The prompt script (`interaction_prompt.gd`) just exposes `set_target(it: Interactable)`, copies `it.prompt_text` into its label (prefixed with the key hint), and in `_process` snaps `global_position` to `it.global_position` plus an offset. Listening to `interactable_focused`/`unfocused` on EventBus is an alternative to the detector calling it directly — pick one path (direct call is simpler for M1; EventBus is more decoupled).

## Open questions

- **Direct call vs. EventBus for the prompt:** Should the prompt subscribe to `interactable_focused`/`interactable_unfocused` (fully decoupled, matches "systems talk via signals") or be owned/positioned directly by the detector (simpler, fewer moving parts)? The interaction *request* must go through EventBus per acceptance; the prompt wiring is the open choice.
  - **Recommendation:** For M1, have the detector own and position the prompt directly (instantiate, `set_target`, follow in `_process`) — the prompt is intrinsically coupled to the detector's "nearest" state, so a direct call is simpler with no real decoupling benefit. Still emit `interactable_focused`/`unfocused` on EventBus (for audio/telemetry consumers), but do not make the prompt depend on them. The required `interaction_requested` still goes through EventBus, satisfying acceptance.
- **Interactable as Area2D vs. component-on-body:** Junk and the gate may want their own physics body. Decide whether `Interactable` is itself the `Area2D` or a child component that wires up a sibling Area — affects how junk/gate scenes are assembled.
  - **Recommendation:** Keep `Interactable extends Area2D` as its own node (as the sample code does) and add it as a CHILD of whatever entity scene needs it (junk pickup, gate), rather than making it the entity root. The Area sits on the `interactable` layer (bit 3) with its own `CollisionShape2D`; the parent can still be a `StaticBody2D`/`Node2D` on the `world` layer for blocking. This keeps the detector's `area_entered` contract intact and stays composition-first — entities gain interactability by dropping the node in.
- **Nearest-selection rule:** Pure distance, or facing-weighted (needs A1's `facing`)? And tie-breaking when two interactables overlap (stable order vs. flicker). M1 likely fine with distance + stable insertion order.
  - **Recommendation:** Use pure nearest-by-`distance_squared_to` for M1 (matches A1's decision to keep facing movement-only). To prevent flicker between near-equal candidates, add hysteresis: only switch focus when a challenger is meaningfully closer than the current target (e.g. `new_d < best_d * 0.9`), and break exact ties by stable insertion order in `_in_range`. This keeps the prompt from jittering when two pieces of junk overlap.
- **Who consumes `interaction_requested`:** Pickup and gate logic live in later tasks (junk economy / dive flow). Confirm the contract: does the listener mutate GameState (run-state Money / descend) directly, and does the Interactable get freed by the owner or by the detector? Detector should stay agnostic.
  - **Recommendation:** The detector stays agnostic — it only emits `interaction_requested(id, target)` and never mutates state or frees nodes. The contract: the Interactable's OWNER (junk script for pickup, dive-flow/gate script for descend) listens to `interaction_requested`, checks `id`, mutates GameState run-state (Money, descend), and is responsible for freeing/disabling its own `target` (e.g. `target.get_parent().queue_free()` for junk). On free, `area_exited` cleans `_in_range` automatically; guard by also erasing freed targets defensively in `_refresh_current`.
- **Key-hint glyph:** Prompt shows "[E]" for keyboard — do we need controller glyph swapping in M1, or is a static keyboard hint acceptable for greybox? Likely static now, revisit with controller polish.
  - **Recommendation:** Static "[E]" keyboard hint for M1 — controller glyph swapping is pure polish that does not affect the dive-vs-extract thesis. To avoid hardcoding, derive the label text once from the `interact` action's first event via `InputMap.action_get_events("interact")` so it reads the actual binding, but do not detect the active device or swap to button glyphs yet. Defer device-aware glyphs to controller-polish in a later task.
- **Input handling location:** `_unhandled_input` on the detector vs. centralizing `interact` in the Player. Centralizing avoids two nodes both reading `interact`; confirm A1/A2 ownership so the press isn't double-handled.
  - **Recommendation:** Keep `interact` handling on the detector via `_unhandled_input` (as in the sample) — it is the node that knows `_current`, so colocating is cleaner than routing through Player. This is safe because A1's movement reads `Input.get_vector` polled in `_physics_process`, not the event queue, so there is no `interact` double-handling. Call `get_viewport().set_input_as_handled()` after firing (already shown) so UI/future consumers don't re-process the same press ([source](https://forum.godotengine.org/t/best-practice-where-to-handle-unhandled-input/139742)).
