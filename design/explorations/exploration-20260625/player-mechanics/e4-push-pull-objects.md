# Push / Pull Objects
**Category:** Interaction & environment verbs

## The mechanic
A verb that lets the player **physically reposition movable world objects** — shove a scatter crate, drag a wrecked hull, slide a barrel. Uses:
- **Build a chokepoint:** wedge cover into a corridor mouth to funnel a pursuer onto your aim line.
- **Block a pursuer / barricade:** push a heavy object into a doorway to buy seconds against the R1 chaser under the dive clock.
- **Weigh down a plate:** shove an object onto a `6-weight-plate` so *it* trips (or holds) the trigger instead of your over-heavy body — solving the plate without dropping your haul.
- **Make cover:** drag a crate out into an open-field arena (`b1`) to create a break-LOS spot where the generator put none.

It is the spatial-layer cousin of the inventory verbs (`i1`–`i6`): instead of arranging your *bag*, you arrange the *room*.

## What exists today
**Honest read of `player.gd`:** the player is a `CharacterBody2D` driven by `move_and_slide()` on a target velocity (`step_velocity`). `move_and_slide` already pushes `RigidBody2D`s it collides with, but with **default mass-ratio physics** — there is no deliberate push verb, no grab, no controlled drag. Aim is decoupled (mouse / right-stick) and the throw seam reads `aim`; nothing reads "object I'm shoving."

**Movable objects do not exist.** Cover today is **static** — `b1` stamps cover as non-walkable WALL atlas cells / collision blockers baked into the arena; `e5` rubble is a generation post-pass, also static geometry. There is no movable-object class, no mass data, no "pushable" interactable.

**Missing:** (1) a `Pushable` object class (RigidBody2D *or* a grid-snapped body) with mass/footprint; (2) a push input path (hold-to-push via collision, or a grab-and-drag mode); (3) re-marking walkability so pathfinding sees the moved object; (4) a RunConfig knob + telemetry.

## How to fit it in
**Object model — two routes.** (a) **Grid-shove (Sokoban-style):** the object snaps to band cells; an `interact`-adjacent press shoves it one cell if the target cell is free. Deterministic, legible, no physics surprises, trivially re-markable for pathfinding. (b) **Physics-push:** a `Pushable extends RigidBody2D` that `move_and_slide` pushes continuously while you lean on it; mass tunes how hard. Juicier, emergent (a shoved barrel can roll onto a plate), but needs continuous nav re-marking and risks chaos.

Given the open-field/cover fiction and the existing physics-driven player, **lean physics-push for feel**, with mass high enough that pushing is slow and deliberate (a setup *cost*, not a free reposition).

- **Cover (`b1`/`e5`):** promote a *subset* of scatter cover from baked WALL cells to `Pushable` bodies (the rest stay static so the arena keeps its shape). Density knob shared with `cover_density`.
- **Weight-plate (`6`):** the plate already reads body-on-plate; a `Pushable` with mass counts as weight — push an object on to arm/hold it without dropping your bag. Direct, satisfying synergy.
- **Conveyor consistency (`3`):** a `Pushable` is "any body," so the conveyor's `hcv_force` must apply to it too — **same push semantics**. A belt carries a shoved crate downstream; push *against* a belt to park cover. Reuse the conveyor's per-frame force accumulation, do not invent a second force path.
- **Pursuer (R1):** a barricaded doorway should cost the chaser pathing time (re-mark the moved object's cells as blocked so R1 re-routes) — that *is* the payoff.
- **Dive clock:** pushing is slow → it spends the clock. Good: barricading is a push-your-luck trade (seconds now for safety now vs. extraction time).

**Control mapping:** hold-to-push (walk into it, it moves while you push — no new button, reads naturally) is the M1.5 fit. Grab-and-drag (an `interact`-style latch that lets you pull/reposition precisely) is a richer later variant but adds a mode + input. Recommend hold-to-push for graybox.

**RunConfig + telemetry:** `pushable_enabled=false` default (all-off reproduces baseline — no object is promoted from static). Knobs: `pushable_mass`, `pushable_cover_fraction`. Telemetry: `pushable_shoved` count, plate-armed-via-object, barricade-built events.

## Research (recently)
Two lineages. **Sokoban (1981)** — boxes pushed (never pulled), one at a time, the whole genre is about avoiding deadlock; the *soft-lock risk is the genre's defining hazard*, directly relevant to our "block the only path" worry ([Sokoban — Wikipedia](https://en.wikipedia.org/wiki/Sokoban), [Pushing Blocks — Demaine](https://erikdemaine.org/pushingblocks/)). Variants matter: classic = one-cell shove; **PushPush** (icy) = slide-till-blocked — our conveyor/ice tiles are exactly that frictionless model. Practitioners note **rigidbody physics is a poor fit for *deterministic* block puzzles** (grid logic is cleaner) — so if we want puzzle-reliable plate solutions, grid-shove; if we want emergent action-feel, physics ([Unity: approaches to 2D sokoban](https://discussions.unity.com/t/approaches-to-2d-sokoban-block-pushing/794684), [box pushing from scratch](https://dev.to/thormeier/let-s-build-a-box-pushing-puzzle-game-from-scratch-5458)). **Immersive-sim / top-down action** (Hotline Miami lineage) treats shovable furniture as emergent barricading rather than puzzle pieces ([best top-down shooters](https://www.allkeyshop.com/blog/best-top-down-shooter-games-top-v/)) — that's our barricade use, with the soft-lock caveat from Sokoban as the thing to design against.

## Graybox sketch
One `Pushable` crate in a corridor band. Walk into it → it slides (physics-push, high mass = slow). Shove it across the corridor → R1 pursuer must re-route (cells re-marked blocked), buying you time. Second beat: a `6-weight-plate` one cell off-path — shove the crate onto it to hold a gate open while you walk light past. A tinted `ColorRect`/box, no art. Knob to disable (baseline = static cover).

## Open questions
- **Physics-push vs. grid-shove (effort/feel — Director).** Physics is juicier and reuses the player's existing `move_and_slide`; grid-shove is deterministic, easier to re-mark for nav, and dodges most soft-locks. Recommend physics for graybox feel, but flag that plate/puzzle *reliability* may push us to grid later.
- **Soft-lock / block-the-only-path (fairness — Director).** A player (or a shoved object on a conveyor) can wall off the *only* route to the gate → unwinnable run. Mitigations: only promote cover where a `clear_lane_guarantee` route survives; cap pushables so a path always exists; allow pull as well as push so the player can undo. Needs a fairness ruling before it ships beyond graybox.
- **Pathfinding around moved cover (effort).** Physics-push needs continuous nav re-marking (cost per frame the object moves); grid-shove re-marks once on settle. How much does R1's pathing tolerate dynamic obstacles? Verify at the fun gate.
- **Does it trivialize the pursuer / the plate?** A free barricade could neuter R1; a free plate-weight could neuter the greed-gate's whole point. Tune mass (slow = real cost) and clock spend; defer the "is it too strong" call to playtest.
- **Pull as well as push?** Pull enables precise placement and soft-lock recovery but needs a grab input. Recommend push-only for graybox, pull as the documented escape-hatch variant.
