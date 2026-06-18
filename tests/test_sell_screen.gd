extends SceneTree
## Headless verification for F2 — the placeholder Sell Screen (reward beat).
##
## Proves the SellScreen is PURE PRESENTATION over F1's logic, driven by the real
## EventBus.run_ended(reason, duration_s, depth) contract:
##   - on run_ended(&"extract") with a known banked set: the screen presents, calls
##     GameState.sell_banked_junk (bank emptied, Money credited by the EXACT sum),
##     renders one row per item, subtotal == sum, MoneyTotalLabel reflects live money,
##     title is "EXTRACTED";
##   - on run_ended(&"timeout"): title is the RUN-LOST variant and the sell source is
##     tagged &"pockets" (Telemetry currency-in-by-source);
##   - a zero-haul extract presents with an empty list + subtotal 0 without erroring.
## Run: godot --headless --script res://tests/test_sell_screen.gd
##
## Autoloads don't resolve as compile-time globals under --headless --script, so we
## reach them via the SceneTree root and run the body as a deferred coroutine that
## awaits process_frame after each tree mutation (same pattern as test_decision_hud.gd).
## The tally duration is forced to 0 so the count-up finishes synchronously and we can
## assert the final live total without waiting on frames.

const SCREEN_SCENE := "res://ui/sell/sell_screen.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _make_item(id: StringName, value: int, name: String) -> JunkItem:
	var it := JunkItem.new()
	it.id = id
	it.display_name = name
	it.slot_size = 1
	it.base_sell_value = value
	it.containment_flags = JunkItem.ContainmentFlag.PLACEABLE
	return it


func _run() -> void:
	var failures: Array[String] = []

	var gs := root.get_node_or_null("GameState")
	var eb := root.get_node_or_null("EventBus")
	if gs == null or eb == null:
		printerr("F2 FAIL: GameState/EventBus autoload missing")
		quit(1)
		return

	# Track the sell source tag (Telemetry currency-in-by-source) via currency_changed.
	var last_money_source: Array = [&""]
	eb.currency_changed.connect(func(kind: StringName, _delta: int, source: StringName) -> void:
		if kind == &"money":
			last_money_source[0] = source)

	var screen := (load(SCREEN_SCENE) as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame  # _ready + EventBus.connect
	screen.tally_duration = 0.0  # finish the count-up synchronously for assertions

	var title: Label = screen.get_node("CenterContainer/Panel/Margin/VBox/Title")
	var item_list: VBoxContainer = screen.get_node("CenterContainer/Panel/Margin/VBox/ItemList")
	var subtotal: Label = screen.get_node("CenterContainer/Panel/Margin/VBox/SubtotalLabel")
	var money_total: Label = screen.get_node("CenterContainer/Panel/Margin/VBox/MoneyTotalLabel")
	var continue_btn: Button = screen.get_node("CenterContainer/Panel/Margin/VBox/ContinueButton")

	var empty: Array[JunkItem] = []

	# === Case 1: clean EXTRACT with a known banked set ======================
	gs.money = 100
	gs.banked_junk = empty.duplicate()
	gs.banked_junk.append(_make_item(&"j_a", 30, "Alpha"))
	gs.banked_junk.append(_make_item(&"j_b", 20, "Bravo"))
	gs.banked_junk.append(_make_item(&"j_c", 10, "Charlie"))   # sum = 60
	last_money_source[0] = &""

	eb.run_ended.emit(&"extract", 27.5, 2)
	await process_frame

	if not screen.visible:
		failures.append("Case1 screen not visible after run_ended(&\"extract\")")
	if gs.banked_junk.size() != 0:
		failures.append("Case1 bank not emptied by sell_banked_junk (%d left)" % gs.banked_junk.size())
	if gs.money != 160:
		failures.append("Case1 money %d, expected 160 (100 + 60)" % gs.money)
	if last_money_source[0] != &"extract":
		failures.append("Case1 sell source == %s, expected &\"extract\"" % str(last_money_source[0]))
	# One row per sold item.
	var rows: int = item_list.get_child_count()
	if rows != 3:
		failures.append("Case1 ItemList has %d rows, expected 3" % rows)
	if title.text != tr("SELL_TITLE_EXTRACT"):
		failures.append("Case1 title '%s' != EXTRACTED" % title.text)
	if subtotal.text != tr("SELL_SUBTOTAL").format({"value": 60}):
		failures.append("Case1 subtotal '%s' != haul 60" % subtotal.text)
	# MoneyTotalLabel reflects LIVE GameState.money (the persistence acceptance).
	if money_total.text != tr("SELL_MONEY_TOTAL").format({"value": gs.money}):
		failures.append("Case1 money label '%s' != live GameState.money %d" % [money_total.text, gs.money])
	# Tally with duration 0 finishes immediately → Continue interactable.
	if continue_btn.disabled:
		failures.append("Case1 Continue still disabled after a zero-duration tally")

	# Reset the screen back to hidden via its Continue path for the next case.
	screen._on_continue_pressed()
	await process_frame

	# === Case 2: RUN LOST (timeout) — title variant + &"pockets" source =====
	gs.money = 200
	gs.banked_junk = empty.duplicate()
	gs.banked_junk.append(_make_item(&"p_x", 7, "PocketX"))
	last_money_source[0] = &""

	eb.run_ended.emit(&"timeout", 30.0, 1)
	await process_frame

	if not screen.visible:
		failures.append("Case2 screen not visible after run_ended(&\"timeout\")")
	if last_money_source[0] != &"pockets":
		failures.append("Case2 sell source == %s, expected &\"pockets\"" % str(last_money_source[0]))
	# "RUN LOST — kept N", N = item count sold (1).
	if title.text != tr("SELL_TITLE_LOST").format({"count": 1}):
		failures.append("Case2 title '%s' != RUN-LOST kept 1 variant" % title.text)
	if gs.money != 207:
		failures.append("Case2 money %d, expected 207 (200 + 7)" % gs.money)

	screen._on_continue_pressed()
	await process_frame

	# === Case 3: zero-haul extract presents without error ===================
	gs.money = 500
	gs.banked_junk = empty.duplicate()   # nothing banked
	last_money_source[0] = &""

	eb.run_ended.emit(&"extract", 5.0, 0)
	await process_frame

	if not screen.visible:
		failures.append("Case3 zero-haul extract did not present the screen")
	if gs.money != 500:
		failures.append("Case3 zero-haul changed money %d -> %d (should be unchanged)" % [500, gs.money])
	if subtotal.text != tr("SELL_SUBTOTAL").format({"value": 0}):
		failures.append("Case3 zero-haul subtotal '%s' != 0" % subtotal.text)
	# Empty list degrades to a single "nothing" placeholder row (never an error).
	if item_list.get_child_count() != 1:
		failures.append("Case3 zero-haul ItemList has %d rows, expected 1 placeholder" % item_list.get_child_count())
	if money_total.text != tr("SELL_MONEY_TOTAL").format({"value": 500}):
		failures.append("Case3 money label '%s' != live 500" % money_total.text)
	if continue_btn.disabled:
		failures.append("Case3 Continue disabled after zero-haul (should be interactable)")

	screen._on_continue_pressed()
	await process_frame

	# --- Cleanup: leave no meta residue for sibling harnesses ---------------
	gs.money = 0
	gs.banked_junk = empty.duplicate()

	if failures.is_empty():
		print("SELL SCREEN OK")
		quit(0)
	else:
		for f in failures:
			printerr("F2 FAIL: ", f)
		quit(1)
