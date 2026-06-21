# K5b — Bomb hazard · Phase-2 design

**Milestone:** M1.4 (Stakes, Variety & Legibility) · Wave 3 (Danger variety).
**Authored:** 2026-06-21, Phase 2 (per-task design) of the four-phase process (`CLAUDE.md`).
**Role(s):** `general-purpose` (entity script/scene) + `character-animator` (pulse/explode tell FX).
**BlockedBy:** K0 (reads its `h_bomb_*` knobs). Spawn-seam wiring is **K5i** (`BlockedBy: K5a,K5b,K5c`).
**Status:** Phase-2 draft. `Open Questions` below are for Phase-3 fresh-eyes + Director.

> **Director work-order (verbatim):** "Big bomb enemy, explodes in a radius if too close. Enemy with a
> visual radius — if you get too close, the enemy pulses for ~2 seconds, then explodes. If it explodes
> when you are inside, it kills you. Spawns randomly around the room, and more the deeper you go."

---

## 0. The one thing this task delivers

A NEW **stationary greybox hazard** — a "bomb" — that is *spatially passive but punishing*: it sits inert
showing a faint **proximity ring**; the instant the player crosses that ring it **arms and pulses for
~2 s** (an accelerating throb), then **detonates**. If the player is inside the **blast radius** at the
detonation frame it is fatal (`GameState.fail_run(&"death")`); otherwise it fizzles. This is the *area-denial /
"don't dawdle here"* danger, complementing K5a's ping-pong (moving line-of-fire) and K5c's rotating spikes
(timing window). Greybox, configurable-not-balanced, all-off-neutral — exactly the M1.1→M1.3 contract.

---

## 1. Research (premise + what it builds on)

### 1.1 The greybox-hazard pattern to mirror (R1)

`scenes/hazards/hazard_entity.gd` (R1, M1.1) is the canonical greybox-hazard template, and K5b mirrors its
load-bearing idioms exactly:

- **A `CharacterBody2D` on layer `hazard`(5), masking ONLY `world`(2)** — `hazard_entity.tscn:8-11`
  (`collision_layer = 16`, `collision_mask = 2`). It deliberately does **not** mask `player`: lethality is a
  **script distance test**, not a physics overlap, so it is deterministic and frame-exact
  (`hazard_entity.gd:24-25`, `:143-147`). K5b keeps this discipline — proximity + blast are `distance_to`
  tests, never `Area2D` `body_entered`.
- **`setup(cfg: RunConfig, player: Node2D)`** snapshots the run config and resolves the player, called by the
  spawn seam right after `add_child` (`hazard_entity.gd:83-91`; called at `main_game.gd:323`/`:349`). The
  snapshot means a later `active_run_config` clear on run-end can't null it mid-frame.
- **Fatal via the EXISTING `GameState.fail_run(&"death")`** — no new end path, no local "already ended" guard.
  `GameState._run_ended` is the single source of truth for run-end idempotency across hazards + extract
  (`hazard_entity.gd:182-191`, `game_state.gd:323-326`). K5b routes its kill through the identical call;
  multiple bombs detonating the same frame are absorbed by that guard for free.
- **A child `Tell: Polygon2D`** is the entire greybox visual — no sprite sheets, no `AnimationTree`
  (`hazard_entity.tscn:13-15`, `hazard_entity.gd:77`, `:212-228`).
- **The R1 tween-flash idiom (reuse this for the pulse).** `_set_tell_awake()` fires a **one-shot
  `create_tween()`** scale-up-and-settle so the state-change beat reads (`hazard_entity.gd:224-228`):

  ```gdscript
  var tw := create_tween()
  tw.tween_property(_tell, "scale", Vector2(1.4, 1.4), 0.08)
  tw.tween_property(_tell, "scale", Vector2.ONE, 0.12)
  ```

  K5b reuses this exact idiom for **(a)** the arm flash (idle→pulsing) and **(b)** the explode flash
  (pulsing→explode), and adds an **accelerating pulse** by chaining `set_loops()` tweens whose durations
  shrink across the ~2 s window. The comment's safety note carries: "if the tree is paused/headless the
  color flip already carries the state; the Tween is pure juice" — the **state machine never depends on a
  tween callback for its fatal logic** (headless determinism). Detonation is driven by an accumulated
  `_pulse_t` float in `_physics_process`, NOT by a tween `finished` signal.

### 1.2 The spawn seam K5i will wire into (this task designs the contract, not the wiring)

`scenes/game/main_game.gd` already has the per-room density seam K5i reuses for K5b's "spawns randomly around
the room, more with depth":

- **`_density_spawn_positions(band, rc) -> Array[Vector2]`** (`main_game.gd:359-397`) is the proven
  **deterministic, RNG-free per-room placement plan**: walk pieces depth-sorted (`_density_pieces_sorted`,
  `:422-434`), count `n = floor(density * area / AREA_UNIT)` capped per-room + band-wide, then **stride** the
  `n` positions across that room's own sorted floor cells (`:391-396`). Same `(band, rc)` → byte-identical list.
- **`_density_cell_to_world(cell)`** (`:448-451`) and **`_hazard_spawn_position(band, depth, index)`**
  (`:502-515`) are the cell→world projections (centred in the cell). K5b positions land via the same
  projection so a bomb sits on a floor-cell centre.
- **`_band_max_depth(band)`** (`:490-491`) = `band.max_depth` — the single source of truth for depth scaling.
- **Depth scaling already has a precedent:** R1's `_hazard_spawn_depths` (`:460-483`) distributes a count
  across `[min..max_depth]`, and `_density_spawn_positions` strides per-room. K5b's "more with depth" is the
  same shape: a **base count + per-depth count** evaluated per room against that room's `depth_index`.

**Seam ownership:** **K5i** is the single writer on `main_game.gd`'s `_spawn_*` seam this wave (Breakdown §4).
This doc designs the **entity + its config group + the depth-scaled-count formula**; K5i implements the loop
that instantiates `BombHazard` nodes at the planned positions into `_band_container` (so `_clear_band()` frees
them — run-state, never persisted, never feeds `fingerprint()`, exactly like the R1 hazards).

### 1.3 The config contract (K0 pre-declares; this doc proposes the shape)

`data/run_config/run_config.gd` is the single run-scoped config object. **K0 (foundation) is the only writer
on `run_config.gd` this milestone** and pre-declares **every** M1.4 knob at off/neutral defaults, extends
`to_flat_dict()`, and bumps the CFG knob count (Breakdown §3 K0, §6). K5b's job is to **specify the `h_bomb_*`
group K0 then declares** — its fields, defaults (all-off-neutral), and meaning. The all-off default
(`h_bomb_enabled = false`) MUST cause the spawn seam to instantiate **no node**, so the M1.0 baseline
(fp=`e943ac9c8bc1`) is byte-for-byte unchanged (the R1 `r1_enabled=false` precedent, `run_config.gd:18-21`).
The fun values ship only in `make_default_play_preset()` (`run_config.gd:428-500`), never in the code-level
defaults.

### 1.4 The player target

`entities/player/player.tscn`: a `CharacterBody2D` in group `player`, **collision radius 14 px**
(`CircleShape2D_player`), layer 1 (`player`). The bomb resolves it via
`get_tree().get_first_node_in_group(&"player")` (the R1 path, `main_game.gd:310`) and tests
`global_position.distance_to(_player.global_position)`. Because the player body is radius 14, the **blast
radius is measured to the player's *centre*** — a blast radius of e.g. 40 px means "player centre within 40 px,"
which is generous-by-design (see Q3 on radius semantics).

---

## 2. Pseudocode (against the real as-built APIs)

### 2.1 The `h_bomb_*` config group (K0 declares; this is the proposed shape)

```gdscript
# data/run_config/run_config.gd — appended by K0, group designed here.
# ALL DEFAULTS ARE OFF/NEUTRAL: h_bomb_enabled=false => spawn seam instantiates no node
# => M1.0 baseline byte-identical (fp=e943ac9c8bc1). The fun values live ONLY in
# make_default_play_preset(); never change these code-level defaults.
@export_group("H_Bomb Hazard", "h_bomb_")
## Master toggle. OFF = no bomb exists; behaviour matches M1.0/M1.3.
@export var h_bomb_enabled: bool = false
## Bombs placed in the SHALLOWEST eligible room (the floor of the depth ramp). 0 = none at depth 0.
@export var h_bomb_base_count: int = 0
## Additive bombs per unit of room depth_index ("more the deeper you go"). 0 = flat (no depth scaling).
@export var h_bomb_count_per_depth: float = 0.0
## Distance (px, player-centre) at which crossing IN arms the bomb (the visible idle ring). 0 = inert.
@export var h_bomb_proximity_radius: float = 0.0
## Seconds the bomb pulses after arming before it detonates (~2.0 per the work-order). 0 = instant (avoid).
@export var h_bomb_pulse_seconds: float = 0.0
## Lethal radius (px, player-centre) tested AT detonation. Player inside => fail_run(&"death").
## May be SMALLER than the proximity radius (telegraph generosity: see Q3) or larger (overkill). 0 = harmless.
@export var h_bomb_blast_radius: float = 0.0
## Per-room hard cap on bombs (perf/fun guard, mirrors r1_density_per_room_cap). 0 = uncapped.
@export var h_bomb_per_room_cap: int = 0
```

And in `to_flat_dict()` (K0 extends; additive payload, not a schema bump — `run_config.gd:281-339`):

```gdscript
        # H_Bomb (K5b, M1.4) — additive telemetry payload; RG2 segments on these
        "h_bomb_enabled": h_bomb_enabled,
        "h_bomb_base_count": h_bomb_base_count,
        "h_bomb_count_per_depth": h_bomb_count_per_depth,
        "h_bomb_proximity_radius": h_bomb_proximity_radius,
        "h_bomb_pulse_seconds": h_bomb_pulse_seconds,
        "h_bomb_blast_radius": h_bomb_blast_radius,
        "h_bomb_per_room_cap": h_bomb_per_room_cap,
```

**Depth-scaled count contract (K5i applies this per room):**

```gdscript
# Per room (a PlacedPiece p with p.depth_index), the bomb count is:
#   n = floor(h_bomb_base_count + h_bomb_count_per_depth * float(p.depth_index))
#   if h_bomb_per_room_cap > 0: n = min(n, h_bomb_per_room_cap)
# Placement reuses the _density_spawn_positions stride idiom: spread n bombs across the
# room's own sorted floor cells (RNG-free, deterministic, run-state). K5i owns the loop.
```

### 2.2 The bomb entity: IDLE → PULSING → EXPLODE state machine

```gdscript
class_name BombHazard
extends Area2D   # RECOMMENDED base — see Q1. Stationary => no CharacterBody2D physics needed.
## BombHazard (K5b, M1.4) — a stationary greybox proximity bomb. Sits inert showing an idle
## proximity ring; when the player crosses h_bomb_proximity_radius it arms and pulses for
## h_bomb_pulse_seconds (~2s, accelerating), then detonates: player within h_bomb_blast_radius
## at the detonation frame => GameState.fail_run(&"death"); else it fizzles.
##
## THROWAWAY GREYBOX, not the M2 enemy-AI slice. No health, no movement, no pathfinding.
## READS ONLY: snapshots GameState.active_run_config (its h_bomb_* knobs) at setup; routes a
## fatal blast through the EXISTING GameState.fail_run(&"death") (no new end path). EMITS the
## pre-declared EventBus.bomb_armed / bomb_detonated (K0 pre-declares; never edits event_bus.gd).
##
## ALL-OFF: with h_bomb_enabled=false the spawn seam never instantiates this node, so the M1.0
## baseline is byte-for-byte unchanged. Determinism: proximity + blast are SCRIPT DISTANCE TESTS
## (mirrors R1, hazard_entity.gd:24-25/:143-147), driven by an accumulated _pulse_t float in
## _physics_process — NEVER by a tween finished-signal (headless/paused-safe).
##
## Collision: as an Area2D it can carry the `hazard`(5) layer for editor/debug parity, but it
## masks NOTHING — it never collides with or blocks anything (a bomb is not a wall and the
## player walks over it). All lethality is the distance test (Q1).

enum State { IDLE, PULSING, EXPLODED }

# Greybox tell colors (character-animator inline contribution; mirrors R1's palette idiom).
const COLOR_IDLE := Color(0.45, 0.45, 0.55, 0.5)   # dim translucent — "dormant ring"
const COLOR_ARMING := Color(0.95, 0.75, 0.2)        # amber — "pulsing, about to blow"
const COLOR_BLAST := Color(1.0, 0.25, 0.1)          # hot orange-red — "detonation flash"

var _cfg: RunConfig                  # snapshot of GameState.active_run_config at setup
var _state: int = State.IDLE
var _player: Node2D                  # resolved at setup via the "player" group
var _pulse_t: float = 0.0            # seconds since arming (drives detonation deterministically)
var _pulse_tween: Tween              # the accelerating throb (juice only; never gates logic)

@onready var _ring: Polygon2D = $IdleRing     # faint proximity-radius ring (the telegraph)
@onready var _core: Polygon2D = $Core         # the bomb body (throbs while pulsing)


## Bind config + player and seat the IDLE ring sized to the proximity radius. Called by the
## K5i spawn loop right after add_child (mirrors hazard_entity.setup, :83-91).
func setup(cfg: RunConfig, player: Node2D) -> void:
    _cfg = cfg
    _player = player
    _state = State.IDLE
    _pulse_t = 0.0
    _draw_idle_ring(cfg.h_bomb_proximity_radius)   # sized to the actual telegraph radius
    _set_tell_idle()


func _physics_process(delta: float) -> void:
    if _player == null or _cfg == null or not is_instance_valid(_player):
        return

    match _state:
        State.IDLE:
            # Arm on the RISING edge into the proximity ring. distance to player CENTRE
            # (player is radius 14; the ring is generous-by-design — see Q3).
            var d := global_position.distance_to(_player.global_position)
            if _cfg.h_bomb_proximity_radius > 0.0 and d <= _cfg.h_bomb_proximity_radius:
                _arm()
        State.PULSING:
            # Committed-once-armed (Director-FINAL recommendation, Q2): leaving the ring does
            # NOT defuse. The pulse window is the player's escape window — run OUT of the blast.
            _pulse_t += delta
            if _pulse_t >= _cfg.h_bomb_pulse_seconds:
                _detonate()
        State.EXPLODED:
            pass   # one-shot terminal (Q4 recommends one-shot free; queue_free below)


## IDLE -> PULSING once: amber flash + start the accelerating throb, emit bomb_armed.
func _arm() -> void:
    _state = State.PULSING
    _pulse_t = 0.0
    _set_tell_arming()
    _start_pulse_tween()                          # juice only — detonation is _pulse_t-driven
    EventBus.bomb_armed.emit(GameState.current_depth_index)


## PULSING -> EXPLODED: distance test at the detonation frame. Inside blast => fatal via the
## EXISTING end path (GameState._run_ended absorbs same-frame dupes). Else fizzle. One-shot.
func _detonate() -> void:
    _state = State.EXPLODED
    if _pulse_tween != null and _pulse_tween.is_valid():
        _pulse_tween.kill()
    var d := global_position.distance_to(_player.global_position)
    var hit: bool = _cfg.h_bomb_blast_radius > 0.0 and d <= _cfg.h_bomb_blast_radius
    _flash_blast()                                # brief explode flash (juice; runs even if fatal)
    EventBus.bomb_detonated.emit(GameState.current_depth_index, hit)
    if hit:
        GameState.fail_run(&"death")              # existing end path; _run_ended owns idempotency
    # Q4 recommendation: one-shot. Free after the flash so the node leaves no lingering ring.
    # The flash is ~0.15s; a short timer then queue_free (run-state, _clear_band would also free it).
    get_tree().create_timer(0.2).timeout.connect(queue_free)


# --- Greybox tells (inline placeholders; character-animator owns the feel) ----

func _set_tell_idle() -> void:
    _core.color = COLOR_IDLE
    _ring.modulate = Color(COLOR_IDLE, 0.35)      # faint, always-visible telegraph

func _set_tell_arming() -> void:
    _core.color = COLOR_ARMING

## Accelerating pulse: a looping scale throb whose period SHRINKS as detonation nears so the
## tempo itself reads "about to blow" (the R1 create_tween idiom, chained + looped). Pure juice —
## if paused/headless the color carries the state and _pulse_t still drives _detonate().
func _start_pulse_tween() -> void:
    _pulse_tween = create_tween().set_loops()     # loops until kill() in _detonate
    # A few throbs across the ~2s window, each faster than the last (illustrative; tuned by anim).
    var period := maxf(_cfg.h_bomb_pulse_seconds, 0.1)
    for step in 4:
        var dur := (period / 8.0) * (1.0 - 0.18 * float(step))   # shrinking period
        _pulse_tween.tween_property(_core, "scale", Vector2(1.35, 1.35), dur * 0.5)
        _pulse_tween.tween_property(_core, "scale", Vector2.ONE, dur * 0.5)

## Brief one-shot explode flash (the R1 wake-flash shape: hot color + a quick scale pop).
func _flash_blast() -> void:
    _core.color = COLOR_BLAST
    var tw := create_tween()
    tw.tween_property(_core, "scale", Vector2(2.2, 2.2), 0.06)
    tw.tween_property(_core, "modulate:a", 0.0, 0.12)

## Draw the faint idle ring as a polygon approximating a circle of radius r (the telegraph).
## (A Polygon2D ring or _draw() draw_arc; greybox — exact shape is the animator's call.)
func _draw_idle_ring(r: float) -> void:
    var pts := PackedVector2Array()
    for i in 24:
        var a := TAU * float(i) / 24.0
        pts.append(Vector2(cos(a), sin(a)) * maxf(r, 1.0))
    _ring.polygon = pts
```

### 2.3 New EventBus signals (K0 pre-declares — never edited here)

```gdscript
# systems/event_bus.gd — appended by K0 (the milestone's signal pre-declare pass).
## K5b (M1.4): a bomb armed (player entered its proximity ring). depth = current_depth_index.
signal bomb_armed(depth: int)
## K5b (M1.4): a bomb detonated. hit = was the player inside the blast radius (fatal)?
signal bomb_detonated(depth: int, hit: bool)
```

These mirror R1's `hazard_awoke` / `hazard_caught` (`event_bus.gd:90-91`) — additive, telemetry-only, no
arity change to `run_ended`. RG2 segments bomb cohorts on `bomb_armed` / `bomb_detonated(hit)` counts.

---

## 3. Design decisions baked in (with rationale)

- **Lethality is a script distance test at the detonation frame**, never a physics overlap — the R1
  determinism discipline (`hazard_entity.gd:24-25`). The blast is evaluated once, on the frame `_pulse_t`
  crosses `h_bomb_pulse_seconds`, so for a given seed+config the death frame is reproducible.
- **The state machine never depends on a tween callback.** Detonation is driven by accumulated `_pulse_t`
  in `_physics_process`; the tweens are pure juice (the R1 note, `hazard_entity.gd:224-228`). Headless/paused
  runs still detonate correctly — load-bearing for the CI smoke test + telemetry determinism.
- **All-off-neutral:** `h_bomb_enabled=false` → K5i instantiates no node → fp byte-identical
  (the `r1_enabled` precedent). Placement is **pure run-state**, never feeds `fingerprint()` (Breakdown §6).
- **Reuses the proven per-room density seam** for "spawns randomly around the room, more with depth" —
  RNG-free deterministic stride over floor cells + a per-depth count, capped per room. No new RNG stream,
  no navmesh, no new spawn machinery (Breakdown §2 guardrails).
- **Fatal routes through the existing `GameState.fail_run(&"death")`** — `_run_ended` absorbs concurrent
  detonations + extract for free (`game_state.gd:323-326`). `run_ended` arity stays locked (Breakdown §6).

---

## 4. Open Questions

These are the load-bearing unresolved calls. Each carries a recommendation for Phase-3 fresh-eyes to ratify
(technical/design merit) or flag to the Director (vision/fun/scope).

### Q1 — Base class: `Area2D` vs `CharacterBody2D` vs plain `Node2D`?

The bomb is **stationary** and never moves, so R1's `CharacterBody2D` (which it uses for `move_and_slide`) is
overkill here.
- **`CharacterBody2D` (R1's base):** maximal parity with the existing template; but it carries a physics body
  + `move_and_slide` machinery the bomb never uses, and a collision shape that could *block the player* if
  masked wrong (we'd have to mask nothing, like R1 masks only `world`). Dead weight.
- **`Area2D`:** cheap, signal-capable, can carry the `hazard`(5) layer for editor/debug parity; masks NOTHING
  so it never blocks the player (a bomb is walk-over). We still use **script distance tests** for arm/blast
  (NOT `body_entered`), to keep R1's frame-exact determinism — the Area2D is essentially just a typed
  `Node2D` with a layer tag.
- **Plain `Node2D`:** the leanest — no collision concept at all, purely a position + two `Polygon2D` tells +
  the distance-test logic. Nothing in the design needs physics or area callbacks.

**Recommendation:** plain **`Node2D`** is the most honest fit (stationary, distance-test-only, never collides),
with the `hazard` group tag for parity. `Area2D` is acceptable if K5i/QA want a debug collision visual. Avoid
`CharacterBody2D` — it implies movement the bomb doesn't have. *Fresh-eyes to confirm; not a Director call.*

### Q2 — Defuse-on-leave vs committed-once-armed?

Once the player crosses the proximity ring and the pulse starts, does **leaving the ring during the ~2 s
cancel** it (defuse), or is it **committed** (it will detonate regardless; the player must escape the *blast*,
not the *proximity* ring)?
- **Committed:** the pulse window is a clean "you triggered it, now run out of the blast" beat — legible,
  punishing, matches "if you get too close... then explodes." Re-entering does nothing new. Simplest, most
  readable.
- **Defuse-on-leave:** more forgiving (back off and it stands down) but muddier — it turns the bomb into a
  proximity *fence* you can repeatedly poke, and re-arm/cancel flicker is ugly at the ring boundary.

**Recommendation:** **committed once-armed** (the pseudocode assumes this). It reads as the work-order
intends ("pulses ~2s then explodes"), and the *escape* is running clear of the (smaller) blast radius, which
is exactly the telegraph-generosity Q3 enables. This is a **fun/feel call → flag to the Director** with this
recommendation; defuse-on-leave is the documented alternative if the Director wants it gentler.

### Q3 — Proximity radius vs blast radius: should they differ, and which is bigger?

The work-order says "explodes in a radius if too close" and "kills you if you are inside" — these can be the
**same** radius or **two** (proximity arms; blast kills).
- **Same radius:** simplest; but then arming and being-killable coincide, leaving no escape window — crossing
  in = guaranteed death after 2 s unless you sprint out of the *same* ring you just entered. Harsh.
- **Proximity > blast (telegraph-generous — recommended):** the visible idle ring (proximity) is *larger*
  than the lethal blast, so the player gets armed with **room to retreat to safety inside the still-visible
  ring**. The ~2 s pulse is a real, winnable escape window. This is the intended "telegraph generosity" the
  task brief names.
- **Blast > proximity:** counter-intuitive (you can be killed without having armed it yourself if a *second*
  player/source armed it) — not applicable to a single-player bomb; avoid.

**Recommendation:** **two radii, proximity ≥ blast**, with the idle ring drawn at the proximity radius so the
telegraph is honest, and an inner (optionally drawn) blast radius. Defaults stay 0 (all-off). The *values*
(e.g. proximity ~64 px, blast ~40 px) are the Director's to sweep — **flag the ratio as a feel call** with
"proximity strictly ≥ blast" as the design invariant. Note radii are to the **player centre** (radius-14
body), so effective lethality reaches `blast_radius + 0` at centre — the generosity is in the gap, not the
body size.

### Q4 — Re-armable (persist after fizzle) vs one-shot (free itself)?

After a **fizzle** (detonated with the player outside the blast), does the bomb **re-arm** (reset to IDLE,
usable again) or **one-shot free itself**?
- **One-shot (recommended):** the bomb is "spent" after it blows — `queue_free` after the flash. Clean, no
  lingering ring clutter, and a room you've "cleared" stays cleared (a small spatial-mastery reward). Matches
  the throwaway-greybox ethos. Simplest state machine (EXPLODED is terminal).
- **Re-armable:** the bomb resets to IDLE after the explode flash, becoming a permanent area-denial fixture
  you must keep avoiding. More persistent threat, but risks a "stuck pulsing forever" feel if the player
  loiters at the ring edge, and needs a re-arm cooldown to avoid instant re-detonation.

**Recommendation:** **one-shot free** (the pseudocode frees after the explode flash). It is the simplest,
cleanest greybox behaviour and avoids re-arm-flicker edge cases. A re-armable variant is a one-line change
(reset `_state=IDLE`, `_pulse_t=0`, re-seat the ring) if a later sweep wants persistent denial — note it as a
future knob (`h_bomb_rearm: bool`) rather than building it now. *Fresh-eyes/Director — leans design, low risk.*

### Q5 — Placement determinism: stride vs local seeded sub-stream?

"Spawns randomly around the room" — but the M1.4 contract is that hazard placement is **pure run-state, never
feeds `fingerprint()`** and is **deterministic** (Breakdown §6; the R1/J3 precedent). Two options:
- **Deterministic stride (R1/J3 precedent — recommended):** reuse `_density_spawn_positions`' exact idiom —
  stride the room's `n` bombs across its sorted floor cells (`main_game.gd:391-396`). NO RNG at all; "random
  around the room" is *visual* spread, not statistical randomness. Byte-identical run-to-run for a seed+config;
  trivially testable (a `test_bomb_placement.gd` against a hand-built band, like `test_per_room_density.gd`).
- **Local seeded sub-stream (`run_seed ^ salt`):** genuine per-cell randomness via a private `RandomNumberGenerator`
  seeded off the run seed (the B3/E3 pattern). More "scattered" visually, still reproducible, never touches the
  global RNG. But adds a sub-stream + salt to manage and complicates the determinism test.

**Recommendation:** **deterministic stride**, identical to J3 — it satisfies "around the room" (the bombs land
spread across the room's cells), keeps the test-harness trivial, and matches the existing density seam K5i
already owns. If the Director specifically wants *non-uniform scatter*, escalate to a local seeded sub-stream
(NOT the global RNG) as a contained follow-up. *Fresh-eyes to confirm; the "never global RNG / never feeds
fingerprint" constraint is non-negotiable per the Breakdown.*

### Q6 — Does a bomb wake/pulse depend on R1's depth/linger awaken rules, or purely on proximity?

R1 hazards awaken by depth-threshold OR linger time (`hazard_entity.gd:163-170`). The bomb's arming is
**purely proximity-driven** (it is always "live" the moment it exists). Should depth/linger also gate it?

**Recommendation:** **purely proximity** — the bomb is a static spatial hazard, not a time/depth-escalating
pursuer; gating its *arming* on depth would make shallow bombs inert decoration. "More the deeper you go" is
already expressed via the **count** (`h_bomb_count_per_depth`), not the arming rule. Keep arming proximity-only.
*Low-risk technical call; fresh-eyes to confirm.*

---

## 5. Definition of done (for the build task that consumes this)

- `scenes/hazards/bomb_hazard.gd` + `.tscn` exist; the IDLE→PULSING→EXPLODE machine matches §2.2; lethality is
  a script distance test; fatal routes through `GameState.fail_run(&"death")`; no edits to `event_bus.gd` or
  `run_config.gd` (K0 owns those) or `main_game.gd`'s spawn seam (K5i owns that).
- With `h_bomb_enabled=false` nothing instantiates → all-off fp stays `e943ac9c8bc1` (no node, no behaviour).
- Placement plan is deterministic + RNG-free (or a local seeded sub-stream per the Q5 verdict) — a unit test
  (`tests/test_bomb_placement.gd`, mirroring `test_per_room_density.gd`) proves byte-identical positions for a
  fixed band+config, and the depth-scaled count formula matches §2.1.
- `bomb_armed` / `bomb_detonated` fire once each per their edge; `godot --headless --import` parses clean and
  the smoke test stays green.
- Worklog records the commit SHA + any deviation; the K5i integration task wires the spawn loop.

---

*Phase 3 (fresh eyes) resolves Q1–Q6 into a `Resolved Decisions` section, ratifying technical/design calls and
flagging Q2 (committed-vs-defuse) and Q3 (radius ratio/values) to the Director as feel calls per the recommendations above.*

---

## Resolved Decisions (Phase 3)

> Fresh-eyes resolution, 2026-06-21, resolving the four K5 hazard docs (K5a/K5b/K5c/K5i) + K0 as ONE coherent family.
> **K0 is NOT yet landed** (verified: no `hbomb_*`/`h_bomb_*` knobs in `run_config.gd`, no bomb signals in
> `event_bus.gd`), so the naming/signal contract here is still soft and **K0 must adopt these names before it is
> dispatched.** K5b had the most divergence from its siblings — two corrections below are load-bearing for mergeability.

### CROSS-CUTTING #1 — config prefix: `h_bomb_` → `hbomb_` (CORRECTION, load-bearing)

**This doc's entire `h_bomb_*` knob group is RE-PREFIXED to `hbomb_`.** Audit: the as-built `run_config.gd` groups are
contiguous prefixes with NO underscore after the leading token (`r1_`, `r2_`, `lvl_` — `run_config.gd:57/121/192`), and
both siblings (K5a `hpp_`, K5c `hspike_`) + K0 §B.1 + K5i's descriptor table all use the contiguous form. K5b's
`h_bomb_enabled` is the lone outlier; the extra underscore breaks the house style and the CFG section-prefix scheme.
Every `h_bomb_*` field, `@export_group("H_Bomb Hazard", "h_bomb_")`, `to_flat_dict()` key, and pseudocode reference in
this doc maps as:

| this doc (REJECTED) | LOCKED |
|---|---|
| `h_bomb_enabled` | `hbomb_enabled` |
| `h_bomb_base_count` | `hbomb_base_count` |
| `h_bomb_count_per_depth` | `hbomb_count_per_depth` |
| `h_bomb_proximity_radius` | `hbomb_trigger_radius` *(see note)* |
| `h_bomb_pulse_seconds` | `hbomb_fuse_s` *(see note)* |
| `h_bomb_blast_radius` | `hbomb_blast_radius` |
| `h_bomb_per_room_cap` | `hbomb_per_room_cap` |
| `@export_group("H_Bomb Hazard", "h_bomb_")` | `@export_group("K5b Bomb Hazard", "hbomb_")` |

**Note on two field names:** K0 §B.1 declared the bomb's proximity field as **`hbomb_trigger_radius`** and the fuse as
**`hbomb_fuse_s`**, while K5b's design named them `h_bomb_proximity_radius` / `h_bomb_pulse_seconds`. The K0 names win
(K0 is the single writer and K5i's descriptor table already lists `hbomb_trigger_radius`, `hbomb_blast_radius`,
`hbomb_fuse_s`). So: proximity/arming radius = **`hbomb_trigger_radius`**, fuse/pulse duration = **`hbomb_fuse_s`**, lethal
radius = **`hbomb_blast_radius`**. K5b's semantics (Q3's "proximity ≥ blast") are unchanged — only the field names align to
K0. **K0 must declare exactly:** `hbomb_enabled`, `hbomb_base_count`, `hbomb_count_per_depth`, `hbomb_trigger_radius`,
`hbomb_fuse_s`, `hbomb_blast_radius`, `hbomb_per_room_cap` (7 knobs).

### CROSS-CUTTING #2 — signals: align with K0, drop the bespoke `bomb_armed`/`bomb_detonated`

K5b invented `bomb_armed(depth)` + `bomb_detonated(depth, hit)`. But K0 §B.3 pre-declared the family telemetry as
**`new_hazard_killed(kind, depth, run_t_ms)`** (the shared kill row, used by K5a/K5c) plus a bomb-specific
**`bomb_pulse_started(depth, run_t_ms)`**. To keep K5b coherent with its siblings and with K0 (the single writer on
`event_bus.gd`):

**LOCKED signal usage for the bomb:**
- **Arming** (IDLE→PULSING) emits **`EventBus.bomb_pulse_started(depth, run_t_ms)`** — the K0 name, replacing
  `bomb_armed(depth)`. (Note K0's payload is `(depth, run_t_ms)` — the bomb self-times `run_t_ms` from spawn like R1
  `hazard_entity.gd:185-187`, NOT just `depth`.)
- **A fatal detonation** (player inside blast at the detonation frame) emits **`EventBus.new_hazard_killed(&"bomb",
  depth, run_t_ms)`** — the shared kill row, so RG2 segments all three hazards on ONE signal. This *replaces* the kill
  half of `bomb_detonated(depth, hit)`.
- **A fizzle** (detonated, player outside blast) emits **no kill row** (no death). If RG2 needs a "bombs detonated vs
  bombs that killed" ratio, that is derivable from `bomb_pulse_started` count vs `new_hazard_killed(&"bomb")` count — so
  **no separate `bomb_detonated` signal is needed.** If the Director later wants explicit fizzle telemetry, add
  `bomb_fizzled(depth)` to K0 then — not now (keeps the signal set minimal, matches "additive-only" Breakdown §2).

So K5b emits exactly **`bomb_pulse_started`** (on arm) and **`new_hazard_killed(&"bomb", …)`** (on fatal detonation).
The §2.2 pseudocode's `EventBus.bomb_armed.emit(...)` → `bomb_pulse_started.emit(depth, run_t_ms)`; its
`EventBus.bomb_detonated.emit(depth, hit)` → on `hit==true` only, `new_hazard_killed.emit(&"bomb", depth, run_t_ms)`.
**K0 must declare `bomb_pulse_started(depth, run_t_ms)` + `new_hazard_killed(kind, depth, run_t_ms)`; it must NOT declare
`bomb_armed` / `bomb_detonated`.**

### CROSS-CUTTING #3 — shared `setup()` contract

**LOCKED family signature: `setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void`** (see K5a's
Resolved Decisions for the full rationale — heterogeneous per-type needs, ONE call site in K5i). **The bomb ignores
`spawn_ctx`** — it needs only a world position (its blast is radial and confined by radius, not by room walls; see Q-new
below). So K5b's `setup(cfg, player)` simply gains the ignored optional third param: `setup(cfg, player, _spawn_ctx :=
{})`. No behaviour change. This keeps K5i's loop type-agnostic.

### Per-doc resolutions (Q1–Q6)

- **Q1 (base class) — RESOLVED: plain `Node2D`, with the `hazard` group tag** (no collision shape, no mask). The bomb is
  stationary and distance-test-only; `CharacterBody2D` implies movement it never has, and `Area2D`'s `body_entered` is the
  physics-order-dependent path the family deliberately avoids (`hazard_entity.gd:24-25`). This **aligns the bomb with K5c's
  `Node2D` resolution (K5c OQ-6)** — both stationary hazards are `Node2D`; only K5a (which moves + bounces off walls) keeps
  `CharacterBody2D`. The §2.2 pseudocode header `extends Area2D` → **`extends Node2D`**. Technical merit — no Director call.

- **Q2 (defuse-on-leave vs committed) — `**NEEDS DIRECTOR REVIEW**` (feel call).** Recommendation: **committed once-armed**
  (the pseudocode's assumption) — it reads as the work-order intends ("pulses ~2s then explodes"), and the escape is
  running clear of the smaller blast radius (Q3's telegraph generosity). Defuse-on-leave is the documented gentler
  alternative. Flagged to the Director with "committed" recommended; the build proceeds on committed unless overridden.

- **Q3 (proximity vs blast radii) — RESOLVED (invariant) + `**NEEDS DIRECTOR REVIEW**` (values).** Lock the design
  **invariant: two radii, `hbomb_trigger_radius` ≥ `hbomb_blast_radius`** (proximity arms; the smaller blast kills),
  drawing the idle ring at the trigger radius so the telegraph is honest and the ~2s fuse is a winnable escape window.
  Both default 0 (all-off). The **exact magnitudes** (e.g. trigger ~64px, blast ~40px) are a Director sweep — flagged.
  Radii measure to the player *centre* (radius-14 body). Technical invariant resolved; magnitudes flagged.

- **Q4 (re-armable vs one-shot) — RESOLVED: one-shot, `queue_free` after the explode flash.** Cleanest greybox
  behaviour, no lingering-ring clutter, a cleared room stays cleared (a small spatial-mastery reward), simplest terminal
  state machine. A re-armable variant is a future `hbomb_rearm: bool` knob if a later sweep wants persistent denial — not
  now (keeps the K0 `hbomb_*` set pinned at 7). Low-risk design call — no Director escalation needed.

- **Q5 (placement determinism) — RESOLVED: deterministic stride, RNG-free.** "Spawns randomly around the room" =
  *visual* spread via striding the room's sorted floor cells (the J3/`_density_spawn_positions` idiom), NOT statistical
  randomness. This is **K5i's to own** (K5i OQ-4, resolved pure-deterministic there) — K5b's count formula §2.1 agrees
  with K5i's `_per_room_positions`. Byte-identical run-to-run; never feeds `fingerprint()`. If the Director judges the
  striped placement too regular at playtest, promote to a local `run_seed ^ salt` sub-stream (never global RNG) as a
  contained follow-up. Non-negotiable: never global RNG, never feeds fingerprint. Technical merit — resolved.

- **Q6 (arming gated by depth/linger vs proximity-only) — RESOLVED: purely proximity.** The bomb is a static spatial
  hazard, not a time/depth-escalating pursuer; gating its arming on depth would make shallow bombs inert decoration.
  "More the deeper you go" is expressed via the **count** (`hbomb_count_per_depth`), not the arming rule. Technical merit
  — resolved.

### New edge case surfaced in resolution (Q-new) — blast confinement to the room

K5i OQ-6 asks whether the bomb needs its room's bounds "to keep its blast inside the room." **Resolved: NO — the bomb
ignores room bounds.** The blast is a radial distance test to the player centre; it cannot "leak" into another room
because it only ever tests the single player's position against `hbomb_blast_radius`. A player standing in an adjacent
room is simply >`blast_radius` away and unharmed. So the bomb needs ONLY a world position from K5i (empty `spawn_ctx`),
confirming the Q1 `Node2D`/no-collision and the §6/K5i contract. No widening needed for the bomb.
