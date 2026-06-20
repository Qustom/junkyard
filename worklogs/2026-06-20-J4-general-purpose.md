# Worklog — J4 Configurable hallway length + corridor telemetry

- **Date:** 2026-06-20
- **Subagent:** general-purpose
- **Milestone:** M1.3 (Wave 2 — Density & spatial; the last Wave-2 task)
- **Branch:** general-purpose/J4-hallway-length
- **Commit:** 3db5d19435363dbf566a7c14f516ae53eb8d02bd

## What changed
Built J4 to the LOCKED Director Disposition (2026-06-19 FINAL): the corridor-length lever is a
**generator down-weight/drop** (Option b/c), NOT the rejected materialise re-pack. Two halves:

- **Half A — corridor-rarity generator lever.** Two `RunConfig` `lvl_` knobs: the continuous
  `lvl_corridor_weight_mult: float = 1.0` (multiplies the corridor family's catalog weight down)
  and the boolean `lvl_short_corridors: bool = false` (zeroes/drops the 16-cell `piece_corridor_long_h`).
  Applied inside `band_generator.gd`'s `_build_weight_table` (the weighted-pick path) via the
  shared hardcoded `RunConfig.CORRIDOR_PIECE_IDS` set. The neutral default (1.0 / false) leaves the
  weight table byte-identical → the all-off fingerprint stays `e943ac9c8bc1`; a non-neutral config
  legitimately MOVES `fingerprint()` (config-keyed, allowed under the seed+config contract, like R4).
  Works R4-on (the weighted draw runs in both modes), so no re-pack and no JunkPlacer seam.
- **Half B — per-frame corridor-time telemetry.** Hoisted the `_player_piece_index` update OUT of
  the R4-gated `_maybe_emit_branch_taken` into a new always-run `_update_player_piece(cell)` (one
  source of truth; only the `nav_branch_taken` emit stays R4-gated). Built `_piece_kind_by_index`
  (index → is_corridor) in `_build_junction_map`'s pass, keyed on `PlacedPiece.piece_id` via
  `CORRIDOR_PIECE_IDS` — **no aspect-ratio fallback** (it mis-classifies the 6×6 L-bend; Phase-3
  correction). Per-frame `_accumulate_piece_time(delta)` runs in `_physics_process` BEFORE the
  depth-tick throttle (exact), banking to `_corridor_time_s` / `_room_time_s` (reset per run in
  `_build_cell_depth_map`). On run end (`_on_run_ended`) MainGame emits the pre-declared
  `EventBus.corridor_time_summary(corridor_s, room_s)`; Telemetry's new `_on_corridor_time_summary`
  writes an additive `CORRIDOR_SUMMARY` JSONL row `{corridor_s, room_s, corridor_frac}` and flushes.
  `SCHEMA_VERSION` stays 1; the `run_ended` signal + row arity are untouched.

Mechanism shipped: **BOTH** the continuous `lvl_corridor_weight_mult` (primary) **and** the boolean
`lvl_short_corridors`. Generator lever touches `systems/bandgen/band_generator.gd` ONLY
(`generate()` threads `rc` into `_build_weight_table`, which applies the corridor knobs).

The default play-preset biases toward fewer/shorter corridors (Director Q-F): preset sets
`lvl_corridor_weight_mult = 0.5` + `lvl_short_corridors = true`. The CODE-level all-off default
stays neutral (1.0 / false) — the permanent control.

## Files touched
- `data/run_config/run_config.gd` — 2 new `lvl_` knobs + `to_flat_dict()` entries; shared
  `CORRIDOR_PIECE_IDS` / `CORRIDOR_LONG_PIECE_ID` consts; preset biases corridors down.
- `systems/bandgen/band_generator.gd` — `generate()` threads `rc` into `_build_weight_table`, which
  down-weights / drops corridor pieces (neutral default = byte-identical table). THE ONLY generator-
  lever file.
- `scenes/game/main_game.gd` — `_piece_kind_by_index` + accumulators; `_update_player_piece` hoist;
  `_accumulate_piece_time` per-frame in `_physics_process`; classify in `_build_junction_map`; reset
  in `_build_cell_depth_map`; emit `corridor_time_summary` in `_on_run_ended`.
- `systems/telemetry/telemetry_schema.gd` — additive `CORRIDOR_SUMMARY` event-type string (v stays 1).
- `systems/telemetry/telemetry.gd` — connect + `_on_corridor_time_summary` → emit the row + flush.
- `ui/config/config_menu.gd` — MANIFEST["lvl_"] += both knobs; `RANGE_CORRIDOR = Vector2(0,1)` +
  FIELD_RANGE / FIELD_STEP (0.25) for the float.
- `ui/config/config_strings.csv` — labels for both new fields.
- `tests/test_run_config.gd` — expected_keys += 2 (now 46); new Case 10 (J4 neutral default +
  preset bias + flat-dict coverage).
- `tests/test_config_menu.gd` — knob count 44 → 46.
- `tests/test_corridor_lever.gd` + `.tscn` + `.uid` — NEW focused J4 test (fp neutral byte-match,
  non-neutral moves+deterministic, long-hall drop, accumulator bucketing + index<0 guard, hoist
  works R4-off, L-bend classifies as corridor).
- `tests/test_corridor_summary_row.gd` + `.tscn` + `.uid` — NEW end-to-end: a real run emits a
  `corridor_summary` row with corridor_frac, schema/arity intact.

## Checks run
- [x] `godot --headless --import` clean (no parse errors).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK (exit 0).
- [x] `test_rg1_m12_verify` → **VERIFY OK; all-off control byte-identical to baseline (fp=e943ac9c8bc1)** — CRITICAL.
- [x] `test_run_config` → R0 OK; **all 46 knobs** flat+JSON-safe; J4 Case 10 green.
- [x] `test_config_menu` → CONFIG MENU OK; **46/46 knobs bound + reachable**; `has_full_coverage()` passes.
- [x] `test_hazard_spread` (J2) → J2 OK (unaffected). `test_per_room_density` (J3) → J3 OK (unaffected).
- [x] `test_corridor_lever` (J4) → J4 OK. `test_corridor_summary_row` → J4-ROW OK (corridor_summary row emits).
- [x] `test_bandgen_determinism` → fp=e943ac9c8bc1. `test_level_scale_determinism` → ext fp=d7c249c3584b (both unmoved).
- [x] Definition of done met: "the knob exists, is reachable from CFG, shortens corridor traversal
  independently of room size (generator down-weight), the all-off default reproduces the M1.2
  baseline (fingerprint), and a corridor-time metric appears in the JSONL as an additive payload
  (no schema bump, no run_ended arity change)."

## Design deviations
**none** — built to the locked Director Disposition (Option b/c generator down-weight, telemetry-only
`main_game.gd` footprint, hoist, hardcoded piece-id classification with the aspect-ratio fallback
dropped). Shipped both levers (the continuous weight-mult as primary + the short-corridors bool) as
the spec invited ("add lvl_short_corridors too only if cheap" — it was a few lines in the same path).
The corridor lever MOVES `fingerprint()` for non-neutral configs (correct + expected, like R4); the
neutral default is byte-identical, asserted by `test_corridor_lever` + `test_rg1_m12_verify`.

## Handoffs / follow-ups
- Did NOT merge to `main` — orchestrator verifies topology + merges (single Wave-2 `main_game.gd`
  owner integrates J2+J3+J4).
- Preset corridor values (0.5 / drop-long) are Director SWEEP starting points (Q-F / Q-C), to be
  tuned in RG1/RG2 against the new `corridor_frac` metric — not balanced absolutes.
