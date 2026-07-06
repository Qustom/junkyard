# Worklog — U0 ScatterBackend: open-field arena generator + `ScatterBandConfig` + pipeline backend dispatch

- **Date:** 2026-07-06
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.11 (Wave 1)
- **Branch:** `worktree-agent-a9de6626bbda65fdb` (isolated worktree branch; left unmerged for the orchestrator's verified merge)
- **Commit:** `bbed6fb945e31cd5fb7dade95031649a275e62e0` (feature) + `d2a8a34e9b1c487eec2a388a39512bc4cc832dc1` (RD-16 comment-only test staleness fix, assertion-preserving, separate per the spec)

## What changed
Built the third generation backend per `design/M1_11_Tasks/U0_scatter_backend.md` (§10 RD-0…RD-18
binding). `ScatterBackend` generates an all-floor arena (forced WALL border ring, rectangle-only
per RD-18) and stamps ≤2×2 cover footprints as NON-floor via order-stable stratified grid-jitter
poisson sampling (RD-1) with a **fixed-length `1 + 4·S` RNG stream** (one seed-drawn lane row +
an unconditional 4-draw tuple per stratum, RD-13). Connectivity + 2×2 player-scale hold **by
construction** (RD-6): Chebyshev `min_cover_spacing >= 3` dilation, `border_margin >= 2` perimeter
road, full-width seed-drawn clear lane — **no carve pass, no retry scaffold** (RD-5;
`requested_seed == resolved_seed` always; `band_generation_failed` never emitted). Cover is
stamped strictly pre-partition (RD-7); the chunk/emit machinery is **duplicated** from the cave
(RD-14 — `cave_backend.gd` byte-untouched, confirmed clean in `git status`), emitting synthetic
`scat_`-content-hashed pieces with the entry anchor lane-aligned (RD-2's tie-break: min
|y − lane_center|, then min y) and front-positioned as `floor_cells[0]`. `ScatterBandConfig` is
the canonical RD-11 integer-only schema with the RD-8 clamps (including the CORRECTED
`chunks_x = ceil(grid_width/chunk_cells) >= 5` depth bar). `BandPipeline` replaces the scatter
fail-loud with real dispatch (socket/cave statements verbatim; post-backend connectivity ASSERT
widened to cave-or-scatter — on the cave arm the boolean short-circuits so the executed statement
is identical). `BandProfile.validate()` gains the scatter branch (RD-10: flavors fail-loud —
the single-location owner of the scatter-flavors rule; `piece_pool` not required; `archetype`
warn-only don't-care).

## Files touched
- `Game/systems/bandgen/scatter_backend.gd` (+`.uid`) — NEW: the backend (§3; RD-1/2/5/6/7/13/14/18).
- `Game/data/bands/scatter_band_config.gd` (+`.uid`) — NEW: the RD-11 canonical schema + RD-8 validate() clamps.
- `Game/systems/bandgen/band_pipeline.gd` — dispatch arm + widened ASSERT + truthful guard docstring (§4.1).
- `Game/data/bands/band_profile.gd` — validate() scatter branch + backend-enum docstring truth (§4.2).
- `Game/tests/test_scatter_backend.gd` / `.tscn` (+`.uid`) — NEW: the S1–S11 acceptance harness (§5, RD-4-corrected).
- `Game/tests/test_band_pipeline_parity.gd`, `Game/tests/test_cave_backend.gd` — **comment-only** (RD-16, separate commit `d2a8a34`; every assertion line byte-identical; both suites re-run green after the edit).
- NOT touched: `cave_backend.gd`, `cave_band_config.gd`, `main_game.gd`, `config_strings.csv`, `band_generator.gd`, `band.gd`, `placed_piece.gd`, `socket_sealer.gd`, `stages/*`, all authored `.tres`, `test_bandgen_determinism.*`, `test_band_three_profile.*`.

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors), re-run after every file change.
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK**.
- [x] **`test_scatter_backend.tscn` → SCATTER BACKEND OK** (S1–S11 across 9 seeds; sample seed 12345 → 35 pieces, max_depth=9, fp=`44a9a9b3756f`).
- [x] **All four controls byte-identical** (asserted from primary sources, suites run sequentially):
  - all-off RunConfig fp **`e943ac9c8bc1`** — `test_band_pipeline_parity` OK ("fp=e943ac9c8bc1"), `test_bandgen_determinism` OK ("fp=e943ac9c8bc1"), `test_rg1_m15_verify` OK ("byte-identical to the locked baseline (fp=e943ac9c8bc1)").
  - `band_greybox` — parity suite OK (pipeline byte-matches direct BandGenerator) + S9 in-suite.
  - `band_two` — `test_band_three_profile` OK (C5 pins the absolute BAND_TWO_GOLDEN constants) + `test_band_two_profile` OK + S9.
  - `band_three` — `test_band_three_profile` OK (cave suite `d984fd8913bf` sample unchanged) + `test_cave_backend` OK + S9.
- [x] P7/C8 fail-loud cases survive with **assertion lines unedited** (config-less scatter profile now nulls via `validate()` instead of the wiring guard — the §1.2 prediction held).
- [x] Adjacent suites green: `test_band_depth`, `test_band_flavors`, `test_cave_materialise`, `test_band_two_profile`, `test_band_routing`. (`tests/procgen/test_layout_determinism.gd` is a GdUnit4 suite with no scene wrapper — not headless-runnable standalone; its coverage is duplicated by the parity/determinism scenes, which ran green.)
- [x] Definition of done met: "new `test_scatter_backend` green; all four control fingerprints byte-identical; all existing bandgen tests green; worklog (with the bespoke-code cost ledger) + commit SHA + deviations" — all four bullets above.

### S11(b) calibration (RD-4 — recorded as required)
Measured openness percentile (floor cells with max axis run ≥ K = interior_min/2 = 17), minimum
across the 9-seed matrix: **default config 99%, dense config (density 90 / bias 40 / lane 2) 95%**.
Asserted calibrated floors with margin: **default ≥ 90%, dense ≥ 75%**. S11(a) (the full-width
lane run == `grid_width − 2`) and S11(c) (`cover_cells · s² <= 4 · interior`) asserted as
universal by-construction bars.

### RD-12 sanity run of U3's authored value set (for the U3 brief)
`64×64 · density 8 · spacing 4 · border 2 · weights 4/1/1/1 · bias 60 · lane 3 · chunk 8 · 16px`:
`validate()` = clean; across the seed matrix: **pieces = 64, max_depth = 11–14 (bar ≥ 4 holds
with 3× headroom), floor 3821–3841 of 3844 interior cells, covers 3–13 (sparse-deadly as
intended), spacing rejects 2–7 (sampler non-vacuous), lane rows seed-varied (4–54), 9 distinct
fingerprints.** U3 starts from measured shape.

## Bespoke-code cost ledger (non-data, non-test code — the N=3 evidence)
Counting method: non-comment, non-blank lines (`grep -vE '^\s*(#|$)'`); raw file totals in parens.

| File | U0 (backend #3) | Cave equivalent (backend #2) |
|---|---|---|
| backend (`scatter_backend.gd`) | **264** (393 raw) — of which ~140 is the RD-14 duplicated chunk/emit/T machinery and ~124 the genuinely new sampler/lane/entry | 404 (545 raw) |
| config (`scatter_band_config.gd`) | **45** (110 raw) | 44 (97 raw) |
| `band_pipeline.gd` dispatch delta | **+8** code lines | ~+6 |
| `band_profile.gd` validate branch delta | **+10** code lines | ~+12 |
| **Total** | **327** | **~466** |

Backend #3 cost **~30% less than backend #2 measured identically** — no retry loop, no CA/flood/
carve machinery, one new sampler function; everything downstream reused unchanged. (The spec's
"~255 for the cave" was a different counting basis; the like-for-like comparison is the table.)
UG3 watch-item carried: extract the duplicated chunker on the *third* consumer (RD-14).

## `CFG_FIELD_*` gloss rows needed at merge
**None.** `config_strings.csv` glosses RunConfig menu fields only; `ScatterBandConfig` is profile
content, not a run lever, and adds no RunConfig knob (frozen knob model). Precedent:
`CaveBandConfig` has zero gloss rows.

## Design deviations
1. **RD-2 interpretation flag (required by the RD itself):** the entry anchor deviates from the
   cave's letter ("west-most, tie min y") to the lane-aligned tie-break (min |y − lane_center|,
   then min y) — a ratified interpretation of the M1.10 Q10 "west-most" contract serving its
   spirit (deterministic, orientation-stable, meaningful entry). Per RD-2, worklog-flagged.
2. **RD-6 interpretation flag (required by the RD itself):** no carve pass ships — "connectivity
   by construction" is the compliant reading of the breakdown's "…or by deterministic CARVE"
   (an *or*); the RD-8 validate() clamps are the proof's teeth, and the pipeline ASSERT + S3 +
   S10 are the invariant's three independent checks. Per RD-6, worklog-flagged.
3. **S10 asserts RD-6's STRONG form** (every floor cell **in** T, not the cave's weaker "in or
   4-adjacent to T"): the spec's §5 S10 said "cave C10 mirror verbatim", but RD-6 proves the
   strong property and breakdown amendment 4 has U1's M6 asserting the same form — asserting it
   here catches a predicate regression at the source. Strictly stronger test; held on all seeds,
   both configs.
4. **RD-16 comment-only touch-up executed** as its own assertion-preserving commit (`d2a8a34`),
   per the RD; flagged here so the merge review sees the U0-branch edit to two T0-owned test files.
Otherwise none — RD-0…RD-18 followed as written (retry fields absent per RD-5; corrected
`chunks_x >= 5` clamp per RD-8; canonical RD-11 schema field-for-field; two-zone bias per RD-17;
rectangle-only per RD-18).

## Handoffs / follow-ups
- **U1:** §8 guarantees delivered data-level (enclosure; cover = ≤2×2 WALL blobs floor-surrounded;
  entry anchor in T front-positioned; `max_depth >= 4` on defaults; `cell_size_px = 16`). RD-9:
  U1's C4/OQ-2 "≥ 2" should be re-worded to "≥ 3 (Chebyshev, U0 RD-8/RD-9)".
- **U3:** author against the RD-11 canonical schema (four `cover_w_*` weights, no
  `min_floor_cells`/`max_attempts`); the RD-12 sanity numbers above are the measured starting shape.
- **Orchestrator at merge:** no `config_strings.csv` rows needed; `tests/procgen/` GdUnit suite
  remains scene-less (pre-existing; noted, not changed).
- **UG3 watch-item:** extract the duplicated chunk/emit machinery on a fourth backend, in its
  version, with all backend suites as the net (RD-14).
