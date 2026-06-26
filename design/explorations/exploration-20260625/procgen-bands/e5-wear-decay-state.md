# Wear / Decay State (generation flavor)
**Category:** Generation flavors (applied on top of any archetype)

## The flavor
A **decay modifier** takes the *same* generated layout and decides, per seed, **how
ruined it is**. Pristine, the band reads as authored: every doorway open, every room
clear. Ruined, the band is choked — rubble piles that change routes, **blocked
passages** that seal a doorway the generator opened, and **broken-wall breaches**
that punch a shortcut between two rooms the generator never connected. It is purely a
post-pass over geometry and connectivity; it adds **no new pieces and no new
archetype**. Thematically it is the cheapest, truest fit in the game: the junkyard is
*already* a ruin, so "how decayed is this stretch" is the natural axis along which the
same place feels different twice.

## How it fits THE FAR YARD bands
The same B2 spine re-skins into many felt-different runs for near-zero content cost —
direct replay value (GDD's "every junkyard" fiction). Decay alters routes **under the
dive clock**: a blocked main artery forces a costly detour deeper before extraction; a
broken-wall breach rewards the player who pokes at a dead-end wall with a shortcut back
to the entry. Tie **ruin level to band depth and Exposure** — deeper/hotter bands
generate more collapse, so escalating instability is *legible in the architecture*, not
just in enemy stats. Oppositions (`exploration-20260625/`) live on the changed routes:
rubble cuts off a pursuer's flank or *your* escape lane, and the throw verb gets a job
(clear a pile, or lob loot across a gap a collapse opened).

## Generation approach (on the real bandgen system)
A deterministic **decay pass that runs at materialisation, after
`BandGenerator.generate()` returns its `Band` and before/around `SocketSealer`** — the
same seam, same determinism rules. It draws from a **local sub-stream seeded off
`band.resolved_seed` + a fixed salt** (exactly the `JunkPlacer` pattern,
`systems/depth/junk_placer.gd` lines 56–59), so it never perturbs the layout RNG and
stays reproducible from `(seed + config)`.

Two operations, both expressed in the geometry the sealer already manipulates:
- **Block:** convert a chosen mated-doorway floor cell to WALL via the existing
  `_place_wall_cap` mechanism (`socket_sealer.gd`) — closes a connection.
- **Breach:** convert a perimeter WALL cell that abuts two pieces' floor sets into
  FLOOR (an atlas `(1,0)→(0,0)` swap) — opens a shortcut. Candidates are any
  `band.pieces[i]` floor cell whose outward neighbour is another piece's footprint WALL.

**Connectivity is non-negotiable:** after each *block*, re-run
`BandGenerator.is_band_connected(band)` (already exists, lines 477–520, FLOOR↔FLOOR
4-adjacency flood-fill from entry). **Reject any block that disconnects the band**;
breaches can only help. So entry→exit walkability holds by construction on every seed —
the same guarantee the existing connectivity test enforces.

## Flavor knobs (on `BandGenConfig` / `RunConfig`)
- `decay_level` 0.0→1.0 (pristine→ruined), ideally derived from depth + Exposure.
- `block_vs_breach_ratio` — how much it closes vs. opens.
- `rubble_density` — count of soft obstacle props (cosmetic/slowing, not topology).
- `destructible_in_run` — whether rubble is a clearable verb or a hard wall.

## Synergies & tensions
Composes with **every** archetype (it only edits connectivity + geometry) and pairs
beautifully with **set-piece injection** — a "decayed variant" of a vault is a free
content multiplier. Tensions: (1) the **solvability guarantee** must hold *jointly*
with blocks (the reject-on-disconnect rule covers it, but breaches-then-blocks ordering
needs care); (2) **player legibility** — ruined geometry must read "passable vs.
impassable" at a glance, or the player wastes dive-clock probing fake openings (an art
+ UX problem, not just generation).

## Open questions
- **Connectivity after decay (effort/scope):** reject-on-disconnect is simple and safe
  but can make `decay_level` *feel* capped (high settings get rejected down). Acceptable
  for M-level, or do we want guaranteed-alternate-route logic? *Recommend* ship the
  reject rule first; revisit only if playtest shows decay feels toothless.
- **Destructible rubble as a player verb (fun/scope — Director):** is clearing rubble a
  real interaction (cost: time/throw/tool) or purely cosmetic dressing? Big fun upside,
  but it's a new verb touching the throw system and the dive clock — flag for the
  Director.
- **Legibility (fun/art — Director):** does broken-wall-as-shortcut read without a
  tutorialized tell? Recommend a distinct breach tile/silhouette before committing.
- **Decay↔Exposure coupling (vision):** should ruin track Exposure (hotter = more
  collapse) or be independent flavor? Recommend coupling — it makes instability
  architectural — but it's a tone call for the Director.
