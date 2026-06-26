# Arc vs. Straight
**Category:** Deepening the throw
**Date:** 2026-06-25

> Player-mechanic exploration only. Pseudocode is illustrative against the real as-built `ThrownItem`/`JunkItem` APIs; no production code, no branch. The pitch: make the *same item property the inventory already cares about* (weight/shape) also decide how the item flies, so one stat does double duty.

## The mechanic
A throw is not one trajectory but two ends of a spectrum the **item itself** picks. A **heavy** item (or a blocky/dense shape) *lobs* — a high parabolic arc that **clears a wall** but **lands short**: short reach, vertical delivery, good for dropping past cover. A **light** item flies **flat and far** — a fast straight line that hits hard at range but is stopped by any wall in the way. Nothing new for the player to configure; you pick *which item* to throw and the weight does the rest. That makes inventory weight a *combat-and-traversal* decision, not just a sell-value-vs-slots one (`value_per_slot()`): the scrap brick you'd dump for space is suddenly your only answer to a Sentry behind a wall.

## What exists today
**Throw is purely flat and straight.** `thrown_item.gd` is an `Area2D` that moves `global_position += _dir * _speed * delta` every physics frame (line 68) until it hits a `world` wall (miss → re-drop), a `hazard` body (kill → consume), or `_max_range`. There is **no Z, no arc, no parabola** — `_speed`, `_dir`, `_max_range` are all planar. Collision mask is `world(2) | hazard(16)`, so **a wall always stops the throw today.**

**The driver does not exist yet.** `junk_item.gd` has **no weight/mass field.** What it *does* have that proxies for weight: `slot_size` (1–9), `grid_footprint` (Vector2i cells), `tier`, and `greybox_shape` (RECT/CIRCLE/TRIANGLE/DIAMOND). So "weight" is available *implicitly* (slot footprint = bulk) or could be one new `@export var mass: float`. Shape is fully present and free.

**The fake-Z problem (the honest core).** In a flat 2D collision world, "lob over a wall" has no real meaning — the projectile's `Area2D` overlaps the wall body whether it's "in the air" or not. To clear a wall you must add a **height scalar `z`** (per the Quora/Clickteam pattern below): the projectile carries `z`/`z_velocity`, follows a parabola in `z`, the **sprite draws offset upward by `z`** with a shrinking ground shadow, and **wall collision is gated on `z`** — while `z > wall_height` the projectile *ignores* `world` bodies (or only tests a footprint shadow at ground level). It lands (resolves hit/miss) when `z` returns to 0. That is a real addition to `ThrownItem`, not a tween skin.

## How to fit it in
- **Reuse weight, don't invent it.** Map trajectory off `slot_size`/`grid_footprint.x*y` (bulk → heavy) for zero new data, OR add one `mass` field. Heavy → high `z_velocity`, short ground range; light → `z≈0`, long flat range. Shape can bias: DIAMOND/TRIANGLE = aerodynamic (flatter), RECT = brick (lobs).
- **Band geometry & cover** (`e3-verticality-fakes.md`): a lob is the answer to a wall a flat throw can't pass, and it pairs with one-way drops — lob loot/lures *down* a pit, or arc across a gap at a pursuer stranded on the far lip (the verticality doc already names this).
- **Oppositions:** the marquee pairing is the **Sentry** (`2-sentry.md`) and the **Lobber** (`2-lobber.md`) — the Lobber arcs shells over *your* cover; arc-vs-straight lets you arc one *back* over a wall you can't path around. It is the player-side mirror of the enemy lob.
- **Telegraph pairing (`t3`):** an arc *must* preview its landing spot (a ground marker, same shadow vocabulary as the Lobber's landing circle) — without a predicted impact dot, a lob over a wall is a blind guess. `t3` (throw preview) is a hard dependency, not a nicety.
- **RunConfig knob + telemetry:** `throw_arc_enabled` (all-off default reproduces today's flat throw = the permanent control), plus `arc_mass_threshold`. Log per-throw `trajectory` (flat/arc), `cleared_wall: bool`, kill/miss — so the gate can measure whether arc throws are *chosen* and whether they hit.

## Research (cited)
- **Spelunky** — the proven precedent that *the item's weight drives the throw*: light objects travel "further and faster," heavies fall short; even the regular throw has "a slight arc," and aiming up throws higher/farther. Exactly the heavy-lobs / light-flies-flat split, validated as fun ([Spelunky Wiki: Throwing](https://spelunky.fandom.com/wiki/Throwing), [Spelunky 2: Bomb](https://spelunky.fandom.com/wiki/Bombs)). Spelunky's "everything measured in blocks" discipline ([Critical-Gaming](https://critical-gaming.com/blog/2009/2/17/spelunky-a-game-design-gold-mine.html)) argues arc reach should be tuned in band-cell units.
- **Worms / grenade arcs** — high-lob-over-cover is the entire verb; the landing-preview/marker is what makes a blind lob fair.
- **Fake-Z in top-down 2D** — the standard trick: a per-object height scalar, parabolic `z`, sprite offset up + shrinking shadow, and **collision gated on `z`** so an airborne projectile clears walls and only tests overlap at ground level ([Quora: top-down with platformer Z](https://www.quora.com/How-can-I-make-a-top-down-2D-game-but-with-a-platformer-scenario-in-it), [Clickteam: simulating the Z-axis](https://community.clickteam.com/threads/99409-Simulating-the-Z-axis-in-a-top-down-game)).

## Graybox sketch
Smallest version that proves arc-vs-flat is a *choice*:
1. Add `var _z := 0.0`, `var _z_vel := 0.0` to `ThrownItem`; in `_physics_process` integrate `_z` under gravity, offset `_greybox` y by `-_z`, draw a ground shadow at `z=0`.
2. In `setup()`, branch on `slot_size >= arc_mass_threshold`: heavy → high `_z_vel` + short `_max_range`; light → `_z=0` + long range (today's path).
3. **Wall gating:** while `_z > WALL_H`, skip the `world`-body miss in `_on_body_entered` (still test `hazard`); resolve hit/miss only when `_z <= 0`.
4. One test room: a junk pickup, a wall, a hazard parked behind it. Throw a light item → blocked by the wall (flat, as today). Throw a heavy item → clears the wall, lands, kills. If players reliably pick the heavy item *because* of the wall, the choice is real.

## Open questions
- **The fake-Z collision model is the key Director call.** Adding `z` + height-gated collision touches the projectile's core loop and ripples into *every* throw consumer (telegraph `t3`, telemetry, any future "thrown lure"). It is the single largest scope item here. *Recommend a strict-scope graybox: `z` on `ThrownItem` only, a single global `WALL_H` constant, no per-wall heights, no airborne enemies. Director scope call.*
- **Weight source: reuse `slot_size` or add `mass`?** `slot_size` is free and "bulky = heavy" reads honestly; a real `mass` field is more expressive but is new data on every `.tres`. *Recommend reuse `slot_size` for the graybox; promote to `mass` only if tuning demands it.*
- **Does flat-far vs arc-short stay a genuine trade?** If flat is strictly better in the open and arc only matters at walls, the choice is binary, not a spectrum. Needs the reach numbers tuned so each end *wins somewhere*. *Tuning — defer to fun gate.*
- **Can a flat throw ever clear a low wall, or is height strictly weight-bound?** Spelunky lets aim-up add arc to anything. Letting the player *choose* arc (hold a modifier) decouples it from weight and weakens the double-duty pitch. *Recommend weight-bound only (no manual arc) to keep the property doing the work; Director fun call.*
- **Marker readability with `t3`.** A lob over a wall is unfair without a trustworthy predicted-impact dot. *Hard-couple to `t3`; do not ship arc without preview.*
