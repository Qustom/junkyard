# Swap-in-Place
**Category:** Inventory as an active system

## The mechanic
Walk over a floor item, hold the grab key, and pick it up by **trading it for a chosen item already in your bag** — no free slot required. The dropped item lands where the floor item was. Instead of the "bag full → open menu → drop something → walk back → grab" juggle, you make one decision (this-for-that) in a single press. Under a ~300s dive clock (`systems/dive_clock.gd`), that's the difference between a fluid late-dive upgrade pass and a fumbling inventory minigame while instability rises.

## What exists today
The pickup flow is binary accept/reject. `junk_pickup.gd._try_pickup()` calls `RunInventory.try_add(item)`; on `false` (bag full / no fit) the junk **stays in the world and flashes red** (`_flash_rejected`). There is no swap path — a full bag is a hard wall. To make room you'd drop via the D2 UI, which is slow mid-combat.

The **shape problem is smaller than it looks here**, because M1 is the **count-based model**, not spatial. `RunInventory.can_accept()` only checks `item.slot_size <= free_slots()`; `grid_footprint` on `JunkItem` is explicitly "advisory in M1." So swapping a 1-slot for a 2-slot isn't a Tetris repack — it's pure arithmetic: a swap is legal iff `free_slots() - incoming.slot_size + outgoing.slot_size >= 0`. Swapping a 2x2 (slot_size 2) for a 1x1 (slot_size 1) is *always* legal and even frees a slot; the only tricky case is incoming-bigger-than-outgoing, which is just the same capacity check on the net delta.

What's missing: a `try_swap(incoming, outgoing_index)` on `RunInventory`, a way to *choose* which carried item to sacrifice, and the UX to know whether the trade is worth it.

## How to fit it in
- **Trigger:** a long-press of the grab key (short press = normal grab; if the short grab would be rejected, the prompt upgrades to "Hold to swap"). Avoids a new binding; reuses the L4 grab-prompt surface.
- **Choosing the victim:** simplest = auto-target the **lowest `value_per_slot()`** carried item (already a helper on `JunkItem`) and show "Swap X for Y?". A richer version pauses into the D2 grid to pick. Recommend auto-target for the graybox — it keeps the loot loop in the world, not in a menu.
- **Shape:** add `try_swap()` doing the net-delta capacity check above. No repack needed in the count model. If/when spatial lands post-M1, swap falls back to "remove victim, then attempt place" and aborts (re-adding the victim) if it doesn't fit.
- **Value clarity:** the prompt shows both items' `base_sell_value` and `value_per_slot()`, with a green ▲ / red ▼ on the net Money delta so a hold is a confident "yes, upgrade."
- **Knob + telemetry:** `RunConfig.swap_in_place_enabled` (default **off** → reproduces today's hard-wall baseline). Emit a config-marked `EventBus.junk_swapped(in_id, out_id, value_delta, slots_free_after)`; compare swaps-per-dive, value-banked, and time-in-inventory-UI against the baseline at the gate.

## Research (cited)
Prior art clusters into two philosophies. **Quick-swap on pickup** — Halo's two-weapon carry replaces the held weapon instantly on grab, with a HUD prompt; Bungie's own retro on the Halo HUD notes the swap message was the worst clutter offender and they fought to make it "read quicker," a caution for our value-comparison prompt — keep it to one glanceable line. **Single-item carry** (Spelunky) makes pickup *implicitly* a swap by limiting hands to one item; clean but only because carry size is 1. **Full-bag swap menus** — Resident Evil 4 lets you swap an unwanted item when the case is full, but it's a deliberate *paused* grid puzzle, the opposite of our time-pressure goal. The lesson: swap-in-place wins fluidity only if the victim-choice and value-judgment happen *without* a menu pause — favor auto-target + a one-line delta over RE4's open-the-case flow.

## Graybox sketch
Hardcode `swap_in_place_enabled = true`. On a rejected grab, long-press swaps in the floor item against the bag's lowest `value_per_slot()` item, drops that item as a new `JunkPickup` at the floor position, and shows a two-line "−Y +X (▲+30)" toast. Ship one over-capacity test junk so testers hit a full bag fast. Question to feel: does trading *without* opening the bag feel powerful, or anxiety-inducing because you can't see the whole bag?

## Open questions
- **Victim selection:** auto-target lowest value-per-slot (fast, in-world) vs. menu-pick (precise, breaks flow). Lean auto, but the Director should rule on whether silent auto-discard of a carried item feels like a betrayal.
- **Value clarity:** is a one-line ▲/▼ delta enough, or do players need the full bag visible before committing? (Halo's clutter warning vs. RE4's full view.)
- **Dropped-item fate:** does the swapped-out item persist as grabbable floor junk (re-grabbable, no value lost) or vanish (cleaner, but punishing)?
- **Bigger-incoming case:** if the lowest-value item still can't free enough slots, do we auto-escalate to sacrificing two items, or just fall back to the red-flash reject?

**Sources:**
- [Spelunky 2 — Pick Up, Drop, Use, Throw (Attack of the Fanboy)](https://attackofthefanboy.com/guides/spelunky-2-how-to-pick-up-drop-use-and-throw-items/)
- [Halo 3 HUD Spec — David Candland](http://www.cand.land/halohud)
- [How Resident Evil 4 Perfected the Inventory System (Bloody Disgusting)](https://bloody-disgusting.com/video-games/3658221/resident-evil-4-perfected-inventory-system-resident-evil-25/)
- [Item Management — Resident Evil Wiki](https://residentevil.fandom.com/wiki/Item_Management)
