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

## M1.12 V5: id-guard + parent-check + lockout mechanism extracted to a shared
## helper (interaction_owner.gd), constructed here in _ready() (no .tscn edit).
var _io: InteractionOwner

@onready var _shop_ui: ShopUI = $ShopUI


func _ready() -> void:
	_io = InteractionOwner.new(self, interactable_id, input_lockout_s)
	add_child(_io)
	_io.activated.connect(_on_activated)


## The shop's one owner-specific action, run once id + parenthood + lockout all pass.
func _on_activated(_target: Node) -> void:
	if _shop_ui != null:
		_shop_ui.open()
