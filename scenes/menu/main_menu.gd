extends Control
## M0 GREYBOX STUB — main_menu.tscn. **REPLACED by M1** (M1_main_menu.md) — do not
## build on this; it exists only so `main` boots end-to-end through the App router
## after Wave 1 (RD-7). A Label + a "Go to Hub" button that hands off to the Hub via
## the M0 router (goto_hub() — the R-a mechanism-agnostic handoff). The menu never
## starts a dive; it hands off to the Hub (the Hub's portal emits dive_requested).

@onready var _to_hub: Button = $Center/VBox/ToHubButton


func _ready() -> void:
	_to_hub.pressed.connect(_on_to_hub_pressed)
	_to_hub.grab_focus()


func _on_to_hub_pressed() -> void:
	var router: Node = get_tree().get_first_node_in_group(&"app_router")
	if router != null and router.has_method(&"goto_hub"):
		router.goto_hub()
	else:
		push_warning("main_menu stub: no app_router in tree; cannot route to Hub.")
