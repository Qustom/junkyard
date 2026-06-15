# Worklog — B2 Modular Room-Graph Generator

- **Date:** 2026-06-15
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1
- **Branch:** general-purpose/B2-band-generator
- **Commit:** 0eb950d203172581bee87e428cf2bd6d0c5b418b   ← required; a worklog without a real commit means the task is NOT done

## What changed
Built the seeded modular room-graph generator (B2): it instances B1 zone-piece
scenes and stitches them into a single connected, walkable band by socket-
adjacency matching, driven entirely by the `RNG` autoload so a given seed yields
a byte-identical layout. All placement is integer-cell math; pixels are derived
only at `instance.position = offset_cell * cell_size_px`. M1 scope per the spec's
Open-questions recommendations: direction-opposite matching only (`width_ok`/
`tags_ok` are dormant true-stubs), `branch_chance` default 0.0 (strictly linear
spine), no per-socket backtracking but whole-band retry on a deterministically
DERIVED seed (integer hash-combine) with an ~80% soft floor and ~8 attempt bound
before emitting `band_generation_failed`, and `loop_back_count`/occupancy/open-
socket retention scaffolding with no loop logic.

## Files touched
- `systems/bandgen/band_generator.gd` — `BandGenerator.generate(seed,cfg,catalog) -> Band`: the stitcher, integer weighted pick, flush socket alignment, retry-seed derivation, walkable-floor connectivity flood-fill.
- `systems/bandgen/band.gd` — `Band`: pieces in placement order, occupancy set, entry/deepest piece, retained open sockets, deterministic `fingerprint()`.
- `systems/bandgen/placed_piece.gd` — `PlacedPiece`: instanced piece + integer offset + global footprint/floor cells + open sockets + mated-socket index.
- `systems/bandgen/open_socket.gd` — `OpenSocket`: frontier socket identity (owner+index+global cell+dir+owner rect) defined locally (B1's SocketInfo has no stable id).
- `data/bandgen_config.gd` + `data/bandgen_config.tres` — `BandGenConfig` (target 12, branch_chance 0.0, max_place_attempts 16, loop_back_count 0, soft_floor 80%, max_band_attempts 8).
- `data/piece_catalog.gd` + `data/piece_catalog.tres` — `PieceCatalog` (typed `Array[ZonePieceData]`) over the 6 B1 piece scenes with weights; index 0 = corridor_h entry.
- `bands/band_root.tscn` — empty `Node2D` root the generator populates.
- `tests/test_bandgen_determinism.gd` + `.tscn` — headless acceptance harness (scene-run so EventBus/RNG globals resolve).

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK — M0 architecture spike healthy**
- [x] `godot --headless res://tests/test_bandgen_determinism.tscn` → **BANDGEN OK — determinism + connectivity verified across 9 seeds (sample seed 12345 -> 12 pieces, fp=e943ac9c8bc1)**
  - same seed → byte-identical fingerprint (9 seeds, each generated twice)
  - different seeds → distinct fingerprints (variation exists)
  - connectivity: walkable-FLOOR flood-fill from the entry reaches every placed piece
  - overlap-free: no two pieces share a cell; soft floor (≥10 of 12) met
  - retry/seed chain is pure: perturbing global RNG between runs does not change the layout
- [x] grep confirms zero `randi`/`randf`/`randomize`/`Time`/`OS`/`instance_id`/`set_seed`/`weighted_pick` outside RNG-routed calls; the lone `RNG.randf()` is the dormant `branch_chance>0` fork path (never fires at M1 default).
- [x] Definition of done met: *"Given a seed, the generator produces a connected, walkable band; the same seed produces a byte-identical layout, verified by an automated test."*

## Design deviations
1. **RNG API adaptation (orchestrator-directed, no sign-off needed).** The spec's
   pseudocode assumed `RNG.set_seed` / `RNG.weighted_pick` / `RNG.fork`. The real
   `systems/rng.gd` surface is `seed_from` / `randi` / `randi_range` / `randf` /
   `pick`. So: call `RNG.seed_from(seed)` once at the top of each attempt and
   implement weighted selection in-house as INTEGER cumulative weights (float
   `ZonePieceData.weight` scaled ×1000 to ints once) rolled against
   `RNG.randi_range(0, total-1)`. Keeps every branch-affecting decision on integer
   math (cross-build determinism). EventBus signals were emitted, not edited.
2. **Flush-edge socket alignment instead of the spec's raw seam formula
   (`cand_cell == sock_cell + dir`).** B1's authored greybox pieces are solid-
   walled rects whose openings reach the piece EDGE while the socket marker sits
   one cell IN from that edge; the raw formula double-counts that inset and overlaps
   mated pieces by two columns. Replaced with `_alignment_offset`: place the
   candidate flush against the host's footprint edge on the facing axis and align
   the socket lanes on the perpendicular axis — pure integer-cell, deterministic,
   and yields real adjacent-floor doorways. This is an adaptation to B1's actual
   geometry, not a design change; flagged here for the record.
3. **Connectivity is FLOOR-cell adjacency, not footprint adjacency.** To make
   "connected AND walkable" a true traversability guarantee, the flood-fill links
   two pieces only when their walkable FLOOR cells (TileSet atlas (0,0)) are
   4-adjacent — a real doorway, never a shared perimeter wall.
4. **Test harness runs as a scene (`.tscn`), not `--script`.** Godot's `--script`
   SceneTree mode does not register autoload singletons (`EventBus`/`RNG`) as
   compile-time globals, so a class that references them fails to load there. The
   generator legitimately uses the global form (matching `game_state.gd`), so the
   acceptance test is launched as a headless scene where those globals resolve
   exactly as in-game.

## Handoffs / follow-ups
- **B3 (band depth structure)** can consume `Band.deepest_piece` (last on the
  linear spine) and `pieces` placement order as the monotonic depth axis; with
  `branch_chance == 0.0`, `depth_index == placement_index`.
- **Width/biome matching:** `_width_ok`/`_tags_ok` are dormant `true` stubs.
  Activate `_width_ok` (return `cand_width == host_width`) the moment B1 introduces
  socket width variance — flagged in the spec's open question.
- **Loop closing:** `Band` retains its full `occupied` set and leftover
  `open_sockets` after generation; a later `loop_back_count > 0` pass has the data
  it needs with no change to the hot placement loop.
- The greybox pieces' solid perimeter walls mean mated rooms share a wall line; if
  B3/art wants visible carved doorways, that is a B1/art follow-up, not a generator
  change.
