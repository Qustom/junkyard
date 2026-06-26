# Open Floorplan / "Building"
**Category:** Room-and-corridor archetypes

> Exploration only. Pseudocode is illustrative against the real as-built bandgen APIs; no production code, no contract change, no branch.

## The archetype
Rooms abut directly and **share walls with doorways punched through** — there are no corridors. The space reads as a ransacked office floor, a stripped house, a gutted retail unit: a tight warren of rectangular rooms whose interior walls are perforated by openings. Movement is fluid and lateral — you flow room-to-room through wide gaps rather than threading single-file halls. The defining property versus a corridor archetype: **a room can have several openings into several neighbours at once**, so paths multiply and there are few single-tile thresholds.

## How it fits THE FAR YARD bands
**The chokepoint problem (the core tension).** The current corridor pieces give the player natural fallback lines — narrow, defensible seams to retreat through, kite the R1 pursuer down, or lob a thrown item along. An open floorplan *removes* those: with multiple doorways per room and no halls, there is rarely a safe threshold to hold. Threat can flank through a second opening. This is a feature, not a bug — it raises pressure precisely when paired with the **dive clock** and the Instability `I` escalation, and it makes the *extraction decision* sharper (you can't safely camp deep, so banking-vs-pushing bites harder). It suits **mid-to-deep bands** where the design wants tension, not the shallow entry rooms (which BUG7's safe-spawn radius already protects).

**Opposition-spread fit.** It rewards the spread well: **Field** oppositions (Conveyor, Magnet, Gas-cloud flood over `room_bounds`) are excellent here because open rooms give them area to matter and no chokepoint to dodge into; **Actor** pursuers (Charger, Pack/Flock) get the lateral room to flank and use second doorways; **SightlineTrigger** Chargers and ranged **Emitter** Actors thrive because open rooms create long cross-room sightlines — which is also exactly what the **mouse-aimed throw** wants: an open floorplan gives the player long clean throw lanes through aligned doorways, trading "no safe cover" for "good offence." Loot and extract verbs are unaffected — junk still scatters on floor cells, extract is a fixture.

## Generation approach (on the real bandgen system)
The generator (`systems/bandgen/band_generator.gd`) mates pieces at a **single socket** and places them *flush, non-overlapping* (`_alignment_offset`), then `socket_sealer.gd` caps every floor cell facing void. Connectivity, depth (`depth_grader.gd`), and the seal all key on the same primitive: **two pieces are joined iff their FLOOR cells are 4-adjacent** (a real doorway), never a shared wall. The open floorplan is built *on top of this* without changing the contract:

1. **Open-plan pieces, not corridor pieces.** Author a piece family in `data/piece_catalog.gd` (`piece_catalog.gd`) whose footprints are larger rect rooms and whose **edges carry multiple sockets per side** (the `Sockets` Marker2D holder already supports N markers per piece — `_read_piece` enumerates all of them). The catalog's existing corridor-rarity lever (`RunConfig.CORRIDOR_PIECE_IDS`, `lvl_corridor_weight_mult`, `lvl_short_corridors`) is the natural knob to **down-weight or drop corridors** in this archetype's `.tres`, so the band fills with rooms.
2. **Multi-doorway adjacency = emergent shared walls.** Because rooms place flush, when a newly-mated room sits beside an *already-placed* room they share a wall by construction. To make that a real opening rather than a sealed party-wall, the post-pass should **punch doorways where two pieces' perimeter walls are back-to-back** — i.e. detect cells where one piece's WALL borders another piece's FLOOR-adjacent edge and carve a FLOOR gap. This is a clean **inverse of `SocketSealer`**: the sealer caps floor→void; an `OpenPlanCarver` would carve floor↔(neighbouring-room) shared walls. It runs at materialisation, reads final geometry, rolls **zero RNG** (deterministic from the layout), so `band.fingerprint()` stays byte-identical with or without it — exactly the sealer's discipline.
3. **Determinism.** All of this is a pure function of the layout. Which extra doorways carve can be a *fixed* geometric rule (carve every back-to-back shared wall ≥ N cells long) or a seeded choice drawn from a **local sub-stream** (the `JunkPlacer._substream_seed` pattern: a `RandomNumberGenerator` salted off `band.resolved_seed`, never the global `RNG`), so seed→layout reproducibility holds.
4. **Loot layering is free.** `depth_grader.gd` and `junk_placer.gd` already operate over FLOOR cells and BFS hops — once doorways are carved, depth re-grades correctly through the new openings, and J3's `loot_density_per_area` lever (loot ∝ room area) pairs naturally with big open rooms.

```
materialise(band):
    SocketSealer.seal(band)                 # existing: cap floor→void
    OpenPlanCarver.carve(band, sub_rng)     # NEW: open back-to-back shared walls
    # both deterministic, zero global RNG → fingerprint unchanged
```

## Flavor knobs
- **Doorways per shared wall** (1 / several / fully-open) — the dial between "house" and "warehouse."
- **Min wall-run to carve** — long shared walls stay solid, short ones open: shapes how mazey vs. open it reads.
- **Room size distribution** (via the piece catalog) — many small offices vs. a few big open-plan floors.
- **Corridor weight** (reuse `lvl_corridor_weight_mult` → ~0) — how purely open-plan vs. hybrid.
- **Branch chance** (R4 `r4_branch_per_depth`) — open plans want *more* branching than a linear spine, so rooms cluster laterally.

## Synergies & tensions
- **+ Field oppositions / + dive clock:** open area + no chokepoint amplifies both — strong mid/deep fit.
- **+ mouse-aim throw:** aligned doorways = long throw lanes (offence compensates for lost cover).
- **− linear spine:** the M1 default is a single chain; open-plan wants branching ON (R4) to read right, and branching stresses the seal — but `SocketSealer` is already BUG4 branch-rate-independent, so that's covered.
- **Combination:** pairs well as the *interior* of a band whose **entry/exit are corridor-gated** (hybrid): safe corridor on-ramp → open-plan danger core → corridor extract. That preserves a couple of designed thresholds at the band's mouth while keeping the chokepoint-starved core.

## Open questions
- **Carve rule: fixed-geometric vs. seeded? (effort/determinism — recommend fixed first.)** A fixed "carve every back-to-back wall-run ≥ N" rule is simplest and trivially deterministic; seeded variety is nicer but adds a sub-stream. Recommend shipping fixed, add seeded later if it reads too uniform.
- **Is "no safe chokepoint" fun or just frustrating? (fun/tone — Director, validate by playtest.)** This is the archetype's whole identity and a judgment call: the throw-offence and the hybrid-corridor-mouth are the mitigations, but only a playtest gate (the M1 "is it fun?" pattern) can confirm the pressure lands as tense rather than cheap. Recommend prototyping it as a *deep-band-only* variant first.
- **Does the flush-mate placement actually produce enough back-to-back walls? (scope/effort.)** The generator grows a spine; adjacent-but-unmated rooms only arise via branching folding back on itself. If lateral adjacency is rare, the archetype may need a light placement bias toward filling occupied-set gaps — a bigger generator change than a post-pass. Flag for a feasibility spike before committing.
- **Depth legibility (scope.)** `depth_grader` measures piece-hops; with many doorways, BFS depth can shortcut and "deeper" rooms read as physically near the entry, weakening the "deeper = farther home" signal. May want `dist_to_gate` (already computed) to drive reward instead of raw `depth_index`.
