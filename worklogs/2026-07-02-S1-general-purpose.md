# Worklog — S1 BandProfile + BandPipeline orchestrator + `band_greybox.tres`

- **Date:** 2026-07-02
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.9 (Wave 1, band migration Phase A)
- **Branch:** general-purpose/S1
- **Commit:** 9a8c6fbc3bd00d0f7a115634a12553bd2a8f6e6d

## What changed
Band-as-data Phase A per `design/M1_9_Tasks/S1_band_profile_pipeline.md` (§10 Resolved Decisions
binding). New `BandProfile` Resource schema (id, socket-only backend enum, backend_config,
declarative archetype + Q1 consistency push_warning, piece_pool, empty principles/flavors stage
lists, depth_curve, junk_catalog, `Array[Resource]` opposition_deck, band_depth, and
`palette_tint: Color` per breakdown amendment 9). New `BandPipeline.generate(profile, seed,
rc = null) -> Band` orchestrator: fail-loud validation (`push_error` + `null`), verbatim
delegation to `BandGenerator.generate` (zero RNG of its own), marked `# STAGE HOOK (S5)` slot,
then grade + return-distance replicating the as-built generation block — the seal stays at
materialisation (`main_game.gd:881`, untouched). `band_greybox.tres` authors today's baseline as
the first profile, referencing the LIVE `bandgen_config.tres` / `piece_catalog.tres` /
`depth_curve.tres` / `junk_catalog.tres` (never copies). No runtime call site changed (S3 owns
the switch); no save-schema change; no EventBus change.

## Files touched
- `Game/data/bands/band_profile.gd` (+ `.uid`) — the BandProfile resource schema (spec §2 + §10).
- `Game/data/bands/band_greybox.tres` — baseline-as-data profile, id `&"band_greybox"` (spec §4).
- `Game/systems/bandgen/band_pipeline.gd` (+ `.uid`) — the Phase-A orchestrator (spec §3 + §10 Q6).
- `Game/tests/test_band_pipeline_parity.gd` / `.tscn` (+ `.uid`) — the P0–P7 acceptance harness (spec §5).

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `res://tests/test_band_pipeline_parity.tscn` → exit 0 — "PIPELINE PARITY OK — BandPipeline
      byte-matches BandGenerator across 9 seeds (sample seed 12345 -> 12 pieces, fp=e943ac9c8bc1)".
      P1 byte-match across the full determinism matrix `[12345, 99999, 1, 2, 7, 808, 424242, -33,
      1000003]`; P0 profile-load contract (same-cached-object identity on config/catalog/curve/junk);
      P2 run-to-run determinism; P3 piecewise grading parity (depth_index/depth_norm/dist_to_gate/
      max_depth/entry/deepest); P4 connectivity + overlap-free + soft floor; P5 rc pass-through
      (r4-on ≈0.06/cap 8 + lvl_room_count=8) byte-exact vs direct, non-vacuous; P6 purity under RNG
      perturbation; P7 fail-loud guards (null / invalid / cave backend / pre-S5 stage-bearing).
- [x] `res://tests/test_bandgen_determinism.tscn` → exit 0 (BANDGEN OK / BUG3 / R4 / BUG4 all OK;
      file untouched). All-off fingerprint **e943ac9c8bc1 unmoved** (reported by both the direct
      test and the parity test's sample).
- [x] `res://tests/test_band_depth.tscn` → exit 0 (BAND DEPTH OK).
- [x] `res://tests/test_level_scale_determinism.tscn` → exit 0 (LVL OK).
- [x] Scope audit: `git status` shows ONLY new files under `Game/systems/bandgen/`,
      `Game/data/bands/`, `Game/tests/test_band_pipeline_parity.*` (+ `.uid`s). No file modified;
      `main_game.gd` / `event_bus.gd` / `game_state.gd` / `run_config.gd` / generator / sealer /
      grader / determinism test all untouched.
- [x] Definition of done met: "New `test_band_pipeline_parity` test scene: the orchestrated path's
      `fingerprint()` byte-matches the direct `BandGenerator.generate` path across the
      `test_bandgen_determinism` seed matrix (9 seeds), plus grading/rc-pass-through/purity guards"
      — all green above.

## Design deviations
- **None of substance.** Built to spec §2–§8 as amended by §10 + breakdown amendments 8/9.
  Two notational notes, not deviations:
  - Commit message prefix is `S1:` (per the dispatch brief) rather than §6's `M1.9 S1:` — the
    brief governs the work-product contract.
  - The Q1 archetype/branch_chance consistency `push_warning` lives in `BandProfile.validate()`
    (schema-local, reusable by tests/tools) — §10.1 Q1 allowed either `validate()` or the
    pipeline pre-flight.

## Handoffs / follow-ups
- **S5 (Wave 2):** the pipeline body carries the marked `# STAGE HOOK (S5)` slot between the
  backend delegation and the grade block; the pre-S5 stage-bearing guard (`push_error` + null)
  is the one S5 replaces with the real loop. S5 is the sole Wave-2 writer of `band_pipeline.gd`.
- **S3 (Wave 3):** call-site switch at `main_game.gd:209`; bind depth_curve/junk_catalog/
  opposition_deck/band_depth/palette_tint from the profile; optional `piece_pool_ext` field for
  the `lvl_enabled` catalog swap (§10.1 Q3); may retighten `opposition_deck` to
  `Array[OppositionDef]` post-integration (§10.1 Q5, optional).
- **S7 (Wave 4):** `band_two.tres` as a sibling profile; `palette_tint` field is ready for the
  tier-1 tint (D-RAT-4).
