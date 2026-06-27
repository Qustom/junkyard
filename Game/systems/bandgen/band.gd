class_name Band
extends RefCounted
## Band — the assembled room-graph: an ordered list of PlacedPiece plus the
## occupancy + frontier data downstream systems (B3 depth axis, a future
## loop-closing pass) consume.
##
## A Band is a pure data container produced by BandGenerator. It does NOT own
## the band_root scene node; the generator parents the piece instances and the
## Band just references them. Run-state, never persisted (CLAUDE.md run/meta
## boundary): a band is regenerated from its seed, never saved.

## Placed pieces in PLACEMENT ORDER — the fingerprint and B3 depth both rely on
## this being deterministic.
var pieces: Array[PlacedPiece] = []

## Set of every occupied band-global cell (Dictionary used as a set:
## Vector2i -> true) for O(1) overlap rejection.
var occupied: Dictionary = {}

## The entry-gate piece (pieces[0]). Where the player spawns; flood-fill root.
var entry_piece: PlacedPiece

## The deepest piece (last on the spine) — B3's extraction/risk anchor.
var deepest_piece: PlacedPiece

## Open sockets left unconsumed after generation. Retained (with `occupied`) so
## a later loop-closing pass (loop_back_count > 0) has everything it needs; no
## loop logic runs in M1.
var open_sockets: Array[OpenSocket] = []

## The seed this band was actually generated from (may be a derived retry seed).
var resolved_seed: int = 0

## The original seed requested by the caller (stable across retries).
var requested_seed: int = 0

## Deepest depth_index found by DepthGrader (entry == 0). 0 before grading or on
## a single-piece band. Used to normalise depth_norm.
var max_depth: int = 0


## Mark a piece's footprint as occupied. Cells are already band-global.
func occupy(piece: PlacedPiece) -> void:
	for c in piece.footprint_cells:
		occupied[c] = true


## True if none of `cells` (band-global) collide with already-placed geometry.
func fits(cells: Array[Vector2i]) -> bool:
	for c in cells:
		if occupied.has(c):
			return false
	return true


## Deterministic layout fingerprint: ordered "piece_id@offset#mated" hashed.
## Same seed -> byte-identical string (acceptance bar).
func fingerprint() -> String:
	var parts := PackedStringArray()
	for p in pieces:
		parts.append("%s@%s#%d" % [p.piece_id, p.offset_cell, p.mated_socket_index])
	return "|".join(parts).sha256_text()
