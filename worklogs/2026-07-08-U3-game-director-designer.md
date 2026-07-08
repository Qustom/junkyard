# Worklog — U3 New band: `band_four.tres` "The Far Field" (scatter profile + deck + curve + tint + contract test)

- **Date:** 2026-07-08
- **Subagent:** game-director-designer
- **Milestone:** M1.11 (Wave 3)
- **Branch:** `game-director-designer/U3`
- **Commit:** `2e439023971021dc8652dc08a80ec4c997da74fb` (deliverables) + the worklog commit that follows it

## What changed
Authored the fourth, deepest dive band — and the FIRST on the third-generation
"scatter" backend — **entirely as data**: a tuned `ScatterBandConfig`, a reward-lifted
`DepthCurve`, a scatter `BandProfile` with a ranged-natives-first deck and a
non-Euclidean-dark tint, plus a near-verbatim clone of the band_three contract test
retargeted to band_four. No production code was written or touched. All binding
`Resolved Decisions (Phase 3)` (RD-1…RD-15) were honored; the shipped native cards
(lobber/sentry `cost 2 / cap 5`) matched RD-1 exactly, so the RD-2 deck pin held
without re-derivation.

## Files touched (all NEW; zero production code)
- `Game/data/bands/scatter_config_band_four.tres` — RD-4 canonical `ScatterBandConfig`:
  `grid 64×64 · cover_density_pct 8 · min_cover_spacing 4 · border_margin 2 ·
  cover_w 4/1/1/1 · edge_cover_bias_pct 60 · clear_lane_width 3 · chunk_cells 8 ·
  cell_size_px 16` (no `min_floor_cells`/`max_attempts` — not on the RD-11 schema).
- `Game/systems/depth/depth_curve_band_four.tres` — RD-11 reward curve: `value 1.45→2.9`,
  `tier` stepped `4→5` (single step at 0.5), `density 1.0→1.2` per chunk-piece.
- `Game/data/bands/band_four.tres` — scatter `BandProfile`: `id &"band_four"`,
  `display_name "The Far Field"`, `backend "scatter"`, `archetype "linear"` (inert),
  `piece_pool null`, `flavors []`, `band_depth 4`, `palette_tint Color(0.42,0.46,0.62,1)`,
  deck `[lobber, sentry, charger, DeckEntry{bomb, base_count:1}]` (ranged-natives-first =
  budget priority). Byte-shape clone of `band_three.tres` (`load_steps=11`, same
  `deck_entry_bomb` SubResource shape).
- `Game/tests/test_band_four_profile.gd` (+`.uid`) + `.tscn` — near-verbatim clone of
  `test_band_three_profile.gd`, re-based per RD-5.

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors).
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK — M0 architecture spike healthy**.
- [x] **`test_band_four_profile.tscn` → BAND_FOUR OK** (C0–C11 across 9 seeds; deck spawns
  `lobber 5 / sentry 5 / charger 4 / bomb 6 = 20`, budget 34 → exactly 0; three golden
  controls byte-identical).
- [x] Regression set (all GREEN unmodified except the one flagged finding below):
  - `test_band_three_profile` OK (band_greybox + band_two byte-identical; ambusher/burrower deck pin unchanged)
  - `test_band_two_profile` OK
  - `test_band_pipeline_parity` OK — **fp `e943ac9c8bc1`** (the all-off control, unmoved)
  - `test_scatter_backend` OK — sample fp `44a9a9b3756f`, max_depth 9 (unchanged)
  - `test_scatter_materialise` OK · `test_cave_materialise` OK
  - `test_band_routing` OK · `test_opposition_def_schema` OK (11-def bijection unchanged — U3 adds no def)
  - **`test_def_menu_coverage` → RED (expected; see Design deviations #1 — a stale golden, NOT a defect)**
- [x] Definition of done met — "Deterministic; connectivity + sightline; FOUR controls
  untouched; profile loads + validates; deck spawns the deterministic outcome; visual
  identity present; import + smoke green; worklog + cost ledger + measured band-total +
  deviations." All met; the four control fps (all-off `e943ac9c8bc1`, band_greybox,
  band_two, band_three) are byte-identical.

## COST LEDGER — the N=3 headline (target: 0 production-code lines)
| Band | Backend | Marginal production-code cost | Footprint |
|---|---|---|---|
| band 2 (M1.9) | socket (reused) | 1 glue line | 3 `.tres` + 1 test |
| band 3 (M1.10) | cave (2nd backend) | 0 | 3 `.tres` + 1 test |
| **band 4 (M1.11 U3)** | **scatter (3rd backend)** | **0** | **3 `.tres` + 1 test** |

**Actual U3 marginal production-code cost: 0 lines.** Deliverables are 3 `.tres` +
1 mirrored contract test (`.gd`+`.tscn`) + inline `DeckEntry` data. Nothing forced a
production-code line — the 0-line prediction (spec §5.2) HELD for a third generation of
generator. The N=3 trend line is flat at zero from the second backend onward: once a
backend exists, adding a band on it is data only. (Fixed cost — the scatter backend
itself + the ranged threat axis — was paid once in U0/U1/U2a/U2b.)

## Measured junk band-total (RD-11 requirement)
`JunkPlacer.plan()` over the authored band across the 9-seed matrix:
**mean 71.1 items/band (min 68, max 75)**. This lands on RD-11's re-pinned target
(band-total ≈ 70, inside the stated ~55–75) — the reward escalation is carried by
**value (1.45→2.9)** and the **tier floor (4)**, not raw count. Recorded per the TG2
rule so UG2 reads the four-band loot comparison on band-total *value*, not naive counts.

## Design deviations
1. **`test_def_menu_coverage` golden is now stale (FLAGGED per the brief — needs Director
   disposition; recommend Addressed with a 2-line golden update).** The ConfigMenu's
   band-scan (`config_menu.gd:_load_deck_membership`) automatically picks up band_four's
   `opposition_deck` with **zero menu code** (the shipped S4 count-agnostic feature). As a
   result `charger`'s honest IN-DECK chip correctly grew from `IN DECK: band_two` to
   `IN DECK: band_four, band_two` (descending-band order, same convention splitter already
   uses for `band_three, band_two`). The test hardcodes the old string at
   `test_def_menu_coverage.gd:352` (`{ "bands": "band_two", "n": 0 }`) and `:386`
   (`{ "bands": "band_two", "n": 2 }`), so both charger assertions now fail. **This is a
   correct-behavior golden drift, not a data or code defect** — it is in fact positive
   evidence for the N=3 "content = data compounds" thesis (the menu reflected the new band
   for free). Only `charger` is affected: `splitter` is not in band_four's deck (band_four
   uses charger), and `lobber`/`sentry`/`bomb` chips are not pinned by this test.
   - Per the U3 hard constraint ("Touch NOTHING but the 3 new `.tres` + the 2 new test
     files") and the explicit brief note ("do NOT edit the test without flagging it as a
     deviation"), **I did NOT edit `test_def_menu_coverage.gd`.**
   - **Recommended disposition (Director):** *Addressed* — update the two goldens to
     `{ "bands": "band_four, band_two", "n": 0 }` (line 352) and
     `{ "bands": "band_four, band_two", "n": 2 }` (line 386). One-line each; restores green
     and pins the correct new membership. (Alternate: *Reviewed* + track the golden update
     as a trivial follow-up task.)
2. **`palette_tint` pinned exactly in C0.** The band_three test only asserted
   `palette_tint != white`; band_four's C0 asserts the exact `Color(0.42,0.46,0.62,1)`
   (RD-7). Strictly stronger identity pin, on-spec (RD-6/RD-7). Not a design departure —
   noted for transparency.

Otherwise none — RD-1…RD-15 followed as written; the shipped native cards matched RD-1,
so the RD-2 deck pin (`5/5/4/6 = 20`) required no re-derivation.

## Handoffs / follow-ups
- **Orchestrator / Director:** disposition Design-deviation #1 (recommend the 2-line
  golden update to `test_def_menu_coverage.gd`). No other regression is red.
- **U4 (routing + portal):** `band_four` is data-only; `BAND_ROUTES` + the 4th hub portal
  + the pinned portal glow `Color(0.15,0.25,1.0)` indigo (RD-6) are U4's, untouched here.
- **Director review queue (RD §D1–D5, unchanged, all ratified at design lock):** name
  "The Far Field" + tint + indigo glow (D1); deck `5/5/4/6=20` with 6 mines (D2); natives
  band-4-exclusive (D3); 1.45 step (D4); reward curve value 1.45→2.9 / tier 4→5 / density
  1.0→1.2 (D5). All shipped as ratified.
- **M2 content follow-ups (logged, out of M1.11 scope):** tier-6 "reality-warping /
  lore-core" JunkItems (OQ8/RD-11); a JunkPlacer `exposure_value_bias` for the
  exposed-center loot-value read (OQ6/RD-12); extract the duplicated chunk/emit machinery
  on this 4th backend consumer (U0 UG3 watch-item).
