# Reflector
**Category:** Inventory & throw-synergy

## The idea
An enemy with a hard, angled face (a shield, a slick carapace, a mirror-shard) that **bounces a head-on thrown projectile straight back at you**. A throw aimed dead-center returns down its own line and can hit *you* (knockback, or a lethal contact if it's fast). To beat it you must **throw at an angle** so the deflection misses you and exposes its soft side, or wait for it to turn. The behavioral distinctness: it converts the mouse-aimed throw from a *point-and-click* into a *geometry puzzle*. The skill it forces is aim precision and reading the reflection normal — the player must think about *where the item goes after the bounce*, not just whether it connects. This is the deepest possible exercise of the mouse-aim throw verb specifically.

## How it fits THE FAR YARD
It builds directly on L1's mouse-aimed projectile. The thrown item already has a velocity vector and a world-collision path; the Reflector adds a face that reflects that vector instead of dying. The returned projectile is the *same item* — so a botched head-on throw both fails to kill *and* re-drops the item behind you (or worse, knocks you toward a hazard / the pursuer). It taxes inventory through *risk of waste* rather than guaranteed loss: a smart throw kills and you might even recover the item; a dumb throw is a wasted slot and a self-hit. It pressures the **extract timer** because solving the angle takes a beat of positioning under the clock. First appears **Band 3 (Lateral)** — the "physics slightly off" band is the thematically perfect home for a reflection gimmick; reflection angle could even warp by band as an instability flavor.

## Graybox sketch
A square with one **highlighted hard face** (a thick colored edge) and three soft faces. States: FACE-PLAYER (rotates its hard edge toward the player every second) → DEFLECT (a projectile hitting the hard face reverses its velocity component along the face normal; a projectile hitting a soft face kills it). The deflected projectile keeps the same `JunkItem` and L1 re-drop semantics. No art: the one thick edge is the entire read — "hit the other sides."

## Synergies & counters
**Synergy with Eater:** Eater says "don't throw," Reflector says "throw, but think" — together they fully decompose the throw verb into *whether* and *where*. **Synergy with corridors:** a Reflector in a tight hall makes head-on throws suicidal (the bounce has nowhere to miss you), forcing the player to create an angle by moving. Counter: flank to hit a soft face; bounce the item off the *wall* into its back; or bait its hard face away and throw in the window.

## Open questions
- **How lethal is the return?** Pure knockback (forgiving, puzzle-y) vs. lethal-if-fast (tense, punishing). Recommend knockback + re-drop at low bands, lethal return only at deep bands. *Director fun/difficulty call.*
- Does the bounce obey *real* reflection math (satisfying, but hard to read at speed) or snap to 4/8 directions (legible, less elegant)? Recommend snapped directions for graybox legibility.
- Should the player be able to *intentionally* bank-shot a throw off a Reflector to hit something behind it? A skill-expression upside vs. scope creep. *Scope call.*
