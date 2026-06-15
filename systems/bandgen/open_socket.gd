class_name OpenSocket
extends RefCounted
## OpenSocket — a frontier connection point: one piece socket, resolved into
## band-global cell space, still available to grow from.
##
## B2 defines its own socket identity here rather than depending on any field
## B1 may not have authored (B1's SocketInfo carries no stable id). The
## (owner, socket_index) pair plus the global cell IS the identity we need.

## The placed piece this socket belongs to.
var owner: PlacedPiece

## Index of the socket within owner.instance.sockets — stable, authored order.
var socket_index: int = 0

## Facing direction of the opening (ZoneSocket.Dir).
var dir: ZoneSocket.Dir = ZoneSocket.Dir.N

## The socket's boundary floor cell in BAND-GLOBAL coordinates.
var cell: Vector2i = Vector2i.ZERO

## Socket opening width in cells (for the dormant width_ok predicate).
var width_cells: int = 2

## Depth (placement order index of the owner) — used for stable frontier sort
## and the "grow the deepest" linear bias.
var depth: int = 0

## Owner footprint rect in BAND-GLOBAL cells (for flush-edge alignment of mates).
var owner_rect: Rect2i = Rect2i()


## The cell on the far side of the opening — where a mate's boundary cell must
## land. global_neighbour = cell + dir_to_cell(dir).
func neighbour_cell() -> Vector2i:
	return cell + ZoneSocket.dir_to_cell(dir)
