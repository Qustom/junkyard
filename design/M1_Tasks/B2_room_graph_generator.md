# B2 — Modular Room-Graph Generator (M1 Prototype)

**Summary:** Instance zone-piece `PackedScene`s and stitch them into a single connected band via socket-adjacency matching, driven entirely by the seeded `RNG` autoload so layouts are reproducible. Cyclic-loop backbone and full WFC are stubbed/minimal for M1.

- **Parent task:** B2
- **Dependencies:** B1 (zone-piece format + tagged sockets), `RNG` autoload (seeded RNG service).
- **Acceptance criterion:** Given a seed, the generator produces a connected, walkable band; the **same seed produces a byte-identical layout**, verified by an automated test.

This is the heart of M1 proc-gen: the Spelunky/Dead-Cells-lineage modular stitcher. Start from an entry gate, repeatedly pick a frontier socket, pick a compatible piece, place it so its mating socket aligns, reject overlaps, and continue until the band reaches a target length. Every random choice flows through `RNG` so the whole assembly is a pure function of the seed.

---

## Assets needed

```
/systems/bandgen
  band_generator.gd         # BandGenerator: the stitching algorithm
  placed_piece.gd           # PlacedPiece: a piece instance + its world transform + open sockets
  band.gd                   # Band: container node holding all placed pieces; queryable
/bands
  band_root.tscn            # Node2D root the generator populates at runtime
/data
  piece_catalog.tres        # Array[ZonePieceData] — the pool B2 draws from (from B1)
  bandgen_config.tres       # BandGenConfig resource: target length, branch chance, etc.
  bandgen_config.gd
/tests
  test_bandgen_determinism.gd   # GUT (or built-in) test: same seed -> identical layout
```

**`RNG` autoload (assumed existing, contract restated):** a single seeded service. B2 must use *only* `RNG` for every stochastic decision — piece selection, frontier ordering, branch coin-flips. No `randi()`, no `randf()`, no `Time`-based seeding inside B2. Expected surface:

```gdscript
RNG.set_seed(seed: int)            # or RNG.fork(stream_name) for sub-streams
RNG.randi_range(lo, hi) -> int
RNG.randf() -> float
RNG.weighted_pick(weights: PackedFloat32Array) -> int
```

**`bandgen_config.tres` fields:**
- `target_piece_count: int` (band length target, e.g. 12)
- `branch_chance: float` (0 = pure linear; M1 default low, e.g. 0.15)
- `max_place_attempts: int` (retries per frontier before giving up on it)
- `loop_back_count: int` (cyclic-loop stub: 0 for M1, >0 later to close loops)

**Band container:** `band_root.tscn` is an empty `Node2D`; the generator adds placed piece instances as children and records the entry/exit gate positions for B3.

---

## Code to generate

### Classes & signals

- **`PlacedPiece`** — wraps an instanced `ZonePiece` with its world offset (in cells) and the subset of its sockets still open (the frontier contribution).
- **`Band`** — owns the list of `PlacedPiece`, an occupancy set of filled cells (for overlap rejection), the entry gate socket, and the deepest placed piece (for B3). Emits `band_generated(seed, piece_count)` on `EventBus`.
- **`BandGenerator`** — stateless-ish driver: `generate(seed, config, catalog) -> Band`.

Signals (via `EventBus`): `band_generation_started(seed)`, `band_generated(seed, piece_count)`, `band_generation_failed(seed, reason)`.

### The stitching algorithm (pseudocode)

```gdscript
# band_generator.gd
class_name BandGenerator
extends RefCounted

func generate(seed: int, cfg: BandGenConfig, catalog: Array[ZonePieceData]) -> Band:
    # DETERMINISM: reset the shared RNG to this seed before ANY random call.
    RNG.set_seed(seed)
    EventBus.band_generation_started.emit(seed)

    var band := Band.new()

    # 1. Place the entry gate piece at origin. Deterministic: index 0, no RNG.
    var entry := _instance_piece(_pick_entry_piece(catalog))
    _place_at(band, entry, Vector2i.ZERO)
    band.entry_piece = entry

    # 2. Frontier = all open sockets, kept in a STABLE, sorted order so
    #    RNG indexing is reproducible regardless of hash/dictionary order.
    var frontier: Array[OpenSocket] = entry.open_sockets()

    while band.pieces.size() < cfg.target_piece_count and not frontier.is_empty():
        _sort_frontier(frontier)              # stable deterministic ordering

        # Pick which open socket to grow from. Bias toward the deepest for
        # a mostly-linear band; branch_chance lets it occasionally fork.
        var grow_idx := _select_frontier_index(frontier, cfg)
        var sock: OpenSocket = frontier[grow_idx]

        var placed := _try_attach_piece(band, sock, cfg, catalog)
        if placed == null:
            frontier.remove_at(grow_idx)      # dead end; retire this socket
            continue

        # Consume the mated socket; add the new piece's other sockets.
        frontier.remove_at(grow_idx)
        for s in placed.open_sockets():
            if s.id != placed.mated_socket_id:
                frontier.append(s)

    if not _is_connected_and_walkable(band):
        EventBus.band_generation_failed.emit(seed, "disconnected")
    EventBus.band_generated.emit(seed, band.pieces.size())
    return band
```

### Socket-adjacency matching + placement

```gdscript
func _try_attach_piece(band: Band, sock: OpenSocket,
                       cfg: BandGenConfig, catalog: Array[ZonePieceData]) -> PlacedPiece:
    var need_dir := ZoneSocket.opposite(sock.dir)   # neighbor must face back at us
    var attempts := 0
    while attempts < cfg.max_place_attempts:
        attempts += 1
        # Weighted, seeded pick over pieces that HAVE a socket facing need_dir.
        var candidates := _pieces_with_socket(catalog, need_dir)
        if candidates.is_empty():
            return null
        var pick := _weighted_seeded_pick(candidates)   # uses RNG.weighted_pick
        var cand := _instance_piece(pick)

        var cand_sock := cand.sockets_facing(need_dir)[0]
        # Compute the cell offset that makes cand_sock coincide with sock.
        var offset := _alignment_offset(sock, cand_sock)

        if _fits(band, cand, offset):                    # no cell overlap
            _place_at(band, cand, offset)
            cand.mated_socket_id = cand_sock.id
            return cand
        cand.free()                                      # rejected; try again
    return null

# Overlap rejection against the occupancy set (the WFC-lite coherence guarantee).
func _fits(band: Band, cand: PlacedPiece, offset: Vector2i) -> bool:
    for cell in cand.footprint_cells(offset):
        if band.occupied.has(cell):
            return false
    return true
```

### Seeded selection helpers (determinism made explicit)

```gdscript
func _weighted_seeded_pick(candidates: Array[ZonePieceData]) -> ZonePieceData:
    var weights := PackedFloat32Array()
    for c in candidates:
        weights.append(c.weight)
    var idx := RNG.weighted_pick(weights)   # SOLE source of randomness here
    return candidates[idx]

func _select_frontier_index(frontier: Array, cfg: BandGenConfig) -> int:
    if RNG.randf() < cfg.branch_chance:
        return RNG.randi_range(0, frontier.size() - 1)   # branch anywhere
    return frontier.size() - 1                            # else grow the deepest (linear)
```

### Determinism contract (the load-bearing rules)

1. `RNG.set_seed(seed)` is called **once** at the top of `generate`, before any other random call.
2. **Every** stochastic decision goes through `RNG`. Grep the file: zero `randi`/`randf`/`randomize`/`Time` references outside `RNG`.
3. Any collection that gets RNG-indexed (frontier, candidate list) is **sorted into a stable order first** — never iterate raw `Dictionary` keys or rely on node-child order that could vary.
4. Piece selection from the catalog is by **stable index**, and the catalog ordering is fixed in `piece_catalog.tres`.
5. No wall-clock, no `OS`/`Time`, no `instance_id`, no float accumulation that depends on iteration order in the geometry math.

### Determinism test (acceptance)

```gdscript
# test_bandgen_determinism.gd
func test_same_seed_identical_layout() -> void:
    var gen := BandGenerator.new()
    var a := gen.generate(12345, _cfg, _catalog)
    var b := gen.generate(12345, _cfg, _catalog)
    assert_eq(_fingerprint(a), _fingerprint(b))   # identical

func test_different_seed_differs() -> void:
    var gen := BandGenerator.new()
    var a := gen.generate(12345, _cfg, _catalog)
    var c := gen.generate(99999, _cfg, _catalog)
    assert_ne(_fingerprint(a), _fingerprint(c))   # (usually) different

# Fingerprint = ordered list of (piece_id, offset_cell, mated_socket) hashed.
func _fingerprint(band: Band) -> String:
    var parts := PackedStringArray()
    for p in band.pieces:   # band.pieces MUST be in placement order
        parts.append("%s@%s#%s" % [p.piece_id, p.offset, p.mated_socket_id])
    return parts.join("|").sha256_text()
```

Connectivity check `_is_connected_and_walkable` does a flood-fill across mated sockets from the entry piece and asserts every placed piece is reached — satisfies the "connected, walkable band" half of acceptance.

---

## Open questions

- **Socket matching strictness:** Direction-opposite only, or also require matching `width_cells` (and later, tags like biome/theme)? M1 can be direction-only with a single fixed width; flag when B1 introduces width variance.
  - **Recommendation:** **Direction-opposite only for M1** (`need_dir == ZoneSocket.opposite(sock.dir)`), relying on B1's single fixed 2-cell width so every socket is interchangeable. Implement the matcher as a predicate chain — `dir_ok and width_ok and tags_ok` — but have `width_ok`/`tags_ok` return `true` unconditionally now; this is the WFC "socket compatibility" pattern in miniature and lets you bolt on width/biome constraints without restructuring the loop. Flag B1's introduction of width variance as the trigger to activate the `width_ok` clause.
- **Branching vs linear for M1:** Default `branch_chance` low so the band reads as a spine (helps B3's depth axis stay legible). Do we want *guaranteed* linearity for M1 and defer branches entirely, or keep the small fork chance? Affects how cleanly "depth" maps to a single number.
  - **Recommendation:** **Ship M1 strictly linear: set the default `branch_chance` to 0.0.** A single spine makes depth an unambiguous, monotonic function of placement order, so `depth_index == dist_to_gate` for every piece and B3's risk/reward axis is dead-legible — exactly what the M1 goal ("prove the dive loop") needs. Keep the `branch_chance` field, the `_select_frontier_index` fork branch, and B3's true-BFS return-distance code in place but dormant, so flipping branches on later is a config change, not a rewrite. This mirrors Spelunky's guaranteed solution-path philosophy ([source](https://procedural-content-generation.fandom.com/wiki/Spelunky)) — get one coherent traversable path first, add side rooms later.
- **Failure / backtracking policy:** When a frontier socket can't be filled, we retire it (no backtracking). Is that acceptable, or do we need to retry the whole band with a re-derived sub-seed if it falls short of `target_piece_count`? Re-seeding on failure must itself be deterministic (e.g. `seed + attempt`).
  - **Recommendation:** **No per-socket backtracking; use whole-band retry with a deterministic derived seed.** Keep the cheap "retire the dead socket and continue" inner loop, then after `generate` finishes, if `band.pieces.size() < target_piece_count` (use a soft floor, e.g. 80% of target), discard the band and re-run with `seed = hash(original_seed, attempt)` for a bounded number of attempts (e.g. 8) before emitting `band_generation_failed`. Derive the retry seed via an integer mix (`hash_combine`/`mix_seed`), never `seed + attempt` (adjacent seeds can correlate) and never wall-clock — so the whole retry chain is itself a pure function of the original seed and the determinism test still passes. For a linear band with the M1 roster, retries should almost never fire; this is a safety net, not the main path.
- **Cyclic-loop stub scope:** `loop_back_count` is 0 for M1. How much scaffolding do we lay now (e.g. record candidate loop-close sockets) vs add wholesale in a later milestone?
  - **Recommendation:** **Minimal scaffolding only: keep the `loop_back_count` config field (default 0) and have `Band` retain its full occupancy set and the list of unconsumed open sockets after generation.** That retained data is everything a later loop-closing pass needs — it can scan retired/open sockets for pairs whose mating cells are adjacent and stitch a connector — so you avoid building (and testing) the loop logic now while leaving no data gap. Do **not** add candidate-loop bookkeeping inside the hot placement loop; that complicates the determinism surface for zero M1 benefit. Add the actual cyclic backbone wholesale in the milestone that needs it, gated on `loop_back_count > 0`.
- **Determinism across Godot versions / platforms:** Does `RNG.weighted_pick` / float math give identical results on Windows vs other targets? If any float comparison feeds a branch, pin the algorithm to integer math where possible and document the guarantee boundary.
  - **Recommendation:** **Guarantee determinism within a single Godot build/target; treat cross-platform bit-identity as out of scope for M1.** Godot's `RandomNumberGenerator` is PCG32: given the same seed it advances a deterministic integer state, and `randi()`/`randi_range()` are pure integer ops that reproduce identically anywhere ([source](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html)). Basic IEEE-754 add/mul/compare are also reproducible across platforms with matching settings, but transcendental functions (`sin`, `log`, etc.) and compiler/arch differences are **not** standardized and are the classic determinism trap ([source](https://gafferongames.com/post/floating_point_determinism/)). So: build every branch-affecting decision on **integer math** — implement `weighted_pick` as integer cumulative weights against `randi_range(0, total_weight-1)` (scale `float` weights to ints once), keep all placement offsets in integer cells, and forbid `randf()`-driven comparisons in the layout path. Document the boundary as "identical layout for a given seed on a given engine build/target" — sufficient for M1's single greybox target and the GdUnit4 determinism test, which runs on one platform.
- **Coordinate space for offsets:** Track placement in integer **cells** (recommended — exact, hashable) vs pixels (float risk). Confirm B1's `cell_size_px` is uniform so cell↔pixel conversion is lossless.
  - **Recommendation:** **Track all placement in integer cells (`Vector2i`); convert to pixels only at the final `instance.position = cell * cell_size_px` step.** Cells are exact, hashable, and directly usable in the occupancy `Dictionary`/set for overlap rejection and in the fingerprint, eliminating all float-accumulation risk from the layout math. B1 fixes a single project-wide `cell_size_px` (16) shared by every piece, so cell↔pixel conversion is a lossless integer multiply with no rounding. Assert at generation start that all catalog pieces report the same `cell_size_px`, failing fast if a piece is authored at the wrong scale.
