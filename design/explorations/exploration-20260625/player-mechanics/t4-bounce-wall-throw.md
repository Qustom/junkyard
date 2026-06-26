# Bounce / Wall-Throw
**Category:** Deepening the throw

## The mechanic
A thrown item that, instead of dying on its first wall, **reflects off the wall's
surface normal** and keeps flying. Geometry stops being the boundary of the throw
and becomes its instrument: a corner is no longer a wall that eats your junk, it's
a mirror you aim *into* to hit the enemy you cannot see. The skill ceiling is
spatial — reading a room's angles to land a shot around a pillar, off a back wall,
into a sentry tucked in a dead corner (`6-reflector.md`'s around-corner ambushers).
Mastery reward: the satisfying "impossible" kill, paid for by the discipline of a
limited bounce budget and energy loss per bounce so it never becomes a free
cross-room autohit.

## What exists today
`thrown_item.gd` is an `Area2D` flying a straight line (`_dir * _speed * delta`),
mask `world(2) | hazard(16) = 18`, resolved in `_on_body_entered`. **Today a wall
hit is a terminal miss**: any non-`hazard` body (i.e. a `world` wall) calls
`_miss()`, which re-drops the item via `EventBus.junk_dropped` and `queue_free()`s.
So the collision with walls already works — we just *consume* it as a loss.

Reflection is cheap to add. The blocker is that an `Area2D` `body_entered` gives no
contact normal. Two clean options: (a) carry a small ray/shapecast one step ahead
in `_physics_process`, reflect `_dir` via `Vector2.bounce(normal)` on a world hit;
or (b) convert the projectile to a `CharacterBody2D` and use
`move_and_collide().get_normal()`. Either yields the normal `Godot` needs.
**Missing:** the normal source, a `_bounces_left` counter, per-bounce speed/range
decay, the resolve-order guard (a bounce must NOT trip `_spent`), and the `t3`
preview drawing the reflected segments.

## How to fit it in
- **Verb:** unchanged — same aim+throw (L6 mouse-aim / twin-stick). Bounce is an
  emergent property of the projectile, not a new button.
- **Geometry:** reflects off `band_generator.gd` walls and `socket_sealer.gd` seals
  alike — any `world` body. Open band centres still reward straight throws.
- **Preview (`t3` dependency):** the aim line MUST raycast-and-reflect up to
  `_bounces_left`, drawing each segment dimmer than the last (the energy-loss tell).
  Without that preview, bounce-aiming is guesswork; t3 and t4 ship together.
- **Bounce budget + decay:** start at **1 bounce** (matches Nuclear Throne's
  bouncer, see Research). Each bounce multiplies speed/remaining-range by a decay
  factor (~0.8) so a ricochet is weaker and shorter than a direct hit — the kill
  stays a skill play, not a spam play.
- **Oppositions:** the **Reflector** (`6-reflector.md`) becomes a true duel — it
  bounces *your* throw back, so your own bounce knowledge predicts the return path.
  Corner sentries / around-corner ambushers become the canonical bounce targets.
- **RunConfig knob:** `throw_bounce_count: int = 0` (all-off default = today's
  terminal-miss baseline, per the configurable-knob contract). A `throw_bounce_decay`
  float tunes feel.
- **Telemetry:** extend `throw_killed_hazard` / `throw_missed` with a
  `bounces_used` field; add `throw_bounced` (depth, segment count, t_ms) so the gate
  can measure *how often* bounces convert to kills vs. wasted ricochets.

## Research (cited)
**Nuclear Throne** bouncer weapons are the closest prior art: rotating bullets that
bounce off walls, **bounce only once, disappear on the second wall**, and travel
slower than normal shots — exactly the "one reflection + decay + budget" tuning
proposed here. Their value is *reaching enemies regular shots can't*, which is the
fun we want. **Transistor's Bounce()** is the other lineage but chains
target-to-target rather than off geometry — a useful contrast (we want
*environmental* bounce, the spatial puzzle, not auto-chaining). The Nuclear Throne
"single bounce keeps it fair" rule is the strongest evidence for starting at 1.

## Graybox sketch
Smallest provable version: in `thrown_item.gd`, add a one-step `RayCast2D`/`bounce()`
in `_physics_process` so a `world` hit with `_bounces_left > 0` reflects `_dir`,
decrements the counter, scales `_speed`, and does **not** set `_spent`. Knob default
`throw_bounce_count = 1`. No preview, no decay-on-range — just prove that a player
can deliberately bank a throw off a back wall to kill a corner sentry and that it
*feels* earned. If that single hidden kill lands as satisfying, build t3's reflected
preview and the decay curve around it.

## Open questions
- **Bounce count:** ship at 1 (NT-proven) or expose 1–3 as an upgrade-track reward?
  More than ~2 risks unreadable spaghetti and exploit lobs. *Director call.*
- **Aim readability without preview:** is a 1-bounce shot intuitive enough to use
  *before* t3 lands, or is t4 hard-blocked on t3? Recommend treating t3 as a
  blocker for the *tuned* version, graybox can stand alone.
- **Exploit potential:** a low-decay bounce could let players spam-clear a room from
  safety around a corner — does decay + the 1-throw-costs-an-item economy
  (`_item` consumed only on kill) already self-limit this, or do we need a cooldown?
- **Reflector interaction:** if both the player throw and the Reflector use
  `Vector2.bounce`, the duel is deterministic — fun mastery, or too solvable? Needs
  a playtest read.

Sources:
- [Nuclear Throne — Weapons (bouncer bullets)](https://nuclear-throne.fandom.com/wiki/Weapons)
- [Bouncer SMG/shotgun — Nuclear Throne Discussions](https://steamcommunity.com/app/242680/discussions/0/535152511365499062/)
- [Bounce() — Transistor Wiki](https://transistor.fandom.com/wiki/Bounce())
