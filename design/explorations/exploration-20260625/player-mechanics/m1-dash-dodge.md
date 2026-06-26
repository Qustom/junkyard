# Dash / Dodge
**Category:** Movement verbs

## The mechanic
A short directional burst on a button: the player moves fast (≈2–3× walk) for a brief window (~0.15–0.25s), then a cooldown gates the next one. It is the universal "oh no" verb — close a gap, escape a corner, cross a hazard tile. It multiplies against *every* opposition already explored because all of them are ultimately spatial problems, and dash is a spatial answer.

**THE FORK — i-frames vs pure-repositioning** is the whole design call, because it decides dash's relationship to the signature **throw** verb:

- **Pure-repositioning (no i-frames).** Dash only moves you faster; you're still solid the whole time. Against a pursuer (charger/leaper/pack) it buys distance and angle; against a *projectile* (lobber, sweeping-laser, suppressor) it only helps if you out-position the shot — you can still be clipped mid-dash. Threats that come *at* you still demand the throw to neutralise. Dash **complements** throw: dash to make space, then turn and throw. The two verbs do different jobs.
- **I-frames (invuln window).** Dash makes you briefly untouchable, so it becomes a *defensive answer in its own right* — dash *through* the leaper's lunge, *through* the laser sweep, *through* the bomb blast. Now dash **competes** with throw: many threats can be solved by dodging instead of killing, and throw risks becoming the slow/optional option. This is the more "actiony" feel (Gungeon/Hades) but it can hollow out the throw's signature role.

The Hades compromise is the interesting middle: full i-frames *until* you act — dashing keeps you safe, but the moment you throw mid-dash, invulnerability drops. That preserves "dodge to survive" while making the offensive verb a deliberate, exposed commitment.

## What exists today
`player.gd` is a clean `CharacterBody2D` with a pure, testable `step_velocity()` (accelerate toward `input_dir * max_speed`, friction to zero) and a decoupled L6 `aim` (mouse / right-stick). `player_movement_stats.gd` holds three knobs (max_speed 200, accel/friction 2000). There is **no burst, no cooldown, no invuln, no i-frame/collision-layer concept** — the player has no defensive state at all. Death is binary: a hazard catch (`r1_catch_kills`) or a lethal-on-contact K5 body (`hpp_kills` etc.) ends the run instantly.

The throw verb (`thrown_item.gd`) is the *only* current answer to a threat: highlight an item, aim, throw, a hazard-layer hit `queue_free()`s the body. But throwing **consumes an item you wanted to extract** — every defensive throw is a salvage cost. So today the player has exactly one threat-answer and it is expensive. That's precisely the gap a dash fills: a *free*, repeatable mobility answer that doesn't spend your haul.

What's missing: a burst integrated into `step_velocity` (or a parallel dash velocity), a cooldown timer, an optional invuln state + (for i-frames) a temporary collision-mask change so the player ignores the `hazard` layer during the window, and EventBus signals for telemetry/FX.

## How to fit it in
- **Core verbs.** Move = unchanged left-stick/WASD. Dash = new action `dash`, **direction = movement vector** (or `aim` when standing still). Crucially **dash and throw stay independent** so you can dash *while* aiming a throw — that's where the verb-pairing depth lives (dash to reset spacing, throw on the way out).
- **Dive clock / exposure.** Dash is run-state only, like throw — never persists. Two coupling options to keep it from being a free spam button: a **cooldown** (feel-based, default), or making it cost something (a small exposure tick or a sliver of dive-clock per dash) so the push-your-luck economy still bites. Recommend cooldown-only for graybox; expose a cost knob for A/B.
- **Oppositions it counters (and the fork's effect):** pursuers (charger/leaper/pack) — pure-reposition already counters via spacing; i-frames additionally beat the leaper's *lunge frame*. Projectiles (lobber/suppressor/sweeping-laser/spinner) — **only i-frames** truly counter these; pure-reposition just relocates. Hazard tiles (popup-spikes/flame-vent/electrified-floor) — i-frames let you cross them; pure-reposition only lets you cross *gaps* between them. This asymmetry is the clearest measurable signature of the fork.
- **Input (L6).** KB/M: a key (default `Shift` or `Space`-adjacent) plus the WASD vector. Controller: a face/shoulder button (e.g. right bumper) plus left-stick. Aim stays on mouse/right-stick — dash never steals the aim channel.
- **RunConfig knob + telemetry (A/B the fork).** Add a `dash_` group, master `dash_enabled=false` (all-off = today's baseline, no dash). Knobs: `dash_distance`, `dash_duration_s`, `dash_cooldown_s`, **`dash_iframes` (bool — THE FORK)**, `dash_iframe_fraction` (Gungeon-style front-loaded vs full-duration), `dash_exposure_cost`/`dash_clock_cost`. Telemetry: `dash_used`, `dash_iframe_save` (a dash that overlapped a lethal body during invuln — the metric that proves i-frames are doing work), `dash_into_death` (dashed and still died). Compare two preset cells — `dash_iframes=false` vs `=true` — on throws-per-run, deaths-per-run, and item-spend-per-run. If i-frames ON collapses throws-per-run, that's the evidence the verbs are competing not complementing.

## Research (cited)
- **Enter the Gungeon — dodge roll:** ~0.7s roll; i-frames **front-loaded** into the first half, vulnerable in the second. Forces commitment + timing; can't act during the roll. The "precise, committed dodge" pole.
- **Hades — dash:** invulnerable for the **whole** dash, *but* acting (attack/cast/special) during it **cancels** invuln for the rest of the dash. The "safe unless you commit to offense" middle — directly maps to our dash-vs-throw fork.
- **Nuclear Throne — Roller's roll:** **no i-frames**, pure fast mover, can shoot while rolling; high risk (hard to steer, can eat several hits at once). The pure-repositioning pole — exactly the "dash complements, doesn't replace, the offensive verb" branch.
- **Risk of Rain (utility dashes):** mobility/repositioning utilities, generally **not** blanket-invuln — reinforces that "dash = spacing tool, kills come from your weapon" is a viable, well-trodden design.

Sources:
- [Enter the Gungeon — Dodge Roll (wiki.gg)](https://enterthegungeon.wiki.gg/wiki/Dodge_Roll_(Move))
- [Enter the Gungeon (Wikipedia)](https://en.wikipedia.org/wiki/Enter_the_Gungeon)
- [Hades — Gameplay mechanics (Fandom)](https://hades.fandom.com/wiki/Gameplay_mechanics)
- [Which part of the dash has i-frames? (Hades II discussion)](https://steamcommunity.com/app/1145350/discussions/0/4635986512580724515/)
- [Nuclear Throne — Mutations / Roller (Fandom)](https://nuclear-throne.fandom.com/wiki/Mutations)

## Graybox sketch
Smallest fun-test, both branches behind one bool:
1. Add `dash` action + a `dash_` RunConfig group (all-off = no dash).
2. In `player.gd`: a `_dash_timer` and `_cooldown_timer`. On `dash` pressed (cooldown ready), latch a dash direction = movement-or-aim, set `_dash_timer = dash_duration_s`. While `_dash_timer > 0`, override `step_velocity` to drive `dash_dir * (dash_distance / dash_duration_s)`; on expiry start `_cooldown_timer`.
3. **Fork toggle:** if `dash_iframes`, during the window (or its front `dash_iframe_fraction`) clear the `hazard` bit from the player's `collision_mask` so catch/contact tests can't trip; restore on expiry. With it off, the body stays solid — pure reposition.
4. Greybox feel: flash/stretch the player rect during dash; faint trail. Emit `EventBus.dash_used` and (i-frame branch) `dash_iframe_save` when a lethal overlap was ignored during invuln.

One playtest with the bool flipped between sessions answers the whole fork.

## Open questions
- **[DIRECTOR — vision/fun fork, the key call] i-frames or pure-repositioning?** This decides whether THE FAR YARD's threat-answer is *kill it (throw)* or *dodge it (dash)*. **Recommendation: ship the graybox with `dash_iframes=false` (pure repositioning) as the default**, keeping **throw the signature threat-answer** and dash a *free spacing/escape tool that complements it* — this protects the salvage-cost tension of throwing (your only kill costs you loot) and matches the extraction-sim fantasy more than a Gungeon action-feel. Then A/B `dash_iframes=true` (ideally the **Hades variant**: invuln until you throw) in a paired playtest cell. Let the throws-per-run / deaths-per-run / item-spend telemetry — not taste alone — confirm whether i-frames hollow out the throw before committing.
- Should dash cost a clock/exposure sliver, or is a cooldown enough to stop spam? (Lean cooldown for graybox; expose the cost knob.)
- Can you dash *through* a lethal K5 body's center even in pure-reposition mode (you'd die), or should the dash speed make that practically impossible? (Tune `dash_distance`/`dash_duration` so a single dash can't fully cross a hazard's lethal radius without i-frames.)
- Does dash break the L6 throw-aim feel if both want the same button on controller? (Keep dash on a bumper, throw on a trigger — verify no contention.)
- Direction source when standing still: dash toward `aim` (lets you dash where you're looking) or refuse to dash with no movement input? (Recommend dash toward `aim` so it's never dead.)
