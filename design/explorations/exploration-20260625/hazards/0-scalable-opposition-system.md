# Scalable Opposition System — Architecture Exploration
**Category:** Cross-cutting system / architecture
**Date:** 2026-06-25

> Architecture exploration only. Pseudocode is illustrative against the real as-built APIs; no production code, no contract widening, no branch. The goal is a model that absorbs (a) the four M1.x hazards already shipped, (b) the 35 graybox ideas just explored, and (c) oppositions we haven't imagined yet — with **minimal new code per addition** and **byte-identical all-off baseline parity** preserved.

## The problem

Every opposition in the build today is **one bespoke script per type**: `hazard_entity.gd` (359 lines), `pingpong_hazard.gd`, `bomb_hazard.gd`, `spike_hazard.gd`. Each is a `CharacterBody2D`/`Node2D` that re-implements, by hand, the same five concerns:

1. **Snapshot the config** at `setup()` so a run-end `active_run_config` clear can't null it mid-frame (the discipline at `hazard_entity.gd:119-128`, copied verbatim into all three K5 entities).
2. **Resolve the player** via the `&"player"` group.
3. **A distance-test** against the player (never a physics overlap — deterministic) gated by a one-shot **rising-edge latch** (the "BUG6 pattern": emit once on entry, re-arm on exit — `hazard_entity.gd:236-240`, `pingpong_hazard.gd:124-129`).
4. **Self-time** a `run_t_ms` from spawn because the run clock isn't exposed read-only (`hazard_entity.gd:316-318`).
5. **Route a kill** through `GameState.fail_run(&"death")` behind a `*_kills` toggle (L5), emitting a telemetry signal *always* and gating only the `fail_run` call.

This duplication is already a tax at 4 types. The 35 new explorations would push it to ~40 scripts, each re-deriving items 1–5. Worse, the *new* behaviors don't fit the current mold at all:

- **Movement variety** — Charger (locked-vector rush + recovery), Burrower (submerge/surface rhythm), Leaper (telegraphed arc), Pack hunters (flocking) — the R1 pursuer is *one* movement style hard-coded into a 359-line file.
- **Projectiles** — Sentry/Lobber/Spinner emit bolts; we have no emitter or pattern abstraction at all (the L1 thrown item is the closest thing, and it's a player tool).
- **Zones** — Gas cloud, Conveyor, Magnet field, Electrified floor are `Area2D` *force/attrition* regions, not `CharacterBody2D` kill-on-touch entities. Gas needs a **survivable HP pool** the game doesn't have.
- **Inventory-synergy** — Thief (`remove_at` on the bag), Eater (grows from thrown items), Mimic (disguised as loot), Weight plate (fires on bag weight) all reach into the inventory/throw subsystems, not the player's position.
- **Spawn-rule variety** — Splitter spawns children on death; Alarm spawner spawns on a timer; Mimic occupies a *loot* slot, not a hazard cell.

A one-script-per-type model can't absorb that spread without 35 more copies of the boilerplate and 35 more `_kills`-style knob blocks bolted onto `RunConfig` (already 60+ fields). We need an architecture where **a new opposition is mostly data + small composable behaviors**, authored in `.tres`, that still routes everything through `EventBus`, stays deterministic, and keeps the all-off control intact.

## What exists today (as-built)

The M1.x system is genuinely good *within its scope* and several of its patterns are load-bearing keepers:

**The fair-share Director (`main_game.gd:403-501`, `_spawn_new_hazards`).** This is already a credit-budget allocator in disguise. It:
- builds a **descriptor table** (`_new_hazard_descriptors`, `main_game.gd:375-383`) — one `Dictionary` per type with `{kind, path, enabled, base, per_depth, cap}` — and **dispatches one generic spawn loop over it** (the kernel of the right idea: data drives placement, the loop is written once);
- enforces a **band-wide ceiling** (`NEW_HAZARD_BAND_CEILING = 48`) split **fair-share** across enabled types so a dense early type can't starve a later one (the L6 follow-up fix);
- places via **depth-scaled per-room counts** (`n = base + floor(per_depth * depth)`, capped per room) walking pieces in a **stable, RNG-free order** (`_density_pieces_sorted`), so placement is pure run-state and **never feeds `fingerprint()`**;
- threads a per-instance **`spawn_ctx` Dictionary** into the locked `setup(cfg, player, spawn_ctx)` signature (`_new_hazard_spawn_ctx`, `main_game.gd:511-522`) — ping-pong reads `initial_dir`+`room_bounds`, spikes read `phase_salt`, bomb ignores it. **This is already a primitive component-parameter channel.**
- excludes the entry piece + a safe radius around spawn (BUG7), so shallow entry stays safe.

**`RunConfig` (`run_config.gd`).** Every opposition is a `@export_group` with an `enabled` master toggle + magnitude knobs, **all-off by default** = byte-identical M1.0 baseline (`all_oppositions_disabled()`), with a **config-trap detector** (`inert_enabled_oppositions()`) that flags "enabled but inert" configs. The named `make_default_play_preset()` is built *on top of* a fresh all-off `RunConfig.new()` so the control is never mutated.

**`EventBus`.** Every opposition **emits, never declares** — signals are pre-declared centrally per milestone (the "pre-declare rule"). Telemetry rows are **primitives only** so they serialize straight to JSONL.

**Where it won't stretch:** the descriptor table only carries *spawn* data (`base/per_depth/cap`); all *behavior* lives in the per-type script. There is no emitter, no zone/force concept, no HP pool, no inventory hook, no death-spawn, no behavior-tree. Adding a 5th type today = a new 200-line script + a new `@export_group`. That's the wall this exploration is for.

## Prior art (researched, cited)

**Director / credit-budget spawning.** *Risk of Rain 2* gives each Director an invisible **credit** pool (scaled by a difficulty coefficient) and a deck of **spawn cards**, each card carrying a **weight**, a **credit cost**, and a **stage condition**; the Director repeatedly draws affordable cards and pays for them until credits run out ([RoR2 Wiki — Directors](https://riskofrain2.wiki.gg/wiki/Directors)). *Left 4 Dead*'s **AI Director** instead spawns by *category* (Wanderers / Mobs / Specials / Bosses) keyed to live player state and pacing ([AI Systems of L4D, M. Booth, Valve](https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf)). **Transfers cleanly:** our fair-share ceiling is already a primitive credit budget; promoting `base/per_depth/cap` to a **cost + weight + band-condition card** is a small, well-trodden step, and the **Instability scalar `I`** is our natural "difficulty coefficient." **Doesn't transfer:** L4D's real-time pacing AI is far beyond M-scope; we want *deterministic* placement (no live re-spawning that would break seed reproducibility), so we adopt the *card/credit* idea but keep placement a pure function of seed+config.

**Data-driven content tables.** *Enter the Gungeon* (Unity) is "very data-driven — adding rooms, layouts, or special behavior is done by adding objects to the appropriate tables," which is credited as what let Dodge Roll ship DLC and mods fast ([BorisTheBrave — ETG generation](https://www.boristhebrave.com/2019/07/28/dungeon-generation-in-enter-the-gungeon/)). This is exactly the `.tres`-as-content philosophy in our TDD §2 ("Data as Resources"). **Transfers directly:** an opposition becomes a `.tres` row, not a script.

**Component composition vs. inheritance.** The Godot-idiomatic answer is **node composition** — a base task `class_name`, with leaf nodes implementing movement/attack and composites (Sequence = AND, Selector = OR) assembling them; "complex AI built from simpler reusable components via hierarchical composition" ([UhiyamaLab — BT in GDScript](https://uhiyama-lab.com/en/notes/godot/behavior-tree-ai-design/), [Baldur Games — BTs in Godot](https://baldurgames.com/posts/behaviour-trees-godot)). The project's **pinned** add-ons are **LimboAI v1.7.1** (BT + state machines, C++ with GDScript task support) and **Beehave v2.9.2** as fallback ([LimboAI](https://github.com/limbonaut/limboai)). Full ECS (Unity DOTS / Bevy) is a *poor* fit for node-based Godot — Godot has no archetype storage or system scheduler, and forcing one fights the engine. **What transfers:** *composition*, *not ECS*. We want a handful of `Node2D` **behavior components** attached to a host scene, configured by a Resource — the Godot "scene = bag of component nodes" idiom, which our `spawn_ctx` already gestures at.

**Effects-as-objects.** *Nuclear Throne* implements **all** effects (even bullet casings) as **objects, not particles** ([GameMaker showcase](https://gamemaker.io/en/showcase/nuclear-throne)). Our greybox already does this (Polygon2D tells, Tween juice). It validates "everything is a small node" at scale for a fast top-down game.

**Net read for us:** adopt **data-driven cards + a credit Director** (RoR2), **composition over inheritance** via a few behavior-component nodes (Godot idiom), keep **LimboAI in reserve** for genuinely tree-shaped enemy AI (M2+), and **resist full ECS**. Determinism is ours to protect — none of the cited Directors are seed-reproducible the way ours must be.

## Proposed architecture

### Opposition taxonomy

One umbrella concept — an **Opposition** — with three *host archetypes* that justifiably differ in their Godot base node, unified by a shared **descriptor Resource**, **component model**, **Director**, and **EventBus contract**:

| Archetype | Godot host | Hit model | Examples |
|---|---|---|---|
| **Actor** | `CharacterBody2D` | distance-test, latch | R1 pursuer, Charger, Burrower, Leaper, Splitter, Thief, Sentry, Spinner, the Hunter |
| **Field** | `Area2D` | per-frame zone test | Gas cloud, Conveyor, Magnet, Electrified floor, Rising tide, Darkness pocket, Sound aggro |
| **Fixture** | `Node2D`/`StaticBody2D` | scripted state machine | Bomb, Pop-up spikes, Crusher, Flame vent, Sweeping laser, Mimic loot, Weight plate |

The split is by **engine substrate** (what node + collision shape it needs), *not* by behavior. Behavior is composed on top (next section), so a Charger and a Burrower are both **Actors** that differ only in their movement component. **Projectiles** are a fourth, *sub*-entity: a lightweight `Projectile` Actor spawned by an **Emitter component**, not a top-level opposition.

### Composition model — behavior components

An opposition host scene is a thin shell (host node + a `Tell` Polygon2D) with **0..N behavior-component child nodes**, each a small `class_name`-typed `Node2D` reading the shared descriptor. Components are the reusable vocabulary; **adding a new opposition is picking + configuring components, not writing a script.** The proposed component set (each ~30-80 lines, written once):

- **Movement** — `MoveToward` (R1), `ChargeLane` (telegraph→locked-vector→recover), `Patrol` (the L2 endpoint pacer, already written), `Burrow` (submerge/surface timer + invuln window), `Leap` (arc), `Flock` (pack), `Drift` (carried by a Field).
- **Targeting / trigger** — `ProximityTrigger` (bomb arm, sound zone), `SightlineTrigger` (Charger lane, Patroller cone), `BagValueTrigger` (Thief, Weight plate), `TimerTrigger` (the Hunter, Alarm spawner).
- **Telegraph** — the color-flip + wake-flash + ring (already idiomatic across all four shipped entities), parameterized by a telegraph duration.
- **Lethality** — the `*_kills`-gated `fail_run` + emit-always (L5), generalized: `lethal | chip(hp) | knockback | steal | none`. Chip introduces the **HP pool** the gas cloud needs.
- **ThrowInteraction** — how the L1 thrown item resolves on this opposition: `die | split (spawn N children) | grow (Eater) | reflect | armor (needs heavy/behind) | feed-stolen-item-back (Thief)`.
- **SpawnRule** — death-spawn (Splitter), timer-spawn (Alarm), loot-slot occupancy (Mimic).
- **Emitter** — fires `Projectile` Actors on a period at an angle function (`aimed | lob-arc | spiral` for Sentry/Lobber/Spinner). The **bullet pattern is a small data-parameterized angle function**, not a per-enemy script.

Composition by example (each row is **data + a list of existing components**, zero new bespoke script):

| Opposition | Archetype | Movement | Trigger | Lethality | Throw | Spawn | Extra |
|---|---|---|---|---|---|---|---|
| **Charger** | Actor | `ChargeLane` | `SightlineTrigger` (ray) | lethal | die | — | recover window = free throw target |
| **Spinner** | Actor (static) | — | always-on (proximity-gated) | — | die (kills emitter) | — | `Emitter(spiral)` → `Projectile` |
| **Conveyor** | Field | — | overlap | **none** | — | — | `Drift` force applied to overlappers |
| **Gas cloud** | Field | — | per-cell fill ≥ threshold | **chip(hp)** | (arcs over) | — | flood-fill grid over `room_bounds` |
| **Thief** | Actor | `MoveToward`/flee | `BagValueTrigger` | **steal** (`remove_at`) | feed-stolen-item-back | — | drops loot on throw-hit |

Each cell maps to a real explored idea and a real as-built primitive (the `Patrol` mover *is* `hazard_entity.gd`'s L2 pacer; the `room_bounds` flood grid *is* the gas sketch's reuse of L2 confinement; `remove_at` + `run_inventory_changed` + `junk_dropped` re-drop are the Thief sketch's named hooks).

### Data layer — the opposition descriptor `.tres`

A new content Resource, `OppositionDef extends Resource` (sibling to `JunkItem`, authored in the inspector). Illustrative schema:

```gdscript
class_name OppositionDef extends Resource
@export var id: StringName                 # &"charger" — stable; events/telemetry/save
@export var display_name: String
@export_enum("actor","field","fixture") var archetype: String = "actor"
@export var host_scene: PackedScene        # the thin shell + its component children

# --- Director / spawn card (RoR2-style) ---
@export var credit_cost: int = 1           # how much band budget one instance costs
@export var spawn_weight: float = 1.0      # relative draw weight within its slot
@export var min_band: int = 0              # band-depth gate (uses Instability I)
@export var per_room_cap: int = 0          # 0 = uncapped (preset MUST set > 0)
@export var rooms_only: bool = false       # exclude corridors (the J3 gate)

# --- Component knob bag (the spawn_ctx generalization) ---
@export var params: Dictionary = {}        # {"charge_speed":220,"recover_s":1.2,...}
@export_enum("lethal","chip","knockback","steal","none") var lethality: String = "lethal"
@export var kills: bool = true             # the L5 *_kills toggle, per-def
```

The `params` Dictionary is the `spawn_ctx` pattern promoted to **authored data**: each component reads only its own keys (`charge_speed`, `spread_seconds`, `arm_count`…), exactly as the K5 entities read `initial_dir`/`phase_salt` today. **RunConfig integration:** rather than 35 new `@export_group`s, `RunConfig` gains *one* generic lever — `oppositions_enabled: Array[StringName]` (which defs are live) + a `param_overrides: Dictionary` keyed by def-id for sweeps — and the per-type knobs **move into the `.tres`**. All-off default = empty `oppositions_enabled` → no def loaded → byte-identical baseline (the same guarantee `all_oppositions_disabled()` gives now). The existing R1/K5 groups stay as-is during migration (see Migration path); new oppositions go data-only.

**Determinism:** placement stays a pure function of `seed + config` (no global `RNG` in the spawn seam — the existing contract). Any per-instance variation a component needs (the spiral phase, the charge-lane offset) is derived from `depth_index`/spawn-index like `phase_salt = depth_index * 131 + k` today — **never** the global RNG, so `fingerprint()` never moves for a given config.

### Spawn / Director layer

Generalize `_spawn_new_hazards` into an **`OppositionDirector`** that consumes `OppositionDef` cards instead of the hard-coded 3-entry descriptor table. Same skeleton, three upgrades:

1. **Band credit budget** scaled by Instability `I` (`budget = BASE * (1 + 0.15 * band)`, matching the GDD's +15%/band) replaces the flat `NEW_HAZARD_BAND_CEILING = 48`. Each def's `credit_cost` is debited as it's placed; the fair-share remainder logic is preserved (it already prevents starvation).
2. **Band-depth gating** via `def.min_band` (a def only enters the deck deep enough) — the data version of "Charger from Band 1, Splitter from Band 2."
3. **Card draw** stays **deterministic**: walk the eligible deck in stable id order, spend the depth-scaled per-room count exactly as today (`n = base + floor(per_depth*depth)`, capped, strided across sorted floor cells). We keep the *credit* concept but **not** RoR2's RNG draw — our placement must reproduce from seed.

Death-spawn (Splitter) and timer-spawn (Alarm) route through the **same Director** via a re-entrant `request_spawn(def, pos, ctx)` call, so children/reinforcements obey the same band ceiling and caps (the Splitter sketch's mandatory spawn-cap becomes the Director's existing budget, free).

### EventBus / telemetry contract

Today each hazard emits a *bespoke* signal (`hazard_caught`, `new_hazard_killed`, `bomb_pulse_started`, `hazard_pursuer_state`…). That doesn't scale to 35 types without 35 signal names. Proposed **two generic signals** (pre-declared per the existing rule), keeping payloads primitives-only:

```gdscript
signal opposition_event(id: StringName, event: StringName, depth: int, run_t_ms: int)
# event ∈ &"spawned"/&"awoke"/&"telegraph"/&"hit_player"/&"killed_by_throw"/&"state"...
signal opposition_killed_player(id: StringName, depth: int, run_t_ms: int)
```

The second is the **dedicated death channel** (kept separate exactly as L1 kept `throw_killed_hazard` separate from `new_hazard_killed` to avoid poisoning RG2's death counts). HUD/audio/telemetry/tests subscribe to the generic pair and filter by `id`/`event` — **decoupled and future-proof**: a new opposition emits the same two signals, no `event_bus.gd` edit. The legacy R1/K5 signals stay during migration for telemetry continuity, then deprecate.

### Determinism & RunConfig parity

The non-negotiables survive intact: (1) **all-off** = empty `oppositions_enabled` → no def loaded → `fingerprint()` byte-identical (the K0 guarantee); (2) placement uses **no global RNG**; (3) the config-trap detector generalizes to "an enabled def whose load-bearing param is neutral"; (4) the named play-preset is still built on a fresh all-off config it never mutates.

## Per-opposition fit table

| Explored category / hard case | Archetype | Key components | Fits cleanly? |
|---|---|---|---|
| **1 Pursuers** (Charger, Burrower, Leaper, Pack) | Actor | Movement variant + trigger + lethal | Yes — movement is the only delta |
| **2 Ranged** (Sentry, Lobber, Spinner) | Actor | `Emitter(aimed/lob/spiral)` + `Projectile` | Yes — needs the new Emitter/Projectile pair |
| **3 Static traps** (Spikes, Crusher, Laser, Flame) | Fixture | `TimerTrigger` + scripted FSM + lethal | Yes — these are closest to today's bomb |
| **3 Conveyor / Ice** | Field | `Drift` force, **none** lethality | Yes — but needs force applied in player/projectile/pursuer integration (3 touch-points) |
| **4 Zones** (Gas, Magnet, Electrified, Darkness) | Field | per-frame zone test + chip/force | **Partly** — Gas/Electrified need the **HP pool** (M2 dep) |
| **5 Time-pressure** (Rising tide, Spreading fire) | Field (map-scale) | monotonic level + per-cell test | **Partly** — tide wants faked elevation on a flat top-down map |
| **5 The Hunter / Alarm** | Actor | `TimerTrigger` + Movement / `SpawnRule(timer)` | Yes |
| **6 Throw-synergy** (Eater, Reflector, Armored) | Actor | `ThrowInteraction` variant | Yes — that's the component's whole job |
| **Tethered pair** | Actor ×2 + link | shared **constraint** between two hosts | **Awkward** — the threat is the *line*, a relation no single host owns; wants a tiny "link" coordinator node |
| **Splitter** | Actor | `ThrowInteraction(split)` → Director re-entry | Yes — death-spawn via Director, cap is free |
| **Mimic loot** | Fixture | occupies a **loot** slot, not a hazard cell | **Awkward** — spawns through `JunkPlacer`, not the OppositionDirector; cross-system |
| **Thief** | Actor | `BagValueTrigger` + steal + flee | Yes — but reaches into inventory (`remove_at`) |
| **Weight plate** | Fixture | `BagValueTrigger` (bag weight) | Yes — same inventory hook as Thief |

**Doesn't fit cleanly (called out honestly):** **Tethered pair** (the hazard is a *relation* between two entities — no component model wants to own a constraint between hosts; needs a small dedicated coordinator). **Mimic loot** (it must masquerade as a `JunkItem` and spawn through `JunkPlacer`, straddling the loot and opposition systems — a genuine cross-subsystem case). **Gas/Electrified/Rising-tide** fit the *Field* shape but depend on a **player HP pool** that doesn't exist in M1 — that's a real M2 prerequisite, not an architecture gap.

## Migration path

Phased, baseline-parity-preserving — never refactor working hazards in one breaking pass:

1. **Phase A (no behavior change).** Introduce `OppositionDef` + `OppositionDirector` as a *parallel* seam that, with an empty deck, is a no-op. Author the **existing four** hazards as defs whose `host_scene` is the *current* `.tscn` unchanged. The Director loads them via the same descriptor data it has now. Verify the all-off fingerprint and every RG verify test (`test_rg1_m1*_verify.gd`) byte-match.
2. **Phase B (extract components).** Refactor the *internals* of the four shipped entities into the shared components (the L2 `Patrol` mover, the BUG6 latch, the L5 lethality, the telegraph), leaving their observable behavior + telemetry identical. This is the riskiest step — gate it behind the verify suite + a determinism fingerprint diff.
3. **Phase C (generic signals).** Add the two `opposition_*` signals alongside the legacy ones; dual-emit; migrate Telemetry/HUD/audio subscribers; then retire the per-type signals once RG telemetry continuity is confirmed.
4. **Phase D (new oppositions are data-only).** New explored ideas ship as `.tres` + component reuse. The first new-type PR proves the "minimal new code" claim — ideally a Charger that is *only* a def + a `ChargeLane` component.

Throughout, `RunConfig`'s R1/K5 groups stay until Phase D, so no existing preset or telemetry breaks mid-migration.

## Open questions

- **How far to push composition in node-based Godot? (effort/vision — Director.)** The honest tension: a full component framework is real engine work, and Godot is *not* ECS — over-abstracting fights the engine ([LimboAI](https://github.com/limbonaut/limboai)). **Recommendation:** build the **handful of components the 35 explorations actually demand** (≈8 movement/trigger/lethality/throw/emitter blocks), *not* a generic ECS. Stop when a new opposition is "def + maybe one new component."

- **Build-vs-buy on LimboAI/Beehave for enemy AI. (effort — Director.)** The shipped hazards are FSM-trivial (color-flip + distance test); a BT add-on is overkill for them and for most graybox ideas. **Recommendation:** keep our lightweight components for graybox/M1.5; reserve **LimboAI** (already pinned) for genuinely tree-shaped M2 enemies (Patroller cone → investigate → chase → return). Don't adopt it as the universal substrate now.

- **Do Field/zone oppositions (gas, conveyor, tide) warrant their own subsystem? (scope — Director.)** They share little with Actors (no chase, no catch latch) and several need an **HP pool** (M2). **Recommendation:** treat **Field** as a first-class archetype but **gate the HP-dependent ones (gas, electrified, tide-as-damage) to M2**; ship the **force-only** Fields (conveyor, magnet) sooner since they need no HP — they're "physics modifiers," not damage.

- **Do throw-synergy oppositions need their own subsystem?** **Recommendation: no** — `ThrowInteraction` as a component (`die/split/grow/reflect/armor/return`) covers Eater/Reflector/Armored/Splitter/Thief without a new subsystem. The one genuine outlier is **Mimic loot** (cross-system with `JunkPlacer`) — flag it as a deliberate special case, not a reason to fork the architecture.

- **Generic vs. per-type EventBus signals. (small judgment — Director may defer to QA.)** Two generic signals scale; per-type signals are more self-documenting and were the milestone house style. **Recommendation:** dual-run during migration, then go generic — the 35-type future makes per-type names untenable, and `id`-filtered subscribers are just as testable.

- **The Instability `I` ↔ credit-budget mapping is a balance call, not architecture.** The +15%/band escalation is settled design; *how many credits* a band gets and each def's `credit_cost`/`spawn_weight` are **economy-model + fun-gate sweeps**, not decidable here. Flag for the M3 tuning pass.

---

**Sources:** [RoR2 Wiki — Directors / spawn cards](https://riskofrain2.wiki.gg/wiki/Directors) · [The AI Systems of Left 4 Dead (M. Booth, Valve)](https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf) · [BorisTheBrave — Enter the Gungeon generation](https://www.boristhebrave.com/2019/07/28/dungeon-generation-in-enter-the-gungeon/) · [LimboAI (GitHub)](https://github.com/limbonaut/limboai) · [UhiyamaLab — Behavior Trees in GDScript](https://uhiyama-lab.com/en/notes/godot/behavior-tree-ai-design/) · [Baldur Games — Behaviour Trees in Godot](https://baldurgames.com/posts/behaviour-trees-godot) · [Nuclear Throne — GameMaker showcase](https://gamemaker.io/en/showcase/nuclear-throne)
