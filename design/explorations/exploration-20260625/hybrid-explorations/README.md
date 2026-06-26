# Explorations — 2026-06-25: Hybrid / Cross-Exploration Analysis

> ← Part of the [2026-06-25 exploration set](../README.md) ([oppositions](../hazards/README.md) · [bands](../procgen-bands/README.md) · [player mechanics](../player-mechanics/README.md) · [economy](../economy-extraction/README.md) · [hub](../hub-staging/README.md) · hybrid).

The 120 ideas + 2 architecture docs were written in parallel, so each was largely blind to the others. These 5 docs read **each set against all the others** and surface the **synergies, contradictions, and shared dependencies** that only appear at the whole-design level. One doc per set (analyzed against the other four):

- [1 — Oppositions cross-analysis](1-hazards-cross-analysis.md) — what the player faces, vs. the verbs/spaces/stakes
- [2 — Band procgen cross-analysis](2-procgen-bands-cross-analysis.md) — the staging layer the other sets assume
- [3 — Player mechanics cross-analysis](3-player-mechanics-cross-analysis.md) — the verbs, and what justifies each
- [4 — Economy / extraction cross-analysis](4-economy-extraction-cross-analysis.md) — the stakes layer everything orbits
- [5 — Hub / staging cross-analysis](5-hub-staging-cross-analysis.md) — the place that spatializes the rest

---

## The five biggest contradictions (one per analysis)
These each emerged as a *system-level* conflict that the individual idea docs flagged only in isolation:

1. **Reset-severity is unresolved AND contradicts shipped code** *(economy `4`, echoed by hub `5`)* — the GDD says "no total resets — the run resets, the life persists" (§6/§13), but the **live K2 quota does a full meta-wipe**. This single dial (`economy-extraction/p4`) decides whether every forgiving sibling (`p1`/`p2`/`p3`/`q4`/`s5`, persistent gear) and every hub growth/decay room means anything at all. **Must be dispositioned before the rest of the economy/hub set can be specced.** This is the keystone decision of the whole exploration set.

2. **The clock-doubling cluster** *(oppositions `1`)* — the Hunter, Alarm-spawner, Greed-escalation, Rising-tide, and Spreading-fire all express "you stayed too long" and risk collapsing into 4–5 redundant time-pressures. Resolution: deliberately assign **one pressure per scale** (global-dive / per-room / per-loot / per-space), not all stacked.

3. **Expensive backends gate whole enemy families** *(bands `2`)* — the two genuinely-new generator backends (CA caverns `b3`, open-field scatter `b1`) are the most costly to build, yet are the *exclusive* homes for the entire ranged opposition group + ambusher/burrower. So the "how many backends?" scope call **covertly decides which enemies can exist at all.**

4. **Dash i-frames vs. throw-as-signature** *(player `3`)* — a single boolean (`dash_iframes`) silently decides whether combat is "kill it" or "dodge it." If dash trivializes threats, the entire throw-synergy opposition group (`hazards/6-*`) and the throw-economy (fragility `m4`, scoping `x3`) **lose the verb they're built to tax.**

5. **Calm hub vs. hub rent** *(hub `5`)* — `v1`'s whole reason to exist is the exhale (no clock); `v2` admits a recurring drain "turns the safe room into another clock." They can't both ship at full strength — a lean-roguelike-teeth vs. cozy-life-sim tone call to A/B, not co-ship.

## The cross-cutting substrates (build these first — they unblock clusters)
Surfaced repeatedly across all 5 docs as shared prerequisites:
- **Noise / enemy-perception** (`player-mechanics/x2`) — gates sneak, sprint-cost, hide AND the sound-aggro / vision-cone oppositions.
- **A player HP pool** — gates zone/Field oppositions, damage tradeoffs, and heal items; deferred to M2 by every set that touches it.
- **The spatial-inventory model** — gates rotate/repack and the loadout bench; today's inventory is count-based (which conveniently makes swap/drop/carry-load cheap).
- **The two architecture docs' shared data seam** — `procgen-bands/0-` hands a generated band to `hazards/0-`'s opposition spawner; both use the same descriptor + composable-stages + all-off-baseline shape.

## The strongest synergy clusters (exploit these)
- **Ranged oppositions ⇄ open-field/grid bands ⇄ the throw verb + trajectory/bounce** — long sightlines are where all three shine together.
- **Throw-synergy oppositions (`hazards/6-*`) ⇄ the throw-deepening verbs (`player/t*`) ⇄ condition/fragility economy (`m4`)** — one tightly-wound signature-verb loop.
- **The economy ⇄ the hub is nearly 1:1** — every money sink has a room (`s1↔h1/h4`, `p1↔h2`, `q3/r1/m2↔c2`, `s4↔c3`, `p2↔g1`, `p4↔v3/g2`). Build the hub and the economy gets a body for free.
- **Multi-exit band geometry (`procgen-bands/d4`) + set-piece injection (`e4`)** are keystones the economy is *blocked on* (sell-location, extraction-as-objective, special exits).

## Notable structural observations
- **The hub is mostly front-end, not new systems** — it spatializes things that already exist; its growth/decay/texture faces (`g1`/`v3`/`n2`) are one `hub_state` rendered three ways.
- **There are architecture docs for oppositions and bands, but none for the economy/meta or the hub** — the analyses (4, 5) raise whether those deserve one too, given how much they bind together.
- **Almost nothing stands alone** — the player set in particular is pure connective tissue; an idea's value is usually defined by what it counters / hosts / sells / preps elsewhere.

---
*5 cross-analyses covering all 122 exploration files. Authored by `game-director-designer` as a per-set fan-out (each reading its own set in full + all six index READMEs + ~15-28 deep cross-reads). Not yet dispositioned by the Director.*
