# Proc-Gen Approach Spike

*Research companion to the THE FAR YARD Technical Design Doc §9 (procedural band assembly).*

This spike compares the three mainstream techniques for stitching hand-authored room/zone pieces into playable levels, evaluates each against THE FAR YARD's needs (2D top-down roguelite extraction, Godot 4.6, rule-based / modular assembly, hand-authored "zone-piece" scenes), and ends with a recommended front-runner plus a concrete sketch of how a sample generator would run.

The team's stated constraints frame the whole evaluation: levels ("bands") are built from hand-authored pieces, the team wants **rule-based/modular assembly, not noise-based**, and pieces are **Godot scenes** (`PackedScene`). That immediately favors approaches that treat a designer's room as the atomic unit and reason about *connectivity and mission structure* rather than per-pixel/per-tile texture synthesis.

---

## 1. Modular Room-Graph Stitching

### How it works
A library of hand-authored rooms (each tagged with metadata: number/side of doors, room "purpose," biome) is connected according to a graph that the generator either authors at runtime or reads from a pre-made template. The generator places special rooms (entrance, exit, shop, boss, treasure), then fills the connective tissue, choosing a concrete room for each node that satisfies the node's door/exit requirements. This is the dominant technique in shipped roguelites.

- **Spelunky** is the canonical hybrid: each level is a 4x4 grid of "rooms," a guaranteed solution path is carved entrance-to-exit, and each cell pulls a room template (typed 0–3 by which exits it needs) whose interior has marked chunks that get randomized for obstacles, traps, and gold ([tinysubversions/Darius Kazemi breakdown](http://tinysubversions.com/spelunkyGen/), [PCG Wiki](https://procedural-content-generation.fandom.com/wiki/Spelunky)).
- **Dead Cells** uses an explicit *concept graph per biome*. Designers hand-build room "tiles" with variations parameterized mostly by entrance/exit count and purpose, draw a graph that encodes level length, number of specials, and how labyrinthine the biome is, then a (mostly brute-force) algorithm tries random rooms per node until one satisfies the graph's constraints. Notably the original brute-force matcher was later reworked toward a WFC-style adjacency match when porting to Switch ([Sébastien Bénard / Deepnight](https://deepnight.net/tutorial/the-level-design-of-dead-cells-a-hybrid-approach/)).
- **Enter the Gungeon** picks a hand-authored "flow" file (a directed graph of room relationships, no positions) and grows it into a tree with extra edges added to create loops; every individual room is hand-designed and playtested, and there are a handful of flows per floor each built around a signature feature like a giant loop or a forced shop ([BorisTheBrave](https://www.boristhebrave.com/2019/07/28/dungeon-generation-in-enter-the-gungeon/), [80.lv](https://80.lv/articles/studying-dungeon-generation-in-enter-the-gungeon)).

### Strengths / weaknesses
**Strengths:** the room stays the designer's atomic, fully-authored unit, so quality-per-room is exactly what the designer made. It is the most *proven* approach for the exact genre. Pacing, special-room placement, and difficulty curve are easy to control because they live in the graph, not in emergent noise. It maps trivially to instancing `PackedScene` rooms.

**Weaknesses:** variety is bounded by how many rooms you author (content treadmill). A naive "try random rooms until one fits" matcher can fail or loop on over-constrained graphs and needs backtracking or fallback rooms. Spatial layout (avoiding overlap when rooms have arbitrary footprints) is a separate problem the graph alone does not solve — Gungeon and Dead Cells both add a packing/placement pass.

### Controllability & authorability
Highest of the three for designers who think in terms of rooms and flow. The graph is human-readable and directly editable; a level designer can author a flow without writing rules or grammars. This is the model behind the popular Unity tool **Edgar**, which has documented recipes reproducing both Dead Cells and Gungeon layouts ([Edgar-Unity docs](https://ondrejnepozitek.github.io/Edgar-Unity/docs/examples/dead-cells/)).

### Determinism / seeding
Trivially deterministic: seed one RNG, drive all node ordering, room selection, and interior randomization from it.

### Implementation difficulty
Lowest. A working version is "tag rooms with door sockets, place specials, BFS/DFS fill, match sockets, instance scenes." The hard parts are spatial packing and graceful failure handling.

### Performance
Excellent. Selection is cheap; the cost is mostly `instantiate()` of scenes, which Godot does well if you preload `PackedScene` resources.

### Godot 4 fit
Native and well-trodden. Rooms are scenes; door connection points are `Marker2D`/`Node2D` sockets; metadata lives in exported vars or a custom `Resource`. Existing addons demonstrate the pattern: **SimpleDungeons** (prefab-room 3D dungeons), **godot-procedural3d**, **Roommate**, and GDQuest's **godot-4-procedural-generation** demos ([SimpleDungeons](https://github.com/majikayogames/SimpleDungeons), [godot-procedural3d](https://github.com/RodZill4/godot-procedural3d), [GDQuest](https://github.com/gdquest-demos/godot-4-procedural-generation)).

---

## 2. Grammar-Based Generation (Graph & Shape Grammars; Mission-vs-Space)

### How it works
Generation is expressed as **rewrite rules**: start from a small "axiom" graph and repeatedly apply find-replace rules that expand non-terminal symbols into more detailed structure, until only terminals remain. Joris Dormans' foundational insight is to split a level into two structures generated separately: a **mission** (the logical sequence of goals/locks/keys/encounters, made with a *graph grammar*) and a **space** (the physical layout, made with a *shape grammar*), because each structure has different needs ([Dormans, "Adventures in Level Design"](https://pcgworkshop.com/archive/dormans2010adventures.pdf); [amidos2006/GraphDungeonGenerator](https://github.com/amidos2006/GraphDungeonGenerator)).

Dormans later productized this in the tool **Ludoscope** and shipped **Unexplored**, whose celebrated twist is **cyclic dungeon generation**: instead of generating a single path or a tree, the generator first draws a *loop* between entrance and goal, splitting the level into two parallel arcs, then applies one of ~24 predefined "cycle types" (lock-and-key hub, hidden shortcut, central lake, etc.) over those arcs. Working from cycles rather than trees yields levels that feel hand-designed, and makes one-way doors and anti-backtracking tricks natural ([Gamasutra/Game Developer](https://www.gamedeveloper.com/design/unexplored-s-secret-cyclic-dungeon-generation-), [BorisTheBrave deep dive](https://www.boristhebrave.com/2021/04/10/dungeon-generation-in-unexplored/)).

A core practical pattern in Unexplored is **generate abstract first, resolve later**: a node starts as a generic "Obstacle" or "Lock/Key" non-terminal, gets manipulated/shuffled while still abstract, and only late in the pipeline is resolved into a specific puzzle/enemy/item, with "biome"/theme annotations keeping choices coherent. Because lock→key relationships are preserved as edges, the generator can guarantee solvability (Unexplored's "Pray For Help" can compute what's blocking you).

### Strengths / weaknesses
**Strengths:** unmatched at producing *mission structure* — guaranteed-solvable lock/key chains, deliberate pacing arcs, puzzle dependencies. The mission/space split means you can reason about gameplay logic independent of geometry. Cyclic generation specifically defeats the "random scattering of rooms" feel.

**Weaknesses:** highest conceptual overhead. Authoring is now *writing rules*, not drawing levels — a different and harder skill; Unexplored's floorplan generator alone has ~5000 rules across ~50 modules, built by an academic who created bespoke tooling (Ludoscope/PhantomGrammar). Without tooling, rule sets become hard to debug. Overkill if the game doesn't actually need deep lock/key mission logic.

### Controllability & authorability
Very high *expressive power*, lower *immediate authorability* without a Ludoscope-class editor. Design intent is explicit (you literally encode "place 3 keys, lock the goal, assign a guardian"), but the iteration loop depends on good tooling. There is no mature Godot equivalent of Ludoscope, so the team would build the rule engine themselves.

### Determinism / seeding
Deterministic given seed + ordered rule application; standard for grammar systems.

### Implementation difficulty
Highest of the three. You implement a graph-rewriting engine, a rule format, a non-terminal resolution pipeline, and a graph→grid embedding step. The cyclic-generation *idea* can, however, be borrowed cheaply even inside a room-graph approach (generate a loop instead of a tree) without a full grammar engine.

### Performance
Fine at runtime — rewriting a few-dozen-node graph is cheap. The cost is build/iteration time and engine complexity, not frame time.

### Godot 4 fit
No native support and no production-grade addon; it's a "build it yourself" path. The mission/space concepts and cyclic-loop trick are highly portable, but the full grammar machinery is a significant engine project on top of Godot.

---

## 3. Constraint Solving / Wave Function Collapse (WFC)

### How it works
WFC (Maxim Gumin, building on Paul Merrell's model synthesis) is **constraint solving in the wild**. Every cell of an output grid starts with a domain of all possible tiles; the algorithm repeatedly (a) picks the lowest-entropy cell, (b) collapses it to one tile chosen by weighted random, and (c) **propagates** the resulting adjacency constraints to neighbors, removing now-impossible tiles. Randomizing the choices turns a *solver* into a *generator* that still obeys every adjacency rule ([BorisTheBrave, "Wave Function Collapse Explained"](https://www.boristhebrave.com/2020/04/13/wave-function-collapse-explained/); [Karth & Smith, "WFC is constraint solving in the wild"](https://www.researchgate.net/publication/319370604_WaveFunctionCollapse_is_constraint_solving_in_the_wild)). Constraints come either from hand-authored adjacency rules ("simple tiled") or learned from a sample image ("overlapped"). Shipped games using WFC variants include **Bad North**, **Townscaper**, and **Caves of Qud** ([Wikipedia: Model synthesis](https://en.wikipedia.org/wiki/Model_synthesis)).

For a room-stitching game, the relevant framing is: each "tile" is one of the hand-authored zone pieces, and the adjacency rules are which piece-edges (door sockets) may connect. This is exactly the WFC-style edge-matching that Dead Cells migrated toward for its Switch port.

### Strengths / weaknesses
**Strengths:** elegant, general, and very good at **local coherence** — edges always line up, so stitched pieces never produce illegal seams. It naturally supports weighting, fixed/pre-placed tiles, hex/3D grids, and "module" tiles spanning multiple cells.

**Weaknesses:** the central, well-documented flaw is **no global structure** — WFC only enforces local adjacency, so without extra constraints it produces homogeneous output and "often generates a bunch of disconnected rooms," and it "struggles when long-range global constraints dominate, such as exact key-lock sequencing or puzzle dependencies" and level-solvability guarantees ([BorisTheBrave tips & tricks](https://www.boristhebrave.com/2020/02/08/wave-function-collapse-tips-and-tricks/); search-surfaced consensus). Boris's own conclusion: let WFC pick tiles but use *a different technique or extra constraint to ensure large-scale structure*. Pure WFC can also hit contradictions requiring backtracking/restart.

### Controllability & authorability
Authoring is "draw tiles + define adjacencies" (or provide a sample), which is intuitive for *texture-like* content. It is **weaker for mission/pacing control**: you cannot easily say "the boss is exactly N rooms past the second key." That is the opposite of what an extraction roguelite's pacing needs.

### Determinism / seeding
Deterministic given seed, *if* contradiction/restart logic is itself seeded. Backtracking and restart-on-contradiction can complicate reproducibility if not handled carefully.

### Implementation difficulty
Moderate. The core loop is short, but performant propagation (support-count arrays, dirty-cell queues) and contradiction handling add real work. Godot has community WFC addons but no first-party support.

### Performance
Good for modest grids; cost grows with grid size and tile count, and pathological tilesets can trigger expensive backtracking. For dozens-to-hundreds of room cells this is acceptable.

### Godot 4 fit
Doable via community code/ports; no native node. Best used here as an *adjacency-matching layer* over the room graph (the role it plays in Dead Cells today), not as the master structural generator.

---

## 4. Side-by-Side Summary

| Criterion | Room-Graph Stitching | Grammar / Mission-Space | WFC / Constraint |
|---|---|---|---|
| Mission/pacing control | High (graph) | Highest (explicit) | Low (local only) |
| Designer authorability | High (draw rooms+graph) | High power, needs tooling | Medium (tiles+adjacency) |
| Global structure / solvability | Good (graph guarantees) | Excellent (lock/key edges) | Weak without add-ons |
| Local seam coherence | Good (socket match) | Good | Excellent |
| Determinism/seeding | Trivial | Straightforward | OK (mind backtracking) |
| Implementation effort | Low | High | Medium |
| Runtime performance | Excellent | Excellent | Good |
| Godot 4 fit / prior art | Strongest (multiple addons) | DIY engine | Community addons |
| Genre track record | Spelunky, Dead Cells, Gungeon | Unexplored | Bad North, Townscaper, Qud |

---

## 5. Recommendation: Room-Graph Stitching, with two borrowed ideas

**Front-runner: modular room-graph stitching**, augmented by (a) the **cyclic-loop backbone** idea from Unexplored and (b) **WFC-style socket adjacency matching** for piece selection. This is precisely the architecture Dead Cells converged on, and it is the lowest-risk, highest-track-record fit for a Godot 4 hand-authored-piece roguelite.

Rationale: the team has already committed to hand-authored zone-piece scenes and rule-based assembly. Room-graph stitching makes the authored scene the atomic unit (preserving quality and the "readable junk" aesthetic), gives direct control over band length / special placement / difficulty pacing via an editable graph, is deterministic with a single seed, and instances `PackedScene`s natively. Full grammar generation is overkill unless THE FAR YARD needs deep lock/key puzzle logic — and its best ideas (mission/space separation, cyclic loops, abstract-first resolution) can be cherry-picked into the graph stage without building a Ludoscope. Pure WFC is the wrong master generator (no global structure, weak pacing control) but is the right *micro*-technique for guaranteeing seams line up.

### Sketch of a sample generator ("BandBuilder")

**Authoring data**
- Each zone piece is a `PackedScene` with a `BandPiece` root carrying an exported `Resource`: `biome`, `purpose` (entrance/exit/extraction/combat/loot/connector/special), a list of **door sockets** (each a `Marker2D` with a `side` and a `socket_type` tag), an optional footprint size, and a spawn-weight.
- Each band/biome has a **BandGraph** resource: target length, count of each special, "loopiness," and which piece pool to draw from.

**Generation pipeline (all driven by one seeded `RandomNumberGenerator`)**
1. **Seed.** `rng.seed = run_seed XOR band_index` so each band is reproducible and independent.
2. **Mission backbone (borrowed cyclic idea).** Place `entrance` and `exit/extraction` nodes. Instead of a pure tree, draw a primary **loop** between them so the band has two arcs (an "in" route and a "different way out"), then attach minor cycles and dead-ends to hit target length. Tag arcs with roles (calm vs. hot) to bake in pacing — the AI-director peaks/breaks idea from Dead Cells/L4D.
3. **Annotate nodes (abstract-first).** Mark nodes as combat / loot / special / connector and place locks/keys as *non-terminal* annotations (key node carries an edge to its lock node) so solvability is guaranteed before any geometry exists.
4. **Resolve pieces (WFC-style match).** For each node, the candidate set is pieces whose `purpose`/`biome` match and whose door sockets satisfy the node's required connections. Choose by weighted random; treat unfilled sockets as constraints on neighbors and propagate (least-options-first), so adjacent pieces always have compatible, matching socket types. On contradiction, backtrack one node or drop in a guaranteed `connector` fallback piece.
5. **Spatial placement.** Walk the graph from entrance, instancing each chosen scene and snapping child sockets to parent sockets; reject placements that overlap already-placed footprints (retry alternate piece or insert a corridor connector). This is the packing pass Gungeon/Dead Cells both have.
6. **Populate.** Derive enemy budget from total combat-piece length (Dead Cells' rule), then place enemies/loot/hazards inside each instanced piece's marked spawn regions, again seeded.
7. **Validate.** Pathfind entrance→exit and entrance→every key→its lock→exit; if unreachable, fail fast and regenerate with an advanced seed (cheap because bands are small).

This gives THE FAR YARD deterministic, designer-controllable bands assembled from hand-authored scenes, with guaranteed-coherent seams, guaranteed solvability, and tunable pacing — while keeping engine complexity modest and staying on well-charted Godot 4 ground.

---

## Sources

- [The Level Design of Dead Cells — Sébastien Bénard / Deepnight Games](https://deepnight.net/tutorial/the-level-design-of-dead-cells-a-hybrid-approach/)
- [Building the Level Design of a procedurally generated Metroidvania (IndieDB mirror)](https://www.indiedb.com/games/dead-cells/news/the-level-design-of-a-procedurally-generated-metroidvania)
- [Spelunky level generation breakdown — Darius Kazemi / tinysubversions](http://tinysubversions.com/spelunkyGen/)
- [Spelunky — Procedural Content Generation Wiki](https://procedural-content-generation.fandom.com/wiki/Spelunky)
- [Dungeon Generation in Enter The Gungeon — BorisTheBrave](https://www.boristhebrave.com/2019/07/28/dungeon-generation-in-enter-the-gungeon/)
- [Studying Dungeon Generation in Enter The Gungeon — 80.lv](https://80.lv/articles/studying-dungeon-generation-in-enter-the-gungeon)
- [Edgar (Unity) — Dead Cells & Gungeon recipes](https://ondrejnepozitek.github.io/Edgar-Unity/docs/examples/dead-cells/)
- [Adventures in Level Design: Generating Missions and Spaces — Joris Dormans (PDF)](https://pcgworkshop.com/archive/dormans2010adventures.pdf)
- [GraphDungeonGenerator (Dormans mission graph + layout grammar) — amidos2006](https://github.com/amidos2006/GraphDungeonGenerator)
- [Unexplored's Secret: 'Cyclic Dungeon Generation' — Game Developer](https://www.gamedeveloper.com/design/unexplored-s-secret-cyclic-dungeon-generation-)
- [Dungeon Generation in Unexplored — BorisTheBrave](https://www.boristhebrave.com/2021/04/10/dungeon-generation-in-unexplored/)
- [Wave Function Collapse Explained — BorisTheBrave](https://www.boristhebrave.com/2020/04/13/wave-function-collapse-explained/)
- [Wave Function Collapse tips and tricks — BorisTheBrave](https://www.boristhebrave.com/2020/02/08/wave-function-collapse-tips-and-tricks/)
- [WaveFunctionCollapse is constraint solving in the wild — Karth & Smith](https://www.researchgate.net/publication/319370604_WaveFunctionCollapse_is_constraint_solving_in_the_wild)
- [Model synthesis (Merrell) & games using WFC — Wikipedia](https://en.wikipedia.org/wiki/Model_synthesis)
- [SimpleDungeons — Godot 4 prefab-room dungeon addon](https://github.com/majikayogames/SimpleDungeons)
- [godot-procedural3d — modular-asset dungeon addon](https://github.com/RodZill4/godot-procedural3d)
- [godot-4-procedural-generation — GDQuest demos](https://github.com/gdquest-demos/godot-4-procedural-generation)
- [RandomNumberGenerator — Godot Engine docs (stable)](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html)
- [Random number generation tutorial — Godot Engine docs](https://docs.godotengine.org/en/latest/tutorials/math/random_number_generation.html)
- [Reproducible/deterministic random streams across Godot versions — issue #27856](https://github.com/godotengine/godot/issues/27856)
