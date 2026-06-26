# Rising Tide
**Category:** Time-pressure / extraction-specific

## The idea
A fluid surface — flood, lava, sludge, "static" — that **climbs at a fixed rate per second**, raising a lethal (or damaging) waterline that swallows the map from the bottom up. The deepest/lowest tiles flood first; the player and the loot sitting on the floor become unreachable in a known order. It is not the clock telling you to leave — it is the **floor itself disappearing** under you.

**Behavioral distinctness:** it forces *spatial triage under a visible, monotonic deadline*. The decision is "which loot is still safe to grab, and for how long" — a reading of the rising line against the map's elevation, not a reaction to a chasing threat. It rewards players who route low-first then retreat high, and punishes the player who lingers over a far corner that is about to be underwater. Unlike a countdown number, the threat is *legible in space*: you can see exactly which junk you'll lose.

## How it fits THE FAR YARD
The build already has a ~300s `dive_clock` (`L0`/`decision_hud.gd` clock bar, `dive_clock_changed`/`dive_clock_timeout`). Rising Tide is **a distinct second pressure, not a redundant clock** — but only if it expresses something the global timer cannot: **the countdown says "leave the band," the tide says "leave *this part of the band* now."** The global clock is band-wide and abstract; the tide is local, geometric, and per-room. It converts the GDD's "the longer you linger in a zone… the terrain shifts" (§6 Instability pressure) into a concrete, readable terrain change.

It layers cleanly on the verbs: MOVE becomes elevation-aware (flee uphill); LOOT becomes a race against the line; EXTRACT is unaffected directly but the tide can cut off the route *back* to the gate, sharpening the push-vs-extract bet (GDD pillar 1). The greed tension is explicit — the richest junk (B3 depth-scaled value) tends to sit deepest, and deepest floods first.

**Band depth:** introduce at **Band 1–2** as a slow, survivable rise (forgiving, teaches the read), escalating rate/lethality by `Instability` band toward Band 3+ where lava/anti-physics floods fast. Rate should scale with the GDD `I` scalar.

## Graybox sketch
- One `tide_level: float` (world-Y), rising `tide_rate_px_s` each `_physics_process` (a `RunConfig` knob, default off → baseline parity).
- A flat `ColorRect`/`Polygon2D` at `tide_level`, full map width, climbing.
- Contact test: player's `global_position.y > tide_level` → damage tick or `fail_run(&"drowned")` (reuse the L5 `*_kills`-style toggle so a non-lethal sweep is possible).
- Floor junk below the line: flag unreachable (dim it) rather than delete, so the player *sees* what they forfeited.
- No art: blue rectangle, rising. That alone proves the "race the line" read is fun.

## Synergies & counters
- **Throw verb (L1):** the tide pushes the player *up and inward*, compressing the arena — making it easier to line up a throw on a room-bound pursuer (you're cornered together). Conversely, retreating uphill can break a chase.
- **The Hunter / Alarm spawner:** tide + a chaser is brutal — it removes the "run away downhill" option. Pair only at deep bands.
- **Counter:** read elevation early, loot low-first, keep a high retreat lane to the gate. A grapple/traversal tool (GDD §7) could let the player cross flooded gaps — a future upgrade sink.

## Open questions
- **Does this double up with the countdown?** Partially — both are "leave soon" timers. It earns its place ONLY if it is *spatial* (per-room loot-denial) where the clock is *global*. If graybox proves players just read it as "a second countdown," cut or merge it. **Director fun-call.**
- Top-down camera has no real Z/elevation — "flooding low-first" needs a faked per-tile height field or per-room flood order. Does that read on a flat top-down map, or does it just look like an expanding stain? **Vision/feel call — graybox first.**
- Lethal vs. damage-over-time on contact: instant death is harsh and may feel unfair if the route-back floods unexpectedly. Recommend damage-tick at shallow bands, lethal deep. **Director.**
- Does the tide ever recede (tidal "low tide" weather hook, GDD §6 run-modifiers) or only rise? Receding adds counterplay but complicates the legible-monotonic promise.
