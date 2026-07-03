# S0 — SpawnService Extraction + OppositionDef Data Layer + EventBus Pre-declare — Expanded Design Spec

> **Task:** S0 (M1.9 Wave 1) · **Assignee:** general-purpose (programmer) · **BlockedBy:** none
> **Contract source:** `design/M1_9_Tasks/M1.9_Breakdown.md` §S0 · **Architecture source:**
> `design/explorations/exploration-20260702/hazards/0-scalable-opposition-system.md` (v2, Phase A)
> + its v1 predecessor (`exploration-20260625`, component taxonomy — not consumed by S0, cited for
> continuity only).
>
> S0 is **opposition migration Phase A**: extract *only the mechanism half* of the fused spawn
> method into a policy-free `SpawnService`, author the 4 shipped hazards as `OppositionDef.tres`,
> and pre-declare ALL M1.9 EventBus signals. **Phase A is code relocation — zero behavior change.**

---

## 0. Hard constraints (read first)

1. **All-off fingerprint `e943ac9c8bc1` byte-identical.** The all-off `RunConfig` default is the
   permanent control (`tests/test_corridor_lever.gd:34` pins `BASELINE_FP := "e943ac9c8bc1"`).
   Placement in this seam is pure run-state on the already-graded band and **never feeds
   `fingerprint()`** (`systems/bandgen/band.gd:58`) — S0 must keep it that way *and* keep the
   spawned node set/positions byte-identical for every config, not just all-off.
2. **`setup(cfg, player, spawn_ctx)` handshake LOCKED.** Entities snapshot config at `setup()`
   (`scenes/hazards/hazard_entity.gd:119-131`, `scenes/hazards/pingpong_hazard.gd:63-74`) and are
   **not edited by S0** (entity internals are S2's). The service calls the same three-arg setup.
3. **No global `RNG` in placement.** The seam is RNG-free today (golden-angle fan, stride math,
   stable sorts — `main_game.gd:341`, `:473-475`, `:734-746`); the relocated code stays RNG-free.
   The service never touches the band-generation RNG stream by construction.
4. **Primitives-only signal payloads.** New EventBus signals carry `StringName`/`int` only
   (straight to JSONL, the TEL rule restated at `event_bus.gd:84-86`).
5. **S0 is the SOLE `main_game.gd` + `event_bus.gd` writer in Wave 1** (breakdown §Wave 1; S1
   stays inside `systems/bandgen/` + `data/bands/`). Nobody else touches these files until S3.
6. **Legacy signals dual-emit; nothing retired.** Every existing per-type signal
   (`hazard_awoke`/`hazard_caught`/`new_hazard_killed`/`hazard_pursuer_state`/…) keeps firing
   unchanged. Retirement is post-gate (SG3 watch-item). §5 defines exactly what S0 emits.
7. **Legacy R1/K5 `RunConfig` `@export` groups stay untouched** (`run_config.gd:57-126`,
   `:298-361`). No preset, no telemetry row, no `config_menu` MANIFEST row changes in S0. The
   89-knob coverage assertion (`ui/config/config_menu.gd:414`) is not touched.
8. **No save-schema change. Run/meta boundary holds.** The service holds only run-state (the live
   registry); nothing it owns is ever persisted.

---

## 1. Research on the premise

### 1.1 Why this task

M1.9's thesis is *adding content is data, not engineering*. Today every new hazard type costs an
edit to `main_game._spawn_new_hazards` (a new descriptor row + knobs), an `event_bus.gd` edit
(per-type signals), and a `config_menu` MANIFEST block — three hand-edits per type, none of them
data. The v2 exploration's headline is the split v1 missed: a **policy-free `SpawnService`
(mechanism)** under one-or-more **`EncounterBuilder`s (policy)**, with the boundary drawn at one
method — `spawn(def, cell, ctx) -> Node`. That boundary already exists *inside* today's fused
method; S0 pulls it out into two objects **without moving a single spawn position**. Everything
downstream depends on it: S2 (components) needs the defs; S3 (builder) needs the service to call;
S6b (Splitter) needs the mid-run `svc.spawn` client; S4 needs `param_schema` to generate menu
sections; S8 needs the pre-declared routing signal. S0 is the root of the M1.9 dependency graph.

### 1.2 What exists in-repo (as-built, line numbers re-verified 2026-07-02)

**The fused spawn method** — `Game/scenes/game/main_game.gd`:

- `_spawn_new_hazards(rc, band, spawn_pos)` — `main_game.gd:385-485`. Policy *and* mechanism in
  one method (dissected statement-by-statement in §1.3).
- `_new_hazard_descriptors(rc)` — `:357-365`. The per-type table: `kind`, scene `path`,
  `enabled`/`base`/`per_depth`/`cap` read off the legacy `hpp_*`/`hbomb_*`/`hspike_*` knobs
  (`run_config.gd:298-361`). This is the proto-`OppositionDef` — a Dictionary that wants to be a
  `.tres`.
- `_new_hazard_spawn_ctx(kind, p, k, index, room_bounds)` — `:496-507`. The per-instance
  primitive parameter channel: ping-pong gets `initial_dir` (golden-angle fan, `:341`) +
  `room_bounds`; spikes get `phase_salt = depth_index * 131 + k` (`:505`); bomb gets `{}`.
- Scene-path consts `HPP_SCENE_PATH`/`HBOMB_SCENE_PATH`/`HSPIKE_SCENE_PATH` — `:325-327`
  (`res://scenes/hazards/pingpong_hazard.tscn`, `bomb_hazard.tscn`, `spike_hazard.tscn`); R1's
  `HAZARD_SCENE_PATH` — `:120` (`res://scenes/hazards/hazard_entity.tscn`). All four verified on
  disk.
- `NEW_HAZARD_BAND_CEILING := 48` — `:337`, enforced inline via the `spawned_total` accumulator
  (`:427`, `:430`, `:446`, `:461`, `:484`), fair-shared across enabled types since L6
  (`:424-435`).
- `NEW_HAZARD_SPAWN_SAFE_CELLS := 2.5` — `:350`; the BUG7 entry-safe exclusion applied as a cell
  filter at `:468-469` plus the depth-0 entry-piece skip at `:454-455`.
- The R1 twin seam: `_spawn_r1_hazards` — `:534-574` (J2 spread loop `:552-569` + J3 density loop
  via `_populate_room_density` `:587-606`), whose *plans* are pure functions
  (`_hazard_spawn_depths`, `_density_spawn_positions` `:671-709`) golden-tested by
  `tests/test_per_room_density.gd` and `tests/test_hazard_spread.gd`. R1's **separate** ceiling
  `R1_DENSITY_BAND_CEILING := 64` lives in `run_config.gd:37` and is enforced inside the *plan*
  (`main_game.gd:682`, `:697`), not the instantiate loop.
- Placement helpers (stable, RNG-free): `_density_pieces_sorted` `:734-746` (depth asc, then
  (y,x) offset tiebreak), `_density_sorted_cells` `:751-757`, `_density_cell_to_world` `:761-763`
  (cell × cell_size + half-cell centring), `_piece_floor_bounds_world` `:514-520`.
- Lifecycle: nodes parent under `_band_container` (`:44`); `_clear_band()` `:1187-1191` frees the
  container's children. Call sites in `start_new_run()`: `_spawn_r1_hazards` at `:309`,
  `_spawn_new_hazards(run_cfg, band, spawn_pos)` at `:317` — after `GameState.stage_run_config`
  + `start_run` (`:287-288`), with `spawn_pos` resolved at `:249`.

**The entities (S0 does not edit them, but the service must honor their contracts):**

- Config snapshot at `setup()` — `hazard_entity.gd:119-131` (and `:75` `_cfg` var doc: "snapshot
  of GameState.active_run_config at setup"); the snapshot exists so a run-end
  `active_run_config` clear can't null a live entity mid-frame.
- BUG6 rising-edge latch — `hazard_entity.gd:236-240` (emit `hazard_caught` once on the rising
  edge into radius; re-arm on the falling edge).
- L5 lethality — `hazard_entity.gd:319-323`: emit-always, `fail_run(&"death")` gated by
  `r1_catch_kills`; mirrored at `pingpong_hazard.gd:137-143` (`new_hazard_killed` emit-always,
  `hpp_kills` gates the kill).
- Player resolution via the `&"player"` group — `main_game.gd:396-397` (null-safe, resolved off
  `_band_container.get_tree()` so a bare headless harness works).

**EventBus house style** — `systems/event_bus.gd`: per-milestone pre-declare blocks with a named
sole owner (`:82-86` M1.1/TEL, `:118-124` M1.4/K0, `:157` M1.5/L0, `:183` M1.6/M0, `:228`
M1.7/N0). Payload primitives-only; owners noted per signal group. Legacy opposition signals S0
must leave firing: `hazard_awoke`/`hazard_caught` `:89-90`, `new_hazard_killed` `:149`,
`bomb_pulse_started` `:151`, `throw_killed_hazard` `:175` (kill-direction separation rationale in
its doc comment — the same reason v2 keeps `opposition_killed_player` a dedicated channel),
`hazard_pursuer_state` `:181`, and `dive_requested(band_id: StringName)` `:197` (the M1.6 routing
signal that already carries a band id — load-bearing for the S8 seam, §4.4).

**Config surface (context for `param_schema`; S0 does NOT touch it):**
`ui/config/config_menu.gd` — hand-authored `MANIFEST` `:84`, `FIELD_RANGE` `:209` /
`FIELD_STEP` `:290`, build-time `has_full_coverage()` reflection assertion `:414`, widget
dispatch `_build_row` `:877`. (Note: the file lives at `Game/ui/config/`, not `Game/scenes/ui/`
— the breakdown's shorthand cite is by basename.) `param_schema` (§3.2) is the metadata that lets
S4 generate these rows per-def; S0 only ships the field.

**RunConfig anchors:** `all_oppositions_disabled()` `run_config.gd:429-430`; `to_flat_dict()`
`:455`; `inert_enabled_oppositions()` `:597`; `make_default_play_preset()` `:662` (K5 preset
values `:799-826`). The generic levers `oppositions_enabled`/`param_overrides` are **S3's**, not
S0's — S0 adds *nothing* to RunConfig.

**Test harness reality (drives the design):** `tests/test_new_hazard_spawn.gd` drives the seam
headlessly on a **bare script instance** — `_fresh_mg()` (`:234-240`) does `mg_script.new()`,
injects a real in-tree `_band_container` + `_band_cell_size_px`, then calls
`mg._spawn_new_hazards(rc, band)` directly and **counts `_band_container.get_child_count()`**
(`:51`, `:61`, `:73`). Two consequences: (a) the service must be constructible by an out-of-tree
MainGame instance with no scene file; (b) the service node must NOT parent under
`_band_container`, or every child-count assertion in the golden harness shifts by one. §3.1's
lifecycle answers both.

**Existing directories:** `Game/systems/spawning/` exists (holds `junk_spawner.gd`) — the natural
home for `spawn_service.gd`. `Game/data/enemies/` and `Game/data/bands/` exist as `.gitkeep`
stubs; `data/oppositions/` does not exist yet (OQ-2).

### 1.3 The mechanism/policy line through `_spawn_new_hazards` (statement-by-statement)

The v2 exploration draws the line abstractly ("validate · instantiate · register · caps ·
lifecycle · setup · emit" vs "descriptor table · fair-share · counts"). Here is the line drawn
through the **actual statements** of `main_game.gd:385-485`. "Stays" = remains in the thinned
`_spawn_new_hazards` (policy, until S3 moves it into `EncounterBuilder`); "moves" = relocates
into `SpawnService`.

| Lines | Statement (as-built) | Verdict | Note |
|---|---|---|---|
| `:386-387` | `if rc == null: return` | **Stays** | Policy entry gate. |
| `:391` | `entry_pos` resolve (`spawn_pos` param else `_entry_spawn_position(band)`) | **Stays** | Uses a main_game topology helper; the *value* is handed to the service via `begin_band()` (§3.1) because the exclusion *enforcement* moves. |
| `:392` | `safe_dist_px = NEW_HAZARD_SPAWN_SAFE_CELLS * cell_size` | **Moves** | The BUG7 exclusion constant + math live with the validation (service). |
| `:396-397` | player resolve via `&"player"` group off `_band_container.get_tree()` | **Moves** | The service resolves the player once per band (same null-safe expression) and threads it into every `setup()`. |
| `:398` | `pieces := _density_pieces_sorted(band)` | **Stays** | The stable walk order feeds the *count* policy. (Helper itself stays in main_game for S0; S3 relocates it with the builder.) |
| `:409-420` | descriptor pre-filter: `enabled` gate, neutral-knob gate, `load(desc["path"])` | **Stays** (loading delegated) | The enabled/neutral gates are pure policy. The *scene load* becomes "lazy-load the def" (§3.3): enabled type → `load(def_path)`; the def's `host_scene` ExtResource pulls the same `.tscn`. Disabled type → nothing loaded, exactly as today. The `push_error` on a missing scene moves to the service (`spawn()` returns null). |
| `:421-422` | `if active.is_empty(): return` | **Stays** | Policy short-circuit — the all-off path exits **before any service call**, so the bare-harness all-off case constructs nothing. |
| `:424-426` | fair-share math (`base_share`, `remainder`) | **Stays** | The L6 fair-share is *the* policy S3 will move into the builder. |
| `:429-441` | per-type loop, `type_budget`, knob unpacks | **Stays** | Policy bookkeeping. |
| `:445-449` | piece loop + `spawned_total`/`type_spawned` budget breaks | **Stays** | The accumulators remain policy-side *counters of successful spawns* (incremented on `spawn() != null`, v2 pseudocode pattern). The service's registry independently enforces the same ceiling (§3.1 cap groups) — belt-and-braces, byte-equivalent because both count the same events. |
| `:450-455` | `depth`, BUG7 depth-0 entry-piece skip | **Stays** | The entry-piece skip is *piece selection* (policy); the *cell-radius* exclusion is placement validation (service). Splitting them this way keeps both halves at their exact current sequence points. |
| `:457-462` | `n = base + floor(per_depth*depth)`; `min(per_room_cap)`; `min(type slice)`; `min(ceiling remainder)` | **Stays** | Depth-scaled count + per-room cap **stay in the count math** in Phase A (see §3.1 "Phase-A enforcement line") so no min() ever moves. |
| `:464` | `cells := _density_sorted_cells(p)` | **Stays** | Stable cell order (policy input to the stride). |
| `:468-469` | BUG7 cell filter (`distance_to(entry_pos) >= safe_dist_px`) | **Moves** — invoked from the same point | The filter code relocates into the service as `valid_cells(cells)` (§3.1), but the policy calls it **at this exact statement position, before the stride**. This is load-bearing: today the stride runs over the *filtered* list; a refuse-at-`spawn()` design instead would shift every stride index → different cells → behavior change. Filter-then-stride order is preserved verbatim. |
| `:470-471` | `if cells.is_empty(): continue` | **Stays** | Policy flow. |
| `:472` | `room_bounds := _piece_floor_bounds_world(cells)` | **Stays** | Feeds the ctx (policy-owned context building). |
| `:473-475` | `stride` math + cell pick | **Stays** | Cell *choice* is policy ("decides def, cell, ctx" — v2 §headline). |
| `:477-478` | `scene.instantiate()` + `_band_container.add_child(hz)` | **Moves** | The heart of the mechanism. |
| `:479` | `hz.global_position = pos` (+ `:476` cell→world) | **Moves** | `spawn(def, cell, ctx)` takes a **cell**; the service owns the cell→world projection (same `_density_cell_to_world` math, configured with `cell_size_px` at `begin_band()`). |
| `:482` | `reset_physics_interpolation()` | **Moves** | The M1.7 interp-ghost fix rides with instantiation. |
| `:483` | `hz.setup(rc, player, ctx)` | **Moves** | The locked handshake, called by the service. The **ctx is built by policy** (`_new_hazard_spawn_ctx` stays, `:496-507`) and passed through opaquely — the service adds nothing to it and reads only its own reserved keys (§3.4). |
| `:484-485` | `spawned_total += 1; type_spawned += 1` | **Stays** (as success counters) | Incremented iff `spawn()` returned non-null; the service registers the instance in the same motion. |
| *(new)* | registry insert + `opposition_event(id, &"spawned", …)` emit | **Moves** (net-new mechanism) | Today there is no spawn registry and no spawn event; both are born in the service (§3.1, §4). |

**What S0 does *not* touch:** `_spawn_r1_hazards` (`:534`) and both R1 plans stay byte-identical
(the R1 unification question is OQ-3, recommended deferred to S3); `_new_hazard_spawn_ctx`
(`:496`) stays; entity scripts stay; `config_menu.gd` stays; `RunConfig` stays.

### 1.4 Prior art / design grounding

Carried from the exploration (v2 §Prior art, verified against its sources): the RoR2 model itself
separates the Director (policy: which card, how many credits) from spawning the card's prefab —
S0 draws that seam; the credit/deck policy half arrives in S3. The GDD/TDD grounding is TDD §2
(signal-driven decoupling, data-as-Resources) — `OppositionDef` is the "content is data" pattern
`data/item.gd` already establishes, applied to oppositions.

---

## 2. Goal & non-goals

**Goal.** After S0: (a) `SpawnService` exists and every K5 hazard node materialises through
`spawn(def, cell, ctx)`; (b) the 4 shipped hazards exist as `OppositionDef.tres` whose
`host_scene` is the current `.tscn` unchanged; (c) all M1.9 EventBus signals are declared and the
service emits `opposition_event(id, &"spawned", …)` centrally; (d) **nothing observable changed**
— fingerprints, spawn positions, node counts, telemetry rows, preset cohort all byte-identical.

**Non-goals (explicitly deferred):** components/`param_schema` completion (S2); the
`EncounterBuilder` + `RunConfig` generic levers + descriptor-table retirement (S3); generated
menu sections + per-def coverage assertion + `debug_dirty` (S4); any new hazard (S6a/S6b); the
portal routing implementation (S8 — S0 only declares its signal); legacy-signal retirement
(post-gate).

---

## 3. Design

### 3.1 `SpawnService` (mechanism, policy-free)

**File:** `Game/systems/spawning/spawn_service.gd` — `class_name SpawnService extends Node`.

**Lifetime & ownership (per-dive, group-resolved — exploration recommendation, restated with
analysis in OQ-1):** one instance owned by `MainGame`, created lazily by
`MainGame._ensure_spawn_service()` and parented **under the MainGame node itself — NOT under
`_band_container`** (two reasons: `_clear_band()` frees the container's children, and the golden
harness `test_new_hazard_spawn.gd` counts them — a service child there breaks the counts, §1.2).
It lives exactly as long as the dive scene (the App router swaps `main_game.tscn` in/out), which
*is* the per-dive lifetime the exploration wants; across `start_new_run()` calls within one dive
scene it persists and is reset via `clear_all()` from `_clear_band()` (`:1187`). It joins the
`&"spawn_service"` group in `_enter_tree()` so mid-run clients (S6b) and the debug menu resolve
it without an autoload ref. Lazy creation makes the bare-script-instance harness work unchanged
(a tree-less `mg` can still `add_child()` a service).

**Per-band configuration:** `begin_band(container, cell_size_px, entry_pos, safe_dist_px)` —
called from `start_new_run()` after `_materialise_band` (which fixes `_band_cell_size_px`,
`:240`) and before the spawn seams. It stores the band container ref, the cell→world projection
scale, the BUG7 exclusion inputs, resolves the player once
(`container.get_tree().get_first_node_in_group(&"player")`, the exact `:396-397` expression), and
resets cap-group accounting. `clear_all()` implicitly re-arms for the next `begin_band`.

**The surface (breakdown-locked names):**

- `spawn(def: OppositionDef, cell: Vector2i, ctx: Dictionary) -> Node` — the one boundary
  method: validate → check caps → instantiate → parent → place → `reset_physics_interpolation()`
  → register → `setup(cfg, player, ctx)` → emit `opposition_event(def.id, &"spawned", …)`.
  Returns the node, or `null` on refusal (invalid cell / cap full / missing scene, with the
  `push_error` from `:417` relocated here for the missing-scene case).
- `spawn_batch(reqs: Array) -> Array[Node]` — `[{def, cell, ctx}, …]`; one validation/registry
  pass; per-request nulls for refusals. No S0-internal caller (the K5 loop calls `spawn()`
  per-instance to keep the relocation literal); it exists because the surface is breakdown-locked
  and S6b/set-pieces consume it (OQ-9).
- `can_afford(def: OppositionDef, cell: Vector2i) -> bool` — would `spawn()` succeed? (cap +
  placement pre-check, no side effects).
- `live_count(def_id: StringName) -> int` — registry query (plus `live_total() -> int` for the
  band-wide accounting; a trivial widening, flagged in OQ-10).
- `despawn(node: Node) -> void` — de-register + `queue_free()` (Splitter parent death, timed
  expiry — no S0 caller, S6b's).
- `clear_all() -> void` — free every registered instance + reset accounting (run-end lifecycle;
  called from `_clear_band()`; idempotent alongside the container-free since `queue_free()` on an
  already-freed node is guarded by `is_instance_valid`).
- `valid_cells(cells: Array[Vector2i]) -> Array[Vector2i]` — the relocated BUG7 radius filter
  (`:468-469` verbatim: keep cells whose world centre is `>= safe_dist_px` from `entry_pos`).
  Exposed as a queryable so the policy can filter-then-stride at the exact current sequence point
  (§1.3). `spawn()` re-applies the same test per-cell (belt-and-braces; non-binding when the
  policy pre-filtered).

**Registry:** `_live: Dictionary` keyed `def_id: StringName → Array[Node]`, plus cap-group
counters. Single-writer discipline: only `spawn`/`despawn`/`clear_all` mutate it. Freed nodes are
lazily compacted (`is_instance_valid` sweep on query) so an entity that dies mid-run without
`despawn()` (all of today's hazards — they are freed with the band, never individually) can't
inflate counts.

**Caps — the Phase-A enforcement line (zero-behavior-change version of "unify the ceilings"):**
the service implements **scoped cap groups**: `set_cap_group(&"new_hazards", 48)` is registered
at `begin_band()` from the relocated `NEW_HAZARD_BAND_CEILING` const (which moves to
`spawn_service.gd`; `main_game.gd` re-exports it or the tests read it off the service script —
see DoD note), and every def carries `cap_group: StringName` (`&"new_hazards"` for all four
authored defs). `spawn()` refuses when the group is at its ceiling. In Phase A this refusal is
**never observed** — the policy's own `spawned_total` min() (`:461`, unchanged) stops the loop
one step earlier, exactly as today; the group cap is the same number counted the same way, so the
two enforcement points agree by construction. Per-def `per_band_cap` and `per_room_cap` fields
exist on the def (§3.2) but are authored `0` (= defer to group/no-op) in S0, because today's
per-room cap is applied inside the *count math* (`:458-459`) which stays put — moving it to
refusal-based enforcement would need `ctx.room_key` accounting and is behavior-relevant only if
the numbers ever disagree; the capability ships (with `test_spawn_service` exercising it via a
synthetic def), the *binding* stays where it is today. `R1_DENSITY_BAND_CEILING` (=64,
`run_config.gd:37`) is **not touched** (OQ-3). Precedence semantics for the full cap stack are
OQ-5. The `{"ignore_room_cap": true}` ctx escape (v2's set-piece override) is **reserved, parsed,
and honored** but has no S0 caller.

**Determinism posture:** the service contains zero RNG calls and zero reads of the generation
stream; it is a pure executor of (def, cell, ctx) instructions. Generation-time callers stay
RNG-free stable walks (unchanged, policy-side); mid-run callers (S6b, debug menu) are run-state
and route through the same `spawn()` which touches no layout RNG — the v2 safety property, held
by construction.

### 3.2 `OppositionDef` (data layer)

**File:** `Game/data/oppositions/opposition_def.gd` (folder per OQ-2 recommendation) —
`class_name OppositionDef extends Resource`. S0 ships the full v2 field set so S2/S3 never bump
the resource script's shape, but only the fields the Phase-A seam reads are load-bearing now:

```gdscript
class_name OppositionDef
extends Resource
## OppositionDef — one opposition type as DATA (M1.9 S0, exploration v2 §data layer).
## Phase A: id / host_scene / cap_group are load-bearing; the spawn-card and params
## fields are authored but unread until S3 (builder) / S2 (components) / S4 (menu).

@export var id: StringName                       # &"pingpong" — MUST equal the legacy telemetry
                                                 # kind (event_bus new_hazard_killed kinds, L1's
                                                 # throw kinds) so opposition_event ids are
                                                 # continuous with historical telemetry.
@export var display_name: String = ""
@export_enum("actor", "field", "fixture") var archetype: String = "actor"
@export var host_scene: PackedScene              # the CURRENT .tscn, unchanged (OQ-6: lazy def
                                                 # load preserves the all-off loads-nothing rule)

# --- Spawn card (read by the S3 builder, NOT the service; authored neutral in S0) ---
@export var credit_cost: int = 1
@export var spawn_weight: float = 1.0
@export var min_band: int = 0

# --- Hard caps (read by the SERVICE) -------------------------------------------------
@export var cap_group: StringName = &""          # shared ceiling pool; &"new_hazards" for K5
@export var per_room_cap: int = 0                # 0 = no service-side per-room refusal (Phase A:
                                                 # the policy count-math cap still applies)
@export var per_band_cap: int = 0                # 0 = defer to cap_group / global

# --- Component knob bag + schema (S2 completes; S4 reflects) --------------------------
@export var params: Dictionary = {}
@export var param_schema: Array[Dictionary] = []

# --- Lethality declaration (informational until S2 moves the *_kills read here) -------
@export_enum("lethal", "chip", "knockback", "steal", "none") var lethality: String = "lethal"
@export var kills: bool = true
```

The **params↔schema bijection assertion** (`params.keys()` == schema keys, per loaded def) is
S2/S4's net; S0 authors both empty/minimal so the invariant is vacuously true from day one.

### 3.3 The four `.tres` (authored in S0, real scene paths)

`Game/data/oppositions/pingpong.tres`, `bomb.tres`, `spike.tres`, `pursuer.tres`. Ids match the
legacy telemetry kinds exactly: `&"pingpong"`, `&"bomb"`, `&"spike"` (the `new_hazard_killed`
kinds, `event_bus.gd:149`) and `&"pursuer"` (L1's throw kind, `event_bus.gd:175`). Illustrative
authoring for one:

```
[gd_resource type="Resource" script_class="OppositionDef" load_steps=3 format=3]

[ext_resource type="Script" path="res://data/oppositions/opposition_def.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/hazards/pingpong_hazard.tscn" id="2"]

[resource]
script = ExtResource("1")
id = &"pingpong"
display_name = "Ping-Pong Bouncer"
archetype = "actor"
host_scene = ExtResource("2")
credit_cost = 1
spawn_weight = 1.0
min_band = 0
cap_group = &"new_hazards"
per_room_cap = 0
per_band_cap = 0
params = {}
param_schema = []
lethality = "lethal"
kills = true
```

(`bomb.tres` → `res://scenes/hazards/bomb_hazard.tscn`, archetype `"fixture"`; `spike.tres` →
`res://scenes/hazards/spike_hazard.tscn`, archetype `"fixture"`; `pursuer.tres` →
`res://scenes/hazards/hazard_entity.tscn`, archetype `"actor"`, `cap_group = &""` — the pursuer
is not in the K5 ceiling pool and its seam is untouched in S0.)

**Lazy-load discipline (the all-off guarantee, restated):** because `host_scene` is an
ExtResource, loading a def `.tres` loads its `.tscn`. Therefore **defs are lazy-loaded exactly
where scenes are lazy-loaded today** — inside the descriptor loop, only for an
enabled+non-neutral type (`:415` becomes `load(desc["def_path"]) as OppositionDef`). All-off →
the loop `continue`s every row → **no def, no scene, no service call, no service node** (the
`active.is_empty()` early-return at `:421` fires before `_ensure_spawn_service()`), byte-identical
to today. `pursuer.tres` is loaded by nothing in S0 (authored for S2) — it costs zero at runtime.

### 3.4 `spawn_ctx` — reserved keys

The ctx Dictionary stays the policy-built, entity-read channel it is today (`:496-507` unchanged;
entities read `initial_dir`/`room_bounds`/`phase_salt` as before). S0 reserves three
**service-read** keys, all primitives, all optional:

| Key | Type | Read by | Meaning |
|---|---|---|---|
| `"depth"` | `int` (default 0) | service | `depth_index` of the placement piece — payload for the `&"spawned"` emit. Generation-time callers pass `p.depth_index`; mid-run callers pass `GameState.current_depth_index`. |
| `"run_t_ms"` | `int` (default 0) | service | run-clock stamp for the `&"spawned"` emit. Generation-time = 0 (band build ≈ run start); mid-run callers self-time exactly as entities do (`hazard_entity.gd:317` pattern — the service **never invents a new clock**). |
| `"ignore_room_cap"` | `bool` (default false) | service | v2's explicit set-piece escape hatch. Parsed + honored; no S0 caller. |

The policy-side ctx builder wraps `_new_hazard_spawn_ctx(...)` output with
`{"depth": p.depth_index, "run_t_ms": 0}` merged in (a pure addition — entities ignore unknown
keys by construction, they `.get()` only their own).

---

## 4. EventBus pre-declare (the sole `event_bus.gd` edit of M1.9)

Appended in the house style (per-milestone block, named owner, primitives-only note), exactly:

```gdscript
# === M1.9 signals (sole event_bus.gd edit this milestone, owner = S0) =========
# Pre-declared up front so S2/S3/S4/S6/S8 only EMIT/CONNECT — they never edit this
# file (the M1.1 pre-declare rule, M1.9 Breakdown §Scope). Payloads PRIMITIVES ONLY
# (straight to JSONL). Legacy per-type opposition signals above (hazard_awoke,
# hazard_caught, new_hazard_killed, bomb_pulse_started, throw_killed_hazard,
# hazard_pursuer_state) DUAL-EMIT alongside these throughout the migration —
# retirement is post-gate (SG3 watch-item), never in M1.9.

# --- Generic opposition telemetry (v2 §EventBus contract) ---------------------
## Any opposition lifecycle event. id = OppositionDef.id (== the legacy kind, so
## historical telemetry joins cleanly). event vocabulary (S0 locks the set):
## &"spawned" / &"awoke" / &"telegraph" / &"hit_player" / &"killed_by_throw" /
## &"state". The SERVICE emits &"spawned" centrally (every client's spawn is logged
## identically); entities/components emit the rest from S2 on. Owner: S0 declares;
## SpawnService + S2 components emit.
signal opposition_event(id: StringName, event: StringName, depth: int, run_t_ms: int)
## The dedicated death channel — an opposition ACTUALLY ended the run (the *_kills-
## gated fail_run fired), kept separate from opposition_event exactly as L1 kept
## throw_killed_hazard separate from new_hazard_killed (line ~175) so kill-direction
## never poisons death counts. NOT emitted by anything in S0 (the kill sites live in
## entity internals — S2's dual-emit; see S0 design §5). Owner: S0 declares; S2 emits.
signal opposition_killed_player(id: StringName, depth: int, run_t_ms: int)

# --- Band-selection routing (S8 seam; S0 pre-declares the resolved shape) ------
## The App router resolved a dive_requested(band_id) to a concrete BandProfile for
## THIS dive. Emitted by the router (S8) after it stages the choice on GameState
## run-state and BEFORE the dive scene swap; consumed by Telemetry (the band_id
## run-stamp, SG2) and the S8 contract test. dive_requested (line ~197) is UNCHANGED
## — it stays the player-intent signal; this is the resolution receipt.
## profile_id = the BandProfile resource id (&"band_greybox" / &"band_two").
signal band_route_selected(band_id: StringName, profile_id: StringName)
```

**Why this routing shape (coordinate with S8 — OQ-4):** `dive_requested(band_id: StringName)`
*already carries a band id* (`event_bus.gd:197`, M1.6 single `&"near"`), so the request side
needs **no arity change** — S8's portal simply emits a different id. What's missing is a
declared, testable seam for the *resolution* (which profile this dive actually uses, staged where
`main_game` can read it — the breakdown's "GameState run-state field recommended"). A sibling
receipt signal keeps `dive_requested`'s M1.6 subscribers untouched and gives Telemetry a
primitives-only hook for the `band_id` run-stamp. The exact emitter placement is S8's resolved
design; S0 only guarantees the declaration exists on `main` in Wave 1.

---

## 5. Dual-emit strategy (what emits what, from when)

| Legacy signal (unchanged) | Generic twin | Who dual-emits, from which task |
|---|---|---|
| *(none — no legacy spawn signal exists)* | `opposition_event(id, &"spawned", depth, run_t_ms)` | **SpawnService, from S0.** Net-new row; nothing legacy to pair with. Telemetry gains the row only for types that actually spawn (all-off emits nothing). |
| `hazard_awoke(depth, trigger)` `:89` | `opposition_event(&"pursuer", &"awoke", …)` | Entity/component, **S2** (S0 does not edit entities). |
| `hazard_caught(depth, run_t_ms)` `:90` | `opposition_event(&"pursuer", &"hit_player", …)` | **S2**. |
| `new_hazard_killed(kind, depth, run_t_ms)` `:149` (emit-always on contact) | `opposition_event(kind, &"hit_player", …)` (emit-always) **+** `opposition_killed_player(kind, …)` (only when the `*_kills` gate actually fires `fail_run`) | **S2** — the kill site is inside the entity (`pingpong_hazard.gd:137-143`), where the gate is visible. |
| `throw_killed_hazard(item_id, kind, …)` `:175` | `opposition_event(kind, &"killed_by_throw", …)` | **S2**. |
| `hazard_pursuer_state(state, …)` `:181` | `opposition_event(&"pursuer", &"state", …)` | **S2**. |
| `bomb_pulse_started(…)` `:151` | `opposition_event(&"bomb", &"telegraph", …)` | **S2**. |

**Rejected alternative — an S0-side bridge** (a relay connecting legacy signals and re-emitting
generic ones): (a) EventBus "holds no state — it is pure wiring" (`event_bus.gd:6`) and a relay
is a subscriber; (b) fatally, `hazard_caught`/`new_hazard_killed` fire on *contact* regardless of
the `*_kills` gate (`hazard_entity.gd:318-323`, `pingpong_hazard.gd:137-142`), so no bridge can
emit a correct `opposition_killed_player` — the kill/contact distinction only exists at the
entity's gate. Dual-emit therefore lands at the emitters, in S2. Telemetry *subscribers* migrate
in S4; through Waves 1–3 the legacy rows remain the system of record and RG telemetry continuity
is never broken.

---

## 6. Pseudocode (illustrative, against as-built APIs)

### 6.1 `systems/spawning/spawn_service.gd`

```gdscript
class_name SpawnService
extends Node
## Policy-free spawn mechanism (M1.9 S0, exploration v2). Owns instantiation,
## placement validation (BUG7), the live registry, cap enforcement, run-end
## lifecycle, the LOCKED setup(cfg, player, spawn_ctx) handshake, and the central
## opposition_event(&"spawned") emit. It never decides WHAT deserves to spawn.
## Run-state only — never persisted. Zero RNG. Group-resolved: &"spawn_service".

const SPAWN_SAFE_CELLS: float = 2.5          # relocated NEW_HAZARD_SPAWN_SAFE_CELLS (BUG7)

var _container: Node2D = null                # the band container (parent of spawned nodes)
var _cell_size_px: int = 16
var _entry_pos: Vector2 = Vector2.INF        # BUG7 exclusion centre
var _safe_dist_px: float = 0.0
var _player: Node2D = null                   # resolved once per band via &"player" group
var _cfg: RunConfig = null                   # the run config threaded into setup()
var _live: Dictionary = {}                   # def_id -> Array[Node]
var _cap_groups: Dictionary = {}             # group -> {ceiling: int, count: int}

func _enter_tree() -> void:
    add_to_group(&"spawn_service")

## Per-band arming. Called from MainGame.start_new_run() after _materialise_band.
func begin_band(container: Node2D, cell_size_px: int, entry_pos: Vector2,
        cfg: RunConfig) -> void:
    _container = container
    _cell_size_px = cell_size_px
    _entry_pos = entry_pos
    _safe_dist_px = SPAWN_SAFE_CELLS * float(cell_size_px)
    _cfg = cfg
    var tree := container.get_tree()                       # main_game.gd:396 verbatim
    _player = tree.get_first_node_in_group(&"player") as Node2D if tree != null else null

func set_cap_group(group: StringName, ceiling: int) -> void:
    _cap_groups[group] = {"ceiling": ceiling, "count": 0}

## THE boundary method. Returns the live node, or null on refusal.
func spawn(def: OppositionDef, cell: Vector2i, ctx: Dictionary = {}) -> Node:
    if def == null or def.host_scene == null:
        push_error("SpawnService: def/scene missing for %s." % [def])   # :417 relocated
        return null
    if not _cell_valid(cell):                              # BUG7 re-check (belt-and-braces)
        return null
    if not _caps_allow(def, ctx):                          # group / per_band (per_room: OQ-5)
        return null
    var hz := def.host_scene.instantiate() as Node2D       # :477
    _container.add_child(hz)                               # :478
    hz.global_position = _cell_to_world(cell)              # :476 / :761-763
    hz.reset_physics_interpolation()                       # :482 (M1.7 interp-ghost fix)
    _register(def, hz)
    hz.setup(_cfg, _player, ctx)                           # :483 — the LOCKED handshake
    EventBus.opposition_event.emit(def.id, &"spawned",
        int(ctx.get("depth", 0)), int(ctx.get("run_t_ms", 0)))
    return hz

func spawn_batch(reqs: Array) -> Array[Node]:
    var out: Array[Node] = []
    for r in reqs:
        out.append(spawn(r["def"], r["cell"], r.get("ctx", {})))
    return out

func can_afford(def: OppositionDef, cell: Vector2i) -> bool:
    return def != null and _cell_valid(cell) and _caps_allow(def, {})

func live_count(def_id: StringName) -> int:
    return _compact(def_id).size()                         # is_instance_valid sweep on query

func despawn(node: Node) -> void:
    _deregister(node)
    if is_instance_valid(node):
        node.queue_free()

func clear_all() -> void:
    for id in _live:
        for n in _live[id]:
            if is_instance_valid(n):
                n.queue_free()
    _live.clear()
    _cap_groups.clear()

## The relocated BUG7 cell filter (main_game.gd:468-469 verbatim), exposed so the
## policy can FILTER-THEN-STRIDE at its exact current sequence point (§1.3).
func valid_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
    return cells.filter(_cell_valid)

func _cell_valid(cell: Vector2i) -> bool:
    if _entry_pos == Vector2.INF:
        return true                                        # unarmed (test harness) — no exclusion
    return _cell_to_world(cell).distance_to(_entry_pos) >= _safe_dist_px

func _cell_to_world(cell: Vector2i) -> Vector2:            # :761-763 verbatim
    return Vector2(cell * _cell_size_px) + Vector2(_cell_size_px, _cell_size_px) * 0.5
```

(`_caps_allow` / `_register` / `_deregister` / `_compact` are straightforward registry math;
`_caps_allow` honors `ctx.get("ignore_room_cap", false)` for the per-room tier per OQ-5's
resolved precedence.)

### 6.2 The thinned `_spawn_new_hazards` (policy shell, byte-equivalent walk)

```gdscript
func _spawn_new_hazards(rc: RunConfig, band: Band, spawn_pos: Vector2 = Vector2.INF) -> void:
    if rc == null:
        return
    var entry_pos: Vector2 = spawn_pos if spawn_pos != Vector2.INF \
            else _entry_spawn_position(band)                       # :391 (stays)
    var pieces := _density_pieces_sorted(band)                     # :398 (stays)

    # Descriptor pre-filter (:409-422, stays) — now lazy-loads the DEF (which pulls the
    # same .tscn); disabled/neutral types load NOTHING (all-off unchanged).
    var active: Array[Dictionary] = []
    for desc in _new_hazard_descriptors(rc):                       # gains "def_path" per row
        if not desc["enabled"]:
            continue
        if desc["base"] <= 0 and desc["per_depth"] <= 0.0:
            continue
        var def := load(desc["def_path"]) as OppositionDef
        if def == null or def.host_scene == null:
            push_error("MainGame: opposition def missing at %s." % desc["def_path"])
            continue
        active.append({"def": def, "base": desc["base"],
            "per_depth": desc["per_depth"], "cap": desc["cap"]})
    if active.is_empty():
        return                                                     # all-off: NO service touched

    var svc := _ensure_spawn_service()                             # lazy child of MainGame
    svc.begin_band(_band_container, _band_cell_size_px, entry_pos, rc)
    svc.set_cap_group(&"new_hazards", SpawnService.NEW_HAZARD_BAND_CEILING)

    # Fair-share policy (:424-461) — UNCHANGED statements, budget counters stay here.
    var n_active := active.size()
    var base_share := SpawnService.NEW_HAZARD_BAND_CEILING / n_active
    var remainder := SpawnService.NEW_HAZARD_BAND_CEILING % n_active
    var spawned_total := 0
    for ti in n_active:
        ...                                                        # :429-441 verbatim
        for p in pieces:
            ...ceiling/type-budget breaks, depth-0 skip, count math...   # :445-462 verbatim
            var cells := svc.valid_cells(_density_sorted_cells(p)) # :464 + :468-469 — the BUG7
                                                                   # filter, SAME sequence point
            if cells.is_empty():
                continue
            var room_bounds := _piece_floor_bounds_world(cells)    # :472 (stays)
            var stride := maxi(cells.size() / maxi(n, 1), 1)       # :473 (stays)
            for k in n:
                var cell := cells[(k * stride) % cells.size()]     # :475 (stays)
                var ctx := _new_hazard_spawn_ctx(kind, p, k, spawned_total, room_bounds)
                ctx["depth"] = p.depth_index                       # service-read keys (§3.4)
                ctx["run_t_ms"] = 0
                if svc.spawn(def, cell, ctx) != null:              # :477-483 relocated
                    spawned_total += 1                             # :484-485 (stay, success-gated)
                    type_spawned += 1
```

`_clear_band()` (`:1187`) appends `if _spawn_service != null: _spawn_service.clear_all()` before
freeing the container children (order-insensitive — both paths `queue_free`, guarded).

### 6.3 Deltas summary (everything S0 writes)

| File | Change |
|---|---|
| `Game/systems/spawning/spawn_service.gd` | **New** — §6.1. `NEW_HAZARD_BAND_CEILING`/`SPAWN_SAFE_CELLS` consts relocate here. |
| `Game/data/oppositions/opposition_def.gd` | **New** — §3.2. |
| `Game/data/oppositions/{pingpong,bomb,spike,pursuer}.tres` | **New** — §3.3. |
| `Game/systems/event_bus.gd` | **Append** the M1.9 block — §4, verbatim. |
| `Game/scenes/game/main_game.gd` | Thin `_spawn_new_hazards` (§6.2); `_ensure_spawn_service()`; `_clear_band()` + `clear_all()`; descriptor rows gain `def_path`; the two relocated consts become `SpawnService.` references (or thin re-export consts if the golden harness reads `mg_script.NEW_HAZARD_BAND_CEILING` — it does, `test_new_hazard_spawn.gd:45` — so **keep a forwarding const** `const NEW_HAZARD_BAND_CEILING := SpawnService.NEW_HAZARD_BAND_CEILING` to leave the harness unedited). `_spawn_r1_hazards` and both R1 plans: **untouched** (OQ-3). |
| `Game/tests/test_spawn_service.gd` + `.tscn` | **New** — §7. |

---

## 7. Definition of done (breakdown DoD, made concrete)

All checks run **sequentially** (never two headless godot instances — import-lock deadlock,
standing memory), from the repo root:

1. **Import + parse:** `godot --headless --path Game --import` clean.
2. **Smoke:** `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → exit 0.
3. **All-off fp byte-identical:**
   `godot --headless --path Game res://tests/test_bandgen_determinism.tscn` and
   `godot --headless --path Game res://tests/test_corridor_lever.tscn` green — the latter pins
   `BASELINE_FP := "e943ac9c8bc1"` (`test_corridor_lever.gd:34`). (Trivially safe — S0 never
   touches generation — but it is the standing wave-boundary gate.)
4. **Placement is the same code, relocated:**
   `res://tests/test_new_hazard_spawn.tscn` green **with the test file unedited** (the golden
   harness: all-off zero-node, per-room counts, ceiling, byte-identical position determinism,
   per-kind ctx — cases (i)–(vi)). Likewise `res://tests/test_pingpong_hazard.tscn`,
   `test_bomb_hazard.tscn`, `test_spike_hazard.tscn`, `test_pursuing_hazard.tscn`,
   `test_per_room_density.tscn`, `test_hazard_spread.tscn` green unedited.
5. **Every RG verify green:** `res://tests/test_rg1_loop_verify.tscn`,
   `test_rg1_m12_verify.tscn`, `test_rg1_m13_verify.tscn`, `test_rg1_m14_verify.tscn`,
   `test_rg1_m15_verify.tscn`.
6. **Preset cohort parity:** `make_default_play_preset()` (`run_config.gd:662`) spawns the same
   node set at the same positions — covered by (4)'s determinism case + (5); if the implementer
   wants a direct check, a before/after position-list dump on a fixed seed matrix belongs in the
   worklog, not a new committed test.
7. **New `test_spawn_service`** (`res://tests/test_spawn_service.tscn`, run-as-scene) asserting,
   with a synthetic def + hand-built band (mirror `test_new_hazard_spawn.gd`'s `_fresh_mg`
   harness):
   - `spawn()` materialises under the container, calls `setup` (probe via a stub scene), returns
     the node, and emits exactly one `opposition_event(id, &"spawned", depth, run_t_ms)`;
   - **caps refuse at ceiling:** a cap_group of N accepts N and returns null for N+1;
     `can_afford` flips false at N; per-def `per_band_cap` refuses independently;
   - **registry counts:** `live_count` tracks spawn/despawn/free correctly (including a
     `queue_free`'d-without-`despawn` node dropping off after the validity sweep);
   - **`clear_all`** frees every registered node and zeroes counts/groups;
   - **entry-safe refusal:** a cell inside `SPAWN_SAFE_CELLS` of `entry_pos` is dropped by
     `valid_cells()` and refused by `spawn()`; an unarmed service (test-harness path) filters
     nothing;
   - `spawn_batch` returns per-request results in order; `ignore_room_cap` ctx is honored;
   - **no RNG:** two identical request sequences produce identical node positions.
8. **EventBus block** matches §4 verbatim (names, arities, primitives).
9. **Worklog** at `worklogs/2026-MM-DD-S0-general-purpose.md` from `worklogs/TEMPLATE.md` — task,
   files, **commit SHA**, checks run, **Design deviations** section (vs this spec + the
   breakdown; "none" if none). Branch `general-purpose/S0` (worktree isolation; verify branch
   topology before merge — qa git-switch-leak memory).

---

## 8. Open Questions

Every unresolved call, with trade-offs. Phase 3 (fresh eyes) resolves on merit; items marked
**Director** need a human verdict.

- **OQ-1 — `SpawnService`: autoload vs per-dive node; and *which parent* if per-dive?** The
  exploration recommends per-dive, group-resolved, and I concur with sharpened reasoning: an
  autoload would hold a live-node registry (pure run-state) in a meta-lifetime singleton —
  exactly the run/meta smear the TDD forbids — and would need explicit re-arming per run anyway;
  a per-dive node gets teardown for free when the App router swaps `main_game.tscn` out, and the
  `&"spawn_service"` group serves the debug menu/S6b without an autoload ref. The *sub-choice*
  S0 adds: parent under the **MainGame node** (lazy `_ensure_spawn_service()`), **not** under
  `_band_container` — the golden harness counts the container's children (`:51`) and
  `_clear_band()` would free the service every run. Per-band reset is the explicit `clear_all()`
  call instead. **Trade-off:** the lazy-create means the service node doesn't exist until the
  first enabled spawn seam runs (all-off dives never create it — which is also what keeps the
  all-off scene tree byte-identical). Alternative: instance it in `main_game.tscn` — simpler
  discovery, but adds a node to the all-off tree (harmless but not byte-identical-tree, and the
  bare-script harness has no scene). **Recommend: per-dive, lazy child of MainGame,
  group-resolved. Ratify.**
- **OQ-2 — Where do the `.tres` live?** Candidates: **(a) `data/oppositions/` (new)** — matches
  the umbrella taxonomy (hazards now, M2 enemies later, Fields/Fixtures after), sits beside
  `data/run_config/`, and gives S3's `oppositions_enabled` loader one canonical scan root;
  **(b) `data/enemies/`** (exists as `.gitkeep` since M0) — avoids a new folder but the name is
  wrong for the umbrella (a spike trap is not an enemy) and M2 will want it for actual
  enemy-combat content. **Recommend (a) `data/oppositions/`**, leave `data/enemies/` for M2.
  Cheap to move later (paths live in one descriptor table until S3). *Technical — resolver may
  decide.*
- **OQ-3 — Is the R1 pursuer's separate density path unified in S0 or deferred?** The breakdown's
  S0 goal says "unifying the two ceilings"; the zero-behavior-change constraint forces a careful
  reading. **Numeric** unification (one shared 48-or-64 pool) is a *behavior change* whenever the
  preset runs both seams (it does — `run_config.gd:662`+) — categorically not Phase A.
  **Mechanical** unification = both ceilings expressed as service cap groups. Sub-options:
  (i) *S0 routes R1's two instantiation loops through the service too* (needs a world-pos entry —
  OQ-10 — since the J2 path places by `_hazard_spawn_position` world coords, `:560`; R1's 64-cap
  stays in the plan functions because `test_per_room_density.gd`'s golden contract drives the
  plans directly): registry complete from day one, but R1's loops get touched twice (S0 relocate
  mechanism, S3 relocate policy) and the locked 6-method surface widens; (ii) *defer R1 routing
  to S3* (this spec's baseline): S0 builds the cap-group mechanism and enforces K5's 48 through
  it; R1's loops + `R1_DENSITY_BAND_CEILING` (`run_config.gd:37`) are untouched until S3's
  builder move (which rewrites those call sites anyway); the registry is K5-only for two waves,
  which nothing consumes before S3. **Recommend (ii) defer** — single-touch on the R1 loops,
  smaller S0 diff, no surface widening; the breakdown's "unifying" is satisfied at the mechanism
  level in S0 and at the call-site level in S3. Whether the *numbers* ever merge into one pool is
  a balance call for the gate. **Needs Director/resolver ratification since it re-reads the
  breakdown's parenthetical.**
- **OQ-4 — Exact band-routing signal shape (coordinate with S8).** Proposed (§4):
  `band_route_selected(band_id: StringName, profile_id: StringName)` as a *resolution receipt*,
  with `dive_requested(band_id)` unchanged as the *intent* signal and the chosen profile staged
  on a GameState **run-state** field (per the breakdown's recommendation) for the hub→dive swap.
  Alternatives: (a) no new signal — GameState field only; simplest, but Telemetry's `band_id`
  run-stamp (SG2's comparison key) then needs a GameState read inside Telemetry rather than a
  subscription, against the EventBus discipline; (b) widen `dive_requested` to
  `(band_id, profile_id)` — an arity change to a live M1.6 signal with existing emitters/
  subscribers, exactly what the pre-declare rule exists to avoid. Is `band_id` vs `profile_id`
  redundant? Possibly 1:1 in M1.9 (two portals, two profiles) — kept as two fields so a future
  band-id (fiction-level) can map to variant profiles (e.g. a debug override) without arity
  churn. **Recommend the sibling receipt signal as declared in §4; S8's Phase-2 design must
  confirm or amend BEFORE S0 merges** (S0 and S8 designs are being authored in the same Phase-2
  fan-out — the Phase-3 resolver for S8 should treat this shape as the default and flag any
  divergence loudly, since S0 is the sole Wave-1 `event_bus.gd` writer and a late change means a
  Wave-5 edit under the same pre-declare rule).
- **OQ-5 — Cap-precedence semantics.** With `per_room_cap`, `per_band_cap`, `cap_group`, and a
  notional global ceiling all expressible in the service, define: **the minimum binds** (a spawn
  must pass *every* applicable tier); check order = cheapest-first (per_band → cap_group →
  per_room, since per-room needs ctx room identity); `0` = "tier absent" at every level (matches
  today's `per_room_cap > 0` guard, `:458`); `ignore_room_cap` skips only the per-room tier,
  never band/group ceilings (a set-piece may crowd a room, not flood a band). Per-room accounting
  needs a room key — propose reserved ctx key `"room_key"` (the piece's `offset_cell` packed as
  `Vector2i`→`String`, or the piece index in the sorted walk) — **not consumed in S0** (per-room
  stays in the policy count math, §3.1) but the key name should be locked now so S3/S6 agree. A
  future `.tres` linter warning ("def per_band_cap exceeds its cap_group ceiling — dead knob")
  goes to the S4/S2 lint net, not S0. *Technical — resolver decides; no Director call.*
- **OQ-6 — `host_scene: PackedScene` export vs a path string.** An ExtResource'd PackedScene
  means loading the def loads the scene; the all-off lazy-load rule survives only because defs
  themselves are lazy-loaded per enabled type (§3.3). A `host_scene_path: String` would decouple
  def-load from scene-load (cheaper def enumeration for S4's menu, which wants schema without
  scenes) at the cost of losing the editor's resource picker + dependency tracking.
  **Recommend PackedScene + lazy def-load** (data-as-Resources convention, TDD); if S4's menu
  enumeration measurably drags loading 6+ scenes, revisit with `load_threaded` or a sidecar
  schema-only resource then, not now. *Technical.*
- **OQ-7 — Who emits `opposition_killed_player` during Waves 1–2?** Nobody (§5): the kill/contact
  distinction is only visible at the entity's `*_kills` gate, entities are S2's, and a bridge
  can't infer it. Consequence: the signal is declared-but-silent for one wave — acceptable
  (subscribers arrive in S4). Alternative — move the kill *decision* into the service in S0 —
  would edit entity internals, out of S0's charter. **Recommend: declared-silent until S2;
  ratify.**
- **OQ-8 — `&"spawned"` payload sourcing.** `depth`/`run_t_ms` from reserved ctx keys (defaults
  0), per §3.4 — the service never invents a clock (the R1 §4 precedent) and never reads
  GameState for the emit (generation-time spawns happen inside `start_new_run` where depth
  bookkeeping is mid-reset). Alternative: the service self-times from `begin_band()` — one clock
  more than needed, and wrong for mid-run clients who already self-time. **Recommend ctx-keys;
  technical.**
- **OQ-9 — Does `spawn_batch` ship in S0 with no caller?** The surface is breakdown-locked, so
  yes — but keep it the thin loop of §6.1 (its "one validation/registry pass" optimisation from
  the exploration is speculative until a real batch client (S6b children / set-pieces) shows a
  need; don't pre-engineer atomicity semantics like all-or-nothing batches without a consumer).
  Locked question for the resolver: is a *partial* batch (some nulls) acceptable as the contract?
  **Recommend yes — per-request independence, nulls in-place.**
- **OQ-10 — Surface widenings S0 wants but the breakdown didn't name:** `valid_cells()` (required
  for the filter-then-stride byte-identity, §1.3 — effectively non-optional), `live_total()`
  (trivial), `begin_band()`/`set_cap_group()` (lifecycle, implied), and — only if OQ-3 resolves
  to routing R1 in S0 — `spawn_world(def, pos, ctx)`. **Recommend: the first four are in-charter
  mechanism plumbing (document in the worklog as spec-sanctioned); `spawn_world` only exists if
  OQ-3(i) is chosen.**
- **OQ-11 — Do the descriptor table's legacy scene-path consts (`:325-327`) survive S0?** The
  defs now carry the scenes; keeping `HPP_SCENE_PATH` etc. as dead consts invites drift.
  **Recommend: delete the three consts, descriptor rows carry `def_path` only** (the def is the
  single source of the scene). `HAZARD_SCENE_PATH` (`:120`) stays — R1's seam is untouched
  (OQ-3). *Technical.*

---

## 9. Resolved Decisions (Phase 3 — fresh-eyes resolution, 2026-07-02)

Resolved by a Phase-3 fresh-eyes resolver (not this spec's author) on technical/design merit,
folding in the **orchestrator's cross-contract adjudications** made across the 10 parallel M1.9
Phase-2 designs. The questions below are now closed; where a resolution amends the body (§0–§7),
the amendment is stated here and **wins over the body text** — an implementing agent reads §9 as
the final word on each conflict. No open Director calls remain inside S0's Wave-1 scope; the one
genuinely Director-facing item (numeric merge of the two ceilings) is post-gate and already on
SG3's watch-list.

### Fresh-eyes verification of the body's load-bearing claims

Spot-verified 2026-07-02 against the working tree: the §1.2/§1.3 line anchors are accurate
(`_spawn_new_hazards` `:385-485` with the BUG7 filter at `:468-469` and player resolve at
`:396-397`; consts `:325-327`/`:337`/`:350`; ctx builder `:496-507`; `_clear_band` `:1187`;
`R1_DENSITY_BAND_CEILING` at `run_config.gd:37`; the EventBus signal lines `:89`/`:90`/`:149`/
`:151`/`:175`/`:181`/`:197`; the entity contracts `hazard_entity.gd:119-131`/`:236-240`/
`:319-323` and `pingpong_hazard.gd:63-74`/`:137-143`; `BASELINE_FP` at
`test_corridor_lever.gd:34`). Three corrections/strengthenings:

1. **The forwarding-const requirement is stronger than the body says.** The harness reads
   `mg_script.NEW_HAZARD_BAND_CEILING` at `test_new_hazard_spawn.gd:44` (body says `:45` —
   off-by-one, immaterial), **and additionally `test_rg1_m14_verify.gd:299` and `:403` read the
   same const off the MainGame script**. Two committed test files depend on it, so §6.3's
   "keep a forwarding const on MainGame" is **mandatory**, not conditional.
2. **`run_config.gd` lives at `Game/data/run_config/run_config.gd`** (not under `systems/`).
   The body's bare `run_config.gd:NNN` cites are all line-accurate; this note just pins the path
   for the implementer.
3. **OQ-11's deletion is verified safe:** `HPP_SCENE_PATH`/`HBOMB_SCENE_PATH`/`HSPIKE_SCENE_PATH`
   are referenced nowhere outside `main_game.gd` itself (repo-wide grep, tests included).

### The decisions

- **OQ-1 — Service lifetime/parent. RESOLVED: per-dive node, lazily created child of the
  MainGame node (never `_band_container`), group-resolved via `&"spawn_service"`.** As
  recommended. An autoload would put a live-node registry (pure run-state) in a meta-lifetime
  singleton — the run/meta smear the TDD forbids; the per-dive node gets teardown free with the
  scene swap, and lazy creation keeps both the all-off tree and the bare-script test harness
  byte-identical (the all-off path exits at `:421` before `_ensure_spawn_service()` ever runs).
  The `_band_container` parent is ruled out on two verified facts: `_clear_band()` frees the
  container's children and the golden harness counts them.

- **OQ-2 — `.tres` home. RESOLVED: `Game/data/oppositions/` (new folder).** Confirmed by
  orchestrator cross-contract adjudication #6 (all 10 designs reference this path). It matches
  the umbrella taxonomy (a spike trap is not an "enemy"), gives S3's `oppositions_enabled`
  loader one canonical scan root, and leaves `data/enemies/` free for M2 combat content.

- **OQ-3 — R1 unification scope. RESOLVED: option (ii), defer R1 routing to S3.** Confirmed by
  orchestrator adjudication #3, which also settles the breakdown's "unifying the two ceilings"
  parenthetical the body flagged for ratification: **K5's 48-ceiling enforcement moves through
  the service in S0** (the `&"new_hazards"` cap group); **R1's 64-ceiling + both R1 spawn loops
  stay parallel/legacy through all of M1.9** — "unify" means *mechanical/registry* unification
  only. Whether the two *numbers* ever merge into one pool is a post-gate balance call (SG3
  watch-item, Director's). Consequence: `spawn_world(def, pos, ctx)` from OQ-10 does **not**
  exist in S0 or M1.9 — mid-run position-based clients use the `world_to_cell` helper instead
  (see OQ-10).

- **OQ-4 — Band-routing signal shape. RESOLVED: `band_route_selected` is DROPPED — no new
  routing signal exists in M1.9.** Orchestrator adjudication #1, overriding this doc's §4
  proposal: S8's Phase-2 design verified end-to-end that `dive_requested(band_id: StringName)`
  has carried the band id since M1.6 (`event_bus.gd:197`; the App router receives and discards
  it, `app.gd:97-101`), so the request side needs nothing and the "resolution receipt" earns no
  second signal — the resolution is a GameState staging read, and Telemetry's `band_id`
  run-stamp rides `start_run(band_key, seed)` (S8 §4.1), not a subscription. **S0's Wave-1
  routing pre-declare shrinks to exactly** (per `S8_hub_portal_routing.md` §3, which this
  resolution defers to as the shape authority):
  1. **`event_bus.gd`** — a **doc-comment amendment only** on `dive_requested` (no new signal,
     no arity change): *"`band_id` is the dive routing key. GameState stages it on emission
     (`_pending_dive_band`); `main_game` resolves it to a `BandProfile` at dive start
     (unknown/empty → `band_greybox`). Emitters: the hub DeparturePortals (one per band)."*
  2. **`systems/game_state.gd`** — the **inert staging seam**: private
     `var _pending_dive_band: StringName = &""` (run-state, never persisted); GameState
     **self-subscribes** in `_ready()` (`EventBus.dive_requested.connect(...)`, one-line handler
     `_pending_dive_band = band_id`, beside the existing `player_died`/`dive_clock_timeout`
     connects); public `consume_pending_dive_band() -> StringName` — consume-on-read (returns
     the staged key and clears it; `&""` = nothing staged), mirroring the `_staged_run_config`
     pattern (`game_state.gd:145-146`). **Inert until S3** — nothing reads the slot in Waves
     1–2, so behavior and the all-off fingerprint are untouched by the pre-declare itself.

  **Body amendments this forces:** §4's code block loses the entire `band_route_selected`
  paragraph + signal (the `opposition_event`/`opposition_killed_player` half stands verbatim);
  §0 constraint 5 widens to "S0 is the sole Wave-1 writer of `main_game.gd`, `event_bus.gd`,
  **and `systems/game_state.gd`**" (S8 §3 designates S0 the seam's Wave-1 writer; S1 still
  touches none of the three); §6.3's deltas table gains a row —
  `Game/systems/game_state.gd`: **Append** the inert staging seam (field + self-subscribe +
  `consume_pending_dive_band()`); DoD item 8 becomes: *"EventBus block matches §4-as-amended
  (the two `opposition_*` signals only, verbatim) + the `dive_requested` doc-comment amendment
  + the GameState staging seam present and inert."* DoD item 7 gains one cheap tail check
  (verify-what-you-ship — S0 lands this code three waves before its first consumer):
  **staging round-trip** — emit `dive_requested(&"band_two")` → `consume_pending_dive_band()`
  returns `&"band_two"` → a second consume returns `&""`. (S8's Wave-5 contract test re-proves
  it end-to-end; this just refuses to ship dead-on-arrival plumbing.)

- **OQ-5 — Cap precedence. RESOLVED as proposed:** the **minimum binds** (a spawn passes every
  applicable tier); check order per_band → cap_group → per_room; `0` = tier absent at every
  level (matches the `per_room_cap > 0` guard at `:458`); `ignore_room_cap` skips **only** the
  per-room tier, never band/group ceilings. The reserved per-room identity key is locked now so
  S3/S6 agree: **`"room_key": String`, produced as `str(p.offset_cell)`** — the placed piece's
  `offset_cell: Vector2i` is intrinsic, stable, and already the piece identity the fingerprint
  serializes (`band.gd:61`); a walk-index would be fragile across policies and meaningless to
  mid-run clients. Not consumed in S0 (per-room stays in the policy count math, §3.1). The
  dead-knob `.tres` lint (per_band_cap > group ceiling) goes to S2/S4's net, as the body says.

- **OQ-6 — `host_scene: PackedScene`. RESOLVED: PackedScene export + lazy def-load,** as
  recommended. It is the `data/item.gd` data-as-Resources convention with editor picker +
  dependency tracking, and the all-off loads-nothing rule survives because defs are loaded
  exactly where scenes are loaded today (§3.3, verified: the enabled/neutral `continue`s at
  `:410-414` precede the `load` at `:415`). S4's def enumeration cost is hypothetical at 6 defs;
  revisit with a sidecar schema resource only if measured.

- **OQ-7 — `opposition_killed_player` emitter in Waves 1–2. RESOLVED: nobody — declared-but-
  silent until S2.** Confirmed by orchestrator adjudication #7. The kill/contact distinction
  exists only at the entity's `*_kills` gate (verified: `hazard_entity.gd:319-323`,
  `pingpong_hazard.gd:137-143` — the legacy signals fire on *contact* regardless of the gate),
  so no S0-side bridge can emit it correctly; entities are S2's charter. Subscribers arrive in
  S4; a declared-silent signal for one wave is the K0 pre-declare pattern working as designed.

- **OQ-8 — `&"spawned"` payload sourcing. RESOLVED: reserved ctx keys (`"depth"`, `"run_t_ms"`,
  defaults 0),** as recommended. The service never invents a clock (the entities' self-timing
  precedent, `hazard_entity.gd:315-318`) and never reads GameState mid-`start_new_run` where
  depth bookkeeping is being reset. Generation-time callers pass `p.depth_index` + `0`; mid-run
  callers (S6b) self-supply both, exactly as they already self-time.

- **OQ-9 — `spawn_batch` ships caller-less. RESOLVED: yes, as the thin per-request loop of
  §6.1; partial batches are the contract** (per-request independence, `null`s in place, order
  preserved). No atomicity/all-or-nothing semantics until a real batch client demonstrates the
  need — S6b's split spawns are 2–3 independent children, not a transaction.

- **OQ-10 — Surface widenings. RESOLVED: the S0 surface is the breakdown's six methods PLUS**
  (all confirmed in-charter mechanism plumbing; document in the worklog as spec-sanctioned):
  - `valid_cells(cells) -> Array[Vector2i]` — **confirmed by orchestrator adjudication #2**:
    the queryable BUG7 filter is a hard requirement (S3 depends on filter-then-stride byte
    parity; §1.3's sequence-point argument is verified correct against `:464-475`).
  - `live_total() -> int`, `begin_band(...)`, `set_cap_group(...)` — lifecycle/accounting as
    specified in §3.1/§6.1.
  - **`live_instances(def_id: StringName) -> Array[Node]`** — orchestrator adjudication #4:
    S4's respawn-with-new-params tier needs to enumerate a def's live nodes. Returns the
    validity-swept array (same `_compact` sweep as `live_count`).
  - **Per-instance spawn-cell bookkeeping + `spawn_cell_of(node: Node) -> Vector2i`** —
    adjudication #4: the registry records each instance's spawn cell at `spawn()` (registry
    entries become `{node, cell}` per def id, or a parallel `node → cell` map — implementer's
    pick), so S4 can respawn *at the same cell* without re-deriving placement. Returns
    `Vector2i.MAX` for an unregistered node.
  - **Public projection pair `cell_to_world(cell: Vector2i) -> Vector2` and
    `world_to_cell(pos: Vector2) -> Vector2i`** — orchestrator adjudication #5: S6b's mid-run
    splits spawn at the parent's *world position* and must snap it to a cell for
    `spawn(def, cell, ctx)`. `cell_to_world` is §6.1's `_cell_to_world` made public (same
    `:761-763` math); `world_to_cell` is its floor-division inverse
    (`Vector2i((pos / float(_cell_size_px)).floor())`).
  - **`spawn_world(...)` does NOT exist** — mooted by OQ-3(ii); a world-pos client composes
    `spawn(def, world_to_cell(pos), ctx)`.

  **Body amendments:** §6.1's registry gains the cell bookkeeping (`_register(def, hz, cell)`),
  the two query methods, and the public projection pair; DoD item 7 gains asserts for
  `live_instances` contents and `spawn_cell_of` round-trip (spawn at cell C → `spawn_cell_of`
  returns C; unregistered node → `Vector2i.MAX`) and a `world_to_cell(cell_to_world(c)) == c`
  identity check.

- **OQ-11 — Legacy scene-path consts. RESOLVED: delete `HPP_SCENE_PATH`/`HBOMB_SCENE_PATH`/
  `HSPIKE_SCENE_PATH`; descriptor rows carry `def_path` only.** Verified safe — no reference
  outside `main_game.gd` (grep, tests included). `HAZARD_SCENE_PATH` (`:120`) stays with R1's
  untouched seam per OQ-3. The def is the single source of the scene from S0 on.

### Cross-contract confirmations folded in (no OQ attached)

- **Def ids** (orchestrator adjudication #6): the four S0 ids are the legacy telemetry kinds
  exactly as §3.3 authors them (`&"pingpong"`, `&"bomb"`, `&"spike"`, `&"pursuer"`); the M1.9
  new-content ids are locked as `&"charger"`, `&"splitter"`, `&"splitter_child"` (S6a/S6b author
  those `.tres` in `Game/data/oppositions/` — S0 ships only the four).
- **Cap-group posture** (adjudication #3 restated at the mechanism level): §3.1's Phase-A
  enforcement line stands verbatim — group cap `&"new_hazards"` = 48 through the service,
  belt-and-braces with the untouched policy min(), never observed to bind first in Phase A.
- **Dual-emit table (§5) and the no-bridge rejection stand unamended** — consistent with
  adjudication #7.

*Phase-3 resolution by fresh-eyes resolver, 2026-07-02. All resolutions are on technical merit
or orchestrator cross-contract adjudication; the sole Director-facing residue (numeric ceiling
merge) is explicitly post-gate on SG3's watch-list. Implementation deviations from §9 go to
`design/DESIGN_DEVIATIONS.md` for the Wave-1 close-out sweep.*

---

## 10. Wave-1 close-out amendments (as-built, Director-dispositioned 2026-07-02)

- **Cap-group accounting is live-registry-derived** (Director: **Reviewed**). §6.1's
  `{ceiling, count}` monotonic-counter sketch is superseded: the service stores ceilings only and
  derives counts from the validity-swept live registry (one source of truth with `live_count()`).
  A node freed mid-run re-opens cap headroom for mid-run spawners (S6b+). Also recorded in the
  breakdown's cross-cutting contracts.
- **Registry sweep is fully typed** (Director: **Addressed** → code restructured at close-out).
  `_compact()`/`clear_all()` test `entry["node"]` in place via `is_instance_valid(...)` instead of
  binding possibly-freed instances to locals — no untyped locals; the typed-GDScript convention
  holds with zero exceptions.
