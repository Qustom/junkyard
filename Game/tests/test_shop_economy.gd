extends Node
## M3 (M1.6): headless shop-economy test. Exercises the GameState buy economy + the
## ShopCatalog data + the persist round-trip — the structural half of M3 (the *felt* UX is
## human-deferred). Asserts:
##   1. The catalog loads with 3 persistent greybox items at the locked costs.
##   2. purchase() debits Money, records the id, emits item_purchased, and the spend persists
##      (save/reload survives) — the meta-spend loop closes.
##   3. The reject paths (unaffordable, already-owned, negative price) emit purchase_failed,
##      mutate NOTHING, and return false.
##   4. owns() reflects ownership; a roguelite wipe_meta() clears owned_items.
##   5. sell_banked_junk(&"shop") credits the held haul to Money (the SELL-tab path).
##
## Run as a SCENE (autoloads resolve as globals): godot --headless res://tests/test_shop_economy.tscn

const CATALOG_PATH := "res://data/shop/shop_catalog.tres"
const TEST_SLOT := 9101


func _ready() -> void:
	get_tree().quit(_run())


func _run() -> int:
	var failures: Array[String] = []
	var gs := get_node_or_null("/root/GameState")
	var save := get_node_or_null("/root/SaveManager")
	if gs == null or save == null:
		printerr("SHOP FAIL: GameState/SaveManager autoload missing")
		return 1

	# Clean meta slate.
	gs.money = 0
	gs.owned_items = [] as Array[StringName]
	gs.banked_junk = [] as Array[JunkItem]

	# --- 1. Catalog shape -----------------------------------------------------
	var catalog: ShopCatalog = load(CATALOG_PATH) as ShopCatalog
	if catalog == null:
		printerr("SHOP FAIL: catalog missing at %s" % CATALOG_PATH)
		return 1
	if catalog.items.size() != 3:
		failures.append("catalog has %d items, expected 3" % catalog.items.size())
	var expected := {
		&"scrap_magnet": 100,
		&"lucky_charm": 150,
		&"reinforced_bag": 250,
	}
	for item in catalog.items:
		if item == null:
			failures.append("catalog has a null item")
			continue
		if not expected.has(item.id):
			failures.append("unexpected catalog id %s" % item.id)
		elif item.cost != expected[item.id]:
			failures.append("%s cost %d != expected %d" % [item.id, item.cost, expected[item.id]])
		if not item.persistent:
			failures.append("%s should be persistent in M1.6" % item.id)
		if item.effect_kind != &"none":
			failures.append("%s effect_kind should be &\"none\" (greybox stub)" % item.id)

	# --- 2. Buy debits, records, persists ------------------------------------
	var purchased_events: Array = []
	var failed_events: Array = []
	var on_purchased := func(id: StringName, price: int, money: int) -> void:
		purchased_events.append([id, price, money])
	var on_failed := func(id: StringName, price: int, money: int) -> void:
		failed_events.append([id, price, money])
	EventBus.item_purchased.connect(on_purchased)
	EventBus.purchase_failed.connect(on_failed)

	gs.money = 300
	var ok1: bool = gs.purchase(&"scrap_magnet", 100)
	if not ok1:
		failures.append("purchase(scrap_magnet, 100) returned false with $300")
	if gs.money != 200:
		failures.append("after buy, money %d != 200" % gs.money)
	if not gs.owns(&"scrap_magnet"):
		failures.append("owns(scrap_magnet) false after buy")
	if purchased_events.size() != 1:
		failures.append("expected 1 item_purchased event, got %d" % purchased_events.size())

	# Persist round-trip: save, scribble, reload → ownership + money survive.
	save.save_meta(TEST_SLOT)
	gs.owned_items = [] as Array[StringName]
	gs.money = 0
	save.load_meta(TEST_SLOT)
	if gs.money != 200:
		failures.append("persist: money %d != 200 after reload" % gs.money)
	if not gs.owns(&"scrap_magnet"):
		failures.append("persist: owns(scrap_magnet) lost after reload")

	# --- 3. Reject paths ------------------------------------------------------
	failed_events.clear()
	# already owned
	var owned_again: bool = gs.purchase(&"scrap_magnet", 100)
	if owned_again:
		failures.append("re-buying an owned item returned true")
	# unaffordable (money 200, cost 250)
	var poor: bool = gs.purchase(&"reinforced_bag", 250)
	if poor:
		failures.append("buying unaffordable item returned true")
	# negative price
	var neg: bool = gs.purchase(&"junk", -5)
	if neg:
		failures.append("negative-price purchase returned true")
	if failed_events.size() != 3:
		failures.append("expected 3 purchase_failed events, got %d" % failed_events.size())
	if gs.money != 200:
		failures.append("reject paths mutated money (now %d, expected 200)" % gs.money)

	# --- 4. Wipe clears owned_items ------------------------------------------
	gs.wipe_meta()
	if gs.owns(&"scrap_magnet"):
		failures.append("wipe_meta did not clear owned_items")
	if gs.owned_items.size() != 0:
		failures.append("wipe_meta left %d owned_items" % gs.owned_items.size())

	# --- 5. SELL-tab path: sell held haul → Money ----------------------------
	var bolt: JunkItem = JunkItem.new()
	bolt.id = &"test_bolt"
	bolt.display_name = "Test Bolt"
	bolt.base_sell_value = 42
	var held: Array[JunkItem] = [bolt]
	gs.banked_junk = held
	gs.money = 0
	gs.sell_banked_junk(&"shop")
	if gs.money != 42:
		failures.append("sell_banked_junk(&shop) credited %d, expected 42" % gs.money)
	if gs.banked_junk.size() != 0:
		failures.append("sell did not empty the held bank (%d left)" % gs.banked_junk.size())

	# Cleanup.
	EventBus.item_purchased.disconnect(on_purchased)
	EventBus.purchase_failed.disconnect(on_failed)
	_clean_slot(save, TEST_SLOT)
	gs.money = 0
	gs.owned_items = [] as Array[StringName]
	gs.banked_junk = [] as Array[JunkItem]

	if failures.is_empty():
		print("SHOP ECONOMY OK — 3-item persistent catalog (scrap_magnet/lucky_charm/reinforced_bag), purchase() debits+records+persists, reject paths inert (owned/unaffordable/negative), wipe clears owned_items, SELL-tab sell_banked_junk(&shop) credits the held haul.")
		return 0
	for f in failures:
		printerr("SHOP FAIL: ", f)
	return 1


func _clean_slot(save: Node, slot: int) -> void:
	var dir: String = save.slot_dir(slot)
	var meta: String = dir + "/meta.sav"
	for p in [meta, meta + ".bak", meta + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	if DirAccess.dir_exists_absolute(dir):
		DirAccess.remove_absolute(dir)
