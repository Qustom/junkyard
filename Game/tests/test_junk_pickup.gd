extends Node
## Headless acceptance test for C2 — junk pickup in the band.
##
## Run as a SCENE (not --script) so the EventBus / RNG / GameState autoloads are
## present (mirrors B3's test_band_depth; autoloads aren't registered as globals
## under --script):
##   godot --headless res://tests/test_junk_pickup.tscn
##
## Proves the C2 acceptance criteria:
##   1. Populate: B2 generate → B3 grade → B3 plan → C2 populate; a JunkPickup is
##      instantiated per plan entry (count == plan size).
##   2. Successful pickup: interaction_requested(&"junk", interactable) adds the
##      item to GameState.run_inventory, frees the pickup, and fires
##      junk_picked_up(..., accepted=true) with the right id/value/slot_size.
##   3. Full-bag rejection: fill the bag, interact on another pickup → NOT added,
##      pickup STAYS in the world, junk_picked_up(..., accepted=false) fired.
##   4. Drop re-spawn: emit junk_dropped(item, pos) → JunkSpawner.spawn_one
##      re-spawns a fresh grabbable pickup in the same container.

const PIECE_CATALOG_PATH := "res://data/piece_catalog.tres"
const CONFIG_PATH := "res://data/bandgen_config.tres"
const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"
const DEPTH_CURVE_PATH := "res://systems/depth/depth_curve.tres"

const SEED := 12345


func _ready() -> void:
	var code := await _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []

	var piece_catalog_res = load(PIECE_CATALOG_PATH)
	var cfg = load(CONFIG_PATH)
	var junk_catalog: JunkCatalog = load(JUNK_CATALOG_PATH)
	var curve: DepthCurve = load(DEPTH_CURVE_PATH)
	if piece_catalog_res == null or cfg == null or junk_catalog == null or curve == null:
		printerr("JUNK PICKUP FAIL: could not load fixtures")
		return 1
	var piece_catalog: Array[ZonePieceData] = piece_catalog_res.pieces

	# --- Start a run so GameState.run_inventory exists ----------------------
	GameState.start_run(&"test_band", SEED)
	if GameState.run_inventory == null:
		printerr("JUNK PICKUP FAIL: run_inventory null after start_run")
		return 1
	# Generous bag so the first pickup is accepted regardless of item slot_size.
	GameState.run_inventory.max_slots = 999

	# --- Track junk_picked_up emissions -------------------------------------
	var pickup_log: Array = []
	EventBus.junk_picked_up.connect(
		func(id: StringName, value: int, slot_size: int, pos: Vector2, accepted: bool) -> void:
			pickup_log.append({"id": id, "value": value, "slot_size": slot_size, "pos": pos, "accepted": accepted}))

	# --- Generate + grade + plan (B2/B3) ------------------------------------
	var gen := BandGenerator.new()
	var grader := DepthGrader.new()
	var placer := JunkPlacer.new()

	var band := gen.generate(SEED, cfg, piece_catalog)
	grader.grade(band)
	grader.compute_return_distance(band)
	var plan := placer.plan(band, curve, junk_catalog)
	if plan.is_empty():
		printerr("JUNK PICKUP FAIL: B3 plan is empty (cannot exercise pickup)")
		_free_band(band)
		return 1

	# --- 1. Populate via the C2 spawner -------------------------------------
	var container := Node2D.new()
	add_child(container)
	var spawner := JunkSpawner.new()
	add_child(spawner)
	var pickups := spawner.populate(plan, container)

	if pickups.size() != plan.size():
		failures.append("populate count %d != plan size %d" % [pickups.size(), plan.size()])
	# Confirm they are real children of the container.
	if container.get_child_count() != plan.size():
		failures.append("container has %d children, expected %d" % [container.get_child_count(), plan.size()])

	# Let _ready() run on the spawned pickups so they connect interaction_requested.
	await get_tree().process_frame

	# --- 2. Successful pickup ----------------------------------------------
	var target_pickup: JunkPickup = pickups[0]
	var target_item: JunkItem = target_pickup.item
	var expected_id: StringName = target_item.id
	var expected_value: int = target_item.base_sell_value
	var expected_slot: int = target_item.slot_size
	var interactable_a := target_pickup.get_node("Interactable")

	var items_before := GameState.run_inventory.items.size()
	EventBus.interaction_requested.emit(&"junk", interactable_a)
	await get_tree().process_frame  # allow queue_free to take effect

	if GameState.run_inventory.items.size() != items_before + 1:
		failures.append("accept: inventory did not grow (%d -> %d)"
			% [items_before, GameState.run_inventory.items.size()])
	if not GameState.run_inventory.items.has(target_item):
		failures.append("accept: picked item not in run_inventory.items")
	if is_instance_valid(target_pickup):
		failures.append("accept: pickup was NOT freed from the world")

	# The accepted event fired last with the right snapshot.
	var accept_evt := _last_event(pickup_log, true)
	if accept_evt.is_empty():
		failures.append("accept: no junk_picked_up(accepted=true) fired")
	else:
		if accept_evt["id"] != expected_id:
			failures.append("accept: event id %s != %s" % [accept_evt["id"], expected_id])
		if accept_evt["value"] != expected_value:
			failures.append("accept: event value %d != %d" % [accept_evt["value"], expected_value])
		if accept_evt["slot_size"] != expected_slot:
			failures.append("accept: event slot_size %d != %d" % [accept_evt["slot_size"], expected_slot])

	# --- 3. Full-bag rejection ----------------------------------------------
	# Find another still-valid pickup.
	var reject_pickup: JunkPickup = null
	for p in pickups:
		if is_instance_valid(p) and p != target_pickup:
			reject_pickup = p
			break
	if reject_pickup == null:
		failures.append("reject: no second pickup available to test rejection")
	else:
		# Fill the bag so can_accept() is false for the next item.
		GameState.run_inventory.max_slots = GameState.run_inventory.used_slots()
		if not GameState.run_inventory.is_full():
			failures.append("reject: failed to force a full bag")
		var reject_item: JunkItem = reject_pickup.item
		var count_before := GameState.run_inventory.items.size()
		var interactable_b := reject_pickup.get_node("Interactable")
		EventBus.interaction_requested.emit(&"junk", interactable_b)
		await get_tree().process_frame

		if GameState.run_inventory.items.size() != count_before:
			failures.append("reject: inventory changed on a rejected pickup")
		if GameState.run_inventory.items.has(reject_item) and not _appeared_twice(GameState.run_inventory.items, reject_item):
			failures.append("reject: rejected item was added to inventory")
		if not is_instance_valid(reject_pickup):
			failures.append("reject: pickup was freed (should stay in world)")
		var reject_evt := _last_event(pickup_log, false)
		if reject_evt.is_empty():
			failures.append("reject: no junk_picked_up(accepted=false) fired")

	# --- 4. Drop re-spawn via junk_dropped → spawn_one ----------------------
	var children_before := container.get_child_count()
	var drop_item: JunkItem = junk_catalog.items[0]
	var drop_pos := Vector2(123, 456)
	EventBus.junk_dropped.emit(drop_item, drop_pos)
	await get_tree().process_frame

	if container.get_child_count() != children_before + 1:
		failures.append("drop: junk_dropped did not re-spawn a pickup (%d -> %d)"
			% [children_before, container.get_child_count()])
	else:
		var newest := container.get_child(container.get_child_count() - 1) as JunkPickup
		if newest == null or newest.item != drop_item:
			failures.append("drop: re-spawned pickup has wrong/no item")
		elif not newest.global_position.is_equal_approx(drop_pos):
			failures.append("drop: re-spawned pickup at %s, expected %s" % [newest.global_position, drop_pos])

	# --- Report -------------------------------------------------------------
	_free_band(band)
	if failures.is_empty():
		print("JUNK PICKUP OK — populated %d pickups from B3 plan (seed %d); " % [plan.size(), SEED]
			+ "accept added '%s' ($%d, %d slot) and freed it; " % [expected_id, expected_value, expected_slot]
			+ "full-bag reject left the junk in-world; drop re-spawned via spawn_one.")
		return 0
	for f in failures:
		printerr("JUNK PICKUP FAIL: ", f)
	return 1


## Latest event in the log matching the given accepted flag, or {} if none.
func _last_event(log: Array, accepted: bool) -> Dictionary:
	for i in range(log.size() - 1, -1, -1):
		if log[i]["accepted"] == accepted:
			return log[i]
	return {}


## True if `item` appears 2+ times in `arr` (guards the reject assertion against a
## catalog dup that legitimately shares the same ref from a prior accept).
func _appeared_twice(arr: Array, item: JunkItem) -> bool:
	var n := 0
	for x in arr:
		if x == item:
			n += 1
	return n >= 2


func _free_band(band: Band) -> void:
	if band == null:
		return
	for p in band.pieces:
		if p.instance != null and is_instance_valid(p.instance):
			p.instance.free()
