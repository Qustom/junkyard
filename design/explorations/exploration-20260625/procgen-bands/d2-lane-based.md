# Lane-Based (organizing principle)
**Category:** Layout-organizing principles
**Date:** 2026-06-25

> Procgen organizing-principle exploration only. Pseudocode is illustrative against the real as-built `BandGenerator` API; no production code, no contract widening, no branch. Unlike a room-and-corridor *archetype*, this is a **reshaping principle**: it overlays a base archetype (rooms, caverns, open-field) and bends its growth into parallel routes.

## The principle

A lane-based band offers **a few parallel routes from entry to exit** — three or four roughly-independent corridors of pieces running the same gate-to-gate distance. The player **reads the lanes, picks one, and commits**, occasionally finding a **cross-connector** to hop sideways mid-run (at a cost). It does not invent its own room shapes — it *organizes* whatever archetype fills each lane: a lane can be a critical-path spine, a string of caverns, or an open-field stretch. The principle is the **topology** (N near-parallel spines + sparse rungs), not the contents.

## How it fits THE FAR YARD bands

The "read-the-lane, then commit" beat is a **second decision layer on top of push/cash-out**, and it directly serves replayability: each run you scan three survivable-looking routes and bet on one before you know what's down it. A lane **is a time-budget** — committing to a lane is committing a slice of the dive clock (GDD §6), so picking wrong (a lane that turns out gauntlet-heavy) costs you the extraction window, not just HP. Cross-connectors are the pressure valve: bail to the easier lane, but spend time and break cover to do it.

Each lane is naturally **themed by a different opposition flavor** (the `exploration-20260625/` set): a "patroller/sentry" lane reads as slow-but-watched, a "rising-tide/spreading-fire" lane as a sprint-or-die, an "armored/eater" lane as a slog. That's how the player *reads* a lane at a glance — by its telegraphed flavor. It overlays best on **mid-to-deep bands** where the loop is taught and a meaningful pre-commit choice raises tension. Archetypes it overlays: critical-path (each lane a spine), discrete-rooms-connectors, organic-caverns (each lane a cavern chain).

## Generation approach (on the real bandgen system)

The socket assembler grows from a frontier of `OpenSocket`s (`band_generator.gd:115`), so N lanes = **N seeded sub-spines** sharing one entry and one exit junction.

Sketch (one `_generate_once` pass, `band_generator.gd:84`):
1. **Fan from entry.** The entry piece exposes several open sockets (`_make_placed`, line 424). Tag each as a **lane root** and grow each lane as its own linear spine — the existing deepest-socket policy (`_select_frontier_index` → `frontier[-1]`, line 329), but partitioned so each lane only consumes its own sockets. With one lane and lanes-off this *is* the M1.0 linear baseline (the permanent control).
2. **Run parallel.** Grow all lanes toward the same `target_piece_count` depth so they reach a common exit band; `_alignment_offset` (line 184) keeps them on disjoint integer cells, and `band.fits` (line 162) rejects overlaps if lanes drift together.
3. **Cross-connectors (sparse).** At a few matched depths, fork a short corridor from a lane-A spine socket toward a lane-B socket — the same fork draw as R4 (`RNG.randi_range`, line 328), gated by a low `cross_connector_chance`. `is_band_connected` (line 477) still guarantees walkability; `socket_sealer` caps the rest.
4. **Per-lane risk tiering.** `DepthGrader.grade` (`depth_grader.gd:26`) already assigns `depth_index`/`depth_norm` by BFS hops — identical across parallel lanes at the same depth. Add a per-lane **risk multiplier** (a lane id stamped at the lane root) that `junk_placer` and opposition density read: the high-risk lane gets denser hazards *and* a higher loot tier, so the lanes are genuinely risk-tiered, not cosmetic. `dist_to_gate` (line 56) still prices the walk home per lane.

Every choice flows through `RNG` at the same draw sites, so `(seed + config)` stays byte-reproducible (`tests/test_bandgen_determinism.gd`); the all-off default (1 lane, 0 connectors) reproduces the M1.0 fingerprint.

## Flavor knobs

- **Lane count** — 2 (binary bet) to 4 (rich read, more gen cost).
- **Cross-connector frequency** — 0 (full commit) to several (porous, low tension).
- **Per-lane risk/loot variance** — how far the safe and greedy lanes spread on hazard density and junk tier.
- **Lane legibility** — how telegraphed the danger is at the mouth (opposition flavor preview, lighting, a peek down the corridor) — the dial between *informed bet* and *blind gamble*.

## Synergies & tensions

- **Critical-path** — each lane is literally a spine; the two principles compose cleanly (a lane *is* a critical path with its own side rooms).
- **Layered/tiered** — risk-tiered lanes are a horizontal version of vertical tiering; a deep band can layer both (pick a lane, then push its depth).
- **Dive clock tension** — committing a lane spends the clock; this is the *intended* pressure, but a bad-luck gauntlet lane with no nearby connector can feel unfair — connector spacing must guarantee an out.
- **Crossing risk** — mid-run lane swaps break cover into an unread lane; great tension, but if connectors are too frequent the commit evaporates and lanes blur into one open space.

## Open questions

- **How does the player READ lane risk before committing?** *The load-bearing fun/vision call.* Options: (a) a clear opposition-flavor tell at each mouth, (b) a brief line-of-sight peek down each corridor, (c) discovery-only (commit blind). Too much info kills the gamble; too little makes the pick arbitrary. Recommend a **flavor tell + short peek**, tuned at the M-gate. *Director.*
- **Lane count default** — 3 reads best but costs the most gen footprint and content variety; 2 is cheaper but a thin choice. *Scope/effort call.*
- **Are dead-end lanes allowed?** A lane that does NOT reach the exit (forcing a connector hop) is high-tension but can feel like a trap. *Fun call.*
- **Connector guarantee** — must every high-risk lane have a reachable connector to an easier lane within X depth, so commitment is never a death sentence? Recommend yes. *Design, small effort.*
- **Determinism of partitioned frontiers** — per-lane socket partitioning needs a stable lane-id tag and same-order integer compares to keep the all-off fingerprint intact (mirrors the R4 contract). *Effort: small.*
