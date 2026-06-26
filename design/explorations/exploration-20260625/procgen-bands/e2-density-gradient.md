# Density Gradient (generation flavor)
**Category:** Generation flavors (applied on top of any archetype)

## The flavor
A **flavor**, not an archetype: it changes *how much stuff sits where* without
changing the base shape. The base archetype decides the topology (room-graph,
open-field, maze, lanes); the density gradient decides whether the
content — pieces, cover, junk, oppositions — is spread **uniformly** or
**clustered into pockets** with comparatively empty space between them.

Uniform density reads flat: every stretch is the same temperature, so the player
stops registering it. Clustered density creates **rhythm** — a tense, dense
pocket (cover, threats, loot) → a breather (sparse, open, calm) → another tense
pocket. That tense → breather → tense cadence is the whole point. It is the
spatial expression of pacing, and it bolts on top of *any* archetype: a clustered
room-graph, a clustered open-field, a clustered maze are all distinct experiences
from their uniform versions.

## How it fits THE FAR YARD bands
**Pacing is the deliverable.** An extraction run is a tension curve, and a flat
curve is the failure mode — either relentless (exhausting, no contrast) or even
(forgettable). Clustering gives the curve teeth: gauntlet pockets where
oppositions + cover + high-value B3 junk concentrate, separated by breathers where
the player exhales, plans, and weighs the **extract decision** against the dive
clock (A3, `dive_clock_changed`). The breather is where "cash out or push the next
pocket" actually gets asked — a uniform band never offers that beat.

The contrast also makes individual systems legible: a pocket is where the
`0-scalable-opposition-system` budget gets *spent* (a real fight with the
ambusher/patroller melee group or a ranged emitter nest), and the breather is
where the player recovers and reads the next pocket's telegraph. Rhythm matters
most in the **mid bands** — deep enough that tension is real, long enough that a
flat curve drags. Shallow bands are short enough to be one pocket; the deepest
"the yard is hunting you" bands may *intentionally* drop the breathers (uniform
high density) to feel relentless.

## Generation approach (on the real bandgen system)
The honest read (`band_generator.gd`): the generator is a socket-based room-graph
stitcher (`_generate_once` → `_try_attach_piece` → `_alignment_offset`) with **no
spatial-density field** — it grows a linear spine to `target_piece_count`. So a
density gradient is driven by a **scalar field over the spine's depth/position**,
sampled at three existing decision sites, all already seeded and deterministic:

1. **A density curve over depth.** Define `density(depth_norm)` as a low-frequency
   waveform (e.g. a summed-sine or a seeded 1-D value-noise) with K peaks (pockets)
   and K troughs (breathers). `depth_norm` already exists per piece from
   `DepthGrader` (BFS hops / `max_depth`). Seed the curve's phase/peaks from
   `band.resolved_seed` + a fixed salt (the `JunkPlacer._JUNK_SALT` pattern) so it
   never perturbs the layout RNG stream (`tests/test_bandgen_determinism.gd`).
2. **Junk density** is the cheapest hook and needs **no new code**:
   `JunkPlacer.plan()` already multiplies expected count by a per-piece factor
   (J3's `loot_density_per_area`, currently ships-off). Feed `density(depth_norm)`
   there so loot piles up in pockets and thins in breathers.
3. **Opposition density** (when the `0-*` spawner lands): scale the per-piece
   opposition budget by the same `density(depth_norm)` so threats co-locate with
   loot — the pocket is dense *and* dangerous, the breather is sparse *and* safe.
4. **Cover/piece density** (optional, biggest lift): bias `_build_weight_table`
   toward cluttered piece variants in peaks and open variants in troughs — same
   lever J4 already uses to down-weight corridors. Or, in an open-field base, drive
   a cover-scatter pass's count by the curve.

The field is the single source: junk, oppositions, and cover all read the *same*
`density(depth_norm)`, so the pocket/breather structure is coherent across systems
from one seeded curve.

**Keeping breathers alive (not dead):** floor density to a non-zero minimum, never
zero — a breather still has *some* junk, *some* navigation interest, and ideally a
**readable payload**: a safe loot stash, a Cyrus VO beat, a vista, a shortcut, or a
decision node. A breather is a *change of activity*, not an absence of it.

## Flavor knobs
- **`pocket_count` (K)** — number of tense pockets per band (curve peaks); sets
  rhythm frequency.
- **`pocket_size` / `gap_size`** — depth-span of a peak vs. a trough; long gaps =
  long breathers, narrow peaks = sharp spikes.
- **`density_contrast`** — peak-vs-trough amplitude; high contrast = dramatic
  swings, low = nearly uniform (the all-off neutral = flat baseline).
- **`breather_floor`** — minimum trough density; guarantees breathers aren't dead.
- **`channel_weights`** — *what* clusters can differ per channel: cover, oppositions,
  and loot each get a curve scale, so a pocket can be "all threat, little loot" or a
  breather can be "calm but loot-rich" (a safe stash).
- **`gradient_target`** — whether peaks ride toward the gate, the deep end, or float
  (seeded), so the climax can sit at extract or mid-run.

## Synergies & tensions
- **Pairs with open-field (b1):** clustering cover into pockets turns a uniform
  killing-field into alternating cover-thickets and exposed flats — natural sightline
  rhythm for the ranged group.
- **Pairs with critical-path / side-rooms (a4):** pockets *are* the path's beats;
  breathers host the optional side-rooms — the gradient and the topology reinforce.
- **Tension — dive clock (A3):** breathers cost time. If the clock is tight, a
  player who dawdles in a breather is punished; if loose, breathers risk feeling
  like dead air. The curve's gap_size must be tuned against `dive_clock` spend.
- **Tension — set-piece injection:** an authored set-piece wants to land *on* a
  pocket peak (max tension) — the gradient must expose "where's the next peak" so a
  set-piece can be slotted there rather than fighting the rhythm.
- **Synergy — escalation hazards (`5-*`):** a rising-tide / spreading-fire hazard
  reads best when it *chases the player out of a pocket into a breather* — the
  rhythm gives the hazard somewhere to push toward.

## Open questions
- **Breather meaningfulness (fun — Director):** the central risk. Is a low-density
  stretch a *welcome exhale* or just *boring empty floor* at our top-down pace? It
  may need a deliberate payload (stash / VO / vista / shortcut) to earn its space —
  which is content cost. Recommend prototyping a hand-authored 3-pocket band and
  playtesting the breather feel *before* building the curve generator.
- **Curve vs. authored beats (scope/effort — Director):** is a procedural density
  curve worth it, or do we get 90% of the value by authoring 2–3 fixed "pocket"
  pieces and 2–3 "breather" pieces and just *ordering* them on the spine? The
  ordered-authored fake is near-zero new code (reuses `_build_weight_table`
  weighting by depth) — recommend that first, promote to a noise field only if
  variety demands it.
- **Cross-channel coherence (design):** should cover, oppositions, and loot share
  one curve (clean, legible) or run on phase-shifted curves (a loot pocket *just
  past* a threat pocket — risk-then-reward)? Phase-shift is richer but harder to
  read; leaning shared-curve for M-scope, flag for later.
- **Determinism of the noise field:** a seeded 1-D value-noise must be pure integer
  / fixed-point at any branch-affecting site to honor the determinism contract — if
  density only drives the off-stream junk/cover salt (never the layout RNG), this is
  free; if it ever biases `_build_weight_table` it moves the layout fingerprint
  (allowed, like J4/R4, but must be intentional). Recommend keeping density on the
  off-stream channels first.
- **Interaction with short bands:** below ~K×2 pieces the curve can't fit a full
  pocket→breather→pocket cycle. Should short bands force `pocket_count = 1` (one
  spike, no rhythm) or disable the flavor entirely? Leaning auto-clamp K to band
  length.
