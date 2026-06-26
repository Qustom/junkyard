# A Map / Intel Table
**Category:** The hub as run-selection / commitment

## The idea
A physical **intel table** in the hub — a greybox prop with a fold-out band schematic
on it — is where you *buy information and act on it in one continuous beat*. You walk
up, pay Money (or spend Knowledge) for a **forecast** of the next dive, watch part of
that dive's map/hazard picture resolve out of fog on the table surface, and then —
without leaving the table — **choose your entry point, difficulty, and loadout**
knowing what you just paid to learn. The hub stops being a menu and becomes a *place
where uncertainty is purchased and a plan is committed*: peer at the table, see the
shape of the run, then push off into it. The intel and the departure decision are one
gesture, not two screens.

This spatializes the s4 "Map Intel" money-sink: instead of a shop line-item, the
table makes "pin the next seed, reveal part of it, choose accordingly" a legible
diegetic ritual — the cartographer's bench of a junkyard diver.

## What exists today
- **The system this places is s4 Map Intel** (`economy-extraction/s4-map-intel.md`):
  three tiers — partial map (shape), hazard forecast (the R1–R4 manifest), high-value-room
  tip (one EV pin). s4's load-bearing finding: band generation is a *pure seeded function*
  (`BandGenerator.generate(seed, cfg, catalog)`), so a forecast is just a headless peek
  at output the generator will reproduce byte-identically on dive entry — **truthful by
  construction**, zero new gen logic.
- **The blocker the table makes physical.** Today the next-run seed is minted at
  dive-start: `MainGame._next_seed()` = `Time.get_unix_time_from_system() * 31 + ...`
  (`scenes/game/main_game.gd:213`). You cannot sell intel about a run with no seed yet.
  s4's fix — *pin the next seed as meta-state at the surface* — is exactly what the
  table dramatizes: spreading the schematic on the bench **is** the act of committing the
  next seed. `RunConfig.seed_override` (`run_config.gd:49`, default -1) is the consumption
  hook; the table writes it.
- **Knowledge as the free path** (`Junkyard_GDD.md` — "Knowledge unlocks … safe routes")
  gives a standing, no-Money forecast capability the table reads.
- **Departure surfaces** the table feeds: the job board (`hub-staging/c2-job-board-contract.md`)
  and the departure point (`c1-departure-point.md`) — the table is the *read* step upstream
  of their *commit* step.
- **Missing:** no hub scene exists (NEW scene); no next-seed meta field / `schema_version`
  bump; no intel-payload extraction or its `RunConfig` gate.

## How it could fit in
1. **A greybox table** (`ColorRect` schematic + three buy buttons) that, on purchase,
   (a) pins the next seed into meta-state, (b) runs `BandGenerator.generate(pinned_seed, staged_cfg, catalog)`
   headless, (c) extracts the bought tier's payload (silhouette / hazard manifest / EV pin),
   frees the band, and renders the payload as fog peeling back on the table.
2. **The continuous beat:** the same table panel then exposes **entry/difficulty/loadout**
   pickers that write into the *staged* `RunConfig` the departure surface (c1/c2) consumes —
   buy → read → commit without a scene change.
3. **Feature gating:** add an `intel_enabled` master toggle + per-tier toggles to `RunConfig`,
   all-off = today's blind dive (the permanent control), mirroring the R1–R4 toggle pattern.
   Telemetry: `intel_bought {tier, currency, seed}`; gate-test = does intel change routing
   entropy / deepest-depth vs. blind runs on the same seed distribution.

## Research (cited)
- **Deep Rock Galactic — Terrain Scanner / mission selection.** Missions are chosen at a
  terminal in front of a hologram of the planet, and the in-mission scanner renders
  objective markers as coloured orbs over the cave — the canonical "stand at a map prop,
  read the terrain, pick where to go" loop, exactly the *place* the table wants to be
  ([Terrain Scanner](https://deeprockgalactic.wiki.gg/wiki/Terrain_Scanner), [Missions](https://deeprockgalactic.fandom.com/wiki/Missions)).
- **Darkest Dungeon — Scouting + Dungeon Map.** Scouting reveals nearby rooms/corridors
  *and their contents* so you reroute around danger; the purchasable Dungeon Map provisioning
  item reveals the layout up front — the literal "pay for a map" precedent and the proof that
  partial reveal *de-risks without removing* the dungeon's threat
  ([Scouting](https://darkestdungeon.fandom.com/wiki/Scouting), [Dungeon Map](https://darkestdungeon.wiki.gg/wiki/Dungeon_Map)).
- **FTL / Loop Hero / Hunt: Showdown.** FTL's jump map shows beacon *types*, not contents —
  partial paid-attention intel that drives routing under fog; Hunt's compass narrows the boss
  to a region via clues rather than pinning it; Loop Hero has the player *build* the map. All
  three argue: reveal enough to *plan*, never enough to remove the gamble — our three tiers sit
  on that reveal-granularity axis (shape ⊂ contents ⊂ exact pin).

## Open questions
- **Seed-pinning architecture (needs a programmer's eye).** Pinning the next seed touches the
  run/meta boundary, `_next_seed()`, and `schema_version` (intel bought must survive a quit).
  s4 already flags this; the table doesn't change the difficulty, only makes it the literal
  unlock condition. Programmer call on the meta field + migration.
- **Does paid intel trivialize tension? (Director fun-gate.)** The high-value-room pin risks
  flattening exploration into a beeline. Recommendation: gate the precise tip behind Knowledge
  or a steep price so it's a rare splurge; reveal *shape*, not *outcome*. Only a playtest decides.
- **Overlap with the job board (c2) and Knowledge.** If a contract already specifies the dive
  and Knowledge already "unlocks safe routes," is a paid table redundant? Possible seam: c2
  sets *what/why* (objective + reward), the table sets *what you know going in* (fog level);
  Money intel stays relevant for deeper bands your Knowledge hasn't covered. **Director scope
  call** on whether the table and board are one fused surface or two distinct beats.
- **One table or many props?** Folding intel into the departure point (c1) keeps the hub lean;
  a dedicated table adds a destination but more greybox. Scope/vision call for the Director.

Sources:
- [Deep Rock Galactic — Terrain Scanner](https://deeprockgalactic.wiki.gg/wiki/Terrain_Scanner)
- [Deep Rock Galactic — Missions](https://deeprockgalactic.fandom.com/wiki/Missions)
- [Darkest Dungeon — Scouting](https://darkestdungeon.fandom.com/wiki/Scouting)
- [Darkest Dungeon — Dungeon Map](https://darkestdungeon.wiki.gg/wiki/Dungeon_Map)
