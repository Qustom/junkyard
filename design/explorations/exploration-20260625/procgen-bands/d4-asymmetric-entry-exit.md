# Asymmetric Entry/Exit Placement (organizing principle)
**Category:** Layout-organizing principles

## The principle
Where you *spawn* and where you *extract* are two independent points on the band
graph, and the **distance/topology between them reshapes the same layout** without
touching a single piece. Co-locate them (extract == near entry) and the band is a
**there-and-back**: dive out to the loot, then haul it back through rooms you've
already cleared. Push them apart (extract on the far side) and it becomes a
**one-way cross-map** push: every step forward is committed, no retreat to safety.
The room contents are identical; the *route shape* — and therefore the risk
profile — is completely different. This is a multiplier on every base archetype
(maze, hub-and-spoke, caverns): each can be run "loop-back" or "cross-map."

## How it fits THE FAR YARD bands
Extraction games live or die on the geometry of the exit. As-built, the band has a
deterministic **entry piece at the origin** (`band.entry_piece`, catalog index 0,
no RNG) and a **`deepest_piece`** at the end of the linear spine
(`band_generator.gd`). E1's current recommendation places **one gate near spawn**,
hand-authored — which is implicitly the *there-and-back* shape (loot is deep, exit
is shallow). This principle promotes that implicit choice to a **first-class,
seeded config axis**.

The dramatic case is the **loaded return trip**: the player is at `deepest_piece`,
inventory full (D1 slots), the dive clock (A3) ticking — and now must traverse
`dist_to_gate` hops *back* through rooms that, if return-aggro is on, have
re-populated or re-awoken. That converts the existing `DepthGrader.dist_to_gate`
field (already a real reverse-BFS, lines 56–76) from cosmetic into the core
tension number. Conversely a **far exit** makes the band a one-way gauntlet:
cheaper to author (no backtrack), but removes the "do I risk the walk home?" beat.

## Generation approach (on the real bandgen system)
The generator already exposes both anchors for free:
- **Entry** = `band.entry_piece` (origin, index 0).
- **Deep anchor** = `band.deepest_piece` (last spine piece).
- **Reverse distances** = `DepthGrader.compute_return_distance()` populates
  `dist_to_gate` per piece via BFS from entry — exactly the metric needed to score
  candidate exit placements.

A post-generation **`ExtractPlacer`** pass (no new RNG draws on the layout path, so
the B2 fingerprint is unchanged) picks the extract node from the graded band:

```
func place_extract(band, cfg) -> PlacedPiece:
    grader.grade(band); grader.compute_return_distance(band)
    match cfg.exit_topology:
        CO_LOCATED:  return band.entry_piece            # there-and-back (E1 default)
        FAR:         return band.deepest_piece          # one-way cross-map
        MID:         pick piece whose dist_to_gate ≈ max_depth * cfg.exit_dist_frac
    # validity is FREE: B2 already guarantees a connected walkable band, so any
    # placed piece is reachable from entry. No path re-check needed.
```

Determinism: the choice is a pure function of the graded graph (integer hops, ties
broken by piece index) — seed-reproducible, covered by the existing
`tests/test_bandgen_determinism.gd` style fingerprint. Re-aggro on return is a
**separate runtime concern** (an opposition/spawn behavior), not layout — see
Open questions.

## Flavor knobs
- **`exit_topology`**: `CO_LOCATED` (loop-back) / `FAR` (cross-map) / `MID`
  (fractional `exit_dist_frac` of max depth).
- **`return_reaggro`**: on/off — do cleared rooms re-populate/re-awaken behind you?
- **`multi_exit`**: 1 gate vs. several (a near "bail cheap" gate + a deep
  "high-value" gate, letting the player choose their return length).
- **Distance floor/ceiling** so a co-located exit isn't *adjacent* to entry
  (trivial) and a far exit isn't beyond a clock-feasible walk.

## Synergies & tensions
- **Multiplies every archetype** — orthogonal reshaper, the point of the category.
- **Time-pressure oppositions** (`5-alarm-spawner`, `5-rising-tide`,
  `5-the-hunter`): the loaded return trip is where these bite hardest — the alarm
  you tripped on the way *in* is now spawning on your one road *out*.
- **Depth gradients / `I` instability**: far-exit means the highest-tier loot and
  enemies sit *between* you and home; the return trip is a deliberate run past the
  worst of the band.
- **Tension with the dive clock (A3):** the return trip *spends* clock the player
  can't spend on loot. Tuned wrong, a loaded return + re-aggro is a death-spiral
  (can't fight through, can't outrun the clock). This is the central balance risk.

## Open questions
- **Re-spawn/re-aggro scope (biggest call).** Full re-population on return is a
  large systems lift (spawn-state tracking, the `5-alarm-spawner` hooks) and a
  *fun/fairness* judgment, not just data. **Recommend to the Director:** ship the
  layout axis (`exit_topology`) first with re-aggro **off** — pure geometry is
  cheap and already measurable — and gate re-aggro behind a later config knob once
  the time-pressure oppositions exist. *Vision/scope/effort — Director call.*
- **Fairness of a forced loaded return.** A mandatory there-and-back can feel like
  padding ("I already cleared this"). Mitigations: `multi_exit` so the long return
  is *opt-in* for more loot; shortcut doors that open one-way on the deep side. Is
  the return a feature or a chore? *Fun — Director playtest call.*
- **Does co-located vs. far change the M1 E1 recommendation?** E1 currently pins
  one near-spawn gate as a *fixed control* for the fun gate. Promoting exit
  placement to seeded config adds run-to-run variance that could confound that
  read — recommend keeping E1's fixed control and introducing this axis only after
  the extract tension is proven. *Scope — Director.*
- **MID-exit pathing quality.** On a branchy band (R4) a `MID` exit by
  `dist_to_gate` could land on a dead-end stub; may need a "prefer spine" tiebreak.
