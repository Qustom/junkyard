# Band Procgen — Cross-Exploration Analysis
**Set:** procgen-bands/  ·  **Analyzed against:** hazards, player-mechanics, economy-extraction, hub-staging
**Date:** 2026-06-25  ·  Author: `game-director-designer` (cross-analysis fan-out; not Director-dispositioned)

> The bands are the **"where."** Every other set is a verb, a threat, a stake, or a place that
> only acquires meaning by being staged in a layout. This doc maps which band archetype is the
> natural *host* for which idea, where the band layer **contradicts** the others, and what the
> band layer must *provide* vs. *depend on* for the other four sets to land. Citations are
> `folder/file.md`.

---

## Synergies (layouts that host / enable / amplify other ideas)

The recurring pattern: an opposition or verb is only as good as the geometry it lives in.
The strongest pairings are the ones where a band archetype is the *only* place a given idea
reads as designed.

1. **Open-field-with-cover ⇄ the entire ranged opposition group + the throw verb.**
   `b1-open-field-with-cover.md` is the explicit, self-described home for the `2-*` ranged
   group: `hazards/2-sentry.md` lane control, `hazards/2-lobber.md` arcs, `hazards/2-spinner.md`
   spirals, `hazards/2-suppressor.md` setups all *require* long sightlines that a corridor band
   denies. Symmetrically it is where the mouse-aimed throw (`player-mechanics/t*`) finally has
   range to matter. This is the cleanest "archetype is the stage for a whole opposition family"
   coupling in the set — and it's mutual: cover gives the player the break-LoS counter the ranged
   entries already assume.

2. **Grid / city-blocks ⇄ ranged + the corner-counter lesson.**
   `c3-grid-city-blocks.md` *teaches its own opposition*: streets are clean firing columns for
   `hazards/2-sentry.md`/`2-suppressor.md`/`2-lobber.md`, and the building corner is the built-in
   break-LoS counter. It is the natural Band-1 teaching floorplan for "corners beat ranged."
   It also pairs with `player-mechanics/m4-vault-slide.md` (vault a block-edge to break a street
   sightline) and the throw verb (a street is a perfect long throw lane).

3. **Organic caverns ⇄ ambusher + burrower (low-sightline pursuers).**
   `b3-organic-caverns.md` exists *for* `hazards/1-ambusher.md` (the disguised-in-a-nook pounce)
   and `hazards/1-burrower.md` (deny a blobby chamber on a timer). Bad sightlines are the feature
   both need to read as fair-but-tense rather than trivial. Caverns also reward the arc-throw
   (`player-mechanics/t2-arc-vs-straight.md`) — lobbing *around* a blobby wall into a pocket.

4. **Archipelago ⇄ Leaper + Conveyor + throw-into-gap loss.**
   `b2-archipelago-islands.md` names `hazards/1-leaper.md` as its banner threat — the gap won't
   save you — and `hazards/3-conveyor-wind-tile.md` on a bridge becomes "drift shoves you off the
   catwalk." It also creates a genuine *economy of the throw verb*: a thrown item lost over a gap
   is gone (`player-mechanics/t6-recall-retrieve.md` becomes load-bearing, since you can't walk
   to fetch it). Strong, but see the contradiction on connectivity.

5. **Verticality-fakes ⇄ Leaper + collapsing-floor + one-way commitment economy.**
   `e3-verticality-fakes.md` (one-way drop edges) is the marquee pairing with
   `hazards/1-leaper.md` (the pursuer that leaps *back up* the ledge you used to escape) and is
   *nearly the same fiction* as `hazards/3-collapsing-floor.md` (a collapse dynamically creates a
   drop edge). It is also the geometric delivery vehicle for `economy-extraction/e3-one-way-commitment.md`
   — both convert "push deeper" into an irreversible spatial commit. Three docs converge on the
   same one-way-flow primitive (see Notable design info: the directed-edge seam).

6. **Asymmetric entry/exit ⇄ the loaded return trip + time-pressure oppositions + sell-location.**
   `d4-asymmetric-entry-exit.md` is the substrate for the whole "carry it home" tension:
   `hazards/5-alarm-spawner.md`/`5-rising-tide.md`/`5-the-hunter.md` bite hardest on the forced
   return (the alarm you tripped on the way in spawns on your one road out). Critically, its
   `multi_exit` knob is the **hard prerequisite** for `economy-extraction/m3-sell-location.md`
   (per-exit buyer taste) and the natural home for `economy-extraction/e5-extraction-as-objective.md`
   (a rare deep forward exit *is* the reward). `dist_to_gate` (already a real reverse-BFS) is the
   shared cost number all of these read.

7. **Set-piece injection ⇄ curated opposition combos + extraction-as-objective + lore beats.**
   `e4-set-piece-injection.md` is the universal delivery vehicle: a trap gauntlet is a hand-placed
   run of `hazards/3-popup-spikes.md`→`3-crusher-piston.md`→`3-sweeping-laser.md`; a boss arena is
   a bounded room for `hazards/5-the-hunter.md`; a mimic vault pairs `hazards/6-mimic-loot.md` with
   fat bait. It is *explicitly* the mechanism `economy-extraction/e5-extraction-as-objective.md`
   names for the special deep exit, and the home for Knowledge/Lore non-combat payouts the GDD
   currency split wants. Cheapest anti-sameness win in the whole set.

8. **Critical-path + side-rooms ⇄ gatekeeper oppositions + greed escalation + push/cash-out.**
   `a4-critical-path-side-rooms.md` is the easiest archetype to tune for extraction because each
   detour is a local opt-in bet: a branch *mouth* hosts a `hazards/1-patroller-vision-cone.md` or
   `hazards/3-crusher-piston.md` toll, the dead end holds the premium loot. It is the spatial
   frame for `economy-extraction/r2-greed-escalation.md` (the side room is the room you milk) and
   the cleanest stage for the macro push/cash-out decision.

9. **Discrete-rooms / open-floorplan ⇄ Field hazards + bounded arenas.**
   `a1-discrete-rooms-connectors.md` and `a2-open-floorplan-building.md` provide the `room_bounds`
   that Field oppositions flood into — `hazards/4-gas-cloud.md`, `hazards/4-electrified-floor.md`,
   `hazards/4-magnet-field.md` — exactly as the gas sketch already reuses L2's room confinement.
   Rooms are Actor arenas; corridors are Fixture lanes. The open-floorplan's "no safe chokepoint"
   amplifies Field hazards (no doorway to dodge into) and the throw-offence verb.

10. **Dense maze / sparse labyrinth ⇄ pursuers + throw-down-a-lane.**
    `c1-dense-maze.md` and `c2-sparse-labyrinth.md` are the canonical pursuer stages
    (`hazards/1-charger.md` lane denial, `hazards/1-pack-hunters.md` encirclement), and a single
    axis to aim makes `player-mechanics/t1-charged-throw.md` read cleanly. Sparse labyrinth's wide
    lanes restore the room the 2-cell hall denies both the throw and `player-mechanics/m1-dash-dodge.md`.

11. **Lane-based ⇄ per-lane opposition theming + read-and-commit replay.**
    `d2-lane-based.md` themes each parallel route by a different opposition flavor (a
    "patroller/sentry" lane vs. a "rising-tide/spreading-fire" sprint-or-die lane), so the player
    *reads a lane by its threat* before committing. It composes with
    `economy-extraction/r1-optional-modifiers.md` (a high-risk lane = a higher loot tier) into a
    legible risk-tiered choice.

12. **Density gradient ⇄ pacing for every opposition + escalation hazards.**
    `e2-density-gradient.md` is where the `hazards/0-scalable-opposition-system.md` credit budget
    gets *spent* (the pocket is where a real fight happens; the breather is recovery). It pairs
    with `hazards/5-rising-tide.md`/`5-spreading-fire.md` (the hazard chases the player out of a
    pocket into a breather) and with `e4-set-piece-injection.md` (the set-piece lands *on* a
    pocket peak). It is the spatial expression of pacing the other sets assume but don't supply.

13. **Radial / concentric ⇄ greed-escalation gradient + Instability bands.**
    `d1-radial-concentric.md` makes "deeper = better + scarier" the literal organizing axis,
    quantizing `depth_norm` into rings that map onto the GDD Instability `I` banding the
    `hazards/0-` Director uses for credit budget. It is the cleanest geometric model of the
    push/cash-out gradient and a natural per-ring opposition-budget gate.

14. **Hub-and-spoke ⇄ the hub/staging fiction + per-spoke commit + toll oppositions.**
    `a3-hub-and-spoke.md`'s central safe hub maps one-to-one onto the extract gate and converts
    one push/cash-out bet into a fan of legible per-spoke bets; spoke mouths host Field/Fixture
    toll oppositions. (Note the *intra-band* hub is distinct from the surface
    `hub-staging/` hub — see Contradictions.)

15. **Wear/decay ⇄ Exposure made architectural + throw/clear verbs.**
    `e5-wear-decay-state.md` couples ruin level to band depth + Exposure
    (`hazards/exposure_meter.gd`), so escalating instability is *legible in the architecture*,
    not just enemy stats. A blocked artery forces a costly detour (clock pressure); a breach
    rewards poking dead-ends. Its optional destructible-rubble verb touches the throw system
    (`player-mechanics/t*`) and pairs beautifully with `e4` (a decayed vault variant = free
    content multiplier).

16. **Carry-load ⇄ asymmetric-exit + collapsing-floor + the loaded walk home.**
    `player-mechanics/x1-carry-load-speed.md` (and its economy twin
    `economy-extraction/r3-full-bag-liability.md`) only *bites* over distance, so it is amplified
    by `d4-asymmetric-entry-exit.md` far exits and `e3`/`hazards/3-collapsing-floor.md` one-way
    routes: a heavy bag on a long, irreversible walk home with the clock draining is the synthesis
    moment. The band geometry sets the length of the leash.

17. **Levers/doors ⇄ socket model + close-door-on-pursuer in any room band.**
    `player-mechanics/e2-levers-doors-switches.md` is "a connector whose seal state is toggleable
    at runtime" — it rides the *same* `socket_sealer` geometry every room-and-corridor archetype
    (a1/a4/c2/c3) produces, and is the player-driven cousin of `e5` decay and `economy/e3`
    one-way commitment.

---

## Contradictions & tensions

1. **The "second backend" cost vs. scope is the single biggest band-layer contradiction.**
   The `0-scalable-band-generation-system.md` is honest that **only two ideas require genuinely
   new generator code**: organic caverns (CA backend, `b3`) and open-field scatter (`b1`). Both
   are flagged *each* as a real subsystem with their own determinism gotcha. Yet they are the
   sole hosts for high-value other-set ideas — `b3` is the *only* home for
   `hazards/1-ambusher.md`/`1-burrower.md`, and `b1` is the *only* home for the entire ranged
   group's intended showcase. So the cheapest archetypes (socket-native rooms/grid/lanes) host
   the *cheaper* oppositions (pursuers, traps), while the two expensive backends gate the
   *ranged and low-sightline* opposition families. The Director's "build vs. defer backends" call
   therefore silently decides *which opposition families ship*, not just which layouts.

2. **Connectivity guarantees are stressed from four directions at once.**
   The band layer's non-negotiable invariant (a walkable entry→exit path,
   `is_band_connected`) is attacked by: `economy-extraction/e3-one-way-commitment.md` (seals the
   entry behind you — needs a *guaranteed forward extract*), `b2-archipelago-islands.md` true-void
   gaps (break contiguous floor outright), `e5-wear-decay-state.md` decay blocks, `c1-dense-maze.md`
   navigation-death, and `e3-verticality-fakes.md` directed drop edges (turn the flood-fill into a
   *directed* BFS). Each individually has a mitigation (the `0-` doc's Stage-5 connectivity
   invariant, bridge-as-piece, reject-on-disconnect), but they **compound**: a one-way commit gate
   *plus* decay *plus* a far exit could jointly strand a player in a way no single doc's guard
   catches. This needs a single owner — the Stage-5 invariant — that runs *after every* reshaping
   pass and is backend-aware (carve for CA, retry for socket).

3. **Multi-exit demand vs. the single-gate reality is a hard sequencing dependency.**
   Three economy ideas hard-depend on geometry the band layer doesn't ship yet:
   `economy-extraction/m3-sell-location.md` ("inert with one gate"),
   `economy-extraction/e5-extraction-as-objective.md` (needs a second reward-bearing exit), and
   `economy-extraction/e1-extraction-cost-tax.md`/`e4-partial-extraction.md` are richer with
   choice of exit. All of them route through `d4-asymmetric-entry-exit.md`'s `multi_exit` /
   `ExtractPlacer` — which is itself only a *proposal*. So `d4` is a quiet keystone: several
   economy features are blocked until the band layer promotes exit placement from "one
   hand-authored gate (E1)" to seeded multi-exit config. This is a real build-order edge the
   producer should draw.

4. **"Layered/tiered" overlaps the BANDS-as-biomes concept — a live naming/scope collision.**
   `d3-layered-tiered.md` flags it itself: the GDD's BANDS *already are* distinct biome regions,
   so intra-band tiering risks duplicating what swapping bands gives. The `0-` doc's recommendation
   (treat distinct biomes as separate `BandProfile`s, reserve `Layered` for a deliberate 2-tier
   "front vs deep" *within* one band) resolves it on paper, but it remains a Director call on
   whether the principle earns its authoring cost. This is the band set's internal contradiction
   that most affects the others, because tiering is also how `d2-lane-based.md`,
   `e2-density-gradient.md`, and the per-tier opposition packages would be sequenced.

5. **One-way flow (e3 / collapsing-floor / e3-commit) vs. the loaded return trip (d4) can
   death-spiral.** `d4`'s own central balance risk is "loaded return + re-aggro = can't fight
   through, can't outrun the clock." Stack `player-mechanics/x1-carry-load-speed.md` (heavy = slow)
   on top of `economy-extraction/e3-one-way-commitment.md` (no retreat) on top of
   `hazards/5-rising-tide.md` (the route floods) and the geometry can manufacture an unwinnable
   state. The mitigations exist (drop verb `player-mechanics/i3`, multi-exit, respawn timers on
   collapse) but they live in *different sets* — no single doc owns the joint fairness guarantee.

6. **Symmetry vs. extraction's single-exit + fixed entry.**
   `e1-symmetry.md` naively duplicates the entry/exit (a mirror produces two gates). Its
   `break_protects` set + forcing entry onto the axis resolves it, but it constrains which axes
   are legal — a real coupling, and it interacts with `d4` exit placement (a mirrored band fights
   a far-exit). Low-severity, but a concrete "two band-set ideas don't compose freely."

7. **Map-scale Field hazards vs. sealed-wall room bands.**
   `a1`/`c2` both flag it: `hazards/5-rising-tide.md`/`5-spreading-fire.md` want continuous
   flooded space, but `socket_sealer` walls every floor cell facing void — a sealed wall stops a
   flood unphysically, and a labyrinth's loops can let fire *outrun* the player around a shortcut.
   These hazards want open or cavern bands, not the room-and-corridor family — another case where
   the opposition's home archetype is constrained, and where `hazards/5-rising-tide.md`'s own
   "flat top-down has no Z for flooding low-first" problem compounds.

8. **Throw-verb economy vs. lossy geometry.**
   `b2-archipelago-islands.md` (throw lost over a gap) and `economy-extraction/m4-condition-fragility.md`
   (throwing damages items) both *tax the signature verb*, and `b1` is where the throw is supposed
   to *shine*. The band layer can both showcase and punish the same verb depending on archetype —
   intended, but the Director must not let gap-loss + fragility + ranged-archetype-scarcity stack
   into "the throw is never worth it."

---

## Shared dependencies & build-order notes

**What the band layer must PROVIDE for the other sets:**

- **Rooms with `room_bounds` + per-piece `floor_cells`** — the placement context every Field
  opposition (`hazards/4-*`) and the `hazards/0-` Director consume. Already produced by the
  socket backend; the `0-` band doc's clean one-directional handoff (band → `OppositionDirector`)
  is the seam.
- **Multi-exit geometry (`d4`)** — the gate for `economy-extraction/m3`, `e5`, and richer
  `e1`/`e4`. The highest-leverage band deliverable for the economy set.
- **Vaultable / cover metadata** — `player-mechanics/m4-vault-slide.md` is *hard-blocked* on cover
  existing (`b1` scatter or `e5` rubble) **plus** a per-edge `vaultable` flag. The band layer owns
  that metadata schema (mirror the dormant `is_drop` socket meta).
- **Directed / one-way edges** — `e3-verticality-fakes.md`'s `is_drop` socket meta is the shared
  primitive for `economy-extraction/e3-one-way-commitment.md`, `hazards/3-collapsing-floor.md`,
  and `player-mechanics/m4` one-way windows. Build the directed-edge + directed-BFS reachability
  once.
- **Toggleable connectors** — `socket_sealer` geometry is what `player-mechanics/e2-levers-doors-switches.md`
  and `e5-wear-decay-state.md` both edit. The band layer's seal pass is the substrate.
- **Set-pieces as a delivery vehicle (`e4`)** — the channel for curated opposition combos,
  the `economy/e5` special exit, and Knowledge/Lore beats. A band-layer feature with the widest
  downstream reach.
- **A depth axis other sets read** — `depth_index` / `depth_norm` / `dist_to_gate` are already
  consumed by `JunkPlacer`, the `hazards/0-` credit budget, `economy/r2`/`e1` tolls, and
  `economy/e3` recompute. The band layer must keep these honest under every reshape (radial
  re-roots it, asymmetric exit re-points it).

**What the band layer DEPENDS ON from the other sets:**

- **The two-architecture shared data seam** — `0-scalable-band-generation-system.md`'s
  `BandProfile.opposition_deck` + `band_depth` (→ Instability `I`) parameterize the handoff to
  `hazards/0-scalable-opposition-system.md`'s Director. Neither owns the other; they meet at data.
  This is the load-bearing dependency for the whole "bands host oppositions" claim.
- **A player HP pool (M2)** — gas/electrified/tide Fields (`hazards/4-gas-cloud.md`,
  `4-electrified-floor.md`, `5-rising-tide.md`) need it before the bands that host them are worth
  building. The band layer should not pre-build CA/scatter backends on spec for hosts whose
  oppositions can't ship until M2.
- **Enemy perception (LoS / vision)** — `hazards/1-patroller-vision-cone.md`,
  `player-mechanics/e3-hide.md`, `m3-sneak-crouch.md` all wait on it; the cavern/grid bands that
  *showcase* sightline play are only as good as the perception system landing.

**Recommended build order (band-layer view):** socket backend + the cheap socket-native archetypes
(a1/a4/c2/c3, the D principles as overlays) → the two cheapest flavors that need no backend
(`e4` set-piece, `e5` wear/decay, per the `0-` doc) → `d4` multi-exit (unblocks the economy set) →
CA + scatter backends **only after** their host oppositions (ambusher/burrower, ranged group)
prove fun at a gate and the M2 HP pool/perception exist.

---

## Notable design information

**The two-architecture mirror.** `procgen-bands/0-scalable-band-generation-system.md` and
`hazards/0-scalable-opposition-system.md` are deliberately the *same shape*: a data `.tres`
descriptor (`BandProfile` ⇄ `OppositionDef`) + composable stages/components + an all-off
baseline-parity & seed-determinism contract. They are the matched halves of one engine: the
band pipeline ends at Stage 7 by handing **placement context** (per-piece `floor_cells`,
`depth_index`/`depth_norm`/`dist_to_gate`, entry/deepest anchors, `resolved_seed`) to the
`OppositionDirector`, which spends an Instability-scaled credit budget per
`BandProfile.opposition_deck`. The handoff is **one-directional and data-only** — the band
generator never spawns oppositions, the Director never edits geometry. This is the cleanest
decoupling in the whole exploration set and should be protected as such.

**Bands are the "where" of a loop whose verbs and stakes live elsewhere.** The master README's
chain says it: a dash matters because of a charger; a charger matters in a corridor; the
corridor's loot matters because of quota + the gear sink; the gear sink feels real as a shop.
The band set is the middle link — it almost never *owns* a decision, it *stages* one. The
implication: a band archetype should be judged not in isolation but by *which decision it makes
legible* (radial = the push/cash-out gradient; archipelago = the chokepoint commit; open-field =
the positioning read). An archetype with no decision it uniquely stages (a naive uniform maze) is
the weakest in the set.

**The directed-edge primitive is over-subscribed and should be built once.** Four ideas across
three sets want "passable one way, walled the other": `e3-verticality-fakes.md` (drop),
`economy-extraction/e3-one-way-commitment.md` (seal), `hazards/3-collapsing-floor.md` (dynamic
collapse), `player-mechanics/m4-vault-slide.md` (one-way window). The `is_drop` socket meta + a
directed-BFS reachability guard is the shared substrate. Building it per-feature is the boilerplate
trap the `hazards/0-` doc warns about, applied to geometry.

**Scope/milestone mismatches to flag.** The band set's most-cited hosts are its most expensive
to build (CA/scatter backends), and several of *their* oppositions are M2-gated (HP pool,
perception). Meanwhile the cheapest band wins (`e4` set-piece, `e5` decay, the D-principle
overlays) ride existing machinery and are M1-cheap — and `e4`/`d4` are exactly what the economy
set needs most. The build-order lesson: **the band layer's cheapest features unblock the most
downstream value; its most expensive features host the most-deferred oppositions.** Sequence
accordingly.

---

## Top 5 things for the Director

1. **Backend build-vs-defer (`procgen/0-`, `b1`, `b3`) silently picks which opposition families
   ship.** CA + scatter are the only new code paths, and they are the sole hosts for the ranged
   group and the ambusher/burrower — defer the backends and you defer those enemies. Decide them
   together, not separately.
2. **`d4-asymmetric-entry-exit` (multi-exit) is a quiet keystone** — it blocks
   `economy/m3-sell-location`, `economy/e5-extraction-as-objective`, and richer `e1`/`e4`. Highest
   downstream leverage of any single band-layer feature; sequence it early.
3. **Connectivity is attacked from four sets at once** (commit-seal, archipelago gaps, decay,
   directed drops). Make the Stage-5 connectivity invariant a single backend-aware owner that runs
   after *every* reshape — otherwise compound configs can strand the player unfairly.
4. **One-way flow + carry-load + far exit + flooding can manufacture an unwinnable state**, and no
   single doc owns the joint fairness guarantee. Needs a cross-set fairness rule (guaranteed
   reachable forward extract + drop valve + respawn-on-collapse) before any two of these stack.
5. **Cheapest band wins (`e4` set-piece, `e5` decay) ride existing machinery and unblock the most
   other-set value** (curated opposition combos, the `economy/e5` special exit, Knowledge beats,
   Exposure-made-architectural). Ship these first; treat CA/scatter as gated, post-fun-gate work.

---

**One-line summary:** The band archetypes are the staging layer the other four sets implicitly
assume — open-field/grid/cavern/archipelago are the *only* homes for whole opposition families,
`d4` multi-exit + `e4` set-pieces are the keystones the economy set is blocked on, and the
`procgen/0-` ⇄ `hazards/0-` data seam is the clean handoff that makes "bands host oppositions"
work — but the layer's cheapest features unblock the most value while its most expensive backends
gate the most-deferred enemies.

**Single biggest contradiction:** the two genuinely-new generator backends (CA caverns `b3`,
open-field scatter `b1`) are the *most expensive to build* yet are the *exclusive hosts* for the
ranged opposition group and the ambusher/burrower — so the Director's scope call on backends
covertly decides which enemy families can exist at all, while the cheap socket-native archetypes
can only host the cheap pursuer/trap oppositions.
