class_name ExtractPrompt
extends Control
## ExtractPrompt (E2) — the explicit "Press E to Extract with N" call-to-action that
## converts the HUD's ambient at-risk number into the actionable decision at the gate.
## Hidden until the gate is the FOCUSED interactable (A2), so both options — extract
## now vs push deeper — are present at the decision moment (spec Open-question #1).
##
## PURE PROJECTION: no source of truth. It toggles on EventBus.interactable_focused /
## interactable_unfocused (A2, the real signals — there is no gate_in_range), filtering
## on the focused Interactable's interactable_id so only the gate (not junk pickups)
## raises it. The live haul value comes from GameState.run_haul_value() at the moment
## it is shown / on inventory change while shown — no polling.
##
## The "E" glyph is hardcoded for the M1 playtest cohort (spec Open-question #5:
## device-aware glyph-swapping deferred to post-M1). Greybox only; strings via tr().

## The interactable_id the gate's child Interactable is authored with (E1: &"gate").
@export var gate_interactable_id: StringName = &"gate"

## Hardcoded prompt glyph for M1 (keyboard cohort). Deferred: device-aware swap.
@export var key_glyph: String = "E"

@onready var _prompt_label: Label = %PromptLabel
@onready var _push_hint: Label = %PushHint

var _focused_gate: Node = null


func _ready() -> void:
	visible = false
	EventBus.interactable_focused.connect(_on_interactable_focused)
	EventBus.interactable_unfocused.connect(_on_interactable_unfocused)
	# Keep the displayed value live while the prompt is up and the player grabs/drops.
	EventBus.run_inventory_changed.connect(_on_run_inventory_changed)
	_push_hint.text = tr("HUD_PUSH_HINT")


func _on_interactable_focused(target: Node) -> void:
	if not _is_gate(target):
		return
	_focused_gate = target
	_refresh_prompt()
	visible = true


func _on_interactable_unfocused(target: Node) -> void:
	# Only hide if the thing leaving focus is the gate we're currently showing for.
	if target == _focused_gate or _is_gate(target):
		_focused_gate = null
		visible = false


func _on_run_inventory_changed(_used_slots: int, _max_slots: int) -> void:
	if visible:
		_refresh_prompt()


## Identify the focused target as the extract gate. A2 passes the Interactable node;
## match on its interactable_id (its own member, or the gate parent's) so junk focus
## never raises the extract prompt. Defensive across both shapes of the A2 payload.
func _is_gate(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var id: Variant = target.get("interactable_id")
	if id != null and StringName(id) == gate_interactable_id:
		return true
	var parent := target.get_parent()
	if parent != null:
		var pid: Variant = parent.get("interactable_id")
		if pid != null and StringName(pid) == gate_interactable_id:
			return true
	return false


func _refresh_prompt() -> void:
	_prompt_label.text = tr("HUD_EXTRACT_PROMPT").format({
		"key": key_glyph,
		"value": GameState.run_haul_value(),
	})
