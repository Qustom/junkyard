# Darkness Pocket
**Category:** Zone & area-denial

## The idea
A bounded region that **collapses the player's vision radius** while inside it — the screen darkens to a small circle around the player, so you **loot blind**. The behavioral distinctness: every existing hazard attacks the player's *body* (a contact that kills). Darkness attacks the player's *information* — it never touches HP, it removes the thing the whole top-down game runs on: knowing what's around you. The decision it forces is *commit-without-seeing*: do you push into the dark for the junk you glimpsed at the edge, memorizing its position, accepting you can't see a pursuer or a spike arriving — or do you skip the room? It rewards spatial memory and nerve over reflexes, and it's the most directly **horror-coded** hazard (GDD's "non-Euclidean dark," "silence used as a weapon" §13).

## How it fits THE FAR YARD
The GDD makes darkness a *depth signature*: bands shift "familiar grime → desaturated nostalgia → impossible color → **non-Euclidean dark**" (§13), and the dive's "**Time/light is a consumable resource**" (§6) — the dive clock is already framed as *light* draining (`max_light`/`drain_per_second`, M1 As-Built). A darkness pocket is the spatial, local version of that global light-clock: the room where your light simply isn't enough. Against the core verbs: **loot** becomes a memory game (you saw the junk before the dark swallowed it); **move** is how you escape the radius; **throw** gets interesting — you can't aim at what you can't see, so the dark **soft-counters L1's mouse-aimed throw**, forcing you to flee a pursuer instead of answering it (a deliberate inversion of M1.5's "you can finally fight back" win). **Extract tension:** darkness *encourages* lingering (you move slower, more carefully) right when the clock punishes it — the opposite pull from the gas cloud, and a good one. It also feeds the GDD's tool fiction: a future **flare/lamp** item (throwable light) is the natural Gear-track counter. First appears **Band 2 (Temporal)** as small pockets, becoming whole-room and routine by **Band 4 (Far)**, where "the deep things may require Knowledge/specific gear to even perceive" (GDD §7) — darkness is the gameplay shape of that.

## Graybox sketch
- A `Node2D` region with `spawn_ctx["room_bounds"]` (L2's Rect2 primitive). A `CanvasModulate` or a full-screen dark `ColorRect` with a radial-gradient hole (a `Polygon2D` mask or a cheap shader) centered on the player.
- State: `inside: bool` (player position vs. bounds). On enter, tween the vision radius from normal → `dark_radius`; on exit, tween back. No per-tile state — one boolean and one radius.
- Junk inside renders normally but is occluded by the dark overlay outside the radius, so it literally disappears as you walk away — proving the "loot blind" feel with zero new art.
- Knobs (`dark_` prefix, all-off default): `dark_enabled`, `dark_radius`, `dark_fade_seconds`, `dark_dims_throw_aim` (bool — whether throw-aim is also clipped to the radius).

## Synergies & counters
- **Throw counter that *fails*:** the dark deliberately blunts L1's throw (can't aim) — the intended cost. A thrown item could be made to *emit a brief light flash* on landing, turning throw into a recon tool (toss to see).
- **Pursuer in the dark:** an R1 pursuer (L2, room-bound) inside a darkness pocket is the scariest combination in the build — you hear/sense it, can't see it, and can't reliably throw at it. Strong horror payoff; verify it's *tense*, not *cheap*.
- **Counter:** memorize-then-commit; route around; or (future) a flare/lamp Gear upgrade. The clean skill expression is reading the room's loot in the half-second before the dark closes.

## Open questions
- **Fairness vs. a lethal hazard you can't see.** A spike/bomb hidden in the dark may read as unfair rather than tense. Option: darkness rooms never *also* host instant-death hazards (composition rule), only soft threats (pursuer, gas). *Fun call — flag to Director; recommend the composition rule for the first ship.*
- **Does the dark dim throw-aim?** Clipping aim to the radius makes the dark a true counter to L1; leaving aim global keeps throw a reliable escape. *Recommend clip-to-radius for distinctness, behind a knob so RG can A/B it.*
- **Pure presentation vs. a stat.** Is "vision radius" a real player stat (so a lamp upgrade reads against it) or a one-off screen effect? The former is cleaner long-term but is new player state. *Scope call.*
