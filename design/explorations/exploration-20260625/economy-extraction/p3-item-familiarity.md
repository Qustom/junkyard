# Item Familiarity
**Category:** Run-to-run persistence

## The mechanic
A junk type you have **handled and sold before** reads *faster and fuller* the next time you see it. The first time you find a Resonant Coil, the ground/inventory read is **partial** — you see a rough silhouette and a value *band* ("worth somethingish") but not the exact figure. After you cash it out a few times, that type becomes **familiar**: its full value and shape resolve instantly, on the ground and at the counter. Familiarity is a **persistent, earned resource** — a per-item-type "I know what this is" that survives death and accrues across runs. It is the player's *appraisal skill*, made diegetic: you learn the Yard's catalogue by working it, and a veteran salvager reads a cluttered floor at a glance precisely because they've sold it all before.

## What exists today
Today junk is **always fully legible**. `JunkItem` (`data/junk/junk_item.gd`) exposes `base_sell_value`, `greybox_color`, `greybox_shape`, `tier`, and `value_per_slot()` as plain data; nothing gates or fogs them, and the F2 sell screen (`design/M1_Tasks/F2_sell_screen.md`) shows exact Money on every item. The readable-junk study (`design/research/03_readable_junk_study.md`) is entirely about making value/rarity/band legible *at a glance* — it assumes full legibility is the *goal*, never that legibility could be **earned**. So the partial→full reveal is the missing layer: a "first-contact" state that resolves with experience.

The GDD's **Knowledge** track is exactly this kind of persistent information resource — "fragments decoded from anomalous finds … the master key" that "unlocks deeper bands … safe routes" (`Junkyard_GDD.md:120,126`). Item familiarity is **Knowledge at the item granularity**: where map intel (`s4-map-intel.md`) de-fogs the *band*, familiarity de-fogs the *catalogue*. Both are information economies; this one is paid in repetition rather than cash.

What's missing concretely: a **familiarity set in meta-state** and a reveal function. `GameState` already persists `unlocked_recipes: Array[StringName]` (`systems/game_state.gd:38`) — the identical pattern fits: a `familiar_items: Dictionary` (id → handled-count) saved via `SaveManager`, bumped at cash-out.

## How to fit it in
1. **Meta-state set.** Add `familiar_items: Dictionary` (StringName id → int sale-count) to `GameState`, persisted like `unlocked_recipes`; bump `schema_version` + migration. Increment on cash-out (the moment the item leaves your hands for Money).
2. **Partial → full reveal.** A `familiarity_of(id)` helper returns a 0..1 tier from the count (e.g. 0 sales = silhouette + value-*range*; 1–2 = approximate value; 3+ = exact value + crisp shape). The ground read (study 03's silhouette/beam/label) and the F2 sell card both query it. Unfamiliar = blurred shape, value shown as a band; familiar = today's exact read.
3. **Knowledge cross-feed (GDD tie).** Spending **Lore/Knowledge** can *buy* familiarity wholesale — an "appraisal manual" that marks a whole band's catalogue familiar without grinding it, mirroring map intel's "Knowledge retires the cash bleed" pattern. Repetition is the free path; Knowledge is the shortcut.
4. **Sell-loop + market interaction.** Unfamiliar items create real **mis-sell risk** if combined with the fluctuating-prices mechanic (m1): you can't tell a price spike on a junk you can't appraise, so you sell blind and sometimes leave Money on the table. Familiarity converts the floor from "grab everything, sort later" into "I know this is the valuable one."
5. **RunConfig knob + telemetry.** `familiarity_enabled` (default **off** = today's always-legible read = permanent control), mirroring `r1_enabled` (`data/run_config/run_config.gd:59`). Telemetry: `familiarity_gained {id, new_count}`, distribution of familiar-vs-unfamiliar items carried, and **mis-sells of unknowns** (sold an unfamiliar item below a later-revealed better price) to measure whether the fog actually changes behaviour.

## Research (cited)
- **NetHack / DCSS identification.** NetHack makes ID a core risk-mystery loop — an unidentified scroll might be Genocide or Punishment ([NetHack Wiki](https://nethackwiki.com/wiki/Identification)). DCSS deliberately *defangs* it for accessibility; veterans "waste one of each in a quiet corner" ([DCSS AI paper](https://arxiv.org/pdf/1902.01769)). The cautionary lesson critics raise: per-*run* re-randomized ID is busywork ([Golden Krone Hotel — "Things I Hate About Roguelikes: Identification"](https://www.goldenkronehotel.com/wp/2017/06/25/things-i-hate-about-roguelikes-part-2-identification/)). **Our twist dodges that complaint by making familiarity *persistent*** — you learn the catalogue *once, forever*, not re-roll it each run, so the knowledge is progress, not a tax.
- **Moonlighter appraisal.** Prices start hidden; you read **customer-reaction feedback** and the game **records the discovered price in the item book** so it's easier next time ([Moonlighter Wiki — Selling and Reactions](https://moonlighter.fandom.com/wiki/Selling_and_Reactions)). That book *is* a familiarity set — direct prior art for "sell it, learn it, it's legible thereafter."
- **Recettear pricing.** Value-by-feedback against a hidden ideal price, learned through repetition ([Recettear Wiki — Pricing Mechanics](https://recettear.fandom.com/wiki/Pricing_Mechanics)) — the merchant-sim ancestor of learned appraisal.

Synthesis: take roguelike ID's *mystery on first contact* but resolve it the **Moonlighter way (persistent, recorded)** rather than the NetHack way (per-run re-randomized), so the result is Knowledge-as-progress, not a per-run chore.

## Open questions
- **Tension vs. annoyance.** Hidden value on first contact adds an appraisal arc, but a too-opaque early read could feel like the game *withholding* basic info. How partial is the early reveal — value *band* (recommended) vs. total blank? **Director fun-gate call** — only a playtest tells us where mystery turns into friction.
- **Overlap with the Knowledge system.** Is item familiarity a *facet of* the Knowledge track or a parallel resource? Recommendation: a facet — familiarity accrues free from play, and **Knowledge buys it wholesale** (per "How to fit it" #3), keeping one master information meta rather than two. **Director call** on whether that muddies the four-track model.
- **Grind feel.** Does requiring N sales per type feel like a checklist? Mitigation: low N (familiar by ~3 sales) and the Knowledge shortcut. Flag whether familiarity should be *type-wide* (any Coil) or finer.
- **Does it change behaviour, or just decorate?** If players grab everything regardless, the fog is cosmetic. The mis-sell telemetry is the test; if it's flat, cut it. **Needs the same causal check as map intel.**

Sources:
- [NetHack Wiki — Identification](https://nethackwiki.com/wiki/Identification)
- [Golden Krone Hotel — Things I Hate About Roguelikes: Identification](https://www.goldenkronehotel.com/wp/2017/06/25/things-i-hate-about-roguelikes-part-2-identification/)
- [DCSS as an AI Evaluation Domain (identification discussion)](https://arxiv.org/pdf/1902.01769)
- [Moonlighter Wiki — Selling and Reactions](https://moonlighter.fandom.com/wiki/Selling_and_Reactions)
- [Recettear Wiki — Pricing Mechanics](https://recettear.fandom.com/wiki/Pricing_Mechanics)
