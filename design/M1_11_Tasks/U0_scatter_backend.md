# U0 — ScatterBackend: open-field arena generator + `ScatterBandConfig` + pipeline backend dispatch — Expanded Design Spec

**Milestone:** M1.11 (Third Backend + Open-Field Band + Ranged Oppositions) · **Workstream:** bands · **Wave:** 1 (parallel worktree, alongside U2a/U2b)
**Task id:** U0 · **blockedBy:** none · **Blocks:** U1 (materialisation verify), U3 (`band_four.tres`)
**Assignee:** general-purpose (programmer)
**Author:** Phase-2 per-task design (2026-07-06) · **Status:** Phase-2 draft — awaiting Phase-3 fresh-eyes resolution of §9

> **What this doc is.** The Phase-2 design for U0 per `M1.11_Breakdown.md` §"Wave 1" — the third and
> last *declared* generation backend (`"scatter"` has sat in the `BandProfile.backend` enum since
> M1.9, `data/bands/band_profile.gd:26`), answering M1.10 TG3's standing "ScatterBackend next?"
> watch-item and the Director's 2026-07-06 directive ("another level with a different procedural
> gen, as different as possible"). It expands the breakdown's U0 contract into a config schema, the
> arena + order-stable poisson cover sampler with its determinism discipline, the
> connectivity-by-construction argument, the chunk-partition reuse, the `band_pipeline.gd` dispatch
> diff, the `validate()` scatter branch, and the acceptance-test plan. It is **design only** — no
> code, no `.tres`, no branch ships with this doc. The programmer builds against it after Phase 3
> resolves §9. Structure and rigor mirror the T0 precedent
> (`design/M1_10_Tasks/T0_cave_backend.md`, incl. its §10 Resolved-Decisions shape).

---

## 0. Hard constraints (read first)

From the breakdown's scope guardrails + cross-cutting contracts. Non-negotiable:

- **FOUR controls byte-identical.** The all-off `RunConfig` fingerprint **`e943ac9c8bc1`**, the
  `band_greybox` fingerprint, the `band_two` fingerprint, and — new this version — the
  **`band_three`** (cave) fingerprint must be untouched at every wave boundary. Scatter code is
  reachable **only** through a `backend == "scatter"` profile — no scatter statement executes on
  any socket or cave path. `test_band_pipeline_parity` + `test_bandgen_determinism` +
  `test_cave_backend` + `test_band_three_profile` are the proof and are never edited to pass
  (§5's one flagged comment-only exception is assertion-preserving).
- **Scatter determinism contract:** `(profile + seed + rc)` → same `Band.fingerprint()` twice,
  byte-for-byte, forever. Reseed via the existing `RNG.seed_from(seed)` discipline
  (`cave_backend.gd:67`, `band_generator.gd:88` precedent); **all sampling is order-stable**
  (sorted/fixed candidate order, fixed accept/reject sequence — the exploration's called-out
  scatter gotcha, the sibling of M1.10's sorted-flood-regions rule); connectivity is guaranteed
  **by construction** (min-spacing + clear-lane + border-margin rules — cover stamping can never
  disconnect the floor, §3.3) or by **deterministic CARVE** — never retry-loops on the global
  stream (§9 Q6 argues no carve is needed at all; the pipeline ASSERT + tests are the teeth).
- **File scope:** U0 touches **only** `Game/systems/bandgen/` + `Game/data/bands/*.gd` schema + its
  new tests. **NOT `main_game.gd`** (U1 is this version's sole `main_game.gd` writer; a test drives
  the pipeline directly). `band_pipeline.gd` + `band_profile.gd` are U0's exclusive files this wave
  (single-writer rule). `cave_backend.gd` / `cave_band_config.gd` are **read-only** — the
  band_three control's byte-safety is structural because those files do not change (§9 Q8).
- **Synthetic pieces carry `floor_cells`** so `Band` / `fingerprint()` / the whole downstream stay
  backend-agnostic (the M1.10 T1 gift: `_build_synthetic_piece`, `main_game.gd:830-876`, hosts any
  `floor_cells`-carrying, instance-null piece — U1 verifies the free ride, U0 changes nothing
  there). **Cover cells are NON-floor** (stamped WALL in the grid), so the unedited `SocketSealer`
  — the single wall-writer for every backend — caps every cover footprint and the arena perimeter
  for free (`socket_sealer.gd:57-84`; U1's headline zero-line verification).
- **No new opposition machinery, no save-schema change, no `RunConfig` knob** — the frozen knob
  model holds; the arena's knobs live in `ScatterBandConfig` (profile content, not run levers).
- **Typed GDScript; integer math on every branch-affecting comparison** (the B2 discipline,
  transposed twice already — `cave_band_config.gd:9-14`). Density/bias are integer percents
  compared against `RNG.randi_range(0, 99)`; no float ever touches the layout path.
- **Headless tests run as SCENES** (`godot --headless --path Game
  res://tests/test_scatter_backend.tscn`), never `--script`, never concurrently with another
  headless godot (import-lock).
- **Worklog carries the bespoke-code cost ledger** (files + line counts of non-data, non-test
  code) — the N=3 trend line IS the scalability answer UG3 judges. Backend #3's target: cheaper
  than backend #2 (~255 lines actual for the cave).

---

## 1. Research — why this task, what exists, what changes

### 1.1 Why this task

M1.9 proved "new content on existing machinery is data"; M1.10 proved a genuinely different
generator slots in behind `BandPipeline` and, en route, made materialisation backend-agnostic.
M1.11 must prove the pattern is now *routine* — that backend #3 costs **less** than backend #2 did.
The `ScatterBackend` is the natural candidate: it is the third and last *declared* backend
(`band_profile.gd:26` — the enum has carried `"scatter"` with a fail-loud guard since M1.9), the
architecture exploration already sized it (*"`ScatterBackend` (new, ~80 lines): one large arena
floor + poisson-disk cover stamping"*, `0-scalable-band-generation-system.md` §"Multi-backend
behind one interface"), and it is the **maximal experiential contrast**: the b1 exploration's
defining property is **long sightlines** — *"from most standing spots you can see — and be seen —
across the whole space"* — the spatial opposite of both shipped generators (socket room-graph =
doorway-reading; CA caverns = low-sightline nooks). It is also the host archetype the version's two
ranged oppositions (U2a Lobber, U2b Sentry) *need* to read as fair, exactly as the cave's bad
sightlines were what the Ambusher/Burrower needed.

Two things changed since the b1 exploration was written, and both make U0 **cheaper** than b1
feared:

1. **b1's "one large arena piece with edge sockets" framing is obsolete.** b1 predates the backend
   seam — it proposed smuggling the arena through the socket assembler as an authored mega-piece
   plus a `JunkPlacer`-style salted cover pass. Post-M1.10, the honest shape is a peer backend:
   emit the arena as synthetic pieces exactly as the cave does, ride `BandPipeline` dispatch, and
   the "needs a genuinely new placement subsystem" cost b1 flagged shrinks to *one sampler
   function* — everything else (chunking, synthetic ids, entry anchoring, sealing, grading,
   population) is the proven M1.10 machinery.
2. **b1's "an arena is a single hop" depth worry is pre-answered.** The cave's chunk partition
   (content-hashed synthetic piece ids, `chunk_cells = 8`, the `max_depth >= 4` bar) exists
   precisely because one mega-piece zeroes the depth economy — `max_depth = 0`, `depth_norm = 0.0`
   everywhere (`depth_grader.gd:47-49` per T0's verified audit), one shallow loot roll
   (`junk_placer.gd:62-74`), zero encounter spawns (`encounter_builder.gd:313-314` skips
   `depth_index <= 0`). U0 reuses the identical chunking idiom on the arena floor (§3.4).

### 1.2 What exists (as-built anchors, verified 2026-07-06)

- **The seam, one value left.** `BandProfile.backend` declares `("socket", "cave", "scatter")`
  (`data/bands/band_profile.gd:26`). The pipeline's wiring guard fail-louds on anything not
  socket/cave (`systems/bandgen/band_pipeline.gd:51-54`): `if profile.backend != "socket" and
  profile.backend != "cave": push_error(...); return null` — U0 replaces this guard with real
  dispatch, mirroring the cave arm (`band_pipeline.gd:73-77`:
  `CaveBackend.new().generate(seed, cave_cfg, rc)`). `BandProfile.validate()` has socket
  (`band_profile.gd:82-95`) and cave (`:96-113`) branches; U0 adds the scatter branch (§4.2) —
  the cave branch is the pattern, including the **flavors fail-loud living in validate()**
  (`:104-109`, the M1.10 Phase-3 amendment-1 location) and the archetype `push_warning`
  don't-care (`:110-113`).
- **The proven backend pattern to mirror — `CaveBackend`** (`systems/bandgen/cave_backend.gd`):
  - *Seeding discipline:* `RNG.seed_from(attempt_seed)` as `_generate_once`'s first act (`:67`);
    **all randomness in one block** with fixed scan order (`:83-93`), every subsequent step a pure
    integer function of the grid (docstring `:14-23`).
  - *Order-stable everything:* flood regions discovered in fixed (y, x) scan order with N/E/S/W
    steps matching `ConnectivityGuarantee._STEPS` (`:32-35`), sorted size-desc / anchor-(y,x)-asc
    total order (`:154-164`); deterministic L-carve (`:212-227`); the 2×2-open traversable set T
    (`:274-285`) and its single-component player-scale guarantee (`:243-269`).
  - *Entry-anchor contract (M1.10 amendments 2-3):* entry = west-most cell of T (min x, tie min y —
    `:359-371`); the entry chunk **front-positions the anchor as `floor_cells[0]`**
    (`:444-450`) because `_entry_spawn_position` reads `entry_piece.floor_cells[0]`
    (`main_game.gd:1017` per T0 §10.1 Q10); all other pieces stay pure (y, x) scan order.
  - *Chunk partition + content-hashed synthetic ids:* one `PlacedPiece` per floor-bearing
    `chunk_cells × chunk_cells` tile, entry chunk first (`:376-418`); `piece_id =
    "cave_" + sha256(chunk-LOCAL floor cells sorted (y,x)).substr(0,12)` (`:460-472`) so
    `fingerprint()` pins the entire floor with **zero `band.gd` edits**; `instance = null`,
    `open_sockets = []`, `mated_socket_index = -1`, `footprint_cells` = the full chunk rect
    (`:421-457`).
  - *`deepest_piece`* replicates DepthGrader's piece adjacency + BFS so
    `deepest_piece.depth_index == band.max_depth` after the pipeline's grade (`:479-521`).
  - *Never-crash posture:* < 2 pieces → `push_error` but return the band (`:412-417`); Q9-style
    test-visible stats fields (`last_region_count`, `last_throat_carve_count`, `:37-39`).
- **The config-schema precedent — `CaveBandConfig`** (`data/bands/cave_band_config.gd`):
  integer-only fields (the M1.10 amendment-4 rule is stated in its own docstring `:9-14` — *"no
  float ever touches the layout path"*, deliberately no float `nook_roughness`), a
  `validate() -> PackedStringArray` guarding degenerate authoring (`:64-96`) **including the ≥ 2
  chunks geometry check** (`:90-95`), `cell_size_px` agreeing with JunkPlacer's instance-null
  fallback of 16 (`junk_placer.gd:198-201`).
- **`Band` + `PlacedPiece` — the data shape (unchanged, read-only).** `Band.fingerprint()` =
  ordered `"piece_id@offset#mated"` sha256 (`band.gd:58-62`), hashing only `piece_id`,
  `offset_cell`, `mated_socket_index`; `floor_fingerprint()` (`band.gd:76-88`) is supplementary
  and never promoted (`:70-75`); `entry_piece = pieces[0]` convention (`:21`). `PlacedPiece`
  fields at `placed_piece.gd:13-55` — `instance` may be null everywhere downstream.
- **The single wall-writer — `SocketSealer` (unedited, both-backend-proven).** Geometry-keyed:
  builds the band-global FLOOR set and caps every floor cell's non-floor 4-neighbour
  (`socket_sealer.gd:57-84`), writing into the owner piece's `Geometry` TileMapLayer
  (`:94-101`). Per M1.10's Correction 2: T1's runtime synthetic host gives synthetic pieces a
  non-null instance at materialise time, so the *verbatim* sealer is the **active wall-writer**
  for synthetic bands. Consequence for U0: a cover footprint is a cluster of non-floor cells
  surrounded by floor — the sealer's cap rule walls its entire perimeter **for free**. U0 emits
  floor-with-holes; U1 verifies the free ride. This is why cover-as-stamped-cells (breakdown OQ4's
  working assumption, b1's own recommendation) costs zero downstream lines, and why the expected
  materialisation delta for backend #3 is **zero**.
- **Downstream consumes FLOOR-cell 4-adjacency only** (verified by T0 §10.0's audit, unchanged
  since): `DepthGrader.grade` BFSes piece-index adjacency from floor 4-adjacency
  (`depth_grader.gd:83-104`, neighbours sorted); `JunkPlacer` rolls per piece on the `_JUNK_SALT`
  sub-stream and (y,x)-sorts each piece's `floor_cells` itself; `EncounterBuilder` walks
  depth-sorted pieces, skips `depth_index <= 0`, keys rooms as `room_key = str(p.offset_cell)`
  (`encounter_builder.gd:366`) — unique per chunk by construction. `piece_id` consumers beyond the
  fingerprint: only `CORRIDOR_PIECE_IDS` membership tests (`main_game.gd:590/649/891`) — synthetic
  `scat_` ids are never members, so every arena chunk classifies as "room", the correct
  open-field-honest classification (the exact cave precedent).
- **The acceptance-bar pattern to extend — `test_cave_backend.gd`** (398 lines): seed matrix
  `[12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]` (`:26`, shared with
  `test_bandgen_determinism.gd:36`); groups C1-C10 (determinism through the *pipeline* so dispatch
  is inside the bar; variation; both-level connectivity; structural invariants incl.
  `max_depth >= 4` on the default config; purity under RNG perturbation; knob-matrix determinism
  with **non-vacuity via backend stats fields**; rc-invariance; fail-loud guards; in-suite
  socket-control regression; the 2×2-open T invariant with Vector2i-keyed test-local mirrors of
  the backend's helpers `:352-398`). Configs built **in code** (no fixture `.tres` — the P7
  pattern), one deliberately non-default so defaults-drift can't mask a dead knob.
- **The two existing tests that mention scatter** — both assert a config-less
  `backend = "scatter"` profile returns null: `test_band_pipeline_parity.gd:253-258` (P7,
  "scatter is now the remaining fail-loud backend") and `test_cave_backend.gd:296-301` (C8,
  "still-unwired backend"). **Both assertions survive U0 unedited**: after §4.2, a scatter profile
  with no/wrong-typed `backend_config` fails `validate()` → the pipeline's validate-then-fail flow
  (`band_pipeline.gd:38-42`) returns null. Only the *comments* become stale ("unwired") — §9 Q10
  dispositions the comment-only touch-up.

### 1.3 What is genuinely NEW (honest deltas vs the cave backend)

| Aspect | CaveBackend (as-built) | ScatterBackend (U0) |
|---|---|---|
| Raw material | integer grid, ~45% seeded wall, CA-smoothed | integer grid, **all-floor interior**, cover stamped in |
| RNG draws | one block: per-interior-cell fill rolls | one block: 1 lane draw + a **fixed 4-draw tuple per sampling stratum** (§3.2) |
| The new algorithm | CA smoothing + flood-keep + carve | **order-stable stratified poisson-disk cover sampling** — the one genuinely new function |
| Connectivity | keep-largest + deterministic carve + player-scale carve pass | **by construction** — min-spacing + border-margin + clear-lane make disconnection impossible (§3.3); no carve at all (§9 Q6) |
| Retry model | whole-grid retry on undersize (`max_attempts`) | **none** — floor count is `interior − cover`, bounded below by construction; generation cannot undershoot (§9 Q5) |
| Play identity property | bad sightlines (nooks) — no test bar needed | **long sightlines — a test-pinned identity bar** (breakdown OQ12, §5 S11, §9 Q4) |
| Chunk partition / ids / entry / deepest | the proven idiom | **reused verbatim in shape** (`scat_` prefix); mostly duplicated code, §9 Q8 |
| Piece-id repetition | content-hash ids mostly unique (CA shapes vary) | many chunks are identical full-floor squares → **shared ids, disambiguated by `@offset`** exactly as repeated catalog pieces are today (`band.gd:58-62`) — fingerprint still pins every cover hole because any cover cell changes its chunk's local floor set |

Everything below the backend — dispatch tail, grade, return-distance, junk, encounters, sealing,
telemetry — is **reused unchanged**. That reuse (and the missing retry/carve machinery the scatter
simply doesn't need) is why the cost ledger should come in *under* the cave's ~255 lines.

---

## 2. `ScatterBandConfig` — the resource script

**File:** `Game/data/bands/scatter_band_config.gd` — schema-with-content placement beside
`cave_band_config.gd` (the T0/S1 precedent), inside U0's "data/bands/*.gd schema" file scope.
`class_name ScatterBandConfig extends Resource`, sibling of `BandGenConfig`/`CaveBandConfig`,
authored in the inspector, referenced by `band_four.tres` (U3) as `profile.backend_config`.

```gdscript
# data/bands/scatter_band_config.gd  (illustrative — programmer owns final code)
class_name ScatterBandConfig
extends Resource
## ScatterBandConfig — tuning knobs for the open-field arena backend (M1.11 U0).
## Sibling of CaveBandConfig; a BandProfile with backend == "scatter" carries one.
##
## DETERMINISM (the B2 discipline, third transposition): EVERY branch-affecting
## field is an INTEGER. Densities/biases are integer percents compared against
## RNG.randi_range(0, 99); spacing is integer Chebyshev distance; no float ever
## touches the layout path. There is deliberately no float knob of any kind.

## Arena extents in cells, INCLUDING the forced-wall border ring. The playable
## interior is (grid_width-2) x (grid_height-2). Wide aspect = the sightline
## identity (entry west, gate east — the long axis IS the band). 56x36 puts the
## floor area (~1.7-1.8k cells post-cover) in the same class as band_three's
## cave (~1.5k) — U3 tunes (§9 Q3).
@export var grid_width: int = 56
@export var grid_height: int = 36

## THE experience dial (b1: sparse-deadly vs dense-stealth): integer percent
## chance that each sampling stratum stamps a cover footprint. 0 = empty arena.
## Note: connectivity/player-scale are knob-INDEPENDENT (§3.3 holds at 100).
@export var cover_density_pct: int = 25

## Minimum Chebyshev distance (cells, edge-to-edge) between any two cover
## footprints. >= 3 guarantees a 2-cell walkable (2x2-open) gap between covers
## — the anti-maze / connectivity-by-construction floor (b1's min_cover_spacing).
@export var min_cover_spacing: int = 3

## Cover keeps at least this many floor cells clear of the border ring — the
## guaranteed all-floor perimeter road that makes disconnection impossible
## (§3.3). >= 2 keeps the rim 2x2-open (player-scale by construction).
@export var border_margin: int = 2

## Cover footprint size mix — integer weights over the fixed shape catalog
## (index 0: 1x1 pillar · 1: 2x1 low wall · 2: 1x2 low wall · 3: 2x2 wreck).
## Weighted pick via an integer cumulative table (the _weighted_pick idiom).
@export var cover_w_1x1: int = 4
@export var cover_w_2x1: int = 2
@export var cover_w_1x2: int = 2
@export var cover_w_2x2: int = 3

## Rim-vs-center density shift, integer percent in -100..100 (b1's
## edge_cover_bias). Positive pushes cover toward the rim (open killing-center),
## negative toward the center. 0 = uniform. Applied as an integer scale of
## cover_density_pct per stratum zone (§3.2).
@export var edge_cover_bias_pct: int = 0

## Height (rows) of the protected all-floor E-W lane — the constructed
## long-sightline guarantee (§3.2 step L; the S11 identity bar reads it).
## >= 2 keeps the lane itself 2x2-open. The lane row is seed-picked.
@export var clear_lane_width: int = 3

## Synthetic-piece partition size (the cave idiom verbatim): one PlacedPiece
## per floor-bearing chunk_cells x chunk_cells tile. Sets the depth-axis /
## loot-roll / encounter-room granularity.
@export var chunk_cells: int = 8

## Pixel size of one cell at materialisation (U1/T1 path consumes; JunkPlacer's
## instance-null fallback is 16 — junk_placer.gd:198-201 — keep agreeing).
@export var cell_size_px: int = 16
```

Schema notes:

- **All defaults are placeholders for U3 to tune** (the cover-density point — sparse-deadly vs
  dense-stealth — is breakdown OQ9, a Director-ratified U3 authoring call). U0's job is that every
  knob is deterministic, live (covered by a non-default test config), and safe at every value.
- **No retry fields** (`min_floor_cells`, `max_attempts` from the cave schema are absent): scatter
  generation cannot undershoot — floor = interior − cover, and cover is bounded by the stratum
  count; there is nothing to retry (§9 Q5). `requested_seed == resolved_seed`, always.
- **No `.tres` ships with U0.** The first authored `ScatterBandConfig.tres` is U3's
  (`band_four`'s `backend_config`, at `data/bands/scatter_config_band_four.tres` per the M1.10
  amendment-3 naming convention). U0's tests build configs in code.
- **`validate() -> PackedStringArray`** (consumed by §4.2), guarding degenerate authoring in the
  `CaveBandConfig.validate()` style (`cave_band_config.gd:64-96`): extents ≥ 12 each axis;
  `cover_density_pct` in 0-100; `min_cover_spacing` ≥ 3; `border_margin` ≥ 2; all four weights
  ≥ 0 with sum ≥ 1; `edge_cover_bias_pct` in -100..100; `clear_lane_width` in 2..(interior
  height); `chunk_cells` ≥ 2; `cell_size_px` ≥ 1; **the Q11-style geometry check** — grid/chunk
  extents must yield ≥ 2 chunks AND enough chunk columns/rows that the default-config depth bar is
  reachable (`(ceil(w/cc)-1) + (ceil(h/cc)-1) >= 4`, the arena's exact chunk-BFS diameter lower
  bound since every chunk is floor-bearing — stronger than the cave's probabilistic check, because
  an arena's chunk graph is the full grid graph, §3.4).
- **No RunConfig lever touches these fields** (frozen knob model). The backend ignores `rc`
  entirely, mirroring the cave (test S7 pins it; the T0 §10.1 Q5 verification that every rc
  generation hook is socket-interior still holds — nothing new reads rc).

---

## 3. `ScatterBackend` — the generator

**File:** `Game/systems/bandgen/scatter_backend.gd`, `class_name ScatterBackend extends
RefCounted` — sibling of `CaveBackend`, same instantiate-and-call shape, same public signature:

```gdscript
func generate(seed: int, cfg: ScatterBandConfig, _rc: RunConfig = null) -> Band
```

`rc` accepted for signature symmetry, **ignored** (the cave's C7 precedent; S7 pins invariance).

### 3.0 Determinism architecture (the whole design in one paragraph)

All randomness happens in **one block**: after `RNG.seed_from(seed)`, draw exactly **1 + 4·S**
integers in a fixed order — one lane-row draw, then a fixed 4-draw tuple (accept roll, jitter-x,
jitter-y, size roll) for **every** sampling stratum in fixed (stratum-y, stratum-x) scan order,
**unconditionally** (a stratum draws its full tuple even when excluded or rejected, so the draw
count is a pure function of `cfg` alone — stronger than the cave's outcome-dependent stream and
trivially review-stable). Every subsequent step — footprint stamping (already decided by the
draws + the deterministic rejection predicates), chunk partition, entry selection, deepest BFS,
piece emission — is a pure integer function of the grid with zero draws and fixed iteration order.
There is no retry loop and no carve, so there is nothing else that could touch the stream. Same
`(cfg + seed)` → same draws → same grid → same pieces → same fingerprint, byte-for-byte, forever.

### 3.1 Top level (no retry — the honest delta from the cave)

```gdscript
# Q9-style test-visible non-vacuity stats, set per generate().
var last_cover_count: int = 0        # footprints actually stamped
var last_spacing_rejects: int = 0    # candidates rejected by spacing/lane/margin
var last_lane_row: int = -1          # the seed-picked lane top row


func generate(seed: int, cfg: ScatterBandConfig, _rc: RunConfig = null) -> Band:
	EventBus.band_generation_started.emit(seed)   # telemetry parity with both backends
	RNG.seed_from(seed)                            # the ONE reseed (band_generator.gd:88 discipline)
	var w := cfg.grid_width
	var h := cfg.grid_height
	var grid := _arena_floor(w, h)                 # border WALL ring, all-floor interior; NO draws
	var lane_y := _pick_lane_row(h, cfg)           # draw #1
	last_lane_row = lane_y
	_stamp_cover(grid, w, h, lane_y, cfg)          # the RNG block: fixed 4-draw tuple per stratum
	var entry_cell := _select_entry(grid, w, h, lane_y, cfg)  # deterministic, RNG-free (§3.5)
	var band := _emit_band(grid, w, h, entry_cell, cfg)       # chunk partition (§3.4), RNG-free
	band.requested_seed = seed
	band.resolved_seed = seed                      # no retry: requested == resolved, always
	EventBus.band_generated.emit(seed, band.pieces.size())
	return band
```

`band_generation_failed` is never emitted (there is no failure mode — §9 Q5 ratifies dropping the
retry scaffold rather than carrying dead code into the ledger).

### 3.2 The sampler — order-stable stratified poisson-disk (the one new algorithm)

**Shape catalog** (fixed, index-stable): `_SHAPES := [[Vector2i(0,0)], [Vector2i(0,0),
Vector2i(1,0)], [Vector2i(0,0), Vector2i(0,1)], [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1),
Vector2i(1,1)]]` — 1×1 pillar, 2×1, 1×2, 2×2 wreck (b1's "small cover footprint (1-4 cells)").

**Step L — lane pick (draw #1):** `lane_y := RNG.randi_range(1 + cfg.border_margin,
h - 2 - cfg.border_margin - cfg.clear_lane_width + 1)` — the protected all-floor E-W lane occupies
rows `[lane_y, lane_y + clear_lane_width)`, spanning the full interior width. Seed-varied so the
arena's one guaranteed sightline corridor is not always dead-center (§9 Q4 covers what the lane is
*for*; §9 Q2 its residuals).

**Step S — stratified sampling.** Partition the interior into square strata of side
`s := cfg.min_cover_spacing + 2` (spacing + the widest shape extent), anchored at (1, 1), iterated
in fixed (stratum-y, stratum-x) ascending order. Per stratum, **always** draw the 4-tuple:

```gdscript
for sy in stride(1, h - 1, s):                     # illustrative; fixed (y, x) order
	for sx in stride(1, w - 1, s):
		var accept_roll := RNG.randi_range(0, 99)  # draw a
		var jx := RNG.randi_range(0, s - 1)        # draw b
		var jy := RNG.randi_range(0, s - 1)        # draw c
		var size_roll := RNG.randi_range(0, wsum - 1)  # draw d (wsum = sum of the 4 weights)
		# --- decision phase: pure integer predicates, zero further draws ---
		if accept_roll >= _stratum_density_pct(sx, sy, w, h, cfg):
			continue                               # density miss (rim/center zoned, below)
		var origin := Vector2i(sx + jx, sy + jy)
		var cells := _shape_cells(origin, _weighted_shape_index(size_roll, cfg))
		if not _fits(cells, w, h, lane_y, cfg, blocked):
			last_spacing_rejects += 1
			continue                               # lane / margin / spacing reject
		for c in cells:
			grid[c.y * w + c.x] = WALL             # STAMP: cover is NON-floor
		_mark_blocked(blocked, cells, cfg.min_cover_spacing)
		last_cover_count += 1
```

**Rejection predicates (`_fits`)** — all deterministic, order-stable because acceptance order =
stratum order:
1. **Bounds + border margin:** every cell inside the interior with ≥ `border_margin` floor cells
   to the border ring (`c.x/c.y` in `[1 + margin, w/h - 2 - margin]`) — this preserves the
   all-floor **perimeter road**, the connectivity backbone (§3.3).
2. **Clear lane:** no cell in rows `[lane_y, lane_y + clear_lane_width)` — the constructed
   sightline (and a protected entry→gate route, b1's `clear_lane_guarantee`).
3. **Spacing:** no cell within Chebyshev `min_cover_spacing − 1` of any previously accepted cover
   cell — implemented as a dilated `blocked` set (`_mark_blocked` marks all cells within Chebyshev
   `min_cover_spacing − 1` of the stamped footprint; a candidate cell in `blocked` → reject).
   O(1) per cell, no distance scans, visibly order-stable.

**Zoned density (`_stratum_density_pct`)** — the `edge_cover_bias_pct` integer formula: a stratum
whose center is in the outer third of the interior (min distance to border ring × 3 <
min(interior_w, interior_h)) uses `cover_density_pct * (100 + edge_cover_bias_pct) / 100`; inner
strata use `cover_density_pct * (100 - edge_cover_bias_pct) / 100`; both clamped 0-100. Integer
division throughout. (Two zones, not a gradient — the cheapest formula that makes the b1 knob real;
U3 tunes or zeroes it.)

**Why stratified-with-jitter and not dart-throwing** (the breakdown's "sorted candidate order,
fixed accept/reject" contract): the stratum grid *is* the sorted candidate order — determinism
falls out of the scan order rather than being imposed on a random candidate stream; one candidate
per stratum gives blue-noise-like even spread before the spacing check even runs (classic
jittered-grid sampling, the standard cheap poisson-disk approximation); the unconditional 4-draw
tuple makes the RNG stream length a constant of `cfg`, which no other backend achieves and which
makes C5-style purity trivially auditable. Dart-throwing (N upfront draws, accept/reject in draw
order) is equally deterministic but needs an arbitrary N, does more spacing rejections at high
density, and its acceptance pattern is harder to reason about in review. §9 Q1 carries the choice.

### 3.3 Connectivity + player-scale BY CONSTRUCTION (the no-carve argument)

The breakdown demands connectivity "by construction (min-spacing + clear-lane rules) or by
deterministic CARVE". U0's design achieves the former, making the latter unnecessary:

1. **The perimeter road:** predicate 1 keeps a ≥ `border_margin` (≥ 2)-wide all-floor ring inside
   the border. Every interior cell column/row therefore reaches an all-floor cycle enclosing the
   whole arena. The ring is ≥ 2 wide → its cells are 2×2-open (in T).
2. **No two cover footprints merge:** predicate 3 keeps every pair of footprints ≥
   `min_cover_spacing` (≥ 3) Chebyshev apart, so between any two covers there are ≥ 2 consecutive
   floor cells along any separating axis — a 2-wide (2×2-open) walkable gap. Cover blobs are ≤ 2×2
   and mutually isolated; no chain of covers can form a wall.
3. **No cover-border pinch:** predicates 1 + 3 together mean every floor cell adjacent to a cover
   footprint has, within Chebyshev 2, floor in all directions not occupied by that single ≤ 2×2
   footprint — it connects around the footprint to the rest of the floor, and belongs to or is
   4-adjacent to a 2×2 all-floor block (the T-coverage property, `cave_backend.gd:243-269`'s
   post-condition, here achieved without the pass).

Hence: **the floor is one 4-connected component, T is non-empty and single-component, and every
floor cell is in or 4-adjacent to T — at every knob value, on every seed, with zero carve code.**
The invariant still gets teeth three times over: the pipeline-level
`ConnectivityGuarantee.enforce(band, Mode.ASSERT)` (§4.1, the cave arm extended), the test's
both-level connectivity group (§5 S3), and the 2×2-open T group (§5 S10). If any of those ever
trips, the *sampler's predicates* are wrong and must be fixed at the source — a silent carve
band-aid would mask the bug (the ASSERT posture, `connectivity_guarantee.gd:14-24`). §9 Q6 asks
Phase 3 to ratify "no defensive carve" as the compliant reading of the breakdown's "or by
deterministic CARVE" clause (it is an *or*; the cave needed carve because CA output is genuinely
fragmented — an arena is not).

### 3.4 Chunk partition → synthetic pieces (the cave idiom, `scat_` ids)

Identical in shape to `cave_backend.gd:376-472`, with the arena-specific notes:

- Tile the grid into `chunk_cells × chunk_cells` tiles anchored at (0, 0), fixed (chunk-y,
  chunk-x) order; every chunk containing ≥ 1 floor cell → one synthetic `PlacedPiece`; **entry
  chunk first** (`Band.entry_piece = pieces[0]`, `band.gd:21`), remainder in scan order. On an
  arena every interior-touching chunk is floor-bearing, so the piece count is effectively
  `ceil(w/cc) × ceil(h/cc)` (56×36 / 8 → 7×5 = **35 pieces**; the depth axis is the chunk-grid
  graph, diameter (7−1)+(5−1) = 10 ≥ 4 — the `max_depth >= 4` bar holds by geometry, which is why
  §2's validate() can check it *exactly* rather than probabilistically).
- Per-piece fields exactly as the cave table (T0 §3.6): `instance = null`, `offset_cell` = chunk
  origin (band-global), `floor_cells` = the chunk's floor cells (y,x)-ordered **except the entry
  chunk, whose element 0 is the front-positioned entry anchor** (M1.10 Q10 amendment, consumed by
  `main_game.gd:1017`), `footprint_cells` = the full chunk rect (floor + cover + any border cells
  in truncated edge chunks), `open_sockets = []`, `mated_socket_index = -1`.
- **`piece_id = StringName("scat_" + sha256("|".join(chunk-LOCAL floor cells sorted (y,x))).substr(0, 12))`**
  — the content-hash scheme verbatim (`cave_backend.gd:460-472`), new prefix. Full-floor interior
  chunks (no cover, no border) share one id and are disambiguated by `@offset` in the fingerprint,
  exactly as repeated catalog pieces are; any cover cell changes its chunk's local floor set →
  different id → `fingerprint()` pins every cover hole byte-for-byte. `floor_fingerprint()` stays
  supplementary, never promoted (`band.gd:70-75`).
- `band.occupy(p)` per piece (disjoint chunk rects → overlap-free trivially);
  `band.open_sockets = []`; `deepest_piece` via the grader-replicating chunk BFS
  (`cave_backend.gd:479-521` idiom) so `deepest_piece.depth_index == band.max_depth` after the
  pipeline's grade; the < 2 pieces `push_error`-but-return guard (`:412-417`) carried over
  (unreachable given §2's validate(), kept for the never-crash posture).

**Cover stamping is strictly pre-partition** (the grid is finalised before `_emit_band` runs):
`floor_cells` must be final before chunking/hashing/grading — stamping after emission would mutate
emitted pieces and break the fingerprint/grading contract (the same argument that moved the cave's
player-scale pass generation-side, T0 §10.1 Q8). §9 Q7 records the alternative (cover as post-hoc
per-chunk metadata) and why it dies.

### 3.5 Entry anchor + deepest anchor

- **Entry** = west-most cell of the 2×2-open set T (min x — the M1.10 Q10 contract), which on an
  arena is the entire border-margin column at x = 1 (always floor, always in T). The **tie-break
  is therefore load-bearing here** in a way it wasn't for the cave: min-y (the cave rule) pins the
  NW corner every seed; this design instead tie-breaks **min |y − lane_center|, then min y** — the
  spawn lands at the *west end of the clear lane*, staring straight down the arena's guaranteed
  sightline. One comparison more than the cave rule; the player's first frame IS the band identity
  ("see — and be seen — across the whole space"). Deterministic (total order), edge-biased,
  orientation-stable ("home is west" carries over from the cave). §9 Q2 carries the choice; the
  cave-verbatim min-y rule is the fallback.
- **Deepest** = the grader-replicating chunk-BFS max (ties (y,x)-asc via fixed iteration), per
  §3.4 — on the default extents this is an east-side chunk, giving the entry-west → gate-east long
  axis the wide aspect exists for. The gate snap (D-RAT-7) and 2×2 spawn→gate throat certificate
  are inherited bars re-asserted end-to-end by U1's M-series (breakdown: "Scatter inherits all
  three bars unchanged"); U0 proves the data-level halves (entry ∈ T front-positioned; gate chunk
  floor-bearing by construction; spawn→gate connectivity = S3/S10).

---

## 4. Pipeline dispatch + `validate()` scatter branch

### 4.1 `band_pipeline.gd` — the dispatch diff

The wiring guard (`band_pipeline.gd:51-54`) updates; the socket and cave paths' statements stay
**verbatim in the same order** (parity- and cave-suite-pinned). Illustrative diff shape:

```gdscript
	# --- Wiring guards (M1.11: all three declared backends wired) ---------
	if profile.backend != "socket" and profile.backend != "cave" \
			and profile.backend != "scatter":
		push_error("BandPipeline: unknown backend '%s' (profile '%s')"
				% [profile.backend, profile.id])   # future-proof fail-loud; unreachable via the enum
		return null
	...principles guard + flavor-type loop: UNCHANGED...

	# --- STAGES 1+2: backend dispatch ------------------------------------
	var band: Band
	if profile.backend == "cave":
		...UNCHANGED (band_pipeline.gd:73-77 verbatim)...
	elif profile.backend == "scatter":
		# SCATTER (M1.11 U0): the open-field arena backend. rc accepted,
		# IGNORED (every as-built rc generation hook is socket-interior; S7 pins).
		var scat_cfg := profile.backend_config as ScatterBandConfig
		band = ScatterBackend.new().generate(seed, scat_cfg, rc)
	else:
		...SOCKET: UNCHANGED verbatim (catalog + I1 swap + generate)...
	...null/empty guard: UNCHANGED...

	# --- Post-backend invariant (synthetic backends): connectivity ASSERT --
	if profile.backend == "cave" or profile.backend == "scatter":
		ConnectivityGuarantee.new().enforce(band, ConnectivityGuarantee.Mode.ASSERT)

	# --- flavor loop / grade / return-distance: UNCHANGED -----------------
```

Notes: (a) **zero scatter statements execute on socket or cave paths** — the additions on those
paths are string compares only (no draws, no state), so `band_greybox`/`band_two`/`band_three`
byte-identity is structural, and the parity + cave suites prove it anyway; (b) the guard's
docstring comment (`:44-50`) updates to the M1.11 truth; (c) the ASSERT-arm extension is one
boolean widening of an existing cave-only conditional — cave profiles execute the identical
statement they did before (fp-neutral: ASSERT never mutates, `connectivity_guarantee.gd:14-24`).

### 4.2 `band_profile.gd` — the `validate()` scatter branch

Appended after the cave branch (`band_profile.gd:96-113`), same fail-loud style, same three
M1.10-canonical rules (config type+content · flavors-empty · archetype don't-care):

```gdscript
	elif backend == "scatter":
		if backend_config == null or not (backend_config is ScatterBandConfig):
			problems.append("BandProfile '%s': scatter backend needs a ScatterBandConfig backend_config" % id)
		else:
			for p in (backend_config as ScatterBandConfig).validate():
				problems.append("BandProfile '%s': %s" % [id, p])
		# Flavors ship EMPTY on scatter bands (M1.11 breakdown / U3 contract; the
		# M1.10 rule carries — SetPieceInject/WearDecay are socket-built).
		if not flavors.is_empty():
			problems.append("BandProfile '%s': scatter backend does not support flavor stages in M1.11 (flavors must be empty)" % id)
		# piece_pool intentionally NOT required (no pieces to draw); non-null is
		# legal-but-inert. The archetype field has no scatter-honest value (the
		# arena IS the topology) — ignored don't-care (warn, never error).
		if archetype != "linear":
			push_warning("BandProfile '%s': archetype '%s' is ignored by the scatter backend (the arena IS the topology)" % [id, archetype])
```

The docstring comment at `band_profile.gd:23-25` ("the pipeline fail-louds on them") updates to
the M1.11 truth. The `push_error + null` posture flows through the pipeline's existing
validate-then-fail gate (`band_pipeline.gd:38-42`) — which is also why the two existing
scatter-fail-loud test cases keep passing unedited (§1.2 last bullet).

---

## 5. `test_scatter_backend` — the acceptance harness

**Files:** `Game/tests/test_scatter_backend.gd` + `.tscn` (root `Node` + script — the standing
shape). Run: `godot --headless --path Game res://tests/test_scatter_backend.tscn` (exit 0 =
green). Same seed matrix (`[12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]`). Configs built
**in code**: the **default config** (`ScatterBandConfig.new()` — the C4/C10-analog bars run on it)
and a **dense config** (non-default on several knobs — e.g. `cover_density_pct = 90`,
`min_cover_spacing = 3`, `edge_cover_bias_pct = 40`, `clear_lane_width = 2` — maximally stressing
spacing rejection so the anti-maze machinery provably runs, and so defaults-drift can't mask a
dead knob).

Assertion groups (mirroring `test_cave_backend.gd` C1-C10, renamed S*, plus the identity bar):

- **S1 — determinism:** same seed ⇒ byte-identical `fingerprint()` twice, per seed, **through
  `BandPipeline.generate(scatter_profile, seed)`** (dispatch inside the bar), plus
  `floor_fingerprint()` equality (supplementary — the floor-with-holes reproduces, not just the
  piece list). Run on both configs.
- **S2 — variation:** ≥ 2 distinct fingerprints across the matrix (cover holes + lane row differ
  per seed; with content-hash ids this is near-certain — assert anyway).
- **S3 — connectivity, both levels:** `BandGenerator.new().is_band_connected(band)` +
  `ConnectivityGuarantee.new().is_fully_connected(band)`, per seed, both configs — the
  by-construction claim's first teeth.
- **S4 — structural invariants:** disjoint `footprint_cells`; no floor on/outside the border ring;
  `entry_piece == pieces[0]` with a non-empty `floor_cells` whose element 0 is a T-member (the
  front-positioned anchor); every piece `instance == null`, `open_sockets == []`,
  `mated_socket_index == -1`, `piece_id` begins `"scat_"`; `pieces.size() >= 2`;
  **`band.max_depth >= 4` on the default config** (the depth-economy bar, U1's hard input
  contract); `deepest_piece.depth_index == band.max_depth`.
- **S5 — purity under RNG perturbation:** generate seed 424242, perturb
  (`RNG.seed_from(987654321); RNG.randi()`), regenerate ⇒ identical fingerprint (the fixed-length
  one-block stream makes this the easiest purity proof of the three backends).
- **S6 — spacing/sampler determinism + non-vacuity** (the C6 analog): the dense config across the
  seed matrix, twice each ⇒ identical fingerprints; per seed, rebuild the band-global cover set
  (footprint − floor over the interior) and assert **every pair of cover blobs is ≥
  `min_cover_spacing` Chebyshev apart** (the anti-maze invariant, asserted directly, not just via
  connectivity); non-vacuity via the backend stats fields (the Q9 precedent): across the matrix,
  `last_cover_count > 0` on every seed AND `last_spacing_rejects > 0` on ≥ 1 dense-config seed
  (spacing rejection provably exercised — a green S6 can't be vacuous).
- **S7 — rc-invariance:** r4-on and lvl-on `RunConfig`s ⇒ fingerprints == the rc-null fingerprint,
  per seed (the cave C7 mirror — pins "backend ignores rc" so an accidental future rc read fails
  loudly).
- **S8 — fail-loud guards:** scatter profile with null `backend_config` ⇒ null; with a
  **wrong-typed config — a `CaveBandConfig`** (the cross-backend confusion case) ⇒ null; with a
  flavor ⇒ null; degenerate configs (extents too small; `min_cover_spacing = 2`;
  `border_margin = 1`; zero weight sum; lane wider than the interior; chunk geometry failing the
  depth-bar check) ⇒ null each.
- **S9 — three-profile control regression (in-suite belt-and-braces):** load `band_greybox.tres`,
  `band_two.tres`, `band_three.tres`; one seed each through the pipeline, twice; assert
  reproduction (the absolute golden pins live in the existing suites, which the DoD runs anyway —
  S9 makes this test self-containedly loud if dispatch broke either older path).
- **S10 — player-scale 2×2-open invariant:** the cave C10 mirror verbatim
  (`test_cave_backend.gd:321-398`'s Vector2i-keyed helpers): T non-empty, single-component,
  contains the entry anchor, and every floor cell is a member of or 4-adjacent to T — per seed,
  **both configs** (the dense config is the one that could ever violate it; by §3.3 it can't).
- **S11 — the long-sightline identity bar** (breakdown OQ12 — what makes this band *provably*
  read open; §9 Q4 carries the exact numbers for Phase 3):
  - **(a) The constructed lane:** rows `[last_lane_row, last_lane_row + clear_lane_width)` are
    all-FLOOR across the full interior width ⇒ the maximum E-W sightline equals the interior
    width (54 cells on the default config — ~3.4× the cave grid's *total* extent between walls).
    Extents-independent form: assert some row's uninterrupted floor run `== grid_width - 2`.
  - **(b) The openness percentile:** ≥ 50% of floor cells have an uninterrupted axis run
    (max of E-W, N-S runs through the cell) ≥ half the interior's shorter dimension — integer
    math, directly operationalising b1's "from *most* standing spots you can see across the
    space". A cave or socket band fails this bar decisively; an arena passes at any legal
    density (cover ≤ ~8% of interior even at `cover_density_pct = 100`, by stratum-count
    arithmetic).
  - **(c) The anti-maze ceiling:** cover cells ≤ 15% of interior cells, both configs (a
    guard-rail restating (b)'s premise in one cheap integer).

**Existing-test edits: NONE required** (the M1.10 P7 lesson landed better this time — both
scatter fail-loud fixtures are config-less profiles that §4.2 keeps returning null via
`validate()`). The stale *comments* at `test_band_pipeline_parity.gd:253` ("scatter is now the
remaining fail-loud backend") and `test_cave_backend.gd:296-297` ("still-unwired backend") are
dispositioned by §9 Q10 (recommendation: one comment-only, assertion-preserving touch-up commit,
worklog-flagged — the T0 P7 precedent of keeping test documentation truthful).

---

## 6. Files to create / touch

**Create (U0-owned):**
- `Game/systems/bandgen/scatter_backend.gd` — the backend (§3).
- `Game/data/bands/scatter_band_config.gd` — the config schema (§2).
- `Game/tests/test_scatter_backend.gd` + `Game/tests/test_scatter_backend.tscn` — the harness (§5).
- (+ the `.uid` files Godot mints on import — commit them.)

**Edit (U0 is this wave's designated single writer of both):**
- `Game/systems/bandgen/band_pipeline.gd` — the dispatch diff (§4.1).
- `Game/data/bands/band_profile.gd` — the `validate()` scatter branch + docstring truth (§4.2).
- *(conditional on §9 Q10)* `Game/tests/test_band_pipeline_parity.gd` +
  `Game/tests/test_cave_backend.gd` — **comment-only** staleness fixes, zero assertion changes,
  worklog-flagged.

**Must NOT touch (contract):**
- `Game/scenes/game/main_game.gd` — U1's exclusive file (Wave 2). A scatter band is proven
  headlessly through the pipeline.
- `Game/systems/bandgen/cave_backend.gd`, `Game/data/bands/cave_band_config.gd` — read-only; the
  band_three control's byte-safety is structural because these do not change (§9 Q8 covers the
  duplication this implies).
- `Game/systems/bandgen/band_generator.gd`, `band.gd`, `placed_piece.gd`, `open_socket.gd`,
  `socket_sealer.gd`, `stages/*` — read-only. The synthetic-piece identity needs **zero**
  `band.gd`/`placed_piece.gd` edits (the §3.4 scheme lives wholly in the backend).
- `Game/systems/depth/*`, `Game/systems/spawning/*`, `Game/systems/event_bus.gd` (existing
  signals suffice, §3.1), `Game/data/run_config/*`, all authored band `.tres` files.
- `Game/tests/test_bandgen_determinism.gd/.tscn`, `test_band_three_profile.*` — never edited.

**Work-product contract:** branch `general-purpose/U0` in an isolated worktree (verify branch
topology before merge — the qa git-switch-leak memory); one worklog
`worklogs/2026-MM-DD-U0-general-purpose.md` naming the commit SHA(s), the **bespoke-code cost
ledger** (expected order: backend ~200 lines — of which ~100 are the §9 Q8 duplicated chunk/emit
machinery and ~70 the genuinely new sampler — + config ~55 + pipeline diff ~10 + validate branch
~15; **vs the cave's ~255** — the N=3 headline), and a Design deviations section; commit messages
prefixed `M1.11 U0:`.

---

## 7. Definition of done (restated + concrete)

1. `godot --headless --path Game res://tests/test_scatter_backend.tscn` exits 0 (S1-S11).
2. `test_band_pipeline_parity.tscn`, `test_bandgen_determinism.tscn`, `test_cave_backend.tscn`,
   `test_band_three_profile.tscn` exit 0 — determinism + band-three files byte-untouched; the
   other two carry at most the Q10 comment-only diff.
3. All four controls hold: all-off fp **`e943ac9c8bc1`** unmoved; `band_greybox`, `band_two`,
   `band_three` fingerprints byte-identical through the pipeline (S9 + the existing suites + the
   RG-style verify run) — asserted from primary sources, per verify-before-reporting-done.
4. All other bandgen-adjacent suites green (`test_band_depth`, flavor/S5 suites,
   `tests/procgen/*`, `test_cave_materialise`); `godot --headless --path Game --import` clean;
   smoke test green. (Suites run sequentially, never concurrently.)
5. Scope audit: the diff touches only §6's create/edit list (+ `.uid`s).
6. Worklog + commit SHA + cost ledger + deviations; task mirrored on `STATUS.md` + the board.

---

## 8. The U0/U1 seam — what U0 guarantees, what U1 verifies

U0 **guarantees** (data-level, headlessly test-pinned):
1. **Enclosure by construction:** forced WALL border ring; every non-floor cell (border + cover)
   is WALL in the grid; no floor on the ring (S4).
2. **Cover = floor-facing non-floor:** every cover footprint is a ≤ 2×2 WALL cluster fully
   surrounded by floor (spacing + margin + lane predicates) — exactly the shape the unedited
   `SocketSealer`'s cap rule walls per-cell (`socket_sealer.gd:77-84`), once U1's ride-through
   gives the synthetic host its `Geometry` layer (the M1.10 Correction-2 mechanism: the sealer is
   the *active* wall-writer for synthetic bands, not a no-op).
3. **Entry anchor player-scale + front-positioned** (`floor_cells[0]` ∈ T, S4/S10); **gate-side
   contract** (`deepest_piece` deterministic, at max chunk depth, S4); **depth economy**
   (`max_depth >= 4` default, S4); **cell scale** (`cell_size_px = 16` agreeing with JunkPlacer's
   fallback).

U1 then verifies (writing, per the version thesis, **nothing**): `_build_synthetic_piece` hosts
the arena chunks; sealer caps perimeter + every cover footprint (collision-closure point queries);
gate snap + 2×2 spawn→gate certificate end-to-end; junk/encounters on floor; fp/floor_fp pre/post
materialisation byte-equal. Any gap is U1's ledger finding, not a U0 re-open — unless the gap is
in a §8 guarantee, which is a U0 bug.

---

## 9. Open Questions (for Phase-3 fresh-eyes resolution)

> Each with trade-offs + a recommendation. Vision/fun/tone/scope calls are flagged **needs
> Director review**; the rest resolve on technical merit. A **Resolved Decisions** section is
> appended below by the Phase-3 resolver before the Wave-1 build dispatches.

**Q1 — Sampler algorithm: stratified grid-jitter vs dart-throwing vs true poisson (Bridson)?**
§3.2 designs stratified-with-jitter: determinism from the stratum scan order (the breakdown's
"sorted candidate order" satisfied structurally), a **constant RNG draw count = f(cfg)** (the
strongest stream-stability property of any backend yet), blue-noise-like spread from
one-candidate-per-stratum + the explicit spacing check, ~40 lines. Dart-throwing (fixed-N upfront
candidate draws, accept/reject in draw order) is equally deterministic but needs an arbitrary N
constant, degrades at high density (rejection storms), and hides the spread property in the
rejection dynamics. Bridson's algorithm gives true poisson-disk quality but uses an active-list
queue whose iteration order + float annulus sampling are exactly the order-stability and
integer-math hazards this repo's discipline exists to avoid. A visible grid alignment in the
cover pattern (stratified's known artifact) is acceptable at ~15-60 stamps per arena and is
further broken up by jitter + size mix. **Recommendation: stratified grid-jitter, as specced.**
*Technical — resolve on merit.*

**Q2 — Entry tie-break: lane-aligned vs cave-verbatim min-y?** The west-most-in-T contract
(M1.10 Q10) is inherited, but on an arena the west-most set is the whole x = 1 column, so the
tie-break picks the spawn. (a) **Lane-aligned** (§3.5: min |y − lane_center|, then min y): the
player spawns staring down the guaranteed sightline — the band identity in frame one; one extra
comparison. (b) **Cave-verbatim min-y:** spawns the NW corner every seed; maximally consistent
with the cave rule, but the first sight is two walls. (c) Seed-drawn spawn row: another draw for
no principled gain. **Recommendation: (a)** — the deviation from the cave's letter serves the
cave rule's own spirit (a deterministic, orientation-stable, *meaningful* entry); worklog-flag it
as an interpretation. *Technical with a feel edge — resolve on merit; the fictional/felt meaning
of the entry view is U3's identity-pitch material, not U0's.*

**Q3 — Arena extents/aspect defaults: 56×36 wide vs 56×56 square vs larger?** §2 picks 56×36
(interior 54×34, ~1.7-1.8k floor post-cover — the same floor-area class as band_three's cave;
35 chunks; chunk-BFS diameter 10). Wide aspect serves the identity (one long axis to see down;
entry-west → gate-east reads as *crossing* the exposed space, b1's "fast to cross, dangerous to
dwell"). A square arena weakens the crossing read; a much larger arena (72×44+) inflates loot
rolls (per-piece) and web-build cover-collision counts before UG2 has perf data. All defaults are
U3-tunable placeholders; U0's tests bind to their own in-code configs, so U3 retuning never
touches the test. **Recommendation: 56×36 as the shipped default; U3 owns the authored point.**
*Technical here; the felt size is U3/Director's via the authored config.*

**Q4 — What exactly does the S11 sightline bar pin (breakdown OQ12)?** Options: (a) the
**constructed lane** only — cheap, deterministic, but pins the *mechanism*, not the *feel* (a
dense maze with one clear lane would pass); (b) an **openness percentile** — ≥ P% of floor cells
with max-axis-run ≥ K (§5 S11(b): P = 50, K = interior_min/2) — directly operationalises b1's
defining property and decisively separates the arena from both shipped generators; costs one
O(floor) integer pass in the test; (c) a **cover-fraction ceiling** — trivial but only a proxy.
**Recommendation: all three, (b) as the load-bearing identity bar** with P = 50 / K =
interior_min/2 as the opening numbers (Phase 3 may re-derive them against generated samples; they
must hold at the *dense* test config too, since the identity claim is "open at any legal knob
value"). *Technical — resolve on merit; whether the band FEELS tense-open is UG2's telemetry
question, not a U0 bar.*

**Q5 — Drop the retry loop entirely?** The cave retries because CA keep-largest can undershoot
`min_floor_cells`; a scatter arena's floor is `interior − cover ≥ interior × 0.92` by stratum
arithmetic — there is no undershoot mode, so `max_attempts`/`min_floor_cells`/`_derive_seed`
would be dead code (and dead ledger lines). Cost of dropping: `band_generation_failed` is never
emitted by this backend (telemetry consumers already treat it as event-driven, not per-band
mandatory); `requested_seed == resolved_seed` always (downstream reads either, both set).
Alternative: keep the scaffold for cross-backend symmetry — symmetry with machinery that cannot
fire is decoration. **Recommendation: drop it; note the delta in the backend docstring and the
worklog.** *Technical — resolve on merit.*

**Q6 — No defensive carve: is "by construction" alone a compliant reading of the breakdown's
"connectivity by construction … or by deterministic CARVE"?** §3.3 argues the sampler's three
rejection predicates make disconnection and sub-player-scale pinches *impossible*, at every knob
value — the "or" clause is an alternative, not a mandate, and the cave only carries carve because
CA output is genuinely fragmented. Carrying a reachable-in-theory carve pass (~60 duplicated
lines) that no seed can trigger would be untestable dead code (the BUG4 no-vacuous-test posture
cuts against it). The invariant keeps three independent teeth (pipeline ASSERT, S3, S10).
Risk: if Phase 3 finds a hole in the §3.3 argument (e.g. a footprint-vs-margin corner case), the
fix is a *predicate* fix, not a carve. **Recommendation: ratify no-carve; require the Phase-3
resolver to adversarially re-derive §3.3's three claims before ratifying.** *Technical — resolve
on merit; worklog-flag as an interpretation of breakdown wording (the T0 Q4 precedent).*

**Q7 — Cover stamping pre- vs post-chunk-partition; stamped cells vs cover-as-entities
(breakdown OQ4).** Stamped-WALL-cells pre-partition (§3.4) is the working assumption and the b1
recommendation: cover participates in floor/connectivity/fingerprint for free, the sealer walls
it for free, and `floor_cells` are final before hashing/grading (the determinism contract's
hard requirement — post-partition stamping would mutate emitted pieces). Cover-as-entities
(scene props placed downstream, JunkPlacer-style salted sub-stream) keeps the floor pure and
would allow destructible/decorative cover later — but it needs new collision/LOS machinery NOW
(the sealer can't see entities), leaves `fingerprint()` blind to cover, and moves U2b's
"cover blocks the bolt" from world-mask-for-free to bespoke code. **Recommendation: stamped
non-floor cells, pre-partition, as specced; cover-as-entities is a future-version option for
*decorative* cover on top.** *Technical — resolve on merit.*

**Q8 — Chunk/emit machinery: duplicate inside `scatter_backend.gd` vs extract a shared helper?**
The partition/`_chunk_id`/`_pick_deepest_piece`/T-set helpers are ~100 lines of near-verbatim
cave code. Extracting a shared `bandgen/synthetic_chunker.gd` used by *both* backends would edit
`cave_backend.gd` — touching the band_three control's code path in the same wave that promotes it
to a control (structural byte-safety lost; only test-pinned safety remains). Extracting it for
scatter *only* (cave keeps its copy) is relocation, not deduplication. Duplication is honest
ledger weight and keeps `cave_backend.gd` byte-untouched. **Recommendation: duplicate inside
`scatter_backend.gd` for M1.11, ledger-recorded; flag "extract on the third consumer" as a UG3
watch-item** (if a fourth backend ever lands, the refactor happens in ITS version with all
backend suites as the net). *Technical/scope — resolve on merit.*

**Q9 — Clear-lane semantics: full-width protected rows vs a weaker guaranteed route; seed-drawn
vs fixed row; is a guaranteed straight corridor a gameplay problem?** The full-width lane (§3.2)
is the cheapest constructed sightline AND b1's `clear_lane_guarantee` (protected entry→gate
route) in one rule; seed-drawing its row keeps arenas from all reading identically. Weaker
alternatives (guarantee only *a* connected route — already true by §3.3; or a lane that stops
short of full width) lose the S11(a) bar's simplicity for no saved code. The gameplay worry —
"a guaranteed straight sprint lane trivializes the crossing" — is real but is exactly what the
band's natives answer (the Sentry *watches* lanes; the Lobber punishes any straight-line
loitering — the U2a/U2b cover dialogue), and the authored `clear_lane_width` is U3's dial (§2
requires ≥ 2 in M1.11 so the S11(a) bar always exists). **Recommendation: full-width, seed-drawn
row, width required ≥ 2, as specced.** *Mechanism technical — resolve on merit; whether the lane
plays as a highway or a trap is UG2's telemetry read and U3's deck/tuning call — flag the
watch-item forward, no Director gate on U0 itself.*

**Q10 — Stale scatter comments in `test_band_pipeline_parity.gd` + `test_cave_backend.gd`.**
Both files' scatter fail-loud cases keep passing unedited (§1.2), but their comments state
"scatter is unwired", which becomes false. (a) Zero-touch: maximal file-disjointness, lying
comments in two acceptance tests; (b) comment-only touch-up (assertion lines byte-identical),
worklog-flagged — the T0 P7 precedent of keeping acceptance-test documentation truthful, at the
cost of U0 touching a T0-owned test file. **Recommendation: (b)**, as a separate commit so the
diff is self-evidently comment-only. *Technical/hygiene — resolve on merit.*

**Q11 — `edge_cover_bias_pct` two-zone model: enough?** §3.2's rim/center split is the cheapest
integer formula that makes b1's knob real; a smooth gradient (per-stratum linear interpolation of
density by border distance) is ~5 more lines, still integer, and reads better at high bias.
Neither has a consumer until U3 picks the band's authored point — and U3 may well ship bias 0.
**Recommendation: two-zone for U0 (the knob exists, is deterministic, is test-covered by the
dense config); upgrade to a gradient only if U3's tuning asks for it.** *Technical — resolve on
merit; the authored value is U3/Director's.*

**Q12 — Should `_arena_floor` support non-rectangular arenas (corner cuts, irregular rim)?**
The b1 fiction ("a drained basin, a scrap flat") doesn't demand a perfect rectangle, and a
seed-varied rim would soften the greybox look. But: every rim variation re-opens the §3.3
by-construction proof (the perimeter road argument assumes a convex ring), adds draws to the one
RNG block, and is pure aesthetics in a tint-only placeholder version. **Recommendation: rectangle
only in M1.11; note rim variation as a future flavor-stage candidate (a scatter-aware `WearDecay`
sibling), not backend code.** *Scope — resolve on merit (recommend defer); the arena's LOOK is
U3/environment-artist territory regardless.*

---

## 10. Resolved Decisions (Phase 3)

> **Fresh-eyes resolution (qa-playtest-coordinator, 2026-07-06).** Author of §0–§9 was the
> Phase-2 designer; this section is a different agent's adversarial pass, mirroring the T0 §10
> shape. Each entry is **BINDING** on the programmer and, where noted, on U1/U3's Phase-3
> resolvers. The §3.3 no-carve claim was re-derived from scratch (RD-6); the schema was re-verified
> against the real `cave_backend.gd` / `band_pipeline.gd` / `band_profile.gd` / `cave_band_config.gd`
> line refs cited in §1.2/§4 (all hold as of `f555f5c`). Body text these override is called out;
> provenance stays (nothing above is deleted).

**RD-0 — Verification of the doc's as-built anchors (no change; confidence base).** Spot-checked
every load-bearing line ref: `band_profile.gd:26` enum `("socket","cave","scatter")` ✓;
`band_pipeline.gd:51-54` guard `if profile.backend != "socket" and profile.backend != "cave"` ✓
and the cave arm `:73-77` ✓; `band_profile.gd:82-95` socket / `:96-113` cave validate branches with
the flavors fail-loud at `:108-109` ✓; `cave_band_config.gd:64-96` validate incl. the ≥2-chunks
geometry check `:88-95` ✓; `cave_backend.gd` seeding `:67`, entry `:359-371`, chunk emit
`:376-472`, deepest BFS `:479-521`, 2×2-open T `:274-285` ✓; `socket_sealer.gd:57-84`/`:94-101`
caps **every** floor cell's non-floor 4-neighbour with **no perimeter concept** (so cover blobs are
capped by the identical statement that seals the ring) ✓; both existing scatter assertions
(`test_band_pipeline_parity.gd:253-258`, `test_cave_backend.gd:296-301`) survive because a
config-less scatter profile fails `validate()` → the pipeline's `:38-42` validate-then-null ✓. The
design is buildable against the real APIs.

**RD-1 (Q1) — Sampler = order-stable stratified grid-jitter, as §3.2.** *Decision: RATIFIED.*
Rationale: the stratum scan order **is** the "sorted candidate order" the breakdown demands (no
sort imposed on a random stream); the unconditional 4-draw tuple makes the RNG stream length a
pure function of `cfg` (`1 + 4·S`, `S` = stratum count) — strictly stronger than the cave's
outcome-dependent stream and the correct discipline to keep as the binding determinism bar (see
RD-13). Dart-throwing needs an arbitrary `N` and hides the spread in rejection dynamics; Bridson's
active-list + float-annulus violates the repo's order-stability + integer-math rules. *Technical.*

**RD-2 (Q2) — Entry tie-break = lane-aligned (min |y − lane_center|, then min y), as §3.5.**
*Decision: RATIFIED, worklog-flag it as an interpretation of the M1.10 Q10 "west-most" contract.*
The west-most set on an arena is the whole `x = 1` margin column (all floor, all in T by RD-6), so
the tie-break, not the west rule, selects the spawn; lane-aligned is a total order (deterministic),
edge-biased, orientation-stable, and lands the first frame down the guaranteed sightline. `lane_center`
is a pure integer of the seed-drawn `lane_y` — determinism preserved. The cave-verbatim min-y is a
safe fallback if the programmer prefers minimal deviation; either is correct. The *felt meaning* of
that first view is U3's identity material, not a U0 gate. *Technical.*

**RD-3 (Q3) — Default extents = 56×36, as §2.** *Decision: RATIFIED as the U0 test/schema default;*
U3 authors its own point (it proposes 64×64, `chunks_x = 8` — compatible, RD-7/RD-11). U0's tests
bind their own in-code configs, so U3 retuning never touches them. *Technical; felt size is U3/Director's.*

**RD-4 (Q4/OQ12) — The S11 sightline identity bar: three tiers, re-scoped for provability.**
*Decision: RATIFIED with a correction to what is asserted universally.*
- **S11(a) — the constructed lane — is the LOAD-BEARING, by-construction identity bar.** The lane
  rows `[lane_y, lane_y + clear_lane_width)` are all-floor across the full interior width by
  predicate 2 + the margin (no cover admitted in those rows or the margin columns), so **some row's
  uninterrupted floor run `== grid_width − 2` on every seed, every legal config** — a property no
  cave (56 wide but ~45–55% wall, max run ≈ single digits) or socket band can hold. This is the
  provable "reads open" separator. Assert the extents-independent form (`== grid_width − 2`).
- **S11(c) — cover-fraction ceiling — is a BY-CONSTRUCTION guard, but the magic "15%" is WRONG and
  is REPLACED.** Each stratum (side `s = min_cover_spacing + 2`) contributes at most one footprint of
  ≤ 4 cells, so `cover_cells ≤ 4·S` and the interior is `≈ S·s²` → the true by-construction ceiling
  is `4 / s²` of the interior (= **16 %** at the dense test config's `min_cover_spacing = 3`, not
  8 %). Assert `cover_cells · s² ≤ 4 · interior_cells` (integer, non-flaky) rather than a fixed 15 %,
  which a rare all-2×2 seed could exceed and make the test flaky. **This overrides §5 S11(c)'s "≤ 15 %"
  and §3.2's "cover ≤ ~8 % … even at 100" and §5 S11(b)'s parenthetical "≤ ~8 %".**
- **S11(b) — the openness percentile — is BUILD-CALIBRATED, not asserted-universal.** `P = 50` /
  `K = interior_min/2` are plausible but NOT by-construction (at high density with covers on the
  ~`s`-cell lattice, per-cell axis runs can fall below `interior_min/2` on cover-dense rows). The
  programmer measures the actual percentile on **both** the default and dense in-code configs across
  the seed matrix and sets `P`/`K` to the empirically-safe floor **with margin**, recording the
  measured values in the worklog. S11(b) stays in the suite (it separates arena from cave/socket) but
  is calibrated, not magic-numbered. **This overrides §5 S11(b)'s "P = 50 / K = interior_min/2 … must
  hold at the dense config" as a hard universal** — it holds *as measured/calibrated*, with S11(a) as
  the guarantee. *Technical.*

**RD-5 (Q5) — Drop the retry scaffold entirely, as §3.1.** *Decision: RATIFIED.* Floor
`= interior − cover`, and RD-4's stratum bound gives `cover ≤ (4/s²)·interior`, so
`floor ≥ (1 − 4/s²)·interior ≥ 0.84·interior` — there is no undershoot mode; `min_floor_cells`,
`max_attempts`, `_derive_seed` would be untestable dead ledger lines. `requested_seed ==
resolved_seed` always; `band_generation_failed` is never emitted (event-driven consumers already
tolerate this — the cave emits it, socket bands do not require it). **Schema consequence (binding
on RD-11): `ScatterBandConfig` has NO `min_floor_cells` and NO `max_attempts` field** — U3's §4.2
proposal of `min_floor_cells 500` / `max_attempts 8` does not map and must be dropped. *Technical.*

**RD-6 (Q6) — NO defensive carve: "connectivity + player-scale BY CONSTRUCTION" is a compliant
reading, and the §3.3 argument HOLDS. Adversarially re-derived.** *Decision: RATIFIED (no carve),
conditioned on the three schema clamps in RD-8. Worklog-flag as an interpretation of the
breakdown's "…or by deterministic CARVE" (an *or*, per the T0 Q4 precedent).*

I re-derived the worst case (density 100, all-2×2 footprints, `min_cover_spacing = 3`,
`border_margin = 2`, edge-bias extremes) from scratch. The proof rests on three enforced facts:
footprints are **≤ 2×2** (the fixed 4-shape catalog — *not* a knob), any two accepted footprints are
**Chebyshev edge-to-edge ≥ `min_cover_spacing` (≥ 3)** apart (the `_mark_blocked` dilation by
`min_cover_spacing − 1` = 2 rejects anything closer, enforced on actual stamped cells, so
jitter/stratum-boundary spill cannot defeat it), and a **≥ `border_margin` (≥ 2)-wide all-floor
frame** rings the interior (predicate 1).

1. **No two covers even touch.** ≥ 3 Chebyshev apart ⇒ not 8-adjacent ⇒ the cover set is a union of
   isolated ≤ 2×2 blobs. Isolated non-boundary blobs cannot form a spanning wall or enclose a
   region, so the floor (margin frame + between-blob space) is **one 4-connected component**.
2. **Every floor cell is IN T (2×2-open) — stronger than the cave's "in or adjacent to T".** For any
   floor cell `f`, at most **one** footprint can intersect `f`'s 3×3 neighbourhood: two cells from
   different footprints both within Chebyshev 1 of `f` would be ≤ Chebyshev 2 of each other,
   contradicting the ≥ 3 separation. A single ≤ 2×2 footprint touches at most **2 adjacent** of
   `f`'s 8 neighbours, all on one side (a 2×2 can't span `f`'s W-and-E or N-and-S). Hence at least
   one of `f`'s four quadrant 2×2-blocks is all-floor ⇒ `f ∈ T`. The margin (≥ 2) supplies the
   interior-side floor for cells against the wall ring, so border-adjacent floor cells are in T too.
3. **T is a single component** because T = the whole (4-connected) floor set.

Therefore connectivity + 2×2 player-scale hold at **every legal knob value, on every seed, with zero
carve code**. The invariant keeps three teeth (pipeline ASSERT §4.1, S3, S10); if any trips, the
sampler *predicates* are wrong and get fixed at source — never a carve band-aid. **Counterexample
found only OUTSIDE the legal range:** `min_cover_spacing = 2` admits covers flanking `f` at E and W
(Chebyshev 2 apart, legal at spacing 2), leaving `f` a 1-wide impassable slot ∉ T — which is exactly
why RD-8 makes `min_cover_spacing ≥ 3` a hard validate() clamp. Within the legal range, **no
counterexample exists; the no-carve claim is sound.**

**RD-7 (Q7/OQ4) — Cover = stamped non-floor cells, pre-partition, as §3.4.** *Decision: RATIFIED.*
Cover participates in floor/connectivity/`fingerprint` for free; the unedited `SocketSealer` walls
every blob for free (RD-0 confirms it caps interior holes by the same statement as the ring);
`floor_cells` are final before hashing/grading (the determinism contract's hard requirement —
post-partition stamping would mutate emitted pieces). Cover-as-entities is deferred (would need new
collision/LOS now, blinds `fingerprint()`, and turns U2b's "cover blocks the bolt" from
world-mask-free into bespoke code). *Technical.*

**RD-8 (schema clamps — the teeth RD-6 depends on; BINDING on `validate()`).** `ScatterBandConfig.validate()`
MUST reject (return a problem string, so the pipeline `:38-42` returns null) any config that breaches
the by-construction preconditions. Exact clamps:
- `min_cover_spacing ≥ 3` (RD-6's player-scale floor; spacing 2 creates 1-wide slots). **This is the
  passability bar and subsumes U1's request — see RD-9.**
- `border_margin ≥ 2` (the 2×2-open perimeter road).
- `grid_width ≥ 12`, `grid_height ≥ 12`; `cover_density_pct ∈ 0..100`; `edge_cover_bias_pct ∈
  −100..100`; the four cover weights each `≥ 0` with **sum ≥ 1**; `clear_lane_width ∈ 2..interior_height`;
  `cell_size_px ≥ 1`; `chunk_cells ≥ 2`.
- **Depth-axis geometry check — CORRECTED (overrides §2's sum formula).** §2 proposed
  `(ceil(w/cc) − 1) + (ceil(h/cc) − 1) ≥ 4` and called it "the exact chunk-BFS diameter lower bound."
  **That is wrong:** the entry chunk is always at chunk-**column 0** (entry cell x = 1 ⇒ chunk 0), and
  the entry row is lane-aligned (≈ vertical centre), so the true BFS lower bound is
  `chunks_x − 1`, NOT the corner-to-corner sum. A config like `chunks 2×4` passes the sum
  (`1 + 3 = 4`) yet yields `max_depth = 3` on centre-entry seeds — violating the `max_depth ≥ 4`
  bar (S4/C4) it was meant to guarantee. **Replace with `ceil(grid_width / chunk_cells) − 1 ≥ 4`
  (i.e. `chunks_x ≥ 5`).** This is a seed-independent guarantee (`max_depth ≥ chunks_x − 1` always,
  since the deepest chunk-column exists and is ≥ `chunks_x − 1` hops from column 0) and is
  design-aligned (the wide entry-west→gate-east aspect *is* the identity). Default 56×36
  (`chunks_x = 7`) and U3's 64×64 (`chunks_x = 8`) both pass. *Technical.*

**RD-9 (cross-task seam: U0 ⇄ U1 spacing) — U0's Chebyshev `min_cover_spacing ≥ 3` SUBSUMES and
CORRECTS U1's requested "`min_cover_spacing ≥ 2`".** *Decision: BINDING; U1's Phase-3 resolver cites
this.* U1 §2.7 C4 / OQ-2 asked U0 to guarantee `min_cover_spacing ≥ 2` so that "≥ 2-cell gaps"
separate footprints. **The numeric `≥ 2` is inconsistent with U1's own stated goal:** Chebyshev
edge-distance `d` leaves `d − 1` floor cells between footprints, so a **2-cell (2×2-open) gap
requires `d ≥ 3`, not `d ≥ 2`** (spacing 2 leaves a single, impassable 1-cell slot — the exact
counterexample in RD-6). U0's authored `min_cover_spacing ≥ 3` (a) delivers the ≥ 2-cell gaps U1
actually needs, (b) is enforced as a hard `validate()` clamp (RD-8), so the schema range **cannot**
admit a sub-passability value, and (c) therefore fully satisfies U1's C4 traversability contract at
the source. U1's M6 T-coverage certificate remains the independent check; by RD-6 it holds by
construction (indeed every floor cell is in T). **U1 should update its C4/OQ-2 text from "≥ 2" to
"≥ 3 (Chebyshev, U0 RD-8/RD-9)".**

**RD-10 (cross-task seam: U0 ⇄ U3 — flavors + validate).** *Decision: BINDING.* The scatter
`validate()` branch (§4.2) **fail-louds on non-empty `flavors`** exactly like the cave branch
(`band_profile.gd:108-109`) — this is the single-location owner of the scatter-flavors rule, so
U3's `band_four.flavors = []` is *mechanically mandatory* and U3 OQ10 is CONFIRMED (empty, U0 owns
the fail-loud). The branch also does **not** require `piece_pool` (a scattered arena has no authored
pieces; non-null is legal-but-inert) and treats `archetype` as an ignored `push_warning` don't-care
(the arena IS the topology), matching U3 §3.2's `piece_pool = null` / `archetype = "linear"` — both
confirmed non-blocking for U3.

**RD-11 (cross-task seam: U0 ⇄ U3 — the CANONICAL landed schema U3 authors against).** *Decision:
BINDING; this table is THE contract for U3 OQ5. U3's §3.3/§4.2 field list must be re-based onto it —
several names/types differ.*

| Field (canonical) | Type | validate() range | Default | U3's Phase-2 name (to rename) |
|---|---|---|---|---|
| `grid_width` | int | ≥ 12 **and** `ceil(w/chunk_cells) ≥ 5` | 56 | `arena_width` |
| `grid_height` | int | ≥ 12 | 36 | `arena_height` |
| `cover_density_pct` | int | 0..100 | 25 | `cover_density` (was ambiguous-unit; it is an integer **percent** per-stratum stamp chance) |
| `min_cover_spacing` | int | **≥ 3** | 3 | `min_cover_spacing` (same) |
| `border_margin` | int | **≥ 2** | 2 | *(absent in U3 — must be added/accepted at default 2)* |
| `cover_w_1x1` | int | ≥ 0 | 4 | `cover_size_mix[0]` |
| `cover_w_2x1` | int | ≥ 0 | 2 | `cover_size_mix` (no separate 2×1/1×2 in U3) |
| `cover_w_1x2` | int | ≥ 0 | 2 | — |
| `cover_w_2x2` | int | ≥ 0 (sum of the four ≥ 1) | 3 | `cover_size_mix[2]` |
| `edge_cover_bias_pct` | int | −100..100 | 0 | `edge_cover_bias` (integer **percent**) |
| `clear_lane_width` | int | 2..interior_height | 3 | `clear_lane_width` (same) |
| `chunk_cells` | int | ≥ 2 (and drives RD-8's `chunks_x ≥ 5`) | 8 | `chunk_cells` (same) — **CONFIRMED present, U3 OQ5(a) answered: the depth axis chunks** |
| `cell_size_px` | int | ≥ 1 | 16 | `cell_size_px` (same) |

**Not on the schema (RD-5):** `min_floor_cells`, `max_attempts` — U3 must drop both from §4.2, and
its contract-test C3 ("total floor cells ≥ `min_floor_cells`") must be replaced with the RD-5
computed lower bound (`floor ≥ (1 − 4/s²)·interior`) or simply `pieces.size() ≥ 2` + a fixed floor
count measured at build. **Cover representation:** four integer weights, **not** a `cover_size_mix`
array — U3's `[4, 2, 1]` maps to e.g. `cover_w_1x1 = 4, cover_w_2x1 = 1, cover_w_1x2 = 1,
cover_w_2x2 = 1` (small-biased). **Units confirmed for U3 OQ5(b):** density and bias are integer
percents (0..100 and −100..100).

**RD-12 (cross-task seam: U0 ⇄ U3 — sparse intent vs the identity bar; U3 OQ5(c) answered).**
*Decision: U3's sparse-deadly point is fully compatible — CONFIRMED.* The S11 identity bars are
threatened (if at all) only at HIGH cover density; **sparse is the easy direction.** S11(a) (the
full-width lane) holds regardless of density. S11(b)/(c) get *easier* as density falls. Concretely,
any `cover_density_pct` in roughly **[5, 40]** satisfies all three S11 tiers with wide margin (the
bars only get interesting approaching 100). U3's proposed sparse value (its "`cover_density 8`" →
`cover_density_pct = 8`) sits comfortably in the compatible range and *supports* the long-sightline
identity. **Compatible range for U3's authored config: `cover_density_pct ∈ [5, 40]`, rim-biased
(`edge_cover_bias_pct > 0`) — all satisfy the identity bar.** U0 will also sanity-run U3's authored
value set on the seed matrix and report region/sightline/`max_depth` at U3 brief time (the T3 OQ5
precedent) so U3 starts from measured shape.

**RD-13 (determinism bar — KEEP the fixed-length stream, per the breakdown + task constraint).**
*Decision: BINDING.* The RNG stream is exactly `1 + 4·S` draws (one lane-row draw + a fixed 4-draw
tuple per stratum, drawn **unconditionally**, in fixed (stratum-y, stratum-x) order), so its length
is a pure function of `cfg` — stronger than the cave's outcome-dependent stream and the required
determinism discipline. No retry, no carve, no conditional draw may weaken it. `cave_backend.gd`
stays **byte-untouched**; the four controls (`e943ac9c8bc1`, `band_greybox`, `band_two`,
`band_three`) are byte-identical because the only additions on socket/cave paths are string
compares (`… != "scatter"` in the guard + the `elif` arm) — zero draws, zero state (RD-0 confirms).

**RD-14 (Q8) — Duplicate the chunk/emit machinery inside `scatter_backend.gd`; do NOT extract a
shared helper this wave.** *Decision: RATIFIED.* Extracting `synthetic_chunker.gd` would edit
`cave_backend.gd` in the same wave that promotes `band_three` to a byte-identical control — losing
structural byte-safety for only test-pinned safety. Duplication is honest ledger weight and keeps
the cave control structurally safe. **UG3 watch-item: extract on the *third* consumer** (a 4th
backend), in ITS version, with all backend suites as the net. *Technical/scope.*

**RD-15 (Q9) — Clear-lane = full-width protected rows, seed-drawn row, `clear_lane_width ≥ 2`, as
§3.2.** *Decision: RATIFIED (mechanism).* Cheapest constructed sightline + b1's `clear_lane_guarantee`
in one rule; seed-drawing the row keeps arenas from reading identically; it only ADDS floor so it
never threatens RD-6. **Forward watch-item (NOT a U0 gate): whether the guaranteed straight lane
plays as a "highway" that trivialises the crossing is a UG2 telemetry read + U3 deck/tuning call**
(the Sentry watches lanes, the Lobber punishes straight-line loitering — the U2a/U2b cover dialogue
is the designed answer). *Technical.*

**RD-16 (Q10) — Comment-only staleness fixes in `test_band_pipeline_parity.gd` +
`test_cave_backend.gd`: DO them, as a separate assertion-preserving commit.** *Decision: RATIFIED
(option b).* Both files' "scatter is unwired / still-unwired" comments become false; the assertion
lines stay byte-identical (RD-0 verified the assertions still pass). Land the comment touch-up as its
own commit so the diff is self-evidently comment-only, worklog-flagged (the T0 P7 precedent of
truthful acceptance-test docs). *Hygiene.*

**RD-17 (Q11) — `edge_cover_bias_pct` two-zone (rim/centre) model for U0; gradient deferred.**
*Decision: RATIFIED.* The two-zone integer split is the cheapest formula that makes b1's knob real,
deterministic, and test-covered (the dense config exercises it). A per-stratum gradient (~5 more
integer lines) is a U3-driven upgrade only if its authored tuning asks for it. *Technical.*

**RD-18 (Q12) — Rectangle-only `_arena_floor` in M1.11; non-rectangular rim deferred.** *Decision:
RATIFIED (defer).* Every rim variation re-opens RD-6's by-construction proof (the perimeter-road
argument assumes a convex ring) and adds draws to the fixed stream (RD-13), for pure aesthetics in a
tint-only version. Note rim variation as a future scatter-aware flavor-stage candidate (a `WearDecay`
sibling), NOT backend code; the arena's LOOK is U3/environment-artist territory. *Scope.*

**Director review queue (U0): NONE block the build.** Every U0 open question resolves on
technical/scope merit above. The genuine vision/fun/tone calls the arena raises are already routed to
their owners: band identity/tint (U3 D1), the sparse-vs-dense *felt* read (U3 D-cover-density +
UG2), the difficulty step (U3 D4), and whether the open field reads *tense vs empty* / the lane
plays as a highway (UG2 telemetry). U0 ships a deterministic, safe, tunable substrate; no U0-level
Director gate exists.

---

*Spec authored for M1.11 U0 (the third generation backend). Design-only — no code, no `.tres`,
no branch. The programmer builds against this after Phase 3 folds a **Resolved Decisions**
section in below. Deviations from the committed design go to `design/DESIGN_DEVIATIONS.md` for
the Wave-1 close-out sweep.*
