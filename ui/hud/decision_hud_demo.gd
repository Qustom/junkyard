extends Node
## DecisionHUD demo driver (E2) — a runnable, eyeball-able harness for the decision
## surface WITHOUT needing the full dive scene. It instances the DecisionHUD and then
## drives the real EventBus/GameState contract with fake data:
##   - starts a run and seeds a couple of catalog JunkItems so "Holding: N" reads,
##   - drains a fake clock (dive_clock_changed) so the bar ramps green→amber→red and
##     the Holding label pulses under the urgency threshold,
##   - press SPACE (ui_select) to toggle the gate's ExtractPrompt on/off so you can
##     see the explicit "Press E to Extract with N" call-to-action,
##   - press ENTER (ui_accept) to add another item and watch Holding climb.
##
## Run: godot ui/hud/decision_hud_demo.tscn   (GUI). Not part of CI.

const CATALOG_PATH := "res://data/junk/junk_catalog.tres"
const CLOCK_MAX := 60.0

var _clock: float = CLOCK_MAX
var _gate_focused: bool = false
var _gate := Interactable.new()
var _catalog: JunkCatalog
var _next_item: int = 0


func _ready() -> void:
	_gate.interactable_id = &"gate"
	add_child(_gate)
	_catalog = load(CATALOG_PATH) as JunkCatalog

	GameState.start_run(&"near", 4242)
	GameState.enter_band(&"near")
	_add_item()
	_add_item()
	EventBus.dive_clock_changed.emit(_clock, CLOCK_MAX)


func _process(delta: float) -> void:
	# Fake clock drain so the ramp + urgency pulse are visible. Loops at zero.
	_clock -= delta * 1.0
	if _clock <= 0.0:
		_clock = CLOCK_MAX
	EventBus.dive_clock_changed.emit(_clock, CLOCK_MAX)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select"):  # SPACE — toggle gate focus
		_gate_focused = not _gate_focused
		if _gate_focused:
			EventBus.interactable_focused.emit(_gate)
		else:
			EventBus.interactable_unfocused.emit(_gate)
	elif event.is_action_pressed("ui_accept"):  # ENTER — grab another item
		_add_item()


func _add_item() -> void:
	if _catalog == null or _catalog.items.is_empty() or GameState.run_inventory == null:
		return
	var item: JunkItem = _catalog.items[_next_item % _catalog.items.size()]
	GameState.run_inventory.try_add(item)
	_next_item += 1
