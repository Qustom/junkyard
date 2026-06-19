# R1 — Pursuing / Awakening Hazard — Expanded Design Spec

**Milestone:** M1.1 (Greybox Cost Axis) · **Workstream:** (b) oppositions · **Wave:** 2 (parallel worktree)
**Task id:** R1 · **dependsOn:** R0 (run-config model), BUG2 (within-band depth)
**Assignees:** game-director-designer (this spec + config defaults) · general-purpose (behaviour) · character-animator (inline greybox "awake/chase" tell)
**Author:** game-director-designer · **Status:** spec (the "first sub-step" of R1 per `M1.1_Breakdown.md` §6)

> **What this doc is.** Per the breakdown, "each opposition's first sub-step is its game-director-designer spec." This is that spec for R1 — the contract from `M1.1_Breakdown.md` §4 expanded into mechanic detail, the greybox tell, telemetry payloads, pseudocode, config defaults, the file plan, and acceptance criteria. It is **design only** — it ships **no game code and no `.tres`**. The programmer builds against it. **All Director calls are resolved:** §9 records the 2026-06-19 apply-all-recommendations ratification and the body commits to a single design — no open questions remain in R1's wave-2 scope.

---

## 0. Hard constraints (read first)

These come straight from the breakdown's scope guardrails (§2) and the wave-2 contract (§6). The spec must not violate them, and neither may the implementation built from it:

- **THROWAWAY-grade greybox prototype, NOT the M2 enemy-AI slice.** Crude is correct. No combat, no health/damage model, no pathfinding graph, no navmesh, no steering behaviours library, no enemy state-machine framework. A colored shape that lerps toward the player is the *target* fidelity, not a fallback.
- **Configurable, not balanced.** Acceptance is "the knob exists and takes effect," never "the value is right." The Director sweeps values across playtest runs. Ship sensible defaults (§6) but assume every number changes.
- **All-off reproduces M1.0 exactly.** With `r1_enabled = false` (the `RunConfig` default), **no hazard node is ever instantiated** — zero cost, zero behavioural difference, zero new telemetry rows.
- **Reads only; does not widen the locked contracts.** R1 *reads* `GameState.active_run_config` (R0) and the live within-band depth (BUG2). It **must NOT edit `event_bus.gd`** (TEL pre-declares `hazard_awoke`/`hazard_caught` in wave 1) and **must NOT edit `game_state.gd`** (R0's `active_run_config` + BUG2's depth are the read surface). Route run-end through the **existing** `GameState.fail_run(&"death")` — never add a new end path.
- **File-disjoint from R2/R3/R4.** R1 owns a new hazard scene/script + one spawn-seam edit in `main_game.gd`. Nothing else.

---

## 1. Goal & design intent

**One sentence:** *A thing that wakes up and chases you the deeper or longer you go, and kills your run if it catches you.*

R1 is **the most direct expression of "deeper = more dangerous."** M1.0 proved the loop is engaging but degenerate — with a reward axis (deeper = better junk) and no cost axis, "push vs. extract" is always "push" (G4 = ITERATE; 30 extract / 2 death / 0 timeout). R1's job in the cost-axis experiment is to put a **legible, embodied predator** on the depth axis: the player can *see* the danger grow, *feel* the moment it wakes, and make a gut "do I grab one more piece or run?" call with a chasing shape closing the distance.

Of the four oppositions, R1 is the most **viscerally readable** (a monster is chasing me) and the most **binary** (caught = run over). That makes it the cleanest single-variable test of whether *any* depth-cost makes the gamble fun — and the easiest for a playtester to narrate ("I pushed one room too far and it got me"). R2/R3/R4 add subtler, attritional costs; R1 adds the sharp one.

**Design feel target (for the Director's sweep, not a balance claim):** the hazard should feel *avoidable but punishing* — slightly slower than or near the player's speed when shallow, so a player who turns back in time escapes, but fast enough (via `r1_speed_per_depth`) that lingering deep is a real bet. The "awaken" moment should be a clear, telegraphed beat (color flip + the shape starting to move), not a silent instant-fail.

---

## 2. Mechanic design — every `r1_*` knob mapped to a behaviour

The hazard is a single greybox node-type (`HazardEntity`). The system spawns `r1_spawn_count` of them when `r1_enabled`. Each instance runs the same tiny loop: **dormant → (awaken trigger) → awake/chasing → (catch test) → run-end.**

### 2.1 Knob → behaviour table

| `RunConfig` field | Type / default | Behaviour it drives |
|---|---|---|
| `r1_enabled` | `bool` / `false` | **Master toggle.** False → R1 spawns nothing, instantiates no node, emits no telemetry; loop == M1.0. True → the spawn seam creates `r1_spawn_count` hazards. |
| `r1_depth_threshold` | `int` / `0` | **Awaken trigger A (depth).** A dormant hazard awakens the first frame the player's live within-band depth (`GameState.current_depth_index`, BUG2) is **≥** this value. `0` → may awaken at depth 0/entry (effectively "awake from the start" once any other gate passes). |
| `r1_linger_seconds` | `float` / `0.0` | **Awaken trigger B (time).** A dormant hazard awakens once **time-in-band** ≥ this many seconds. `0.0` → time never triggers awakening on its own (depth is the only trigger). The hazard awakens on **whichever trigger fires first** (depth OR linger) — see §2.2. |
| `r1_chase_speed` | `float` / `0.0` (px/s) | **Flat chase speed** once awake. The base movement speed toward the player. `0.0` → an awake hazard that doesn't move (a pure tell, useful for isolating the awaken beat in a sweep). |
| `r1_speed_per_depth` | `float` / `0.0` (px/s per depth) | **Depth speed scaling.** Effective speed = `r1_chase_speed + r1_speed_per_depth * current_depth_index`, evaluated live each frame off the player's current depth. This is the "deeper = faster predator" lever — the core of "deeper = more dangerous." |
| `r1_catch_radius` | `float` / `0.0` (px) | **Catch distance.** When the distance from an awake hazard to the player ≤ this radius, the hazard "catches" the player → run-end. `0.0` → can only catch on near-exact overlap (effectively very hard to catch); set > 0 for a fair hitbox. |
| `r1_catch_kills` | `bool` / `false` | **Catch consequence.** `true` → catching routes through `GameState.fail_run(&"death")` (run over, pockets fraction applies). `false` → catching inflicts a **non-fatal cost** instead of ending the run: **knockback + a brief stun/slow + a short hazard cooldown**, self-contained with no other-system coupling (ratified §9 Q2; see §2.5). |
| `r1_spawn_count` | `int` / `0` | **How many hazards.** The spawn seam instantiates this many `HazardEntity` nodes when enabled. `0` with `r1_enabled = true` is a valid no-op (enabled but nothing spawns). When `> 1`, hazards are **fully independent** — separate awaken/catch state, no inter-hazard collision, first-to-catch ends the run (ratified §9 Q3). |

### 2.2 Awaken trigger (depth OR linger, first to fire)

A hazard is **dormant** until **either** condition becomes true, then it latches **awake** permanently for the run. **It never re-sleeps** — once triggered it stays awake even if the player retreats shallow (ratified §9 Q4). Staying awake makes the threat "sticky" and the gamble one-directional, matching "deeper = more dangerous, and you can't fully undo it":

```
awaken IF  (current_depth_index >= r1_depth_threshold)   # depth trigger
        OR (time_in_band_seconds >= r1_linger_seconds AND r1_linger_seconds > 0)
```

- Depth trigger uses BUG2's **live** within-band depth (the `depth_index` of the piece the player is in). On a branching layout (R4 on) this is the player's **current** branch depth, used as-is — the once-only awaken latch above makes a transient depth dip on a dead-end branch harmless (ratified §9 Q5).
- Linger trigger uses **time-in-band** measured from band entry (the hazard's own accumulated `awake`-eligible time; spec recommends measuring from spawn = band entry, see §5 pseudocode).
- `r1_linger_seconds = 0.0` disables the time trigger (so a config can be "depth-only" or, by setting a huge `r1_depth_threshold`, "time-only").
- On awaken: emit `hazard_awoke(depth, trigger)` once (§4), flip the greybox tell (§3), and begin chasing.

### 2.3 Chase behaviour (crude steering — NO pathfinding)

Once awake, each `_physics_process(delta)`:

1. Compute the live effective speed: `speed = r1_chase_speed + r1_speed_per_depth * current_depth_index`.
2. Compute a direction toward the player. **Two allowed crudeness levels** (the programmer picks the simpler one that reads acceptably; the spec's default is **(a)**):
   - **(a) Direct toward-player steering (recommended default).** `dir = (player_pos - hazard_pos).normalized()`; move `speed * delta` along `dir`. The hazard is a `CharacterBody2D` using `move_and_slide()` so band walls stop it (it slides along walls rather than passing through). This can get stuck behind a wall — **acceptable** for a throwaway greybox; the design *wants* walls to be a partial refuge.
   - **(b) Nearest-floor-cell hop (optional, only if (a) reads badly).** Snap toward the adjacent floor cell that most reduces distance to the player (a 1-step greedy grid move using the band's floor-cell adjacency). Still no graph search, still no path — just "step to the neighbouring floor cell closest to the player." Use only if (a)'s wall-hugging looks broken in playtest.
3. **No** A*, no navmesh, no LimboAI/Beehave behaviour tree, no flow field. If the hazard gets stuck on geometry, that is a feature (refuge), not a bug to solve this milestone.

### 2.4 Catch test

Each physics frame while awake, after moving:

```
IF hazard_pos.distance_to(player_pos) <= r1_catch_radius:
    on_catch()
```

On a fatal catch, `on_catch()` is **idempotent across all hazards and against extract** — it must respect `GameState`'s existing `_run_ended` guard so two hazards (or a hazard + a same-frame extract) cannot double-fire run-end. The hazard does **not** own that guard; it calls the canonical `GameState.fail_run(&"death")`, which already carries the `_run_ended` idempotency (extract wins a same-frame tie, per `M1_As_Built.md` E3 decision #13). With `r1_spawn_count > 1`, hazards are fully independent and the **first** to catch ends the run via that guard (ratified §9 Q3). See §5 pseudocode.

### 2.5 Catch consequence (`r1_catch_kills`)

- **`r1_catch_kills = true` (the death path — the primary behaviour, and the first-gate value):** emit `hazard_caught(depth, run_t_ms)`, then call `GameState.fail_run(&"death")`. This is the existing death end-cause: pockets fraction applies (player keeps `floor(run_haul_value() * pockets_fraction)` worth of items, per `RunRules`), meta persists, `run_ended.reason = "death"`. **No new end path, no new signal, no `game_state.gd` edit.**
- **`r1_catch_kills = false` (the cost-instead-of-kill path — ratified §9 Q2):** catching does **not** end the run. It inflicts a **self-contained non-fatal cost**: the hazard **knocks the player back**, applies a **brief stun/slow**, and goes on a **short cooldown** before it can catch again; the chase then continues. `hazard_caught` is still emitted (tagged non-fatal), but there is **no** `fail_run` call and **no coupling to any other system** — R1 does not drop items, touch the dive clock, or add exposure (those would entangle R1 with R2/R3/R4 and muddy the single-variable test). This is the committed full behaviour for the non-fatal path, not a placeholder.

> **First-gate default:** `r1_catch_kills = true` (§6.2). The sharp binary (caught = dead) is the cleanest test of "does a depth-predator make the gamble fun"; the non-fatal variant is a later sweep variant that overlaps R2/R3's attritional costs. Both paths are fully specified — the Director sweeps the flag.

---

## 3. Greybox tell (character-animator, inline placeholder)

Per the M1 greybox asset norm (`M1_As_Built.md` §"Greybox asset norm"), the implementing agent **stubs the placeholder inline** — no PixelLab/paid generation. The tell is a flat colored shape with a clear dormant/awake state change.

**Visual states:**

| State | Shape | Color | Motion |
|---|---|---|---|
| **Dormant** | A `ColorRect` or a `Polygon2D` (diamond/circle reads as "creature," distinct from junk's rects) | **Desaturated / cool** (e.g. dim grey-blue `Color(0.35, 0.4, 0.5)`) | Stationary (optionally a slow idle pulse via `Tween` — nice-to-have) |
| **Awake / chasing** | Same shape | **Hot / alarm** (e.g. `Color(0.9, 0.2, 0.2)` red) | Moves toward the player; optional faster pulse or scale-throb to read "active" |

- The **awaken moment** is the key beat: an instant color flip (dormant cool → awake hot) the frame `hazard_awoke` fires, ideally with a one-shot `Tween` "wake" flash (quick scale-up-and-settle) so the player registers "it woke up." This is the telegraph that makes the gamble *felt* rather than a silent fail.
- **Size:** roughly player-sized or slightly larger so it reads as a threat and the `r1_catch_radius` hitbox is legible.
- **Collision layer:** the hazard body sits on **layer 5 = `hazard`** (`M1_As_Built.md` collision map; reference the name, never raw bits). It masks `world` (layer 2) so walls stop it; it does **not** mask `player` (catch is a distance test in script, not a physics overlap — simpler and deterministic) and it does **not** mask `hazard`, so hazards never collide with or block each other (ratified §9 Q3). If the implementer prefers an `Area2D` overlap for catch, that Area also sits on `hazard`.
- The character-animator's contribution here is **inline and minimal**: define the two colors/shapes + the wake-flash Tween in the hazard scene. No sprite sheets, no `AnimationTree`. If even a Tween is over-scope, a hard color swap is acceptable.

---

## 4. Telemetry

R1 emits **only** the two signals TEL pre-declares on `event_bus.gd` in wave 1 (R1 itself touches neither `event_bus.gd` nor `telemetry/`). Payloads must match TEL's declarations exactly. Run-end on a fatal catch rides the **existing** `run_ended.reason = "death"` — R1 does not add an end-cause.

| Signal | Payload | When | Maps to |
|---|---|---|---|
| `hazard_awoke(depth: int, trigger: StringName)` | `depth` = `current_depth_index` at awaken; `trigger` = `&"depth"` or `&"linger"` (which condition fired first) | Once per hazard, the frame it transitions dormant→awake | A new TEL `EventType` row (config-marked) |
| `hazard_caught(depth: int, run_t_ms: int)` | `depth` = `current_depth_index` at catch; `run_t_ms` = elapsed run time in ms at catch | Each catch event — fatal (`r1_catch_kills = true`) or non-fatal (tagged) | A new TEL `EventType` row |
| `run_ended(reason=&"death", duration_s, depth_reached)` | the **existing locked** arity — emitted by `GameState.fail_run(&"death")`, not by R1 | On a fatal catch, via `fail_run` | **Existing** contract, unchanged |

**Payload confirmation against the breakdown (§4 R1 + TEL §):** the breakdown specifies `hazard_awoke(depth, trigger)` and `hazard_caught(depth, run_t_ms)` — this spec matches both. **R1 must coordinate with TEL** so the pre-declared signal **signatures are exactly these** (`depth: int`, `trigger: StringName`; `depth: int`, `run_t_ms: int`). If TEL's pre-declared signatures differ, TEL's win (it owns `event_bus.gd`) and this spec is updated — flag at brief time. With `r1_enabled = false`, neither signal is ever emitted (no hazard exists), so the "off → no R1 rows" acceptance holds for free.

**`run_t_ms` source (ratified §9 Q5):** read BUG1's run-elapsed clock (real run duration captured at `start_run`) **read-only** off `GameState`/`Telemetry` when it is exposed. If it is not reachable read-only, the hazard times from its own spawn (band entry ≈ run start in single-band M1) and reports that, with the fallback documented in the worklog. Either way, **no `game_state.gd` edit**.

---

## 5. Pseudocode — the hazard node

GDScript-flavoured pseudocode for `HazardEntity` (a `CharacterBody2D`). **Illustrative, not final code** — the programmer owns the real implementation and may simplify. Reads `GameState.active_run_config` and `GameState.current_depth_index`; emits the two pre-declared signals; routes run-end through `fail_run`.

```gdscript
# scenes/hazards/hazard_entity.gd  (illustrative)
class_name HazardEntity
extends CharacterBody2D

enum State { DORMANT, AWAKE }

var _cfg: RunConfig                 # snapshot of GameState.active_run_config at spawn
var _state: int = State.DORMANT
var _time_in_band: float = 0.0      # seconds since spawn (≈ band entry)
var _player: Node2D                 # resolved via get_first_node_in_group("player")
var _tell: Node2D                   # the ColorRect/Polygon2D greybox shape

func setup(cfg: RunConfig, player: Node2D) -> void:
    _cfg = cfg
    _player = player
    _set_tell_dormant()             # cool color, stationary

func _physics_process(delta: float) -> void:
    if _player == null or _cfg == null:
        return
    _time_in_band += delta

    if _state == State.DORMANT:
        if _should_awaken():
            _awaken()
        return                      # dormant: no movement, no catch test

    # --- AWAKE ---
    var depth: int = GameState.current_depth_index          # BUG2 live depth
    var speed: float = _cfg.r1_chase_speed + _cfg.r1_speed_per_depth * float(depth)

    var to_player: Vector2 = _player.global_position - global_position
    var dir: Vector2 = to_player.normalized() if to_player.length() > 0.001 else Vector2.ZERO
    velocity = dir * speed
    move_and_slide()                # walls (layer 2 = world) stop it; sliding is fine

    # catch test (distance-based, deterministic, no physics overlap needed)
    if global_position.distance_to(_player.global_position) <= _cfg.r1_catch_radius:
        _on_catch(depth)

func _should_awaken() -> bool:
    var depth: int = GameState.current_depth_index
    if depth >= _cfg.r1_depth_threshold:
        _pending_trigger = &"depth"
        return true
    if _cfg.r1_linger_seconds > 0.0 and _time_in_band >= _cfg.r1_linger_seconds:
        _pending_trigger = &"linger"
        return true
    return false

func _awaken() -> void:
    _state = State.AWAKE
    _set_tell_awake()               # hot color + one-shot wake-flash Tween
    EventBus.hazard_awoke.emit(GameState.current_depth_index, _pending_trigger)

func _on_catch(depth: int) -> void:
    # run_t_ms: BUG1's run clock if reachable read-only; else time_in_band*1000 (§4)
    var run_t_ms: int = _run_elapsed_ms()
    EventBus.hazard_caught.emit(depth, run_t_ms)
    if _cfg.r1_catch_kills:
        GameState.fail_run(&"death")   # existing end path; its _run_ended guard
                                        # makes this idempotent vs. other hazards/extract
        # (this hazard need not free itself; the run-end teardown clears the band)
    else:
        _apply_nonfatal_catch()        # ratified Q2: knockback + brief stun/slow +
                                        # short hazard cooldown; NO fail_run, NO
                                        # other-system coupling. Chase then continues.
```

**Spawn-seam pseudocode** (in `main_game.gd`'s `start_new_run()`, after the player is placed at §5 step 5, before/after `start_run` — see §7):

```gdscript
# main_game.gd  — inside start_new_run(), after _player is positioned
var rc: RunConfig = GameState.active_run_config        # or the staged config
if rc != null and rc.r1_enabled and rc.r1_spawn_count > 0:
    for i in rc.r1_spawn_count:
        var hz: HazardEntity = HAZARD_SCENE.instantiate()
        _band_container.add_child(hz)
        hz.global_position = _hazard_spawn_position(band, i)   # at/near the piece
                                                                # at r1_depth_threshold
                                                                # (ratified Q1)
        hz.setup(rc, _player)
# r1_enabled == false → loop above never runs → no hazard, exact M1.0 behaviour
```

> **Idempotency note for the programmer:** do not implement a local "already ended" bool in the hazard that *prevents* calling `fail_run`. Call `fail_run` and let `GameState`'s `_run_ended` guard absorb duplicates — that is the single source of truth for run-end (M1_As_Built E3 #13). The only local guard a hazard may keep is one preventing it from re-emitting `hazard_caught` every frame while overlapping (emit once per catch, then cooldown/stop).

---

## 6. Config defaults recommendation

Two recommended presets for the Director. Defaults in `run_config.gd` are already **all-off** (R0) — that is the permanent M1.0 control and must stay. The "interesting" set below is a **suggested starting point for the first sweep**, explicitly *configurable, not balanced* — expect the Director to move every number.

### 6.1 All-off (the shipped default — do not change)
Every `r1_*` at the `run_config.gd` default (`r1_enabled = false`, all magnitudes `0`). No hazard spawns; loop == M1.0. This is the in-build control RG2 measures against.

### 6.2 Suggested "interesting" first-sweep set (Director tunes from here)

| Field | Suggested value | Rationale (greybox feel, not balance) |
|---|---|---|
| `r1_enabled` | `true` | turn it on |
| `r1_depth_threshold` | `3` | wakes a few rooms in, so shallow play stays safe and the threat is a *depth* decision (assumes band `max_depth` ≳ 5–6; Director adjusts to the actual seed's depth range) |
| `r1_linger_seconds` | `20.0` | secondary "don't dawdle" trigger; fires if the player loiters shallow without pushing — keeps camping from being a free strategy. Set `0.0` to test depth-only |
| `r1_chase_speed` | `~0.85 × player speed` | slightly slower than the player when shallow, so turning back in time escapes (avoidable-but-punishing). Read the player's actual `move_speed` from `entities/player/player.gd` and set ~85% of it |
| `r1_speed_per_depth` | small positive (e.g. `+4 px/s per depth`) | the core "deeper = faster predator" lever; by deep rooms the hazard out-paces the player, making deep lingering a real bet. Director sweeps this hardest |
| `r1_catch_radius` | `~24` (px, ≈ ¾ player width) | a fair, legible hitbox — not pixel-exact, not huge |
| `r1_catch_kills` | `true` | the clean binary for the first test (see §2.5 + ratified §9 Q2) |
| `r1_spawn_count` | `1` | one predator is the clearest read; multi-spawn (fully independent hazards, ratified §9 Q3) is a later sweep variant |

> The programmer should **not hardcode** these — they live in the Config menu (CFG) / a labelled `.tres` the Director loads. This table is guidance for the Director's first run, recorded so the sweep has a sane origin. (Velocity figures reference the player's real speed in `player.gd`; the spec gives ratios, not absolutes, precisely because it's unbalanced.)

---

## 7. Files to create / touch

**Create (R1-owned, file-disjoint from R2/R3/R4):**
- `scenes/hazards/hazard_entity.tscn` — the greybox hazard scene: a `CharacterBody2D` (collision layer `hazard`, mask `world`) + a child `ColorRect`/`Polygon2D` tell + a `CollisionShape2D`. New folder `scenes/hazards/`.
- `scenes/hazards/hazard_entity.gd` — the `HazardEntity` script (§5). Typed GDScript; reads `GameState.active_run_config` + `GameState.current_depth_index`; emits `hazard_awoke`/`hazard_caught`; calls `GameState.fail_run(&"death")` on fatal catch.

**Touch (one seam only):**
- `scenes/game/main_game.gd` — add the spawn loop in `start_new_run()` (§5 spawn-seam pseudocode), guarded by `r1_enabled && r1_spawn_count > 0`. Also add the player to a `"player"` group if not already (the drop-to-swap follow-up in `M1_As_Built.md` §D3 already wants this; R1 needs `get_first_node_in_group("player")`). This is the **only** shared-file edit and it is additive + fully gated by `r1_enabled`.

**Must NOT touch (contract):**
- `systems/event_bus.gd` — TEL pre-declares `hazard_awoke`/`hazard_caught` in wave 1. R1 only *emits* them.
- `systems/game_state.gd` — R0's `active_run_config` + BUG2's `current_depth_index` are the read surface; `fail_run(&"death")` is the run-end. R1 reads/calls, never edits.
- `systems/telemetry/*` — TEL owns the `EventType` rows that consume the two signals.

**Where the hazard is spawned:** each hazard spawns **dormant at/near the piece at `r1_depth_threshold`** (the threshold-depth piece — ratified §9 Q1), so the predator "lives in the deep" and pushing past the threshold means walking into its lair. It is added into `_band_container` during `MainGame.start_new_run()`, **after** the player is positioned at the entry (§5 step 5) and after the config is staged/`start_run` binds `active_run_config`. The helper `_hazard_spawn_position(band, i)` resolves a floor cell on/near the `r1_depth_threshold` piece (if `r1_depth_threshold` exceeds the band's max depth, clamp to the deepest piece). Spawning into `_band_container` means the existing `_clear_band()` teardown disposes hazards on run-end / next run for free (no extra cleanup path). Confirm `active_run_config` is readable at the spawn point (it is, once `stage_run_config` + `start_run` have run — order the spawn after line ~151).

---

## 8. Acceptance criteria (restated from `M1.1_Breakdown.md` §4 R1)

1. With **R1 on**, the hazard **awakens per its threshold** (depth `r1_depth_threshold` reached **or** `r1_linger_seconds` elapsed), **visibly chases** the player (greybox shape moves toward the player, color flipped to "awake"), and **can end a run as `death`** (fatal catch within `r1_catch_radius` routes through `GameState.fail_run(&"death")`; pockets fraction applies; `run_ended.reason == "death"`).
2. With **R1 off** (`r1_enabled = false`), **no hazard exists** and behaviour matches M1.0 exactly (no node, no telemetry rows, no behavioural delta).
3. **All knobs take effect from the Config menu** (CFG) — `r1_depth_threshold`, `r1_linger_seconds`, `r1_chase_speed`, `r1_speed_per_depth`, `r1_catch_radius`, `r1_catch_kills`, `r1_spawn_count` each observably change behaviour when set; none is hardcoded/unreachable.
4. **Events log:** with R1 on, `hazard_awoke(depth, trigger)` fires once per hazard at awaken and `hazard_caught(depth, run_t_ms)` fires on catch; both appear as config-marked TEL rows; with R1 off, neither appears. The locked `run_ended` arity is unchanged.

**Process acceptance (work-product contract):** a shared R1 worklog names the real commit SHA(s) for the programmer + character-animator contributions; the headless smoke test / parse check is green; `godot --headless --import` compiles the new scene/script; the all-off default still reproduces M1.0.

---

## 9. Resolved Decisions (Director-ratified 2026-06-19 — apply-all-recommendations)

The Director ruled on 2026-06-19 to **adopt every recommendation in this section as a ratified decision**. The questions below are now closed; the body of this spec (§2–§8) commits to these answers. An implementing agent reads a **single definite spec** — there are no remaining Director calls inside R1's wave-2 scope. Items flagged here as "new knob / R0 follow-up" are explicitly **out of scope for R1 wave 2** and are not to be added.

- **Q1 — Spawn location.** **Decision: spawn the `r1_spawn_count` hazards dormant at/near the piece at `r1_depth_threshold` (the threshold-depth piece — option (a)).** *Rationale:* ties the hazard's location to the depth axis so pushing past the threshold feels like crossing into its lair — the strongest "deeper = danger" read. The entry-spawn "cut off from the exit" variant (b) would need a new `r1_spawn_anchor` knob beyond R0's schema and is deferred as a possible R0 follow-up, **not** built in wave 2.

- **Q2 — `r1_catch_kills = false` cost-instead-of-kill meaning.** **Decision: a non-fatal catch applies knockback + a brief stun/slow + a short hazard cooldown, fully self-contained, with `hazard_caught` emitted (tagged non-fatal) and no `fail_run` and no other-system coupling (option (a)).** *Rationale:* keeps R1 self-contained and the single-variable test clean; dropping items / shaving the clock / adding exposure would entangle R1 with R2/R3/R4 and muddy the signal. `r1_catch_kills = true` remains the first-gate value (§6.2).

- **Q3 — Multiple spawns behaviour.** **Decision: hazards are fully independent — each owns its own dormant/awake state and catch test, they do not collide with or block each other (mask `world` only, never `hazard`), and the first to catch ends the run via `GameState`'s `_run_ended` idempotency guard.** *Rationale:* simplest implementation, and a swarm waking at slightly different moments is a fine emergent read. `r1_spawn_count = 1` stays the first-sweep value (§6.2).

- **Q4 — Awaken stickiness / re-sleep.** **Decision: no re-sleep — a hazard latches awake for the rest of the run once triggered and never returns to dormant, even if the player retreats shallow.** *Rationale:* keeps the threat one-directional ("you can't un-ring the bell") and matches "deeper = more dangerous, partly permanent." A retreat-to-safety valve (`r1_resleep_on_retreat`) is a deferred R0 follow-up, **not** built in wave 2.

- **Q5 — Depth on branching layouts + `run_t_ms` clock source.**
  - **Decision (depth): R1 reads `GameState.current_depth_index` — the live within-band depth of the piece the player occupies (BUG2) — and uses that live value for both the awaken trigger and the chase-speed math.** *Rationale:* simplest for the greybox, and the once-only awaken latch (Q4) makes a transient depth dip on a branch harmless. Re-keying the awaken trigger to *max depth reached* is a deferred one-line tweak to revisit only once R4's branching layouts exist; it is **not** built in wave 2.
  - **Decision (`run_t_ms`): R1 reads BUG1's real run-elapsed clock read-only off `GameState`/`Telemetry` when it is exposed; if it is not reachable read-only, the hazard times from its own spawn (≈ band entry ≈ run start in single-band M1) and the worklog documents that fallback.** *Rationale:* prefers the canonical run clock without editing `game_state.gd`, with a documented self-timed fallback so R1 never blocks on BUG1.

---

*Spec authored by game-director-designer for M1.1 R1. Design-only — no code, no `.tres`. The programmer + character-animator build against this. **All Q1–Q5 calls are Director-ratified (2026-06-19, apply-all-recommendations) and folded into the body above** — the spec commits to one design. Deviations from this committed design go to `DESIGN_DEVIATIONS.md` for the wave-2 close-out sweep.*
