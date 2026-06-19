# J3 — Per-room hazard / density knob (M1.3 spec)

**Milestone:** M1.3 — Legibility & Density (iteration of M1.2) · **Workstream:** Wave 2 — Density & spatial
**Task id:** J3 · **dependsOn:** J1 (`design/M1_3_Tasks/M1.3_Breakdown.md` §4 — J3 `BlockedBy: J1`, tunes against the new default scale; pairs with J2)
**Assignees (build wave):** `general-purpose` (the placer/spawn-seam wiring) — single builder; see §(a) "J2/J3 seam ownership"
**Status:** Phase-2 design spec (this doc). Phase-3 fresh-eyes resolves §(c) Open Questions before build.
**Companion docs:** `M1.3_Breakdown.md` §J2/§J3/§4/§5/§7 · `G4_findings_M1.2.md` §3 (I1 "huge empty room" + F3b row) + §5 (Director F3b) · `M1_2_Tasks/I1_level_scale.md` (the size multiplier + the junk-coordinate seam this builds on) · `data/run_config/run_config.gd` · `scenes/game/main_game.gd` (`_spawn_r1_hazards`, `_hazard_spawn_position`) · `scenes/hazards/hazard_entity.gd` · `systems/depth/junk_placer.gd` + `systems/depth/depth_curve.tres` · `systems/depth/depth_grader.gd` · `systems/bandgen/band_generator.gd` + `placed_piece.gd` · `data/piece_catalog_ext.tres`

> **Scope guardrail (Breakdown §2):** J3 is **greybox + configurable-not-balanced**, same as I1/J1/J2. It exposes a *density* lever as a swept `RunConfig` knob; the value is the Director's to sweep, not ours to finalize. The all-off default must reproduce the M1.0/M1.1/M1.2 baseline (no hazards, baseline loot count) byte-for-byte. **Density = more of the existing hazard** (and optionally a small loot bump) keyed to room size — NOT a new hazard type, NOT new gameplay, NOT a generator rewrite, NOT new art.

---

## (a) Research

### The one sentence
*When the Director dials rooms big (size 4×–40×), populate each room with danger proportional to its size so a 40×-room is a charged space to cross, not an empty field — without moving the all-off baseline and without fighting J2's depth-spread spawn.*

### Why this task — the "huge empty room" evidence (G4 §3 + §5 F3b)

`G4_findings_M1.2.md` is unambiguous that I1's size multiplier *worked* spatially but left the big rooms **hollow**:

- **§3, I1 row:** at `lvl_size_mult = 10.0` "**every run times out at 60 s without finishing — depth only ~4**." Big rooms turned the sprint into an expedition, but the time was spent on **empty traversal**, not on interesting decisions.
- **§3, I1 "long hallways" read:** `nav_branch_taken` averages ~6–7 junctions/run *regardless of size* (size 2×: 7.0/run, 4×: 6.6/run, 10×: 5.3/run). Junction count per run is flat while duration grows with size → **the extra time at larger sizes is content-free space**: same number of meaningful decisions, much more void between them.
- **§5, Director F3b (verbatim intent):** *"Want a hazard per room to fill huge empty rooms."* The Director's own diagnosis: a size-10× run reaches depth only ~4 in 60 s → "lots of empty traversal."
- **§3 recommendation row (table #3b):** "per-room hazard/loot density knob."

The defect has a precise mechanical cause in two systems, both visible in-repo:

1. **Hazards don't scale with room size at all.** `scenes/game/main_game.gd` `_spawn_r1_hazards()` spawns exactly `rc.r1_spawn_count` hazards, all clustered at **one** depth (`r1_depth_threshold`) via `_hazard_spawn_position(band, rc.r1_depth_threshold, i)`. A 40×-room and a 1×-room get the **same** hazard population. Nothing reads room area.
2. **Loot barely scales with room size.** `systems/depth/junk_placer.gd` `plan()` draws `count = _seeded_round(curve.expected_count(d), rng)` **per piece**, and `depth_curve.tres`'s `density_curve` is held *flat* at ~2.0–2.3 (G4-confirmed design intent in `depth_curve.gd`: "density held roughly flat… flooding deep rooms with quantity would make shallow pieces feel worthless"). So `piece_room_xl` (16×12 = 192 cells, the largest ext piece, `data/piece_catalog_ext.tres`) gets **~2 junk items** — the same ~2 a `piece_corridor_h` (8×4 = 32 cells) gets. At size 40× the room is geometrically ~36× the corridor's area but holds the same two pickups. **Density-per-area collapses as rooms grow** — that is the literal "empty" feeling.

So J3 must make **per-room population a function of room size**, defaulting to today's behaviour when off.

### What "density" means here (three distinct things — name them so the knob is unambiguous)

The Breakdown deliberately writes J3 as "hazard/density" with a slash because two reward-orthogonal things both contribute to "empty":

- **Hazard density** — how much *danger* fills a room (more HazardEntity nodes, or hazards seeded *inside* big rooms rather than all at one depth). This is the **primary** F3b ask ("a hazard per room"). It makes a big room a space you must *navigate under threat*, not just walk.
- **Interest / loot density** — how much *reason-to-be-there* fills a room (junk pickups, props). A big empty room with one hazard is still mostly empty floor; spreading a few more pickups gives the player something to weave toward while dodging. This is the *secondary* "fill the emptiness" reading.
- **Per-depth density** — how danger/reward is distributed *along the spine* (J2's axis: N hazards across `depth_index`). This is **J2's** job, not J3's.

J3 owns the first two (population **per room, scaled by room size**); J2 owns the third (population **per depth, scaled by spine length**). They are two *views of the same population system* — see the seam below. **Recommendation:** J3's knob is primarily a **hazard** density knob (the Director said "hazard per room"); add a *small, optional, off-by-default* loot-density-per-area sub-knob so "fill emptiness" can be tested with loot too without a second task. (Open Q B settles the loot question.)

### What exists in-repo (real files / APIs)

**The hazard spawn seam (the shared seam with J2).** `scenes/game/main_game.gd`:
- `_spawn_r1_hazards(rc, band)` (line ~276): gated on `rc.r1_enabled and rc.r1_spawn_count > 0`; loops `for i in rc.r1_spawn_count`, instantiating `HazardEntity` into `_band_container`, positioned by `_hazard_spawn_position(band, rc.r1_depth_threshold, i)`, then `hz.setup(rc, player)`.
- `_hazard_spawn_position(band, depth_threshold, index)` (line ~296): clamps `depth_threshold` to the band's max graded depth, collects `floor_cells` of all pieces at that **one** target depth, returns `cells[index % cells.size()]` centred in world px (`* _band_cell_size_px`). **Every hazard lands at the single threshold depth** — this is exactly the "one enemy at a gate" J2 replaces, and the same function J3 must extend to seed *per room*.
- `HazardEntity.setup(cfg, player)` (`scenes/hazards/hazard_entity.gd`) snapshots the config; the hazard reads `_cfg.r1_*` for its awaken/chase/catch. **A J3 hazard is just another HazardEntity** — no new entity type, no new behaviour; J3 only changes *how many and where* hazards spawn.

**The loot density seam.** `systems/depth/junk_placer.gd` `plan(band, curve, catalog, emit_events, cell_size_override)`:
- per piece: `count = _seeded_round(curve.expected_count(p.depth_norm), rng)`, then a loop placing `count` items on `_sorted_floor_cells(p)` via a local deterministic sub-stream (`rng` seeded from `band.resolved_seed + _JUNK_SALT`). **The per-piece count is the single line J3's loot sub-knob would scale.**
- `cell_size_override` already threads `lvl_size_mult`'s effective px-per-cell (the I1 junk-seam fix). J3's loot scaling is a *count* change, orthogonal to the px coordinate change.

**Room-vs-corridor classification (how to tell a "room" from a "corridor").** Two real signals, both already on `PlacedPiece` / the catalog:
- **By id prefix** — `data/piece_catalog_ext.tres` pieces split cleanly: corridors = `piece_corridor_h/v/l`, `piece_corridor_long_h`, `piece_hall_v`; rooms = `piece_box_small/large`, `piece_room_hub`, `piece_room_xl`, `piece_chamber`. `PlacedPiece.piece_id` carries this.
- **By floor-cell area / aspect** — `PlacedPiece.floor_cells.size()` is the walkable cell count; corridors are long-thin (high aspect, small area: corridor_h = 8×4, long_h = 16×4, hall_v = 4×14), rooms are chunky (box_large 10×8, room_hub 12×12, room_xl 16×12, chamber 14×10). **Area is the robust, content-agnostic signal** — it works for any future piece without an id allow-list and is what "scale danger with how big the room is" literally means. **Recommendation: scale off floor-cell area** (`floor_cells.size()`), with the id prefix available as an optional "rooms only, never corridors" filter (Open Q A). Area is also already used everywhere (placer, grader) so it's a known-good per-piece scalar.

**The size multiplier does NOT change cell counts.** Critical for the metric choice: `lvl_size_mult` is a **pixel projection** (I1 Resolved F — `fingerprint()` is layout-invariant under it). A `piece_room_xl` is *192 floor cells at every `lvl_size_mult`*. So a density metric keyed off `floor_cells.size()` gives the **same room-population at every size multiplier** — which is correct for "danger per room" (a room of the same shape gets the same number of hazards) but does **not** automatically scale population with the *pixel* size the player experiences. This is the central tuning question (Open Q C): do we want N hazards per *room* (cell-area-keyed, size-invariant) or N hazards per *screen of floor* (px-area-keyed, grows with `lvl_size_mult`)? See §(b) and Open Q C.

**Determinism contract (inherited).** Two separate determinism keys are live and J3 must respect both:
- **Layout** — `band.fingerprint()` keys piece_id@offset#mated_socket. Hazards and loot are **run-state population placed *after* generation** — they are NOT in `fingerprint()` and must never enter it (they are torn down with `_band_container` each run, never persisted). *J3 must not touch `band_generator.gd`/`band.gd`/`fingerprint()`.*
- **Loot sub-stream** — `JunkPlacer` uses a **local `RandomNumberGenerator`** seeded from `band.resolved_seed + _JUNK_SALT`, deliberately *not* the global `RNG` autoload, so junk rolls never perturb the layout stream. Any J3 loot-count change rides this existing sub-stream and stays reproducible from seed+config.
- **Hazard placement** — `_hazard_spawn_position` is currently **fully deterministic with no RNG** (it walks `floor_cells` in piece order and indexes `cells[index % size]`). If J3 wants hazards seeded at *varied* in-room positions (not just the first floor cell), it must either stay index-deterministic (preferred — no RNG, trivially reproducible) **or** use a dedicated local sub-stream like JunkPlacer's (seed = `band.resolved_seed + a J3 salt`), **never** the global `RNG` (which would desync layout). **Recommendation: keep hazard placement RNG-free / index-deterministic** (cheapest, provably reproducible, matches today). See §(b).

### The shared hazard-spawn seam with J2 — composition proposal

**The problem the Breakdown flags (§4, §5 Wave 2, §7):** J2 (enemy spread across *depth*) and J3 (density per *room/size*) both want to rewrite `_spawn_r1_hazards` / `_hazard_spawn_position`. Two tasks writing the same two functions in one wave is the W1.1-2 multi-writer collision the Breakdown explicitly forbids.

**The insight: J2 and J3 are one population system viewed on two axes.** Both answer "how many HazardEntity nodes, and at which floor cells." They differ only in the *distribution rule*:
- **J2** distributes a hazard *budget* across `depth_index` (so danger is spread along the spine, not stacked at one threshold).
- **J3** sets *how big that budget is per room* as a function of room size (so big rooms aren't empty).

These compose cleanly as **budget (J3) → distribution (J2)**: J3 decides *how many* hazards a room earns from its size; J2 decides *which depths/rooms* get them so they're spread, not clustered. A single rewritten spawn seam computes a per-room hazard count (J3's rule) and walks the depth-sorted rooms placing them (J2's rule).

**Recommended ownership for Wave 2 (single-writer-per-file, per Breakdown §6):**

- **One builder owns the entire hazard-spawn seam** — `_spawn_r1_hazards` + `_hazard_spawn_position` in `scenes/game/main_game.gd` (and any new `r1_`/`density_` knobs they read). Build **J2 and J3 as one merged spawn rewrite on one shared branch** (the Breakdown allows shared-task branches; §4 "design them together, may share the hazard-spawn seam"). The merged function:
  1. computes a **per-room hazard budget** (J3: `f(room area, density knob)`),
  2. **distributes** that budget across rooms ordered by `depth_index` (J2: spread, with J2's count/distribution knobs governing the spine-level shape),
  3. places each hazard at a deterministic in-room floor cell, `setup()`s it.
- **`run_config.gd` is owned by J1 in Wave 1** (Breakdown §5 single-writer warning). **Both J2's and J3's new knobs must be declared by J1's Wave-1 `run_config.gd` edit**, OR J2/J3 sequence after J1 and one of them owns the `run_config.gd` add in Wave 2. *Recommendation:* fold the J2 + J3 knobs into J1's Wave-1 `run_config.gd`/CFG/`to_flat_dict()` pass (J1 already touches all three) so Wave 2 only writes the spawn seam — this is the cleanest single-writer split and matches how I1 pre-added the `lvl_` knobs before its consumers.
- **`junk_placer.gd`** (J3's *optional* loot sub-knob) is **disjoint from the hazard seam** and from J2 — if the loot sub-knob ships (Open Q B), it can be a separate single-writer file owned by J3 with no collision. (J4's hallway-length task does not touch `junk_placer.gd`.)

**Net:** J3's *design contract* is "per-room size-scaled hazard budget + an optional loot-per-area bump"; J3's *code* is co-built with J2 as one spawn-seam rewrite under one owner, plus an optional disjoint `junk_placer.gd` edit. This removes the multi-writer risk the Breakdown calls out.

---

## (b) Pseudocode

Illustrative, against the real as-built APIs. The programmer writes typed GDScript.

### The knobs (declared by J1's Wave-1 `run_config.gd` pass; J3 consumes)

```gdscript
# run_config.gd — extend the R1 group (density rides the existing hazard system).
# ALL-OFF DEFAULTS reproduce M1.0/M1.1/M1.2: 0 hazards-per-room, loot multiplier 1.0.
@export_group("R1 Pursuing Hazard", "r1_")
# ... existing r1_* knobs ...
## J3: extra hazards seeded PER ROOM, scaled by room size. 0 = off (M1.2 behaviour:
## only r1_spawn_count hazards at the threshold). One unit = "this many hazards per
## R1_DENSITY_AREA_UNIT floor-cells of a room" (size metric, see r1_density_metric).
@export var r1_per_room_density: float = 0.0
## J3: which area metric scales the per-room budget.
##   0 = cell_area   (floor_cells.size(); SIZE-INVARIANT — N per room shape)
##   1 = px_area     (cell_area * size_mult^2; grows with lvl_size_mult — N per screenful)
@export_enum("cell_area", "px_area") var r1_density_metric: int = 0
## J3: only seed density hazards in ROOM pieces (id not corridor_*), never corridors.
## false = any piece above the area floor is eligible.
@export var r1_density_rooms_only: bool = false
## J3: floor-cell area a piece must exceed before it earns ANY density hazard
## (so small boxes/corridors stay empty until genuinely big). 0 = no floor.
@export var r1_density_min_area: int = 0
## J3 hard cap on density hazards per single room (perf + fun guard). 0 = uncapped.
@export var r1_density_per_room_cap: int = 0
```

```gdscript
# OPTIONAL loot sub-knob (Open Q B — off by default, separate single-writer file).
# Lives near the lvl_ group OR the r1_ group; it scales JunkPlacer's per-piece count
# by room area so big rooms get proportionally more interest. 1.0 = M1.2 behaviour.
@export var lvl_loot_density_per_area: float = 0.0   # 0 = off (curve count only)
```

### J3 ⨉ J2 merged spawn seam (one owner; main_game.gd)

```gdscript
# main_game.gd — replaces _spawn_r1_hazards. J3 sets the per-room BUDGET; J2 spreads
# it across depth. Fully gated: r1 off OR (spawn_count==0 AND per_room_density==0) → 0
# hazards → byte-identical to the all-off baseline (no node ever instantiated).
func _spawn_r1_hazards(rc: RunConfig, band: Band) -> void:
    if rc == null or not rc.r1_enabled:
        return
    var hazard_scene := load(HAZARD_SCENE_PATH) as PackedScene
    if hazard_scene == null:
        push_error("MainGame: R1 hazard scene missing at %s." % HAZARD_SCENE_PATH)
        return
    var player := get_tree().get_first_node_in_group(&"player") as Node2D

    # --- J3: per-room size-scaled budget (deterministic, no RNG) --------------
    # For each piece, compute how many density hazards it earns from its size.
    var spawns: Array[Vector2] = []   # world positions, deterministic order
    for p in _rooms_sorted_by_depth(band):          # stable: depth_index, then piece order
        var area := _density_area(p, rc)            # cell_area or px_area per r1_density_metric
        if rc.r1_density_rooms_only and _is_corridor(p.piece_id):
            continue
        if area < rc.r1_density_min_area:
            continue
        var n := int(floor(rc.r1_per_room_density * float(area) / float(R1_DENSITY_AREA_UNIT)))
        if rc.r1_density_per_room_cap > 0:
            n = mini(n, rc.r1_density_per_room_cap)
        # J3 placement: spread the room's n hazards across ITS OWN floor cells,
        # index-deterministic (no RNG) — even fractions across the sorted cells.
        var cells := _sorted_floor_cells(p)         # reuse JunkPlacer's stable sort
        for k in n:
            var cell: Vector2i = cells[(k * maxi(cells.size() / maxi(n, 1), 1)) % cells.size()]
            spawns.append(_cell_centre_world(cell))

    # --- J2: ALSO place the threshold/spread hazards (J2 owns this distribution) -
    # J2's rewrite contributes the spine-spread hazards (its r1_spawn_count budget
    # distributed across depth_index). Appended to the SAME spawns list so J2 and
    # J3 hazards are one population. (J2 authors this block; shown for the seam.)
    spawns.append_array(_j2_spread_spawn_positions(rc, band))

    # --- instantiate one HazardEntity per planned position (shared by J2+J3) ----
    for pos in spawns:
        var hz := hazard_scene.instantiate() as HazardEntity
        _band_container.add_child(hz)
        hz.global_position = pos
        hz.setup(rc, player)   # density hazards are ordinary HazardEntities

# Cell-area vs px-area metric (px grows with the size multiplier; cell is invariant).
func _density_area(p: PlacedPiece, rc: RunConfig) -> float:
    var cells := float(p.floor_cells.size())
    if rc.r1_density_metric == 1:                 # px_area: scale by size_mult^2
        var m := rc.lvl_size_mult if (rc.lvl_enabled) else 1.0
        return cells * m * m
    return cells                                  # cell_area: size-invariant

func _is_corridor(id: StringName) -> bool:
    return String(id).begins_with("piece_corridor") or id == &"piece_hall_v"

func _cell_centre_world(cell: Vector2i) -> Vector2:
    return Vector2(cell * _band_cell_size_px) \
        + Vector2(_band_cell_size_px, _band_cell_size_px) * 0.5
```

> **Determinism note:** the J3 path uses **no RNG at all** — it walks pieces in depth-sorted, then stable-cell order and indexes by integer arithmetic, exactly like today's `_hazard_spawn_position`. Same (seed → band) → same density placement, run to run. Hazards are run-state (`_band_container`, freed each run), never persisted, never in `fingerprint()`. **All-off (`r1_per_room_density == 0`) → the inner `n` loop produces 0 spawns → identical to the M1.2 baseline.** The J1 preset sets `r1_per_room_density` to a non-zero sweep value so big rooms fill.

### Optional loot density (JunkPlacer; disjoint file, only if Open Q B → yes)

```gdscript
# junk_placer.gd — plan(): scale the per-piece count by room area when the knob is on.
# Rides the EXISTING local sub-stream (band.resolved_seed + _JUNK_SALT) — reproducible,
# never touches the global RNG. All-off (mult 0/1.0) → identical to today.
var base_count := curve.expected_count(p.depth_norm)        # ~2.0 flat (depth_curve.tres)
var area_count := base_count
if loot_density_per_area > 0.0:
    var area_units := float(p.floor_cells.size()) / float(JUNK_AREA_UNIT)
    area_count = base_count + loot_density_per_area * base_count * (area_units - 1.0)
var count := _seeded_round(area_count, rng)                 # seeded probabilistic round
```

### All-off / default reproduces the baseline

| Knob | All-off default | Effect |
|---|---|---|
| `r1_per_room_density` | `0.0` | no density hazards; only `r1_spawn_count` at threshold (= M1.2) |
| `r1_density_metric` | `cell_area` | inert at density 0 |
| `r1_density_rooms_only` | `false` | inert at density 0 |
| `r1_density_min_area` | `0` | inert at density 0 |
| `r1_density_per_room_cap` | `0` | uncapped (inert at density 0) |
| `lvl_loot_density_per_area` | `0.0` | JunkPlacer uses the curve count only (= M1.2) |

With all at default, `_spawn_r1_hazards` produces exactly the M1.2 hazard population and `JunkPlacer` exactly the M1.2 loot — the permanent control (all-off fp still `e943ac9c8bc1`; hazards/loot are run-state, never in the fingerprint anyway).

### CFG coverage + TEL snapshot (the standing M1.1/M1.2 contract)

- Every new knob joins `ui/config/config_menu.gd` (`SECTIONS`/`MANIFEST`/`FIELD_RANGE`) so `has_full_coverage()` passes (J1 owns the CFG pass if the knobs ride J1's Wave-1 add; otherwise the seam owner does). Density knobs sit under the existing **R1** section (they extend the hazard system) — propose `FIELD_RANGE`: `r1_per_room_density → [0.0, 4.0]` (0.25 step), `r1_density_min_area → [0, 256]`, `r1_density_per_room_cap → [0, 16]`.
- Every new knob joins `RunConfig.to_flat_dict()` (additive `data` payload on `run_started`, NOT a schema bump) so RG2 can segment outcomes by density and compare M1.3 to the M1.0–M1.2 baselines on the same metrics.
- Update `tests/test_run_config.gd` / `test_config_menu.gd` knob counts (the M1.1/M1.2 obligation).

### Files to touch (build wave)

**Touch (Wave 2, shared hazard-spawn branch, single owner with J2):**
- `scenes/game/main_game.gd` — the merged `_spawn_r1_hazards` budget+spread seam (J3 budget + J2 distribution). *One owner for both tasks.*

**Touch (Wave 1, J1's pass — pre-declare the J3 + J2 knobs):**
- `data/run_config/run_config.gd` — the new `r1_*` density knobs + `to_flat_dict()` additions.
- `ui/config/config_menu.gd` + `ui/config/config_strings.csv` — CFG section/manifest/range/strings.
- `tests/test_run_config.gd` / `tests/test_config_menu.gd` — knob-count updates.

**Touch (only if Open Q B → loot, disjoint file owned by J3):**
- `systems/depth/junk_placer.gd` — area-scaled per-piece count (rides the existing sub-stream).

**Confirm NOT touched:**
- `systems/bandgen/band_generator.gd` / `band.gd` `fingerprint()` — unchanged (hazards/loot are post-gen run-state).
- `systems/event_bus.gd` — NOT edited (no new signal; density projects through the existing `run_started` config snapshot and the existing `hazard_*` events). *If RG2 wants per-room-density telemetry beyond the config snapshot, decide in Phase 3 and pre-declare on `main`.*
- `scenes/hazards/hazard_entity.gd` — unchanged (a density hazard IS an ordinary HazardEntity).

### Acceptance criteria (from Breakdown §J3, made concrete)

1. **Density is settable + takes effect.** With `r1_enabled` and `r1_per_room_density > 0`, big rooms get hazards proportional to their size; off (`0.0`) = the M1.2 single-threshold hazard population.
2. **Big rooms aren't empty.** At the J1 preset (size ≥4.0, R1 on) a `piece_room_xl`/`chamber` carries ≥1 density hazard; a `piece_corridor_h` carries few/none (per the metric + min-area).
3. **All-off == baseline.** With `r1_per_room_density = 0` (and loot knob 0), hazard + loot population is identical to M1.2 — the permanent control; all-off `fingerprint()` unchanged (`e943ac9c8bc1`).
4. **Determinism preserved.** Same (seed + config) → byte-identical density placement run-to-run (J3 path is RNG-free; loot sub-knob rides the existing `_JUNK_SALT` sub-stream). Hazards/loot never enter `fingerprint()` and are never persisted.
5. **CFG + TEL pick up the knobs.** `has_full_coverage()` passes; `to_flat_dict()` carries every density knob onto `run_started`; knob-count tests updated.
6. **Composes with J2.** J2's spine-spread hazards and J3's per-room density hazards are one population, placed by one owner; no multi-writer collision on the spawn seam; both visible/segmentable in RG2.
7. **Perf guard holds.** With `r1_density_per_room_cap` and a sane sweep, a high-density × huge-room run does not spawn an unbounded hazard count (see Open Q E).

---

## (c) Open Questions (Phase-3 fresh-eyes resolves; Director/fun calls flagged)

**A. Density metric: per-room count vs per-area vs per-depth?** *(design call, lean technical)*
Three candidate metrics: (1) **flat per-room count** ("every room gets exactly N") — simple, but a tiny box and a chamber get the same N, which doesn't "fill *big* rooms"; (2) **per-area** (`r1_per_room_density * floor_cells / unit`) — scales danger with how big the room actually is, directly matching "fill huge rooms"; (3) **per-depth** — that's J2's axis, not J3's. **Recommendation: per-area, keyed off `floor_cells.size()`**, with `r1_density_min_area` so small pieces/corridors stay empty until genuinely big and `r1_density_rooms_only` as an optional corridor exclusion. Per-area is what "scale with room size" means and is content-agnostic (works for any future piece). *Resolve on merit; not a Director call.*

**B. Should "fill emptiness" be hazards only, or also loot/props?** *(Director / fun call)*
F3b says "a hazard per room," but the §3 recommendation row also says "hazard/loot density." Pure-hazard density makes big rooms *dangerous*; adding loot-per-area gives the player a *reason* to enter the danger (something to weave toward). Trade-off: loot-per-area risks the exact thing `depth_curve.gd` warns against — "flooding deep rooms with quantity makes shallow pieces feel worthless" — and inflates the economy the RG2 re-gate reads. **Recommendation: ship the hazard density knob as primary (the literal F3b ask) AND ship the loot-per-area sub-knob OFF by default**, so the Director can A/B "dangerous-but-empty-of-loot" vs "dangerous-and-rewarding" big rooms in one build without a second task — but ship the loot knob as a disjoint, clearly-secondary lever. *Genuine Director feel/economy call: does filling emptiness mean threat, reward, or both? Flag for Director review; recommend "both, loot off-by-default."*

**C. Does density scale with `lvl_size_mult` (px-area) or stay size-invariant (cell-area)?** *(Director / fun call — the load-bearing one)*
A `piece_room_xl` is 192 floor *cells* at every `lvl_size_mult` (size is a pixel zoom, not a cell change — I1 Resolved F). So **cell-area** density gives the *same* number of hazards to a room regardless of the size slider — a 40×-room and a 4×-room of the same shape get equal hazards, meaning the 40×-room is *less dense per screenful* (the original "empty" complaint partially returns at extreme sizes). **px-area** (`cell_area * size_mult²`) keeps a constant hazard-per-screen feel as the room grows. Trade-offs: cell-area is bounded/predictable and won't explode at size 40× (perf-safe, Open Q E); px-area "fills the screen" consistently but a size-40× room (1600× the px-area) would demand a huge count unless capped hard. **Recommendation: expose BOTH via `r1_density_metric` (default `cell_area`), and have the J1 preset choose** — start the preset on `cell_area` (predictable, perf-safe) and let the Director sweep `px_area` if cell-area big rooms still read empty at 40×. *This is precisely the F3b fun question ("fill huge empty rooms") — flag for Director review; recommend cell-area default + px-area as a swept option + a hard per-room cap.*

**D. J2/J3 seam ownership — merged spawn rewrite vs sequenced.** *(build-org call, resolve in Phase 3 / at brief)*
§(a) recommends **one owner builds J2+J3 as one spawn-seam rewrite on a shared branch** (budget = J3, distribution = J2), with J1 pre-declaring both tasks' knobs in Wave 1. The alternative — J2 and J3 as two sequential single-writer edits to `main_game.gd` — risks the second rewrite clobbering the first's distribution logic. **Recommendation: merged rewrite, one owner; J1 pre-adds the knobs.** *Confirm the owner + that J1's Wave-1 `run_config.gd` pass includes the J2 + J3 knobs (so Wave 2 writes only the spawn seam). Lean build-org, but it touches the wave plan — Phase 3 / orchestrator confirms.*

**E. Perf at high density × huge rooms.** *(build-time verification + a guard)*
The combinatorial worst case is `px_area` metric × `lvl_size_mult = 40` × a high `r1_per_room_density`: a size-40× `piece_room_xl` has px-area ~192 × 40² ≈ 307,200 area-units → without a cap, the per-room count explodes and every HazardEntity runs a `_physics_process` chase + a slide-collision de-pin per frame. Even cell-area at high density across ~20 rooms could spawn dozens of chasing bodies. **Mitigations baked into §(b):** `r1_density_per_room_cap` (hard per-room ceiling) and `r1_density_min_area` (corridors/small boxes earn none). **Recommendation: the J1 preset MUST set `r1_density_per_room_cap` to a sane value (e.g. 2–4) and a non-trivial `r1_density_min_area`**, and the build worklog must record a measured frame-time at the Director's intended max sweep (size 40× × preset density) so RG1 confirms it holds. *Build-time verification + the cap is non-negotiable; the exact cap value is a Director sweep.*

**F. Should density hazards spawn AWAKE / pre-positioned to threaten, or dormant like threshold hazards?** *(design / fun call, lean technical)*
Today every hazard spawns `State.DORMANT` and wakes on `r1_depth_threshold` or `r1_linger_seconds` (`hazard_entity.gd` `_should_awaken`). A density hazard seeded *inside* a deep big room may already be past its depth threshold at spawn → it could wake almost immediately, making big rooms instantly lethal rather than "charged." Conversely if all density hazards stay dormant until the global threshold, a shallow big room reads empty (dormant = inert grey shape). **Recommendation: keep the existing awaken logic unchanged (density hazards are ordinary HazardEntities; they wake by the same depth/linger rules), and let the Director tune `r1_depth_threshold`/`r1_linger_seconds` in the preset so the wake cadence feels right.** No new wake rule in J3 — that keeps J3 a pure population knob and avoids entangling it with R1's awaken design. *If playtest shows deep big rooms are instant-death, that's an R1 tuning call (threshold/linger), not a J3 schema change — flag the observation for the Director, don't pre-solve it.*

**G. Telemetry — does RG2 need a per-room-density event, or is the config snapshot enough?** *(qa / RG2 call)*
The `run_started` `to_flat_dict()` snapshot tells RG2 *what density was configured*; the existing `hazard_awoke`/`hazard_caught` events tell it *what hazards did*. But neither directly reports *how many hazards spawned per room* (the J3 budget actually realised), which RG2 may want to confirm "density landed." Options: (1) rely on the config snapshot + an inferred count (cheap, no new signal); (2) add a one-shot `hazard_population_spawned(total, density_total)` emit at spawn (one new signal, pre-declared on `main` the M1.1 way). **Recommendation: option (1) for now** — the config snapshot + the spawn count are enough to segment, and the Breakdown's "no new EventBus signal unless needed" bias applies. *Defer to qa-playtest-coordinator (owns RG2); if they want the realised-count signal, pre-declare it on `main` before Wave 2.*

---

*Authored by `game-director-designer` as Phase-2 of M1.3's four-phase breakdown (`CLAUDE.md` → "Version breakdown authoring"). This doc sets the J3 contract; a Phase-3 fresh-eyes pass resolves §(c), the Director dispositions the flagged fun calls (B, C, and the F observation), then the Wave-2 build (general-purpose, J2+J3 merged spawn seam) builds against it. Update alongside `M1_As_Built.md`/`M1.3` decisions as J3 resolves.*

---

**Changelog**

- **2026-06-19 — Phase-2 spec authored.** Premise research (G4 §3 I1 "huge empty room" + §5 F3b "hazard per room"; the two real causes — hazards don't scale with room size in `_spawn_r1_hazards`, loot count is flat-per-piece in `JunkPlacer`/`depth_curve.tres`); defined the three densities (hazard / interest-loot / per-depth) and assigned J3 = per-room size-scaled hazard budget (+ optional off-by-default loot-per-area), J2 = per-depth distribution; **proposed the J2/J3 composition as budget→distribution with one owner for a merged spawn-seam rewrite and J1 pre-declaring both tasks' knobs (single-writer-safe)**; RNG-free deterministic placement; CFG coverage + TEL snapshot wiring; all-off reproduces the M1.0–M1.2 baseline; 7 Open Questions (A–G) with Director-review flags on B (hazards vs also loot), C (cell-area vs px-area scaling — the load-bearing fun call), and the F wake-cadence observation.
