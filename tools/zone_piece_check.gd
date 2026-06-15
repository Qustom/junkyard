extends SceneTree
## Headless integrity + walkability check for the B1 zone-pieces.
##
## For every piece in bands/pieces/:
##   - it loads and its root is a ZonePiece;
##   - the Geometry TileMapLayer has set cells (get_used_cells non-empty);
##   - the computed footprint matches the cell extent;
##   - sockets were collected, each with a valid Dir + width_cells == 2,
##     and each socket's boundary cell is an actual FLOOR cell (walkable);
##   - the greybox pawn's collider, dropped at a socket's floor cell, does NOT
##     overlap geometry there (floor is clear), but DOES collide when placed on
##     a perimeter WALL cell (walls are solid). This proves the collision setup
##     without relying on a flaky headless move_and_slide loop.
##
## Prints "ZONE PIECES OK" and exits 0 on success; non-zero on any failure.
## Run: godot --headless --script res://tools/zone_piece_check.gd

const PIECES := [
	"res://bands/pieces/piece_corridor_h.tscn",
	"res://bands/pieces/piece_corridor_v.tscn",
	"res://bands/pieces/piece_corridor_l.tscn",
	"res://bands/pieces/piece_box_small.tscn",
	"res://bands/pieces/piece_box_large.tscn",
	"res://bands/pieces/piece_room_hub.tscn",
]
const PAWN := "res://entities/debug/greybox_pawn.tscn"
const CELL := 16
const FLOOR_ATLAS := Vector2i(0, 0)
const WALL_ATLAS := Vector2i(1, 0)
const WORLD_BIT := 2   # A1 locked map: "world" = physics layer 2

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await physics_frame   # ensure the PhysicsServer space is live
	var pawn_scene := load(PAWN) as PackedScene
	var pawn_radius := 5.0
	if pawn_scene == null:
		_fail("global", "greybox_pawn.tscn failed to load")
	else:
		for path in PIECES:
			await _check_piece(path, pawn_radius)
	_verdict()


func _check_piece(path: String, pawn_radius: float) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		_fail(path, "scene failed to load")
		return
	var piece := packed.instantiate()
	if not (piece is ZonePiece):
		_fail(path, "root is not a ZonePiece")
		piece.free()
		return
	root.add_child(piece)
	await physics_frame   # let _ready run + collisions register in the space

	var zp := piece as ZonePiece
	var geo := zp.get_node_or_null("Geometry") as TileMapLayer

	# --- geometry ---
	if geo == null:
		_fail(path, "no Geometry TileMapLayer")
	else:
		var used := geo.get_used_cells()
		if used.is_empty():
			_fail(path, "Geometry has no set cells")
		if zp.occupied_cells.size() != used.size():
			_fail(path, "occupied_cells (%d) != get_used_cells (%d)" % [
				zp.occupied_cells.size(), used.size()])
		if zp.footprint_cells.size != geo.get_used_rect().size:
			_fail(path, "footprint_cells mismatch")

	# --- sockets ---
	if zp.sockets.is_empty():
		_fail(path, "no sockets collected")
	for s in zp.sockets:
		if s.width_cells != 2:
			_fail(path, "socket %s width_cells=%d (expected 2)" % [
				ZoneSocket.dir_name(s.dir), s.width_cells])
		if s.dir < 0 or s.dir > 3:
			_fail(path, "socket dir out of range: %d" % s.dir)
		if geo != null:
			var atlas := geo.get_cell_atlas_coords(s.cell)
			if geo.get_cell_source_id(s.cell) == -1:
				_fail(path, "socket %s boundary cell %s is empty" % [
					ZoneSocket.dir_name(s.dir), s.cell])
			elif atlas != FLOOR_ATLAS:
				_fail(path, "socket %s boundary cell %s is not FLOOR (atlas %s)" % [
					ZoneSocket.dir_name(s.dir), s.cell, atlas])

	# --- collision proof via space-state shape queries ---
	if geo != null and not zp.sockets.is_empty():
		_collision_check(path, zp, geo, pawn_radius)

	root.remove_child(piece)
	piece.free()


func _collision_check(path: String, zp: ZonePiece, geo: TileMapLayer,
		pawn_radius: float) -> void:
	var space := root.world_2d.direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = pawn_radius

	# 1) At the first socket's floor cell, the pawn must be CLEAR (walkable).
	var floor_cell := zp.sockets[0].cell
	var floor_world := geo.to_global(geo.map_to_local(floor_cell))
	if _overlaps(space, shape, floor_world):
		_fail(path, "pawn collides on FLOOR at socket cell %s (not walkable)" % floor_cell)

	# 2) On a perimeter WALL cell, the pawn MUST collide (walls are solid).
	var wall_cell: Variant = _find_wall_cell(geo)
	if wall_cell == null:
		_fail(path, "no WALL cell found to test solidity")
	else:
		var wc: Vector2i = wall_cell
		var wall_world := geo.to_global(geo.map_to_local(wc))
		if not _overlaps(space, shape, wall_world):
			_fail(path, "pawn does NOT collide on WALL cell %s (walls not solid)" % wc)


func _overlaps(space: PhysicsDirectSpaceState2D, shape: Shape2D, at: Vector2) -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, at)
	params.collision_mask = WORLD_BIT
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var hits := space.intersect_shape(params, 1)
	return not hits.is_empty()


func _find_wall_cell(geo: TileMapLayer) -> Variant:
	for c in geo.get_used_cells():
		if geo.get_cell_atlas_coords(c) == WALL_ATLAS:
			return c
	return null


func _fail(scope: String, msg: String) -> void:
	_failures.append("%s: %s" % [scope, msg])


func _verdict() -> void:
	if _failures.is_empty():
		print("ZONE PIECES OK — %d pieces load, sockets tagged, floor walkable, walls solid" % PIECES.size())
		quit(0)
	else:
		for f in _failures:
			printerr("ZONE PIECE FAIL: ", f)
		quit(1)
