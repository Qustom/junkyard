extends Node
## Headless integration drive of the ASSEMBLED MainGame scene (G3).
##
## Where test_loop_drive isolates the GameState loop CONTRACT, this proves the actual
## scenes/game/main_game.tscn wiring: it instances the real MainGame, calls its
## start_new_run() loop entry, and verifies the world is assembled (band geometry +
## junk pickups + a gate + the player in the "player" group), then drives a real
## interaction-based pickup and a gate extract through EventBus, then loops again.
##
## Run as a SCENE so autoloads resolve:
##   godot --headless res://tests/test_main_game_loop.tscn
##
## Asserts:
##   1. start_new_run() builds a band (BandContainer has children: pieces + pickups + gate).
##   2. The player is registered in the "player" group (W4-6 drop-lookup fix).
##   3. A real interaction_requested(&"junk", ...) adds to the run bag (loop's first half).
##   4. A real interaction_requested(&"gate", ...) extracts → run_ended(extract), run inactive,
##      and the carried junk is HELD-banked in meta (M1.6 M2: no auto-sell; M3's Shop sells).
##   5. start_new_run() works AGAIN cleanly (fresh run-state, old band torn down).

const MAIN_GAME_PATH := "res://scenes/game/main_game.tscn"


func _ready() -> void:
	get_tree().quit(await _run())


func _run() -> int:
	var failures: Array[String] = []

	var ended: Array = []
	EventBus.run_ended.connect(func(reason: StringName, _d: float, _depth: int) -> void: ended.append(reason))

	# Clean meta slate.
	var empty: Array[JunkItem] = []
	GameState.banked_junk = empty.duplicate()

	var scene := load(MAIN_GAME_PATH) as PackedScene
	if scene == null:
		printerr("MAIN GAME FAIL: could not load %s" % MAIN_GAME_PATH)
		return 1
	var game: MainGame = scene.instantiate() as MainGame
	add_child(game)
	# M1.6 (M2): main_game is dive-only and SELF-STARTS a run on _ready (the dive scene IS
	# the dive). We let that settle, then call start_new_run() again to exercise the public
	# loop entry the RG tests still drive — a fresh restart with the old band torn down.
	await get_tree().process_frame  # let _ready() load fixtures + self-start the run

	# --- 1. Start a run: world assembled ------------------------------------
	game.start_new_run()
	await get_tree().process_frame  # let spawned pickups _ready() (connect interaction)

	var container := game.get_node("BandContainer")
	if container.get_child_count() == 0:
		failures.append("start_new_run produced an empty BandContainer")

	# A gate exists in the world.
	var gate := _first_gate(container)
	if gate == null:
		failures.append("no ExtractGate spawned into the band")

	# At least one JunkPickup exists.
	var pickup := _first_pickup(container)
	if pickup == null:
		failures.append("no JunkPickup spawned into the band")

	# --- 2. Player in the "player" group ------------------------------------
	if get_tree().get_first_node_in_group(&"player") == null:
		failures.append("player not registered in the \"player\" group (W4-6)")

	# --- 3. Real interaction-based pickup -----------------------------------
	if pickup != null:
		var item: JunkItem = pickup.item
		var before: int = GameState.run_inventory.items.size()
		var interactable := pickup.get_node("Interactable")
		EventBus.interaction_requested.emit(&"junk", interactable)
		await get_tree().process_frame
		if GameState.run_inventory.items.size() != before + 1:
			failures.append("interaction pickup did not add to the run bag")
		if not GameState.run_inventory.items.has(item):
			failures.append("picked item missing from run bag")

	# --- 4. Gate extract via interaction ------------------------------------
	# M1.6 (M2): extract ends the run and BANKS the carried junk into meta (banked_junk) —
	# it no longer auto-sells. The SellScreen is gone; the App router auto-returns to the
	# Hub on run_ended, and M3's Shop converts the held bank to Money later. So we assert
	# the M2 LOOP RESULT: extract → run_ended(extract) → run inactive → the carried item is
	# HELD in banked_junk (not sold). Money is unchanged by extract alone.
	if gate != null:
		var banked_before: int = GameState.banked_junk.size()
		var gate_interactable := gate.get_node("Interactable")
		var ended_before: int = ended.size()
		EventBus.interaction_requested.emit(&"gate", gate_interactable)
		await get_tree().process_frame
		if ended.size() != ended_before + 1 or ended[ended.size() - 1] != &"extract":
			failures.append("gate interact did not end the run with cause extract")
		if GameState.run_active:
			failures.append("run_active still true after gate extract")
		if GameState.banked_junk.size() != banked_before + 1:
			failures.append("loop result: banked_junk %d -> %d, expected +1 (extract → held bank, NOT sold)"
				% [banked_before, GameState.banked_junk.size()])

	# M1.6 (M2): no SellScreen pauses the tree anymore; keep the unpause as a belt-and-braces.
	get_tree().paused = false

	# --- 5. Restart cleanly --------------------------------------------------
	game.start_new_run()
	await get_tree().process_frame
	if not GameState.run_active:
		failures.append("second start_new_run did not start a run")
	if not GameState.run_inventory.items.is_empty():
		failures.append("second run did not reset the bag")
	if container.get_child_count() == 0:
		failures.append("second run produced an empty band")

	get_tree().paused = false
	GameState.banked_junk = empty.duplicate()
	game.queue_free()

	if failures.is_empty():
		print("MAIN GAME OK — assembled dive-only scene built a band (pieces+pickups+gate), player in group, "
			+ "interaction pickup + gate extract drove run_ended(extract) with the haul held-banked (not sold), "
			+ "and a second run restarted clean.")
		return 0
	for f in failures:
		printerr("MAIN GAME FAIL: ", f)
	return 1


func _first_pickup(node: Node) -> JunkPickup:
	var as_pickup := node as JunkPickup
	if as_pickup != null:
		return as_pickup
	for c in node.get_children():
		var found := _first_pickup(c)
		if found != null:
			return found
	return null


func _first_gate(node: Node) -> ExtractGate:
	var as_gate := node as ExtractGate
	if as_gate != null:
		return as_gate
	for c in node.get_children():
		var found := _first_gate(c)
		if found != null:
			return found
	return null
