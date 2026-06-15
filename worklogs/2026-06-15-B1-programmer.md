# Worklog — B1 Zone-piece authoring format

- **Date:** 2026-06-15
- **Subagent:** programmer (general-purpose)
- **Milestone:** M1
- **Branch:** programmer/B1-zone-piece-format
- **Commit:** 238a502639430a70d2d7f0db673c46e866de7622

## What changed
Defined the atomic zone-piece authoring format and authored the greybox piece
roster that B2 (room-graph generator) will consume. A zone-piece is a
`Node2D` (ZonePiece) with a `Geometry` TileMapLayer blockout plus tagged
`Marker2D` sockets. Added the socket direction vocabulary, the per-piece root
script (footprint computed from `get_used_rect()`/`get_used_cells()` in
`_ready()`, sockets collected from `Sockets` Marker2D children), a 2-tile
greybox TileSet (FLOOR no-collision, WALL full-cell collision on the `world`
layer), 6 piece scenes, a debug pawn + walk-test harness, and a headless
integrity/walkability check. Implemented every "Open questions" recommendation
from the spec (socket on last interior floor cell centered on width; fixed
2-cell openings with authored `width_cells`; no runtime rotation — one scene per
orientation; footprint computed not hand-exported; single Geometry layer; 16px
cells).

## Files touched
- `data/zone_socket.gd` — `ZoneSocket` (RefCounted): `Dir{N,E,S,W}` enum + `dir_to_cell()`, `opposite()` (fixed the spec's `Dir[...]` sketch to `((int(d)+2)%4) as Dir` so it compiles), `dir_name()`.
- `bands/pieces/zone_piece.gd` — `ZonePiece` (Node2D): exported `piece_id`/`size_cells`/`cell_size_px`, inner `SocketInfo`, sockets collected in `_ready()` from `Sockets` Marker2D metas, footprint computed from Geometry (`footprint_cells`/`occupied_cells`), `sockets_facing()`.
- `data/zone_piece_data.gd` — `ZonePieceData` (Resource): scene/piece_id/weight catalog entry for B2.
- `data/tilesets/greybox.png` (+ `.import`) — flat-color 2-tile placeholder atlas (dark-grey FLOOR, light-grey WALL), 32×16, LFS-tracked.
- `data/tilesets/greybox.tres` — built-in TileSet, 16×16, FLOOR (no collision) + WALL (full-cell collision polygon) on physics layer `world` (bit 2).
- `bands/pieces/piece_corridor_h.tscn` (W,E), `piece_corridor_v.tscn` (N,S), `piece_corridor_l.tscn` (W,S), `piece_box_small.tscn` (E,W), `piece_box_large.tscn` (N,E,S,W), `piece_room_hub.tscn` (N,E,S,W) — the authored roster.
- `entities/debug/greybox_pawn.gd` + `.tscn` — CharacterBody2D (layer `pawn`=bit32, mask `world`=bit2) + CircleShape2D (r=5) + a visible dot; reads raw keys (not A1's Input Map) for zero coupling.
- `entities/debug/walk_test.gd` + `.tscn` — loads a piece, spawns the pawn at the first socket; the manual walkability harness.
- `tools/gen_greybox_texture.gd`, `tools/gen_greybox_tileset.gd`, `tools/gen_zone_pieces.gd`, `tools/gen_debug_scenes.gd` — one-shot generators (the recipes that produced the binary/.tres/.tscn artifacts; kept for reproducible re-gen).
- `tools/zone_piece_check.gd` — headless integrity + walkability check (loads all 6 pieces, asserts cells/footprint/sockets, FLOOR clear + WALL solid via space-state shape queries).
- `project.godot` — added `[global_group] socket` and `[layer_names]` (mirrors A1's locked 1-5 map and adds `pawn`=layer_6).

## Checks run
- [x] `godot --headless --import` clean (0 error/parse lines)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy`
- [x] `godot --headless --script res://tools/zone_piece_check.gd` → `ZONE PIECES OK — 6 pieces load, sockets tagged, floor walkable, walls solid`
- [x] definition of done met: "4–6 zone-piece scenes exist with consistently tagged entry/exit sockets; each loads standalone and is walkable by a CharacterBody2D." — 6 pieces, every socket tagged `dir`+`width_cells=2` on a FLOOR boundary cell; the check proves floor is walkable (pawn shape clear) and walls are solid (pawn shape collides) for every piece.

## Design deviations
- **Greybox tiles stubbed inline as flat-color placeholders** (generated via `tools/gen_greybox_texture.gd`) instead of dispatching the environment-artist / PixelLab. On-spec — the B1 spec explicitly says "No art. Use two flat color tiles" — so no Director sign-off needed; PixelLab is paid + human-gated and was deliberately not called.
- **Physics layer reconciliation:** the B1 spec says add layer names `world` + `pawn`. A1's concurrently-landed locked map already claims `world`=layer_2, so I aligned the greybox geometry/tileset to `world`=bit2 (not bit1) and put the debug pawn on a fresh `pawn`=layer_6 (bit32) to avoid clashing with A1's reserved 1-5. Functionally identical; respects A1's authority over the layer map. No Director sign-off needed.
- **`opposite()` fix:** the spec's sketch `Dir[(int(d)+2)%4]` does not compile (the enum is a Dictionary, not an ordinal-indexable array). Implemented as `((int(d)+2)%4) as Dir`. Correctness fix, not a design change.

## Handoffs / follow-ups
- **Stray empty dir `data/zone_pieces/`** exists in the repo (pre-existing). The spec puts pieces under `bands/pieces/` (which I followed). Recommend the producer delete the unused `data/zone_pieces/` dir to avoid confusion; I did not touch it.
- **Concurrent-agent git churn:** during this task the shared working tree was switched across A1/C1 branches by other agents mid-flight. I isolated my work onto `programmer/B1-zone-piece-format` and committed only my own files; other agents' uncommitted changes (`entities/player/`, `tests/`, `data/player/`, their `project.godot`/`settings.local.json` edits) were left untouched/stashed. Flag to the orchestrator: the single shared checkout is a collision risk for parallel dispatch — consider per-agent worktrees.
- **B2 (next):** consume `ZonePieceData` catalog `.tres` instances (not authored here — class only, per spec) + `ZonePiece.sockets`/`occupied_cells`/`footprint_cells` for deterministic stitching. Socket mate rule documented in `zone_piece.gd`: `cand.cell == sock.cell + ZoneSocket.dir_to_cell(sock.dir)` with `cand.dir == ZoneSocket.opposite(sock.dir)`.
