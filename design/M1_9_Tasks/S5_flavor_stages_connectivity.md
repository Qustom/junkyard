# S5 — Band Flavor Stages: `SetPieceInject` + `WearDecay` + Stage-5 Connectivity Guarantee — Expanded Design Spec

**Milestone:** M1.9 (Scalable Opposition + Band Systems) · **Workstream:** band migration Phase B · **Wave:** 2 (parallel worktree, ∥ S2)
**Task id:** S5 · **blockedBy:** S1 (BandProfile + BandPipeline + `band_greybox.tres`)
**Assignees:** general-purpose (implementation + tests) · **Author:** game-director-designer (Phase-2 design fan-out)
**Status:** design **locked** (Phase 3 resolved — §10 folds in the fresh-eyes resolution + the orchestrator's cross-contract adjudications; Q4's breach-led-decay headline + Q5's breach-legibility watch-item are surfaced to the Director at wave close-out / SG2, non-blocking for the Wave-2 build)

> **What this doc is.** The per-task design doc for S5 per `M1.9_Breakdown.md` §Wave 2: the two cheapest flavor stages from the band exploration — `SetPieceInject` ([e4](../explorations/exploration-20260625/procgen-bands/e4-set-piece-injection.md)) and `WearDecay` ([e5](../explorations/exploration-20260625/procgen-bands/e5-wear-decay-state.md)) — plus the explicit **connectivity-guarantee stage** the architecture doc promotes to a pipeline invariant ([0-scalable-band-generation-system.md](../explorations/exploration-20260625/procgen-bands/0-scalable-band-generation-system.md) §"Determinism & connectivity contracts"). It is **design only** — no game code, no `.tres` ships from this doc. The programmer builds against it in Wave 2. §9 lists the open questions with recommendations; nothing in the body is Director-ratified yet.

---

## 0. Hard constraints (read first)

From the breakdown's scope guardrails + cross-cutting contracts. The design must not violate these, and neither may the implementation:

- **Both stages OFF by default.** A profile with empty `flavors` runs *zero* flavor code — the `band_greybox` control profile's `fingerprint()` stays **byte-identical** through the pipeline (the band-side permanent control, mirror of the all-off `RunConfig` fp `e943ac9c8bc1`). Guard the whole flavor block behind `not profile.flavors.is_empty()` so the control path is literally the S1 parity path.
- **Per-stage sub-seeds off the layout stream.** Every stochastic flavor decision draws from a **local `RandomNumberGenerator`** seeded from `band.resolved_seed` hash-combined with a per-stage salt — the exact `JunkPlacer._JUNK_SALT` pattern (`junk_placer.gd:26,139-143`). **No stage ever touches the `RNG` autoload** — the grow loop's draw sequence is sacred.
- **Connectivity invariant runs after EVERY reshaping pass.** The guarantee stage executes after each flavor that adds pieces or mutates floor, not once at the end.
- **No `main_game.gd` change** (S0 owned it Wave 1; S3 owns it Wave 3 — S5 never). S5's stages are proven by tests that drive `BandPipeline` directly, exactly like S1's parity test. No `event_bus.gd` change either (S0 pre-declared all M1.9 signals in Wave 1; S5 adds none — failures surface via `push_error` + test assertions).
- **Order-stable iteration everywhere.** Candidate lists (doorways, sockets, wall pairs, entries) are explicitly sorted before any RNG indexing — never raw Dictionary/append order. This is the CA-backend gotcha from the architecture doc applied preemptively.
- **Socket backend only.** No `BandBuild` refactor, no `_generate_once` surgery, no second backend. The stages operate on the as-built `Band` (see §1.3 / §9 Q1).
- **File discipline (Wave 2):** S5 owns `systems/bandgen/` (incl. S1's new pipeline file), `data/bands/` flavor-config scripts, and its own tests. S2 owns entity/component files. Disjoint by construction.

---

## 1. Research — premise, sources, and the as-built reality

### 1.1 What e4 explored (SetPieceInject)

Hand-authored prefab rooms (vault / trap gauntlet / boss arena) injected into procedural space — the "cheapest, highest-leverage anti-sameness win" (Spelunky special rooms, Isaac fixed rooms, Diablo pre-set tiles). Key mechanisms proposed:
- A set-piece is **just an authored zone piece** (B1 format: `PackedScene`, `Geometry` TileMapLayer, tagged `Marker2D` sockets) that happens to be hand-designed — it rides `_weighted_pick_index` / `_alignment_offset` / `band.fits` / `SocketSealer` with **no new placement engine**.
- An **injection policy** on top of raw selection: depth gating (`min_depth_index` / `depth_norm`, mirroring `JunkPlacer`'s depth keying), frequency caps (`max_per_band`), dedupe (`unique`).
- e4's open flags: authoring budget (Director/scope); appearance rate before rote (Director/fun, gate-tunable); **socket-compatibility guarantee** (recommend: enforce ≥1 canonical 2-cell socket as authoring lint + graceful "skip and log" on injection failure); **reserved-slot vs swap** (e4 leaned *swap* — but see §1.3, the as-built reality flips this); guaranteed-vs-probabilistic flagship pacing (Director).

### 1.2 What e5 explored (WearDecay)

A decay modifier that takes the *same* layout and decides, per seed, how ruined it is — pure post-pass over geometry/connectivity, no new pieces, no new archetype. Key mechanisms proposed:
- **Block:** convert a mated-doorway FLOOR cell to WALL via the sealer's `_place_wall_cap` mechanism — closes a connection, forces detours under the dive clock.
- **Breach:** convert perimeter WALL between two pieces' floor sets to FLOOR — opens a shortcut the generator never authored.
- **Connectivity non-negotiable:** after each block, re-run the flood-fill connectivity check; **reject any block that disconnects**; breaches can only help. Runs at materialisation on a `resolved_seed ⊕ salt` sub-stream (the JunkPlacer pattern, cited by line number in e5).
- Knobs: `decay_level` 0→1, `block_vs_breach_ratio`, `rubble_density` (props), `destructible_in_run` (a new player verb).
- e5's open flags: reject-on-disconnect can make high `decay_level` *feel* capped (recommend ship-first, revisit at gate); destructible rubble as a verb (Director — new verb, deferred); breach legibility without a tutorialized tell (Director/art); decay↔Exposure coupling (vision — Exposure doesn't exist yet in M1).

### 1.3 The stage contract, and where flavors actually hook (as-built)

The architecture doc's pipeline is `backend → archetype → principles → flavors → connectivity → seal → grade`, with each stage a small **`RefCounted`** exposing one method — `apply(build, profile, stage_seed)` — mutating a shared `BandBuild`. **But M1.9 Phase A (S1) deliberately did not build `BandBuild`:** S1's `BandPipeline.generate(profile, seed)` *wraps* `BandGenerator.generate(seed, cfg, catalog, rc) -> Band` unchanged, because refactoring `_generate_once` is exactly the churn Phase A avoids. So in M1.9 there is no pre-Band build state a flavor could hook — **the `Band` is the build state**. It carries everything the stages need:

- `band.pieces: Array[PlacedPiece]` in placement order (the fingerprint basis), each with band-global `footprint_cells` + `floor_cells` + a live `instance` whose `Geometry` TileMapLayer is the tile-write surface (`socket_sealer.gd:_place_wall_cap` is the proven write pattern; FLOOR = source 0 atlas `(0,0)`, WALL = atlas `(1,0)` with collision — `band_generator.gd:382-385`, `socket_sealer.gd:45-46`).
- `band.occupied` (the O(1) overlap set) + `band.open_sockets` (the retained unconsumed frontier — "retained … so a later pass has everything it needs", `band.gd:26-29`). **This retained frontier is the set-piece attachment surface.**
- `band.resolved_seed` (post-retry, what `JunkPlacer` keys off) and `band.entry_piece` / `deepest_piece`.

**Therefore: flavors run on the `Band`, post-`BandGenerator.generate`, pre-seal/pre-final-grade, inside `BandPipeline.generate`.** The `apply(band, profile, stage_seed)` signature keeps the breakdown's contract shape with `band` in the `build` slot. When Phase D (M2+) introduces a second backend and a real `BandBuild`, the stages port by swapping the first parameter — their internals already speak only floor-cell/socket geometry. (§9 Q1 records this as the coordination point with S1's in-flight design.)

### 1.4 Which stage moves `fingerprint()` — the as-built answer

`Band.fingerprint()` is the sha256 of the ordered `piece_id@offset#mated` list (`band.gd:58-62`) — **it hashes the piece list only, not floor cells**. So, precisely:

| Stage | Piece list | Floor/wall cells | `fingerprint()` | Classification |
|---|---|---|---|---|
| `SetPieceInject` | **appends** pieces | adds their cells | **moves** (deterministically) | **Layout-affecting** under the `(seed + config)` contract — like R4/J4: a non-empty flavor config legitimately moves the fp; same seed+profile always reproduces the same fp. Uses its own sub-stream (§0), so the *underlying* spine draw sequence is untouched — the control layout is a strict prefix of the flavored one. |
| `WearDecay` | untouched | **mutates** (block/breach) | **does NOT move** | Off-fingerprint **but still layout-touching**: it changes the walkable graph without changing the piece list. This is the sharpest as-built finding — the existing fp is blind to decay, so (a) WearDecay's determinism needs a supplementary **floor fingerprint** (§6), and (b) connectivity MUST re-verify after it regardless of the fp reading "unchanged". |
| `ConnectivityGuarantee` | untouched (ASSERT) / reverts journal (CARVE) | restore-only | never moves it on a healthy seed | RNG-free, geometry-keyed — the `SocketSealer` pattern. |

### 1.5 Exactly where they run relative to seal/grade

Two as-built facts force the order. (1) e4's depth gating needs `depth_norm`, which only `DepthGrader.grade()` assigns — but the architecture doc runs flavors *before* grade. Resolution: `DepthGrader` is a pure, RNG-free, idempotent graph function (`depth_grader.gd:4-10`), so the pipeline runs a cheap **provisional grade** before the flavor loop and re-grades after any piece-list mutation; the pipeline's existing tail grade (S1's `grade` + `compute_return_distance`) remains the canonical one — it is equivalent to a post-seal grade because the seal never touches `floor_cells` (§10 C1). (2) `SocketSealer` is geometry-keyed off the band-global FLOOR set built from `floor_cells` (`socket_sealer.gd:57-84`), so it must run **after** all floor mutation — it then auto-seals a set-piece's unused sockets and caps around blocked doorways for free, with zero new seal code. **As-built this already holds without S5 moving anything: S1's pipeline does NOT invoke the sealer** ("the SEAL stays a MATERIALISATION concern (main_game.gd:881) and is NOT invoked here" — S1 §pipeline pseudocode), and materialisation is downstream of `BandPipeline.generate`, hence downstream of every flavor stage. See §10 correction **C1**.

```
BandPipeline.generate(profile, seed):
    band = BandGenerator.generate(seed, cfg, catalog, rc)      # unchanged (S1 wrapper)
    if not profile.flavors.is_empty():                          # control path skips ALL of this
        DepthGrader.grade(band)                                 # provisional (RNG-free, idempotent)
        for i, fcfg in profile.flavors (array order):
            stage = _stage_for(fcfg)                            # config-type -> RefCounted stage
            stage.apply(band, profile, _stage_seed(band.resolved_seed, fcfg.salt, i))
            if stage.MUTATES_PIECES:  DepthGrader.grade(band)   # re-grade for later gates
            ConnectivityGuarantee: ASSERT after pure-socket stages,
                                   CARVE (journal revert) after floor-reshaping ones   # §5
    DepthGrader.grade(band); DepthGrader.compute_return_distance(band)   # canonical grade (S1's existing tail)
    return band                                                 # JunkPlacer/opposition downstream, unchanged
    # NOTE (§10 C1): SocketSealer.seal_unused_sockets(band) is NOT called here — per S1
    # as-built, the seal stays a MATERIALISATION concern (main_game.gd:881), which runs
    # downstream of this whole function and therefore still after all floor mutation.
    # The seal is grade-neutral (floor_cells are captured pre-seal, socket_sealer.gd:30-31),
    # so canonical-grade-before-seal is equivalent to the grade-after-seal sketched in Phase 2.
```

`JunkPlacer` runs downstream off the graded band and iterates `band.pieces` — **an injected set-piece gets depth-appropriate loot automatically**, no S5 work. (Its *curated* loot/opposition interior is deferred — §1.6.)

### 1.6 The deferred opposition tie-in (client (c))

The opposition exploration v2 defines client (c): curated set-piece spawns via `svc.spawn(def, cell, ctx)` with the `ignore_room_cap` ctx escape (reserved in the breakdown's cross-cutting contracts). **Deferred beyond M1.9**: S5 set-pieces are geometry + auto-loot only. The data shape (§3.1) leaves the forward hook — a `SetPieceEntry` can later grow an `Array` of curated opposition placements consumed by client (c) — but no field ships now (YAGNI until the client exists).

---

## 2. Architecture — the stage + config surfaces

### 2.1 Stage contract (RefCounted, one method)

```gdscript
# systems/bandgen/stages/band_flavor_stage.gd (illustrative base; duck-typing acceptable)
class_name BandFlavorStage extends RefCounted
const MUTATES_PIECES := false      # pipeline re-grades after me if true
const RESHAPES_FLOOR := false      # pipeline runs connectivity in CARVE mode after me if true
func apply(band: Band, profile: BandProfile, stage_seed: int) -> void: pass
```

`SetPieceInjectStage`: `MUTATES_PIECES = true`, `RESHAPES_FLOOR = false` (pure-socket — assembly guarantees its connection). `WearDecayStage`: `MUTATES_PIECES = false`, `RESHAPES_FLOOR = true`.

### 2.2 Config resources (what `profile.flavors` actually holds)

`BandProfile.flavors: Array[Resource]` is authored in a `.tres`, and `.tres` can only hold `Resource`s — so the array holds **stage-config Resources**, not the RefCounted stages. The pipeline maps config-type → stage (a `match`/`is` dispatch): `SetPieceInjectConfig → SetPieceInjectStage.new(cfg)`, `WearDecayConfig → WearDecayStage.new(cfg)`. Unknown config type = `push_error` + **`null`** (fail-loud, generation refused — *amended at Wave-2 close-out, Director Reviewed 2026-07-03: "skip and still generate" was unsatisfiable alongside S1's parity guard P7, which pins unknown-flavor → `null` for control safety; an unknown stage in an authored profile is an authoring error*).

Every config carries `@export var salt: int` (defaults: `0x53455450` "SETP", `0x57454152` "WEAR"). The per-stage seed is `_stage_seed(resolved_seed, salt, index) = hash_combine(hash_combine(resolved_seed, salt), index)` using the generator's boost-style mix (`band_generator.gd:352-362`) — the array index disambiguates two instances of the same stage in one profile.

### 2.3 New files (S5-owned)

- `Game/systems/bandgen/stages/set_piece_inject.gd` · `wear_decay.gd` · `connectivity_guarantee.gd`
- `Game/data/bands/flavors/set_piece_entry.gd` · `set_piece_inject_config.gd` · `wear_decay_config.gd`
- Edit: S1's `BandPipeline` file (the §1.5 flavor loop — S5 is the sole Wave-2 bandgen writer) + **additive** `Band.floor_fingerprint()` (§6.1).
- Tests: `Game/tests/test_band_flavors.gd` + `.tscn` (run as a SCENE, never `--script`; never concurrently with another headless instance).

**Zero edits to** `band_generator.gd` (its helpers `_read_piece` / `_find_mate_socket` / `_alignment_offset` / `_make_placed` are callable cross-class in GDScript — `SetPieceInjectStage` holds a private `BandGenerator.new()` and reuses them as-is), `socket_sealer.gd`, `depth_grader.gd`, `junk_placer.gd`, `main_game.gd`, `event_bus.gd`, `run_config.gd`.

---

## 3. `SetPieceInject` — design + pseudocode

### 3.1 What a set-piece is, in data (recommendation — §9 Q2)

**A `SetPieceEntry extends Resource` in the stage config's own pool — NOT a tagged entry in `piece_catalog.tres`.** Decisive as-built reason: anything in the base catalog enters `_build_weight_table` and shifts every grow-loop draw → the **control fingerprint moves**, violating the wave contract. A separate pool keeps the base catalog byte-identical by construction, and matches the Dead Cells biome-pool model (set-pieces are per-band content, authored on the band's profile).

```gdscript
# data/bands/flavors/set_piece_entry.gd
class_name SetPieceEntry extends Resource
@export var piece: ZonePieceData          # reuses B1 format: scene + piece_id + weight
@export var min_depth_norm: float = 0.0   # host-socket depth gate (e4: vaults deep)
@export var max_per_band: int = 1         # frequency cap per e4
@export var unique: bool = true           # dedupe per e4

# data/bands/flavors/set_piece_inject_config.gd
class_name SetPieceInjectConfig extends Resource
@export var entries: Array[SetPieceEntry] = []
@export var max_total: int = 1            # injection slots attempted per band
@export var salt: int = 0x53455450        # "SETP"
```

The set-piece scene itself is a plain B1 `ZonePiece` (≥1 canonical 2-cell socket — e4's authoring lint, enforced as a `push_error` + skip at load). **S5 authors no new set-piece art**: its tests wrap an *existing* greybox room scene in a `SetPieceEntry` (proving the machinery with zero authoring); S7 authors `band_two`'s real vault/gauntlet pieces against this format.

### 3.2 How it rides the socket machinery — attach-at-open-socket, not swap

e4 leaned "swap a placed generic room" — written before the S1 wrapper decision. As-built, swap is the *expensive* option: a mid-spine room has a parent mate **and** children mated onto its other sockets, so swapping requires re-mating the whole neighborhood. Meanwhile `band.open_sockets` — the retained unconsumed frontier, kept precisely "so a later pass has everything it needs" — offers a strictly cheaper ride: **append the set-piece to a depth-gated open socket using the exact grow-loop machinery** (`_find_mate_socket` → `_alignment_offset` → `band.fits` → `_make_placed` → `band.occupy`). The set-piece becomes a dead-end special room off the spine: a *detour*, which is exactly e4's risk/reward read (the vault is the thing worth the longer walk home). This is a recorded deviation from e4's lean, argued from the as-built reality — §9 Q3.

### 3.3 Pseudocode

```gdscript
# systems/bandgen/stages/set_piece_inject.gd (illustrative)
class_name SetPieceInjectStage extends RefCounted
const MUTATES_PIECES := true
const RESHAPES_FLOOR := false
var _cfg: SetPieceInjectConfig
var _gen := BandGenerator.new()            # helper reuse only; never its generate()

func apply(band: Band, _profile: BandProfile, stage_seed: int) -> void:
    if _cfg == null or _cfg.entries.is_empty(): return
    var rng := RandomNumberGenerator.new()
    rng.seed = stage_seed; rng.state = rng.seed          # local sub-stream (JunkPlacer pattern)
    var placed_per_entry := {}                            # entry index -> count

    for _slot in _cfg.max_total:
        # 1. Eligible entries, stable config order (caps + unique).
        var eligible: Array[int] = []
        for i in _cfg.entries.size():
            var e := _cfg.entries[i]
            var cap := 1 if e.unique else e.max_per_band
            if placed_per_entry.get(i, 0) < cap: eligible.append(i)
        if eligible.is_empty(): break
        var entry_i: int = eligible[_weighted_pick(eligible, rng)]   # int cum table over entry.piece.weight
        var e := _cfg.entries[entry_i]
        var data := _gen._read_piece(e.piece.scene)

        # 2. Candidate sockets: retained frontier, STABLE order (the grow loop's own
        #    _sort_frontier ordering: depth, cell.y, cell.x, dir, index), depth-gated on the
        #    HOST piece's provisional depth_norm (graded by the pipeline before this stage).
        var socks := band.open_sockets.duplicate()
        _gen._sort_frontier(socks)
        socks = socks.filter(func(s): return s.owner.depth_norm >= e.min_depth_norm)
        if socks.is_empty(): continue                    # e4: graceful skip-and-log, never fail the band

        # 3. Try sockets starting at an rng-drawn index (deterministic ring walk).
        var start := rng.randi_range(0, socks.size() - 1)
        for k in socks.size():
            var sock: OpenSocket = socks[(start + k) % socks.size()]
            var mate_idx := _gen._find_mate_socket(data, sock, ZoneSocket.opposite(sock.dir))
            if mate_idx == -1: continue
            var offset := _gen._alignment_offset(sock, data, mate_idx)
            if not band.fits(_gen._global_cells(data.occupied_cells, offset)): continue
            var placed := _gen._make_placed(e.piece.piece_id, e.piece.scene, data,
                    offset, mate_idx, band.pieces.size())
            band.pieces.append(placed)                   # fingerprint moves HERE, deterministically
            band.occupy(placed)
            band.open_sockets.erase(sock)                # consumed
            band.open_sockets.append_array(placed.open_sockets)  # sealer caps leftovers for free
            placed_per_entry[entry_i] = placed_per_entry.get(entry_i, 0) + 1
            break
        # no fit anywhere -> skip and log (push_warning), per e4's recommendation
```

Notes: `band.entry_piece` / `band.deepest_piece` are **never reassigned** — the extraction anchor stays on the spine; the set-piece is a side attraction even if its re-graded `depth_index` exceeds the old max. The set-piece intentionally does **not** count toward `target_piece_count`/soft-floor (it appends post-generation). The pipeline re-grades after this stage (`MUTATES_PIECES`), then runs `ConnectivityGuarantee` in **ASSERT** mode (§5) — socket mating makes disconnection structurally impossible, so a trip here is a real bug and must fail loud.

---

## 4. `WearDecay` — design + pseudocode

### 4.1 State param, and what blocks/opens

`WearDecayConfig.state: StringName` names the ruin fiction and presets the op mix; the ops themselves are the two e5 primitives expressed in as-built geometry:

| | `&"collapsed"` (default) | `&"flooded"` |
|---|---|---|
| Reads as | rubble-choked, sealed doorways | washed-out walls, breached shortcuts |
| Default op mix | breach-lean enough to enable blocks (see 4.2) | breach-heavy, few blocks |
| Greybox visual | warm grey-brown modulate on touched pieces | blue-green modulate (§9 Q5) |

```gdscript
# data/bands/flavors/wear_decay_config.gd
class_name WearDecayConfig extends Resource
@export var state: StringName = &"collapsed"
@export var decay_level: float = 0.5       # 0..1, scales both budgets (e5's master knob)
@export var breach_budget: int = 2         # max breaches attempted at decay_level 1.0
@export var block_budget: int = 2          # max blocks attempted at decay_level 1.0
@export var depth_bias: float = 0.0        # >0 -> deeper pieces preferentially decayed (depth_norm-weighted)
@export var breach_width: int = 2          # cells; 2 matches the canonical socket/doorway width
@export var salt: int = 0x57454152         # "WEAR"
```

Deferred from e5's knob list: `rubble_density` (needs props — no asset), `destructible_in_run` (a new player verb — Director/M2, per e5's own flag), Exposure coupling (no Exposure system in M1; `depth_bias` is the M1.9-shaped stand-in — §9 Q6).

### 4.2 The as-built topology finding: breaches MUST run before blocks

e5 noted "breaches-then-blocks ordering needs care." As-built it is **mandatory, not care**: the generator produces a **tree** (linear spine, or R4-branchy — still acyclic; `loop_back_count` is a dormant export with zero consumer code, verified §10 V3). In a tree, *every* doorway is a bridge — so *every* block disconnects the band and reject-on-disconnect rejects **all** of them. (Precision note, §10 C2: acyclicity is an *empirical* property of the mated grow loop, not a theorem — `band.fits` rejects overlap only, never adjacency, so an unmated flush floor-to-floor seam creating a cycle is geometrically possible; the §6.2-5 test therefore asserts the tree precondition explicitly rather than assuming it.) Blocks can only ever land where a **prior breach has created a cycle** providing the alternate route. Consequences baked into the design: (1) the stage runs its breach pass first, block pass second — hardcoded, not authored; (2) a config with `block_budget > 0` and `breach_budget == 0` is a legal no-op for blocks — log a `push_warning` so the author learns why, but gate the warning on the pre-decay adjacency graph actually being a tree (edges == `pieces.size() - 1`) so it never mis-fires on a future cyclic band (§10 Q4); (3) e5's "decay_level feels capped" flag is *structural* here, and the honest tuning story for `band_two` is breach-led decay. Recorded as the headline design note for the Director (§9 Q4).

### 4.3 Op mechanics (as-built geometry)

**Doorway enumeration (block candidates).** A *doorway* = the set of FLOOR cells of piece *i* 4-adjacent to FLOOR cells of piece *j* (the exact walkable-adjacency definition shared by `is_band_connected`, `DepthGrader._build_adjacency`, and the sealer's guard). Enumerate per unordered pair `(i<j)` from a **pre-decay snapshot** (breach-created adjacencies are excluded — blocking a breach you just cut is churn), sort pairs ascending, sort each doorway's cells by `(y, x)`.

**Block** = pick a doorway (rng over the sorted list, `depth_bias`-weighted by the deeper piece's `depth_norm`); for **every** cell on the *i*-side of the seam (a full-overlap doorway is 2 cells wide and partial-overlap mates can leave 1-wide seams — `socket_sealer.gd` BUG4 note, §10 C3 — so walling anything less than the whole seam can leave it passable): write WALL via the sealer's proven write (`geo.set_cell(global - offset_cell, 0, WALL_ATLAS)` into the owner's `Geometry`), erase the cell from the owner's `floor_cells`. **Tentatively** — then run the cell-level connectivity check (§5); if disconnected, revert (restore tile + floor_cells) and retire that doorway. Every committed op is pushed onto a **journal** (`{op, piece, cells, prior_atlas}`) — the CARVE fallback's revert surface.

**Breach** = find a *wall-pair*: as-built pieces are solid-walled rects mated flush, so a non-doorway seam is **two** wall cells thick (each piece's own perimeter wall) — e5's "one perimeter WALL cell" only exists in the 1-thick idealisation. A breach candidate is a pair of 4-adjacent wall cells `(w1 ∈ piece A, w2 ∈ piece B)` where `w1` has a FLOOR neighbour in A and `w2` a FLOOR neighbour in B, aligned on the seam axis; convert **`breach_width` parallel pairs** (2-wide = doorway width = guaranteed player-traversable) to FLOOR (`set_cell(..., 0, Vector2i(0,0))`), append the cells to their owner pieces' `floor_cells`, journal the op. Candidates sorted by `(min cell y, x)`; runs of `breach_width` adjacent pairs precomputed; rng picks over the sorted run list. Breaches can only add edges — no connectivity risk — but they still journal (uniform CARVE surface).

Budgets: `ceil(budget * decay_level)` each, integer math. Both passes draw from the single stage-seed sub-stream in a fixed op order (all breaches, then all blocks) so the draw sequence is reproducible.

### 4.4 Pseudocode

```gdscript
# systems/bandgen/stages/wear_decay.gd (illustrative)
class_name WearDecayStage extends RefCounted
const MUTATES_PIECES := false
const RESHAPES_FLOOR := true
var _cfg: WearDecayConfig
var journal: Array = []                                  # consumed by ConnectivityGuarantee CARVE

func apply(band: Band, _profile: BandProfile, stage_seed: int) -> void:
    if _cfg == null or _cfg.decay_level <= 0.0: return
    var rng := RandomNumberGenerator.new()
    rng.seed = stage_seed; rng.state = rng.seed
    var doorways := _enumerate_doorways(band)            # pre-decay snapshot, sorted (§4.3)

    # PASS 1 — breaches (must precede blocks: tree topology, §4.2)
    var runs := _enumerate_breach_runs(band, _cfg.breach_width)   # sorted wall-pair runs
    for _b in ceili(_cfg.breach_budget * _cfg.decay_level):
        if runs.is_empty(): break
        var r = runs.pop_at(rng.randi_range(0, runs.size() - 1))
        for pair in r: _set_floor(pair.piece, pair.cell, journal)  # tile + floor_cells + journal

    # PASS 2 — blocks (tentative + reject-on-disconnect, e5's rule)
    for _k in ceili(_cfg.block_budget * _cfg.decay_level):
        if doorways.is_empty(): break
        var d = doorways.pop_at(_biased_pick(doorways, rng, _cfg.depth_bias))
        var mark := journal.size()
        for cell in d.side_cells_i: _set_wall(d.piece_i, cell, journal)
        if not ConnectivityGuarantee.new().is_fully_connected(band):
            _revert_to(journal, mark, band)              # reject: doorway stays open
```

The pipeline then runs `ConnectivityGuarantee` in **CARVE** mode with `journal` (§5) — belt-and-braces on top of the inline rejects.

---

## 5. `ConnectivityGuarantee` — the Stage-5 invariant

**Check:** flood-fill from the entry over **FLOOR 4-adjacency at cell level** — root = first cell of `band.entry_piece.floor_cells` sorted `(y, x)`; frontier = the band-global floor set built from every piece's `floor_cells` (the `SocketSealer` floor-set construction, reused). Connected ⇔ every floor cell is reached. Cell-level is deliberately **stronger** than the as-built `is_band_connected` piece-level BFS (`band_generator.gd:477-520`): piece-level cannot see an intra-piece stranding (e.g. a floor cell walled off inside its own piece by a future op). RNG-free, pure geometry — like the sealer. (The generator's own piece-level check stays untouched.)

**Policy, per the exploration's recommendation — carve for reshaped floors, assert for pure-socket:**

- **ASSERT mode** (after `SetPieceInject`, and after any future pure-socket stage): disconnection is structurally impossible (socket mating *is* the connection), so a trip = a real bug → `push_error` with the unreached-cell count + seed, and the band is returned as-is (never crash generation); tests assert it never fires.
- **CARVE mode** (after `WearDecay`, and after any future `RESHAPES_FLOOR` stage): "carving a minimal connector" for a doorway-blocking pass **is re-opening the doorway** — so carve = pop the stage's journal LIFO, reverting committed ops until the flood-fill covers all floor. Deterministic (journal order is deterministic), minimal (stops at first full coverage), and asset-free (no arbitrary tunnel carving through authored geometry — that's the CA-backend problem, deferred with the CA backend to Phase D). With the inline reject-on-disconnect in §4.4 the journal revert should never trigger on a healthy build — it is the invariant's teeth, unit-tested by force-feeding a disconnecting journal (§6).

```gdscript
# systems/bandgen/stages/connectivity_guarantee.gd (illustrative)
class_name ConnectivityGuarantee extends RefCounted
enum Mode { ASSERT, CARVE }

func is_fully_connected(band: Band) -> bool:
    var floor_set := {}                                  # Vector2i -> owner piece (sealer pattern)
    for p in band.pieces:
        for c in p.floor_cells: floor_set[c] = p
    if floor_set.is_empty() or band.entry_piece == null: return false
    var root: Vector2i = _sorted_first(band.entry_piece.floor_cells)   # (y,x) min
    # BFS over 4-neighbours within floor_set ...
    return reached_count == floor_set.size()

func enforce(band: Band, mode: Mode, journal: Array = []) -> bool:
    if is_fully_connected(band): return true
    if mode == Mode.ASSERT:
        push_error("ConnectivityGuarantee: pure-socket stage disconnected band (seed %d)"
                % band.resolved_seed)
        return false
    while not journal.is_empty():                        # CARVE = deterministic LIFO revert
        _revert(journal.pop_back(), band)
        if is_fully_connected(band): return true
    push_error("ConnectivityGuarantee: CARVE exhausted journal, still disconnected"); return false
```

---

## 6. Determinism contract + tests

### 6.1 `Band.floor_fingerprint()` (additive)

Because `fingerprint()` cannot see WearDecay (§1.4), S5 adds one **additive** method to `band.gd` — `floor_fingerprint()`: sha256 of the band-global floor cells sorted `(y, x)` (`"x,y"` joined). `fingerprint()` itself is **untouched** (the pinned determinism fixtures depend on its exact definition). `floor_fingerprint()` becomes the wear-aware determinism bar and S7's "connectivity green through WearDecay" handle.

### 6.2 Test plan — `tests/test_band_flavors.tscn` (headless SCENE; sequential with other godot runs)

Profiles are built **in code** (`BandProfile.new()` + config resources) against S1's `band_greybox` inputs, across the `test_bandgen_determinism` seed matrix:

1. **Control unmoved (the wave contract):** empty-`flavors` profile through the S5-extended pipeline → `fingerprint()` byte-matches the direct `BandGenerator.generate` path per seed (re-asserts S1's parity *with the flavor plumbing present*). All existing bandgen tests stay green.
2. **SetPieceInject determinism:** same seed+profile → same `fingerprint()` **twice** (fresh pipeline instances); fp ≠ control fp; injected `piece_id` present; count ≤ caps; `unique` respected; every injected piece's host socket satisfied `min_depth_norm` (checked against the re-graded band); a `min_depth_norm = 1.1` gate injects nothing (graceful-skip path).
3. **WearDecay determinism + fp-invariance:** same seed+profile → same `floor_fingerprint()` twice; **`fingerprint()` byte-equals the control's** (piece list untouched — the off-fingerprint claim, asserted not assumed); different seed → different `floor_fingerprint()` (sanity).
4. **WearDecay cannot strand (the DoD test):** aggressive config (`decay_level = 1.0`, budgets maxed) across the full seed matrix → `ConnectivityGuarantee.is_fully_connected(band)` true after the pipeline; additionally every piece (incl. `deepest_piece`, the extraction anchor) is reached and `DepthGrader` left no `depth_index == pieces.size()` sentinel (its unreachable marker, `depth_grader.gd:41-43`).
5. **Tree-topology fact pinned (as a conditional, per §10 C2):** first assert the **precondition** — the pre-decay piece-adjacency graph is a tree (edge count == `pieces.size() - 1`); then `breach_budget = 0, block_budget = 8, decay_level = 1.0` → **zero** journal entries of type block (every block rejected on the acyclic band) and `floor_fingerprint()` equals control — the §4.2 finding as a regression test. If a future seed/config trips the precondition (accidental unmated adjacency, or `loop_back_count` activation), the test fails loudly at the precondition instead of the zero-blocks assertion silently going stale.
6. **CARVE unit test:** hand-block a doorway *bypassing* the inline reject (direct `_set_wall` + journal), assert `is_fully_connected` false, run `enforce(CARVE, journal)` → true, tiles + `floor_cells` restored.
7. **Ordering/composition:** `[SetPieceInject, WearDecay]` in one profile → deterministic fp + floor-fp twice; the set-piece is placed before decay ops (decay can touch the vault's doorway — the e4×e5 "decayed vault" multiplier working).
8. **Salt independence:** two `WearDecay` entries in one `flavors` array draw distinct sub-streams (index-mixed seeds) — floor-fp differs from the single-entry run, deterministically.

---

## 7. Files to create / touch (recap)

| Action | Path |
|---|---|
| create | `Game/systems/bandgen/stages/set_piece_inject.gd`, `wear_decay.gd`, `connectivity_guarantee.gd` (+ optional shared `band_flavor_stage.gd` base) |
| create | `Game/data/bands/flavors/set_piece_entry.gd`, `set_piece_inject_config.gd`, `wear_decay_config.gd` |
| create | `Game/tests/test_band_flavors.gd` + `.tscn` |
| edit | S1's `BandPipeline` file (flavor loop per §1.5, guarded by `not flavors.is_empty()`) |
| edit (additive) | `Game/systems/bandgen/band.gd` — `floor_fingerprint()` only |
| **never** | `main_game.gd`, `event_bus.gd`, `run_config.gd`, `band_generator.gd`, `socket_sealer.gd`, `depth_grader.gd`, `junk_placer.gd`, `config_menu.gd`, any save code |

---

## 8. Definition of done (concrete)

1. `godot --headless --path Game --import` clean; CI smoke test green; **all existing bandgen tests green** (`test_bandgen_determinism`, S1's `test_band_pipeline_parity`) — run sequentially, never concurrent headless instances.
2. **Control intact:** empty-`flavors` `band_greybox` profile `fingerprint()` byte-identical through the S5-extended pipeline across the full seed matrix (test §6.2-1); all-off `RunConfig` fp `e943ac9c8bc1` unmoved (S5 touches no RunConfig path — verified anyway).
3. **Each stage deterministic:** same seed+profile → same `fingerprint()` + `floor_fingerprint()` twice (tests §6.2-2/3/7/8), on local sub-streams only — zero `RNG` autoload calls in any stage (code-review assertion + the control test proves it behaviorally).
4. **`WearDecay` cannot strand:** test §6.2-4 green across the seed matrix at maximum decay; CARVE unit test §6.2-6 green; the connectivity invariant demonstrably runs after **both** flavor stages in the pipeline.
5. `SetPieceInject` proves the socket ride with an existing greybox piece (no new art); skip-and-log path exercised (§6.2-2 tail).
6. Worklog at `worklogs/<date>-S5-general-purpose.md` naming the real commit SHA(s) + a Design-deviations section (at minimum: the attach-vs-swap call §9 Q3 and the breach-before-block finding §4.2, if ratified as designed); commit message references `S5`.

---

## 9. Open Questions (CLOSED — all nine resolved in §10; Director-visibility items ride the close-out, non-blocking)

1. **`Band` vs `BandBuild` hook point — coordination with S1 (technical).** This doc commits to stages operating on the **post-assembly `Band`** inside `BandPipeline.generate`, pre-seal/pre-final-grade (§1.3/§1.5), because Phase A wraps `_generate_once` unrefactored and the `Band` already carries pieces/occupancy/open-sockets/resolved_seed. S1's design doc is being authored in parallel — if S1 lands a different pipeline shape (e.g. an early thin `BandBuild`), the stage signature's first parameter follows S1's noun; internals are geometry-only either way. **Recommend:** ratify Band-as-build-state for M1.9; defer `BandBuild` to the first non-socket backend (Phase D).
2. **What IS a set-piece in M1.9 data terms (technical/content).** Options: (a) tagged `ZonePieceData` rows in `piece_catalog.tres` — rejected: entries enter `_build_weight_table` and move the control fingerprint; (b) **new `SetPieceEntry` resource in the stage config's own pool (§3.1) — recommended**: control-safe by construction, per-band authoring per the Dead Cells model, and the natural future carrier for client-(c) curated opposition placements (deferred, §1.6). Needs a yes/no on the deferred-hook framing.
3. **Attach-at-open-socket vs e4's swap lean (technical — deviation from the exploration).** §3.2 recommends **attach** (rides `band.open_sockets` + the untouched grow-loop helpers; set-piece = dead-end detour). Swap gives mid-spine placement (the vault *on* the path) at the cost of neighborhood re-mating complexity. **Recommend attach for M1.9**; revisit swap only if S7's playtest says detour-vaults read as skippable. If ratified, log as a deviation against e4 in `DESIGN_DEVIATIONS.md` at wave close-out.
4. **Blocks are structurally rare on tree bands (design/fun — Director should see this).** §4.2: on the as-built acyclic layouts, blocks land **only** behind prior breaches. So M1.9 decay is breach-led (shortcuts) more than block-led (detours). Accept for M1.9 (recommended — honest to the geometry, and breaches are the fun half: secret-shortcut energy), or pull the dormant `loop_back_count` cyclic pass forward to give blocks room (scope growth — not recommended this version)?
5. **WearDecay's visual representation at greybox fidelity (art/fun — Director).** Blocks/breaches are self-representing (real WALL/FLOOR tiles with collision). Beyond that, recommend the cheapest legible tell: a per-piece `Geometry` **modulate tint on decay-touched pieces** (`&"collapsed"` warm grey-brown / `&"flooded"` blue-green), zero new assets, fp-neutral. e5's legibility flag (does a breach read as passable without a tell?) stays open for the SG2 playtest; a distinct breach tile is an S7/environment-artist follow-up if not.
6. **Decay scaling source (vision — Director, deferred-leaning).** e5 wants ruin tied to depth + Exposure. No Exposure system exists in M1; `band_depth` lives on the profile. **Recommend:** `decay_level` stays profile-authored (band_two sets its own ruin), `depth_bias` gives within-band deep-is-more-ruined; Exposure coupling deferred to the milestone that builds Exposure.
7. **Stage ordering rules (technical/authoring).** Recommended contract: **execution order = `flavors` array order (profile-authored)**; connectivity interleaving is **pipeline-enforced** off the per-stage `RESHAPES_FLOOR`/`MUTATES_PIECES` traits (never authored — an author must not be able to skip the invariant); within WearDecay, breach-before-block is **hardcoded** (§4.2). Authored guidance (not enforced): `SetPieceInject` before `WearDecay` so decay can ruin the vault (the e4×e5 multiplier). Ratify or tighten (e.g. hard-sort flavors by a stage priority)?
8. **Cell-level vs piece-level connectivity bar (technical).** §5 recommends cell-level flood-fill (strictly stronger; catches intra-piece stranding no current op can cause but future ops could). Cost: one dict-BFS over ~10²–10³ cells per reshaping stage per generation — negligible headless and at dive start. Confirm cell-level as the invariant's definition.
9. **Breach width (technical/feel).** §4.3 recommends `breach_width = 2` (matches doorway width — guaranteed traversable, reads as a "real" opening). 1-wide breaches are moodier but risk player-collision squeeze at 16 px cells and read as untraversable. Ship 2 as default with the knob exposed?

---

## 10. Resolved Decisions (Phase 3 — fresh-eyes resolution, 2026-07-02)

Resolved by a Phase-3 fresh-eyes agent (not the Phase-2 author) against the as-built code, the band explorations (e4/e5/architecture doc), S1's Phase-2 design, and the orchestrator's **cross-contract adjudications** (fixed inputs, marked *[adjudicated]* below). The body of this spec (§0–§8) now commits to these answers, with the §1.5/§4.2/§4.3/§6.2 corrections applied inline. The implementing agent reads a single locked design; the two Director-visibility items (Q4 headline, Q5 legibility watch-item) are **non-blocking** and travel with the worklog/close-out, not the dispatch.

### Verifications & claim corrections (as-built spot-checks)

- **V1 — `fingerprint()` hashes the piece list only: VERIFIED.** `band.gd:58-62` is exactly the ordered `piece_id@offset#mated` sha256 — no floor cells, no tiles. §1.4's classification table stands.
- **V2 — retained open-socket frontier: VERIFIED.** `band.gd:26-29` retains `open_sockets` verbatim ("so a later loop-closing pass … has everything it needs"); `OpenSocket` carries `owner: PlacedPiece` / `dir` / `cell` / `depth` (`open_socket.gd`), so §3.3's `sock.owner.depth_norm` gate works once the provisional grade has run.
- **V3 — `loop_back_count` is dormant: VERIFIED.** It exists only as an export (`data/bandgen_config.gd:27`, `.tres` value 0) with **zero consumer code** in the generator — its only other appearances are comments. Bands are generated as mated trees today.
- **V4 — the sub-stream pattern citation: VERIFIED.** `junk_placer.gd:57-59` is literally `rng.seed = _substream_seed(...)` then `rng.state = rng.seed`; §3.3/§4.4's pseudocode mirrors the as-built pattern exactly. `_sort_frontier`'s order (depth, cell.y, cell.x, dir, index) and the `_hash_combine` boost mix (`band_generator.gd:352-362`) are as cited. Seed matrix = `tests/test_bandgen_determinism.gd::SEEDS` (9 seeds).
- **C1 — CORRECTED: the seal is NOT in the pipeline.** §1.5's Phase-2 pseudocode invoked `SocketSealer.seal_unused_sockets(band)` inside `BandPipeline.generate`; S1's as-built design explicitly keeps the seal **at materialisation** (`main_game.gd:881` — "NOT invoked here"). Fixed inline: S5's flavor loop fills S1's vacant "STAGES 3-5" slot; S1's existing tail grade is the canonical grade (equivalent to a post-seal grade because the seal never touches `floor_cells`, `socket_sealer.gd:30-31`); the seal keeps running at materialisation, still downstream of every floor mutation. **S5 moves no seal code and still never touches `main_game.gd`.**
- **C2 — SOFTENED: "every doorway is a bridge" is empirical, not a theorem.** `band.fits` rejects overlap only, never adjacency, so an unmated flush floor-to-floor seam (an accidental doorway → a cycle) is geometrically possible; `socket_sealer.gd`'s BUG4 note and `depth_grader.gd`'s "branches/loops are handled the moment B2 enables them" both anticipate non-tree adjacency. Consequence: test §6.2-5 now asserts the tree **precondition** explicitly (edges == n−1) before asserting zero blocks, and the §4.2 author warning is tree-gated.
- **C3 — CORRECTED: doorways are not always 2 cells wide.** BUG4 records partially-overlapped mates, so a seam can be 1 cell. The block mechanic was already robust (it writes **every** i-side seam cell); only §4.3's parenthetical was an idealisation — fixed inline.

### Q1 — Hook point: `Band` vs `BandBuild` — **RESOLVED** *[adjudicated]*

**Decision: stages operate on the post-assembly `Band` inside `BandPipeline.generate` — after `BandGenerator.generate`, before S1's tail (final grade / return-distance), i.e. in S1's explicitly vacant "STAGES 3-5" slot — with the provisional grade supplying the depth gates.** The signature is `apply(band, profile, stage_seed)` with `band` in the contract's `build` slot. `BandBuild` is deferred to the first non-socket backend (Phase D); stage internals speak only floor-cell/socket geometry, so the port is a parameter swap. S1's doc is being reconciled to exactly this hook, and its Phase-A guard (`push_error` + `return null` on a non-empty `flavors` array, S1 pseudocode) is precisely the code S5 replaces with the flavor loop. *Rationale:* the `Band` already carries pieces/occupancy/open-sockets/resolved_seed; inventing a `BandBuild` now is the `_generate_once` churn Phase A exists to avoid. Amended per **C1**: the loop's tail is S1's existing grade, not a relocated seal.

### Q2 — Set-piece data shape — **RESOLVED** *[adjudicated]*

**Decision: a new `SetPieceEntry` pool resource inside the stage config (§3.1) — never the base `piece_catalog.tres`.** Anything in the base catalog enters `_build_weight_table` and moves the control fingerprint; a config-owned pool is control-safe by construction. **The deferred-hook framing is ratified as-is:** no opposition field ships on `SetPieceEntry` in M1.9 (YAGNI until opposition client (c) exists); the `ignore_room_cap` ctx escape stays reserved in the `SpawnService` per the breakdown's cross-cutting contracts, and `svc.spawn` is never called from a stage this version.

### Q3 — Attach vs e4's swap lean — **RESOLVED** *[adjudicated]*

**Decision: ATTACH — append the set-piece to a depth-gated retained open socket via the untouched grow-loop helpers (§3.2/§3.3).** Swap (e4's lean) requires re-mating a mid-spine neighborhood and is strictly more expensive as-built. **Record as a deviation-from-e4 in `design/DESIGN_DEVIATIONS.md` at wave close-out** (already in DoD §8.6); revisit swap only if S7's playtest says detour-vaults read as skippable. Two S7 reconciliation consequences (see also A2): (a) S7 §3.4/§3.7 currently describes a *mark-the-deepest-room* rule — it must be re-authored to attach; (b) S7 §3.7 rule 5 (exempt set-piece cells from decay blocking) is **dropped as unnecessary**: an attached set-piece is a dead-end whose single doorway is a bridge, so any block on it disconnects and is rejected by the inline guard — the vault cannot be stranded, and decay *touching* it is the desired e4×e5 multiplier (test §6.2-7).

### Q4 — Blocks structurally rare on tree bands — **RESOLVED for the M1.9 build; Director visibility mandatory at close-out**

**Decision: accept breach-led decay for M1.9. Do NOT pull `loop_back_count` forward.** Activating loop closure is new generator logic, which the §0 guardrails ("socket backend only, no `_generate_once` surgery") prohibit this version — it is not merely "scope growth," it is out of contract. The breach-before-block hardcode is **not over-fitted to tree topology** (fresh-eyes stress-test): breach-first is weakly dominant on *any* topology — breaches only add edges, and each block is individually guarded by the topology-agnostic reject-on-disconnect check — so if `loop_back_count` ever activates, blocks simply start landing on authored cycles with no breach needed and the hardcoded order stays correct. What *was* tree-coupled has been generalised inline: the `breach_budget == 0` author warning is now tree-gated (§4.2), and test §6.2-5 asserts its acyclicity precondition explicitly (**C2**). **The "M1.9 decay is breach-led (shortcut energy), blocks only land behind breaches" finding is the headline design note in the S5 worklog's deviations section and the SG3 gate material — the Director must see it, but it does not block the build** (the stage supports both mixes; tuning is S7/SG3 territory).

### Q5 — WearDecay's greybox visual tell — **RESOLVED (watch-item flagged)**

**Decision: ship the per-piece `Geometry` modulate tint on decay-touched pieces** (`&"collapsed"` warm grey-brown / `&"flooded"` blue-green): zero new assets, fingerprint-neutral (modulate touches no tile data), one line per touched piece. Blocks/breaches remain self-representing (real WALL/FLOOR tiles with collision). This stays within the established greybox-retone placeholder precedent, so it is not escalated; **e5's breach-legibility question (does a breach read as passable without a tell?) is parked as an SG2 playtest watch-item**, where the Director already presides — a distinct breach tile is an S7/environment-artist follow-up only if the playtest flags it (S7's Tier-2 accent tile is already authored as optional).

### Q6 — Decay scaling source — **RESOLVED**

**Decision: `decay_level` stays profile-authored; `depth_bias` provides within-band deeper-is-more-ruined; Exposure coupling is deferred to the milestone that builds Exposure.** No Exposure system exists in M1 (GDD-only), and e5 itself flagged the coupling as a vision item. Nothing in the config schema forecloses the coupling later (a future stage can compute an effective `decay_level` from Exposure before constructing the config).

### Q7 — Stage ordering rules — **RESOLVED** *[adjudicated]*

**Decision: execution order = `flavors` array order (profile-authored); connectivity interleaving is pipeline-enforced off the `RESHAPES_FLOOR`/`MUTATES_PIECES` traits — including ASSERT-vs-CARVE mode selection — and is never authorable; breach-before-block is hardcoded inside `WearDecay`.** The hard-sort/priority-field alternative is **rejected**: it adds an authoring surface with no M1.9 need, and the only cross-stage ordering preference (inject before decay, the e4×e5 multiplier) is correctly *guidance*, pinned working by test §6.2-7 rather than enforced.

### Q8 — Cell-level vs piece-level connectivity bar — **RESOLVED**

**Decision: cell-level flood-fill is the invariant's definition (§5), confirmed.** Strictly stronger than the generator's piece-level `is_band_connected` (which stays untouched as the grow loop's internal retry check); cost is one dict-BFS over ~10²–10³ cells per reshaping stage, negligible headless and at dive start; precedent is on its side — `SocketSealer` and `DepthGrader` already operate on exactly this floor-cell 4-adjacency, so the invariant, the seal, and the depth graph all agree on one walkability definition.

### Q9 — Breach width — **RESOLVED**

**Decision: `breach_width = 2` default, knob exposed.** 2 is the canonical socket width (`open_socket.gd` `width_cells` default 2; `_read_piece`'s marker meta default 2), guaranteed player-traversable at 16 px cells, and reads as a "real" opening; 1-wide stays reachable via the knob for a future moodier state but is not authored anywhere in M1.9 (S7 leaves it at default).

### A1 — `floor_fingerprint()` as an additive determinism bar (fresh-eyes stress-test, §6.1) — **RESOLVED with guardrails**

The additive method is sound, but the confusion risk with the control bar is real and must be named precisely. The **control determinism bar** is `Band.fingerprint()` (piece-list sha256, `band.gd:58-62`) as pinned by **`Game/tests/test_bandgen_determinism.gd`** (its `SEEDS` matrix; same-seed→same-fp, diff-seed→diff-fp, seal-invariance assertions) and re-asserted by S1's `test_band_pipeline_parity`; the *other* pinned fp in the wave contract — `e943ac9c8bc1` — is the **RunConfig-level all-off control**, a different artifact entirely. `floor_fingerprint()` is neither: it is the **wear-aware supplementary bar** that exists precisely because `fingerprint()` is blind to WearDecay (V1). Guardrails, binding on the implementation: **(a)** its docstring must state it is NOT the layout-control fingerprint and must never replace `fingerprint()` in any control/parity assertion; **(b)** `test_bandgen_determinism.gd` and `test_band_pipeline_parity` are not edited — `floor_fingerprint()` is asserted only in `test_band_flavors.gd`; **(c)** it is computed from `floor_cells` (the pre-seal walkable truth), which makes it stable whether called before or after the materialisation seal — state this in the docstring; **(d)** the name stands (adequately distinct); no aliasing or wrapping of `fingerprint()`.

### A2 — Cross-doc parameter alignment with S7 (`band_two`) — **RESOLVED** *[adjudicated: S5's schema is canonical]*

S7 §3.4/§3.7 was authored against a provisional param sketch; **S5's §3.1/§4.1 schema is the canonical surface** and S7 reconciles at its build (S7 is blockedBy S5, so no file conflict). The mapping S7 folds in:

| S7 sketch | S5 canonical | S7 value → |
|---|---|---|
| `defs` | `SetPieceInjectConfig.entries: Array[SetPieceEntry]` | one entry wrapping the chosen landmark piece |
| `max` | `max_total` | `1` |
| `min_depth_norm` (config-level) | `SetPieceEntry.min_depth_norm` (per-entry) | `0.6` |
| `intensity` | `WearDecayConfig.decay_level` | `0.25` |
| `block_routes: true` | `block_budget > 0` | default `2` |
| `open_breaches: true` | `breach_budget > 0` | default `2` |
| `state: &"flooded"` | supported as-is | Pitch A/B |
| `state: &"disused"` (Pitch C) | **not an S5 state** | maps to `&"collapsed"`, or S7 requests an S5 state extension if Pitch C wins |
| *(unset)* | `depth_bias`, `breach_width`, salts | S5 defaults |

Two further S7 reconciliation notes riding Q3: the mark-based placement rule and the decay-exemption rule are superseded (Q3), and S7's "off-stream flavors never move the fingerprint" phrasing needs its SetPieceInject half updated — attach-ratified injection is **layout-affecting** (moves band_two's fp deterministically), which the breakdown explicitly permits under the `(seed + config)` contract; S7's determinism test asserts same-seed reproducibility, not fp equality with a mark-based build, so no S7 test changes.

---

*Spec authored for M1.9 S5 (Phase-2 design fan-out); §10 Resolved Decisions folded in by the Phase-3 fresh-eyes resolver (2026-07-02) with the orchestrator's cross-contract adjudications. Design only — no code, no `.tres`. The implementing agent reads this as a single locked design (§0–§8 as corrected + §10). Q4's headline and Q5's watch-item go to the Director with the wave close-out / SG2 material; deviations during the build go to `design/DESIGN_DEVIATIONS.md` for the close-out sweep.*

---

## 11. Wave-2 close-out amendments (as-built, Director-dispositioned 2026-07-03)

All four S5 deviations dispositioned **Reviewed**:

- **Set-pieces attach at a retained open socket** (dead-end detour off the spine), per §10 Q3 —
  swap stays a possible revisit only if S7's playtest says detour-vaults read as skippable.
- **M1.9 decay is breach-led** (the §4.2 headline): on tree bands, blocks land only behind breaches
  (a breach must first create a cycle). Band_two's ruin tuning is breach-heavy — tune `breach_budget`
  first (S7 note: width-2 breach runs are scarce on greybox bands, 0–2 per band; tune budgets, not
  width). `loop_back_count` stays out of M1.9 scope.
- **Unknown flavor config = fail-loud `null`** (§2.2 amended in place above).
- **Stage traits are overridable methods** (`mutates_pieces()` / `reshapes_floor()` / `journal()`),
  not consts — GDScript cannot shadow a base-class const in a subclass; contract semantics identical.
