# Dense Maze
**Category:** Maze & density archetypes

## The archetype
A thicket of thin walls and one-cell-wide corridors that fork constantly and dead-end
often. The feel is claustrophobic: short sightlines, no open floor to read, every junction
a gamble. Its defining trait is the **cornering risk** — a dead-end is a death sentence
when something is behind you, and a perfect maze hands the pursuer roster (the Charger's
lane-denial, Pack Hunters' encirclement) free kill-boxes because the player can't see the
trap until they're in it.

That same property is why **full-map density is too punishing**. A whole-band maze turns
navigation into the entire challenge, drowns the extraction loop in route-hunting, and
makes the dive clock a coin-flip rather than a pressure. So the honest use is a **REGION** —
a bounded maze pocket injected into a larger, more legible band — where the claustrophobia
is a *set-piece* the player enters with full HP and exits, not a 3-minute tax on every run.

## How it fits THE FAR YARD bands
The extraction loop wants *legible push*: dive, grab, read the threat, decide to bank or
go deeper. A maze region adds a deliberate "do I risk this pocket?" beat — the dead-ends
**bait greed** (loot piled where you're most exposed) while the timer makes lingering
expensive. Its brutal interaction with the **dive clock** is the point: a maze is the one
place where *finding the exit* is itself the threat, so it must be gated (see Open
questions) so a player can't be timer-killed by pure navigation RNG.

Hosting opposition: the narrow corridors are ideal for **throw down a lane** (the core
verb reads cleanly when there's only one axis to aim), and a single Charger or a 3-Hunter
pack parked at a junction converts the maze from annoying to genuinely scary. Density here
should be *sub-band*, never the whole spread.

## Generation approach (on the real bandgen system)
`BandGenerator.generate()` stitches authored `ZonePieceData` pieces by socket-mating
(`_try_attach_piece` → `_alignment_offset`), not by carving tiles — so two grounded options:

1. **Maze-of-pieces (preferred, no new subsystem).** Author a small catalog of thin
   1-2-cell corridor + junction + cap pieces, then run the *existing* growth loop in a
   maze-biased mode: raise `branch_chance` (via a RunConfig knob, like R4) so
   `_select_frontier_index` forks aggressively, and let the natural `band.fits()` overlap
   rejection + frontier retirement (`_try_attach_piece` returns null → socket retired)
   manufacture the dead-ends. This stays inside the byte-reproducible `(seed+config)`
   contract — no new RNG site, same draw order with all-off default.
2. **Tile-maze pocket.** Reserve one large piece's interior as a sub-grid and run a
   **recursive-backtracker / growing-tree** carve over its cells, seeded from a *local*
   `RandomNumberGenerator` keyed off `band.resolved_seed + salt` — exactly the
   `JunkPlacer._substream_seed` pattern, so the maze never perturbs the layout stream.

Depth: `DepthGrader` already grades by FLOOR-cell 4-adjacency BFS hops, so a branchy maze
grades correctly with no change — `dist_to_gate` is the honest "how far home" read. Feed
`JunkPlacer` a higher `loot_density_per_area`/value at the deep dead-ends so the bait is
deterministic.

## Flavor knobs
- **Wall density** — corridor width (1 vs 2 cells) and junction frequency.
- **Dead-end frequency** — fork rate vs. spine bias; how many caps the maze keeps.
- **Braid factor** — perfect maze (every junction a real choice, max dead-ends) vs. braided
  (loops punched in, escape lanes added) for fairness vs. cruelty.
- **Region size cap** — pieces-in-pocket / sub-grid dimensions; the single most important
  fun lever.

## Synergies & tensions
- **Pursuers:** the strongest pairing and the strongest danger — braid factor is the safety
  valve that keeps it fair against Pack Hunter encirclement.
- **Dive clock:** maze + tight timer compounds two pressures; either soften the timer inside
  the region or guarantee a short exit path.
- **Depth grading:** works as-is; loops just give `dist_to_gate` shortcuts.
- **As a pocket inside other archetypes:** drop it inside a Hub-and-Spoke spoke or behind an
  Open-Floorplan room as the "high-risk vault" wing.

## Open questions
- **Guaranteed findable exit under the timer (fairness).** A perfect maze can hide the exit
  behind maximal backtracking. Do we *guarantee* a bounded entry→exit path (cap the maze
  diameter, or force a braid loop), or accept navigation-death as intended difficulty?
  Recommend: guarantee a bounded exit — surface as a Director **fun/fairness** call.
- **Region vs. whole-band.** This doc assumes a region. Is a full maze band ever a deliberate
  "nightmare floor" set-piece? Director **scope/vision** call.
- **Maze-of-pieces vs. tile-carve effort.** Option 1 reuses everything; option 2 needs a new
  carve subsystem. Recommend option 1 for M-near; option 2 only if corridor variety feels too
  blocky. Director **effort/scope** call.
- **Throw readability in 1-cell corridors** — does the throw arc/aim feel good at min width,
  or does it need a 2-cell floor? Needs **playtest**.
