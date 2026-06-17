class_name DepthGrader
extends RefCounted
## DepthGrader — annotates a Band with its depth axis (B3).
##
## Pure graph function over B2's output: no RNG, fully determined by the band's
## layout. Same band in -> same depths out. Assigns, per PlacedPiece:
##   - depth_index : BFS hops from the entry gate (entry == 0)
##   - depth_norm  : depth_index / band.max_depth, in [0,1]
##   - dist_to_gate: shortest hops back to the entry (independent reverse BFS)
##
## Depth is measured in PIECE HOPS, not pixels (B3 open-Q recommendation): pure
## integer math over B2's deterministic graph, trivially reproducible, and on a
## linear band it tracks physical backtrack length closely enough that players
## read "deeper = farther home" correctly.
##
## Adjacency is derived structurally from FLOOR-cell 4-adjacency (a real walkable
## doorway, never a shared wall) — the same definition BandGenerator uses for its
## connectivity guarantee — so the depth graph and the traversability graph agree
## exactly, and branches/loops are handled the moment B2 enables them.

const _STEPS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


## Annotate every piece with depth_index + depth_norm, and set band.max_depth.
## Idempotent and deterministic.
func grade(band: Band) -> void:
	if band == null or band.pieces.is_empty():
		return

	var adjacency := _build_adjacency(band)
	var entry_idx := band.pieces.find(band.entry_piece)
	if entry_idx == -1:
		entry_idx = 0  # defensive: treat first piece as the gate

	var depths := _bfs_distances(band, adjacency, entry_idx)

	var max_depth := 0
	for i in band.pieces.size():
		var d: int = depths[i]
		# Unreachable pieces (shouldn't happen — B2 guarantees connectivity) keep
		# the deepest known distance so they never read as "shallow".
		if d < 0:
			d = band.pieces.size()
		band.pieces[i].depth_index = d
		max_depth = maxi(max_depth, d)

	band.max_depth = max_depth
	for p in band.pieces:
		p.depth_norm = 0.0 if max_depth == 0 else float(p.depth_index) / float(max_depth)


## Shortest hops back to the entry gate for every piece. On the linear spine this
## equals depth_index; computed independently so divergent-branch return
## distances are already correct when B2's branch_chance goes > 0 (reward can
## then key off dist_to_gate instead of raw depth).
func compute_return_distance(band: Band) -> void:
	if band == null or band.pieces.is_empty():
		return

	# The graph is undirected (walkable doorways are bidirectional), so the
	# shortest path home from a piece is symmetric to the shortest path out to
	# it: a single BFS rooted at the entry gives both. We run a fresh reverse BFS
	# anyway (same root, same result) to keep the two concerns decoupled and make
	# the "true BFS, not the = depth_index shortcut" guarantee explicit.
	var adjacency := _build_adjacency(band)
	var entry_idx := band.pieces.find(band.entry_piece)
	if entry_idx == -1:
		entry_idx = 0

	var dist := _bfs_distances(band, adjacency, entry_idx)
	for i in band.pieces.size():
		var d: int = dist[i]
		if d < 0:
			d = band.pieces.size()
		band.pieces[i].dist_to_gate = d


# --- Graph helpers -----------------------------------------------------------

## Piece-index adjacency list via FLOOR-cell 4-adjacency. Neighbours are emitted
## in ascending piece-index order so traversal is deterministic regardless of
## placement/append order.
func _build_adjacency(band: Band) -> Array:
	var cell_owner := {}
	for i in band.pieces.size():
		for c in band.pieces[i].floor_cells:
			cell_owner[c] = i

	var adjacency: Array = []
	for i in band.pieces.size():
		adjacency.append([] as Array[int])

	for i in band.pieces.size():
		var seen := {}
		for c in band.pieces[i].floor_cells:
			for step in _STEPS:
				var n: Vector2i = c + step
				if cell_owner.has(n):
					var j: int = cell_owner[n]
					if j != i and not seen.has(j):
						seen[j] = true
						adjacency[i].append(j)
		adjacency[i].sort()  # ascending index -> stable BFS order
	return adjacency


## BFS hop distances from root over the adjacency list. -1 for unreachable.
func _bfs_distances(band: Band, adjacency: Array, root: int) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(band.pieces.size())
	dist.fill(-1)
	dist[root] = 0
	var queue: Array[int] = [root]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nxt in adjacency[cur]:
			if dist[nxt] == -1:
				dist[nxt] = dist[cur] + 1
				queue.append(nxt)
	return dist
