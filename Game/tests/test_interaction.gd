extends SceneTree
## Headless verification for A2 interaction component.
##
## Input cannot be injected through the OS in --headless and a raw SceneTree
## --script run has limited physics, so we drive the detector's own logic
## directly against the real EventBus:
##   - register two stub Interactables via _on_area_entered (the area_entered
##     contract the detector reacts to),
##   - run _refresh_current() and assert the NEAREST one is focused
##     (EventBus.interactable_focused fired naming it),
##   - feed a synthetic "interact" InputEventAction to _unhandled_input() and
##     assert EventBus.interaction_requested fired naming that same target,
##   - move the player past the other stub and assert focus switches only when
##     meaningfully closer (hysteresis), with a clean unfocus/refocus.
## Run: godot --headless --script res://tests/test_interaction.gd

const DETECTOR_SCENE := "res://components/interaction/interaction_detector.tscn"
const INTERACTABLE_SCENE := "res://components/interaction/interactable.tscn"

var _focused: Array[Node] = []
var _unfocused: Array[Node] = []
var _requests: Array = []  # [ [id, target], ... ]


func _initialize() -> void:
	var failures: Array[String] = []

	var event_bus: Node = root.get_node_or_null("EventBus")
	if event_bus == null:
		printerr("INTERACT FAIL: EventBus autoload missing")
		quit(1)
		return

	event_bus.interactable_focused.connect(_on_focused)
	event_bus.interactable_unfocused.connect(_on_unfocused)
	event_bus.interaction_requested.connect(_on_requested)

	var detector_packed: PackedScene = load(DETECTOR_SCENE)
	var it_packed: PackedScene = load(INTERACTABLE_SCENE)
	if detector_packed == null or it_packed == null:
		printerr("INTERACT FAIL: could not load detector/interactable scene")
		quit(1)
		return

	var detector: Variant = detector_packed.instantiate()
	root.add_child(detector)  # runs _ready(), connecting area_entered/exited
	detector.global_position = Vector2.ZERO

	# Two stubs: NEAR (60px) and FAR (200px). Nearest must win.
	var near_it: Variant = it_packed.instantiate()
	near_it.display_name = "Near"
	near_it.interactable_id = &"junk"
	near_it.prompt_text = "Grab"
	root.add_child(near_it)
	near_it.global_position = Vector2(60, 0)

	var far_it: Variant = it_packed.instantiate()
	far_it.display_name = "Far"
	far_it.interactable_id = &"gate"
	far_it.prompt_text = "Descend"
	root.add_child(far_it)
	far_it.global_position = Vector2(200, 0)

	# --- Register both as in-range (the area_entered contract) ---------------
	detector._on_area_entered(near_it)
	detector._on_area_entered(far_it)

	# --- Focus: nearest wins -------------------------------------------------
	detector._refresh_current()
	if _focused.size() != 1 or _focused[0] != near_it:
		failures.append("focus: expected single focus on Near, got %s" % [_focused])
	if detector._current != near_it:
		failures.append("focus: detector._current is not Near (%s)" % [detector._current])

	# Prompt should have been instanced and made visible on the near target.
	if detector._prompt == null:
		failures.append("prompt: not instanced on focus")
	elif not detector._prompt.visible:
		failures.append("prompt: instanced but not visible on focus")

	# --- interact press fires the EventBus request naming Near --------------
	var action_ev := InputEventAction.new()
	action_ev.action = "interact"
	action_ev.pressed = true
	detector._unhandled_input(action_ev)
	if _requests.size() != 1:
		failures.append("request: expected 1 interaction_requested, got %d" % _requests.size())
	elif _requests[0][1] != near_it or _requests[0][0] != StringName("junk"):
		failures.append("request: wrong payload %s (expected id=junk target=Near)" % [_requests[0]])

	# --- Hysteresis: nudge player so Far becomes nearer; focus must switch ---
	# Move detector well past Near so Far is clearly (>10%) closer.
	detector.global_position = Vector2(260, 0)  # Near now 200px, Far now 60px
	_focused.clear()
	_unfocused.clear()
	detector._refresh_current()
	if detector._current != far_it:
		failures.append("hysteresis: focus did not switch to Far when clearly closer (%s)" % [detector._current])
	if _unfocused.size() != 1 or _unfocused[0] != near_it:
		failures.append("hysteresis: expected unfocus of Near, got %s" % [_unfocused])
	if _focused.size() != 1 or _focused[0] != far_it:
		failures.append("hysteresis: expected focus of Far, got %s" % [_focused])

	# --- Hysteresis stickiness: a near-equal challenger must NOT steal focus -
	# Focus is currently Far. Hysteresis compares SQUARED distances and only
	# switches when challenger_d2 < current_d2 * SWITCH_RATIO (0.9). Place the
	# challenger (Near) marginally closer but within that band so it must NOT
	# steal: detector@260, Far@360 -> 100px (d2=10000); Near@355 -> 95px
	# (d2=9025), and 9025 >= 10000*0.9 (9000) so Far keeps focus.
	near_it.global_position = Vector2(355, 0)
	far_it.global_position = Vector2(360, 0)
	_focused.clear()
	_unfocused.clear()
	detector._refresh_current()
	if detector._current != far_it:
		failures.append("hysteresis: focus flickered off Far despite near-equal challenger (%s)" % [detector._current])

	# --- enabled guard: disabling current drops focus -----------------------
	far_it.enabled = false
	_focused.clear()
	_unfocused.clear()
	detector._refresh_current()
	# Near is now the only valid target (100px) -> focus should move to Near.
	if detector._current != near_it:
		failures.append("guard: disabling Far did not move focus to valid Near (%s)" % [detector._current])

	# --- L4 HIDE INVARIANT: disable the ONLY valid target -> prompt hidden ---
	# Focus is on Near. Disabling it leaves NO valid target; the prompt must go
	# invisible the same frame (best == null transition).
	near_it.enabled = false
	_focused.clear()
	_unfocused.clear()
	detector._refresh_current()
	if detector._current != null:
		failures.append("hide(disable): focus did not clear when all targets disabled (%s)" % [detector._current])
	if detector._prompt == null:
		failures.append("hide(disable): prompt unexpectedly null")
	elif detector._prompt.visible:
		failures.append("hide(disable): prompt still visible with no valid target")

	# Re-enable Near and re-focus so the next cases start from a VISIBLE prompt.
	near_it.enabled = true
	detector._refresh_current()
	if detector._current != near_it or detector._prompt == null or not detector._prompt.visible:
		failures.append("hide: failed to re-establish visible focus on Near before free/exit cases")

	# --- L4 HIDE INVARIANT: range-exit the focused target -> prompt hidden ---
	# The clean steady-state path: area_exited removes Near from _in_range, next
	# refresh finds best == null, the invariant hides the prompt.
	detector._on_area_exited(near_it)
	_focused.clear()
	_unfocused.clear()
	detector._refresh_current()
	if detector._current != null:
		failures.append("hide(range-exit): focus did not clear after area_exited (%s)" % [detector._current])
	if detector._prompt != null and detector._prompt.visible:
		failures.append("hide(range-exit): prompt still visible after focused target left range")

	# --- L4 HIDE INVARIANT: deferred queue_free ordering --------------------
	# Reproduce root-cause #1: the focused target is queue_free()'d (deferred),
	# so for one frame it is still in _in_range but is_instance_valid() is about
	# to go false; area_exited has not yet fired. The per-frame invariant must
	# hide the prompt the moment the node becomes invalid, WITHOUT relying on a
	# focus-change edge.
	# Re-establish a fresh, visible focus on a brand-new target first.
	var doomed_it: Variant = it_packed.instantiate()
	doomed_it.display_name = "Doomed"
	doomed_it.interactable_id = &"junk"
	doomed_it.prompt_text = "Grab"
	root.add_child(doomed_it)
	doomed_it.global_position = detector.global_position  # 0px -> nearest
	detector._on_area_entered(doomed_it)
	detector._refresh_current()
	if detector._current != doomed_it or detector._prompt == null or not detector._prompt.visible:
		failures.append("hide(deferred-free): failed to focus+show on Doomed target")
	# queue_free is deferred: the node is still in _in_range and still == _current
	# this instant, but free it for real (synchronous, mimicking the post-defer
	# state) and refresh WITHOUT calling area_exited -- the invariant must hide.
	doomed_it.free()
	_focused.clear()
	_unfocused.clear()
	detector._refresh_current()
	if detector._current != null:
		failures.append("hide(deferred-free): _current not cleared after focused target freed (%s)" % [detector._current])
	if detector._prompt != null and detector._prompt.visible:
		failures.append("hide(deferred-free): prompt stranded visible after focused target was freed")

	detector.free()
	near_it.free()
	far_it.free()

	if failures.is_empty():
		print("INTERACT OK — focus(nearest), interaction_requested(target), hysteresis, enabled-guard, and prompt hide-invariant (disable/range-exit/deferred-free) verified")
		quit(0)
	else:
		for f in failures:
			printerr("INTERACT FAIL: ", f)
		quit(1)


func _on_focused(target: Node) -> void:
	_focused.append(target)


func _on_unfocused(target: Node) -> void:
	_unfocused.append(target)


func _on_requested(id: StringName, target: Node) -> void:
	_requests.append([id, target])
