class_name JunkPickup
extends Area2D
## JunkPickup — one piece of salvageable junk in the world (C2).
##
## The integration capstone of the loop's first half: B3 PLANS where junk goes
## (JunkPlacer) → C2's JunkSpawner INSTANTIATES one of these per plan entry →
## the player walks up and grabs it (A2 interaction) → D1's RunInventory decides
## accept/reject → a junk_picked_up telemetry event fires either way.
##
## Composition (A2 contract): this Area2D owns a greybox renderer and an
## Interactable child on the `interactable` layer (bit 3). It does NOT detect the
## player — the player's InteractionDetector sees the Interactable child and
## emits EventBus.interaction_requested(id, target). This node listens for that
## request and, when the id is &"junk" AND it is the focused target, performs the
## pickup. This mirrors ExtractGate exactly (the gate is the reference pattern).
##
## Accept/reject (capacity tension made physical, C2 + D1 + D2 share one truth):
##   - accepted → the item is in the bag; the pickup queue_free()s (leaves world).
##   - rejected (bag full / no fit) → the pickup STAYS in the world and flashes
##     red. D2's panel flips to "BAG FULL" off the SAME D1 predicate
##     (is_full()/can_accept()); we add no second source of truth.

## The kind of junk this pickup holds. Set by setup() from B3's depth-scaled
## duplicate (base_sell_value is already final/scaled when it arrives here).
var item: JunkItem

## Cached so the handler reads the child's id without re-fetching each interact.
var _interactable_id: StringName = &"junk"

@onready var _greybox: Node2D = $Greybox
@onready var _interactable: Interactable = $Interactable

## Reject-flash state (red pulse on a full-bag interact; junk stays in the world).
var _flashing: bool = false
var _flash_t: float = 0.0
const _FLASH_DURATION := 0.35  # seconds the red pulse lasts


func _ready() -> void:
	if _interactable != null:
		_interactable_id = _interactable.interactable_id
	# A2 contract: the detector announces the request; we (the owner) act on it.
	EventBus.interaction_requested.connect(_on_interaction_requested)
	# Greybox draws from item data; queue an initial paint.
	if _greybox != null:
		_greybox.connect("draw", _draw_greybox.bind(_greybox))
		_greybox.queue_redraw()


## Initialize from a JunkItem. Stores the item and repaints the greybox from its
## color/shape. Called by JunkSpawner.spawn_one() right after instantiation.
func setup(p_item: JunkItem) -> void:
	item = p_item
	if _greybox == null:
		_greybox = get_node_or_null("Greybox")
	if _greybox != null:
		_greybox.queue_redraw()


## A2 contract (copied structure from ExtractGate): act only on our own id, and
## only when WE are the focused target (the detector always passes the focused
## Interactable, whose parent is this node).
func _on_interaction_requested(id: StringName, target: Node) -> void:
	if id != _interactable_id:
		return
	if target != null and target.get_parent() != self:
		return
	_try_pickup()


## Hand the accept/reject decision to D1 (via GameState run-state) and fire the
## telemetry event with a SNAPSHOT of value/slot_size. Only leaves the world on
## accept; a full bag flashes and leaves the junk behind.
func _try_pickup() -> void:
	if item == null:
		return
	# D1 run_inventory can be null between runs (run/meta boundary) — guard it.
	var inv: RunInventory = GameState.run_inventory
	var accepted: bool = false
	if inv != null:
		accepted = inv.try_add(item)

	EventBus.junk_picked_up.emit(item.id, item.base_sell_value, item.slot_size, global_position, accepted)

	if accepted:
		queue_free()
	else:
		_flash_rejected()


## Reject feedback: a short red pulse on the greybox; the junk stays grabbable.
func _flash_rejected() -> void:
	_flashing = true
	_flash_t = _FLASH_DURATION
	set_process(true)
	if _greybox != null:
		_greybox.queue_redraw()


func _process(delta: float) -> void:
	if not _flashing:
		set_process(false)
		return
	_flash_t -= delta
	if _flash_t <= 0.0:
		_flashing = false
		set_process(false)
	if _greybox != null:
		_greybox.queue_redraw()


## Renders the greybox shape from the item's data. Bound to the Greybox child's
## `draw` signal so the shape is data-driven (no sprite asset in M1). During a
## reject flash the fill blends toward red so the rejection reads as feedback.
func _draw_greybox(canvas: Node2D) -> void:
	if item == null:
		return
	var col: Color = item.greybox_color
	if _flashing:
		# Pulse intensity rides the remaining flash time (1 at start → 0 at end).
		var k: float = clampf(_flash_t / _FLASH_DURATION, 0.0, 1.0)
		col = col.lerp(Color(1.0, 0.15, 0.15, 1.0), 0.5 + 0.5 * k)
	var r := 10.0  # greybox half-extent (px)
	match item.greybox_shape:
		JunkItem.GreyboxShape.CIRCLE:
			canvas.draw_circle(Vector2.ZERO, r, col)
		JunkItem.GreyboxShape.TRIANGLE:
			var tri := PackedVector2Array([
				Vector2(0, -r), Vector2(r, r), Vector2(-r, r)])
			canvas.draw_colored_polygon(tri, col)
		JunkItem.GreyboxShape.DIAMOND:
			var dia := PackedVector2Array([
				Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
			canvas.draw_colored_polygon(dia, col)
		_:  # RECT (default)
			canvas.draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), col)
