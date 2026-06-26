# Worklog — M0 Foundation: app-flow router + economy + signals + P action

- **Date:** 2026-06-26
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.6 (Wave 1, lands first + alone)
- **Branch:** general-purpose/M0
- **Commit:** b68c94e678684cde6a37b5dae458a1983026b41c

## What changed
M0 is the single-writer foundation pass over the shared structural files for M1.6.
Landed: (1) a persistent root **App** router (`scenes/app/app.tscn`+`.gd`) that swaps
one state scene (Menu/Hub/Dive) under a StateHost with a persistent DebugOverlay
CanvasLayer (empty mount for M4), observing `EventBus.run_ended` to auto-return to the
Hub (deferred one frame) and exposing `current_state` for M4; (2) the entry swap
`run/main_scene` → `app.tscn` + the `debug_menu_toggle`=P (keycode 80) input action;
(3) the 8 locked M1.6 EventBus signals (declare-only); (4) the GameState economy
surface (`owned_items` meta, `purchase()`/`owns()`, the dive-staged-config accessor
`stage_dive_config()`/`dive_config_or_default()`, and `evaluate_quota_on_return()`) at
neutral defaults — NO save-schema bump (META_SCHEMA_VERSION stays 3); (5) a v3→v4
migration SKELETON in `save_manager.gd` (inert `3:` case for M3 to fill); (6) greybox
menu/hub stubs so `main` boots end-to-end; (7) a router smoke test scene.

## Files touched
- `systems/event_bus.gd` — appended the M1.6 signal block: `dive_requested`,
  `hub_entered`, `returned_to_hub`, `shop_opened`, `shop_closed`, `item_sold(item_count,
  total_value, money)`, `item_purchased(item_id, price, money)`, `purchase_failed(...)`
  (8 signals, arities per RD-2; declare-only, owners M2/M3/App emit).
- `systems/game_state.gd` — `owned_items` meta array (reset in `wipe_meta`);
  `purchase(item_id, price)` (ledger debit via `add_currency(&"money", -price, &"shop")`
  → append → `save_meta(0)` → `item_purchased`; reject paths emit `purchase_failed`);
  `owns(item_id)`; `_dive_config` slot + `stage_dive_config()`/`dive_config_or_default()`
  (M4 writes, M2 reads, falls back to `make_default_play_preset()`);
  `evaluate_quota_on_return()` (quota eval decoupled from `sell_banked_junk`, basis = held
  `banked_junk` value; idempotency guard makes a later sell a no-op re-eval).
- `systems/save_manager.gd` — v3→v4 migration SKELETON (`3:` case, body commented;
  inert while META_SCHEMA_VERSION==3 so M3 activates it). NO version bump.
- `project.godot` — `run/main_scene`→`res://scenes/app/app.tscn`; new `debug_menu_toggle`
  action = physical keycode 80 (P), mirrors `debug_kill`'s shape.
- `scenes/app/app.gd` + `scenes/app/app.tscn` — NEW the router (App→StateHost+DebugOverlay).
- `scenes/menu/main_menu.gd` + `.tscn` — NEW greybox menu stub (Label + "Go to Hub" →
  `router.goto_hub()`). **REPLACED by M1.**
- `scenes/hub/hub.gd` + `.tscn` — NEW greybox hub stub (Label + "Dive" →
  `EventBus.dive_requested.emit(&"near")`). **REPLACED by M2.**
- `tests/test_app_router.gd` + `.tscn` — NEW router smoke test (boots → menu → hub →
  dive → hub; asserts `current_state`).

## Checks run
- [x] `godot --headless --import` clean — no script/parse errors on any new/edited file
  (only the pre-existing missing-`.translation` warnings, unrelated generated artifacts).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK** (entry swap
  is CI-safe; the smoke test is entry-agnostic, runs as `--script`).
- [x] `godot --headless res://tests/test_app_router.tscn` → **ROUTER OK** (exit 0; the
  camera_2d line-68 warning is a harmless engine notice from the dive scene loading
  headless, not a failure).
- [x] `godot --headless res://tests/test_run_config.tscn` → exit 0; `test_config_menu.tscn`
  → **CONFIG MENU OK — 89/89 knobs** (knob count UNCHANGED; M0 added no RunConfig knob).
- [x] `godot --headless res://tests/test_corridor_lever.tscn` → **J4 OK — neutral fp
  byte-matches e943ac9c8bc1** (all-off determinism fingerprint UNMOVED — M0 touches no
  generation).
- [x] Regression on touched logic: `test_save_migration.tscn` exit 0; `test_quota_system.tscn`
  exit 0; `test_money_ledger.gd` (--script) → MONEY LEDGER OK.
- [x] Definition of done met: "Project imports clean and boots through the App router to
  the menu stub; all 8 EventBus signals declared; the GameState economy surface +
  `evaluate_quota_on_return()` + staged-config accessor exist at neutral defaults with no
  save-schema bump (META_SCHEMA_VERSION==3) and the v3→v4 skeleton scaffolded;
  `debug_menu_toggle`=P added; greybox menu/hub stubs route correctly; router smoke test
  green; all-off fp e943ac9c8bc1 unmoved; 89-knob count unchanged; CI smoke green."

## Design deviations
- **none** (functional). One mechanism choice worth flagging for the orchestrator, fully
  within the locked design: RD-2 dropped the Menu→Hub signal, and `App` is a root scene
  node (not an autoload), so the Menu/Hub scenes cannot name it. I exposed the router via
  the group `&"app_router"` + a public `App.goto_hub()` method (the R-a "go to Hub" handoff
  M1_main_menu.md explicitly anticipated). This adds no EventBus signal and no autoload —
  it is the documented mechanism-agnostic seam, so it is on-spec, not a deviation. Noted so
  M1 binds to `get_tree().get_first_node_in_group(&"app_router").goto_hub()`.

## Handoffs / follow-ups
- **→ M2 (dive-only refactor seam):** the router loads `main_game.tscn` AS-IS. main_game
  still owns its embedded `MainMenu` CanvasLayer + Start button + ConfigMenu rail and still
  auto-presents SellScreen on `run_ended` (`main_game.gd:143-169`, `:158`). The router
  puts the dive in the tree but does NOT auto-start a run — so today, entering the dive via
  the router shows main_game's OWN embedded menu (the player still presses Start). M2 must:
  (a) strip the embedded menu and make `main_game._ready()` self-start via `start_new_run()`,
  (b) resolve its `RunConfig` from `GameState.dive_config_or_default()` (M0 landed it) and
  feed it through the existing `stage_run_config()` before `start_run()`, (c) remove the
  SellScreen auto-present to avoid a double-sell orphan, (d) preserve the programmatic
  `start_new_run()` entry the RG-verify tests drive. The router auto-returns to the Hub on
  `run_ended` (deferred) — M2's Hub-return controller reads `returned_to_hub(reason)`, calls
  `GameState.evaluate_quota_on_return()`, and on a MISS shows the beat + `wipe_meta()` before
  re-arming the portal.
- **→ M3:** call `GameState.purchase(item.id, item.cost)` (primitive args — `ShopItem` is
  M3's type, M0 stayed catalog-agnostic). `purchase()` already emits `item_purchased(id,
  price, money)` (3-arg) and guards double-buy via `owns()`. Emit `item_sold(item_count,
  total_value, money)` (3-arg roll-up) from the single `sell_banked_junk()` call. M3 owns
  the v3→v4 bump: bump META_SCHEMA_VERSION to 4, uncomment the `3:` skeleton in
  `save_manager.gd`, add `owned_items` to `to_meta_dict`/`from_meta_dict`, add a
  `meta_v3.sav` fixture + a `test_save_migration` v3 case — gated on the RD-4 Director call.
- **→ M4:** mount the P-toggle tabbed menu under `App.DebugOverlay`; read `App.current_state`
  for pause-in-dive; write config via `GameState.stage_dive_config(cfg)`. The
  `debug_menu_toggle`=P action is live. M4 owns pause/visibility (RD-6).
- **→ M1:** REPLACE `scenes/menu/main_menu.tscn`; route Menu→Hub via
  `get_tree().get_first_node_in_group(&"app_router").goto_hub()`. Never call change_scene_*.
- **Director review queue (unchanged, M0 did not self-resolve):** RD-4 — persistent
  purchases → META v3→v4 save bump (fun/scope). Recommend persistent; the bump lands in M3.
