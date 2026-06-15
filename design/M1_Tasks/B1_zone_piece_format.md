# B1 — Zone-Piece Authoring Format

**Summary:** Define the atomic zone-piece as a hand-authored `PackedScene` built on `TileMapLayer` with consistently tagged entry/exit sockets, and author 4–6 greybox pieces (boxes, corridors, a room) using the built-in TileSet — blockout collision only.

- **Parent task:** B1
- **Dependencies:** None (foundational). Consumed by B2 (room-graph generator) and B3 (depth structure).
- **Acceptance criterion:** 4–6 zone-piece scenes exist with consistently tagged entry/exit sockets; each loads standalone and is walkable by a `CharacterBody2D`.

A zone-piece is the smallest reusable unit of level geometry. It is hand-authored (no proc-gen inside a piece), and B2 instances + stitches many of them. The contract B1 must nail is the *socket*: a tagged, directional connection point with a known world offset and grid size, so B2 can match exits to entries deterministically.

---

## Assets needed

Feature-first layout under the project root:

```
/data
  zone_socket.gd            # SocketDir enum + helpers (class_name ZoneSocketDir-style consts)
  zone_piece_data.tres      # OPTIONAL shared default ZonePieceData resource
  zone_piece_data.gd        # Resource subclass: metadata about a piece (size, tags)
/data/tilesets
  greybox.tres              # built-in TileSet: 1 floor tile (walkable), 1 wall tile (collision)
/bands/pieces
  piece_box_small.tscn
  piece_box_large.tscn
  piece_corridor_h.tscn     # horizontal corridor (W <-> E)
  piece_corridor_v.tscn     # vertical corridor (N <-> S)
  piece_corridor_l.tscn     # L-bend (e.g. W <-> S)
  piece_room_hub.tscn       # 4-exit room (N/S/E/W)
  zone_piece.gd             # script attached to each piece root; exposes sockets
/entities/debug
  greybox_pawn.tscn         # CharacterBody2D + CollisionShape2D for walkability smoke-test
```

**Greybox TileSet (`greybox.tres`):**
- Single source, 16×16 (or 32×32 — pick one cell size project-wide; recommend **16px**).
- Two tiles only: `FLOOR` (no collision) and `WALL` (one rectangular collision polygon covering the cell, physics layer = `world`).
- No art. Use two flat color tiles (e.g. dark grey floor, light grey wall) generated from a placeholder image or Godot's built-in atlas with solid-color regions.

**Zone-piece scene structure (every piece):**

```
ZonePiece (Node2D, script = zone_piece.gd)
├── Geometry (TileMapLayer, tile_set = greybox.tres)   # the blockout
└── Sockets (Node2D)
    ├── Socket_N (Marker2D, groups: ["socket"], meta: dir, width_cells)
    ├── Socket_E (Marker2D, ...)
    └── ...                                              # one Marker2D per opening
```

Sockets are authored as `Marker2D` children so the position is visible/editable in the editor. Each socket carries:
- `dir`: which wall it sits on (`N/E/S/W`) — drives adjacency matching.
- `width_cells`: opening width in tiles (so a 2-wide corridor only mates with a 2-wide opening).
- Implicit world offset = the Marker2D's `position` relative to the piece root.

**Piece roster (the 4–6 to author):**

| Scene | Shape | Sockets | Purpose |
|---|---|---|---|
| `piece_corridor_h` | 1×N strip | W, E | linear connector |
| `piece_corridor_v` | N×1 strip | N, S | linear connector |
| `piece_corridor_l` | bend | W, S (one variant) | turns the graph |
| `piece_box_small` | small room | E, W | filler / pacing |
| `piece_box_large` | large room | N, E, S, W | branch point |
| `piece_room_hub` | big open room | N, E, S, W | hub / set-piece |

This roster guarantees B2 has at least one straight, one turn, and one multi-exit branch — the minimum to produce a non-trivial connected band.

**Project settings:**
- Physics layer names: `world` (geometry), `pawn` (the test pawn).
- A `socket` node group registered for fast lookup.

---

## Code to generate

**`/data/zone_socket.gd`** — direction enum + opposite/offset helpers, used by both pieces and the B2 generator.

```gdscript
# zone_socket.gd  (autoload-free; pure static utility)
class_name ZoneSocket
extends RefCounted

enum Dir { N, E, S, W }

# Cardinal grid offset for a direction (in cells).
static func dir_to_cell(d: Dir) -> Vector2i:
    match d:
        Dir.N: return Vector2i(0, -1)
        Dir.E: return Vector2i(1, 0)
        Dir.S: return Vector2i(0, 1)
        Dir.W: return Vector2i(-1, 0)
    return Vector2i.ZERO

# A socket can only mate with the opposite-facing socket.
static func opposite(d: Dir) -> Dir:
    return Dir[(int(d) + 2) % 4]
```

**`/bands/pieces/zone_piece.gd`** — attached to each piece root. Reads its authored `Marker2D` sockets at load and exposes a typed list. This is what B2 queries.

```gdscript
# zone_piece.gd
class_name ZonePiece
extends Node2D

# Authored metadata (set per-scene in the inspector).
@export var piece_id: StringName = &"unnamed"
@export var size_cells: Vector2i = Vector2i.ONE   # bounding footprint in tiles
@export var cell_size_px: int = 16

class SocketInfo:
    var dir: ZoneSocket.Dir
    var local_pos: Vector2      # Marker2D position, piece-local
    var width_cells: int

var sockets: Array[SocketInfo] = []

func _ready() -> void:
    _collect_sockets()

func _collect_sockets() -> void:
    sockets.clear()
    for m in $Sockets.get_children():
        if m is Marker2D:
            var s := SocketInfo.new()
            s.dir = m.get_meta(&"dir") as ZoneSocket.Dir
            s.local_pos = m.position
            s.width_cells = int(m.get_meta(&"width_cells", 1))
            sockets.append(s)

# Sockets facing a given direction — B2 uses this to find candidate mates.
func sockets_facing(d: ZoneSocket.Dir) -> Array[SocketInfo]:
    return sockets.filter(func(s): return s.dir == d)
```

**`/data/zone_piece_data.gd`** — optional `.tres`-authored registry entry so B2 can iterate "all available pieces" without scanning the filesystem. (Can be deferred; for M1 a hardcoded array in B2 is acceptable.)

```gdscript
# zone_piece_data.gd
class_name ZonePieceData
extends Resource

@export var scene: PackedScene
@export var piece_id: StringName
@export var weight: float = 1.0   # selection weight for B2's seeded pick
```

**Determinism note for B1:** B1 itself does no RNG. But it *enables* determinism by guaranteeing every socket has a stable, declared `dir` + `local_pos` + `width_cells`. B2's seeded assembly is only reproducible if these authored values never depend on runtime/order. Authoring rule: **socket metadata is static, set in-editor, never computed at runtime.**

**Walkability smoke-test (acceptance):** a tiny standalone scene that adds `greybox_pawn.tscn` into a loaded piece and lets you drive it.

```gdscript
# /entities/debug/walk_test.gd  (attach to a test root, run any single piece)
extends Node2D

@export var piece_scene: PackedScene

func _ready() -> void:
    var piece := piece_scene.instantiate()
    add_child(piece)
    var pawn := preload("res://entities/debug/greybox_pawn.tscn").instantiate()
    pawn.position = piece.get_node("Sockets").get_child(0).position
    add_child(pawn)
    # Enable Debug Draw 2D for collision/nav visualization while testing.
```

Acceptance is met when each of the 4–6 piece scenes opens, the pawn spawns at a socket, and you can walk the full interior without falling through floor or clipping walls.

---

## Open questions

- **Socket placement convention:** Should the `Marker2D` sit *on the wall cell* (the opening tile) or *one cell outside* (where the neighbor's floor begins)? B2's offset math depends on this — recommend "on the boundary cell, centered on the opening" and document it once.
  - **Recommendation:** Place the `Marker2D` on the **last interior floor cell of the opening, centered on its width**, not in the empty neighbor cell. Store the socket's cell coordinate as `floor(local_pos / cell_size_px)`; B2 then mates two sockets by translating the candidate so `cand_sock_cell == sock_cell + ZoneSocket.dir_to_cell(sock.dir)` (the neighbor's matching cell lands exactly one step past our boundary in the socket's facing direction). Anchoring on a real floor cell (rather than empty space) keeps the marker visible/snappable in-editor and makes the offset pure integer-cell arithmetic with no rounding ambiguity. Document this as the single canonical rule so every authored piece obeys it.
- **Variable-width sockets vs fixed:** Is a single canonical opening width (e.g. 2 cells) enough for M1, or do we need width matching now? Fixed width is simpler and removes a whole class of B2 matching failures — defer variable width unless a piece demands it.
  - **Recommendation:** Use a **single fixed opening width of 2 cells** for every socket in M1. A 2-wide door reads as a real doorway (not a 1-tile pinch), guarantees a `CharacterBody2D` with a sub-cell collider passes through cleanly, and makes B2's matching purely directional — no width predicate, zero width-mismatch dead ends. Still author and populate `width_cells` (always `2`) so the field exists and B2's matcher can begin checking it the day a piece needs a wider/narrower socket; defer the actual variable-width logic to a later milestone.
- **Rotation/mirroring:** Do we author each orientation as its own scene (more files, zero runtime transform risk) or allow B2 to rotate a piece 90°? Rotation multiplies coverage from few pieces but complicates socket transforms and TileMapLayer rotation. Recommend **no runtime rotation for M1** — author distinct variants.
  - **Recommendation:** **No runtime rotation or mirroring for M1 — author each orientation as a distinct scene.** Rotating a `TileMapLayer` and its per-cell collision while keeping socket `dir`/`local_pos` consistent is exactly the kind of float/transform step that threatens the byte-identical determinism requirement, and the roster (corridor_h/v, corridor_l, hub) already covers the cardinal cases by hand. With only 4–6 pieces the extra .tscn files are cheap insurance. Defer transform-based variant generation until determinism is locked and a piece-count explosion actually justifies it.
- **Bounding footprint accuracy:** `size_cells` must match the actual TileMapLayer extent for B2's overlap checks. Should this be exported-by-hand (error-prone) or computed once in `_ready()` from `get_used_rect()`? Computed-from-tiles is safer; confirm it stays deterministic.
  - **Recommendation:** **Compute the footprint once in `_ready()` from `Geometry.get_used_rect()`** rather than exporting `size_cells` by hand. `get_used_rect()` returns the minimal integer `Rect2i` enclosing all set cells and is a pure function of the authored tile data — same tiles in, same rect out, so it is deterministic and stays in lockstep with edits ([source](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html)). For B2's overlap test, use the actual **set of occupied cells** from `get_used_cells()`, not just the bounding rect, so non-rectangular pieces (the L-bend) don't reserve empty corner cells and falsely block placement. Keep the `@export var size_cells` field as an editor-visible convenience that you assign from the computed rect, but treat the computed value as authoritative.
- **One TileMapLayer vs multiple:** Single `Geometry` layer for M1, or split floor/wall/decoration now? Single layer is enough for greybox; flag if B3's junk placement wants a separate layer.
  - **Recommendation:** **One `Geometry` TileMapLayer for M1.** Greybox needs only floor (no collision) and wall (collision) tiles, both of which live happily in one layer, and a single layer keeps `get_used_cells()`/footprint logic trivial. B3 does **not** need a tile layer for junk — pickups are `Area2D` scene instances added as children, not tiles, so they never touch the geometry layer. Defer a floor/wall/decoration split to the art pass (post-M1), where draw-order and a separate non-colliding decoration layer actually start to matter.
