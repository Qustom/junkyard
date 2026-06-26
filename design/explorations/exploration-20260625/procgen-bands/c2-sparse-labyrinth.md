# Sparse Labyrinth
**Category:** Maze & density archetypes

## The archetype
A maze *topology* — many junctions, branches, dead-ends, and a non-obvious route to the deep end — drawn with **wide corridors** instead of tight 1-cell walls. The player reads it as a network of **winding paths through a junk-warren**, not a claustrophobic hedge maze. The challenge stays navigational ("which fork goes deeper? where does this loop back?") but the moment-to-moment movement is forgiving: a 3–4-cell-wide lane means you don't scrape every corner, a charging enemy isn't an instant pin, and a thrown item has room to fly. Where a Dense Maze taxes you on *cornering precision*, Sparse Labyrinth taxes you on *spatial memory and route choice*. The frustration of "I keep clipping the wall" is removed; the satisfaction of "I found the way through" is kept.

## How it fits THE FAR YARD bands
The extraction loop's core question is **"push deeper or extract now?"**, and a labyrinth makes the *cost of leaving* tangible: the route home is winding, so `DepthGrader.dist_to_gate` grows faster per piece than on a straight spine, and braided loops mean there may be a *shorter* way back you have to spot under the dive clock. That's exactly the right pressure — navigation as a resource you spend against time, without the unfair "died to a corner" feel.

Crucially this is a viable **whole-band** layout (unlike Dense Maze, which is best as a sub-region) — wide corridors keep every part of the band playable, so a full band can be one labyrinth. It hosts the opposition spread well: wide lanes are real **Actor lanes** (Charger gets its sightline, Patroller a cone to sweep, Pack hunters room to flank), junction cells act as small **arenas** for Sentry/Spinner standoffs, and dead-end pockets are natural high-risk **loot rooms**. **Field** hazards (gas, electrified floor) flood a corridor segment into a "hold your breath and pick the right fork" beat. For the **core verbs**: wide corridors give throw the room it needs (a 2-cell lane often blocks a useful arc; 3–4 cells restores it), loot reads clearly along the path, and the entry piece (`catalog[0]`) stays the extraction anchor.

## Generation approach (on the real bandgen system)
The as-built `BandGenerator._generate_once` already grows a frontier socket-by-socket with weighted `_weighted_pick_index` draws, flush `_alignment_offset` mating, and `band.fits()` overlap rejection — a maze is just *more branching plus loop-closing* on that same machine:

- **Wide-corridor pieces** (`zone_piece.gd`, B1): author the corridor family at **3–4-cell `width_cells` sockets** (vs. the current 2-cell long hall in `RunConfig.CORRIDOR_PIECE_IDS`), plus **junction pieces** (3- and 4-socket cross/T pieces) — the maze's branch nodes. Wide is purely a piece-authoring + socket-width change; the dormant `_width_ok` predicate (currently `return true`) activates cleanly to keep wide lanes mating wide.
- **Branching:** drive forks via R4 (`rc.r4_enabled`, `_select_frontier_index`) with a healthy `r4_branch_chance_base`/`r4_branch_per_depth` so the frontier fans out into a tree rather than a spine — the labyrinth's many paths.
- **Braiding (loops):** a tree isn't a maze until paths reconnect. Use the **stubbed `loop_back_count`** (`bandgen_config.gd`) for a post-growth pass: take `band.open_sockets` pairs that are 4-adjacent / short-gap and within compatible direction, and stitch a connector to close a loop (re-running `band.fits` + connectivity). This is the one genuinely *new* code beyond config — but the data contract for it already exists. `socket_sealer.gd` then walls every *remaining* unused socket so dead-ends are clean.
- **Depth + loot:** `DepthGrader.grade()` measures depth in BFS **piece hops** — already loop-aware (it's a graph BFS), so a braided band grades correctly and `dist_to_gate` reflects the real winding walk. `JunkPlacer.plan()` scales loot by `depth_norm` and gates tier by `curve.min_tier`, weighting dead-end pockets richer.
- **Determinism:** every draw stays on the `RNG` autoload at the same site/order; the braid pass is pure integer-cell geometry (no RNG, or one salted sub-stream like `JunkPlacer`'s `_JUNK_SALT`), so `test_bandgen_determinism.gd`'s seed-reproducibility holds.

## Flavor knobs
- **Corridor width** (`width_cells`, piece art): 3 = winding-but-snug, 4+ = generous halls (more throw/dodge room, less "maze" feel) — the archetype's defining dial.
- **Braid factor** (`loop_back_count`): 0 = pure tree (one route, many dead-ends); high = many loops (forgiving, route-rich, faster backtrack).
- **Junction frequency** (junction-piece catalog weight + R4 branch chance): how often paths split — the labyrinth's density.
- **Overall size** (`target_piece_count`): total maze extent = total dive-clock exposure.

## Synergies & tensions
- **Oppositions:** strong with lane Actors (Charger, Patroller, Pack hunters) and junction-standoff Fixtures; wide lanes finally give the throw verb and dodge-roll the space the 2-cell hall denied. Tension with **map-scale Field** hazards (Rising tide, Spreading fire): sealed corridor walls fight a continuous flood, and a labyrinth's loops can let fire outrun the player around a shortcut — pair these carefully or confine them to segments.
- **Dive clock:** the winding route *is* spatial time-pressure; the braid factor is the safety valve — too few loops and a wrong fork under the clock feels punishing, too many and the navigation challenge evaporates.
- **Depth grading:** excellent fit — graph-BFS depth already handles loops, so "deeper = richer + farther home" stays honest even with shortcuts; loops add the tactical "is there a faster way back?" read.
- **Combining archetypes:** composes as a *macro* skeleton with Discrete-Rooms interiors (a junction piece can be a small arena), or a labyrinth fills one region of a Hub-and-Spoke band. Wide corridors make it the most "mixable" maze variant.

## Open questions
- **Avoiding "samey winding" monotony.** A naive maze of identical wide corridors reads as repetitive sludge. *Recommendation:* vary corridor segment length + junction shape in the catalog, and let dead-end **reward pockets** + Field-hazard segments punctuate the path so each leg has a beat. Whether that's enough is a **fun call — needs a layout playtest, surface to Director.**
- **Braid pass is new code.** `loop_back_count` is currently a stub; the loop-closing geometry (find stitchable open-socket pairs, validate, connect) is real implementation effort beyond pure config. **Scope/effort call for the Director:** ship Sparse Labyrinth as a *branchy-tree-only* approximation first (no loops, R4 forks + dead-ends), and add braiding later — or fund the braid pass up front because loops are what make it feel like a labyrinth rather than a tree?
- **How wide is "wide enough"?** 3 vs. 4 cells changes both the feel and how the opposition/throw verbs read. Pure feel — **prototype both, let the M-gate decide.**
- **Navigation legibility vs. the dive clock.** A genuinely confusing maze under a hard timer can feel unfair rather than challenging. Does the band need a minimap, breadcrumbs, or a depth-tinted palette (`depth_grader` already gives `depth_norm`) to keep "winding" from becoming "lost"? **Vision/UX call for the Director.**
