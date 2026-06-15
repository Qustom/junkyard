extends Node2D
## walk_test — drive a greybox pawn through any single zone-piece (B1).
##
## Assign a piece scene in the inspector, run this scene, and arrow-key/WASD the
## pawn around the interior to confirm walkable floor + solid walls. Acceptance
## harness for B1's "each piece loads standalone and is walkable" criterion.
## (Headless socket/walkability integrity is asserted separately in
## tools/zone_piece_check.gd.)

@export var piece_scene: PackedScene


func _ready() -> void:
	if piece_scene == null:
		push_warning("walk_test: no piece_scene assigned.")
		return
	var piece := piece_scene.instantiate() as ZonePiece
	add_child(piece)

	var pawn := preload("res://entities/debug/greybox_pawn.tscn").instantiate() as Node2D
	# Spawn on the first socket's interior floor cell so the pawn starts inside.
	if piece.has_node("Sockets") and piece.get_node("Sockets").get_child_count() > 0:
		var first := piece.get_node("Sockets").get_child(0) as Node2D
		pawn.position = first.position
	add_child(pawn)
