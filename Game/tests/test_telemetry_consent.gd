extends Node
## Headless verification for G6 — first-run telemetry consent prompt.
##
## Runs as a SCENE (not --script) so the EventBus / GameState / Telemetry autoloads
## resolve as live nodes, per M1_As_Built "Testing constraints (headless)":
##   godot --headless res://tests/test_telemetry_consent.tscn
##
## Asserts the show-once consent contract:
##   (a) Fresh profile (asked-flag cleared) → the prompt WOULD show / asked starts false.
##   (b) Enable sets enabled=true AND asked=true, and a subsequent telemetry emission
##       writes user://telemetry/run_log.jsonl.
##   (c) Not now leaves enabled=false AND asked=true, and NO file is written.
##   (d) Once asked=true the prompt does NOT re-show.
##
## The prompt's choice logic is exercised directly via TelemetryConsentPrompt (its
## _resolve does the same Settings/Telemetry calls the buttons fire), and the static
## should_show() gate is asserted across states.

const SettingsScript := preload("res://systems/settings/settings.gd")
const ConsentPromptScript := preload("res://systems/settings/telemetry_consent_prompt.gd")

const LOG_PATH := "user://telemetry/run_log.jsonl"


func _ready() -> void:
	get_tree().quit(await _run())


func _run() -> int:
	var failures: Array[String] = []

	var bus := get_node_or_null("/root/EventBus")
	var tel := get_node_or_null("/root/Telemetry")
	if bus == null or tel == null:
		printerr("CONSENT FAIL: EventBus or Telemetry autoload missing")
		return 1

	# --- (a) Fresh profile → prompt would show, asked starts false -----------
	_reset_profile(tel)
	if SettingsScript.get_telemetry_asked():
		failures.append("(a) fresh profile: asked-flag should start false")
	if not ConsentPromptScript.should_show():
		failures.append("(a) fresh profile: should_show() should be true when never asked")
	if SettingsScript.get_telemetry_enabled():
		failures.append("(a) fresh profile: telemetry should default OFF")

	# --- (b) Enable → enabled=true AND asked=true; an emission writes the log -
	_reset_profile(tel)
	_remove_log()
	var enable_prompt: TelemetryConsentPrompt = ConsentPromptScript.new()
	add_child(enable_prompt)
	await get_tree().process_frame
	var enable_choice: Array = []
	enable_prompt.choice_made.connect(func(v: bool) -> void: enable_choice.append(v))
	enable_prompt._on_enable()
	await get_tree().process_frame
	if enable_choice != [true]:
		failures.append("(b) Enable: choice_made should emit true once, got %s" % str(enable_choice))
	if not SettingsScript.get_telemetry_enabled():
		failures.append("(b) Enable: persisted enabled should be true")
	if not SettingsScript.get_telemetry_asked():
		failures.append("(b) Enable: asked-flag should be true")
	if not tel.is_enabled():
		failures.append("(b) Enable: live Telemetry should be enabled")
	# A subsequent emission must now write the JSONL log.
	bus.run_started.emit(&"surface", 991122)
	bus.run_ended.emit(&"extract", 12.0, 1)
	tel.set_enabled(false)  # flush+close so the file is on disk
	if not FileAccess.file_exists(LOG_PATH):
		failures.append("(b) Enable: telemetry emission did not write %s" % LOG_PATH)

	# --- (c) Not now → enabled stays false AND asked=true; NO file written ----
	_reset_profile(tel)
	_remove_log()
	var decline_prompt: TelemetryConsentPrompt = ConsentPromptScript.new()
	add_child(decline_prompt)
	await get_tree().process_frame
	var decline_choice: Array = []
	decline_prompt.choice_made.connect(func(v: bool) -> void: decline_choice.append(v))
	decline_prompt._on_decline()
	await get_tree().process_frame
	if decline_choice != [false]:
		failures.append("(c) Not now: choice_made should emit false once, got %s" % str(decline_choice))
	if SettingsScript.get_telemetry_enabled():
		failures.append("(c) Not now: telemetry should remain OFF")
	if not SettingsScript.get_telemetry_asked():
		failures.append("(c) Not now: asked-flag should be true")
	if tel.is_enabled():
		failures.append("(c) Not now: live Telemetry should be disabled")
	# An emission while declined must write nothing.
	bus.run_started.emit(&"surface", 334455)
	bus.run_ended.emit(&"extract", 9.0, 1)
	if FileAccess.file_exists(LOG_PATH):
		failures.append("(c) Not now: a telemetry file was written while declined")

	# --- (d) Once asked=true the prompt does not re-show ---------------------
	# State after (c): asked=true. should_show() must now be false regardless of choice.
	if ConsentPromptScript.should_show():
		failures.append("(d) after a choice, should_show() must be false (no re-show)")

	# Cleanup: leave the profile at the safe default (OFF, not-asked) + no log.
	_reset_profile(tel)
	_remove_log()

	if failures.is_empty():
		print("CONSENT OK — fresh profile prompts (asked=false); Enable sets enabled+asked and a later emission wrote run_log.jsonl; Not now leaves telemetry OFF + asked with no file; once asked the prompt never re-shows.")
		return 0
	for f in failures:
		printerr("CONSENT FAIL: ", f)
	return 1


## Reset the profile to a never-asked, telemetry-OFF state and sync the live autoload.
func _reset_profile(tel: Node) -> void:
	tel.set_enabled(false)
	SettingsScript.set_telemetry_enabled(false)
	SettingsScript.set_telemetry_asked(false)


func _remove_log() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(LOG_PATH)
