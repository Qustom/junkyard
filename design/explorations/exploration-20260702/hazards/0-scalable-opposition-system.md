# Scalable Opposition System — Architecture Exploration (v2)
**Category:** Cross-cutting system / architecture
**Date:** 2026-07-02
**Supersedes:** [exploration-20260625 v1](../../exploration-20260625/hazards/0-scalable-opposition-system.md) — this is a refinement pass, not a rewrite. It keeps v1's taxonomy (Actor/Field/Fixture), component model, `OppositionDef.tres`, determinism contract, generic-EventBus signals, prior-art research, and migration spine; it corrects one structural mistake and answers two questions v1 left open.

> Architecture exploration only. Pseudocode is illustrative against the real as-built APIs; no production code, no contract widening, no branch. v1's non-negotiables are carried intact and made explicit at the end: **all-off byte-identical baseline, no global RNG in generation-time placement, the EventBus pre-declare rule, primitives-only telemetry payloads.**

## What v2 changes

v1 was right that "an opposition is data + small composable behaviors placed by a credit Director." But it made one structural error and dodged two questions the Director has now put on the table:

1. **v1 fused mechanism and policy into one `OppositionDirector`** that both *decides what to spawn* and *does the spawning*. That blocks the thing v1's own companion band-gen doc promised — a spawn seam other systems (a set-piece injector, a death-spawn, a debug menu, a test harness) can call. **v2's headline: split it into a policy-free `SpawnService` (mechanism) and one-or-more `EncounterBuilder`s (policy).**
2. **v1 moved per-type knobs into an untyped `params` Dictionary** but never said how the Director's tune-and-sweep surface survives that. Today's `ConfigMenu` is *hand-authored rows over `RunConfig`'s `@export` fields with a build-time coverage assertion* (`config_menu.gd:84`, `:414`) — a model that has no metadata to reflect over once knobs live in `params`. **v2 answers: a `param_schema` on `OppositionDef`, and the coverage-assertion invariant generalized per-def.**
3. **v1 said little about who else calls the spawner.** v2 enumerates the real future clients and shows one API serves all of them, with per-client RNG discipline so mid-run reinforcements never poison `fingerprint()`.

## What exists today (as-built)

The spawner is `main_game._spawn_new_hazards` (`main_game.gd:385-486`) plus its two helpers `_new_hazard_descriptors` (`:357-365`) and `_new_hazard_spawn_ctx` (`:496-507`). Read against the mechanism/policy lens, it is **both layers fused in one method**:

- **Policy it does:** builds a descriptor table from `RunConfig` (`:357`), pre-filters to enabled+non-neutral types (`:410-420`), computes per-type depth-scaled counts `n = base + floor(per_depth*depth)` (`:457`), and fair-shares the band ceiling across active types so a dense early type can't starve a later one (`:400-435`, the L6 fix).
- **Mechanism it does:** walks pieces in a stable RNG-free order (`_density_pieces_sorted`, `:734`), strides cells (`:473-475`), `instantiate()` + `add_child` into `_band_container` (`:477-478`), `reset_physics_interpolation()` (`:482`), and calls the locked `setup(cfg, player, spawn_ctx)` handshake (`:483`). Nodes are freed with the band by `_clear_band()` — lifecycle is "parent under the band container."
- **The band ceiling** `NEW_HAZARD_BAND_CEILING = 48` (`:337`) is a hard cap enforced inline; R1 keeps a *separate* `R1_DENSITY_BAND_CEILING = 64` (`run_config.gd:37`). Two ceilings, two code paths, no shared registry.

The keepers (load-bearing, carry forward): placement is **pure run-state on the already-graded band — no global RNG, never feeds `fingerprint()`** (the R1/K5i contract); the per-instance **`spawn_ctx` Dictionary** is already a primitive component-parameter channel (`:496-507`); each entity **snapshots its config at `setup()`** so a run-end `active_run_config` clear can't null it mid-frame (`hazard_entity.gd:119-128`, `pingpong_hazard.gd:63-72`); the **BUG6 rising-edge latch** de-storms telemetry (`hazard_entity.gd:236-240`); and lethality is **`*_kills`-gated `fail_run` with emit-always** (L5, `hazard_entity.gd:319-323`).

The `ConfigMenu` surface: a **hand-authored `MANIFEST`** of one row per `RunConfig` field (`config_menu.gd:84-162`), a per-field `FIELD_RANGE`/`FIELD_STEP` table (`:209`, `:290`), and a **build-time coverage assertion** `has_full_coverage()` that reflects `RunConfig` via `get_property_list()` (`:446-455`) and fails loudly if any exported knob is unbound or any bound row references a dead field (`:414-437`). That "surface 100% of knobs + fail on drift" invariant is the discipline that caught config drift across M1.1–M1.7; **v2 must preserve it, not discard it.**

The band seam (companion doc): `BandProfile.opposition_deck` + `band_depth`, and the claim that all three backends (socket|cave|scatter) produce the *same* placement context — floor cells + `depth_index`/`depth_norm` + entry/deepest anchors + `resolved_seed`. `band_generator.generate()` is a pure function returning that graded `Band` (`band_generator.gd:46-64`).

## Prior art (carried from v1)

Unchanged and still load-bearing: **RoR2 credit/spawn-card Directors** ([RoR2 Wiki](https://riskofrain2.wiki.gg/wiki/Directors)) — our fair-share ceiling is a primitive credit budget, Instability `I` is the difficulty coefficient; **L4D's category/pacing AI Director** ([Valve, M. Booth](https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf)) — beyond scope, and its live re-spawning would break seed reproducibility, so we borrow the card/credit idea and keep placement a pure function of seed+config; **Enter the Gungeon data-tables** ([BorisTheBrave](https://www.boristhebrave.com/2019/07/28/dungeon-generation-in-enter-the-gungeon/)); **Godot node composition over ECS** with **LimboAI v1.7.1** held in reserve ([LimboAI](https://github.com/limbonaut/limboai)); **Nuclear Throne "everything is an object"** ([GameMaker](https://gamemaker.io/en/showcase/nuclear-throne)). **One addition relevant to v2's split:** the RoR2 model itself separates the *Director* (policy: which card, how many credits) from the act of *spawning* the card's prefab — v2 is drawing that same seam we under-drew in v1.

## Proposed architecture

### The headline: two layers with a named boundary

```
BandPipeline ──(Band + opposition_deck + I)──▶  ENCOUNTER BUILDER (policy)
                                                     │  decides def, cell, ctx
                                                     │  N × spawn(def, cell, ctx)
                                                     ▼
                                                SPAWN SERVICE (mechanism)
                                                     │  validate · instantiate · register
                                                     │  enforce caps · setup() handshake
                                                     │  emit opposition_event
                                                     ▼
                                                live Node in the band container
```

- **Spawn layer — `SpawnService` (mechanism, policy-free).** Owns instantiation, placement validation, the **registry of live instances**, **per-band/per-def hard caps**, **lifecycle** (run-end cleanup), the `setup(cfg, player, spawn_ctx)` handshake, and the EventBus spawn events. It does **not** decide what deserves to spawn — hand it a `def`, a `cell`, and a `ctx` and it makes the node exist (or refuses, by cap). This is the API every client calls.
- **Encounter-builder layer — `EncounterBuilder` (policy).** Decides *what* to spawn *where* and *when*, then calls the spawn layer. v1's credit/card/deck design lives **here**, parameterized by `BandProfile.opposition_deck` and Instability `I`. The Instability-driven band populator is *one* builder — the default. Others: scripted set-piece rooms, the Alarm reinforcement logic, a future pacing director.

The boundary is one method: **`SpawnService.spawn(def, cell, ctx) -> Node`** (plus batch/query helpers). Everything above it is policy; everything below it is mechanism. `main_game._spawn_new_hazards` is exactly this boundary drawn *inside one method today* — v2 pulls the line out into two objects.

### Taxonomy & component model (carried from v1, unchanged)

One umbrella **Opposition** with three host archetypes differing only by engine substrate, behavior composed on top:

| Archetype | Godot host | Hit model | Examples |
|---|---|---|---|
| **Actor** | `CharacterBody2D` | distance-test + latch | pursuer, Charger, Burrower, Splitter, Thief, Sentry |
| **Field** | `Area2D` | per-frame zone test | Gas, Conveyor, Magnet, Electrified floor |
| **Fixture** | `Node2D`/`StaticBody2D` | scripted FSM | Bomb, Spikes, Crusher, Sweeping laser, Mimic loot |

Behavior is `0..N` `class_name`-typed component child nodes reading the shared descriptor (Movement / Trigger / Telegraph / Lethality / ThrowInteraction / SpawnRule / Emitter). "Add an opposition = pick + configure components," ≈8 blocks built once. See v1 §"Composition model" for the full set and the per-opposition composition table — unchanged.

### Data layer — `OppositionDef.tres` + `param_schema` (axis 2)

v1's descriptor, with **one addition that makes the debug menu generatable** — a `param_schema` array that gives the untyped `params` bag the type/range/gloss metadata a menu needs:

```gdscript
class_name OppositionDef extends Resource
@export var id: StringName                     # &"charger" — stable; events/telemetry/save
@export var display_name: String
@export_enum("actor","field","fixture") var archetype: String = "actor"
@export var host_scene: PackedScene

# --- Spawn card (read by the encounter builder, NOT the service) ---
@export var credit_cost: int = 1               # band-budget cost of one instance
@export var spawn_weight: float = 1.0          # relative draw weight in its deck slot
@export var min_band: int = 0                  # depth gate (uses Instability I)

# --- Hard caps (read by the SERVICE — every client obeys these) ---
@export var per_room_cap: int = 0              # 0 = uncapped (preset MUST set > 0)
@export var per_band_cap: int = 0              # 0 = fall back to the global ceiling

# --- Component knob bag + its self-describing schema (axis 2) ---
@export var params: Dictionary = {}            # {"charge_speed":220,"recover_s":1.2}
@export var param_schema: Array[Dictionary] = []
#   each: {key:"charge_speed", type:"float", default:220.0, min:0.0, max:400.0,
#          gloss:"CFG_GLOSS_CHARGER_SPEED"}  — the FIELD_RANGE/FIELD_STEP/CSV-gloss
#          tables generalized from per-RunConfig-field to per-def-param.
@export_enum("lethal","chip","knockback","steal","none") var lethality: String = "lethal"
@export var kills: bool = true                 # the L5 *_kills toggle, per-def
```

**Why `param_schema` over the alternatives.** Two other options exist: (a) typed sub-Resources per component with `@export` fields the menu reflects over via `get_property_list()`; (b) keep hand-authoring per def. **Recommend `param_schema`** because it *preserves the exact invariant the current menu depends on*. Today's coverage net is "reflect `RunConfig`'s exported fields; assert bound set == exported set" (`config_menu.gd:446-455`). Generalized per-def: **assert every key in `params` has a `param_schema` entry, and every schema entry names a real `params` key** — the same "surface 100% + fail loudly on drift" discipline, now scoped to a def instead of the global `RunConfig`. Typed sub-Resources (a) give cleaner static typing but scatter the gloss/range across N component scripts, force the menu to recurse `get_property_list()` per component, and blur the single coverage assertion into per-component ones — more moving parts for the same result. Hand-authoring (b) doesn't survive 40 defs. `param_schema` keeps one flat, inspectable, lintable table per def and one coverage rule. (**A Python `.tres` linter should assert the params↔schema bijection at author time** — the run/meta and cross-reference lint this role already owns.)

**RunConfig integration (unchanged from v1, refined).** `RunConfig` does not grow 35 `@export_group`s. It gains generic levers: `oppositions_enabled: Array[StringName]` (which defs are live) and `param_overrides: Dictionary` keyed by `def_id → {param_key → value}` for sweeps. **All-off = empty `oppositions_enabled` → no def loaded → byte-identical baseline**, the same guarantee `all_oppositions_disabled()` (`run_config.gd:429`) gives now. The legacy R1/K5 `@export` groups stay untouched during migration.

### Spawn layer — the `SpawnService` API (axis 1)

A single client-agnostic service (autoload or one instance per dive scene — see Open Questions). Illustrative surface:

```gdscript
class_name SpawnService extends Node
# --- The one boundary method ---
func spawn(def: OppositionDef, cell: Vector2i, ctx: Dictionary) -> Node
#   validate cell is graded floor & not the entry-safe zone (the BUG7 exclusion, main_game.gd:454/468);
#   check caps (per_room / per_band / global ceiling) against the registry — REFUSE (return null) if full;
#   instantiate def.host_scene, add under the band container, reset_physics_interpolation(),
#   register the live instance keyed by def.id, then call the LOCKED setup(cfg, player, ctx);
#   emit EventBus.opposition_event(def.id, &"spawned", depth, run_t_ms). Policy-free.

func spawn_batch(reqs: Array) -> Array[Node]   # [{def, cell, ctx}, ...] — one validation/registry pass
func can_afford(def, cell) -> bool             # would spawn() succeed? (cap + placement pre-check)
func live_count(def_id: StringName) -> int     # registry query — the fair-share/cap accounting source
func despawn(node: Node) -> void               # de-register + free (Splitter parent death, timed expiry)
func clear_all() -> void                       # run-end lifecycle — frees every registered instance
```

The service is the **single writer to the live registry**, which is what lets it enforce caps atomically for *every* client (a death-spawn and the band populator both see the same `live_count`). It resolves the player via the `&"player"` group and threads the config snapshot exactly as the seam does today — the `setup(cfg, player, ctx)` handshake is **unchanged and locked** (`hazard_entity.gd:119`, `pingpong_hazard.gd:63`), so entities need no edit to be driven by the service instead of `main_game`.

**Budget/cap enforcement — where it lives (Director-relevant call, with a recommendation).** Split it:

- **Hard caps + lifecycle + registry → the SERVICE.** `per_room_cap`, `per_band_cap`, the global ceiling, and run-end cleanup are *safety ceilings every client must obey no matter who spawns*. They can only be enforced atomically by the single owner of the live registry. A death-spawn client cannot see the band populator's spend accounting, but it **must** still be stopped at the ceiling — so the ceiling lives where every client passes through: `spawn()`. This also unifies today's two separate ceilings (`NEW_HAZARD_BAND_CEILING`, `R1_DENSITY_BAND_CEILING`) into one registry-backed cap.
- **Credit budget → the BUILDER.** *How many* credits a band gets and *which* affordable card to spend them on is pure economy policy — it belongs to the populating builder, parameterized by `I` and the deck. The service never sees "credits"; it only ever answers "are you under the cap?" via `can_afford`.

The honest counter-argument: putting caps in the service means a builder that wants to *intentionally* exceed a per-room cap for a scripted boss room has to go through an override. That's acceptable — the override is an explicit `ctx` flag (`{"ignore_room_cap": true}`) the set-piece builder sets deliberately, which is *better* than silent cap-free spawning. Caps-in-service with an explicit escape hatch beats caps-in-builder where each of five clients re-implements the ceiling.

### Encounter-builder layer — the policy clients (axis 3)

The builder consumes band context + deck + `I` and emits spawn calls. The default and the sequence:

```gdscript
class_name EncounterBuilder extends RefCounted   # the default band populator
func populate(band: Band, deck: Array[OppositionDef], I: float, svc: SpawnService) -> void:
    var budget := int(BASE_CREDITS * (1.0 + 0.15 * band.band_depth))   # GDD +15%/band via I
    var eligible := deck.filter(func(d): return band.band_depth >= d.min_band)
    for p in _pieces_depth_sorted(band):           # stable, RNG-free order (main_game.gd:734)
        if budget <= 0: break
        for d in _deck_order(eligible):            # stable id order — deterministic "draw"
            var n := d.base + int(floor(d.per_depth * p.depth_index))
            for k in n:
                if budget < d.credit_cost: break
                var cell := _stride_cell(p, k)     # deterministic cell pick (main_game.gd:473)
                if svc.spawn(d, cell, _ctx(d, p, k)) != null:   # service enforces caps
                    budget -= d.credit_cost
```

Sequence sketch: **`BandPipeline` → (`Band` + `deck`) → `EncounterBuilder.populate(band, deck, I, svc)` → N × `SpawnService.spawn(def, cell, ctx)`.** The band-gen doc's handoff ("band hands placement context to the opposition spawner") **terminates at the builder, not the service** — the builder consumes the graded band + deck + budget; the service only receives per-instance spawn calls. This is the one-directional data seam v1 promised, now correctly addressed.

**The realistic future clients of the API — different clients, one API:**

| Client | Layer | Call shape | Determinism class |
|---|---|---|---|
| **(a) Instability band populator** (default) | builder | `populate(band, deck, I, svc)` → many `spawn()` | **Seed-deterministic** — generation-time, RNG-free stable walk; feeds nothing to `fingerprint()` but must be reproducible from seed+config |
| **(b) Death/timer re-entry** (Splitter children, Alarm reinforcements) | builder-lite / entity | `svc.spawn(child_def, self_cell, ctx)` mid-run | **Legitimately run-state** — reacts to player-caused deaths/timing; NOT reproducible and must not touch the layout RNG stream |
| **(c) Set-piece injector** (authored encounter rooms from the band pipeline's flavor stage) | builder | `svc.spawn(def, authored_cell, {"ignore_room_cap": true})` at generation time | **Seed-deterministic** — placed during generation; authored cells, no RNG |
| **(d) Debug menu / test harness** ("spawn a charger at cursor") | direct | `svc.spawn(charger_def, cursor_cell, {})` | **Explicitly non-deterministic + telemetry-dirty** (see axis 2 below) |
| **(e) Future scripted encounters / quest beats** | builder | scripted sequence of `spawn()` / `despawn()` | Per-beat: authored = deterministic; reactive = run-state |

The key safety property: **generation-time clients (a, c) never call the global `RNG`** — they derive any per-instance variation from `depth_index`/spawn-index (`phase_salt = depth_index * 131 + k`, `main_game.gd:505`), exactly as today, so `fingerprint()` never moves for a given config. **Mid-run clients (b, d) are run-state by definition** — a Splitter spawning children in reaction to being thrown at is not part of the seeded layout, so it may use run-state values freely *provided it routes through `spawn()` (which touches no layout RNG) and never writes back to the generator*. The service enforces this by construction: it has no access to the band-generation RNG stream; it only reads the already-graded band. That is what makes one API safe for both the deterministic and the reactive client without poisoning determinism.

### Debug menu — how the tune-and-sweep surface scales (axis 2)

The problem restated: `ConfigMenu` is hand-authored rows over `RunConfig`'s `@export` fields with a coverage assertion (`config_menu.gd:84`, `:877`, `:414`). Once per-type knobs live in `params` Dictionaries (untyped, unbounded set of defs), that model has nothing to reflect over. The fix has three parts:

1. **Generate rows from `param_schema`, not hand-authoring.** The menu iterates loaded `OppositionDef`s; for each, one **collapsible section** (reusing the existing section/tab pattern, `config_menu.gd:540`) generated from `param_schema` — each entry's `type` picks the widget (`bool→CheckButton`, `float/int→slider+SpinBox`, `enum→OptionButton`, exactly `_build_row`'s dispatch at `:891-905`), `min/max` fills the slider range (the `FIELD_RANGE` table becomes per-param), `gloss` the label. **The coverage assertion generalizes:** instead of "bound set == `RunConfig` exported set," assert **for every loaded def, `params.keys()` == `param_schema` keys** — no unschema'd param, no orphan schema entry. Same fail-loud net, per def. At 40 defs × ~6 params the menu is 40 generated collapsible sections with search/filter and "recently touched" pinning; UX stays greybox-realistic because nothing is bespoke — it's the current row builder driven by data.

2. **Live editing vs. the config-snapshot discipline.** `ConfigMenu` today is pre-run staging only (`apply_and_get_config()` read at the *next* dive, `config_menu.gd:405`). A debug menu that modifies enemies wants **live** editing — select a live instance or a def, tweak `charge_speed`, watch it change. This collides with the config-snapshot discipline (entities snapshot at `setup()` precisely because run-end clears `active_run_config`, `hazard_entity.gd:119-128`). Reconcile it with **three tiers, cheapest first:**
   - **v1 (cheap, ship first): "respawn with new params."** Edit the def's `params`, then `svc.despawn(node)` + `svc.spawn(def, same_cell, ctx)`. No component change at all — the new instance snapshots the new value at `setup()`. Covers 90% of "does this feel better" tuning.
   - **v2 (read-through defs): components re-read `params` from the shared `OppositionDef` Resource each frame instead of snapshotting.** Because defs are Resources, editing the shared def propagates to every instance that reads through. This trades the snapshot's null-safety (run-end clears `active_run_config`, but the *def* is not run-state — it's content, so it survives) for live feel. **Only opt specific hot params into read-through**; keep the config snapshot for run-lifecycle values.
   - **per-instance override:** the `ctx` Dictionary already carries per-instance params (`spawn_ctx`, `main_game.gd:496`). A debug "tweak this one instance" writes `ctx`-level overrides the component prefers over the def.

3. **Sweep/experiment hygiene — the debug menu must not pollute gate metrics.** `RunConfig.param_overrides` keyed by def-id remains the *config-marked-telemetry* vehicle: a staged sweep is a labeled experiment, stamped on the `run_started` row like `to_flat_dict()` does today (`run_config.gd:455`). But a **live** debug-menu tweak is not a staged config — so it **marks the run telemetry-dirty/experimental** (a `debug_dirty: true` flag on the run row), exactly as the config-trap detector (`inert_enabled_oppositions()`, `run_config.gd:597`) marks inert configs, so the gate can filter debug-polluted runs out of the cohort. The **all-off baseline is untouched**: an empty `oppositions_enabled` loads no def, so the debug menu has nothing live to tweak and the byte-identical control holds. The config-trap detector generalizes too — "an enabled def whose load-bearing param is neutral" is the same check, now reading `param_schema` to know which param is load-bearing.

### EventBus / telemetry contract (carried from v1)

Two generic signals, pre-declared per the existing rule (`event_bus.gd` house style), payloads primitives-only:

```gdscript
signal opposition_event(id: StringName, event: StringName, depth: int, run_t_ms: int)
signal opposition_killed_player(id: StringName, depth: int, run_t_ms: int)
```

`opposition_event` carries `&"spawned"/&"awoke"/&"telegraph"/&"hit_player"/&"killed_by_throw"/&"state"`; the second is the dedicated death channel (kept separate exactly as L1 kept `throw_killed_hazard` from `new_hazard_killed`, `event_bus.gd:175`, to avoid poisoning death counts). **The `SpawnService` emits `&"spawned"` centrally** — one more reason the mechanism layer is the right home for it: every client's spawn is logged identically without each builder re-emitting. Subscribers filter by `id`/`event`; a new opposition emits the same two signals, no `event_bus.gd` edit. Legacy R1/K5 signals stay during migration, then deprecate.

## Per-opposition fit table (updated for the two-layer split)

The split *clarifies* the awkward v1 rows — the ones that were "cross-system" are now "a different encounter-builder client," not architecture gaps:

| Explored case | Archetype | Layer note (what the split clarifies) | Fits? |
|---|---|---|---|
| Pursuers (Charger/Burrower/Leaper/Pack) | Actor | populator builder → `spawn()`; movement component is the delta | Yes |
| Ranged (Sentry/Lobber/Spinner) | Actor | `Emitter` spawns `Projectile` via **`svc.spawn()`** — projectiles are client (b)-style mid-run spawns through the same service | Yes |
| Static traps (Spikes/Crusher/Laser) | Fixture | populator or set-piece builder | Yes |
| Conveyor/Ice | Field | **none** lethality; force in 3 integration touch-points | Yes |
| Zones (Gas/Electrified) | Field | needs the **HP pool** (M2 dep) | Partly (M2) |
| **Alarm spawner** | Actor | **Clarified by split:** the Alarm *is a builder client (b)* — a `TimerTrigger` component calls `svc.spawn(reinforcement_def, cell, ctx)` mid-run; the service's cap stops it flooding. v1 called this "SpawnRule(timer)"; it's cleaner as "a tiny builder that calls the service." | Yes |
| **Splitter** | Actor | **Clarified:** death-spawn is client (b) — on throw-death the entity calls `svc.spawn(child_def, self_cell, ctx)`; the per-band cap is free from the registry. | Yes |
| **Mimic loot** | Fixture | **Clarified by split:** the Mimic is a **set-piece builder client (c)** that spawns through `JunkPlacer`'s loot slot *and* registers an opposition — two clients, one boundary. Still the genuine cross-subsystem case, but the split names *where* it lives (a builder that talks to both), not an architecture fork. | Awkward but placed |
| Throw-synergy (Eater/Reflector/Armored) | Actor | `ThrowInteraction` component | Yes |
| Tethered pair | Actor ×2 + link | still wants a tiny "link" coordinator no single host owns | Awkward |

**Doesn't fit cleanly (honest):** Tethered pair (a *relation* between two hosts — needs a coordinator node); Gas/Electrified/Rising-tide (Field shape but depend on a **player HP pool** that doesn't exist in M1 — a real M2 prerequisite, not a gap). The Mimic and Alarm/Splitter, which v1 flagged as awkward *cross-system* cases, are now cleanly *builder clients* — that is the split earning its keep.

## Migration path (v1 phases A–D, revised to introduce the split)

Phased, baseline-parity-preserving — never refactor working hazards in one breaking pass. The split is introduced **at Phase A** (as the service seam) and **Phase C** (the builder), not bolted on later:

1. **Phase A — introduce `SpawnService` as a thin wrapper (no behavior change).** Extract *only the mechanism half* of `_spawn_new_hazards` into `SpawnService.spawn/register/clear_all`, leaving the policy half (descriptor table, fair-share, counts) calling into it. The service starts as a no-op-equivalent: same instantiation, same `add_child`, same `setup()` handshake, same ceiling — just relocated behind the API. Author the existing four hazards as `OppositionDef`s whose `host_scene` is the current `.tscn` unchanged. **Acceptance:** the all-off `fingerprint()` and every `test_rg1_m1*_verify.gd` byte-match (placement is unmoved — it's the same code, relocated).
2. **Phase B — extract components + `param_schema` (internals only).** Refactor the four shipped entities' internals into the shared components (the L2 `Patrol` mover, the BUG6 latch, the L5 lethality, the telegraph), and author each def's `param_schema` mirroring its current knobs. Observable behavior + telemetry stay identical. Riskiest step — gate behind the verify suite + a determinism fingerprint diff.
3. **Phase C — introduce `EncounterBuilder` (policy out of `main_game`).** Move the descriptor table + fair-share + depth-scaled counts out of `main_game` into `EncounterBuilder.populate`, driven by `BandProfile.opposition_deck` + `I`. `main_game` now just calls `builder.populate(band, deck, I, svc)`. This is where the fused method finally becomes two objects. **Acceptance:** default preset still spawns the same cohort (the builder reproduces the fair-share math); all-off still empty-deck no-op.
4. **Phase D — generic signals + generated debug menu.** Add the two `opposition_*` signals (dual-emit with legacy), migrate subscribers; generate the debug-menu sections from `param_schema` with the per-def coverage assertion; wire `param_overrides` + the `debug_dirty` telemetry flag. Retire per-type signals once RG telemetry continuity is confirmed.
5. **Phase E — new oppositions are data-only + new builder clients.** New explored ideas ship as `.tres` + component reuse (the "Charger = def + `ChargeLane` component" proof). The first *builder-client* PR (Splitter death-spawn or Alarm reinforcement calling `svc.spawn` mid-run) proves the multi-client API. Mimic/set-piece builder comes with the band pipeline's flavor stage.

Throughout, `RunConfig`'s R1/K5 groups stay until Phase E, so no existing preset or telemetry breaks mid-migration.

## Open questions (fresh ones raised by the split; Director calls flagged)

- **Where does `SpawnService` live — autoload vs. per-dive node? (scope — Director; recommendation.)** An autoload is always-available for the debug menu + test harness and matches the `EventBus`/`GameState` discipline; a per-dive node is torn down with the band for free (matching `_clear_band()` lifecycle). **Recommendation:** a **per-dive node** owned by `main_game`, so `clear_all()` is guaranteed on scene teardown and the run/meta boundary stays crisp (the service holds only run-state — the live registry). The debug menu/test harness resolves it via a group (`&"spawn_service"`) rather than an autoload ref. Revisit only if a between-runs (hub) client ever needs it.

- **Is the encounter builder "part of Instability," or is Instability an input to it? (design — Director; recommendation.)** **Recommend: Instability `I` is an *input scalar*, the builder is its own thing.** `I` is a GDD-level difficulty coefficient that drives enemy stats *and* loot tier *and* the credit budget together (the design direction's "+15% per band" linear growth). If the builder *owned* `I`, we'd couple loot generation and enemy stat scaling to the opposition populator, which is wrong — `I` is a shared input read by `JunkPlacer` (loot tier), the entities (stat scaling), and the builder (budget). The builder consumes `I`; it does not define it. (This keeps the door open for the band-gen doc's separate consumption of `I` for depth grading.)

- **One builder or a builder registry? (scope — Director.)** The default populator, the set-piece injector, the Alarm/Splitter mid-run clients, and a future pacing director are all "builders." **Recommendation:** don't build a builder *framework* — the default populator is a concrete class; mid-run clients (b) are just entities calling `svc.spawn` directly (no builder object needed); the set-piece injector is a band-pipeline flavor stage that happens to call the service. Add a formal builder-registry only if/when a pacing director needs to arbitrate between multiple simultaneous policies (M2+).

- **Read-through defs vs. respawn for live tweak — how far to push? (effort — Director; recommendation.)** Read-through gives the best live feel but complicates the snapshot discipline. **Recommendation:** ship "respawn with new params" (v1) as the debug-menu default; opt *only* named hot params into read-through if playtesting shows respawn-flicker is disruptive. Don't make read-through the universal model — the config snapshot exists for a reason (run-end null-safety).

- **The `I` ↔ credit-budget mapping is a balance call, not architecture.** How many credits a band gets and each def's `credit_cost`/`spawn_weight`/`min_band` are economy-model + fun-gate sweeps (the M3 tuning pass, and this role's economy workbook), not decidable here. Flag for M3.

- **Per-def cap vs. global ceiling precedence.** With `per_room_cap`, `per_band_cap`, and a global registry ceiling all in the service, precedence must be defined (recommend: the *minimum* binds, global ceiling last-resort). A `.tres` linter should warn if a def's `per_band_cap` exceeds the global ceiling (dead knob). Technical, not a Director call.

---

**Sources (carried from v1):** [RoR2 Wiki — Directors / spawn cards](https://riskofrain2.wiki.gg/wiki/Directors) · [The AI Systems of Left 4 Dead (M. Booth, Valve)](https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf) · [BorisTheBrave — Enter the Gungeon generation](https://www.boristhebrave.com/2019/07/28/dungeon-generation-in-enter-the-gungeon/) · [LimboAI (GitHub)](https://github.com/limbonaut/limboai) · [UhiyamaLab — Behavior Trees in GDScript](https://uhiyama-lab.com/en/notes/godot/behavior-tree-ai-design/) · [Baldur Games — Behaviour Trees in Godot](https://baldurgames.com/posts/behaviour-trees-godot) · [Nuclear Throne — GameMaker showcase](https://gamemaker.io/en/showcase/nuclear-throne)
</content>
</invoke>
