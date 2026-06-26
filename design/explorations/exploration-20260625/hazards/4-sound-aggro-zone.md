# Sound Aggro Zone
**Category:** Zone & area-denial

## The idea
A bounded region where **noise wakes things**: while inside it, **moving fast or throwing** raises a local alarm that **wakes nearby dormant enemies**; moving slowly (or standing still) keeps it quiet. The behavioral distinctness: it's the only hazard that **punishes the player's own verbs** rather than occupying space — the danger is *you*. The decision it forces is *patience vs. tempo*: creep through (slow, safe, eats your extraction clock) or sprint through (fast, but you pull the pursuer/sleepers down on yourself). It turns the run's most automatic input — movement — into a deliberate, throttled choice, and it's the GDD's stealth pillar ("**Stealth, distraction... and routing around are first-class options**," §7) made into a concrete zone.

## How it fits THE FAR YARD
This is the most GDD-native of the zone hazards. The breather rig already "**muffles sound for stealth**" (§7); the combat philosophy is "**an engineer, not a soldier... Avoidance is always viable**" (§2/§7); and "**toss a noisy part**" as a distraction is named as a verb (§7) — a sound zone makes that throw *matter* (throwing here is loud, so it doubles as a lure). Against the core verbs: **move** gains a speed/noise trade (this implies a slow/sneak movement state the player can choose); **throw** becomes loud → a deliberate aggro tool *or* a mistake; **loot** is unaffected directly but you must reach the junk quietly; **extract** tension is the headline — patience is the safe play but the dive clock (`dive_clock_timeout`, M1 As-Built) punishes the slow creep, so the zone weaponizes the timer against caution. That's the inverse of the gas cloud (which weaponizes the timer against *lingering*) — together they'd give the build two opposite time-pressures, good variety. It pairs naturally with the **R1 pursuer** (L2): the dormant sleepers are the same `HazardEntity`, just spawned **asleep** until the noise threshold trips them. First appears **Band 1–2** as a tutorialized "quiet zone," and becomes the dominant routing layer in **Band 3 (Lateral)** where many deep things "can't be killed cleanly, only evaded" (§7).

## Graybox sketch
- A `Node2D` region (`spawn_ctx["room_bounds"]`, L2 primitive) holding a `noise: float` accumulator and N references to dormant `HazardEntity` sleepers spawned in IDLE.
- Each frame inside the zone: `noise += player_speed * dt` (fast move adds a lot, slow adds little, still adds nothing); a `throw` event inside adds a big burst. `noise` decays toward 0 when quiet.
- When `noise > wake_threshold`, wake the nearest dormant sleeper (flip it to its existing chase state, reuse L2 room-bound patrol). Optionally tier it: cross threshold 1 → one wakes; threshold 2 → all wake.
- Feedback (greybox, no audio asset): a debug noise-meter bar + the zone tint pulsing brighter as `noise` rises — a pure visual tell of "you're being loud."
- Knobs (`sound_` prefix, all-off default): `sound_enabled`, `sound_wake_threshold`, `sound_move_gain`, `sound_throw_burst`, `sound_decay_per_second`, `sound_sleeper_count`.

## Synergies & counters
- **Throw as a lure (the key synergy):** a *loud* throw is also a *distraction* — toss a junk item to one side, spike the noise there, and slip past while sleepers orient to the burst. This makes the L1 throw a stealth tool, not only a weapon — directly the GDD's "toss a noisy part" (§7).
- **Anti-synergy with gas/dark:** a sound zone overlapping a darkness pocket is brutal (creep blind *and* quiet); recommend a composition rule limiting overlap until tuned.
- **Counter:** patience (creep), the breather rig's sound-muffle (Gear track), or the lure-throw. Skill = pacing your own movement.

## Open questions
- **Requires a sneak/slow-move state the player doesn't have yet.** M1.5 movement is single-speed. Is adding a speed throttle (hold-to-creep, or auto-slow inside the zone) in scope, or does the zone instead just penalize *any* movement above a low cap? *Scope/fun call — flag to Director; recommend auto-slow inside the zone for the first ship (no new input).*
- **Dormant enemies = the same R1 entity asleep?** Reusing `HazardEntity` is cheap, but R1 is currently a chaser, not a sleeper — needs an IDLE-until-woken state. Confirms a small L2 extension. *Technical, low-risk.*
- **Does standing still trickle noise, or is stillness perfectly safe?** Perfectly-safe stillness invites camping (anti-fun with the clock); a slow trickle keeps you moving. *Recommend a tiny idle trickle so the extraction clock still bites.*
