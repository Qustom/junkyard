class_name PlacedPiece
extends RefCounted
## PlacedPiece — one instanced ZonePiece fixed into a band at an integer-cell
## offset, plus the bookkeeping B2's stitcher needs.
##
## All placement lives in integer CELL space (Vector2i). Pixels are derived only
## at the final instance.position = offset_cell * cell_size_px step (see Band).
## This keeps the occupancy set, overlap test, and determinism fingerprint on
## exact integer math — no float accumulation in the layout path (B2 open-Q:
## "Coordinate space for offsets").

## Stable piece identity (from ZonePiece.piece_id) — used in the fingerprint.
var piece_id: StringName = &""

## The instanced scene root. May or may not be in the tree; geometry/socket data
## is captured into this struct so the generator never depends on _ready timing.
var instance: ZonePiece

## Top-left cell offset of this piece's local cell space within the band.
## global_cell = local_cell + offset_cell.
var offset_cell: Vector2i = Vector2i.ZERO

## Exact occupied cells in BAND-GLOBAL coordinates (offset already applied).
## Derived from the piece's get_used_cells() so non-rectangular pieces (the
## L-bend) don't reserve empty corner cells.
var footprint_cells: Array[Vector2i] = []

## Walkable (FLOOR) cells in BAND-GLOBAL coordinates. Subset of footprint_cells
## used for the "connected AND walkable" flood-fill — two pieces only count as
## connected if their FLOOR cells are 4-adjacent (a real doorway, not a shared
## wall), so the connectivity guarantee is a true traversability guarantee.
var floor_cells: Array[Vector2i] = []

## Open sockets contributed to the frontier, in BAND-GLOBAL cell coords.
## The socket mated to the parent is excluded.
var open_sockets: Array[OpenSocket] = []

## Identity of the socket on THIS piece that mated to its parent (-1 for entry).
## Part of the fingerprint so a rotated/mirrored mate is distinguishable.
var mated_socket_index: int = -1


func pixel_position(cell_size_px: int) -> Vector2:
	return Vector2(offset_cell * cell_size_px)
