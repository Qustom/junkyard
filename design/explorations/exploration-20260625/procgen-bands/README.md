# Explorations — 2026-06-25: Band Procedural-Generation Archetypes

How the **bands** (the regions the player dives through) could be generated. Each file explores one archetype/principle/flavor: **what it is**, **how it fits THE FAR YARD bands** (extraction loop, dive clock, depth grading, hosting the [opposition spread](../hazards/README.md)), the **generation approach on the real bandgen system**, **flavor knobs**, **synergies & tensions**, and **open questions** (vision/fun/scope/effort calls flagged for the Director).

All are grounded in the **real socket-based piece-assembly generator** — `systems/bandgen/band_generator.gd`, `band.gd`, `placed_piece.gd`, `socket_sealer.gd`; data `data/bandgen_config.gd`, `piece_catalog.gd`, `zone_socket.gd`; depth `systems/depth/depth_grader.gd`, `junk_placer.gd` — and preserve the seeded-RNG determinism contract (`tests/test_bandgen_determinism.gd`).

> **Two layers:** the **base archetypes** (groups A–C) are standalone layouts; the **organizing principles** (D) and **generation flavors** (E) *reshape or apply on top of* any base archetype.

## 0 — Cross-cutting architecture
*How all of the below get generated from data, not a bespoke generator each time.*
- [Scalable Band-Generation System](0-scalable-band-generation-system.md) — promotes today's single socket generator into a **default backend + first stages** of a data-driven `BandProfile.tres` pipeline (backend → archetype → ordered principle overlays → ordered flavor passes → connectivity guarantee → seal/grade/populate). The existing band, the 19 archetypes/principles/flavors below *with their modifications*, and future bands all become **`.tres` composing reusable stages**; the empty-flavor socket profile stays a byte-identical determinism control. Includes prior-art research (Dead Cells biomes, Unexplored cyclic generation, WFC, Spelunky chunks) + a composition-proof table + the band→opposition handoff seam. **Director flag:** how many generation backends to actually build vs defer (CA caverns + scatter open-field are the only genuinely-new code paths).

## A — Room-and-corridor archetypes
- [Discrete rooms + connectors](a1-discrete-rooms-connectors.md) — legible encounter units (≈ the current `branch_chance==0` default)
- [Open floorplan / "building"](a2-open-floorplan-building.md) — shared walls + doorways, no corridors, few safe chokepoints
- [Hub-and-spoke](a3-hub-and-spoke.md) — central exit; per-spoke push-out/turn-back commit
- [Critical path + side rooms](a4-critical-path-side-rooms.md) — forced spine + greedy detours; easiest to tune for extraction

## B — Open-space archetypes
- [Open field with cover](b1-open-field-with-cover.md) — long sightlines; throw verb + ranged shine (needs a scatter pass)
- [Archipelago / islands](b2-archipelago-islands.md) — islands + bridges/gaps; chokepoint & leaper puzzles
- [Organic caverns](b3-organic-caverns.md) — cellular-automata blobs; low sightlines (a *second* generator backend)

## C — Maze & density archetypes
- [Dense maze](c1-dense-maze.md) — claustrophobic cornering; best as a bounded region, not a whole band
- [Sparse labyrinth](c2-sparse-labyrinth.md) — maze topology, wide corridors; navigation minus the frustration
- [Grid / city blocks](c3-grid-city-blocks.md) — streets vs interiors; legible teaching band

## D — Layout-organizing principles *(reshape any archetype)*
- [Radial / concentric](d1-radial-concentric.md) — danger+loot scale with distance from a pole (literal extraction tension)
- [Lane-based](d2-lane-based.md) — parallel routes; read-and-commit replayability
- [Layered / tiered](d3-layered-tiered.md) — stitched sub-zones, each its own ruleset
- [Asymmetric entry/exit](d4-asymmetric-entry-exit.md) — spawn-vs-extract placement; the loaded return trip

## E — Generation flavors *(apply on top of any archetype)*
- [Symmetry](e1-symmetry.md) — mirrored/rotational = deliberate; asymmetric = wild
- [Density gradient](e2-density-gradient.md) — clustered pockets → tense/breather/tense rhythm
- [Verticality fakes](e3-verticality-fakes.md) — ledges/pits/drops imply height + one-way flow in 2D
- [Set-piece injection](e4-set-piece-injection.md) — hand-authored prefab rooms (vault/arena/gauntlet); cheapest anti-sameness win
- [Wear / decay state](e5-wear-decay-state.md) — same layout, variable ruin; blocked routes + shortcut breaches

---
**Recurring Director-decision flags across these docs:**
- **Second generator backend?** Organic caverns (CA) and full tile-mazes don't fit socket piece-assembly — they're a separate backend (cost vs. variety).
- **Scatter/poisson pass** for open-field cover is genuinely new code beyond the current piece placer.
- **Connectivity guarantees** under decay, archipelago gaps, and dense mazes — every route-altering idea must still guarantee a findable entry→exit path under the dive clock.
- **"Layered/tiered" vs the existing BANDS concept** — possible conceptual overlap to resolve (intra-band tiers vs. bands as biomes).
- **Cheapest wins first:** set-piece injection and wear/decay both ride the *existing* socket/sealer machinery — strong effort-to-variety ratio.

*19 explorations across 5 groups. Authored by the `game-director-designer` role as a parallel fan-out; not yet dispositioned by the Director.*
