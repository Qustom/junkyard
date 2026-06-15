extends CharacterBody2D
## greybox_pawn — minimal debug pawn for B1 walkability testing.
##
## Reads raw arrow/WASD keys (deliberately NOT the project Input Map, which A1
## owns) so this test harness has zero coupling to gameplay input. Collides with
## the "world" geometry layer; lives on the "pawn" layer.

@export var speed: float = 120.0


func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	velocity = dir.normalized() * speed
	move_and_slide()
