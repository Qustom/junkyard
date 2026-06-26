# Worklog — M1 Main menu scene (M1.6 Wave 2)

- **Date:** 2026-06-26
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.6
- **Branch:** general-purpose/M1
- **Commit:** bbc61ff9d2863a6fa17e8fd550f1a87a124ec924

## What changed
Replaced the M0 greybox stub `scenes/menu/main_menu.{tscn,gd}` with the real routed Main
Menu — the app's front door. New Game (wipe-with-confirm over an existing save → fresh meta),
Continue (save-gated, text-swapped disabled state), Settings ("coming soon" placeholder modal),
Quit (hidden on web). Re-homed the G6 first-run telemetry-consent modal onto the menu (fires
once, blocks the buttons until answered). Routes into the Hub via the M0 App router
(`goto_hub()` discovered through the `&"app_router"` group). All strings via `tr()` against a
new `scenes/menu/menu_strings.csv`. No save-schema change, no generation touch, no RunConfig knob.

## Files touched
- `scenes/menu/main_menu.gd` — full rewrite: New/Continue/Settings/Quit + G6 consent re-home + router handoff (replaces the stub).
- `scenes/menu/main_menu.tscn` — greybox Control: Backdrop + centered VBox (Title/New/Continue/Settings/Quit) + bottom-right VersionLabel; buttons are `unique_name_in_owner` (%-access).
- `scenes/menu/menu_strings.csv` — new `MENU_*` strings surface (own CSV per OQ 7; mirrors sell/config CSV setup).
- `scenes/menu/menu_strings.csv.import` — CSV-translation import sidecar (Godot regenerated the UID on first import; the `.en.translation` artifact is gitignored like the other surfaces').

## Checks run
- [x] `godot --headless --import` clean — `MainMenu` class registered, `menu_strings.csv` reimported, NO parse/script errors. (The `*_strings.en.translation` "Cannot open" lines are pre-existing for inventory/hud/sell/config — those generated artifacts are gitignored and absent in a fresh worktree; not introduced by M1.)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy` (exit 0).
- [x] `godot --headless res://tests/test_app_router.tscn` → `ROUTER OK — App router boots → menu → hub → dive → hub` (exit 0). The router test calls `app.goto_hub()` directly and does NOT reference the menu's node names, so replacing the stub left it green.
- [x] `godot --headless --quit-after 3 res://scenes/app/app.tscn` → boots to the real Main Menu with ZERO errors/warnings: `tr()` resolved (no raw-key leakage), version label built via `BuildVersion.id()`, no `app_router`-missing warning, G6 path clean.
- [x] Definition of done met (see below).

## Definition of done (quoted + status)
- "Boot lands on the real Main Menu" — ✓ (clean headless boot; router Case 1 `current_state == &"menu"` with the new scene).
- "New/Continue/Quit/Settings behave as locked (Continue gates on save presence; New Game confirms before wiping; Quit hidden on web)" — ✓ structurally: `_refresh_continue_state()` reads `SaveManager.has_save(0)` (greyed + `MENU_CONTINUE_NONE` text-swap); New Game pops an exclusive `ConfirmationDialog` → `GameState.wipe_meta()` only on confirm; `_maybe_hide_quit_on_web()` hides Quit under `OS.has_feature("web")`; Settings opens an honest "coming soon" `AcceptDialog`.
- "G6 consent fires once on first run from the menu" — ✓ `_maybe_show_consent_prompt()` calls the static `TelemetryConsentPrompt.should_show()`, instances the unchanged prompt (layer 100), disables the menu buttons until `choice_made`. The prompt itself is reused verbatim (no edit) and writes through `Settings`/`user://settings.cfg` (zero meta-schema impact).
- "routes into the Hub via `App.goto_hub()`" — ✓ via `get_tree().get_first_node_in_group(&"app_router").goto_hub()` (R-a, OQ 6 locked). The menu never emits `dive_requested`.
- "`menu_strings.csv` wired, all strings via `tr()`; greybox" — ✓ default theme, no authored art.
- "import + smoke green; fp/knob-count untouched" — ✓ (writes only `scenes/menu/*`; no generation/RunConfig/EventBus-signal change → all-off fp `e943ac9c8bc1` and 89-knob count structurally untouchable).

## Design deviations
1. **Runtime self-registration of `menu_strings` translation.** project.godot's `locale/translations`
   is owned by M0 and out of my write scope, so I cannot register the new CSV there. To keep the
   menu localized rather than leaking raw `MENU_*` keys, `_ensure_strings_registered()` loads the
   `.translation` and `TranslationServer.add_translation()`s it at `_ready` — guarded (no-op if
   `tr()` already resolves the key). This is idempotent and becomes a dead no-op once M0 adds the
   registration line. **Recommendation for the orchestrator:** add
   `res://scenes/menu/menu_strings.en.translation` to `project.godot`'s `locale/translations`
   PackedStringArray (alongside inventory/hud/sell/config) and the runtime fallback becomes
   redundant (it can stay harmlessly, or be dropped). Low-stakes; flagged for awareness.
2. **Settings = "coming soon" placeholder (OQ 2-a), not the `TelemetrySettingsPanel` reuse the
   author leaned toward.** This follows the Phase-3 LOCKED floor (panel is uninstanced, unframed,
   raw-string → real new UI deferred to M5), not a deviation from the locked spec — noted for
   traceability. The post-G6 "change my telemetry opt-in from the menu" upgrade is the Director
   seam flagged in the spec's "Needs Director review #2"; recommend deferring to M5.

## Handoffs / follow-ups
- **M2 coordination (OQ 5) — old G6 path must be deleted by M2.** M1 ADDS the consent re-home to
  the menu; M2 (single writer of `main_game.*`) must DELETE the embedded `MainMenu` CanvasLayer
  + `StartButton`/`_show_menu`/`_hide_menu`/`_on_start_pressed`/`_maybe_show_consent_prompt`/
  `_on_consent_choice` + the `ConsentPromptScript` preload from `main_game.{tscn,gd}`, so no
  duplicate consent path lands on `main`. Both can co-exist in-wave (file-disjoint); the close-out
  sweep must confirm M2 removed the old one before RG1. My files do not overlap M2's.
- **Orchestrator:** add the menu translation to `project.godot` locale/translations (deviation #1).
