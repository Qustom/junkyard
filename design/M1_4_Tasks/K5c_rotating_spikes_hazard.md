# K5c — Rotating-spikes hazard · Phase-2 Design

**Task:** K5c (M1.4 Wave 3, parallel with K5a/K5b). **Role:** general-purpose (programmer) + character-animator (the rotating tell).
**Director work-order:** *"Rotating spikes randomly in some part of the room. Spawns more the deeper you go."* Lethal on contact, and it rotates.
**Blocks:** K5i (the spawn-seam integration that actually instantiates K5a/b/c). **BlockedBy:** K0 (reads its `hspike_*` knobs + emits the K0-declared `new_hazard_killed` signal).
**Authored:** 2026-06-21, Phase 2 of the four-phase process (`CLAUDE.md`), from `design/M1_4_Tasks/M1.4_Breakdown.md` §3 (K5c) + §7 (new-hazard config shape).

> **What this doc IS:** the design of one NEW greybox hazard *entity* — its scene/script, its lethal hit test, its rotation, and its
> depth-scaled count contract that K5i applies. It is the rotating sibling of K5a (ping-pong) and K5b (bomb): three disjoint entity
> files that K5i wires into the existing per-depth + per-room spawn seam.
>
> **What this doc is NOT:** the spawn seam itself (that is **K5i** — single-writer on `main_game.gd`'s `_spawn_*` seam this wave),
> the knob declarations (those are **K0**, already landed at off/neutral — `hspike_enabled/base_count/count_per_depth/rotation_speed/
> arm_length/per_room_cap`), or any `event_bus.gd`/`run_config.gd` edit (K0 owns both shared files for the whole milestone). K5c
> writes only its own two files: `scenes/hazards/spike_hazard.gd` + `.tscn`.

---

## (a) Research — the as-built surface K5c builds on

### A.1 The greybox-hazard prior art — `HazardEntity` (R1, M1.1)

`scenes/hazards/hazard_entity.gd` + `.tscn` is the canonical "throwaway colored shape that can end your run" pattern K5c copies
wholesale, deviating only where "rotating spike" genuinely differs from "pursuing chaser":

- **Node + tell.** `class_name HazardEntity extends CharacterBody2D` (`hazard_entity.gd:1`) with one `@onready var _tell: Polygon2D = $Tell`
  (`:77`); the `.tscn` is a body + a `Polygon2D` "Tell" (`hazard_entity.tscn:13-15`, a 24px diamond) + a `CollisionShape2D`
  (`:17-18`). The tell *is* the placeholder art — no sprite sheets, no `AnimationTree` (`:212` "inline placeholder").
- **`setup(cfg, player)` snapshot binding.** `func setup(cfg: RunConfig, player: Node2D)` (`:83-91`) snapshots `GameState.active_run_config`
  + resolves the player so a later `active_run_config` clear on run-end can't null it mid-frame (`:80-82` doc). K5c uses the
  **identical signature** so K5i's spawn loop is uniform across all three new hazards (`hz.setup(rc, player)`, `main_game.gd:323/349`).
- **The lethal test is a SCRIPT distance test, NOT a physics overlap — deterministic (R1 §2.4).** `hazard_entity.gd:143-147`:
  `global_position.distance_to(_player.global_position) <= catch_r`. The class doc is explicit (`:23-25`): the body "does NOT mask
  `player` (catch is a script distance test, deterministic)". **This is the load-bearing convention K5c must honor** — the kill is
  geometry the script computes each frame, not a `body_entered`. K5c's only twist is that the lethal geometry is a *rotating arm
  segment*, not a point-to-point distance.
- **Fatal via the EXISTING end path.** `hazard_entity.gd:189` routes a fatal catch through `GameState.fail_run(&"death")`
  (signature `func fail_run(cause: StringName)`, `game_state.gd:323-324`), and lets `GameState._run_ended` (`game_state.gd:70,
  324-326`) absorb duplicate calls — "no local 'already ended' bool that PREVENTS the call" (`:182-183`). K5c does the same: it
  never invents a new end path and never guards `_run_ended` itself; the `_run_ended` flag is the single idempotency source across
  every hazard + extract. (A *local* one-shot latch to stop a per-frame TELEMETRY storm is fine — see A.4 / the BUG6 `_caught_latched`
  precedent, `:69-75`.)
- **Collision layers.** Body on layer `hazard` (16 = bit 5), masks `world` (2) ONLY (`hazard_entity.tscn:9-10`, doc `:23-25`).
  Walls stop the chaser; it does not mask `player` or `hazard`. **K5c differs here:** a rotating spike is *anchored* — it doesn't
  move, so it has no reason to collide with walls at all. K5c's body needs **no collision shape and no mask** (its kill is pure
  script geometry); see OQ-1. The player itself is `collision_layer 1`, `mask 26`, a `CircleShape2D` `radius = 14.0`
  (`entities/player/player.tscn:7-12, 28`) in group `player` — the same 14px player radius R1's 24px catch floor accounts for.
- **All-off discipline.** `hazard_entity.gd:20-21`: with the master toggle off "the spawn seam never instantiates this node, so the
  M1.0 baseline is byte-for-byte unchanged (no node, no telemetry, no behaviour)." K5i gates K5c the same way: `hspike_enabled == false`
  ⇒ no spike scene loaded, no node, no behaviour.

### A.2 The spawn seam K5i wires K5c into — `main_game.gd`

K5c does **not** edit `main_game.gd` (K5i does), but K5c's count contract is designed against the seam's real shape:

- **`_spawn_r1_hazards(run_cfg, band)`** (`main_game.gd:296-328`) is the template: a gate (`rc == null or not rc.<enabled>` ⇒
  return early — no scene load), a `load(<PATH>) as PackedScene`, a `get_tree().get_first_node_in_group(&"player")`, then a loop
  that `add_child`s into `_band_container` (so `_clear_band()` frees them — run-state, never persisted) and calls `setup(rc, player)`.
- **The two placement helpers K5c's count contract reuses (via K5i):**
  - **`_density_spawn_positions(band, rc) -> Array[Vector2]`** (`:359-397`) — the **per-room** density plan: walks pieces
    depth-sorted (`_density_pieces_sorted`, `:422-434`), gates on min-area + corridor exclusion, computes a per-room count,
    applies a **per-room cap** + a **band-wide ceiling** (`R1_DENSITY_BAND_CEILING = 64`, `run_config.gd:37`), and **strides the
    count across that room's own sorted floor cells** (`:391-396`) — **NO RNG, pure run-state**, "same (band, rc) → byte-identical
    list". This is the proven "place N things in part of a room deterministically" machinery K5c's "randomly in some part of the
    room" reuses (see OQ-4).
  - **`_band_max_depth(band) -> int`** (`:490-491`) returns `band.max_depth` (set by `DepthGrader.grade()` during generation) — the
    single source of truth for the deepest graded depth. K5c's "more with depth" count formula keys off `depth_index` (per-room
    `PlacedPiece.depth_index`) relative to this max, exactly as R1's J2 spread does (`_hazard_spawn_depths`, `:460-483`).
  - **`_density_cell_to_world(cell)`** (`:449-451`) — band-global cell → centred world pixel. K5c anchors spawn at a cell centre
    via this same projection (K5i calls it), so a spike sits in the middle of a floor tile, not on a wall edge.
- **Why this matters for K5c:** the entity is *position-agnostic*. K5i hands it a `global_position` (a deterministic floor-cell
  centre) and `setup(rc, player)`. K5c owns only what happens *at* that anchor: rotate + test the arm against the player + die.

### A.3 K0's pre-declared `hspike_*` knobs (already on `main` at off/neutral)

`design/M1_4_Tasks/K0_foundation_knobs_signals.md` §B.1 already landed the K5c group (off/neutral, so the all-off control is
byte-identical), and §B.2 added them to `to_flat_dict()`:

```gdscript
@export_group("K5c Rotating Spikes", "hspike_")
@export var hspike_enabled: bool = false
@export var hspike_base_count: int = 0
@export var hspike_count_per_depth: float = 0.0
@export var hspike_rotation_speed: float = 0.0   # deg/s (signed → direction)
@export var hspike_arm_length: float = 0.0       # reach of the lethal arm (px)
@export var hspike_per_room_cap: int = 0
```

**K5c reads these (snapshotted in `setup`); it does not add or rename any.** The one nuance K5c must resolve for the build agent
(OQ-2): the knob set has `rotation_speed`, `arm_length` and the count trio, but **no `arm_count`** (how many spike arms radiate
from the hub) and **no kill-radius/arm-thickness** field. The recommendation (OQ-2/OQ-3) is to make `arm_count` and the
arm-thickness greybox **self-contained constants in `spike_hazard.gd`** — exactly as `HazardEntity` keeps its non-RunConfig feel
knobs (`NONFATAL_KNOCKBACK_SPEED`, `STALL_FRACTION`, the tell colors) as in-file constants the Director edits there
(`hazard_entity.gd:39-57, 32-34`). This keeps the CFG knob count pinned to K0's count and matches the established "magnitude knobs
in RunConfig, greybox-feel knobs in the file" split.

### A.4 The K0-declared kill signal + telemetry shape

K0 §B.3 pre-declared the new-hazard telemetry signal (K5c only EMITS it — never edits `event_bus.gd`):

```gdscript
signal new_hazard_killed(kind: StringName, depth: int, run_t_ms: int)   # event_bus.gd, K0-added
```

K5c emits `new_hazard_killed(&"spike", depth, run_t_ms)` on the lethal frame, mirroring R1's `hazard_caught(depth, run_t_ms)`
(`event_bus.gd:91`, emitted `hazard_entity.gd:188`). Payload is **primitives only** (the telemetry-row rule, `event_bus.gd:86-88`).
The actual death still flows through `GameState.fail_run(&"death")` (the K0 doc note: "the actual death still flows through
`player_died(cause)`" — `fail_run` is what emits `player_died`). For `run_t_ms`, K5c **self-times from spawn** (`_alive_time * 1000`)
exactly as R1 does (`hazard_entity.gd:185-187` — the run clock isn't exposed read-only off GameState in M1). A **one-shot kill
latch** (`_killed_emitted`) gates the emit so a paused/over-determined frame can't double-emit, mirroring R1's `_caught_latched`
rising-edge gate (`hazard_entity.gd:69-75, 154-158`) — but, like R1, it does **not** guard the `fail_run` call (the `_run_ended`
flag owns run-end idempotency).

### A.5 GDD/TDD grounding

- **TDD data-as-Resources + run/meta boundary:** the spike's *config* is run-scoped `RunConfig` (never persisted), its *spawned
  nodes* are run-state under `_band_container` (disposed by `_clear_band`) — never meta-state. K5c adds no save-schema surface
  (only K2's quota does this milestone, Breakdown §2).
- **Deterministic seeded RNG (TDD):** the spike's placement is **pure run-state on the already-graded band** (like R1's density),
  so it **never feeds `fingerprint(seed+config)`** (Breakdown §6: "New-hazard spawn placement (K5) is pure run-state … like the R1
  hazards"). If K5c ever wants per-instance *variety* (phase/direction jitter), it must derive it **deterministically from spawn
  state** (cell index / a local `seed ^ salt` sub-stream — the B3/E3 pattern), **never `RNG.randi()` mid-generation** (OQ-5).
- **Pixel art / greybox:** the rotating bar/star is a `Polygon2D` in a distinct danger color — the rotation itself is the
  telegraph (the player learns the rhythm), no real art (Breakdown §2 "greybox shapes (colored `Polygon2D` tells)").

---

## (b) Pseudocode — the entity (illustrative, against the real as-built APIs)

> Two files only: `scenes/hazards/spike_hazard.gd` (below) + `scenes/hazards/spike_hazard.tscn` (a `Node2D` root named per
> recommendation, with one child `Polygon2D` "Tell" drawn as a multi-arm star; **no `CollisionShape2D`** — the kill is script
> geometry, OQ-1). K5i loads it at a new `SPIKE_HAZARD_SCENE_PATH` const and spawns it through the seam.

```gdscript
class_name SpikeHazard
extends Node2D
## SpikeHazard (K5c, M1.4) — the greybox "rotating spikes" hazard: an ANCHORED hub
## that spins at a constant angular velocity, with `_arm_count` lethal arms of length
## `arm_length` radiating from it. Lethal on contact: the kill is an ANALYTIC distance-
## to-arm-segment test against the player each frame (deterministic, NO physics overlap —
## the R1 convention, hazard_entity.gd:143-147). The rotation IS the telegraph; the player
## learns the rhythm and threads the gap between arms.
##
## THROWAWAY GREYBOX, not the M2 enemy slice. No combat, no health, no pathfinding.
## Stationary, so (unlike R1) it has NO collision shape and NO collision mask — it never
## moves, never blocks anything, and its kill is pure geometry.
##
## READS ONLY (R1's contract): reads its hspike_* knobs (snapshotted at setup); reads
## GameState.current_depth_index live for the telemetry depth; EMITS the pre-declared
## EventBus.new_hazard_killed (never edits event_bus.gd); routes a fatal hit through the
## EXISTING GameState.fail_run(&"death") — no new end path, no local _run_ended guard.
##
## ALL-OFF: with hspike_enabled == false the spawn seam (K5i) never instantiates this node,
## so the M1.0 baseline is byte-for-byte unchanged.

# --- Greybox-feel constants (NOT RunConfig knobs — the magnitude knobs live in RunConfig,
# the feel knobs live here, like hazard_entity.gd:32-57). The Director edits these in-file. -
const COLOR_SPIKE := Color(0.95, 0.55, 0.1)   # hot orange "blades" — distinct from R1 red / bomb
const ARM_COUNT_DEFAULT := 3                   # spike arms radiating from the hub (OQ-2)
const ARM_HALF_WIDTH := 6.0                    # px half-thickness of an arm (the greybox blade is a thin bar)
# Lethal kill radius around the arm SEGMENT = the player's body radius (14, player.tscn:8)
# plus the arm's half-thickness, so the kill fires when the player's circle touches the blade.
const PLAYER_RADIUS := 14.0
const KILL_PAD := ARM_HALF_WIDTH               # tunable contact slack

var _cfg: RunConfig
var _player: Node2D
var _alive_time: float = 0.0          # seconds since setup (self-timed run clock, R1 §4)
var _angle: float = 0.0               # current rotation (radians); rotation += speed * delta
var _omega: float = 0.0               # angular velocity (rad/s), signed → direction (from hspike_rotation_speed deg/s)
var _arm_length: float = 0.0          # snapshotted reach of each lethal arm (px)
var _arm_count: int = ARM_COUNT_DEFAULT
var _killed_emitted: bool = false     # one-shot telemetry latch (R1 _caught_latched precedent); does NOT guard fail_run

@onready var _tell: Polygon2D = $Tell


## Bind the run config + player + initial phase. Called by K5i's spawn loop right after
## add_child (uniform with HazardEntity.setup — main_game.gd:323). Snapshots the config.
## `phase_salt` is a DETERMINISTIC per-instance offset K5i derives from spawn order/cell
## (NOT global RNG — OQ-5); 0 reproduces a fixed phase.
func setup(cfg: RunConfig, player: Node2D, phase_salt: int = 0) -> void:
	_cfg = cfg
	_player = player
	_alive_time = 0.0
	_killed_emitted = false
	_omega = deg_to_rad(cfg.hspike_rotation_speed)   # signed deg/s → signed rad/s (direction baked in)
	_arm_length = cfg.hspike_arm_length
	# Deterministic per-instance phase so a field of spikes isn't lock-step (OQ-5). Pure
	# function of the salt — reproducible run-to-run, never touches RNG.
	_angle = deg_to_rad(float((phase_salt * 47) % 360))
	if _tell != null:
		_rebuild_tell()          # draw the N-arm star once at setup
		_tell.color = COLOR_SPIKE


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return
	_alive_time += delta

	# --- Rotate (constant angular velocity — the telegraph itself) -----------
	_angle = wrapf(_angle + _omega * delta, 0.0, TAU)
	rotation = _angle          # spins the Tell Polygon2D with the node (greybox blades)

	# --- Analytic lethal test: is the player within KILL of ANY arm segment? --
	# Each arm is the segment from the hub (global_position) outward to
	# hub + arm_length * (unit vector at _angle + i * (TAU / _arm_count)).
	# distance_point_to_segment is closed-form — deterministic, no physics overlap.
	var kill: float = PLAYER_RADIUS + KILL_PAD
	var hit: bool = false
	for i in _arm_count:
		var a: float = _angle + float(i) * (TAU / float(_arm_count))
		var tip: Vector2 = global_position + Vector2(cos(a), sin(a)) * _arm_length
		if _dist_point_to_segment(_player.global_position, global_position, tip) <= kill:
			hit = true
			break

	# One-shot kill (R1 idempotency): emit telemetry ONCE, route death through the EXISTING
	# end path. fail_run's _run_ended guard absorbs dupes across all hazards (game_state.gd:324).
	if hit and not _killed_emitted:
		_killed_emitted = true
		var depth: int = GameState.current_depth_index
		var run_t_ms: int = int(_alive_time * 1000.0)
		EventBus.new_hazard_killed.emit(&"spike", depth, run_t_ms)
		GameState.fail_run(&"death")   # single source of run-end truth; no local guard


## Closed-form distance from point p to segment [a, b] (Godot has Geometry2D for this, but
## inlined here to show it is pure math — no physics, fully deterministic).
func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	if len2 <= 0.0001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)
	# (In the real build, prefer Geometry2D.get_closest_point_to_segment(p, a, b) for parity.)


## Build the greybox star: _arm_count thin bars radiating from the hub, as ONE Polygon2D
## (a single concave star polygon) in COLOR_SPIKE. Drawn in LOCAL space (the node's rotation
## spins it). Pure presentation — the lethal test above uses _angle math, not this polygon.
func _rebuild_tell() -> void:
	var pts := PackedVector2Array()
	for i in _arm_count:
		var a: float = float(i) * (TAU / float(_arm_count))
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x) * ARM_HALF_WIDTH
		pts.append(perp)                                   # base, one side of hub
		pts.append(dir * _arm_length)                      # tip
		pts.append(-perp)                                  # base, other side
	_tell.polygon = pts
```

### The depth-scaled count contract K5i applies (designed here, implemented by K5i)

K5c does not spawn itself; it **specifies the count formula** K5i evaluates per band/room. Two equivalent expressions of "more
with depth," matching how R1's two budgets already work — recommendation in OQ-4:

```gdscript
# Per-room count (the recommended shape — reuses _density_spawn_positions machinery, OQ-4):
# for each eligible piece p at depth_index d (depth-sorted, corridor/min-area gated like R1 density):
#   n_room = floor(rc.hspike_base_count + rc.hspike_count_per_depth * float(d))
#   n_room = mini(n_room, rc.hspike_per_room_cap)            if cap > 0
#   n_room = mini(n_room, BAND_CEILING - spawned_total)      band-wide guard (reuse R1_DENSITY_BAND_CEILING)
#   stride n_room spikes across p's OWN sorted floor cells   (deterministic, NO RNG — R1 density:391-396)
# phase_salt for spike k in piece p = (p.depth_index * 131 + k)   # deterministic per-instance phase (OQ-5)
```

All-off (`hspike_enabled == false`, or `hspike_base_count == 0` and `hspike_count_per_depth == 0.0`) ⇒ K5i instantiates **no node**
⇒ byte-identical to M1.0 (placement is run-state, never feeds `fingerprint()`).

---

## (c) Open Questions

### OQ-1 — Hit test: analytic distance-to-segment vs an `Area2D`/physics arm. *(recommendation: analytic)*
- **Analytic (pseudocode above):** a closed-form `distance_point_to_segment(player, hub, tip) <= kill` for each of `_arm_count`
  arms, computed from the current `_angle`. **Pros:** exactly the established R1 convention (`hazard_entity.gd:143-147` "script
  distance test, deterministic"); no collision layer/mask wiring; trivially unit-testable (pure function of `(angle, arm_length,
  player_pos)`); cheap (≤3 segment tests/frame). **Cons:** the arm is a 1-D segment + a kill radius, so the lethal area is a
  capsule, not the exact star polygon — but that *is* the spike (a thin blade), so the approximation is faithful.
- **`Area2D`/`RotationalKinematicBody` arm:** physics children that rotate, firing `body_entered`. **Pros:** "free" overlap.
  **Cons:** breaks the deterministic-script-test convention every other hazard follows; `body_entered` is frame/physics-order
  dependent (the exact M1.1 trap R1 avoided by NOT masking `player`); adds collision layers; harder to unit-test. **Recommend
  analytic** — consistent with R1, deterministic, no physics surface. *(Technical merit — resolvable in Phase 3, not a Director call.)*

### OQ-2 — `_arm_count`: in-file constant (3) vs a new RunConfig knob. *(recommendation: in-file constant, default 3)*
- K0 declared `hspike_*` WITHOUT an `arm_count` knob. Options: (a) keep `_arm_count` a self-contained constant the Director edits
  in `spike_hazard.gd` (like `STALL_FRACTION`, `NONFATAL_*` in `hazard_entity.gd:39-57`); (b) ask K0 to add an `hspike_arm_count`
  knob (a CFG count bump + `to_flat_dict` entry + the BUG6/coverage count update).
- **Trade-off:** (a) keeps the CFG knob count pinned to K0's already-landed set (no cross-file churn into K0's single-writer
  files, no count-test re-bump) and matches the "feel knobs live in the file" precedent. (b) lets RG1 *sweep* arm count, which is a
  legitimately fun-relevant variable ("2 arms = easy gap, 6 arms = a wall"). **Recommend (a) constant = 3 for the build**, and
  **flag to the Director**: *if arm count should be a swept variable in RG1/RG2, promote it to an `hspike_arm_count` knob — that is
  a fun/scope call.* Default 3 reads clearly as "rotating spikes" without being an impassable wall. *(Has a Director-facing
  fun/scope tail — flag in Phase 3.)*

### OQ-3 — `arm_length` / kill-radius defaults. *(recommendation below; values are the Director's to sweep)*
- The lethal capsule radius is `PLAYER_RADIUS (14) + KILL_PAD`. `KILL_PAD = ARM_HALF_WIDTH (6)` ⇒ ~20px contact slack, so the kill
  fires when the player's 14px circle visibly touches a 6px-wide blade — fair and readable. `arm_length` is a swept `RunConfig`
  knob (`hspike_arm_length`); a first-sweep value of **~48–64px** (3–4 player radii) gives a blade that sweeps a meaningful arc of a
  room without filling it. **Recommend:** ship the kill radius as the `PLAYER_RADIUS + ARM_HALF_WIDTH` constant (matches R1's
  "radius must clear the player body" logic, `run_config.gd:71`), and seed `make_default_play_preset()` (a K1/K5i preset edit, NOT
  a code-default change) with `hspike_arm_length ≈ 56`. **The exact preset value is the Director's sweep, not ours** (Breakdown §2:
  "the *value* is the Director's to sweep"). *(Technical floor is resolvable; the preset magnitude is a Director sweep — flag.)*

### OQ-4 — Placement determinism: reuse R1's per-room density machinery vs a fresh stride. *(recommendation: reuse, per-room)*
- "Randomly in some part of the room" + "more with depth" maps cleanly onto K5i either as (a) a **per-room** budget that **reuses
  `_density_spawn_positions`'s proven machinery** (depth-sort pieces → gate min-area/corridor → per-room count from
  `base_count + count_per_depth*depth` → per-room cap → band ceiling → **stride across the room's own sorted floor cells**,
  `main_game.gd:359-397`), or (b) a **band-level** budget like R1's J2 spread (`_hazard_spawn_depths`, `:460-483`).
- **Trade-off:** (a) gives the Director's "in *part of the room*" phrasing directly (a spike sits at a deterministic floor cell
  *inside* a room) and inherits R1's perf caps + determinism for free; (b) is simpler but scatters spikes by depth-band, not by
  room. **Recommend (a)** — it is the closest match to the work-order's wording, it is already deterministic + capped + RNG-free
  (the Breakdown §6 contract), and K5i can literally clone the R1-density loop with the `hspike_*` knobs. "Random" here is
  **deterministic stride**, not `RNG` — the whole hazard-placement layer is pure run-state (never feeds `fingerprint()`). The
  band-wide ceiling reuses `R1_DENSITY_BAND_CEILING` (or a K5i-added per-type ceiling constant). *(Technical merit — resolvable.)*

### OQ-5 — Rotation phase + direction: fixed vs deterministic per-instance variation. *(recommendation: deterministic per-instance phase; uniform direction)*
- **Phase:** if every spike in a field starts at `_angle = 0`, a row of them spins in lock-step (visually flat, and the player can
  thread one safe corridor through all of them). Varying the start phase per instance makes the field read as a chaotic blade-garden.
  **Recommend:** a **deterministic** per-instance phase derived from spawn order/cell (`phase_salt` → `_angle` in `setup`, NO global
  RNG — the B3/E3 `seed ^ salt` discipline, Breakdown §6). This gives visual variety while keeping the run reproducible from
  (seed+config) and the all-off fingerprint frozen.
- **Direction:** `hspike_rotation_speed` is **signed deg/s** (K0's comment: "signed → direction"), so one knob sets a uniform
  spin direction. Options: (a) all spikes spin the knob's signed direction (uniform); (b) alternate/derive direction per instance
  from the same salt. **Recommend (a) uniform** for the first build (one knob, one legible rhythm to learn); per-instance direction
  jitter is a cheap follow-up if RG2 shows the field reads too uniform — but that is borderline a fun call. **Flag to the Director:**
  *uniform direction (recommended, simplest) vs deterministic per-instance direction variety.* *(Phase: technical, resolvable.
  Direction-variety: a minor fun call — flag.)*

### OQ-6 — Node base type: `Node2D` (anchored) vs `CharacterBody2D` (R1 parity). *(recommendation: `Node2D`, no collision)*
- R1 is a `CharacterBody2D` because it *moves* (`move_and_slide`, wall refuge). A rotating spike is **anchored** — it never
  translates. **Recommend `Node2D`** with no `CollisionShape2D`/mask: the kill is the analytic test, the rotation is `rotation =
  _angle`, and there is nothing to physically collide with (the hub sits at a floor-cell centre K5i picks, away from walls). This is
  lighter than `CharacterBody2D` and removes the "does it grind a wall?" class of bugs R1 had to engineer around
  (`hazard_entity.gd:43-57`). **Trade-off:** if a future variant should be *blocked by walls* (arm clipping through a wall), it
  would need a body — but greybox K5c explicitly does not (the arm visibly sweeping over a wall corner is acceptable greybox).
  *(Technical merit — resolvable in Phase 3.)*

---

## Files this task writes (and only these)
- `scenes/hazards/spike_hazard.gd` — the `SpikeHazard` entity (pseudocode above).
- `scenes/hazards/spike_hazard.tscn` — `Node2D` "SpikeHazard" + child `Polygon2D` "Tell" (the N-arm star, `COLOR_SPIKE`); **no**
  `CollisionShape2D` (OQ-1/OQ-6). character-animator owns the tell's shape/color so it reads as spinning blades distinct from R1
  (red) and the bomb (K5b).

## Files this task must NOT touch (owned elsewhere this milestone)
- `data/run_config/run_config.gd`, `systems/event_bus.gd` — **K0** (single writer; `hspike_*` + `new_hazard_killed` already landed).
- `scenes/game/main_game.gd` (`_spawn_*` seam, the new `SPIKE_HAZARD_SCENE_PATH` const, the count formula evaluation) — **K5i**.

## Definition of done (for the build agent, once Phase 3 locks the OQs)
- `godot --headless --import` compiles `spike_hazard.gd` with no parse errors; the scene loads.
- A unit test on the pure hit-test (`_dist_point_to_segment` + the arm loop) confirms: player on a blade ⇒ hit; player in the gap
  between arms ⇒ no hit; the test is reproducible for a fixed `(angle, arm_length, player_pos)`.
- With `hspike_enabled = false` no spike node is instantiated (K5i's gate) and the all-off fingerprint stays `e943ac9c8bc1`
  (placement is run-state, never feeds `fingerprint()`).
- A worklog at `worklogs/<date>-K5c-*.md` (shared with K5i if integrated together) names the commit SHA + records any deviation.
```

---

## Resolved Decisions (Phase 3)

> Fresh-eyes resolution, 2026-06-21, resolving the four K5 hazard docs (K5a/K5b/K5c/K5i) + K0 as ONE coherent family.
> **K0 is NOT yet landed** (verified: no `hspike_*` knobs in `run_config.gd`, no `new_hazard_killed` in `event_bus.gd`),
> so the contract below is still soft and **K0 must adopt these names before it is dispatched.** K5c was already the most
> aligned of the three (it uses `hspike_` and `new_hazard_killed` matching K0) — only minor coherence fixes below.

### CROSS-CUTTING — naming coherence

K5c's config prefix **`hspike_` is CORRECT** and locked (matches K0 §B.1, the contiguous-prefix house style `r1_`/`lvl_`,
and its siblings `hpp_`/`hbomb_`). No change. The entity is `class_name SpikeHazard`, scene
`scenes/hazards/spike_hazard.tscn` — **note K5i's descriptor lists the scene as `rotating_spikes_hazard.tscn`; the LOCKED
path is `spike_hazard.tscn`** (K5c is the file's author; K5i must use that path). K5c emits **`new_hazard_killed(&"spike",
…)`** (singular) — locked; **K5i's descriptor uses `&"spikes"` (plural), which must be corrected to `&"spike"`** to match
this emit and RG2's cohort key.

### CROSS-CUTTING — shared `setup()` contract (resolves K5c's `phase_salt` vs K5i's `setup(cfg, player)`)

K5c proposed `setup(cfg, player, phase_salt: int)`; K5i assumed `setup(cfg, player)` for all three (its OQ-6 flags the
clash). **LOCKED family signature: `setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void`** (full
rationale in K5a's Resolved Decisions — heterogeneous per-type needs behind ONE type-agnostic call site). For K5c:
**`phase_salt` moves into `spawn_ctx`** — `setup` reads `var phase_salt: int = spawn_ctx.get("phase_salt", 0)`. K5i
builds `spawn_ctx["phase_salt"] = p.depth_index * 131 + k` (the deterministic per-instance offset §2.4 already specifies)
per spike. All §(b) rotation/phase logic is otherwise unchanged. This keeps K5c's two entity files disjoint from K5i's
`main_game.gd` seam.

### Per-doc resolutions (OQ-1 … OQ-6)

- **OQ-1 (hit test) — RESOLVED: analytic distance-to-segment, as recommended.** Closed-form
  `Geometry2D.get_closest_point_to_segment(player, hub, tip)` distance ≤ `kill` per arm, computed from `_angle`. This is
  the established R1 determinism convention (`hazard_entity.gd:143-147` "script distance test, deterministic"); no
  collision layer/mask, frame-exact, trivially unit-testable. An `Area2D`/`body_entered` arm is rejected (physics-order
  dependent — the exact trap R1 avoids). **Prefer the engine `Geometry2D` call over the inlined `_dist_point_to_segment`
  in the real build for parity** (the pseudocode notes this). Technical merit — no Director call.

- **OQ-2 (`arm_count`: constant vs knob) — RESOLVED for the build: in-file constant `ARM_COUNT_DEFAULT = 3`;
  `**NEEDS DIRECTOR REVIEW**` for promotion.** Ship arm count as a self-contained constant (matches the "feel knobs live
  in the file, magnitude knobs in RunConfig" split — `hazard_entity.gd:39-57`), keeping the CFG knob count pinned to K0's
  already-listed `hspike_*` set (no cross-file churn into K0's single-writer files). **Flag to the Director:** arm count is
  a legitimately fun-relevant swept variable ("2 arms = easy gap, 6 arms = a wall"); IF the Director wants it swept in
  RG1/RG2, promote it to an `hspike_arm_count` knob (a K0 edit + CFG count bump). Default 3 reads clearly as "rotating
  spikes" without being an impassable wall. Build proceeds on constant=3 unless the Director promotes it.

- **OQ-3 (`arm_length` / kill-radius defaults) — RESOLVED (floor) + `**NEEDS DIRECTOR REVIEW**` (preset magnitude).**
  Lock the kill capsule radius as the in-file constant `PLAYER_RADIUS (14) + ARM_HALF_WIDTH (6) = 20` (matches R1's
  "radius must clear the player body" logic, `run_config.gd:71`) so the kill fires when the player's circle visibly
  touches a blade — fair and readable. `hspike_arm_length` is a swept `RunConfig` knob; the **preset value** (recommended
  ~56px, 3–4 player radii) is the Director's sweep, not ours (Breakdown §2). Technical floor resolved; magnitude flagged.

- **OQ-4 (placement: reuse R1 density vs fresh stride) — RESOLVED: reuse, per-room.** "Randomly in some part of the room"
  + "more with depth" maps onto K5i's `_per_room_positions` (the generalized `_density_spawn_positions`): depth-sort
  pieces → per-room count `base + floor(count_per_depth * depth)` → per-room cap → band ceiling → stride across the room's
  own sorted floor cells. Deterministic, RNG-free, never feeds `fingerprint()`. This is **K5i's to own** (K5i OQ-1/OQ-2,
  resolved per-room + share-cell-helpers there); K5c's §2.4 count formula agrees. "Random" = deterministic stride.
  Technical merit — resolved.

- **OQ-5 (rotation phase + direction) — RESOLVED (phase) + `**NEEDS DIRECTOR REVIEW**` (direction variety).**
  **Phase: deterministic per-instance**, derived from spawn order/cell (`spawn_ctx["phase_salt"]` → `_angle`, NO global
  RNG — the B3/E3 `seed ^ salt` discipline), so a field of spikes reads as a chaotic blade-garden rather than lock-step,
  while staying reproducible from (seed+config) with the all-off fingerprint frozen. Locked.
  **Direction: uniform** (all spikes spin the signed `hspike_rotation_speed` direction) for the first build — one knob, one
  legible rhythm to learn. **Flag to the Director:** per-instance direction variety (alternating/salt-derived) is a minor
  fun call; recommend uniform for RG1, revisit if RG2 shows the field reads too uniform. Build proceeds on uniform.

- **OQ-6 (node base type) — RESOLVED: `Node2D`, no collision shape/mask.** The spike is anchored (never translates); the
  kill is the analytic test, the rotation is `rotation = _angle`, nothing to physically collide with (the hub sits at a
  floor-cell centre K5i picks, away from walls). Lighter than `CharacterBody2D` and removes the wall-grind bug class R1
  engineered around. **This aligns the two stationary hazards: K5b (bomb) is ALSO resolved to `Node2D` (K5b Q1)** — only
  K5a (ping-pong) keeps `CharacterBody2D` because it moves and bounces off walls. A future wall-blocked variant would need
  a body, but greybox K5c explicitly does not (an arm visibly sweeping over a wall corner is acceptable greybox).
  Technical merit — resolved.

### `**NEEDS DIRECTOR REVIEW**` — tell color (part of the shared palette)

K5c's `COLOR_SPIKE = Color(0.95, 0.55, 0.1)` (orange) currently clashes with K5a's amber and K5b's arming-amber — three
near-identical warm hues. **My cross-doc recommendation (see K5a's Resolved Decisions for the full set): pull K5c toward
steel/grey-cyan** so the rotating-blades hazard is hue-separated from the warm amber/orange ping-pong + bomb, not just
shape-separated (its multi-arm star silhouette already disambiguates shape). The character-animator should pick the
K5a/b/c trio as a SET against R1's grey-blue/red during Wave 3; the Director ratifies the final palette at RG1. Flagged,
not self-resolved.
