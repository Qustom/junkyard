class_name SellScreen
extends CanvasLayer
## SellScreen (F2) — the M1 reward beat that visibly CLOSES the core loop.
## PURE PRESENTATION over F1's logic: it owns no Money, touches no save. It listens
## for the one run-end signal, asks F1 to cash out the bank, then DISPLAYS the
## per-item payoff and the persistent running total.
##
## Reconciled to As-Built (NOT a design change): the F2 spec sketch listened to an
## idealized `run_end(cause, payload)` signal that does not exist. The real signal
## is EventBus.run_ended(reason, duration_s, depth_reached) — fixed-arity, no payload.
## We switch on `reason`.
##
## Present-on-ALL-THREE-causes is the ratified decision (E3 + F2 Open-question #1):
##   &"extract"          → title "EXTRACTED"
##   &"death" / &"timeout" → title "RUN LOST — kept N" (N = item count sold)
## The conversion path is identical for all three — one sell_banked_junk() call. The
## only difference is the source tag (Telemetry currency-in-by-source) and the title.
##
## Ordering (matches F1's save-before-animate contract): capture money_before, call
## GameState.sell_banked_junk(source) ONCE (it credits Money + saves synchronously
## BEFORE returning), then animate a count-up *toward* the already-updated, already-
## saved GameState.money. Quitting mid-animation keeps the Money — the tween is pure
## flourish. The total label always reads LIVE GameState.money, never a run-local sum
## (the "persists across runs" acceptance).
##
## Greybox only: default theme, plain containers, no art. A human owns the visual pass.
## All player-facing strings go through tr() against ui/sell/sell_strings.csv.

## Emitted when the player presses Continue (after the tally has finished/skipped).
## The PRODUCTION SellScreen is decoupled from the run-start/overworld loop (G3 owns
## that): it only announces intent. The demo scene wires this to a minimal restart.
signal continue_pressed

## RG1 (M1.1, §8 Q2): emitted when the Director presses "Back to Config". Like
## continue_pressed it only announces intent — MainGame subscribes and re-shows the
## menu/ConfigMenu instead of looping straight into a fresh dive, so the Director can
## switch configs mid-session without quitting. Continue remains the quick re-run path.
signal back_to_config_pressed

## Full count-up duration. Kept short (spec Open-question #2: ~0.6–0.8s) so repeat-run
## testers are never gated by animation; ANY input snaps it to completion immediately.
@export var tally_duration: float = 0.7

@onready var _backdrop: ColorRect = %Backdrop
@onready var _title_label: Label = %Title
@onready var _item_list: VBoxContainer = %ItemList
@onready var _subtotal_label: Label = %SubtotalLabel
@onready var _money_total_label: Label = %MoneyTotalLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _back_to_config_button: Button = %BackToConfigButton
# DLV2: web-only telemetry export. Hidden on desktop (the on-disk retrieval flow is
# unchanged there); on web it downloads user://telemetry/run_log.jsonl to the browser.
@onready var _export_telemetry_button: Button = %ExportTelemetryButton
@onready var _export_status_label: Label = %ExportStatusLabel

# Count-up animation state. We drive the roll-up manually from _process rather than
# a Tween: the screen runs while the tree is paused, and Godot 4 has a standing
# regression where Tween.TWEEN_PAUSE_PROCESS does not reliably tick on a paused tree
# (godotengine/godot#81994, #67504). A manual lerp on a PROCESS_MODE_ALWAYS node is
# functionally identical (the spec only asks for a count-up; "a Tween is enough" but
# not required) and side-steps the regression entirely.
var _tallying: bool = false
var _tally_elapsed: float = 0.0
var _tally_from: int = 0
var _tally_to: int = 0


func _ready() -> void:
	# This CanvasLayer + its children run while the tree is paused (we pause the dive
	# behind us) — set in the scene via process_mode = Always on the root. Guard here
	# too in case the script is attached to a hand-built node.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)  # only tick during a tally
	hide()
	_continue_button.pressed.connect(_on_continue_pressed)
	_back_to_config_button.pressed.connect(_on_back_to_config_pressed)
	_setup_export_control()
	EventBus.run_ended.connect(_on_run_ended)


# --- DLV2: web telemetry export ----------------------------------------------

## Web-platform guard: the export control only exists on a web build, where the
## telemetry log lives in the browser's IndexedDB-backed VFS and can't be retrieved
## by the desktop "zip the app-data dir" flow. On desktop we hide it entirely (and
## skip wiring its signal) so DLV2 is fully inert off-web.
func _setup_export_control() -> void:
	if not TelemetryExporter.is_supported():
		_export_telemetry_button.hide()
		_export_status_label.hide()
		return
	_export_telemetry_button.text = tr("SELL_EXPORT_TELEMETRY")
	_export_status_label.text = ""
	_export_telemetry_button.pressed.connect(_on_export_telemetry_pressed)


## Called only on web (the signal is connected only there). Reads the existing JSONL
## log and hands it to the browser as a download — pure read, no schema/arity change.
## download_buffer must run inside this user gesture or the browser blocks it.
func _on_export_telemetry_pressed() -> void:
	if not TelemetryExporter.has_log():
		_export_status_label.text = tr("SELL_EXPORT_EMPTY")
		return
	var filename := TelemetryExporter.download_filename()
	if TelemetryExporter.export():
		_export_status_label.text = tr("SELL_EXPORT_DONE").format({"name": filename})
	else:
		_export_status_label.text = tr("SELL_EXPORT_EMPTY")


# --- Run-end entry point ------------------------------------------------------

func _on_run_ended(reason: StringName, _duration_s: float, _depth_reached: int) -> void:
	# Ratified: present on extract AND death/timeout. The conversion path is identical;
	# only the source tag and the title differ.
	var source: StringName = &"extract" if reason == &"extract" else &"pockets"
	_present(reason, source)


## Drive the whole beat: pause, show, cash out via F1 (ONCE), render, animate.
func _present(reason: StringName, source: StringName) -> void:
	get_tree().paused = true
	show()

	# F1 does the conversion + persistence; returns what was sold. After this call the
	# bank is empty and GameState.money is already credited AND saved.
	var money_before: int = GameState.money
	var breakdown: Array[Dictionary] = GameState.sell_banked_junk(source)
	var money_after: int = GameState.money            # live, post-sale, persistent total
	var subtotal: int = money_after - money_before    # what THIS haul was worth

	_render_rows(breakdown)
	_render_title(reason, breakdown.size())

	# Continue (and Back to Config) are locked until the tally completes/skips so the
	# reward beat lands.
	_continue_button.disabled = true
	_back_to_config_button.disabled = true
	_animate_tally(subtotal, money_before, money_after)


# --- Rendering ----------------------------------------------------------------

func _render_title(reason: StringName, sold_count: int) -> void:
	if reason == &"extract":
		_title_label.text = tr("SELL_TITLE_EXTRACT")
	else:
		# "RUN LOST — kept N" — N is the count of items that survived into pockets.
		_title_label.text = tr("SELL_TITLE_LOST").format({"count": sold_count})


func _render_rows(breakdown: Array[Dictionary]) -> void:
	for child in _item_list.get_children():
		child.queue_free()
	# Drive rows from the returned array (not a separate query). Empty / breakdown-less
	# payload (zero-haul extract, empty-pockets fail) degrades to one "nothing" row —
	# never an error.
	if breakdown.is_empty():
		var empty_row := Label.new()
		empty_row.text = tr("SELL_EMPTY")
		_item_list.add_child(empty_row)
		return
	for entry in breakdown:
		var row := Label.new()
		# Guard each field so a malformed entry can't crash the reward screen.
		var item_name: String = String(entry.get("name", "?"))
		var value: int = int(entry.get("value", 0))
		row.text = tr("SELL_ROW").format({"name": item_name, "value": value})
		_item_list.add_child(row)


# --- Tally animation ----------------------------------------------------------

## Roll the persistent total up from before → after, and reveal the subtotal. Money
## is ALREADY saved before this runs; the roll-up is pure flourish. Kept under
## tally_duration; any input snaps it to completion via _skip_tally().
func _animate_tally(subtotal: int, money_before: int, money_after: int) -> void:
	_subtotal_label.text = tr("SELL_SUBTOTAL").format({"value": subtotal})
	# Seed the total at its pre-sale value so the count-up reads as a gain.
	_set_money_label(money_before)

	if money_after == money_before or tally_duration <= 0.0:
		# Zero-haul (or no animation): nothing to roll. The total is already correct
		# and persistent.
		_finish_tally()
		return

	_tally_from = money_before
	_tally_to = money_after
	_tally_elapsed = 0.0
	_tallying = true
	set_process(true)


func _process(delta: float) -> void:
	# Runs only during a tally (set_process toggled). The node is PROCESS_MODE_ALWAYS
	# so this ticks while the tree is paused — robust against the Tween-pause regression.
	if not _tallying:
		set_process(false)
		return
	_tally_elapsed += delta
	var t: float = clampf(_tally_elapsed / tally_duration, 0.0, 1.0)
	var v: int = int(round(lerpf(float(_tally_from), float(_tally_to), t)))
	_set_money_label(v)
	if t >= 1.0:
		_finish_tally()


func _set_money_label(v: int) -> void:
	_money_total_label.text = tr("SELL_MONEY_TOTAL").format({"value": v})


## Snap the running total to its final (already-saved) value and unlock Continue.
func _finish_tally() -> void:
	_tallying = false
	set_process(false)
	# Always paint the final live value — never trust the last interpolated frame.
	_set_money_label(GameState.money)
	_continue_button.disabled = false
	_back_to_config_button.disabled = false
	_continue_button.grab_focus()


## Any input while the tally is running snaps it to completion (repeat-run testers are
## never gated). After it has finished this is inert. Uses _input so it fires while paused.
func _input(event: InputEvent) -> void:
	if not visible or not _tallying:
		return
	if event is InputEventMouseButton and event.pressed:
		_skip_tally()
	elif event is InputEventKey and event.pressed and not event.echo:
		_skip_tally()


func _skip_tally() -> void:
	_finish_tally()
	get_viewport().set_input_as_handled()


# --- Continue -----------------------------------------------------------------

## Continue unpauses, hides, and announces intent via `continue_pressed`. The
## production SellScreen does NOT own the restart — the future G3 run-start/overworld
## loop subscribes and decides where to go. (The demo scene wires a minimal restart.)
func _on_continue_pressed() -> void:
	get_tree().paused = false
	hide()
	continue_pressed.emit()


## RG1 (§8 Q2): the switch-config path. Unpauses + hides like Continue, but announces
## back_to_config_pressed so MainGame re-shows the menu instead of looping into a fresh
## dive. The next Start (door 1) re-reads the menu's config; Continue (door 2) is unused
## on this path. Decoupled identically to Continue — the SellScreen owns no navigation.
func _on_back_to_config_pressed() -> void:
	get_tree().paused = false
	hide()
	back_to_config_pressed.emit()
