extends Node
## Headless acceptance test for M1.12 V5 — the InteractionOwner helper
## (components/interaction/interaction_owner.gd), extracted from the id-guard +
## parent-check + fat-finger-lockout mechanism previously duplicated verbatim
## across ExtractGate/DeparturePortal/HubShop (all three, lockout_s > 0) and
## partially (id-guard + parent-check only, NO lockout) in JunkPickup.
##
## Run as a SCENE (not --script), since it needs a live SceneTree for
## get_tree().create_timer() + await:
##   godot --headless --path Game res://tests/test_interaction_owner.tscn
##
## Asserts (per V5_interaction_owner_helper.md's "Test addition" + Resolved
## Decisions #3):
##   1. lockout_s = 0.25: two back-to-back requests with a matching id/parent →
##      `activated` fires exactly once; after the window elapses, a further
##      request fires `activated` again.
##   2. lockout_s = 0.0 (JunkPickup's case): three back-to-back requests all
##      fire `activated` — proves the no-debounce path survives the extraction.
##   3. A wrong-id and a wrong-parent request never fire `activated` (the
##      guard the four owners relied on implicitly before this refactor).

const OWNER_ID := &"test_owner"


func _ready() -> void:
	get_tree().quit(await _run())


func _run() -> int:
	var failures: Array[String] = []

	await _test_lockout_window(failures)
	await _test_no_lockout(failures)
	await _test_wrong_id_and_parent(failures)

	if failures.is_empty():
		print("INTERACTION_OWNER OK — lockout_s=0.25 debounces then re-arms after the "
			+ "window, lockout_s=0.0 (JunkPickup's case) never debounces, and wrong-id/"
			+ "wrong-parent requests never activate.")
		return 0
	for f in failures:
		printerr("INTERACTION_OWNER FAIL: ", f)
	return 1


## A bare owner Node (stands in for ExtractGate/DeparturePortal/HubShop/JunkPickup)
## with a child Interactable-shaped stand-in target, so target.get_parent() == owner.
func _make_owner_and_target() -> Dictionary:
	var owner := Node.new()
	add_child(owner)
	var target := Node.new()
	owner.add_child(target)
	return {"owner": owner, "target": target}


func _test_lockout_window(failures: Array[String]) -> void:
	var setup := _make_owner_and_target()
	var owner: Node = setup["owner"]
	var target: Node = setup["target"]

	var io := InteractionOwner.new(owner, OWNER_ID, 0.25)
	owner.add_child(io)
	var fire_count := {"n": 0}
	io.activated.connect(func(_t: Node) -> void: fire_count["n"] += 1)

	# Two back-to-back requests within the lockout window: only the first should fire.
	EventBus.interaction_requested.emit(OWNER_ID, target)
	EventBus.interaction_requested.emit(OWNER_ID, target)
	if fire_count["n"] != 1:
		failures.append("(1) lockout window: expected exactly 1 activation for 2 "
			+ "back-to-back requests, got %d" % fire_count["n"])

	# Wait past the 0.25s window, then fire again — must activate a second time.
	await get_tree().create_timer(0.3).timeout
	EventBus.interaction_requested.emit(OWNER_ID, target)
	if fire_count["n"] != 2:
		failures.append("(1) lockout window: expected a second activation after the "
			+ "window elapsed, got %d total" % fire_count["n"])

	owner.queue_free()
	await get_tree().process_frame


func _test_no_lockout(failures: Array[String]) -> void:
	var setup := _make_owner_and_target()
	var owner: Node = setup["owner"]
	var target: Node = setup["target"]

	var io := InteractionOwner.new(owner, OWNER_ID, 0.0)
	owner.add_child(io)
	var fire_count := {"n": 0}
	io.activated.connect(func(_t: Node) -> void: fire_count["n"] += 1)

	# Three back-to-back requests, no lockout armed (JunkPickup's case) — all fire.
	EventBus.interaction_requested.emit(OWNER_ID, target)
	EventBus.interaction_requested.emit(OWNER_ID, target)
	EventBus.interaction_requested.emit(OWNER_ID, target)
	if fire_count["n"] != 3:
		failures.append("(2) lockout_s=0.0: expected 3 activations for 3 back-to-back "
			+ "requests, got %d" % fire_count["n"])

	owner.queue_free()
	await get_tree().process_frame


func _test_wrong_id_and_parent(failures: Array[String]) -> void:
	var setup := _make_owner_and_target()
	var owner: Node = setup["owner"]
	var target: Node = setup["target"]

	var io := InteractionOwner.new(owner, OWNER_ID, 0.0)
	owner.add_child(io)
	var fire_count := {"n": 0}
	io.activated.connect(func(_t: Node) -> void: fire_count["n"] += 1)

	# Wrong id: never activates.
	EventBus.interaction_requested.emit(&"not_the_owner_id", target)
	if fire_count["n"] != 0:
		failures.append("(3) wrong id: expected 0 activations, got %d" % fire_count["n"])

	# Wrong parent: a target whose parent is NOT this owner never activates.
	var other_owner := Node.new()
	add_child(other_owner)
	var other_target := Node.new()
	other_owner.add_child(other_target)
	EventBus.interaction_requested.emit(OWNER_ID, other_target)
	if fire_count["n"] != 0:
		failures.append("(3) wrong parent: expected 0 activations, got %d" % fire_count["n"])

	other_owner.queue_free()
	owner.queue_free()
	await get_tree().process_frame
