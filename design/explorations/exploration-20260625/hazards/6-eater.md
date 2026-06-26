# Eater
**Category:** Inventory & throw-synergy

## The idea
A slow, hungry enemy that **catches thrown items mid-air and grows/heals from them**. Throwing junk *at* it is exactly the wrong move — each item you feed it makes it bigger, faster, or harder to kill. The behavioral distinctness: it inverts the throw verb's default reflex. Everywhere else in the game "in danger → throw something at it" is the answer (the L1 lesson). The Eater punishes that reflex and forces the player to *withhold* the throw, or to throw *around* it — at a wall to lure it, at the floor to bait it onto a hazard, or simply to **not throw at all and re-route**. It makes "should I throw?" a real question rather than a reflex, which is the point of building the whole category around the throw verb.

## How it fits THE FAR YARD
It's the anti-cheese guardian. L1 established the throw as the universal answer to the pursuer; the Eater is the band that says "not here." It reads `EventBus` for a thrown-projectile-overlap (the same projectile L1 spawns) and, instead of dying, consumes the `JunkItem` — the item is *gone* (no `junk_dropped` re-drop), a permanent cost. So it taxes the **inventory economy** twice: a wasted item *and* a stronger enemy. It pressures the **extract timer** by being slow-but-unkillable-by-throw — you must spend time and space disengaging rather than spending an item. First appears **Band 2–3 (Temporal/Lateral)**, once the player has internalized throw-to-kill and needs the assumption broken. Higher instability `I` makes it grow faster per item, tying it to the depth scalar.

## Graybox sketch
A large slow circle with a mouth-arc facing the player. States: HUNT (drifts toward player) → CATCH (any thrown projectile entering its mouth cone is consumed: item destroyed, the circle's radius and chase-speed tick up one step) → ENRAGE (after N feedings, brief lethal lunge). It has a real kill condition that is *not* a frontal throw — e.g. it can be staggered by a throw to its *back* (links to Armored/Shelled), or only dies on a hazard. No art: radius growth + speed are the whole read.

## Synergies & counters
**Synergy with Reflector:** both punish naive head-on throws, training the player to throw *at angles and at the world*, not at enemies. **Synergy with hazards (K5 bomb/spike):** the real counter is to lure the Eater onto a hazard rather than feed it — turning the *environment* into the weapon, the most "engineer not soldier" solution (GDD pillar 2). Counter: don't throw; kite it into a bomb's blast or onto rotating spikes; or just leave — it's slow.

## Open questions
- **Is a fed item gone forever, or does killing the Eater disgorge everything it ate** (a fat loot piñata reward for solving it right)? The piñata version makes feeding-then-killing a viable *strategy*, which may undercut the anti-cheese intent. *Director fun call.*
- Does it grow unboundedly (hard cap needed) or cap at a size? Recommend a cap so a panicking player can't create an unkillable boss.
- Should it telegraph "I eat throws" before the player learns the hard way? A first-encounter signpost vs. a punishing surprise. *Tone call.*
