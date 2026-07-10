# Worklog — V3 Migrate the K5 fair-share hazard lane onto the deck lane

- **Date:** 2026-07-10
- **Subagent:** general-purpose
- **Milestone:** M1.12
- **Branch:** feat/V3-k5-migration
- **Commit:** 6e6c956233ddfabf1c5423764f3d7ad14fe67ad3   ← V3: migrate K5 fair-share lane onto the deck lane

## What changed

Retired the K5 fair-share hazard machine (`EncounterBuilder._populate_legacy` + `_legacy_active_specs`
+ `LEGACY_DEF_PATHS`) and the 21 bespoke `rc.hpp_/hbomb_/hspike_` RunConfig knobs. The three K5
hazards (pingpong / bomb / spike) are now pure `OppositionDef` + deck data like the six modern
hazards: `band_greybox` carries a real `opposition_deck`, per-room caps (2/2/1) + a fair-share slice
cap (`per_band_cap = 16`) ride the shared defs, and the play magnitudes ride the play preset's
`rc.param_overrides`. Added a content-data `BandProfile.opposition_credits` field (band_greybox = 48)
to preserve the historical K5 body density. Rewired the three entities to read `spawn_ctx["params"]`
(the charger pattern) instead of `cfg.h*_*`. This is M1.12's largest deletion and its ONE sanctioned
behavioural change (D-RAT-3): the greybox hazard-SPAWN sequence is now the deck spender, proven
equivalent to the old fair-share plan and re-pinned. Layout fingerprints stay byte-identical.

**Scope: K5 ONLY.** The R1 pursuer machine (`main_game.gd`, `rc.r1_*`) is untouched — that is task V3b.

## Chosen `opposition_credits` + K5 caps (for V3b to build on)

- **`band_greybox.opposition_credits = 48`** — mirrors the historical `NEW_HAZARD_BAND_CEILING` (48).
  It funds the full K5 body density; the budget never binds *below* the caps.
- **Binding constraint on K5 counts = the caps, not the raw budget:** the `&"new_hazards"` cap-group
  ceiling (48) + per-room caps (pingpong/bomb 2, spike 1) + a `per_band_cap = 16` on each K5 def
  (the fair-share slice — `48 / 3`). `per_band_cap 16` is load-bearing: without it, the deck's
  draw-order (pingpong→bomb→spike) lets pingpong+bomb saturate the 48 cap-group on a deep band and
  starve spike to 0 (the old fair-share explicitly split 16/16/16). With it, each type is bounded at
  its 16-slice, exactly reproducing the fair-share.
- **Robust for V3b's bump:** V3b will BUMP `opposition_credits` (~55–65) to additionally fund the
  pursuer's ~15–25-body share (the pursuer has NO cap-group, so it is additive on top of the K5 48
  ceiling). Because the K5 caps (cap-group 48 + per-room + per-band 16) are the binding constraint,
  K5 counts stay ≤ 48 regardless of the bump — the field is robust to V3b raising it.

## K5 equivalence (deck vs frozen legacy fair-share plan @ play preset)

Golden captured BEFORE deletion (`tests/goldens/greybox_k5_legacy_plan.json`), then compared by
`tests/test_greybox_deck_equivalence.gd`. Bar (D-RAT-3a): exact type coverage + per-type ±15% +
entry-safe + caps + determinism + distribution ≥ as deep. Result — **EXACT (0.0% Δ) on all bands:**

| band | type | legacy | deck | Δ% | within ±15%? |
|---|---|---|---|---|---|
| small | pingpong / bomb / spike | 0 / 0 / 2 | 0 / 0 / 2 | 0.0 | yes |
| preset_deep (15-depth) | pingpong / bomb / spike | 9 / 9 / 14 | 9 / 9 / 14 | 0.0 | yes |
| realistic (~19-room) | pingpong / bomb / spike | 16 / 16 / 16 | 16 / 16 / 16 | 0.0 | yes |

## Layout fingerprints (HARD contract — all BYTE-IDENTICAL)

- **all-off / band_greybox** = `e943ac9c8bc1` (seed 12345, 12 pieces) — `test_band_pipeline_parity`
  `PIPELINE PARITY OK` + `test_encounter_builder` pins `e943ac9c8bc1`. `Band.fingerprint()` hashes
  only placed pieces; hazards are run-state, never feed it.
- **band_two** — `test_band_two_profile` OK (its neutral K5 refs + the on-def caps are inert for it).
- **band_three** — `test_band_three_profile` OK ("keeps band_greybox AND band_two byte-identical").
- No layout fp moved.

## Files touched

**Product code**
- `Game/systems/spawning/encounter_builder.gd` (+63 / −152) — deleted `_populate_legacy`,
  `_legacy_active_specs`, `LEGACY_DEF_PATHS`; `populate` is deck-only; `is_inert` → `_deck_all_neutral`
  fast-path (byte-exact all-off scene tree preserved); `_populate_deck` reads `opposition_credits`.
- `Game/data/run_config/run_config.gd` (+42 / −154) — deleted 21 `hpp_/hbomb_/hspike_` fields + their
  21 `to_flat_dict` stamp rows; `make_default_play_preset()` K5 block → `rc.param_overrides`.
- `Game/ui/config/config_menu.gd` (+9 / −44) — deleted the 3 K5 `SECTIONS`, 3 `MANIFEST` blocks, the
  Hazards-tab K5 half (r1_ kept), 14 `RANGES`, the reflection prefix entries.
- `Game/scenes/hazards/{pingpong,bomb,spike}_hazard.gd` — `_resolve_params(spawn_ctx)` reads
  `spawn_ctx["params"]` + a `DEFAULTS` mirror; `kills` entity-local (default true).
- `Game/data/bands/band_profile.gd` (+13) — new `@export var opposition_credits: int = 0` (content-data).
- `Game/data/bands/band_greybox.tres` — `opposition_deck` = [pingpong, bomb, spike]; `opposition_credits = 48`.
- `Game/data/oppositions/{pingpong,bomb,spike}.tres` — `per_room_cap` 2/2/1, `per_band_cap` 16.

**Tests (re-pinned / added)**
- NEW `Game/tests/test_greybox_deck_equivalence.gd`+`.tscn` (193 LOC) — the DR-3 equivalence proof.
- NEW `Game/tests/k5_equivalence_bands.gd` (65 LOC) — shared deterministic fixture bands.
- NEW `Game/tests/goldens/greybox_k5_legacy_plan.json` (126 LOC, data) — frozen pre-migration plan.
- Re-pinned: `test_new_hazard_spawn`, `test_encounter_builder` (legacy cases → greybox-deck case +
  deleted `_mirror_legacy_plan`), `test_config_menu` (89→68 / 91→70), `test_run_config`,
  `test_opposition_def_schema` (K5 mirror rows dropped), `test_{pingpong,bomb,spike}_hazard`,
  `test_opposition_components` (params via ctx — goldens byte-identical), `test_rg1_m14_verify`,
  `test_rg1_m15_verify`, `test_band_pipeline_parity` (P0 deck assertion), `test_def_menu_coverage`
  (band_two leak isolation), `test_cave_materialise` + `test_scatter_materialise` (synthetic profiles
  given a K5 deck — the legacy lane that used to populate their empty-deck bands is gone).

## Debt ledger

- **Removed:** the K5 fair-share machine (`_populate_legacy` ~64 LOC + `_legacy_active_specs` ~23 +
  `LEGACY_DEF_PATHS` ~8 + the legacy branch of `populate` + `is_inert`'s legacy clause); **21**
  `rc.hpp_/hbomb_/hspike_` knobs + their 21 telemetry stamp rows; the config-menu K5 plumbing (3
  sections + 3 manifest blocks + the Hazards-tab K5 half + 14 ranges + the reflection prefix list);
  the K5 entities' direct `cfg.h*_*` reads; the `test_encounter_builder` legacy mirror (~85 LOC).
- **The second hazard-adding path is gone** — the K5 trio is now added the same way as the six modern
  hazards (author a def, add a deck row). "Exactly one way to add an opposition" delivered for K5.
- **Config surface: 91 → 70 knobs (−21); legacy 89 → 68.** Three config sections + the Hazards-tab K5
  half disappear.
- **Net product-code LOC ≈ −201** (~−335 removed machine/knob/menu/preset code, against ~+70 deck/
  entity/field + ~+13 field additions). New *test* code ≈ +258 (equivalence test + shared bands) +
  126 data (the frozen fixture).
- **No save bump** — RunConfig is run-scoped, never persisted (grep-confirmed `META_SCHEMA_VERSION`
  is separate); dropping 21 `@export`s needs no meta migration. Meta stays v4.

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] **Full suite: 68/68 test scenes GREEN.** Key: `test_greybox_deck_equivalence` (EXACT 0.0% Δ),
  `test_new_hazard_spawn`, `test_encounter_builder`, `test_config_menu` (70/70 bound, counts 68/70),
  `test_run_config`, `test_band_pipeline_parity` (fp e943ac9c8bc1), `test_band_two_profile`,
  `test_band_three_profile`, `test_rg1_m14_verify`, `test_rg1_m15_verify`, the 3 K5 unit tests,
  `test_opposition_components` (goldens byte-identical), `test_cave_materialise`, `test_scatter_materialise`.
- [x] Definition of done: layout fps byte-identical; K5 equivalence proven + Director-facing evidence
  table produced; config bijection green at the reduced knob set; no save bump; full suite green.

## Design deviations
See `design/DESIGN_DEVIATIONS.md` (V3 entries). Two:
1. **`per_band_cap = 16` added to the K5 defs (not in the V3 design's step-4 letter).** The design
   put per-room caps on the shared defs but relied on the cap-group ceiling alone for the total.
   On a deep (~30-room) band the deck's draw-order lets pingpong+bomb saturate the 48 ceiling and
   starve spike to 0 — a coverage failure vs the old fair-share 16/16/16. `per_band_cap = 16` (the
   fair-share slice) restores per-type balance and makes equivalence EXACT. Inert for band_two
   (neutral cards). Recommend **Reviewed**.
2. **The play preset's `rc.param_overrides` (a global def-id lever) activates band_two's neutral K5
   deck cards if band_two is generated under the preset** — greybox K5 magnitudes "leak" onto
   band_two. Benign in M1 (band_two is never dived under the play preset; greybox is), and band_two's
   PROFILE stays byte-identical (`test_band_two_profile` green). `test_def_menu_coverage` (which
   artificially generates band_two under the menu's default preset) drops the greybox-only K5
   overrides to isolate its charger/splitter staging intent. This is inherent to the design's choice
   of `rc.param_overrides` (required so all-off = neutral = no hazards; baking magnitudes into the
   band would break the all-off baseline). Recommend **Reviewed** (surface to Director; note for V3b
   / future bands that share K5 def ids).

## Handoffs / follow-ups
- **V3b (pursuer/R1 → deck)** consumes the `opposition_credits` field authored here: BUMP
  band_greybox to ~55–65 to add the pursuer's ~15–25-body share (pursuer has no cap-group → additive
  on the K5 48 ceiling). The K5 caps (cap-group 48 + per-room + per-band 16) are the binding
  constraint on K5, so the bump only funds the pursuer. V3 + V3b must agree on the final number at
  the Wave-4 close-out.
- **DR-3 golden re-pin sign-off** stays formally open to the Wave-4 close-out — the equivalence table
  above + the frozen fixture are the evidence to present to the Director.
