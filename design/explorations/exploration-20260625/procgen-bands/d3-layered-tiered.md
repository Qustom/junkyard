# Layered / Tiered (organizing principle)
**Category:** Layout-organizing principles

## The principle
A band is partitioned into a small number of contiguous **sub-zones (tiers)**, each running a *different ruleset* — its own piece-set, its own opposition/hazard package, and optionally its own base archetype. You don't get one uniform space; you get a **tour through biomes**: a flooded stretch gives way to a pitch-dark warren gives way to a dense, alarm-rigged kill-box. It is a *compositional* principle, not a base layout: it reshapes whatever archetype it wraps by chopping the spine into bands-of-rules. Tier 1 might be `a1` discrete-rooms; tier 2 `b3` organic caverns; tier 3 `c1` dense maze — stitched into one continuous dive.

## How it fits THE FAR YARD bands
Caution on naming: the GDD's **BANDS are already distinct biome-like regions**. This principle is strictly **intra-band tiering** — sub-zones *within a single band's* generated layout — not a competitor to the band concept. Read it as "a band can be authored as N rule-zones in sequence" rather than "more bands."

It fits the extraction loop cleanly: tiers give **escalating rules with depth**, which is exactly the "push deeper" gamble B3 already encodes for loot. The shallow tier teaches the band's safe verbs; deeper tiers layer a hazard ruleset on top (rising-tide, darkness-pocket, alarm-spawner), so the dive clock and the rising junk-value curve are reinforced by a rising *rules* cost. Each tier hosts a different opposition package, so the band's core verbs (move, salvage, fight, extract) get re-contextualized zone by zone without new mechanics.

## Generation approach (on the real bandgen system)
The generator already grows a depth-ordered spine: `BandGenerator._generate_once` appends pieces in placement order, and `DepthGrader.grade` (`systems/depth/depth_grader.gd`) assigns each `PlacedPiece.depth_index` / `depth_norm` by BFS hops from `band.entry_piece`. Tiering keys off that axis.

Sketch (all integer-deterministic, on the existing RNG autoload):
1. Add a `tiers` array to `BandGenConfig` (`data/bandgen_config.gd`): each entry = `{depth_fraction, piece_tag, opposition_id, archetype}`. Tier boundaries are cut on `depth_norm` thresholds.
2. During growth, the active tier is a pure function of the grow socket's gen-time depth (`OpenSocket.depth`, the placement index `_select_frontier_index` already reads). The tier selects a **filtered catalog slice** for `_weighted_pick_index` — this is exactly what the dormant `_tags_ok()` predicate in `_find_mate_socket` was reserved for: activate it to gate candidates by the active tier's `piece_tag`.
3. **Boundary sockets** are the natural seam: the first socket of tier N+1 is a normal mate (`ZoneSocket.opposite`), optionally restricted to a "transition" piece tag so the biome change reads as a doorway, not a teleport. `socket_sealer.gd` caps unused sockets as today.
4. After layout, `DepthGrader` orders tiers by depth (already does the ordering work); a post-pass tags each piece with `tier_index` from its `depth_norm`, and the opposition/hazard spawner reads `tier.opposition_id` per piece.

Determinism holds: tier selection is integer-threshold math on `depth_index`, no new RNG draws; `tests/test_bandgen_determinism.gd` fingerprint is unchanged when `tiers` is empty (the all-off default reproduces today's single-ruleset band).

## Flavor knobs
- **Tier count** (2–4 recommended; 1 = today's baseline).
- **Per-tier ruleset**: piece_tag + opposition_id + optional archetype override.
- **Transition sharpness**: hard boundary (single seam piece) vs blend (a few shared/mixed pieces straddling the threshold).
- **Tier ordering by depth**: monotonic-escalating (calm→lethal) vs deliberately jarring sequences.

## Synergies & tensions
- **Composes every other archetype** — each tier *is* a base layout; this is the principle that lets a band sample `a1`/`b3`/`c1` in one dive. Pairs naturally with the opposition catalog (one ruleset per tier).
- **Tension — legibility:** too many rulesets per band reads as incoherent noise; the player can't form a mental model. Cap tiers low and telegraph each boundary.
- **Tension — dive clock:** learning a fresh ruleset mid-dive costs time the extraction clock is already pressuring. Escalating order (familiar→novel) mitigates; random order amplifies.

## Open questions
- **Overlap with the band concept (flag to Director):** is intra-band tiering *worth it* when bands themselves already deliver biome variety? Recommendation: prototype as 2-tier only (a "front" and a "deep" ruleset) to prove value before committing to N-tier authoring cost — it may duplicate what swapping bands already gives.
- **Authoring cost (scope/effort):** N tiers × per-tier piece-sets multiplies the piece catalog and the opposition-tuning surface. Director call on content budget.
- **Fun (Director):** does a mid-dive ruleset change feel like *escalation* or *whiplash*? Pure feel question — needs the playtest gate, not a spec answer.
- **Transition pieces:** do we author dedicated seam pieces (clear biome doorways) or let tags blend? Affects the catalog and the `_tags_ok` activation shape.
