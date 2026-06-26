# Explorations — 2026-06-25

A graybox design-exploration set for THE FAR YARD, authored as parallel `game-director-designer` fan-outs and grounded in the real as-built systems. **Not yet dispositioned by the Director.** Three companion sets, each with its own index:

| Set | Folder | Count | What it covers |
|---|---|---|---|
| **Oppositions** (enemies & hazards) | [hazards/](hazards/README.md) | 36 + architecture | What the player faces — grouped by the decision each forces (pursuers, ranged, traps, zones, time-pressure, throw-synergy) + the *Scalable Opposition System* architecture |
| **Band procedural generation** | [procgen-bands/](procgen-bands/README.md) | 19 + architecture | How the **bands** (regions) get generated — room/corridor, open-space, maze archetypes + organizing principles + flavors, and the *Scalable Band-Generation System* architecture. The layouts that **host** the oppositions |
| **Player mechanics** | [player-mechanics/](player-mechanics/README.md) | 25 | What the player *does* — movement, the active inventory, deepening the throw, other item verbs, interaction verbs, and the extraction-binding tradeoffs. The verbs that **multiply against** the oppositions |
| **Money / quota / extraction** | [economy-extraction/](economy-extraction/README.md) | 26 | The meta-loop — the missing money-sink/investment half, plus quota depth, extraction-mechanic depth, run-to-run persistence, dynamic economy, and risk/reward dials. What makes a haul **matter** between runs |
| **Hub / staging area** | [hub-staging/](hub-staging/README.md) | 14 | The between-runs **place** — the money sink made physical (shop, stash, loadout bench, upgrade station), run-selection & commitment, the pacing-valve exhale, the home of visible meta-progression, and light narrative texture. Where the economy becomes a space you walk through |
| **Hybrid (cross-analysis)** | [hybrid-explorations/](hybrid-explorations/README.md) | 5 | Each set read **against all the others** — the synergies, contradictions, and shared dependencies that only appear at the whole-design level. Start here for the system-level view |

## How the sets relate
The **player mechanics** are the verbs; the **oppositions** are what those verbs are tested against; the **bands** are the spaces where the two meet; the **economy** is why any of it matters once you surface; the **hub** is where the economy becomes a physical place you prep, commit, and grow in. A dash (`player-mechanics/m1`) only matters because of a charger (`hazards/1-charger`); a charger only matters in a corridor (`procgen-bands/a1`); the corridor's loot only matters because of quota and the gear sink (`economy-extraction/s1`); and the gear sink only feels real when it's a shop you walk up to (`hub-staging/h1`). Each set's README has its own per-item table and its own roll-up of Director-decision flags.

> **For the system-level view, read [hybrid-explorations/](hybrid-explorations/README.md) first** — it cross-analyzes all five sets against each other and ranks the five biggest contradictions and the shared substrates to build first. The threads below are the short version.

## Cross-cutting threads worth the Director's eye
- **Two architecture docs** propose the same shape — a data `.tres` descriptor + composable stages/components + an all-off baseline-parity & seed-determinism contract — for [oppositions](hazards/0-scalable-opposition-system.md) and [band generation](procgen-bands/0-scalable-band-generation-system.md). They share a clean data seam (a generated band hands placement context to the opposition spawner).
- **Player HP pool is a recurring M2 prerequisite** — zone/Field oppositions (gas, electrified floor), damage tradeoffs, and heal items (`player-mechanics/u1`) all wait on it.
- **Enemy perception / noise** is the other shared substrate — sneak, hide, sprint-cost, sound-aggro zones, and vision-cone patrollers all depend on a hearing/LoS system that doesn't exist yet (`player-mechanics/x2`).
- **The RunConfig knob pattern** (default-off = byte-identical baseline, config-marked telemetry) is the proposed A/B vehicle across all five sets, consistent with the existing M1.x experiment discipline.
- **The reset-severity dial** (`economy-extraction/p4`) surfaced a live doc contradiction worth resolving early: the GDD says "no total resets," but the built K2 quota does a full meta-wipe. It's the single knob that sets the game's roguelike↔roguelite identity, and it reframes the whole economy set — *and* what the hub renders as growth vs decay (`hub-staging/v3`, `g1`).
- **The hub is mostly front-end, and it's one scene + one `hub_state`.** It spatializes economy mechanics that already exist rather than adding systems; its growth/decay/texture faces (`hub-staging/g1`,`v3`,`n2`) are the same meta-state rendered three ways. The big open question there is art-authoring cost, not architecture.

---
*120 explorations + 2 architecture docs across 5 sets, plus 5 hybrid cross-analyses. Authored 2026-06-25 as parallel `game-director-designer` / `narrative-writer` fan-outs; awaiting Director disposition.*
