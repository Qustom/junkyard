# T0 — CaveBackend: CA caverns generator + `CaveBandConfig` + pipeline backend dispatch — Expanded Design Spec

**Milestone:** M1.10 (Second Backend + Cave Band + Low-Sightline Oppositions) · **Workstream:** bands · **Wave:** 1 (parallel worktree, alongside T2a/T2b)
**Task id:** T0 · **blockedBy:** none · **Blocks:** T1 (materialisation), T3 (`band_three.tres`)
**Assignee:** general-purpose (programmer)
**Author:** Phase-2 per-task design (2026-07-04) · **Status:** Phase-3 resolved (2026-07-04) — §10 Resolved Decisions is BINDING over the doc body

> **What this doc is.** The Phase-2 design for T0 per `M1.10_Breakdown.md` §"Wave 1" — the exploration's
> **Phase D second backend**, brought forward by the Director's M1.10 directive ("a new band that tests
> the scalability of adding bands — using a different type of procedural generation"). It expands the
> breakdown's T0 contract into a config schema, the CA algorithm with its determinism discipline, the
> synthetic-`PlacedPiece` shape, the `band_pipeline.gd` dispatch diff, the `validate()` cave branch,
> and the acceptance-test plan. It is **design only** — no code, no `.tres`, no branch ships with this
> doc. The programmer builds against it after Phase 3 resolves §9.

---

## 0. Hard constraints (read first)

From the breakdown's scope guardrails + cross-cutting contracts. Non-negotiable:

- **Three controls byte-identical.** The all-off `RunConfig` fingerprint **`e943ac9c8bc1`**, the
  `band_greybox` profile fingerprint, and the `band_two` profile fingerprint must be untouched. Cave
  code is reachable **only** through a `backend == "cave"` profile — no cave statement executes on any
  socket path. `test_band_pipeline_parity` + `test_bandgen_determinism` + the RG-style verify are the
  proof and are never edited to pass.
- **Cave determinism contract:** `(profile + seed + rc)` → same `Band.fingerprint()` twice,
  byte-for-byte, forever. Reseed via the existing `RNG.seed_from(seed)` discipline
  (`band_generator.gd:88` precedent); **order-stable iteration everywhere** (sorted flood regions,
  fixed cell-scan order — the b3 exploration's called-out gotcha); connectivity repair is
  **deterministic CARVE**, never retry-loops on the global stream (§3.5 interprets this against the
  as-built `ConnectivityGuarantee` — see §9 Q4).
- **File scope:** T0 touches **only** `Game/systems/bandgen/` + `Game/data/bands/*.gd` schema + its new
  tests. **NOT `main_game.gd`** (T1 is this version's sole `main_game.gd` writer; a test drives the
  pipeline directly). `band_pipeline.gd` + `band_profile.gd` are T0's exclusive files this wave
  (single-writer rule).
- **No new opposition machinery, no save-schema change, no `RunConfig` knob** — the 91-knob model is
  frozen; the cave's knobs live in `CaveBandConfig` (profile content, not run-experiment levers).
- **Typed GDScript; integer math on every branch-affecting comparison** (the B2 discipline —
  `band_generator.gd:8-11`). `fill_pct` is an integer percent compared against `randi_range(0, 99)`,
  never a `randf()`.
- **Headless tests run as SCENES** (`godot --headless --path Game res://tests/test_cave_backend.tscn`),
  never `--script`, never concurrently with another headless godot (import-lock).
- **Worklog carries the bespoke-code cost ledger** (files + line counts of non-data, non-test code) —
  M1.10's version-defining discipline; TG3 judges the scalability claim on it.

---

## 1. Research — why this task, what exists, what changes

### 1.1 Why this task

M1.9 proved "new content on the existing machinery is data": `band_two.tres` was a new profile on the
*same* socket backend. M1.10 must prove the harder half of the exploration's claim — that the
`BandPipeline` seam is a genuine **multi-backend interface**, not a wrapper with one implementation.
The b3 exploration (`b3-organic-caverns.md`) is blunt about why this cannot be a piece-catalog trick:
*"A CA cavern has no pieces and no sockets... Forcing organic blobs through rectangular pieces would
just be lumpy corridors."* The value of the cave band — bad sightlines as the play identity, the host
archetype the Ambusher/Burrower (T2a/T2b) need to read as fair — only exists if the floor is genuinely
irregular, which means a genuinely different generator.

The architecture exploration (`0-scalable-band-generation-system.md` §"Multi-backend behind one
interface") already sized this: *"`CaveBackend` (new, ~120 lines): seeded fill% → N CA smoothing passes
→ keep largest flood region"*, feeding *"the SAME downstream stages"* because `SocketSealer`,
`DepthGrader`, and `JunkPlacer` *"consume only FLOOR-cell 4-adjacency — they never touch sockets"*. T0
builds exactly that backend, plus the two things the exploration hand-waved: the **synthetic
`PlacedPiece` identity** that keeps `Band.fingerprint()` backend-agnostic (breakdown OQ5), and the
**dispatch seam** replacing the Phase-A fail-loud. S1's own §8 deferred the backend interface with
*"extract the `build_layout` interface when the second backend is actually built"* — this is that
moment.

### 1.2 What exists (as-built, verified 2026-07-04)

- **The seam, already declared and guarded.** `BandProfile.backend` carries `"cave"` as a declared enum
  value (`data/bands/band_profile.gd:26`) with the comment *"the pipeline fail-louds on them"*.
  `BandPipeline.generate` does exactly that at the Phase-A wiring guard
  (`systems/bandgen/band_pipeline.gd:45-48`): `if profile.backend != "socket": push_error(...); return
  null`. `test_band_pipeline_parity.gd:253-257` (P7) pins that a synthetic `backend = "cave"` profile
  returns null — **T0 must update that P7 case** (the guard it asserts is being replaced by real
  dispatch; the new failure mode it should pin is "cave profile with a missing/wrong-typed
  `backend_config` returns null"). `BandProfile.validate()` has a socket-only branch
  (`band_profile.gd:82-95`); T0 adds the cave branch (§4.2).
- **The pipeline stage stack T0 slots into** (`band_pipeline.gd:33-117`): fail-loud validation (`:34-42`)
  → wiring guards (`:44-63`) → **STAGES 1+2 backend** (today: `BandGenerator.new().generate(seed, cfg,
  catalog, rc)` verbatim, with the I1 `lvl_enabled`/`piece_pool_ext` catalog swap just above it,
  `:70-80`) → S5 flavor loop + `ConnectivityGuarantee` CARVE/ASSERT (`:86-107`, guarded so empty
  flavors run zero flavor code) → `DepthGrader.grade` + `compute_return_distance` (`:112-113`). The
  pipeline rolls **zero** RNG of its own (docstring `:14-19`); per-stage sub-seeds derive via
  `_stage_seed`/`_mix` (`:143-151`, the boost-style hash-combine kept local so `band_generator.gd`
  stays untouched).
- **The RNG + retry discipline to mirror** (`band_generator.gd`): `generate(seed, cfg, catalog, rc)`
  (`:46`) runs a whole-band retry loop (`:60-79`) — attempt 0 uses `seed`, attempt *n* uses
  `_derive_seed(seed, n)` (boost-style integer hash-combine, `:352-362`); each attempt's
  `_generate_once` calls **`RNG.seed_from(seed)` as its first act** (`:88`) before any draw; undersize
  attempts keep the largest band seen and emit `band_generation_failed` (`:76`). Signals
  `band_generation_started`/`band_generated` emit inside the generator (`:48,71,78`). Purity under
  global-RNG perturbation is test-pinned (`test_bandgen_determinism.gd:105-115`).
- **`Band` + `PlacedPiece` — the data shape synthetic pieces must fill.**
  `Band.fingerprint()` = ordered `"piece_id@offset#mated"` sha256 (`band.gd:58-62`) — it hashes **only**
  `piece_id`, `offset_cell`, `mated_socket_index`, and never floor cells. `Band.floor_fingerprint()`
  (`band.gd:76-88`, M1.9 S5) is the supplementary sorted-floor-cells hash, explicitly NOT the control
  bar. `Band` docstring convention: `entry_piece` = `pieces[0]` (`band.gd:21`); `deepest_piece` is set
  by the generator (`band_generator.gd:132`: last-placed on the spine) and consumed at materialisation
  for gate placement. `PlacedPiece` fields (`placed_piece.gd`): `piece_id: StringName` (`:13`, "used in
  the fingerprint"), `instance: ZonePiece` (`:17` — **may be null-safe everywhere downstream**, see
  next bullet), `offset_cell` (`:21`), `footprint_cells` (`:26`, feeds `Band.occupy`/`fits` + the
  overlap test), `floor_cells` (`:32`, band-global, the walkable truth), `open_sockets` (`:36`),
  `mated_socket_index = -1` for entry (`:40`), grader-assigned `depth_index`/`depth_norm`/`dist_to_gate`
  (`:44-55`).
- **Downstream is per-piece — the decisive constraint on synthetic-piece cardinality.**
  - `DepthGrader.grade` BFSes **piece-index adjacency** built from FLOOR 4-adjacency
    (`depth_grader.gd:83-104`, neighbours sorted ascending for stable BFS) and sets
    `band.max_depth = max(depth_index)` (`:47`). **A one-piece band grades to `max_depth = 0`,
    `depth_norm = 0.0` everywhere** (`:49`).
  - `JunkPlacer.plan` rolls loot **per piece** off `curve.expected_count(p.depth_norm)`
    (`junk_placer.gd:62-74`). One mega-piece ⇒ one shallow-depth loot roll for the whole cave.
    `_cell_size_px(p)` falls back to **16** when `p.instance == null` (`:198-201`) — synthetic pieces
    already have a safe default there.
  - `EncounterBuilder` walks `pieces_depth_sorted(band)` (`encounter_builder.gd:72-84`) and **skips
    `depth_index <= 0`** as entry safety (`:313-314` in the deck lane, `:211-212` legacy). One
    mega-piece ⇒ the entire cave is the entry piece ⇒ **zero spawns**. Its per-room cap identity is
    `room_key = str(p.offset_cell)` (`:366`); its room bounds are the piece's floor-cell bbox (`:458-464`).
  - **Conclusion:** the cave floor **must be partitioned into multiple synthetic pieces** — this is not
    an aesthetic choice, it is what makes the depth axis, the loot economy, and encounter population
    work *unchanged*, which is the whole reuse claim T0 exists to prove. §3.6 designs the partition.
- **`ConnectivityGuarantee`** (`stages/connectivity_guarantee.gd`): `is_fully_connected(band)`
  (`:41-62`) is a **cell-level** flood from the entry piece's (y,x)-first floor cell over the
  band-global floor set — backend-agnostic, RNG-free, exactly the invariant a cave must satisfy.
  `enforce(band, Mode.CARVE, journal)` (`:68-81`) is a **journal-LIFO revert** — "carve" there means
  *undo a flavor stage's committed tile writes until coverage returns*. A backend has no journal
  (there is no prior state to revert to), so the existing CARVE mode is structurally inapplicable
  *inside* the backend; §3.5 mirrors the carve *concept* (deterministically cut a connector) at the
  grid level and reuses `is_fully_connected` as the pipeline-level ASSERT. §9 Q4 asks Phase 3 to
  ratify this reading of the breakdown's "the ConnectivityGuarantee stage's existing CARVE mode" line.
- **`SocketSealer` is already inert on synthetic pieces.** `seal_unused_sockets` walks floor cells and
  calls `_place_wall_cap(owner, n)`, which **early-returns when `owner.instance == null`**
  (`socket_sealer.gd:95-96`). A cave band flowing through the as-built materialisation seal therefore
  writes nothing — byte-identically zero code change for socket bands. This is most of the answer to
  breakdown OQ4 (§8 + §9 Q3).
- **The acceptance-bar patterns to mirror:** `test_bandgen_determinism.gd` (seed matrix `:36` =
  `[12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]`; same-seed twice, diff-seed variation,
  connectivity, overlap-free, retry purity under RNG perturbation `:105-115`) and
  `test_band_pipeline_parity.gd` (profile-load contract P0, byte-parity P1, run-to-run P2, grading
  parity P3, structural invariants P4, rc pass-through P5, purity P6, fail-loud P7).

### 1.3 What changes vs the socket backend (honest deltas)

| Aspect | Socket backend (as-built) | CaveBackend (T0) |
|---|---|---|
| Raw material | authored `ZonePiece` scenes, weighted draw | an integer cell grid, no assets at all |
| RNG draws | interleaved through the grow loop (frontier pick, piece pick, branch roll) | **one block**: the initial fill rolls, fixed scan order, then zero draws |
| Retry model | whole-band retry on undersize via `_derive_seed` | same shape: whole-grid retry when the kept region undershoots (§3.4) |
| Connectivity | guaranteed by construction (socket mating IS connection) | keep-largest + deterministic grid carve, then pipeline ASSERT |
| Piece identity | authored `piece_id` from the catalog | **synthetic**: content-hashed chunk id (§3.7 — the OQ5 answer) |
| `instance` | the instantiated scene | `null` (T1 builds runtime greybox geometry from `floor_cells`) |
| Sockets | the frontier machinery | none; `open_sockets = []`, `mated_socket_index = -1` |

Everything below the backend — flavor loop (empty for caves in M1.10), grade, return-distance, junk,
encounters, telemetry — is **reused unchanged**. That reuse is the cost-ledger headline.

---

## 2. `CaveBandConfig` — the resource script

**File:** `Game/data/bands/cave_band_config.gd` — schema-with-content placement, mirroring
`band_profile.gd`/`deck_entry.gd` (S1 §10.1 Q4a precedent), and inside T0's "data/bands/*.gd schema"
file scope. `class_name CaveBandConfig extends Resource`, sibling of `BandGenConfig`
(`data/bandgen_config.gd`), authored in the inspector, referenced by `band_three.tres` (T3) as
`profile.backend_config`.

```gdscript
# data/bands/cave_band_config.gd  (illustrative — programmer owns final code)
class_name CaveBandConfig
extends Resource
## CaveBandConfig — tuning knobs for the CA caverns backend (M1.10 T0).
## Sibling of BandGenConfig; a BandProfile with backend == "cave" carries one.
##
## Determinism note (B2 discipline transposed): every branch-affecting field is
## an INTEGER. fill_pct is an integer percent compared against randi_range(0,99);
## the smoothing rule is pure integer neighbour-counting; no float ever touches
## the layout path.

## Grid extents in cells, INCLUDING the forced-wall border ring (§3.2). The
## playable interior is (grid_width-2) x (grid_height-2). ~60x44 gives a cave
## in the same floor-area class as the 12-piece socket band.
@export var grid_width: int = 60
@export var grid_height: int = 44

## Initial wall density, integer percent (b3: "~45%; higher = tighter").
@export var fill_pct: int = 45

## CA smoothing passes (b3: "more passes = smoother, fewer islands (~4-5)").
@export var smooth_passes: int = 4

## The CA wall rule threshold: a cell becomes WALL when >= wall_threshold of
## its 8 neighbours are wall, FLOOR otherwise (b3's stated rule at 5). Lower =
## more wall = tighter/nookier. THE nook/roughness knob for M1.10 (§9 Q7).
@export var wall_threshold: int = 5

## Flood regions with at least this many floor cells are CARVED into the main
## region (a deterministic connector corridor); smaller ones are filled to
## wall (discarded). The b3 "connectivity threshold" knob.
@export var min_region_cells: int = 12

## Width of carved connector corridors, in cells. 2 matches the socket
## doorway width (authored sockets are 2-cell — band_generator.gd:399) so a
## carved throat is never tighter than a socket door (player-scale floor).
@export var carve_width: int = 2

## Synthetic-piece partition size (§3.6): the kept floor is chunked into
## chunk_cells x chunk_cells tiles, one PlacedPiece per floor-bearing chunk.
## Sets the granularity of the depth axis / loot rolls / encounter rooms.
@export var chunk_cells: int = 8

## Whole-grid retry soft floor: if the kept+carved floor has fewer than
## min_floor_cells cells, discard and retry with a derived seed (the socket
## backend's retry model, band_generator.gd:60-79).
@export var min_floor_cells: int = 300

## Max whole-grid retries before emitting band_generation_failed and
## returning the best (largest-floor) attempt.
@export var max_attempts: int = 8

## Pixel size of one cell at materialisation (T1 consumes; JunkPlacer's
## instance-null fallback is 16 — junk_placer.gd:201 — keep these agreeing).
@export var cell_size_px: int = 16
```

Schema notes:

- **All defaults are placeholders for T3 to tune** ("chamber-y, nook-rich" is T3's authoring job with
  the Director's identity pitch); T0's job is that every knob is deterministic and covered by the test.
- **No `.tres` ships with T0.** The first authored `CaveBandConfig.tres` is T3's
  (`band_three`'s `backend_config`). T0's test builds configs in code (`CaveBandConfig.new()` + field
  pokes), the P7 pattern — no throwaway fixture files.
- **No RunConfig lever touches these fields** in M1.10 (frozen 91-knob model). If a future version
  wants Director-sweepable cave knobs, that is a new-version RunConfig decision, not T0's.

---

## 3. `CaveBackend` — the generator

**File:** `Game/systems/bandgen/cave_backend.gd`, `class_name CaveBackend extends RefCounted` — sibling
of `BandGenerator`, mirroring its instantiate-and-call shape and its public signature minus the catalog
(a cave draws from no piece pool):

```gdscript
func generate(seed: int, cfg: CaveBandConfig, rc: RunConfig = null) -> Band
```

`rc` is accepted for signature symmetry and future cave levers but is **ignored in M1.10** — every
as-built rc generation hook (r4 branching, lvl room-count/catalog-swap, J4 corridor weights) is
socket-interior and meaningless for CA (§9 Q5; the test pins rc-invariance so the decision is
enforced, not implied).

### 3.0 Determinism architecture (the whole design in one paragraph)

All randomness happens in **one block**: after `RNG.seed_from(attempt_seed)`, the fill loop draws
exactly one `RNG.randi_range(0, 99)` per interior cell in **fixed scan order** (y outer ascending, x
inner ascending). Every subsequent step — smoothing, flood-fill, region sort, discard, carve, entry
selection, chunking, piece emission — is a **pure integer function of the grid** with zero draws and a
fixed iteration order. Retries reseed with `_derive_seed(seed, attempt)` (the socket backend's exact
hash-combine, reimplemented locally so `band_generator.gd` stays untouched — the `BandPipeline._mix`
precedent, `band_pipeline.gd:139-151`). Same `(cfg + seed)` ⇒ same grid ⇒ same pieces ⇒ same
fingerprint, byte-for-byte.

### 3.1 Top level (retry loop — the `band_generator.gd:60-79` shape)

```gdscript
func generate(seed: int, cfg: CaveBandConfig, rc: RunConfig = null) -> Band:
	EventBus.band_generation_started.emit(seed)     # telemetry parity with the socket path
	var attempt := 0
	var best: Band = null
	while attempt < cfg.max_attempts:
		var attempt_seed := seed if attempt == 0 else _derive_seed(seed, attempt)
		var band := _generate_once(attempt_seed, cfg)
		band.requested_seed = seed
		band.resolved_seed = attempt_seed
		if best == null or _floor_count(band) > _floor_count(best):
			best = band                              # largest-floor fallback (mirrors "largest band seen")
		if _floor_count(band) >= cfg.min_floor_cells:
			EventBus.band_generated.emit(seed, band.pieces.size())
			return band
		attempt += 1
	EventBus.band_generation_failed.emit(seed, &"undersized")
	if best != null:
		EventBus.band_generated.emit(seed, best.pieces.size())
	return best
```

### 3.2 One deterministic attempt

```gdscript
func _generate_once(seed: int, cfg: CaveBandConfig) -> Band:
	# DETERMINISM: reset the shared stream before any draw (band_generator.gd:88).
	RNG.seed_from(seed)

	var w := cfg.grid_width
	var h := cfg.grid_height
	# Grid as PackedByteArray, index y * w + x. WALL = 1, FLOOR = 0.
	# The border ring is FORCED WALL (never rolled): the cave is enclosed at the
	# DATA level by construction — the T1 sealing seam's foundation (§8).
	var grid := _seeded_fill(w, h, cfg.fill_pct)      # the ONLY RNG block
	for _i in cfg.smooth_passes:
		grid = _smooth(grid, w, h, cfg.wall_threshold)  # pure integer CA, RNG-free
	var regions := _flood_regions(grid, w, h)          # fixed scan order, sorted output
	_keep_and_carve(grid, w, h, regions, cfg)          # keep-largest + deterministic carve
	var entry_cell := _select_entry(grid, w, h)        # deterministic anchor (§3.5)
	return _emit_band(grid, w, h, entry_cell, cfg)     # chunk -> synthetic pieces (§3.6-3.7)
```

**`_seeded_fill`** — the one RNG block, fixed scan order, integer compare:

```gdscript
func _seeded_fill(w: int, h: int, fill_pct: int) -> PackedByteArray:
	var grid := PackedByteArray()
	grid.resize(w * h)
	for y in h:
		for x in w:
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				grid[y * w + x] = WALL                       # forced border, no draw
			else:
				grid[y * w + x] = WALL if RNG.randi_range(0, 99) < fill_pct else FLOOR
	return grid
```

**`_smooth`** — double-buffered (never in-place: in-place smoothing reads half-updated neighbours and
is scan-order-dependent — a classic CA determinism *and correctness* bug), out-of-grid neighbours count
as wall, border stays forced wall:

```gdscript
func _smooth(src: PackedByteArray, w: int, h: int, wall_threshold: int) -> PackedByteArray:
	var dst := PackedByteArray()
	dst.resize(w * h)
	for y in h:
		for x in w:
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				dst[y * w + x] = WALL
				continue
			var walls := 0
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0: continue
					if src[(y + dy) * w + (x + dx)] == WALL: walls += 1
			# b3's stated rule: wall when >= threshold (default 5) of 8 neighbours
			# are wall, floor otherwise. Pure integer compare.
			dst[y * w + x] = WALL if walls >= wall_threshold else FLOOR
	return dst
```

### 3.3 Flood regions (order-stable — the b3 gotcha, answered)

Scan cells in the fixed (y, x) order; BFS each unvisited FLOOR cell with an array-based queue pushing
4-neighbours in the fixed N/E/S/W step order (`connectivity_guarantee.gd:35-36`'s `_STEPS` order,
reused for consistency). Regions are therefore **discovered in deterministic order** and each region's
cell list is in deterministic BFS order. Each region records: `cells: Array[int]` (grid indices),
`size`, and `anchor` = its (y, x)-minimal cell (= its first-discovered cell, since discovery scan is
(y, x)-ordered). The region list is then sorted **by size descending, tie-broken by anchor (y, x)
ascending** — a total order, so "largest" and "secondary, in order" are unambiguous on every seed.
No Dictionary drives any ordered decision (GDScript dicts are insertion-ordered, but arrays + explicit
sorts make order-stability *visible* in review, per the breakdown's contract).

### 3.4 Keep-largest, discard-small, carve-the-rest

Processing order is load-bearing and fixed:

1. **Keep** `regions[0]` (the largest) — the main floor.
2. **Discard** every secondary region with `size < cfg.min_region_cells`: fill its cells to WALL.
   (Discard before carving, so a carve path never targets a doomed region.)
3. **Carve** each surviving secondary region into the main region, **in sorted-region order**: an
   L-shaped corridor from the region's `anchor` to its **nearest main-region cell** (minimal Manhattan
   distance; ties broken by (y, x) ascending — scan the main region's cell list, which is itself in
   deterministic order). The L walks the x axis first, then y (fixed rule), setting each cell on the
   path — thickened to `carve_width` on the perpendicular axis (extending toward +y/+x, fixed rule) —
   to FLOOR, clamped inside the border ring. After each carve, the carved region's cells are appended
   to the main-region cell list (so a later region may connect via an earlier carve — nearest-cell
   search must include them for stable results).

This is the deterministic **grid-level carve**: pure integer geometry, zero RNG, no retry. A carve can
only add floor, so it can never disconnect anything; step 2 can only remove whole isolated regions, so
the invariant "the emitted floor set is one 4-connected component" holds **by construction** — and is
still asserted, twice (pipeline ASSERT §4.1 + the test §5).

### 3.5 Entry anchor + deepest anchor

- **Entry** = the **west-most floor cell** of the final floor set: minimal x, tie-broken by minimal y.
  Deterministic, edge-biased (an entry in the cave's middle would halve the effective depth axis), and
  orientation-stable across seeds ("home is the way you came" gets a consistent compass direction —
  a small mercy for the b3 disorientation watch-item, TG2's item, not T0's).
- **Deepest** = run one RNG-free cell BFS from the entry cell over the floor set (fixed N/E/S/W step
  order); the deepest cell is the max-distance cell, ties broken by (y, x) ascending.
  `band.deepest_piece` = the synthetic piece owning that cell (materialisation places the exit gate at
  `deepest_piece` — T1 verifies). `DepthGrader.grade` later recomputes piece-level depth independently;
  the two agree on the far chunk by construction (chunk-hop BFS is a coarsening of cell BFS — exact
  agreement is not required, only that `deepest_piece` is deterministic and genuinely far; the test
  asserts `deepest_piece.depth_index == band.max_depth` after grading).

### 3.6 Synthetic pieces — the chunk partition (the load-bearing design call)

Per §1.2, one mega-piece breaks everything downstream (`max_depth = 0`, one loot roll, zero encounter
rooms). And "one piece per flood region" (the exploration's throwaway suggestion) collapses to one
piece *after* keep+carve unifies the floor. So T0 partitions the floor into **grid-aligned chunks**:

- Tile the grid into `chunk_cells × chunk_cells` tiles anchored at grid origin (0, 0). Iterate chunks
  in fixed (chunk-y, chunk-x) order.
- Every chunk containing **≥ 1 floor cell** becomes one synthetic `PlacedPiece`; floorless chunks are
  skipped (they are not part of the band).
- Chunk rects are disjoint by construction ⇒ the overlap-free invariant holds trivially.
- Piece order: **the entry chunk first** (the `Band.entry_piece = pieces[0]` convention,
  `band.gd:21`), then all remaining chunks in the fixed scan order.

Why chunks and not chamber segmentation (distance-transform watershed into "rooms" and "throats"):
chunks are ~20 lines, trivially order-stable, and give `DepthGrader` a uniform-granularity hop metric
(chunk-hops ≈ distance / chunk_cells — a real, monotone depth axis). Watershed segmentation would give
semantically prettier "rooms" for encounter placement at ~5x the code and a genuinely fragile
determinism surface (float distance fields, plateau tie-breaking) — exactly the wrong trade for the
version whose thesis is *cheap* backends. §9 Q1 keeps the door open; chunks are the recommendation.

What each synthetic `PlacedPiece` carries:

| Field | Value | Consumer it satisfies |
|---|---|---|
| `piece_id` | content-hashed id, §3.7 | `Band.fingerprint()` |
| `instance` | `null` | JunkPlacer falls back to 16px (`junk_placer.gd:201`); SocketSealer no-ops (`socket_sealer.gd:95-96`); T1 builds real geometry |
| `offset_cell` | the chunk's origin cell (grid coords are band-global; no translation) | fingerprint; `room_key = str(p.offset_cell)` (`encounter_builder.gd:366`) — unique per chunk by construction |
| `floor_cells` | the chunk's floor cells, band-global, in fixed (y, x) scan order | DepthGrader/JunkPlacer/EncounterBuilder/ConnectivityGuarantee — the entire downstream |
| `footprint_cells` | **all** in-grid cells of the chunk rect (floor + wall) | `Band.occupy`; overlap test; gives T1 per-piece wall ownership (§8) |
| `open_sockets` | `[]` | nothing (sockets don't exist) |
| `mated_socket_index` | `-1` (the entry-piece convention, `placed_piece.gd:40`) | fingerprint (constant, honest: nothing mated) |
| depth fields | left at defaults; `DepthGrader` assigns | as today |

`Band` assembly: `pieces` in the order above; `band.occupy(p)` per piece; `entry_piece = pieces[0]`;
`deepest_piece` per §3.5; `open_sockets = []`; seeds set by the retry loop (§3.1).

### 3.7 Synthetic-piece fingerprint identity (breakdown OQ5 — the design's answer)

`Band.fingerprint()` hashes only `piece_id@offset_cell#mated` (`band.gd:58-62`). For authored pieces
the id+offset pair pins the full layout because a `piece_id` *implies* its geometry. A synthetic chunk
with a fixed id (`&"cave_chunk"`) would **not**: two seeds producing the same set of floor-bearing
chunk origins but different floor shapes *inside* the chunks would collide to one fingerprint —
the determinism bar would go blind exactly where the CA does its work.

**Design: content-hashed piece ids.** Each synthetic piece's id encodes its own floor content:

```gdscript
# chunk-LOCAL floor cells (band-global minus chunk origin), already in fixed
# (y, x) scan order from the chunk walk — no re-sort needed, but sort anyway
# (cheap, makes the invariant explicit).
var parts := PackedStringArray()
for c in local_floor_cells:
	parts.append("%d,%d" % [c.x, c.y])
var content_hash := "|".join(parts).sha256_text().substr(0, 12)
placed.piece_id = StringName("cave_" + content_hash)
```

Properties: (a) `fingerprint()` now pins the **entire cave floor**, byte-for-byte, with zero change to
`band.gd` — the identity scheme lives wholly in the backend; (b) identical chunk *shapes* at different
offsets share an id (fine — `@offset` disambiguates, exactly as repeated catalog pieces do today);
(c) diff-seed ⇒ diff floor ⇒ diff ids ⇒ diff fingerprint, making the variation assertion robust;
(d) nothing downstream keys behaviour off `piece_id` (verified: EncounterBuilder keys rooms off
`offset_cell`, JunkPlacer/DepthGrader never read it), so an opaque hash id is safe. The alternative —
fixed id + relying on `floor_fingerprint()` as the cave bar — is rejected: `floor_fingerprint()` is
documented as the *supplementary* bar that must never replace `fingerprint()` in control assertions
(`band.gd:70-75`), and T0 should not promote it. §9 Q2 carries the residual naming/length choices.

---

## 4. Pipeline dispatch + `validate()` cave branch

### 4.1 `band_pipeline.gd` — the dispatch diff

The Phase-A guard block (`band_pipeline.gd:44-48`) is replaced by dispatch; the socket path's
statements stay **verbatim in the same order** (parity-pinned). Illustrative diff shape:

```gdscript
	# --- Wiring guards (M1.10: socket + cave wired; scatter still fail-loud) --
	if profile.backend != "socket" and profile.backend != "cave":
		push_error("BandPipeline: backend '%s' is not wired in M1.10 (profile '%s')"
				% [profile.backend, profile.id])
		return null
	if not profile.principles.is_empty():
		push_error(...)   # unchanged
		return null
	if profile.backend == "cave" and not profile.flavors.is_empty():
		# M1.10 scope: SetPieceInject/WearDecay are socket-built (they write authored
		# piece TileMapLayers); a flavor-bearing cave profile is an authoring error
		# until a cave-aware stage exists (breakdown OQ10: cave flavors ship EMPTY).
		push_error("BandPipeline: profile '%s' is a cave band with flavor stages — none are cave-wired in M1.10"
				% profile.id)
		return null
	for fcfg in profile.flavors:
		...               # unchanged (socket-only by the guard above)

	# --- STAGES 1+2: backend dispatch ------------------------------------
	var band: Band
	if profile.backend == "cave":
		var cave_cfg := profile.backend_config as CaveBandConfig
		band = CaveBackend.new().generate(seed, cave_cfg, rc)   # rc accepted, ignored (§3.0)
	else:
		# SOCKET: the existing block, verbatim — catalog + I1 lvl swap + generate
		# (band_pipeline.gd:70-80 exactly as-is; byte-parity is test-pinned).
		var cfg := profile.backend_config as BandGenConfig
		var catalog: Array[ZonePieceData] = profile.piece_pool.pieces
		if rc != null and rc.lvl_enabled and profile.piece_pool_ext != null \
				and not profile.piece_pool_ext.pieces.is_empty():
			catalog = profile.piece_pool_ext.pieces
		band = BandGenerator.new().generate(seed, cfg, catalog, rc)
	if band == null or band.pieces.is_empty():
		push_error(...)   # unchanged
		return band

	# --- Post-backend invariant (cave only): cell-level connectivity ASSERT --
	# The backend guarantees one component by construction (§3.4); this is the
	# invariant's teeth at the pipeline seam, reusing the existing checker.
	# Fail-loud, never a silent fix (ASSERT posture, connectivity_guarantee.gd:14-16).
	if profile.backend == "cave":
		ConnectivityGuarantee.new().enforce(band, ConnectivityGuarantee.Mode.ASSERT)

	# --- flavor loop / grade / return-distance: UNCHANGED -----------------
```

Notes: (a) a `match` vs `if/else` is the programmer's call — behaviour-identical; (b) the docstring's
"backend '%s' is not wired in M1.9 (socket only …)" text updates to the M1.10 truth; (c) **zero cave
statements execute for a socket profile** (the `backend == "cave"` conditionals are the only additions
on that path — string compares, no draws, no state), so `band_greybox`/`band_two` byte-identity is
structural, and the parity test proves it anyway.

### 4.2 `band_profile.gd` — the `validate()` cave branch

Appended to the existing socket branch (`band_profile.gd:82-95`), same fail-loud style:

```gdscript
	elif backend == "cave":
		if backend_config == null or not (backend_config is CaveBandConfig):
			problems.append("BandProfile '%s': cave backend needs a CaveBandConfig backend_config" % id)
		elif not (backend_config as CaveBandConfig).validate().is_empty():
			for p in (backend_config as CaveBandConfig).validate():
				problems.append("BandProfile '%s': %s" % [id, p])
		# piece_pool intentionally NOT required (no pieces to draw); a non-null
		# piece_pool on a cave profile is legal-but-inert (documentary).
		if archetype != "linear":
			push_warning("BandProfile '%s': archetype '%s' is ignored by the cave backend (the CA IS the topology)"
					% [id, archetype])
```

with a small `CaveBandConfig.validate() -> PackedStringArray` guarding degenerate authoring (extents
≥ 8 in each axis; `fill_pct` in 0–100; `smooth_passes` ≥ 0; `wall_threshold` in 1–8; `chunk_cells` ≥ 2;
`carve_width` ≥ 1; `min_floor_cells` ≥ 1; `max_attempts` ≥ 1) — the `push_error + null` posture (S1
§10.1 Q7) via the pipeline's existing validate-then-fail flow. §9 Q6 covers the archetype-field wart.

---

## 5. `test_cave_backend` — the acceptance harness

**Files:** `Game/tests/test_cave_backend.gd` + `.tscn` (root `Node` + script — the standing shape).
Run: `godot --headless --path Game res://tests/test_cave_backend.tscn` (exit 0 = green). Same seed
matrix as the determinism suite (`[12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]`). The test
builds its cave profile + config **in code** (no fixture `.tres` — the P7 pattern), using a config
deliberately non-default on a couple of knobs so defaults-drift can't mask a knob being dead.

Assertion groups (mirroring `test_bandgen_determinism` C1–C5 + parity P-groups):

- **C1 — same seed ⇒ byte-identical fingerprint, twice**, per seed, through
  `BandPipeline.generate(cave_profile, seed)` (the real path — dispatch included in the bar), plus
  `floor_fingerprint()` equality (supplementary — proves the *floor*, not just the piece list,
  reproduces).
- **C2 — different seeds differ**: ≥ 2 distinct fingerprints across the matrix (with content-hash ids
  this is near-certain; assert anyway).
- **C3 — connectivity, both levels**: `BandGenerator.new().is_band_connected(band)` (the piece-level
  acceptance bar the breakdown names) AND `ConnectivityGuarantee.new().is_fully_connected(band)`
  (cell-level, strictly stronger) — per seed.
- **C4 — structural invariants**: no two pieces share a `footprint_cells` cell (disjoint chunks); every
  floor cell is inside the grid interior (border ring intact — no floor on the ring); `entry_piece ==
  pieces[0]` and its `floor_cells` contain the entry anchor; `mated_socket_index == -1` and
  `open_sockets` empty on every piece; `pieces.size() >= 2` (the depth axis exists);
  `deepest_piece.depth_index == band.max_depth > 0` after the pipeline's grade.
- **C5 — purity under RNG perturbation**: generate seed 424242, perturb (`RNG.seed_from(987654321);
  RNG.randi()`), generate again ⇒ identical fingerprint (retry-chain + fill-block purity — the
  `test_bandgen_determinism.gd:105-115` mirror).
- **C6 — region keep + carve determinism across a knob/seed matrix** (the breakdown's named bar): a
  second config with low `smooth_passes` + high `fill_pct` (maximally fragmenting — many secondary
  regions, so carve/discard actually exercises) run across the seed matrix, twice each ⇒ identical
  fingerprints; plus C3 connectivity on every one (proving carve genuinely unified the fragments —
  non-vacuity: assert at least one seed in this config produced > 1 raw region, via a test-visible
  region count or by asserting the fragmenting config's floor differs from its pre-carve size…
  simplest honest form: expose `last_region_count` as a public backend field set per attempt, read by
  the test; §9 Q9).
- **C7 — rc-invariance (cave ignores rc)**: `pipe.generate(cave_profile, seed, r4_on_config)` and
  `…lvl_on_config` fingerprints == the rc-null fingerprint, per seed — pins §3.0's decision so a
  future accidental rc read fails loudly here.
- **C8 — fail-loud guards**: cave profile with null / wrong-typed (`BandGenConfig`) `backend_config` ⇒
  null; cave profile with a flavor ⇒ null; degenerate config (e.g. `grid_width = 4`) ⇒ null;
  `backend = "scatter"` still ⇒ null (the remaining unwired backend).
- **C9 — socket-control regression (in-suite belt-and-braces)**: load `band_greybox.tres` +
  `band_two.tres`, one seed each through the pipeline, assert fingerprints equal a second generation
  in-run (the full byte-pins live in the existing suites, which the DoD runs anyway; C9 just makes
  this test self-containedly loud if dispatch broke the socket path).

**Existing-test edit (the one allowed):** `test_band_pipeline_parity.gd:253-257`'s P7 cave case
currently asserts the *wiring guard*. It updates to assert the new truth: a `backend = "cave"` profile
with **no/invalid config** returns null (fail-loud preserved), and the "unwired backend" case moves to
`"scatter"`. This is a deliberate, worklog-flagged edit to an acceptance test — the assertion's
*intent* (fail-loud on bad profiles) is preserved, its *fixture* tracks the wired reality. No other
existing test file is touched.

---

## 6. Files to create / touch

**Create (T0-owned):**
- `Game/systems/bandgen/cave_backend.gd` — the backend (§3).
- `Game/data/bands/cave_band_config.gd` — the config schema (§2).
- `Game/tests/test_cave_backend.gd` + `Game/tests/test_cave_backend.tscn` — the harness (§5).
- (+ the `.uid` files Godot mints on import — commit them.)

**Edit (T0 is this wave's designated single writer of both):**
- `Game/systems/bandgen/band_pipeline.gd` — the dispatch diff (§4.1).
- `Game/data/bands/band_profile.gd` — the `validate()` cave branch (§4.2).
- `Game/tests/test_band_pipeline_parity.gd` — the P7 fixture update ONLY (§5, flagged).

**Must NOT touch (contract):**
- `Game/scenes/game/main_game.gd` — T1's exclusive file (Wave 2). Materialisation of synthetic pieces
  is T1's; T0's band is proven headlessly.
- `Game/systems/bandgen/band_generator.gd`, `band.gd`, `placed_piece.gd`, `open_socket.gd`,
  `socket_sealer.gd`, `stages/*` — read-only. The synthetic-piece identity (§3.7) is deliberately
  designed to need **zero** `band.gd`/`placed_piece.gd` edits.
- `Game/systems/depth/*`, `Game/systems/spawning/*`, `Game/systems/event_bus.gd` (existing signals
  suffice, §3.1), `Game/data/run_config/*`, `band_greybox.tres`, `band_two.tres`.
- `Game/tests/test_bandgen_determinism.gd/.tscn` — never edited.

**Work-product contract:** branch `general-purpose/T0` in an isolated worktree (verify branch topology
before merge — the qa git-switch-leak memory); one worklog `worklogs/2026-MM-DD-T0-general-purpose.md`
naming the commit SHA(s), the **bespoke-code cost ledger** (expected order: backend ~220 lines + config
~45 + pipeline diff ~25 + validate branch ~15 — the ledger records actuals), and a Design deviations
section; commit messages prefixed `M1.10 T0:`.

---

## 7. Definition of done (restated + concrete)

1. `godot --headless --path Game res://tests/test_cave_backend.tscn` exits 0 (C1–C9).
2. `test_band_pipeline_parity.tscn` + `test_bandgen_determinism.tscn` exit 0 (determinism file
   untouched; parity file's only diff is the flagged P7 fixture update).
3. `band_greybox` + `band_two` fingerprints byte-identical through the pipeline (C9 + the existing
   suites + the RG-style verify run); all-off fp **`e943ac9c8bc1`** unmoved (no runtime call site
   changed — asserted anyway, per verify-before-reporting-done).
4. All other bandgen-adjacent suites green (`test_band_depth`, flavor/S5 suites, `tests/procgen/*`);
   `godot --headless --path Game --import` clean; smoke test green. (Suites run sequentially, never
   concurrently.)
5. Scope audit: the diff touches only §6's create/edit list (+ `.uid`s).
6. Worklog + commit SHA + cost ledger + deviations; task mirrored on `STATUS.md` + the board.

---

## 8. The T0/T1 seam — void sealing + materialisation contract (breakdown OQ4, T0's half)

What T0 **guarantees** (data-level, headlessly testable):

1. **Enclosure by construction:** the grid's border ring is forced WALL and every non-floor interior
   cell is WALL, so every floor cell's 4-neighbourhood is floor-or-wall — never "off-map void" — *in
   the grid data*. (C4 asserts the border-intact half.)
2. **Wall ownership:** `footprint_cells` = the full chunk rect (floor + wall), so every wall cell
   adjacent to floor is owned by some floor-bearing piece **except** walls whose chunk is floorless —
   which is why T1's materialisation must build from **floor/void adjacency** (the SocketSealer
   geometric rule: cap every floor cell's non-floor 4-neighbour), not from footprint ownership alone.
3. **`SocketSealer` needs no edit:** `_place_wall_cap` already early-returns on `instance == null`
   (`socket_sealer.gd:95-96`), so the as-built materialisation seal is a natural no-op on a
   pure-synthetic band and byte-identical (zero code change) for socket bands.

What is **T1's** (recorded here so the seam is explicit, per the breakdown's "Phase-2 design's call"):
building runtime greybox visuals + wall collision from `floor_cells`/`footprint_cells` (ColorRect/
Polygon2D vs generated TileMapLayer — breakdown OQ3, T1 researches); whether T1 mirrors the
floor-adjacency perimeter rule inside its synthetic-geometry builder or adds a geometry-keyed sealer
sibling; the min-corridor/player-scale check (T0 contributes `carve_width = 2` as the config floor for
*carved* throats; natural CA throats can still pinch to 1 — T1's check or a T0 widening pass is §9 Q8);
`cell_size_px` agreement between config, JunkPlacer's fallback, and the materialised scale.

**Recommendation to Phase 3 (OQ4 disposition):** backend guarantees data-level enclosure (above);
T1 owns all materialised sealing via the floor-adjacency rule; `SocketSealer` is left untouched and
naturally inert. No sealer generalization, no sealer sibling *in T0*.

---

## 9. Open Questions (for Phase-3 fresh-eyes resolution)

> Each with trade-offs + a recommendation. Vision/fun/tone/scope calls are flagged **needs Director
> review**; the rest resolve on technical merit. A **Resolved Decisions** section is appended below by
> the Phase-3 resolver before the build wave dispatches.

**Q1 — Synthetic-piece partition: grid chunks vs chamber segmentation vs region-per-piece?**
Region-per-piece degenerates to one piece post-carve (§3.6) — rejected on the evidence (one piece ⇒
`max_depth = 0` ⇒ zero encounters, one loot roll; `depth_grader.gd:47-49`,
`encounter_builder.gd:313-314`). Chamber segmentation (watershed over a distance field) gives
semantically real "rooms" but ~5x the code and a fragile float/plateau determinism surface. Grid
chunks (`chunk_cells = 8`) are ~20 lines, trivially order-stable, and give a uniform hop metric —
at the cost of "rooms" that are arbitrary squares (an encounter's `room_bounds`/per-room cap applies
to a chunk, not a chamber; two spawns in one chamber spanning two chunks double-dip the per-room cap
slightly). **Recommendation: grid chunks for M1.10**; revisit chamber segmentation only if TG2 says
cave encounters feel mis-clustered. *Technical — resolve on merit.*

**Q2 — Fingerprint identity residuals (breakdown OQ5).** §3.7's content-hashed ids are the design.
Residual calls: (a) hash truncation length — 12 hex chars (48 bits) per chunk: collision odds across
~40 chunks are negligible (~10⁻¹¹ per band) and the string stays log-readable; full 64-char digests
would bloat fingerprint input for nothing. (b) Should the id prefix be `cave_` or carry the profile id?
Bare `cave_` recommended — profile identity is not the *piece's* identity, and fingerprints are already
compared per-profile. (c) Confirm no consumer anywhere keys behaviour off `piece_id` beyond the
fingerprint (audited: EncounterBuilder uses `offset_cell` for `room_key`; JunkPlacer/DepthGrader never
read it; `RunConfig.CORRIDOR_PIECE_IDS` matching only fires in `_build_weight_table`, socket-only).
**Recommendation: 12-hex `cave_` prefix, as specced.** *Technical — resolve.*

**Q3 — Void-sealing seam ownership (breakdown OQ4).** Options: (i) backend emits materialisation-ready
wall data and T1 just instantiates; (ii) backend guarantees data-level enclosure, T1 derives walls from
floor/void adjacency (§8's design); (iii) generalize/extend `SocketSealer`. (i) makes the backend know
about materialisation (wrong layer, and T1 hasn't picked its geometry tech yet — breakdown OQ3);
(iii) is needless — the sealer is already inert on synthetic pieces via the `instance == null` return
(`socket_sealer.gd:95-96`), and touching it risks the socket controls for zero gain.
**Recommendation: (ii), per §8** — T0 guarantees enclosure in data; T1 owns materialised sealing;
`SocketSealer` untouched. *Technical (T0/T1 seam) — resolve on merit; byte-safety for socket bands is
the bar and (ii) achieves it with zero sealer diff.*

**Q4 — Is grid-level carve an acceptable reading of the breakdown's "deterministic CARVE (the
`ConnectivityGuarantee` stage's existing CARVE mode)"?** The existing CARVE mode is journal-LIFO
*revert* of a flavor stage's tile writes (`connectivity_guarantee.gd:75-81`) — inapplicable inside a
backend that has no prior state to revert to. §3.4 mirrors the carve *concept* (deterministically cut
minimal connectors, sorted order, zero RNG) at the grid level, and §4.1 **reuses** the stage's checker
(`is_fully_connected` via `Mode.ASSERT`) as the pipeline invariant — reuse where the machinery fits,
deterministic mirror where it can't. The alternative — forcing the backend to emit a journal so
`enforce(CARVE)` could "revert" disconnection — inverts the semantics (reverting a cave's fill doesn't
connect anything). **Recommendation: ratify §3.4 + §4.1 as the compliant reading.** *Technical —
resolve; flag in the worklog as an interpretation of breakdown wording.*

**Q5 — Does the cave backend really ignore `rc` entirely?** Every as-built rc generation hook is
socket-interior (r4 branch rolls, lvl room-count/catalog swap, J4 corridor weights). The play preset
ships `lvl_enabled = true` — on a cave dive that must be a clean no-op at generation (C7 pins it).
Alternative: map `rc.lvl_room_count`-style levers onto grid extents for sweepability — rejected for
M1.10 (frozen knob model; a cave lever is a *new* knob by another name). Note the **downstream** rc
surface (junk `cell_size_override`/`loot_density_per_area`, `param_overrides`, `oppositions_enabled`)
still applies to cave bands unchanged — that's the call site's, not the backend's. **Recommendation:
ignore rc in the backend, keep the parameter for signature symmetry, pin with C7.** *Technical —
resolve.*

**Q6 — The `archetype` field on cave profiles.** The enum (`linear/branchy/hub/grid/lanes`,
`band_profile.gd:36`) has no cave-honest value. Options: (a) cave profiles author `"linear"` as an
ignored don't-care + `push_warning` on anything else (§4.2 — zero schema change); (b) add `"organic"`
to the enum (honest, but an enum extension ripples into S1-era validate()/docs for a field the cave
backend never reads). **Recommendation: (a) for M1.10**; revisit if a second non-socket backend makes
the archetype field genuinely polymorphic. *Technical/schema — resolve.*

**Q7 — The nook/roughness knob mechanism.** §2 makes `wall_threshold` (the CA rule threshold) the
roughness knob — under-smoothing via fewer passes + a lower threshold leaves more fringe pockets (the
b3 "under-smoothing" suggestion), all integer, zero extra code. Alternative: a dedicated post-smooth
roughen pass (seeded per-cell wall-nibbling draws in fixed scan order — deterministic but a second RNG
block whose draw count depends on the smoothed grid, complicating the purity story). **Recommendation:
`wall_threshold` + `smooth_passes` ARE the roughness surface for M1.10; no roughen pass.** Whether the
resulting nook density *feels* right is T3/TG2's tuning question on real configs — **the mechanism is
technical, the eventual values are Director-tuned at T3** (no Director review needed for T0 itself).

**Q8 — Natural 1-cell throats: T0 widening pass or T1 check?** Carved corridors are `carve_width = 2`,
but raw CA can produce organic 1-cell pinches; the player body (socket doorways are 2-cell) may not
fit. Options: (a) T0 adds a deterministic throat-widening pass (detect floor cells whose passage is
1-wide, widen toward the (y,x)-fixed side) — more backend code, guarantees playability in data;
(b) leave it to T1's min-corridor-width check / config floor (the breakdown assigns "player-scale
sanity" to T1) and accept that some T3 tuning configs get rejected by T1's check rather than fixed by
T0. **Recommendation: (b)** — keep T0 minimal, T1 owns player-scale (its DoD already says so); if T1's
check trips constantly at T3 tuning time, a widening pass is a contained T0 follow-up. *Technical —
resolve; mild scope edge (it moves work between tasks, inside the version).*

**Q9 — Test visibility for carve non-vacuity (C6).** Proving "carve determinism" non-vacuously needs
the test to know fragmentation happened pre-carve. Options: (a) a public `last_region_count` (or a
small stats dict) field on `CaveBackend`, set per final attempt — one line, test-only consumer, mild
API smell; (b) re-deriving regions in the test from a re-run of fill+smooth (duplicating CA code in
the test — drift risk); (c) trusting the fragmenting config's parameters (vacuity risk, the thing
BUG4's test explicitly refuses). **Recommendation: (a).** *Technical — resolve.*

**Q10 — Entry anchor rule.** §3.5 picks the west-most floor cell (min x, tie min y) for edge bias +
a stable compass identity across seeds. Alternatives: (y,x)-min (top-left — equally deterministic, no
directional story); a `CaveBandConfig` enum (`west/north/…`) for T3 to author (one more knob, no
current consumer needs it). **Recommendation: west-most, hardcoded; promote to config only if T3's
identity pitch wants a specific approach direction.** The *fictional* meaning of the entry direction
belongs to T3's identity pitch — **needs Director review only there, not for T0's mechanism.**

**Q11 — `pieces.size() >= 2` guard.** A pathological config (tiny grid, huge `chunk_cells`) can emit
one chunk — silently reintroducing the mega-piece failure (§1.2). Options: (a) backend `push_error` +
null-equivalent (return the band anyway + error — matching the "never crash generation" posture);
(b) a `CaveBandConfig.validate()` heuristic (grid area vs chunk area must permit ≥ 2 chunks — cheap,
catches it at authoring time); (c) both. **Recommendation: (c)** — validate() catches the authorable
case, a runtime `push_error` (not null — the band is still *playable*, just depth-degenerate) catches
the emergent one; C4 asserts ≥ 2 on the test configs regardless. *Technical — resolve.*

---

*Spec authored for M1.10 T0 (the second generation backend). Design-only — no code, no `.tres`, no
branch. The programmer builds against this after Phase 3 folds a **Resolved Decisions** section in
below. Deviations from the committed design go to `design/DESIGN_DEVIATIONS.md` for the Wave-1
close-out sweep.*

---

## 10. Resolved Decisions (Phase 3 — fresh-eyes resolution, 2026-07-04)

Resolved by a Phase-3 fresh-eyes agent (not this doc's author), after re-reading
`M1.10_Breakdown.md`, the sibling seam docs (`T1_cave_materialisation.md` §2.2/§2.4/§2.6/§2.7,
`T3_band_three.md` §3.3/§4.2/OQ5/OQ6), and spot-verifying every load-bearing as-built claim against
the working tree (`main` @ `303f14e`). **These resolutions are BINDING and override the doc body
where they conflict** (specifically: §8/§9 Q3's "sealer naturally inert" framing, §9 Q8's
recommendation, §4.1's cave-flavor pipeline guard, and §3.5/§3.6's entry-anchor/ordering details are
amended below). No open item blocks the Wave-1 build dispatch. **Zero items need Director review for
T0** — this task's surface is wholly technical; the version's vision/fun/tone calls live in
T2a/T2b/T3's queues.

### 10.0 Verification notes + claim corrections

- **Spot-verified accurate** (2026-07-04): Phase-A wiring guard `band_pipeline.gd:45-48`
  (`backend != "socket"` → `push_error` + null); socket backend block + I1 catalog swap `:70-80`
  verbatim as quoted; flavor loop + `ConnectivityGuarantee` CARVE/ASSERT `:90-107` (doc says
  `:93-107` — the guard is at `:90`; trivial); tail grade + return distance `:112-113`;
  `_stage_seed`/`_mix` `:143-151`; zero-RNG pipeline docstring `:14-19`. Generator: retry loop
  `band_generator.gd:60-79`; reseed-first `RNG.seed_from(seed)` `:88`; `deepest_piece = placed`
  `:132`; `_derive_seed`/`_hash_combine` `:352-362`; socket default width 2 `:399`; `_make_placed`
  always instantiates a scene `:413-417` (so `instance == null` is unreachable on the socket path —
  T1's load-bearing observation, confirmed). `Band.fingerprint()` `band.gd:58-62` hashes only
  `piece_id@offset#mated`; `floor_fingerprint()` `:76-88` documented supplementary-only `:70-75`;
  `entry_piece = pieces[0]` convention `:21`. `PlacedPiece` fields at the cited lines.
  `SocketSealer` geometry-keyed `:16-26`, RNG/fingerprint discipline `:28-35`, floor-set + cap walk
  `:57-84`, `_place_wall_cap` early-return on `owner.instance == null` `:94-96`.
  `ConnectivityGuarantee.is_fully_connected` cell-level flood `:41-62`; `enforce` ASSERT/CARVE
  journal-LIFO `:68-81`; `_STEPS` N/E/S/W `:35-36`; ASSERT posture "push_error, band returned as-is,
  never crash" `:14-24`. `BandProfile.backend` enum with `"cave"` declared `band_profile.gd:26`;
  socket-only `validate()` branch `:82-95` (requires `BandGenConfig` + non-empty `piece_pool` +
  linear/branchy archetype — exactly what the cave branch must NOT require). `DepthGrader`:
  piece-index BFS off sorted adjacency `:83-104`, `max_depth` `:47`, one-piece band → `depth_norm
  0.0` `:49`. `JunkPlacer`: per-piece `expected_count(depth_norm)` roll `:62-75`, instance-null
  fallback 16 `:198-201`, and it (y,x)-sorts each piece's `floor_cells` itself before use — per-piece
  list order never reaches the junk stream. `EncounterBuilder`: `BASE_CREDITS = 24`, `instability()`
  `1.0 + 0.15·(depth−1)`, deck budget floor, `min_band` gate, entry-safety `depth_index <= 0` skip
  (both lanes), demand formula, neutral-card skip, `room_key = str(p.offset_cell)`,
  `_floor_bounds_world` — all as cited. EventBus signal signatures match §3.1's pseudocode exactly
  (`band_generation_started(seed)`, `band_generated(seed, piece_count)`,
  `band_generation_failed(seed, reason: StringName)` — `event_bus.gd:39-41`). `RNG.seed_from`
  exists (`rng.gd:15`). Parity P7 cave case `test_band_pipeline_parity.gd:252-257` asserts the
  wiring guard as described; determinism seed matrix + retry-purity perturbation check
  (`test_bandgen_determinism.gd:36`, `:105-115`) as quoted. `data/bandgen_config.gd` and
  `data/bands/` exist as described.
- **Correction 1 — the `piece_id` consumer audit (§3.7(d) / §9 Q2(c)) is incomplete.** The claim
  "nothing downstream keys behaviour off `piece_id` beyond the fingerprint" is wrong as stated:
  **`main_game.gd:590` and `:649`** filter pieces via `_is_corridor(p.piece_id)` when
  `rc.r1_density_rooms_only` is on, and **`main_game.gd:891`** classifies piece kind for the R4
  junction map / J4 `corridor_summary` telemetry — all via `RunConfig.CORRIDOR_PIECE_IDS.has(...)`
  (plus `band_generator.gd:261` in the weight table, socket-only as the doc says). **The conclusion
  survives:** synthetic `cave_<hash>` ids are never in `CORRIDOR_PIECE_IDS`, so every cave chunk
  classifies as "room" — the correct cave-honest classification (T1 §2.1 independently records the
  `corridor_frac = 0` telemetry note for TG2). Opaque content-hash ids remain safe; the audit is
  corrected, the design unchanged.
- **Correction 2 — "SocketSealer is naturally inert on cave bands" (§1.2 bullet, §8 item 3) is true
  only in T0's headless world and is NOT the shipping behaviour.** T1's ratified design (T1 §2.2–2.3)
  builds a runtime `ZonePiece` host with a `"Geometry"` TileMapLayer for every synthetic piece at
  materialise time — so `p.instance` is **non-null when the sealer runs**, and the sealer (verbatim,
  unedited) becomes the cave's **active wall-writer** (the entire WALL shell). T0's actual guarantees
  are unchanged (no sealer edit; data-level enclosure; headless pipeline tests see the no-op because
  no instance exists there), but §8's framing is superseded: the seam is "already generalized —
  sealer runs verbatim as the cave wall-writer," not "sealer no-ops on caves." See Q3.

### 10.1 The questions

- **Q1 — Synthetic-piece partition.** **RESOLVED: grid chunks (`chunk_cells`, default 8), as
  specced.** The evidence in §1.2 is verified and decisive (one piece ⇒ `max_depth = 0` ⇒ zero
  encounter spawns + one loot roll; region-per-piece collapses to one piece post-carve). Watershed
  segmentation is the wrong trade for the cheap-backend thesis. The chunk-as-room per-room-cap
  imprecision is accepted and TG2-watched. **Amendment (reconciles T1 T0-C1):** the acceptance bar
  for chunk granularity is not just `pieces.size() >= 2` — C4 upgrades to assert
  **`band.max_depth >= 4` on the default config across the full seed matrix** (T1's hard input
  contract; its `test_cave_materialise` M4 re-asserts the same bar end-to-end). If a default-config
  seed grades shallower, tune `chunk_cells`/grid extents at T0, not at T1.

- **Q2 — Fingerprint identity residuals.** **RESOLVED: 12-hex `cave_` prefix, as specced.**
  (a) 48 bits/chunk is ample and log-readable; (b) bare `cave_` — profile identity is not piece
  identity; (c) ratified **with Correction 1 folded in**: `piece_id` consumers exist
  (`main_game.gd:590/649/891` via `CORRIDOR_PIECE_IDS`) but non-membership yields the correct "room"
  classification for every cave chunk, so opaque ids are safe. The content-hash scheme stands: it
  pins the entire cave floor through `fingerprint()` with zero `band.gd`/`placed_piece.gd` edits,
  and `floor_fingerprint()` stays supplementary (never promoted — `band.gd:70-75` honored).

- **Q3 — Void-sealing seam ownership (breakdown OQ4).** **RESOLVED: option (ii) as amended by T1
  §2.2 — and the T0/T1 positions reconcile cleanly.** T0 guarantees **data-level enclosure** (forced
  WALL border ring; every non-floor interior cell WALL; C4 asserts no floor on the ring) and touches
  no sealer code. T1 builds the synthetic instance with a `"Geometry"` TileMapLayer holding FLOOR
  tiles, and the **unedited `SocketSealer` runs verbatim as the cave's wall-writer** (its
  floor-adjacency cap rule IS the cave wall-front definition — T1 §2.2). No sealer edit, no sealer
  sibling, no bypass; socket-band byte-safety is trivial (the file does not change). §8 item 3 and
  §1.2's "inert" bullet are superseded per Correction 2; §8 items 1–2 (enclosure + wall ownership
  caveat) stand as T0's contract.

- **Q4 — The "existing CARVE mode" reading.** **RESOLVED: ratify §3.4 + §4.1 as the compliant
  reading.** Verified: `enforce(band, Mode.CARVE, journal)` is journal-LIFO revert
  (`connectivity_guarantee.gd:75-81`) — structurally inapplicable inside a backend with no prior
  state. The breakdown's operative intent is its own parenthetical: *deterministic, never
  retry-loops on the global stream* — §3.4's zero-RNG sorted-order grid carve satisfies it, and
  §4.1 reuses the stage's real machinery (`is_fully_connected` via `Mode.ASSERT`) as the pipeline
  invariant. ASSERT's fail-loud posture (push_error, band returned, never crash —
  `connectivity_guarantee.gd:14-24`) is kept as-is; the test (C3) is the hard bar. Worklog flags the
  interpretation, per the doc.

- **Q5 — rc ignored by the backend.** **RESOLVED: yes, as specced; C7 pins it.** Verified every
  as-built rc generation hook is socket-interior (`effective_room_count` at
  `band_generator.gd:111-113`, corridor weights `:55/:238-261`, r4 in `_select_frontier_index`).
  The play preset's `lvl_enabled = true` must be a generation no-op on caves — exactly what C7
  asserts. Downstream rc surfaces (junk overrides, `param_overrides`, `oppositions_enabled`) apply
  to cave bands at the call sites unchanged, as noted. Keep the `rc` parameter for signature
  symmetry.

- **Q6 — `archetype` on cave profiles.** **RESOLVED: option (a)** — cave profiles author
  `"linear"` as an ignored don't-care; the cave `validate()` branch never *requires* an archetype
  and `push_warning`s (never errors) on a non-linear value. No enum extension in M1.10. This
  satisfies T3's OQ6 coordination note verbatim (T3 authors `archetype = "linear"`,
  `piece_pool = null`; the §4.2 branch requires only a valid `CaveBandConfig`). Revisit `"organic"`
  only when a second non-socket backend makes the field genuinely polymorphic.

- **Q7 — Nook/roughness knob.** **RESOLVED: `wall_threshold` + `smooth_passes` ARE the roughness
  surface; no dedicated roughen pass.** All-integer, zero extra code, no second RNG block. The
  eventual *values* are T3/Director tuning, not T0's. **Cross-task consequence:** T3's sketched
  `nook_roughness: 0.5` (a float) does not exist and would violate the integer discipline — see
  Cross-task amendment 3.

- **Q8 — Natural 1-cell throats.** **RESOLVED: option (a) — the doc's recommendation (b) is
  OVERRIDDEN. T0 owns the player-scale guarantee, generation-side.** T1 §2.6's argument is
  structurally correct and wins on merit: widening mutates `floor_cells`, and `floor_cells` must be
  final before grading/fingerprinting — T1 *cannot* fix a pinch without breaking the determinism
  contract, so "leave it to T1's check" means any red seed forces a mid-version T0 follow-up anyway.
  Binding contract: after keep+discard+carve (§3.4), T0 runs a **deterministic, RNG-free
  player-scale pass**: compute the **2×2-open set** T (floor cells belonging to ≥ 1 all-floor 2×2
  block — T1 §2.6's traversability certificate: a 28 px player disc fits a 32×32 px block); reuse
  the §3.4 carve machinery (width ≥ 2, sorted component order, fixed L-rule) to connect every
  secondary T-component — and any floor component containing no T-cell — to the largest T-component
  (size desc, anchor (y,x) tiebreak). Post-pass invariant, test-asserted (new check **C10**): *T is
  non-empty, single-component, contains the entry anchor, and every floor cell is a member of or
  4-adjacent to T* (so scattered gates/loot on any floor cell are at most one cell from standable
  space). Carves only add floor ⇒ §3.4's connectivity-by-construction argument is preserved. Entry
  and deepest anchors are selected **after** this pass. T1's M6 spawn→gate 2×2-open bar remains the
  independent end-to-end proof. Estimated ledger cost ~30–40 lines — recorded honestly as bespoke
  backend code.

- **Q9 — C6 non-vacuity visibility.** **RESOLVED: option (a)** — a public `last_region_count: int`
  on `CaveBackend`, set from the returned attempt's pre-carve region tally; test-only consumer,
  mild API smell accepted (the BUG4 no-vacuous-test precedent outweighs it). The programmer may add
  sibling stats fields (e.g. `last_throat_carve_count` for C10's non-vacuity) if a check needs
  them — worklog-noted, same pattern.

- **Q10 — Entry anchor rule.** **RESOLVED: west-most, hardcoded — amended by Q8 and T1 T0-C2/C3:**
  the entry anchor is the **west-most cell of the 2×2-open set T** (min x, tie min y over
  T-members — not over raw floor), selected after the Q8 pass, so the spawn cell always has the
  player-scale clearance T1's M4 asserts. **Ordering amendment (§3.6):** the entry piece's
  `floor_cells` list the **anchor FIRST**, remainder in fixed (y,x) scan order — because
  `_entry_spawn_position` reads `entry_piece.floor_cells[0]` (`main_game.gd:1017`, T1 T0-C2).
  Verified safe: nothing is order-sensitive to a per-piece list head (`floor_fingerprint()` sorts
  globally, `fingerprint()` never reads floor cells, `ConnectivityGuarantee._sorted_first` computes
  its own (y,x)-min, `JunkPlacer`/`EncounterBuilder` re-sort per piece). All non-entry pieces stay
  pure (y,x) scan order. No config enum; the entry direction's *fictional* meaning stays T3's.

- **Q11 — `pieces.size() >= 2` guard.** **RESOLVED: option (c), both** — `CaveBandConfig.validate()`
  rejects configs whose grid/chunk geometry cannot yield ≥ 2 chunks (authoring-time catch), plus a
  runtime `push_error` (band still returned — playable-but-degenerate, matching the never-crash
  posture) if emission ever produces < 2 pieces; C4 asserts ≥ 2 (and now `max_depth >= 4`, per Q1)
  on the test configs.

### 10.2 Design amendments (binding edits to the doc body)

1. **§4.1 cave-flavor guard moves into `validate()` (§4.2).** The cave branch of
   `BandProfile.validate()` appends a problem on **non-empty `flavors`** for a cave profile (the
   breakdown's flavors-ship-EMPTY guardrail; T1 assumption (c) asks for exactly this). The pipeline
   already fail-louds on validate problems (`band_pipeline.gd:38-42`), making §4.1's separate
   cave+flavors pipeline guard unreachable — drop it from the dispatch diff (smaller diff, same
   fail-loud). C8's "cave profile with a flavor ⇒ null" assertion is unchanged (it now trips in
   validation).
2. **§3.2 attempt order gains the Q8 player-scale pass:** `_keep_and_carve` → **player-scale pass
   (Q8)** → `_select_entry` (over T, per Q10) → deepest BFS → `_emit_band`.
3. **§5 test matrix gains C10** (the Q8 invariant, per seed, both test configs) and upgrades C4's
   depth bar to `band.max_depth >= 4` on the default config (Q1). C6 may additionally use the Q9
   stats fields for non-vacuity.
4. **§6 ledger expectation updated:** backend ~220 → **~255** lines (the Q8 pass); everything else
   unchanged.

### 10.3 Cross-task amendments (for orchestrator adjudication)

1. **Breakdown T1-goal wording vs Q8 (task-seam move):** the breakdown assigns "player-scale sanity
   … via a min-corridor-width check or config floor" to T1; Q8 moves the *guarantee* to T0
   (generation-side, the only place `floor_cells` may mutate) while T1 keeps the *independent test
   bar* (M6). T1 §2.6 already argues for exactly this split — both Phase-2 docs now agree; the
   orchestrator should record the breakdown deviation at Wave-1 close-out.
2. **T1 T0-C3 ordering contract:** amend "floor_cells sorted (y,x) for order-stability" to "sorted
   (y,x), **except the entry piece, whose element 0 is the entry anchor**" (Q10). T1's M4
   (`spawn cell = entry_piece.floor_cells[0]`, 2×2-open) is then satisfied by construction.
3. **T3 §3.3/§4.2 knob names:** `nook_roughness: 0.5` (float) does not exist in the T0 schema and
   would break the integer discipline. T3 authors T0's real knobs — `wall_threshold` (int; THE
   roughness lever, lower = tighter/nookier) alongside `fill_pct`/`smooth_passes`, plus the fields
   T3's sketch omits (`chunk_cells`, `carve_width`, `min_floor_cells`, `max_attempts`,
   `cell_size_px` — all have T3-authorable defaults). Also: the config `.tres` lives under
   **`data/bands/`** (T0's schema-with-content convention), i.e.
   `data/bands/cave_config_band_three.tres`, not T3's sketched `data/cave_config_band_three.tres`.
4. **T1 assumption (a) confirmed:** the §4.1 dispatch leaves the tail grade + return-distance
   (`band_pipeline.gd:112-113`) running unconditionally, so cave bands return graded
   (`entry_piece`/`deepest_piece`/`max_depth` set) — no T1 escalation needed.
5. **T1 assumption (c) satisfied** via Design amendment 1 (flavor rejection lives in `validate()`,
   which T3's contract test calls directly).

### 10.4 NEEDS DIRECTOR REVIEW

**None from T0.** Every T0 question resolves on technical merit. For the record, the two items the
doc body already routes elsewhere: the *felt* nook density (Q7's knob **values**) is T3's
Director-tuned authoring, and the entry direction's *fictional* meaning (Q10) belongs to T3's
identity pitch — both are on T3's Director queue (its D1/OQ5), not T0's.
