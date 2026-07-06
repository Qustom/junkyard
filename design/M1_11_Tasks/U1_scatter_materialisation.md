# U1 — Scatter Materialisation Ride-Through + Downstream Verify — Expanded Design Spec

**Milestone:** M1.11 (Third Backend + Open-Field Band + Ranged Oppositions) · **Wave:** 2 (U1 ALONE — the version's sole `main_game.gd` writer through its wave)
**Task id:** U1 · **blockedBy:** U0 (ScatterBackend + `ScatterBandConfig` + pipeline dispatch)
**Assignee:** general-purpose (programmer) · **Author:** Phase-2 fan-out (programmer-authored — this task IS an audit of programmer-owned code paths)
**Template:** [`../M1_10_Tasks/T1_cave_materialisation.md`](../M1_10_Tasks/T1_cave_materialisation.md) (the direct predecessor; its Resolved Decisions are BINDING as-built context, cited throughout)
**Source explorations:** [`b1-open-field-with-cover.md`](../explorations/exploration-20260625/procgen-bands/b1-open-field-with-cover.md) (cover-as-stamped-cells is the working assumption this doc certifies) · [`0-scalable-band-generation-system.md`](../explorations/exploration-20260625/procgen-bands/0-scalable-band-generation-system.md) (the materialisation-contract seam)

> **What this doc is.** The Phase-2 design for U1 — the wave that proves a U0-generated open-field band is *playable* on the **existing, unedited** synthetic-piece materialisation path. M1.10's T1 made materialisation backend-agnostic on purpose (`_build_synthetic_piece` hosts ANY `floor_cells`-carrying synthetic piece; the unedited `SocketSealer` is the single wall-writer for every backend); U1's thesis is that backend #3 rides that for **zero new lines**. The core of this doc is therefore an **audit**, not an architecture: §2 walks every step of the cave materialisation path against the real code (`main` @ `f555f5c`) and gives each an explicit *holds-for-scatter* or *RISK* verdict; §3 designs `test_scatter_materialise` (mirroring the cave test's M1–M9 bar) plus the precisely-scoped fix for the one gap the audit found. It is **design only** — no code, no branch. Where U0 (Wave 1, parallel-designed) defines the substrate, the assumed landed contract is stated explicitly in §2.7 and must be re-verified against U0's worklog at brief time.
>
> **Audit verdict up front:** the free ride holds at **every step except one**. The synthetic-piece build, the sealer (including interior cover holes — proven in §2.2), entry spawn, depth/junk/encounter placement, tint, camera, and collision all host scatter output unchanged. The one gap: **`_pinned_gate_pos`'s snap guard is written `backend != "cave"`** (`main_game.gd:1076`), so a scatter band takes the *socket* arm — an unsnapped gate 10 cells east of spawn that lands on a cover cell or ring wall on some seeds → unreachable-gate softlock. The breakdown's own anchor table ("gate snaps to nearest floor (D-RAT-7). Scatter inherits all three bars unchanged") *assumes* the snap generalises; as-built it does not. The fix is a **one-line guard widening** (§3.1) — the honest cost-ledger datum, exactly the "near-nothing gap fix" the breakdown budgets for.

---

## 0. Hard constraints (read first)

From the M1.11 breakdown's scope guardrails + the U1 task contract:

- **U1 is the version's sole `main_game.gd` writer through Wave 2** (single-writer-per-file per wave; U4 writes exactly one `BAND_ROUTES` row + the portal instance in Wave 4). `systems/bandgen/*`, `band_pipeline.gd`, `band_profile.gd` are **U0's** — any need discovered mid-build is a flagged deviation + orchestrator adjudication, never a silent edit. `socket_sealer.gd` is touched by **nobody** (§2.2's whole point).
- **All FOUR control fingerprints byte-identical:** the all-off `RunConfig` fp **`e943ac9c8bc1`**, `band_greybox`, `band_two`, and `band_three` (the cave band is itself a control now). Every new/changed code path must be *unreachable or value-identical* on all four, by inspection — not merely "should behave the same."
- **Existing hub / routing / rg1 / parity / cave suites green UNMODIFIED** — `test_cave_materialise` in particular doubles as U1's cave control (§3.2 M9).
- **Determinism contract:** U1's materialisation-side work adds **zero RNG draws** and never mutates `floor_cells` / the piece list — `Band.fingerprint()` (`band.gd:57-63`) and `floor_fingerprint()` byte-stable pre/post materialise, the standing SocketSealer discipline (`socket_sealer.gd:28-35`).
- **Cost-ledger discipline (the version-defining measure):** U1's worklog carries the bespoke-code ledger. **Target: 0 lines**; the audited expectation after this doc is **1 line** (§3.1) — the deviation from zero IS the finding, itemised, and the headline N=3 datum UG3 judges.
- **No save-schema change. Placeholder art tint-only.** No new `RunConfig` knobs.

---

## 1. Goal & design intent

**One sentence:** *certify — by audit and by test — that a `backend == "scatter"` band materialises, seals, and populates on the code that shipped in M1.10, with cover footprints wall-capped for free by the geometry-keyed sealer, and fix (at single-writer, single-line scope) exactly what the audit proves broken.*

After U1, a scatter dive runs headlessly end-to-end: pipeline → `_materialise_band` builds a greybox host per `scat_` chunk → the unedited `SocketSealer` caps the arena perimeter AND every cover blob → gate snaps to floor → junk + encounters land on reachable floor → tint applies. T1's design intent was "the diff should be small"; U1's is stronger — **the diff should be (nearly) nothing**, because T1 already paid for the generality. The cost ledger is the proof or refutation.

---

## 2. Research — the audit

Every step of the cave materialisation path, walked in execution order against `main` @ `f555f5c`, with a verdict per step. "Scatter output" below = the U0 contract of §2.7 (chunked `scat_` synthetic pieces, `instance == null`, band-global `floor_cells`, cover cells simply absent from every `floor_cells` array — floor-with-holes).

### 2.1 The piece walk + synthetic build — HOLDS, zero lines

`_materialise_band` (`main_game.gd:825-852`) walks `band.pieces`; the T1 branch at `:829-839` fires on `p.instance == null` + non-empty `floor_cells` and calls `_build_synthetic_piece(p)` (`:864-878`). The audit point-by-point:

- **The branch condition is backend-blind.** It keys on the *piece* (`instance == null`), not the profile. U0's `scat_` chunks satisfy it identically to `cave_` chunks. The comment says "cave-backend" (`:830`) — a wording artifact, not a behavior; see OQ-4.
- **`_build_synthetic_piece` reads only `piece_id`, `offset_cell`, `floor_cells`** (`:866`, `:871-873`) — all fields U0's contract carries (§2.7 C3). It writes FLOOR tiles at `cell - p.offset_cell` (the `local = global − offset` invariant every geometry writer shares, `socket_sealer.gd:100`). Nothing cave-shaped: no CA knowledge, no chunk-size assumption, no piece-count cap. An 8×8 arena chunk with 85–95% floor density writes ≤ 64 tiles — same order as a cave chunk.
- **The defensive empty-floor skip (`:837-838`)** never fires: U0 (like T0, §2.7 C1) emits only floor-bearing chunks. Harmless either way.
- **Scale path (`:840-843`)** reads `p.instance.cell_size_px` which the builder sets to 16 (`:867`) — identical to cave. `lvl_size_mult` scaling works verbatim.
- **The lazy tileset load (`:38`, `:870`)** is per-synthetic-piece; already exercised by cave dives. No socket-path impact.
- **Piece cardinality:** a 60×44-class arena at `chunk_cells = 8` yields ~40–48 chunks — the same order as the cave's (56×56 → ≤ 49) and the socket bands' 16–30 pieces. Every downstream piece walk (`_build_cell_depth_map`, `_build_junction_map`, junk, encounters) is O(pieces × cells) with no hard piece-count or piece-size assumption anywhere (searched: no `MAX_PIECES`, no size assert outside U0's own backend). **No max-piece violation exists to find.**

**Verdict: HOLDS — zero lines.** The branch was built for exactly this.

### 2.2 The sealer on an arena with holes — HOLDS, and interior cover holes are capped for free (the load-bearing claim, proven)

The specific risk named by the breakdown: does `SocketSealer` cap **interior** holes (cover-blob perimeters), or only the outer shell?

**Proof from source that it caps both, by the same statement.** `seal_unused_sockets` (`socket_sealer.gd:57-84`) builds the band-global FLOOR set (`:64-67`) and then, for **every floor cell**, caps **every non-floor 4-neighbour** (`:77-84`, cap write `:94-101`). There is **no perimeter concept in the code** — the loop cannot distinguish "outer void" from "interior hole"; both are simply *a non-floor cell 4-adjacent to floor*, and both get a WALL tile. A cover blob's boundary is, cell for cell, floor-facing void — so the entire blob surface is capped by the identical rule that seals the arena's ring. This is not an emergent accident; it is the BUG4 geometry-keyed rule ("caps every floor cell's outward 4-neighbour that is not itself floor" — the doc comment at `:16-20`) applied to a topology it never needed to know about. Closure is **by construction**, the exact inverse of the leak condition `_count_floor_facing_void`.

Three sub-audits on top of the headline:

- **Blob solidity at U0's footprint sizes.** U0 stamps 1–4-cell cover footprints (breakdown §U0). At ≤ 4 cells, **every** cover cell has ≥ 1 floor 4-neighbour (the smallest footprint with a floor-isolated interior cell is 3×3), so every cover cell receives a WALL tile → cover blobs materialise as fully solid, fully colliding greybox. **No walk-through-cover, by construction** — the same physics tile (greybox WALL atlas `(1,0)`, `physics_layer_0`, `collision_layer = 2`) the player already masks (mask 26 ⊇ 2, verified in T1 RD). If a future config ever emits ≥ 3×3 blobs, interiors would be uncapped darkness inside a sealed shell — the shell-only read T1's D-T1-2 already ratified for cave voids; see OQ-5.
- **Wall-count / perf — no explosion; scatter is CHEAPER than the cave it already ships.** Distinct WALL tiles = |non-floor cells 4-adjacent to floor| ≈ arena ring perimeter + total cover cells. A 60×44 arena with ~50 blobs averaging 2.5 cells: ≈ 2·(60+44) + 125 ≈ **~330 wall tiles**. The shipped cave control (56×56, fill 45) has an irregular shell empirically in the high hundreds to ~1000+ tiles — scatter's wall set is the *smaller* of the two, and both ride the engine's quadrant-batched TileMapLayer physics that 16–30 authored pieces already exercise per socket band. Cap-*write* count ≈ 4× tile count (idempotent re-writes across shared neighbours) ≈ ~1.3k `set_cell` calls, trivial. **No perf guard is needed; the "0 lines" target does not bend for perf** (the OQ the breakdown asked us to run down — answered with arithmetic, closed).
- **Cross-chunk cap ownership.** A wall cell adjacent to floor cells owned by different chunks is capped into each owner's sparse layer — duplicate overlapping WALL tiles at one world cell. Precedented (branchy socket bands post-BUG4; every cave chunk seam in M1.10), idempotent per layer, physics-harmless, and immaterial to the point-query closure test (any layer's tile answers the query). Scatter adds nothing new here.
- **The sealer's only requirement** — `owner.instance != null` with a `"Geometry"` TileMapLayer (`:95-99`) — is satisfied because `_materialise_band` assigns instances *before* the seal call (`:839` runs in the walk; `:851` seals after). Same ordering as cave, unchanged.

**Verdict: HOLDS — zero lines, zero sealer edits.** The unedited `SocketSealer` wall-caps the arena perimeter AND every cover footprint. This is the version's headline claim, and it survives the audit intact.

### 2.3 The gate — **RISK: the D-RAT-7 snap is cave-gated; scatter takes the unsnapped socket arm** (THE gap)

`_pinned_gate_pos` (`main_game.gd:1074-1090`):

```gdscript
if _band_profile == null or _band_profile.backend != "cave":
    return want                    # socket / harness path: today's exact value
```

A `backend == "scatter"` profile fails the `!= "cave"` test's *else*, i.e. **returns the raw `spawn_pos + GameState.GATE_SPAWN_OFFSET`** — the fixed cell 10 east of spawn — with no snap. All three call sites inherit the miss: the all-off single gate (`:1105`), the play preset's keep-one gate (`:1117`), and the candidate-pool exclusion (`:1194`).

Why that is a real softlock, not a cosmetic miss: the spawn anchor is the **west-most** 2×2-open floor cell (U0 contract, §2.7 C2), so 10-east is well inside the arena — but on some seeds that specific cell is a **cover cell** (stamped non-floor) or, on a narrow config, the ring wall. The gate itself never collides (`extract_gate.tscn` is Area-driven, verified in T1 RD) — it spawns fine, renders fine, and **cannot be reached**: the player's 28 px disc cannot stand inside a sealed cover blob, and on the play preset the pinned gate is very likely the *only* gate (T1 RD OQ-1's arithmetic: `floor(0.1·depth)` extra exits ≈ 0–1). An instant, seed-dependent run-softlock — precisely the failure class D-RAT-7 fixed for caves.

The breakdown anticipated the *bar* ("gate snaps to nearest floor (D-RAT-7). Scatter inherits all three bars unchanged") but the as-built guard was written **denylist-style** (`!= "cave"`) in a two-backend world. The audit's conclusion: **scatter does NOT inherit D-RAT-7 without a guard change.** Fix design in §3.1 — a one-expression flip to allowlist form (`== "socket"`), byte-identical on socket/null/cave paths by inspection, snap armed for scatter (and any future non-socket backend by default — the right polarity for an N-backend world). Alternatives weighed in OQ-1.

Everything else about gates HOLDS: the `exit_enabled` scatter arm (`_exit_placement_positions`, `:1167-1184`) draws from floor cells via a local sub-stream; `_exit_candidate_cells` (`:1190-1201`) excludes the pinned cell *through the same `_pinned_gate_pos` helper*, so the fix propagates to the exclusion for free; `_exit_count_for_depth` floors at 1. Snap determinism: pure geometry over sorted-emitted `floor_cells`, `Vector3i(d2, y, x)` lexicographic total order, zero RNG, run-state only — and when the wanted cell IS floor (d2 = 0) the snap returns the identical cell centre, so the fix is a **no-op on every seed where U0's layout happens to leave 10-east clear**.

### 2.4 Entry spawn — HOLDS, on U0's inherited anchor contract

`_entry_spawn_position` (`:1056-1062`) reads `band.entry_piece.floor_cells[0]`, centre of cell. Nothing cave-specific — it is the same read the M1.10 amendment-2/3 contract (CT-2) fixed for synthetic backends: entry anchor = west-most **2×2-open** floor cell, **front-positioned** as `floor_cells[0]` of the entry chunk. The breakdown's anchor table carries all three bars to scatter unchanged; U0 owns emitting them (§2.7 C2), U1's test asserts them end-to-end (M4). **Verdict: HOLDS — zero lines; enforced by test, guaranteed by U0.**

### 2.5 Downstream consumers — HOLDS across the board

Walked one by one (each already proven backend-agnostic by the cave, re-checked for arena-shaped input):

| Consumer | As-built read | Scatter verdict |
|---|---|---|
| `_build_cell_depth_map` (`:904-917`) | floor cells → `(depth_index, dist_to_gate)`; no instance reads | **HOLDS.** Chunked `scat_` pieces grade exactly like `cave_` chunks; U0's `max_depth ≥ 4` bar (breakdown §U0 DoD) keeps the depth/loot economy live — the amendment-4 lesson, already answered by reusing the chunk idiom. |
| `DepthGrader` piece-BFS | floor 4-adjacency across piece boundaries | **HOLDS.** Chunk grid adjacency is the cave case with fewer holes. |
| `JunkPlacer.plan` (`:271`; `junk_placer.gd:96`) | `floor_cells` walk, `cell_size_override` **always passed** from `start_new_run` → the `instance == null` 16-px fallback is never hit | **HOLDS — zero lines.** Junk lands on floor cells only. Exposed-centre vs cover-edge *feel* is placement-blind uniform scatter — the breakdown explicitly routes that to a UG1 eyeball, not code. |
| `EncounterBuilder.populate` / `SpawnService` | floor cells + `depth_index` policy; entry-safety skip `depth_index <= 0`; `room_key = str(p.offset_cell)` unique per chunk; BUG7 spawn-radius exclusion via ctx | **HOLDS.** Chunk = "room"; J2 even-spread walks chunk floor cells; budget × instability(4) is U3's concern, not U1's. No corridor-width assumption exists in the builder (bounds are per-piece floor rects). |
| `_hazard_spawn_position` (`:775-788`) / R1 lanes | floor cells of pieces at target depth, piece order | **HOLDS.** |
| Tint (`:279`) | `_band_container.modulate = _band_profile.palette_tint` — whole-container | **HOLDS — zero lines.** Runtime-built arena children inherit the modulate exactly as cave chunks do (M8 asserts with a non-white tint). |
| Camera (`CameraView`, K3/K6 rig) | level-owned follow rig, fixed visible world-width from cam_* knobs | **HOLDS.** No corridor/piece assumption anywhere in the rig; an open arena just fills the frame with more floor. Long sightlines are the *point* (b1) — any "too exposed" feel is a UG2 watch-item by breakdown guardrail. |
| Player collision | mask 26 ⊇ wall layer 2; 28 px disc | **HOLDS** for walls/cover (§2.2). Traversability *between* cover blobs is a generation-side guarantee — §2.7 C4 + OQ-2; U1's test carries the independent 2×2-open certificate (M6), the exact T1 OQ-3 division of labor: widening mutates `floor_cells`, so it MUST live in U0; U1 structurally cannot fix a red M6. |
| `_resolve_player_depth` / `_update_player_piece` (`:1004-1033`) | off-floor cells keep last known depth/piece | **HOLDS.** Cover cells map to no depth; the player can't stand there anyway. |
| `_clear_band` (`:1213-1222`) | frees container children; SpawnService reset | **HOLDS.** Synthetic hosts are container children like any piece. |

### 2.6 Telemetry-reading notes (correct-by-definition zeros — carried to UG2, not bugs)

- **`corridor_frac = 0` on scatter:** `scat_<hash>` ids are never in `RunConfig.CORRIDOR_PIECE_IDS` (`:932-933`), so every arena chunk classifies "room" — the identical, already-ratified cave posture (T1 OQ-8: accepted, noted in the analysis plan). One line in UG2's plan extends the note to four bands.
- **`nav_branch_taken` noise under R4:** interior arena chunks have junction degree 3–4 (`_build_junction_map`, `:925-957`), so with `r4_enabled` nearly every chunk crossing emits. Same class as the cave's chunk-degree inflation; emit-side only (R4-gated), no gameplay effect. UG2 reading note.

### 2.7 Integration assumptions on U0 (verify against U0's worklog at brief time; any drift = stop and adjudicate)

Mirrors T1 §2.7 / T0's C-contract, transposed. U0's Phase-2 doc is parallel-authored — these are the bars U1's design *requires*, sourced from the breakdown's binding §U0 text + the T0 synthetic-piece contract it inherits:

- **C1 (chunked pieces):** the arena is emitted as multiple synthetic `PlacedPiece`s (content-hashed `scat_` ids, the cave chunking idiom), entry chunk first, floorless chunks skipped; `max_depth ≥ 4` on defaults across the seed matrix.
- **C2 (entry anchor):** `entry_piece.floor_cells[0]` = the west-most 2×2-open floor cell, front-positioned (the CT-2 canon). `deepest_piece` set by the pipeline tail grade.
- **C3 (piece fields):** stable content-hashed `piece_id`; band-global sorted `floor_cells` (cover cells absent — **cover is stamped non-floor cells, not entities**: the ratified working assumption, breakdown OQ-4); `footprint_cells` = chunk rect; `offset_cell` honoring `local = global − offset`; `instance == null`; `open_sockets` empty; `mated_socket_index = -1`.
- **C4 (connectivity + traversability):** single connected FLOOR component by construction; **Chebyshev `min_cover_spacing ≥ 3` between cover footprints (and blob-to-ring) leaves the ≥ 2-cell gaps this bar needs** *(corrected per U0 RD-8/RD-9 — this doc originally asked "≥ 2", which was numerically inconsistent with its own 2-cell-gap goal: Chebyshev edge-distance `d` leaves `d − 1` floor cells between footprints, so 2-cell gaps require `d ≥ 3`; U0 enforces ≥ 3 as a hard `validate()` clamp)*, so the 2×2-open traversable set T covers the arena (every floor cell in T or 4-adjacent to T — and U0's RD-6 proof in fact delivers the stronger form: **every floor cell is IN T**; see RD-U1-2). Floor-*connectivity* alone is NOT sufficient for a 28 px player — a 1-cell slot between blobs is connected but impassable; this is the second real audit finding, routed as a U0 contract bar + U1 test certificate (OQ-2).
- **C5 (dispatch):** `BandPipeline.generate` replaces the fail-loud (`band_pipeline.gd:51-54` — as-built: `backend != "socket" and != "cave"` → error) with scatter dispatch mirroring the cave arm, and the tail grade runs for scatter. `BandProfile.validate()` gains the scatter branch incl. the flavors fail-loud. All U0's files; U1 asserts outcomes only.
- **C6 (reachability path):** U1's end-to-end proof is component-driven (pipeline → materialise → plan → populate in one headless test), NOT portal-routed — `BAND_ROUTES` gains no scatter key until U4.

---

## 3. Pseudocode

Illustrative, against the as-built APIs; the programmer owns the real code.

### 3.1 The gap fix — one expression in `_pinned_gate_pos` (the entire expected feature diff)

```gdscript
## M1.11 (U1): guard flipped denylist -> allowlist. Snap-to-nearest-floor (D-RAT-7)
## now arms for EVERY synthetic backend (cave + scatter + future); only the socket
## backend -- whose authored entry pieces make the fixed offset historically safe --
## and the null-profile harness path keep the raw offset. Socket/null return values
## are byte-identical by inspection; the cave arm's behaviour is unchanged (proven
## by test_cave_materialise staying green unmodified).
func _pinned_gate_pos(band: Band, spawn_pos: Vector2) -> Vector2:
    var want := spawn_pos + GameState.GATE_SPAWN_OFFSET
    if _band_profile == null or _band_profile.backend == "socket":   # WAS: backend != "cave"
        return want
    # ... snap body verbatim (:1078-1090) — zero RNG, Vector3i(d2, y, x) total order ...
```

Byte-safety by inspection: `_band_profile == null` (every existing harness) → `want`, unchanged. `backend == "socket"` (band_greybox, band_two, all-off) → `want`, unchanged — the guard short-circuits before any band walk, so the all-off fp and both socket band fps cannot move. `backend == "cave"` → falls through to the snap, the same arm as today (band_three fp pinned by existing suites; `test_cave_materialise` M5/M6 green unmodified is the proof). `backend == "scatter"` → snap, the new behavior. All three call sites (`:1105`, `:1117`, `:1194`) inherit the fix through the shared helper — **no other touch point exists**. When 10-east is already floor the snap degenerates to the identical cell centre, so the fix only *acts* on the seeds that would have softlocked.

**Ledger entry: 1 changed line of non-data, non-test code** (+ its docstring — recorded separately, not counted; see OQ-4). If Phase-3 / U0's landed design instead guarantees the offset cell by construction (OQ-1 option B), this line is not written and the ledger reads 0 — the fix is designed either way so Wave 2 cannot stall on it.

### 3.2 `tests/test_scatter_materialise.gd` (+ `.tscn`) — headless SCENE, mirroring the cave M1–M9 bar

Shape cloned from `test_cave_materialise.gd` (the proven harness: bare `MainGame` script instance, injected `_band_container`/`_band_cell_size_px`/`_band_profile` so the gate guard arms; same seed matrix `[12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]`; profile built **in code** off `ScatterBandConfig.new()` schema defaults — the T1 OQ-6 resolution inherited verbatim, no fixture `.tres` to collide with U3's `band_four` authoring). Helpers (`_floor_owners`, `_traversable_set`, `_flood_over_set`, `_component_count`) reused in shape.

```
M1  Materialise closure (THE bar): generate -> _materialise_band -> for EVERY floor
    cell, each 4-neighbour is floor OR its owner Geometry layer holds the greybox
    WALL cap. Because the rule is perimeter-blind (§2.2), this single assertion
    covers the arena ring AND every cover-blob surface at once. Every seed.
M2  Collision truth — the anti-walk-through-cover bar: after a physics-frame await,
    direct_space_state point queries (mask 2):
      (a) EVERY cover cell (non-floor cell 4-adjacent to floor, enumerated from the
          floor set) HITS — exhaustive on seed[0] (~150-350 queries, cheap);
      (b) sampled ring-wall cells HIT; (c) sampled floor cells MISS.
    Cover-cell enumeration needs no U0 internals: cover == capped void, derivable
    from floor_cells alone. (Breadth trade in OQ-3.)
M3  Determinism: fingerprint() + floor_fingerprint() byte-equal pre/post
    _materialise_band, every seed (zero RNG, no floor mutation).
M4  Anchors: spawn cell == entry_piece.floor_cells[0], IS floor, IS 2x2-open;
    max_depth >= 4; deepest_piece.depth_index == max_depth. Every seed.
M5  Gate: all-off rc -> exactly 1 gate, its cell IS floor (the §3.1 snap armed for
    scatter), reachable from spawn over floor 4-adjacency. Preset rc (exit_enabled +
    keep_one) -> every gate cell IS floor. Every seed.
M6  2x2-open throat certificate: T (all-floor 2x2-block membership) is a single
    component; spawn anchor in T; the all-off gate cell in T's flood from spawn OR
    4-adjacent to it (the Area-gate adjacency allowance, cave-test precedent).
    PLUS the arena-specific coverage bar (§2.7 C4): every floor cell is in T or
    4-adjacent to a T cell -- the certificate that makes M7's loot reachable by a
    28px player, not merely floor-connected. Every seed.
M7  Downstream population: JunkPlacer.plan -> every world_pos maps to a floor cell;
    _spawn_new_hazards (play preset) -> >= 1 spawn, every spawn cell floor at
    depth_index > 0. No sealed-off loot: with M6's T-coverage + single-T-component
    green, every junk/spawn/gate cell is player-reachable BY IMPLICATION — no
    per-item flood needed (the cheap assertion, OQ-2 rationale).
M8  Tint: _band_container.modulate == profile.palette_tint (non-white test tint)
    through the assignment path.
M9  Backend controls: (a) socket — _materialise_band on a band_greybox pipeline band
    adds exactly pieces.size() children and builds ZERO synthetic hosts (instances
    identity-unchanged); (b) cave — the UNMODIFIED test_cave_materialise suite green
    in the same verify run is the cave-side regression control (no duplicated cave
    asserts here; one extra guard-arm check: a cave-profile _pinned_gate_pos call
    still snaps, pinning §3.1's cave-arm equivalence from inside this test too.)
```

Plus the existing suites as regression, unmodified: `test_bandgen_determinism`, `test_band_pipeline_parity`, `test_band_two_profile`, `test_cave_materialise`, `test_scatter_backend` (U0's), `test_rg1_m1*` fp pins, hub/routing. Run serially — never concurrent headless godot (import-lock).

### 3.3 Files to create / touch

**Create:** `Game/tests/test_scatter_materialise.gd` + `.tscn`.
**Touch:** `Game/scenes/game/main_game.gd` ONLY — the §3.1 one-expression guard flip (+ docstring). **Nothing else**: no new helper, no new const, no materialise edit — the T1 machinery hosts scatter as-is.
**Must NOT touch:** `systems/bandgen/*` (incl. `socket_sealer.gd` and U0's new `scatter_*.gd`), `band_pipeline.gd`, `band_profile.gd`, `data/**`, `entities/**`, any committed golden/fixture, any existing test.

## 4. Definition of done (restated, concrete)

1. `test_scatter_materialise` green (M1–M9) across the seed matrix.
2. All FOUR control fingerprints byte-identical (`e943ac9c8bc1`, `band_greybox`, `band_two`, `band_three`); every existing suite green **unmodified**.
3. Import + smoke green; a component-driven scatter dive (generate → materialise → junk + gate + spawns on FLOOR) proven headlessly by M5+M7.
4. Worklog with **the headline cost ledger** (audited expectation: **1 line** — or **0** if OQ-1 resolves to option B) naming commit SHA(s) + deviations; board mirrored.

---

## Open Questions

- **OQ-1 — The gate-gap fix: guard flip in `main_game.gd` (A, recommended) vs U0-side clear-lane guarantee of the offset cell (B) vs both (C)? *(technical — resolve on merit, with one messaging note)*** **A** (§3.1): 1 line, robust against any config/extents, the correct allowlist polarity for an N-backend world, and self-noöps when the cell is clear. **B**: U0's clear-lane machinery additionally protects the 10-cells-east-of-anchor cell → U1 writes 0 lines — but it couples the *backend* to a materialisation constant (`GameState.GATE_SPAWN_OFFSET`) it has no business knowing, fails silently if the offset or arena extents ever change, and leaves every future backend to rediscover the trap. **C**: belt-and-braces at no interaction cost (the snap degenerates when B holds). Recommend **A** (C if U0's lane covers the offset incidentally); the ledger honestly records 1 — the breakdown's own "the deviation from zero IS the finding" clause. The messaging note (whether "≈0" survives as the headline vs "1, and here's why that's the proof the seam works"): cosmetic, fold into the UG3 ledger narrative — flag to Director only if Phase 3 thinks the headline matters.
- **OQ-2 — Traversability vs connectivity: where does the ≥2-cell cover-gap guarantee live? *(cross-task seam — orchestrator adjudicates with U0 before Wave-1 dispatch, the CT-3 pattern)*** §2.7 C4's finding: U0's "cover never disconnects the floor" invariant is necessary but NOT sufficient for the 28 px player — a 1-cell slot between blobs is connected-but-impassable, which would strand loot behind an untraversable gap (the scatter sibling of T1's throat problem). Division of labor exactly per T1 OQ-3's ratified protocol: **U0 owns the guarantee** (`min_cover_spacing ≥ 3` — Chebyshev, corrected per U0 RD-8/RD-9: this doc's original "≥ 2" left a single impassable 1-cell slot, the exact RD-6 counterexample — between footprints and blob-to-ring, a stamping-time rejection rule, deterministic, pre-fingerprint, enforced as a hard `validate()` clamp), **U1 owns the independent certificate** (M6's T-coverage bar: every floor cell in T or 4-adjacent to T), and a red M6 routes to a pre-agreed U0 config/rule follow-up — never a U1 patch (widening mutates `floor_cells`; U1 structurally cannot). Needs U0's Phase-2/3 to ratify the same text.
- **OQ-3 — M2 point-query breadth: exhaustive cover-cell queries on seed[0] + tile-atlas-only checks matrix-wide (recommended) vs exhaustive physics queries on every seed? *(technical — resolve on merit)*** Physics queries need a materialised in-tree band + a physics-frame await per band; 9 materialise+await cycles are affordable but slow the suite for little marginal truth — M1's tile-atlas closure already runs matrix-wide and the tileset's tile→polygon mapping doesn't vary by seed. Recommend the cave test's economy: physics truth once, geometric truth everywhere.
- **OQ-4 — Comment hygiene: T1's synthetic-piece comments say "cave-backend" and the D-RAT-7 docstring says "Cave bands" — retitle to "synthetic backends" in the §3.1 commit, or leave? *(hygiene — resolve on merit)*** The `_pinned_gate_pos` docstring MUST change (its behavior does); recommend updating **only** the comments in the functions the diff already touches and leaving `_materialise_band`/`_build_synthetic_piece` wording for the post-TG3/UG3 hygiene pass already holding the `SocketSealer` rename (T1 OQ-7) — diff purity in the version whose bar is a near-zero diff. Comment lines recorded in the worklog but outside the bespoke-code ledger count (the ledger measures code).
- **OQ-5 — Cover blob solidity ceiling: should `ScatterBandConfig` structurally cap footprints at ≤ 2×2 / ≤ 4 cells so blobs stay fully capped, or accept shell-only interiors if a bigger blob ever ships? *(rider to U0, look-adjacent — recommend accept-with-note)*** At U0's declared 1–4-cell mix the question is moot (§2.2: every cover cell is floor-adjacent → solid). If a future band wants boulder-scale cover, interiors read as darkness inside a sealed shell — the exact look D-T1-2 ratified for cave void. Recommend: no schema cap, one sentence in U0's config doc noting the ≥3×3 threshold; Director sees the look only if/when such a config is authored.
- **OQ-6 — Telemetry zeros (§2.6): accept `corridor_frac = 0` + high junction-degree `nav_branch_taken` on scatter as definitionally correct? *(reading note — confirm at UG2 setup)*** Both are the already-ratified cave posture (T1 OQ-8) extended to backend #3. Recommend accept + one bundled line in UG2's analysis plan (with the depth-unit note: arena chunk-hops ≈ cave chunk-hops, both ≠ socket piece-hops).

---

## Resolved Decisions (Phase 3)

> **Fresh-eyes resolution (Phase-3 resolver — NOT the Phase-2 author), 2026-07-06.** Verified
> against `main` @ `2816bdd`; the three commits since the doc's audited `f555f5c` are design-docs
> only (`git diff --stat f555f5c..2816bdd` on `main_game.gd` / `systems/bandgen/` / `data/bands/`
> is **empty**), so every line cite below was re-checked at effective code parity with the audit.
> Upstream Wave-A contracts read in full: U0 §10 RD-0…RD-18 (RD-6/RD-8/RD-9 are load-bearing
> here). Each entry is **numbered and BINDING** and **overrides the body text where they
> conflict**; nothing above is deleted (the two RD-9 spacing corrections are folded inline into
> §2.7 C4 and OQ-2, provenance preserved).

**RD-U1-0 — As-built verification of the two load-bearing audit claims: BOTH HOLD (independently re-derived from source).**
- **(a) Sealer caps interior cover holes identically — VERIFIED.** `seal_unused_sockets`
  (`socket_sealer.gd:57-84`) builds the band-global floor dict at `:64-67` and, for every floor
  cell, caps every non-floor 4-neighbour at `:77-84` via `_place_wall_cap` (`:94-101`). Read in
  full: there is **no perimeter/frontier concept anywhere in the pass** (the BUG4 rewrite removed
  it by design, doc comment `:11-20`) — "outer void" and "interior cover hole" are
  indistinguishable to the loop; both are *a non-floor cell 4-adjacent to floor*. §2.2's proof is
  sound, and independently matches U0's RD-0 spot-check. The `:95-99` requirements
  (`owner.instance != null`, `"Geometry"` layer) are met by `_materialise_band`'s
  assign-then-seal ordering (`:839` before `:851`) — confirmed.
- **(b) Gate-snap guard is denylist-style and the allowlist flip is byte-identical on
  socket/null/cave — VERIFIED, all three call sites walked.** The guard is exactly
  `if _band_profile == null or _band_profile.backend != "cave": return want`
  (`main_game.gd:1076-1077`). The flip to `== "socket"` re-derived arm by arm: **null** → first
  clause short-circuits, `want`, unchanged; **socket** → `want`, unchanged; **cave** → falls
  through to the snap body — the same arm it takes today; **scatter** → snap (the new behavior;
  today it returns raw `want`). All three call sites — all-off pin (`:1105`), keep-one
  (`:1117`), candidate-pool exclusion (`:1194`) — route through the one helper; `grep` confirms
  `:1076` is the **only** `_band_profile.backend` conditional in `main_game.gd`, so no second
  denylist lurks. **One footnote to §3.1's "no other touch point exists":** `:1170`
  (`_exit_placement_positions`'s degenerate empty-pool fallback) also computes
  `spawn_pos + GATE_SPAWN_OFFSET` raw — it is *not* a `_pinned_gate_pos` call site, fires only
  when the candidate pool is empty (structurally impossible on a scatter arena with hundreds of
  floor cells), and is untouched by the flip. Correct as-is; noted for the programmer so the
  grep-match doesn't read as a missed site.

**RD-U1-1 (OQ-1) — The fix is the §3.1 allowlist flip (option A). RATIFIED; ledger = 1. New fresh-eyes finding: option B holds *incidentally* at defaults under U0's resolved geometry — and that is precisely why it cannot be relied on.**
Under U0's Phase-3-resolved predicates, the 10-east offset cell is floor **by construction at
default-shaped configs** for *both* legal entry tie-breaks: the spawn column is `x = 1`
(west-most 2×2-open, inside the ≥ 2-wide all-floor margin frame, U0 RD-6 predicate 1), and the
spawn row is either `lane_center` (RD-2's lane-aligned tie-break → the row is all-floor across
the full interior width, RD-15) or `y = 1` (RD-2's sanctioned min-y fallback → inside the
all-floor margin frame). Either way `(x+10, y)` is constructed floor — the softlock §2.3
describes is **latent at RD-11 defaults, not seed-frequent** (a truthfulness correction to
§2.3's "on some seeds that specific cell is a cover cell"). The flip is ratified anyway, on
three grounds: **(i) the coincidence is uncontracted** — no U0 `validate()` clamp, test, or
RD mentions `GATE_SPAWN_OFFSET`; RD-2 explicitly leaves the tie-break to the programmer; nothing
pins spawn-row/lane alignment forever. **(ii) It fails inside the legal schema range:** RD-8
admits `grid_width = 12` with `chunk_cells = 2` (`ceil(12/2) = 6 ≥ 5` passes), where floor spans
`x ∈ 1..10` and the offset cell `x = 11` **is the ring wall** — the softlock is real at legal
corners, and only the snap is robust across the whole config space. **(iii) Allowlist polarity
is the correct N-backend default** (backend #4 inherits the snap for free), and the snap
self-degenerates to the identical cell centre whenever the offset cell is floor — so at
defaults the flip is behaviorally invisible *and* structurally load-bearing. This is
effectively option C at zero extra cost, with U0's lane as the incidental belt. **The
messaging footnote resolves on merit, no Director gate:** UG3 is already the Director's read;
the ledger reports the fact — "1 line, itemised" — per the breakdown's own "the deviation from
zero IS the finding" clause. §3.1's "or 0 if option B" contingency and DoD item 4's "(or 0…)"
are **dead**: the answer is 1.

**RD-U1-2 (OQ-2) — Spacing seam SETTLED by U0 RD-8/RD-9 (this doc's "≥ 2" corrected to Chebyshev ≥ 3 inline); M6's certificate is STRENGTHENED to the provable form.**
U0's hard `validate()` clamp `min_cover_spacing ≥ 3` (Chebyshev, enforced by `_mark_blocked`
dilation on actual stamped cells) subsumes and corrects this doc's request — the schema *cannot*
admit a sub-passability value, so C4's guarantee lives at the source exactly as OQ-2's protocol
wanted. Per U0 RD-6's re-derived proof, the truth on every legal config is **stronger** than
this doc's certificate: *every floor cell is IN the 2×2-open set T* (not merely in-or-4-adjacent),
and T equals the whole 4-connected floor set. **M6 is therefore re-specified to assert the
stronger, still by-construction form:** (a) every floor cell ∈ T; (b) T is a single component
(== the floor set); (c) spawn anchor ∈ T and the all-off gate cell in T's flood from spawn (or
4-adjacent, the Area-gate allowance). This tightens the regression tripwire on U0's predicates
at zero flakiness cost and makes M7's reachability implication direct (junk on floor ⇒ junk in
T). The division-of-labor protocol is RATIFIED verbatim: a red M6 routes to a pre-agreed U0
config/predicate follow-up, **never** a U1 patch (widening mutates `floor_cells`; U1
structurally cannot) — the T1 OQ-3 / CT-3 pattern, third application.

**RD-U1-3 (OQ-3) — M2 breadth: RATIFIED as recommended — physics truth once, geometric truth everywhere.**
Exhaustive `direct_space_state` point queries (mask 2) on seed[0] only — every cover cell
(enumerable from `floor_cells` alone: non-floor 4-adjacent to floor), sampled ring cells,
sampled floor negatives — after ONE physics-frame await (the T1 resolved-section implementation
note carries over); M1's tile-atlas closure runs matrix-wide. **Arithmetic corrected to RD-11
defaults:** at 56×36 / density 25 / stratum side 5 (≈ 60 strata → ~15 stamps × mean footprint
24/11 ≈ 2.2 cells), expect **~25–40 cover cells**, not §3.2's "~150–350 queries" (an estimate
predating U0's resolved units) — the exhaustive sweep is even cheaper than the doc assumed.

**RD-U1-4 (OQ-4) — Comment hygiene: RATIFIED as recommended.** The `_pinned_gate_pos`
docstring (`:1065-1073`) MUST be rewritten in the same commit — its "Socket bands (and every
non-cave harness path)" description becomes false with the flip — along with the two
stale `# cave: snap-to-floor … socket: today's value` call-site comments (`:1105`, `:1117`)
that name the arms. The `_materialise_band`/`_build_synthetic_piece` "cave-backend" wording
(`:830`, `:855`) is **left untouched**, deferred to the post-TG3/UG3 hygiene pass already
holding the `SocketSealer` rename (T1 OQ-7) — diff purity in the version whose bar is a
near-zero diff. Comment/docstring lines are recorded in the worklog but **excluded from the
bespoke-code ledger count** (the ledger measures code; the count stays 1).

**RD-U1-5 (OQ-5) — MOOT by U0 RD-6/RD-11, resolved stronger than the doc asked.** The
footprint catalog is **fixed at the four ≤ 2×2 shapes and is not a knob** (U0 RD-6's proof
premise; RD-11's schema carries four *weights*, no size field) — so the ≥ 3×3
uncapped-interior case is structurally unreachable this version, and there is no schema cap to
add because there is no size knob to clamp. Any future boulder-scale cover config must re-open
U0 RD-6's by-construction proof (its ≤ 2×2 premise is load-bearing for passability, not just
capping) — *that* is the real gate, and the shell-only-interior look note (D-T1-2 precedent)
travels with it. No U0 config-doc sentence needed beyond what RD-6 already states; no Director
item until such a config is actually authored.

**RD-U1-6 (OQ-6) — Telemetry zeros: ACCEPTED as definitionally correct.** `corridor_frac = 0`
(no `scat_` id in `CORRIDOR_PIECE_IDS`, `:932-933`) and R4 junction-degree `nav_branch_taken`
inflation are the ratified cave posture (T1 OQ-8) extended to backend #3. One bundled line in
UG2's analysis plan covering all four bands, including the depth-unit note (arena chunk-hops at
`chunk_cells = 8` ≈ cave chunk-hops; both ≠ socket piece-hops). Confirmed at UG2 setup;
emit-side only, no build change.

**RD-U1-7 — §2.2 wall-count arithmetic corrected to U0's RESOLVED defaults; the verdict
strengthens.** §2.2's "~330 wall tiles" was computed on a hypothetical 60×44 arena with ~50
blobs × 2.5 cells. At the landed RD-3/RD-11 defaults (56×36, `cover_density_pct = 25`
per-stratum, stratum side `s = 5`, weights 4/2/2/3): ring ≈ 2·(54+34) = **~176** wall cells +
cover ≈ 15 stamps × 24/11 ≈ **~33** cells → **~210 distinct WALL tiles** (idempotent `set_cell`
writes ≈ low hundreds, not "~1.3k" — each ring cap has 1 floor neighbour, cover caps up to 4).
Every directional conclusion holds *a fortiori*: scatter's wall set is far smaller than the
shipped cave's (high hundreds+), no perf guard is needed, the 0-line target does not bend.

**RD-U1-8 — Final ledger expectation: EXACTLY 1 changed line of non-data, non-test code** (the
`:1076` guard expression), plus its rewritten docstring/comments recorded-but-uncounted
(RD-U1-4). Files: `main_game.gd` (the 1 line) + the two new test files (`test_scatter_materialise.gd`/`.tscn`,
outside the ledger by definition). All four control fingerprints byte-identical by the RD-U1-0(b)
arm walk; every existing suite green unmodified, with `test_cave_materialise` doubling as the
cave-arm equivalence proof and M9's in-suite cave-profile guard-arm check pinning it from this
suite too.

**Director review queue (U1): NONE.** The doc's author flagged only OQ-1's headline-messaging
footnote as arguably Director-facing; RD-U1-1 resolves it on merit (UG3 — already
Director-owned — receives the itemised "1 line" ledger with the §3.1 rationale; no build-time
vision/fun/tone/scope call exists in U1's scope).
