# L2 — Spawn-room pursuer (#6) · Per-task design (Phase 2)

**Milestone:** M1.5 (Agency & Legibility). **Task id:** L2. **Wave:** 2.
**BlockedBy:** L0 (reads the new `r1_*` spawn-room knob(s) + emits the pursuer-state signal L0 declares).
**Role(s):** general-purpose (the HazardEntity branch) + game-director-designer (knob naming/defaults + the FEEL call).
**Author:** game-director-designer, Phase-2 fan-out (2026-06-24).
**Status:** Phase 2 draft — Open Questions below await Phase-3 fresh-eyes + Director disposition. NOT locked.

**Director-LOCKED semantics (do NOT re-open):** the pursuing hazard becomes a **room-bound slow patrol**. It
**patrols within its spawn room** and **chases the player only while the player is inside that spawn room**; when the
player is NOT in the spawn room it does **not** chase — it **keeps patrolling** (NOT despawn, NOT idle-freeze). The whole
behaviour is **knob-gated**: default off = today's chase-everywhere pursuer (byte-identical); the M1.5 play-preset turns
it on.

---

## (a) Research on the premise

### Why this change — the playtest finding

M1.4's RG3 gate (`design/M1_4_Tasks/G4_findings_M1.4.md` §#6) flagged the R1 pursuer as the loop's worst
*legibility* offender: an **always-on chaser** that the player can only ever run from, never reason about. Because the
hazard wakes globally (depth/linger trigger, `hazard_entity.gd:163` `_should_awaken()`) and thereafter homes on the
player *everywhere in the band* (`hazard_entity.gd:114-127`), the threat has no spatial logic the player can read: it is
not tied to a place, so there is no "I am safe here / dangerous there" mental model — only an undifferentiated dread that
follows you across rooms. Combined with M1.5's L1 (you can now *throw an item to kill a pursuer*), the threat needs to
become **comprehensible and place-bound** so the player can form a plan: "this room has the hunter; I can leave, or I can
turn and fight it." A **room-bound slow patrol** delivers exactly that — the danger is *located*, it is *slower* (so
out-running it inside the room is plausible and throwing at it is feasible), and *leaving the room is a real escape*. This
is the M1.5 thesis ("agency against danger + a comprehensible threat") expressed on the pursuer.

### The current pursuer — what we are branching on (real APIs)

`scenes/hazards/hazard_entity.gd` (`class_name HazardEntity extends CharacterBody2D`):

- **Spawn / bind:** `setup(cfg: RunConfig, player: Node2D)` — **two args only** (`hazard_entity.gd:83`). Snapshots the
  run config (`_cfg`), resolves the player (`_player`), seats the dormant tell. **Note the asymmetry with the K5 family**
  (see below): R1's `setup` has **no `spawn_ctx` third parameter** today, so it currently receives no room information.
- **Per-frame chase + catch** (`hazard_entity.gd:94-158`, `_physics_process`): when `AWAKE`, computes
  `speed = _cfg.r1_chase_speed + _cfg.r1_speed_per_depth * depth` (`:115`), steers `velocity = dir * speed` straight at
  the player and `move_and_slide()` (`:126-127`, walls on the `world` mask stop it — a deliberate refuge). The
  **distance-based catch test** (`:146-147`): `catch_r = r1_catch_radius + r1_catch_radius_per_depth*depth`, then
  `in_range = global_position.distance_to(_player.global_position) <= catch_r`. A rising-edge latch (`_caught_latched`,
  `:154-158`) fires `_on_catch()` once.
- **Catch outcome** (`_on_catch`, `:184-193`): always `EventBus.hazard_caught.emit(depth, run_t_ms)`; then if
  `_cfg.r1_catch_kills` → `GameState.fail_run(&"death")` (the existing fatal path; its `_run_ended` guard owns run-end
  idempotency — never add a local guard that *prevents* the call). Else `_apply_nonfatal_catch()` (knockback + stun +
  cooldown).
- **Collision:** body on layer `hazard` (5), masks `world` (2) only (`hazard_entity.gd:23-25`). Walls stop it; it does
  **not** mask `player` (catch is the script distance test) nor `hazard` (hazards pass through each other).
- **Tell:** `$Tell: Polygon2D`, `COLOR_DORMANT` grey-blue → `COLOR_AWAKE` alarm-red on wake (`:32-33`, `:214-228`).

### The prior art for room confinement — the K5 ping-pong (study this)

The M1.4 K5 hazards are **already room-confined**, and L2 should reuse their mechanism rather than invent one.
`scenes/hazards/pingpong_hazard.gd`:

- **`setup(cfg, player, spawn_ctx: Dictionary = {})`** (`pingpong_hazard.gd:63`) — the **LOCKED three-arg family
  signature** shared by all three M1.4 hazards. The ping-pong reads `spawn_ctx["room_bounds"]` (a `Rect2`, default empty)
  into `_room_bounds` (`:67`). **Empty `Rect2()` == "no clamp" (pure-wall confinement); non-empty == hard rect confine.**
- **The rect-confine** (`_confine_to_room`, `:148-157`): each frame, if `_room_bounds.has_area()`, test the body's
  `global_position` against `_room_bounds.position` / `.end`, reflect the heading and `clampf` the position back inside.
  This is the exact "keep an entity inside its spawn room's world-space rect" primitive L2 needs (for L2 it becomes a
  *clamp the patrol target/position* + *rect-contains test on the player*, not a bounce).

### Where `room_bounds` comes from — the spawn seam (real, already built)

`main_game.gd` builds `room_bounds` for the K5 family from the spawn piece's floor cells and threads it through
`spawn_ctx`:

- `_spawn_new_hazards()` (`main_game.gd:391`): per placed piece, computes
  `var room_bounds: Rect2 = _piece_floor_bounds_world(cells)` (`:449`), then
  `hz.setup(rc, player, _new_hazard_spawn_ctx(kind, p, k, spawned_total, room_bounds))` (`:457`).
- `_piece_floor_bounds_world(cells)` (`:487-493`): the encompassing `Rect2` of a piece's floor cells in **world space**,
  via the same `_density_cell_to_world` projection used for placement. Pure topology, no RNG. **This is the helper L2
  reuses** to learn a pursuer's spawn-room bounds.

**The R1 pursuer spawn seam** `_spawn_r1_hazards(rc, band)` (`main_game.gd:507-539`) and its density sibling
`_populate_room_density()` (`:552-560`) currently call `hz.setup(rc, player)` (**two-arg**, `:534`, `:558`) — they have
the placement piece/cell in hand at spawn time but **do not** compute or pass `room_bounds`. This is the crux of the
`main_game.gd`-seam question (OQ-1): to give the pursuer its spawn-room bounds we must either (i) widen these R1 spawn
calls to compute + pass bounds (touches `main_game.gd` — the L1/L2 single-writer concern), or (ii) derive bounds inside
the entity from its own `global_position` (no `main_game.gd` edit).

### The relevant R1 knobs (`data/run_config/run_config.gd`, `@export_group("R1 Pursuing Hazard", "r1_")`)

`r1_enabled` (`:59`), `r1_depth_threshold` (`:61`), `r1_linger_seconds` (`:63`), `r1_chase_speed` (`:65`),
`r1_speed_per_depth` (`:67`), `r1_catch_radius` (`:72`), `r1_catch_radius_per_depth` (`:77`), `r1_catch_kills` (`:79`),
`r1_spawn_count` (`:81`), `r1_spawn_distribution` (`:88`), `r1_spread_min_depth` (`:92`), `r1_per_room_density` (`:99`),
`r1_density_metric` (`:105`), `r1_density_rooms_only` (`:108`), `r1_density_min_area` (`:112`),
`r1_density_per_room_cap` (`:116`). Each appears in `to_flat_dict()` (`:416-433`). The default play-preset sets the live
values in `make_default_play_preset()` (`:626-654`, e.g. `r1_chase_speed = 56.0`). **L2 adds the new spawn-room
knob(s) here (off/neutral default), and L0 freezes the list + the new knob-count.** Contiguous-prefix house style: new
knobs are `r1_*`.

### Carried contracts grounding

- The behaviour is **knob-gated, default off = byte-identical** today's pursuer. Note the all-off fingerprint
  `e943ac9c8bc1` (`run_config.gd:626` preset header / breakdown §6) is **not moved by L2 in any case** — the pursuer is
  pure **run-state**: it is materialised after band grading, never feeds `fingerprint()` (same as the K5 entities,
  `pingpong_hazard.gd:17-19`). The knob default still matters for *behavioural* baseline parity, not for the fp.
- New signals are **L0-declared and additive** (a pursuer-state telemetry signal — see §b/OQ-7). `run_ended` arity is
  locked. **No save change** (run-state only).

---

## (b) Pseudocode (illustrative, against the real as-built APIs)

> All sketches are illustrative. The load-bearing decisions (does `main_game.gd` change? patrol pattern? re-entry?) are
> Open Questions below; the pseudocode shows the **recommended** shape and flags the branch points inline.

### B0. Knob read (L0 pre-declares; values are L2's recommendation, Director-sweepable)

```gdscript
# data/run_config/run_config.gd — added to the R1 group, off/neutral defaults (all-off baseline).
@export var r1_spawn_room_only: bool = false   # OFF = today's chase-everywhere; ON = room-bound patrol+gated chase
@export var r1_patrol_speed: float = 0.0       # px/s while patrolling (NOT chasing). 0 = idle-pivot (no roaming)
# (optional, OQ-5) @export var r1_patrol_pattern: int = 0  # 0 = pace endpoints, 1 = bounded random-walk, 2 = idle
# to_flat_dict(): add "r1_spawn_room_only", "r1_patrol_speed" (+ pattern). Knob count 81 -> 83 (or 84). L0 freezes.
```

### B1. Learning "my spawn room" bounds — two candidate sources (OQ-1)

**Option A — `main_game.gd` passes bounds (mirrors K5; recommended for fidelity).** Widen R1's `setup` to the
**same three-arg family signature** the K5 hazards already use, and have the spawn seam thread the piece bounds it
already has the inputs for:

```gdscript
# hazard_entity.gd — widen setup to the locked family signature (third arg optional, back-compatible).
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
    _cfg = cfg
    _player = player
    _room_bounds = spawn_ctx.get("room_bounds", Rect2())   # empty == no room → fall back to Option B / chase-everywhere
    ...

# main_game.gd _spawn_r1_hazards() — compute bounds from the SAME piece the hazard is placed in:
#   for the J2 spread:   the piece at depths[i] (needs the placed-piece handle, not just a world pos — see OQ-1)
#   for the J3 density:   _populate_room_density already iterates pieces; pass _piece_floor_bounds_world(cells)
hz.setup(rc, player, { "room_bounds": _piece_floor_bounds_world(cells) })
```

**Option B — derive inside the entity, no `main_game.gd` edit.** The entity does not know its piece. It could
synthesise an approximate room rect from its **spawn `global_position`** ± a configured half-extent
(`r1_patrol_radius`), giving a square "home zone" centred on spawn:

```gdscript
func setup(cfg, player) -> void:   # signature UNCHANGED — no main_game.gd touch
    ...
    if _cfg.r1_spawn_room_only:
        var h := _cfg.r1_patrol_radius   # px half-extent
        _room_bounds = Rect2(global_position - Vector2(h, h), Vector2(h, h) * 2.0)
```

Trade-off captured in OQ-1: Option A is *accurate* (the real room, doorways respected) but **touches `main_game.gd`**
(serialises L1/L2 in Wave 2). Option B keeps L2 entirely inside `hazard_entity.gd` (L1/L2 run parallel) but the "room" is a
geometric blob, not the actual room — it can poke through walls / not fill an irregular room. **Recommendation: Option A**
(reuse the proven K5 mechanism; the fidelity matters because "leaving the room = safe" is the whole point), and accept the
`main_game.gd` single-writer sequencing (L1 → L2) in Wave 2. See OQ-1.

### B2. Patrol behaviour (slow, bounded) — recommended: pace between two endpoints

```gdscript
# New AWAKE-time sub-behaviour, gated by r1_spawn_room_only. Replaces the straight-at-player chase
# WHEN the player is NOT in the spawn room.
func _patrol(delta) -> void:
    if _cfg.r1_patrol_speed <= 0.0 or not _room_bounds.has_area():
        velocity = Vector2.ZERO   # idle-pivot fallback (no roaming) — still gates chase, just doesn't wander
        move_and_slide()
        return
    # Pace between two deterministic endpoints inside the room (e.g. left-mid <-> right-mid of _room_bounds).
    # Endpoints derived from _room_bounds (NO RNG — pure run-state, determinism-safe).
    var target := _patrol_endpoints[_patrol_leg]
    var to_t := target - global_position
    if to_t.length() <= PATROL_ARRIVE_EPS:
        _patrol_leg = 1 - _patrol_leg          # flip to the other endpoint
        target = _patrol_endpoints[_patrol_leg]
        to_t = target - global_position
    velocity = to_t.normalized() * _cfg.r1_patrol_speed
    move_and_slide()
    _clamp_inside_room()                       # belt-and-braces, like pingpong _confine_to_room
```

### B3. The "chase iff player in spawn room" gate

```gdscript
func _physics_process(delta) -> void:
    ... # DORMANT/awaken unchanged
    # AWAKE:
    if _cfg.r1_spawn_room_only and _room_bounds.has_area():
        var player_in_room := _room_bounds.has_point(_player.global_position)  # Rect2.has_point — the gate
        if player_in_room:
            _chase(delta)        # the EXISTING chase+catch math, unchanged (hazard_entity.gd:114-158)
        else:
            _patrol(delta)       # B2 — keep patrolling, do NOT chase, do NOT freeze, do NOT despawn
        _maybe_emit_state(player_in_room)   # OQ-7 telemetry mark
        return
    # r1_spawn_room_only OFF -> fall through to today's exact chase-everywhere code (byte-identical baseline).
    _chase(delta)
```

`Rect2.has_point()` is the built-in rect-contains test — exactly the API for the gate (mirrors how the ping-pong tests
edges with `_room_bounds.has_area()` / `.position` / `.end`).

### B4. Catch only when chasing (OQ-4)

The catch test (`hazard_entity.gd:146-158`) lives inside `_chase()` in the refactor, so a pursuer that is *patrolling*
(player outside the room) **cannot catch**, even if its patrol path happens to pass near a player standing in a doorway
just outside the rect. Recommended (see OQ-4): keep catch strictly inside `_chase()` — no catch while patrolling.

### B5. Config-marked telemetry (additive; L0 declares the signal)

```gdscript
# event_bus.gd (L0 adds): a pursuer-state mark so RG2 can show "room-bound vs chase-everywhere" cohorts.
# signal hazard_pursuer_state(state: StringName, depth: int, run_t_ms: int)   # &"patrol" | &"chase"
func _maybe_emit_state(in_room: bool) -> void:
    var s: StringName = &"chase" if in_room else &"patrol"
    if s != _last_state:                       # rising-edge only (BUG6 latch pattern) — no per-frame storm
        _last_state = s
        EventBus.hazard_pursuer_state.emit(s, GameState.current_depth_index, int(_time_in_band * 1000.0))
```

Marked-optional: if the Director wants the lightest footprint, L2 can ship without a new signal and rely on the existing
`hazard_caught` counts (catches drop sharply when the pursuer is room-bound) — see OQ-7.

---

## (c) Open Questions

> Each states the trade-off and a recommendation. **Director-judgment items are flagged.** Fresh-eyes (Phase 3) resolve
> the technical ones; the FEEL/scope calls go to the Director.

**OQ-1 — Does L2 need to write `main_game.gd`, or can it stay inside `hazard_entity.gd`? (drives Wave-2 parallelism.)**
This is the load-bearing question for the build order. *Option A* (widen R1 `setup` to the 3-arg family signature and
have `_spawn_r1_hazards`/`_populate_room_density` pass `_piece_floor_bounds_world(cells)`) is **accurate** — the pursuer
gets the *real* room rect, doorways respected, "leave the room = safe" holds honestly — but it **touches `main_game.gd`**,
so if L1 also edits `main_game.gd` (it likely parents the thrown projectile into `_band_container`), L1 and L2 must be
**single-writer-sequenced (L1 → L2)** in Wave 2, not parallel. *Option B* (derive a square home-zone from spawn position ±
`r1_patrol_radius`, no `main_game.gd` edit) keeps L1/L2 **parallel** but the "room" is a geometric blob that can poke
through walls or under-fill an irregular room — undermining the very legibility the feature exists for. **Note** the J2
spread seam (`main_game.gd:530-534`) currently passes only a world *position* to the hazard, not the placed-piece handle,
so Option A also needs that loop to retain the piece (a small refactor) to call `_piece_floor_bounds_world`. **Recommend
Option A** + accept L1→L2 single-writer on `main_game.gd`; the fidelity is worth one serialised file. *Fresh-eyes:
confirm the spread-seam refactor is small; Director: ratify the parallel-vs-sequential Wave-2 call.*

**OQ-2 — Exact patrol pattern. [FEEL — Director judgment.]** Three candidates: (a) **pace between two endpoints**
(left-mid ↔ right-mid of the room rect) — simple, deterministic, reads as "guarding a beat"; (b) **bounded random-walk**
inside the rect — but RNG is forbidden in run-state determinism-sensitive code, so it would need a deterministic
pseudo-walk (lissajous/index-driven), more code; (c) **idle-pivot** — stays at spawn, rotates the tell, never roams.
**Recommend (a) pace-endpoints** (best legibility-per-line; "this thing owns this room and walks its beat"), with
`r1_patrol_speed = 0` collapsing to (c) idle as a built-in control. *This is a fun/feel call — flag for Director.*

**OQ-3 — Patrol speed relative to chase speed. [FEEL — Director judgment.]** The whole point is that the room-bound
pursuer is *slower* and *answerable*. Patrol should be clearly slower than chase (`r1_chase_speed = 56` in the preset),
and arguably the **chase** speed should also drop under `r1_spawn_room_only` so the player can plausibly out-manoeuvre it
inside one room and line up a throw (L1). **Recommend** preset values around `r1_patrol_speed ≈ 25-30` (≈half of chase),
and consider whether the room-bound preset also lowers `r1_chase_speed` — *both are Director sweep values, flagged.*

**OQ-4 — Can the pursuer catch while patrolling (player outside the room)?** If the player stands in a doorway just
outside the rect and the patrol path skims the edge, should a catch be possible? **Recommend NO** — catch lives strictly
inside `_chase()` (B4), so only an in-room player is ever in danger. This makes the rect boundary a *clean, readable safe
line* (the feature's purpose) and avoids a confusing "I was outside but still died" death. *Edge note for fresh-eyes:* the
existing `r1_catch_radius` can exceed the rect margin, so without this rule a patroller could catch through the wall — the
B4 rule closes that. **No catch while patrolling.**

**OQ-5 — Re-entry behaviour: player leaves then returns — resume chase immediately?** Options: (a) **resume chase
instantly** the frame `has_point` flips true (simplest, matches "it's hunting in here"); (b) a brief **re-acquire delay**
(predator "notices" you). **Recommend (a) immediate resume** — simpler, more legible (the room is *consistently*
dangerous; no hidden grace window to mis-learn). The awaken latch is unchanged (once awake, stays awake — `:175`), so
re-entry never re-runs the dormant→awake beat. *Lean technical; fresh-eyes confirm.*

**OQ-6 — Behaviour when the entity has no room bounds (empty `Rect2`).** If `room_bounds` arrives empty (Option A spawn
path that couldn't resolve cells, or Option B disabled), what does `r1_spawn_room_only=ON` do? **Recommend: fall back to
today's chase-everywhere** (the `has_area()` guard in B1/B3 already does this) — never silently freeze a hazard, and never
crash. This keeps a mis-wired instance harmless. *Technical; fresh-eyes confirm the guard covers every spawn path
(J2 spread, J3 density).*

**OQ-7 — Telemetry: new `hazard_pursuer_state` signal, or rely on existing counts? [partly Director — scope.]** A
rising-edge `hazard_pursuer_state(state, depth, run_t_ms)` signal (B5) lets RG2 directly compare patrol-vs-chase time
across cohorts; but it's a new signal L0 must declare and the breakdown calls the mark "optional." The cheaper path is to
infer the room-bound effect from the **drop in `hazard_caught` counts** already logged. **Recommend** the lightweight new
signal (additive, rising-edge-latched — no per-frame storm, mirrors the BUG6 pattern) because RG2 explicitly wants
"pursuer-state counts" (breakdown §3 RG2 row). *L0 must pre-declare it if adopted — flag the signal name/arity to L0;
scope call to Director.*

**OQ-8 — Knob names/defaults to feed L0. [Director ratifies the final set.]** Proposed: `r1_spawn_room_only: bool =
false` (the master gate), `r1_patrol_speed: float = 0.0` (px/s; 0 = idle), and *optionally* `r1_patrol_pattern: int = 0`
(if OQ-2 adopts a selectable pattern) and/or `r1_patrol_radius: float = 0.0` (only if OQ-1 picks Option B). All
off/neutral so the all-off control reproduces today's chase-everywhere pursuer. **Recommend the minimal set
`{r1_spawn_room_only, r1_patrol_speed}`** (knob count 81 → 83) and only add `r1_patrol_pattern`/`r1_patrol_radius` if
OQ-2/OQ-1 force them. *L0 freezes the final list + the new knob-count once the Director ratifies OQ-1/OQ-2.*

---

## Definition of done (for the build task, after lock)

- `r1_spawn_room_only = false` → `hazard_entity.gd` behaviour is **byte-identical** to today's chase-everywhere pursuer
  (the existing chase/catch path runs unchanged; the all-off control's pursuer behaviour is unmoved). Pursuer is
  run-state → fp `e943ac9c8bc1` unmoved regardless.
- `r1_spawn_room_only = true` → the pursuer patrols inside its spawn room and chases **iff** the player is inside that
  room (rect `has_point`); outside, it keeps patrolling (no despawn/freeze). Catch fires only while chasing.
- New knob(s) pre-declared by L0, in `to_flat_dict()` + the CFG coverage assertion; knob-count tests updated to L0's new
  number. Preset (`make_default_play_preset`) turns the feature on with the Director-ratified patrol/speed values.
- (If adopted) `hazard_pursuer_state` declared by L0, emitted rising-edge only; `run_ended` arity untouched; no save
  change.
- Worklog at `worklogs/<date>-L2-*.md` naming the commit SHA + a "Design deviations" section.

---

## Resolved Decisions (Phase 3)

_Fresh-eyes pass, 2026-06-24 (resolver NOT the L2 author). Re-verified against live code: `hazard_entity.gd:83` (the **2-arg** `setup(cfg, player)` — confirmed, no `spawn_ctx`), `:94-158` (chase+catch), `:146-147` (distance catch), `:154-158` (BUG6 latch), `:23-25`/`hazard_entity.tscn` (layer `hazard`, mask `world`); `pingpong_hazard.gd:63,67,148-157` (the **3-arg family** `setup(cfg, player, spawn_ctx)` + `room_bounds` + `_confine_to_room`); `main_game.gd:532-533` (J2 spread `hz.setup(rc, player)`), `:556` (`for pos in _density_spawn_positions(...)`), `:570-609` (`_density_spawn_positions` returns `Array[Vector2]` — **positions only, NO piece retained**), `:487-493` (`_piece_floor_bounds_world(cells)`), `:455-457` (the K5 path that DOES pass `room_bounds`). All L2 premise claims hold; one cost is materially understated — see RD-1._

### RD-1 (was OQ-1) — Does L2 write `main_game.gd`? **RESOLVED: YES — Option A; SEQUENCE L1 → L2.**
**Adopt Option A** (widen R1 `setup` to the 3-arg family `(cfg, player, spawn_ctx)`, thread `room_bounds` from the spawn seam). Reject Option B (spawn-position blob) on fidelity — a square home-zone pokes through walls / under-fills irregular rooms, defeating the "leave the room = safe" legibility that is the feature's whole purpose.

**Correction to the author's cost estimate (verified):** the author wrote that `_populate_room_density` "already iterates pieces, pass `_piece_floor_bounds_world(cells)`." That is **not** what the code does. `_spawn_r1_hazards`'s density branch calls `for pos in _density_spawn_positions(band, rc)` (`main_game.gd:556`), and `_density_spawn_positions` (`:570-609`) returns `Array[Vector2]` — it iterates pieces *internally* (`:582`) and computes `room_bounds` would be available **there**, but it **discards the piece** and yields only `_density_cell_to_world(cell)` positions (`:606`). Likewise the J2 spread loop (`:527-533`) calls `_hazard_spawn_position(band, depths[i], i)` which returns a bare `Vector2` (`:713-727`) — the piece is gone. **So Option A is a real refactor of BOTH spawn helpers**, not a one-line `spawn_ctx` add:
- **J3 density path:** change `_density_spawn_positions` to return position **+ its piece's `room_bounds`** together (e.g. `Array[Dictionary]` of `{pos, room_bounds}`, or a parallel `Array[Rect2]`), since the bounds are already computable inside its per-piece loop (`p.floor_cells` / `_density_sorted_cells(p)` are in hand at `:603`). Then the spawn loop passes `{ "room_bounds": rb }` to `setup`.
- **J2 spread path:** `_hazard_spawn_position(band, depth, index)` collects the depth's floor cells internally (`:715-721`) but returns only one cell's world pos. To get `room_bounds`, either have it also return the depth's cell-set bbox, or compute `_piece_floor_bounds_world` for the chosen piece at spawn time. A small but real change.

**`hazard_entity.gd` `setup` widening is back-compatible:** add the optional third param `spawn_ctx: Dictionary = {}` (matching the K5 family signature exactly), `_room_bounds = spawn_ctx.get("room_bounds", Rect2())`. **Verify the two existing `setup(rc, player)` call sites still compile** — they do, since the third arg defaults; they simply pass no bounds (empty Rect2 → the `r1_spawn_room_only` guard falls back to chase-everywhere per RD-6, harmless). Any test fixture that calls `setup` with two args also stays valid.

**Wave-2 sequencing (definitive, mirrors L1's verdict):** because **L1 also writes `main_game.gd`** (the throw handler + projectile parenting under `_band_container`, confirmed), **L1 and L2 must be single-writer-sequenced: L1 → L2.** L1 lands its small throw seam first; L2 rebases and adds the R1-spawn `room_bounds` plumbing. **L5 runs fully parallel** (disjoint entity files). Do NOT run L1‖L2 as parallel worktrees.

### RD-2 (was OQ-4) — Catch only while chasing. **RESOLVED: YES — no catch while patrolling.**
The catch test (`hazard_entity.gd:146-158`) moves inside the refactored `_chase()`; `_patrol()` never runs the distance/latch check. A patrolling pursuer whose path skims the rect edge cannot catch a player standing just outside. This makes the rect a clean readable safe line and closes the "I was outside the room but still died" failure (which `r1_catch_radius` exceeding the rect margin would otherwise allow). **Build instruction: the catch block lives in `_chase()` only; `_patrol()` is pure locomotion.** Preserve the BUG6 `_caught_latched` rising-edge semantics inside `_chase()` exactly as today (do not add any guard that *prevents* `fail_run`; `GameState._run_ended` owns run-end idempotency, per `hazard_entity.gd:183-191`).

### RD-3 (was OQ-5) — Re-entry resume. **RESOLVED: immediate resume.**
The frame `_room_bounds.has_point(player.global_position)` flips true, `_chase()` resumes. No re-acquire delay. The awaken latch is untouched (`hazard_entity.gd:174-175` — once AWAKE, stays AWAKE), so re-entry never re-runs the dormant→awake beat or re-emits `hazard_awoke`. Simpler and more legible: the room is *consistently* dangerous, no hidden grace window to mis-learn. The state-transition telemetry (RD-5) marks the patrol→chase flip.

### RD-4 (was OQ-6) — Empty `room_bounds` fallback. **RESOLVED: fall back to chase-everywhere; never freeze/crash.**
If `room_bounds` arrives empty (a spawn path that couldn't resolve cells, or a mis-wire), `r1_spawn_room_only=ON` falls through to today's chase-everywhere code via the `_room_bounds.has_area()` guard in B1/B3. A mis-wired instance is harmless (behaves like the all-off pursuer), never silently frozen, never crashes. **Build instruction: every patrol/gate branch is guarded by `_cfg.r1_spawn_room_only and _room_bounds.has_area()`; the else falls to the existing chase path.** **Verify the guard covers BOTH spawn paths** (J2 spread + J3 density) — per RD-1 both must now thread real bounds, so the empty-bounds case should be the exception, not the rule; but the guard makes a gap fail safe rather than freeze.

### RD-5 (was OQ-7, technical half) — Telemetry signal. **RESOLVED technically: adopt the rising-edge `hazard_pursuer_state` signal; scope confirmation → Director.**
Adopt the lightweight new signal `hazard_pursuer_state(state: StringName, depth: int, run_t_ms: int)` (`&"patrol"`/`&"chase"`), emitted **rising-edge only** (mirroring the BUG6 `_caught_latched` pattern at `hazard_entity.gd:154-158` and the ping-pong's `_killed_latched`) so there is no per-frame emit storm. RG2 explicitly wants "pursuer-state counts" (breakdown §3). Primitives-only payload, additive, `run_ended` arity untouched, no save change. **L0 must pre-declare this signal** — flag the exact name/arity to L0 (it is in scope for L0's single-writer `event_bus.gd` pass). The scope question (ship it vs rely on the `hazard_caught` count drop) is flagged to the Director below, but the technical recommendation is to ship it (cheap, RG2 wants it). Self-time `run_t_ms` from `_time_in_band` exactly as `_on_catch` does (`hazard_entity.gd:185-188`) — do NOT invent a new clock.

### RD-6 — Knob set for L0 to freeze (consolidates OQ-8). **RESOLVED: minimal set `{r1_spawn_room_only, r1_patrol_speed}`.**
Two new `r1_`-prefix knobs, off/neutral: `r1_spawn_room_only: bool = false` (master gate; OFF = today's byte-identical chase-everywhere), `r1_patrol_speed: float = 0.0` (px/s while patrolling; `0.0` collapses to idle-pivot, a built-in control). **Do NOT add `r1_patrol_radius`** — it only existed for the rejected Option B (RD-1 picks Option A, real room bounds). **Do NOT add `r1_patrol_pattern`** unless the Director picks a selectable pattern in DR-L2-1; the recommendation there is a single fixed pattern (pace-endpoints), so the knob is unnecessary. Both join `to_flat_dict()` + the CFG coverage assertion; L0 reconciles the final knob-count delta across the L1 `throw_` group, this `r1_` pair, and the L5 `*_kills` group. All-off control reproduces today's chase-everywhere pursuer (behavioural baseline parity); the fp `e943ac9c8bc1` is unmoved regardless (pursuer is run-state, never feeds `fingerprint()`).

### RD-7 — Patrol endpoints must be RNG-free (determinism). **CONFIRMED.**
The patrol endpoints (B2) must be a **pure deterministic function of `_room_bounds`** (e.g. left-mid ↔ right-mid: `Vector2(bounds.position.x + margin, bounds.get_center().y)` ↔ `Vector2(bounds.end.x - margin, bounds.get_center().y)`), with **NO `RNG` autoload call** — consistent with the ping-pong's no-RNG rule (`pingpong_hazard.gd:16-19`) and the determinism contract. Clamp the body back inside with a `_confine_to_room`-style guard (reuse the `pingpong_hazard.gd:148-157` shape) as belt-and-braces against `move_and_slide` drift. Patrol locomotion uses `move_and_slide` (walls still stop it on the `world` mask — unchanged collision).

---

### Needs Director review (L2)

> Fresh-eyes did NOT self-resolve these — vision/fun/feel/scope calls per the orchestrator loop step 7.

- **DR-L2-1 — Patrol pattern (was OQ-2). FEEL.** Three candidates: (a) **pace between two endpoints** (left-mid ↔ right-mid of the room rect) — deterministic, simple, reads as "guarding a beat"; (b) **bounded pseudo-random walk** — but RNG is forbidden in this determinism-sensitive run-state code, so it needs a deterministic index/lissajous walk (more code, less legible intent); (c) **idle-pivot** (stay at spawn, rotate the tell). **Recommendation: (a) pace-endpoints**, with `r1_patrol_speed = 0` collapsing to (c) idle as a built-in control — best legibility-per-line, "this thing owns this room and walks its beat", no extra knob. *Director ratifies the pattern; if (a), no `r1_patrol_pattern` knob is needed.*

- **DR-L2-2 — Patrol speed, and whether chase speed also drops under `r1_spawn_room_only` (was OQ-3). FEEL / sweep values.** The room-bound pursuer should be clearly *slower* and answerable (so the player can out-manoeuvre it in one room and line up an L1 throw). The author recommends preset `r1_patrol_speed ≈ 25–30` (~half of the `r1_chase_speed = 56` preset), and raises whether the room-bound preset should *also* lower `r1_chase_speed`. **These are Director sweep values, not design code** — they ship in `make_default_play_preset()`, never in the code-level defaults. *Director sweeps `r1_patrol_speed`; decides whether the M1.5 preset also lowers `r1_chase_speed` for the room-bound feel.*

- **DR-L2-3 — Ship the `hazard_pursuer_state` telemetry signal, or rely on `hazard_caught` count drop? (was OQ-7, scope half).** Technically the signal is cheap and RG2 wants explicit patrol/chase counts (RD-5 recommends shipping it). The only reason to decline is to keep the L0 `event_bus.gd` footprint minimal and infer the effect from the `hazard_caught` count drop. **Recommendation: ship the signal** (additive, rising-edge, RG2-requested). *Director confirms scope; if shipped, L0 pre-declares the name/arity.*
