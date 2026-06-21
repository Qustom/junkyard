# K5a — Ping-pong hazard (Phase-2 design)

**Milestone:** M1.4 · **Wave:** 3 (danger variety) · **Role(s):** general-purpose + character-animator (tell)
**BlockedBy:** K0 (reads its `hpp_*` knobs + emits the K0-declared `new_hazard_killed` signal).
**Status:** Phase 2 (per-task design). Open Questions below feed Phase 3 (fresh-eyes resolution).

> **Scope boundary with K5i.** This doc designs the **entity** (`PingPongHazard` scene + script) and its **config
> contract** only. The **spawn wiring** — how many spawn, where, and per-room caps fed from the `hpp_*` knobs — is
> **K5i**'s job (single-writer on `main_game.gd`'s `_spawn_*` seam). §6 states the exact seam contract K5i implements so
> the two tasks are file-disjoint and mergeable. K0 has **already pre-declared** the `hpp_*` knob group + the
> `new_hazard_killed` / no new signal needed here — this doc only references them.

---

## 0. Intent (one sentence)

A greybox **bouncer** confined to its room: it travels in a straight line at a fixed speed, **bounces off walls**
(reflecting its velocity on the wall normal), is **lethal the instant it touches the player** (a deterministic script
distance test routed through `GameState.fail_run(&"death")`, exactly like `HazardEntity`), and **more of them spawn the
deeper you go** — all gated by an all-off `hpp_*` config so an unconfigured run is byte-for-byte M1.0.

---

## 1. Research (the premise + the in-repo prior art)

### 1.1 Director work-order, restated as requirements

> "Ping pong in a single room. This hazard will kill you if it touches you. Spawn more the deeper you go. Will stay in a
> room. Will collide with the wall, bounce off, and continue to do so."

Four hard requirements: (a) **bounces** off walls indefinitely; (b) **lethal on contact**; (c) **depth-scaled count**;
(d) **confined to one room** ("stay in a room"). This is a NEW greybox hazard entity, modeled on the existing pursuer.

### 1.2 The prior-art entity — `HazardEntity` (R1, M1.1)

`scenes/hazards/hazard_entity.gd` is the throwaway-greybox hazard pattern K5a mirrors. The load-bearing structure:

- **`CharacterBody2D`** root (`hazard_entity.gd:2`), greybox `Polygon2D` `Tell` child for color
  (`hazard_entity.gd:77`, `hazard_entity.tscn:13-15`), `CircleShape2D` body radius **10.0** (`hazard_entity.tscn:5-6`).
- **Collision: layer `hazard` (5) → bit 16, mask `world` (2) → bit 2 ONLY** (`hazard_entity.tscn:9-10`, doc-string
  `hazard_entity.gd:23-25`). Walls (the `world` layer) **stop** the body via `move_and_slide()`; it does **not** mask
  `player` (so the catch is a **script distance test**, deterministic — not a physics overlap) and does **not** mask
  `hazard` (hazards never block each other). **K5a inherits this layer/mask exactly** — it is what makes walls bounce it
  while the kill stays a deterministic distance test.
- **`setup(cfg: RunConfig, player: Node2D)`** (`hazard_entity.gd:83-91`) snapshots the run config + resolves the player
  so the entity never re-reads `GameState.active_run_config` mid-frame (survives the run-end config clear). K5a copies
  this signature verbatim so K5i's spawn loop calls it identically (`main_game.gd:323`, `:349`).
- **`_physics_process(delta)`** (`hazard_entity.gd:94-158`): drives `velocity` then `move_and_slide()`, then runs a
  **distance-based catch test** (`global_position.distance_to(_player.global_position) <= catch_r`,
  `hazard_entity.gd:146-147`) and on a fatal catch calls **`GameState.fail_run(&"death")`** (`hazard_entity.gd:189-191`).
  K5a reuses the distance-test-then-`fail_run` shape but with a **fixed contact radius** (no awaken state, no chase).
- **Idempotent death:** `GameState.fail_run()` is guarded by `_run_ended` (`game_state.gd:323-326`) — the **single
  source of truth** for run-end idempotency across all hazards + extract. K5a never adds a local "already ended" guard
  that *prevents* the call (`hazard_entity.gd:182-191` idempotency note). It MAY keep a one-shot **local** latch purely
  to stop a per-frame **telemetry** emit storm (the BUG6 pattern, `hazard_entity.gd:69-75`, `:154-158`).
- **Tell colors** (`hazard_entity.gd:32-33`): R1 dormant = `Color(0.35, 0.4, 0.5)` (grey-blue), awake =
  `Color(0.9, 0.2, 0.2)` (alarm red). K5a needs a **distinct** tell color (see §3) so the three M1.4 hazards read apart.
- **All-off contract** (`hazard_entity.gd:20-21`): with the master toggle off the spawn seam never instantiates the
  node, so the M1.0 baseline is byte-for-byte unchanged. K5a's `hpp_enabled=false` default does the same.

### 1.3 The spawn seam K5a plugs into (K5i owns the edits)

`scenes/game/main_game.gd` already has a fully-built per-depth + per-room hazard spawn seam K5a/K5i reuse:

- **`_spawn_r1_hazards(rc, band)`** (`main_game.gd:296-328`) is the per-dive entry; it instantiates a scene, resolves
  the player via `get_tree().get_first_node_in_group(&"player")` (`main_game.gd:310`), sets `global_position`, calls
  `setup(rc, player)`. K5i adds a parallel `_spawn_hpp_hazards(rc, band)` of the same shape.
- **`_hazard_spawn_position(band, depth, index)`** (`main_game.gd:502-515`) → a floor-cell world position at a target
  depth; the within-depth `index % cells.size()` wrap spreads multiple hazards. K5i can reuse it for placement.
- **`_band_max_depth(band)`** (`main_game.gd:490-491`) → `band.max_depth` (set by `DepthGrader.grade()`), the single
  source of truth for the deepest graded depth — the input to the "more with depth" formula.
- **`_band_cell_size_px`** (`main_game.gd:81`, set by `_materialise_band`) → effective px/cell, the cell↔world scale.
- Placement is pure **run-state** (no RNG; never feeds `band.fingerprint()`) — the J2/J3 contract (`main_game.gd:316`,
  `:359` doc-strings). K5a's spawn placement inherits this: it is run-state, the all-off control's fingerprint
  (`e943ac9c8bc1`) never moves.

### 1.4 Room geometry + the seal (the "confinement" substrate)

- **`PlacedPiece`** (`systems/bandgen/placed_piece.gd`) carries **`floor_cells: Array[Vector2i]`** in band-global cell
  coords (`:32`) and **`offset_cell`** (`:21`). A piece's floor-cell **bounding box** in cell space → world px (via
  `_band_cell_size_px`) gives a room's pixel bounds — the input to a clamp-style confinement.
- **`SocketSealer.seal_unused_sockets()`** (`systems/bandgen/socket_sealer.gd:57`) caps **every** unmated band edge with
  a **WALL collision tile on the `world` layer** after materialisation (`main_game.gd:565`). So the **band perimeter is
  fully sealed** — a `world`-masking body physically cannot leave the band. **BUT rooms connect to each other through
  walkable doorways** (the connectivity guarantee, `placed_piece.gd:28-32`): pure wall-collision confines a bouncer to
  the **band**, not necessarily to a **single room** — it could bounce out a doorway into the next piece. This is the
  crux of **OQ-1 (room confinement)**.

### 1.5 Collision-layer / player facts (for the kill + bounce math)

- Layers (`project.godot:102-107`): `player`=1, `world`=2, `interactable`=3, `enemy`=4, `hazard`=5, `pawn`=6.
- Player body: `CircleShape2D` **radius 14.0**, `collision_layer=1` (player) (`player.tscn:8,:11`). The R1 catch-radius
  floor is `player_r 14 + hazard_r 10 = 24 px` (`run_config.gd:69-71`) — **the same floor applies to K5a's contact
  radius**: below it the bodies (if K5a masked the player, which it does NOT) would touch before the distance test trips.
  Since K5a uses a distance test (not a physics overlap), the contact radius is a tunable, but it should sit at/above
  the visual body sum so "touch" reads honestly. See §3.
- `GameState.fail_run(&"death")` (`game_state.gd:323`) is the existing fatal end-path; `&"death"` is the death cause
  (`game_state.gd:308`). K5a uses it unchanged — **no new `reason`** (the kill is a death, same as R1).

---

## 2. Pseudocode (against the real as-built APIs)

### 2.1 The config group (K0 ALREADY declared this — shown for reference, NOT re-authored here)

K0 pre-declared the exact group below at `run_config.gd` (K0 doc §B.1, prefix **`hpp_`**) and added all five keys to
`to_flat_dict()` (K0 doc §B.2). **K5a does not edit `run_config.gd`** — K0 is the single writer this milestone. The
group, for grounding:

```gdscript
# =============================================================================
# K5a (M1.4) — Ping-pong hazard (bounces off room walls, lethal on contact)
# =============================================================================
@export_group("K5a Ping-Pong Hazard", "hpp_")
@export var hpp_enabled: bool = false           # master toggle; OFF = no node spawned (M1.0 baseline)
@export var hpp_base_count: int = 0             # bouncers at depth 0 (per-room budget — K5i applies)
@export var hpp_count_per_depth: float = 0.0    # additive count scaling per within-band depth
@export var hpp_speed: float = 0.0              # constant travel speed (px/s, greybox units)
@export var hpp_per_room_cap: int = 0           # 0 = uncapped (preset MUST set > 0 — perf guard)
```

All-off default (every value 0/false) = no bouncer spawned = byte-for-byte M1.0. The preset
(`make_default_play_preset()`) is where non-zero sweep values ship — **never** the code-level defaults (the carried
M1.1/M1.3 contract, Breakdown §2). K5a's recommended preset seed values (Director sweeps the actual numbers) live in §5.

### 2.2 The entity script — `scenes/hazards/pingpong_hazard.gd`

The new entity. Mirrors `HazardEntity`'s shape: `CharacterBody2D`, a `setup(cfg, player)` config snapshot, a `Tell`
`Polygon2D`, `move_and_slide()`, distance-test kill → `fail_run(&"death")`. The differences: **no DORMANT/AWAKE state**
(it is live from spawn), **constant velocity** (no chase lerp), and a **bounce** step that reflects velocity off the wall
normal each frame.

```gdscript
class_name PingPongHazard
extends CharacterBody2D
## PingPongHazard (K5a, M1.4) — a throwaway greybox "bouncer": a colored shape that
## travels in a straight line at a constant speed, bounces off walls, and ends the run
## if it touches the player. No state machine, no chase, no awaken — it is live from
## spawn. Confined to its room (see OQ-1 for the chosen mechanism). Mirrors HazardEntity's
## structure (CharacterBody2D, setup() snapshot, Tell polygon, distance-test kill).
##
## Collision: body on layer `hazard` (5), masks `world` (2) ONLY — identical to
## HazardEntity. Walls (the `world` layer) bounce it; it does NOT mask `player`
## (the kill is a script distance test, deterministic) nor `hazard` (bouncers never
## block each other — they pass through, no inter-hazard pinball).
##
## ALL-OFF: with hpp_enabled = false the spawn seam (K5i) never instantiates this node,
## so the M1.0 baseline is byte-for-byte unchanged.

## Greybox tell color — DISTINCT from R1 (grey-blue/red) and the other M1.4 hazards.
## Recommended: a hot ORANGE-YELLOW "live projectile" read (see §3 / OQ — character-animator).
const COLOR_LIVE := Color(0.95, 0.65, 0.15)     # amber — "a thing in motion that will hurt you"

## Contact radius (px): distance at/under which touching the player kills. Self-contained
## greybox constant (NOT a RunConfig knob — keeps the CFG knob count pinned, like
## HazardEntity's NONFATAL_* constants, hazard_entity.gd:39-41). Floored at the visual body
## sum so "touch" reads honestly: player_r 14 + hazard_r 10 = 24 (run_config.gd:69-71).
const CONTACT_RADIUS := 24.0

var _cfg: RunConfig                 # snapshot of GameState.active_run_config at setup
var _player: Node2D                 # resolved at setup via the "player" group
var _speed: float = 0.0             # snapshot of hpp_speed (px/s)
var _killed_latched: bool = false   # one-shot telemetry latch (BUG6 pattern) — NOT a fail_run guard
var _spawn_time: float = 0.0        # self-timed run clock for the telemetry run_t_ms (R1 §4 pattern)

# OQ-1 (confinement = clamp option only): the room's world-space bounds, set by setup().
# Zero rect == "no clamp" (pure wall-bounce confinement). See OQ-1.
var _room_bounds: Rect2 = Rect2()

@onready var _tell: Polygon2D = $Tell


## Bind config + player + the initial heading. Called by K5i's spawn seam right after
## add_child (mirrors HazardEntity.setup, hazard_entity.gd:83). `initial_dir` is supplied
## by the spawn seam so direction policy (fixed vs seeded) lives in ONE place (OQ-4).
## `room_bounds` is the optional clamp rect (OQ-1); pass Rect2() to disable the clamp.
func setup(cfg: RunConfig, player: Node2D, initial_dir: Vector2, room_bounds: Rect2 = Rect2()) -> void:
	_cfg = cfg
	_player = player
	_speed = maxf(cfg.hpp_speed, 0.0)
	_room_bounds = room_bounds
	_killed_latched = false
	_spawn_time = 0.0
	var d := initial_dir.normalized() if initial_dir.length() > 0.001 else Vector2.RIGHT
	velocity = d * _speed
	if _tell != null:
		_tell.color = COLOR_LIVE


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return
	_spawn_time += delta

	# --- Travel + bounce ----------------------------------------------------
	# Constant-speed straight-line travel; move_and_slide() stops the body on a wall
	# (layer `world`) and reports the contact. We then REFLECT velocity off the wall
	# normal so the next frame travels the mirrored heading — the "ping-pong". Speed is
	# re-normalised after the bounce so glancing hits don't bleed speed (OQ-2 recommends
	# this explicit reflect over relying on slide's residual velocity).
	move_and_slide()
	if get_slide_collision_count() > 0:
		var col := get_last_slide_collision()
		if col != null:
			var n: Vector2 = col.get_normal()
			# Reflect only if heading INTO the wall (dot < 0), so we never double-flip
			# on a frame where we're already moving away (prevents jitter in corners).
			if velocity.dot(n) < 0.0:
				velocity = velocity.bounce(n).normalized() * _speed

	# --- OQ-1 (clamp option): hard-confine to the room rect as a belt-and-braces.
	# If a non-empty room_bounds was supplied, reflect at the rect edges too, so a
	# bouncer can never leak through a doorway into the next room even if wall-bounce
	# alone would let it. No-op when _room_bounds is the empty Rect2 (pure-wall mode).
	if _room_bounds.has_area():
		_confine_to_room()

	# --- Lethal contact test (deterministic distance test, like HazardEntity) ----
	# CONTACT_RADIUS is fixed; touching the player kills outright. One-shot telemetry
	# latch (BUG6 pattern, hazard_entity.gd:154-158): emit new_hazard_killed exactly
	# once on the rising edge, but ALWAYS let fail_run run (its _run_ended guard owns
	# run-end idempotency — game_state.gd:323-326 — we never gate the call itself).
	var in_contact: bool = global_position.distance_to(_player.global_position) <= CONTACT_RADIUS
	if in_contact and not _killed_latched:
		_killed_latched = true
		_on_contact()
	elif not in_contact:
		_killed_latched = false


## A lethal touch lands. Emit the K0-declared telemetry row, then route the death through
## the EXISTING fatal path (no new reason, no local "already ended" bool that PREVENTS it).
func _on_contact() -> void:
	var run_t_ms: int = int(_spawn_time * 1000.0)
	var depth: int = GameState.current_depth_index   # live within-band depth (BUG2)
	EventBus.new_hazard_killed.emit(&"pingpong", depth, run_t_ms)
	GameState.fail_run(&"death")   # existing end path; its _run_ended guard de-dupes.


## OQ-1 clamp belt-and-braces: if the body crossed a room-rect edge this frame, snap it
## back inside and reflect the perpendicular velocity component. Pure run-state math, no
## physics — independent of (and complementary to) the wall-bounce above.
func _confine_to_room() -> void:
	var p := global_position
	if p.x < _room_bounds.position.x or p.x > _room_bounds.end.x:
		velocity.x = -velocity.x
		p.x = clampf(p.x, _room_bounds.position.x, _room_bounds.end.x)
	if p.y < _room_bounds.position.y or p.y > _room_bounds.end.y:
		velocity.y = -velocity.y
		p.y = clampf(p.y, _room_bounds.position.y, _room_bounds.end.y)
	global_position = p
```

### 2.3 The scene — `scenes/hazards/pingpong_hazard.tscn`

Clone `hazard_entity.tscn` (`hazard_entity.tscn:1-19`): `CharacterBody2D` in group `["hazard"]`, `collision_layer=16`
(`hazard`/bit 5), `collision_mask=2` (`world`/bit 2), a `CircleShape2D` body (radius **10.0**, matching R1 so the
24-px contact floor holds), and a `Tell` `Polygon2D`. The only authoring differences:

- **Tell shape:** a distinct silhouette so it doesn't read as the R1 diamond — recommend a small **square/box**
  (`PackedVector2Array(-10,-10, 10,-10, 10,10, -10,10)`) tinted `COLOR_LIVE` amber. Final shape is the
  character-animator's call (§3 / OQ-tell).
- **Script:** `res://scenes/hazards/pingpong_hazard.gd`.

### 2.4 The depth-scaled count (the formula K5i applies — stated here, applied there)

"More the deeper you go" maps to a per-depth count, parallel to R1's `r1_speed_per_depth` additive scaling
(`hazard_entity.gd:115`) and J3's `floor(...)` budget math (`main_game.gd:381`). Recommended:

```
n_at_depth(d) = clampi( floor(hpp_base_count + hpp_count_per_depth * d), 0, hpp_per_room_cap_or_inf )
```

where `d` is the within-band depth of the room being populated (`PlacedPiece.depth_index`) and the cap applies when
`hpp_per_room_cap > 0`. With `hpp_base_count=0 AND hpp_count_per_depth=0` → `n=0` → no node → all-off byte-match. K5i
decides per-room-vs-per-band application (OQ-3) and owns this loop on the spawn seam.

---

## 3. Greybox tell (character-animator inline contribution)

The three M1.4 hazards must read **apart at a glance** and **apart from R1**. R1 owns grey-blue (dormant) / alarm-red
(hunting) (`hazard_entity.gd:32-33`). Recommended K5a palette + silhouette (Director/character-animator final):

- **Color `COLOR_LIVE = Color(0.95, 0.65, 0.15)`** — **amber/orange**, a "live projectile in motion" read. Distinct
  from R1 red (which means "the thing hunting *you*") and from the bomb's expected pulse-red and the spike's expected
  steel/grey. Amber says "moving, will hit you, but not aimed."
- **Silhouette:** a small **box/square** (vs R1's diamond, vs the bomb's circle, vs the spikes' star/cross) so shape
  alone disambiguates on a busy screen.
- **Motion is the tell.** Unlike R1 (which telegraphs via a dormant→awake color flip), a ping-pong's danger is read
  from its **constant straight-line travel + visible bounce** — the player learns the angle and dodges. No awaken
  flash needed; the entity is "on" from spawn. A subtle optional juice (character-animator's call, scope-safe): a tiny
  squash-on-bounce `Tween` (scale 1.15 along the impact axis for ~0.06 s) so each bounce reads as an impact — pure
  juice, the color+motion already carry the state if the tree is paused/headless.

---

## 4. Determinism & the run/meta boundary

- **Placement is pure run-state** — never feeds `band.fingerprint()` (the J2/J3 contract, `main_game.gd:316/:359`).
  The all-off control's fingerprint `e943ac9c8bc1` is untouched because `hpp_enabled=false` spawns nothing.
- **Initial direction** is the one determinism subtlety (OQ-4): if it is **fixed** (e.g. always a 45° down-right or a
  per-index rotation), it adds **no** RNG and is trivially reproducible. If it is **seeded-random**, it MUST draw from a
  **local sub-stream** (`run_seed ^ salt`, the B3/E3 pattern named in Breakdown §6), **never** the global `RNG`
  mid-generation — and since placement is run-state (post-generation), even a sub-stream draw cannot move the
  fingerprint. Recommendation in OQ-4: **fixed per-index direction** (cheapest, fully deterministic, no sub-stream).
- **No save-schema impact.** K5a touches no meta-state — bouncers are run-state entities torn down with the band in
  `_clear_band()` (`main_game.gd:759-763`). Only K2 (quota) bumps the save schema this milestone (Breakdown §2).
- **`run_ended` arity locked.** The kill ends the run through `fail_run(&"death")` — the existing path, existing
  `&"death"` reason. No new reason, no arity change.

---

## 5. Recommended preset seed values (Director sweeps — NOT final)

For `make_default_play_preset()` once K5a is built (the Director tunes these in RG1; the code-level all-off defaults
stay 0/false). A conservative "one bouncer in the early rooms, a second appearing as you go deep" start:

```gdscript
c.hpp_enabled = true
c.hpp_base_count = 1          # ~1 bouncer in a shallow room
c.hpp_count_per_depth = 0.4   # +1 roughly every ~2-3 depth bands
c.hpp_speed = 90.0            # px/s — fast enough to threaten, slow enough to dodge/learn
c.hpp_per_room_cap = 2        # MANDATORY > 0 (perf guard, mirrors r1_density_per_room_cap, run_config.gd:465)
```

Rationale: `hpp_speed` sits above the player's effective speed range so a bouncer *can* catch a stationary player but a
moving player can dodge the telegraphed line; `per_room_cap=2` bounds a worst-case big-room population. These are
sweep **starts**, explicitly the Director's to tune at the re-gate.

---

## 6. The K5i seam contract (what K5i implements; K5a only declares it)

So the two tasks merge cleanly (K5a = entity files; K5i = `main_game.gd` spawn seam, single-writer):

1. **Scene constant:** K5i adds `const PINGPONG_SCENE_PATH := "res://scenes/hazards/pingpong_hazard.tscn"` alongside
   `HAZARD_SCENE_PATH` (`main_game.gd:115`).
2. **Spawn helper:** K5i adds `_spawn_hpp_hazards(rc, band)`, gated `if not rc.hpp_enabled: return`, mirroring
   `_spawn_r1_hazards` (`main_game.gd:296`). It instantiates `PingPongHazard`, `add_child` into `_band_container`, sets
   `global_position` from a floor cell (reusing `_hazard_spawn_position` or a per-room equivalent), and calls
   **`hz.setup(rc, player, initial_dir, room_bounds)`** — supplying `initial_dir` (per OQ-4 policy) and `room_bounds`
   (per OQ-1 policy, `Rect2()` if pure-wall confinement is chosen).
3. **Count:** K5i applies `n_at_depth(d)` from §2.4 per room (capped by `hpp_per_room_cap`), reading
   `PlacedPiece.depth_index` and `band.max_depth` (`_band_max_depth`, `main_game.gd:490`).
4. **Call site:** K5i calls `_spawn_hpp_hazards(run_cfg, band)` in `start_new_run()` next to `_spawn_r1_hazards`
   (`main_game.gd:282`).
5. **The entity provides:** the scene, the script, `setup(cfg, player, initial_dir, room_bounds)`, and the
   `new_hazard_killed.emit(&"pingpong", ...)` telemetry. K5i provides: how many, where, with what direction/bounds.

**Contract for OQ-1/OQ-4:** whichever way Phase 3 resolves room-confinement and initial-direction, the **resolution
lives in K5i's spawn call** (what it passes for `room_bounds` / `initial_dir`) — the entity supports both modes via its
`setup` args, so the Phase-3 verdict does not force an entity-script rewrite. This is deliberate decoupling.

---

## 7. Edge cases & test hooks (for QA / Phase 3)

- **Player null / freed mid-frame:** `_physics_process` guards `_player == null or not is_instance_valid(_player)` and
  returns (mirrors `hazard_entity.gd:95`) — a bouncer never crashes after the player is gone (e.g. run end).
- **Speed 0:** `hpp_speed=0` → `velocity = 0` → the bouncer sits still (harmless degenerate; the all-off path never
  reaches here since `hpp_enabled=false` skips spawn). A still bouncer can still kill on contact (distance test runs).
- **Corner double-bounce:** the `velocity.dot(n) < 0.0` guard prevents a second flip on a frame already moving away —
  without it a corner can produce a per-frame velocity oscillation (jitter). Test: place a bouncer in a 90° corner,
  assert it exits the corner within N frames with a stable heading.
- **Multiple bouncers:** they do **not** mask `hazard`, so they pass through each other (no inter-bouncer pinball) —
  matches R1's "multiple hazards never collide/block each other" (`hazard_entity.gd:24-25`).
- **Determinism test hook:** with a fixed seed + a fixed-direction policy (OQ-4), two runs must place bouncers at
  byte-identical positions and headings (extend the existing per-room-density / hazard-spawn determinism tests:
  `tests/test_per_room_density.gd`, `tests/test_hazard_spread.gd`).
- **Confinement test hook:** spawn a bouncer in a room with a doorway, run M physics frames, assert
  `global_position` stays within the room's floor-cell bounds (validates the chosen OQ-1 mechanism).
- **Kill test hook:** place the player within `CONTACT_RADIUS`, step one physics frame, assert
  `GameState.run_active == false` and the death cause is `&"death"`, and `new_hazard_killed(&"pingpong", ...)` fired
  exactly once (latch test, mirrors the BUG6 catch-storm tests).
- **All-off control:** `hpp_enabled=false` → no node, no telemetry, fingerprint `e943ac9c8bc1` unchanged (the
  permanent baseline assertion every M1.4 task must preserve).

---

## Open Questions

> Each is stated with trade-offs for Phase-3 fresh-eyes resolution. The two load-bearing ones (OQ-1, OQ-4) are
> deliberately resolvable **in K5i's spawn call** without rewriting the entity (§6), so this entity design ships either way.

### OQ-1 — Room-confinement mechanism: pure wall-bounce vs. explicit room-rect clamp?

"Stay in a room" can be achieved three ways:

- **(a) Pure wall-bounce (no clamp).** Rely only on `move_and_slide` + reflect off `world`-layer walls. **Pro:** zero
  extra state, simplest; matches R1's "walls stop it" philosophy. **Con:** rooms are **not** sealed from each other —
  they connect via walkable doorways (`placed_piece.gd:28-32`; only the band *perimeter* is sealed,
  `socket_sealer.gd`). A bouncer aimed at a doorway **leaks into the next room** and roams the band. This **violates
  "stay in a room"** unless doorways are narrow enough that bounces rarely thread them (unreliable).
- **(b) Room-rect clamp (the `_confine_to_room` belt-and-braces in §2.2).** K5i passes the room's floor-cell bounding
  box as `room_bounds`; the entity reflects at the rect edges too. **Pro:** guarantees "stay in a room" regardless of
  doorways; cheap (4 comparisons/frame); deterministic. **Con:** the rect is an axis-aligned box, so an L-shaped/non-
  rectangular room (the L-bend piece) confines the bouncer to the *bounding* box, which may include a non-floor corner
  — the bouncer could bounce over a wall-corner visually. Mitigation: clamp to the *intersection* of rect + walls
  (wall-bounce handles the concave corner, rect handles the doorway leak) — i.e. **(a) AND (b) together**, which is
  what §2.2 does.
- **(c) Seal the bouncer's room.** Add invisible collision across the room's doorways at spawn. **Pro:** pure-physics,
  no per-frame clamp. **Con:** blocks the *player* too (or needs a player-permeable one-way collision) — over-scope
  for greybox, and it changes room traversal. **Rejected** for M1.4.

**Recommendation:** **(b)+(a) combined** — pass the floor-cell bounding-box rect from K5i and keep wall-bounce. The
rect guarantees confinement (the hard requirement); wall-bounce handles concave/L-shaped interiors. The entity already
supports `Rect2()` to fall back to pure-wall if Phase 3 disagrees. **Needs Phase-3 confirmation** (cheap, low-risk).

### OQ-2 — Bounce implementation: explicit `velocity.bounce(normal)` re-normalised, vs. rely on `move_and_slide` residual?

- **(a) Explicit reflect** (§2.2): read `get_last_slide_collision().get_normal()`, `velocity = velocity.bounce(n) *
  _speed`. **Pro:** exact mirror angle, constant speed preserved (glancing hits don't bleed speed), reads as a clean
  ping-pong. **Con:** must guard `dot(n) < 0` to avoid corner double-flips, and a multi-contact frame uses only the
  *last* collision normal (fine for a single-wall bounce; corners need the guard). **The recommended option.**
- **(b) Rely on slide residual.** Let `move_and_slide` deflect and keep `get_real_velocity()`. **Pro:** no reflect
  math. **Con:** slide *projects along* the wall (doesn't reflect) — the bouncer would **slide along** the wall, not
  ping off it. That is the **opposite** of the required behaviour. **Rejected.**

**Recommendation:** **(a) explicit `velocity.bounce(n).normalized() * _speed` with the `dot(n) < 0` guard.** This is
the only option that actually ping-pongs; (b) produces wall-grinding (the very R1 bug I2 fought). Lock (a).

### OQ-3 — Depth-scaling: per-room count vs. per-band budget, and is the formula linear?

§2.4 proposes `n_at_depth(d) = floor(hpp_base_count + hpp_count_per_depth * d)` applied **per room** (using the room's
`depth_index`), capped by `hpp_per_room_cap`. Alternatives: a **per-band** total (like J2's `r1_spawn_count` spread,
`main_game.gd:316`) scaled by `band.max_depth`; or a non-linear curve (J2's `pow(t,1.6)` curve mode,
`main_game.gd:472`). **Trade-off:** per-room is the most legible "deeper rooms have more bouncers" and matches the J3
per-room-density mental model the Director already tuned (`run_config.gd:99`); per-band is fewer total entities but
less directly "deeper = more *here*." **Recommendation:** **per-room linear** (matches the work-order "spawn more the
deeper you go" most literally and reuses the J3 cap pattern). **This is a K5i decision** (K5i owns the loop) — flagged
here so K5i and K5a agree on the `n_at_depth` contract. Mild **Director-flavour** call (how aggressively depth ramps
count is a fun-tuning sweep, not a correctness call) → resolvable by K5i + Director sweep.

### OQ-4 — Initial direction: fixed (per-index) vs. seeded local sub-stream?

- **(a) Fixed per-index.** Direction = a deterministic function of the spawn index (e.g. `Vector2.from_angle(index *
  GOLDEN_ANGLE)` or a small fixed table of diagonals). **Pro:** zero RNG, trivially reproducible, no sub-stream
  needed, cannot affect fingerprint. **Con:** identical seeds → identical headings (a non-issue for a greybox sweep;
  arguably a *feature* for comparability). **Recommended.**
- **(b) Seeded local sub-stream.** Draw the angle from `RNG`-seeded sub-stream `run_seed ^ HPP_SALT` (the B3/E3
  pattern, Breakdown §6). **Pro:** varied headings run-to-run feel less mechanical. **Con:** must use a sub-stream,
  never the global `RNG` mid-generation; more code; the variety is marginal for a bouncing entity that quickly
  randomises its own heading via bounces anyway.

**Recommendation:** **(a) fixed per-index direction.** A bouncer's heading is scrambled by its first few wall bounces
regardless of the start angle, so seeded variety buys little; fixed keeps the entity RNG-free and the determinism
story trivial. **Direction policy lives in K5i's `setup` call** (§6) so this can flip to (b) without an entity change.

### OQ-5 — Fatal vs. knockback on contact?

- **(a) Fatal (recommended).** The Director work-order is explicit: *"This hazard will kill you if it touches you."*
  Contact → `GameState.fail_run(&"death")`. No `hpp_catch_kills`-style toggle is in K0's knob set (unlike R1's
  `r1_catch_kills`, `run_config.gd:79`), reflecting that K5a is *defined* as lethal. **Lock fatal.**
- **(b) Knockback option.** R1 carries a non-fatal path (`hazard_entity.gd:200-209`) for its single-variable cost
  experiment. K5a *could* mirror it. **Con:** adds a knob (breaks K0's pinned `hpp_*` set + the CFG knob count),
  contradicts the work-order, and a *bouncing* non-lethal hazard is just a pinball nuisance with no clear stake.

**Recommendation:** **fatal, no toggle.** Matches the Director's explicit instruction and keeps the K0 knob set intact.
If a future milestone wants a non-lethal variant it's a new knob then, not now. (No genuine vision/tone call here — the
Director already specified "will kill you"; this is just confirming we honor it.)

### OQ-6 — Contact radius: fixed constant vs. a knob?

§2.2 makes `CONTACT_RADIUS = 24.0` a **self-contained constant** (like `HazardEntity`'s `NONFATAL_*` and `STALL_FRACTION`
constants, `hazard_entity.gd:39-57`), floored at `player_r + hazard_r = 24` (`run_config.gd:69-71`) so "touch" reads
honestly. **Trade-off:** a constant keeps K0's `hpp_*` knob set + the CFG knob count pinned (the M1.4 contract); a knob
would let the Director sweep "how forgiving is a graze." **Recommendation:** **fixed constant** — the bouncer's
difficulty lever is its **speed** (`hpp_speed`) and **count**, not its graze radius; adding a radius knob dilutes the
sweep and breaks the pinned knob count. Director may override at RG1 if grazes feel unfair.

### OQ-7 — Tell color + silhouette (character-animator + Director judgment)?

§3 recommends **amber `Color(0.95, 0.65, 0.15)` + a box silhouette** to read apart from R1 (grey-blue/red), the bomb
(expected pulse-red circle), and the spikes (expected steel cross/star). This is a **legibility/tone call** — flagged
**needs Director + character-animator review**: the exact hue and shape should be chosen *together with* K5b/K5c so all
four hazards (R1 + the three new) form a coherent, distinguishable greybox palette, not three independently-picked
colors that happen to clash. Recommendation: the character-animator picks the K5a/b/c trio's colors as a set during
Wave 3, against R1's existing red, with the Director ratifying the final palette at RG1.

---

*Phase 3 (fresh eyes, NOT this author) resolves the Open Questions into a `Resolved Decisions` section, flagging the
legibility/fun calls (OQ-3 ramp aggressiveness, OQ-7 palette) for the Director per the orchestrator loop.*

---

## Resolved Decisions (Phase 3)

> Fresh-eyes resolution, 2026-06-21. I read the four K5 hazard docs (K5a/K5b/K5c/K5i) + K0 as ONE family and resolved
> their Open Questions for cross-doc coherence. **K0 is NOT yet landed** (verified: `run_config.gd` / `event_bus.gd` carry
> no `hpp_*`/`hbomb_*`/`hspike_*` knobs or new-hazard signals, and K0 has no Resolved-Decisions section). That means the
> naming + signal + setup contracts below are still soft and **K0 must be updated to match these resolutions before it is
> dispatched** — the K0 doc itself notes its set is a "provisional union … refined once the K5 designs land" (K0 §intro,
> OQ-8). Where I lock a name, **K0 is the single writer that must adopt it.**

### CROSS-CUTTING — naming coherence (locks the family scheme)

The three entities used three different prefix styles across the docs. I audited the as-built convention:
`run_config.gd` groups are **contiguous prefixes with no underscore after the leading token** — `r1_`, `r2_`, `r3_`,
`r4_`, `lvl_` (`run_config.gd:57/121/140/161/192`), and the group string equals the field prefix exactly
(`@export_group("R1 Pursuing Hazard", "r1_")`). The CFG menu keys off that exact prefix.

**LOCKED scheme (matches K0 §B.1's `hpp_`/`hbomb_`/`hspike_` for two of three; corrects K5b):**

| type | config prefix | group title | entity `class_name` | scene file | telemetry `kind` |
|---|---|---|---|---|---|
| ping-pong | **`hpp_`** | `K5a Ping-Pong Hazard` | `PingPongHazard` | `scenes/hazards/pingpong_hazard.tscn` | `&"pingpong"` |
| bomb | **`hbomb_`** | `K5b Bomb Hazard` | `BombHazard` | `scenes/hazards/bomb_hazard.tscn` | `&"bomb"` |
| spikes | **`hspike_`** | `K5c Rotating Spikes` | `SpikeHazard` | `scenes/hazards/spike_hazard.tscn` | `&"spike"` |

Rationale: `hpp_`/`hbomb_`/`hspike_` are the only set that is (a) self-consistent (each is a contiguous prefix), (b)
already used by K0 §B.1 + K5i's descriptor table, and (c) collision-free. **K5b's `h_bomb_` is REJECTED** — the extra
underscore (`h_bomb_enabled`) breaks the contiguous-prefix house style and forces a different CFG section-prefix from its
siblings. K5b must be re-prefixed `hbomb_` throughout. **K5a (this doc) already uses `hpp_` — no change needed here.**
**K0 must declare the `hbomb_*` group, NOT `h_bomb_*`.**

**Telemetry `kind` token is singular `&"spike"`** (not `&"spikes"`) — K5i's descriptor table uses `&"spikes"` in one place
(`_new_hazard_descriptors`), which must be corrected to `&"spike"` to match K5a/K5c's `new_hazard_killed` emit and the
RG2 cohort segmentation. **K5a uses `&"pingpong"` — locked, unchanged.**

### CROSS-CUTTING — shared `setup()` contract (locks the signature per entity)

The docs diverged: K5a proposed `setup(cfg, player, initial_dir, room_bounds)`, K5c `setup(cfg, player, phase_salt)`,
K5b/K5i `setup(cfg, player)`. K5i's spawn loop is **type-agnostic** (`node.setup(rc, player)` for all three) and its OQ-6
flags this as the open reconciliation. Resolving for file-disjoint mergeability:

**LOCKED: every entity exposes `setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void`.**

- The first two params are the invariant `HazardEntity` contract (`hazard_entity.gd:83`) — uniform, type-agnostic.
- The **third param is a small per-type context Dictionary**, default `{}` (empty = neutral fallback), so K5i's loop stays
  ONE call site but can hand each entity exactly what it needs without three different arities. This is cleaner than
  widening to `setup(cfg, player, piece)` for all three (K5i OQ-6's alternative), because (a) the bomb needs nothing extra,
  (b) ping-pong needs `initial_dir` + `room_bounds`, (c) spikes needs `phase_salt` — heterogeneous needs, one signature.
- **K5i builds `spawn_ctx` per type** in its descriptor loop and each entity reads only its own keys:
  - ping-pong: `spawn_ctx.get("initial_dir", Vector2.RIGHT)`, `spawn_ctx.get("room_bounds", Rect2())`
  - spikes: `spawn_ctx.get("phase_salt", 0)`
  - bomb: ignores `spawn_ctx` entirely.
- **K5a (this doc):** the proposed `setup(cfg, player, initial_dir, room_bounds)` is SUPERSEDED by
  `setup(cfg, player, spawn_ctx)`. Internally read `var d: Vector2 = spawn_ctx.get("initial_dir", Vector2.RIGHT)` and
  `_room_bounds = spawn_ctx.get("room_bounds", Rect2())`. All §2.2 / §6 logic is otherwise unchanged — the resolution
  mechanism still lives in K5i's spawn call (the deliberate decoupling §6 describes is preserved).

This keeps the three entity files + K5i's `main_game.gd` seam file-disjoint and mergeable: K5i never edits an entity, the
entities never edit the seam, and the one shared shape is the `Dictionary` key contract documented here.

### Per-doc resolutions (this doc's Open Questions)

- **OQ-1 (room confinement) — RESOLVED: (b)+(a) combined, as recommended.** Wall-bounce handles concave/L-shaped
  interiors; the room-rect clamp (`_confine_to_room`) guarantees the hard "stay in a room" requirement against doorway
  leaks (rooms connect via walkable doorways — only the band perimeter is sealed, `socket_sealer.gd`). K5i passes the
  floor-cell bounding-box `Rect2` via `spawn_ctx["room_bounds"]`. The entity already supports `Rect2()` to disable the
  clamp, so this is reversible without an entity rewrite. Technical merit — no Director call.

- **OQ-2 (bounce implementation) — RESOLVED: (a) explicit `velocity.bounce(n).normalized() * _speed` with the
  `dot(n) < 0` guard.** Locked. Option (b) (`move_and_slide` residual) projects *along* the wall = wall-grinding, the exact
  opposite of ping-pong and the I2 bug R1 fought. Keep the corner double-flip guard. Technical merit — no Director call.

- **OQ-3 (depth-scaling shape) — RESOLVED (technical) + one flag.** The **count law and per-room application are K5i's to
  own** (see K5i OQ-1, resolved per-room there): `n_at_depth(d) = base + floor(count_per_depth * d)` per room, capped.
  K5a's §2.4 formula agrees with K5i's `_per_room_positions` — locked consistent. The *ramp aggressiveness* (how steeply
  count climbs with depth) is a Director sweep value, already covered by the Breakdown §2 "the value is the Director's to
  sweep" contract — not a separate flag (the knob exists; only its preset magnitude is open).

- **OQ-4 (initial direction) — RESOLVED: (a) fixed per-index direction.** Locked. A bouncer scrambles its own heading
  within a few bounces, so seeded variety buys nothing; fixed keeps the entity RNG-free and the determinism story trivial.
  **K5i supplies it** via `spawn_ctx["initial_dir"]` as a deterministic function of spawn index (e.g.
  `Vector2.from_angle(index * GOLDEN_ANGLE)` or a fixed diagonal table) — no sub-stream, cannot move `fingerprint()`.
  Consistent with K5i OQ-4 (pure-deterministic placement) — the whole family stays RNG-free for RG1.

- **OQ-5 (fatal vs knockback) — RESOLVED: fatal, no toggle.** Locked. The Director work-order is explicit ("will kill
  you"); no `hpp_catch_kills` knob (keeps the K0 `hpp_*` set + CFG count pinned). Honors the spec; no new vision call.

- **OQ-6 (contact radius) — RESOLVED: fixed constant `CONTACT_RADIUS = 24.0`.** Locked, floored at `player_r 14 +
  hazard_r 10 = 24` (`run_config.gd:69-71`) so "touch" reads honestly. The difficulty levers are `hpp_speed` + count, not
  graze radius; a radius knob would dilute the sweep and break the pinned knob count. Director may override at RG1.

- **OQ-7 (tell color + silhouette) — `**NEEDS DIRECTOR REVIEW**`.** This is a legibility/tone call and MUST be resolved as
  a **set** across R1 + the three new hazards, not per-doc. See the consolidated palette recommendation in the cross-doc
  note below. K5a's recommendation: **amber `Color(0.95, 0.65, 0.15)` + a box/square silhouette** (motion is the primary
  tell). Recommend the character-animator picks the K5a/b/c trio's colors+shapes together against R1's existing
  grey-blue/red during Wave 3, Director ratifies at RG1.

### `**NEEDS DIRECTOR REVIEW**` — the shared greybox palette (spans K5a/K5b/K5c)

The three hazards' tell colors + silhouettes must read **apart from each other AND from R1** at a glance on a busy screen.
The docs each picked a color independently and they currently overlap (K5a amber `0.95,0.65,0.15`; K5b arming-amber
`0.95,0.75,0.2`; K5c orange `0.95,0.55,0.1` — three near-identical oranges that WILL clash). **Recommendation to the
Director + character-animator (decide as a set during Wave 3, ratify at RG1):**

- **R1 pursuer** (existing, locked): grey-blue dormant → **alarm red** hunting — "the thing aimed at *you*."
- **K5a ping-pong:** **amber/yellow** + box silhouette — "moving, will hit you, not aimed." Distinguished by constant
  motion.
- **K5b bomb:** dim translucent ring idle → **hot orange** pulse → red-white blast + circle silhouette — distinguished by
  the proximity ring + accelerating throb (a *temporal* tell, not just color).
- **K5c spikes:** **steel/grey-cyan** + multi-arm star silhouette — distinguished by rotation + a cooler metallic hue that
  separates it from the warm amber/orange pair. (I specifically recommend pulling K5c OFF the orange it currently shares
  with K5a/K5b, toward steel/cyan, so the three are hue-separated, not just shape-separated.)

Silhouette already disambiguates (box / circle / star), but color should reinforce, not fight it. This is the one genuine
tone/legibility call in K5a — flagged, not self-resolved.
