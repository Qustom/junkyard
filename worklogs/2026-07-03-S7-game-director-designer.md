# Worklog — S7 New band: `band_two.tres` "The Sump"

- **Date:** 2026-07-03
- **Subagent:** game-director-designer (profile/deck/curve + tint-only environment-artist half delivered inline per D-RAT-4)
- **Milestone:** M1.9 (Wave 4)
- **Branch:** game-director-designer/S7
- **Commit:** b25e00b6f2dcc689d3c31c2bba3f677fd0a2430a

## What changed
Authored the second dive band **entirely as data** — the band-side proof that "adding a
band = data, not engineering." `band_two.tres` "The Sump" is a branchy socket layout
(target 16 / branch 0.15) in a sepia-amber tint, decayed by the two S5 flavor stages
(SetPieceInject deep vault + WearDecay flooded), rewarded by its own lifted depth curve,
and stocked with a `min_band`-gated opposition deck — assembled from the existing
`BandProfile`/`BandPipeline`/stage machinery with **zero new generator code** (the one
palette-tint glue line was already wired by S3 at `main_game.gd:252`; no code touched).

## Files touched (all new — file-disjoint from S4/S6a/S6b)
- `Game/data/bands/band_two.tres` — the `BandProfile`: id `&"band_two"`, "The Sump",
  socket/branchy, `piece_pool` = extended 10-piece catalog, `flavors =
  [SetPieceInjectConfig, WearDecayConfig]` (embedded sub-resources), `band_depth = 2`,
  `opposition_deck` = 4 shipped defs (charger/splitter deferred — see integration note),
  `palette_tint = Color(0.82, 0.66, 0.42, 1)` sepia-amber (D-RAT-1/D-RAT-4).
- `Game/data/bandgen_config_band_two.tres` — branchy `BandGenConfig`
  (`target_piece_count = 16`, `branch_chance = 0.15`; all other knobs = greybox).
- `Game/systems/depth/depth_curve_band_two.tres` — reward-lifted `DepthCurve`
  (value 1.15→2.1, density 2.2→2.6, tier stepped 2→5) per R-OQ4.
- `Game/tests/test_band_two_profile.gd` + `.tscn` — headless profile-load + determinism +
  connectivity + set-piece + control-untouched + deck-gating contract test (C0–C6).

**Not touched (contract honored):** `band_greybox.tres`, `bandgen_config.tres`,
`piece_catalog*.tres`, `depth_curve.tres`, `greybox.tres`/`.png`, `run_config.gd`,
`config_menu.gd`, `main_game.gd`, `event_bus.gd`, entity/component scripts,
`data/oppositions/` (S0's defs referenced read-only), `systems/spawning/` (EncounterBuilder
read-only in the test).

## Authored value decisions (all per the spec's binding Resolved Decisions + D-RAT-1..4)
- **Identity (D-RAT-1):** "The Sump" · fiction *"A junkyard that fell out of another decade —
  war-surplus, dead formats, rust that remembers being new."* · sepia-amber tint · WearDecay
  `state = &"flooded"`.
- **Tuning (D-RAT-3):** 16 pieces / branch 0.15; difficulty step = +15% credit budget via
  `band_depth = 2` → `EncounterBuilder.instability(2) = 1.15` (budget `floor(24·1.15) = 27`).
- **Set-piece (D-RAT-3 / R-Flavors):** reuses the existing large piece `piece_room_xl` (no
  bespoke landmark), one `SetPieceEntry` (`min_depth_norm = 0.6`, `max_per_band = 1`,
  `unique = true`), `SetPieceInjectConfig.max_total = 1`. Verified non-vacuous (injects on
  ≥1 seed) and always deep (host `depth_norm ≥ 0.6`) across the 9-seed matrix.
- **WearDecay (R-Flavors reconciled table):** `state = &"flooded"`, `decay_level = 0.3`,
  `breach_budget = 2`, `block_budget = 1` (breach-led, per the S5 tree-band note),
  `depth_bias = 0.0`, `breach_width = 2`. Salts left at the schema defaults (`0x53455450` /
  `0x57454152` — exactly the spec values).
- **Reward (R-OQ4):** own curve authored; tier 2→5 resolves to real loot (junk pool stocks
  tiers 1–5), floor of 2 excludes the two tier-1 items — "band 2 loot is better" lands.
- **Palette tint (D-RAT-4):** `Color(0.82, 0.66, 0.42, 1)`. **Tint-only** — no retoned tileset,
  no `tileset` field (deferred); no PixelLab run.

## Checks run
- [x] `godot --headless --path Game --import` clean (exit 0; only pre-existing unrelated
      `*_strings.en.translation` load warnings).
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK**.
- [x] `res://tests/test_band_two_profile.tscn` → **BAND_TWO OK** (C0 profile contract ·
      C1 determinism · C2 connectivity through WearDecay · C3 soft floor · C4 set-piece
      deep + non-vacuous · C5 band_greybox control untouched · C6 deck gating; 9 seeds).
- [x] `res://tests/test_band_pipeline_parity.tscn` → **PIPELINE PARITY OK** (band_greybox
      fp `e943ac9c8bc1` byte-matches direct BandGenerator; 0 real FAILs).
- [x] `res://tests/test_band_flavors.tscn` → **BAND FLAVORS OK** (0 real FAILs).
- [x] `res://tests/test_bandgen_determinism.tscn` → **BANDGEN OK** (greybox fp
      `e943ac9c8bc1` unmoved; determinism + connectivity across 9 seeds).
- [x] **Definition of done met:** "`band_two` generates deterministically (same seed → same
      fp, twice; connectivity green through WearDecay); the deck spawns via the builder within
      caps [static gate contract proven; full-populate integration-checked at S8/SG1];
      `band_greybox` control fingerprint untouched; a headless profile-load contract test."

## Integration note (S8/SG1 — the parallel-merge deck completion)
`band_two.tres`'s deck ships **4 entries** in this worktree because `charger.tres`/
`splitter.tres` (S6a/S6b) are authored in parallel and absent here (an ExtResource to a
missing file would fail the whole resource load + break the contract test). **At S8/SG1
integration**, complete the deck to the ratified 6 (order `[pursuer, pingpong, bomb, spike,
charger, splitter]`, D-RAT-2 band-2-exclusive via `min_band = 2` on the two predator defs):

1. Add two ext_resources to `band_two.tres` (renumber ids as needed):
   `[ext_resource type="Resource" path="res://data/oppositions/charger.tres" id="15"]`
   `[ext_resource type="Resource" path="res://data/oppositions/splitter.tres" id="16"]`
2. Append them to the array:
   `opposition_deck = Array[Resource]([ExtResource("11"), ExtResource("12"), ExtResource("13"), ExtResource("14"), ExtResource("15"), ExtResource("16")])`
3. Re-run `test_band_two_profile.tscn` — C0 will then satisfy the full `size() == 6`
   (the test asserts `>= 4` + the shipped ids today; tighten to `== 6` post-merge if desired).
   Confirm S6a/S6b stamped `min_band = 2` on the two defs so band 1 (legacy empty-deck lane)
   never sees them and band_two (depth 2) includes all six.

Also confirm at S8/SG1 (per breakdown amendment 3 / R-Instability): the pipeline copies
`profile.band_depth` onto the returned `Band` so the deck lane's `band_depth >= d.min_band`
gate reads 2 (EncounterBuilder `_populate_deck` gates off `band.band_depth`).

## Design deviations
Two, both anticipated by the brief/ratifications and logged to `design/DESIGN_DEVIATIONS.md`
with **Reviewed** recommendations:
1. **Deck ships 4, not the DoD's 6** — the file-disjoint parallel-merge state; completes at
   S8/SG1 (diff above). Not a design change.
2. **Tint-only, no retoned tileset/`tileset` field** — per Director ratification **D-RAT-4**;
   the design already matches (recorded for the wave-4 audit trail only).
Everything else is on-spec against the S7 Resolved Decisions + D-RAT-1..4.

## Handoffs / follow-ups
- **S8/SG1:** complete the deck to 6 + verify `band_depth` threading (above).
- **M1.10/M2 content backlog (D-RAT-3 note):** author a *bespoke* Sump set-piece scene +
  bespoke band-2 pieces/junk (antiques/retro-tech/future-alloys) + the Tier-2 retoned tileset
  if the Director later funds it — this version proves the mechanism with reused parts only.
