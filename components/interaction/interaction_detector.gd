class_name InteractionDetector
extends Area2D
## InteractionDetector — the player-side half of the interaction component
## (A2, M1 greybox prototype).
##
## Added as a child of Player (player.tscn). A CircleShape2D (~36px reach) on an
## empty collision_layer with collision_mask = `interactable` (bit 3) only means
## this Area sees Interactables enter/exit its radius and nothing else. It tracks
## the in-range set, recomputes the nearest target each frame (the list is tiny),
## owns + positions the floating prompt directly, and on `interact` emits
## EventBus.interaction_requested naming that target.
##
## Deliberately agnostic: it never performs the pickup, opens the gate, mutates
## GameState, or frees nodes. It only surfaces "what is focused" (prompt + the
## EventBus focus/unfocus signals, for audio/telemetry) and "the player pressed
## interact on this" (interaction_requested). The Interactable's owner consumes
## the request and is responsible for freeing/disabling its own target.
##
## Selection is pure nearest-by-distance_squared with hysteresis: a challenger
## only steals focus when meaningfully closer (new_d < best_d * SWITCH_RATIO),
## and exact ties resolve by stable insertion order in `_in_range`. This stops
## the prompt jittering between two overlapping pieces of junk. Facing bias is
## intentionally not used (A1 keeps `facing` movement-only).

## Hysteresis: a non-focused candidate must be at least this fraction of the
## current target's squared distance to take focus. < 1.0 adds stickiness.
const SWITCH_RATIO: float = 0.9

## ui/interaction_prompt.tscn — instanced lazily on first focus and reused.
@export var prompt_scene: PackedScene

## In-range Interactables, kept in insertion order so ties break stably.
var _in_range: Array[Interactable] = []

## The currently focused target (nearest valid), or null.
var _current: Interactable = null

## The lazily-instanced prompt (an InteractionPrompt Node2D), or null.
var _prompt: Node = null


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	var it := area as Interactable
	if it != null and not _in_range.has(it):
		_in_range.append(it)


func _on_area_exited(area: Area2D) -> void:
	var it := area as Interactable
	if it != null:
		_in_range.erase(it)


func _process(_delta: float) -> void:
	_refresh_current()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current != null and _current.can_interact():
		# Detector stays agnostic: announce the request, let the owner act.
		EventBus.interaction_requested.emit(_current.interactable_id, _current)
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


## Recompute the nearest valid target with hysteresis and update focus/prompt.
func _refresh_current() -> void:
	var origin: Vector2 = global_position
	var best: Interactable = null
	var best_d: float = INF

	# Iterate a copy-safe pass: defensively drop freed/invalid entries so a
	# target freed by its owner (which queues area_exited a frame later) can't
	# crash the distance read in the meantime.
	var i: int = 0
	while i < _in_range.size():
		var it: Interactable = _in_range[i]
		if not is_instance_valid(it):
			_in_range.remove_at(i)
			continue
		if not it.can_interact():
			i += 1
			continue
		var d: float = origin.distance_squared_to(it.global_position)
		if d < best_d:
			best_d = d
			best = it
		i += 1

	# Apply hysteresis: if the current target is still valid and in range, only
	# switch when the new best is meaningfully closer than the current.
	if _current != null and is_instance_valid(_current) and _current.can_interact() \
			and _in_range.has(_current):
		if best != _current:
			var cur_d: float = origin.distance_squared_to(_current.global_position)
			if best == null or best_d >= cur_d * SWITCH_RATIO:
				best = _current

	if best == _current:
		return

	# Focus changed -> update prompt + notify consumers.
	if _current != null:
		EventBus.interactable_unfocused.emit(_current)
	_current = best
	if _current != null:
		EventBus.interactable_focused.emit(_current)
		_show_prompt(_current)
	else:
		_hide_prompt()


func _show_prompt(it: Interactable) -> void:
	if _prompt == null and prompt_scene != null:
		_prompt = prompt_scene.instantiate()
		# Parent to the detector so it lives in world space; the prompt itself
		# snaps to the target's global_position each frame.
		add_child(_prompt)
	if _prompt != null:
		_prompt.set_target(it)
		_prompt.visible = true


func _hide_prompt() -> void:
	if _prompt != null:
		_prompt.set_target(null)
		_prompt.visible = false
