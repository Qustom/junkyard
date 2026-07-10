class_name InteractionOwner
extends Node
## InteractionOwner — extracted id-guard + parent-check + fat-finger-lockout
## mechanism, previously duplicated verbatim across ExtractGate/DeparturePortal/
## HubShop (all three) and partially (id-guard + parent-check only, NO lockout)
## in JunkPickup (M1.12 V5 / report R6).
##
## Not scene-authored: the owner constructs + add_child()s one of these in its
## own _ready(), so no .tscn edits are needed and it is freed automatically when
## the owner frees (a real child node — Godot auto-disconnects its EventBus
## connection on free, same as the owner did for itself before this refactor).
##
## lockout_s == 0.0 disables the lockout arm entirely (JunkPickup's case): every
## request that passes id + parenthood activates immediately, every time, with
## no debounce — reproducing its exact current (lockout-free) behavior.

## Emitted once id + parenthood (+ lockout, if armed) all pass. The owner
## connects this once and does its one piece of owner-specific work.
signal activated(target: Node)

var _owner: Node
var _id: StringName
var _lockout_s: float
var _locked: bool = false


func _init(p_owner: Node = null, p_id: StringName = &"", p_lockout_s: float = 0.0) -> void:
	_owner = p_owner
	_id = p_id
	_lockout_s = p_lockout_s


func _ready() -> void:
	EventBus.interaction_requested.connect(_on_interaction_requested)


func _on_interaction_requested(id: StringName, target: Node) -> void:
	if id != _id:
		return
	if target != null and target.get_parent() != _owner:
		return
	if _lockout_s > 0.0:
		if _locked:
			return
		_locked = true
		_start_lockout()
	activated.emit(target)


## Arm the fat-finger lockout. Uses a SceneTree timer so it is frame-rate
## independent and needs no _process polling.
func _start_lockout() -> void:
	var tree := get_tree()
	if tree == null:
		_locked = false
		return
	var timer := tree.create_timer(_lockout_s)
	timer.timeout.connect(func() -> void: _locked = false)
