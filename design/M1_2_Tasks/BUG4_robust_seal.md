# BUG4 — Branch-rate-independent socket seal

**Milestone:** M1.2 · **Wave:** 1 (Spatial & data foundation) · **Workstream:** correctness
**Design author:** `game-director-designer` (this doc) · **Builder:** `general-purpose`
**dependsOn:** none · **Knobs:** none (correctness fix) · **Telemetry:** none
**Touch:** `systems/bandgen/socket_sealer.gd` (+ acceptance in `tests/test_bandgen_determinism.gd`)

> **This is a DESIGN doc, not an implementation.** It specifies the fix, the recommended
> approach, and the contract the implementing agent builds against. Code sketches are
> illustrative; the canonical APIs are in `M1_As_Built.md` and the real source files cited
> below (which win on any disagreement). DESIGN ONLY — no code/`.tres` ships from this task.

---

## 1. Goal & premise research

### 1.1 Goal (one sentence)

Make the band seal **branch-rate-independent**: after the seal pass, **no floor cell faces
off-map void on any seed at any branch rate** — by capping *all* outward-facing perimeter
floor edges, not just the unmated frontier (`band.open_sockets`).

### 1.2 Why now — the residual gap BUG3 left (cited evidence)

BUG3 (`design/M1_1_Tasks/BUG3_open_sockets.md`) shipped Option (a): a post-placement
`SocketSealer` that iterates `band.open_sockets` (the retained, unmated frontier) and writes
a 2-cell WALL cap across each opening. That sealed the **M1.0 linear spine and the
recommended-preset R4 envelope cleanly** — but R4's *deep branching* surfaced a residual gap:

- **`M1.2_Breakdown.md` §BUG4 (lines 63–65):** "at high R4 branch rates some seeds leave 2–6
  floor cells facing void because `SocketSealer` caps only `band.open_sockets`. Cap **all**
  outward-facing perimeter floor edges (any floor cell whose outward neighbour is neither
  floor nor a mated doorway) so the seal is **branch-rate-independent**. Geometry-only pass;
  `band.fingerprint()` unchanged."

- **`design/DESIGN_DEVIATIONS_HISTORY.md` → W2-R4-1 (Director: *Addressed*):** "at
  `r4_branch_per_depth ≳ 0.12` some seeds leave 2–6 floor cells facing off-map void after
  `SocketSealer` (which caps only `band.open_sockets`, missing branchy socket-opening edges).
  Recommended presets S1/S3 seal cleanly (0 leaks/9 seeds), so the realistic envelope is fine;
  gap appears past ~2× the recommended branch rate." Filed as BUG4.

- **`design/M1_1_Tasks/R4_maze_navigation.md` §6 as-built note (line 245):** the gap is
  because "the wave-1 sealer caps only `band.open_sockets` (the unmated frontier) and **misses
  branchy socket-opening edges not in that set.**" Safe envelope = presets **S1
  (`branch_per_depth=0.06`)** / **S3 (`0.05`)**; high-branch sweeps (`> ~0.08`) are gated
  until BUG4 lands.

**Why it matters in M1.2:** I1 enlarges/branchifies the spatial canvas (more rooms, possibly
bigger rooms) and I4 reworks vision/fog — both assume a **bounded** play space (R4 §6: a
dead-end is only a fair "wrong turn" if it terminates in a *wall*, not in nothing; limited
vision is only fair inside a sealed space). BUG4 removes the branch-rate gate so the Director
can sweep the *full* spatial range without re-introducing the walk-off-into-void confound that
BUG3 was meant to eliminate. This is a **correctness fix**, not navigation tuning or art.

### 1.3 Root cause — why `open_sockets`-only misses edges

The defect is a **set-membership gap**, not a geometry-math bug. Trace the data:

1. **What a piece's open edge is.** B1 greybox pieces are solid-walled rects: a perimeter ring
   of WALL tiles (atlas `(1,0)`, carries the cell-covering collision polygon on the `world`
   layer) around a FLOOR interior (atlas `(0,0)`, no collision). A **socket** is a deliberate
   2-cell gap punched in that wall ring (`band_generator.gd` §line 162 note; verified against
   `_capture` at lines 332–340, where `floor_cells` = cells whose atlas is `(0,0)`).

2. **What the generator retains.** `BandGenerator._generate_once` grows the spine, then sets
   `band.open_sockets = frontier` (line 120) — **only the sockets still on the frontier when
   the loop stopped.** A socket that was *consumed* (mated) is removed from the frontier
   (`_grow`/`_mate` path) and never returns to `open_sockets`.

3. **Where the gap opens.** On a linear spine, the only unmated openings ARE the leftover
   frontier, so `open_sockets` == the full leak set and BUG3 sealed everything. But a
   **branchy** layout (R4's `branch_per_depth > 0`) places multi-exit pieces (box_large,
   room_hub) whose extra sockets get *partially* consumed. The failure modes:
   - A piece face that was **never a socket at all** can still end up as a perimeter floor
     edge facing void if a neighbour was *expected* but the branch the generator grew turned
     elsewhere — i.e. floor cells whose outward neighbour is empty but which were never
     enumerated as an `OpenSocket` (they're interior-floor-against-the-edge geometry the
     `open_sockets` set never tracked).
   - More commonly: a socket that the matcher **counted as consumed** because a mate was
     placed, but where the mate's flush-edge alignment left a **partial overlap** — some of
     the 2-cell opening lane abuts the mate's floor (a real doorway) while the rest abuts
     **void** because the mate is a different width/shape. The consumed socket leaves
     `open_sockets`, so BUG3 never revisits it, yet 1–2 of its lane cells still face void.

   Both are **floor cells on the band perimeter whose outward neighbour is neither another
   piece's floor nor a wall** — exactly the condition the existing acceptance check
   `_count_floor_facing_void` (`tests/test_bandgen_determinism.gd` lines 173–197) counts as a
   leak. **The test already defines the true invariant; the sealer just doesn't enforce it
   for edges outside `open_sockets`.**

### 1.4 The real APIs this fix reads (verified against source)

| Symbol | Where | What BUG4 uses it for |
|---|---|---|
| `Band.pieces: Array[PlacedPiece]` | `systems/bandgen/band.gd:14` | iterate every placed piece (in placement order — irrelevant to a geometry pass, but stable) |
| `PlacedPiece.floor_cells: Array[Vector2i]` | `systems/bandgen/placed_piece.gd:32` | band-global FLOOR (walkable) cells; the perimeter-edge source of truth |
| `PlacedPiece.offset_cell: Vector2i` | `placed_piece.gd:21` | `local_cell = global_cell - offset_cell` to write into the owner's Geometry layer |
| `PlacedPiece.instance` (`ZonePiece`) | `placed_piece.gd:18` | `.get_node_or_null("Geometry") as TileMapLayer` — the live collision layer |
| `Band.open_sockets: Array[OpenSocket]` | `band.gd:29` | (optionally) still consulted by the existing pass; BUG4 either subsumes or complements it |
| FLOOR atlas `(0,0)` / WALL atlas `(1,0)`, source `0` | `band_generator.gd:336–340`; `socket_sealer.gd:28–29` | tile identity; cap reuses the existing WALL tile |
| `SocketSealer.GREYBOX_SOURCE_ID`, `WALL_ATLAS`, `_place_wall_cap()` | `systems/bandgen/socket_sealer.gd:28–29, 87–94` | reuse as-is — the *write* primitive is correct; only the *which-cells* set changes |
| `_count_floor_facing_void(band)` | `tests/test_bandgen_determinism.gd:173–197` | the canonical leak definition BUG4 must drive to 0; reuse its geometry as the spec for the sealer |
| `band.fingerprint()` | `band.gd:58–62` | `sha256` of ordered `piece_id@offset#mated`; MUST be byte-identical pre/post seal |

**Note — the `local==(0,0)` vs band-global trap.** `_count_floor_facing_void` reads FLOOR/WALL
sets straight off the **live, already-sealed** Geometry layers (`geo.get_used_cells()`), so a
WALL cap BUG4 writes shows up in `wall_set` and stops counting as a leak. `PlacedPiece.floor_cells`
is captured **at generation, before sealing** (it's the pristine walkable set). BUG4 should treat
`floor_cells` as the *floor* truth (capping never removes floor) and treat "a cap was written
here" as turning that boundary into wall — see §2's two-set construction.

---

## 2. Design / approach + pseudocode

### 2.1 The fix in one line

Replace the **frontier-keyed** cap-cell selection with a **geometry-keyed** one: build the
band-global FLOOR set across *all* pieces, and for every floor cell whose outward 4-neighbour
is **neither floor nor an already-mated doorway**, write a WALL cap at that **outward neighbour
cell**. This is exactly the inverse of `_count_floor_facing_void`'s leak condition, so the
post-condition is "that check returns 0" by construction — independent of branch rate.

### 2.2 Why this is deterministic, O(cells), and fingerprint-safe

- **No RNG, no piece add/reorder.** Like BUG3, BUG4 runs at **materialisation**
  (`main_game.gd:310`, `SocketSealer.new().seal_unused_sockets(band, cell_size)`), *after*
  `generate()` has returned the final `Band`. It reads `band.pieces[*].floor_cells` (already
  fixed) and writes only WALL tiles into existing Geometry layers. It touches **neither `RNG`
  nor `band.pieces` membership/order**. Therefore `band.fingerprint()` — which hashes only
  `piece_id@offset#mated` over `band.pieces` — is **byte-identical with and without the pass**.
  *Determinism is sacred (B2 fingerprint contract; `R4 §10 Q5`: all-off config byte-matches the
  M1.0 band for a seed). This is the single hardest acceptance bar.*
- **Geometry-only, idempotent.** Writing WALL over an existing WALL cell is a no-op (Godot
  `set_cell` overwrite); writing WALL onto a void cell adds collision. The pass never writes
  onto a FLOOR cell (see the doorway guard, §2.4), so it can never seal a walkable cell.
- **O(cells).** One pass to build the FLOOR set (Σ `floor_cells` ≈ total walkable cells), one
  pass over floor cells × 4 neighbours with O(1) dictionary lookups. Linear in band size; at
  I1's larger room counts it stays O(total cells) (see Open Question 4).

### 2.3 Pseudocode (illustrative — against the real data)

```gdscript
# systems/bandgen/socket_sealer.gd — generalised seal. Runs at materialisation, after
# generate(). No RNG, no piece edits -> band.fingerprint() byte-identical (B2 sacred).

func seal_unused_sockets(band: Band, _cell_size_px: int = 0) -> void:
    if band == null:
        return

    # 1. Band-global FLOOR set across ALL pieces (the walkable truth). O(total cells).
    #    floor_cells is captured pre-seal, so caps we add never appear here as "floor".
    var floor_set := {}                                   # Vector2i -> PlacedPiece (owner)
    for p in band.pieces:
        for c in p.floor_cells:
            floor_set[c] = p

    # 2. For every floor cell, inspect its 4 outward neighbours. Any neighbour that is
    #    NOT floor is either (a) this/another piece's perimeter WALL (already sealed —
    #    writing WALL is a no-op) or (b) OFF-MAP VOID (the leak we must cap). We cap by
    #    writing WALL at the neighbour cell, owned by the floor cell's piece. Capping a
    #    perimeter-wall cell is harmless; capping a void cell is the fix. We do NOT need
    #    to distinguish wall-vs-void here because writing WALL onto either is correct and
    #    idempotent — the ONLY cell we must never overwrite is a FLOOR cell (a doorway).
    var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
    for cell in floor_set:
        var owner: PlacedPiece = floor_set[cell]
        for step in steps:
            var n: Vector2i = cell + step
            if floor_set.has(n):
                continue                                  # mated doorway / interior — leave walkable
            _place_wall_cap(owner, n)                     # seal: WALL over void OR over existing wall (no-op)

# _place_wall_cap is UNCHANGED from BUG3 (socket_sealer.gd:87-94): writes WALL_ATLAS
# (Vector2i(1,0)), source GREYBOX_SOURCE_ID (0), at (n - owner.offset_cell) into the
# owner's "Geometry" TileMapLayer. Reuses the existing greybox WALL tile (BUG3 §7.1).
```

### 2.4 The doorway guard (the one subtlety)

A **mated doorway** is the case where a floor cell's outward neighbour `n` is *another piece's
floor cell* — that's the 4-adjacent FLOOR↔FLOOR link the generator's connectivity flood-fill
(`band_generator.gd:444–445`) defines as a real walkable doorway. The pseudocode handles this
**automatically**: because `floor_set` is built across **all** pieces, a doorway neighbour is in
`floor_set`, the `floor_set.has(n)` guard fires, and we `continue` — **never capping it.** This
is why building **one global floor set** (vs per-piece) is essential: a per-piece-only check
would see the neighbour piece's floor as "not my floor" and wrongly wall off real doorways. *The
global set is what makes "distinguish a mated doorway from a void gap" fall out for free.*

### 2.5 How this subsumes the old `open_sockets`-only pass

The new condition — "any floor cell whose outward neighbour is not floor gets a wall there" —
is a **strict superset** of "cap each `open_sockets` opening lane":
- Every unmated frontier socket's opening lane is, by construction, a run of floor-edge cells
  facing void → the new pass caps them (it caps *every* such edge, frontier-tracked or not).
- The branchy edges W2-R4-1 found (consumed-but-partially-overlapping sockets, never-socket
  perimeter floor) are **not** in `open_sockets` but **are** floor-cells-facing-void → the new
  pass caps them; the old pass missed them.

So BUG4 can **replace** the `open_sockets` loop entirely (recommended — see Open Question 1),
making the sealer's correctness depend on **geometry it can fully observe** rather than on a
frontier set the generator happens to retain. The `_opening_lane_cells` helper
(`socket_sealer.gd:58–80`, with its inset-by-one / floor-direction-growth math) becomes dead
code and can be deleted; `_place_wall_cap` is kept verbatim.

### 2.6 Files to touch

| File | Change |
|---|---|
| `systems/bandgen/socket_sealer.gd` | Rewrite `seal_unused_sockets` to the global-floor-set perimeter pass (§2.3). **Keep `_place_wall_cap`, `GREYBOX_SOURCE_ID`, `WALL_ATLAS` verbatim.** Delete `_opening_lane_cells` if the `open_sockets` loop is removed (Open Q1). No new public API; call site in `main_game.gd:310` is unchanged. |
| `tests/test_bandgen_determinism.gd` | Extend the BUG3 seal checks: run the existing `_count_floor_facing_void == 0` assertion across a **high-branch-rate** config sweep (`branch_per_depth ≥ 0.12` — past the W2-R4-1 failure point) and across I1's larger room counts; keep the fingerprint-unchanged-pre/post-seal assertion; keep the non-vacuous "unsealed leaks" guard. No new test infra — the leak counter already exists. |

This is **file-disjoint** from the rest of Wave 1 (I1 → `band_generator.gd`/`run_config.gd`; I5
→ `telemetry.gd`/`version.gd`), so it runs in parallel (Breakdown §line 124).

---

## 3. Acceptance criteria

1. **Branch-rate-independent seal.** Across a seed sweep at **high branch rate**
   (`r4_branch_per_depth ≥ 0.12`, i.e. past the W2-R4-1 failure point) AND at I1's largest
   room-count/size presets, `_count_floor_facing_void(band) == 0` on **every** seed.
2. **No doorway regressions.** No FLOOR cell is ever overwritten; every mated doorway stays
   walkable; the connectivity flood-fill (`_connected`) still passes (a route home always
   exists — R4 §line 25 design boundary).
3. **`band.fingerprint()` byte-identical pre/post seal**, every seed, every config — the seal
   adds/reorders zero pieces and rolls zero RNG. (Existing BUG3.6 assertion, must stay green.)
4. **All-off control unchanged.** With all oppositions OFF, the all-off config still byte-matches
   the M1.0 band for a seed (permanent control; R4 §10 Q5).
5. **Existing tests green:** `tests/test_bandgen_determinism.gd` (BUG3 + R4 sections) and the
   headless smoke test pass.

---

## 4. Open Questions

> All are **implementation/QA calls for Phase 3 / the builder**, not design-vision calls. **No
> Director call is required** — BUG4 is a correctness fix; the W2-R4-1 disposition (*Addressed*)
> already ratifies "cap all outward-facing perimeter floor edges, branch-rate-independent."

1. **Replace vs. augment the `open_sockets` pass?** *Recommendation: replace.* The global-floor
   perimeter pass is a strict superset (§2.5), so keeping the old `open_sockets` loop is
   redundant work and a second code path to keep correct. Replacing it makes correctness depend
   on observable geometry, not on the generator's frontier bookkeeping. *(Builder confirms by
   deleting `_opening_lane_cells` and verifying the test sweep still passes.)*

2. **How to distinguish a mated doorway from a wall-gap so real doorways aren't capped?**
   *Resolved by design (§2.4):* a doorway's outward neighbour is another piece's floor cell, so
   it lives in the **global** `floor_set` and the `floor_set.has(n)` guard skips it. The only
   risk is building the floor set per-piece instead of globally (see Q3). No heuristic needed —
   it's exact set membership.

3. **One global floor set, or per-piece with cross-piece neighbour lookups?** *Recommendation:
   one global set* (§2.4). It's simpler, O(total cells), and is what makes the doorway guard
   exact. A per-piece approach would need every piece to see every other piece's floor to avoid
   capping doorways — i.e. it reconstructs the global set anyway, with more code.

4. **Perf at large room counts (I1)?** The pass is O(total floor cells × 4) with O(1) dict
   lookups; at I1's largest presets this is still linear and runs once at materialisation (not
   per-frame). *Recommendation: accept as-is; if I1 lands very large bands, add a one-line timing
   assertion to the test, but no algorithmic change is anticipated.* (BUG4 should be briefed
   *after* I1's final room-count ceiling is known so the sweep covers it — they're parallel in
   Wave 1, so confirm the ceiling at integration.)

5. **Does the cap belong in `socket_sealer.gd` or a new pass?** *Recommendation: stays in
   `socket_sealer.gd`.* It IS the seal — same responsibility, same call site
   (`main_game.gd:310`), same `_place_wall_cap` primitive. A new file would split one concept
   across two classes. The class doc comment should be updated to describe the generalised
   (perimeter-floor, not frontier-only) contract.

6. **Should the WALL cap remain the visible greybox tile (vs an invisible collider)?**
   *Resolved by BUG3 §7.1 (ratified):* visible greybox WALL tile, reusing atlas `(1,0)` — the
   player reads "wall, turn around," no new asset. BUG4 inherits this unchanged. *(Listed only
   to record that BUG4 does not reopen it.)*
