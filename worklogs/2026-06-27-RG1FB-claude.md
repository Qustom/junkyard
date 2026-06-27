# Worklog — M1.6 RG1 playtest feedback fixes (FB1 extract prompt, FB2 quota-on-return)

- **Task:** Two Director playtest bugs on the M1.6 RG1 build, applied direct by the orchestrator (the M1.5 post-RG tuning precedent — focused, well-understood fixes, full gate re-run).
- **Date:** 2026-06-27
- **Agent(s):** orchestrator (claude), direct.
- **Commit:** see below.

## FB1 — "F to extract" prompt was hidden behind the extraction door

**Symptom (Director):** at the gate, the extract prompt text renders behind the door and isn't visible when near.

**Root cause:** the world-space `InteractionPrompt` (`ui/interaction_prompt.tscn`, a `Node2D`+`Label` floated above the focused
interactable by `interaction_detector`) sat at `z_index 0` — the same z as the gate's `Doorway`/`DoorwayInner` `ColorRect`s
(`entities/gate/extract_gate.tscn`), so the door drew over it. Separately, the HUD `ExtractPrompt` (`ui/hud/extract_prompt.gd`,
in `decision_hud`) hardcoded its glyph to **"E"** — stale since the L1 (M1.5) remap moved `interact` to **F** — so the on-screen
extraction key disagreed with the actual binding.

**Fix:**
- `ui/interaction_prompt.tscn`: root `Node2D` → `z_index = 100`, `z_as_relative = false` (absolute z above world geometry), so
  the floating "[F] …" prompt always renders above the gate door + walls.
- `ui/hud/extract_prompt.gd`: derive `key_glyph` from the real `interact` binding at `_ready` (`_derive_key_glyph()`, mirrors
  `InteractionPrompt._derive_key_hint`), so the HUD CTA reads **"Press F to Extract…"** and never drifts from the keymap.

## FB2 — quota always MISSED even with more than the $50 bar

**Symptom (Director):** the quota reads MISS on every run, even when the haul exceeds the initial $50 quota.

**Root cause (M1.6 regression):** the play preset uses `quota_basis = cumulative_money`, so `_evaluate_quota` computes
`achieved = money`. In M1.6 the haul is **held** (`banked_junk`, unsold) until the Shop, and `evaluate_quota_on_return()` fires
on the guaranteed Hub-return beat **before** any sale — so `money` excludes this run's haul → `achieved = 0` → always MISS.
(The pre-M1.6 flow sold first, so `money` already included the haul when the quota was evaluated.)

**Fix (`systems/game_state.gd`):** added `_held_haul_value()` (sums `base_sell_value` over the live `banked_junk` pile) and
made the `cumulative_money` basis `achieved = money + _held_haul_value()`. On the sell path the pile is already emptied before
`_evaluate_quota`, so `_held_haul_value()` returns 0 and that path stays `achieved = money` exactly (no behaviour change).
`evaluate_quota_on_return()` simplified to reuse the helper. `this_run_banked` basis unchanged (reads the held haul as before).

## Tests / checks (all green; `godot --headless`, one instance at a time)

- New regression **Case 7** in `tests/test_quota_system.gd`: Hub-return cumulative basis with `money=0` + a held $60 item →
  **met** (`achieved=60`). Previously MISS. → `QUOTA OK`.
- Full invariant gate after the fixes: import clean · `ci_smoke_test` SMOKE OK · `test_corridor_lever` fp **`e943ac9c8bc1`**
  byte-match · `test_config_menu` **89/89** · `test_run_config` 89 · `test_app_router` OK · `test_main_game_loop` OK ·
  `test_save_migration` v1/v2/v3→v4 OK · `test_shop_economy` OK · `test_rg1_m15_verify` OK.

## Design deviations

None. UI-only z/glyph change + a run-state quota-math correction; no generation touched (fp unmoved), no RunConfig knob
(89 held), no save-schema change, `run_ended` arity untouched. Changelog: no new entry — both are fixes to behaviour already
described for M1.6 (changelog scope rule: don't add FIXED lines for in-version fixes).

## FB3 — current quota not visible (couldn't see the bar / how much I need)

**Symptom (Director):** "I can't see the current quota, or how much I need. Add that under the holding text."

**Root cause:** the HUD `QuotaLabel` (K2, M1.4 — "Run N · Quota: $have / $need") already existed but was anchored to the
**bottom-right** (`anchors_preset=3`), not under the L3-relocated top-right "Holding:" label, so it read as missing. Worse,
its `have` projected **`money` only** — excluding the haul you're carrying — so post-FB2 it would show e.g. "$0 / $50" while
you held $60 and then passed (the same confusion FB2 fixed).

**Fix:**
- `ui/hud/decision_hud.tscn`: moved `QuotaLabel` to the top-right directly under `HaulValueLabel` (`anchors_preset=1`,
  `offset_top=100`/`offset_bottom=126`, same right edge, right-aligned).
- `ui/hud/decision_hud.gd`: `have = GameState.money + GameState.run_haul_value()` (what the run would bank toward the
  cumulative quota at extract — matches the FB2 held-haul logic) and refresh it on `run_inventory_changed` so it tracks live
  as you grab/drop. Still gated on `quota_enabled` (all-off run → hidden, M1.0 HUD).

Verified: import clean; fp `e943ac9c8bc1`; 89/89; router/loop/quota/smoke green. Pure HUD projection — no GameState/save/knob change.

## Files touched

- `ui/interaction_prompt.tscn` (FB1 z-order)
- `ui/hud/extract_prompt.gd` (FB1 derive glyph)
- `systems/game_state.gd` (FB2 `_held_haul_value()` + cumulative-basis fix + `evaluate_quota_on_return` simplify)
- `tests/test_quota_system.gd` (FB2 Case 7 regression)
- `ui/hud/decision_hud.tscn` (FB3 QuotaLabel reposition under Holding)
- `ui/hud/decision_hud.gd` (FB3 quota `have` = money + haul, live-refresh)

## FB4 — hub controls list + changelog

**Director:** "In the hub, add text for all the controls inputs." + "ensure the changelog is updated."

**Fix:**
- `scenes/hub/hub.tscn`: added a `ControlsLabel` to the hub `HudLayer` (bottom-left, outlined, multi-line) listing the full
  scheme decoded from `project.godot` `[input]` + the L1/L6 mouse/stick design: Move (WASD/Arrows/Left stick), Aim
  (Mouse/Right stick), Throw (Left-click/Space/RT), Cycle item (Mouse wheel/Q·E/LB·RB), Interact·Extract (F / A),
  Pause (Esc/Start), Debug menu (P). Static help text (matches the hub's existing inline labels; greybox).
- `changelog.txt` (M1.6 "THE HUB" section): added the on-screen-controls bullet + a line that the HUD now shows the current
  quota (have vs need) under "Holding:" (folds in FB3 as a player-facing note, per the changelog scope rule — feature
  descriptions updated in place, no FIXED entries for the in-version FB1/FB2/FB3 fixes).

Verified: import clean; `test_app_router` (boots the hub) OK; smoke OK. Pure hub HUD text + docs — no system/save/knob/fp change.

Files (FB4): `scenes/hub/hub.tscn`, `changelog.txt`.
