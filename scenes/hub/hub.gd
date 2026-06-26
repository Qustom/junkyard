extends Control
## M0 GREYBOX STUB — hub.tscn. **REPLACED by M2** (M2_hub_scene_flow.md) — do not build
## on this; it exists only so `main` boots end-to-end through the App router after Wave 1
## (RD-7). A Label + a "Dive" button that requests a dive via the M0 EventBus signal
## (dive_requested, which the App router observes → swaps in the dive scene). The Hub is
## a pure view over meta-state (it reads GameState meta, holds no run-state).

@onready var _dive: Button = $Center/VBox/DiveButton


func _ready() -> void:
	_dive.pressed.connect(_on_dive_pressed)
	_dive.grab_focus()


func _on_dive_pressed() -> void:
	# M1.6 has the single band &"near"; M2's real portal emits the same signal.
	EventBus.dive_requested.emit(&"near")
