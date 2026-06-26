class_name HubShop
extends Area2D
## HubShop (M1.6 M3) — the "walk up and open the shop" interactable in the Hub.
##
## Built on the DeparturePortal / ExtractGate pattern (departure_portal.gd): a DUMB
## interactable whose OWNER acts on EventBus.interaction_requested. Where the portal
## emits dive_requested, the shop opens its child ShopUI (the SELL + BUY screen). It owns
## NO Money truth and NO save — the ShopUI talks to GameState's economy API directly.
##
## Greybox: an Area2D with a ColorRect body + a child Interactable(id=&"shop") on the
## interactable layer (bit 3 = collision_layer 4); it detects nothing itself (layer/mask 0).
## The ShopUI lives as a child CanvasLayer so the shop is fully self-contained in the Hub.

## StringName the child Interactable is authored with; the shop only acts on its own.
@export var interactable_id: StringName = &"shop"

## Fat-finger lockout window (mirrors departure_portal.gd:27): after an accepted interact,
## further interacts are ignored until the window elapses.
@export var input_lockout_s: float = 0.25

var _locked: bool = false

@onready var _shop_ui: ShopUI = $ShopUI


func _ready() -> void:
	EventBus.interaction_requested.connect(_on_interaction_requested)


## A2 contract: the detector announces the request; the owner (this shop) checks the id
## and acts. We ignore requests for other interactables and our own re-presses during the
## lockout. Mirrors departure_portal.gd:_on_interaction_requested, swapping the dive-launch
## for opening the ShopUI.
func _on_interaction_requested(id: StringName, target: Node) -> void:
	if id != interactable_id:
		return
	if target != null and target.get_parent() != self:
		return
	if _locked:
		return
	_locked = true
	_start_lockout()
	if _shop_ui != null:
		_shop_ui.open()


## Arm the fat-finger lockout via a SceneTree timer (frame-rate independent, no polling).
## Copied from departure_portal.gd:_start_lockout.
func _start_lockout() -> void:
	var tree := get_tree()
	if tree == null:
		_locked = false
		return
	var timer := tree.create_timer(input_lockout_s)
	timer.timeout.connect(func() -> void: _locked = false)
