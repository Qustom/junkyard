# Lobber
**Category:** Ranged & projectile enemies

## The idea
A slow, low-threat entity that **arcs a projectile in a high parabola onto a target spot on the ground** — landing a telegraphed shadow/marker where the player *currently is* (or, smarter, slightly ahead of their movement), then exploding on impact after a short delay. The arc means **walls don't stop it**: the Lobber can shell you from behind cover or across a gap it can't path to. Its behavioral distinctness is that it **punishes standing still** — every other ranged threat here is about reading a line or a pattern *in the moment*, but the Lobber turns *dwelling in one place* into the mistake. It makes the player keep moving while doing everything else (looting, deciding, fighting the pursuer), which is a different cognitive load than dodging a bolt.

## How it fits THE FAR YARD
Looting (the **loot** verb) requires a pause at a junk pickup; the Lobber taxes exactly that pause, so grabbing a piece of junk becomes "grab and immediately relocate." It pressures the **extract** decision indirectly: you can't comfortably idle near a gate deciding push-vs-cash-out while shells rain. It reuses the K5 bomb's blast model (`scenes/hazards/bomb_hazard.gd` — a delayed-detonation distance test with a telegraph), just with an *arcing, player-targeted* delivery instead of a fixed placement. Pure run-state, knob-gated, distance-based (no pathing needed — the arc ignores geometry, which is the point). First appears in **Band 2 (Temporal)** as old artillery/ordnance half-buried in a war-surplus scrapyard; deeper bands make the shadow harder to read (delayed reveal, or two overlapping markers).

## Graybox sketch
- A static or slow-drifting square (Lobber, layer `hazard`) with a fire timer.
- On `FIRE`: read `player.global_position`, optionally lead it by `lead_factor * player_velocity`, draw a **landing-marker circle** on the ground there. After `arc_time_ms ≈ 900` (the "shell in flight"), detonate: blast radius distance test → `fail_run(&"death")` behind a `lobber_kills` toggle.
- Reuse the bomb's blast-radius + telegraph draw; the only new piece is target selection (player pos + optional lead).
- Knobs: `lobber_fire_period_ms`, `lobber_arc_time_ms`, `lobber_blast_radius`, `lobber_lead_factor` (0 = lands where you are, >0 = leads you — the difficulty dial).

## Synergies & counters
- **Counter (move):** the whole counter is "don't stop where the marker landed." Readable, requires no item cost.
- **Throw counter:** mouse-aimed throw to kill the Lobber stops the rain — but it's slow and low-threat, so often *ignoring it while moving* is correct; spending an item is a judgment call, which is good.
- **Hazard combo:** Lobber + Sentry is vicious — the Lobber denies the safe standing spots *between* the Sentry's lane crossings, so you can't wait out the cooldown. Lobber + pursuer forces you to keep moving toward the chaser.

## Open questions
- **Does it lead the player or just target current position?** No-lead is fair and readable but trivially countered by walking; leading makes movement-prediction a skill but can feel unfair when the lead is wrong. Recommend a small lead that scales by band. (Fun/difficulty — Director.)
- **Should the shell arc over walls (geometry-ignoring) or be blockable by tall cover?** Geometry-ignoring is its identity and reuses the distance model cleanly; blockable cover needs occlusion the engine doesn't have yet. Recommend geometry-ignoring for greybox. (Scope — Director.)
- **One Lobber or volleys?** A single slow shell teaches the verb; a 2–3 shell volley with staggered markers is the real "keep moving" pressure but risks marker-soup. (Tuning — defer to fun gate.)
