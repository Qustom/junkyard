extends Control
## TelemetrySettingsPanel — minimal greybox opt-in UI for telemetry (G1).
##
## Per the M1 greybox norm this is a stubbed-inline Control (no asset-role
## subagent, no .tscn dependency): it builds its own children in _ready(). A
## proper settings screen + styling is a post-M1 ui-ux-designer task; this exists
## so the opt-in is reachable and the consent copy + log-folder discoverability
## (the #1 friction point for non-technical testers returning JSONL) are present.
##
## Wiring: the checkbox calls Telemetry.set_enabled() (which persists via Settings
## and applies live). Initial state reflects the persisted Settings flag.

const SettingsScript := preload("res://systems/settings/settings.gd")

const CONSENT_COPY := "Logs anonymous gameplay events (run length, depth, junk values, money in) to a local file. No personal data. Off by default. Disabling stops future logging; it does not delete past logs."


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = "Telemetry (opt-in)"
	vbox.add_child(title)

	var check := CheckBox.new()
	check.text = "Enable anonymous telemetry"
	check.button_pressed = SettingsScript.get_telemetry_enabled()
	check.toggled.connect(_on_toggled)
	vbox.add_child(check)

	var copy := Label.new()
	copy.text = CONSENT_COPY
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(copy)

	var path_label := Label.new()
	path_label.text = "Log folder: %s" % ProjectSettings.globalize_path("user://telemetry/")
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_label.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(path_label)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	var copy_btn := Button.new()
	copy_btn.text = "Copy path"
	copy_btn.pressed.connect(_on_copy_path)
	buttons.add_child(copy_btn)

	var open_btn := Button.new()
	open_btn.text = "Open log folder"
	open_btn.pressed.connect(_on_open_folder)
	buttons.add_child(open_btn)


func _on_toggled(pressed: bool) -> void:
	var tel := get_node_or_null("/root/Telemetry")
	if tel != null:
		tel.set_enabled(pressed)
	else:
		# Telemetry autoload absent (e.g. isolated UI test) — persist directly.
		SettingsScript.set_telemetry_enabled(pressed)


func _on_copy_path() -> void:
	DisplayServer.clipboard_set(ProjectSettings.globalize_path("user://telemetry/"))


func _on_open_folder() -> void:
	# Ensure the dir exists so the OS file browser opens something real.
	DirAccess.make_dir_recursive_absolute("user://telemetry/")
	OS.shell_open(ProjectSettings.globalize_path("user://telemetry/"))
