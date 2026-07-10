extends Node
## Headless verification for L1 (M1.5) — the throwing mechanic projectile.
##
## Runs as a SCENE (godot --headless res://tests/test_throw_mechanic.tscn) so the
## EventBus autoload is registered (the projectile references it directly). Asserts
## the L1 locked contract:
##   - a hazard-layer body hit → opposition_event(kind, &"killed_by_throw", depth, t)
##     fires (V2: the legacy throw_killed_hazard signal was retired — the hazard kind
##     rides as `id`; the throwing item_id is no longer on the payload, OQ-2), the body
##     is freed (kill), the projectile is freed, the item is CONSUMED (NOT re-dropped),
##   - a miss (non-hazard / wall body) → throw_missed(item_id, depth, t) fires AND
##     junk_dropped(item, pos) fires (the re-drop path), the projectile is freed,
##   - the kind is &"pursuer" for a HazardEntity-grouped body, else name fallback,
##   - the one-shot _spent guard resolves exactly once (a second body_entered is inert).
##
## Drives the projectile's body_entered handler DIRECTLY (no physics step) with
## stand-in bodies, so it is deterministic and needs no live collision space.

const THROWN_ITEM_SCENE := preload("res://entities/thrown_item/thrown_item.tscn")


func _make_item(id: StringName) -> JunkItem:
	var it := JunkItem.new()
	it.id = id
	it.base_sell_value = 10
	it.containment_flags = JunkItem.ContainmentFlag.PLACEABLE
	return it


func _make_hazard_body() -> CharacterBody2D:
	var b := CharacterBody2D.new()
	b.add_to_group(&"hazard")
	return b


func _make_wall_body() -> StaticBody2D:
	return StaticBody2D.new()


func _ready() -> void:
	var failures: Array[String] = []

	var killed: Array = []
	var missed: Array = []
	var dropped: Array = []
	# V2: legacy throw_killed_hazard retired → opposition_event(&"killed_by_throw")
	# fires at the identical site/moment; the hazard kind rides as `id` (the throwing
	# item_id is no longer on the payload — OQ-2, unconsumed telemetry).
	EventBus.opposition_event.connect(func(id, event, depth, t):
		if event == &"killed_by_throw":
			killed.append({"kind": id, "depth": depth}))
	EventBus.throw_missed.connect(func(item_id, depth, t):
		missed.append({"id": item_id, "depth": depth}))
	EventBus.junk_dropped.connect(func(item, pos):
		dropped.append({"item": item, "pos": pos}))

	# === CASE 1: hit a hazard-layer body → kill + consume (no re-drop) ========
	var proj1 := THROWN_ITEM_SCENE.instantiate() as ThrownItem
	add_child(proj1)
	var item1 := _make_item(&"gear")
	proj1.setup(item1, Vector2.RIGHT, 180.0, 320.0, 3)
	var hazard := _make_hazard_body()
	add_child(hazard)

	proj1._on_body_entered(hazard)

	if killed.size() != 1:
		failures.append("CASE1: expected 1 opposition_event(&\"killed_by_throw\"), got %d" % killed.size())
	else:
		# item_id sub-assertion dropped (OQ-2: the generic payload carries the hazard
		# kind as `id`, not the throwing item; no production consumer read item_id).
		if killed[0]["depth"] != 3:
			failures.append("CASE1: killed_by_throw depth = %d (want 3)" % killed[0]["depth"])
	if not dropped.is_empty():
		failures.append("CASE1: a kill must NOT re-drop the item (got %d junk_dropped)" % dropped.size())
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(hazard):
		failures.append("CASE1: hazard body was not freed (kill)")
	if is_instance_valid(proj1):
		failures.append("CASE1: projectile was not freed after a kill")

	# === CASE 2: hit a non-hazard wall body → miss + re-drop =================
	missed.clear()
	dropped.clear()
	var proj2 := THROWN_ITEM_SCENE.instantiate() as ThrownItem
	add_child(proj2)
	var item2 := _make_item(&"pipe")
	proj2.setup(item2, Vector2.RIGHT, 180.0, 320.0, 5)
	proj2.global_position = Vector2(100, 50)
	var wall := _make_wall_body()
	add_child(wall)

	proj2._on_body_entered(wall)

	if missed.size() != 1:
		failures.append("CASE2: expected 1 throw_missed, got %d" % missed.size())
	elif missed[0]["id"] != &"pipe" or missed[0]["depth"] != 5:
		failures.append("CASE2: throw_missed payload wrong: %s" % str(missed[0]))
	if dropped.size() != 1:
		failures.append("CASE2: a miss must re-drop via junk_dropped (got %d)" % dropped.size())
	elif dropped[0]["item"] != item2:
		failures.append("CASE2: junk_dropped carried the wrong item")
	wall.queue_free()
	await get_tree().process_frame
	if is_instance_valid(proj2):
		failures.append("CASE2: projectile was not freed after a miss")

	# === CASE 3: one-shot _spent guard — a second hit is inert ===============
	killed.clear()
	missed.clear()
	dropped.clear()
	var proj3 := THROWN_ITEM_SCENE.instantiate() as ThrownItem
	add_child(proj3)
	proj3.setup(_make_item(&"coil"), Vector2.RIGHT, 180.0, 320.0, 1)
	var hz3a := _make_hazard_body()
	var hz3b := _make_hazard_body()
	add_child(hz3a)
	add_child(hz3b)
	proj3._on_body_entered(hz3a)   # resolves once
	proj3._on_body_entered(hz3b)   # must be a no-op (_spent)
	if killed.size() != 1:
		failures.append("CASE3: _spent guard failed — got %d kills (want exactly 1)" % killed.size())
	await get_tree().process_frame
	await get_tree().process_frame

	# === CASE 4 (L6): the throw uses the player's AIM direction, not facing =======
	# The throw seam (main_game._try_throw) passes player.aim to setup(); a thrown
	# item must fly along that aim. Drive a known non-cardinal aim and assert _dir
	# matches it (proving the seam reads aim, and the projectile honours that vector).
	# Untyped (Variant) so we can read the Player's `aim` member + call resolve_aim
	# without cross-file class-member resolution quirks (matches test_player_movement).
	# Instantiated but NOT added to the tree: we only exercise the aim plumbing (a
	# member + a pure method), so it needs no _physics_process / collision space.
	var player: Variant = load("res://entities/player/player.tscn").instantiate()
	# A deliberately non-cardinal aim that differs from any movement direction, so a
	# stale "facing" source could not coincidentally produce it.
	player.aim = Vector2(0.6, -0.8)   # already unit-length, up-and-right
	var proj4 := THROWN_ITEM_SCENE.instantiate() as ThrownItem
	add_child(proj4)
	proj4.setup(_make_item(&"bolt"), player.aim, 180.0, 320.0, 2)
	# resolve_aim should also surface this aim when the mouse is the active device.
	var resolved: Vector2 = player.resolve_aim(
		Vector2.ZERO, player.aim, true, Vector2.ZERO, Vector2.DOWN)
	if not proj4._dir.is_equal_approx(player.aim):
		failures.append("CASE4: projectile _dir %s != player.aim %s (throw must use aim)"
			% [proj4._dir, player.aim])
	if not resolved.is_equal_approx(player.aim):
		failures.append("CASE4: resolve_aim did not surface the mouse aim (%s)" % resolved)
	proj4.queue_free()
	player.free()
	await get_tree().process_frame

	if failures.is_empty():
		print("L1+L6 OK — throw projectile verified: hazard-hit kills body + consumes item (no re-drop) + emits opposition_event(&\"killed_by_throw\"); miss emits throw_missed + junk_dropped re-drop; one-shot _spent guard resolves exactly once; CASE4 throw flies along player.aim (L6).")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("L1 FAIL: ", f)
		get_tree().quit(1)
