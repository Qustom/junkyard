# S2 — Opposition Component Extraction + `param_schema` Authoring — Expanded Design Spec

**Milestone:** M1.9 (Scalable Opposition + Band Systems) · **Workstream:** opposition migration Phase B · **Wave:** 2 (parallel with S5 — file-disjoint)
**Task id:** S2 · **blockedBy:** S0 (SpawnService + `OppositionDef` data layer + EventBus pre-declare)
**Assignees:** general-purpose (component extraction + defs + tests)
**Author:** game-director-designer (Phase-2 design fan-out) · **Status:** design (open questions pending Phase-3 resolution)

> **What this doc is.** The Phase-2 per-task design for S2 per `M1.9_Breakdown.md` §Wave 2: refactor the 4 shipped hazard entities' internals into shared `class_name`-typed components, and complete each `OppositionDef`'s `params` + `param_schema` mirroring today's knobs exactly. **Behavior and telemetry must stay observably identical** — this is the riskiest migration step (it rewrites the per-frame logic of every lethal entity at once), so the whole design is organized around *transplant, don't rewrite* and around the test gates that prove parity. It is design only — no game code ships from this doc; the programmer builds against it. Source architecture: exploration-20260702 v2 (`param_schema` rationale, §"Data layer") and exploration-20260625 v1 (component taxonomy, §"Composition model").

---

## 0. Hard constraints (read first)

From `M1.9_Breakdown.md` (S2 + scope guardrails) and the v2 exploration's non-negotiables:

- **All-off `RunConfig` fingerprint `e943ac9c8bc1` byte-identical.** Hazard entities never feed `fingerprint()` (placement is pure run-state), so the fp check guards the *seam*, not the entities — the entity-level parity burden falls on the test suite (§2.3).
- **Full hazard test suite green, unchanged** — `test_pursuing_hazard`, `test_pingpong_hazard`, `test_bomb_hazard`, `test_spike_hazard`, `test_hazard_spread`, `test_new_hazard_spawn`, `test_per_room_density`, `test_throw_mechanic`, and every `test_rg1_m1*_verify` + `test_rg1_loop_verify`. The tests are the acceptance oracle; **no test may be edited to pass** (a test edit is a red flag, not a fix). Run as SCENES, one `godot --headless` at a time (import-lock memory).
- **BUG6 rising-edge latch, L5 `*_kills` semantics, and the `setup()` config-snapshot discipline preserved verbatim** (`hazard_entity.gd:236-240`, `:319-323`, `:119-128`). Same emit counts, same kill frame, same gating.
- **Locked `setup(cfg, player, spawn_ctx)` handshake unchanged** — the K5 family signature is a cross-cutting lock; S0's `SpawnService` and the legacy seams both call it. Components live *below* it.
- **`params` ↔ `param_schema` bijection check required** for all 4 defs (test or lint; §3.4).
- **No `main_game.gd` change.** S2 runs Wave 2; `main_game.gd`'s sole writers are S0 (Wave 1) and S3 (Wave 3). The legacy spawn seams (`_spawn_new_hazards`/`_spawn_r1_hazards`, as relocated by S0) keep driving spawning untouched.
- **No `event_bus.gd` change.** S0 pre-declared `opposition_event`/`opposition_killed_player` in Wave 1; S2 only *emits* pre-declared signals.
- **Legacy R1/K5 `RunConfig` `@export` groups stay untouched** (the exploration's migration contract) — no knob added, removed, or renamed; the 89-row `config_menu.gd` coverage assertion must still pass byte-for-byte.
- **Typed GDScript everywhere; worklog + commit SHA + Design-deviations section** per the work-product contract.

---

## 1. Goal & design intent

**One sentence:** *turn the four bespoke hazard scripts into thin hosts over a shared component vocabulary, and give every def the self-describing `params` + `param_schema` table, so that S6a's Charger is "def + one movement component" and S4's debug menu can be generated instead of hand-authored — while a player, the telemetry log, and the test suite cannot tell anything changed.*

S2 is the load-bearing middle of the opposition migration: S0 made the 4 hazards *addressable as data* (`OppositionDef.tres` with `host_scene` = the current `.tscn`); S2 makes their *behavior* reusable and their *knobs* reflectable. Everything M1.9 must prove ("adding content is data, not engineering") depends on the component set extracted here actually covering the 4 shipped entities plus the two planned proofs (Charger, Splitter) — no more, no less.

**Design intent in one line (deviation detector):** internals-only refactor — observable behavior, telemetry rows, signal payloads, kill frames, and every `.tres`/knob surface are byte/frame-identical; the only new artifacts are component scripts, completed defs, and the schema test.

---

## 2. Research

### 2.1 As-built anatomy of the four entities (the exact internals being extracted)

All four share the family shape: host node + `Tell` `Polygon2D` child(ren), `setup(cfg, player, spawn_ctx)` snapshot, per-frame guard `if _player == null or _cfg == null or not is_instance_valid(_player): return`, a self-timed run clock (`_time_in_band`/`_spawn_time`/`_time_alive`/`_alive_time` → `run_t_ms`), a script distance-test kill (never physics overlap), a BUG6-pattern one-shot telemetry latch, and the L5 `*_kills`-gated `GameState.fail_run(&"death")` with emit-always. Scenes are minimal (`scenes/hazards/*.tscn`: root + Tell (+ CollisionShape2D for the two CharacterBody2D hosts), `groups=["hazard"]`, layer 16/mask 2).

#### HazardEntity — the R1 pursuer (`Game/scenes/hazards/hazard_entity.gd`, host `CharacterBody2D`)

| Concern | Where | What it does |
|---|---|---|
| Config snapshot | `setup()` `:119-131` | snapshots `_cfg`, resolves `_player`, resets all state (`_caught_latched = false` `:125`), reads `spawn_ctx["room_bounds"]` `:126`, derives patrol endpoints `:128` |
| Trigger (awaken) | `_should_awaken()` `:293-300`, `_awaken()` `:305-308` | DORMANT→AWAKE latch: live depth (`GameState.current_depth_index`) ≥ `r1_depth_threshold` OR `_time_in_band` ≥ `r1_linger_seconds` (>0); records `_pending_trigger` (&"depth"/&"linger"); emits `hazard_awoke(depth, trigger)` once; never re-sleeps |
| Movement (chase) | `_chase()` `:195-240` | live speed = `r1_chase_speed + r1_speed_per_depth * depth` `:197`; straight steer + `move_and_slide()`; anti-wall-stick de-pin (`STALL_FRACTION` `:57`, tangent steer `:214-223`) |
| Movement (patrol) | `_patrol()` `:249-265`, endpoints `:138-151`, clamp `:271-276` | L2 room-bound pacer: RNG-free left-mid↔right-mid endpoints inset `PATROL_EDGE_MARGIN`; `r1_patrol_speed`; re-arms the catch latch `:252`; `r1_spawn_room_only` + non-empty bounds gates the chase/patrol split `:178-189` |
| Lethality + latch | `:225-240`, `_on_catch()` `:314-323` | effective radius = `r1_catch_radius + r1_catch_radius_per_depth * depth` `:228`; **BUG6 rising-edge latch** `:236-240` (emit once on entry, re-arm on exit); `hazard_caught(depth, run_t_ms)` emit-always; **L5**: `r1_catch_kills` gates `fail_run(&"death")` `:319-321`; non-fatal path = knockback/stun/cooldown consts `:39-41`, `:330-339` |
| Telegraph / tell | `:32-33`, `:344-358` | dormant grey-blue → awake alarm-red + one-shot wake-flash Tween |
| State telemetry | `_emit_pursuer_state()` `:283-288` | rising-edge-only `hazard_pursuer_state(state, depth, run_t_ms)` on patrol↔chase flips (room-bound mode only) |

#### PingPongHazard (`pingpong_hazard.gd`, host `CharacterBody2D`)

| Concern | Where | What it does |
|---|---|---|
| Config snapshot | `setup()` `:63-74` | snapshots `_cfg`, `_speed = maxf(cfg.hpp_speed, 0)`, reads `spawn_ctx["initial_dir"]` (default RIGHT) + `["room_bounds"]`; live from spawn — no trigger |
| Movement | `:77-110` | **BUG8 heading-source-of-truth**: `velocity = _dir * _speed` → `move_and_slide()` → reflect **`_dir`** off the *summed* slide normals (corner resolve), only when `dot < 0`; squash juice on bounce `:169-174` |
| Room clamp | `_confine_to_room()` `:153-162` | reflect the perpendicular component of `_dir` (not just velocity) + snap inside; no-op on empty rect |
| Lethality + latch | `:119-129`, `_on_contact()` `:134-143` | fixed `CONTACT_RADIUS = 24.0` const `:30`; BUG6 latch `_killed_latched`; `new_hazard_killed(&"pingpong", depth, run_t_ms)` emit-always; L5 `hpp_kills` gate `:142` |
| Telegraph / tell | `:24`, `:73-74` | constant amber; motion is the telegraph |

#### BombHazard (`bomb_hazard.gd`, host `Node2D` — no collision at all)

| Concern | Where | What it does |
|---|---|---|
| Config snapshot | `setup()` `:61-69` | snapshots `_cfg`; **ignores `spawn_ctx`**; draws the idle ring sized to `hbomb_proximity_radius` `:68` |
| Trigger | IDLE branch `:78-84` | rising edge into `hbomb_proximity_radius` (0 = inert) → `_arm()` |
| Telegraph FSM | `enum State {IDLE, PULSING, EXPLODED}` `:36`; `_arm()` `:96-101`; PULSING `:85-90` | committed/no-defuse; detonation driven by accumulated `_pulse_t ≥ hbomb_pulse_seconds` (**never** a tween callback — headless-safe); `bomb_pulse_started(depth, run_t_ms)` on arm; accelerating throb tween = juice only `:151-160` |
| Lethality | `_detonate()` `:109-125` | one distance test at the detonation frame vs `hbomb_blast_radius`; hit → `new_hazard_killed(&"bomb", …)` emit-always + L5 `hbomb_kills` gate `:121`; fizzle emits nothing; one-shot `queue_free` after the flash `:125`. No latch needed — the FSM is terminal (EXPLODED) |

#### SpikeHazard (`spike_hazard.gd`, host `Node2D` — no collision at all)

| Concern | Where | What it does |
|---|---|---|
| Config snapshot | `setup()` `:58-72` | snapshots `_omega = deg_to_rad(cfg.hspike_rotation_speed)`, `_arm_length`; deterministic phase from `spawn_ctx["phase_salt"]` (`posmod(salt*47, 360)` `:67-68`, never RNG); rebuilds the 3-arm tell |
| Movement (spin) | `:80-82` | `_angle = wrapf(_angle + _omega*delta)`; `rotation = _angle` (the rotation IS the telegraph) |
| Lethality + latch | `:88-101`, `_is_player_on_any_arm()` `:107-116` | analytic capsule test: player point vs each arm segment (`Geometry2D.get_closest_point_to_segment`), kill radius `PLAYER_RADIUS + KILL_PAD = 20` `:34-35`; `_killed_emitted` latches **permanently** (RD-3: no re-arm — deliberately different from the pingpong latch); `new_hazard_killed(&"spike", …)` emit-always; L5 `hspike_kills` gate `:100` |
| Tell | `_rebuild_tell()` `:127-142` | per-arm quad islands (the invisible-blade fix); `ARM_COUNT = 3` locked const `:30` |

#### Cross-entity seams that constrain the refactor

- **Throw-kill lives OUTSIDE the entities**: `thrown_item.gd:79-92` — group check + `body.queue_free()`; the telemetry kind comes from **typed root checks** `body is HazardEntity` / `body is PingPongHazard` (`:112-115`). ⇒ the `class_name`s **must stay on the host roots** and the roots must stay in the `hazard` group, or throw telemetry silently degrades to the name-fallback.
- **The spawn seam builds per-kind `spawn_ctx`** (`main_game.gd:496-507`, relocated by S0 but semantically identical): pingpong `initial_dir` (golden-angle fan) + `room_bounds`; spike `phase_salt = depth_index*131 + k`; bomb `{}`; R1 J2/J3 paths pass `{"room_bounds": …}` (`:569`, `:606`).
- **RunConfig knob groups** (all legacy, untouched): R1 `run_config.gd:57-126` (17 knobs — 8 entity-read, 9 spawn/density policy), K5a `:298-312`, K5b `:319-337`, K5c `:345-361`. `R1_DENSITY_BAND_CEILING = 64` (`run_config.gd:37`) and `NEW_HAZARD_BAND_CEILING = 48` (`main_game.gd:337`) are S0's unification concern, not S2's.
- **ConfigMenu ranges** to mirror into `param_schema` min/max: `config_menu.gd:33-55` (`RANGE_DEPTH (0,10)`, `RANGE_SPEED (0,120)`, `RANGE_SECONDS (0,30)`, `RANGE_RADIUS (0,64)`, `RANGE_MAGNITUDE (0,100)`, `RANGE_COUNT_SMALL (0,10)`, `RANGE_PER_DEPTH (0,5)`, `RANGE_ROOM_CAP (0,16)`, `RANGE_ROTATION (-360,360)`), bound per-field at `:210-273`.
- **Signals** (all pre-declared; S2 edits nothing): `hazard_awoke`/`hazard_caught` `event_bus.gd:89-90`, `new_hazard_killed` `:149`, `bomb_pulse_started` `:151`, `throw_killed_hazard` `:175`, `hazard_pursuer_state` `:181`, plus S0's `opposition_event`/`opposition_killed_player`.

### 2.2 The component set (build ONLY these)

Derived strictly from what the 4 entities above + the two planned Wave-4 hazards need. v1's full taxonomy (Burrow, Leap, Flock, Drift, SightlineTrigger, BagValueTrigger, TimerTrigger, Emitter, SpawnRule…) is **explicitly not built** — Emitter/projectiles are ranged-hazard surface (no ranged hazard this version), SpawnRule's death-spawn is S6b's tiny client code, LimboAI stays in reserve.

| Component (`class_name`) | Extracted from | Reused by | Contract (params it reads) |
|---|---|---|---|
| **`ChaseMove`** | R1 `_chase()` incl. de-pin (`hazard_entity.gd:195-223`) | R1; Splitter (slow pursuit variant, S6b Director-pending) | `chase_speed`, `speed_per_depth`; in-file `STALL_FRACTION` const moves with it |
| **`PatrolMove`** | R1 `_patrol()` + endpoints + clamp (`:138-151`, `:249-276`) | R1 room-bound mode; candidate Splitter idle | `patrol_speed`; `room_bounds` from spawn_ctx; consts `PATROL_EDGE_MARGIN`/`PATROL_ARRIVE_EPS` move with it |
| **`StraightBounceMove`** | pingpong travel+bounce+clamp (`pingpong_hazard.gd:77-117`, `:153-162`) | pingpong only (today) — but it is the closest cousin of S6a's dash | `speed`; `initial_dir`/`room_bounds` from spawn_ctx; BUG8 heading-source-of-truth semantics preserved verbatim |
| **`SpinMove`** | spike rotate (`spike_hazard.gd:80-82`) + phase seed (`:67-68`) | spike only | `rotation_speed`; `phase_salt` from spawn_ctx |
| **`DepthLingerTrigger`** | R1 awaken (`hazard_entity.gd:293-308`) | R1; Charger could reuse it as a proximity-free arm gate (S6a's call) | `depth_threshold`, `linger_seconds`; emits the awaken beat via the host (see §3.1 event routing) |
| **`ProximityTrigger`** | bomb IDLE arm test (`bomb_hazard.gd:78-84`) | bomb; **Charger** (S6a: proximity/sightline arm before the telegraph) | `proximity_radius` (or per-def key alias; 0 = inert) |
| **`TelegraphFSM`** | bomb PULSING→EXPLODED timing + tells (`bomb_hazard.gd:85-101`, `:136-160`) and R1's dormant/awake tell flip (`hazard_entity.gd:344-358`) | bomb, R1; **Charger** (telegraph→dash→recover is exactly this FSM with one more state) | `pulse_seconds` (per-def key names differ); owns Tell coloring/tween juice; **all state advancement time-accumulator-driven, tweens juice-only** (the headless-safe rule) |
| **`LethalContact`** | all four kill paths + latches (`hazard_entity.gd:225-240,314-339`; `pingpong_hazard.gd:119-143`; `bomb_hazard.gd:109-125`; `spike_hazard.gd:88-116`) | all 4 + Charger + Splitter | test modes: `radius` (pursuer/pingpong; per-frame), `arm_segments` (spike; reads `SpinMove`'s angle), `on_command` (bomb; `TelegraphFSM` invokes the one-frame test). Owns: the BUG6 latch (incl. the spike's no-re-arm variant and R1's cooldown conjunction), emit-always telemetry, the **L5 `kills` gate → `GameState.fail_run(&"death")`**, and R1's non-fatal knockback/stun/cooldown branch |
| **`ThrowInteraction`** | today implicit in `thrown_item.gd:88-93` (`queue_free` = "die") | all 4 (mode `die`, byte-identical); **Splitter** (S6b overrides the death hook to call `svc.spawn(child_def, …)`) | mode (`die` only in S2); exposes `on_thrown_hit(item_id)` so S6b needs zero `thrown_item.gd` edits (see Open Question 5) |

Nine small blocks, each 30–90 lines, each a direct transplant of code that already exists and is already test-covered. **S6a's `ChargeLane` is NOT built in S2** — it is the Phase-E proof that the vocabulary is sufficient; S2 only guarantees `TelegraphFSM` + `LethalContact` + `ThrowInteraction` are genuinely reusable so Charger = def + one new movement component.

The in-file greybox feel constants (`NONFATAL_*`, `STALL_FRACTION`, `PATROL_*`, `CONTACT_RADIUS`, `ARM_COUNT`, `ARM_HALF_WIDTH`, colors, squash/tween timings) **move with their component as consts and do NOT enter `params`/`param_schema`** — the schema mirrors today's *knobs* exactly; promoting a const to a knob is knob-count growth and a separate Director call (see Open Question 7).

### 2.3 Risk analysis — why this is the riskiest step, and how the tests gate it

**Why riskiest.** Every other migration phase moves *where* code runs (S0: relocation behind an API; S3: policy math into a builder) with byte-level acceptance oracles (`fingerprint()`, golden position lists). S2 rewrites the **per-frame internals of four lethal entities simultaneously**, and the failure modes are exactly the ones this codebase has already paid for once each:

1. **Frame-order drift.** Splitting one `_physics_process` into component `tick()`s can reorder operations (move-then-test vs test-then-move; latch update before vs after cooldown decrement). A one-frame shift in the kill frame silently changes `run_ended.duration_s` and death telemetry — invisible to the fp check, visible only to a frame-exact test. (The BUG6 fix's whole point was that the fatal-catch *frame* is byte-identical; a careless extraction can undo it while every signal still fires "once".)
2. **Latch semantics divergence.** Three different latch flavors exist deliberately: pursuer (re-arm on radius exit, conjunction with `_catch_cooldown` `:236`, **plus patrol re-arms it** `:252`), pingpong (re-arm on contact exit), spike (permanent, RD-3). A "unified" latch that re-arms the spike or drops the pursuer's cooldown conjunction changes emit counts — the exact storm class BUG6 killed (85→2,199 events/run).
3. **Float-path drift.** `velocity = dir * speed; move_and_slide()` transplanted with a different intermediate (e.g. normalizing where the original didn't, or reflecting post-slide velocity instead of `_dir` — the exact BUG8 regression) shifts trajectories. Rule: **movement math is transplanted verbatim, operation-for-operation** — the diff of extracted-function bodies against the originals should be whitespace/`self`→`host` only.
4. **Snapshot discipline breaks.** A component that reads `GameState.active_run_config` (or holds a `RunConfig` ref it re-reads late) reintroduces the run-end mid-frame null crash the snapshot exists to prevent (`hazard_entity.gd:119-128` doc). Components must receive **resolved values**, not live config (§3.1).
5. **Type identity breaks.** Moving the script off the root, renaming `class_name`s, or re-rooting scenes breaks `thrown_item.gd:113-115`'s typed checks and every test that `instantiate() as PingPongHazard`.
6. **Double-driving.** If components read def `params` while the legacy knobs still drive, a def authored at preset values (not code defaults) would change behavior under all-off/preset configs. S2's rule: **legacy knobs are the sole behavior source; defs mirror** (§3.3, Open Question 2).

**How the tests gate it.** The suite is unusually strong here precisely because each behavior was regression-hardened when first built:

- `test_pursuing_hazard` — awaken triggers (depth/linger), chase math, catch + BUG6 latch single-emit, non-fatal path, patrol gating.
- `test_pingpong_hazard` — empty-ctx safe construction, initial-dir velocity, room-rect reflect+snap, kill-once (latch), **no-RNG source scan** (the script-source grep must now also sweep the component scripts — the one test-side *addition* S2 makes, flagged in the worklog).
- `test_bomb_hazard` — arm on proximity rising edge, committed pulse, `_pulse_t`-driven detonation frame, blast vs fizzle, L5 gate.
- `test_spike_hazard` — analytic arm hit (pure function), deterministic phase from salt, permanent latch, L5 gate.
- `test_new_hazard_spawn` + `test_hazard_spread` + `test_per_room_density` — the seam contract (counts, caps, ceiling, per-kind spawn_ctx, byte-identical position plans). S2 doesn't touch the seam; these prove it.
- `test_throw_mechanic` — throw-kill + `throw_killed_hazard` kind continuity (guards risk 5 and the ThrowInteraction seam).
- `test_rg1_m12/m13/m14/m15_verify` + `test_rg1_loop_verify` — end-to-end preset cohorts and telemetry row shapes.
- All-off fp `e943ac9c8bc1` + import + smoke — the standing floor.

**One new gate S2 adds (recommended, cheap): a golden frame-trace parity harness.** Before refactoring, capture per-entity traces (N≈300 physics frames of `global_position`/state/emit-log under a fixed cfg + scripted player path, per entity type) using the *current* scripts; after, assert the refactored entities reproduce them exactly. This closes the gap the existing tests leave (they assert semantics at key frames, not the whole trajectory) and directly detects risks 1–3. It can live inside `test_opposition_components.gd` and be dropped post-gate if it proves brittle. If the traces cannot be made to match exactly, that is a **deviation to surface**, not a tolerance to widen silently.

---

## 3. Pseudocode

### 3.1 Component base contract (the snapshot discipline, made structural)

Components are `Node` children with **no `_physics_process` of their own**; the host remains the only physics ticker and calls components in an explicit, fixed order — this is what makes frame-order parity provable (risk 1) and keeps per-entity cost one `_physics_process` callback, same as today.

```gdscript
# scenes/hazards/components/opposition_component.gd  (illustrative)
class_name OppositionComponent extends Node
## Base for hazard behavior components. Components NEVER read
## GameState.active_run_config and NEVER hold a RunConfig — they are bound
## once, at host.setup(), with already-RESOLVED primitive values (the config-
## snapshot discipline made structural: run-end clearing active_run_config
## cannot reach a component, because a component only ever saw floats/ints).

var host: Node2D                      # the entity root (CharacterBody2D / Node2D)
var player: Node2D                    # resolved once by the host at setup

## Bind resolved params + per-instance spawn context. `p` is a flat primitive
## Dictionary (§3.3 resolve order); `ctx` is the locked spawn_ctx pass-through.
func bind(host_: Node2D, player_: Node2D, p: Dictionary, ctx: Dictionary) -> void:
    host = host_
    player = player_
    _configure(p, ctx)                # subclass snapshots ITS keys into typed fields

func _configure(_p: Dictionary, _ctx: Dictionary) -> void: pass
func tick(_delta: float) -> void: pass    # called by the HOST, in fixed order
```

Host-side pattern — the locked `setup()` signature is untouched; the guard, the self-clock, and the tick order stay in the host so the per-frame skeleton is diff-ably identical to today's:

```gdscript
# The generic host shape (each of the 4 keeps its class_name + root script)
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
    _cfg = cfg                                   # snapshot kept — L5 gates + tests read it
    _player = player
    var p := _resolve_params(cfg)                # §3.3: S2 = legacy knobs ONLY
    for c in _components:                        # fixed order, mirrors the old inline order
        c.bind(self, player, p, spawn_ctx)

func _physics_process(delta: float) -> void:
    if _player == null or _cfg == null or not is_instance_valid(_player):
        return                                   # the family guard, verbatim
    _clock += delta
    for c in _components:                        # e.g. pingpong: [move, lethal]
        c.tick(delta)
```

**Event routing:** components emit through small host callbacks (`host._on_lethal_contact(depth, run_t_ms)`) or directly on `EventBus` with values the host supplies — but the **emit site keeps the exact legacy signal + payload** (`hazard_caught`, `new_hazard_killed(&"pingpong", …)`, `bomb_pulse_started`, `hazard_pursuer_state`), and additionally dual-emits the S0-pre-declared generic `opposition_event(def_id, event, depth, run_t_ms)` / `opposition_killed_player(def_id, depth, run_t_ms)` (no Telemetry subscriber until S4 ⇒ zero new rows now — see Open Question 6). The self-timed run clock stays host-owned so both signal families share one timestamp.

### 3.2 Worked example — PingPongHazard rebuilt as host + components

```gdscript
# scenes/hazards/pingpong_hazard.gd  (AFTER — root script + class_name UNCHANGED,
# .tscn untouched; components composed in code — Open Question 4)
class_name PingPongHazard extends CharacterBody2D

var _cfg: RunConfig
var _player: Node2D
var _clock: float = 0.0
var _move: StraightBounceMove
var _lethal: LethalContact
var _throw: ThrowInteraction          # mode "die" — behavior identical to today

func _ready() -> void:
    _move = StraightBounceMove.new();  add_child(_move)
    _lethal = LethalContact.new();     add_child(_lethal)
    _throw = ThrowInteraction.new();   add_child(_throw)

func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
    _cfg = cfg; _player = player; _clock = 0.0
    var p := {                                    # S2 resolve: LEGACY KNOBS ONLY
        "speed": maxf(cfg.hpp_speed, 0.0) if cfg != null else 0.0,
        "contact_radius": 24.0,                   # CONTACT_RADIUS const, moves into LethalContact
        "kills": cfg.hpp_kills,                   # the L5 gate value, resolved at snapshot time
        "telemetry_kind": &"pingpong", "def_id": &"pingpong",
    }
    _move.bind(self, player, p, spawn_ctx)        # reads initial_dir + room_bounds from ctx
    _lethal.bind(self, player, p, spawn_ctx)      # mode "radius"; latch reset here (re-setup safe)
    _throw.bind(self, player, p, spawn_ctx)
    if _tell != null: _tell.color = COLOR_LIVE    # trivial constant tell — no TelegraphFSM needed

func _physics_process(delta: float) -> void:
    if _player == null or _cfg == null or not is_instance_valid(_player):
        return
    _clock += delta
    _move.tick(delta)      # velocity=_dir*_speed → move_and_slide → BUG8 reflect → clamp  (verbatim)
    _lethal.tick(delta)    # radius test → BUG6 latch → emit-always → kills-gated fail_run (verbatim)
```

```gdscript
# scenes/hazards/components/lethal_contact.gd  (illustrative core — the shared block)
class_name LethalContact extends OppositionComponent
var _mode: StringName          # &"radius" | &"arm_segments" | &"on_command"
var _radius: float; var _kills: bool; var _kind: StringName; var _def_id: StringName
var _latched: bool = false; var _rearm: bool = true      # spike: _rearm=false (RD-3, permanent)
var _cooldown: float = 0.0                               # pursuer non-fatal path only

func tick(delta: float) -> void:
    if _mode != &"radius": return                        # arms/on_command variants elsewhere
    if _cooldown > 0.0: _cooldown -= delta               # order preserved from hazard_entity.gd:165
    var hit := host.global_position.distance_to(player.global_position) <= _radius
    if hit and not _latched and _cooldown <= 0.0:        # the BUG6 conjunction, verbatim
        _latched = true
        _emit_and_resolve()                              # emit-always → if _kills: GameState.fail_run(&"death")
    elif not hit and _rearm:
        _latched = false                                 # re-arm on the falling edge only
```

The pursuer is the maximal case: `[DepthLingerTrigger, ChaseMove, PatrolMove, LethalContact(radius, cooldown+nonfatal), TelegraphFSM(dormant/awake tell), ThrowInteraction(die)]`, with the host keeping the DORMANT gate + the chase/patrol mode switch (`hazard_entity.gd:159-189`'s exact branch structure) as ~15 lines of orchestration. The bomb: `[ProximityTrigger, TelegraphFSM(IDLE/PULSING/EXPLODED), LethalContact(on_command), ThrowInteraction(die)]`. The spike: `[SpinMove, LethalContact(arm_segments, no-re-arm), ThrowInteraction(die)]`.

### 3.3 `params` + `param_schema` — resolve order and the four completed defs

**S2 coexistence rule (the no-double-driving contract):** the legacy R1/K5 knobs remain the **sole behavior source** — `_resolve_params(cfg)` reads only `cfg.*`. The defs' `params` are authored to **mirror the RunConfig *code defaults*** (the all-off values, `RunConfig.new()`), and `param_schema` mirrors each knob's type/default/`FIELD_RANGE` bounds/gloss key. Nothing reads `params` at runtime in S2; S3 flips `_resolve_params` to `def.params` + `RunConfig.param_overrides` with the legacy knobs mapped in by the default populator (preset parity is S3's acceptance bar). A **mirror-parity assertion** (§3.4) keeps the two surfaces from drifting during the one wave they coexist unused.

Def files (S0's, completed here): `Game/data/oppositions/pursuer.tres`, `pingpong.tres`, `bomb.tres`, `spike.tres`. Ids = the existing telemetry kinds (`&"pursuer"` per `thrown_item.gd:114`, `&"pingpong"`/`&"bomb"`/`&"spike"` per the `new_hazard_killed` rows) so id continuity is free when the generic signals take over.

Placement of each legacy knob (three destinations, stated per knob below):
- **typed def field** — archetype-contract values the service/lethality read uniformly: `kills` (the L5 gate), `per_room_cap` (the S0 cap field). Not in `params` (no double-representation; the bijection check covers `params` only).
- **`params` + schema entry** — entity-read behavior knobs, plus the two spawn-card counts (`base_count`, `count_per_depth`) that the S3 builder will read (inert in S2, marked below).
- **stays RunConfig-only** — `*_enabled` masters (they become `oppositions_enabled` membership in S3) and R1's J2/J3 spawn/density policy family (see Open Question 3).

#### `pursuer.tres` — params (8) + schema  *(kills → typed field, default `false` — mirrors `r1_catch_kills`)*

| key | type | default | min | max | gloss (reuse existing CSV key) | mirrors |
|---|---|---|---|---|---|---|
| `depth_threshold` | int | 0 | 0 | 10 | `CFG_GLOSS_R1_DEPTH_THRESHOLD` | `r1_depth_threshold` |
| `linger_seconds` | float | 0.0 | 0.0 | 30.0 | `CFG_GLOSS_R1_LINGER_SECONDS` | `r1_linger_seconds` |
| `chase_speed` | float | 0.0 | 0.0 | 120.0 | `CFG_GLOSS_R1_CHASE_SPEED` | `r1_chase_speed` |
| `speed_per_depth` | float | 0.0 | 0.0 | 100.0 | `CFG_GLOSS_R1_SPEED_PER_DEPTH` | `r1_speed_per_depth` |
| `catch_radius` | float | 0.0 | 0.0 | 64.0 | `CFG_GLOSS_R1_CATCH_RADIUS` | `r1_catch_radius` |
| `catch_radius_per_depth` | float | 0.0 | 0.0 | 100.0 | `CFG_GLOSS_R1_CATCH_RADIUS_PER_DEPTH` | `r1_catch_radius_per_depth` |
| `spawn_room_only` | bool | false | — | — | `CFG_GLOSS_R1_SPAWN_ROOM_ONLY` | `r1_spawn_room_only` |
| `patrol_speed` | float | 0.0 | 0.0 | 120.0 | `CFG_GLOSS_R1_PATROL_SPEED` | `r1_patrol_speed` |

*Excluded (policy — stays RunConfig until S3 designs the R1 populator mapping):* `r1_spawn_count`, `r1_spawn_distribution`, `r1_spread_min_depth`, `r1_per_room_density`, `r1_density_metric`, `r1_density_rooms_only`, `r1_density_min_area`, `r1_density_per_room_cap` (+ `r1_enabled`). `per_room_cap` typed field = 0 (R1 has no K5-style per-room cap today; its `r1_density_per_room_cap` is a *density-path* cap and stays with that path).

#### `pingpong.tres` — params (3) + schema  *(kills → typed, `true`; per_room_cap → typed, `0`)*

| key | type | default | min | max | gloss | mirrors |
|---|---|---|---|---|---|---|
| `base_count` | int | 0 | 0 | 10 | `CFG_GLOSS_HPP_BASE_COUNT` | `hpp_base_count` *(builder-read; inert in S2)* |
| `count_per_depth` | float | 0.0 | 0.0 | 5.0 | `CFG_GLOSS_HPP_COUNT_PER_DEPTH` | `hpp_count_per_depth` *(builder-read; inert in S2)* |
| `speed` | float | 0.0 | 0.0 | 120.0 | `CFG_GLOSS_HPP_SPEED` | `hpp_speed` |

#### `bomb.tres` — params (5) + schema  *(kills → typed, `true`; per_room_cap → typed, `0`)*

| key | type | default | min | max | gloss | mirrors |
|---|---|---|---|---|---|---|
| `base_count` | int | 0 | 0 | 10 | `CFG_GLOSS_HBOMB_BASE_COUNT` | `hbomb_base_count` *(inert)* |
| `count_per_depth` | float | 0.0 | 0.0 | 5.0 | `CFG_GLOSS_HBOMB_COUNT_PER_DEPTH` | `hbomb_count_per_depth` *(inert)* |
| `proximity_radius` | float | 0.0 | 0.0 | 64.0 | `CFG_GLOSS_HBOMB_PROXIMITY_RADIUS` | `hbomb_proximity_radius` |
| `pulse_seconds` | float | 0.0 | 0.0 | 30.0 | `CFG_GLOSS_HBOMB_PULSE_SECONDS` | `hbomb_pulse_seconds` |
| `blast_radius` | float | 0.0 | 0.0 | 64.0 | `CFG_GLOSS_HBOMB_BLAST_RADIUS` | `hbomb_blast_radius` |

#### `spike.tres` — params (4) + schema  *(kills → typed, `true`; per_room_cap → typed, `0`)*

| key | type | default | min | max | gloss | mirrors |
|---|---|---|---|---|---|---|
| `base_count` | int | 0 | 0 | 10 | `CFG_GLOSS_HSPIKE_BASE_COUNT` | `hspike_base_count` *(inert)* |
| `count_per_depth` | float | 0.0 | 0.0 | 5.0 | `CFG_GLOSS_HSPIKE_COUNT_PER_DEPTH` | `hspike_count_per_depth` *(inert)* |
| `rotation_speed` | float | 0.0 | -360.0 | 360.0 | `CFG_GLOSS_HSPIKE_ROTATION_SPEED` | `hspike_rotation_speed` |
| `arm_length` | float | 0.0 | 0.0 | 64.0 | `CFG_GLOSS_HSPIKE_ARM_LENGTH` | `hspike_arm_length` |

Schema entry shape (v2 exploration, verbatim): `{key, type ("bool"|"int"|"float"|"enum"), default, min, max, step?, gloss}` — `step` optional, defaulting per type like `FIELD_STEP` does today; `enum` entries add `options` (none needed for these 4 defs).

### 3.4 The bijection check (required) + mirror-parity (recommended)

```gdscript
# tests/test_opposition_def_schema.gd  (run as a SCENE, like every verify test)
# For EVERY .tres under res://data/oppositions/:
#  (1) BIJECTION: Set(def.params.keys()) == Set(schema entries' `key`) — no
#      unschema'd param, no orphan schema row (the config_menu.gd:414-455
#      coverage invariant, generalized per-def — fail-loud, per def, listing keys).
#  (2) TYPE/RANGE SANITY: typeof(params[key]) matches entry.type; default == params[key]
#      (in S2 the authored value IS the default); min <= default <= max.
#  (3) MIRROR PARITY (S2-only, drop at S3 flip): params defaults == the matching
#      RunConfig.new() knob values, per the mirror tables above — so the unused
#      def surface cannot drift from the live knob surface during Wave 2/3.
#  (4) HOST CONTRACT: def.host_scene loads; its root keeps the expected class_name
#      and the "hazard" group (guards thrown_item.gd:113-115 typed-kind continuity).
```

The standing Python `.tres` linter (the game-director-designer's cross-reference lint) should mirror check (1)+(2) at author time; the headless test is the CI gate.

---

## 4. Files to create / touch (expected shape — the worklog records actuals)

| File | Action |
|---|---|
| `Game/scenes/hazards/components/opposition_component.gd` | NEW — base contract (§3.1) |
| `Game/scenes/hazards/components/{chase_move, patrol_move, straight_bounce_move, spin_move, depth_linger_trigger, proximity_trigger, telegraph_fsm, lethal_contact, throw_interaction}.gd` | NEW — the nine components (§2.2) |
| `Game/scenes/hazards/{hazard_entity, pingpong_hazard, bomb_hazard, spike_hazard}.gd` | REWRITE internals → host + composition; `class_name`s, `setup()` signature, signals, consts-hosting unchanged where not moved |
| `Game/scenes/hazards/*.tscn` | **UNTOUCHED** (Open Question 4 recommendation) |
| `Game/data/oppositions/{pursuer, pingpong, bomb, spike}.tres` (+ `opposition_def.gd` if schema fields are missing from S0's minimal version) | COMPLETE `params` + `param_schema` (§3.3) |
| `Game/entities/thrown_item/thrown_item.gd` | MINIMAL — prefer-component dispatch with byte-identical fallback (Open Question 5; only if ratified) |
| `Game/tests/test_opposition_def_schema.{gd,tscn}` | NEW — §3.4 |
| `Game/tests/test_opposition_components.{gd,tscn}` | NEW (recommended) — golden frame-trace parity (§2.3) |
| `Game/tests/test_pingpong_hazard.gd` | ONLY the no-RNG source-scan sweep extended to component files (flag in worklog) |

Not touched: `main_game.gd`, `event_bus.gd`, `run_config.gd`, `config_menu.gd`, `game_state.gd`, any preset value, any signal payload.

## 5. Definition of done (restated, concrete)

1. `godot --headless --path Game --import` and the CI smoke test green.
2. All-off fingerprint **`e943ac9c8bc1`** byte-identical (the standing fp check).
3. Full hazard suite green **without test edits**: `test_pursuing_hazard`, `test_pingpong_hazard` (incl. the extended no-RNG scan), `test_bomb_hazard`, `test_spike_hazard`, `test_hazard_spread`, `test_new_hazard_spawn`, `test_per_room_density`, `test_throw_mechanic`, `test_rg1_m12/m13/m14/m15_verify`, `test_rg1_loop_verify` — run sequentially (never concurrent headless instances).
4. `test_opposition_def_schema` green: bijection + type/range + mirror-parity + host-contract for all 4 defs.
5. Golden frame-trace parity green for all 4 entity types (or a Director-surfaced deviation explaining any divergence).
6. `git diff --stat` shows **no** `main_game.gd` / `event_bus.gd` / `run_config.gd` / `config_menu.gd` change.
7. Preset behavior spot-check: one `make_default_play_preset()` run spawns the same cohort and produces the same telemetry row kinds as pre-refactor (the rg1 verifies substantially cover this; the worklog notes the check).
8. Worklog at `worklogs/<date>-S2-general-purpose.md` naming the commit SHA + a Design-deviations section; board mirrored.

---

## Open Questions

1. **Components as child `Node`s vs `RefCounted` strategy objects?** Nodes: `.tscn`-authorable (S6a/S7 can compose a new hazard in the editor, the "content is data" story), visible in the remote tree while debugging, owner-freed with the host; cost = ~3–6 extra nodes per instance (worst case ≈ 112 live hazards under both ceilings ⇒ ~500 extra idle nodes — negligible when they have **no** `_process`/`_physics_process` of their own). RefCounted: cheapest, but invisible to the editor/inspector, not `.tscn`-composable, and needs manual lifecycle care. **Recommendation:** child `Node`s **without their own physics callbacks** — the host explicitly `tick()`s them in fixed order (determinism + frame-order parity, §3.1). Revisit RefCounted only if SG2's worst-case body-count tick-time measurement flags node overhead (it won't at these counts).

2. **How exactly do `params` and the legacy knobs coexist without double-driving in S2?** Options: (a) legacy knobs stay the sole source, defs mirror inertly (this doc, §3.3) — zero behavior risk, one wave of duplicated-but-asserted surface; (b) flip entities to read `def.params` now with the legacy knobs copied in at spawn — makes S2 also a data-flow change and moves S3 risk earlier, violating "one risky thing per wave"; (c) per-key fallback (`params` if present else knob) — worst of both, silent divergence. **Recommendation: (a)**, enforced by the mirror-parity assertion (§3.4 check 3), which is deleted when S3 flips the resolve order. The one wrinkle: the *preset* sets non-default knob values at runtime — that's fine, because in S2 params are never read; mirror-parity is against **code defaults** only.

3. **Does `hazard_entity.gd` (R1) migrate in S2, or is R1 deferred?** R1 is the biggest entity (359 lines), has the only non-fatal path, and — unlike the K5 trio — its *spawning* rides its own J2 spread + J3 density paths with a separate ceiling (`_spawn_r1_hazards`, `main_game.gd:534-606`; `R1_DENSITY_BAND_CEILING`, `run_config.gd:37`). Deferring it would shrink S2's blast radius but leave `ChaseMove`/`PatrolMove`/`DepthLingerTrigger`/the non-fatal `LethalContact` branch unextracted — exactly the blocks S6a/S6b lean on — and would leave M1.9 shipping a half-migrated roster into S4's generated menu. **Recommendation: migrate R1's entity internals in S2** (it is `spawn_ctx`-driven behavior like the others; its per-frame code transplants the same way), while its **J2/J3 spawn/density policy family explicitly stays RunConfig-only** (§3.3 exclusion list) — that policy's def/builder mapping is S3's design, and its density *path* may legitimately outlive the builder as R1-specific populator code. The pursuer def ships entity-params-only; the worklog flags the policy family as deliberately unmapped.

4. **Scene-structure churn — are the `.tscn`s rewired to hold component children, or do scripts compose internally?** Rewiring the scenes puts components in the editor (nice authoring story) but churns 4 `.tscn` uids/structure, risks the typed-root checks, and makes the diff noisy exactly where parity review needs it quiet. **Recommendation: scripts compose in `_ready()` in S2; all four `.tscn`s byte-untouched.** The base contract should *also* adopt `.tscn`-declared component children when present (discover-by-type before instancing defaults), so S6a/S6b hosts may be authored either way — the legacy four just don't exercise that path this wave.

5. **Does the `ThrowInteraction` seam (the one edit outside `scenes/hazards/`) land in S2 or wait for S6b?** Today throw-death is `thrown_item.gd` calling `body.queue_free()` (`:88-93`); Splitter needs a death hook on the entity side. If S2 doesn't land the dispatch (`if body.has_method("on_thrown_hit"): body.on_thrown_hit(item_id) else: queue_free()` with the component reproducing today's emit+free byte-identically), S6b — a Wave-4 parallel lane that owns only its new files — has no compliant way to get it. **Recommendation: land it in S2**, gated by `test_throw_mechanic` + the kind-continuity check (§3.4 check 4). Alternative if Phase-3 judges it scope-creep: S3 (the next sequential wave) carries the two-line dispatch instead.

6. **When does the generic dual-emit start — S2 (components emit both signal families) or S4 (with the subscriber migration)?** Emitting `opposition_event`/`opposition_killed_player` from the components now costs nothing observable (Telemetry has no subscriber until S4 ⇒ zero new rows; the breakdown's dual-emit contract is satisfied early) and avoids re-opening every component's emit site in S4 — the second-touch risk. **Recommendation: dual-emit from S2**, with `test_opposition_def_schema` (or the component test) asserting payloads are primitives-only and ids match def ids. Flag: SG1's telemetry-continuity check must confirm no row-count drift.

7. **Do any in-file feel constants get promoted to `params` while we're here?** (`CONTACT_RADIUS`, `NONFATAL_*`, `STALL_FRACTION`, `ARM_COUNT`, patrol margins…) Promoting them would make the S4 generated menu richer — but grows the knob surface mid-migration and breaks "params mirror today's knobs exactly." **Recommendation: no — consts move with their component unchanged**; promotion is a Director-gated S4/SG3 follow-up with its own schema rows and trap-detector entries.

8. **Def id for the R1 pursuer — `&"pursuer"` (the `throw_killed_hazard` kind, `thrown_item.gd:114`) vs `&"r1"`/`&"hazard"` (its config/test names)?** Telemetry continuity says the id that flows into the generic signals should be the kind analysts already group by. **Recommendation: `&"pursuer"`** — and SG2's deaths-by-id analysis inherits an unbroken series. Needs no Director call unless someone wants a rename, which would be a telemetry-series break (then it *is* a Director call).

---

*Phase-3 resolvers: questions 1, 2, 4, 6, 7, 8 are technical-merit calls (resolve with rationale); question 3 is scope-shaped (resolve, but flag the verdict in the resolution block for Director visibility since it moves S2's risk size); question 5 touches the single-writer-per-file discipline across waves (resolve against the wave map, flag if the S3-carry alternative is chosen).*
