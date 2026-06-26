# Gas Cloud
**Category:** Zone & area-denial

## The idea
A toxic pocket that **spreads from a source to fill a room over time** and deals **chip damage** (a slow drain, not a kill-on-contact) to anyone standing in filled cells. The behavioral distinctness: unlike every M1.4/M1.5 hazard — which are all **instant, binary, lethal contacts** (ping-pong, bomb, spike, R1 pursuer all route straight to `GameState.fail_run(&"death")`) — gas is the first **gradient, survivable-for-a-while** hazard. The decision it forces is *route timing under a growing exclusion zone*: the room is fully lootable at second 0, partly lootable at second 8, and a death-trap by second 20. You read the spread, grab the high-value junk near the source first (it's the most exposed), and leave before the safe area closes. It punishes greed with attrition, not a guillotine.

## How it fits THE FAR YARD
The GDD already names "**toxic pockets**" and the **breather rig** that "lets you survive toxic pockets *and* muffles sound for stealth" (GDD §7). Gas is the in-dive hazard that motivates that Gear/Tech-track tool — the first concrete reason to buy the breather, exactly the GDD's "new tools open new traversal" pattern. It reads against the core verbs cleanly: **move** is the answer (keep circulating), **loot** is the temptation (the best junk is near the gas source), **throw** is unaffected (you can pelt a pursuer through the cloud), and **extract** is the squeeze — the dive clock (`dive_clock_changed`/`dive_clock_timeout`, M1 As-Built) already punishes lingering, and gas adds a *second, spatial* clock that runs faster. That double-clock is the **deliberate tension to watch**: gas says "move NOW" while the extraction timer says "don't waste the day." Done right that's a sharp push/cash-out beat; done wrong it's two unfair clocks stacking. Chip damage needs a survivable HP/drain model, which M1 doesn't have yet (contacts are instant-death) — so gas is the first hazard that wants a **player health pool**, a real M2 dependency, not an M1.5 drop-in. First appears **Band 1 (Near)** as a thin, slow leak (sub-lethal even if you dawdle), escalating to room-filling lethal clouds by **Band 2–3**.

## Graybox sketch
- A `Node2D` source at a floor cell, given its room's `spawn_ctx["room_bounds"]` Rect2 (the L2 confinement primitive, reused).
- State: a coarse grid over the room bounds; each cell has a `fill: float` 0→1. Each tick, the source cell sets fill=1 and neighbors lerp up toward the max of their neighbors (cheap flood, no fluid sim). One `spread_seconds` knob = time to fully fill.
- Damage: any frame the player's cell `fill > threshold`, drain a `chip_per_second` from a debug HP bar. At HP 0 → existing `fail_run(&"death")`.
- Render: flat translucent `ColorRect`/`Polygon2D` per filled cell, alpha = fill. No particles.
- Knobs (RunConfig `gas_` prefix, all-off default per L0 house style): `gas_enabled`, `gas_spread_seconds`, `gas_chip_per_second`, `gas_max_fill_radius`, `gas_kills` (default true).

## Synergies & counters
- **Throw synergy:** a thrown item arcs *over* gas (it's a projectile, L1) — you can still answer a pursuer that's standing in the cloud you won't enter.
- **Pursuer pincer:** an R1 pursuer (now room-bound, L2) that shares a gassing room becomes a real squeeze — flee the gas *and* the hunter in the same shrinking space.
- **Counter:** the breather rig (Gear track) negates chip entirely — the clean upgrade payoff. Pre-breather, the counter is pure routing: enter, grab the exposed near-source loot first, leave before fill closes the door. A bomb/spike in the same room is *harder* with gas (you can't wait out the safe tile).

## Open questions
- **Needs a health pool (M2 dependency).** Chip damage is meaningless without survivable HP, which M1 lacks. Is "first hazard that introduces HP" acceptable scope, or should the graybox fake it with a per-second clock-drain so it ships in the existing instant-death model? *Scope call — flag to Director.*
- **Does gas dissipate or fill permanently?** Permanent-fill = the room becomes a no-go (clean area-denial); slow-dissipate = a tractable wait-it-out puzzle that interacts with the extraction clock. *Fun call — recommend slow-dissipate so it dialogues with, rather than dominates, the timer.*
- **Spread shape:** flood-from-source (telegraphs a safe direction) vs. uniform room-fill (pure "get out"). Recommend flood-from-source for legibility.
