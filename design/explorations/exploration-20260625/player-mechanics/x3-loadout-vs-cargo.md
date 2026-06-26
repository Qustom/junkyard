# Loadout vs. Cargo Distinction
**Category:** Tradeoff systems (extraction-binding)

## The mechanic
Split the carried bag into two zones with different rules. A small **loadout** of
quick-access slots holds *tools I'm using* — items throwable instantly. A larger
**cargo** hold is *loot I'm protecting* — it cannot throw without a **repack**
(move a cargo item into a loadout slot first). The separation makes inventory
layout a *tactical commitment*: every slot you reserve for a throwable battery is
a slot not banking a reactor core. The throw verb stops being free over your
whole bag and becomes a layout decision made *before* the fight, then paid for
under pressure if you guessed wrong.

## What exists today
Honest read: the inventory is **one undifferentiated zone, and everything in it is
throwable.** `run_inventory.gd` is a flat count-based model — `items: Array[JunkItem]`,
capacity by `used_slots()` vs `max_slots`, no positions, no zones (its doc:
"carry-choice tension comes from value-vs-space, not from spatial packing"). The
L1 throw does `remove_at(highlighted_index)` on a selector that defaults to slot 0
and clamps over the *whole* array (`L1_throwing_mechanic.md`) — so the most
valuable extraction loot is as throwable as a rock. There is no concept of a
protected hold. This mechanic **adds a zone partition** to that flat array. It is a
smaller change than `i2`'s spatial rework: zones are still count-based, just two
buckets with one rule difference (loadout = throwable, cargo = not). It needs
`i2`-style repack only as the *cargo→loadout* move, not full tetris. What's
missing: the zone field, a quick-slot selector bound to loadout (not the whole
bag), and a repack action.

## How to fit it in
Extend `RunInventory` with a `loadout: Array[JunkItem]` (size N, e.g. 3) beside the
existing `items` (cargo). The L1 throw selector iterates **loadout only**;
`remove_at` over cargo is never a throw. **Repack** = a discrete action moving one
cargo item into a free loadout slot (the `i2` "diegetic act under threat"), so a
mid-fight "I need to throw that" costs time while the dive clock and pursuer keep
running. This binds to **carry-load (`x1`)**: loadout slots could be capped
separately, so committing throwables eats into protectable haul. Control: quick-slot
select reuses L1's highlight, scoped to loadout; `Tab`/scroll cycles loadout, a
repack key promotes the focused cargo item. RunConfig knob
`loadout_zones_enabled` (default **off** = today's one-zone, everything-throwable
baseline, the permanent control). Telemetry: `repack_under_threat` count,
`throw_blocked_cargo` (tried to throw with empty loadout), loadout-occupancy at
extract.

## Research (cited)
Tarkov splits **rig** (chest, fast-access ammo/meds/grenades) from **backpack**
(bulk loot, slower); you can even drop the backpack to move faster — loadout stays,
cargo is sheddable. Resident Evil's belt-vs-case and Don't Starve's **hand/body
equip slots vs the 15-slot pack** (backpack shares the armor slot — a real
opportunity cost) encode the same "ready vs stored" split. Minecraft's **hotbar
vs inventory** is the purest form: only the 9 hotbar slots are usable in-hand, the
27 below are dead storage until you move an item up. All four prove the pattern:
a *small fast zone* + a *large protected zone* + a *move cost between them*.

## Graybox sketch
3 loadout slots above the existing cargo grid. Only loadout items show the L1 throw
highlight; throwing pulls from loadout. A `repack` key moves the focused cargo
item into the first free loadout slot (instant for graybox; timed later). Empty
loadout → throw is a no-op with a "no throwable ready" flash.

## Open questions
- **N loadout slots?** 2 feels tight/tactical; 4 erodes the distinction. Flag for
  the Director (fun call).
- **Auto-promote on pickup?** If a thrown-type item auto-fills a free loadout slot,
  the player rarely repacks — convenient but kills the tension. Manual-only is
  purer but fiddly.
- **Does this over-complicate the bag?** L1 just shipped a single-zone selector;
  adding zones + repack is real UI/cognitive load mid-fight. Worth gating behind
  the RunConfig knob and playtesting one-zone vs two-zone head-to-head.
- **Interaction with `i2`:** if cargo later goes spatial, repack becomes spatial
  too — keep the zone rule independent of the packing model so they compose.

Sources:
- [Better storage for rigs/backpacks — EFT Forum](https://forum.escapefromtarkov.com/topic/67221-better-storage-for-rigsbackpacks/)
- [EFT Smart Inventory Management Guide](https://www.eyeonannapolis.net/2025/10/escape-from-tarkov-smart-inventory-management-guide/)
- [Don't Starve Inventory — Fandom Wiki](https://dontstarve.fandom.com/wiki/Inventory)
- [Don't Starve Backpack — Wiki](https://dontstarve.wiki.gg/wiki/Backpack/DST)
- [Inventory Case Study: Minecraft](https://thevideogamediaries.wordpress.com/2017/10/28/inventory-case-study-1-minecraft/)
- [Saved Hotbars — Minecraft Wiki](https://minecraft.wiki/w/Saved_Hotbars)
