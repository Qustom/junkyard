extends SceneTree
## One-shot generator for the B1 debug harness scenes.
##   entities/debug/greybox_pawn.tscn  — CharacterBody2D + CollisionShape2D
##   entities/debug/walk_test.tscn      — loads a piece + spawns the pawn
## Run: godot --headless --script res://tools/gen_debug_scenes.gd

const PAWN_SCRIPT := "res://entities/debug/greybox_pawn.gd"
const WALK_SCRIPT := "res://entities/debug/walk_test.gd"
const PAWN_OUT := "res://entities/debug/greybox_pawn.tscn"
const WALK_OUT := "res://entities/debug/walk_test.tscn"
const SAMPLE_PIECE := "res://bands/pieces/piece_room_hub.tscn"

# Physics layers (aligned to A1's locked map): world = layer_2 (bit 2).
# pawn gets its own non-clashing layer_6 (bit 32) — A1 owns layers 1-5.
const WORLD_BIT := 2
const PAWN_BIT := 32


func _initialize() -> void:
	_build_pawn()
	_build_walk_test()
	print("debug scenes generated.")
	quit(0)


func _build_pawn() -> void:
	var body := CharacterBody2D.new()
	body.name = "GreyboxPawn"
	body.set_script(load(PAWN_SCRIPT))
	body.collision_layer = PAWN_BIT      # is on "pawn"
	body.collision_mask = WORLD_BIT      # collides with "world" geometry

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 5.0                    # < 8px so it clears a 2-cell doorway
	col.shape = shape
	body.add_child(col)
	col.owner = body

	# Visible greybox dot so the pawn is findable in the editor run.
	var vis := ColorRect.new()
	vis.name = "Vis"
	vis.color = Color(0.95, 0.55, 0.2)
	vis.size = Vector2(10, 10)
	vis.position = Vector2(-5, -5)
	body.add_child(vis)
	vis.owner = body

	var packed := PackedScene.new()
	var err := packed.pack(body)
	if err == OK:
		err = ResourceSaver.save(packed, PAWN_OUT)
	if err != OK:
		printerr("pawn save failed: %d" % err)
	else:
		print("  wrote %s" % PAWN_OUT)


func _build_walk_test() -> void:
	var root := Node2D.new()
	root.name = "WalkTest"
	root.set_script(load(WALK_SCRIPT))
	root.set("piece_scene", load(SAMPLE_PIECE))

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, WALK_OUT)
	if err != OK:
		printerr("walk_test save failed: %d" % err)
	else:
		print("  wrote %s" % WALK_OUT)
