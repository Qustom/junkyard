# Charged Throw
**Category:** Deepening the throw

## The mechanic
Hold the throw input to *wind up*: the longer you hold, the farther and faster
the item flies (and the harder it staggers). Releasing fires. The cost is a
**beat of vulnerability** — while charging you move slower (or are rooted) and
your aim is committed, so a full charge is a gamble against the danger closing in.
A tap still throws at the current baseline (a free, weak snap-throw), so charge
is *added depth*, never a tax on the common case. The skill ceiling is in the
**read**: how long dare I hold to reach that sentry / punch through that shell
before the pursuer reaches me?

## What exists today
**Fixed-force, single-frame fire.** `entities/thrown_item/thrown_item.gd` flies a
straight line at a constant `_speed` (px/s) until `_max_range` (px) or a 5s
lifetime fallback. Both values come straight from `RunConfig` knobs
(`throw_speed: float = 180.0`, `throw_max_range: float = 320.0`) and are stamped
once in `setup()` — there is **no per-throw variation at all**. The input (L6) is
a press: `throw` action (LMB / RT / Space) routes through `_unhandled_input` →
`_try_throw()` → `_spawn_thrown_item(player.aim, …)`. Aim is fully decoupled and
continuous (mouse vector or right stick, `resolve_aim`), so **the aiming half is
already rich; the *force* half is a flat constant.** Missing: any hold/charge
input, any speed/range scaling, and any feedback for "how charged am I."

## How to fit it in
**Input:** reuse the existing `throw` action as a hold. On press, start a charge
timer; on release, fire with `speed = lerp(throw_speed, throw_speed_max, t)` and
`max_range = lerp(throw_max_range, throw_max_range_max, t)`, where `t` is the
clamped, eased charge fraction. Tap (< ~80ms) = baseline throw, so muscle memory
is preserved.

**Dive clock & vulnerability:** the ~300s `DiveClock` already makes time scarce;
charging spends *real-time tension*, not clock seconds. The vulnerability beat is
a movement debuff while charging (slow to ~40% or root) — this is the trade. It
makes the *armored/shelled* "heavy throw" (`6-armored-shelled.md`) legible: a
full charge is the heavy hit that staggers/cracks a shell, so charge **is** the
counter-verb that file asks for. It also reaches **distant/lane enemies**
(`2-sentry.md`) that baseline range (320px) can't touch — closing the "I can't
answer the thing across the room" gap.

**Charge-while-moving** is the central knob (see Open Questions): full mobility
kills the trade; full root may feel punishing in a fast game. Lean toward a
*slow*, not a *root*.

**RunConfig knob + telemetry:** add `throw_charge_enabled: bool = false` (all-off
default reproduces the fixed-force baseline byte-identical, per the L0/L6 knob
contract) plus `throw_charge_time_s`, `throw_speed_max`, `throw_max_range_max`,
`throw_charge_move_mult`. Emit a `throw_charge_released` row carrying the charge
fraction so the gate sees the **charge-time distribution** — the proof of whether
players engage charge or just spam taps.

## Research (cited)
- **Spelunky** ties throw distance/arc to *item weight and momentum* (run/jump
  carry into the throw), not a charge — a different depth axis, but confirms
  "throw force should be expressive, not flat." ([Spelunky Wiki — Throwing](https://spelunky.fandom.com/wiki/Throwing))
- **TowerFall** deliberately made arrows **fire without charging**, biasing toward
  targets for "more leeway"; hold only previews the 8-way *aim*, never velocity.
  The cautionary tale: charge can become a chore if the base verb is already
  tight. Our answer: keep tap = full-speed-baseline, charge = *bonus* reach/force.
  ([Game Developer — The magic of TowerFall](https://www.gamedeveloper.com/design/the-magic-of-i-towerfall-i-depth-simplicity-community), [TowerFall Wiki — How To Play](http://towerfall.wikidot.com/how-to-play))
- **Golf/archery charge meters** are the canonical hold-for-power loop: a rising
  bar the player releases at a target point. Maps cleanly onto our hold-to-throw,
  with the rising bar as the charge feedback. ([Archery Golf — Rules](https://www.archerygolfwi.com/rules-of-the-game.html))

## Graybox sketch
1. On `throw` press, start `_charge_s`; while held and `throw_charge_enabled`,
   apply `throw_charge_move_mult` to player velocity and draw a growing reticle/
   bar at the cursor.
2. On release, `t = clamp(_charge_s / throw_charge_time_s, 0, 1)`; pass
   `lerp`-ed speed and range into `ThrownItem.setup()`. Emit
   `throw_charge_released(item_id, t, depth, t_ms)`.
3. Verify on one sentry (out of baseline range) + one shelled enemy: a tap can't
   reach/crack; a full charge can — but the pursuer covers ground while you hold.
   That single A/B is the whole "is charge a skill or a chore" test.

## Open questions (Director)
- **Charge curve:** linear, or ease-out (cheap early reach, expensive last 20%)?
  Ease-out rewards partial charges and reads better; needs a feel pass.
- **Move-while-charging:** slow (mobility-tax) vs. root (commitment). Recommend
  *slow* (~40%) — preserves the fast game while still being a real beat.
- **Auto-min on tap:** confirm tap < threshold = baseline throw (no dead "fizzle"
  on a quick press). Recommend yes; threshold ~80ms.
- **Does charge gate the heavy-throw counter,** or is heavy-throw a separate verb?
  i.e. is "crack a shell" *only* possible at high `t`, coupling this directly to
  `6-armored-shelled.md`? Scope/fun call.
- **Feedback channel:** reticle growth vs. a charge bar vs. audio pitch-rise —
  which reads fastest under pursuit? Needs the audio/UI roles.
