# Worklog — M4 Debug-menu rework (P-key + tabs)

- **Date:** 2026-06-26
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.6 (Surface & Staging), Wave 2
- **Branch:** general-purpose/M4
- **Commit:** 1d0c0dc213d5bc9847a9335f3ec846d43d56a9c5 (worklog SHA noted post-amend; tree content final)

## What changed
Re-homed the pre-run config rail (`ConfigMenu`) as a P-toggle, 7-tab debug overlay mounted
once on `App.DebugOverlay` (RD-7), available in Menu/Hub/Dive. Restructured the single scroll
into a 7-tab `TabContainer` (RD-2) with the `r4_` vision/fog rows split into their own Vision
tab via the **Option A** render-time sub-list (`R4_VISION_FIELDS` + master-less `"r4_vision_"`
pseudo-section, RD-1) — **no field renamed, no new master, no knob added/removed**, so the
89-field coverage `bound` set is byte-identical. Added pause-in-dive (RD-3), `r4_enabled`
dual-dim across the maze + Vision bodies (RD-5), and re-homed the web telemetry-export button
into the Meta tab (RD-9 fallback slot, web-guarded).

## Files touched
- `ui/config/config_menu.gd` — added `R4_VISION_KEY`/`R4_VISION_FIELDS`/`TABS` consts; trimmed
  `MANIFEST["r4_"]` to maze rows; rebuilt `_build_ui` as a `TabContainer`; factored
  `_build_section` → `_build_section_into(parent, section_key)` + a master-less
  `_build_vision_pseudo_section`; added `_section_descriptor`, `_dim_bodies_for` (dual-dim for
  r4_), the P-toggle (`_unhandled_input`/`_toggle_overlay`/`_pauses_dive`, `PROCESS_MODE_ALWAYS`,
  `visible=false`, `_paused_by_overlay` restore-only-our-pause), and the Meta-tab telemetry
  export button (`_build_meta_export_button`/`_on_export_telemetry_pressed`, `TelemetryExporter`).
- `scenes/app/app.gd` — **minimal mount edit**: `DEBUG_MENU_PATH` const + `_mount_debug_overlay()`
  called in `_ready`, instancing `config_menu.tscn` once under `$DebugOverlay`.
- `ui/config/config_strings.csv` — added 7 `CFG_TAB_*` keys + `CFG_SEC_R4_VISION`/
  `CFG_GLOSS_R4_VISION`/`CFG_R4_VISION_GATED` + 3 `CFG_EXPORT_*` keys; re-narrowed `CFG_GLOSS_R4`
  to maze-only wording (kept the `CFG_SEC_R4` title per RD-8). No key removed/renamed.

## Checks run
- [x] `godot --headless --import` clean (no parse errors; only pre-existing first-pass
      `.translation` not-yet-generated notices, gone on second import).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK**
- [x] `godot --headless res://tests/test_config_menu.tscn` → **CONFIG MENU OK — 89/89 knobs
      bound + reachable** (the key coverage gate; `has_full_coverage()` true).
- [x] `godot --headless res://tests/test_run_config.tscn` → **R0 OK — all 89 knobs** present.
- [x] `godot --headless res://tests/test_corridor_lever.tscn` → **J4 OK — fp e943ac9c8bc1
      byte-matches** the locked all-off baseline (no generation touched).
- [x] `godot --headless res://tests/test_app_router.tscn` → **ROUTER OK** (still green with the
      overlay mounted on `App.DebugOverlay`; menu→hub→dive→hub, current_state correct).
- [x] Definition of done met: P opens/closes the tabbed menu in all 3 states (mounted on
      App.DebugOverlay); Vision is its own tab/section, maze rows stay in Level Gen, no `r4_`
      field renamed; `has_full_coverage()` + both 89-count tests green; pause-in-dive freezes
      the clock (DiveClock is `PROCESS_MODE_PAUSABLE`, confirmed in `systems/dive_clock.gd:40`);
      telemetry-export works from the Meta tab (web-guarded); all-off fp byte-identical.

## How Option A kept coverage byte-identical
`has_full_coverage()` builds `bound` = every `_rows` key + every non-empty `SECTIONS[*].master`
— never off `MANIFEST`/tab grouping. Under Option A: `SECTIONS["r4_"]` is unchanged → `r4_enabled`
stays the lone r4 master in `bound`; the 4 vision fields still each get one `_build_row` → one
`_rows` entry (now via `R4_VISION_FIELDS` instead of the `MANIFEST["r4_"]` tail). So the field-name
set is member-for-member identical → 89/89, fp untouched. `"r4_vision_"` is a body/dim key only;
it is NOT in `_prefix_of` and registers no chip, so the vision rows route their chip/summary
through the existing `"r4_"` prefix (the single R4 ON/OFF chip in Level Gen stays authoritative).

## Design deviations
none. Every call follows the locked Resolved Decisions (RD-1 Option A, RD-2 7-tab map with
`exit_` in Throw & Camera, RD-3 pause-in-dive + DiveClock pausable, RD-4 next-Start apply, RD-5
dual-dim + gloss cue, RD-6 in-session tab memory, RD-7 single mount on App.DebugOverlay, RD-8
re-narrow gloss / keep title, RD-9 Meta-tab export fallback slot).

## Handoffs / follow-ups
- **M2 coordination:** the embedded `%ConfigMenu` mount in `main_game.tscn` is being removed by
  M2 in parallel; the config menu is now the App-overlay instance. M2's dive-only `main_game`
  reads config via `GameState.dive_config_or_default()` (the overlay's Apply stages it) — the
  overlay's `apply_and_get_config()` is the single persistent instance the dive should read at
  start. No direct `%ConfigMenu` NodePath should remain in `main_game` after M2.
- **RRD-A (Director, M3's call):** the web Export-telemetry button is re-homed into the Meta tab
  here as the RD-9 *fallback* slot. If the Director prefers it in M3's Shop (recommended,
  tester-facing), M3 can host it and this Meta-tab button can be dropped — no coverage impact
  either way (it never touches `_rows`).
