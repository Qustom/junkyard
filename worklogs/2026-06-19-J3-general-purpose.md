# Worklog — J3 Per-room hazard density

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.3 (Wave 2 — Density & spatial)
- **Branch:** worktree-agent-a8e275fc341969669 (isolated worktree; logically `general-purpose/J3-per-room-density`)
- **Commit:** 5fdcc76f2e917dcaed4b739279f2f7486e71fd1c

## What changed
Implemented J3 **additively on top of J2's spawn seam** (per the locked Director Disposition).
A new pure planner `MainGame._density_spawn_positions(band, rc)` computes, per eligible piece,
`n = floor(r1_per_room_density * area / R1_DENSITY_AREA_UNIT)`, applies the per-room cap + a
band-wide ceiling, and strides the `n` hazards across THAT room's own sorted floor cells —
**index-deterministic, NO RNG**. `_populate_room_density` is a thin instantiate loop over that
plan (ordinary HazardEntities; reuses the band cell→world projection). It is called from
`_spawn_r1_hazards` after J2's spread, so J2 + J3 are one HazardEntity population. The Director
chose **cell_area** (size-invariant) as the default metric; **px_area** (`cell_area * lvl_size_mult²`)
is built as a selectable enum option. Added the disjoint **loot-per-area sub-knob** to
`junk_placer.gd` (off by default, never preset-on). Six new knobs added to RunConfig +
`to_flat_dict()` + the CFG menu + CSV; knob count 38 → 44. Preset wired with the mandatory
perf cap (`r1_density_per_room_cap = 3`) and a non-trivial `r1_density_min_area = 64`.

## Files touched
- `data/run_config/run_config.gd` — 6 new knobs (`r1_per_room_density`, `r1_density_metric` enum,
  `r1_density_rooms_only`, `r1_density_min_area`, `r1_density_per_room_cap`, `lvl_loot_density_per_area`),
  the 3 J3 constants (`R1_DENSITY_AREA_UNIT=96`, `R1_DENSITY_BAND_CEILING=64`, `LVL_LOOT_AREA_UNIT=96`),
  `to_flat_dict()` additions, and `make_default_play_preset()` density wiring (cell_area, density 1.0,
  cap 3, min_area 64, loot OFF). All-off defaults unchanged → all-off byte-identical to M1.2.
- `scenes/game/main_game.gd` — additive J3 step: `_populate_room_density` + pure `_density_spawn_positions`
  + helpers `_density_area`, `_is_corridor`, `_density_pieces_sorted`, `_density_sorted_cells`,
  `_density_cell_to_world`; restructured `_spawn_r1_hazards` so a density-only run (spawn_count 0) still
  works while all-off stays a no-node early return. Threaded the loot knob into the `JunkPlacer.plan()` call.
- `systems/depth/junk_placer.gd` — disjoint single-writer edit: `plan()` gains a `loot_density_per_area`
  param (default 0.0 = OFF, byte-identical draw); when > 0 scales the per-piece expected count by room area
  before `_seeded_round`, riding the existing `_JUNK_SALT` sub-stream (never the global RNG).
- `ui/config/config_menu.gd` — SECTIONS/MANIFEST/FIELD_RANGE/FIELD_STEP entries for all 6 knobs
  (RANGE_DENSITY [0,4] 0.25 step, RANGE_AREA [0,256], RANGE_ROOM_CAP [0,16]); enum + bool auto-handled.
- `ui/config/config_strings.csv` — 6 `CFG_FIELD_*` labels.
- `tests/test_run_config.gd` — `expected_keys` += 6 (44 total); new Case 9 asserts all-off density OFF +
  preset density sweep (cap > 0 mandatory, min_area > 0, loot OFF).
- `tests/test_config_menu.gd` — knob count 38 → 44.
- `tests/test_per_room_density.gd` + `.tscn` (+ auto `.gd.uid`) — NEW focused J3 acceptance test.

## Checks run
- [x] `godot --headless --import` clean (no parse/script errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK (exit 0)
- [x] `test_run_config` → R0 OK (all 44 knobs; all-off + preset density verified)
- [x] `test_config_menu` → CONFIG MENU OK (44/44 knobs bound + reachable)
- [x] `test_hazard_spread` → J2 OK (J2 unchanged, still passes)
- [x] `test_level_scale_determinism` → LVL OK
- [x] `test_per_room_density` → J3 OK (scales with floor_cells.size(), cap/min-area/rooms-only filters,
  px_area scales by mult², all-off → 0 nodes, deterministic, band ceiling bounds worst case)
- [x] `test_rg1_m12_verify` → RG1 M1.2 VERIFY OK — **all-off byte-identical to the locked baseline
  (fp=e943ac9c8bc1)** — CRITICAL invariant intact.
- [x] Definition of done met: additive per-room size-scaled budget, cell_area default + px_area option,
  loot sub-knob OFF, mandatory cap + band ceiling, focused test, perf measurement recorded.

## Perf measurement (Q E mandate — recorded for RG1)
Measured the realised density-hazard count on a realistic 19-room band (sizes 32–192 cells, ext-catalog
shaped). Each density hazard is one HazardEntity running one `_physics_process` chase/frame, so the count
IS the per-frame bound:
- **PRESET (cell_area, density 1.0, cap 3, min_area 64):** **14 density hazards** across 19 rooms
  (size-invariant — same at lvl_size_mult 4× or 40×; bounded by the per-room cap of 3).
- **px_area at size 40× (preset cap 3):** **42 density hazards** — under the 64 ceiling.
- **Worst case (px_area, size 40×, density 4.0, per-room cap REMOVED):** **exactly 64** = the band ceiling
  (`R1_DENSITY_BAND_CEILING`) — proves a mis-set px_area sweep CANNOT explode; the global ceiling holds.

14 chasing bodies at the preset is a modest load (the existing R1 preset already spawns 5 J2 hazards).
The mandatory per-room cap + the band ceiling bound the worst case at 64 regardless of metric/size/density.
(A headless frame-time sample on the assembled scene was attempted but `--script`/SceneTree `await` driving
proved unreliable headless; the realised count + the cap bound are the load-bearing perf evidence per the
spec — RG1 can confirm the in-game frame-time when it drives the real loop.)

## Design deviations
**None functional.** Notes for the record (all within-spec):
- The spec's §(b) pseudocode for the seam was the *merged-branch* sketch; per the Phase-3 Resolved
  Decision D + the Director Disposition I built J3 as the **additive** model (J2 owns `_spawn_r1_hazards`;
  J3 adds `_populate_room_density`). Kept J3's budget math verbatim; did NOT rename or re-derive J2's
  `_hazard_spawn_position`/`_hazard_spawn_depths`. This is the spec's own override, not a deviation.
- `_density_spawn_positions` reuses the same stable (y,x) cell sort that `JunkPlacer` and
  `_hazard_spawn_position` use, rather than calling `_hazard_spawn_position` directly — because that helper
  collects floor cells of ALL pieces at a depth (cross-room), whereas J3 must keep a room's hazards inside
  THAT room. Same deterministic cell ordering, scoped to the single piece. Within the spec's "reuse the
  stable cell-ordering it uses" allowance.
- `r1_density_min_area` gate is on CELL area regardless of metric (a room-shape gate, not pixels), so the
  px_area metric doesn't let tiny pieces slip the floor at high mult. Reasonable, matches the spec intent.

## Handoffs / follow-ups
- Director sweep knobs for RG1: `r1_per_room_density` (preset start 1.0), `r1_density_per_room_cap` (3),
  `r1_density_min_area` (64), and the `px_area` metric option. The **loot-per-area sub-knob ships OFF and
  is never preset-on** (contradicts `depth_curve.gd`'s "don't flood deep rooms") — a swept lever RG2
  segments on only.
- Q F observation (surfaced, not pre-solved): a density hazard seeded inside a deep big room may be past
  `r1_depth_threshold` at spawn and wake almost immediately. If RG1 shows deep big rooms read instant-death,
  that is an R1 tuning call (`r1_depth_threshold`/`r1_linger_seconds` in the preset), not a J3 change.
