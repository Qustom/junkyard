# A1 — Player Scene with Top-Down Movement

**Summary:** A `Player` entity built as a `CharacterBody2D` with smooth 8-direction movement (acceleration/friction), greybox placeholder art, driven entirely by named Input Map actions, supporting both keyboard and controller.

- **Parent task:** A1 (M1 greybox prototype — player foundation)
- **Dependencies:** None. This is the foundation; A2 (interaction) and A3 (clock) attach to or are siblings of this scene. Phantom Camera (top-down framing) will follow this node but is not required for the movement to work.
- **Acceptance criterion:** Movement is smooth in all 8 directions, read from named Input Map actions; both keyboard and controller produce identical movement.

## Assets needed

Scenes & nodes (feature-first layout under `/entities/player/`):
- `entities/player/player.tscn` — root `CharacterBody2D` named `Player`.
  - `Sprite` — placeholder visual. For M1 use a `ColorRect` (e.g. 28x28, distinct color like teal) parented under a `Node2D`/`Marker2D`, OR a `Polygon2D`/`CapsuleShape` outline. Centered on origin. A small `Polygon2D` "nose" triangle indicating facing is optional but cheap and helps readability.
  - `CollisionShape2D` — `CapsuleShape2D` or `CircleShape2D` (~14px radius) for body collision.
  - (Anchor points for later) `Marker2D` named `MuzzlePoint`/`InteractionOrigin` at center — A2's interaction Area will live here or directly under Player.

Input Map actions (lock these names now — they are referenced project-wide):
- `move_up`, `move_down`, `move_left`, `move_right` — keyboard WASD + arrow keys; controller left-stick axes (negative/positive Y and X) and D-pad.
- `interact` — keyboard `E` (and/or `Space`); controller face button `A`/`Cross` (`joypad_button 0`).
- Set a stick **deadzone** of ~0.2 on the analog axis events.

Project settings:
- Add the actions above in **Project > Project Settings > Input Map**.
- Physics tick: default 60 Hz is fine; movement runs in `_physics_process`.

Resources / data:
- `data/player/player_movement.tres` — a small `Resource` (`PlayerMovementStats`) holding `max_speed`, `acceleration`, `friction`. Authoring tuning as a `.tres` keeps it data-driven and consistent with project conventions. Optional for M1 but recommended; exported vars on the script are an acceptable fallback.

## Code to generate

One script: `entities/player/player.gd` (`class_name Player extends CharacterBody2D`). Optionally `data/player/player_movement_stats.gd` defining the tuning Resource.

The movement reads a normalized input vector via `Input.get_vector` (which handles deadzone and gives identical results for keyboard and stick), then lerps `velocity` toward the target with acceleration when there is input and friction when there is none. `move_and_slide()` applies it. No EventBus traffic is needed for raw movement; A2 owns the `interact` press handling, so this script only needs to expose facing/last-direction if A2 wants it.

```gdscript
class_name PlayerMovementStats
extends Resource

@export var max_speed: float = 220.0
@export var acceleration: float = 1600.0   # px/s^2 toward target velocity
@export var friction: float = 1800.0       # px/s^2 toward zero when no input
```

```gdscript
class_name Player
extends CharacterBody2D

@export var stats: PlayerMovementStats

var facing: Vector2 = Vector2.DOWN  # last non-zero direction, for A2 / sprite

func _physics_process(delta: float) -> void:
    var input_dir: Vector2 = Input.get_vector(
        "move_left", "move_right", "move_up", "move_down")
    # get_vector returns a length-clamped, deadzone-applied vector;
    # identical for keyboard (digital -> unit) and analog stick.

    if input_dir != Vector2.ZERO:
        facing = input_dir.normalized()
        var target: Vector2 = input_dir * stats.max_speed
        velocity = velocity.move_toward(target, stats.acceleration * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, stats.friction * delta)

    move_and_slide()
    _update_facing_visual()

func _update_facing_visual() -> void:
    # Greybox only: rotate the optional "nose" marker toward `facing`.
    # No-op if no directional sprite exists yet.
    pass
```

Note: `Input.get_vector` already normalizes diagonal input so diagonal speed equals cardinal speed — do not multiply by `max_speed` before normalizing, and do not normalize twice. Using `move_toward` per-axis-magnitude gives the acceleration/friction feel without overshoot.

## Open questions

- **Tuning values:** `max_speed`, `acceleration`, and `friction` are first-guess placeholders. These need playtest passes once the dive layout (room scale) exists — speed should feel snappy but allow the push-your-luck retreat decision to matter.
  - **Recommendation:** Ship M1 with `max_speed = 200`, `acceleration = 2000`, `friction = 2000` (very snappy, ~0.1s to full speed — standard for responsive top-down roguelites). Keep the body radius at ~14px and size greybox rooms so a full traverse takes ~3–5s; that makes the retreat-to-extract distance legible. Lock these only after one playtest pass against the real room scale — they are intentionally not the variable M1 is trying to validate.
- **Facing model:** Do we keep `facing` from movement direction only, or decouple aim/facing from movement (twin-stick) later? M1 only needs movement-facing, but A2's "nearest interactable" may want a facing bias — decide whether interaction is purely radial or facing-weighted (see A2 open questions).
  - **Recommendation:** For M1, keep `facing` derived from movement direction only (last non-zero `input_dir`) and let A2 use pure radial nearest-by-distance — do not decouple aim. Keep `facing` exported as a public read-only field so A2 can optionally add a facing bias later without a refactor. Twin-stick aim is a deferred concern with no bearing on the dive-vs-extract thesis M1 must prove.
- **Stats source:** Commit to `.tres` Resource now vs. exported script vars? Resource is more in-convention and lets enemies/other mobs reuse the movement stat shape, but adds a file for a single M1 entity.
  - **Recommendation:** Commit to the `.tres` `PlayerMovementStats` Resource now. It matches the project's data-as-Resources convention, lets enemies/mobs reuse the same stat shape (the movement loop is identical for any `CharacterBody2D`), and a single extra file is trivial cost. Tuning iteration also stays out of code, which is exactly what the placeholder-tuning question above needs.
- **Camera coupling:** Phantom Camera follow target wiring — does the PCam2D node live inside `player.tscn` or in the dive/level scene referencing the player? Recommend level-owned PCam to keep the player entity reusable, but confirm.
  - **Recommendation:** Confirmed — put the `PhantomCamera2D` in the dive/level scene, not in `player.tscn`, keeping the player entity camera-agnostic and reusable. Set its `follow_target` from code at dive start (the docs note assigning a `PhysicsBody2D` target via code avoids jitter, and PCam auto-selects `_process`/`_physics_process` based on the target since 4.3+). Use a small follow damping (~0.1–0.2) for a top-down feel ([source](https://phantom-camera.dev/core-nodes/phantom-camera-2d)).
- **Controller mapping breadth:** Only one face button bound to `interact` for M1 — confirm whether we also bind a second button (e.g. `B`/`Circle`) for a future "extract" action now to avoid remap churn, or defer until E-series tasks.
  - **Recommendation:** Reserve the action names now, wire only what M1 uses. Add `interact` (A/Cross = `joypad_button 0`, keyboard E/Space) and also declare `extract` (B/Circle = `joypad_button 1`, keyboard Q) and `pause` (Start = `joypad_button 6`) in the Input Map up front so the map is stable, but leave `extract` unconsumed until the E-series. Defining the slot costs nothing and avoids remap churn across tasks; binding the listener is the deferred part.
- **Collision layers:** Define player collision layer/mask bits now (player vs. world vs. interactable Areas) so A2's Area2D and the dive geometry agree — currently unassigned.
  - **Recommendation:** Lock this layer map now (layer = "who I am", mask = "who I detect"): bit 1 = `player`, bit 2 = `world` (walls/geometry), bit 3 = `interactable`, bit 4 = `enemy`, bit 5 = `hazard` (reserved). Player `CharacterBody2D`: layer 1, mask 2+4+5 (collides with world/enemy/hazard, NOT interactables — those are non-blocking Areas). A2's `InteractionDetector` Area2D: layer empty, mask 3 only. Name the bits in Project Settings > Layer Names so every task references names, not numbers ([source](https://forum.godotengine.org/t/whats-the-best-practice-for-setting-up-collision-layers-masks/121503)).
