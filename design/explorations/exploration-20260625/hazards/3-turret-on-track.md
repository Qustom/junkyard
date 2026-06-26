# Turret on a Track
**Category:** Static & environmental traps

## The idea
A sentry that **patrols a fixed rail along a wall**, sweeping a threat (a beam, a firing line, or a contact arc) as it travels. It is the bridge between "static trap" and "enemy": it has a *position that moves* (like the crusher's block or the laser's pivot) but on a **predictable patrol path**, not chasing you. Distinctness vs. the sweeping laser (a beam from a *fixed* anchor) and the R1 pursuer (a thing that *comes for you*): the turret's anchor *moves on a track* but its behavior is **schedulable** — you can predict where the danger zone will be and *when*, and slip past behind it or through a gap in its line. The decision it forces is **timing your movement to a patrolling threat's position**, reading both *where it is on the rail* and *where it's pointing*.

## How it fits THE FAR YARD
A placed run-state hazard in the fair-share system, snapshotting `RunConfig` at `setup(...)` and reading `_cfg.htr_*`. It is an `AnimatableBody2D`/`Node2D` that lerps between two rail endpoints (`htr_speed`, endpoints from the spawn context). Its threat is a fixed-direction firing line (perpendicular to the wall) tested analytically (distance-to-segment, like `spike_hazard.gd`), or a periodic pulse along that line. A hit routes through `GameState.fail_run(&"death")` behind `htr_kills` (default `true`, L5 pattern) and emits `new_hazard_killed(&"turret", ...)`. **It does not chase or acquire** — that keeps it firmly a *trap* (predictable) and avoids treading on the pursuer/enemy-AI lane (R1, K5). It's a moving lethal lane on rails.

It's the richest static trap for the **answer-danger** texture the M1.5 gate prized: with the L6 mouse-aim throw, a turret on a track is a moving target you can *kill* (throw an item to break it, if `htr_kills` of the turret by hazards/throws is in scope) — making it the first static trap that is itself *beatable* by the throw verb, not only avoided. That directly serves the GDD "cleverness beats firepower" pillar and the L1 "spend an item to answer a threat" loop.

First appearance: **Band 2–3.** It is the most complex static trap (moving anchor + directional threat), so it lands after the player has met the simpler timed traps; a sentry from a future scrapyard or an alt-reality watch-machine fits Band 2/3 fiction.

## Graybox sketch
A `ColorRect` body that lerps along a line between two `Marker2D` endpoints + a drawn firing line in front of it. State: `PATROL` (always moving) with an optional `FIRE` pulse cadence (`htr_idle_s`/`htr_fire_s`) so the line is only lethal during pulses (readable gaps to cross). Kill-test = distance to the firing segment during `FIRE`. No art: a sliding rect with a blinking line. Tune `htr_speed` + pulse cadence so a patient player always finds a window but a careless crossing gets caught.

## Synergies & counters
- **With throw (L6):** **the headline** — a thrown item can *destroy* the turret (lead the moving target), the first static trap the throw verb defeats outright. Lose the item's sale value to clear the lane permanently: a real push-your-luck trade.
- **With pursuer (R1):** the turret's firing line can catch the pursuer too (if hazards take hazard damage), letting you kite R1 through a turret's path.
- **With conveyor / ice:** crossing a turret's lane while drifting or sliding compounds the timing read — deep-band combo.
- **With collapsing floor:** drop the floor in the turret's path to strand it (if the rail crosses collapsible tiles) — emergent toy.
- **Counter:** time the crossing to the turret's position + pulse gap, or spend a throw to kill it.

## Open questions
- **Can the throw kill it (is the turret destructible)?** This is the most exciting distinction — a static trap you can *answer*, not just dodge — but it needs a throw-vs-static-hazard hit rule the system doesn't yet have (L1 throws kill the body-based pursuer; static `Node2D` hazards aren't hit-testable the same way). *Strong recommend yes (it's the reason this idea earns its place over the laser); flag the projectile-vs-hazard-collision work + balance to the Director.*
- **Contact-kill vs. fire-line-only** — does touching the moving body kill (like the crusher) or only the firing line? *Recommend fire-line-only for fairness + readability.*
- **Does it cross the player's only route?** Placement must leave a timing window or an alternate; never an unwinnable lane. *Placement-rules call.*
- **Scope creep toward "enemy."** A patrolling, firing sentry is close to an enemy; keeping it strictly schedulable (no acquisition, no chase) is what holds it in the *trap* category. *Hold the line at graybox — flag if the Director wants it to read more as a foe.*
