# Thief
**Category:** Inventory & throw-synergy

## The idea
A small, fast enemy that does not attack you — it darts in, **grabs one item out of your slot inventory**, and flees toward the band's edge (or a hole it crawled from). You either **chase it down** (spending the run clock and risking depth) or **eat the loss** of whatever it took. The behavioral distinctness: it attacks your *inventory* directly, not your HP. It turns the bag from a passive value-store into something you must *defend*. The skill it forces: snap target-prioritization under the throw verb — a thrown item *kills the thief and drops your stolen item back*, but you must lead a fleeing target with a mouse-aimed arc, and you must decide *which* carried item is worth spending to recover the one it stole. Throwing your second-most-valuable item to recover your most-valuable is a real, legible trade.

## How it fits THE FAR YARD
It directly pressures the two core verbs. The slot inventory (`systems/inventory/run_inventory.gd`, `items: Array[JunkItem]`) becomes a thing with *exposure*: the thief calls something like `remove_at(highest_value_index)` against your bag, firing the existing `run_inventory_changed` so the HUD's "Holding: N" drops visibly. The throw verb (L1: highlight Q/E, mouse-aim, Space) is the counter — a hit `queue_free()`s the thief and re-spawns the stolen item via the existing `EventBus.junk_dropped` re-drop path, so recovery reuses infrastructure that already exists. It taxes the **extract-pressure / exposure timer** loop: chasing burns the dive clock and pulls you *deeper*, away from the gate, raising instability `I`. First appears **Band 1–2 (Near/Temporal)** as a low-danger nuisance that teaches "the bag is not safe," escalating in count and speed by band.

## Graybox sketch
A fast triangle that idle-wanders until the player's `run_haul_value()` is above a threshold. States: WANDER → DART-IN (lunges to contact range) → STEAL (removes one item, snapshots its id) → FLEE (sprints toward nearest band edge/spawn hole, despawns after a timer if it escapes). On thrown-projectile hit during FLEE: drop the carried stolen item at its position and `queue_free()`. No art: color shift while "carrying loot" so it reads as the thief-with-your-stuff.

## Synergies & counters
The throw verb is the whole counter — but it competes with throw-as-defense (you might need that item for a pursuer). **Synergy with Eater:** a thief stealing near an Eater is a nightmare (your thrown recovery shot feeds the Eater). **Synergy with depth:** thieves flee *deeper*, baiting greedy chases. Counter without throwing: corner it against geometry, or simply accept the loss and extract — the design must make "eat the loss" a valid, non-punishing choice (it took one item, not your run).

## Open questions
- **What does it steal?** Highest-value (stings most, clearest) vs. random (fairer, less rage-bait) vs. highlighted slot (skill-testable). *Director call — fun/tone.*
- Does a stolen item that *escapes* count as lost forever, or recoverable on the surface (a "fence who buys from thieves" hook)? *Scope/economy call.*
- Should it be throw-killable only, or also bumpable? Throw-only keeps the category pure but may frustrate; recommend throw-primary with a melee-bump fallback.
