extends SceneTree
## One-shot generator for the greybox placeholder atlas (B1).
##
## Produces a 32x16 PNG: two flat-color 16x16 tiles side by side.
##   tile (0,0) = FLOOR — dark grey
##   tile (1,0) = WALL  — light grey
## Run once with: godot --headless --script res://tools/gen_greybox_texture.gd
## The committed art is data/tilesets/greybox.png; this script is the recipe.

const CELL := 16
const FLOOR_COLOR := Color8(0x33, 0x33, 0x38)   # dark grey
const WALL_COLOR := Color8(0xAA, 0xAA, 0xB0)     # light grey
const OUT_PATH := "res://data/tilesets/greybox.png"

func _initialize() -> void:
	var img := Image.create(CELL * 2, CELL, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, CELL, CELL), FLOOR_COLOR)
	img.fill_rect(Rect2i(CELL, 0, CELL, CELL), WALL_COLOR)
	var err := img.save_png(ProjectSettings.globalize_path(OUT_PATH))
	if err != OK:
		printerr("greybox texture save failed: %d" % err)
		quit(1)
	print("greybox texture written: %s" % OUT_PATH)
	quit(0)
