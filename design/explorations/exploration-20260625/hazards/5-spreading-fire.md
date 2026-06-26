# Spreading Fire
**Category:** Time-pressure / extraction-specific

## The idea
A fire (or corrosive bloom, or "rot") that **spreads cell-to-cell across the floor over time**, and — the hook — **destroys loot it reaches**. Junk that catches fire is gone: its value burns before you can grab it. The player who lingers to clear a room watches the back half of the haul turn to ash.

**Behavioral distinctness:** it makes **greed cost you directly and visibly**. Other time pressures threaten *you*; this threatens *the haul*. The decision becomes "grab the burning-soon items first and abandon the rest" — a real-time value-prioritization puzzle where the optimal grab order is dictated by the fire front, not by item value alone. It punishes the completionist instinct (clear the whole room) that the loot loop otherwise encourages, and it does so without a single number on screen.

## How it fits THE FAR YARD
This is the **most distinct** of the four from the ~300s `dive_clock`, because its stakes are *the loot*, not the run. The countdown ends your dive; the fire **shrinks the prize while you're still in the dive**. That is a different lever on the same GDD pillar 1 ("push or cash out") and pillar 4 ("money is a problem") — and it makes the B3 depth-scaled value of deep junk *literally perishable*, sharpening the push-vs-extract math: the richer the room, the more there is to lose to the flames.

Verbs: LOOT becomes a triage race (grab high-value-soon-burning first); MOVE is pathing around/through the spreading front; THROW (L1) gains a *new use* — see synergies. EXTRACT is indirectly pressured: a fire between you and the gate forces a route choice. It realizes the GDD's "entities multiply, the terrain shifts" instability flavor as a loot-economy threat rather than a body threat.

**Band depth:** first at **Band 2** (slow spread, mostly a "don't dawdle" nudge), escalating spread-rate with `Instability` so deep bands have aggressive blooms that can eat a whole room's haul if mishandled.

## Graybox sketch
- Floor as a coarse cell grid (reuse B1/B2 `Vector2i` cell space). A `burning: Set[Vector2i]` front; each tick, ignite orthogonal neighbors after `spread_interval_s` (a `RunConfig` knob; off by default → baseline parity).
- A `JunkPickup` whose cell is `burning` for > `burn_to_destroy_s` → `queue_free` + emit `junk_burned(item_id, value_lost, depth)` (telemetry for RG-style analysis of how much haul players lose).
- Player standing in a burning cell takes a damage tick (or non-lethal, L5-toggle style).
- No art: red cells, orange junk-about-to-burn flash, then gone. Proves the "grab-order-under-pressure" loop.

## Synergies & counters
- **Throw verb (L1):** strong synergy — let the player **throw an item to a safe cell** to rescue it from the front (toss the engine block out of the fire's path), or eventually throw a "damp/ward" consumable to *snuff* a few cells (a Salvage/Gear sink, GDD §7). This turns a pure punisher into a skill expression.
- **Rising Tide:** fire + tide could *interact* (water snuffs fire) — emergent, probably too complex for graybox; note for later.
- **Counter:** loot the fire-side of the room first; sacrifice low-value junk; carry a snuffer. The fire's spread is deterministic, so it's *learnable*.

## Open questions
- **Does this double up with the countdown?** Least of the four — it threatens loot, not run-time. The risk is the *opposite*: it might feel like it *replaces* the loot-grabbing fun with frustration ("I never get the whole room"). Tune spread slow enough that a smart player keeps ~most of the haul. **Director fun-call: is losing loot to fire satisfying-tense or just annoying?**
- Destroying loot the player can *see but not save* may feel unfair on first contact. Telegraph hard (cells smolder before igniting; junk flashes before burning). Needs the graybox to find the fairness line.
- Spread that can wall off the gate route risks accidental soft-locks. Cap total burnable area, or make fire never block the only path to extraction. **Scope/safety call.**
- Does fire spread between rooms (through doorways) or stay room-local like K5 hazards? Room-local is simpler and more legible. Recommend room-local for graybox.
