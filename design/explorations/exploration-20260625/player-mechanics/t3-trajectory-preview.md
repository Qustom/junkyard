# Trajectory Preview
**Category:** Deepening the throw

## The mechanic
A faint line (or dotted arc) drawn from the player along the current `aim` vector,
showing where a thrown item will go *before* you commit. Today a throw is a gamble:
you point, click, and watch a straight projectile fly until it hits a hazard, a wall,
or runs out of `_max_range`. The preview turns that gamble into a **plan** — you can
line up a pursuing R1 hazard at range, judge whether a wall is between you and it, and
not waste the consumed item on a miss (a real cost: a kill *consumes* the item, a miss
re-drops it where it lands, often deeper/worse-positioned).

It is pure graybox QoL — no new verbs, no new state — but it **shifts the skill
expression**: less twitch execution (can I flick the cursor to the moving target?),
more spatial planning (which item, from where, at what moment?). That trade is the
design tension, not a free win (see Open Questions).

## What exists today
`L6` already decoupled `aim` from movement: KB/M aim = cursor-relative unit vector,
controller aim = right stick, with a `resolve_aim()` arbiter, and the `Nose` marker
rotates to `aim`. So **there is a direction indicator** (the nose points where you'd
throw) — but **no reach or path indicator**. The thrown projectile flies straight
(`thrown_item.gd`: `global_position += _dir * _speed * delta`) until `_max_range` or
a `body_entered`. What's missing to draw the line: a short overlay that reads the same
`player.aim`, `throw_speed`, and `throw_max_range` the spawn uses, and (for partial
modes) optionally raycasts the world(2)|hazard(16) mask the projectile already collides
against, drawn as a fading dotted polyline.

## How to fit it in
- **Must mirror whatever throw depth ships.** Straight throw today → a straight
  segment. If charged throw (`t1`) ships, line **length scales with charge**. If arc
  (`t2`) ships, the preview is a real ballistic curve sampled from item weight
  (`junk_item.gd`). If bounce (`t4`) ships, reflect off the first `world` body. The
  preview is a *read* of the same physics the projectile runs — keep it one shared
  helper so they can't drift (the Angry Birds lesson: static-drawn dots lie the moment
  a dynamic element bends the path).
- **The tension knob: how much to show.** Full path-to-impact removes the gamble
  entirely. Partial preserves it: (a) **direction-only** short stub, (b) **fades with
  distance** so far throws stay a judgment call, (c) **no impact marker** (show the
  path, not the guaranteed hit). Recommend distance-fade partial as the default feel.
- **Readability over busy bands.** Faint, single-color, thin dotted; must survive
  high-contrast band palettes and hazard clutter — outline/low-alpha, not a bright line.
- **`RunConfig` knob + telemetry.** Add `throw_preview` (off / partial / full),
  default **off** to preserve the all-off baseline fingerprint and make it a clean A/B.
  Telemetry: tag existing `throw_missed` / `throw_killed_hazard` rows with the preview
  mode so the gate can measure hit-rate and throws-per-kill across modes.

## Research (cited)
Angry Birds' dotted trajectory is the canonical "helpful preview" — players note it's
accurate *until* a teleporter/trampoline bends the path, i.e. previews are honest only
when they model the real physics (key lesson for `t2`/`t4`). Cyberpunk 2077's grenade
arc lets you bounce around corners "with luck and skill" — evidence a preview can aid
without erasing skill. Accessibility research frames aim aids as removing barriers for
players with motor/perceptual limits without necessarily lowering the challenge ceiling,
supporting a **configurable** (off/partial/full) approach over a one-size default.

## Graybox sketch
Smallest version: a `_draw()` overlay on the player drawing ~6–10 fading dots along
`player.aim * throw_max_range`, single low-alpha color, no impact marker, no raycast —
direction + reach only. Gated behind `throw_preview != off`. Ships before any arc/bounce
and stays a thin read-only layer those later add to.

## Open questions
- **Full vs partial — skill-vs-accessibility — FLAG FOR DIRECTOR.** Full preview makes
  throwing reliable (good for a frustrated tester, the RG3 "clunky controls" complaint)
  but may trivialize the throw-to-kill risk that gives the verb weight. Partial keeps
  the gamble. Recommend shipping all three as a `RunConfig` knob and letting the
  playtest gate decide the *default* on hit-rate + fun data — but the default is a
  fun/tone call the Director owns, not Claude.
- Does the preview update only while a charge is held (`t1`) or always-on? Always-on is
  simpler but adds permanent on-screen clutter.
- Should it raycast (truncate at the first wall) or always draw full reach? Truncating
  is more honest but edges toward "full" assistance.

## Sources
- [Angry Birds trajectory dots accuracy thread](https://www.angrybirdsnest.com/forums/topic/trajectory-dots-not-always-right/)
- [Aim preview for projectile trajectory (Unity)](https://discussions.unity.com/t/aim-preview-for-projectile-trajectory/26841)
- [Grenade trajectory indication discussion (Frontier)](https://forums.frontier.co.uk/threads/grenade-trajectory-indication.585728/)
- [UX Design: Game accessibility features design (Game Developer)](https://www.gamedeveloper.com/design/ux-design-game-accessibility-features-design)
