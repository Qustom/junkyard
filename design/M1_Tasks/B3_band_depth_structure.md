# B3 — Band Depth / "Push Deeper" Structure

**Summary:** Make the generated band express *depth* so "push deeper" is a real risk/reward choice — junk value and density rise with distance from the entry gate, and the trip back to safety grows longer. No instability scaling math yet (that lands in M3); M1 is simply "deeper = more/better junk, farther from the gate."

- **Parent task:** B3
- **Dependencies:** B2 (the connected band + entry gate), C1 (junk-as-Resource — the `Junk` definition B3 places and values).
- **Acceptance criterion:** Moving deeper into the band **visibly** increases junk reward and the distance back to the entry gate.

B2 produces a connected band but treats all pieces equally. B3 adds the *axis of meaning*: a per-piece **depth** value, and a deterministic junk-placement pass whose value/density curve is a pure function of depth. This is what turns the band from "a maze" into "a gamble — keep going for richer junk, but you're farther from the exit."

---

## Assets needed

```
/systems/depth
  depth_grader.gd           # assigns depth_index / depth_norm to each PlacedPiece
  junk_placer.gd            # seeded pass that spawns junk weighted by depth
  depth_curve.tres          # DepthCurve resource: value & density vs depth
  depth_curve.gd
/data
  junk_pool.tres            # Array of junk entries w/ tiers (from C1)
/entities/pickups
  junk_pickup.tscn          # Area2D + Sprite (greybox: colored marker) carrying a Junk resource
/entities/debug
  depth_debug_overlay.gd    # Debug Draw 2D: print depth index + dist-to-gate per piece
/bands
  band.gd                   # EXTENDED (from B2): now stores depth + gate path data
```

**`DepthCurve` resource (`depth_curve.tres`):** authored tuning, not code-baked.
- `value_curve: Curve` — junk value multiplier vs `depth_norm` (0→1). Monotonic rising for M1.
- `density_curve: Curve` — expected junk count per piece vs `depth_norm`.
- `tier_threshold_curve: Curve` — minimum junk tier unlocked at a given depth (so deep pieces can roll rarer junk).

**Junk dependency (C1):** B3 consumes the `Junk` Resource type defined in C1 — assumed to expose at least `base_value: int` and `tier: int`. `junk_pool.tres` is an array of `Junk` grouped/filterable by tier. If C1 isn't ready, B3 stubs a placeholder `Junk` with those two fields and swaps later.

**Greybox junk pickup:** `junk_pickup.tscn` = `Area2D` + a solid-color `Sprite2D` (color/size scales with tier for at-a-glance depth reading) + an exported `junk: Junk`. On body-enter it emits `EventBus.junk_collected(junk)`.

---

## Code to generate

### Depth assignment

Depth is **graph distance from the entry gate**, measured in pieces (BFS over mated sockets). Using piece-distance (not pixels) keeps it deterministic and matches B2's integer-cell world.

```gdscript
# depth_grader.gd
class_name DepthGrader
extends RefCounted

# Annotate every PlacedPiece with depth_index (BFS hops from entry)
# and depth_norm (0..1). Deterministic: BFS order fixed by stable child sort.
func grade(band: Band) -> void:
    var queue: Array[PlacedPiece] = [band.entry_piece]
    band.entry_piece.depth_index = 0
    var visited := { band.entry_piece.id: true }
    var max_depth := 0

    while not queue.is_empty():
        var cur: PlacedPiece = queue.pop_front()
        # Neighbors via mated sockets, sorted by socket id for stable order.
        for nb in _sorted_neighbors(band, cur):
            if visited.has(nb.id):
                continue
            visited[nb.id] = true
            nb.depth_index = cur.depth_index + 1
            max_depth = max(max_depth, nb.depth_index)
            queue.append(nb)

    band.max_depth = max_depth
    for p in band.pieces:
        p.depth_norm = 0.0 if max_depth == 0 else float(p.depth_index) / float(max_depth)
```

### Distance-back-to-gate

The "farther from safety" half of acceptance. Store, per piece, the **shortest path length back to the entry gate** (in pieces) so the run/UI can show it. With a mostly-linear M1 band this equals `depth_index`, but computing it explicitly survives branching.

```gdscript
func compute_return_distance(band: Band) -> void:
    # Reverse BFS from entry gives shortest hops home for every piece.
    # (Same traversal as grade(); reuse if linear.) Result -> p.dist_to_gate.
    for p in band.pieces:
        p.dist_to_gate = p.depth_index   # linear M1; replace w/ true BFS when branching
```

### Seeded junk placement scaled by depth

The reward curve. Density and value both pull from `DepthCurve` sampled at the piece's `depth_norm`. Every roll uses `RNG` so the same seed yields the same loot — **junk placement reuses B2's seed stream (or a named sub-stream) so it never desyncs the layout RNG.**

```gdscript
# junk_placer.gd
class_name JunkPlacer
extends RefCounted

func populate(band: Band, curve: DepthCurve, pool: Array[Junk]) -> void:
    # DETERMINISM: derive a dedicated, reproducible sub-stream so junk rolls
    # do not perturb (and are not perturbed by) the layout RNG sequence.
    RNG.set_seed(band.seed)
    RNG.fork("junk")   # named sub-stream; identical given the same band.seed

    for p in band.pieces:
        var d := p.depth_norm

        # 1. How much junk (expected count -> probabilistic integer, seeded).
        var density := curve.density_curve.sample(d)
        var count := _seeded_round(density)        # uses RNG.randf for the fractional part

        # 2. What tier is unlocked at this depth.
        var min_tier := int(curve.tier_threshold_curve.sample(d))

        for i in count:
            var junk := _seeded_pick_junk(pool, min_tier)   # RNG.weighted_pick
            # 3. Scale value up with depth (M1: simple multiply, no instability).
            var spawned := junk.duplicate() as Junk
            spawned.base_value = int(junk.base_value * (1.0 + curve.value_curve.sample(d)))
            _spawn_pickup(band, p, spawned)

func _seeded_round(x: float) -> int:
    var lo := int(floor(x))
    return lo + (1 if RNG.randf() < (x - lo) else 0)
```

### Spawn placement within a piece (deterministic)

```gdscript
func _spawn_pickup(band: Band, p: PlacedPiece, junk: Junk) -> void:
    var pickup := preload("res://entities/pickups/junk_pickup.tscn").instantiate()
    pickup.junk = junk
    # Pick a walkable floor cell inside the piece via the seeded stream.
    var cells := p.walkable_cells()                 # stable, sorted order
    var cell := cells[RNG.randi_range(0, cells.size() - 1)]
    pickup.position = p.cell_to_world(cell)
    p.node.add_child(pickup)
    EventBus.junk_spawned.emit(junk, p.depth_index)
```

### Determinism notes specific to B3

- Depth grading and return-distance are **pure graph functions** — no RNG, fully determined by B2's output. Same band in → same depths out.
- Junk placement uses a **named sub-stream** (`RNG.fork("junk")`) keyed off the same `band.seed`. This guarantees: (a) identical loot for identical seeds, and (b) loot rolling can't shift the layout RNG sequence (and vice-versa) — the two concerns are decoupled but both reproducible.
- All curves are sampled from authored `Curve` resources (`.tres`), so designers tune the risk/reward feel without touching code, and the values are frozen at author time (no runtime drift).

### Acceptance hookup

- A debug overlay (Debug Draw 2D) prints each piece's `depth_index` and `dist_to_gate`, and the total junk value placed per piece — so you can *see* the curve rise as you push deeper.
- Smoke check: generate a band, walk from gate to the deepest piece, confirm junk markers get bigger/richer and the return path counter climbs. That visibly satisfies "deeper = more/better junk, farther from safety."

---

## Open questions

- **Depth metric — graph hops vs Euclidean distance:** Piece-hops are clean and deterministic but ignore physical backtrack length. Do we ever want pixel/path distance for "farther from safety," or is hop-count enough for M1? Recommend hops now.
  - **Recommendation:** **Use graph hops (BFS distance in pieces) for M1.** Hop-count is pure integer math over B2's deterministic graph, trivially reproducible, and on a linear band it tracks physical backtrack length closely enough that players read "deeper = farther home" correctly. Euclidean/true-path pixel distance adds float math and a pathfinding dependency for marginal fidelity. If a later milestone wants the return trip to *feel* its true length (e.g. for a timer or instability ramp), layer a cell-path-length metric on top of hops then — it's additive, not a redesign.
- **How depth maps to reward — curve shape:** Linear, exponential, or stepped tiers? Exponential makes deep dives dramatic but can trivialize early game; stepped reads clearly to players. This is a tuning call best answered by feel once the overlay exists.
  - **Recommendation:** **Ship M1 with a gently-rising near-linear `value_curve` (slope ~1.0→1.8 across `depth_norm` 0→1) and keep tier unlocks stepped.** Because all reward shaping lives in authored `Curve` `.tres` resources, the *code* is curve-shape-agnostic — designers retune by dragging points once the debug overlay makes the rise visible, with no code change. Start linear-ish (not exponential) so early pieces stay meaningful and the prototype reads honestly; reserve dramatic exponential deep-dive payoff for when instability/risk scaling lands in M3 to balance it.
- **Reward axis: value vs density vs tier:** All three rise with depth in this draft. Is that too generous (compounding)? Maybe only *tier unlock* + modest value, with density flat, to keep early pieces meaningful. Needs a design decision.
  - **Recommendation:** **For M1, raise only two axes: tier-unlock (stepped) and modest per-item value (the near-linear curve); hold density roughly flat.** Compounding all three multiplies into a runaway deep-piece jackpot that makes shallow pieces feel worthless and skews the very risk/reward read M1 is trying to prove. Tier + value already delivers a legible "deeper junk is better" signal without flooding deep rooms with quantity. Keep the `density_curve` resource present but author it near-constant (slight rise at most); promoting density to a real reward lever is a post-M1 tuning decision once the loop feels right.
- **Branching depth ambiguity:** If B2 branches, two pieces can share a `depth_index` but differ wildly in return distance. Confirm whether M1 stays linear (sidesteps this) or B3 must already handle divergent branch rewards.
  - **Recommendation:** **M1 stays linear (B2 `branch_chance = 0.0`), which sidesteps this entirely** — on a spine `depth_index`, `dist_to_gate`, and placement order all coincide, so there is no ambiguity to resolve. Still implement `compute_return_distance` as a real reverse BFS (not the `= depth_index` shortcut) so the moment branches turn on, divergent-branch return distances are already correct and reward can key off `dist_to_gate` rather than raw depth. No divergent-branch reward logic is needed for M1 beyond that.
- **Determinism of `.duplicate()` on Junk resources:** Duplicating + mutating `base_value` per spawn must not share state across pickups. Verify deep vs shallow duplicate semantics with C1's `Junk` resource.
  - **Recommendation:** **Use `junk.duplicate(true)` and require C1's `Junk` to keep its per-spawn-mutated fields as flat values (`int base_value`, `int tier`), not nested resources/arrays.** Godot's `duplicate(true)` copies direct subresources but is documented to **not** deep-copy resources stored inside `Array`/`Dictionary` properties — those stay shared ([source](https://github.com/godotengine/godot/issues/74918)). Since B3 only mutates the scalar `base_value`, a duplicate is sufficient to give each pickup independent value with no shared state. Add a GdUnit4 assertion that mutating one spawned junk's `base_value` leaves the pool template and sibling spawns unchanged; if C1 ever nests mutable subresources in arrays, give `Junk` a custom `deep_copy()` method instead of relying on `duplicate(true)`.
- **Where the "gate" lives:** Is the entry gate a special socket on the entry piece, or its own piece? B3's `dist_to_gate` anchors there — needs a single agreed definition shared with B2.
  - **Recommendation:** **Define the gate as the entry *piece* (`band.entry_piece`, placed at `Vector2i.ZERO` with `depth_index = 0`), not a special socket.** B2 already anchors generation on a dedicated entry piece, and BFS depth/return-distance are naturally piece-keyed, so anchoring `dist_to_gate` on that piece keeps B2 and B3 sharing one unambiguous definition with zero extra concepts. The actual exit/extraction trigger is then just an `Area2D` placed inside the entry piece (a known floor cell), which the dive-loop reads as "you're back at safety." Record `band.entry_piece` explicitly in the `Band` API as the single shared anchor so both systems reference the same object.
