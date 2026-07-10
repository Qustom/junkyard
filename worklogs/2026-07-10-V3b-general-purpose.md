# Worklog — V3b Migrate the R1 pursuer machine onto the deck lane

- **Date:** 2026-07-10
- **Subagent:** general-purpose (+ general-purpose sub-agent for the verify-matrix test re-points)
- **Milestone:** M1.12
- **Branch:** feat/V3b-pursuer-migration
- **Commit:** a697d87a225f0ecd229ec91fd82f76a685d2952d   ← V3b: migrate R1 pursuer machine onto the deck lane

## What changed

Retired the R1 pursuer's bespoke spawn machine (`main_game.gd` `_spawn_r1_hazards` + its J2
spread + J3 area-scaled density stack, ~291 net LOC) and the **18** `rc.r1_*` RunConfig knobs
(+ their telemetry rows, 2 density consts, 2 BUG6 traps, the whole `r1_` config-menu section,
and the now-empty Hazards tab). The pursuer is now a `band_greybox` **deck card** drawn through
EncounterBuilder's ONE credit machine — exactly like the K5 trio V3 migrated. With this, **all
three greybox spawn machines are unified onto the deck lane** and "exactly one way to add an
opposition" (a `.tres` def + a deck row) is FULLY delivered (D-RAT-3). This is M1.12's largest
deletion and the version's highest-risk migration: the deck lane is structurally less expressive
than the R1 machine (no J2 single_gate/curve modes — both preset-OFF, dropped safely; no J3
area-scaled per-room density — its bodies FOLD to the deck's even-spread, the one licensed
fidelity loss per D-RAT-3a). Layout fingerprints stay byte-identical; the pursuer behaviour trace
stays byte-identical (value-preserving entity rewire).

## Final `opposition_credits` + pursuer DeckEntry cost/cap + reconciliation with V3's 48

- **`band_greybox.opposition_credits = 48 → 58`** (D-RAT-8 target ~55–65). Computed from the
  frozen Step-0 fixture: K5 spends ≤48 (cap-group `new_hazards` ceiling 48 + per_band_cap 16 each)
  + the pursuer's ~10-body share = **58**. Reconciliation with V3's 48: **K5 counts are UNCHANGED**
  — K5 is bound by its cap-group ceiling (48) + per-band caps (16), NOT the raw budget, so raising
  the budget to 58 feeds ONLY the pursuer entry (`test_greybox_deck_equivalence` re-run: EXACT 0.0%
  Δ on all bands). V3 and V3b agree on **58** at the Wave-4 close-out.
- **Pursuer deck row:** `pursuer.tres` appended to `band_greybox.opposition_deck` as a plain
  `ExtResource` ref (matching V3's K5 pattern — its `param_overrides` bag is the play preset's
  `rc.param_overrides["pursuer"]`, kept off the shared def so band_two's neutral pursuer ref never
  spawns). **credit_cost = 1** (on the def). **`pursuer.tres.per_band_cap = 0 → 10`** — the
  reservation mechanism (OQ-H correction: `DeckEntry` has no `per_band_cap` field, so the max-bound
  rides the SHARED def; provably inert for band_two whose pursuer is neutral → skipped → the cap
  never binds).
- **Spawn tuning (play preset `param_overrides["pursuer"]`):** `base_count = 2`, `count_per_depth
  = 0.5` — tuned against the Step-0 fixture so the greybox pursuer per-type TOTAL lands within ±15%.
  Behaviour magnitudes (the most-fun ba745e1 cell, verbatim) + L2 room-bound patrol ride the same bag.

## Pursuer equivalence (deck vs frozen R1 J2+J3 plan @ play preset)

Golden captured BEFORE deletion (`tests/goldens/pursuer_r1_plan.json`) via a one-shot capture tool
driving the LIVE R1 machine, then compared by `tests/test_pursuer_deck_equivalence.gd`. Bar
(D-RAT-3a): exact type coverage + per-type ±15% + entry-safe + per_band_cap + L2 room-bounds
threaded + determinism + distribution ≥ as deep.

| band | fixture (J2+J3) | deck | Δ% | within ±15%? | L2 bounds threaded? |
|---|---|---|---|---|---|
| small | 5 (5+0) | 5 | +0.0 | yes | yes |
| preset_deep | 9 (5+4) | 10 | +11.1 | yes | yes |
| realistic | 10 (5+5) | 10 | +0.0 | yes | yes |

**Licensed fidelity loss (D-RAT-3a, documented):** the J3 per-room AREA-scaled density (big rooms
clustered more pursuers) has NO deck equivalent — those bodies fold into the deck's flat
even-spread. The per-type TOTAL is preserved (±15%); the big-room spatial clustering is NOT. The
`preset_deep` +11.1% is the density-fold surfacing (the deck even-spreads 10 where the R1 machine
placed 9 clustered). The J2 single_gate/curve depth modes are preset-OFF, so dropping them is
behaviour-preserving for the shipped config.

## `trace_pursuer_room.txt` byte-identity proof (the rewire-safety proof)

`hazard_entity.gd::_resolve_params(cfg)` → `_resolve_params(spawn_ctx)` now reads
`spawn_ctx["params"]` (the deck lane's ctx-merged bag) instead of `cfg.r1_*`, with the SAME
key-name mapping (`catch_radius→contact_radius`, `catch_radius_per_depth→contact_radius_per_depth`,
`catch_kills→kills`) and the L2 `spawn_room_only` snapshot. Because the resolved output dict is
value-identical, `test_opposition_components.gd` reports **all 5 entity traces byte-identical to
the pre-refactor goldens** — including **`trace_pursuer_room.txt` AND `trace_pursuer_chase.txt`
(300 frames each, byte-identical)**. A moved byte there would have been a rewire bug; none moved.

## Layout fingerprints (HARD contract — all four BYTE-IDENTICAL)

- **all-off / band_greybox = `e943ac9c8bc1`** — `test_band_pipeline_parity` `PIPELINE PARITY OK`
  (seed 12345, 12 pieces, fp=e943ac9c8bc1) + `test_encounter_builder` pins `e943ac9c8bc1`.
- **band_two** — `test_band_two_profile` OK (its neutral pursuer ref stays skipped; the
  `legacy_ctx` `&"pursuer"` room_bounds arm only fires for a NON-neutral pursuer).
- **band_three** — `test_band_three_profile` OK ("keeps band_greybox AND band_two byte-identical").
- No layout fp moved. `Band.fingerprint()` hashes only placed pieces; hazards are run-state.

## Files touched

**Product code (net −395 LOC)**
- `Game/scenes/game/main_game.gd` (+15 / −306) — deleted `_spawn_r1_hazards` + the J2/J3 machine
  (`_hazard_spawn_depths`, `_hazard_spawn_position`, `_populate_room_density`, `_density_spawn_positions`,
  `_density_spawn_bounds`, `_density_area`, `_piece_bounds_at_world`, `_piece_floor_bounds_world`,
  `_is_corridor`) + `HAZARD_SCENE_PATH` + the `:353` call. KEPT `_band_max_depth`,
  `_density_cell_to_world`/`_density_pieces_sorted`/`_density_sorted_cells` (now K7-exits-only),
  `_entry_spawn_position`.
- `Game/data/run_config/run_config.gd` (+53 / −156) — deleted the 18 `r1_*` @export fields + their
  18 `to_flat_dict` rows + 2 density consts + the 2 BUG6 R1 traps; `all_oppositions_disabled()` →
  `not (r2||r3||r4)`; the 18 preset assignments → `param_overrides["pursuer"]`.
- `Game/scenes/hazards/hazard_entity.gd` (+44 / −24) — `_resolve_params(spawn_ctx)` reads
  `spawn_ctx["params"]` + a neutral `DEFAULTS` mirror; L2 `_spawn_room_only` snapshot (was `cfg.r1_*`).
- `Game/systems/spawning/encounter_builder.gd` (+8) — the ONE `legacy_ctx` `&"pursuer"` arm.
- `Game/data/bands/band_greybox.tres` — `opposition_deck` += pursuer; `opposition_credits` 48 → 58.
- `Game/data/oppositions/pursuer.tres` — `per_band_cap` 0 → 10.
- `Game/ui/config/config_menu.gd` (+12 / −42) + `config_strings.csv` — deleted the `r1_` SECTIONS row,
  MANIFEST block (18), RANGES (10) + STEP + chip summary + `_prefix_of` prefix + the Hazards TAB;
  dropped the R1 flag from `CFG_RUN_SUMMARY`.

**Tests**
- NEW `Game/tests/test_pursuer_deck_equivalence.gd`+`.tscn` (210 LOC) — the D-RAT-3a pursuer proof.
- NEW `Game/tests/goldens/pursuer_r1_plan.json` (46 LOC data) — the frozen pre-migration plan.
- DELETED `test_hazard_spread.gd` (180) + `test_per_room_density.gd` (239) — their J2/J3-machine
  goldens are gone; the surviving concerns fold into the equivalence test.
- Re-pointed: `test_opposition_components` (2 pursuer traces → ctx["params"]; goldens byte-identical),
  `test_pursuing_hazard` (rc.r1_* → params bag via spawn_ctx), `test_config_menu` (70→52 knob count +
  EDIT probe r1_→r2_), `test_greybox_deck_equivalence` (credits 48→58 + filter pursuer from the K5
  assertions), `test_band_pipeline_parity` (P0 deck size 3→4 / credits 48→58), and (via sub-agent)
  `test_run_config`, `test_opposition_def_schema`, `test_telemetry_config_marking`, `test_rg1_loop_verify`,
  `test_rg1_m12/m13/m14/m15_verify` (r1_* preset asserts → `param_overrides["pursuer"]`; m13 deleted the
  two sub-verifiers that drove the deleted `_hazard_spawn_depths`/`_density_spawn_positions`).

## Debt ledger

- **Removed:** the R1 pursuer machine (~291 net LOC in `main_game.gd`) + **18** `rc.r1_*` knobs (+ 18
  telemetry rows, 2 density consts, 2 BUG6 traps, the `r1_` config-menu section + the Hazards tab) +
  the deleted J2/J3 golden tests (419 LOC). Combined with V3, **all three greybox spawn machines are
  retired**; every opposition is added exactly one way.
- **Config surface: 70 → 52 knobs (−18); legacy 68 → 50.** The `r1_` section + the Hazards tab
  disappear (V3 had emptied the tab's K5 half; V3b removes its last member).
- **Net product-code LOC ≈ −395** (138 ins / 533 del). New *test* code ≈ +210 (equivalence) + 46 data.
- **No save bump** — RunConfig is run-scoped, never persisted (grep-confirmed `META_SCHEMA_VERSION`
  stays 4; no `r1_` in `save_manager.gd`/`game_state.gd`; RunConfig not `store_var`'d). Meta stays v4.

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] **Full suite: 67/67 test scenes GREEN.** Key: `test_band_pipeline_parity` (fp e943ac9c8bc1),
  `test_band_two_profile`, `test_band_three_profile`, `test_encounter_builder` (e943ac9c8bc1),
  `test_greybox_deck_equivalence` (K5 EXACT 0.0% Δ — unchanged by the bump), `test_pursuer_deck_equivalence`
  (±15% + L2 bounds + density-fold documented), `test_opposition_components` (5 traces byte-identical),
  `test_config_menu` (52/52 bound), `test_run_config`, `test_pursuing_hazard`, the 4 `test_rg1_*_verify`.
- [x] Definition of done: 4 layout fps byte-identical; pursuer trace byte-identical; K5 equivalence
  intact; pursuer equivalence ±15% + density-fold documented; config bijection green at 52; no save
  bump; full suite green.

## Design deviations

**RISK NOTE / the ONE sanctioned behavioural change (D-RAT-3a, licensed, surfaced for Director
close-out — NOT a new deviation):** V3b is the version's highest-risk task because the deck lane is a
strictly less expressive placer than the R1 machine. The pursuer's per-type TOTAL is preserved
within ±15%, but the historical **J3 big-room clustering is folded to the deck's even-spread** — the
greybox pursuer *feel* shifts slightly (bodies more uniformly spread, `preset_deep` +11.1%). This is
inside the ratified D-RAT-3a bar ("deck even-spread ≠ per-piece formula; spread slightly deeper") and
is documented in the equivalence proof; it belongs in the SAME single D-RAT-3 sign-off as V3's K5
proof at the Wave-4 close-out (both equivalence tables presented together). No self-disposition — the
Director sees the density-fold concretely.

Otherwise **none** — the migration follows the locked Resolved Decisions (Phase 3): full 18-knob
deletion (OQ-E), Hazards tab dropped (OQ-F), no save bump (OQ-G), `per_band_cap` on the shared def
(OQ-H correction), the `legacy_ctx` one-arm ctx fix (OQ-C/D), and the golden-capture-before-delete
ordering. OQ-B (the 48-vs-±15% reconciliation) was Director-dispositioned as **D-RAT-8** (preserve
density → credits 58); folded here.

## Handoffs / follow-ups
- **Wave-4 close-out:** present the K5 (V3) + pursuer (V3b) equivalence tables together for the ONE
  D-RAT-3 golden-re-pin sign-off; the pursuer density-fold is the item to surface concretely.
- `opposition_credits = 58` is the agreed single number (V3's 48 + pursuer's 10).
