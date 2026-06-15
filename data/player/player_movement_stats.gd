extends Resource
class_name PlayerMovementStats
## PlayerMovementStats — top-down movement tuning, authored as data (TDD §2).
##
## The movement loop (accelerate toward a target velocity, decelerate by friction
## when no input) is identical for any CharacterBody2D, so enemies/mobs can reuse
## this same stat shape. Tuning lives in a .tres, not in code — see
## data/player/player_movement.tres. A1 ship values: 200 / 2000 / 2000.

## Top speed in px/s the body reaches under sustained input.
@export var max_speed: float = 200.0

## How fast (px/s^2) velocity ramps toward the target while there is input.
@export var acceleration: float = 2000.0

## How fast (px/s^2) velocity bleeds toward zero when there is no input.
@export var friction: float = 2000.0
