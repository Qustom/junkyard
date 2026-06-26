# M1 — Main menu scene

**Milestone:** M1.6 (Surface & Staging), **Wave 2 — Surface scenes (parallel worktrees, file-disjoint)**.
**Role(s):** `ui-ux-designer` (UX/IA/readability + the `Control` tree) + `general-purpose` (the `.gd` wiring:
router handoff, save-exists gating, New/Continue meta entry points, the re-homed G6 modal). One shared worklog.
**Type:** New scene + entry-point swap. **UI/meta only — touches NO generation** → the all-off `RunConfig`
fingerprint (`e943ac9c8bc1`) and the 89-knob count are **out of scope and must not move** (M1 writes only
`scenes/menu/*` — see breakdown §4: "Writes only `scenes/menu/*` — file-disjoint from M2/M4").
**BlockedBy:** **M0** (the foundation pass: the scene/flow **router**, the `run/main_scene` swap to
`main_menu.tscn`, the `dive_requested`/`hub_entered` EventBus signals, and the `project.godot` edits — M1.6
breakdown §3/§4/§5). M1 **routes into the Hub via the M0 router**; it does not own the router file or
`project.godot`.

**Definition of done (per the breakdown M1 row + the UI/UX playbook):**
- New `scenes/menu/main_menu.tscn` (+ `main_menu.gd`) is the **app entry** (`run/main_scene`, repointed by M0).
- Greybox default-theme `Control` (no authored art, no PixelLab) with **New Game / Continue / Quit** and a
  **Settings** *stub* button; a **version label** (`BuildVersion.id()`).
- **Continue is disabled when no save exists** (`SaveManager.has_save(0)`), enabled + loads otherwise.
- **New Game** starts a fresh-meta session and **routes into the Hub** via the M0 router.
- The **first-run G6 telemetry-consent modal is re-homed here** from `main_game` (shown over the menu, blocks
  Start-equivalent input until answered), reusing the existing `TelemetryConsentPrompt` verbatim.
- **All player-facing strings go through `tr()`** (the playbook's "externalize all strings"); a **clickable
  HTML mockup of the menu states is approved before engine work** (playbook workflow 2).
- Headless `--import` + `tools/ci_smoke_test.gd` still green (the entry-scene swap is M0's; M1 must not break
  the boot — confirm the smoke test doesn't hard-assume `main_game` is the entry, breakdown §6 last bullet).

---

## (a) Research on the premise — why a real Main Menu now, and what it builds on

### Why now (the one thing M1.6 must prove)
M1.6's thesis (breakdown §1) is that the game still **boots straight into a debug harness**: today the very
first thing a player sees is the `main_game` scene with a **Start button bolted onto the config rail** and the
knob menu in their face. M1.6 gives the game a *surface* — **boot to a real Main Menu → stage in a walkable
Hub → depart into dives**. This task (M1) is the **front door**: the screen that makes THE FAR YARD read as a
game rather than a test bench, and the home of the **New / Continue** distinction that every later meta system
(debt, upgrades, save slots) needs. It is deliberately small and greybox — the *information architecture* and
the *flow* are the deliverable; the *look* goes to a human later (playbook: "Defers final visual look/icons/
polish to a human").

### What exists in-repo it re-homes (the current `main_game`-embedded menu)
Today's "menu" is a **`MainMenu` CanvasLayer inside the dive scene** (`scenes/game/main_game.tscn:42-93`):

```
[node name="MainMenu" type="CanvasLayer" parent="."]            # main_game.tscn:42
  Backdrop  (ColorRect, full-rect, Color(0.07,0.08,0.1,1))      # :44-50
  ConfigMenu (instance, %ConfigMenu)                             # :52-53  ← M4 moves this to a P-overlay; NOT M1's
  Center/VBox:
    TitleLabel  "THE FAR YARD"  (font_size 40, centered)         # :67-71
    HintLabel   "WASD move · E interact/extract · K debug-kill"  # :73-77
    StartButton "START RUN"  (%StartButton, 220×48)              # :79-83
  VersionLabel (%VersionLabel, bottom-right, build <id>)         # :85-93
```

The `.gd` side (`scenes/game/main_game.gd`) shows exactly the seams M1 inherits:
- `_ready()` (`:151`) sets `_version_label.text = "build %s" % BuildVersion.id()` — **the version label pattern
  M1 copies** (`systems/version.gd:43` `BuildVersion.id()` → e.g. `m1-20260626-<sha>`).
- `_start_button.pressed.connect(_on_start_pressed)` (`:152`) → `_on_start_pressed()` (`:1276`) → `start_new_run()`.
  In M1.6 this single "Start" splits into **New Game** + **Continue**, and the destination changes from
  "start a dive in this scene" to "**route to the Hub**" (the Hub then owns the depart-to-dive portal — M2).
- `_show_menu()` / `_hide_menu()` (`:1314-1320`) just toggle `_menu.visible`. In M1 the menu is its **own
  top-level scene**, so "hide the menu" becomes "the router swaps to the Hub scene" (no visibility toggle).
- The **G6 first-run consent** is wired here (`:41`, `:139-140`, `:166-169`, `:1291-1311`): `_maybe_show_consent_prompt()`
  runs after `_show_menu()`, instances a `TelemetryConsentPrompt`, and **blocks Start** (`_consent_pending` +
  `_start_button.disabled = true`) until `choice_made` fires. **M1 re-homes this whole block** onto the Main
  Menu (breakdown M1 row: "first-run telemetry-consent modal (G6) re-homed here from `main_game`").

> **Seam note (coordinate with M2):** when M2 refactors `main_game.tscn` to **dive-only** (breakdown §4), it
> **strips the `MainMenu` CanvasLayer, the Start button, and the G6 consent wiring** out of `main_game`. M1
> *re-creates* New/Continue/Quit + G6 as a standalone scene; M2 *deletes* the old embedded copy. The two are
> file-disjoint (M1 writes `scenes/menu/*`; M2 edits `scenes/game/main_game.*`) but must agree that **G6 lives
> on the Menu now** and the old `_maybe_show_consent_prompt()` path is removed by M2. This doc treats the G6
> re-home as M1's deliverable and flags the deletion as M2's (Open Question 5).

### The G6 consent prompt is already standalone — re-home is a *move*, not a *rebuild*
`TelemetryConsentPrompt` (`systems/settings/telemetry_consent_prompt.gd`) is a **self-contained `CanvasLayer`
modal** that builds its own UI in `_ready()`, persists the choice + the asked-flag itself, and emits
`choice_made(enabled)`. Crucially it is **autoload-free and gating-ready**:
- `TelemetryConsentPrompt.should_show()` is **static** (`:39-40`) → `not Settings.get_telemetry_asked()`. M1
  calls it without instancing, exactly as `main_game.gd:1297` does.
- It sits at `MODAL_LAYER = 100` (`:32`) — **above** any menu CanvasLayer — and a dim input-blocking backdrop
  makes it truly modal. So M1 just needs to (1) call `should_show()`, (2) on true, disable the menu buttons +
  `add_child(prompt)`, (3) re-enable on `choice_made`. **No change to the prompt itself.**
- It writes through `Settings` (`user://settings.cfg`, ini, **not** the meta save schema) — so re-homing G6
  has **zero save-schema impact** (no META bump; that's reserved for M3's buy-economy per breakdown §6).

### The Continue/New meta entry points (what each button must call)
The breakdown's M1 row defines the semantics: **New Game** = "fresh meta", **Continue** = "load save, disabled
if no save". The real `GameState`/`SaveManager` APIs:

- **Save-exists detection (drives Continue's `disabled`):** `SaveManager.has_save(slot)` (`save_manager.gd:35-36`)
  → `FileAccess.file_exists(slot_dir(slot) + "/meta.sav")`. M1 uses **slot 0** — the single slot the whole M1
  codebase persists to (`game_state.gd` calls `SaveManager.save_meta(0)` everywhere: extract `:249`, sell
  `:345`, wipe `:426`; the "higher layer … will own slot selection" note at `:248` is *this* milestone's seam,
  but M1.6 stays single-slot — Open Question 4).
- **Continue → load:** `SaveManager.load_meta(0)` (`save_manager.gd:27-33`) reads `meta.sav`, runs the
  migration chain, and calls `GameState.from_meta_dict(data)` — rehydrating Money / banked_junk / quota meta
  into the live `GameState`. Returns `{}` if nothing on disk (M1 only offers Continue when `has_save` is true,
  so this is the populated path; the `{}` guard is belt-and-braces).
- **New Game → fresh meta:** the question is *what "fresh" means over an existing save* (Open Question 1).
  `GameState.wipe_meta()` (`game_state.gd:410-431`) resets **every** meta field to its construction default
  (money/salvage/lore/exposure/knowledge 0, recipes/banked_junk empty, `run_number`→1, `quota_target`→0),
  re-persists through the atomic write, and emits `meta_wiped`. A **fresh process with no save on disk**
  already starts at construction defaults — `GameState` boots all-zero (`:33-49`) and a brand-new profile needs
  *nothing* to be "fresh." So **New Game ≡ "ensure meta is at defaults, then route to the Hub"**: a no-op when
  there's no save, and a `wipe_meta()` (ideally confirmed) when there is. The first quota-enabled `start_run`
  lazy-seeds the quota bar from `quota_base` (`game_state.gd:144-153`), so New Game does **not** need to seed
  anything — it just needs the meta to be clean.

### The M0 router seam this plugs into
Per the breakdown (§3 M0 row, §4, §7 first bullet), **M0 defines the scene/flow router** and **pre-declares the
EventBus signals** (`dive_requested`, `hub_entered`, `returned_to_hub`, …) and **owns the `run/main_scene` swap**
to `main_menu.tscn`. M1 is a **consumer** of that router. The router *mechanism* is M0's to resolve (§7 first
bullet: `get_tree().change_scene_to_file()` between three top-level scenes **vs.** a persistent root `App` node
that swaps children), and M1 must work under **either** outcome. M1's handoff is therefore written against a
**thin, mechanism-agnostic "go to Hub" call** that M0 publishes — concretely one of:

- **(R-a) a router autoload/singleton call** — e.g. `Router.goto_hub()` / `Router.go(&"hub")`; **or**
- **(R-b) an EventBus request signal** the router listens for — e.g. `EventBus.hub_entered.emit()` /
  a `EventBus.menu_start_requested.emit(...)` that the root `App` reacts to by swapping to `hub.tscn`; **or**
- **(R-c) the raw fallback** — `get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")` directly, if M0
  picks the simplest `change_scene_to_file` model and exposes no wrapper.

The pseudocode below uses a single private helper `_route_to_hub()` so the **exact** call is a one-line change
once M0 locks the mechanism (Open Question 6). **Whatever the mechanism, the menu never starts a *dive*** — it
hands off to the **Hub**, and the Hub's departure portal (M2) is what emits `dive_requested`. The menu's job
ends at "the player is now in the Hub with their meta loaded (Continue) or fresh (New Game)."

### Readability rules that apply (UI/UX playbook §2.7, mirrored from `config_menu.gd`'s header)
The Main Menu is **band-independent UI** (it renders over a flat backdrop, no band styling), so the rarity/
origin-band rules don't bite here — but the **legibility-layer + redundant-channel** discipline does:
- **Continue's disabled state is carried by `Button.disabled` (greyed *and* non-interactive) AND a non-colour
  channel** — a sub-label / changed text ("no save yet") — never colour alone (colorblind-safe; playbook
  "back every colour cue with a redundant non-colour channel"). See Open Question 3.
- **Keyboard + controller focus is first-class:** the menu `grab_focus()`es a sensible default (Continue if a
  save exists, else New Game) and the buttons are in a focus-navigable `VBoxContainer`, mirroring how
  `main_game.gd:1316` `grab_focus()`es Start and how the G6 prompt focuses "Not now" (`:108`). The G6 modal,
  while up, must **steal focus and block the menu** (it already does via its layer-100 input-blocking backdrop;
  M1 also disables the menu buttons as a belt-and-braces, mirroring `_maybe_show_consent_prompt`).
- **Every string via `tr()`** against a strings CSV (Open Question 7 decides reuse vs. a new `menu_strings.csv`).

---

## (b) Pseudocode — node tree + `main_menu.gd`

### Node-tree sketch: `scenes/menu/main_menu.tscn`
Greybox, default theme, plain `Control` containers — the same idiom as the current embedded menu and as
`sell_screen.tscn`/`telemetry_consent_prompt.gd`. **Root is a `Control`** (this scene is the whole screen, not
an overlay over a world), so no `CanvasLayer` wrapper is needed; the G6 prompt brings its own layer-100 layer.

```
MainMenu                (Control, root, script main_menu.gd, anchors full-rect)
├── Backdrop            (ColorRect, full-rect, Color(0.07,0.08,0.1,1))   # copied from main_game.tscn:44-50
├── Center              (CenterContainer, full-rect)
│   └── VBox            (VBoxContainer, separation 16)
│       ├── TitleLabel  (Label, "THE FAR YARD", font_size 40, centered)   # tr("MENU_TITLE")
│       ├── NewGameButton   (Button, %NewGameButton,  220×48)             # tr("MENU_NEW_GAME")
│       ├── ContinueButton  (Button, %ContinueButton, 220×48)            # tr("MENU_CONTINUE")  — .disabled gated
│       ├── SettingsButton  (Button, %SettingsButton, 220×48)            # tr("MENU_SETTINGS")  — STUB (OQ 2)
│       └── QuitButton      (Button, %QuitButton,     220×48)            # tr("MENU_QUIT")      — hidden on web? (OQ 8)
└── VersionLabel        (Label, %VersionLabel, bottom-right)             # BuildVersion.id()   # main_game.tscn:85-93
```

A **confirm sub-dialog** for "New Game over an existing save" (Open Question 1) is built inline in `.gd`
(mirroring the `TelemetryConsentPrompt` self-build idiom) rather than authored as a node, so the `.tscn` stays
a clean greybox shell. The **G6 consent prompt** is *not* a child in the `.tscn` — it's instanced at runtime by
the script (exactly as `main_game.gd` does), so it sits at layer 100 over everything.

### Script: `scenes/menu/main_menu.gd` (illustrative, against REAL APIs)

```gdscript
class_name MainMenu
extends Control
## MainMenu (M1.6 · M1) — the app's front door and the home of the New/Continue
## distinction. Greybox default-theme Control; the visual pass is a human's.
##
## ORCHESTRATION ONLY (run/meta boundary, signal-driven decoupling, TDD §2): this
## node owns no game-state truth. It reads SaveManager.has_save() to gate Continue,
## drives the New/Continue meta entry points on GameState/SaveManager, re-homes the
## G6 telemetry-consent modal, and hands off to the Hub via the M0 router. It NEVER
## starts a dive (the Hub's departure portal owns dive_requested — M2).

## G6: first-run telemetry consent prompt, re-homed from main_game (Director-ratified).
const ConsentPromptScript := preload("res://systems/settings/telemetry_consent_prompt.gd")

## The single save slot M1.6 uses (matches game_state.gd's SaveManager.save_meta(0)
## calls; multi-slot is a later milestone — OQ 4).
const SAVE_SLOT: int = 0

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _version_label: Label = %VersionLabel

## G6: true while the first-run consent modal is up; the menu buttons are disabled
## until it's answered (belt-and-braces over the prompt's own input-blocking backdrop).
var _consent_pending: bool = false


func _ready() -> void:
	_version_label.text = tr("MENU_VERSION").format({"id": BuildVersion.id()})  # e.g. "build m1-…"
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


# --- Continue (load save) -----------------------------------------------------

## Continue is offered ONLY when a meta.sav exists for the slot. Redundant non-colour
## channel: disabled => greyed AND the button text/sublabel reads "no save yet" (OQ 3).
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
## existing save it WIPES (with a confirm) — the recommended resolution (OQ 1). With no
## save, "fresh" is already true (GameState boots all-zero), so it's a straight route.
func _on_new_game_pressed() -> void:
	if _consent_pending:
		return
	if SaveManager.has_save(SAVE_SLOT):
		_confirm_overwrite_then_new()                  # modal confirm before destroying a save
	else:
		_start_fresh_and_route()


func _start_fresh_and_route() -> void:
	# A brand-new profile is already at defaults; an overwrite path has just wiped. Either
	# way, meta is clean. wipe_meta() is idempotent + atomic-persists, so calling it on the
	# overwrite path leaves a clean meta.sav on disk (so a later Continue resumes the fresh
	# game, not the destroyed one). The first quota-enabled start_run lazy-seeds the bar.
	_route_to_hub()


## Inline greybox confirm (built like TelemetryConsentPrompt — self-building modal). On
## confirm: GameState.wipe_meta() (resets every meta field + re-persists atomically), then
## route. On cancel: dismiss, menu unchanged.
func _confirm_overwrite_then_new() -> void:
	var dialog := ConfirmationDialog.new()             # default-theme greybox; or an inline VBox modal
	dialog.dialog_text = tr("MENU_NEWGAME_CONFIRM")
	dialog.ok_button_text = tr("MENU_NEWGAME_CONFIRM_OK")
	dialog.cancel_button_text = tr("MENU_CANCEL")
	dialog.confirmed.connect(func() -> void:
		GameState.wipe_meta()                          # game_state.gd:410 — fresh meta + persist + meta_wiped
		_refresh_continue_state()                      # (Continue stays enabled; the slot now holds fresh meta)
		_start_fresh_and_route())
	add_child(dialog)
	dialog.popup_centered()


# --- Settings (STUB — OQ 2) ---------------------------------------------------

## M1 ships a Settings BUTTON, not a full panel (breakdown M1 row: "+ a Settings stub").
## Minimal honest stub: open the existing TelemetrySettingsPanel (the only real setting in
## M1) OR a placeholder "coming soon" modal. Full accessibility/rebinding settings are M5.
func _on_settings_pressed() -> void:
	if _consent_pending:
		return
	# Recommended stub: surface the one real setting that exists today (telemetry opt-in).
	# Implementation resolved in OQ 2 (panel reuse vs. placeholder).
	pass


# --- Quit ---------------------------------------------------------------------

func _on_quit_pressed() -> void:
	if _consent_pending:
		return
	get_tree().quit()                                  # desktop; no-op-ish on web (OQ 8 hides it)


func _maybe_hide_quit_on_web() -> void:
	# On HTML5 there's no app to quit; hide Quit so the menu doesn't offer a dead action (OQ 8).
	if OS.has_feature("web"):
		_quit_button.hide()


# --- M0 router handoff (mechanism-agnostic; OQ 6 locks the exact call) ---------

## The ONE place the menu leaves for the Hub. Written against whatever "go to Hub" seam
## M0 publishes (router autoload call, an EventBus request signal, or a raw
## change_scene_to_file). Swapped to the real call once M0 locks the mechanism.
func _route_to_hub() -> void:
	# (R-a) Router.goto_hub()                                   — if M0 ships a router singleton, OR
	# (R-b) EventBus.hub_entered.emit()                         — if a root App swaps on the signal, OR
	# (R-c) get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")  — raw fallback.
	pass


# --- G6 first-run telemetry consent (re-homed verbatim from main_game) --------

## Show the consent modal exactly once (first launch / wiped profile). Blocks the menu
## buttons until answered; after any answer it never re-shows. Identical to
## main_game.gd:_maybe_show_consent_prompt — only the host scene changed.
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
```

### Strings (externalized — playbook "all text via `tr()`")
Keys the menu needs (CSV resolved in Open Question 7): `MENU_TITLE`, `MENU_NEW_GAME`, `MENU_CONTINUE`,
`MENU_CONTINUE_NONE` ("Continue — no save yet"), `MENU_SETTINGS`, `MENU_QUIT`, `MENU_VERSION` ("build {id}"),
`MENU_NEWGAME_CONFIRM` ("Start a new game? This erases your current save."), `MENU_NEWGAME_CONFIRM_OK`
("New game"), `MENU_CANCEL`. The G6 modal's strings stay where they already live (`TelemetrySettingsPanel.CONSENT_COPY`,
shared single source — `telemetry_consent_prompt.gd:84`); M1 does **not** duplicate them.

### Smoke-test / load expectations (no generation, no schema, no knob)
- The entry-scene swap (`run/main_scene` → `main_menu.tscn`) is **M0's** edit; M1 must keep the scene
  *loadable headless* (greybox `Control`, no exotic deps) so `--import` and `tools/ci_smoke_test.gd` stay green.
  Confirm with M0 that the smoke test loads its scenes **directly** and doesn't assume `main_game` is the entry
  (breakdown §6 last bullet; §7 last bullet).
- **No `RunConfig` field, no EventBus signal *added by M1*** (M0 pre-declares any new signals), **no save-schema
  field** (G6 writes to `Settings`/`user://settings.cfg`, outside the meta schema). Fingerprint + 89-knob count
  are untouched — M1 is structurally incapable of moving them (it writes only `scenes/menu/*`).

---

## (c) Open Questions

> Flagged where Director taste/scope genuinely helps. Phase-3 fresh-eyes resolves the technical ones; the
> New-Game-over-save behaviour (OQ 1) and the Settings-stub scope (OQ 2) are the two with a real judgment seam.

1. **New Game over an existing save — wipe-with-confirm vs. refuse vs. silent-wipe?** (breakdown §7 "Main-menu
   Continue/New semantics".) Three options: **(i) wipe-with-confirm** — New Game on an existing save pops a
   greybox `ConfirmationDialog` ("This erases your current save"); on confirm `GameState.wipe_meta()` then route;
   **(ii) refuse** — disable/grey New Game whenever a save exists (force the player to Continue or there's no
   New Game), which is hostile and dead-ends a player who *wants* a fresh start; **(iii) silent wipe** — destroy
   the save with no prompt (data-loss footgun). **Recommendation: (i) wipe-with-confirm.** It matches player
   expectations from every roguelite, it's reversible-by-intent (the confirm is the safety), and `wipe_meta()`
   already exists + atomically re-persists so the on-disk save becomes the *fresh* game (a later Continue
   resumes the new game, not the destroyed one — no orphaned save). This is a **mild Director taste call** (the
   confirm wording + whether a single-slot game should even *offer* both buttons when a save exists) — flag it,
   recommend (i). **Director taste, low-stakes; recommend wipe-with-confirm.**

2. **Settings-stub scope — placeholder modal vs. wire the one real setting (telemetry) vs. full panel?** The
   breakdown says "**a Settings stub button**" — so the *button* is in scope, the *content* is the question.
   Today the only persisted setting is the telemetry opt-in (`Settings`/`TelemetrySettingsPanel`,
   `telemetry_settings_panel.gd`); full accessibility (text size, colorblind palettes, screen-shake, rebinding)
   is explicitly **M5** (playbook workflow 4). Options: **(a) honest placeholder** — a "Settings — coming soon"
   greybox modal (cheapest; truthful that it's a stub); **(b) reuse `TelemetrySettingsPanel`** — open the
   existing telemetry toggle panel (gives the button *one* real function: change the G6 choice later, which the
   breakdown's G6 flow implies a player needs); **(c) build a real settings screen** — out of M1.6 scope
   (M5 owns it; would balloon this task). **Recommendation: (b) reuse `TelemetrySettingsPanel`** — it's the one
   real, already-built setting, it gives the menu a non-dead Settings button, and it's the natural "change my
   telemetry opt-in" home now that G6 lives on the Menu. If (b) is more wiring than a "stub" should be, fall
   back to (a). **Mild scope call — recommend (b), accept (a) as the minimal floor.**

3. **Continue's disabled-state non-colour channel — text-swap vs. sublabel vs. hide?** Colorblind-safety needs
   a redundant non-colour channel beyond the greyed look (playbook). Options: **(i) text-swap** — Continue's
   label becomes "Continue — no save yet" when disabled (proposed in the pseudocode, `MENU_CONTINUE_NONE`);
   **(ii) a small sublabel** under the button; **(iii) hide Continue entirely** when there's no save (cleanest
   visually but removes the affordance/teaching that Continue *exists*). **Recommendation: (i) text-swap** —
   keeps the button present (teaches the New/Continue model) while making "why is this greyed" legible without
   colour. **Resolvable now (ui self-resolve); recommend text-swap.**

4. **Single slot (0) vs. a slot picker?** M1.6 stays single-slot — every `GameState` persist targets slot 0
   (`game_state.gd:249/345/426`), and the breakdown scopes M1 to New/Continue/Quit + Settings, not slots. The
   `save_manager.gd:248` "a higher layer … will own slot selection" note points at a *future* milestone, not
   M1.6. **Recommendation: hard-code `SAVE_SLOT = 0`** and leave slots out of M1.6. **Resolvable now; recommend
   single-slot.**

5. **Who deletes the old embedded menu + G6 wiring — M1 or M2?** M1 *creates* the standalone Menu (incl. the
   re-homed G6); M2 *refactors* `main_game.tscn`/`main_game.gd` to **dive-only** and is the single writer of
   those files (breakdown §4). So **M2 deletes** the `MainMenu` CanvasLayer (`main_game.tscn:42-93`), the
   `StartButton`/`_show_menu`/`_hide_menu`/`_on_start_pressed`/`_maybe_show_consent_prompt`/`_on_consent_choice`
   block, and the `ConsentPromptScript` preload from `main_game.gd`. **M1 must NOT touch `main_game.*`** (file-
   disjoint). **Action: the breakdown/M2 design must list "remove the embedded menu + G6 wiring" as M2's job;**
   M1's worklog should note the dependency so neither agent leaves a duplicate consent path on `main`. **Cross-
   task coordination — call it out to the orchestrator; no Director call.**

6. **Exact router handoff to the Hub (depends on M0's mechanism).** M1 cannot lock `_route_to_hub()`'s body
   until M0 resolves the router (§7 first bullet: `change_scene_to_file` between three scenes vs. a persistent
   root `App` that swaps children). M1 is written mechanism-agnostically (one private helper) so the swap is a
   one-liner. **Recommendation: M0 should publish a thin named "go to Hub" seam** (a `Router.goto_hub()` call
   **or** a single `EventBus` request signal) so M1/M2 don't hard-code `change_scene_to_file` paths that the
   `App`-node model would break. **Blocked-on-M0; flag to the M0 design + Phase-3 to reconcile.**

7. **Strings: reuse `config_strings.csv`, extend an existing CSV, or a new `menu_strings.csv`?** The menu's keys
   (`MENU_*`) are a new, cohesive surface. `ui/config/config_strings.csv` is the **config menu's** namespace
   (`CFG_*`) and M4 owns that file — reusing it would create a cross-task write conflict and mix unrelated
   namespaces. **Recommendation: a NEW `scenes/menu/menu_strings.csv`** (mirroring `ui/sell/sell_strings.csv`
   and `ui/config/config_strings.csv` — each surface owns its CSV), keeping M1 file-disjoint and the namespace
   clean. **Resolvable now; recommend a new `menu_strings.csv` under `scenes/menu/`.**

8. **Quit on web vs. desktop.** `get_tree().quit()` is meaningful on desktop but a near-no-op in a browser tab
   (HTML5 can't close its own tab). Options: **(i) hide Quit on web** (`OS.has_feature("web")` → `_quit_button.hide()`,
   proposed); **(ii) keep it** and accept it's inert; **(iii) replace it with "Back to itch"** or similar on web.
   **Recommendation: (i) hide on web** — the itch playtest build (Chromium-only, breakdown standing step) has no
   use for a Quit that does nothing, and a dead button reads as broken. **Resolvable now (ui self-resolve);
   recommend hide-on-web.**

9. **Mockup-first (playbook workflow 2) — HTML or skip?** The playbook requires "a clickable HTML mockup of the
   screen + its states (empty/full inventory, low-resource HUD, menu open), approved before heavy engine work."
   For this menu the meaningful states are: **(s1)** no-save (Continue greyed/"no save yet"), **(s2)** save-
   exists (Continue enabled, focused), **(s3)** first-run (G6 consent modal up, buttons blocked), **(s4)** New
   Game confirm dialog over an existing save, **(s5)** web (Quit hidden). **Recommendation: yes — build a
   single-file `main_menu_mockup.html`** walking s1–s5, get Director sign-off, *then* author the `.tscn`/`.gd`.
   It's cheap (one greybox screen) and it's the playbook's gate. **Process step, not a design call — do it.**

---

## Resolved Decisions (Phase 3)

**Resolver:** fresh-eyes pass (NOT the M1 author), 2026-06-26. Verified every cited API against the live source:
`SaveManager.has_save(slot)` / `load_meta` (`systems/save_manager.gd:35-36`, `:27-33`), `GameState.wipe_meta()`
(`game_state.gd:410-431`, slot-0 persist + `meta_wiped`), `GameState` all-zero construction defaults (`:33-49`),
`TelemetryConsentPrompt.should_show()` static + `MODAL_LAYER=100` (`telemetry_consent_prompt.gd:39-40`, `:32`),
`BuildVersion.id()` (`systems/version.gd:43`), and the CSV-per-surface precedent (`ui/sell/sell_strings.csv`,
`ui/config/config_strings.csv`). One correction below (OQ 2). The flow + gating design is otherwise confirmed and
**frozen** as authored.

### Verification (against real code)
- **`SaveManager.has_save(0)`** is exactly `FileAccess.file_exists(slot_dir(0)+"/meta.sav")` — a cheap, pollable
  predicate. Continue's gating is sound. ✓
- **`GameState.wipe_meta()`** resets every meta field to construction default, **re-persists through the atomic
  slot-0 path** (`save_meta(0)`, `:426`), and emits `meta_wiped`. So the wipe-then-route path leaves a *clean*
  `meta.sav` on disk — a later Continue resumes the fresh game, never the destroyed one. No orphaned save. ✓
- **A brand-new profile boots all-zero** (`game_state.gd:33-49`): money/salvage/lore/exposure/knowledge `0`,
  empty recipes/banked_junk, `run_number=1`, `quota_target=0`. So "New Game with no save" needs **no** seeding —
  a straight route. ✓ The first quota-enabled `start_run` lazy-seeds the bar (`:144-153`); the menu seeds nothing.
- **G6 re-home is a verbatim move:** `should_show()` is static and autoload-free; the prompt self-builds at
  layer 100 with its own input-blocking backdrop. M1 calls `should_show()`, on true disables the menu buttons +
  `add_child(prompt)`, re-enables on `choice_made`. **The prompt itself is unchanged.** It writes through
  `Settings`/`user://settings.cfg`, **outside** the meta save schema → **zero META-schema impact** (no v3→v4
  bump — that's reserved for M3 if purchases persist). ✓
- **No fingerprint/knob exposure:** M1 writes only `scenes/menu/*`, adds no `RunConfig` field, no generation
  touch, no EventBus signal of its own (M0 pre-declares any). The all-off fp (`e943ac9c8bc1`) and the 89-knob
  count are structurally untouchable from this task. ✓

### Locked decisions

- **OQ 1 — New Game over an existing save: WIPE-WITH-CONFIRM (option i).** LOCKED as the author recommends. New
  Game on an existing save pops a greybox confirm (`MENU_NEWGAME_CONFIRM`, "Start a new game? This erases your
  current save."); on confirm `GameState.wipe_meta()` → route to Hub; on cancel, dismiss with the menu unchanged.
  No save → straight route (already fresh). This matches roguelite convention, is reversible-by-intent (the
  confirm is the safety), and uses an already-atomic, already-persisting API. **One implementation refinement
  for the builder (not a design change):** the pseudocode's `_confirm_overwrite_then_new()` uses a bare
  `ConfirmationDialog` whose default OK/Cancel button text is engine-locale, not `tr()`-routed — set
  `ok_button_text`/`cancel_button_text` explicitly from `menu_strings.csv` (the pseudocode already does this:
  `MENU_NEWGAME_CONFIRM_OK` / `MENU_CANCEL`), and keep the confirm **modal/exclusive** (`dialog.exclusive = true`
  or disable the menu buttons while it's up) so a click-through can't fire New Game twice. **Director taste flag
  (low-stakes):** the *destructiveness* of New-Game-wipes-save in a single-slot game is the one human seam — see
  "Needs Director review." Recommendation stands: ship wipe-with-confirm.

- **OQ 2 — Settings-stub scope: HONEST PLACEHOLDER (option a) is the locked M1.6 floor; reuse (b) is an
  upgrade gated on a Director call.** This **adjusts** the author's lean toward (b). Fresh-eyes verification
  found that `TelemetrySettingsPanel` (`telemetry_settings_panel.gd`) is **(1) not instanced anywhere today**
  (only its `CONSENT_COPY` constant is referenced — there is no existing "open the settings panel" idiom to
  reuse), **(2) a plain full-rect `Control`** with no backdrop, no close button, and no modal framing — opening
  it from the menu means *building a host overlay + dismiss affordance the panel lacks*, and **(3) authored with
  raw string literals, NOT `tr()`** — surfacing it from the menu drags a non-localized surface into the new
  `tr()`-clean menu. That is real new UI wiring, not a "stub." Per the breakdown's exact wording ("a Settings
  **stub** button") the cheapest truthful deliverable is a greybox **"Settings — coming soon"** modal (built
  inline like the confirm dialog, strings via `tr()` → `MENU_SETTINGS_SOON`). Full settings (incl. a real home
  for the telemetry opt-in + rebinding/accessibility) remain **M5**. **Recommendation: ship (a) the honest
  placeholder for M1.6.** If the Director wants the button to *do* something now — specifically to give a player
  a post-G6 way to change their telemetry choice — that's option (b), which is a small but real add (host
  overlay + close + ideally `tr()`-ing the panel) and is **flagged for Director review** below.

- **OQ 3 — Continue disabled-state non-colour channel: TEXT-SWAP (option i).** LOCKED. Disabled Continue greys
  *and* swaps its label to `MENU_CONTINUE_NONE` ("Continue — no save yet"), a redundant non-colour channel
  (colorblind-safe) that keeps the affordance visible (teaches the New/Continue model) rather than hiding it.
  `_refresh_continue_state()` re-runs on `_ready` and after the G6 choice — no polling needed (the menu can't
  gain a save while it's up; a save only appears after routing away). Resolvable now, no Director input.

- **OQ 4 — Single slot 0.** LOCKED. Hard-code `SAVE_SLOT = 0` (a `const`). Every `GameState` persist already
  targets slot 0 (`:249/345/426`); multi-slot is a later milestone. No Director input.

- **OQ 5 — Old embedded menu + G6 deletion is M2's job (coordination, no Director call).** CONFIRMED. M1 only
  *creates* `scenes/menu/*` (file-disjoint). **M2** is the single writer of `main_game.*` and must, in its
  dive-only refactor, **delete** the `MainMenu` CanvasLayer (`main_game.tscn:42-93`) and the
  `StartButton`/`_show_menu`/`_hide_menu`/`_on_start_pressed`/`_maybe_show_consent_prompt`/`_on_consent_choice`
  block + the `ConsentPromptScript` preload from `main_game.gd`, so **no duplicate consent path lands on `main`**.
  **Action for the orchestrator:** ensure the M2 design/breakdown row explicitly lists "remove the embedded menu
  + G6 wiring," and M1's shared worklog notes this dependency. Until M2 lands, both paths could co-exist on a
  feature branch — acceptable in-wave (file-disjoint), but the close-out sweep must confirm M2 removed the old
  one before RG1.

- **OQ 6 — Router handoff: mechanism-agnostic `_route_to_hub()` helper; M0 publishes the seam.** LOCKED as
  designed, with the cross-task convergence noted in the Phase-3 brief: **M0 = a persistent root `App` node** that
  swaps state scenes and holds the P-overlay. Under that model the menu's handoff is **(R-a/R-b): call the App
  router API / emit the M0 router request signal** (e.g. `App.goto_hub()` or `EventBus.<hub-request>.emit()`),
  **NOT** a raw `change_scene_to_file` (R-c) — a raw scene-change would tear down the persistent `App` root the
  router model depends on, so (R-c) is explicitly the *wrong* call under the ratified App-node design and should
  be dropped from the final body. M1 keeps the single private `_route_to_hub()` helper so the exact call is a
  one-line fill once M0 lands; **M1 `BlockedBy: M0`** and must not invent its own router. The menu **never** emits
  `dive_requested` — it hands off to the Hub; the Hub's departure portal (M2) owns `dive_requested`. This is
  resolved on technical merit (no Director call) given the convergence; the only residual is M0 naming the exact
  symbol, which M1 consumes verbatim.

- **OQ 7 — Strings: NEW `scenes/menu/menu_strings.csv`.** LOCKED. Each UI surface owns its CSV
  (`ui/sell/sell_strings.csv`, `ui/config/config_strings.csv`); a new `menu_strings.csv` under `scenes/menu/`
  keeps M1 file-disjoint and the `MENU_*` namespace clean (reusing `config_strings.csv` would collide with M4,
  which owns that file in the same wave). Keys: `MENU_TITLE`, `MENU_NEW_GAME`, `MENU_CONTINUE`,
  `MENU_CONTINUE_NONE`, `MENU_SETTINGS`, `MENU_SETTINGS_SOON` (the placeholder modal, per OQ 2-a), `MENU_QUIT`,
  `MENU_VERSION`, `MENU_NEWGAME_CONFIRM`, `MENU_NEWGAME_CONFIRM_OK`, `MENU_CANCEL`. The G6 modal's own strings
  stay in `TelemetrySettingsPanel.CONSENT_COPY` (single source — not duplicated). No Director input.

- **OQ 8 — Quit hidden on web.** LOCKED. `OS.has_feature("web")` → `_quit_button.hide()`. The itch build
  (Chromium-only) can't close its tab; a dead Quit reads as broken. Desktop keeps `get_tree().quit()`. Resolvable
  now, no Director input.

- **OQ 9 — Mockup-first: YES, build `main_menu_mockup.html`.** CONFIRMED as a process step (UI/UX playbook
  workflow 2). One greybox HTML file walking states s1 (no-save/Continue greyed) · s2 (save-exists/Continue
  focused) · s3 (G6 consent up, buttons blocked) · s4 (New-Game confirm over a save) · s5 (web/Quit hidden),
  Director sign-off, *then* author `.tscn`/`.gd`. Cheap and the gate — do it. The mockup is the natural place for
  the Director to also rule on the OQ-1 / OQ-2 taste seams below.

### Needs Director review (two seams — both low-stakes, surface at the mockup gate)
1. **New-Game destructiveness in a single-slot game (OQ 1).** The locked behavior wipes the one save behind a
   confirm. The only human call is whether a single-slot build should even *offer* New Game alongside Continue
   when a save exists (vs., e.g., gating New Game behind Settings), and the exact confirm wording/tone.
   **Recommendation: keep both buttons + wipe-with-confirm** (standard roguelite, the confirm is the safety).
   Decide at the mockup sign-off (state s4).
2. **Does Settings do anything in M1.6? (OQ 2)** Locked floor = honest "coming soon" placeholder (truthful,
   cheapest, `tr()`-clean). The upgrade — reuse `TelemetrySettingsPanel` so a player can change their post-G6
   telemetry opt-in now — is a small but real add (build a host overlay + close affordance + ideally `tr()` the
   panel, which is raw-string today and not currently instanced anywhere). **Recommendation: ship the placeholder
   for M1.6; defer the real telemetry-settings home to M5** unless the Director wants the post-G6 opt-in change
   reachable from the menu this iteration. Decide at the mockup sign-off.
