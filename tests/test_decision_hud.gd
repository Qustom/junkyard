extends SceneTree
## Headless verification for E2 — the push/cash-out DecisionHUD + ExtractPrompt.
##
## Proves the HUD is a PURE PROJECTION of the real autoload contract, signal-driven
## with no polling:
##   - Holding label tracks GameState.run_haul_value(), refreshed on run_inventory_changed,
##   - ClockBar value/max + ClockLabel track EventBus.dive_clock_changed(current, maximum),
##   - the clock-bar tint ramps green→amber→red as the fraction drains (distinct colours),
##   - DepthLabel tracks GameState.current_depth_index / max_depth_reached via
##     EventBus.depth_changed (J5 — was wrongly reading the band counter current_depth),
##   - the ExtractPrompt is hidden until the GATE is the focused interactable
##     (interactable_focused), shows the live haul value, and hides on unfocus —
##     while a non-gate (junk) focus never raises it.
## Run: godot --headless --script res://tests/test_decision_hud.gd
##
## Autoloads don't resolve as compile-time globals under --headless --script, so we
## reach them via the SceneTree root and run the body as a deferred coroutine that
## awaits process_frame after each tree mutation (same pattern as test_inventory_ui.gd).

const HUD_SCENE := "res://ui/hud/decision_hud.tscn"
const CATALOG_PATH := "res://data/junk/junk_catalog.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []

	var gs := root.get_node_or_null("GameState")
	var eb := root.get_node_or_null("EventBus")
	if gs == null or eb == null:
		printerr("E2 FAIL: GameState/EventBus autoload missing")
		quit(1)
		return

	var catalog: JunkCatalog = load(CATALOG_PATH)
	if catalog == null or catalog.items.is_empty():
		printerr("E2 FAIL: junk catalog missing or empty")
		quit(1)
		return

	var hud := (load(HUD_SCENE) as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame  # _ready + EventBus.connect

	var haul_label: Label = hud.get_node("Root/HaulValueLabel")
	var clock_bar: ProgressBar = hud.get_node("Root/ClockTopRight/ClockBar")
	var clock_label: Label = hud.get_node("Root/ClockTopRight/ClockLabel")
	var depth_label: Label = hud.get_node("Root/DepthLabel")
	var prompt: Control = hud.get_node("Root/ExtractPrompt")
	var prompt_label: Label = prompt.get_node("VBox/PromptLabel")

	# --- Clock projection: feed dive_clock_changed, assert bar + label + tint -----
	eb.dive_clock_changed.emit(60.0, 60.0)
	await process_frame
	if not is_equal_approx(clock_bar.max_value, 60.0) or not is_equal_approx(clock_bar.value, 60.0):
		failures.append("clock bar did not mirror dive_clock_changed(60,60): max=%s value=%s"
			% [clock_bar.max_value, clock_bar.value])
	if clock_label.text != tr("HUD_CLOCK_TIME").format({"seconds": "60"}):
		failures.append("clock label '%s' != expected full-clock text" % clock_label.text)
	var color_full: Color = clock_bar.modulate

	eb.dive_clock_changed.emit(6.0, 60.0)  # 10% remaining → red end of ramp
	await process_frame
	if not is_equal_approx(clock_bar.value, 6.0):
		failures.append("clock bar value did not update to 6.0 (got %s)" % clock_bar.value)
	var color_low: Color = clock_bar.modulate
	# Tint must visibly change green→red as it drains (redundant non-colour = the bar fill + Ns text).
	if color_full.is_equal_approx(color_low):
		failures.append("clock tint did not change between full and low (no urgency ramp)")
	if not (color_low.r > color_low.g):
		failures.append("low-clock tint is not red-dominant (r=%s g=%s)" % [color_low.r, color_low.g])

	# --- Haul projection: run + items, Holding tracks run_haul_value() ------------
	gs.start_run(&"near", 4242)
	await process_frame
	if haul_label.text != tr("HUD_HOLDING").format({"value": 0}):
		failures.append("empty-run Holding '%s' != Holding: 0" % haul_label.text)
	var inv: RunInventory = gs.run_inventory
	if inv == null:
		failures.append("start_run did not create run_inventory")
	else:
		var seeded := 0
		for item in catalog.items:
			if seeded >= 2:
				break
			if inv.try_add(item):  # fires run_inventory_changed → HUD refreshes haul
				seeded += 1
		await process_frame
		var expected: int = gs.run_haul_value()
		if expected <= 0:
			failures.append("seeded items produced non-positive haul value (%d)" % expected)
		if haul_label.text != tr("HUD_HOLDING").format({"value": expected}):
			failures.append("Holding '%s' != run_haul_value() %d" % [haul_label.text, expected])

	# --- Depth projection (J5): HUD tracks ROOM depth via depth_changed ------------
	# The run is already started (above) → entry is depth_index 0 / max 0. Descend by
	# calling set_current_depth, which emits depth_changed(idx, max); the HUD must follow.
	gs.set_current_depth(1, 1)  # room depth 1
	await process_frame
	gs.set_current_depth(3, 3)  # jump to room depth 3 (max climbs to 3)
	await process_frame
	var want_depth := tr("HUD_DEPTH").format({
		"depth": gs.current_depth_index,  # 3
		"max": gs.max_depth_reached,       # 3
	})
	if depth_label.text != want_depth:
		failures.append("Depth '%s' != depth_index/%d max/%d (J5: must track room depth, not band counter)"
			% [depth_label.text, gs.current_depth_index, gs.max_depth_reached])
	# Regression guard: the BAND counter must NOT be what's shown — band entry bumps
	# current_depth but leaves the room readout (current_depth_index) untouched.
	gs.enter_band(&"near")  # current_depth → 1 (band), room depth unchanged
	await process_frame
	if depth_label.text != want_depth:
		failures.append("Depth readout moved on band entry — J5 regression (still reading current_depth?)")

	# --- ExtractPrompt: hidden until the GATE is focused --------------------------
	if prompt.visible:
		failures.append("ExtractPrompt visible before any gate focus")

	# A non-gate focus (junk) must NOT raise the prompt.
	var junk_focus := Interactable.new()
	junk_focus.interactable_id = &"junk"
	root.add_child(junk_focus)
	eb.interactable_focused.emit(junk_focus)
	await process_frame
	if prompt.visible:
		failures.append("ExtractPrompt raised on a non-gate (junk) focus")
	eb.interactable_unfocused.emit(junk_focus)
	junk_focus.queue_free()

	# Gate focus raises it and shows the live haul value.
	var gate_focus := Interactable.new()
	gate_focus.interactable_id = &"gate"
	root.add_child(gate_focus)
	eb.interactable_focused.emit(gate_focus)
	await process_frame
	if not prompt.visible:
		failures.append("ExtractPrompt did not appear on gate focus")
	var want_prompt := tr("HUD_EXTRACT_PROMPT").format({"key": "E", "value": gs.run_haul_value()})
	if prompt_label.text != want_prompt:
		failures.append("prompt '%s' != expected '%s'" % [prompt_label.text, want_prompt])

	# Unfocus hides it.
	eb.interactable_unfocused.emit(gate_focus)
	await process_frame
	if prompt.visible:
		failures.append("ExtractPrompt still visible after gate unfocus")
	gate_focus.queue_free()

	# --- Cleanup so we leave no run residue for sibling harnesses -----------------
	gs.end_run(&"abandon", 0.0)

	if failures.is_empty():
		print("DECISION HUD OK — E2 verified (Holding tracks run_haul_value, clock bar/label/tint "
			+ "mirror dive_clock_changed, depth tracks current_depth_index/max_depth_reached via "
			+ "depth_changed, extract prompt gate-only + live value).")
		quit(0)
	else:
		for f in failures:
			printerr("E2 FAIL: ", f)
		quit(1)
