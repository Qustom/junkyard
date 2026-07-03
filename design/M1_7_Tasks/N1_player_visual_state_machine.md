# N1 — Player Visual State Machine (8-way + actions + lock) · Phase-2 Design

**Milestone/iteration:** M1.7 (Player Embodiment). **Task id:** `N1`. **Role(s):** `general-purpose` (programmer) +
`character-animator`. **Authored:** 2026-06-27 (Phase 2 fan-out, expanding `M1.7_Breakdown.md` §3 N1 row / §6 / §7 N1).
**Blocks:** N2 (the debug toggle swaps the `AnimatedSprite2D`↔greybox seam N1 establishes). **Blocked by:** N0 (produces
`res://entities/player/player_frames.tres` + pre-declares `EventBus.debug_player_art_toggled`).

**The one thing N1 delivers:** a visual controller that turns the existing `Player` `CharacterBody2D` into a legible,
8-directional animated character — idle/walk driven by the existing `velocity`/`facing`, pickup/throw one-shots driven by the
existing `junk_picked_up`/`item_thrown` EventBus signals, with a brief gated movement-lock during the action clips — **adding
no new gameplay state and touching no collision, movement, or RNG.**

---

## Hard constraints (state up front, hold throughout)

- **Determinism fp `e943ac9c8bc1` UNMOVED.** This task touches no RNG, no `RunConfig` field, no generator. The sprite is a
  pure renderer; the only state it reads is already-resolved per-frame (`velocity`, `facing`/`aim`) or event-driven
  (`junk_picked_up`, `item_thrown`). Nothing N1 writes can reach `fingerprint()`.
- **Art-OFF == M1.6 byte-for-byte.** When art is OFF: the greybox (`Visual` `ColorRect` + `Nose`) renders, the
  `AnimatedSprite2D` is hidden, **and the movement-lock is inert** — `_physics_process` is identical to today's. Default = art
  ON. The OFF path must be the *exact* current code path (no new branch executed), so M1.6 feel is preserved bit-for-bit.
- **Collision + movement untouched.** `CircleShape2D` r=14, `collision_layer=1`/`collision_mask=26`, and
  `res://data/player/player_movement.tres` (`stats`) are unchanged. The sprite is scaled/offset to *read against* the r=14
  body, never to redefine it. `step_velocity` / `resolve_aim` math is unchanged (the lock gates their *inputs*, see §a).
- **Existing seams only for gameplay.** Direction = `facing`/`aim`; walk/idle = `velocity`; pickup = `junk_picked_up`; throw =
  `item_thrown`. N1 declares **no** new signal (N0 pre-declared the only new one, the *debug* `debug_player_art_toggled`,
  which N1 merely *listens* to for the art on/off swap; N2 emits it).
- **Pure helpers stay headless-unit-testable** — `quantize_dir(facing) -> StringName` and
  `select_state(velocity, locked, action) -> StringName` are pure, no node/tree/physics access, mirroring `step_velocity` /
  `resolve_aim` and their test `Game/tests/test_player_movement.gd`.

---

## (a) Research on the premise — the real seams and how they map

### Existing as-built seams (cited)

| Seam | Where | Maps to animation as |
|---|---|---|
| `var aim: Vector2 = Vector2.DOWN`, `var facing: Vector2 = Vector2.DOWN` | `player.gd:29`, `:34` | **Direction.** Post-L6 `facing` follows where the player *points* (mouse dir / right-stick), defaulting DOWN. Quantize its angle → one of 8 dir strings → the directional clip suffix. `facing` is kept in sync with `aim` each tick (`player.gd:85`). |
| `velocity` (CharacterBody2D), set via `step_velocity(...)` | `player.gd:71`, `:127` | **idle ↔ walk.** `velocity.length()` above a small threshold → `walk_<dir>`; at/below → `idle_<dir>`. |
| `resolve_aim(...)` (pure) + `_update_facing_visual()` | `player.gd:109`, `:136` | The **seam to extend.** `_update_facing_visual()` today only rotates the optional `Nose` by `aim.angle()` (`player.gd:140-141`). N1 extends *this call site* (or a sibling) to also drive the `AnimatedSprite2D`. |
| `EventBus.junk_picked_up(item_id, value, slot_size, world_pos, accepted)` | `event_bus.gd:59` | **pickup** one-shot. Fires on **every** interact attempt (accepted OR rejected). N1 plays `pickup_<dir>` on it (see OQ-5 re: whether rejected pickups animate). |
| `EventBus.item_thrown(item_id, depth, run_t_ms)` | `event_bus.gd:167`; emitted at `main_game.gd:1228` | **throw** one-shot. Fires once per launched throw (edge-latched in `_unhandled_input` `main_game.gd:1187-1196` → `_try_throw` `main_game.gd:1205`). N1 plays `throw_<dir>`. |
| `EventBus.debug_player_art_toggled(enabled: bool)` (N0 pre-declares) | `event_bus.gd` (N0 add) | **art on/off swap.** N1 *connects* to it: show `AnimatedSprite2D` + arm the lock when `true`; show greybox + disarm the lock when `false`. N1 does not emit it (N2 does). |

### N0's asset contract (assumed to exist)

`res://entities/player/player_frames.tres` — a `SpriteFrames` with 8 dirs `{south, south_east, east, north_east, north,
north_west, west, south_west}` and clips: `idle_<dir>` (8×1, loop), `walk_<dir>` (8×6, loop), `pickup_<dir>` (8×5, one-shot),
`throw_<dir>` (8×7, one-shot). N1 selects clips by **name** (`"%s_%s" % [state, dir]`), so N1 only needs the naming convention
to be stable, not the FPS/frame-count internals (those are N0's). **Dir-string spelling is a shared contract** — N1's
`quantize_dir` must emit *exactly* N0's suffixes; this doc fixes them as `&"south"`/`&"south_east"`/… (underscored). N0 must
author with the same spelling. (OQ-7 covers the spelling/contract risk.)

### How the movement-lock interacts with `_physics_process` / `step_velocity`

The Director locked: pickup + throw root the player for ~0.2–0.3 s (the clip beat), then return to walk/idle; the lock is
**active only when art is ON**. The cleanest seam that **leaves `step_velocity` / `resolve_aim` math untouched** is to gate
the *movement input* to zero while locked — i.e. feed `Vector2.ZERO` as `input_dir` into the unchanged `step_velocity`. The
consequence is exactly the intended one: with no input, `step_velocity` applies **friction toward zero** (`player.gd:133`), so
the player decelerates and roots, using the *same* tuning — no separate "freeze" code, no teleport, no velocity clobber, and
collision response (`move_and_slide`) still runs so a locked player resting against a wall stays put cleanly.

Critically, **aim is NOT gated** — `facing`/`aim` keep updating while locked, so the action clip points where the player is
aiming at the moment the lock began *and* a player who keeps moving the mouse mid-lock still re-faces (the clip's dir suffix is
chosen once at lock-start to avoid mid-clip dir-flip; see OQ-4). This matches "commit to the action" without feeling frozen.

**The OFF path is the current path verbatim.** Art-OFF means `_locked()` is *never true* (the lock is only ever armed under art
ON), so the `input_dir` gate never triggers and `_physics_process` executes today's exact lines. That is what guarantees
byte-for-byte M1.6 feel — not a parallel "if off" branch, but the *absence* of the lock state.

Collision/movement tuning is confirmed untouched: the lock changes only the *value fed to* `step_velocity` (zero vs. real
input) for a few frames; `stats.max_speed`/`acceleration`/`friction`, the r=14 shape, and the layer/mask are never read or
written by N1.

### Controller placement — recommendation: a child `player_visual.gd` node, NOT a section of `player.gd`

**Recommend a dedicated child node `PlayerVisual` (script `player_visual.gd`, extends `Node2D` or `AnimatedSprite2D`)** under
`player.tscn`, plus a *minimal* surgical change in `player.gd`. Reasoning:

- **Run/meta + decoupling discipline (TDD §2).** Keeping the renderer + its EventBus subscriptions (`junk_picked_up`,
  `item_thrown`, `debug_player_art_toggled`) in their own node keeps `player.gd` focused on movement/aim and avoids bloating
  the body with view concerns. The body stays the reusable "physics + intent" object the camera/HUD already treat it as.
- **The lock is the one unavoidable `player.gd` edit.** The input-gate has to live where `input_dir` is read
  (`player.gd:68-71`), so `player.gd` *must* expose whether it is locked. The pure helper `select_state` and the lock-timer
  live in the visual node; `player.gd` reads one boolean (`_visual.is_locked()` or a cached `_movement_locked` the visual sets)
  to decide whether to zero the input. This is the **single** functional line added to `player.gd`'s hot path, and it short-
  circuits to today's behaviour whenever the lock is inert (art OFF or no action running).
- **N2 integration seam.** N2 swaps `AnimatedSprite2D`↔greybox at runtime; having that swap target one self-contained node
  (show/hide its own sprite + the parent's greybox) is a clean handler. N1 sets this up; N2 wires the menu to it.

The alternative (everything in `player.gd`) is fewer files but couples the body to its renderer and grows the hot path; given
the body is already a careful, tested file, the child node is the lower-risk seam. **Pure helpers (`quantize_dir`,
`select_state`) are `static`** so the headless test can call them with no instance regardless of which node hosts them.

---

## (b) Pseudocode (against the real APIs)

> Illustrative — final names/values are the build's, but the seams, signatures, and the `player.gd` edit are load-bearing.

### `player.gd` — the only edit (gate movement input while locked)

```gdscript
@onready var _visual: PlayerVisual = get_node_or_null("PlayerVisual")

func _physics_process(delta: float) -> void:
    var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

    # N1: while the action-lock is active (only ever true under art ON), zero the
    # movement input so the UNCHANGED step_velocity decelerates the body via friction.
    # _visual is null-guarded; lock is false when art is OFF → today's exact path.
    if _visual != null and _visual.is_locked():
        input_dir = Vector2.ZERO

    velocity = step_velocity(velocity, input_dir, delta)   # math unchanged
    # ... aim resolution UNCHANGED (aim/facing keep updating even while locked) ...
    move_and_slide()
    _update_facing_visual()   # still rotates the (now hidden-by-default) Nose; PlayerVisual reads facing itself
```

`_update_facing_visual()` keeps its current body (rotates `Nose` when present, null-safe) — under art ON the `Nose` is hidden
(OQ-8) so the rotation is harmless; under art OFF it works exactly as today.

### `player_visual.gd` — the renderer + state machine

```gdscript
class_name PlayerVisual
extends Node2D   # holds the AnimatedSprite2D child; reads the parent Player's facing/velocity

const WALK_SPEED_THRESHOLD := 8.0          # px/s; below → idle (OQ-2)
const LOCK_DURATION := 0.25                # s; default action root (OQ-3); tunable @export
const DIR_HYSTERESIS_DEG := 10.0          # extra angle a new dir must win by (OQ-1)

const DIRS := [&"east", &"south_east", &"south", &"south_west",
               &"west", &"north_west", &"north", &"north_east"]   # CCW? — fixed in OQ-1

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
var _player: Player
var _art_on := true
var _lock_remaining := 0.0
var _current_dir: StringName = &"south"
var _current_action: StringName = &""      # &"" | &"pickup" | &"throw"

func _ready() -> void:
    _player = get_parent() as Player
    EventBus.junk_picked_up.connect(_on_junk_picked_up)
    EventBus.item_thrown.connect(_on_item_thrown)
    EventBus.debug_player_art_toggled.connect(_on_art_toggled)
    _sprite.animation_finished.connect(_on_anim_finished)
    _apply_art_visibility()

func is_locked() -> bool:
    return _art_on and _lock_remaining > 0.0   # gates player.gd's input; ALWAYS false when art OFF

func _process(delta: float) -> void:
    if not _art_on:
        return                                  # art OFF → no work; greybox path untouched
    if _lock_remaining > 0.0:
        _lock_remaining -= delta

    # Direction: quantize the parent's facing, with hysteresis to stop diagonal flicker.
    _current_dir = quantize_dir(_player.facing, _current_dir)

    var state := select_state(_player.velocity, is_locked(), _current_action)
    _play(state, _current_dir)

func _play(state: StringName, dir: StringName) -> void:
    var clip := StringName("%s_%s" % [state, dir])
    if _sprite.animation != clip:
        _sprite.play(clip)
    # Note: while locked, dir is FROZEN to _action_dir (set at lock-start) — see _begin_action.

# --- action one-shots ---------------------------------------------------------
func _on_junk_picked_up(_id, _value, _slot, _pos, accepted: bool) -> void:
    if not _art_on: return
    if not accepted and not PLAY_PICKUP_ON_REJECT: return   # OQ-5
    _begin_action(&"pickup")

func _on_item_thrown(_id, _depth, _t) -> void:
    if not _art_on: return
    _begin_action(&"throw")

func _begin_action(action: StringName) -> void:
    _current_action = action
    _current_dir = quantize_dir(_player.facing, _current_dir)   # snap dir at action start, then freeze
    _lock_remaining = LOCK_DURATION                              # or clip-driven (OQ-3)
    _play(action, _current_dir)

func _on_anim_finished() -> void:
    # one-shot clip ended → drop back to idle/walk selection next _process
    if _sprite.animation == StringName("%s_%s" % [_current_action, _current_dir]):
        _current_action = &""

# --- N2 art swap --------------------------------------------------------------
func _on_art_toggled(enabled: bool) -> void:
    _art_on = enabled
    if not enabled:
        _lock_remaining = 0.0                  # release any in-flight lock immediately → M1.6 feel
        _current_action = &""
    _apply_art_visibility()

func _apply_art_visibility() -> void:
    _sprite.visible = _art_on
    # parent greybox: show Visual + Nose when art OFF, hide when ON (OQ-8)
    var vis := _player.get_node_or_null("Visual"); if vis: vis.visible = not _art_on
    var nose := _player.get_node_or_null("Nose");  if nose: nose.visible = not _art_on
```

### The pure, headless-unit-testable helpers (the N1 test seam)

```gdscript
## Pure: angle of `facing` → one of 8 dir StringNames. Hysteresis: keep `current`
## unless the candidate beats it by > DIR_HYSTERESIS_DEG, killing diagonal flicker
## when facing sits on a boundary. No node/tree/physics access — mirrors resolve_aim.
static func quantize_dir(facing: Vector2, current: StringName) -> StringName:
    if facing == Vector2.ZERO:
        return current                          # hold last dir (never undefined)
    var deg := rad_to_deg(facing.angle())       # screen space: +x = east (0°), +y = south (90° DOWN)
    var idx := int(round(deg / 45.0)) % 8        # 8 sectors of 45°
    # ... map idx → DIRS[idx]; apply hysteresis band vs `current` ...
    return _dir_for_index(idx)

## Pure: pick the clip family. pickup/throw take priority while their one-shot +
## lock window runs; otherwise walk above the speed threshold, else idle.
static func select_state(velocity: Vector2, locked: bool, action: StringName) -> StringName:
    if action != &"":                            # an action one-shot owns the sprite
        return action
    if not locked and velocity.length() > WALK_SPEED_THRESHOLD:
        return &"walk"
    return &"idle"
```

Headless test (new `Game/tests/test_player_visual.gd`, run as a **SCENE** per repo convention) asserts: all 8 cardinal/diagonal
`facing` vectors quantize to the right dir; hysteresis holds dir across a small boundary jitter; `select_state` returns
`walk`/`idle` across the threshold and `pickup`/`throw` win while `action` is set; `select_state(.., locked=true, ..)` never
returns `walk` (a locked player reads idle/action, never a walk-in-place). These call the `static` helpers directly — no
physics space, mirroring `test_player_movement.gd`.

### `player.tscn` changes

- **ADD** `AnimatedSprite2D` (child of a new `PlayerVisual` node) with `sprite_frames =`
  `res://entities/player/player_frames.tres`, scaled + Y-offset so the character reads against the r=14 body (exact scale/offset
  is N0's call; N1 consumes it — OQ-6). `centered = true`, `z_index` so the sprite sorts above the floor but interacts sanely
  with world depth (OQ-6).
- **ADD** the `PlayerVisual` node + `player_visual.gd`.
- **RETAIN** `Visual` (`ColorRect`) and `Nose` (`Polygon2D`) exactly as-is — set `visible = false` by default (art ON default),
  re-shown by the N2 toggle path. **No node deleted.** Collision shape, `InteractionOrigin`, `InteractionDetector` unchanged.

---

## (c) Open Questions

- **OQ-1 — 8-dir quantize boundaries + hysteresis.** Sector mapping: `round(deg/45) % 8` gives 8 equal 45° sectors centred on
  each dir (east at 0°, south at +90° since +y is down). **Hysteresis:** require a new dir to win by > N° (proposed 10°) before
  switching, so a `facing` hovering on a 22.5° boundary (common with mouse aim) doesn't strobe between e.g. `east` and
  `south_east`. Open: the exact hysteresis band (5°/10°/15°), and whether to also add a small *time* debounce (hold a dir for ≥
  k ms) on top of the angular band. *Recommend angular-only at 10°; revisit if RG2 shows flicker.*
- **OQ-2 — walk↔idle velocity threshold.** Proposed `WALK_SPEED_THRESHOLD = 8.0` px/s (well below `max_speed=200`, above the
  friction tail so a decelerating player snaps to idle promptly rather than walking-in-place at ~1 px/s). Open: exact value;
  whether to add a tiny hysteresis here too (enter-walk at 8, exit-walk at 4) to avoid idle/walk strobe when grazing the
  threshold. *Recommend a single threshold first; add exit-hysteresis only if it strobes.*
- **OQ-3 — lock mechanism + duration vs. clip length.** Mechanism chosen: **zero the movement `input_dir`** (so the unchanged
  `step_velocity` friction roots the body) — preferred over zero-velocity (skips deceleration, feels like a hard stop) or a
  full `_physics_process` early-out (would also freeze aim + `move_and_slide`, breaking wall-resting). Open: **does the clip
  drive the lock, or is it a fixed `LOCK_DURATION`?** If clip-driven, the lock = the one-shot's real runtime (frames/fps from
  N0) and `animation_finished` releases it — self-consistent, but pickup (5f) and throw (7f) then lock for *different* lengths,
  and the duration is implicit in N0's fps. If fixed (~0.25 s), the lock is tunable independently and identical across actions,
  but can mismatch the clip (lock ends before/after the animation). *Recommend clip-driven for honesty (the root lasts exactly
  as long as the animation reads), with a `@export` ceiling so a mis-authored long clip can't over-root — needs Director feel
  review (felt-cost of locking during a tense extract is the breakdown's explicit RG-watch item).*
- **OQ-4 — throw/pickup mid-stride behaviour.** When an action begins while running, do we (a) **snap the dir at lock-start and
  freeze it** for the clip (proposed — the action points where you aimed when you committed, no mid-clip dir-flip), or (b) let
  the dir keep tracking `facing` through the clip (re-faces mid-throw, can look jittery)? And does the *clip* play from frame 0
  (proposed) or could it ever need to "freeze the current frame"? *Recommend (a): freeze dir at commit, play the one-shot from
  frame 0; the body still decelerates underneath via the input-gate so it reads as "plant + act."* Needs a quick Director look.
- **OQ-5 — does PICKUP have a felt moment at all?** Interact/pickup is near-instant gameplay, and `junk_picked_up` fires on
  **rejected** attempts too (`event_bus.gd:59`, `accepted` flag). Options: (i) play `pickup_<dir>` + lock fully on **accepted**
  pickups only (proposed — a real "stoop and grab" beat, no animation on a full-bag reject); (ii) play on every attempt
  (accepted + rejected) — a reject then animates a grab that grabbed nothing (odd); (iii) pickup is **cosmetic-only, no lock**
  (the 5-frame clip plays but movement isn't rooted) — avoids a root on a near-instant action but breaks the "actions root"
  rule the Director set. *Recommend (i): accepted-only, with lock.* Whether a *rejected* pickup plays a (lockless) "reach" is a
  feel call — *recommend no animation on reject* to keep it clean; needs Director sign-off.
- **OQ-6 — z-ordering + sprite scale/offset.** The sprite must sort above the floor and read against the r=14 body, and relate
  sanely to the `Nose` (hidden under art ON, OQ-8) and any world depth sorting (hazards/junk). Open: the `AnimatedSprite2D`'s
  `z_index`/`y_sort` relationship to band pieces + pickups (does the player ever need to draw *behind* a tall piece? M1.7 art is
  a flat top-down character, so likely a fixed `z_index` above the floor is fine). Scale + Y-offset (the 64px-on-124px canvas
  character sitting on the r=14 body) is **N0's authored decision**; N1 just consumes the `.tscn` transform. *Recommend N0
  fixes scale/offset; N1 uses a fixed `z_index` above the floor layer, no y-sort, pending RG2.*
- **OQ-7 — dir-string contract with N0.** N1's `quantize_dir` output strings must match N0's `SpriteFrames` clip suffixes
  **exactly** (`south`/`south_east`/… underscored, as fixed in this doc). If N0 authored a different spelling (e.g. `SE`,
  `southeast`, hyphenated), every clip lookup silently no-ops. *Recommend this doc's underscored set be the locked shared
  contract; N0 + N1 both reference it. A startup assert (`_sprite.sprite_frames.has_animation("idle_south")`, etc.) in
  `_ready()` under art ON catches a mismatch loudly.*
- **OQ-8 — hide the `Nose` (and `Visual`) when art is ON?** Proposed: under art ON, hide **both** greybox nodes (`Visual`
  `ColorRect` + `Nose` `Polygon2D`) so only the real sprite renders; under art OFF, show both (today's look). The `Nose`
  rotation in `_update_facing_visual()` stays harmless while hidden. Open: is there any value in keeping the `Nose` visible
  *over* the sprite as an aim indicator (the sprite is 8-dir-quantized, so it reads aim only in 45° steps, whereas the `Nose`
  is continuous)? *Recommend hide both under art ON for a clean character; if playtesters lose the precise-aim read, a
  dedicated thin aim-reticle is a later, separate task — not the greybox `Nose`.* Needs Director feel review.

---

## Resolved Decisions

*Phase-3 fresh-eyes resolution (resolver did NOT author this doc), 2026-06-27. Grounded in `M1.7_Breakdown.md` (LOCKED
Director calls: art in BOTH hub+dive; brief movement-lock ON only when art is ON), `player.gd` (real `aim`/`facing`/
`velocity`/`step_velocity`/`resolve_aim` seams), and `N0_art_import_spriteframes.md` (locked clip names/FPS). Technical OQs
resolved on merit; feel/tuning OQs carry a recommendation but are marked **needs Director review** — the Director already
chose "brief movement lock" at the breakdown level, so only the *tuning* is open, never *whether* to lock.*

- **OQ-1 (quantize boundaries + hysteresis) — RESOLVED.** Use `round(deg/45) % 8` (8 equal 45° sectors; east=0°, south=+90°
  since +y is down) with **angular-only hysteresis at 10°** and **no time debounce**. Rationale: 10° is ~22% of a 45° sector —
  enough to kill boundary strobe from continuous mouse aim without the new dir feeling laggy; a time debounce adds latency to a
  responsive twin-stick aim and is unnecessary if the angular band already holds. Revisit only if RG2 shows residual flicker.

- **OQ-2 (walk↔idle threshold) — RESOLVED.** Single threshold `WALK_SPEED_THRESHOLD = 8.0` px/s, **no exit-hysteresis to
  start**. Rationale: 8 px/s sits well above the friction tail (so a decelerating player snaps to idle promptly, no
  walk-in-place at ~1 px/s) and far below `max_speed=200` (so any real walk reads as walk). Add enter-8/exit-4 hysteresis only
  if RG2 shows idle/walk strobe when grazing the threshold — keep it simple until proven needed.

- **OQ-3 (lock mechanism + duration) — mechanism RESOLVED; duration NEEDS DIRECTOR REVIEW.** Mechanism is locked: **zero the
  movement `input_dir`** so the unchanged `step_velocity` friction roots the body (preserves wall-resting, aim, and
  `move_and_slide`; no velocity clobber). For duration, recommend **clip-driven** (the lock lasts exactly the one-shot's real
  runtime — pickup ≈0.25 s, throw ≈0.29 s per N0's FPS — released by `animation_finished`) **with an `@export` ceiling**
  (e.g. 0.4 s) as a safety cap so a mis-authored long clip can't over-root. Clip-driven is "honest" (root = exactly as long as
  the animation reads) and keeps the single tuning point in N0's FPS, which already lands inside the breakdown's ~0.2–0.3 s
  window. **needs Director review** — the felt-cost of rooting during a tense extract is the breakdown's explicit RG-watch
  item; if the clip-length root reads as sluggish, fall back to a shorter fixed `LOCK_DURATION` (~0.18 s) with the clip allowed
  to finish cosmetically after movement frees.

- **OQ-4 (mid-stride behaviour) — RESOLVED, with a feel flag.** **Snap the dir at lock-start and freeze it for the clip,
  playing the one-shot from frame 0** (option a). Rationale: the action points where the player committed, with no mid-clip
  dir-flip (which reads as a jitter/swivel); the body still decelerates underneath via the input-gate, so it reads as "plant +
  act." `facing`/`aim` keep updating (not gated) so the player re-faces immediately on the next state after the clip. This is a
  clean technical default; the only residual feel question (does freezing the throw dir mid-sprint feel like a hitch?) is
  subsumed by OQ-3's lock-feel review at RG2 — no separate Director call needed unless RG2 surfaces it.

- **OQ-5 (does PICKUP have a felt moment) — RECOMMENDATION; NEEDS DIRECTOR REVIEW.** Recommend **(i): play `pickup_<dir>` +
  full movement-lock on ACCEPTED pickups only**, and **no animation on a rejected pickup** (a full-bag reject grabbed nothing,
  so a "stoop and grab" beat would lie). N1 gates on the `accepted` flag of `junk_picked_up` (`event_bus.gd:59`). Rationale:
  this honors the Director's "actions root" rule while keeping rejects clean; cosmetic-only-no-lock (iii) would violate that
  rule, and animate-every-attempt (ii) shows a grab that grabbed air. **needs Director review** — whether interact is too
  near-instant for a rooted pickup beat to feel good (vs. feeling like an interruption) is a fun call; the fallback if it reads
  as a stutter is to keep the pickup clip but drop its lock to ~0 (cosmetic), accepting a one-action exception to "actions
  root." `PLAY_PICKUP_ON_REJECT` defaults `false`.

- **OQ-6 (z-order + scale/offset) — RESOLVED.** N1 uses a **fixed `z_index` above the floor layer, no `y_sort`** — M1.7 art is
  a flat top-down character with no requirement to draw behind tall pieces, so a fixed sort above the floor and at/above pickups
  is correct and avoids y-sort flicker against the r=14 body's origin. **Scale + Y-offset are N0/asset-tuned, consumed by N1**
  from the `.tscn` transform (N0's design recommends scale ≈0.45–0.5 with a negative Y-offset so feet sit at body center); N1
  must not bake scale into textures. Revisit y-sort only if a later iteration adds tall occluders.

- **OQ-7 (dir-string contract with N0) — RESOLVED (now a confirmed cross-doc lock).** The shared contract is the
  **underscored 8-token set** `&"south", &"south_east", &"east", &"north_east", &"north", &"north_west", &"west",
  &"south_west"` — this matches N0's locked normalization (N0 OQ-6, copy plan normalizes hyphen→underscore) exactly. `quantize_dir`
  emits these verbatim and `_play` builds `"%s_%s" % [state, dir]`. **Required guard:** a `_ready()` startup assert under art ON
  (`_sprite.sprite_frames.has_animation("idle_south")` plus a sample of the other states) so a future spelling drift fails
  loudly, not as a silent clip no-op. No remaining ambiguity — N0 and N1 reference the same token list.

- **OQ-8 (hide the Nose/Visual under art ON) — RESOLVED, with a deferred fallback.** Under art ON, **hide BOTH greybox nodes**
  (`Visual` `ColorRect` + `Nose` `Polygon2D`); under art OFF, show both (M1.6 look). `_update_facing_visual()`'s `Nose`
  rotation stays harmless while hidden (no body change needed). Rationale: a clean single-character read is the milestone's goal;
  the 8-dir-quantized sprite loses continuous-aim precision vs. the `Nose`, but repurposing the greybox `Nose` as an aim
  indicator over real art is visually muddy. If RG2 playtesters lose the precise-aim read, a **dedicated thin aim-reticle is a
  later separate task** — not the greybox `Nose`. This is a clean default; the aim-read question is a watch-item for RG2, not a
  build blocker.

### Hard contracts re-affirmed (unchanged by any decision above)
- **Art-OFF == M1.6 byte-for-byte:** the lock is *never armed* under art OFF (`is_locked()` returns `_art_on and …`), so
  `_physics_process` executes today's exact lines (greybox path verbatim). Default = art ON.
- **Collision r=14 + movement tuning UNTOUCHED:** the lock gates only the `input_dir` *value* fed to the unchanged
  `step_velocity`; `stats`, the `CircleShape2D` r=14, and layer/mask are never read or written by N1.
- **Determinism fp `e943ac9c8bc1` UNMOVED:** N1 is a pure renderer — no RNG, no `RunConfig` field, no generator; nothing it
  writes reaches `fingerprint()`.

---

## Director Dispositions (ratified 2026-06-27) — design LOCKED

The two `needs Director review` feel-calls were dispositioned by the Director. **Both verdicts add a "make it configurable"
rider** — the chosen default is correct, but expose it as a tunable so it can be flipped without a code change.

- **OQ-5 (pickup felt-moment) → RATIFIED: lock + crouch-grab clip on ACCEPTED pickups only; a full-bag reject plays nothing —
  AND make this CONFIGURABLE.** Implement as `@export` flags on the visual controller (e.g. `@export var lock_on_pickup: bool = true`,
  `@export var play_pickup_on_reject: bool = false`). These are **visual-controller exports, NOT `RunConfig` knobs** — they live
  on `player_visual.gd` (or the player), entirely outside the `config_menu` MANIFEST / 89-field coverage set, so the determinism
  fingerprint and knob count are untouched. Default ships = accepted-only, no reject anim.
- **OQ-3 (lock duration) → RATIFIED: clip-driven (released by `animation_finished`, pickup≈0.25 s / throw≈0.29 s) with an
  `@export` ceiling cap — AND make the MODE configurable.** Implement as `@export` on the visual controller, e.g.
  `@export var lock_mode: LockMode = LockMode.CLIP_DRIVEN` (CLIP_DRIVEN | FIXED) + `@export var lock_duration_cap_s: float`
  (and a `fixed_lock_s` used when mode = FIXED). Again a visual-controller export, not a `RunConfig` field. Default = clip-driven
  with a sane ceiling cap. This lets the Director switch to a shorter fixed lock in-editor if RG1 reads sluggish, no rebuild of logic.

Both remain **RG-watch items** for the RG1 Director playtest (felt-cost of rooting in a tense extract); the configurability is the
agreed hedge so tuning is a one-line export change, not a redesign. Walk-cadence FPS ratified at **10 fps for RG1** (revisit at RG2).

---

## As-built amendment (M1.8 close-out, 2026-07-02 — deviation PLAYERTAB, Director: Addressed)

The ratified shared lock knobs `lock_duration_cap_s` (0.4) + `fixed_lock_s` (0.18) were **replaced
post-N1 by per-action knobs** `pickup_lock_s` (0.25) + `throw_lock_s` (0.30) (Director-directed, commit
`bb1976a`), tunable live from the debug-menu **Player tab** alongside lock-on-pickup / animate-on-reject /
lock-mode. **CLIP_DRIVEN (the shipped default) is byte-for-byte unchanged** (caps ≥ clip lengths →
non-binding); only non-default FIXED-mode durations differ. These per-action knobs are the canonical
as-built timing model; this section supersedes the shared-knob text above. fp `e943ac9c8bc1` + knob-count
contracts held (controls are debug-only, outside the MANIFEST).
