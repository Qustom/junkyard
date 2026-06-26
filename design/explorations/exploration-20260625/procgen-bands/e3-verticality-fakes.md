# Verticality Fakes (generation flavor)
**Category:** Generation flavors (applied on top of any archetype)
**Date:** 2026-06-25

> Procgen-flavor exploration only. Pseudocode is illustrative against the real as-built `BandGenerator` API; no production code, no contract widening, no branch. A *flavor* re-skins/re-wires connections on top of any base archetype (critical-path, hub-and-spoke, caverns) rather than defining the room shape itself.

## The flavor

Ledges, pits, and one-way drops that **imply height in pure 2D top-down**. A player walks to the lip of a ledge and *drops* to the level below — the camera never tilts, but the art (a cast shadow, a darker lower band, a fall animation) and the collision sell a height change. The load-bearing consequence is **one-directional flow**: a drop you can fall *down* but not climb *back up*. A band laced with drops stops being freely reversible space and becomes a set of tiers connected by commit-points. This is a flavor, not an archetype: you take any base layout and convert *some* of its socket connections into one-way drop edges.

## How it fits THE FAR YARD bands

One-way flow renders the extraction loop's core tension as geometry. GDD §6 ("push deeper or cash out") becomes literal: dropping to a lower tier **commits** you — you can't trivially backtrack to the entry gate the way you came, so the safe exit must be *found*, not retraced. This pairs naturally with an **asymmetric entry/exit** (drop in near the top, extract via a gate on a lower tier or a found route home) and tightens the dive clock — every drop spends route options. Falling *toward* depth also matches the "diving through portals into deeper bands" fiction.

The pixel-art/top-down constraint means no real Z exists: height is faked entirely with **art layering + collision**. A drop edge is a one-way doorway (you pass through descending, a wall ascending) dressed as a ledge with a shadow and a short fall tween. Oppositions host richly: the **Leaper** (`1-leaper.md`) *ignores* drops — it can leap back *up* a ledge you used to escape, the one pursuer a drop won't shake. The **throw verb** (L6) gains a vertical read — throw loot or a lure *down* a pit ahead of you, or throw across a pit at a pursuer stranded on the far lip.

## Generation approach (on the real bandgen system)

Drop edges are injected as **directed sockets**. Today `_try_attach_piece` (`band_generator.gd:141`) mates on `ZoneSocket.opposite(dir)` and the connectivity flood-fill (`is_band_connected`, line 477) treats every doorway as bidirectional. A drop is a socket flagged **one-way** (a dormant `is_drop` meta on the `Sockets` marker, read alongside `dir`/`width_cells` in `_read_piece`, line 393): pieces still mate normally on cells, but the *seam* between them is a directed edge — passable N→S only, walled S→N.

Algorithm sketch (one `_generate_once` pass, line 84):
1. Run the chosen base archetype unchanged (spine, hub, etc.).
2. After placement, **promote** a seeded subset of seams to drops: for each candidate seam, `RNG.randi_range` against a `drop_chance` knob decides if it becomes one-way (descending toward greater `depth_index`). Same draw site/order discipline as the R4 branch hook (`band_generator.gd:308-329`), so the all-off default (`drop_chance == 0`) never draws and reproduces the current fingerprint.
3. **Guarantee traversability forward**: connectivity must still hold *with directed edges*, so the flood-fill becomes a directed BFS from entry; the gate must remain reachable *descending*. A reverse pass (`DepthGrader.dist_to_gate`, `depth_grader.gd:56`) already computes return distance — if a one-way promotion would strand the only gate, reject that seam and keep it two-way.

Selling height is presentation, not layout: a `world`-layer collision strip on the up-side of the seam (the ledge wall), a cast-shadow sprite, and a brief fall tween on cross. Fully integer-cell + seeded, so `(seed + config)` stays byte-reproducible (`tests/test_bandgen_determinism.gd`).

## Flavor knobs

- **Drop frequency** — fraction of seams promoted to one-way drops (`drop_chance`); 0 = neutral baseline.
- **One-way vs two-way mix** — some ledges climbable (a ramp piece nearby) vs. hard commits.
- **Drop "height"** (visual) — shadow depth + fall-tween length; small step vs. sheer cliff (cosmetic, no layout cost).
- **Pit-as-hazard vs pit-as-shortcut** — does a drop fast-track you toward depth/loot (reward), or is the *pit itself* a gap-hazard you fall into and lose the haul (threat)?

## Synergies & tensions

- **+ Critical-path / asymmetric exit** (`a4`): drops make the spine genuinely one-way, so detours off it become true commitments and the cash-out walk-home is non-trivial.
- **+ Leaper** (`1-leaper.md`): the marquee pairing — the pursuer that defeats your drop-escape, forcing a *direct* answer (throw/dodge) where geometry fails.
- **+ Collapsing floor** (`3-collapsing-floor.md`): nearly the same one-way fiction by a different mechanism — a collapse *creates* a drop edge dynamically; together they make a tier you can only descend from.
- **Tension — readability.** The single hard problem: in flat top-down, is the drop *obviously* a one-way ledge and not a wall or a decorative pit? If players don't read "I can go down here but not back," the commit feels like a bug, not a choice.

## Open questions

- **Selling height convincingly** — can shadow + fall-tween + a lower-tier palette band read as "down" without a camera tilt or parallax we don't have? *Highest-risk fun/vision call; needs a graybox readability playtest before committing scope. Flag to Director.*
- **Collision-authoring cost** — directed one-way seams aren't in B1's piece format; authoring drop pieces (ledge-up wall + open-down) and a directed connectivity check is real effort beyond the dormant `is_drop` meta. *Scope/effort call.*
- **Pit-death vs. wall-only** — mirrors collapsing-floor's open Q: does falling into a *gap* kill/cost the haul, or is the drop always a safe descent? *Recommend safe-descent for drops (the commit is the cost), reserve pit-death for explicit hazard pits; fun call.*
- **Stranding safety** — the directed-BFS reachability guard must never leave a required gate unreachable. *Placement-rule, small effort, but must be proven by a determinism + reachability test.*
- **Does it earn its keep over collapsing-floor?** Both produce one-way flow; verticality adds the *art* of height for more authoring cost. *Director scope call: flavor vs. hazard as the cheaper path to the same tension.*
