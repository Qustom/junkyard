# S1 — BandProfile resource + BandPipeline orchestrator + `band_greybox.tres` — Expanded Design Spec

**Milestone:** M1.9 (Scalable Opposition + Band Systems) · **Workstream:** bands · **Wave:** 1 (parallel worktree, alongside S0)
**Task id:** S1 · **blockedBy:** none · **Blocks:** S5 (flavor stages), S3 (call-site integration), S7 (`band_two`)
**Assignee:** general-purpose (programmer)
**Author:** Phase-2 per-task design · **Status:** design (Open Questions pending Phase-3 fresh-eyes resolution)

> **What this doc is.** The Phase-2 design for S1 per `M1.9_Breakdown.md` §"Wave 1" — **band migration Phase A** of
> `design/explorations/exploration-20260625/procgen-bands/0-scalable-band-generation-system.md`. It expands the
> breakdown's S1 contract into a full schema, orchestrator shape, `.tres` authoring plan, parity-test plan, and
> acceptance criteria. It is **design only** — no code, no `.tres`, no branch ships with this doc. The programmer
> builds against it after Phase 3 resolves the Open Questions (§9).

---

## 0. Hard constraints (read first)

From the breakdown's scope guardrails + the exploration's Phase-A definition. The spec must not violate these,
and neither may the implementation built from it:

- **Byte-match is THE acceptance bar.** `Band.fingerprint()` through the orchestrated
  `BandPipeline.generate(profile, seed)` path must be **byte-identical** to the direct
  `BandGenerator.generate(seed, cfg, catalog)` path for every seed in `tests/test_bandgen_determinism.gd`'s
  matrix (`[12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]`, `test_bandgen_determinism.gd:36`). Every
  assertion of that test transfers to the orchestrated path as the regression bar.
- **File scope:** S1 touches **ONLY** `Game/systems/bandgen/` + `Game/data/bands/` + new test files
  (`Game/tests/test_band_pipeline_parity.gd/.tscn`). Nothing else.
- **No `main_game.gd` change.** S0 is the sole `main_game.gd` writer in Wave 1; the call-site switch at
  `main_game.gd:209` is **S3's** (Wave 3). In Phase A nothing in-game calls the pipeline — the parity test
  drives it directly. Consequently the **all-off `RunConfig` fingerprint `e943ac9c8bc1` cannot move** (no
  runtime path changes).
- **`band_generator.gd` is READ-ONLY for S1.** The pipeline *delegates to* `BandGenerator.generate()`
  verbatim — zero edits to the generator, the sealer, the grader, or the placer. Any edit risks the
  fingerprint; Phase A is "a wrapper + a descriptor Resource," nothing more (exploration §Migration Phase A:
  "the riskiest *correctness* step and the cheapest *code* step").
- **RNG discipline unchanged.** The backend reseeds exactly as today because `_generate_once` does the
  reseed itself (`RNG.seed_from(seed)` at `band_generator.gd:88`). The pipeline rolls **zero** RNG of its
  own — no draw before, between, or after stages. No new sub-streams in Phase A.
- **No EventBus edit.** S0 owns `event_bus.gd` in Wave 1. The pipeline path re-emits today's
  `band_generation_started` / `band_generated` / `band_generation_failed` **for free** (they're emitted
  inside `BandGenerator.generate()`, `band_generator.gd:48,71,76-78`); S1 adds no signal.
- **No save-schema change; run/meta boundary holds.** A `BandProfile` is meta *content* (a `.tres` on disk);
  which profile a dive uses is run-state routing (S8's problem). Nothing here persists.
- **Headless tests run as SCENES** (`godot --headless --path Game res://tests/test_band_pipeline_parity.tscn`),
  never `--script`, and never concurrently with another headless godot (import-lock deadlock).

---

## 1. Research — why this task, what exists, what changes

### 1.1 Why this task

M1.9's thesis is *adding content is data, not engineering*. On the band side, the wall is concrete: **a "band"
today is the global config, not a content resource.** There is exactly one `bandgen_config.tres` and one
`piece_catalog.tres`, loaded by path constants in `main_game.gd` (`main_game.gd:22-31`), and
`Game/data/bands/` is empty (a lone `.gitkeep`) — the folder the data-as-Resources architecture always meant
to fill. S7 must ship `band_two.tres` as *data* in Wave 4; that is impossible until a band **is** a datum.
S1 creates that datum (`BandProfile`), the thin orchestrator that consumes it (`BandPipeline`), and the
proof that the abstraction costs nothing: `band_greybox.tres`, today's baseline expressed as the first
profile, byte-identical through the new path.

Phase A deliberately ships **zero new generation behaviour**. Its entire value is (a) the schema every later
phase hangs off (S5's flavor stages read `profile.flavors`; S3's integration reads the whole profile; S7
authors a second one), and (b) the parity harness that makes each later phase's "control intact" claim
checkable.

### 1.2 What exists (as-built, verified 2026-07-02)

- **`Game/systems/bandgen/band_generator.gd` (520 lines).** `generate(seed, cfg, catalog, rc = null) -> Band`
  (`:46-47`) is a pure function: whole-band retry loop (`:60-79`) deriving per-attempt seeds via
  `_derive_seed(seed, attempt)` (boost-style integer hash-combine, `:352-362`); each attempt's
  `_generate_once` (`:84`) reseeds the autoload with `RNG.seed_from(seed)` as its **first** act (`:88`),
  then grows a socket-mated piece graph (weighted draw `:281`, flush alignment `:184`, overlap rejection via
  `band.fits`). `rc` hooks already live *inside* the generator: J4 corridor weights in `_build_weight_table`
  (`:250-276`), I1 room-count override via `rc.effective_room_count` (`:111-113`), R4 depth-scaled branching
  in `_select_frontier_index` (`:308-329`). Dormant seams: `_width_ok`/`_tags_ok` true-stubs (`:221-229`),
  `loop_back_count` unused.
- **`Game/systems/bandgen/band.gd`.** `Band` is a pure data container; `fingerprint()` (`:58-62`) is the
  ordered `piece_id@offset#mated` sha256 — the byte-identity currency of this whole task.
- **`Game/systems/bandgen/socket_sealer.gd`.** `seal_unused_sockets(band, cell_size)` (`:57`) is
  geometry-keyed, RNG-free, and **fingerprint-preserving by construction** (`:28-35`). Crucially it is
  invoked at **materialisation**, inside `main_game._materialise_band` (`main_game.gd:881`), *not* in the
  generation block — see §3's stage-order decision.
- **`Game/systems/depth/depth_grader.gd`.** `grade(band)` (`:26`) + `compute_return_distance(band)` (`:56`)
  — pure RNG-free BFS over FLOOR-cell 4-adjacency; annotates pieces, never reorders them (fingerprint-inert).
- **`Game/systems/depth/junk_placer.gd`** (the JunkPlacer — it lives under `systems/depth/`, not `bandgen/`).
  `plan(band, curve, catalog, ...)` (`:47`) draws from a **local** `RandomNumberGenerator` seeded
  `band.resolved_seed ⊕ _JUNK_SALT` (`:26`, `:139-143`) — the salt/sub-stream pattern S5's stages will copy.
  It is *population*, downstream of the band, called by `main_game.gd:236` with call-site knobs
  (`cell_size_override`, `loot_density_per_area`) — **not** a pipeline stage in Phase A.
- **The call site S1 must NOT touch** — `main_game.start_new_run()` (`main_game.gd:181`): resolve `run_cfg`
  (`:198`) → pick catalog by `rc.lvl_enabled` (baseline vs `piece_catalog_ext`, `:205-207`) →
  `generator.generate(seed, _cfg, catalog, run_cfg)` (`:209`) → `grader.grade(band)` +
  `compute_return_distance(band)` (`:213-215`) → junk plan (`:236`) → `_materialise_band` (`:240`, which
  seals at `:881`). This *is* the "today's exact order" the pipeline replicates.
- **Config/data surface.** `BandGenConfig` (`data/bandgen_config.gd`: `target_piece_count=12`,
  `branch_chance=0.0`, `max_place_attempts=16`, `loop_back_count=0`, `soft_floor_percent=80`,
  `max_band_attempts=8` — exactly the values in `data/bandgen_config.tres`). `PieceCatalog`
  (`data/piece_catalog.gd`): an **ordered** `Array[ZonePieceData]`, index 0 = entry piece, order is part of
  the determinism contract. `DepthCurve` at `systems/depth/depth_curve.tres`; `JunkCatalog` at
  `data/junk/junk_catalog.tres`. `main_game.gd:39` carries `const BAND_ID := &"near"` (telemetry stamp —
  see Open Question 4c).
- **The regression bar** — `Game/tests/test_bandgen_determinism.gd`, run as a scene
  (`test_bandgen_determinism.tscn`): same-seed byte-identity, diff-seed variation, connectivity,
  overlap-free, soft-floor size, retry-chain purity under RNG perturbation (`:105-115`), seal
  fingerprint-invariance + closed-perimeter (BUG3/BUG4 sweeps), and the R4 `(seed + config)` contract
  (all-off ≡ rc-null, `:240-246`). None of it is edited by S1; all of it must stay green.

### 1.3 What "band as data" changes vs today's single global config

Today the band's identity is smeared across `main_game.gd` constants: *which* config
(`BANDGEN_CONFIG_PATH`), *which* pieces (`PIECE_CATALOG_PATH` / `_EXT_PATH`), *which* loot curve/catalog
(`DEPTH_CURVE_PATH`, `JUNK_CATALOG_PATH`), *which* hazards (the `_new_hazard_descriptors` table at
`main_game.gd:357`). Making a second band under that model means a second set of constants and `if band ==
2` branches in the dive scene — exactly the "one ever-growing config blob" the exploration rejects.

After S1, a band is **one Resource** that aggregates those references: generation knobs
(`backend_config`), content pools (`piece_pool`, `junk_catalog`), the depth economy (`depth_curve`,
`band_depth`), the opposition handoff (`opposition_deck`), and the future stage lists (`principles`,
`flavors`). In Phase A the profile is *load-bearing for generation only* (backend_config + piece_pool feed
the pipeline); the population/opposition fields are authored-but-documentary until S3 rewires the call site
(Open Question 2). The payoff lands in S7: `band_two.tres` is a sibling file, not a code change.

### 1.4 The Dead-Cells-profile model (grounding)

The exploration's prior-art read (§"Prior art", researched + cited there): Dead Cells authors each biome as
**data** — a per-biome concept graph (length, labyrinthine-ness, entrance-to-exit distance) plus a **room
pool dedicated to that biome** — and one generator walks any biome's graph drawing from its pool
([Deepnight — Level Design of Dead Cells](https://deepnight.net/tutorial/the-level-design-of-dead-cells-a-hybrid-approach/)).
`BandProfile` is that model transposed: `backend_config`+`archetype` ≈ the concept graph,
`piece_pool` ≈ the biome room pool, `opposition_deck` ≈ the biome spawn rules. The staged-pipeline half
(backend → reshape → decorate → grade → populate) is the Minecraft/PLUME generation-vs-population split the
exploration also cites — and our `SocketSealer → DepthGrader → JunkPlacer` stack is *already* the population
half, which is why Phase A can be a pure wrapper. What we add that none of the cited generators have:
**seed-byte-reproducibility as a contract**, carried by the parity test.

---

## 2. `BandProfile` — the resource script

**File:** `Game/data/bands/band_profile.gd` (co-located with the `.tres` it types, mirroring
`data/junk/junk_item.gd` ↔ `data/junk/items/*.tres`; see Open Question 4a). Typed GDScript, `class_name
BandProfile`, sibling of `JunkItem`/`BandGenConfig`/(S0's) `OppositionDef`.

```gdscript
# data/bands/band_profile.gd  (illustrative — programmer owns final code)
class_name BandProfile
extends Resource
## BandProfile — a band-as-biome authored as data (M1.9 S1, band Phase A).
## One .tres per band. The BandPipeline consumes it; data/bands/ holds them.
## Phase-A binding: backend/backend_config/archetype/piece_pool drive generation;
## depth_curve/junk_catalog/opposition_deck/band_depth are authored now, consumed
## by S3 (call-site) / S3's EncounterBuilder; principles/flavors land in S5.

## Stable identity — telemetry/routing/save-safe key. NOT the filename.
@export var id: StringName = &""
@export var display_name: String = ""

# --- Which BACKEND builds the raw floor/occupancy -------------------------
## M1.9 wires "socket" ONLY (scope guardrail). "cave"/"scatter" are declared so
## the schema is stable across the exploration's Phase D, but the pipeline
## fail-louds on them (see §3).
@export_enum("socket", "cave", "scatter") var backend: String = "socket"
## The backend's own config Resource. For "socket": a BandGenConfig.
@export var backend_config: Resource = null

# --- Base ARCHETYPE (topology the backend grows toward) -------------------
## Phase A: declarative + validated, NOT dispatched — the socket backend's
## grow loop IS linear/branchy, keyed off backend_config.branch_chance and/or
## the RunConfig r4_* levers (see §3 + Open Question 1).
@export_enum("linear", "branchy", "hub", "grid", "lanes") var archetype: String = "linear"
@export var archetype_params: Dictionary = {}

# --- Content the backend draws from ---------------------------------------
@export var piece_pool: PieceCatalog = null   # the biome's dedicated pieces

# --- ORGANIZING PRINCIPLES / FLAVOR passes (ordered stage lists) -----------
## Empty in every Phase-A profile. S5 defines the stage Resource contract
## (apply/decorate(build, profile, stage_seed) + per-stage salt). Typed
## Array[Resource] until the stage base class exists (S5 may tighten).
@export var principles: Array[Resource] = []
@export var flavors: Array[Resource] = []

# --- Depth + population (documentary in Phase A — bound at S3) -------------
@export var depth_curve: DepthCurve = null
@export var junk_catalog: JunkCatalog = null
## Typed Array[Resource], NOT Array[OppositionDef]: OppositionDef is authored
## by S0 in a PARALLEL Wave-1 worktree — a class_name dependency here would
## break S1's branch in isolation. S3 (which depends on both) may retighten.
@export var opposition_deck: Array[Resource] = []

# --- Band-depth placement (bands-as-biomes ordering) -----------------------
@export var band_depth: int = 1   # dive tier; drives Instability I at S3


## Fail-loud self-check the pipeline runs before generating. Returns problem
## strings; empty = valid. Kept schema-local so tests/tools can reuse it.
func validate() -> PackedStringArray:
    var problems := PackedStringArray()
    if id == &"":
        problems.append("BandProfile: id is empty")
    if backend == "socket":
        if backend_config == null or not (backend_config is BandGenConfig):
            problems.append("BandProfile '%s': socket backend needs a BandGenConfig backend_config" % id)
        if piece_pool == null or piece_pool.pieces.is_empty():
            problems.append("BandProfile '%s': socket backend needs a non-empty piece_pool" % id)
        if archetype != "linear" and archetype != "branchy":
            problems.append("BandProfile '%s': archetype '%s' is not wired for the socket backend in M1.9" % [id, archetype])
    if band_depth < 1:
        problems.append("BandProfile '%s': band_depth must be >= 1" % id)
    return problems
```

Schema notes:

- **Every field from the exploration's illustrative schema is present** except `tileset` — S7 differentiates
  `band_two` visually by palette-retone/tinted piece pool, and the breakdown's S1 field list omits `tileset`;
  adding it is a one-line S7 follow-up if the retone wants it (recorded as Open Question 4d, not schema now).
- **`archetype_params`** ships as an empty `Dictionary` in both Phase-A profiles. It is the `spawn_ctx`
  pattern promoted to data; *nothing reads it in Phase A* (Open Question 1 covers where its keys eventually
  bind — the honest answer today is that the socket knobs live in `backend_config`).
- **Consistency guard (recommended, pending Phase 3):** `validate()` may additionally `push_warning` when
  `archetype == "linear"` but `backend_config.branch_chance > 0.0` (or vice versa) — declarative metadata
  that lies is worse than none. Warning, not error: RunConfig r4 levers can legitimately make a
  "linear"-declared profile branch during a sweep (§9 Q1/Q3).

---

## 3. `BandPipeline` — the orchestrator

**File:** `Game/systems/bandgen/band_pipeline.gd`, `class_name BandPipeline extends RefCounted` — sibling of
`BandGenerator`, mirroring its instantiate-and-call usage (`BandPipeline.new().generate(...)`).

**Phase-A shape:** the exploration's Stage 1–7 skeleton, with Stages 1+2 collapsed into a verbatim
delegation to today's `BandGenerator` (whose grow loop **is** the socket backend *and* the linear/branchy
archetype), Stages 3–5 vacant (S5), and Stages 6–7 replicated in **today's exact in-game order** — which
means: **grade + return-distance in the pipeline; the seal stays at materialisation.** As built, the
generation block (`main_game.gd:209-215`) never seals; `SocketSealer` runs inside `_materialise_band`
(`main_game.gd:881`). The pipeline copies the generation block, not the exploration's sketch (which drew
seal before grade — order-irrelevant to results since both passes are RNG-free and read pre-seal
`floor_cells`, but Phase A copies reality, not the sketch; see Open Question 6).

```gdscript
# systems/bandgen/band_pipeline.gd  (illustrative — programmer owns final code)
class_name BandPipeline
extends RefCounted
## BandPipeline — the profile-driven band orchestrator (M1.9 S1, Phase A).
##
## generate(profile, seed, rc) is a PURE FUNCTION of its inputs, same as the
## generator it wraps. Phase A adds NO generation behaviour: for a
## socket+linear/branchy+empty-stages profile it byte-matches the direct
## BandGenerator path (test_band_pipeline_parity is the proof; the
## test_bandgen_determinism assertions transfer wholesale).
##
## RNG DISCIPLINE: this class rolls ZERO randomness. The reseed
## (RNG.seed_from) happens inside BandGenerator._generate_once exactly as
## today; grading is RNG-free; there is no draw before/between/after stages.

func generate(profile: BandProfile, seed: int, rc: RunConfig = null) -> Band:
    # --- Fail-loud profile validation (never a silent fallback) ----------
    if profile == null:
        push_error("BandPipeline: null profile"); return null
    var problems := profile.validate()
    if not problems.is_empty():
        for p in problems: push_error(p)
        return null

    # --- Phase-A wiring guards -------------------------------------------
    if profile.backend != "socket":
        push_error("BandPipeline: backend '%s' is not wired in M1.9 (socket only — profile '%s')"
                % [profile.backend, profile.id])
        return null
    if not profile.principles.is_empty() or not profile.flavors.is_empty():
        # S5 lands the stage contract; until then a stage-bearing profile is
        # an authoring error, not something to silently skip (control safety).
        push_error("BandPipeline: profile '%s' declares principle/flavor stages before S5 wired them"
                % profile.id)
        return null

    # --- STAGES 1+2: backend + archetype = today's generator, verbatim ---
    # The socket grow loop IS the linear/branchy archetype: branch topology
    # is keyed off backend_config.branch_chance and the rc r4_* levers at
    # the exact same draw sites as today (band_generator.gd:308-329). Same
    # args, same retry loop, same _derive_seed chain, same RNG reseed.
    var cfg := profile.backend_config as BandGenConfig
    var catalog: Array[ZonePieceData] = profile.piece_pool.pieces
    var band := BandGenerator.new().generate(seed, cfg, catalog, rc)
    if band == null or band.pieces.is_empty():
        push_error("BandPipeline: generation produced no pieces (profile '%s', seed %d)"
                % [profile.id, seed])
        return band

    # --- STAGES 3-5: principles / flavors / connectivity guarantee -------
    # Vacant in Phase A (S5). The empty loops are NOT stubbed in — S5 adds
    # them with the per-stage sub-seed contract (seed ⊕ stage.salt).

    # --- STAGES 6-7: today's exact generation-block order ----------------
    # (main_game.gd:213-215). Grade + return distance here; the SEAL stays a
    # MATERIALISATION concern (main_game.gd:881) and is NOT invoked here —
    # fingerprint-neutral either way (socket_sealer.gd:28-35), but Phase A
    # replicates the as-built order, not the exploration's sketch.
    var grader := DepthGrader.new()
    grader.grade(band)
    grader.compute_return_distance(band)

    # Population (JunkPlacer / oppositions) stays DOWNSTREAM, unchanged —
    # the exploration's clean handoff seam. S3 rewires the consumer.
    return band
```

Design decisions embedded above (each with its Open Question where genuinely open):

1. **`rc: RunConfig = null` pass-through (third arg).** The as-built generator takes `rc` and reads it at
   three interior hook sites (room count, corridor weights, r4 branching). Dropping it from the pipeline
   would strand every M1.1–M1.8 lever and preset the moment S3 switches the call site. So the pipeline's
   determinism key is `(profile + seed + rc)` — the profile is the band's *content identity*, `rc` remains
   the *per-run experiment overlay*, exactly as today. Precedence needs no new rule because no field
   overlaps: `rc` overrides flow through the generator's existing interior hooks untouched. (Open Question 3
   covers the one genuine overlap-in-waiting: the `lvl_enabled` ext-catalog swap, which today lives at the
   call site, `main_game.gd:205-207`.)
2. **Grading inside the pipeline.** `grade`/`compute_return_distance` are deterministic, RNG-free, and
   fingerprint-inert (they annotate pieces, never reorder). Including them makes `BandPipeline.generate`
   return a *ready* band matching what `start_new_run` builds by :215, so S3's switch is a genuine 3-line
   collapse. The parity test asserts grading parity piecewise, not just the fingerprint (§5).
3. **Fail-loud, never fail-soft.** Unwired backend, early-declared stages, invalid profile → `push_error` +
   `null`, never a silent fallback to defaults — the M1.9 coverage-discipline ethos (fail loud on drift)
   applied to profiles (§9 Q7 asks Phase 3 to confirm error-vs-assert style).
4. **No new EventBus surface.** `band_generation_started/generated/failed` ride through from inside the
   generator. A future `band_pipeline_*`/profile-tagged signal is S0/S8 territory (S0 owns `event_bus.gd`).

---

## 4. `data/bands/band_greybox.tres` — today's baseline as data

The first content of `data/bands/` (currently only `.gitkeep`), and the **band-side permanent control**
(breakdown cross-cutting contracts): with the socket backend, linear archetype, and empty stage lists, this
profile reproduces today's band **byte-for-byte** — mirroring the all-off `RunConfig` discipline.

Authored in the inspector against `band_profile.gd`. Exact values (illustrative `.tres` text; ext-resource
ids/`load_steps`/uids are whatever the editor serialises):

```
[gd_resource type="Resource" script_class="BandProfile" load_steps=6 format=3]

[ext_resource type="Script" path="res://data/bands/band_profile.gd" id="1"]
[ext_resource type="Resource" path="res://data/bandgen_config.tres" id="2"]
[ext_resource type="Resource" path="res://data/piece_catalog.tres" id="3"]
[ext_resource type="Resource" path="res://systems/depth/depth_curve.tres" id="4"]
[ext_resource type="Resource" path="res://data/junk/junk_catalog.tres" id="5"]

[resource]
script = ExtResource("1")
id = &"band_greybox"
display_name = "The Near Yard (greybox)"
backend = "socket"
backend_config = ExtResource("2")     ; target 12 · branch 0.0 · place 16 · loop 0 · floor 80% · attempts 8
archetype = "linear"
archetype_params = {}
piece_pool = ExtResource("3")         ; the BASELINE catalog (never piece_catalog_ext — see OQ3)
principles = []
flavors = []
depth_curve = ExtResource("4")
junk_catalog = ExtResource("5")
opposition_deck = []
band_depth = 1
```

Authoring rules:

- **Reference, never copy.** `backend_config` points at the *live* `res://data/bandgen_config.tres` (same
  object identity `main_game` loads at `:158`) — not a duplicated sub-resource. If the Director retunes the
  baseline config, both paths move together and parity can't silently fork. Same for the catalog/curve/junk
  references (`main_game.gd:22,30,31`).
- **`piece_pool` = the baseline `piece_catalog.tres`,** not `piece_catalog_ext.tres` — the ext catalog is
  the `lvl_enabled` *config-dependent* swap (I1, `main_game.gd:205-207`) and stays a RunConfig concern until
  Open Question 3 is resolved at S3.
- **`opposition_deck` = `[]`** even though S0 is authoring the four legacy `OppositionDef.tres` this same
  wave: band 1's hazard cohort is still driven by the legacy `RunConfig` knob groups through S3 (breakdown:
  "Legacy R1/K5 knobs keep driving the default populator"), so an empty deck is the truthful Phase-A value.
  S3/S7 revisit whether `band_greybox` gains a deck or stays legacy-driven through the gate.
- **`display_name`** is a placeholder tone-neutral string (the fiction pitch is S7's Director item);
  `id = &"band_greybox"` matches the breakdown's canonical name everywhere (tests, S8 routing, telemetry —
  but see Open Question 4c on the existing `BAND_ID := &"near"` stamp).

---

## 5. `test_band_pipeline_parity` — the acceptance harness

**Files:** `Game/tests/test_band_pipeline_parity.gd` + `test_band_pipeline_parity.tscn` (root `Node` with
the script — clone of `test_bandgen_determinism.tscn`'s shape). **Run as a SCENE:**

```bash
godot --headless --path Game res://tests/test_band_pipeline_parity.tscn   # exit 0 = green
```

It drives the pipeline **directly** (no `main_game`, which S1 may not touch) and proves the orchestrated
path is a byte-perfect wrapper. Structure (illustrative):

```gdscript
extends Node
## S1 acceptance — BandPipeline parity vs direct BandGenerator (band Phase A).
## Same seed matrix as test_bandgen_determinism (the assertions transfer).

const PROFILE_PATH := "res://data/bands/band_greybox.tres"
const CONFIG_PATH := "res://data/bandgen_config.tres"
const CATALOG_PATH := "res://data/piece_catalog.tres"
const SEEDS := [12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]  # = determinism matrix

func _ready() -> void:
    get_tree().quit(_run())

func _run() -> int:
    var failures: Array[String] = []

    # --- P0. Profile-load contract: band_greybox is exactly the baseline-as-data
    var profile := load(PROFILE_PATH) as BandProfile
    #   assert: profile != null; validate() empty; id == &"band_greybox";
    #   backend == "socket"; archetype == "linear"; archetype_params == {};
    #   principles/flavors/opposition_deck all empty; band_depth == 1;
    #   backend_config IS the live bandgen_config.tres object (load(CONFIG_PATH) ==
    #   profile.backend_config — same resource cache identity, so the two paths
    #   cannot fork on a duplicated config); piece_pool IS piece_catalog.tres.

    var gen := BandGenerator.new()
    var pipe := BandPipeline.new()
    var cfg := load(CONFIG_PATH) as BandGenConfig
    var catalog: Array[ZonePieceData] = (load(CATALOG_PATH) as PieceCatalog).pieces
    var grader := DepthGrader.new()

    for seed in SEEDS:
        var direct := gen.generate(seed, cfg, catalog)          # today's path
        var piped := pipe.generate(profile, seed)               # orchestrated path

        # --- P1. THE BAR: byte-identical fingerprint, per seed
        if direct.fingerprint() != piped.fingerprint():
            failures.append("seed %d: pipeline fp != direct fp (%s vs %s)" % [...])

        # --- P2. Pipeline path run-to-run deterministic (same seed twice)
        var piped2 := pipe.generate(profile, seed)
        #   piped.fingerprint() == piped2.fingerprint()

        # --- P3. Grading parity: the pipeline's built-in grade matches grading
        #     the direct band by hand — piecewise, not just the hash.
        grader.grade(direct); grader.compute_return_distance(direct)
        #   per index i: depth_index, depth_norm, dist_to_gate identical;
        #   band.max_depth identical; entry/deepest piece ids identical.

        # --- P4. Structural invariants transfer (determinism-test assertions 3/4):
        #   gen.is_band_connected(piped); no overlapping footprint cells;
        #   piped.pieces.size() >= soft floor.
        _free_band(direct); _free_band(piped); _free_band(piped2)

    # --- P5. rc pass-through parity: a non-neutral RunConfig flows through the
    #     pipeline to the SAME interior hooks. Reuse the determinism test's
    #     r4-on shape (r4_enabled, per_depth 0.06, cap 8):
    #   for seed in SEEDS: pipe.generate(profile, seed, r4_on).fingerprint()
    #       == gen.generate(seed, cfg, catalog, r4_on).fingerprint()
    #   plus one lvl room-count override config (effective_room_count hook) the
    #   same way — proving profile and RunConfig sweeps COEXIST byte-exactly.

    # --- P6. Purity under RNG perturbation through the pipeline (mirror of
    #     determinism assertion 5): pipe.generate(profile, 424242) →
    #     RNG.seed_from(987654321); RNG.randi() → pipe.generate(profile, 424242)
    #     → identical fingerprints.

    # --- P7. Fail-loud guards: pipe.generate(null, 1) == null; a synthetic
    #     profile with backend = "cave" returns null with a push_error (captured
    #     count or just documented manual check); a synthetic profile with a
    #     non-empty flavors array returns null. (Built in-code, no extra .tres.)

    # report + return 0/1, freeing piece instances via _free_band as
    # test_bandgen_determinism.gd:420-425 does.
```

Notes:

- **P1 is the definition-of-done bar** ("byte-matches ... across the `test_bandgen_determinism` seed
  matrix"). P2–P6 make the determinism suite's own guarantees (connectivity, overlap-free, retry purity,
  `(seed+config)` stability) hold *through the pipeline*, so later phases regress loudly here rather than
  only at the direct-path test.
- The existing `test_bandgen_determinism.tscn` is **not edited** — it keeps guarding the direct path; the
  new scene guards the wrapper. Run them **sequentially**, never concurrently (headless import-lock).
- P7 keeps the fail-loud contract honest without authoring throwaway `.tres` fixtures — synthetic profiles
  are built in code (`BandProfile.new()` + field pokes).

---

## 6. Files to create / touch

**Create (S1-owned):**
- `Game/data/bands/band_profile.gd` — the `BandProfile` resource script (§2).
- `Game/data/bands/band_greybox.tres` — the baseline profile (§4).
- `Game/systems/bandgen/band_pipeline.gd` — the orchestrator (§3).
- `Game/tests/test_band_pipeline_parity.gd` + `Game/tests/test_band_pipeline_parity.tscn` — the harness (§5).
- (Godot will mint `.uid` files for the new scripts on import — commit them, per repo convention.)

**Must NOT touch (contract):**
- `Game/scenes/game/main_game.gd` — S0's exclusive file this wave; the `:209` switch is S3's.
- `Game/systems/event_bus.gd` — S0 pre-declares all M1.9 signals.
- `Game/systems/bandgen/band_generator.gd`, `band.gd`, `open_socket.gd`, `placed_piece.gd`,
  `socket_sealer.gd` — read-only; the pipeline delegates, never modifies.
- `Game/systems/depth/depth_grader.gd`, `junk_placer.gd`, `depth_curve.gd` — read-only.
- `Game/data/run_config/run_config.gd`, `data/bandgen_config.*`, `data/piece_catalog.tres` — read-only.
- `Game/tests/test_bandgen_determinism.gd/.tscn` — the regression bar is never edited to pass.

**Work-product contract:** branch `general-purpose/S1` (worktree isolation; verify branch topology before
merge per the qa git-switch-leak memory); one worklog `worklogs/2026-MM-DD-S1-general-purpose.md` naming the
commit SHA(s) + a Design deviations section; commit message prefixed `M1.9 S1:`.

---

## 7. Definition of done (restated + concrete)

1. **Parity:** `godot --headless --path Game res://tests/test_band_pipeline_parity.tscn` exits 0 — P1
   byte-match across all 9 seeds, plus P2–P7 green.
2. **Regression bar:** `godot --headless --path Game res://tests/test_bandgen_determinism.tscn` exits 0,
   with the file untouched (`git diff --stat` shows no bandgen-test edit). Other bandgen-adjacent suites
   (`test_band_depth.tscn`, `tests/procgen/*`) stay green.
3. **All-off fingerprint unmoved:** the RG-style verify run still reports `e943ac9c8bc1` — trivially, since
   no runtime call site changed; asserted anyway (verify-before-reporting-done).
4. **Compiles + smoke:** `godot --headless --path Game --import` clean;
   `godot --headless --path Game --script res://tools/ci_smoke_test.gd` green.
5. **Scope audit:** the diff touches only `systems/bandgen/`, `data/bands/`, `tests/test_band_pipeline_parity.*`
   (+ `.uid` files).
6. **Profile-load contract:** `band_greybox.tres` loads headlessly with every field per §4 (P0).
7. **Worklog + commit SHA + deviations section** exist; task mirrored Done on `STATUS.md` + the board.

---

## 8. What S1 explicitly does NOT do (deferred, by design)

- No call-site change (`S3`), no flavor/principle stage classes or `BandBuild` mutable-state object (`S5` —
  Phase A has no reshaping stage, so `Band` itself remains the pipeline's working type and `to_band()`
  conversion machinery is deferred until a stage actually needs pre-Band mutation), no connectivity-carve
  Stage 5 (`S5`), no second profile (`S7`), no portal/routing/telemetry stamp (`S8`), no CaveBackend /
  ScatterBackend / WFC / grammar (post-M1.9 gate, per the exploration's own recommendation), no
  formal backend interface/class hierarchy (one wired backend does not justify an abstraction — extract the
  `build_layout` interface when the second backend is actually built).

---

## 9. Open Questions (for Phase-3 fresh-eyes resolution)

> Each stated with trade-offs + a recommendation. Genuinely-Director items are flagged. A
> **Resolved Decisions** section is appended below by the Phase-3 resolver / Director ratification before
> the build wave dispatches.

**Q1 — Where does the archetype seam sit in Phase A?** The exploration's pipeline sketch has a distinct
Stage-2 `_archetype_for(profile.archetype).shape(...)`, but its own §"Proposed architecture" concedes the
truth: for the socket backend, `_generate_once` **is** `build_layout` *and* the linear/branchy `shape` —
topology is an emergent property of the grow loop's branch roll (`branch_chance` at
`band_generator.gd:310`, r4 levers at `:311-319`), not a separable pass. Refactoring the generator into
backend+archetype objects now would touch the RNG draw sites and gamble the fingerprint for zero Phase-A
behaviour. Options: **(a)** `archetype` is declarative-and-validated metadata; the *binding* knobs live in
`backend_config` (a branchy profile = a `BandGenConfig` with `branch_chance > 0`, which is exactly how S7
will author `band_two`'s "branchy at distinct params"); pipeline/`validate()` warns on
metadata-vs-config disagreement. **(b)** `archetype_params` actively *overrides* `backend_config` fields in
the pipeline (e.g. `{"branch_chance": 0.15}` applied to a duplicated config before generating) — makes the
archetype field load-bearing immediately, but introduces a config-mutation path two sources of truth wide,
right in the parity-critical wave. **(c)** Do the backend/archetype object split now — rejected above.
**Recommendation: (a)** for Phase A; revisit the dispatch seam at the exploration's Phase C when `hub`/`grid`
archetypes force a real `shape()` pass. S7 then decides between "distinct `BandGenConfig.tres`" and
activating (b) — flag forward to S7's design.

**Q2 — Do `depth_curve`/`junk_catalog` bind in Phase A, or stay documentary until S3?** The pipeline could
run `JunkPlacer.plan` as a stage (the exploration's Stage-8/population instinct), but as built the plan is a
*call-site* concern with call-site knobs — `cell_size_override` derived from `rc.effective_cell_size_px`
and `lvl_loot_density_per_area` (`main_game.gd:224-236`) — and its output feeds `JunkSpawner`, which is
scene-side. Pulling it into the pipeline in Wave 1 would duplicate that knob plumbing without a consumer.
**Recommendation: documentary-but-authored** — the fields point at the real live resources (§4) so the
profile is complete as data and S7 can author `band_two`'s curve/catalog, but nothing reads them until S3
rewires `start_new_run` to pull `_depth_curve`/`_junk_catalog` (and `piece_pool`) **from the active profile
instead of `main_game`'s path constants** (`main_game.gd:22-31` retire then). The parity test asserts the
references are the same cached resources main_game loads, so "documentary" cannot silently drift.
`opposition_deck`/`band_depth` likewise bind at S3 (EncounterBuilder budget + deck).

**Q3 — RunConfig interaction: how does the profile coexist with `rc` sweeps?** Resolved in the design as a
pass-through third arg (`generate(profile, seed, rc = null)`, §3 decision 1) — the generator's interior
hooks (room-count override, corridor weights, r4 branching) keep working untouched, and P5 proves it
byte-exactly. The **residual sub-question** is the I1 catalog swap: today `rc.lvl_enabled` swaps
`piece_catalog` → `piece_catalog_ext` *at the call site* (`main_game.gd:205-207`), but the pipeline reads
`profile.piece_pool`. Options for S3: **(a)** pipeline consults `rc.lvl_enabled` and an optional new
`piece_pool_ext: PieceCatalog` profile field (the swap becomes profile data — faithful to as-built I1
semantics, +1 schema field); **(b)** the swap stays call-site: S3's `main_game` stages a different
*profile* (a `band_greybox_lvl.tres` variant) when `lvl_enabled` — no schema change but profile
proliferation for what is an experiment lever; **(c)** drop the swap into `rc → archetype_params`-style
overrides — over-general. **Recommendation: (a), added at S3, not now** (S1 keeps the breakdown's exact
field list; the parity test doesn't exercise `lvl_enabled` catalog swapping since the direct path in the
test also uses the baseline catalog). Flag prominently in S3's design so preset parity (`lvl_enabled=true`
in `make_default_play_preset`) isn't broken by the switch.

**Q4 — Resource-load location + identity conventions.** Four small calls, none behaviour-affecting, all
worth pinning: **(a) Where does `band_profile.gd` live?** `data/bands/` (recommended — mirrors
`data/junk/junk_item.gd`, `data/shop/shop_item.gd`: the schema script sits with its content; also keeps S1
inside its file-scope constraint) vs `systems/bandgen/` (with its consumer, like `band.gd`). **(b) How are
profiles discovered/loaded?** Explicit `const` paths at the consumer (recommended for M1.9 — matches every
existing loader in `main_game.gd:22-36`; deterministic; S8 needs exactly two) vs a directory scan of
`data/bands/` (rejected: `PieceCatalog`'s own docstring warns filesystem scans are unordered) vs a
`BandCatalog.tres` registry resource (right answer *eventually* — defer until >2 bands or an unlock system
needs enumeration; note it in S8's design). **(c) Profile `id` vs the telemetry band stamp:**
`main_game.gd:39` has `const BAND_ID := &"near"` while the profile is `&"band_greybox"`. S8 stamps
`band_id` on `run_started` — recommend the stamp become **`profile.id`** and `&"near"` retire at S3/S8 (one
id space, owned by the profile); flag to S8's design + SG2's analysis so the telemetry cohort key is agreed
before data lands. *Mild Director-adjacent naming call — surface at ratification.* **(d)** `tileset` field
omitted from the Phase-A schema (§2) — confirm S7 is content with palette-retone via piece pool, or add the
field then.

**Q5 — `opposition_deck` element typing.** `Array[Resource]` (recommended, §2) avoids a compile-time
`class_name OppositionDef` dependency on S0's parallel Wave-1 branch — S1 must import/parse green in an
isolated worktree. Cost: no inspector type-filtering until retightened. Retighten to
`Array[OppositionDef]` at S3 (both S0+S1 merged; S3 already depends on both)? **Recommendation: yes,
retighten at S3** — a one-line schema edit; `.tres` files don't re-serialise on an export-type narrowing.

**Q6 — Should the pipeline ever own the seal, and where does S5's connectivity stage sit relative to it?**
Phase A keeps seal at materialisation (§3 — as-built order). But the exploration's Stage-5 connectivity
guarantee (S5) must run *after* every reshaping flavor and *before* the player walks the band, and
`WearDecay` will interact with sealed geometry. Options when S5 lands: **(a)** pipeline gains seal as its
Stage 6 (exploration order) and `_materialise_band`'s call becomes an idempotent second seal until S3
removes it (`seal_unused_sockets` is idempotent by construction, `socket_sealer.gd:52-56`); **(b)** seal
stays materialisation-side forever and flavor stages are constrained to pre-seal cell-space mutation.
**Recommendation: defer to S5's design with a lean toward (a)** — fingerprint-neutral either way, so this
is an ordering-hygiene call, not a determinism one. S1 merely must not foreclose it (it doesn't: the
pipeline body has an obvious slot).

**Q7 — Error-handling style: `push_error + null` vs `assert`.** `assert` strips in release builds and would
turn an authoring error into undefined behaviour on itch; `push_error + null return` keeps headless tests
able to assert failure paths (P7) and matches `main_game`'s own `push_error` style (`:162,211`).
**Recommendation: `push_error + null`** for content/authoring errors; reserve `assert` for programmer
invariants (e.g. `catalog` uniform cell size already asserts inside the generator). Phase 3 confirms.

**Q8 — Does `band_greybox` stay deck-less through M1.9?** §4 authors `opposition_deck = []` because legacy
knobs drive band 1's cohort through the gate. But S6a ships Charger "enabled in the new band's deck (+
optionally the preset — Director call at the gate)". If the Director wants new hazards in band 1 *via the
deck* rather than via preset knobs, `band_greybox` gains a deck at S7/S8 time. **Recommendation: keep `[]`
now; band-2-exclusive per breakdown open-question 5's recommendation.** *Vision/fun — Director ratifies at
the breakdown level; S1 just needs the field authored empty.*

---

*Spec authored for M1.9 S1 (band migration Phase A). Design-only — no code, no `.tres`, no branch. The
programmer builds against this after Phase 3 folds a **Resolved Decisions** section in below. Deviations
from the committed design go to `design/DESIGN_DEVIATIONS.md` for the Wave-1 close-out sweep.*
