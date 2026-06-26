class_name App
extends Node
## App (M1.6 M0) — the persistent root scene router. THE app entry (run/main_scene).
##
## Holds exactly one "state scene" child at a time (Main Menu / Hub / Dive) under a
## StateHost node and swaps it on the flow signals. A persistent DebugOverlay
## CanvasLayer survives every swap, so M4's P-toggle tabbed menu is available in ALL
## THREE states from one instance (RD-1/RD-6). The router owns NO game-state truth
## (the run/meta boundary stays GameState's) — it only swaps scenes by PATH (never
## holding a scene ref across a swap) and re-emits hub_entered/returned_to_hub so
## observers fire AFTER the swap, on a settled tree.
##
## Transition wiring (RD-2, final 8-signal set):
##   - boot            → Main Menu          (_ready → _goto MAIN_MENU_PATH)
##   - dive_requested  → Dive               (_on_dive_requested → _goto DIVE_PATH)
##   - run_ended       → Hub (auto-return)  (_on_run_ended → deferred _return_after_dive)
## M1.6 only ever AUTO-returns from a dive (the Phase-2 return_to_hub_requested was
## dropped, RD-2/OQ-5). The Menu→Hub hop rides on the menu stub emitting hub_entered
## via the router; the menu/hub scenes only EMIT intent, never call change_scene_*.

const MAIN_MENU_PATH := "res://scenes/menu/main_menu.tscn"   # M1 REPLACES this scene
const HUB_PATH := "res://scenes/hub/hub.tscn"                # M2 REPLACES this scene
const DIVE_PATH := "res://scenes/game/main_game.tscn"        # M2 refactors to dive-only

@onready var _state_host: Node = $StateHost          # the swappable state scene lives here
@onready var _overlay: CanvasLayer = $DebugOverlay   # persistent P-menu mount (M4 fills it)

## &"" before boot, then &"menu" / &"hub" / &"dive" — pure router bookkeeping.
## Exposed (current_state) so M4's pause-in-dive logic can read where we are.
var _current_state: StringName = &""

## M1.6 (M0): read-only router state for M4 (the P-overlay pauses the tree only in
## the dive — it reads this to decide). Never returns null; &"" only before _ready.
var current_state: StringName:
	get: return _current_state


## M1.6 (M0): the router is discoverable by the Menu/Hub scenes (which can't name the
## root node) via get_tree().get_first_node_in_group(&"app_router"). The Main Menu (M1)
## calls goto_hub() on it (the mechanism-agnostic "go to Hub" handoff, M1_main_menu.md R-a).
const GROUP := &"app_router"


func _ready() -> void:
	add_to_group(GROUP)
	# The router listens to the flow signals + run_ended so it OWNS the transitions;
	# the state scenes only EMIT intent (decoupled exactly like SellScreen.continue_pressed
	# was). dive_requested is M2's portal; the menu stub emits dive_requested too (M0 stub).
	EventBus.dive_requested.connect(_on_dive_requested)
	EventBus.run_ended.connect(_on_run_ended)   # auto-return after a dive resolves (RD-2)
	_goto(MAIN_MENU_PATH, &"menu")              # boot → Main Menu (the new entry beat)


## M1.6 (M0): the Menu→Hub handoff (M1's Main Menu calls this — R-a in M1_main_menu.md).
## The menu never starts a dive; it hands off to the Hub with meta loaded/fresh. Routes
## to the Hub and fires hub_entered AFTER the swap so the Hub reads a settled tree.
## NOT the dive-return path (that's _return_after_dive, which also emits returned_to_hub).
func goto_hub() -> void:
	_goto(HUB_PATH, &"hub")
	EventBus.hub_entered.emit()


## Swap the state scene: free the old StateHost child(ren), instance + add the new
## one. Greybox-simple; no transition animation (M1.6 is structural). Scenes are
## resolved by PATH (not ref) so the router holds no scene references across a swap.
func _goto(scene_path: String, state: StringName) -> void:
	for child in _state_host.get_children():
		_state_host.remove_child(child)   # detach now so the new scene is the only live one this frame
		child.queue_free()
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("App: missing state scene %s" % scene_path)
		return
	_state_host.add_child(packed.instantiate())
	_current_state = state


# --- Flow handlers (the router's whole job) ---------------------------------
func _on_dive_requested(_band_id: StringName) -> void:
	_goto(DIVE_PATH, &"dive")
	# NOTE: the dive scene starts the run itself on entry (M2 wiring: main_game._ready
	# → start_new_run, resolving its config via GameState.dive_config_or_default()).
	# The router only puts the dive in the tree. (M1.6 has the single band &"near".)


## Auto-return: a dive that ends (extract/death/timeout) routes back to the Hub. We
## defer one frame so any same-frame run_ended consumers (the old SellScreen-style
## listeners) settle first, then return. Ignores run_ended that didn't originate from
## the dive state (defensive — only the dive emits run_ended in M1.6).
func _on_run_ended(reason: StringName, _duration_s: float, _depth_reached: int) -> void:
	if _current_state != &"dive":
		return
	call_deferred("_return_after_dive", reason)


func _return_after_dive(reason: StringName) -> void:
	EventBus.returned_to_hub.emit(reason)   # carries the dive outcome for the Hub-return beat
	_goto(HUB_PATH, &"hub")
	EventBus.hub_entered.emit()             # fire AFTER the hub is in the tree (settled state)
