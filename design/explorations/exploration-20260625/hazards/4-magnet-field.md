# Magnet Field
**Category:** Zone & area-denial

## The idea
A region that exerts a **constant pull** — dragging the player (and/or metal loot) toward a wall, an edge, or another hazard. Inside it you don't fully control your own position; you must **fight the drift** to hold a line or reach junk. The behavioral distinctness: it's the only hazard that **corrupts the player's movement vector itself** — every other hazard leaves you in full control of where you go and threatens you for going to the wrong place; the magnet makes the *going* unreliable. The decision it forces is *thrust budgeting*: you can still get anywhere, but moving against the pull is slow and moving with it is fast-and-dangerous, so you plan a path that uses the drift instead of fighting it the whole way. It's the inverse of the magnet-grapple tool fiction — here the yard pulls *you*.

## How it fits THE FAR YARD
The GDD's signature tool is a "**magnet-grapple** [that] pulls loot, yanks enemies, and crosses gaps" (§7) — a magnet *field* is that mechanic turned into an environmental threat, thematically perfect for a junkyard (everything here is metal). It dovetails with the GDD's "**reality instability**" of the deeper bands (§4) where a constant ambient force reads as the world itself being wrong. Against the core verbs: **move** is recontextualized (drift-aware pathing, the core skill); **loot** gets a twist — *metal* junk on the floor also drifts, so a high-value part may be sliding toward a wall/pit and you race the drift to grab it (loot that runs away); **throw** interacts richly — a thrown item's trajectory **curves in the field**, so aiming at a pursuer means leading the pull (the field makes L1's mouse-aim a real skill check), and throwing *with* the pull extends range while *against* it falls short; **extract tension** — the pull toward a hazard/edge means *standing still costs you* (you drift into danger), which, like the gas cloud, layers a spatial pressure on top of the dive clock, but here "keep correcting" rather than "keep moving." It's a strong **traversal-puzzle** hazard rather than a lethal one — the magnet rarely kills directly; it pushes you *into* what kills (a wall of spikes, a pit, the gas). First appears **Band 3 (Lateral)** — it wants reality to feel off, and it's mechanically rich enough that introducing it shallow would muddy the simpler early bands.

## Graybox sketch
- A `Node2D` region (`spawn_ctx["room_bounds"]`, L2 primitive) with an `attractor` point/edge and a `pull_strength`.
- State: each frame inside, add `pull_dir * pull_strength * dt` to the player's velocity (before `move_and_slide`) — the player's own input still applies, so it's a tug-of-war, not a loss of control. Optional: apply the same to metal `JunkPickup` bodies so loot drifts.
- The magnet itself isn't lethal — pair it (graybox composition) with an existing lethal edge: a spike row or `gas` cloud at the wall it pulls toward. Death is the existing path of *that* hazard.
- Tell: flat directional arrows / a gradient tint showing pull direction and strength. No particles.
- Knobs (`magnet_` prefix, all-off default): `magnet_enabled`, `magnet_pull_strength`, `magnet_affects_loot` (bool), `magnet_curves_throws` (bool), `magnet_attractor_mode` (enum: point / wall-edge).

## Synergies & counters
- **Throw synergy (the standout):** the field **curves the thrown projectile** — a deliberate aim challenge that makes L1's mouse-aim mastery matter, and lets a clever player *slingshot* a throw using the pull for extra range/angle around cover.
- **Composition synergy:** magnet + spike-wall = "don't get pulled into the spikes"; magnet + pit/void = a soft-kill that reuses the gas/electric death paths; magnet + R1 pursuer (L2) = you fight drift *and* a hunter.
- **Counter:** path with the drift, not against it; time your dashes; and (future Gear) the magnet-grapple tool could *anchor* you against the field — a lovely "the same physics that threatens you is also your tool" payoff true to the GDD.

## Open questions
- **Does it pull loot, the player, or both?** Player-only is the cleanest single mechanic; adding drifting metal loot is evocative but doubles the moving parts and may read as buggy. *Recommend player-only for the first ship, `magnet_affects_loot` defaulting off behind a knob.* Scope call.
- **Curve-the-throw: depth or noise?** A curving projectile is the richest synergy but can feel unfair if the curve isn't legible. *Recommend shipping it OFF (`magnet_curves_throws=false`) first so the field is learnable, then A/B the curve in RG.* Fun call — flag to Director.
- **Is it a hazard or a traversal element?** The magnet rarely kills alone; it's a force multiplier on other hazards/edges. Risk: with nothing to be pulled into, it's merely annoying. *Needs a clear lethal partner in every composition — recommend a placement rule that a magnet field always points at a lethal edge.*
- **Top-down "thrust" feel.** Tug-of-war movement can feel sluggish/unresponsive in a top-down twin-stick context. *Verify at playtest that fighting the pull reads as tense, not as input lag.* Fun call.
