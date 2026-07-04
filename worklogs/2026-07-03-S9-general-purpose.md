# Worklog — S9 Deck-entry override wrapper (D-RAT-2 delivery)

- **Date:** 2026-07-03
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.9 (Wave 5, ∥ S8)
- **Branch:** general-purpose/S9
- **Commit:** ac289db05f9564f3284af3457480beaeaf86e4e0

## What changed
D-RAT-2 ratified the Charger as dash-invulnerable in band_two's deck with wall-crash
bonus-stun 2.0, but S7's deck was a plain `Array[Resource]` of defs with no override
mechanism. Built the Director-chosen wrapper: a new `DeckEntry` Resource (`def` +
`param_overrides`) accepted in `BandProfile.opposition_deck` MIXED with plain defs
(back-compat); the EncounterBuilder deck lane unwraps wrappers for gating/costing/
ordering and merges overrides at ctx time with the locked precedence **def params <
deck-entry overrides < rc.param_overrides**. band_two's charger row is rewrapped with
`throwable_while_charging=false` / `wall_crash_recover_mult=2.0`; the other 5 rows stay
plain refs; charger def defaults stay D-RAT-2-letter (`true`/`1.0`, pinned by
`test_charger` — untouched).

## Files touched
- `Game/data/bands/deck_entry.gd` (+ `.uid`) — NEW: `class_name DeckEntry extends Resource`;
  `@export var def: Resource` (OppositionDef, Resource-typed per the S1 Q5 deck convention)
  + `@export var param_overrides: Dictionary` (String key → primitive).
- `Game/systems/spawning/encounter_builder.gd` — `_authored_deck()` unwraps DeckEntry rows
  (fail-loud on broken wrappers; first-wins dedup keeps the FIRST row's overrides) and fills
  a `deck_overrides` bag (def id → overrides); `populate()` threads it into `_populate_deck()`
  (new optional param, default `{}`); `_effective_params()` gains the middle merge layer
  (def params → deck-entry overrides → rc.param_overrides, keys normalized to String).
  Extras (`rc.oppositions_enabled`) carry no deck overrides. Legacy lane untouched.
- `Game/data/bands/band_two.tres` — charger deck row (was ExtResource 15 plain ref) rewrapped
  as an embedded `DeckEntry` sub-resource with exactly the two D-RAT-2 override values;
  load_steps 21→23; deck order unchanged `[pursuer, pingpong, bomb, spike, charger, splitter]`.
- `Game/tests/test_band_two_profile.gd` — extended ADDITIVELY: C0/C6 unwrap deck rows via a
  `_deck_def()` helper (plain OR wrapper); new C0/S9 pins: exactly ONE wrapper (the charger
  row), carrying exactly the 2 D-RAT-2 values; all prior assertions kept.
- `Game/tests/test_deck_entry.gd` / `.tscn` (+ `.uid`) — NEW run-as-scene test, cases (a)–(e):
  (a) empty-overrides wrapper ≡ plain ref (byte-identical ordered plan); (b) precedence chain
  proven per-layer (exclusive keys survive, contested keys resolve outward; deck override
  reaches the count math via `base_count`); (c) real band_two + BandPipeline: every charger
  instruction's resolved params == def params + exactly the 2 D-RAT-2 values, non-charger
  rows byte-equal their defs, and rc.param_overrides still wins on top of the wrapper;
  (d) mixed-array: order preserved, override binds only to the wrapped row, first-wins dedup
  incl. overrides both directions, broken wrapper (null def) fail-louds + skipped;
  (e) fp guards: all-off pipeline pins `e943ac9c8bc1`, greybox all-off inert, band_two layout
  generation deterministic post-rewrap.

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `test_deck_entry` → S9 OK (new)
- [x] All-off fp + greybox parity byte-identical: `test_bandgen_determinism` (fp
  `e943ac9c8bc1`), `test_corridor_lever` (neutral fp byte-match), `test_band_pipeline_parity`
  (9 seeds byte-match) — all green
- [x] `test_band_two_profile` → BAND_TWO OK (deck assertions extended additively, not weakened)
- [x] `test_encounter_builder` → S3 OK (preset byte-parity + all cases)
- [x] `test_charger` → S6a OK (def defaults still `true`/`1.0` — pin intact, def untouched)
- [x] `test_splitter` → S6b OK
- [x] `test_opposition_def_schema` → DEF SCHEMA OK (7 defs)
- [x] Definition of done met: "all-off + greybox fps byte-identical;
  `test_band_two_profile`/`test_encounter_builder`/`test_charger` green (charger def defaults
  still D-RAT-2-letter — the test pins them); new `test_deck_entry` green; worklog + commit."

## Design deviations
none — built to the TASKS §S9 contract letter (wrapper shape, mixed-array back-compat,
precedence order, D-RAT-2 values, empty-overrides byte-parity, def defaults untouched).
Two implementation notes (in-contract, recorded for the as-built):
- The band_two wrapper is an embedded sub-resource of `band_two.tres` (not a standalone
  `.tres`) — a deck-row override is deck-local data, not shareable content; the contract
  specified no placement.
- `deck_overrides` is keyed by def id (StringName), populated only for non-empty override
  bags — so an empty-overrides wrapper takes the byte-identical code path of a plain ref.

## Handoffs / follow-ups
- S8 integration: no shared surfaces touched (`main_game.gd`, hub scenes, `app.gd`,
  `game_state.gd`, `event_bus.gd`, telemetry all untouched); merge order vs S8 is free.
- The S1 Q5 "retighten `opposition_deck` typing post-integration" follow-up now also covers
  DeckEntry (a typed union isn't expressible; `Array[Resource]` remains the honest type).
- Charger runtime consumption of the ctx-merged params is S6a's existing
  `setup(cfg, player, spawn_ctx)` seam — verified plan-side here; the live-band behavior
  check rides SG1's full verify matrix as planned.
