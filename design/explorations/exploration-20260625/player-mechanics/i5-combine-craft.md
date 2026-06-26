# Combine / Craft
**Category:** Inventory as an active system

## The mechanic
Merge two carried items into one. The merge resolves to a *smaller* result (a **space
win** — two bulky parts become one compact assembly) and/or a result with a **new
effect** (a **power win** — two inert parts become a usable tool/consumable). This
gives the shape system (`JunkItem.slot_size`, `RunInventory.used_slots()`) a second
job beyond the existing value-vs-space carry decision: a piece is now either an
**ingredient** (worth slots only as input) or a **finished good** (worth slots for
its sell value or effect). The same 12-slot bag now holds two *classes* of object,
and the player decides mid-dive whether to spend space speculatively (carry
ingredients) or bank it (carry finished goods).

## What exists today
The GDD **already has a craft path**: repair/fixing is **recipe-based** meta-state
(GDD §"Repair / fixing", §11), recipes are *acquired* (bought, found, Lore-unlocked),
and fixing "consumes the broken item plus required components/Salvage to produce the
fixed, higher-value good" — explicitly **not a tactile minigame**, with depth in
*what* you can make. Knowledge gates new craft branches (GDD §5, §12). So a surface
crafting system is canon-in-design but **not yet built**.

What `run_inventory.gd` has today: flat count-based slots, no stacking, items are
**shared catalog refs** (no per-instance state — the file flags the eventual switch
to duplicated per-instance items as "a localized change"). `JunkItem` carries
`tier`, `base_sell_value`, `slot_size`, `containment_flags`. **Missing:** any recipe
Resource, any combine action, per-instance item state, and a craft UI. This mechanic
must *reconcile* with the planned recipe system rather than invent a parallel one.

## How to fit it in
**The key fork — WHERE crafting happens:**
- **In-dive ad-hoc combine** — costs **dive-clock time** (`dive_clock.gd`, ~300s
  light budget) per merge and is **risky** (you're standing still while threats
  close). Pays off as the space win: compress a full bag to extract more.
- **Surface crafting** — the GDD's recipe system: safe, deliberate, meta-state,
  consumes banked junk + Salvage, gated by Knowledge.

Recommendation: **make in-dive combine a strict subset of the recipe system, not a
rival.** A `CraftRecipe.tres` (inputs: ids/tiers/counts → output id + result
`slot_size`/`base_sell_value`/effect) is the single source of truth. A recipe flagged
`in_dive_allowed` can be executed in the bag (clock cost) **only if its recipe is
known**; everything else is surface-only. This keeps one data spine, makes Knowledge
the universal gate, and lets in-dive combine be the *fast, costly* face of the same
content.

**Shape interaction:** in-dive merge requires the result `slot_size <= sum(inputs)`
(it must at least not grow), so combine is always a defensible carry decision.
**Per-instance state:** finished goods may need instance fields → reuse the planned
`JunkItem` instance switch. **Control mapping:** hold a "combine" modifier + click two
slots; valid pairs highlight (reuse `run_inventory_changed` + a new
`EventBus.run_item_combined(out_id, clock_cost)`).

**RunConfig knob + telemetry:** `i5_combine_enabled=false` (all-off = today's baseline),
`i5_in_dive_clock_cost`, `i5_require_known_recipe`. Telemetry: combines/run, clock
spent on combining, space recovered, in-dive vs surface split — config-marked.

## Research (cited)
- **Vampire Survivors evolutions/Unions** — the proven "merge two things, free a slot"
  loop: a Union "combines two weapons... emptying a weapon slot," and evolution
  *removes* the base and adds a stronger result. Validates both the space win and the
  power win, and the "you must *know*/meet conditions" gate. ([Vampire Survivors Wiki](https://vampire.survivors.wiki/w/Evolution), [Fandom](https://vampire-survivors.fandom.com/wiki/Evolution))
- **Brotato combine / Loop Hero / Don't Starve** — in-run merging and on-the-fly
  recipe crafting as a moment-to-moment decision rather than a menu.
- **Escape from Tarkov hideout** — the meta counterpart: crafting is a *second
  character sheet* done in safety, gated by built modules, where outputs gain status
  ("found in raid"). The clean separation of **safe-meta craft** vs **risky in-run
  action** is exactly our fork. ([EFT Wiki Hideout](https://escapefromtarkov.fandom.com/wiki/Hideout), [Crafts](https://escapefromtarkov.fandom.com/wiki/Crafts))

## Graybox sketch
One known in-dive recipe: **2× tier-1 scrap (slot_size 1 each) → 1× "scrap brick"
(slot_size 1, higher value/slot)**. Hold modifier, click two scrap slots; a 1.5s
clock-cost merge fires `run_item_combined`. Proof point: in a near-full bag with one
free slot, does the player *combine to make room for a better find*, or *cash out as
is*? If that single choice shows up in playtest, combine earns its keep.

## Open questions
- **[FLAG: Director] In-dive vs surface fork.** Ship in-dive combine at all in the
  first iteration, or prove **surface recipe crafting** (already GDD-canon) *first*
  and add in-dive as a later power-up? Risk: two craft surfaces dilute the message.
- **[FLAG: Director] Overlap with the existing recipe system.** Confirm combine is a
  *subset* of recipes (one data spine) vs a distinct ad-hoc "any two compatibles
  merge" system. The former is cleaner; the latter is more discovery-driven (matches
  GDD "curiosity is a stat") but harder to balance.
- Does in-dive combine demand per-instance item state now, or can M1 stay shared-ref
  with stateless outputs?
- Is the clock cost the right risk lever, or should combining draw Exposure instead?
- Knowledge gate granularity: per-recipe unlock vs branch unlock?
