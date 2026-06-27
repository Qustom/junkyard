extends Node2D
## gate_test.gd — manual demo harness for E1 (NOT an automated test).
##
## Boots a tiny scene with a player and the extract gate placed at the fixed
## hand-authored offset (GameState.GATE_SPAWN_OFFSET, decision #8), starts a run,
## and seeds a couple of catalog junk items into the run inventory so that walking
## to the gate and pressing `interact` visibly banks them and ends the run.
##
## Open in the editor and press Play, then walk the teal player onto the green gate
## and press the interact key. Watch the console for the run_ended / haul_banked log.

const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"

@onready var _gate: Node2D = $ExtractGate


func _ready() -> void:
	# Listen so the demo prints visible feedback on extract.
	EventBus.haul_banked.connect(_on_haul_banked)
	EventBus.run_ended.connect(_on_run_ended)

	# Place the single gate at the fixed offset from spawn (player sits at origin).
	if _gate != null:
		_gate.position = GameState.GATE_SPAWN_OFFSET

	# Start a run and seed a couple of real catalog items into the bag.
	GameState.start_run(&"near", 4242)
	_seed_inventory()


func _seed_inventory() -> void:
	var cat: JunkCatalog = load(JUNK_CATALOG_PATH) as JunkCatalog
	if cat == null or cat.items.is_empty():
		push_warning("gate_test: junk catalog empty; nothing seeded.")
		return
	# Add the first two PLACEABLE catalog items so the bank has visible value.
	var added := 0
	for item in cat.items:
		if added >= 2:
			break
		if GameState.run_inventory.try_add(item):
			added += 1
	print("gate_test: seeded %d junk into run inventory; walk to the green gate and press interact." % added)


func _on_haul_banked(total_value: int) -> void:
	print("gate_test: HAUL BANKED — value=%d, banked_junk now holds %d items."
		% [total_value, GameState.banked_junk.size()])


func _on_run_ended(reason: StringName, duration_s: float, depth: int) -> void:
	print("gate_test: RUN ENDED — reason=%s duration=%.1fs depth=%d (run_inventory empty=%s)"
		% [reason, duration_s, depth,
			str(GameState.run_inventory == null or GameState.run_inventory.items.is_empty())])
