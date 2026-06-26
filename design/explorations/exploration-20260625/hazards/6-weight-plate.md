# Weight Plate
**Category:** Inventory & throw-synergy

## The idea
A floor trigger that **only fires when your inventory is full or heavy** — a pressure plate calibrated to *greed*. Walk across it light and nothing happens; walk across it with a fat haul and it springs (a gate slams, spikes rise, a pursuer wakes, the floor drops). The behavioral distinctness: it makes the *state of your bag* a movement constraint. It is the first hazard that reads `run_haul_value()` / slot-fill as its trigger condition, so the player's own loot becomes the thing that endangers them. The skill/decision it forces is sharp and pure: **drop or throw items to get under the weight**, cross safely, then re-grab — or find another route. It weaponizes the throw verb as a *traversal* tool (throw your haul across the plate, walk light, pick it up on the far side) and makes inventory management a literal physical gate.

## How it fits THE FAR YARD
It turns the slot inventory (`run_inventory.items.size()` / `run_haul_value()`) into a traversal variable, the most direct possible coupling of inventory to the world. It reuses the existing **drop-to-swap** path (`EventBus.junk_dropped` re-spawn) and the L1 throw — you can *throw* items across the plate to the far side and walk over light, then collect them, a satisfying use of mouse-aim that the player discovers themselves. It pressures **extraction** hard: late in a dive when you're heaviest is exactly when plates are most dangerous, so the deep-and-greedy run is the punished one — perfectly on-theme with push-your-luck. First appears **Band 3 (Lateral)** as a "your wealth is a liability" beat that rhymes with the surface Exposure system (visible wealth = danger, GDD §9) — the dive-layer echo of the life-sim's central tension.

## Graybox sketch
A floor rectangle (distinct color). On player-body enter, it checks `slots_used >= full_threshold` (or `haul_value >= heavy_threshold`): below → inert; at/above → FIRE (a wall-gate drops, or spikes raise, or a `dive_clock` penalty, or a pursuer spawns). No art: the plate tints "armed red" when the player approaching it is over-weight, telegraphing the trigger so it's a readable decision, not a gotcha.

## Synergies & counters
**Synergy with the throw verb (core hook):** throw your haul across the plate, walk light, re-collect — turning a wall into a juggling puzzle. **Synergy with the thief:** a thief that *lightens* your bag could let you cross a plate you couldn't before — emergent, possibly desirable. **Synergy with extraction routing:** a plate between you and the gate forces a drop-cross-regrab ritual under the clock. Counter: drop/throw to get under threshold; route around; or extract before you're heavy enough to trip it.

## Open questions
- **Trigger on slot-count or on haul-value?** Slot-count is legible (you can see the bag); value is thematically richer ("greed plate") but invisible to the player without UI. Recommend slot-count for graybox legibility, value as a later variant with a HUD tell. *Director call.*
- **Telegraph the armed state, or make it a discovery hazard?** Recommend telegraphed (armed-red) — a hidden weight plate punishes information the player can't have. *Tone/fairness call.*
- Does throwing items across actually beat it cleanly, or does that trivialize it? If trivial, gate the far side so the throw must be precise. *Scope/fun call — defer to playtest.*
