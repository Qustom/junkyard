class_name SocketSealer
extends RefCounted
## SocketSealer (BUG3) — the post-placement "seal unused sockets" pass.
##
## A generated band is a linear (M1) or branching (R4) spine of solid-walled
## greybox pieces stitched at mated sockets. Every UNMATED socket left on the
## frontier (`band.open_sockets`) is a 2-cell gap punched in a piece's perimeter
## wall that mates with NOTHING — an opening straight onto off-map void the player
## can walk through. This pass seals each one with a 2-cell WALL cap so the band is
## a closed play space (BUG3 acceptance: "no open socket off-map").
##
## DETERMINISM IS SACRED (B2 fingerprint). This pass:
##   - runs at MATERIALISATION, after BandGenerator.generate() returns its Band;
##   - reads the already-final, deterministic `band.open_sockets`;
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


## Seal every unmated socket opening in `band` with a 2-cell WALL cap, so no
## opening leads off-map. Idempotent in effect (writing WALL over WALL is a no-op);
## reads the final band, mutates only live Geometry tiles. cell_size_px is accepted
## for the alternate collider-parenting seam and for API symmetry with the spec; the
## tile-write seam (used here) works in pure cell space and does not need it.
func seal_unused_sockets(band: Band, _cell_size_px: int = 0) -> void:
	if band == null:
		return
	for sock in band.open_sockets:
		for cell in _opening_lane_cells(sock):
			_place_wall_cap(sock.owner, cell)


## The boundary lane an unmated socket opens through, in BAND-GLOBAL cells.
##
## B1 authoring convention (verified against every piece scene): the socket Marker2D
## sits on the LAST INTERIOR FLOOR cell, INSET one cell from the piece edge. Stepping
## one cell along the socket's facing direction lands on the boundary FLOOR cell of
## the opening (`edge_cell`). The opening is `width_cells` wide, spanning along the
## perpendicular axis — but the marker sits at ONE END of it, and which way the gap
## extends (+perp vs -perp) differs per socket (e.g. +perp for N/W, -perp for E/S in
## B1). Rather than hardcode that sign, we read the OWNER's floor cells: the gap is
## the run of boundary cells that ARE floor in the owning piece. We grow from
## edge_cell into whichever perpendicular direction is floor (the wall gap), covering
## width_cells boundary cells. Pure integer-cell math, no RNG, no float; robust to
## any future piece authoring.
func _opening_lane_cells(sock: OpenSocket) -> Array[Vector2i]:
	var facing := ZoneSocket.dir_to_cell(sock.dir)   # +1 along the wall-gap axis
	var perp := Vector2i(facing.y, facing.x)         # opening's width axis
	var edge_cell := sock.cell + facing              # marker is inset one cell; step to the wall gap

	# The owning piece's band-global floor cells, as a set for O(1) lookup.
	var floor_set := {}
	if sock.owner != null:
		for c in sock.owner.floor_cells:
			floor_set[c] = true

	# Pick the gap direction: the boundary partner that is floor in the owner piece.
	# (edge_cell itself is floor; exactly one of edge±perp is the floor gap, the other
	#  is the piece's perimeter wall.) Default to +perp if neither reads as floor
	#  (degenerate/1-wide), so we always seal at least edge_cell.
	var grow := perp
	if floor_set.has(edge_cell - perp) and not floor_set.has(edge_cell + perp):
		grow = -perp

	var cells: Array[Vector2i] = []
	for k in range(maxi(sock.width_cells, 1)):
		cells.append(edge_cell + grow * k)
	return cells


## Write a WALL cell at a band-global cell into the owner piece's Geometry layer.
## global_cell -> owner-local cell via `local_cell = global_cell - owner.offset_cell`
## (the piece materialises at offset_cell * cell_size, so global == local + offset).
## Reuses the existing greybox WALL tile so collision + look match B1 exactly.
func _place_wall_cap(owner: PlacedPiece, global_cell: Vector2i) -> void:
	if owner == null or owner.instance == null:
		return
	var geo := owner.instance.get_node_or_null("Geometry") as TileMapLayer
	if geo == null:
		return
	var local_cell := global_cell - owner.offset_cell
	geo.set_cell(local_cell, GREYBOX_SOURCE_ID, WALL_ATLAS)
