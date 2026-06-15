class_name InteractionPrompt
extends Node2D
## InteractionPrompt — the floating "[E] Grab" greybox prompt (A2, M1).
##
## A world-space Node2D + Label that hovers above whatever Interactable the
## detector currently focuses. The detector owns it (instantiates, set_target,
## toggles visible); this script just renders prompt_text with a derived key
## hint and snaps to the target each frame. World-space (not a screen-anchored
## CanvasLayer) is clearer about *which* thing is being targeted.
##
## The key hint is derived once from the `interact` action's first event via
## InputMap, so it reads the actual binding ("[E]") instead of a hardcoded glyph.
## Device-aware controller glyphs are deferred to controller-polish (M1 keeps a
## static keyboard hint).

## Pixels above the target's origin to float the label.
const OFFSET: Vector2 = Vector2(0, -28)

var _target: Interactable = null
var _key_hint: String = "[E]"

@onready var _label: Label = $Label


func _ready() -> void:
	_key_hint = _derive_key_hint()
	# Render whatever target was set before _ready (set_target may run first).
	_render()


## Point the prompt at an Interactable (or null to clear). Called by the
## detector on focus change.
func set_target(it: Interactable) -> void:
	_target = it
	if is_node_ready():
		_render()


func _process(_delta: float) -> void:
	if _target != null and is_instance_valid(_target):
		global_position = _target.global_position + OFFSET


func _render() -> void:
	if _label == null:
		return
	if _target != null and is_instance_valid(_target):
		_label.text = "%s %s" % [_key_hint, _target.prompt_text]
	else:
		_label.text = ""


## Read the first keyboard event bound to `interact` and format it as "[KEY]".
## Falls back to "[E]" if the action or a keyboard binding is missing.
func _derive_key_hint() -> String:
	if not InputMap.has_action("interact"):
		return "[E]"
	for event in InputMap.action_get_events("interact"):
		var key := event as InputEventKey
		if key != null:
			var keycode: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
			var label: String = OS.get_keycode_string(keycode)
			if label != "":
				return "[%s]" % label
	return "[E]"
