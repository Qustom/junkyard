# Sneak / Crouch
**Category:** Movement verbs

## The mechanic
A second movement gear: hold (or toggle) to **creep** — slower, quieter, and with a **smaller detection footprint**. The core decision is *slow-and-quiet vs. fast-and-exposed*: sneaking lowers the three things that get you caught (your speed, the noise you emit, and the radius/range at which perceiving enemies notice you), at the cost of eating the dive clock. It is the player-side counterpart to the perception oppositions — it only means anything once something is watching or listening. Mechanically it scales a small set of multipliers: `max_speed × sneak_speed_mult` (movement), a future noise-emission `× sneak_noise_mult` (the sound zone), and an enemy-perception `× sneak_detect_mult` (the vision cone notices you later / from closer). It directly delivers the GDD's "stealth is first-class / avoidance is always viable" pillar as a *verb the player chooses* rather than a zone that's imposed on them.

## What exists today
- **Single speed.** `player.gd` is one gear: `Input.get_vector` → `step_velocity` accelerates toward `stats.max_speed` (200 px/s, `player_movement.tres`). There is no crouch input, no second speed, no stance state. The only existing speed modifier is the R3 exposure penalty `_exposure_speed_mult` — a clean precedent for a *multiplier on `max_speed`* that a sneak state would mirror.
- **Vision is cosmetic and player-only.** `vision_fog.gd` occludes the band beyond the player's *own* sight radius — it is a player limited-vision overlay, **not** enemy perception. "Smaller vision footprint" for sneak means the radius at which *enemies* detect the player, which **does not exist yet**.
- **No enemy perception, no noise system.** There is no vision cone and no noise model in the build. So sneak has a **hard dependency on the patroller-vision-cone opposition** (`hazards/1-patroller-vision-cone.md`, its `pat_cone_*` detector) and the **sound system** flagged by `hazards/4-sound-aggro-zone.md` (its `noise` accumulator). Until at least one of those ships, sneak reduces an input nobody reads — pure speed loss, no payoff.

**Missing:** a stance state + input (L6), a `sneak_*` knob group, and at least one perceiving enemy to dodge.

## How to fit it in
- **Core verbs:** sneaking layers onto move (a speed gear) and pairs with **throw-as-lure** (creep close, throw noisy, slip past — the GDD's "toss a noisy part"). Loot grabs become "creep in, time the cone, press F."
- **Dive clock = the cost.** `dive_clock.gd` drains ~real-time seconds regardless of speed, so creeping covers less ground per second of light — patience is *literally* expensive. This is the tension that stops sneak from being a free dominant strategy.
- **Oppositions:** against the **vision cone**, sneak shrinks `pat_cone_range` effectively (detected later/closer); against the **sound zone**, sneak is the intended quiet-pass; against **ambushers**, sneak does little (proximity triggers ignore stance) — good, it keeps sneak from being universal.
- **Control mapping (L6):** **toggle** for low-friction long creeps (twin-stick-friendly, no held finger) vs **hold** for momentary precision at a cone edge. Recommend **hold-to-sneak** as the ship default (matches "press = commit", auto-releases on mistake), with a toggle accessibility option.
- **Knob + telemetry:** `sneak_*` group, all-off default reproducing today's single-speed baseline (`sneak_enabled=false`). Knobs: `sneak_speed_mult`, `sneak_noise_mult`, `sneak_detect_mult`. Telemetry (config-marked): fraction of dive time spent sneaking, detections-while-sneaking vs running, clock spent creeping.

## Research (cited)
- **Vision-cone model (Monaco):** ~90° forward cones, invisible to the player, with a *progressive* fill-to-alert rather than binary spotting — being at a cone's edge "notices" you before it catches you. Argues sneak should affect a **fill rate / effective range**, not a yes/no flip.
- **Noise + speed (Invisible Inc):** sprinting *emits noise into the tile you enter*, heard within a radius; walking is silent. Sound is a deliberate, throwable distraction. Validates the sneak-vs-run noise trade and the throw-as-lure synergy. Tom Francis / Spaderdabomb's lesson: "being directly seen is rare — lots happens between perfect stealth and caught," i.e. design the **noticed** middle state, don't make detection binary.
- **Detection-radius vs cone:** radius (omnidirectional sound) and cone (directional sight) are complementary — sneak should reduce **both**, which is why it needs both the cone opposition and the noise system to fully read.

## Graybox sketch
Smallest fun proof needs **one perceiving enemy**: a single patroller on a 4-point loop with a drawn cone (`hazards/1-patroller-vision-cone.md` graybox) guarding one pickup. Add a hold-to-sneak input that halves `max_speed` and multiplies the cone's effective detect range. Question to answer: does "creep up, wait for the sweep to point away, grab, slip out" feel like a satisfying heist — and does the dive clock make the wait *meaningfully* tense? No art; reuse the debug cone wedge.

## Open questions
- **Real stealth pillar vs. light option?** The biggest call. A full pillar wants noise, cones, search states, and lures all interlocking; a light option is just "hold to go slow + sneak past cones." **Recommend shipping the light option first** (sneak + one cone), measure whether testers *use* it before investing in a pillar. *Vision/scope call — flag to Director.*
- **Toggle vs hold default** (above) — recommend hold; *fun/feel call, sweep at gate.*
- **Does sneak reduce the player's OWN vision footprint too** (smaller `vision_fog` radius while crouched, trading awareness for stealth)? Thematically rich but can feel punishing. *Recommend NOT coupling for v1 — keep sneak purely about being un-perceived.*
- **Stillness:** is standing still strictly safer than sneaking? Pairs with the sound-zone's "idle trickle" question — keep them consistent.

---
Sources:
- [Monaco stealth — vision cone & progressive alert (Fandom wiki)](https://monacowhatsyoursismine.fandom.com/wiki/Stealth)
- [Invisible Inc — Movement & sprint noise (Fandom wiki)](https://invisibleinc.fandom.com/wiki/Movement)
- [The Problems of Modern Stealth Design, and How Invisible Inc. Solves Them (Game Developer)](https://www.gamedeveloper.com/design/lesson-the-problems-of-modern-stealth-design-and-how-invisible-inc-solves-them)
- [What Works And Why: Invisible Inc — Tom Francis](https://www.pentadact.com/2014-12-29-what-works-and-why-invisible-inc/)
