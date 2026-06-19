class_name SocketSealer
extends RefCounted
## SocketSealer (BUG3 → BUG4) — the post-placement "seal the band perimeter" pass.
##
## A generated band is a linear (M1) or branching (R4) spine of solid-walled
## greybox pieces stitched at mated sockets. Anywhere a FLOOR (walkable) cell sits
## on the band perimeter with its outward neighbour landing on off-map void, the
## player can walk straight off the map. This pass seals every such edge with a
## WALL cap so the band is a closed play space.
##
## BUG4 — branch-rate-independent seal. BUG3 capped only `band.open_sockets` (the
## unmated frontier the generator happened to retain). On a linear spine that set
## IS the full leak set, but a branchy R4 layout (`r4_branch_per_depth ≳ 0.12`)
## leaves floor-edge-facing-void cells OUTSIDE `open_sockets` — consumed sockets
## whose mate only partially overlapped, and perimeter floor never enumerated as a
## socket at all. So this pass is now GEOMETRY-KEYED, not frontier-keyed: it builds
## the band-global FLOOR set across ALL pieces and caps every floor cell's outward
## 4-neighbour that is not itself floor. This is the exact inverse of the test's
## leak condition (`_count_floor_facing_void`), so "no floor cell faces void" holds
## BY CONSTRUCTION on any seed at any branch rate — independent of the frontier.
##
## The doorway guard is exact (not a heuristic): a mated doorway's outward
## neighbour is ANOTHER piece's floor cell, present in the band-global FLOOR set, so
## the `floor_set.has(n)` skip protects it. Building ONE global set (vs per-piece)
## is what makes that guard exact — it uses the identical FLOOR↔FLOOR 4-adjacency
## the generator's connectivity flood-fill defines as a real walkable doorway.
##
## DETERMINISM IS SACRED (B2 fingerprint). This pass:
##   - runs at MATERIALISATION, after BandGenerator.generate() returns its Band;
##   - reads the already-final, deterministic `PlacedPiece.floor_cells`
##     (captured pre-seal, so caps it adds never pollute the floor truth);
##   - adds ONLY collision/visual geometry (WALL tiles in each owner's Geometry
##     TileMapLayer) — it adds/removes/reorders NO pieces and rolls ZERO RNG.
## Therefore band.fingerprint() is byte-identical with and without the seal pass
## for any seed (verified by tests/test_bandgen_determinism).
##
## The cap reuses the EXISTING greybox WALL tile (source 0, atlas (1,0)) the pieces
## already carry — no new authored asset (Director decision §7.1). Writing into the
## owner piece's own Geometry layer keeps the cap inside that piece's existing
## collision setup and moving with it if anything re-parents the piece.

## Greybox tileset source id (data/tilesets/greybox.tres sources/0) and the WALL
## atlas coords — the cell-covering collision tile on the `world` layer. Confirmed
## against the authored piece scenes (all pieces use source 0, WALL == (1,0)).
const GREYBOX_SOURCE_ID := 0
const WALL_ATLAS := Vector2i(1, 0)


## Seal the band perimeter so no FLOOR cell faces off-map void. Geometry-keyed:
## caps every floor cell's outward 4-neighbour that is not itself floor (so a mated
## doorway — whose neighbour IS another piece's floor — is left walkable). Reads the
## final band, mutates only live Geometry tiles. Idempotent (writing WALL over an
## existing WALL is a no-op; the floor-set guard means a FLOOR cell is never
## overwritten). cell_size_px is accepted for API symmetry with the spec; the
## tile-write seam works in pure cell space and is scale-correct by construction
## (relevant because I1 may scale pieces in parallel), so it is ignored here.
func seal_unused_sockets(band: Band, _cell_size_px: int = 0) -> void:
	if band == null:
		return

	# 1. Band-global FLOOR set across ALL pieces (the walkable truth). O(total
	#    cells). floor_cells is captured pre-seal, so caps we add never appear here
	#    as "floor". Maps each floor cell -> its owning piece (the cap target layer).
	var floor_set := {}                                   # Vector2i -> PlacedPiece
	for p in band.pieces:
		for c in p.floor_cells:
			floor_set[c] = p

	# 2. For every floor cell, inspect its 4 outward neighbours. A neighbour that is
	#    NOT floor is either (a) this/another piece's perimeter WALL (already sealed
	#    — writing WALL is a no-op) or (b) OFF-MAP VOID (the leak we must cap). We
	#    cap by writing WALL at the neighbour cell, owned by the floor cell's piece.
	#    We do NOT need to distinguish wall-vs-void: writing WALL onto either is
	#    correct and idempotent — the ONLY cell we must never overwrite is a FLOOR
	#    cell, and the floor_set.has(n) guard skips exactly those (mated doorways +
	#    interior links).
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for cell in floor_set:
		var owner: PlacedPiece = floor_set[cell]
		for step in steps:
			var n: Vector2i = cell + step
			if floor_set.has(n):
				continue                                  # mated doorway / interior — leave walkable
			_place_wall_cap(owner, n)                     # seal: WALL over void OR over existing wall (no-op)


## Write a WALL cell at a band-global cell into the owner piece's Geometry layer.
## global_cell -> owner-local cell via `local_cell = global_cell - owner.offset_cell`
## (the piece materialises at offset_cell * cell_size, so global == local + offset).
## A TileMapLayer is sparse/unbounded, so a cap written "outside" the owner's
## authored rect still produces a valid collision cell at the right band-global
## position (collision is per-cell — no clamping or owner-reassignment needed).
## Reuses the existing greybox WALL tile so collision + look match B1 exactly.
func _place_wall_cap(owner: PlacedPiece, global_cell: Vector2i) -> void:
	if owner == null or owner.instance == null:
		return
	var geo := owner.instance.get_node_or_null("Geometry") as TileMapLayer
	if geo == null:
		return
	var local_cell := global_cell - owner.offset_cell
	geo.set_cell(local_cell, GREYBOX_SOURCE_ID, WALL_ATLAS)
