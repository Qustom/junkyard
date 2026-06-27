extends Node
## Headless smoke test for the M1.6 M0 App router (scenes/app/app.gd/.tscn).
##
## Runs as a SCENE (test_app_router.tscn) so the EventBus/GameState autoloads resolve
## via the live SceneTree (project memory: verify tests run as SCENES, not --script;
## never two godot --headless instances concurrently).
##   godot --headless res://tests/test_app_router.tscn
##
## Asserts the M0 router contract (RD-1/RD-2/RD-8):
##   - app.tscn boots and the router reports current_state == &"menu";
##   - the StateHost holds exactly ONE state scene (the menu) after boot;
##   - the Menu→Hub handoff (router.goto_hub()) puts current_state == &"hub" + emits hub_entered;
##   - dive_requested(&"near") swaps to the dive (current_state == &"dive");
##   - a dive run_ended auto-returns to the Hub (deferred) → current_state == &"hub" + returned_to_hub;
##   - current_state reads correctly throughout (the M4-readable accessor).

const APP_SCENE := "res://scenes/app/app.tscn"

var _hub_entered_count: int = 0
var _returned_to_hub_reason: StringName = &""
var _returned_to_hub_count: int = 0


func _ready() -> void:
	get_tree().quit(await _run())


func _run() -> int:
	var failures: Array[String] = []

	EventBus.hub_entered.connect(func() -> void: _hub_entered_count += 1)
	EventBus.returned_to_hub.connect(func(reason: StringName) -> void:
		_returned_to_hub_count += 1
		_returned_to_hub_reason = reason)

	# --- Boot the router -----------------------------------------------------
	var packed := load(APP_SCENE) as PackedScene
	if packed == null:
		printerr("ROUTER FAIL: could not load %s" % APP_SCENE)
		return 1
	var app: Node = packed.instantiate()
	add_child(app)            # _ready runs → boots to the menu state
	await get_tree().process_frame

	# --- Case 1: boots to the menu state -------------------------------------
	if app.current_state != &"menu":
		failures.append("after boot current_state == %s, expected &\"menu\"" % app.current_state)
	var state_host: Node = app.get_node_or_null("StateHost")
	if state_host == null:
		failures.append("App has no StateHost child")
	elif state_host.get_child_count() != 1:
		failures.append("StateHost holds %d children after boot, expected 1 (the menu)" % state_host.get_child_count())
	if app.get_node_or_null("DebugOverlay") == null:
		failures.append("App has no persistent DebugOverlay CanvasLayer mount")

	# --- Case 2: Menu → Hub (router.goto_hub) --------------------------------
	var hub_entered_before: int = _hub_entered_count
	app.goto_hub()
	await get_tree().process_frame
	if app.current_state != &"hub":
		failures.append("after goto_hub current_state == %s, expected &\"hub\"" % app.current_state)
	if _hub_entered_count <= hub_entered_before:
		failures.append("goto_hub did not emit hub_entered")
	if state_host != null and state_host.get_child_count() != 1:
		failures.append("StateHost holds %d children in Hub, expected 1" % state_host.get_child_count())

	# --- Case 3: Hub → Dive (dive_requested) ---------------------------------
	EventBus.dive_requested.emit(&"near")
	# The dive scene (main_game) self-starts a run on _ready; give it a few frames to
	# instance + settle. We only assert the ROUTER state, not the dive's internals.
	await get_tree().process_frame
	await get_tree().process_frame
	if app.current_state != &"dive":
		failures.append("after dive_requested current_state == %s, expected &\"dive\"" % app.current_state)

	# --- Case 4: Dive end → auto-return to Hub (deferred) --------------------
	var returned_before: int = _returned_to_hub_count
	# Emit run_ended as the dive would on extract/death/timeout; the router auto-returns
	# (deferred one frame). reason rides along on returned_to_hub.
	EventBus.run_ended.emit(&"extract", 1.0, 0)
	await get_tree().process_frame   # let the deferred _return_after_dive run
	await get_tree().process_frame
	if app.current_state != &"hub":
		failures.append("after run_ended current_state == %s, expected &\"hub\" (auto-return)" % app.current_state)
	if _returned_to_hub_count <= returned_before:
		failures.append("run_ended did not emit returned_to_hub")
	elif _returned_to_hub_reason != &"extract":
		failures.append("returned_to_hub reason == %s, expected &\"extract\"" % _returned_to_hub_reason)

	# --- Verdict -------------------------------------------------------------
	if failures.is_empty():
		print("ROUTER OK — App router boots → menu → hub → dive → hub; current_state correct")
		return 0
	for f in failures:
		printerr("ROUTER FAIL: ", f)
	return 1
