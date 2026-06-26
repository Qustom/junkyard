# Open Field with Cover
**Category:** Open-space archetypes

## The archetype
A mostly-empty arena dotted with obstacles — low walls, wrecked hulks, scatter
crates, pillars. It reads as a *clearing*: a parking lot, a plaza, a drained
basin, a scrap flat. The defining property is **long sightlines**: from most
standing spots you can see — and be seen — across the whole space. Cover is local
and discrete (a thing you tuck behind), not the maze of a corridor band. The
single dominant knob is **cover density**: sparse reads as exposed and deadly (a
killing field), dense reads as a stealth/positioning playground (a cluttered lot
you pick through). It is the spatial opposite of a tight room-graph band — instead
of "which doorway" the question is "where do I stand, and what can see me."

## How it fits THE FAR YARD bands
Long sightlines are exactly where the **mouse-aimed throw** (L1) and the **ranged
opposition spread** (the `2-*` group) come alive. The throw verb is wasted in a
cramped corridor; in an open field you can line up a hit on a Sentry across the
arena, lead a Lobber, or kill a Spinner guarding the far gate — the verb finally
has range to matter. Symmetrically, ranged enemies *need* sightlines to function:
a Sentry's lane, a Spinner's spiral, a Suppressor's setup shots all assume open
space. So this archetype is the natural **host for the ranged group** the way a
maze hosts the ambusher/patroller melee group.

Against the **dive clock** (A3, `dive_clock_changed`): an open field is fast to
*cross* but dangerous to *dwell* in — perfect for the extract decision. High-value
junk (B3 depth-scaled) placed in the exposed center vs. safe behind cover at the
edges makes "grab the risky one or cash out" a spatial, legible choice.

**Cover density is the experience dial.** Sparse → every threat sees you, the
field is a gauntlet you sprint across using the clock (good for a shallow,
high-tempo band or a deep "the yard is hunting you" moment). Dense → you can
break line-of-sight, flank emitters, and pick a route; ranged enemies become a
puzzle rather than a wall. Suitable as a **Band 1 (Near)** flat scrapyard lot and
again deep as a wrong, too-open expanse.

## Generation approach (on the real bandgen system)
**Honest read of the current generator:** `BandGenerator` is a socket-based
room-graph stitcher (`_try_attach_piece` → `_alignment_offset` mates pieces
flush, cell-by-cell). It has **no scatter/poisson pass** — it only places authored
`ZonePiece` rectangles against sockets. So this archetype is *not* a natural fit
for the existing assembly loop and needs a **new placement mode**, not a new piece.

Proposed extension (smallest seam): treat the open field as **one large arena
piece** (an authored `ZonePiece` — a big floor rect with edge sockets so it still
mates into the band spine), then run a **seeded scatter pass** over its interior
that drops cover obstacles. The scatter pass is a sibling to `JunkPlacer`, which
already proves the pattern: a **local `RandomNumberGenerator` seeded from
`band.resolved_seed` + a fixed salt** (here a `_COVER_SALT`), so cover placement
is reproducible from seed yet never perturbs the layout RNG stream
(determinism contract, `tests/test_bandgen_determinism.gd`). Algorithm sketch:

1. Take the arena piece's `floor_cells` (already in band-global cells).
2. Poisson-disk / blue-noise sample N obstacle centers, N derived from a
   `cover_density` knob × floor area, with a min-spacing radius so cover never
   walls off the field.
3. For each sample, stamp a small cover footprint (1–4 cells) as collision/los
   blockers — mark those cells non-walkable so connectivity (`is_band_connected`)
   and `DepthGrader` still see a traversable floor.
4. Guarantee a clear path entry→exit-socket (reject samples that would block it).

Loot rides the existing path: `DepthGrader` grades the arena by hops like any
piece, and `JunkPlacer.plan()` scatters depth-scaled junk on its floor cells —
no change needed there, the arena is just a big-area piece (J3's
`loot_density_per_area`, currently ships-off, would let a big arena hold
proportionally more interest if ever turned on).

## Flavor knobs
- **`cover_density`** — *the* knob; obstacles per unit floor area (sparse↔dense).
- **`cover_size_mix`** — distribution over small (pillar) / medium (wreck) / large
  (wall segment) footprints; biases stealth vs. open feel.
- **`arena_size`** — floor dimensions of the authored arena piece (sightline length).
- **`min_cover_spacing`** — poisson radius; guards against accidental mazes.
- **`edge_cover_bias`** — push cover to rim (open killing-center) vs. uniform.
- **`clear_lane_guarantee`** — width of the protected entry→exit corridor.

## Synergies & tensions
- **Ranged group (`2-*`):** the headline synergy. Sentry lanes, Spinner spirals,
  Lobber arcs, Suppressor setups all want sightlines; cover gives the player the
  break-LOS counters those entries already assume. Throw verb gets its stage.
- **Tension — melee group (`1-*`):** ambushers/patrollers built on vision-cones
  and cover want a *denser* layout; an open field neuters their ambush. Mixing
  melee in needs higher `cover_density`, which then dulls the ranged showcase —
  a real tradeoff, not a free combo.
- **Dive clock:** sparse fields are crossed fast under clock pressure; dense ones
  cost time to pick through — density indirectly tunes clock spend.
- **Depth grading:** an arena is a single hop, so depth granularity is coarse; if
  a band is all-arena, `depth_index` barely moves and loot tiers flatten. Best
  used as **one node in a mixed band** (arena + corridors), not a whole band.
- **Combining archetypes:** slots cleanly into a mixed spine because it's still a
  socketed piece — an open plaza between corridor stretches gives pacing contrast.

## Open questions
- **Scatter-pass effort (scope/effort — Director):** this needs a genuinely new
  placement subsystem (poisson sampler + walkability re-marking + path guarantee),
  not just data. Is an open-field archetype worth that build, or do we fake it with
  a handful of *authored* large arena pieces that have cover baked in (zero new
  code, less variety)? Recommend prototyping the baked-piece fake first to test fun
  before committing to the sampler.
- **Cover as obstacles vs. tiles (effort):** are cover blockers their own
  collision entities, or just WALL atlas cells stamped into the arena's
  TileMapLayer? Stamping cells reuses the existing floor/wall connectivity check
  for free — recommend that route.
- **Fun gate (fun — Director):** does an open field read as *tense* or just
  *empty/boring* at our top-down scale and camera? Sparse-deadly vs. dense-stealth
  may both be flat without good telegraphs and enemy density. Needs a playtest
  before it earns a slot.
- **Depth coarseness:** should a large arena count as multiple depth hops (so loot
  tiers progress across it), or accept it as one flat node? Leaning one node, but
  flag if loot pacing suffers.
