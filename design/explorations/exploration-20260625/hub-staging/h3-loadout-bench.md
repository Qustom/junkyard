# A Loadout Bench
**Category:** The hub as the money sink made physical

## The idea
A **place** in the surface hub — a greasy workbench by the portal door — where you
pre-pack the run before you dive. It is where every inventory mechanic that is "too
slow to do mid-run" finally has room to **breathe**: lay out the grid, rotate the
awkward pieces (`i1`), tetris them flat (`i2`), reserve your quick-throw loadout
slots (`x3`), drop your protected item into a shape-pocket, and pack the consumables
you bought (`s2`). The key insight: the dive is the **live test under the clock**;
the bench is the **calm rehearsal** with no clock at all. Mid-run there is no time to
fiddle — so the fiddling moves here, on purpose. The bench is the safe pole of the
pause-vs-real-time tension that `i2` deliberately left unresolved: deliberate planning
happens *here*, safely; the run is where your plan meets the Hunter.

## What exists today
Honest read: the **model exists, the between-run editing screen does not.**
`run_inventory.gd` is a flat count-based bag (`items: Array[JunkItem]`,
`used_slots()` vs `max_slots`) — and crucially it is **run-state**: built fresh in
`start_run()`, wiped at run end (`clear_run()`), never banked. `D2_inventory_ui.md`
is a live **HUD projection**, not an editor. There is **no hub scene** and **no
pre-run loadout surface** at all today.

This is the gap the bench fills, and it forces a real design call: a between-run
loadout *implies a persistent pre-pack* — items you choose to carry in *before* the
run starts. That can't live in the volatile `RunInventory`; the bench must read/write
a small **meta-state "packed loadout"** (the protected item, reserved quick-slots,
bought consumables) that `start_run()` then **seeds** into the fresh `RunInventory`.
That seam is the missing piece, and it cleanly resolves `i2`'s open question: the bench
is the **safe deliberate pause** (no clock), so the live overlay can stay tense.

## How it could fit in
A greybox **bench room** in the hub scene, entered pre-departure (the last thing
before the portal). It hosts the **full inventory-edit UI** that the HUD can't be:
rotate (`i1`), repack/tetris (`i2`) with **zero time pressure**, assign the `x3`
quick-throw loadout slots, slot the protected item into its shape-pocket, and load the
`s2` consumables. On "dive," the packed loadout seeds the run. Gate the whole room and
each capability behind `RunConfig` flags (`loadout_bench_enabled`, plus per-feature
`bench_rotate`, `bench_quick_slots`, `bench_protected_pocket`) so all-off reproduces
today's no-bench, count-model baseline — the standing control.

## Research (cited)
The **safe-prep / live-management split** is genre-standard. **Monster Hunter**'s
Item Box lets you restock, craft, and **save named item loadouts** before a quest —
prep is calm and repeatable, the hunt is not
([Gamer Guides](https://www.gamerguides.com/monster-hunter-generations/guide/facilities-and-places/your-house/item-box),
[TheGamer](https://www.thegamer.com/before-quest-preparation-monster-hunter-rise/)).
**Deep Rock Galactic**'s Equipment Terminal sets weapons + tools + a throwable and
stores **presets** ([DRG Wiki](https://deeprockgalactic.wiki.gg/wiki/Equipment)).
**Tarkov** is both the model and the warning: keeping **ready kits** pre-staged and
loading mags *before* a raid cuts prep time and lets you "jump in without fumbling" —
but its in-raid grid Tetris is the thing players resent ("stash Tetris instead of
raids")
([Eye On Annapolis](https://www.eyeonannapolis.net/2025/10/escape-from-tarkov-smart-inventory-management-guide/),
[Z2U presets guide](https://www.z2u.com/detail/how-to-save-and-use-gear-presets-in-escape-from-tarkov.html)).
The lesson for us: **move the Tetris to the bench**, keep the dive's live management
small and snappy (`i2`).

## Open questions
- **[DIRECTOR — fun/scope] How much inventory depth gates to the bench vs stays
  mid-run?** Cleanest split: deep packing (rotate, full tetris, protected-pocket) is
  **bench-only**; mid-run is fast value-vs-space + quick-throw only. Risk: too much
  at the bench makes the dive's inventory feel inert. **Recommendation:** bench owns
  layout, dive owns *consequences* — playtest the seam.
- **[DIRECTOR — fun] Protected-item pocket UX.** A dedicated shape-pocket (drag the
  one item you most want to keep) vs a flag on a normally-packed item. The pocket is
  more legible and ties to the secure-container fantasy; flagging is lighter.
- **Default auto-pack?** A "repeat last loadout" / auto-fill button removes tedium but
  erodes the deliberate-choice fantasy the bench exists to create. Lean **auto-pack
  available, off by default**; knob it and watch usage telemetry.
- **Where exactly pre-departure, and is it skippable?** Forcing the bench every run
  risks friction; making it skippable risks players never engaging the mechanics it
  justifies. Flag for the Director.
```
