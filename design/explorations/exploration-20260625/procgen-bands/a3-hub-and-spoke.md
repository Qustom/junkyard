# Hub-and-Spoke
**Category:** Room-and-corridor archetypes
**Date:** 2026-06-25

> Design exploration only — no code, no branch. Pseudocode is illustrative against the real as-built APIs (`band_generator.gd`, `depth_grader.gd`). The goal is to characterize a band *shape*, tie it to THE FAR YARD's push/cash-out tension, and sketch how the existing socket generator produces it.

## The archetype
A **central chamber** with rooms radiating off it like the spokes of a wheel. You enter at the hub, and every direction is a separate dead-end (or short) limb you can choose to explore. The spatial feel is a *clearing in a forest*: a known, safe center and a ring of unknown branches. It reads instantly — "home base is the middle, the prizes are out at the tips." There is no single "deeper and deeper" corridor; instead there are several parallel investments, each with its own depth, all sharing one return point.

## How it fits THE FAR YARD bands
The hub maps **one-to-one onto the central exit/extract gate**. The GDD's core loop is *push or cash out* (§"Push or cash out"; the dive clock + soft-roguelite haul loss at §6): loot is unbanked until you reach a gate, and death/timeout costs the unbanked haul minus the small "pockets" save. Hub-and-spoke makes that decision **geometric and repeated**: the entry piece (the gate) is the hub, and each spoke is a self-contained *commit*. Walk a spoke out for richer loot, but every cell out is two cells of round-trip you owe the clock. The player keeps asking the same question per-spoke — "one more room out, or turn back to the hub and pick a fresh spoke?" — instead of once per band. This is the archetype's signature: it converts the single push/cash-out bet into a **fan of smaller, legible bets** around a visible safe center.

Best for **shallow-to-mid bands** where the fun gate wants the commit decision *frequent and readable* — the player can always see home. It hosts the opposition spread well: spokes are natural **Field/Fixture** lanes (a gas cloud or sweeping laser gating a rich spoke is a clean "is the tip worth the toll?" tax), while the hub stays an **Actor arena** (a patroller or the Hunter prowling the one place you must keep returning to). Core verbs — explore, salvage, decide, extract — all key off the hub as anchor.

## Generation approach (on the real bandgen system)
The generator (`BandGenerator.generate` → `_generate_once`) already grows from a frontier of `OpenSocket`s, picking a grow socket via `_select_frontier_index` and attaching weighted pieces via `_try_attach_piece`. Hub-and-spoke needs only **a fat entry piece and a branch policy that forks early then runs linear** — both reachable without rewriting the algorithm:

1. **Hub = a high-socket entry piece.** `catalog[0]` is placed deterministically at the origin (`_generate_once` step 1). Author a large entry `ZonePiece` with **N sockets** (one per intended spoke, on distinct `ZoneSocket.Dir`s). Its `open_sockets` seed the frontier with N divergent starts — the spokes' roots.
2. **Branch policy = "fork at the hub, spine on the spokes."** `_select_frontier_index` already supports depth-scaled branching (the R4 hook): with `r4_enabled`, fork chance is high at shallow `OpenSocket.depth` and forced to `0.0` past `r4_max_branch_depth`. Tuning `r4_branch_chance_base` high and `r4_max_branch_depth` to ~1 yields exactly the shape — fork off the hub, then each spoke chains linearly via the `frontier.size()-1` spine path. All draws stay on the RNG autoload, integer-compared, **same draw site/order**, so the `fingerprint(seed+config)` determinism contract holds (and all-off still reproduces the linear baseline).
3. **Depth maps cleanly to spoke distance.** `DepthGrader.grade` is BFS hops from the entry (`depth_index`), and `compute_return_distance` is the independent reverse BFS — *already correct for branches* (its comment says so). On a hub-and-spoke band, `depth_index` *is* "how far out this spoke tip is," and `dist_to_gate` *is* the round-trip cost. **Loot tier keys off `depth_norm`**: deeper spoke cell → better junk (`junk_placer` / Instability `I` banding), so the spoke tips are genuinely the prize, and the central hub is genuinely the safest, poorest cell.

## Flavor knobs
- **Spoke count** — sockets on the hub piece (3–6).
- **Spoke length** — `r4_max_branch_depth` (fork cutoff) + `target_piece_count` split across spokes; uneven lengths via per-spoke length variance.
- **Hub size** — footprint of the entry piece (small junction vs. big arena for an Actor fight).
- **Loot-vs-distance curve** — the `depth_norm → tier` mapping in `junk_placer`: linear, or steepened so only the deepest spoke cell pays out (sharpening the commit).
- **Spoke asymmetry** — bias one spoke long-and-rich (a "jackpot limb") via per-spoke target weighting.
- **Toll gates** — a Field/Fixture opposition planted at a spoke's mouth as an explicit entry tax.

## Synergies & tensions
- **Dive clock:** the strongest pairing — round-trip-per-spoke makes clock pressure *spatially legible*; the player feels time as distance.
- **Oppositions:** hub as Actor arena + spokes as toll lanes is a natural division (ties to the Field/Fixture/Actor taxonomy in `0-scalable-opposition-system.md`).
- **Depth grading:** zero new work — `dist_to_gate` already models the return cost branches need; reward can key off it directly.
- **Tension — connectivity vs. branching:** B2's `is_band_connected` flood-fill handles branches structurally, but `_try_attach_piece` rejects overlaps, so **densely-packed spokes can collide** in cell space; long spokes need room to splay, or the whole-band retry burns attempts. Cap spoke count to fit the footprint.
- **Combining archetypes:** a hub whose spokes each *end in* a small loop or grid (composite archetype) gives "radial limbs with a destination," softening the dead-end feel.

## Open questions
- **Dead-end backtrack feel — fun or tedious?** Walking a spoke out and all the way back with no shortcut may read as padding. Should a deep spoke occasionally drop a one-way shortcut back to the hub (rewarding the commit)? **Director call (fun).**
- **Spoke-count vs. footprint budget:** how many spokes before overlap-rejection makes generation unreliable at the M1 `max_band_attempts`? Needs a generation-success sweep. **Effort/scope.**
- **Does the hub need to be *re*-visited, or just *reachable*?** If extract is only at the hub, every spoke is a forced round-trip (max tension). If shortcut gates exist, the hub becomes optional and the commit softens. Which serves the fun gate? **Director call (vision/fun).**
- **Authoring cost:** a fat multi-socket hub piece is a bespoke greybox asset, not a reuse of the existing 2-cell-width corridor/room set. **Effort.**
- **Bands suited:** is this a *shallow*-band signature (legible, frequent commits) or does it scale to deep bands, where many long spokes may overwhelm the clock? **Scope.**
