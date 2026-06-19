# BUG3 — Open sockets to off-map void

**Milestone:** M1.1 (foundations / wave 1) · **Workstream:** (a) Foundations
**Assignees:** `environment-artist` (socket/cap geometry authoring) + `general-purpose` (generator cap pass)
**dependsOn:** none (wave-1 foundation). **Prerequisite for:** R4 (maze / navigation risk).
**Knobs:** none (correctness fix). **Telemetry:** none.

> **This is a DESIGN doc, not an implementation.** It specifies the fix, the recommended
> approach, and the contract the implementing agents build against. Code sketches are
> illustrative; the canonical APIs are in `M1_As_Built.md` (which wins on any disagreement).

---

## 1. Goal & design intent

**Seal the band.** A generated band must be a closed play space: every walkable floor cell
is enclosed by wall collision, with the *only* deliberate boundary openings being the ones
that mate two pieces (real doorways). After this fix, there is **no open socket leading
off-map**, and the player physically cannot walk out of the band into the empty off-map void.

Three reasons this matters now, in priority order:

1. **Prerequisite for R4 (maze / navigation risk).** R4 turns on `branch_chance > 0` (branching,
   dead-ending layouts) and a limited-vision / fog lever. Branching and limited vision are only
   a *fair* navigation challenge if the play space is **bounded** — a player who "gets lost" must
   be lost *inside* the maze, not because they wandered out through an uncapped opening into a
   featureless void. A dead-end in R4 is a *sealed* socket (a wall you turn around at); BUG3 is
   what makes a dead-end actually dead. Without BUG3, R4's "did they get lost?" proxy is
   contaminated by players falling off the map.
2. **Removes a quality confound for the re-gate playtest.** M1.1's whole purpose is to measure
   whether a depth-scaled cost axis makes push-vs-extract fun (RG2/RG3 compare outcome
   distributions against the M1.0 baseline). A player walking off into void is a **broken-build
   artifact** that pollutes run-length, depth-reached, and end-cause telemetry with noise that
   has nothing to do with the oppositions under test. Sealing the band removes that confound so
   the comparison is clean.
3. **Baseline correctness.** Even with all oppositions OFF (the M1.0-equivalent control), the
   band should be sealed. This is a latent M1.0 bug surfaced by M1.1's need for a bounded map;
   fixing it makes the all-off control a faithful, non-glitchy baseline.

**Non-goal:** this is not level-design polish, art, or navigation tuning. It is a geometry
correctness fix. It must change **only collision/geometry at unused socket openings** and must
**not** perturb the layout (see determinism constraint, §3).

---

## 2. Root-cause analysis

### 2.1 What a socket opening physically is

B1 greybox pieces are **solid-walled rects**: a perimeter ring of `WALL` tiles (atlas `(1,0)`,
which carries the cell-covering collision polygon on layer `world`) around an interior of
`FLOOR` tiles (atlas `(0,0)`, no collision). A **socket** is a deliberate **2-cell gap punched
in that perimeter wall** — the opening through which a neighbour piece connects. The socket
`Marker2D` sits **inset one cell** from the piece edge, centered on the 2-cell opening, on the
last interior floor cell (`M1_As_Built.md` → "Procedural geometry").

Concretely, `piece_corridor_h.tscn` is an 8×4 cell rect:

```
row y=0 : W W W W W W W W      (north wall, solid)
row y=1 : F F F F F F F F      (floor — the corridor interior, NO collision)
row y=2 : F F F F F F F F      (floor)
row y=3 : W W W W W W W W      (south wall, solid)
```

The W socket marker is at pixel `(24,32)` → cell `(1,2)`; the E socket at `(104,32)` → cell
`(6,2)`. The **west and east faces have no wall column at all** — rows y=1,2 run straight to the
piece edge (x=0 and x=7) as open floor. That open floor edge **is** the socket opening: a 2-cell-
tall gap in the perimeter where a mating corridor's floor will become 4-adjacent and form a
walkable doorway. (Other pieces — boxes, hub — punch their openings the same way on whichever
faces carry a socket.)

### 2.2 Which sockets end up unconnected, and why

The generator (`band_generator.gd`) grows a linear spine (`branch_chance = 0.0`): it places the
entry piece, then repeatedly pops a frontier socket, mates a piece against it, and pushes the new
piece's *remaining* sockets onto the frontier. The loop ends when `band.pieces.size()` hits
`target_piece_count` (or the frontier empties).

When the loop ends with pieces still capped at the target count, the **frontier is not empty** —
every socket still on it is an opening that never got a mate. `_generate_once` explicitly retains
them:

```gdscript
# band_generator.gd, end of _generate_once
band.open_sockets = frontier   # leftover, unconsumed openings — RETAINED, never sealed
```

So **`band.open_sockets` is the exact, already-computed set of openings into void.** On the M1.0
linear spine these are typically:

- the **terminal piece's** outward-facing socket(s) — the spine grew to length and stopped, so
  the deepest piece's far opening was never mated;
- any **side sockets** on multi-exit pieces (box_large, room_hub) that the linear bias never grew
  from (the spine grows from the *deepest* socket; a hub placed mid-spine contributes 3 extra
  sockets, only one of which the spine consumes).

Each such `OpenSocket` carries its band-global boundary `cell`, its `dir`, its `width_cells` (2),
and `owner_rect` — i.e. **everything needed to locate the uncapped opening already exists** on
the object.

### 2.3 Why the player can cross them (collision reasoning)

Collision layers are locked (`M1_As_Built.md`): `world` = layer 2 carries geometry collision; the
player body collides with `world`. **Walls block; floor does not.** A piece keeps the player in
*only* because its perimeter `WALL` ring surrounds the floor.

At an **unused socket**, the perimeter ring has a 2-cell hole and **nothing fills it** — there is
no neighbour piece's wall, and the generator added no cap. The cells just past the opening
(`OpenSocket.neighbour_cell()` and its width partner) are **off-map void**: no tile, no collision.
So the floor lane runs to the piece edge, hits the gap, and **opens onto empty space the player
can walk straight through** — there is no `world`-layer collider anywhere along that 2-cell
boundary to stop the `CharacterBody2D`. Once across, the player is on un-tiled void with no walls
in any direction and can wander arbitrarily far off-map.

**In one line:** pieces are solid-walled, but a socket is a deliberate 2-cell wall gap; a *mated*
socket is sealed by the neighbour's adjacent geometry, an *unmated* socket is sealed by nothing —
so the player walks through the hole into void.

---

## 3. Design options & recommendation

All three options must satisfy the hard constraint:

> **Determinism is sacred (B2 `band.fingerprint()`).** The fingerprint is
> `sha256("piece_id@offset#mated" for each piece in placement order)`. The fix must **not** add,
> remove, reorder, or re-offset any piece, and must **not** consume any RNG draw on the layout
> path. The cap is a **post-placement geometry/collision pass** that runs *after* `generate()`
> returns its `Band`, reads the already-final `band.open_sockets`, and only adds collision/visual
> geometry. It must touch neither `RNG` nor `band.pieces` ordering. A determinism sweep
> (`fingerprint(seedN)` identical with and without the cap pass) is part of acceptance.

### Option (a) — Generator post-placement cap pass *(RECOMMENDED)*

After the band is assembled, enumerate `band.open_sockets` (already the exact unmated set) and,
for each, add a **2-cell wall cap** of `world`-layer collision across the opening, at the inset
boundary the socket marks. Implemented as a pass that runs at **materialisation time** (in
`MainGame._materialise_band`, where pieces become live scene nodes), writing `WALL` tiles into
the owning piece's `Geometry` TileMapLayer at the opening cells — or, equivalently, parenting a
small cap collider/greybox at the opening's world position.

- **Pros:** Uses data that already exists (`band.open_sockets`), so it is a pure read-then-decorate
  pass with **zero layout perturbation** — fingerprint provably untouched. One code site, no new
  authored assets, no catalog changes, no risk of the matcher behaving differently. Automatically
  correct for **branching layouts (R4)**: when `branch_chance` goes > 0, the dead-end sockets land
  in `band.open_sockets` exactly the same way and get capped with no extra work. Scales to any
  piece roster.
- **Cons:** The cap must reproduce B1's "WALL across this 2-cell opening" convention precisely
  (which cells, which atlas tile / which collision shape) — a small amount of opening→cells math
  (the socket marker is inset one cell, so the cap fills the *opening lane*, i.e. the boundary
  cells the marker's 2-wide lane occupies). This is the same flush-edge cell arithmetic B2 already
  does, so the idiom exists.

### Option (b) — Author dedicated cap pieces

Author `piece_cap_N/E/S/W.tscn` (a single solid-wall stub that presents one socket) and have the
generator **place a cap piece on every leftover frontier socket** before returning.

- **Pros:** Caps are "just pieces," reusing the existing place/occupy path; visually they can be a
  proper greybox wall nub.
- **Cons:** **Placing pieces is a layout act** — it appends to `band.pieces` and therefore
  **changes `fingerprint()`** (more pieces, new offsets, new mated indices). To keep determinism
  you'd have to either exclude caps from the fingerprint (a special-case carve-out in a load-bearing
  determinism primitive — fragile) or accept a fingerprint change (breaks the B2 contract and the
  determinism test). It also needs `_fits` overlap handling for the cap footprint, four new authored
  scenes + catalog plumbing, and care that caps never themselves leave a socket. More surface, more
  risk, for the same outcome. **Rejected** primarily on the determinism collision.

### Option (c) — Single bounding wall

Compute the band's overall occupied-cell bounding rect and ring it with wall collision (a box
around everything).

- **Pros:** Trivially seals the outer perimeter; one rect.
- **Cons:** **Does not actually seal the openings** — a socket opening is a gap in a *piece's*
  perimeter that may sit interior to the band bounding rect (e.g. a hub's unused side socket facing
  a pocket of void *inside* the bounding box but not adjacent to any piece). A bounding box leaves
  those internal void pockets reachable. It also walls off legitimately empty interior gaps the
  player should never reach anyway, and for branching R4 layouts the bounding rect contains large
  empty regions the player could roam. **Rejected** — wrong granularity; seals the wrong boundary.

### Decision (Director-ratified 2026-06-19)

**FINAL: Option (a) — a deterministic post-placement cap pass keyed on `band.open_sockets`,
run at materialisation (`main_game.gd`), capping each unmated opening with the existing greybox
WALL tile.** Options (b) and (c) are rejected (see above). Option (a) is the only one that (1)
leaves `fingerprint()` provably untouched because it adds no piece and rolls no RNG, (2) reuses
data the generator already computes, (3) caps *exactly* the openings that lead to void (no more,
no less), and (4) is automatically correct for R4's branching/dead-ending layouts with no extra
authoring. Per §7: the cap is a **visible greybox wall reusing the existing WALL tile** (§7.1),
the seal runs at **materialisation while `generate()` stays a pure layout function** (§7.4), and
every R4 dead-end is a **sealed terminus** capped by this same pass (§7.3). The `environment-artist`
confirms the precise opening→cells convention (matching B1's wall authoring); the `general-purpose`
programmer implements the pass and the determinism guard.

---

## 4. Pseudocode — the "seal unused sockets" pass

The pass runs **after** `BandGenerator.generate()` returns, against the final `Band`. It reads
`band.open_sockets` (the retained unmated frontier) and, for each, writes wall geometry/collision
across the opening lane. Two equivalent placements (pick one at implementation; tile-write is the
recommended seam because it reuses the piece's existing `Geometry` collision and stays in cell
space):

```gdscript
# Conceptual — runs at materialisation, NOT inside generate(). No RNG, no band.pieces edits.
# Reads the already-final, deterministic band; only adds WALL collision at uncapped openings.

func seal_unused_sockets(band: Band, cell_size_px: int) -> void:
    for sock in band.open_sockets:              # exactly the unmated openings (into void)
        for cell in _opening_lane_cells(sock):  # the 2-cell boundary lane this socket opens through
            _place_wall_cap(sock.owner, cell, cell_size_px)

# The boundary cells the opening occupies. The socket marker is INSET one cell (B1 convention),
# centered on a 2-wide opening, so the opening lane is the two perimeter cells on the socket's
# facing edge: the marker cell stepped one cell toward the edge (the gap in the wall), spanning
# width_cells along the perpendicular axis. Pure integer-cell math — no RNG, no float.
func _opening_lane_cells(sock: OpenSocket) -> Array[Vector2i]:
    var facing := ZoneSocket.dir_to_cell(sock.dir)          # +1 along the wall-gap axis
    var perp := Vector2i(facing.y, facing.x)                # perpendicular (the opening's width axis)
    var edge_cell := sock.cell + facing                     # marker is inset one cell; step out to the wall gap
    var cells: Array[Vector2i] = []
    # Centered 2-wide opening: cover the width_cells lane (default 2) centered on the marker.
    var half := sock.width_cells / 2
    for k in range(-half, sock.width_cells - half):         # e.g. width 2 -> {0,1} or centered span
        cells.append(edge_cell + perp * k)
    return cells

# Add a WALL cell (world-layer collision) at a band-global cell. Greybox: reuse the piece's
# Geometry TileMapLayer WALL tile (atlas (1,0)) so collision + look match B1 exactly — this is
# the ratified visible-greybox-wall, reuse-existing-WALL-tile decision (§7.1), not a distinct tile.
func _place_wall_cap(owner: PlacedPiece, global_cell: Vector2i, cell_size_px: int) -> void:
    var geo := owner.instance.get_node_or_null("Geometry") as TileMapLayer
    if geo == null:
        return
    var local_cell := global_cell - owner.offset_cell      # back to the piece's local cell space
    geo.set_cell(local_cell, GREYBOX_SOURCE_ID, WALL_ATLAS) # WALL_ATLAS == Vector2i(1,0)
    # (Alt seam: parent a small StaticBody2D/ColorRect cap at global_cell * cell_size_px on the
    #  world layer — same effect; tile-write is preferred for collision/visual parity with B1.)
```

**Notes for the implementer:**
- The exact `_opening_lane_cells` math is the one detail to nail with a quick in-editor check on
  the real pieces (corridor_h/v, box_small/large, hub) — confirm the capped cells fall on the
  perimeter gap (not a cell deeper inside the floor, not a cell out in void). The inset-by-one is
  the load-bearing fact: the marker is *interior*, the wall gap is *one cell outward*.
- Run the pass **once**, after `generate()`, before/at `_materialise_band`. Do **not** mutate
  `band.open_sockets` membership or `band.pieces`.
- Capping by **writing into the owner's own `Geometry` layer** keeps the cap inside the piece's
  existing collision setup and moves with the piece if anything re-parents it.

---

## 5. Files to touch

| File | Change |
|---|---|
| `systems/bandgen/band_generator.gd` *(or a small new `systems/bandgen/socket_sealer.gd`)* | Add the `seal_unused_sockets(band, cell_size_px)` pass + `_opening_lane_cells` / `_place_wall_cap` helpers. A separate `socket_sealer.gd` (RefCounted) is cleaner — keeps the pure-function `generate()` untouched and makes the determinism guarantee obvious. **Recommended: new `socket_sealer.gd`.** |
| `scenes/game/main_game.gd` | Call `seal_unused_sockets(band, cell_size)` in `_materialise_band` (after pieces are parented, before/independent of gate placement) so live geometry is sealed. **This is the single integration site** — the ratified seam (§7.4): the seal runs at materialisation and is **not** baked into the `Band` object, keeping `generate()` a pure layout function. |
| `bands/pieces/zone_piece.gd` *(read-only reference; no change)* | The cap **reuses the existing greybox WALL tile/atlas** the pieces already use (Director decision §7.1) — no distinct cap color. No change to this file. |
| `data/tilesets/greybox.tres` *(no change)* | **Decided (§7.1): reuse the existing WALL tile — no new cap tile.** This file is untouched. |
| `tests/test_bandgen_determinism.gd` *(extend)* + a new walk-off check | Add: (1) `fingerprint(seed)` identical with the seal pass applied vs not (proves no layout perturbation); (2) a sweep asserting **no `world`-collision gap remains** at any `band.open_sockets` opening after sealing (the "no open socket" invariant) across a seed sweep. |

**Disjointness for the wave-1 parallel fan-out:** BUG3 touches `band_generator.gd`/a new
`socket_sealer.gd`, `main_game.gd`'s `_materialise_band`, and the bandgen test — **disjoint** from
CFG (`main_game.tscn` UI scene + new Config UI), TEL (`telemetry/` + `event_bus.gd`), and the
`[GS]` bug fixes (`game_state.gd`). It touches **no** `event_bus.gd` and **no** `game_state.gd`, so
it runs cleanly in parallel per the §6 wave plan.

---

## 6. Acceptance criteria

Restated from the M1.1 breakdown (§4 BUG3) and made testable:

1. **No open socket off-map.** A generated + sealed band has **no socket opening leading off-map** —
   every cell in every `OpenSocket`'s opening lane carries `world`-layer wall collision after the
   seal pass. (Mated doorways are untouched and stay walkable.)
2. **Player cannot walk into void — any seed.** Across a **determinism / seed sweep** (e.g. seeds
   covering the test set used by `test_bandgen_determinism.gd`), there is no reachable boundary
   through which a `CharacterBody2D` on the player layer can exit the band into untiled void. (Test
   as a structural invariant: every floor cell on the band perimeter abuts either another piece's
   floor or a wall cap — no floor cell faces an empty off-map cell.)
3. **`band.fingerprint()` preserved.** For every seed in the sweep, `fingerprint(seed)` is
   **byte-identical** with and without the seal pass, and identical across repeated runs of the same
   seed. The seal pass consumes **zero** RNG draws and adds/reorders **zero** pieces. (B2 determinism
   contract intact — the most important guard.)
4. **Baseline behaviour otherwise unchanged.** With all oppositions OFF, the loop is still the M1.0
   spine; sealing only *adds* boundary walls — it changes no piece, no depth, no reward, no spawn.
5. **R4-ready.** The pass caps the leftover frontier correctly when `branch_chance > 0` produces
   dead-ends (a dead-end socket is sealed exactly like a terminal socket) — verified by a sweep with
   `branch_chance` raised, fingerprint still stable for a given seed+config.

---

## 7. Resolved Decisions (Director-ratified 2026-06-19 — apply-all-recommendations)

The Director adopted **every recommendation** in this section as a ratified decision. Each entry
below states the committed decision; the body of this doc commits to these choices (see §3, §4, §5).

1. **Cap as collision-only vs. visible greybox wall.**
   **Decision: visible greybox wall, reusing the existing WALL tile** (atlas `(1,0)`) — no new,
   distinct cap tile.
   *Rationale:* the player reads "this is a wall, turn around" (no confusing invisible collider),
   and reusing the existing WALL tile keeps R4 navigation fair with zero new authored assets.
2. **Camera clamping.**
   **Decision: out of scope for BUG3** — BUG3 = "can't walk off." Camera-clamp is flagged as a
   small follow-up and folded into R4's vision/fog work.
   *Rationale:* sealing physics is a geometry fix; clamping the camera is camera work that belongs
   with R4's vision lever, so it ships separately.
3. **Interaction with R4's intentional dead-ends — clarification.**
   **Decision: a dead-end is a *sealed terminus*, never an open void edge** — R4's spec treats
   "dead-end" as "sealed socket," and BUG3 caps every unmated opening (terminal *and* dead-end).
   *Rationale:* BUG3 and R4 are complementary — BUG3 makes a dead-end legitimately dead; R4 just
   produces more of them by branching, with no conflict.
4. **Where to run the pass — generator vs. materialisation.**
   **Decision: keep `generate()` a pure layout function and run the seal at materialisation**
   (`main_game.gd`); the seal is **not** baked into the `Band` object.
   *Rationale:* this keeps the determinism surface (`fingerprint`) provably independent of sealing
   and keeps `generate()` cleanest.
