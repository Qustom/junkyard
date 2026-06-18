extends Node
## F2 demo harness — lets a human eyeball the reward beat without a live dive.
##
## Banks a couple of real catalog JunkItems into GameState.banked_junk, then fakes a
## run-end by emitting EventBus.run_ended(...). The SellScreen (a sibling in this
## scene) cashes them out via F1 and shows the count-up. Two buttons fake the two
## variants: a clean EXTRACT and a RUN-LOST (timeout) ending.
##
## This is a DEMO-ONLY restart wiring: SellScreen.continue_pressed routes back here,
## which simply re-arms the buttons. The production SellScreen stays decoupled — the
## real run-start/overworld loop (G3) owns where Continue actually goes.

const CATALOG_PATH := "res://data/junk/junk_catalog.tres"

@onready var _sell_screen: SellScreen = $SellScreen
@onready var _extract_btn: Button = %ExtractButton
@onready var _lost_btn: Button = %LostButton
@onready var _info: Label = %InfoLabel


func _ready() -> void:
	_extract_btn.pressed.connect(_on_extract_pressed)
	_lost_btn.pressed.connect(_on_lost_pressed)
	_sell_screen.continue_pressed.connect(_on_continue)
	_refresh_info()


func _on_extract_pressed() -> void:
	_bank_demo_haul(3)
	# E1's clean extract: cause &"extract" → title "EXTRACTED", source &"extract".
	EventBus.run_ended.emit(&"extract", 27.5, 2)


func _on_lost_pressed() -> void:
	# Fake "kept pockets": bank a smaller surviving subset, then a failed-run end.
	_bank_demo_haul(1)
	# E3 timeout: cause &"timeout" → title "RUN LOST — kept N", source &"pockets".
	EventBus.run_ended.emit(&"timeout", 30.0, 1)


## Push `count` catalog items into the meta bank so the sell screen has something to
## cash out (a stand-in for E1/E3 having banked them).
func _bank_demo_haul(count: int) -> void:
	var catalog: JunkCatalog = load(CATALOG_PATH) as JunkCatalog
	if catalog == null or catalog.items.is_empty():
		push_warning("F2 demo: junk catalog missing; nothing to bank.")
		return
	var banked: int = 0
	for item in catalog.items:
		if item == null:
			continue
		GameState.banked_junk.append(item)
		banked += 1
		if banked >= count:
			break


func _on_continue() -> void:
	# Demo restart stub: the loop is back to "ready to dive again". A real build would
	# hand off to G3's run-start here.
	_refresh_info()


func _refresh_info() -> void:
	_info.text = "Money: %d   Bank: %d items\nClick a button to fake a run-end." % [
		GameState.money, GameState.banked_junk.size()]
