extends SceneTree
## One-shot generator for data/tilesets/greybox.tres (B1).
##
## Builds a built-in TileSet, 16x16 cells, with exactly two tiles from the
## greybox atlas:
##   FLOOR (atlas 0,0) — no collision
##   WALL  (atlas 1,0) — one rectangular collision polygon covering the cell,
##                       on physics layer 0 (collision_layer = "world" = bit 1)
## Run once: godot --headless --script res://tools/gen_greybox_tileset.gd
## Authoring it via script guarantees a valid, version-correct serialization.

const TEX_PATH := "res://data/tilesets/greybox.png"
const OUT_PATH := "res://data/tilesets/greybox.tres"
const CELL := 16

func _initialize() -> void:
	var tex := load(TEX_PATH) as Texture2D
	if tex == null:
		printerr("could not load greybox texture")
		quit(1)
		return

	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL, CELL)

	# Physics layer 0 -> "world" geometry. A1's locked layer map puts "world" on
	# physics layer 2 (bit value 2). Static geometry actively collides with
	# nothing (mask 0); movers mask against it.
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 2)   # world = layer_2 = bit 2
	ts.set_physics_layer_collision_mask(0, 0)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(CELL, CELL)

	# FLOOR tile at atlas coord (0,0) — walkable, no collision.
	src.create_tile(Vector2i(0, 0))

	# WALL tile at atlas coord (1,0).
	src.create_tile(Vector2i(1, 0))

	# Source must belong to the TileSet before tile_data sees its physics
	# layers, otherwise add_collision_polygon(0) is out of bounds.
	ts.add_source(src, 0)

	# WALL full-cell collision polygon on physics layer 0.
	var wall := src.get_tile_data(Vector2i(1, 0), 0)
	wall.add_collision_polygon(0)
	var half := CELL / 2.0
	var poly := PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	])
	wall.set_collision_polygon_points(0, 0, poly)

	var err := ResourceSaver.save(ts, OUT_PATH)
	if err != OK:
		printerr("tileset save failed: %d" % err)
		quit(1)
		return
	print("greybox tileset written: %s" % OUT_PATH)
	quit(0)
