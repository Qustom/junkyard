class_name ZoneSocket
extends RefCounted
## ZoneSocket — pure static direction utility for zone-piece sockets (B1).
##
## A socket is a tagged, directional connection point on a zone-piece. This
## class owns the canonical cardinal-direction vocabulary shared by the
## authored pieces (zone_piece.gd) and the B2 room-graph generator, so both
## sides agree on what "facing N" means and how two sockets mate.
##
## Autoload-free, no state, no RNG. Determinism (B2 requirement) depends on
## these helpers being pure functions of their input — same Dir in, same
## Vector2i / Dir out, every time.

enum Dir { N, E, S, W }

## Cardinal grid offset for a direction (in cells). The step from a socket's
## own boundary cell to the neighbour cell its opening faces into.
static func dir_to_cell(d: Dir) -> Vector2i:
	match d:
		Dir.N: return Vector2i(0, -1)
		Dir.E: return Vector2i(1, 0)
		Dir.S: return Vector2i(0, 1)
		Dir.W: return Vector2i(-1, 0)
	return Vector2i.ZERO

## A socket can only mate with the opposite-facing socket (an E exit meets a
## W entry). The enum is a Dictionary in GDScript, so index it numerically and
## cast back to Dir rather than subscripting the enum identifier.
static func opposite(d: Dir) -> Dir:
	return ((int(d) + 2) % 4) as Dir

## Human-readable name for a direction (logging / debug).
static func dir_name(d: Dir) -> String:
	match d:
		Dir.N: return "N"
		Dir.E: return "E"
		Dir.S: return "S"
		Dir.W: return "W"
	return "?"
