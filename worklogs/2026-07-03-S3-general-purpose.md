# Worklog — S3 EncounterBuilder + RunConfig generic levers + both call-site integrations

- **Date:** 2026-07-03
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.9 (Wave 3 — sole `main_game.gd` writer)
- **Branch:** general-purpose/S3
- **Commit:** d9f537712e482561fe761ec2f2a1c972160489f3 (implementation; this worklog is a
  follow-up commit on the same branch)

## What changed
Opposition migration **Phase C** ("policy out of `main_game`") + the band-side call-site
switch, per `design/M1_9_Tasks/S3_encounter_builder_integration.md` (§7 Resolved Decisions
binding, amended by C1–C4 + breakdown amendments 3/7/8/10). Zero observable behavior
change: the all-off fingerprint `e943ac9c8bc1` is byte-identical **through both new call
sites**, and the default play preset spawns the byte-identical cohort (same ordered
(def, cell, ctx) plan — proven against a verbatim in-test mirror of the pre-S3 math).

- **`EncounterBuilder`** (new): one `populate(band, profile, rc, svc)` entry, two lanes.
  Legacy lane = the K5 fair-share machine relocated VERBATIM (descriptor table → the
  legacy adapter over the untouched `hpp_*/hbomb_*/hspike_*` knobs; fair-share 48-split;
  filter-then-stride via `svc.valid_cells()`; cross-type `spawned_total` threading the
  golden-angle fan; credits never consulted — §7.2 Q5). Deck lane = the credit machine:
  budget `floor(BASE_CREDITS * instability(band_depth))`, `min_band` gated off
  `profile.band_depth`, deterministic id-deduped authored-order draw (`spawn_weight`
  reserved), counts off `d.params["base_count"]`/`["count_per_depth"]` (amendment 10),
  service caps as the hard stop, refusals never spend. `instability(band_depth) = 1.0 +
  0.15*(band_depth-1)` (amendment 7 — band 1 = 1.0 exactly). The shared stable-walk
  helpers are hoisted here as the SINGLE copy (§2.6.d); the golden-angle const moved in.
- **`main_game.gd`** (thin consumer): the `:209` switch →
  `BandPipeline.new().generate(profile, seed, run_cfg)`; `_resolve_band_profile()`
  consumes `GameState.consume_pending_dive_band()` and returns `band_greybox` for every
  key until S8's one-function rewire (§7.2 Q2; `BAND_ID` stays `&"near"` — Q2b); grading
  moved into the pipeline; profile binds `depth_curve`/`junk_catalog` (same live .tres
  objects → byte-identical loot plan) + `palette_tint` at materialise (neutral white =
  zero visual change; the S7 seam). `_spawn_new_hazards` = kept-signature façade
  (`is_inert` pre-check → arm service → `populate`); `_new_hazard_spawn_ctx` = forwarder
  (docstring corrected per §7.1: `index` is the CROSS-type accumulator);
  `NEW_HAZARD_BAND_CEILING`/`NEW_HAZARD_SPAWN_SAFE_CELLS` re-exports retained (C2);
  `_density_pieces_sorted`/`_density_sorted_cells` = forwarders to the hoisted copy;
  `_new_hazard_descriptors`, the spawn-loop internals, `NEW_HAZARD_GOLDEN_ANGLE`, the
  def-path consts, and the generation fixtures (`_piece_catalog`/`_piece_catalog_ext`/
  `_cfg` + their consts) deleted. R1/J2/J3 lanes untouched (§7.2 Q4).
- **`run_config.gd`** (additive only — legacy groups byte-untouched):
  `oppositions_enabled: Array[StringName]` + `param_overrides: Dictionary` as
  **`@export_storage`** (invisible to `has_full_coverage()` — 89 holds; S4 promotes in
  Wave 4, amendment 3); two additive `to_flat_dict()` rows (`param_overrides` = the one
  sanctioned nested stamp, docstring amended per amendment 10) + two String-safe
  serializer helpers.
- **Q6(iv) (binding supersession):** `BandProfile.piece_pool_ext: PieceCatalog` + the
  pipeline-owned `rc.lvl_enabled` ext-catalog swap; `band_greybox.tres` authors the live
  `piece_catalog_ext.tres`. The I1 call-site swap lines left `main_game` with the rest of
  the generation block.

## Files touched
- `Game/systems/spawning/encounter_builder.gd` (+ `.uid`) — **new**: the policy class (above).
- `Game/scenes/game/main_game.gd` — the sole-writer rewrite (above).
- `Game/data/run_config/run_config.gd` — the S3 `@export_storage` block + flat-dict rows.
- `Game/data/bands/band_profile.gd` — `piece_pool_ext` field (Q6(iv)).
- `Game/data/bands/band_greybox.tres` — authors `piece_pool_ext = piece_catalog_ext.tres`.
- `Game/systems/bandgen/band_pipeline.gd` — the 5-line lvl_enabled catalog-swap
  conditional (Q6(iv); flagged as a deviation vs the dispatch brief's must-not-touch line).
- `Game/tests/test_encounter_builder.gd` / `.tscn` (+ `.uid`) — **new** (10 cases, §3.5 + Q6(iv)).
- `Game/tests/test_band_pipeline_parity.gd` — P5's lvl direct-comparison now uses the ext
  catalog (the swap is pipeline-owned); P0 pins `piece_pool_ext` same-object identity.
- `Game/tests/test_run_config.gd` — the two new flat-dict keys, the sanctioned
  `param_overrides` nested exception, neutrality + round-trip assertions.
- `design/DESIGN_DEVIATIONS.md` — 5 entries appended (below).

## Checks run
All sequential (never two headless instances), in this worktree:
- [x] `godot --headless --path Game --import` clean (no parse/compile errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] **All-off fp `e943ac9c8bc1` byte-identical through the new call sites**:
  `test_bandgen_determinism` ✓, `test_corridor_lever` ✓ (pins BASELINE_FP),
  `test_band_pipeline_parity` ✓ (sample fp e943ac9c8bc1), and
  `test_encounter_builder` case 9 pins the fp through `BandPipeline` + the authored
  greybox profile directly.
- [x] **Preset parity**: `test_encounter_builder` case 2 — ordered (def_id, cell, ctx)
  plan equals the verbatim pre-S3 mirror (cells + counts + `initial_dir` fan +
  `phase_salt`s + order), refusal-free; `test_new_hazard_spawn` green **UNMODIFIED**
  through the façade; `test_rg1_m14_verify` + `test_rg1_m15_verify` green.
- [x] Every `test_rg1_m1*` verify green: `test_rg1_loop_verify`, `test_rg1_m12_verify`,
  `test_rg1_m13_verify` (**passed on the FIRST run — no BUG-M13FLAKE retry needed**),
  `test_rg1_m14_verify`, `test_rg1_m15_verify`.
- [x] Config coverage: `test_config_menu` → **89/89** (the `@export_storage` levers are
  invisible, C1 holds on 4.6.3); `test_run_config` → 91 knobs in `to_flat_dict()`,
  levers neutral-empty on the control, nested stamp JSON-safe.
- [x] New `test_encounter_builder` green (10 cases: all-off inert / preset byte-parity /
  fair-share 16-16-16 + 24-24 + deepest-first starvation / budget math + refusal
  non-spend / min_band / deterministic dedup draw / levers + neutrality /
  caps-in-service / pipeline lvl-swap fp pins / instability normalization).
- [x] Full hazard suite green unedited: `test_pingpong_hazard`, `test_bomb_hazard`,
  `test_spike_hazard`, `test_pursuing_hazard`, `test_per_room_density` (byte-frozen
  golden), `test_hazard_spread`, `test_throw_mechanic`; `test_spawn_service` green;
  `test_opposition_components` (golden frame-trace parity) + `test_opposition_def_schema`
  green.
- [x] Band suite green: `test_band_pipeline_parity` (amended P5/P0), `test_band_flavors`,
  `test_band_depth`, `test_level_scale_determinism`.
- [x] Main-loop/regression sweep green: `test_main_game_loop`, `test_loop_drive`,
  `test_within_band_depth`, `test_exit_placement`, `test_exit_placement_count`,
  `test_duration_loop_reentry`, `test_run_duration`, `test_corridor_summary_row`,
  `test_telemetry_config_marking`.
- [x] Definition of done met: *"All-off fp e943ac9c8bc1 byte-identical through the new
  call sites; preset spawns the SAME cohort; test_config_menu 89/89; new
  test_encounter_builder green; full hazard suite + test_spawn_service +
  test_opposition_components + band suite green; import + smoke green."* — all above.

## Design deviations
Five entries appended to `design/DESIGN_DEVIATIONS.md` (all recommended **Reviewed**):
1. **Bandgen surface touched** (`band_pipeline.gd` / `band_profile.gd` /
   `band_greybox.tres` / parity-test P5+P0) — directed by the BINDING §7.2 Q6(iv)
   adjudication, which supersedes both §2.4(ii)'s call-site fallback and the dispatch
   brief's must-not-touch line (the brief defers to the spec). Without it the lvl-on
   preset band would silently lose the ext catalog (a parity break).
2. **`test_run_config.gd` flatness pin amended** — one sanctioned nested exception
   (`param_overrides`), per amendment 10's nested stamp key.
3. **Spec §3.5 case-7 expectation corrected** — `oppositions_enabled` alone spawns
   nothing because S2 authored every spawn card NEUTRAL; the test asserts enable-list +
   `param_overrides` spawning instead. Flag to S4: consider a "enabled def with a
   fully-neutral card" config trap.
4. **Deck-lane ctx enrichment vs the §3.1 sketch** — per-piece (not per-def)
   cells/bounds compute; ctx additionally carries the per-kind legacy vocabulary +
   `room_key` + the merged `params` bag. Determinism-neutral; keeps S7's deck-authored
   known hazards on their locked entity contract.
5. **Façade `is_inert()` pre-check** — additive builder API preserving S0's "all-off
   creates NO service node" contract through the extraction.

Implementation notes (not deviations): `_resolve_band_profile()` already consumes the
routing key (per the dispatch brief; every key → greybox until S8); the resolved profile
is cached on `_band_profile` so the façade sees the SAME profile the band generated from
(bare-instance harness calls fall back to resolving); `opposition_deck` stays
`Array[Resource]` (S1's optional retighten deferred — the builder casts + fail-louds);
`main_game`'s dead generation fixtures were deleted rather than left as unused members.

## Handoffs / follow-ups
- **S4 (Wave 4):** promotes `oppositions_enabled`/`param_overrides` to plain `@export` +
  bound rows (89 → 91); consider the "enabled def id with fully-neutral card" trap
  (deviation 3); `param_schema` is complete for all 4 defs.
- **S7 (Wave 4):** author `band_two.tres` with `opposition_deck` (counts live in
  `params`, `min_band` vs `band_depth = 2` → I = 1.15 → budget 27); `palette_tint` is
  now applied at materialise; confirm the deck-lane ctx vocabulary suffices (deviation 4).
  If band_two wants lvl-on ext pieces, author `piece_pool_ext` (null = no swap).
- **S8 (Wave 5):** rewire ONLY `_resolve_band_profile()`'s body (key → profile map;
  unknown/empty → greybox); `BAND_ID`/telemetry stamping story is S8's.
- **SG2:** `BASE_CREDITS` (24) is the Director-sweepable deck-budget knob; the
  `param_overrides`/`oppositions_enabled` stamps are live on `run_started` rows.
- **Post-gate (SG3 watch):** R1 lane retirement + cap-domain unification unchanged;
  legacy adapter + `LEGACY_DEF_PATHS` retire with the R1/K5 knob groups.
