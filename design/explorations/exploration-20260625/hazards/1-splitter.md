# Splitter
**Category:** Pursuers & movement enemies

## The idea
A slow, soft pursuer that, **when killed, divides into two smaller, faster copies** — and those
copies split again (down to a minimum size), so a careless kill turns one slow problem into a
swarm of fast ones. The total threat *grows* the more you attack it.

The behavioral distinctness: the entire rest of the roster — and the throw verb itself —
trains the player that *killing is the answer*. The Splitter is the deliberate counter-lesson:
**killing is the bad default.** It makes the player ask "should I kill this at all?", which is
the single most on-theme question in THE FAR YARD ("an engineer, not a soldier"; "avoidance is
always viable"; deep things "can only be evaded, not killed cleanly"). It forces *restraint*
and *routing* over the reflexive throw.

## How it fits THE FAR YARD
- **Throw:** this is the enemy that *punishes* the throw verb. Throwing an item to kill a
  Splitter spends a sale item **and** makes things worse — a perfectly inverted incentive. It
  teaches that the throw is a scarce, situational tool, not a default, which protects the whole
  push-your-luck economy from "just kill everything."
- **Move / extract:** because killing backfires, the answer is *out-run / out-route* — which
  feeds the dive-clock pressure (evading costs time but keeps the swarm from forming). The
  player who panics and throws gets buried; the player who keeps moving and banks survives.
- **Systems reused:** `HazardEntity` with a `tier`/size field. On death (throw-kill →
  `queue_free`), instead of just freeing, spawn 2× child Splitters at the next size down with
  higher speed, until `tier == min` (a true kill). Spawns reuse the band container parenting.
  Knob group `spl_*` (`spl_split_count`, `spl_min_tier`, `spl_child_speed_mult`,
  `spl_child_scale`), off by default. **Caution:** spawn cap to prevent runaway counts.
- **First appears:** Band 2 (Temporal/Lateral edge) — once the player is comfortable killing,
  introduce the thing that punishes it. Thematically it suits the "stranger entities" tier.

## Graybox sketch
A large slow circle. On throw-kill: free it, spawn 2 half-size circles at 1.5× speed offset
left/right of the death point, each one tier smaller. At `min_tier` a kill is final (no spawn).
Hard cap on live Splitter count (e.g. 8) to keep the greybox honest. Smallest proof: one big
Splitter and the throw — does the player *feel the regret* of the first split and start trying
to avoid instead? That regret is the entire design.

## Synergies & counters
- **+ environmental kills:** if a Charger's overshoot or a pit can kill a Splitter *without*
  splitting it (or split it into a corner), that becomes the clever-engineer answer. Worth a
  rule: "only direct throws split; environmental death is clean." **Strong, on-theme.**
- **+ tight rooms:** splitting in a corridor is far worse than in open floor — geometry-aware
  dread.
- **Counters:** *don't kill it* — out-route it (primary); kill it cleanly via environment
  (clever); or commit fully and kill every fragment to zero (expensive, sometimes correct).

## Open questions
- Should *every* death split, or only the throw (so environmental/Charger kills are clean)? The
  "only direct kills split" rule is more interesting and more on-theme. **Recommend
  throw-splits-only; flag to Director.**
- Min size + spawn cap are the runaway-safety knobs — get them wrong and the greybox swarms to
  a framerate problem. Must cap. **Technical, but the *feel* of the cap is a Director tune.**
- Do split children inherit a fraction of the parent's "value as a target" (any reward for
  clearing them), or is clearing pure cost? Pure-cost best teaches avoidance. **Recommend
  pure-cost — Director confirms.**
- Is there ever a reason to *want* to split it (e.g. fragments are individually harmless and
  block a Charger)? Emergent, possibly too clever for greybox. **Defer.**
