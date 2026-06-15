extends SceneTree
## One-shot generator for the B1 greybox zone-piece scenes.
##
## Builds each piece as: ZonePiece (Node2D, zone_piece.gd)
##   -> Geometry (TileMapLayer, greybox.tres)
##   -> Sockets (Node2D) -> one Marker2D per opening (group "socket",
##                          metas dir + width_cells=2)
## then packs to res://bands/pieces/<id>.tscn.
##
## Authoring rule baked in here (B1 canonical):
##   - 16px cells; perimeter is WALL, interior is FLOOR.
##   - Every opening is OPENING_W (2) cells wide; the wall tiles along that
##     span are replaced with FLOOR so the pawn can pass.
##   - The socket Marker2D sits on the LAST INTERIOR FLOOR CELL of the opening,
##     centered on the opening width (cell center in pixels).
##
## Run: godot --headless --script res://tools/gen_zone_pieces.gd

const CELL := 16
const OPENING_W := 2
const TS_PATH := "res://data/tilesets/greybox.tres"
const SCRIPT_PATH := "res://bands/pieces/zone_piece.gd"
const OUT_DIR := "res://bands/pieces/"

const FLOOR := Vector2i(0, 0)   # atlas coord of FLOOR tile
const WALL := Vector2i(1, 0)    # atlas coord of WALL tile
const SRC_ID := 0

# ZoneSocket.Dir mirror (avoid loading the class at tool time): N=0 E=1 S=2 W=3
const N := 0
const E := 1
const S := 2
const W := 3

var _tileset: TileSet
var _piece_script: Script


func _initialize() -> void:
	_tileset = load(TS_PATH) as TileSet
	_piece_script = load(SCRIPT_PATH) as Script
	if _tileset == null or _piece_script == null:
		printerr("missing tileset or zone_piece.gd")
		quit(1)
		return

	_build_corridor_h()
	_build_corridor_v()
	_build_corridor_l()
	_build_box_small()
	_build_box_large()
	_build_room_hub()

	print("zone pieces generated.")
	quit(0)


# --- Painting helpers -------------------------------------------------------

## Center pixel of a cell.
func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL / 2.0, c.y * CELL + CELL / 2.0)

## Center pixel of a 2-cell-wide opening whose lower cell index is c0 along the
## span axis. For an opening on a vertical wall (N/S), c0 is the start column;
## for a horizontal wall (E/W), c0 is the start row.
func _span_center_x(col0: int) -> float:
	return (col0 + OPENING_W / 2.0) * CELL

func _span_center_y(row0: int) -> float:
	return (row0 + OPENING_W / 2.0) * CELL


## Fill a w x h grid: perimeter WALL, interior FLOOR.
func _fill_rect_room(geo: TileMapLayer, w: int, h: int) -> void:
	for y in h:
		for x in w:
			var on_edge := (x == 0 or y == 0 or x == w - 1 or y == h - 1)
			geo.set_cell(Vector2i(x, y), SRC_ID, WALL if on_edge else FLOOR)


## Carve a 2-wide FLOOR opening through the perimeter wall for a socket, and
## return the SocketInfo (dir, marker cell, marker pixel pos).
## c0 is the start index along the wall's span axis.
func _carve_opening(geo: TileMapLayer, dir: int, w: int, h: int, c0: int) -> Dictionary:
	var marker_cell := Vector2i.ZERO
	match dir:
		N:
			for i in OPENING_W:
				geo.set_cell(Vector2i(c0 + i, 0), SRC_ID, FLOOR)
			# last interior floor cell of the opening = row 1 (just inside top)
			marker_cell = Vector2i(c0, 1)
		S:
			for i in OPENING_W:
				geo.set_cell(Vector2i(c0 + i, h - 1), SRC_ID, FLOOR)
			marker_cell = Vector2i(c0, h - 2)
		W:
			for i in OPENING_W:
				geo.set_cell(Vector2i(0, c0 + i), SRC_ID, FLOOR)
			marker_cell = Vector2i(1, c0)
		E:
			for i in OPENING_W:
				geo.set_cell(Vector2i(w - 1, c0 + i), SRC_ID, FLOOR)
			marker_cell = Vector2i(w - 2, c0)
	# Marker centered on the 2-cell opening span.
	var pos: Vector2
	if dir == N or dir == S:
		pos = Vector2(_span_center_x(c0), _cell_center(marker_cell).y)
	else:
		pos = Vector2(_cell_center(marker_cell).x, _span_center_y(c0))
	return {"dir": dir, "pos": pos}


# --- Scene assembly ---------------------------------------------------------

func _make_piece(piece_id: String, w: int, h: int) -> Dictionary:
	var root := Node2D.new()
	root.set_script(_piece_script)
	root.name = "ZonePiece"
	root.set("piece_id", StringName(piece_id))
	root.set("cell_size_px", CELL)
	root.set("size_cells", Vector2i(w, h))

	var geo := TileMapLayer.new()
	geo.name = "Geometry"
	geo.tile_set = _tileset
	root.add_child(geo)
	geo.owner = root

	var sockets := Node2D.new()
	sockets.name = "Sockets"
	root.add_child(sockets)
	sockets.owner = root

	return {"root": root, "geo": geo, "sockets": sockets, "w": w, "h": h}


func _add_socket(ctx: Dictionary, info: Dictionary) -> void:
	var sockets: Node2D = ctx["sockets"]
	var m := Marker2D.new()
	var names: Array[String] = ["N", "E", "S", "W"]
	var dname: String = names[info["dir"]]
	m.name = "Socket_%s" % dname
	m.position = info["pos"]
	m.add_to_group("socket", true)
	m.set_meta(&"dir", info["dir"])
	m.set_meta(&"width_cells", OPENING_W)
	sockets.add_child(m)
	m.owner = ctx["root"]


func _save_piece(ctx: Dictionary, piece_id: String) -> void:
	var packed := PackedScene.new()
	var err := packed.pack(ctx["root"])
	if err != OK:
		printerr("pack failed for %s: %d" % [piece_id, err])
		return
	err = ResourceSaver.save(packed, OUT_DIR + piece_id + ".tscn")
	if err != OK:
		printerr("save failed for %s: %d" % [piece_id, err])
		return
	print("  wrote %s%s.tscn" % [OUT_DIR, piece_id])


# --- The roster -------------------------------------------------------------

func _build_corridor_h() -> void:
	# 8 wide x 4 tall; W & E openings on the middle 2 rows.
	var w := 8
	var h := 4
	var ctx := _make_piece("piece_corridor_h", w, h)
	_fill_rect_room(ctx["geo"], w, h)
	var row0 := 1
	_add_socket(ctx, _carve_opening(ctx["geo"], W, w, h, row0))
	_add_socket(ctx, _carve_opening(ctx["geo"], E, w, h, row0))
	_save_piece(ctx, "piece_corridor_h")


func _build_corridor_v() -> void:
	# 4 wide x 8 tall; N & S openings on the middle 2 cols.
	var w := 4
	var h := 8
	var ctx := _make_piece("piece_corridor_v", w, h)
	_fill_rect_room(ctx["geo"], w, h)
	var col0 := 1
	_add_socket(ctx, _carve_opening(ctx["geo"], N, w, h, col0))
	_add_socket(ctx, _carve_opening(ctx["geo"], S, w, h, col0))
	_save_piece(ctx, "piece_corridor_v")


func _build_corridor_l() -> void:
	# L-bend: 6x6 room, openings W (left) and S (bottom). Interior is a full
	# open box so the path from W to S is walkable.
	var w := 6
	var h := 6
	var ctx := _make_piece("piece_corridor_l", w, h)
	_fill_rect_room(ctx["geo"], w, h)
	_add_socket(ctx, _carve_opening(ctx["geo"], W, w, h, 2))
	_add_socket(ctx, _carve_opening(ctx["geo"], S, w, h, 2))
	_save_piece(ctx, "piece_corridor_l")


func _build_box_small() -> void:
	# 6x6 filler room; E & W openings.
	var w := 6
	var h := 6
	var ctx := _make_piece("piece_box_small", w, h)
	_fill_rect_room(ctx["geo"], w, h)
	_add_socket(ctx, _carve_opening(ctx["geo"], W, w, h, 2))
	_add_socket(ctx, _carve_opening(ctx["geo"], E, w, h, 2))
	_save_piece(ctx, "piece_box_small")


func _build_box_large() -> void:
	# 10x8 branch room; N, E, S, W openings.
	var w := 10
	var h := 8
	var ctx := _make_piece("piece_box_large", w, h)
	_fill_rect_room(ctx["geo"], w, h)
	_add_socket(ctx, _carve_opening(ctx["geo"], N, w, h, 4))
	_add_socket(ctx, _carve_opening(ctx["geo"], S, w, h, 4))
	_add_socket(ctx, _carve_opening(ctx["geo"], W, w, h, 3))
	_add_socket(ctx, _carve_opening(ctx["geo"], E, w, h, 3))
	_save_piece(ctx, "piece_box_large")


func _build_room_hub() -> void:
	# 12x12 hub; N, E, S, W openings.
	var w := 12
	var h := 12
	var ctx := _make_piece("piece_room_hub", w, h)
	_fill_rect_room(ctx["geo"], w, h)
	_add_socket(ctx, _carve_opening(ctx["geo"], N, w, h, 5))
	_add_socket(ctx, _carve_opening(ctx["geo"], S, w, h, 5))
	_add_socket(ctx, _carve_opening(ctx["geo"], W, w, h, 5))
	_add_socket(ctx, _carve_opening(ctx["geo"], E, w, h, 5))
	_save_piece(ctx, "piece_room_hub")
