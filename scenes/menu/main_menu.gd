class_name MainMenu
extends Control
## MainMenu (M1.6 · M1) — the app's front door and the home of the New/Continue
## distinction. Greybox default-theme Control; the visual pass is a human's.
##
## ORCHESTRATION ONLY (run/meta boundary, signal-driven decoupling, TDD §2): this
## node owns no game-state truth. It reads SaveManager.has_save() to gate Continue,
## drives the New/Continue meta entry points on GameState/SaveManager, re-homes the
## G6 telemetry-consent modal, and hands off to the Hub via the M0 App router. It
## NEVER starts a dive (the Hub's departure portal owns dive_requested — M2).

## G6: first-run telemetry consent prompt, re-homed from main_game (Director-ratified).
const ConsentPromptScript := preload("res://systems/settings/telemetry_consent_prompt.gd")

## The single save slot M1.6 uses (matches game_state.gd's SaveManager.save_meta(0)
## calls; multi-slot is a later milestone — OQ 4).
const SAVE_SLOT: int = 0

## Menu strings live in their own CSV (OQ 7). It is imported to a .translation but is
## NOT (yet) registered in project.godot's locale/translations (M0 owns that file).
## We self-register at runtime so tr("MENU_*") resolves regardless — idempotent, and
## a no-op once M0 adds the registration line. See the worklog's coordination flag.
const STRINGS_TRANSLATION := "res://scenes/menu/menu_strings.en.translation"

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _version_label: Label = %VersionLabel
@onready var _title_label: Label = %Title

## G6: true while the first-run consent modal is up; the menu buttons are disabled
## until it's answered (belt-and-braces over the prompt's own input-blocking backdrop).
var _consent_pending: bool = false


func _ready() -> void:
	_ensure_strings_registered()

	_title_label.text = tr("MENU_TITLE")
	_new_game_button.text = tr("MENU_NEW_GAME")
	_settings_button.text = tr("MENU_SETTINGS")
	_quit_button.text = tr("MENU_QUIT")
	_version_label.text = tr("MENU_VERSION").format({"id": BuildVersion.id()})

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_refresh_continue_state()       # save-exists gating (no polling; re-run on return-to-menu)
	_maybe_hide_quit_on_web()       # OQ 8

	# Focus the most likely action: Continue if there's a save, else New Game.
	if _continue_button.disabled:
		_new_game_button.grab_focus()
	else:
		_continue_button.grab_focus()

	# G6 first-run consent — re-homed from main_game (_maybe_show_consent_prompt).
	_maybe_show_consent_prompt()


## Self-register the menu strings translation so tr("MENU_*") resolves even though the
## CSV isn't (yet) in project.godot's locale/translations (M0 owns that file). Loading
## the same .translation twice would stack duplicates, so guard on a sentinel key: if
## tr() already resolves it (M0 registered it, or we did), do nothing.
func _ensure_strings_registered() -> void:
	if tr("MENU_NEW_GAME") != "MENU_NEW_GAME":
		return   # already resolving
	if not ResourceLoader.exists(STRINGS_TRANSLATION):
		return   # import hasn't produced the .translation yet — tr() falls back to the key
	var t := load(STRINGS_TRANSLATION) as Translation
	if t != null:
		TranslationServer.add_translation(t)


# --- Continue (load save) -----------------------------------------------------

## Continue is offered ONLY when a meta.sav exists for the slot. Redundant non-colour
## channel: disabled => greyed AND the button text reads "Continue — no save yet" (OQ 3).
func _refresh_continue_state() -> void:
	var has := SaveManager.has_save(SAVE_SLOT)        # save_manager.gd:35
	_continue_button.disabled = not has
	_continue_button.text = tr("MENU_CONTINUE") if has else tr("MENU_CONTINUE_NONE")


func _on_continue_pressed() -> void:
	if _consent_pending:
		return                                         # G6 modal up → ignore
	if not SaveManager.has_save(SAVE_SLOT):            # guard a stale-state double-click
		return
	SaveManager.load_meta(SAVE_SLOT)                   # → GameState.from_meta_dict (money/quota/banked_junk)
	_route_to_hub()


# --- New Game (fresh meta) ----------------------------------------------------

## New Game ensures meta is at construction defaults, then routes to the Hub. Over an
## existing save it WIPES (with a confirm — OQ 1, LOCKED). With no save, "fresh" is
## already true (GameState boots all-zero), so it's a straight route.
func _on_new_game_pressed() -> void:
	if _consent_pending:
		return
	if SaveManager.has_save(SAVE_SLOT):
		_confirm_overwrite_then_new()                  # modal confirm before destroying a save
	else:
		_start_fresh_and_route()


func _start_fresh_and_route() -> void:
	# A brand-new profile is already at defaults; an overwrite path has just wiped via
	# GameState.wipe_meta() (which atomic-persists a clean meta.sav). Either way the meta
	# is clean, so a later Continue resumes the fresh game, not the destroyed one. The
	# first quota-enabled start_run lazy-seeds the bar — New Game seeds nothing.
	_route_to_hub()


## Inline greybox confirm. OK/Cancel text is set explicitly via tr() (don't rely on the
## engine locale, OQ 1 refinement), and the dialog is exclusive so a click-through can't
## fire New Game twice. On confirm: GameState.wipe_meta() then route; on cancel: dismiss.
func _confirm_overwrite_then_new() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.exclusive = true
	dialog.dialog_text = tr("MENU_NEWGAME_CONFIRM")
	dialog.ok_button_text = tr("MENU_NEWGAME_CONFIRM_OK")
	dialog.cancel_button_text = tr("MENU_CANCEL")
	dialog.confirmed.connect(func() -> void:
		GameState.wipe_meta()                          # game_state.gd:410 — fresh meta + atomic persist + meta_wiped
		_refresh_continue_state()                      # (Continue now points at the fresh slot)
		_start_fresh_and_route())
	# Free the dialog after either outcome so it doesn't linger as a hidden child.
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


# --- Settings (STUB — OQ 2: honest "coming soon" placeholder) -----------------

## M1.6 ships a Settings BUTTON, not a panel. The locked floor (OQ 2-a) is an honest
## greybox "coming soon" modal — TelemetrySettingsPanel is not instanced anywhere, has
## no modal framing, and uses raw strings, so surfacing it now is real new UI deferred
## to M5. Built inline like the confirm dialog; OK text via tr().
func _on_settings_pressed() -> void:
	if _consent_pending:
		return
	var dialog := AcceptDialog.new()
	dialog.exclusive = true
	dialog.dialog_text = tr("MENU_SETTINGS_SOON")
	dialog.ok_button_text = tr("MENU_OK")
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


# --- Quit ---------------------------------------------------------------------

func _on_quit_pressed() -> void:
	if _consent_pending:
		return
	get_tree().quit()                                  # desktop; hidden on web (OQ 8)


func _maybe_hide_quit_on_web() -> void:
	# On HTML5 there's no app to quit; hide Quit so the menu doesn't offer a dead action (OQ 8).
	if OS.has_feature("web"):
		_quit_button.hide()


# --- M0 router handoff (R-a: App.goto_hub via the app_router group) ------------

## The ONE place the menu leaves for the Hub. M0 ships a persistent root App router
## (scenes/app/app.gd) discoverable via the &"app_router" group; it exposes goto_hub()
## (R-a in M1_main_menu.md, OQ 6 LOCKED). The menu never starts a dive — the Hub's
## departure portal (M2) owns dive_requested.
func _route_to_hub() -> void:
	var router: Node = get_tree().get_first_node_in_group(&"app_router")
	if router != null and router.has_method(&"goto_hub"):
		router.goto_hub()
	else:
		push_warning("MainMenu: no app_router in tree; cannot route to Hub.")


# --- G6 first-run telemetry consent (re-homed verbatim from main_game) --------

## Show the consent modal exactly once (first launch / never-asked profile). Blocks the
## menu buttons until answered; after any answer it never re-shows. Identical contract to
## main_game.gd's _maybe_show_consent_prompt — only the host scene changed.
func _maybe_show_consent_prompt() -> void:
	if not ConsentPromptScript.should_show():          # telemetry_consent_prompt.gd:39 (static)
		return
	_consent_pending = true
	_set_buttons_disabled(true)
	var prompt: TelemetryConsentPrompt = ConsentPromptScript.new()
	prompt.choice_made.connect(_on_consent_choice)
	add_child(prompt)                                  # sits at MODAL_LAYER=100 over the menu


func _on_consent_choice(_enabled: bool) -> void:
	_consent_pending = false
	_set_buttons_disabled(false)
	_refresh_continue_state()                          # restore Continue's gated state (not blanket-enable)
	if _continue_button.disabled:
		_new_game_button.grab_focus()
	else:
		_continue_button.grab_focus()


func _set_buttons_disabled(d: bool) -> void:
	_new_game_button.disabled = d
	_settings_button.disabled = d
	_quit_button.disabled = d
	# Continue is special: when re-enabling, restore its SAVE-GATED state, not blanket-enable.
	_continue_button.disabled = d if d else not SaveManager.has_save(SAVE_SLOT)
