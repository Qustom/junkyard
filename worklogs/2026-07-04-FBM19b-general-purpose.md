# Worklog — FBM19b Oppositions tab: surface deck-spawned hazards' knobs

- **Date:** 2026-07-04
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.9 (post-SG1 Director request)
- **Branch:** general-purpose/FBM19b
- **Commit:** 923fd7511e42b8eb2b2b1a8a3ef47e99ac40994e (+ the worklog-SHA amend commit)

## What changed
The Director opened the Oppositions tab to tune the two Sump hazards and couldn't
find/trust the knobs: deck-spawned defs (charger/splitter — spawned by band_two's
`opposition_deck`, never in `oppositions_enabled`) showed the misleading "OFF" chip
and defaulted collapsed. Presentation-only fix in `config_menu.gd`:
1. **Deck-membership scan** (`_load_deck_membership`, build-time, display-only): every
   `res://data/bands/*.tres` loading as a `BandProfile` contributes def id → {band id,
   display name} per `opposition_deck` row (DeckEntry wrappers unwrapped via `entry.def`);
   fail-soft `push_warning` skip on a non-loading profile; `bands_dir` test hook mirrors
   `defs_dir`.
2. **Honest chip** (`_refresh_def_chip`): not-enabled + deck-listed → `CFG_DEF_CHIP_DECK`
   ("IN DECK: {bands} · {n} tuned") with the band display names in the chip tooltip
   (`CFG_DEF_CHIP_DECK_TIP`; chip label gets `MOUSE_FILTER_PASS` so the tooltip can show).
   Truly nowhere-spawning defs (splitter_child) keep OFF; enabled defs keep ENABLED·n.
3. **Auto-expand** (`_def_section_active`): deck-listed sections start EXPANDED (default
   only — folding stays available). Staging/precedence untouched: `_stage_override` →
   `rc.param_overrides` still wins per def < deck-entry < rc.
4. **End-to-end proof** (test_def_menu_coverage case E): chip text/tooltip + fold/visible
   assertions for charger/splitter (deck-listed) vs splitter_child (nowhere-spawning);
   then the four Director knobs staged via the MENU path (charger `aggro_range`=200 +
   `charge_speed`=700, splitter `aggro_radius`=300 + `move_speed`=120) and the
   EncounterBuilder deck lane run on the REAL band_two (seed 12345, FakeSpawnService
   recorder) — resolved ctx params carry the staged values ON TOP of the D-RAT-2
   deck-entry layer (throwable_while_charging=false / wall_crash_recover_mult=2.0
   intact), with `oppositions_enabled` still empty.

## Files touched
- `Game/ui/config/config_menu.gd` — BANDS_DIR const + `bands_dir`/`_def_deck_bands` state;
  `_load_deck_membership()` + `_deck_bands_for()`; deck branch in `_refresh_def_chip`
  (+ tooltip, cleared in the other branches); deck-listed term in `_def_section_active`;
  chip `mouse_filter = PASS`; doc-comment updates.
- `Game/ui/config/config_strings.csv` — `CFG_DEF_CHIP_DECK`, `CFG_DEF_CHIP_DECK_TIP`.
- `Game/tests/test_def_menu_coverage.gd` — case (E) + FakeSpawnService recorder class +
  `_def_by_id` helper; header doc + OK message updated.

## Checks run
- [x] `godot --headless --path Game --import` clean
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `test_def_menu_coverage` → OK (cases A–E; E is the new FBM19b proof)
- [x] `test_config_menu` → OK (91/91 knobs bound + reachable — RunConfig untouched)
- [x] `test_deck_entry` → S9 OK (precedence + D-RAT-2 + fp guards)
- [x] `test_opposition_def_schema` → OK (7 defs — defs untouched)
- [x] `test_run_config` → R0 OK
- [x] `test_bandgen_determinism` → OK, all-off fp `e943ac9c8bc1` byte-identical
- [x] `test_corridor_lever` → J4 OK, neutral fp byte-matches `e943ac9c8bc1`
- [x] Definition of done: "deck-spawned defs' sections show the deck state instead of OFF,
  start expanded, and the four Director knobs staged via the menu reach the deck lane
  end-to-end; only config_menu.gd, config_strings.csv and tests touched; all listed
  tests + import + smoke green; all-off fp unchanged" — met.

## Design deviations
none — Director-directed presentation task; no departures from the FBM19b brief.
(Note, not a deviation: the not-enabled body dim (DIM_ALPHA) is kept even for
deck-listed defs — the dim channel mirrors the STAGED-ENABLE state per the
redundant-cue rules; the chip text is the honest deck channel. Flagged here in case
the Director wants deck-listed bodies undimmed too.)

## Handoffs / follow-ups
- If a future band ships with a broken profile, the menu warns + skips it (fail-soft);
  the deck chip simply omits that band — the builder's own fail-loud still covers
  generation.
