class_name Interactable
extends Area2D
## Interactable — a reusable interaction marker (A2, M1 greybox prototype).
##
## Dropped as a CHILD of any entity scene (junk pickup, gate, NPC) to make it
## usable. It is the Area2D the player's InteractionDetector sees via
## area_entered/area_exited, so it must sit on the `interactable` collision layer
## (bit 3) with its own CollisionShape2D and an empty mask (it detects nothing —
## it is detected). The parent entity can still be a StaticBody2D/Node2D on the
## `world` layer for blocking; interactability is composed in, not inherited.
##
## This node is pure data + a can_interact() guard. It never performs the pickup
## or opens the gate — that logic lives on the parent/owner, which listens for
## EventBus.interaction_requested(id, target) and acts on it (A3 / dive-flow).
## The detector stays agnostic and only emits the request.

## Identifies the kind of interaction so the listener can branch on it
## (e.g. &"junk" → pickup, &"gate" → descend).
@export var interactable_id: StringName = &"junk"

## Human-readable name, for debug / future UI. Not shown in the M1 prompt.
@export var display_name: String = "Junk"

## Verb shown in the floating prompt, prefixed with the key hint ("[E] Grab").
@export var prompt_text: String = "Grab"

## When false, can_interact() returns false: the detector skips this node when
## choosing the nearest target and ignores interact presses against it. Lets an
## owner temporarily disable a target (e.g. a depleted node) without freeing it.
@export var enabled: bool = true


## The single guard the detector consults. Kept a method (not a raw read of
## `enabled`) so owners can override with richer rules later (cooldowns, locks)
## without changing the detector contract.
func can_interact() -> bool:
	return enabled
