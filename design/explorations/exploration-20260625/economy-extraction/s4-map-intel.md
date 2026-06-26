# Map Intel
**Category:** Money sink / investment loop

## The mechanic
Between runs, you spend a currency to **buy information about the next dive** before you commit to it. Three tiers of product, escalating in price and specificity:

1. **Partial map** — reveal the band's spine/shape (room count, branch points, the rough silhouette the fog would otherwise hide), so you route instead of grope.
2. **Hazard forecast** — a manifest of *what* opposes you this run: pursuing-hazard density, the maze/nav severity, exposure pressure (the R1–R4 oppositions), without telling you exactly where.
3. **High-value-room tip** — "the deepest east branch holds a tier-3 cache." A pin on one specific high-EV node, the most precise and most expensive product.

Money (or Knowledge — see below) buys **de-randomization of risk**. The dive's danger is unchanged; your *uncertainty* about it shrinks, which converts a blind gamble into a planned extraction. This is the purest expression of the money-sink loop: cash spent on the surface that pays out as fewer deaths and deeper successful runs below.

## What exists today
The load-bearing fact: **band generation is a pure, seeded function**. `BandGenerator.generate(seed, cfg, catalog)` is documented as "a PURE FUNCTION of its inputs … a given seed yields a byte-identical layout" (`systems/bandgen/band_generator.gd`). Everything intel would describe — the room graph, branch points (`_select_frontier_index`), corridor rarity, and downstream `depth_grader` / `junk_placer` loot tiers — is **fully determined by `(seed, config)`**. So intel is not a separate system that "knows" the future; it is a **pre-computed peek at output the generator can produce on demand**. You can generate the band headless, read whatever the tier sells, throw the band away, and you have truthful intel with zero new generation logic.

`VisionFog` (`entities/dive/vision_fog.gd`) is the thing intel *counteracts*: it OCCLUDES the band beyond a vision bubble (hides, doesn't dim) and keeps a three-state fog memory. A bought "partial map" is conceptually the fog's revealed set, pre-seeded before you enter.

**The blocker — is the next-run seed known in advance?** Today, **no**. `MainGame._next_seed()` is `Time.get_unix_time_from_system() * 31 + _run_count * 2654435761` — the seed is minted at the moment you start the run (`scenes/game/main_game.gd:213`, `start_run(BAND_ID, seed)`). `RunConfig.seed_override` exists (default `-1` = none) but nothing pre-commits a seed to a *future* run. **You cannot sell intel about a run that doesn't have a seed yet.** Missing: a "next-run seed is decided at the surface, not at dive-entry" step — pin the seed when you buy intel, carry it through to `start_run`.

## How to fit it in
1. **Pin the next seed at the surface.** Replace "seed minted at dive-start" with "next-run seed exists as meta-state the moment the previous run ends." The shop reads it; the dive consumes it via `seed_override`. This is a small, clean inversion of `_next_seed()`'s call site and a strong run/meta-boundary fit: the *seed* is meta (it survives until consumed), the *band* stays run-state (regenerated on entry, never persisted).
2. **Intel products = headless generator queries.** Buy → generate `(next_seed, config)` once off-screen → extract the tier's payload (graph silhouette / hazard manifest / top-EV room) → store the payload as meta, free the band. On dive entry the band regenerates identically (same seed) and the intel is *truthful by construction*.
3. **Knowledge as the free/discount path (GDD tie-in).** The GDD makes **Knowledge** "the master key … safe routes" (`Junkyard_GDD.md:120,126`, "Knowledge unlocks … safe routes"). So: **Money buys intel per-run** (a recurring sink, you re-pay every dive); **Knowledge buys a *standing* intel capability** (once you understand the band, partial maps are free or hazard forecasts always-on). Money is the faucet you bleed every run; Knowledge is the permanent upgrade that retires that bleed — classic cross-feed, and it makes the Knowledge track feel like literal de-fogging of the world.
4. **The extraction-decision hook.** Intel changes the *go/no-go and how-deep* calculus, not just routing. A bad hazard forecast → buy a cheaper run, or skip. A high-value-room tip deep in the band → a deliberate "push past the safe extraction" gamble. Intel should make players go *deeper on purpose*, which is the EV the sink is paying for.
5. **RunConfig knob + telemetry.** Add `intel_enabled` (default off = today's blind dive = the permanent control) plus per-tier toggles, mirroring the R1–R4 master-toggle pattern in `run_config.gd`. Telemetry: `intel_bought {tier, currency, seed}`, and the load-bearing causal question — **did intel change behaviour?** Compare routing entropy, deepest-depth-reached, and death-cause for intel vs. blind runs on the *same seed distribution*. If routing doesn't change, the intel is decorative.

## Research (cited)
- **Darkest Dungeon — Scouting**: entering a room has a chance to reveal nearby rooms/corridors and *their contents*, making traversal "less risky" — the canonical "reveal de-risks the next step" loop, there earned in-dungeon rather than bought ([wiki](https://darkestdungeon.wiki.gg/wiki/Scouting)). DD's purchasable **Dungeon Map** provisioning item reveals the whole layout up front — the literal "pay money for a map" precedent ([Dungeon Map](https://darkestdungeon.fandom.com/wiki/Dungeon_Map)).
- **Escape from Tarkov — intel items**: maps/intel are *items you carry into a raid* that mark loot and key locations — information as a consumable, lootable, tradeable good ([Rogue intel maps](https://escapefromtarkov.fandom.com/wiki/Rogue_intel_maps)). Direct prior art for "information as currency" in an extraction shooter, the closest genre cousin.
- **Slay the Spire — map preview**: the act map is fully visible up front (one act at a time) so the player *plans a path through known node types* — information given free, and the entire act's tension lives in routing it ([Map Generation](https://slaythespire.wiki.gg/wiki/Map_Generation)). The cautionary data point: full, free map knowledge is *fun* in StS precisely because the danger is still real — argues intel need not trivialize tension if you reveal *shape*, not *outcome*.
- **FTL beacons / Loop Hero**: FTL's jump map shows beacon *types* but not contents — partial, free intel that drives route choice under fog; Loop Hero's loop is *built* by the player, an extreme of self-authored intel. Both reinforce: reveal enough to plan, not enough to remove the gamble.

Cross-genre synthesis: the live design space is the **reveal granularity** axis — shape (StS) ⊂ contents (DD scout) ⊂ exact high-value pin (Tarkov). Our three tiers sit on exactly that axis, and pricing them separately lets the economy meter how much certainty a player will pay for.

## Open questions
- **Seed-reveal architecture (needs a programmer's eye).** Pinning the next seed at the surface is small but touches the run/meta boundary and `_next_seed()`. Does the pinned seed persist across a *quit between runs* (it should, or intel you bought evaporates)? Bump `schema_version` for a `next_run_seed` meta field? Flag to programmer.
- **Does intel trivialize the dive's tension?** The StS evidence says revealing *shape* is safe but revealing the *exact best room* may flatten exploration into a beeline. Recommendation: gate the precise tip behind Knowledge or a steep price so it's a rare splurge, not the default. **Needs Director fun-gate judgment** — only a playtest tells us where reveal stops being interesting.
- **Overlap with the Knowledge meta-system.** If Knowledge already "unlocks safe routes," is *paid* intel redundant once Knowledge is high — does the money sink die in the late game? Possible resolution: Money intel stays relevant for *fresh/deeper* bands your Knowledge hasn't yet covered (you always out-dive your understanding). **Director call** on whether that's the intended late-game economy shape.
- **Truthfulness vs. unreliable intel.** Should bought intel ever *lie* (cheap-but-noisy forecast vs. expensive-and-exact)? Unreliable intel restores tension and adds a price-tier axis, but contradicts the seeded "truthful by construction" simplicity. Flag for Director — a tone/fun call (is a lying fence on-brand?).
- **Is intel per-band or per-run?** If a band is re-dived on the same seed, is the intel still valid / already spent? Interacts with whether seeds are one-shot or persistent.

Sources:
- [Darkest Dungeon — Scouting](https://darkestdungeon.wiki.gg/wiki/Scouting)
- [Darkest Dungeon — Dungeon Map](https://darkestdungeon.fandom.com/wiki/Dungeon_Map)
- [Escape from Tarkov — Rogue intel maps](https://escapefromtarkov.fandom.com/wiki/Rogue_intel_maps)
- [Slay the Spire — Map Generation](https://slaythespire.wiki.gg/wiki/Map_Generation)
