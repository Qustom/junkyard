# Sentry
**Category:** Ranged & projectile enemies

## The idea
A **stationary** emplacement that watches one fixed lane (a straight corridor of clear line-of-sight) and fires a fast bolt down it the moment the player crosses into that lane. It never moves, never chases, and only threatens the column of space directly in front of it. Its behavioral distinctness is **lane denial**: unlike the pursuer (which converts the whole room into a "keep distance" problem) or the lobber (which punishes standing still), the Sentry makes a *specific line on the floor* lethal while leaving the rest of the room totally safe. The skill it forces is **route reading** — recognize the firing lane, cross it on the gap between shots (or not at all), and decide whether the loot in the lane is worth the timing. It turns a room into a puzzle of "where is it safe to stand," which no other enemy in the set does.

## How it fits THE FAR YARD
It directly taxes the **move** verb against the **extract-before-timer** clock: the safe route around a Sentry's lane is longer, so it spends light/time (the A3 dive clock, `dive_clock_changed`), making "push deeper for better junk vs. extract now" sharper. High-value junk placed *in* the lane (B3 `JunkPlacer` already depth-scales placement) becomes a deliberate risk-reward grab. It reuses the existing distance/line test pattern the K5 hazards and R1 pursuer use (`scenes/hazards/`), is pure run-state, knob-gated, and never feeds `fingerprint()`. The bolt is a fast projectile reusing the L1 thrown-item projectile lifecycle. First appears in **Band 1 (Near)** as a literal rusted automated gate-sentry — believable junkyard tech — and gets weirder by band (Band 3: fires when you *look away*; Band 4: the lane is non-Euclidean).

## Graybox sketch
- A static square (the Sentry, on layer `hazard`) with a **drawn lane rectangle** showing its firing column (telegraph; always visible so the player can read it).
- States: `IDLE` (lane empty) → `WINDUP` (player center enters lane: lane flashes for `windup_ms ≈ 350`) → `FIRE` (spawn a fast bolt straight down the lane) → `COOLDOWN` (`cooldown_ms ≈ 1200`, can't fire) → `IDLE`.
- Bolt = a small fast projectile; contact in the lane routes to `GameState.fail_run(&"death")` behind a `sentry_kills` toggle (mirror `r1_catch_kills`).
- Tuning knobs: `sentry_windup_ms`, `sentry_cooldown_ms`, `sentry_bolt_speed`, `sentry_lane_length`. The windup + cooldown gap is the whole game — it must be crossable.

## Synergies & counters
- **Throw counter:** a thrown item (L1, mouse-aimed) that hits the Sentry destroys/disables it — spend sale value to permanently open a lane. Clean, readable use of the throw verb.
- **Hazard combo:** a Sentry covering the only gap past a pursuer (R1) creates a real pincer — wait for the cooldown *and* dodge the chaser.
- **Counters without throwing:** time the cooldown gap; break the lane by routing through a doorway; bait the windup then back out.

## Open questions
- **Does the lane fire on the player's center crossing, or any part of the player body?** Center is more forgiving and readable; body-edge is meaner. (Fun call — Director.)
- **Should the lane telegraph always be visible, or only light up on windup?** Always-visible = pure route puzzle; reveal-on-windup = a "learn the room" surprise that may feel cheap on first death. (Vision/tone call — Director.)
- **Is permanent throw-disable too strong** — does it make Sentries trivial loot piñatas, or is "spend an item to open a route" exactly the intended economy? (Scope/fun — Director; resolve at a fun gate.)
