# Radial / Concentric (organizing principle)
**Category:** Layout-organizing principles
**Date:** 2026-06-25

> Design exploration only — no code, no branch. Pseudocode is illustrative against the real as-built APIs (`band_generator.gd`, `depth_grader.gd`, `junk_placer.gd`). This is a *layout-organizing principle*: it RESHAPES any base archetype (discrete-rooms, hub-and-spoke, caverns, grid) by re-deciding how depth is spatially assigned — it is not a standalone floorplan.

## The principle
Pick a **pole** — a center cell, an edge, or the entry — and let danger and loot scale **monotonically with radial distance from it**. The classic reading is "the deep end is the middle": the entry is the rim, the center is the jackpot, and concentric **rings** of escalating reward + escalating opposition sit between. Equivalently the pole can be an edge (a far wall) so depth grows as a one-directional front. The defining move is that *meaning is keyed to a distance field*, not to graph topology — so the same ring structure can be laid over a hub (spokes become radii), over discrete rooms (rooms inherit their ring's danger budget), or over caverns (the distance field is just sampled more finely). It is a reshaping lens, applied on top of whatever produced the pieces.

## How it fits THE FAR YARD bands
This is almost a literal model of extraction tension. The GDD loop is *push or cash out* (the dive clock + soft-roguelite haul loss): unbanked loot is owed back to the gate, so **every cell deeper is two cells of round-trip you owe the clock**. Radial makes that owed distance the *organizing axis of the whole band* — "deeper = better but scarier" stops being flavor and becomes the literal gradient. The push/cash-out decision becomes spatial and continuous: at each ring boundary the player re-asks "cross into the richer/nastier ring, or turn and bank what I have?" The as-built `DepthGrader` already supplies exactly the two numbers this needs — `depth_index` (reward axis) and `dist_to_gate` (the round-trip cost) — and `junk_placer` already keys value/tier/density off `depth_norm`. Radial doesn't add a new system; it changes **what `depth_norm` is measured from** so rings emerge.

It overlays best on **hub-and-spoke** (spokes become literal radii — rings cut across all spokes at once) and on **open-floorplan / cavern** archetypes (a continuous distance field reads as smooth rings). It overlays weakly on a pure linear spine, where "radial from the entry" collapses back into plain `depth_index` and adds nothing.

## Generation approach (on the real bandgen system)
The reshaping happens **entirely in the depth pass**, not the stitcher. `BandGenerator` runs unchanged (it still grows from `OpenSocket`s, weighted-picks pieces, rejects overlaps). What changes is the source of the distance field that `DepthGrader.grade` BFS-floods from.

As built, `DepthGrader.grade` floods from `band.entry_piece` (`entry_idx`), so `depth_index` = hops from the rim. Radial-from-center is the same algorithm with a **different root**:

1. **Pick the pole deterministically.** After layout, choose the center as the piece with maximum existing `depth_index` (the as-built `band.deepest_piece`) — no RNG, pure graph function, so the determinism contract holds. (Edge-pole variant: keep the entry as root — that *is* the current behavior.)
2. **Re-grade from the pole.** Run the existing BFS rooted at the center piece to get `dist_from_center` per piece; define `depth_norm := 1 - dist_from_center / max_dist` so depth_norm=1 sits at the center, rising radially inward.
3. **Keep `dist_to_gate` honest.** `compute_return_distance` stays rooted at the entry — it is the *cost* axis and must always measure hops home, independent of where reward peaks. Radial decouples the two: reward keys off the center-distance field, cost keys off the entry-distance field. (On hub-and-spoke these point opposite ways — the tension is the point.)
4. **Drive oppositions + junk by ring.** `junk_placer.plan` already samples `curve.value_mult/min_tier/expected_count` at `p.depth_norm` — unchanged, it now reads radially. Quantize `depth_norm` into N rings to gate opposition budget per ring (more/harder oppositions from `0-scalable-opposition-system.md` toward the center).

Net change: **where depth is computed from** (BFS root + a normalization flip), nothing in the placement loop or RNG sequence. Seeded determinism is preserved because root selection is a pure graph function.

## Flavor knobs
- **Pole choice** — center (max-depth piece) vs. entry-edge vs. an arbitrary anchored piece; flips where the jackpot lives.
- **Ring count** — quantization of `depth_norm` into discrete bands (3–4, matching the Instability `I` banding flavor).
- **Gradient steepness** — the `depth_norm → value/tier` curve shape in `DepthCurve` (gentle linear vs. only-the-core-pays sharp).
- **Loot-vs-danger curve offset** — let danger ramp a ring *ahead* of loot (the next ring looks scary before it looks rich) to sharpen the commit.
- **Eccentricity** — fuzz the distance field so rings aren't perfect circles (avoids a too-readable bullseye).

## Synergies & tensions
- **Hub-and-spoke** — the natural pairing: spokes are radii, rings cut across them, and a single ring boundary becomes one legible commit line for all spokes at once.
- **Dive clock** — strongest synergy: when the pole is the center but the gate is the rim, reward and return-cost grow *in opposite directions*, so the deepest haul is also the longest carry — pure extraction tension, no extra system.
- **Asymmetric exit placement (tension)** — if extraction is only at the entry rim, radial maximizes tension; but if a second exit sits near the center (a "deep extract"), the radial cost gradient inverts and the commit softens. Exit placement and pole choice must be designed together.
- **Connectivity (tension)** — densely-ringed layouts pack pieces tightly; `_try_attach_piece` overlap-rejection can burn `max_band_attempts`. Rings need radial breathing room.

## Open questions
- **Center-pole vs. edge-pole as the M1 default?** Edge-pole *is* the current shipped behavior (zero work); center-pole is the more dramatic "dive to the core" read but needs the re-grade + exit-placement co-design. **Director call (vision/fun).**
- **Is a visible bullseye fun or too predictable?** A clean radial gradient is legible but may telegraph the whole band; eccentricity fuzzing trades readability for surprise. **Director call (fun).**
- **Discrete rings vs. continuous gradient?** Rings read clearly and map onto Instability bands; a smooth field feels organic but blurs the "I'm crossing into danger now" beat. **Director call (fun); effort is symmetric.**
- **Re-grade cost + determinism surface.** Re-rooting BFS at the center adds one pass and a new root-selection rule into the deterministic surface — small, but it must be covered by `test_bandgen_determinism.gd`. **Scope/effort.**
- **Does radial earn its keep over plain `depth_index` on non-radial archetypes?** On a linear spine it collapses to the existing behavior; it only pays off on hub/cavern/grid shapes. Worth gating the principle to those archetypes. **Scope.**
