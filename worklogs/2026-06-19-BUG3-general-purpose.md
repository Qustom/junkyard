# Worklog — BUG3 Open sockets to off-map void

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.1 (wave 1)
- **Branch:** general-purpose/BUG3
- **Commit:** e9bc21f33618256c2e549a93f7a4a4a3003abea1

## What changed
Implemented Option (a) from the ratified BUG3 spec: a deterministic post-placement
"seal unused sockets" pass that closes every unmated socket opening so the player
can no longer walk through a perimeter gap into off-map void. The pass runs at
materialisation (not inside `generate()`), reads the already-final `band.open_sockets`,
and writes a 2-cell WALL cap (existing greybox WALL tile) into each owning piece's
Geometry TileMapLayer. It adds/reorders zero pieces and rolls zero RNG, so
`band.fingerprint()` is byte-identical with and without the seal — verified across the
seed sweep.

## Files touched
- `systems/bandgen/socket_sealer.gd` — NEW. `SocketSealer` (RefCounted) with
  `seal_unused_sockets(band, cell_size_px)` + `_opening_lane_cells(sock)` +
  `_place_wall_cap(owner, global_cell)`. Pure integer-cell math, zero RNG, zero edits
  to `band.pieces`/ordering. Keeps `generate()` a pure layout function (§7.4).
- `systems/bandgen/socket_sealer.gd.uid` — NEW (import-generated, tracked like sibling scripts).
- `scenes/game/main_game.gd` — single integration site: one call to
  `SocketSealer.new().seal_unused_sockets(band, cell_size)` at the end of
  `_materialise_band`, after pieces are parented. Minimal/localized so the later CFG
  edit to `main_game.gd` merges cleanly.
- `tests/test_bandgen_determinism.gd` — extended: BUG3.6 fingerprint-identical
  with-vs-without seal across the seed sweep; BUG3.7 no-open-socket structural invariant
  (no floor cell faces off-map void after sealing) plus a non-vacuity guard (the matching
  unsealed band is asserted to leak). Prints `BUG3 SOCKET SEAL OK`.

## `_opening_lane_cells` approach (the load-bearing detail)
The socket Marker2D is inset one cell; stepping along `dir_to_cell(sock.dir)` lands on
the boundary FLOOR cell of the opening (`edge_cell`). The 2-wide opening extends along
the perpendicular axis, but the marker sits at ONE END and the gap direction (+perp vs
-perp) is NOT uniform across sockets (it's +perp for N/W, -perp for E/S in B1). Rather
than hardcode that sign, the cap reads the OWNER piece's `floor_cells` and grows from
`edge_cell` into whichever perpendicular neighbour IS floor (the gap), covering
`width_cells` boundary cells. This is robust to future piece authoring and was the fix
after a first +perp-only version left corner leaks (E/S sockets).

## Env-artist convention verification (no new asset)
Decoded every `bands/pieces/piece_*.tscn` TileMapLayer: all use greybox tileset
**source id 0**, FLOOR atlas **(0,0)**, WALL atlas **(1,0)** (the cell-covering collision
tile on layer `world`). Confirmed for every authored socket that the marker is inset one
cell and the opening is the two boundary FLOOR cells of a wall gap. The cap **reuses the
existing WALL tile** — **NO new authored asset, no tile added** (§7.1). `greybox.tres`
untouched.

## Checks run
- [x] `godot --headless --import` clean (exit 0, no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK`
- [x] `godot --headless res://tests/test_bandgen_determinism.tscn` → `BANDGEN OK` +
  `BUG3 SOCKET SEAL OK` (exit 0): fingerprint byte-identical with/without seal across all
  9 seeds; no floor cell faces void after sealing; unsealed bands confirmed to leak.
- [x] `bash tools/run_gdunit.sh` → 30/30 test cases PASSED, exit 0.
- [x] Definition of done met: "no open socket leading off-map; band.fingerprint()
  preserved across the seed sweep; baseline otherwise unchanged (seal only adds boundary
  walls)."

## Design deviations
none. (Spec pseudocode sketched a centered `range(-half, width-half)` span and a fixed
`+perp` growth; the canonical M1_As_Built convention wins, and the verified-against-the-
real-pieces lane is the two boundary floor cells growing in the floor (gap) direction.
This is the spec's own §4 note — "nail `_opening_lane_cells` against the real pieces" —
not a design departure. `cell_size_px` is accepted but unused by the tile-write seam,
which works in pure cell space; kept for API symmetry / the alternate collider seam.)

## Handoffs / follow-ups
- Camera-clamp remains out of scope (§7.2), folded into R4 — unchanged.
- CFG will also edit `main_game.gd` after this; the BUG3 edit is a single localized line
  in `_materialise_band` to keep that merge clean.
