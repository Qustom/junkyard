class_name TelemetryConsentPrompt
extends CanvasLayer
## TelemetryConsentPrompt (G6) — first-run, in-build telemetry consent modal.
##
## Why this exists (wave-5 close-out deviation G3 #1, Director disposition: Addressed):
## the G3 greybox build shipped with NO in-build consent prompt — only a README note +
## the existing settings toggle. Testers skip the README, so the G4 fun-gate cohort
## would return empty telemetry and wreck the gate. This is the first-run nudge that
## actually surfaces the opt-in, while keeping telemetry opt-in / default OFF.
##
## Greybox norm: a stubbed-inline modal (no asset-role subagent, no .tscn, no PixelLab)
## that builds its own children in _ready(). It is a blocking modal over a dim backdrop
## with two choices:
##   * Enable   → Telemetry.set_enabled(true)  (persists enabled=true, applies live)
##   * Not now  → leave telemetry OFF (no telemetry write)
## EITHER choice sets the asked-flag true so the prompt shows exactly once.
##
## Consent wording is the single source of truth shared with the settings panel:
## TelemetrySettingsPanel.CONSENT_COPY. The settings toggle remains the way to change
## the choice later; this is purely the first-run nudge.
##
## Wiring is decoupled: it emits `choice_made(enabled)` after handling the choice; the
## host (MainGame) connects that to unblock gameplay start. The prompt does the Settings
## /Telemetry calls itself so the host needs no telemetry knowledge.

signal choice_made(enabled: bool)

const SettingsScript := preload("res://systems/settings/settings.gd")
const PanelScript := preload("res://systems/settings/telemetry_settings_panel.gd")

# High layer so the modal sits above the menu CanvasLayer and the world.
const MODAL_LAYER := 100

var _decided: bool = false


## Should the first-run prompt show? True only when the player has never been asked.
## Static so the host can gate without instancing the prompt.
static func should_show() -> bool:
	return not SettingsScript.get_telemetry_asked()


func _ready() -> void:
	layer = MODAL_LAYER
	_build_ui()


func _build_ui() -> void:
	# Dim, input-blocking backdrop so the modal is truly modal (clicks behind it die).
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Help improve THE FAR YARD?"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	# Single source of consent wording, shared with the settings panel.
	var copy := Label.new()
	copy.text = PanelScript.CONSENT_COPY
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size = Vector2(400, 0)
	vbox.add_child(copy)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)

	# "Not now" is the privacy-preserving default; place it first (left), focus it
	# so a player who just presses Enter/Space does NOT silently opt in.
	var decline_btn := Button.new()
	decline_btn.text = "Not now"
	decline_btn.custom_minimum_size = Vector2(120, 40)
	decline_btn.pressed.connect(_on_decline)
	buttons.add_child(decline_btn)

	var enable_btn := Button.new()
	enable_btn.text = "Enable"
	enable_btn.custom_minimum_size = Vector2(120, 40)
	enable_btn.pressed.connect(_on_enable)
	buttons.add_child(enable_btn)

	decline_btn.grab_focus()


func _on_enable() -> void:
	_resolve(true)


func _on_decline() -> void:
	_resolve(false)


## Apply the choice exactly once: enabling persists+applies telemetry; either way the
## asked-flag is set so the prompt never reappears. Emits choice_made then self-frees.
func _resolve(enabled: bool) -> void:
	if _decided:
		return
	_decided = true

	if enabled:
		var tel := get_node_or_null("/root/Telemetry")
		if tel != null:
			# set_enabled persists enabled=true via Settings AND applies live.
			tel.set_enabled(true)
		else:
			# Telemetry autoload absent (isolated UI test) — persist directly.
			SettingsScript.set_telemetry_enabled(true)
	# "Not now": do NOT enable telemetry; leave it OFF (default). No telemetry write.

	# EITHER choice records that we've asked, so this shows exactly once.
	SettingsScript.set_telemetry_asked(true)

	choice_made.emit(enabled)
	queue_free()
