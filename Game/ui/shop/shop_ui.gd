class_name ShopUI
extends CanvasLayer
## ShopUI (M1.6 M3) — the Hub shop's SELL + BUY screen. Greybox Control over the M0
## economy API; owns NO Money truth and NO save (mirrors the retired SellScreen's "pure
## presentation" contract). It only:
##   SELL tab — shows the HELD banked haul (count + summed base_sell_value) and a "Sell all"
##     button that calls GameState.sell_banked_junk(&"shop") ONCE (credits Money + saves +
##     re-evaluates the quota, which the Hub-return beat already ran → a safe NO-OP re-eval
##     via the _quota_evaluated_this_run idempotency guard). Re-homes SellScreen R1/R2/R3.
##   BUY tab — lists the ShopCatalog; each cell's [Buy] calls GameState.purchase(id, cost)
##     (Money-gated; disabled when unaffordable OR already owned). Owned persistent items
##     grey out. A failed purchase flashes a transient label (M0's purchase_failed). RD-2/RD-8.
##   Quota-MISS echo — reads GameState.last_quota_result(); on a MISS shows the player-facing
##     "QUOTA MISSED — progress wiped" notice (W2-F2). The wipe itself fired on the guaranteed
##     Hub-return beat (hub.gd / evaluate_quota_on_return); the Shop only SURFACES it.
##
## Opened by the Shop interactable (scenes/hub/shop.gd) on interact; closed with the Close
## button or the ui_cancel action. Emits EventBus.shop_opened / shop_closed for telemetry.
## Greybox only — default theme, plain containers, ColorRect cells. A human owns the polish.

const CATALOG_PATH := "res://data/shop/shop_catalog.tres"
const SELL_SOURCE := &"shop"

var _catalog: ShopCatalog
var _flash_until_ms: int = 0

@onready var _root: Control = %Root
@onready var _money_label: Label = %MoneyLabel
@onready var _quota_notice: Label = %QuotaNotice
@onready var _flash_label: Label = %FlashLabel
@onready var _close_button: Button = %CloseButton
# SELL tab
@onready var _sell_list: VBoxContainer = %SellList
@onready var _sell_total_label: Label = %SellTotalLabel
@onready var _sell_button: Button = %SellButton
# BUY tab
@onready var _buy_list: VBoxContainer = %BuyList


func _ready() -> void:
	# Run while the (hub) tree is unpaused — the hub is a non-dive scene, nothing to pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	hide()
	_catalog = load(CATALOG_PATH) as ShopCatalog
	if _catalog == null:
		push_warning("ShopUI: catalog missing at %s; BUY tab will be empty." % CATALOG_PATH)
	_close_button.pressed.connect(close)
	_sell_button.pressed.connect(_on_sell_pressed)
	# Repaint the money header + buy gating whenever Money moves (sale, purchase, wipe).
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.item_purchased.connect(_on_item_purchased)
	EventBus.purchase_failed.connect(_on_purchase_failed)


## Open the shop: refresh every tab off live meta and reveal. Called by the Shop interactable.
func open() -> void:
	_build_buy_tab()       # build once per open (catalog is static; owned-state refreshes below)
	_refresh_all()
	_flash_label.text = ""
	show()
	if _sell_button != null:
		_sell_button.grab_focus()
	EventBus.shop_opened.emit()


## Close the shop and hand control back to the Hub.
func close() -> void:
	hide()
	EventBus.shop_closed.emit()


func _refresh_all() -> void:
	_refresh_money()
	_refresh_sell_tab()
	_refresh_buy_gating()
	_refresh_quota_notice()


# --- Money header -------------------------------------------------------------
func _refresh_money() -> void:
	_money_label.text = "Money: $%d" % GameState.money


func _on_currency_changed(_kind: StringName, _delta: int, _source: StringName) -> void:
	if not visible:
		return
	_refresh_money()
	_refresh_buy_gating()


# --- SELL tab -----------------------------------------------------------------
## R2/R3: render one row per held junk item ({name, value}) + the summed haul value.
## Pure read over the held banked_junk meta (the same per-item math sell_banked_junk uses).
func _refresh_sell_tab() -> void:
	for child in _sell_list.get_children():
		child.queue_free()
	var total: int = 0
	var count: int = 0
	for item in GameState.banked_junk:
		if item == null:
			continue
		count += 1
		total += item.base_sell_value
		var row := Label.new()
		row.text = "%s    $%d" % [item.display_name, item.base_sell_value]
		_sell_list.add_child(row)
	if count == 0:
		var empty_row := Label.new()
		empty_row.text = "(nothing to sell)"
		_sell_list.add_child(empty_row)
	_sell_total_label.text = "Held haul: %d items  ~$%d" % [count, total]
	_sell_button.disabled = (count == 0)


## R1: the cash-out. ONE sell_banked_junk(&"shop") call — it credits Money, saves, and
## re-evaluates the quota (a NO-OP re-eval since the Hub-return beat already ran it). After
## it returns the bank is empty and Money is already updated + saved.
func _on_sell_pressed() -> void:
	var count_before: int = 0
	var value_before: int = 0
	for item in GameState.banked_junk:
		if item != null:
			count_before += 1
			value_before += item.base_sell_value
	if count_before == 0:
		return
	GameState.sell_banked_junk(SELL_SOURCE)
	# Roll-up telemetry (one emit per sale, matching the single sell call).
	EventBus.item_sold.emit(count_before, value_before, GameState.money)
	_refresh_all()


# --- BUY tab ------------------------------------------------------------------
## Build one cell per catalog item: a greybox swatch, the name + cost, and a [Buy] button.
## Cells are rebuilt each open; per-cell enabled state refreshes via _refresh_buy_gating.
var _buy_buttons: Dictionary = {}   # item_id (StringName) -> Button

func _build_buy_tab() -> void:
	for child in _buy_list.get_children():
		child.queue_free()
	_buy_buttons.clear()
	if _catalog == null:
		return
	for item in _catalog.items:
		if item == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(24, 24)
		swatch.color = item.greybox_color
		row.add_child(swatch)

		var label := Label.new()
		label.text = "%s    $%d" % [item.display_name, item.cost]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var buy := Button.new()
		buy.text = "Buy"
		var captured_id: StringName = item.id
		var captured_cost: int = item.cost
		buy.pressed.connect(func() -> void: _on_buy_pressed(captured_id, captured_cost))
		row.add_child(buy)
		_buy_buttons[item.id] = buy

		_buy_list.add_child(row)
	_refresh_buy_gating()


## RD-8: gate each [Buy] — disabled when already owned (greyed "Owned") OR unaffordable.
func _refresh_buy_gating() -> void:
	if _catalog == null:
		return
	for item in _catalog.items:
		if item == null:
			continue
		var buy: Button = _buy_buttons.get(item.id, null)
		if buy == null:
			continue
		if GameState.owns(item.id):
			buy.text = "Owned"
			buy.disabled = true
		elif GameState.money < item.cost:
			buy.text = "Buy"
			buy.disabled = true
		else:
			buy.text = "Buy"
			buy.disabled = false


## RD-2: the UI does the owned/affordability gate, then calls the catalog-agnostic
## GameState.purchase(id, cost). purchase() also re-checks (belt-and-braces) and emits
## item_purchased / purchase_failed, which drive the repaint + flash below.
func _on_buy_pressed(item_id: StringName, cost: int) -> void:
	GameState.purchase(item_id, cost)


func _on_item_purchased(_item_id: StringName, _price: int, _money: int) -> void:
	if not visible:
		return
	_flash("Purchased!")
	_refresh_money()
	_refresh_buy_gating()


func _on_purchase_failed(item_id: StringName, _price: int, _money: int) -> void:
	if not visible:
		return
	if GameState.owns(item_id):
		_flash("Owned")
	else:
		_flash("Not enough Money")
	_refresh_buy_gating()


# --- Quota-MISS notice (W2-F2) ------------------------------------------------
## Surface the roguelite wipe to the player. The wipe already fired on the guaranteed
## Hub-return beat (hub.gd:_resolve_return_quota → wipe_meta); the Shop only DISPLAYS it,
## reading the cached last_quota_result(). A checked MISS shows the notice; anything else
## (met / quota-off / fresh boot) hides it.
func _refresh_quota_notice() -> void:
	var q: Dictionary = GameState.last_quota_result()
	if bool(q.get("checked", false)) and not bool(q.get("met", true)):
		_quota_notice.text = "QUOTA MISSED — progress wiped"
		_quota_notice.visible = true
	else:
		_quota_notice.visible = false


# --- Transient flash ----------------------------------------------------------
func _flash(msg: String) -> void:
	_flash_label.text = msg
	_flash_until_ms = Time.get_ticks_msec() + 1200
	set_process(true)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _flash_until_ms:
		_flash_label.text = ""
		set_process(false)


# --- Close on cancel ----------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
