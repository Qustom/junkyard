class_name JunkSpawner
extends Node
## JunkSpawner — instantiates JunkPickup world entities from B3's plan (C2).
##
## SCOPE SEAM (B3 owns the plan; C2 owns the spawn): B3's JunkPlacer.plan() is the
## single source of WHAT goes WHERE — it encapsulates ALL deterministic randomness
## (item selection, depth scaling, placement). This spawner is a PURE CONSUMER of
## that plan: it adds no RNG draws of its own (the C2 spec's RNG.stream("junk_spawn")
## does not exist and is not needed — B3's density curve already folds in any
## per-anchor spawn probability). Same seed → same plan → same pickups.
##
## Two entry points, one instantiation path:
##   - populate(plan, container): the band-generation step calls this directly
##     after grading + planning (NOT a fire-and-forget signal — spawning has a
##     hard ordering + data dependency on the band/plan, per the C2 recommendation).
##   - spawn_one(item, world_pos, container): the shared single-pickup factory.
##     Also driven by EventBus.junk_dropped so D2's drop-to-swap re-spawns a
##     re-grabbable pickup through the SAME code (no duplicated instantiation).

## The JunkPickup scene to instance. Defaults to the C2 entity; overridable for
## tests that want a stub.
@export var pickup_scene: PackedScene = preload("res://entities/junk_pickup/junk_pickup.tscn")

## When set, junk_dropped events re-spawn into this container (so the drop path
## has somewhere to put the pickup once D2 emits). Tests/the band set this.
var _drop_container: Node = null


func _ready() -> void:
	# Drop-to-swap re-spawn: D2's drop gesture (a one-line follow-up in D2) emits
	# junk_dropped; we turn it back into a grabbable world pickup via spawn_one.
	EventBus.junk_dropped.connect(_on_junk_dropped)


## Instantiate one JunkPickup per plan entry. `plan` is B3's
## Array[Dictionary] of { world_pos: Vector2, item: JunkItem, depth: int }.
## Returns the spawned pickups (handy for tests / later cleanup).
func populate(plan: Array, container: Node) -> Array[JunkPickup]:
	_drop_container = container  # dropped junk re-spawns into the same band container
	var spawned: Array[JunkPickup] = []
	if container == null:
		push_warning("JunkSpawner.populate: null container; nothing spawned.")
		return spawned
	for entry in plan:
		var item: JunkItem = entry.get("item", null)
		var pos: Vector2 = entry.get("world_pos", Vector2.ZERO)
		if item == null:
			continue
		var pickup := spawn_one(item, pos, container)
		if pickup != null:
			spawned.append(pickup)
	EventBus.band_populated.emit(spawned.size())
	return spawned


## Shared single-pickup factory — the ONE place a JunkPickup is instantiated.
## Used by populate() (per plan entry) and by the drop-respawn path.
func spawn_one(item: JunkItem, world_pos: Vector2, container: Node) -> JunkPickup:
	if item == null or container == null or pickup_scene == null:
		return null
	var pickup: JunkPickup = pickup_scene.instantiate() as JunkPickup
	if pickup == null:
		push_warning("JunkSpawner.spawn_one: pickup_scene did not instance a JunkPickup.")
		return null
	container.add_child(pickup)
	pickup.global_position = world_pos
	# M1.7 interp-ghost fix: physics_interpolation is ON (project.godot) — without this reset
	# the pickup renders one frame interpolated between its spawn transform and world_pos (the
	# "junk flashes/ghosts" bug). Render-only: no gameplay/RNG change. Covers BOTH planned band
	# junk AND re-dropped junk (the _on_junk_dropped path routes through spawn_one).
	pickup.reset_physics_interpolation()
	pickup.setup(item)
	return pickup


## D2 → world re-spawn. A dropped item becomes an ordinary, re-grabbable pickup at
## the drop position. No special dropped-state; it is identical to a planned one.
func _on_junk_dropped(item: JunkItem, world_pos: Vector2) -> void:
	if _drop_container == null:
		# No band container registered (e.g. outside a populated band) — ignore.
		return
	spawn_one(item, world_pos, _drop_container)
