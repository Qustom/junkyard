# Symmetry (generation flavor)
**Category:** Generation flavors (applied on top of any archetype)

## The flavor
Symmetry is not a layout — it is a *transform discipline* laid over whatever the
base archetype already produced. After the archetype lays out its pieces, the
flavor demands the result obey an order: **mirror symmetry** (reflect the band
across one or more axes, like a cathedral nave) or **rotational symmetry**
(replicate a wedge N times around a center, like a clock face or a fan). The
read is immediate and pre-verbal: a symmetric space looks *built* — placed by an
intelligence — while a fully asymmetric space looks *grown, weathered, wild*. The
same archetype can therefore ship as "deliberate" or "feral" purely by dialing
this flavor.

## How it fits THE FAR YARD bands
Bands are *every junkyard*, so they range from human-engineered strata to alien
deep-band weirdness. Symmetry is a cheap, legible signal of **who built this
place**: a high-symmetry band reads as a constructed installation (vaults,
foundries, ritual halls); low symmetry reads as accreted scrap, organic decay, or
alien growth. Under the dive clock this is a *gift to readability*: a player who
clocks "this band is mirrored" can predict the far half from the near half —
where the matching loot alcove sits, where the twin of that turret will be. That
predictability is the danger, too. **Symmetric danger is fair danger**: if a
hazard or opposition sits at (x, y), its mirror sits at (-x, y), so the player who
survived one encounter is genuinely prepared for its reflection — but a designer
must *want* that, because it halves novelty. Symmetry pairs naturally with depth
gradients when the axis aligns with the depth axis: **rotational symmetry around
the entry composes cleanly with concentric/radial depth** (each wedge crosses the
same depth rings), while a mirror axis *along* the spine keeps deep == far on both
halves. A mirror axis *across* the spine is dangerous — it can put two entries or
fold the depth gradient back on itself, so we constrain axis choice (below).

## Generation approach (on the real bandgen system)
The generator (`systems/bandgen/band_generator.gd`) grows a frontier in integer
cell space from an entry at the origin (`_generate_once`), so symmetry is a
**post-placement reflection pass**, not a change to the growth rule — keeping the
core deterministic and untouched:

1. Run the normal grow loop to produce a **half-band (the fundamental domain)** —
   target ~`target_piece_count / axis_count` pieces.
2. **Replicate** each `PlacedPiece` under the symmetry group: for mirror, negate
   the chosen axis on `offset_cell` and `footprint_cells`/`floor_cells` and flip
   socket `dir` via `ZoneSocket.opposite`/a reflected-dir map; for rotational,
   apply the integer 90°/N-fold cell rotation about the center cell. All integer
   math, so it stays byte-reproducible.
3. **Re-run overlap acceptance** (`band.fits`) on the seam where halves meet; if
   the reflected copy collides on the axis, snap-merge the shared spine pieces or
   reject and shrink the fundamental domain by one piece, then replicate again.
4. **Break symmetry locally** for the things that *must* be unique: exactly one
   exit, the deepest reward, and a roll of `symmetry_break_rate` interior pieces
   get swapped/perturbed *after* replication, drawn from the same RNG stream so
   the break is seeded. Then run `DepthGrader.grade` + `compute_return_distance`
   on the final merged band as usual.

Determinism holds because every reflection is a pure integer function of placed
cells and every break draw is on the `RNG` autoload at a fixed site/order — the
same `(seed + config)` fingerprint contract R4/J4 already rely on
(`tests/test_bandgen_determinism.gd`).

## Flavor knobs
- **`symmetry_type`** — `none` (default; reproduces the bare archetype) / `mirror`
  / `rotational`.
- **`axis_count`** — 1–2 mirror axes, or N-fold rotational order (2, 3, 4).
- **`symmetry_break_rate`** — 0.0 (pure, eerie, samey) → ~0.3 (asymmetric accents
  that keep replay variety while preserving the *gestalt* of order).
- **`break_protects`** — set of "always unique" slots (exit, deepest reward) that
  break regardless of rate, so symmetry never duplicates the extraction point.

## Synergies & tensions
- **Flatters:** hub-and-spoke (rotational order == spoke count, instantly
  legible), grid/city-blocks (mirror snaps to the lattice for free), radial/
  concentric (rotational symmetry *is* its native order).
- **Tension — replay variety:** high symmetry + low break = every run of that
  archetype feels like the same building. `symmetry_break_rate` is the release
  valve; pair it with a *minimum* break floor in production.
- **Tension — asymmetric entry/exit:** extraction wants ONE exit, and entry is
  fixed at origin. A naive mirror duplicates the entry/exit. `break_protects` +
  forcing the entry onto the symmetry axis (so it maps to itself) resolves this,
  but it constrains which axes are legal — a real coupling, not free.

## Open questions
- **Mirror vs. rotational as the M-something default** — rotational composes with
  the depth gradient more cleanly (wedges cross the same rings); mirror is cheaper
  to author and read. Which is the house style? *Vision/tone call — Director.*
- **Is symmetric "fair danger" actually fun, or merely tidy?** Predictable twin
  encounters could read as elegant or as filler. *Fun call — needs playtest;
  recommend prototyping one mirror band against an asymmetric control at the same
  seed.*
- **Seam-merge vs. shrink-and-retry** when halves collide — merge is prettier but
  adds a special-case to the otherwise uniform stitcher; shrink is simpler but can
  undershoot the soft floor. *Effort/scope call — recommend shrink-and-retry for
  the first cut.*
- **Does enforced symmetry shrink the effective seed space** (perceptually fewer
  distinct bands) below the variety bar? *Scope — measure with a layout-diversity
  metric before committing to it as more than an occasional flavor.*
