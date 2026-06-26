# Sprint with a Cost
**Category:** Movement verbs

## The mechanic
A second, faster movement gear — held (or toggled) — that the player can fall
back on when they want to cover ground quickly: outrun a pursuer, reach an exit
before the dive clock empties, or cross a long corridor. The point is **not** the
extra speed; it's that sprinting is **never free**, so "do I run?" becomes a live
decision every time rather than a default the player holds down the whole dive.

**The cost fork** — two distinct models, each with a different feel:

- **Noise-based (positional).** Sprinting is *louder*: it broadcasts a noise
  radius that wakes sound-aggro zones, draws pursuers, or trips alarms. The cost
  is **spatial and conditional** — sprinting through a dead, empty corridor is
  basically free; sprinting past a sleeping sound-aggro zone is a gamble. This
  makes the decision *read the room*: where am I, what's listening.
- **Meter-based (resource).** Sprinting drains a stamina meter that refills when
  you walk/stand; empty = forced walk (or a sluggish penalty) until it recovers.
  The cost is **rhythmic and self-contained** — it doesn't depend on what's
  nearby, so it's a pacing tax (sprint in bursts, can't sprint forever). It works
  even in an empty band.

They are not mutually exclusive. The richest version is **both**: a meter caps
*how long* you can sprint and noise governs *when it's safe to* — but each alone
is a complete, testable mechanic, and shipping both at once doubles the tuning
surface. The cost-model choice is the headline Director call (see Open Questions).

## What exists today
**A single move speed.** `player_movement_stats.gd` exposes exactly one
`max_speed` (200 px/s), `acceleration`, and `friction`; `player.gd`'s
`step_velocity()` accelerates toward `input_dir * max_speed`. There is no gear
shift, no second speed, no stamina concept. The only existing speed modifier is
the R3 exposure seam (`_exposure_speed_mult`, default 1.0) which *scales* top
speed downward — a precedent for layering a multiplier, but the opposite sign.

**Time pressure already exists** via `DiveClock` (~300s in the current preset,
`timer_length_s`). Sprint-to-save-time has a real meter to play against today.

**No noise/aggro system exists yet.** Nothing in the build emits a "noise" event
or listens for one — the sound-aggro zone (`hazards/4-sound-aggro-zone.md`) and
the noise→aggro tradeoff are **explorations, not built**. So the *noise-based*
cost fork has a hard upstream dependency: it cannot ship until a noise-emit /
noise-listen contract exists on the EventBus. The *meter-based* fork has **no
such dependency** and could ship standalone.

What's missing: the second speed tier itself, the input to engage it, the cost
accounting (meter and/or noise emission), and the feedback that tells the player
they're paying.

## How to fit it in
**Core verbs.** Sprint composes with throw (L1/L6): you can't throw mid-sprint
cleanly (or sprinting cancels aim), forcing a "stop, turn, throw" beat against a
pursuer — which is exactly the L2 spawn-room-pursuer fantasy ("turn and throw to
kill it"). Sprint is the *flee* option; throw is the *fight* option; the meter/
noise is what stops flee from being strictly dominant.

**Dive clock + exposure.** Sprint is the lever that trades **safety for time**.
Meter model: sprinting saves clock seconds at the cost of being unable to sprint
when you next need to. Noise model: sprinting saves time but raises the odds of
waking something — and with R3 exposure on, a sprint could even *add* exposure
climb (sprint = "make noise" = "get noticed faster"), unifying it with the
Blades-style Heat model the GDD wants.

**Oppositions.** Sound-aggro zone: sprinting inside its radius wakes it; walking
sneaks past — the canonical noise-cost payoff. The Hunter / pursuers: sprint is
how you *open a gap*, but a stamina cap means you can't kite forever (you must
lose them in the maze, not outrun them indefinitely). Patroller vision-cone:
sprint is orthogonal (it's seen, not heard) — good, it keeps sprint from being a
universal "ignore all threats" button.

**Control mapping (L6).** Movement is left-stick/WASD; aim is decoupled
(mouse/right-stick). Sprint wants a held modifier that doesn't fight either:
**Left-shift (KB) / left-stick-click or a face/shoulder button (pad)**. Hold-to-
sprint (not toggle) keeps it a moment-to-moment choice and auto-releases when the
meter empties.

**RunConfig knob + telemetry.** Follow the locked pattern: an `sprint_` group,
master toggle `sprint_enabled` (default **false** → byte-identical baseline, no
new speed, no meter, no noise), with `sprint_speed_mult`, `sprint_meter_max`,
`sprint_drain_per_s`, `sprint_refill_per_s`, `sprint_noise_radius`, and a
`sprint_cost_model` enum (`meter` / `noise` / `both`). Add to `to_flat_dict()`.
Config-marked telemetry: `sprint_seconds`, `sprint_distance_frac`, sprint-state
at each death/catch, and (noise model) `aggro_woke_via_sprint` count — so RG2 can
ask "did sprint change time-to-extract and death cause?"

## Research (cited)
Prior art splits cleanly along the same fork:

- **Meter-as-cost.** *Dark Souls* stamina is the canonical "every action spends a
  shared bar, empty = vulnerable" loop — sprint competes with attack/dodge for the
  same resource, so running away has an opportunity cost. *Don't Starve* sprint-
  equivalents and hunger gate over-exertion similarly. *Escape from Tarkov* ties
  sprint to a stamina/endurance system where over-exertion forces a slow recovery,
  and crucially **weight raises both stamina drain and footstep loudness** —
  bridging the two models ([Tarkov Endurance/Strength wiki](https://escapefromtarkov.fandom.com/wiki/Endurance)).
- **Noise-as-cost.** *Hunt: Showdown* is the strongest reference: traversal noise
  (sprinting, breaking glass, noise traps) gives away position and *triggers
  monsters*, and Crytek explicitly tunes "the cost of silence" as a balance lever —
  i.e. moving fast/loud is a deliberate risk traded against speed
  ([PC Gamer: "increase the cost of silence"](https://www.pcgamer.com/games/fps/we-want-to-increase-the-cost-of-silence-hunt-showdown-1896s-latest-update-brings-a-new-event-a-massive-list-of-bugfixes-and-a-tougher-challenge-for-stealthy-players/),
  [PC Gamer: Hunt sound design](https://www.pcgamer.com/lets-hear-it-for-hunt-showdowns-incredible-sound-design/),
  [Hunt noise traps wiki](https://huntshowdown.wiki.gg/wiki/Noise_Traps)).

Takeaway: the **meter** model is self-contained and ships first; the **noise**
model is richer and more on-theme for an extraction game but needs the noise
system. Tarkov shows they can be one mechanic (weight → drain + loudness).

## Graybox sketch
Smallest version that proves the decision is live — **meter-only** (no noise
dependency):
1. Add `sprint_enabled` + a held sprint action. While held and `meter > 0`,
   multiply `max_speed` by `sprint_speed_mult` (~1.6×) in `step_velocity` (reuse
   the existing `_exposure_speed_mult` multiplier pattern — same slot, new factor).
2. Drain `meter` while sprinting, refill while not; at 0, force-release sprint.
3. A bare HUD bar for the meter (greybox `ColorRect`, mirroring the dive-clock
   meter).
4. One opposition that makes the choice bite: pair it with the L2 spawn-room
   pursuer — sprint to open a gap, but the cap means you must reach the door
   before it empties. If players just hold sprint forever, the cap is too high; if
   they never sprint, the cost is too high. That tension *is* the test.

If the meter version reads as fun, add the noise fork once a noise-emit contract
exists, and segment the two in RG2.

## Open questions
- **Cost-model choice (Director call — fun/tone).** Meter, noise, or both? Meter
  is shippable now and reads as a pacing/skill tax; noise is more thematic
  (extraction stealth) but gated on an unbuilt system and risks being invisible if
  no sound-aggro zones are nearby. **Recommendation:** ship **meter-only** as the
  M2 graybox to validate "do I run?" as a live decision, and treat **noise** as a
  fast-follow once the noise→aggro system lands — then offer `both`.
- **Hard dependency (flag for Director).** The noise fork **cannot** be built
  until a noise-emit / noise-listen EventBus contract and at least one listener
  (sound-aggro zone) exist. Should noise-sprint be scheduled *with* the sound-aggro
  zone work as a bundle, or strictly after?
- **Sprint vs. throw/aim interaction.** Does sprint cancel aim (forcing the
  stop-to-throw beat) or coexist with it? Affects how flee-vs-fight reads.
- **Empty-on-zero feel.** Hard stop to walk, or a sluggish over-exert penalty
  (Tarkov-style) that punishes redlining? The latter is harsher but discourages
  "mash sprint to empty, repeat."
- **Does sprint feed exposure (R3)?** Unifying sprint-noise with the Heat model is
  elegant but couples two systems — worth it only if R3 is on by default.
