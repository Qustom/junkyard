extends Node
## Headless acceptance test for D3 — activate drop-to-swap re-spawn.
##
## Run as a SCENE (not --script) so the EventBus / RNG / GameState autoloads are
## present (mirrors test_junk_pickup; autoloads aren't globals under --script):
##   godot --headless res://tests/test_drop_swap.tscn
##
## D3 wires D2's drop gesture to C2's already-subscribed JunkSpawner. This test
## proves the D2 SIDE of that seam end to end:
##   1. Emit-and-remove: performing the panel's drop handler removes the item from
##      GameState.run_inventory AND emits EventBus.junk_dropped with the SAME
##      JunkItem ref and the player's world position (drop_world_pos resolution).
##   2. Live re-spawn: with a real JunkSpawner registered on a drop container
##      (via populate, as the band does), the drop emit re-instantiates exactly one
##      grabbable JunkPickup at the drop position — closing drop-to-swap.
##   3. Swap integrity: the dropped item is gone from the bag (not both carried and
##      on the ground).
## Prints "DROP SWAP OK" on success; non-zero exit on any failure.

const PIECE_CATALOG_PATH := "res://data/piece_catalog.tres"
const CONFIG_PATH := "res://data/bandgen_config.tres"
const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"
const DEPTH_CURVE_PATH := "res://systems/depth/depth_curve.tres"
const PANEL_SCENE := "res://ui/inventory/inventory_panel.tscn"
const PLAYER_SCENE := "res://entities/player/player.tscn"

const SEED := 12345
const PLAYER_POS := Vector2(640, 360)


func _ready() -> void:
	var code := await _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []

	var piece_catalog_res = load(PIECE_CATALOG_PATH)
	var cfg = load(CONFIG_PATH)
	var junk_catalog: JunkCatalog = load(JUNK_CATALOG_PATH)
	var curve: DepthCurve = load(DEPTH_CURVE_PATH)
	var panel_scene: PackedScene = load(PANEL_SCENE)
	var player_scene: PackedScene = load(PLAYER_SCENE)
	if piece_catalog_res == null or cfg == null or junk_catalog == null \
			or curve == null or panel_scene == null or player_scene == null:
		printerr("DROP SWAP FAIL: could not load fixtures")
		return 1
	var piece_catalog: Array[ZonePieceData] = piece_catalog_res.pieces

	# --- Start a run so GameState.run_inventory exists ----------------------
	GameState.start_run(&"test_band", SEED)
	if GameState.run_inventory == null:
		printerr("DROP SWAP FAIL: run_inventory null after start_run")
		return 1
	var inv: RunInventory = GameState.run_inventory
	inv.max_slots = 999  # generous bag so seeding always fits

	# --- Place a Player in the scene at a known world position --------------
	# The panel resolves drop_world_pos by scanning the CURRENT scene for a
	# Player. We add the player under get_tree().current_scene (this test scene)
	# so _player_world_pos() finds it. global_position is the expected drop point.
	var player := player_scene.instantiate() as Player
	if player == null:
		printerr("DROP SWAP FAIL: player scene did not instance a Player")
		return 1
	get_tree().current_scene.add_child(player)
	player.global_position = PLAYER_POS

	# --- Seed two real catalog items into the bag ---------------------------
	var seeded := 0
	for item in junk_catalog.items:
		if seeded >= 2:
			break
		if inv.try_add(item):
			seeded += 1
	if seeded == 0:
		printerr("DROP SWAP FAIL: could not seed any catalog item")
		return 1

	# --- Register a live spawner on a drop container (as the band does) -----
	# populate() sets the spawner's _drop_container, so junk_dropped re-spawns
	# into it. We feed a minimal real plan so populate registers the container.
	var container := Node2D.new()
	add_child(container)
	var spawner := JunkSpawner.new()
	add_child(spawner)
	await get_tree().process_frame  # spawner._ready connects junk_dropped

	# Build a tiny plan from the catalog so populate registers _drop_container.
	var plan: Array = [{"world_pos": Vector2.ZERO, "item": junk_catalog.items[0], "depth": 1}]
	spawner.populate(plan, container)
	var children_after_populate := container.get_child_count()

	# --- Instantiate the panel (the unit under test) ------------------------
	var panel := panel_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame  # _ready + EventBus.connect

	# --- Track junk_dropped emissions ---------------------------------------
	var drop_log: Array = []
	EventBus.junk_dropped.connect(
		func(item: JunkItem, pos: Vector2) -> void:
			drop_log.append({"item": item, "pos": pos}))

	# --- Perform the drop gesture via the cell's signal ---------------------
	# Find a real item cell and capture which item it maps to, then fire the
	# cell's drop_requested(index) — the panel's _on_cell_drop_requested handler
	# does the remove + emit. This exercises the exact D2→D3 path, not a shortcut.
	var grid: GridContainer = panel.get_node("Margin/VBox/Grid")
	var drop_index := 0
	var dropped_item: JunkItem = inv.items[drop_index]
	var items_before := inv.items.size()

	# Emit drop_requested directly from a live item cell (the gesture's payload).
	var fired := false
	for child in grid.get_children():
		if child.is_queued_for_deletion():
			continue
		var cell := child as InventoryCell
		if cell != null and not cell.is_empty():
			cell.drop_requested.emit(drop_index)
			fired = true
			break
	if not fired:
		failures.append("no live item cell to fire the drop gesture")

	await get_tree().process_frame  # let remove → rebuild + re-spawn settle

	# --- 1. Removed from the bag (swap integrity) ---------------------------
	if inv.items.size() != items_before - 1:
		failures.append("drop did not remove the item from the bag (%d -> %d)"
			% [items_before, inv.items.size()])
	if inv.items.has(dropped_item):
		failures.append("dropped item is STILL in the bag (carried AND on the ground)")

	# --- 2. Emitted junk_dropped with the right item + player position ------
	if drop_log.is_empty():
		failures.append("drop gesture did not emit junk_dropped")
	else:
		var evt: Dictionary = drop_log[-1]
		if evt["item"] != dropped_item:
			failures.append("junk_dropped carried the wrong JunkItem ref")
		if not (evt["pos"] as Vector2).is_equal_approx(PLAYER_POS):
			failures.append("junk_dropped pos %s != player pos %s"
				% [evt["pos"], PLAYER_POS])

	# --- 3. Live spawner re-instantiated exactly one pickup at PLAYER_POS ----
	if container.get_child_count() != children_after_populate + 1:
		failures.append("spawner did not re-spawn exactly one pickup (%d -> %d)"
			% [children_after_populate, container.get_child_count()])
	else:
		var newest := container.get_child(container.get_child_count() - 1) as JunkPickup
		if newest == null or newest.item != dropped_item:
			failures.append("re-spawned pickup has wrong/no item")
		elif not newest.global_position.is_equal_approx(PLAYER_POS):
			failures.append("re-spawned pickup at %s, expected player pos %s"
				% [newest.global_position, PLAYER_POS])

	# --- Report -------------------------------------------------------------
	if failures.is_empty():
		print("DROP SWAP OK — drop gesture removed the item from the bag, emitted "
			+ "junk_dropped(item, player_pos=%s), and C2's live spawner re-instantiated "
				% [PLAYER_POS]
			+ "one grabbable JunkPickup at the player position (drop-to-swap closed).")
		return 0
	for f in failures:
		printerr("DROP SWAP FAIL: ", f)
	return 1
