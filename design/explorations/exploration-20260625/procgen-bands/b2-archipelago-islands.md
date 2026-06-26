# Archipelago / Islands
**Category:** Open-space archetypes

## The archetype
A band whose walkable ground is broken into **discrete patches separated by impassable gaps** — water, void, lava, a collapsed concrete pit. You can't walk the gap; you cross it only at **bridges and chokepoints** (a fallen girder, a catwalk, stepping pylons). The spatial read is immediate and legible: ground is safe, gap is death-or-loss, the bridge is the only seam. It plays as a string (or web) of small arenas linked by thin commit points, the opposite of one open floor — every transition is a *decision*, not a stroll.

## How it fits THE FAR YARD bands
The chokepoint **is** the extraction-loop beat. A bridge is an ambush point on the way out and a commit point on the way in: cross it and the gap is at your back. Set good loot on a **far island** and the dive clock makes reaching-and-returning a real wager — the depth axis (BFS hops) naturally lengthens because the only paths are the bridges, so "deeper = farther home" reads cleanly and backtracking is forced through the same pinch points.

Opposition fit is the headline:
- **Leaper** (`1-leaper.md`) becomes the archetype's signature threat — it *clears the gap*. The "the room won't save you" beat sharpens into "the gap won't save you." A bridge you'd hold against ground pursuers is irrelevant to a Leaper, forcing the throw/sidestep answer. Strong here, banner enemy.
- **Conveyor / Wind tile** (`3-conveyor-wind-tile.md`) on or beside a bridge is a spatial puzzle: drift can shove you *off the catwalk into the void*, and a belt across a gap turns the crossing into a lead-against-drift movement test.
- **THROW-verb risk (call it out):** a thrown item that misses *over a gap is lost* — no recovery, the bomb/ranged answer now has a real whiff cost over void. That raises the skill ceiling and is genuinely good, **but** it can feel punishing if gaps are everywhere and the throw is the player's main tool. Recommend gaps be *crossable-by-sight* (you can see your target across them) and gap-loss be a deep-band sharpening, not a Band-1 default.

Suits **mid-to-deep bands** where the band fiction (a flooded yard, a slag pit) and the harsher loss-rules belong; gentlest version (one gap, redundant bridges) could seed in Band 1.

## Generation approach (on the real bandgen system)
The generator (`systems/bandgen/band_generator.gd`) is **socket-piece assembly with a hard FLOOR↔FLOOR 4-adjacency connectivity contract** (`is_band_connected`) — it has no concept of gaps, and `SocketSealer` actively **walls every floor cell that faces void**. So an archipelago is *against the grain* and needs a real decision (flag honestly to Director):

- **Preferred — bridge-as-piece (no engine change).** Author **island pieces** (small floor rects, multiple sockets) and **bridge pieces** (long, thin: a 2-cell-wide floor lane with WALL gutters on both long sides). The generator already stitches these via opposite-direction sockets; an "island → bridge → island" chain is just normal growth with bridge pieces in the catalog. The *gap* is the un-floored space the bridge's walls border. `SocketSealer` works **as-is** — it caps the bridge's perimeter into a real lethal-feel wall edge. Determinism is untouched (`tests/test_bandgen_determinism.gd` still holds: same seed → same fingerprint). This buys 80% of the feel with zero generator surgery.
- **True open gaps — separate void/gap pass (engine work).** If we want *jumpable/lethal* gaps (real void the Leaper clears, items fall into), that needs a new post-placement pass that (a) carves `VOID` cells between pieces and (b) teaches `SocketSealer` a third tile state (FLOOR / WALL / **VOID**) so it caps walls but leaves void as a hazard edge, not a wall. This **breaks the current connectivity guarantee** (floor is no longer contiguous) — see open questions.

Algorithm sketch (bridge-as-piece, no engine change): catalog = {entry-island, island×N (varied size/socket-count), bridge-short, bridge-long}; bias the weight table toward islands with bridges as connectors; `DepthGrader` grades hops as today; `JunkPlacer` plants the good tiers on high-`depth_norm` (far) islands automatically via the value/tier curve — **far island = best loot** falls out for free.

## Flavor knobs
- **Island count / size** (few-big vs. many-small).
- **Gap width** (cosmetic in bridge-as-piece; real traversal cost in the void-pass version).
- **Bridge redundancy** — one bridge per gap (single chokepoint, tense) vs. two (a flank route, fairer). This is the single biggest feel lever.
- **Hazard-gap type** — water (loss only) / lava (loss + edge damage) / void (instant), as band-flavored skins of the same impassable.

## Synergies & tensions
- **+ Leaper / Conveyor:** best-in-class, as above. **+ Pack hunters:** a single bridge funnels a pack into the doorway — strong, but a *single* bridge plus a Leaper plus a pack can become an unfair pinch; pair with bridge redundancy.
- **Dive clock:** lengthens routes (good pressure) but a forced single chokepoint on the return can spike difficulty unfairly under time — tune redundancy.
- **Depth grading:** synergizes cleanly — far islands are deep by hop-count, so the existing loot curve rewards reach.
- **Combining:** an archipelago "core" with a denser warren archetype *on each island* would layer macro-commit-points over micro-navigation — promising, untested.

## Open questions
- **Connectivity guarantee across gaps (the big one).** The current contract is *contiguous floor*. The bridge-as-piece version keeps it (bridges are floor). The true-void version **violates it** — we'd need a new guarantee: "every island reachable via bridge OR a guaranteed Leaper/grapple parity." Recommend **bridge-as-piece for M-scope** (cheap, deterministic, keeps the guarantee); defer true void to a vertical-traversal milestone. *Scope/effort — flag to Director.*
- **Throw-loss over gaps:** keep it (skill ceiling) or soften (items snap back)? Recommend keep, deep-band only. *Fun/tone — Director.*
- **Pathfinding:** if any opposition uses navmesh later, gaps must be baked as non-nav; bridge-as-piece is already nav-safe (all floor). Void-pass needs explicit nav holes.
- **Does a Leaper trivialize the archetype** by ignoring every chokepoint, or is that exactly the point? Recommend it's the point (banner threat), but cap Leaper density so the archipelago tension isn't fully erased. *Fun — Director, at the gate.*

---
*One-line summary:* Archipelago = island floor-pieces joined by thin bridge-pieces; ships cheaply and deterministically as bridge-as-piece on the existing socket generator (SocketSealer caps gutters for free, far islands auto-get best loot), with true jumpable void deferred as engine work that would break the contiguous-floor connectivity guarantee — and the Leaper/Conveyor opposition plus throw-into-gap loss are its defining beats.
