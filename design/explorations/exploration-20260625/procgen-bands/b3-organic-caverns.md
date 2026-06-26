# Organic Caverns
**Category:** Open-space archetypes

## The archetype
Blobby, irregular open spaces with no straight lines — the look a cellular-automata cave
sweep produces: rounded wall fronts, pinched throats opening into bulbous chambers, and a
dense fringe of nooks, pockets, and dead-end alcoves. It reads as *grown, not built* —
natural or alien rather than the machined corridors of the surface junkyard. The defining
play property is **bad sightlines**: a player can rarely see across a chamber, and the
ragged wall fringe hides what's around every lobe. That low legibility is the whole point —
it favours anything that wants to be unseen until it's close.

## How it fits THE FAR YARD bands
The extraction loop is "dive, loot nook-by-nook, beat the clock home." Organic caverns
weaponise the clock through **disorientation**: with no straight spine to sight down, the
player must commit time to *clear* a chamber before trusting it, and the way back home is
visually ambiguous (the depth axis is real but not eyeballable). That makes the
push/cash-out bet sharper — "have I time to sweep this lobe?" — and turns looting into a
genuine search rather than a sprint past visible piles.

It suits a **deeper / alien band** (Band 2+ in the GDD escalation), where the fiction has
already left the built junkyard behind. It is the natural host for the low-sightline
opposition spread: the **Ambusher** (disguised in a nook beside a juicy pickup) and the
**Burrower** (denying a blobby chamber on a timer) both *need* poor sightlines to read as
fair-but-tense rather than trivial. Core verbs still work: the mouse-aimed throw arcs
*around* the blobby walls into a pocket — a skill expression caverns reward more than
corridors do.

## Generation approach (on the real bandgen system)
Be honest: the shipped generator (`systems/bandgen/band_generator.gd`) is **socket-based
piece-assembly** — it stitches authored `ZonePiece` rects flush along matched sockets. A CA
cavern has no pieces and no sockets, so this is **a second generator backend**, not a piece
catalog trick. Forcing organic blobs through rectangular pieces would just be lumpy
corridors; the value is the genuinely irregular floor.

Algorithm sketch (a `CaveBandGenerator` parallel to `BandGenerator`, same `generate(seed,
cfg, ...) -> Band` signature):
1. Allocate an integer cell grid; fill each cell wall/floor by a seeded roll against `fill%`
   (all draws via the `RNG` autoload after `RNG.seed_from(seed)` — same determinism contract
   as B2, byte-reproducible per `tests/test_bandgen_determinism.gd`).
2. Run N **smoothing passes** (the classic 4-5 rule: a cell becomes wall if ≥5 of its
   8-neighbours are wall, floor otherwise) — pure integer cellular automata, deterministic.
3. **Connectivity guarantee:** flood-fill floor regions; keep the largest, then either carve
   the rest in or discard them. This must satisfy the same acceptance bar B2 enforces
   (`is_band_connected`) — one walkable component.

Crucially the output is **the same `Band` data shape** (`floor_cells` per region/`PlacedPiece`,
an entry, occupancy). That means `DepthGrader` and `JunkPlacer` work *unchanged*: both consume
only FLOOR-cell 4-adjacency, never piece sockets. Depth-in-hops still grades a cave (BFS over
floor cells), and `JunkPlacer` scatters loot on `floor_cells` exactly as today — so the
depth/loot/determinism stack is reused wholesale; only the front-end geometry differs.

## Flavor knobs
A `CaveBandConfig` (sibling to `BandGenConfig`, all integer-comparable where they gate
branches):
- **Fill %** — initial wall density (~45%); higher = tighter, more wall.
- **Smoothing iterations** — more passes = smoother, fewer islands (~4-5).
- **Blob size / scale** — neighbourhood radius or grid coarseness; sets chamber bulk.
- **Nook frequency** — under-smoothing or a roughness pass leaves more fringe pockets.
- **Connectivity threshold** — min floor-region size kept before carve-or-discard.

## Synergies & tensions
- **Ambusher/Burrower:** the archetype's reason to exist — nooks hide the disguised pounce;
  blobby chambers are exactly the "deny an area on a timer" the Burrower wants. Strong synergy.
- **Dive clock:** caverns *cost time to read*, amplifying clock pressure (good tension, but
  watch it doesn't make deep bands feel sludgy — a tuning call).
- **Depth grading:** hop-distance still works, but a cave's depth is less visually obvious than
  a linear spine — may need a lighting/signposting assist so "deeper = farther home" still reads.
- **Combining archetypes:** caverns could be a *band-2-onward* swap, or pockets stitched into a
  socket-based band as a "cave room" piece-type — but that re-imports the lumpy-corridor problem.

## Open questions
- **Second-backend cost vs. reuse (the big one).** A whole CA generator + config + tests is real
  effort; the depth/loot/determinism reuse softens it, but it's still a new code path. Worth it
  only if low-sightline play proves fun at the gate. **Scope/effort — Director.**
- **Tile-world vs. piece-world.** CA wants a free-form cell grid; the rest of the build assumes
  authored piece scenes (collision, tilemaps). How do cave walls get collision + art — a single
  generated TileMapLayer instead of instanced pieces? **Effort/architecture — flag.**
- **Does disorientation read as tense or as lost/annoying?** Bad sightlines are the feature and
  the risk. **Fun/feel — Director, validate at the playtest gate.**
- **Determinism of flood-fill carve.** The carve step must be order-stable (sorted regions) or
  it breaks the seed contract — solvable, but a real correctness gotcha to spec.
