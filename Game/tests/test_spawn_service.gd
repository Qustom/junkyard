extends Node
## Headless acceptance test for S0 (M1.9) — the policy-free SpawnService mechanism.
##
## Run as a SCENE (autoloads + a live tree):
##   godot --headless --path Game res://tests/test_spawn_service.tscn
##
## Drives the service DIRECTLY with a synthetic OppositionDef (a runtime-built stub
## PackedScene whose root records its setup() calls) — no band, no policy — mirroring
## test_new_hazard_spawn.gd's hand-built-harness approach. The K5 seam integration
## (byte-identical placement through the service) is proven separately by the UNMODIFIED
## golden harness test_new_hazard_spawn.tscn.
##
## Asserts (S0 spec §7 DoD item 7, as amended by §9/OQ-10):
##   (a) spawn() materialises under the container, calls setup(cfg, player, ctx), returns
##       the node, and emits exactly one opposition_event(id, &"spawned", depth, run_t_ms);
##   (b) caps refuse at ceiling: a cap_group of N accepts N and refuses N+1; can_afford
##       flips false at N; per-def per_band_cap refuses independently;
##   (c) registry: live_count / live_instances / live_total track spawn, despawn, and a
##       freed-without-despawn node (drops off after the validity sweep); spawn_cell_of
##       round-trips (spawn at C -> C; unregistered -> Vector2i.MAX);
##   (d) clear_all frees every registered node and zeroes counts/groups;
##   (e) entry-safe refusal: a cell inside SPAWN_SAFE_CELLS of entry_pos is dropped by
##       valid_cells() AND refused by spawn(); an unarmed service filters nothing;
##   (f) spawn_batch returns per-request results in order (nulls in place);
##       ignore_room_cap ctx is honored (skips ONLY the per-room tier);
##   (g) no RNG: two identical request sequences produce identical node positions;
##       world_to_cell(cell_to_world(c)) == c identity;
##   (h) staging round-trip (the S8 seam S0 pre-declared): dive_requested(&"band_two")
##       -> consume_pending_dive_band() == &"band_two"; a second consume == &"".

const CELL := 16

var _events: Array[Array] = []   # recorded opposition_event emissions


func _ready() -> void:
	var code: int = await _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []
	EventBus.opposition_event.connect(_on_opposition_event)

	var stub_scene := _make_stub_scene()
	var cfg := RunConfig.new()

	# --- (a) spawn basics: parent / place / setup / return / one &"spawned" emit ----
	var svc := _fresh_service()
	var container := _fresh_container()
	svc.begin_band(container, CELL, Vector2.INF, cfg)   # unarmed (no entry exclusion)
	var def := _make_def(&"stub", stub_scene)
	_events.clear()
	var ctx := { "depth": 3, "run_t_ms": 7, "marker": 42 }
	var node := svc.spawn(def, Vector2i(5, 4), ctx)
	if node == null:
		failures.append("(a) spawn() returned null on a valid request")
	else:
		if node.get_parent() != container:
			failures.append("(a) spawned node not parented under the container")
		var want_pos := Vector2(Vector2i(5, 4) * CELL) + Vector2(CELL, CELL) * 0.5
		if (node as Node2D).global_position != want_pos:
			failures.append("(a) spawned at %s, expected %s"
				% [(node as Node2D).global_position, want_pos])
		var calls: Array = node.get("setup_calls")
		if calls.size() != 1:
			failures.append("(a) setup() called %d times, expected 1" % calls.size())
		elif calls[0]["cfg"] != cfg or calls[0]["ctx"].get("marker", 0) != 42:
			failures.append("(a) setup() did not receive the begin_band cfg + the opaque ctx")
	if _events.size() != 1:
		failures.append("(a) %d opposition_event emissions, expected exactly 1" % _events.size())
	elif _events[0] != [&"stub", &"spawned", 3, 7]:
		failures.append("(a) opposition_event payload %s, expected [stub, spawned, 3, 7]"
			% [_events[0]])

	# --- (b) caps: cap_group ceiling + can_afford + independent per_band_cap --------
	var svc_cap := _fresh_service()
	var cont_cap := _fresh_container()
	svc_cap.begin_band(cont_cap, CELL, Vector2.INF, cfg)
	svc_cap.set_cap_group(&"grp", 3)
	var def_g := _make_def(&"grouped", stub_scene)
	def_g.cap_group = &"grp"
	var accepted := 0
	for i in 3:
		if svc_cap.spawn(def_g, Vector2i(i, 0), {}) != null:
			accepted += 1
	if accepted != 3:
		failures.append("(b) cap_group 3 accepted %d, expected 3" % accepted)
	if svc_cap.can_afford(def_g, Vector2i(9, 9)):
		failures.append("(b) can_afford true at a full cap_group, expected false")
	if svc_cap.spawn(def_g, Vector2i(3, 0), {}) != null:
		failures.append("(b) cap_group of 3 accepted a 4th spawn")
	# per_band_cap refuses independently (no cap_group on this def).
	var def_b := _make_def(&"banded", stub_scene)
	def_b.per_band_cap = 2
	if svc_cap.spawn(def_b, Vector2i(0, 5), {}) == null \
			or svc_cap.spawn(def_b, Vector2i(1, 5), {}) == null:
		failures.append("(b) per_band_cap 2 refused an in-budget spawn")
	if svc_cap.spawn(def_b, Vector2i(2, 5), {}) != null:
		failures.append("(b) per_band_cap of 2 accepted a 3rd spawn")

	# --- (c) registry: counts, instances, despawn, free-without-despawn, cells ------
	var svc_reg := _fresh_service()
	var cont_reg := _fresh_container()
	svc_reg.begin_band(cont_reg, CELL, Vector2.INF, cfg)
	var def_r := _make_def(&"reg", stub_scene)
	var n1 := svc_reg.spawn(def_r, Vector2i(1, 1), {})
	var n2 := svc_reg.spawn(def_r, Vector2i(2, 2), {})
	var n3 := svc_reg.spawn(def_r, Vector2i(3, 3), {})
	if svc_reg.live_count(&"reg") != 3 or svc_reg.live_total() != 3:
		failures.append("(c) live_count/live_total != 3 after 3 spawns (%d/%d)"
			% [svc_reg.live_count(&"reg"), svc_reg.live_total()])
	var inst := svc_reg.live_instances(&"reg")
	if inst.size() != 3 or not (inst.has(n1) and inst.has(n2) and inst.has(n3)):
		failures.append("(c) live_instances does not hold the 3 spawned nodes")
	if svc_reg.spawn_cell_of(n2) != Vector2i(2, 2):
		failures.append("(c) spawn_cell_of round-trip failed: %s" % svc_reg.spawn_cell_of(n2))
	if svc_reg.spawn_cell_of(self) != Vector2i.MAX:
		failures.append("(c) spawn_cell_of(unregistered) != Vector2i.MAX")
	svc_reg.despawn(n3)
	if svc_reg.live_count(&"reg") != 2:
		failures.append("(c) live_count != 2 after despawn (%d)" % svc_reg.live_count(&"reg"))
	n1.free()   # freed WITHOUT despawn — must drop off via the validity sweep
	if svc_reg.live_count(&"reg") != 1:
		failures.append("(c) freed-without-despawn node did not drop off the sweep (%d)"
			% svc_reg.live_count(&"reg"))
	if svc_reg.live_instances(&"reg") != ([n2] as Array[Node]):
		failures.append("(c) live_instances after despawn+free should be exactly [n2]")

	# --- (d) clear_all frees every registered node and zeroes counts/groups ---------
	var svc_clr := _fresh_service()
	var cont_clr := _fresh_container()
	svc_clr.begin_band(cont_clr, CELL, Vector2.INF, cfg)
	svc_clr.set_cap_group(&"grp", 2)
	var def_c := _make_def(&"clr", stub_scene)
	def_c.cap_group = &"grp"
	var c1 := svc_clr.spawn(def_c, Vector2i(0, 0), {})
	var c2 := svc_clr.spawn(def_c, Vector2i(1, 0), {})
	if c1 == null or c2 == null:
		failures.append("(d) clear_all setup spawns failed (test mis-set)")
	svc_clr.clear_all()
	if svc_clr.live_total() != 0 or svc_clr.live_count(&"clr") != 0:
		failures.append("(d) counts not zeroed after clear_all")
	await get_tree().process_frame   # let the queue_frees resolve
	await get_tree().process_frame
	if (c1 != null and is_instance_valid(c1)) or (c2 != null and is_instance_valid(c2)):
		failures.append("(d) clear_all did not free the registered nodes")
	# cap groups reset too: re-register and spawn again (a fresh band's worth).
	svc_clr.set_cap_group(&"grp", 1)
	if svc_clr.spawn(def_c, Vector2i(2, 0), {}) == null:
		failures.append("(d) post-clear_all re-registered group refused its first spawn")

	# --- (e) entry-safe refusal (BUG7): armed filters + refuses; unarmed does not ---
	var svc_arm := _fresh_service()
	var cont_arm := _fresh_container()
	var entry_cell := Vector2i(0, 0)
	var entry_pos := Vector2(entry_cell * CELL) + Vector2(CELL, CELL) * 0.5
	svc_arm.begin_band(cont_arm, CELL, entry_pos, cfg)
	var def_e := _make_def(&"entry", stub_scene)
	# SPAWN_SAFE_CELLS = 2.5 → 40px at CELL=16. Cell (1,0) centre is 16px away (inside);
	# cell (5,0) centre is 80px away (outside).
	var near_cell := Vector2i(1, 0)
	var far_cell := Vector2i(5, 0)
	var filtered := svc_arm.valid_cells([entry_cell, near_cell, far_cell] as Array[Vector2i])
	if filtered != ([far_cell] as Array[Vector2i]):
		failures.append("(e) valid_cells kept %s, expected only %s" % [filtered, [far_cell]])
	if svc_arm.spawn(def_e, near_cell, {}) != null:
		failures.append("(e) spawn() accepted an entry-unsafe cell")
	if svc_arm.spawn(def_e, far_cell, {}) == null:
		failures.append("(e) spawn() refused an entry-SAFE cell")
	# Unarmed service (entry_pos == Vector2.INF) filters nothing.
	var svc_una := _fresh_service()
	svc_una.begin_band(_fresh_container(), CELL, Vector2.INF, cfg)
	var all_cells: Array[Vector2i] = [entry_cell, near_cell, far_cell]
	if svc_una.valid_cells(all_cells) != all_cells:
		failures.append("(e) unarmed service filtered cells (expected pass-through)")

	# --- (f) spawn_batch order + nulls in place; ignore_room_cap honored ------------
	var svc_bat := _fresh_service()
	var cont_bat := _fresh_container()
	svc_bat.begin_band(cont_bat, CELL, entry_pos, cfg)   # armed at (0,0)
	var def_f := _make_def(&"batch", stub_scene)
	var batch := svc_bat.spawn_batch([
		{ "def": def_f, "cell": Vector2i(6, 0) },
		{ "def": def_f, "cell": near_cell },              # entry-unsafe → null IN PLACE
		{ "def": def_f, "cell": Vector2i(7, 0), "ctx": { "depth": 1 } },
	])
	if batch.size() != 3 or batch[0] == null or batch[1] != null or batch[2] == null:
		failures.append("(f) spawn_batch order/nulls wrong: %s" % [batch])
	# ignore_room_cap skips ONLY the per-room tier.
	var svc_room := _fresh_service()
	svc_room.begin_band(_fresh_container(), CELL, Vector2.INF, cfg)
	var def_room := _make_def(&"roomy", stub_scene)
	def_room.per_room_cap = 1
	if svc_room.spawn(def_room, Vector2i(0, 0), { "room_key": "A" }) == null:
		failures.append("(f) per_room_cap 1 refused the first spawn in room A")
	if svc_room.spawn(def_room, Vector2i(1, 0), { "room_key": "A" }) != null:
		failures.append("(f) per_room_cap 1 accepted a 2nd spawn in room A")
	if svc_room.spawn(def_room, Vector2i(0, 1), { "room_key": "B" }) == null:
		failures.append("(f) per_room_cap bound a DIFFERENT room (B)")
	if svc_room.spawn(def_room, Vector2i(2, 0),
			{ "room_key": "A", "ignore_room_cap": true }) == null:
		failures.append("(f) ignore_room_cap did not skip the per-room tier")

	# --- (g) no RNG: identical request sequences → identical positions; projections --
	var seq: Array[Vector2i] = [Vector2i(4, 1), Vector2i(9, 2), Vector2i(3, 7)]
	var pos_a := _run_sequence(stub_scene, cfg, seq)
	var pos_b := _run_sequence(stub_scene, cfg, seq)
	if pos_a != pos_b or pos_a.is_empty():
		failures.append("(g) identical request sequences diverged: %s vs %s" % [pos_a, pos_b])
	var svc_prj := _fresh_service()
	svc_prj.begin_band(_fresh_container(), CELL, Vector2.INF, cfg)
	for c in [Vector2i(0, 0), Vector2i(-3, 7), Vector2i(120, -45)]:
		if svc_prj.world_to_cell(svc_prj.cell_to_world(c)) != c:
			failures.append("(g) world_to_cell(cell_to_world(%s)) != %s" % [c, c])

	# --- (h) GameState dive-band staging round-trip (the S8 seam, pre-declared) -----
	EventBus.dive_requested.emit(&"band_two")
	var staged: StringName = GameState.consume_pending_dive_band()
	if staged != &"band_two":
		failures.append("(h) consume_pending_dive_band() == %s, expected &\"band_two\"" % staged)
	if GameState.consume_pending_dive_band() != &"":
		failures.append("(h) second consume did not return &\"\" (consume-on-read broken)")

	EventBus.opposition_event.disconnect(_on_opposition_event)
	if failures.is_empty():
		print("S0 OK — SpawnService verified: spawn/parent/place/setup/&\"spawned\" emit, "
			+ "cap_group + per_band_cap refusal at ceiling, registry counts/instances/cells "
			+ "(despawn + free-without-despawn sweep), clear_all teardown + accounting reset, "
			+ "BUG7 entry-safe valid_cells()/spawn() refusal (unarmed passes through), "
			+ "spawn_batch order + ignore_room_cap, deterministic (no RNG) placement, "
			+ "projection identity, and the dive-band staging round-trip.")
		return 0
	for f in failures:
		printerr("S0 FAIL: ", f)
	return 1


func _on_opposition_event(id: StringName, event: StringName, depth: int, run_t_ms: int) -> void:
	_events.append([id, event, depth, run_t_ms])


## A fresh SpawnService parented under this test node (in-tree, like MainGame owns it).
func _fresh_service() -> SpawnService:
	var svc := SpawnService.new()
	add_child(svc)
	return svc


## A fresh in-tree container standing in for the band container.
func _fresh_container() -> Node2D:
	var c := Node2D.new()
	add_child(c)
	return c


## A synthetic OppositionDef around the stub scene (no .tres — the 4 authored defs are
## exercised through the UNMODIFIED golden K5 seam harness instead).
func _make_def(id: StringName, scene: PackedScene) -> OppositionDef:
	var def := OppositionDef.new()
	def.id = id
	def.host_scene = scene
	return def


## A runtime-built stub hazard scene: a Node2D whose script records every setup() call,
## so the LOCKED setup(cfg, player, spawn_ctx) handshake is probe-able.
func _make_stub_scene() -> PackedScene:
	var script := GDScript.new()
	script.source_code = """extends Node2D
var setup_calls: Array = []
func setup(cfg, player, spawn_ctx) -> void:
	setup_calls.append({\"cfg\": cfg, \"player\": player, \"ctx\": spawn_ctx})
"""
	script.reload()
	var proto := Node2D.new()
	proto.set_script(script)
	var packed := PackedScene.new()
	packed.pack(proto)
	proto.free()
	return packed


## Spawn the same cell sequence on a fresh service/container and return the positions.
func _run_sequence(stub_scene: PackedScene, cfg: RunConfig, cells: Array[Vector2i]) -> Array[Vector2]:
	var svc := _fresh_service()
	var container := _fresh_container()
	svc.begin_band(container, CELL, Vector2.INF, cfg)
	var def := _make_def(&"det", stub_scene)
	var out: Array[Vector2] = []
	for c in cells:
		var n := svc.spawn(def, c, {})
		if n != null:
			out.append((n as Node2D).global_position)
	return out
