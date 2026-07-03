class_name ConnectivityGuarantee
extends RefCounted
## ConnectivityGuarantee — the Stage-5 pipeline invariant (M1.9 S5, spec §5).
##
## CHECK: flood-fill from the entry over FLOOR 4-adjacency at CELL level —
## root = first cell of band.entry_piece.floor_cells sorted (y, x); frontier =
## the band-global floor set built from every piece's floor_cells (the
## SocketSealer floor-set construction). Connected ⇔ every floor cell reached.
## Cell-level is deliberately STRONGER than the generator's piece-level
## is_band_connected (§10 Q8): piece-level cannot see an intra-piece stranding.
## RNG-free, pure geometry — like the sealer.
##
## POLICY (pipeline-enforced off the stage traits, §10 Q7):
##   - ASSERT (after pure-socket stages, e.g. SetPieceInject): disconnection is
##     structurally impossible (socket mating IS the connection), so a trip is
##     a real bug -> push_error + band returned as-is (never crash generation).
##   - CARVE (after RESHAPES_FLOOR stages, e.g. WearDecay): "carving a minimal
##     connector" for a doorway-blocking pass IS re-opening the doorway — carve
##     = pop the stage's journal LIFO, reverting committed ops until the
##     flood-fill covers all floor. Deterministic (journal order is
##     deterministic), minimal (stops at first full coverage), asset-free.
##     With WearDecay's inline reject-on-disconnect this should never trigger
##     on a healthy build — it is the invariant's teeth (unit-tested by
##     force-feeding a disconnecting journal).

enum Mode { ASSERT, CARVE }

## Greybox tile constants shared by the decay write/revert path. Same source +
## WALL atlas as SocketSealer (socket_sealer.gd:45-46); FLOOR per
## band_generator.gd:382-385.
const GREYBOX_SOURCE_ID := 0
const FLOOR_ATLAS := Vector2i(0, 0)
const WALL_ATLAS := Vector2i(1, 0)

const _STEPS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


## True iff every band-global floor cell is reachable from the entry piece's
## (y, x)-first floor cell over FLOOR 4-adjacency.
func is_fully_connected(band: Band) -> bool:
	if band == null or band.entry_piece == null:
		return false
	var floor_set := {}                                # Vector2i -> true
	for p in band.pieces:
		for c in p.floor_cells:
			floor_set[c] = true
	if floor_set.is_empty():
		return false
	var root := _sorted_first(band.entry_piece.floor_cells)
	if not floor_set.has(root):
		return false                                   # entry floor gone — stranded by definition
	var reached := {root: true}
	var queue: Array[Vector2i] = [root]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for step in _STEPS:
			var n: Vector2i = cur + step
			if floor_set.has(n) and not reached.has(n):
				reached[n] = true
				queue.append(n)
	return reached.size() == floor_set.size()


## Enforce the invariant after a flavor stage. Returns true when the band is
## fully connected on exit. ASSERT mode fail-louds (push_error) and leaves the
## band as-is; CARVE mode reverts the journal LIFO until coverage is restored.
func enforce(band: Band, mode: Mode, journal: Array = []) -> bool:
	if is_fully_connected(band):
		return true
	if mode == Mode.ASSERT:
		push_error("ConnectivityGuarantee: pure-socket stage disconnected band (seed %d)"
				% (band.resolved_seed if band != null else 0))
		return false
	while not journal.is_empty():                      # CARVE = deterministic LIFO revert
		revert_op(journal.pop_back())
		if is_fully_connected(band):
			return true
	push_error("ConnectivityGuarantee: CARVE exhausted journal, still disconnected (seed %d)"
			% (band.resolved_seed if band != null else 0))
	return false


## Revert one committed journal op: restore each write's prior atlas tile and
## the owner piece's floor_cells membership. Writes are undone in reverse
## order. Journal op shape: { "kind": StringName, "writes": Array[Dictionary
## { "piece": PlacedPiece, "cell": Vector2i (band-global), "prior": Vector2i }] }.
static func revert_op(op: Dictionary) -> void:
	var writes: Array = op["writes"]
	for k in range(writes.size() - 1, -1, -1):
		var w: Dictionary = writes[k]
		var piece: PlacedPiece = w["piece"]
		var cell: Vector2i = w["cell"]
		var prior: Vector2i = w["prior"]
		if piece.instance != null:
			var geo := piece.instance.get_node_or_null("Geometry") as TileMapLayer
			if geo != null:
				geo.set_cell(cell - piece.offset_cell, GREYBOX_SOURCE_ID, prior)
		if prior == FLOOR_ATLAS:
			if not piece.floor_cells.has(cell):
				piece.floor_cells.append(cell)
		else:
			piece.floor_cells.erase(cell)


## (y, x)-minimal cell of a floor list — the deterministic flood-fill root.
func _sorted_first(cells: Array[Vector2i]) -> Vector2i:
	var best := Vector2i.ZERO
	var first := true
	for c in cells:
		if first or c.y < best.y or (c.y == best.y and c.x < best.x):
			best = c
			first = false
	return best
