class_name ZonePiece
extends Node2D
## ZonePiece — root script for every hand-authored zone-piece scene (B1).
##
## A zone-piece is the smallest reusable unit of band geometry: a `Geometry`
## TileMapLayer blockout plus a set of tagged `Marker2D` sockets. B2 instances
## many of these and stitches them by matching opposite-facing sockets.
##
## Authoring contract (do not violate — B2 determinism depends on it):
##   - Sockets are `Marker2D` children of a `Sockets` node, in group "socket".
##   - Each socket carries metas `dir` (ZoneSocket.Dir) and `width_cells` (int).
##   - The Marker2D sits on the LAST INTERIOR FLOOR CELL of the opening,
##     centered on its width (B1 canonical rule). Its cell coord is
##     floor(local_pos / cell_size_px); the mating neighbour cell is
##     that + ZoneSocket.dir_to_cell(dir).
##   - All socket metadata is STATIC, set in-editor, never computed at runtime.

## Stable identifier for this piece (used by B2's catalog / logging).
@export var piece_id: StringName = &"unnamed"

## Editor-visible footprint convenience. Authoritative value is recomputed in
## _ready() from the Geometry layer — keep this in sync but trust the computed
## one (footprint_cells / occupied_cells) for any placement logic.
@export var size_cells: Vector2i = Vector2i.ONE

## Cell edge length in pixels. Project-wide convention is 16 (B1).
@export var cell_size_px: int = 16

## A single authored socket, resolved from its Marker2D at load.
class SocketInfo:
	var dir: ZoneSocket.Dir
	var local_pos: Vector2      # Marker2D position, piece-local
	var width_cells: int
	## Integer cell coordinate of the socket's boundary floor cell.
	var cell: Vector2i

	func _to_string() -> String:
		return "Socket(%s @ %s cell=%s w=%d)" % [
			ZoneSocket.dir_name(dir), local_pos, cell, width_cells]

## Sockets collected at load, in authored child order.
var sockets: Array[SocketInfo] = []

## Minimal integer Rect2i enclosing all set cells (from get_used_rect()).
var footprint_cells: Rect2i = Rect2i()

## Exact set of occupied cells (from get_used_cells()) — use this for B2's
## overlap test so non-rectangular pieces (the L-bend) don't reserve empty
## corner cells.
var occupied_cells: Array[Vector2i] = []


func _ready() -> void:
	_compute_footprint()
	_collect_sockets()


func _compute_footprint() -> void:
	var geo := get_node_or_null("Geometry") as TileMapLayer
	if geo == null:
		push_warning("ZonePiece '%s' has no Geometry TileMapLayer." % piece_id)
		return
	footprint_cells = geo.get_used_rect()
	occupied_cells = geo.get_used_cells()
	# Keep the editor convenience field in lockstep with the authored tiles.
	size_cells = footprint_cells.size


func _collect_sockets() -> void:
	sockets.clear()
	var holder := get_node_or_null("Sockets")
	if holder == null:
		push_warning("ZonePiece '%s' has no Sockets node." % piece_id)
		return
	for m in holder.get_children():
		if m is Marker2D:
			var s := SocketInfo.new()
			s.dir = int(m.get_meta(&"dir", ZoneSocket.Dir.N)) as ZoneSocket.Dir
			s.local_pos = m.position
			s.width_cells = int(m.get_meta(&"width_cells", 1))
			s.cell = Vector2i(
				int(floor(s.local_pos.x / float(cell_size_px))),
				int(floor(s.local_pos.y / float(cell_size_px))))
			sockets.append(s)


## Sockets facing a given direction — B2 uses this to find candidate mates.
func sockets_facing(d: ZoneSocket.Dir) -> Array[SocketInfo]:
	var out: Array[SocketInfo] = []
	for s in sockets:
		if s.dir == d:
			out.append(s)
	return out
