# Worklog — I1 Configurable level scale (room count + size + larger greybox pieces)

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer). **Process note:** the `environment-artist`
  greybox-piece-authoring scope (the new larger pieces) was executed WITHIN this
  programmer task for worktree atomicity — the pieces are geometry+socket greybox rects
  (no shippable art), authored to the B1 contract, so a single builder + single branch
  keeps the determinism-sensitive catalog seam coherent. One shared worklog, as required.
- **Milestone:** M1.2 (Wave 1)
- **Branch:** gp/I1
- **Commit:** 2cab397144475fafa8dbcde3a19e584e5b9ec5f2

## What changed
Turned two currently-baked spatial parameters into swept `RunConfig` knobs and added a
config-gated set of larger greybox room pieces, per the Director-LOCKED I1 scope (ships
all three: count override + size multiplier + new pieces).

- **Room COUNT override** — new `lvl_room_count` (sentinel -1 = baseline). The generator
  resolves the effective grow-loop target ONCE before the loop (`rc.effective_room_count`),
  so the determinism surface is a single value; no new RNG draw, no reorder. With lvl off
  the loop bound is `cfg.target_piece_count` exactly → byte-identical M1.0/M1.1 sequence.
- **Room SIZE multiplier** — new `lvl_size_mult` applied at MATERIALISATION as one shared
  integer `cell_size = round(16 * mult)` (`rc.effective_cell_size_px`). `_materialise_band`
  re-spaces pieces at `offset_cell * cell_size` AND sets `p.instance.scale = mult` so
  collision + visuals fill the scaled lane. Cell-space `band` / `fingerprint()` untouched.
- **Phase-3 build-breaking loot-seam fix** — threaded the SAME effective `cell_size` into
  `JunkPlacer.plan(..., cell_size_override)`. Pickups are parented to the band container at
  raw world coords (NOT children of scaled piece nodes), so without this they'd cluster at
  1x coords and land outside scaled rooms. Verified 0 mis-placed loot at mult 2.0.
- **New larger greybox pieces** (B1-compliant: WALL (1,0) perimeter + FLOOR (0,0) interior,
  `Marker2D` sockets with `dir`+`width_cells=2` metas on the last interior floor cell,
  `size_cells`, `cell_size_px=16`): `piece_room_xl` (16x12, NESW), `piece_chamber`
  (14x10, NESW), `piece_corridor_long_h` (16x4, WE), `piece_hall_v` (4x14, NS). They
  stitch, seal (BUG3/BUG4), and grade.
- **Determinism-safe catalog seam (Resolved G)** — `data/piece_catalog_ext.tres` (baseline
  6 pieces in the SAME order + the 4 new pieces appended). `main_game` uses the baseline
  catalog when `lvl_enabled` is off (byte-matches M1.0/M1.1) and the extended catalog when
  on. Each catalog fingerprint-tested independently.
- **CFG coverage** — new `lvl_` SECTION/MANIFEST/FIELD_RANGE (`RANGE_COUNT` (1,30),
  `RANGE_MULT` (0.5,4)) + a `FIELD_STEP` override so `lvl_size_mult` snaps to 0.25 (integer
  px/cell). `lvl_room_count` SpinBox min -1 to carry the sentinel. CSV strings added.
  `has_full_coverage()` passes (35/35 knobs).
- **TEL** — the three knobs added to `to_flat_dict()` (additive payload, no schema bump).
- **`all_oppositions_disabled()`** — `lvl_` deliberately EXCLUDED (Resolved E: orthogonal
  spatial axis; RG2 segments on it separately).

## Files touched
- `data/run_config/run_config.gd` — 3 new `lvl_` `@export`s; `effective_cell_size_px()` +
  `effective_room_count()` helpers; `to_flat_dict()` additions; `all_oppositions_disabled()`
  note (lvl_ excluded).
- `systems/bandgen/band_generator.gd` — resolve effective `target_count` once before the
  grow loop from `rc`.
- `scenes/game/main_game.gd` — config-dependent catalog pick; derive effective `cell_size`
  once; thread it into `placer.plan()` AND `_materialise_band()`; `_materialise_band` scales
  each piece (`scale = mult`).
- `systems/depth/junk_placer.gd` — `plan()` gains `cell_size_override` (loot world coords use
  the effective px/cell).
- `ui/config/config_menu.gd` — `lvl_` section/manifest/ranges/step, chip summary, `_prefix_of`.
- `ui/config/config_strings.csv` — `CFG_SEC_LVL`, `CFG_GLOSS_LVL`, `CFG_CHIP_LVL_SUMMARY`,
  `CFG_LVL_COUNT_BASE`, `CFG_FIELD_LVL_ROOM_COUNT`, `CFG_FIELD_LVL_SIZE_MULT`.
- `bands/pieces/piece_room_xl.tscn`, `piece_chamber.tscn`, `piece_corridor_long_h.tscn`,
  `piece_hall_v.tscn` — new greybox pieces.
- `data/piece_catalog_ext.tres` — the extended catalog (NEW).
- `tests/test_level_scale_determinism.gd` + `.tscn` — NEW determinism test (collision-guard:
  did NOT touch `test_bandgen_determinism.gd`, owned by BUG4 this wave).
- `tests/test_config_menu.gd` — exported-field count 32 → 35 (schema grew by 3).
- `tests/test_run_config.gd` — added the 3 lvl_ keys to the to_flat_dict completeness list.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `tests/test_level_scale_determinism.tscn` → LVL OK (count + size + per-catalog
      determinism across 9 seeds): all-off byte-matches M1.1 baseline; count==12 override
      byte-matches baseline; pinned count stable run-to-run; size mult NEVER changes
      fingerprint (layout-invariant); each catalog (baseline/extended) stable + connected +
      seals clean; ext catalog is a strict superset.
- [x] `tests/test_bandgen_determinism.tscn` → BANDGEN OK + BUG3 SEAL OK + R4 NAV OK
      (baseline fingerprint unmoved: sample seed 12345 still 12 pieces fp=e943ac9c8bc1).
- [x] `test_config_menu` → 35/35 knobs bound; `test_run_config` → R0 OK; `test_band_depth`,
      `test_junk_pickup`, `test_main_game_loop`, `test_telemetry_config_marking` → all OK.
- [x] Materialise/loot sanity (throwaway diag): at mult 2.0 effective cell = 32, piece +
      Geometry node scale = 2.0 (collision follows node scale), 0 loot mis-placed.

## Definition of done (quoted + verified)
- "Room count + size settable from CFG visibly change the band" — ✅ `lvl_` section in CFG;
  count grows the spine, mult scales rooms+spacing (verified).
- "new pieces stitch/seal/grade" — ✅ extended catalog stays connected + seals clean across
  all 9 seeds (test (d)); grader runs over them in the loop.
- "default (lvl_enabled=false / count -1 / mult 1.0) = M1.1 baseline byte-identical
  fingerprint" — ✅ test (a) + bandgen baseline fp unchanged.
- "determinism preserved (count rides the piece list, size is layout-invariant, each catalog
  stable)" — ✅ tests (b)/(b')/(c)/(d).
- "CFG `has_full_coverage()` passes" — ✅ 35/35.
- "`to_flat_dict()` carries the three knobs" — ✅ test_run_config + telemetry test.
- "loot places correctly at any mult" — ✅ 0 mis-placed at mult 2.0.

## Empirical room-count ceiling (for the Director's count sweep)
Swept requested counts {12,16,20,25,30,40,60} on both catalogs over 9 seeds: the linear
spine REACHED the requested count every time (max_achieved == requested, avg == requested) —
no boxing-in / undersized failure observed up to 60. So within the realistic sweep envelope
there is effectively NO count ceiling; the spine extends outward without self-collision on
the tested seeds. `_soft_floor` rescales off the override automatically and the graceful
`undersized` failure path (Resolved H) remains intact for pathological cases, but the
Director can sweep count freely in the 12–60 range. (Run-time, not piece-count, is the real
constraint — stacked with R2/R3 clock pressure under the ~15-min tier; that is RG1/RG2's
empirical tuning call, not I1's.)

## Design deviations
- **New piece authoring folded into the programmer task** (not a separate environment-artist
  dispatch). Process choice for worktree atomicity given the determinism-sensitive catalog
  seam; pieces are greybox geometry+sockets only, on the B1 contract. Recorded as a process
  note per the brief — NOT a design departure. Logged to `design/DESIGN_DEVIATIONS.md` for
  Director visibility.
- **`piece_hall_v` authored at 4 cells wide (interior 2), not the spec's illustrative 6x16.**
  A 6-wide vertical hall has a 4-cell interior, so its N/S perimeter openings would be 4
  cells wide while the socket declares `width_cells=2`, leaving 2 floor cells facing void
  after the (2-cell) seal (caught by the new determinism test on seeds 7 & 1000003).
  Matching the baseline `piece_corridor_v` 4-wide convention gives a true 2-cell opening that
  seals clean. This keeps within the spec's intent (a taller hall for traversal); the spec
  dimensions were illustrative ("e.g. 16x8 or 12x8"). Logged to DESIGN_DEVIATIONS.md.

## Handoffs / follow-ups
- Director count/size sweep (RG1/RG2) — knobs are configurable-not-balanced; the right values
  are empirical. Starting candidates: count {12,16,20}, mult {1.0,1.5,2.0,2.5,3.0} (all
  integer px/cell). Surfaced, not decided (Open Q A/C remain Director feel calls).
- The extended catalog's piece WEIGHTS (room_xl 2.5, long_h 3.5, hall_v 2.5, chamber 2.0) are
  greybox guesses biased toward the larger pieces; tune in the sweep if the band reads
  monotonous or too sparse.
