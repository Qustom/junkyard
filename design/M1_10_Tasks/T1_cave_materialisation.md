# T1 — Cave Materialisation + Backend-Agnostic Sealing + Downstream Verify — Expanded Design Spec

**Milestone:** M1.10 (Second Backend + Cave Band + Low-Sightline Oppositions) · **Wave:** 2 (T1 ALONE — the version's sole `main_game.gd` writer)
**Task id:** T1 · **blockedBy:** T0 (CaveBackend + `CaveBandConfig` + pipeline dispatch)
**Assignee:** general-purpose (programmer) · **Author:** game-director-designer (Phase-2 fan-out)
**Source explorations:** [`b3-organic-caverns.md`](../explorations/exploration-20260625/procgen-bands/b3-organic-caverns.md) (the "tile-world vs piece-world" open flag this doc closes) · [`0-scalable-band-generation-system.md`](../explorations/exploration-20260625/procgen-bands/0-scalable-band-generation-system.md) (Phase D's materialisation-contract seam)

> **What this doc is.** The Phase-2 design for T1 — the wave that makes a T0-generated cave *playable*: runtime greybox floor visuals + wall collision from `floor_cells`, void-sealing without sockets, and the downstream verify (DepthGrader anchors, JunkPlacer, EncounterBuilder, camera/player collision, `palette_tint`). It is **design only** — no code, no branch. Pseudocode is illustrative against the real as-built APIs (`main` @ `303f14e`); where T0 (Wave 1, parallel-designed) changes the substrate, the assumed landed contract is stated explicitly in §2.7 and must be re-verified against T0's worklog at brief time.

---

## 0. Hard constraints (read first)

From the M1.10 breakdown's scope guardrails + the T1 task contract:

- **Socket-band materialisation stays byte-identical.** `band_greybox` and `band_two` fingerprints unmoved; the existing `test_rg1_m1*` / hub / routing / parity suites green **unmodified**. Every new code path must be *unreachable* on a socket band (guarded or structurally impossible), not merely "should behave the same."
- **All-off fp `e943ac9c8bc1` unmoved** (pinned at `test_corridor_lever.gd:34`, `test_charger.gd:52`, `test_deck_entry.gd:31` among others).
- **T1 is the version's ONLY `main_game.gd` writer** (breakdown scope guardrail; single-writer-per-file per wave). `band_pipeline.gd` / `band_profile.gd` / `systems/bandgen/` generation internals are T0's — T1 does not edit them; any need discovered mid-build is a flagged deviation + orchestrator adjudication, not a silent edit.
- **Determinism contract:** materialisation adds **zero RNG draws** and never mutates `floor_cells` / the piece list — `Band.fingerprint()` (`band.gd:58-62`) and `floor_fingerprint()` (`band.gd:76-88`) are byte-stable across materialise, exactly as the SocketSealer discipline established (`socket_sealer.gd:28-35`).
- **No save-schema change. Placeholder art tint-only** (`palette_tint` tier-1; pixel filter OFF; no PixelLab run in T1).
- **Cost-ledger discipline:** T1's worklog carries the bespoke-code ledger (files + line counts of non-data, non-test code) — T1 *is* the "materialisation contract reused" half of the scalability claim TG3 judges.

---

## 1. Goal & design intent

**One sentence:** *give a synthetic (piece-less, socket-less) band a materialisation path — runtime-built greybox geometry + collision from `floor_cells`, sealed by the already-geometry-keyed sealer — such that every downstream consumer (depth, loot, encounters, camera, player, tint) works unchanged, and the socket path is untouched by construction.*

After T1, `_materialise_band` reads: authored instance → place it (today's path, byte-identical); no instance + floor cells → **build** it (the new path); then `SocketSealer` seals the whole band exactly as today. The design intent, in the breakdown's own terms: T1's diff should be *small* — the M1.9 architectures claimed the materialisation contract was backend-agnostic; T1's cost ledger is the proof or refutation.

---

## 2. Research

### 2.1 The as-built materialisation path, and where a cave band currently dies

`_materialise_band` (`main_game.gd:818-836`) walks `band.pieces`, and for each piece: **skips `p.instance == null`** (`:822-823`), computes the scale mult from `p.instance.cell_size_px` (`:824-825`), positions at `offset_cell * cell_size` (`:826`), parents into `_band_container` (`:828`), then runs `SocketSealer.seal_unused_sockets(band, cell_size)` (`:835`). T0's synthetic pieces carry `floor_cells` but `instance == null` (the backend is deliberately scene-free so the pipeline tests stay headless-pure), so **a cave band materialises as nothing**: no visuals, no collision, a player falling through void. The null-skip is the exact seam: on socket bands `BandGenerator._make_placed` (`band_generator.gd:413`) always instantiates a `ZonePiece` scene, so `instance == null` is **unreachable on the socket path** — a new branch behind that null test is byte-invisible to `band_greybox`/`band_two` by construction. That is the load-bearing observation of this whole design.

Downstream of materialise, `start_new_run` (`main_game.gd:199-353`) already consumes only backend-agnostic surfaces:
- `_build_cell_depth_map` (`:862-875`) — floor cells → `(depth_index, dist_to_gate)`; no instance reads.
- `placer.plan(band, …, cell_size_px, …)` (`:264`) — `JunkPlacer` walks `floor_cells` with the **`cell_size_override` always passed** (`junk_placer.gd:96`), so its `_cell_size_px(p)` instance-fallback (`junk_placer.gd:198-200`) is never hit from `start_new_run`. Loot plan is instance-null-safe today.
- `_band_container.modulate = _band_profile.palette_tint` (`:272`) — a whole-container modulate; runtime-built children inherit it **for free**. Tint-ready is a zero-line feature.
- `_entry_spawn_position` (`:1014-1020`) — `entry_piece.floor_cells[0]` centred; instance-free.
- `_place_gate` (`:1029-1055`) — all-off pins one gate at `spawn_pos + GameState.GATE_SPAWN_OFFSET` (`game_state.gd:30` — `(160, 0)`, i.e. **10 cells east of spawn**); `exit_enabled` scatters over floor cells. One cave problem here — §2.5.
- `EncounterBuilder.populate` — floor-cell + `depth_index` policy throughout (`encounter_builder.gd:210`, `:313`); `SpawnService.begin_band/cell_to_world/valid_cells` (`spawn_service.gd:81-86`, `:208`, `:219-221`) are pure cell↔world math. One cave dependency here — §2.4.
- Depth driver + junction map (`:883-915`) — floor cells only. Note: piece-kind classification (`:891`) keys `RunConfig.CORRIDOR_PIECE_IDS.has(piece_id)`; synthetic ids are not in that list, so **every cave chunk classifies as "room"** and J4's `corridor_summary` telemetry reads `corridor_frac = 0` on cave runs. Correct-by-definition (a cave has no corridors in the authored sense); recorded as a TG2 telemetry-reading note, not a bug.

**Conclusion:** the only band-facing code that *needs* new work is `_materialise_band` (build the missing instance) and the pinned-gate position (§2.5). Everything else is verify, not build — if that survives contact with the code, the cost ledger will show it.

### 2.2 What the sealer actually is now — and why OQ4 mostly dissolves

`SocketSealer` is misnamed since BUG4: it is **geometry-keyed, not socket-keyed** (`socket_sealer.gd:16-26`). `seal_unused_sockets` builds the band-global FLOOR set across all pieces and caps *every floor cell's non-floor 4-neighbour* with a WALL tile written into the owner piece's `Geometry` TileMapLayer (`:57-84`, cap write `:94-101`). It reads no sockets, rolls no RNG, mutates no `floor_cells`. Two properties make it cave-perfect as-is:

1. **The cap rule is exactly a cave's wall-front definition.** For an organic blob, "every floor-adjacent non-floor cell becomes WALL" *is* the complete reachable wall surface — pinched throats, nook fringes, chamber rims, and the map perimeter all in one pass, closure **by construction** (the same argument BUG4 made for branchy bands: the rule is the exact inverse of the leak condition `_count_floor_facing_void`, `test_bandgen_determinism.gd:22-29`).
2. **Caps may land outside the owner's authored rect** — a TileMapLayer is sparse/unbounded (`:90-92`, explicit in the sealer's own doc) — so the owner-assignment never needs cave-specific geometry logic.

Its **only** requirement is `owner.instance != null` with a `"Geometry"` TileMapLayer child (`:95-98`; it silently no-ops otherwise). So the T0/T1 seam position (breakdown OQ4): **the backend emits no walls and no sealing data; T1's synthetic instance carries a `Geometry` TileMapLayer; the sealer runs verbatim, zero edits.** Not a no-op, not a bypass, not a sibling — the third option the breakdown didn't list: *already generalized*. Socket-band byte-safety is then trivial (an unedited file cannot regress), and the sealer becomes the single wall-writer for caves, which also minimizes collision tile count (§2.3, web-perf watch-item at TG2).

The same instance contract is what `WearDecayStage._write_cell` (`wear_decay.gd:137-152`) and `ConnectivityGuarantee.revert_op` (`connectivity_guarantee.gd:88-103`) key on — cave flavors ship EMPTY in M1.10 (breakdown guardrail), but choosing this shape means the flavor machinery is *not structurally excluded* from caves later. That is free future-proofing, worth a line in the ledger.

### 2.3 Breakdown OQ3 — greybox geometry per synthetic piece vs a generated TileMapLayer: both researched, one recommended

The b3 exploration flagged "tile-world vs piece-world" as the architecture question. Three concrete candidates, evaluated against the as-built consumers:

| | **(A) Per-piece runtime `Geometry` TileMapLayer** (recommended) | (B) One band-level generated TileMapLayer | (C) Polygon2D/ColorRect visuals + StaticBody2D collision rects |
|---|---|---|---|
| Collision source | Existing `greybox.tres` tileset — WALL atlas `(1,0)` carries the 16×16 physics polygon on `physics_layer_0`, `collision_layer = 2` (`data/tilesets/greybox.tres`), the layer the player already masks (`player.tscn:14` — mask 26 ⊇ 2) and every socket wall uses | Same tileset — same collision semantics | Bespoke: hand-built StaticBody2D + rect merging for sane body counts |
| SocketSealer | Works **verbatim** (§2.2) — per-piece `Geometry` is its write target | Needs an owner-remap or a sealer edit (caps key on `owner.instance`) — the byte-safety bar now touches a socket-path file | Doesn't apply — a bespoke perimeter pass must be written and proven |
| WearDecay / ConnectivityGuarantee revert | Compatible unchanged (same `p.instance`→`Geometry` contract) | Incompatible without edits (per-piece ownership assumed) | Incompatible |
| `_materialise_band` scale path | Reuses `:824-827` unchanged (`cell_size_px`, `position`, `scale`) | New special-case beside the piece walk | New special-case + separate visual/collision scaling (drift risk) |
| Node count | ~1 TileMapLayer per chunk (T0 emits chunked pieces, §2.4 — order tens) | 1 | Hundreds of rects, or a merge pass |
| Visual identity | Greybox floor/wall tiles, `palette_tint` via container modulate — matches socket bands' look vocabulary | Same | Flat rects; diverges from the band look for no gain |

**Recommendation: (A).** The decisive evidence is the second and third rows: (A) is the only option under which *zero socket-path files change* — the sealer, the flavor write/revert machinery, and the materialise scale path all keep their exact contracts because the synthetic piece *impersonates the authored one* at the node-contract level (`Geometry` TileMapLayer child, `cell_size_px`, `piece_id`). (B)'s single layer is marginally cheaper at runtime but forces edits into `socket_sealer.gd` (or a parallel sealer — breakdown OQ4's worse branches) and walls off the flavor stages from caves permanently. (C) re-derives collision the tileset already provides and is strictly worse. This closes the b3 "tile-world vs piece-world" flag: **the cave stays a piece-world citizen; the pieces are just born at runtime.** Per-cell TileMapLayer physics is the engine's quadrant-batched path — the same mechanism ~16-30 authored pieces already use per socket band; a cave's shell-only wall set (§3.2) keeps the physics tile count the same order of magnitude. TG2's web-perf question is watched, not pre-solved.

**Wall-fill policy under (A):** T1 writes **FLOOR tiles only** (atlas `(0,0)`, no collision) into each synthetic `Geometry` layer; the **sealer contributes the entire WALL shell**. This is the minimal-collision, minimal-code shape: no interior solid-mass fill, so unreachable wall interiors carry zero tiles and the void beyond the 1-tile shell reads as darkness — acceptable greybox, and honest about what a cave is. The alternative (solid WALL fill across each chunk's `footprint_cells`) is a look/perf trade flagged in §6 (OQ-2).

### 2.4 The depth axis on a cave — the input contract T0 must honor (piece granularity)

`DepthGrader` grades **pieces**, not cells: BFS over piece-level adjacency derived from floor 4-adjacency (`depth_grader.gd:83-104`, `:26-49`). If T0 emitted the cave as ONE synthetic piece, the whole downstream depth axis collapses: `max_depth = 0`, every cell depth 0 → **`EncounterBuilder` spawns nothing** (entry-safety skip `depth_index <= 0`, `encounter_builder.gd:210`/`:313`), the depth curve samples 0 everywhere, K7's depth-scaled exit count flattens, R1's depth thresholds clamp to 0, and the HUD depth reads 0 for the whole dive. So T1's design states, as a **hard input contract on T0** (coordinate at brief time; any drift = stop and adjudicate):

- **T0-C1 (chunked pieces):** the backend emits the cave as **multiple synthetic `PlacedPiece`s** — fixed-size grid chunks (e.g. 8×8 cells) or flood-regions, T0's call — such that piece-level BFS yields a real gradient (`band.max_depth ≥ 4` on the default config across the seed matrix; T1's test asserts this bar end-to-end).
- **T0-C2 (entry anchor):** `band.entry_piece` set; its `floor_cells[0]` is the spawn anchor (`_entry_spawn_position` reads exactly that, `main_game.gd:1017`) and has **2×2 open clearance** (player circle radius 14 (`player.tscn:10`) → 28 px diameter > one 16 px cell — see §2.6). `band.deepest_piece` set by the pipeline's tail grade as today (`band_pipeline.gd:112`).
- **T0-C3 (piece fields):** each synthetic piece carries stable `piece_id` (fingerprint identity — breakdown OQ5, T0's), band-global `floor_cells` (sorted (y,x) for order-stability), `footprint_cells` ⊇ `floor_cells` (the chunk rect — used by T1 only for local-rect derivation), `offset_cell` such that `local = global − offset_cell` (the invariant every writer assumes, `socket_sealer.gd:100`, `wear_decay.gd:144`), `instance == null`, `mated_socket_index = -1`, `open_sockets` empty.

`EncounterBuilder`'s entry-skip doubles as cave entry-safety for free; room bounds (`_floor_bounds_world` over chunk floor cells) and the J2 even-spread walk work per-chunk unchanged. `_hazard_spawn_position` (`main_game.gd:768-781`) and the R1 lanes ride the same chunk depth axis.

### 2.5 Gate placement — the one downstream consumer that is NOT floor-safe on a cave

Both the all-off control (`main_game.gd:1034-1036`) and the play preset (`exit_keep_one_at_spawn = true`, `run_config.gd:901`, path `:1046-1047`) pin a gate at `spawn_pos + (160, 0)` — 10 cells due east. On socket bands the authored entry pieces make that historically safe; on a CA cave the cell 10 east of spawn is **wall or void on most seeds**. The gate itself doesn't collide (`extract_gate.tscn:10-11` — Area-driven interactable), so it wouldn't block — it would be **unreachable**, an instant run-softlock. Fix (cave-only, guarded on `_band_profile.backend == "cave"`, null-safe → socket path byte-untouched): **snap the pinned gate to the nearest floor cell** to the intended offset — deterministic tie-break `(dist², y, x)`, pure geometry, zero RNG (§3.3). The `exit_enabled` scatter path (`_exit_placement_positions`, `:1097-1114`) already draws from floor cells and needs nothing; `_exit_candidate_cells`' exclusion of the pinned cell (`:1120-1129`) must exclude the **snapped** cell on caves (same helper, one call site).

### 2.6 Player-scale sanity — why the throat bar is 2 cells, and who enforces it

Numbers: cell = 16 px (`DEFAULT_CELL_SIZE_PX`, `main_game.gd:55`; `greybox.tres` tile size); player collision = CircleShape2D radius 14 → **28 px diameter** (`player.tscn:9-10`). A 1-cell throat (16 px between wall physics polygons) is **impassable**; a 2-cell throat (32 px) passes with 4 px total margin. CA output at ~45% fill routinely produces 1-cell throats. Therefore:

- **The guarantee belongs generation-side (T0),** because widening is a `floor_cells` mutation and `floor_cells` must be final before grading/fingerprinting — T1 (materialisation) structurally *cannot* widen without breaking the determinism contract. Position: T0's `CaveBandConfig` carries the config floor (a min-throat/roughness knob per its own task goal — "nook/roughness knob"; a deterministic post-CA widening or a 2×2-erosion-guided dilation both qualify; T0's design chooses the mechanism).
- **T1 ships the independent bar as a test** (the breakdown's "min-corridor-width check" reading): `test_cave_materialise` asserts spawn→gate connectivity over **2×2-open cells** (a cell is 2×2-open iff it belongs to at least one 2×2 all-floor block — a 28 px disc fits a 32×32 px block, so a 2×2-open path is a sufficient traversability certificate for the player circle). This is a pure-geometry check over `floor_cells`, seed-matrix-wide, and it fails loudly if T0's guarantee regresses. Seam adjudication flagged in §6 (OQ-3).

### 2.7 Integration assumptions (verify against T0's worklog at brief time)

- **(a)** `BandPipeline.generate` dispatches `backend == "cave"` (replacing the fail-loud at `band_pipeline.gd:45-48`) and returns a **graded** band (tail grade `:112-113` runs for caves too) with `entry_piece`/`deepest_piece`/`max_depth` set. If grading doesn't run on the cave path, T1 stops and escalates — grading is pipeline-owned, not T1's to add.
- **(b)** The T0-C1..C3 piece contract of §2.4 (chunking, anchor, fields). The `max_depth ≥ 4` bar and the 2×2 clearances are asserted, not assumed.
- **(c)** `BandProfile.validate()` gained a cave branch (T0's) accepting `backend_config is CaveBandConfig` — and (T1 flags for T0) it should **reject non-empty `flavors` on cave profiles** in M1.10, matching the breakdown's flavors-ship-EMPTY guardrail. If T0 didn't add that rejection, T1 records it as a deviation, not a T1 edit.
- **(d)** Cave `fingerprint()` stability across materialise — holds by construction if T1 adds no RNG and never touches `floor_cells`/pieces; asserted in the test anyway (the sealer's own pre/post-seal fp bar, `test_bandgen_determinism` check 10, transposed to caves).
- **(e)** A cave dive reaches materialisation only via a `backend == "cave"` profile; `BAND_ROUTES` (`main_game.gd:49-52`) gains no cave key until T4 — T1's end-to-end proof is component-driven (pipeline → materialise → plan → populate in one headless test), NOT a portal-routed `start_new_run` (that is T4's contract check).

---

## 3. Pseudocode

Illustrative, against the as-built APIs; the programmer owns the real code. New helpers live in `main_game.gd` (T1 is its sole writer; a separate `systems/` file for ~60 lines of materialise-only code would scatter the seam — revisit if a second consumer appears).

### 3.1 `_materialise_band` — the diff shape

```gdscript
## M1.10 (T1): synthetic pieces (cave backend — instance == null, floor_cells
## carried) get their greybox instance BUILT here at materialise time: a runtime
## ZonePiece host + generated Geometry TileMapLayer (FLOOR tiles; the sealer
## contributes the WALL shell). Socket bands never hit the branch (the generator
## always instantiates authored scenes), so the legacy path is byte-identical.
func _materialise_band(band: Band, cell_size: int = DEFAULT_CELL_SIZE_PX) -> int:
	for p in band.pieces:
		if p.instance == null:
			if p.floor_cells.is_empty():
				continue                                  # defensive: the legacy skip, kept
			p.instance = _build_synthetic_piece(p)        # NEW — the only new line on the walk
		var base_cell := p.instance.cell_size_px if p.instance.cell_size_px > 0 else DEFAULT_CELL_SIZE_PX
		var mult := float(cell_size) / float(base_cell)   # unchanged (:824-827)
		p.instance.position = Vector2(p.offset_cell * cell_size)
		p.instance.scale = Vector2.ONE * mult
		_band_container.add_child(p.instance)
	SocketSealer.new().seal_unused_sockets(band, cell_size)  # unchanged (:835) — on a cave
	return cell_size                                          # this pass IS the wall-writer (§2.2)
```

### 3.2 `_build_synthetic_piece(p: PlacedPiece) -> ZonePiece` — the new helper

```gdscript
const GREYBOX_TILESET_PATH := "res://data/tilesets/greybox.tres"  # load lazily: socket dives never load it here

## Build the runtime greybox host for one synthetic piece. Node contract mirrors
## the authored ZonePiece scenes exactly (Geometry TileMapLayer + Sockets holder)
## so SocketSealer._place_wall_cap, WearDecay._write_cell and the I1 scale path
## all work verbatim. FLOOR tiles only — WALL shell comes from the sealer (§2.3).
## Pure function of the piece's cell data: no RNG, no floor_cells mutation.
func _build_synthetic_piece(p: PlacedPiece) -> ZonePiece:
	var host := ZonePiece.new()                    # typed slot: PlacedPiece.instance is ZonePiece (placed_piece.gd:17)
	host.piece_id = p.piece_id
	host.cell_size_px = DEFAULT_CELL_SIZE_PX       # authored-base 16; caller's mult handles lvl scaling
	var geo := TileMapLayer.new()
	geo.name = "Geometry"                          # the name every writer keys on (sealer :97, decay :141)
	geo.tile_set = load(GREYBOX_TILESET_PATH)
	for cell in p.floor_cells:                     # band-global -> piece-local (the :100 invariant)
		geo.set_cell(cell - p.offset_cell,
				ConnectivityGuarantee.GREYBOX_SOURCE_ID, ConnectivityGuarantee.FLOOR_ATLAS)
	host.add_child(geo)
	var sockets := Node2D.new()
	sockets.name = "Sockets"                       # empty holder: silences ZonePiece._ready's warning (:73)
	host.add_child(sockets)
	return host
```

Notes: `ZonePiece._ready` recomputes `footprint_cells`/`occupied_cells` from the layer (`zone_piece.gd:58-66`) — harmless and correct for the synthetic host. Tile writes before tree entry are valid (TileMapLayer data is node-local). `palette_tint` needs nothing: `_band_container.modulate` (`:272`) modulates the runtime children like any authored piece.

### 3.3 Cave-safe pinned gate — `_pinned_gate_pos` + the two `_place_gate` touch points

```gdscript
## The pinned/near-spawn gate position. Socket bands: the historical fixed offset,
## byte-identical. Cave bands: the offset cell is wall/void on most seeds (§2.5),
## so snap to the NEAREST floor cell — deterministic tie-break (dist², y, x),
## pure geometry over floor_cells, zero RNG, run-state only (never in fingerprint()).
func _pinned_gate_pos(band: Band, spawn_pos: Vector2) -> Vector2:
	var want := spawn_pos + GameState.GATE_SPAWN_OFFSET
	if _band_profile == null or _band_profile.backend != "cave":
		return want                                # socket/harness path: EXACTLY today's value
	var want_cell := _world_to_cell(want)
	var best := want_cell;  var best_key := Vector3i(2147483647, 0, 0);  var found := false
	for piece in band.pieces:
		for c in piece.floor_cells:
			var d2 := (c - want_cell).length_squared()
			var key := Vector3i(d2, c.y, c.x)      # dist², then (y, x) — total order, seed-stable
			if not found or _key_lt(key, best_key):
				best = c; best_key = key; found = true
	return _density_cell_to_world(best) if found else want
```

Touch points, each a one-expression swap: `:1035` all-off → `_spawn_gate_at(_pinned_gate_pos(band, spawn_pos))`; `:1047` keep-one → `positions.append(_pinned_gate_pos(band, spawn_pos))`; `:1122` candidate exclusion → `_world_to_cell(_pinned_gate_pos(band, spawn_pos))`. On socket bands all three return today's exact value (guard short-circuits before any band walk) — byte-identity is by inspection, and the untouched suites prove it.

### 3.4 `tests/test_cave_materialise.gd` (+ `.tscn`) — headless SCENE, house rules

Mirrors `test_band_two_profile.gd`'s shape (seed matrix `[12345, 99999, 1, 2, 7, 808, 424242, -33, 1000003]`, per-check helpers, exit-code contract). The cave profile is **built in code** (`BandProfile.new()` + `CaveBandConfig.new()` at T0's shipped defaults) — no committed `.tres` fixture to collide with T3's `band_three.tres` authoring (§6 OQ-6). A bare `MainGame` instance with an injected `_band_container` Node2D drives materialise (the `test_new_hazard_spawn` harness pattern); `_band_profile` is injected so the cave gate guard arms.

```
M1. Materialise closure (THE bar): generate via BandPipeline → _materialise_band →
    for EVERY floor cell, each 4-neighbour is floor OR its owner Geometry layer holds
    WALL atlas (1,0) — _count_floor_facing_void == 0 transposed to caves. Every seed.
M2. Collision truth: sampled wall cells report the greybox WALL tile (source 0, (1,0))
    whose tileset physics polygon (layer 2) is the collision — plus a physics-query
    spot-check (direct_space_state point query inside a wall cell hits; floor doesn't).
M3. Determinism across materialise: fingerprint() + floor_fingerprint() byte-equal
    before vs after _materialise_band (no RNG, no floor mutation), every seed.
M4. Anchors: spawn cell = entry_piece.floor_cells[0], IS floor, has 2×2 open clearance;
    band.max_depth >= 4 (the §2.4 chunk-granularity bar); deepest_piece non-null with
    depth_index == max_depth.
M5. Gate: all-off rc → single gate; its cell IS floor (the §2.5 snap); reachable —
    flood-fill from spawn over floor 4-adjacency covers the gate cell. Preset rc
    (exit_enabled + keep_one) → every gate cell is floor.
M6. Throat bar (§2.6): spawn→gate connectivity over 2×2-OPEN cells only, every seed —
    the player-circle traversability certificate.
M7. Downstream population: JunkPlacer.plan → every world_pos maps back to a floor cell;
    EncounterBuilder.populate with make_default_play_preset() + an armed SpawnService
    (begin_band with the real container/entry) → >= 1 spawn lands, every spawn cell is
    floor at depth_index > 0 (proves chunked grading feeds the builder end-to-end).
M8. Tint: _band_container.modulate == profile.palette_tint after the start-of-run
    assignment path (driven directly; a non-white test tint).
M9. Socket control: _materialise_band on a band_greybox pipeline band adds exactly
    band.pieces.size() children pre-seal and builds ZERO synthetic hosts (every
    p.instance already a ZonePiece scene instance) — the null-branch is unreachable.
```

Plus the existing suite as regression, unmodified: `test_bandgen_determinism`, `test_band_pipeline_parity`, `test_band_two_profile`, `test_rg1_m1*_verify` (fp pins), hub/routing tests. Run serially (never concurrent headless godot — import-lock).

### 3.5 Files to create / touch

**Create:** `tests/test_cave_materialise.gd` + `.tscn`.
**Touch:** `scenes/game/main_game.gd` ONLY — the `_materialise_band` null-branch (§3.1), `_build_synthetic_piece` (§3.2), `_pinned_gate_pos` + 3 call-site swaps (§3.3), one lazy tileset const.
**Must NOT touch:** `systems/bandgen/*` (incl. `socket_sealer.gd` — §2.2's whole point; comment-only edits also skipped to keep the diff clean), `band_pipeline.gd`/`band_profile.gd`/`cave_*.gd` (T0's), `data/run_config/*`, `entities/*`, any committed golden/fixture.

## 4. Definition of done (restated, concrete)

1. `test_cave_materialise` green (M1–M9) across the seed matrix.
2. Socket byte-identity: `test_bandgen_determinism` + `test_band_pipeline_parity` + `test_band_two_profile` + `test_rg1_m1*` + hub/routing suites green **unmodified**; all-off fp `e943ac9c8bc1` unmoved.
3. Import + smoke green; a component-driven cave dive (generate → materialise → junk + gate + spawns on FLOOR) proven headlessly by M5+M7.
4. Worklog (with the bespoke-code ledger — expected order: ~1 branch line + ~60 helper lines + ~15 gate lines) naming commit SHA(s) + deviations; board mirrored.

---

## Open Questions

- **OQ-1 — Pinned-gate semantics on caves: snap-to-nearest-floor (recommended) vs gate-at-deepest-region? *(feel — needs Director review)*** The pinned gate is the "way home near where you came in" anchor — snapping preserves that read (§2.5, §3.3) and is the minimal change. A deepest-region gate would make caves extraction-different from every other band (a real design fork, not a bug fix). Recommend snap; Director confirms the extraction feel is meant to stay uniform across backends.
- **OQ-2 — Wall look: 1-tile sealer shell over darkness (recommended) vs solid WALL fill of each chunk rect? *(tone/readability — needs Director review, cheap to flip)*** Shell-only is minimal collision + code and reads "grown void-cave"; solid fill reads "carved mass" and costs ~grid-area tiles (web-perf watch-item, TG2). Flippable post-playtest by adding one fill loop in §3.2 — recommend shipping shell-only and letting the Director judge on the TG1 build.
- **OQ-3 — Throat-width ownership: T0 config-floor guarantee + T1 test bar (recommended) vs T1-only check? *(technical seam — orchestrator adjudicates with T0 before Wave 1 dispatch)*** §2.6's argument: widening mutates `floor_cells`, so it MUST live before grading (T0); T1 materialisation cannot do it without breaking determinism. If T0 lands without a guarantee, M6 red-flags the seeds and the fix is a T0 follow-up, never a T1 patch.
- **OQ-4 — Chunk granularity / `max_depth ≥ 4` bar: is 4 the right floor for the default config? *(technical, resolve on merit with T0)** Too-coarse chunks flatten the depth economy (loot curve, encounter budget, K7 exits all key on depth); too-fine chunks inflate piece counts (junction map, builder walks). 8×8 chunks on the exploration's default grid gives roughly spine-like depth ranges; T0's design should co-own the number and T1's M4 pins whatever is ratified.
- **OQ-5 — Synthetic host construction: runtime `ZonePiece.new()` assembly (recommended, §3.2) vs a committed `cave_piece.tscn` template? *(technical — resolve on merit)*** Runtime assembly keeps the cave fully data-born (no scene asset whose edits could drift from code); a `.tscn` template is more editor-inspectable. The typed `PlacedPiece.instance: ZonePiece` slot (`placed_piece.gd:17`) is satisfied either way. Recommend runtime; flip if the programmer hits `_ready`-ordering friction.
- **OQ-6 — Test profile as in-code construction (recommended) vs a committed `tests/fixtures/cave_test.tres`? *(technical — resolve on merit)*** In-code avoids a second cave-profile artifact that T3's `band_three.tres` authoring (and its contract test) could half-duplicate; the cost is the test pinning T0's config defaults in code. Recommend in-code with the defaults read off `CaveBandConfig.new()` (schema defaults, not literals) so a T0 default-tune doesn't break the test.
- **OQ-7 — Should `SocketSealer` be renamed/re-documented as the backend-agnostic `PerimeterSealer` it now is? *(hygiene — scope call, recommend defer)*** Accurate naming vs touching a socket-path file in the exact version whose bar is "socket path untouched." Recommend: defer to a post-TG3 hygiene task; T1's worklog notes it.
- **OQ-8 — Cave runs report `corridor_frac = 0` (synthetic ids are never in `RunConfig.CORRIDOR_PIECE_IDS`, `main_game.gd:891`). Accept as definitionally correct? *(telemetry-reading note — confirm at TG2 setup)*** Recommend accept + a one-line note in TG2's analysis plan so the three-band comparison doesn't misread the zero.
