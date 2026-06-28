# Worklog — N2 Debug "disable player art" toggle (Meta tab)

- **Date:** 2026-06-27
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.7 (Player Embodiment) — last build task
- **Branch:** general-purpose/N2
- **Commit:** 5f57846ad887a92c54d45daa685bd8e8b2f9f399

## What changed
Added a view-only **"Player art (debug)"** `CheckButton` to the ConfigMenu **Meta tab**
(above the web-only telemetry-export button, per the Director disposition). On `toggled` it
emits `EventBus.debug_player_art_toggled(enabled)`; the N1 `PlayerVisual._on_art_toggled`
listener (already on `main`) swaps `AnimatedSprite2D` ↔ greybox `Visual`/`Nose`. The toggle
is **session-only** (no save write / no schema bump), **defaults checked = art ON** (matches
the player scene's art-on default — no boot emit), and is built by its own method that
**never** writes `_rows` / `MANIFEST` / a `SECTIONS` master, so it is invisible to
`has_full_coverage()` — the 89-knob count and the determinism fingerprint are untouched.
Menu-only, no hotkey. N0 (signal) + N1 (player listener) already on `main`; N2 wired only the
menu side + the CSV string. The player was NOT touched.

## Files touched
- `Game/ui/config/config_menu.gd` — new `_build_debug_player_art_toggle(parent)` +
  `_on_debug_player_art_toggled(enabled)`; hooked into the `prefix == ""` (Meta) branch of
  `_build_section_into`, appended *before* `_build_meta_export_button`. Not added to
  `_rows`/`MANIFEST`/`SECTIONS`.
- `Game/ui/config/config_strings.csv` — one new row `CFG_DEBUG_PLAYER_ART,Player art (debug)`.
- `Game/tests/test_config_menu.gd` — added a permanent N2 regression block: the toggle exists
  on the Meta tab, defaults checked, and is NOT in `_rows` (so it can never inflate coverage).

## Checks run
- [x] `godot --headless --path Game --import` clean (CSV reimported; no parse errors; EXIT 0).
- [x] `godot --headless --path Game res://tests/test_config_menu.tscn` → **CONFIG MENU OK —
      89/89 knobs bound + reachable**; the new N2 assertions (toggle present, default checked,
      outside `_rows`) all pass. EXIT 0.
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` →
      **SMOKE OK — M0 architecture spike healthy**. EXIT 0.
- [x] `godot --headless --path Game res://tests/test_rg1_m15_verify.tscn` →
      **RG1 M1.5 VERIFY OK** — all-off control byte-identical to the locked baseline
      (**fp=e943ac9c8bc1**, unmoved). EXIT 0.
- [x] Config-menu scene instantiates headless without error: `test_config_menu.tscn` loads the
      real `ConfigMenu` PackedScene (autoloads resolved), builds the full UI including the new
      Meta-tab toggle, and asserts coverage — green. (A throwaway bare-`SceneTree` `--script`
      probe failed with "Identifier not found: EventBus" — that is the probe's own
      missing-autoload limitation, NOT a code fault; the scene-run test is the authoritative
      load check and it passes.)
- [x] definition of done met: "A view-only `CheckButton` on the Meta tab, label
      'Player art (debug)', CSV key `CFG_DEBUG_PLAYER_ART`, default checked = art ON,
      session-only, emitting `EventBus.debug_player_art_toggled(enabled)` on toggle, NEVER added
      to `_rows`/MANIFEST/SECTIONS so coverage stays 89 and fp stays `e943ac9c8bc1`."

## Hard constraints — honored
- **89-knob count + coverage assertion unchanged** — toggle is OUTSIDE `MANIFEST`/`_rows`/
  `SECTIONS` masters; test reports 89/89.
- **All-off determinism fp `e943ac9c8bc1` unmoved** — toggle mutates no `_cfg` field, never
  calls `_set_field`; `apply_and_get_config()` returns an unchanged RunConfig.
- **Session-only** — no save-schema touch, no `schema_version` bump, no migration fixture.
- **Default = art ON** — CheckButton `button_pressed = true` ⇄ player scene art-on default; no
  boot emit.

## Design deviations
none — implemented exactly per the locked N2 spec + Director disposition (label
"Player art (debug)", placed above the web-only export button, session-only, default art ON).
The N1 `PlayerVisual._on_art_toggled` listener was confirmed already connected on `main`
(`player_visual.gd:85`), so the player was not touched.

## Handoffs / follow-ups
- **RG1 / manual:** the live art↔greybox swap in the Hub + Dive cannot be exercised headless
  (no render, and the P-overlay menu can't be driven without a viewport). Flag for the RG1
  manual playtest: open the P-menu → Meta tab → toggle "Player art (debug)" off/on and confirm
  the player swaps to the greybox (Visual + Nose) and back, in both Hub and Dive.
