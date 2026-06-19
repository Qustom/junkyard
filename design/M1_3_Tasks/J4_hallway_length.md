# J4 — Configurable hallway length + corridor telemetry (M1.3 spec)

**Milestone:** M1.3 — Legibility & Density (iteration of M1.2) · **Workstream:** Wave 2 — Density & spatial
**Task id:** J4 · **dependsOn:** J1 (owns `run_config.gd`/`config_menu.gd`/CFG in Wave 1; J4's knob layers on top in Wave 2)
**Assignees (build wave):** `general-purpose` (RunConfig knob + generator/materialise wiring + corridor-time telemetry seam + CFG/TEL coverage)
**Status:** Phase-2 design spec (this doc). Phase-3 fresh-eyes pass resolves §3 Open Questions before build.
**Companion docs:** `M1.3_Breakdown.md` §J4/§4/§5/§6 · `G4_findings_M1.2.md` §3 (I1 read: "extra time = corridor traversal") + §5 (F3a) · `M1_2_Tasks/I1_level_scale.md` (the `lvl_` group + the size-mult materialise seam + the (seed+config) determinism contract J4 inherits) · `M1_As_Built.md` (proc-gen, determinism, Telemetry) · `data/run_config/run_config.gd` · `systems/bandgen/band_generator.gd` · `scenes/game/main_game.gd` · `systems/telemetry/telemetry.gd` · `systems/event_bus.gd`

> **Scope guardrail (Breakdown §2):** J4 is **greybox + configurable-not-balanced**. It exposes a corridor/hallway-length lever as a swept `RunConfig` knob and emits a corridor-time telemetry metric so the re-gate can measure "time in hallway" directly instead of inferring it. Acceptance is *"the knob exists, is reachable from CFG, shortens corridor traversal independently of room size, the all-off default reproduces the M1.2 baseline (fingerprint + pixels), and a corridor-time metric appears in the JSONL as an additive payload (no schema bump, no `run_ended` arity change)."* It is **NOT** a generator rewrite, **NOT** new corridor content balancing, **NOT** a new band. If the re-gate (RG3) says "fun," M2 builds the real spatial system; if not, we re-tune or cut.

---

## 1. Goal & premise research

**The one sentence:** *Let the Director shorten the boring dead-time the player spends walking down corridors — independent of how big the rooms are — and emit a direct "seconds spent in corridor vs. room" telemetry metric so the re-gate can prove whether the fix landed.*

### Why this task (the G4 finding — F3a)

`G4_findings_M1.2.md` §3 (the I1 read) and §5 (F3a) establish the exact defect, with data:

- **Bigger rooms feel good; the *added* dive time is mostly hallway, not decisions.** The I1 size knob (`lvl_size_mult`) measurably turned the 17 s sprint into 25–60 s expeditions (§3 I1 table). But `nav_branch_taken` stayed **flat at ~6–7 junctions/run regardless of size** (size 2×: 7.0/run, 4×: 6.6/run, 10×: 5.3/run). Junction *count* per run is flat while run *duration* grows with size → **the extra time is corridor traversal between the same number of junctions — dead corridor time, not extra meaningful choices** (G4 §3 I1, verbatim).
- **The Director's qualitative read matches:** "huge rooms good, long hallways boring → configurable hallway length" (G4 §4 table row 3a; §5 F3a). The fix is to make corridor length **its own lever**, decoupled from room size — shorten the dull halls while keeping the big rooms.
- **The metric is currently inferred, not measured.** G4 §3 I1 explicitly flags: *"A precise time-in-corridor metric isn't emitted yet — flag for M1.3 telemetry: timestamp corridor entry/exit so this is directly measurable, not inferred."* RG2 wants this so the re-gate can compare "fraction of run spent in corridor" across M1.0/M1.1/M1.2/M1.3 on the same axis.

So J4 has **two halves**: (a) a corridor-length lever decoupled from room size, and (b) a corridor-time telemetry metric.

### The corridor-vs-room reality (real files / APIs)

**Pieces are typed by `piece_id`, and corridor pieces are physically longer cell-footprints.** From the piece `.tscn`s (`bands/pieces/`) and the extended catalog (`data/piece_catalog_ext.tres`), the catalog splits cleanly into corridor-like vs. room-like pieces by `size_cells` and by `piece_id` prefix:

| piece_id | `size_cells` | kind |
|---|---|---|
| `piece_corridor_h` | 8×4 | corridor |
| `piece_corridor_v` | 4×8 | corridor |
| `piece_corridor_l` | 6×6 | corridor (L-bend) |
| `piece_corridor_long_h` | **16×4** | corridor (the long one — I1 added it) |
| `piece_hall_v` | 4×14 | corridor (tall hall — I1 added it) |
| `piece_box_small` | 6×6 | room |
| `piece_box_large` | 10×8 | room |
| `piece_room_hub` | 12×12 | room |
| `piece_room_xl` | 16×12 | room (I1 added) |
| `piece_chamber` | 14×10 | room (I1 added) |

The corridor pieces are the **long, thin** footprints (one dimension ≫ the other, the other = the 4-cell socket lane). `piece_corridor_long_h` is **16 cells long** — exactly the "boring long hallway" the Director named. **Corridor length is therefore TWO things at once:**

1. **Baked into the corridor `.tscn` footprints** (the cell length of `piece_corridor_long_h`/`piece_corridor_h`/`piece_hall_v`), and
2. **Selected by the generator's weighted draw** — `data/piece_catalog_ext.tres` weights corridors heavily (`corridor_h`=5.0, `corridor_long_h`=3.5, `hall_v`=2.5, vs `room_xl`=2.5, `chamber`=2.0). A high corridor weight + the long corridor piece → lots of long-corridor cells in the spine.

**`lvl_size_mult` currently scales corridors TOO — that is the coupling J4 must break.** `RunConfig.effective_cell_size_px(base)` returns `round(16 * lvl_size_mult)` (run_config.gd:171), and `main_game.gd` `start_new_run()` derives `cell_size_px` once from it (line 204-206) and feeds it to BOTH `JunkPlacer.plan()` and `_materialise_band()`. `_materialise_band` (line 341) sets each piece `position = offset_cell * cell_size` and `scale = cell_size / base_cell`. So **a 16-cell corridor at `lvl_size_mult=4.0` becomes 16 cells × 64 px = 1024 px long** — the corridor stretches exactly as much as the rooms. The player crosses it at a fixed 200 px/s (`player_movement.tres`, verified in I1 Resolved D — player speed is unscaled px/s). Result: **dialing up room size to make rooms feel like a journey also inflates every corridor into a slog.** That is precisely the G4 "extra time = corridor traversal" signature.

**Where the player's owning piece is already resolved (the telemetry seam already exists).** `main_game.gd` already tracks which piece the player is in, every depth tick:

- `_build_junction_map(band)` (line 402) builds `_cell_to_junction`: `band-global FLOOR cell → Vector2i(piece_index, junction_degree)`.
- `_resolve_player_depth()` (line 448, driven by `_physics_process` every `depth_tick_interval`) computes the player's cell and calls `_maybe_emit_branch_taken(cell)`.
- `_maybe_emit_branch_taken` (line 466) reads `_cell_to_junction[cell]`, extracts `piece_index`, and compares to **`_player_piece_index`** (line 99, the persistent "which piece am I in" tracker) — **emitting `nav_branch_taken` exactly once on a piece-to-piece transition.**

This is the clean seam J4 needs: **the build already detects "player entered a new piece."** J4 only has to (1) know each piece's *kind* (corridor vs. room) and (2) accumulate wall-clock time against the current piece's kind. No new traversal/sampling system is required — it rides the existing per-piece tracking.

**Telemetry / signal infrastructure.** `systems/telemetry/telemetry.gd` listens on EventBus, mints a per-run id, and writes JSONL rows via `_emit_row(type, data)` (additive `data` payloads, schema v1, `run_ended` fixed-arity `(reason, duration_s, depth_reached)` — all locked per §2). The M1.1 opposition signals (`hazard_caught`, `nav_branch_taken`, etc.) live in one pre-declared block in `event_bus.gd` (lines 83-110); the M1.1 contract is **the owner declares any new signal on `main` before a parallel wave, the rest subscribe** (Breakdown §6).

---

## 2. Design / approach + pseudocode

J4 ships **(A) a corridor-length lever decoupled from room size** and **(B) a corridor-time telemetry metric**. The all-off default of the lever = today's behaviour (corridors scale exactly as M1.2), and the metric is purely additive, so the all-off control is unchanged on both axes.

### Part A — the corridor-length lever (three candidate mechanisms; recommendation below)

The lever must shorten corridor traversal *independently* of `lvl_size_mult`. There are three ways to do it; the Phase-3 agent / Director picks (Open Qs A–D). The spec presents all three so the choice is informed.

**Option (a) — a separate corridor cell-scale at materialisation (`lvl_corridor_len_mult`) (RECOMMENDED).** Add a knob that scales corridor pieces' *length* by a factor distinct from `lvl_size_mult`. At materialise, corridor pieces get a per-piece cell size = `room_cell_size × lvl_corridor_len_mult` (default 1.0 = today). Because `_materialise_band` already positions each piece at `offset_cell × cell_size` and scales each piece individually (`p.instance.scale`), a per-piece-kind cell size is a localized change to that loop. But a *uniform* per-corridor scale on the px projection alone re-spaces and re-scales the corridor but **also moves every downstream piece's world origin** (pieces abut), so the cleanest decoupled form is to shrink corridors **only along their length axis** while keeping the socket-lane (cross) axis equal to the room cell size so doorways still align.

> ⚠ This is the subtle part: corridors abut rooms at sockets. If a corridor is scaled smaller than the room cell size, the doorway lane (the 4-cell socket width) shrinks too and the seam mismatches the room's opening. **The decoupled-length form must scale ONLY the long axis** (the corridor's length), leaving the perpendicular socket-lane axis at the room cell size. That keeps the doorway 2-cell opening at the same px width as the room it mates, so no seam — only the corridor gets shorter. See pseudocode below and Open Q B (this is the load-bearing geometry call).

**Option (b) — bias the weighted draw away from long corridors (`lvl_corridor_weight_mult`).** A knob that multiplies the catalog weight of corridor pieces (especially `piece_corridor_long_h`) down, so the generator picks fewer/shorter corridors and more rooms. This is a *cell-space* change: it alters the weighted-pick sequence → **it moves `fingerprint()`** (a different band per config). That is allowed under the (seed+config) contract (a config-keyed layout change), but it is a coarser lever — it changes *which* pieces appear, not their length, and it changes the room:corridor *ratio* as a side effect.

**Option (c) — drop the long corridor piece from the catalog at a threshold (`lvl_short_corridors`).** A bool that swaps `piece_corridor_long_h` out of the effective catalog (or down-weights it to ~0), forcing only short corridors. Also a cell-space change (moves `fingerprint()`); coarsest of the three (binary, not a dial).

**Recommendation:** ship **Option (a) — a length-axis-only `lvl_corridor_len_mult`** for M1.3. It is the only one that *directly* answers "make the dull corridors shorter independent of room size": it shrinks corridor traversal time as a continuous dial, leaves room size on its own `lvl_size_mult` axis, and — because it is a *pure pixel projection along one axis* — **does NOT move `fingerprint()`** (the cell-space layout, piece selection, and weight table are untouched; only the px length of corridor pieces changes). That keeps the all-off control byte-identical and is the smallest determinism surface. Option (b)/(c) are coarser, move the fingerprint, and conflate "shorter corridors" with "fewer corridors / more rooms" (which is closer to J2/J3's density job). **This recommendation is a Director-review item** (it trades "real fewer/shorter corridor *pieces*" for "same layout, corridors visually compressed"). See Open Q A/B.

```gdscript
# run_config.gd — NEW knob in the existing "Level Scale" lvl_ group (J1 owns this
# file in Wave 1; J4 adds ONE field in Wave 2 — single-writer handoff, see §4).
## Corridor-length multiplier applied at MATERIALISATION along the corridor's
## LENGTH axis only (the socket-lane / cross axis stays at the room cell size so
## doorways still align). 1.0 = baseline (corridors scale exactly with rooms, M1.2).
## < 1.0 = shorter corridors (less dead traversal) WITHOUT shrinking rooms.
## Decoupled from lvl_size_mult on purpose (F3a: rooms big, halls short).
## Layout-invariant: a length-axis px projection does NOT change fingerprint().
@export var lvl_corridor_len_mult: float = 1.0
```

```gdscript
# main_game.gd — _materialise_band(): apply the corridor length mult ONLY to
# corridor pieces, ONLY along their long axis. Rooms are untouched. The room
# cell_size (from lvl_size_mult, already resolved at the call site) is the base.
func _materialise_band(band: Band, cell_size: int = DEFAULT_CELL_SIZE_PX,
        corridor_len_mult: float = 1.0) -> int:
    for p in band.pieces:
        if p.instance == null:
            continue
        var base_cell := p.instance.cell_size_px if p.instance.cell_size_px > 0 else DEFAULT_CELL_SIZE_PX
        var room_mult := float(cell_size) / float(base_cell)
        if _is_corridor(p) and corridor_len_mult != 1.0:
            # Scale ONLY the length axis; socket-lane axis stays at room_mult so
            # the doorway opening matches the room it mates (no seam).
            var axis := _corridor_long_axis(p)   # Vector2i(1,0) for H, (0,1) for V
            var sx := room_mult * (corridor_len_mult if axis.x == 1 else 1.0)
            var sy := room_mult * (corridor_len_mult if axis.y == 1 else 1.0)
            p.instance.scale = Vector2(sx, sy)
            p.instance.position = _corridor_compressed_position(p, cell_size, corridor_len_mult, axis)
        else:
            p.instance.scale = Vector2.ONE * room_mult
            p.instance.position = Vector2(p.offset_cell * cell_size)
        _band_container.add_child(p.instance)
    SocketSealer.new().seal_unused_sockets(band, cell_size)
    return cell_size
```

> **The hard sub-problem (flag for Phase-3 / build): re-packing the spine after compression.** The naive sketch above scales a corridor's *visuals* but every piece is laid out at `offset_cell × cell_size` in a fixed cell grid — shrinking a corridor's visual length leaves a *gap* between it and the next piece (the next piece's `offset_cell` was computed for the full-length corridor). Two ways to handle it:
> - **(a1) Visual-compress-and-gap (simplest, cosmetically wrong):** scale corridors down in place; the player crosses less *visible* corridor but the cell-space gap remains as empty floor — the player still walks the same world distance. **This does NOT reduce traversal time** → it fails the goal. Reject.
> - **(a2) Re-pack world positions post-generation (correct):** after the cell-space band is final, walk the spine in placement order and accumulate a *world* offset, subtracting the saved length from each compressed corridor so downstream pieces shift up to close the gap. This is a **pure pixel-space re-projection** (cell-space `band`/`fingerprint()` untouched) — the same family as I1's size-mult, but per-piece-cumulative instead of uniform. It genuinely shortens the path → reduces traversal time. **This is the form J4 should ship.** It requires the materialise loop to compute each piece's world position from a running cumulative offset rather than `offset_cell × cell_size` directly. **Phase-3 must confirm the re-pack preserves doorway adjacency** (the perpendicular alignment is unchanged; only the along-spine distance shrinks). This is the one genuinely non-trivial piece of J4 — see Open Q B.

Because (a2) is non-trivial, **a simpler fallback that still meets the goal** is worth flagging: **Option (a-lite) — uniform corridor cell-size reduction with re-spacing handled by the existing `offset_cell × cell_size` math, by giving corridors a SMALLER effective `cell_size` than rooms.** This keeps the existing position formula but breaks doorway-lane alignment (corridor cells shrink in both axes) unless the socket lane is handled. The length-axis-only re-pack (a2) is cleaner; see Open Q B for the trade.

> **Determinism note (Part A, Option a):** the corridor-length compression is a **pure pixel-space re-projection applied after generation** — it does not change the cell-space `band`, the piece catalog, the weight table, or any RNG draw. Therefore `fingerprint(seed + config)` is **unchanged by `lvl_corridor_len_mult`** (same layout, corridors visually/positionally compressed) — exactly like `lvl_size_mult` is layout-invariant (I1 Resolved F). The all-off default (`lvl_corridor_len_mult = 1.0`) byte-matches the M1.2 band AND its pixel projection. **If Phase-3/Director instead picks Option (b)/(c) (weight/catalog change), that DOES move `fingerprint()`** — allowed as a config-keyed layout change per the (seed+config) contract, but it must be called out and the all-off byte-match must still hold (the knob's default leaves the weight table/catalog untouched). Spell out whichever is chosen in the worklog.

### Part B — corridor-time telemetry

Measure **seconds spent in corridor pieces vs. room pieces**, accumulated across the run, emitted on `run_ended` as an additive `data` field (no schema bump, no arity change). The seam is the existing per-piece tracking in `_resolve_player_depth` / `_player_piece_index`.

**Step 1 — classify each piece's kind once, at band build.** Build a parallel `_cell_to_piece_kind` map alongside `_cell_to_junction` (or extend the junction map's value), keyed by the same band-global floor cells. Kind is derived from `piece_id` (corridor pieces are the `piece_corridor_*` / `piece_hall_*` ids, or — more robustly — derived from `size_cells` aspect ratio: a corridor is a piece whose footprint is long-and-thin). Recommendation: a small `_is_corridor(placed)` helper that checks the `piece_id` prefix against a known corridor set, with the aspect-ratio rule as a fallback for any future piece (see Open Q E).

```gdscript
# main_game.gd — classify pieces once at band build (extends _build_junction_map's pass).
const _CORRIDOR_PIECE_IDS := {
    &"piece_corridor_h": true, &"piece_corridor_v": true, &"piece_corridor_l": true,
    &"piece_corridor_long_h": true, &"piece_hall_v": true,
}

func _is_corridor(p: PlacedPiece) -> bool:
    if _CORRIDOR_PIECE_IDS.has(p.piece_id):
        return true
    # Fallback for future pieces: long-and-thin footprint = corridor.
    var s := p.instance.size_cells if p.instance != null else Vector2i.ZERO
    return s != Vector2i.ZERO and (maxi(s.x, s.y) >= 3 * mini(s.x, s.y))
```

**Step 2 — accumulate time against the current piece's kind, every physics tick.** `_physics_process` already runs each frame while `run_active`; the depth resolver runs every `depth_tick_interval`. Accumulate `delta` against whichever kind the player's current piece is — using `_player_piece_index` (already maintained) to look up the kind. This is a per-frame accumulator, NOT a sampling approximation, so it is exact regardless of tick throttling.

```gdscript
# main_game.gd — per-run accumulators (reset on run_started, like Telemetry's).
var _corridor_time_s: float = 0.0
var _room_time_s: float = 0.0

func _physics_process(delta: float) -> void:
    if not GameState.run_active:
        return
    # Accumulate corridor/room time EVERY frame (exact), keyed by the current piece.
    _accumulate_piece_time(delta)
    _depth_tick_accum += delta
    if _depth_tick_accum < depth_tick_interval:
        return
    _depth_tick_accum = 0.0
    _resolve_player_depth()   # updates _player_piece_index on piece transitions

func _accumulate_piece_time(delta: float) -> void:
    if _player_piece_index < 0:
        return  # not yet resolved into a piece (frame 0 / mid-doorway)
    if _piece_kind_by_index.get(_player_piece_index, false):  # true == corridor
        _corridor_time_s += delta
    else:
        _room_time_s += delta
```

> Note: `_player_piece_index` is updated inside `_maybe_emit_branch_taken`, which currently only runs the piece-transition logic when R4 is enabled (the junction emit is R4-gated). **The piece-index tracking must run unconditionally** so corridor-time works with R4 off (the J1 default preset has R4 *on*, but the all-off control and other configs may not). Phase-3 must confirm the build hoists the `_player_piece_index` update out of the R4 gate, or J4 maintains its own piece-index tracker off `_cell_to_junction[cell].x`. This is a small but real cross-task interaction with the R4 path — see Open Q D + §4.

**Step 3 — emit on run end.** The cleanest, lowest-risk emission is an **additive field on the existing `run_ended` telemetry ROW** (NOT the signal — the signal arity is locked). Telemetry's `_on_run_ended` builds the `RUN_ENDED` row's `data` dict; J4 adds two keys. But MainGame, not Telemetry, owns the accumulators, so MainGame must hand them to Telemetry. Two clean ways:

- **(B-i) A new EventBus signal `corridor_time_summary(corridor_s, room_s)`** that MainGame emits just before `run_ended`, and Telemetry caches → folds into the `run_ended` row's `data` (or emits its own `corridor_summary` row). This is the M1.1 pattern (a dedicated, pre-declared signal). **Pre-declare it on `main` before Wave 2** (the M1.1 way; owner = whoever declares EventBus that wave — coordinate with the wave's single-writer for `event_bus.gd`). Recommendation: a **dedicated `corridor_summary` JSONL row** (additive type, like `junk_lost`), emitted by Telemetry on receiving the signal — keeps `run_ended`'s row shape stable and is the least-coupled option.
- **(B-ii) MainGame reads/pushes via GameState** (no new signal): stash the two accumulators somewhere Telemetry reads in `_on_run_ended`. More coupling, no signal. Less clean than (B-i).

**Recommendation: (B-i) with a dedicated `corridor_summary` row** — pre-declare `corridor_time_summary(corridor_s: float, room_s: float)` on EventBus the M1.1 way; MainGame emits it on run end (before/with `run_ended`); Telemetry adds `_on_corridor_time_summary` → `_emit_row(Schema.CORRIDOR_SUMMARY, {"corridor_s": ..., "room_s": ..., "corridor_frac": corridor_s/(corridor_s+room_s)})`. This adds one schema *type string* (a new event type is NOT a schema *version* bump — the M1.1 oppositions added type strings freely; v stays 1) and one signal, both additive. **No `run_ended` arity change, no schema version bump.**

```gdscript
# event_bus.gd — pre-declared in the M1.1 opposition-signals block (owner declares
# on main BEFORE Wave 2; see §4). Payload primitives only (JSONL-clean).
signal corridor_time_summary(corridor_s: float, room_s: float)
```

```gdscript
# telemetry.gd — new handler + schema type (additive; v stays 1).
EventBus.corridor_time_summary.connect(_on_corridor_time_summary)

func _on_corridor_time_summary(corridor_s: float, room_s: float) -> void:
    var total := corridor_s + room_s
    _emit_row(Schema.CORRIDOR_SUMMARY, {
        "corridor_s": corridor_s,
        "room_s": room_s,
        "corridor_frac": (corridor_s / total) if total > 0.0 else 0.0,
    })
    if _writer != null:
        _writer.flush()  # end-of-run summary, like run_ended
```

```gdscript
# main_game.gd — emit just before the run_ended path resolves (extract/death/timeout).
# Reset the accumulators on run_started (alongside the existing run-state reset).
EventBus.corridor_time_summary.emit(_corridor_time_s, _room_time_s)
```

> **Schema / arity discipline:** `CORRIDOR_SUMMARY` is a new **event-type string** in `telemetry_schema.gd` (like `JUNK_LOST`, `HAZARD_CAUGHT`) — additive, `SCHEMA_VERSION` stays 1. The `run_ended` row and signal are untouched. RG2 reads `corridor_frac` per config to measure F3a directly. Even with `lvl_corridor_len_mult = 1.0` (all-off), the row still emits — so RG2 gets a corridor-fraction baseline for M1.0/M1.1/M1.2-style configs too (the metric is comparable across versions because it's just "fraction of run in corridor pieces," which any band has).

### How all-off / default reproduces the M1.2 baseline

| Knob / metric | All-off default | Effect |
|---|---|---|
| `lvl_corridor_len_mult` | `1.0` | corridors scale exactly with `lvl_size_mult` (M1.2 behaviour); re-pack is a no-op |
| corridor-time accumulators | always run | additive; emit a `corridor_summary` row only — never alters `run_ended` or layout |
| `corridor_time_summary` signal | declared, emitted every run | additive EventBus signal; inert effect on gameplay/determinism |

With `lvl_corridor_len_mult = 1.0` the materialise loop takes the unchanged `Vector2.ONE * room_mult` path and `offset_cell × cell_size` positions (byte-identical to M1.2); `fingerprint()` is untouched (no cell-space change). The corridor-time metric is observation-only. **The all-off control (fp=`e943ac9c8bc1`) is unchanged on both axes.**

### How the knob joins the determinism key + CFG + TEL coverage

- **`lvl_corridor_len_mult`** is a **pure pixel re-projection** (Option a) → does **NOT** change `fingerprint()` (layout-invariant, like `lvl_size_mult`). Test obligations: (1) all-off fingerprint still byte-matches M1.2; (2) a test asserts `lvl_corridor_len_mult` does NOT change `fingerprint()` for a fixed seed (layout invariance); (3) a test asserts the re-packed world positions still keep doorway adjacency (pieces remain connected) at a sub-1.0 mult.
- **CFG coverage:** adding the `@export` trips `has_full_coverage()` until wired. J4 must add `lvl_corridor_len_mult` to `MANIFEST["lvl_"]` (after `lvl_size_mult`) and a `FIELD_RANGE` entry (propose `RANGE_CORRIDOR = Vector2(0.25, 1.0)` — corridors can shrink to ¼, never grow past room scale, snapped to 0.25 steps so px stays integer). Plus the CFG CSV strings (`CFG_LBL_lvl_corridor_len_mult`, gloss). **Single-writer caveat:** J1 owns `config_menu.gd`/`config_strings.csv` in Wave 1; J4's CFG additions land in Wave 2 — see §4.
- **TEL coverage:** add `lvl_corridor_len_mult` to `RunConfig.to_flat_dict()` (so `run_started` snapshots it and RG2 can segment on it). Update `tests/test_run_config.gd` / `test_config_menu.gd` knob counts (the M1.1/M1.2 convention).

### Files to create / touch (build wave)

**Touch:**
- `data/run_config/run_config.gd` — ONE new `@export var lvl_corridor_len_mult` in the `lvl_` group + its `to_flat_dict()` entry. *(general-purpose; single-writer handoff — J1 owns this file in Wave 1, J4 adds its field in Wave 2; see §4.)*
- `scenes/game/main_game.gd` — the per-piece-kind materialise branch (corridor length re-pack), the `_is_corridor`/`_corridor_long_axis` helpers, the `_piece_kind_by_index` classification (extends `_build_junction_map`'s pass), the per-frame `_accumulate_piece_time`, the accumulator reset on `run_started`, the `corridor_time_summary` emit on run end, and hoisting `_player_piece_index` update out of the R4 gate. *(general-purpose; **Wave-2 `main_game.gd` collision with J2** — assign single-writer per file at brief time, §4.)*
- `systems/event_bus.gd` — pre-declare `corridor_time_summary(corridor_s, room_s)` in the opposition-signals block, on `main`, BEFORE Wave 2. *(M1.1 pre-declare rule.)*
- `systems/telemetry/telemetry.gd` + `systems/telemetry/telemetry_schema.gd` — connect `corridor_time_summary` → `_on_corridor_time_summary` → emit the new `CORRIDOR_SUMMARY` row type (additive; v stays 1). *(general-purpose)*
- `ui/config/config_menu.gd` + `ui/config/config_strings.csv` — the `lvl_corridor_len_mult` manifest/range/strings. *(general-purpose; single-writer handoff from J1, §4.)*
- `tests/test_run_config.gd` / `tests/test_config_menu.gd` — knob-count bumps; a fingerprint-invariance test for the corridor mult; a doorway-adjacency-after-repack test.

**Confirm NOT touched:**
- `systems/bandgen/band.gd` `fingerprint()` — unchanged (corridor length is presentation, like size; Option a does no cell-space change).
- `systems/bandgen/band_generator.gd` — NOT edited under Option (a) (the lever is materialise-side). *(Edited ONLY if Phase-3/Director picks Option b/c, the weight/catalog levers.)*
- `data/piece_catalog_ext.tres` / `data/bandgen_config.tres` — left as-is (corridor weights unchanged under Option a).
- `run_ended` signal + row arity, `SCHEMA_VERSION` — unchanged (additive type + signal only).

### Acceptance criteria (from Breakdown §J4, made concrete)

1. **Corridor length is settable + decoupled.** With `lvl_corridor_len_mult < 1.0` (and `lvl_enabled`), corridor pieces are shorter — the player crosses them in proportionally less time — while rooms keep their `lvl_size_mult` size. At `1.0` (or all-off), corridors scale exactly with rooms (M1.2).
2. **It actually reduces traversal time, not just visuals.** The world path through a corridor genuinely shortens (the re-pack closes the gap); a measurable drop in `corridor_s` for the same seed at a lower mult.
3. **All-off == M1.2 baseline.** With `lvl_corridor_len_mult = 1.0` (or `lvl_enabled = false`), the band is byte-identical (`fingerprint()`) and pixel-identical to the M1.2 baseline for a seed.
4. **Determinism preserved.** `lvl_corridor_len_mult` provably does NOT change `fingerprint()` (Option a, layout invariance); all-off fingerprint test green; doorway adjacency holds after the re-pack.
5. **Corridor-time metric emitted.** Every run emits a `corridor_summary` JSONL row with `corridor_s`, `room_s`, `corridor_frac` — additive type, `SCHEMA_VERSION` unchanged, `run_ended` untouched. RG2 can segment `corridor_frac` by config across M1.0–M1.3.
6. **CFG + TEL pick up the knob.** `has_full_coverage()` passes with the new field; `to_flat_dict()` carries it onto `run_started`; knob-count tests updated.

---

## 3. Open Questions (Phase-3 fresh-eyes resolves; Director-review items flagged)

**A. Corridor-length mechanism: separate length-mult (Option a) vs. down-weight long corridors (Option b) vs. drop the long piece (Option c)?** *(Director / scope call)*
Option (a) is a continuous dial that shortens *the same* corridors (layout-invariant, smallest determinism surface, but needs the world-position re-pack); (b)/(c) change *which* pieces appear (move `fingerprint()`, conflate "shorter halls" with "fewer halls / more rooms" — which overlaps J2/J3's density job). **Recommendation: Option (a)** — it is the only one that cleanly answers F3a ("shorten the dull corridors *independent of room size*") without bleeding into density. *Director-review: trades "real fewer corridor pieces" for "same layout, corridors compressed."* Could also ship (a) now and (b) as an M2 follow-up if "same corridors, just shorter" reads monotonous.

**B. The world-position re-pack: does length-axis-only compression preserve doorway adjacency, and is the per-piece cumulative re-projection worth the complexity vs. a simpler approximation?** *(build-time verification + a design call)*
The correct form (a2) re-packs every piece's world position by subtracting each compressed corridor's saved length, so downstream pieces shift up to close the gap — a pure pixel re-projection that genuinely shortens the path. The risk: a branchy band (R4 on, the J1 default) is **not a single linear spine**, so "walk the spine accumulating offset" must handle forks (each branch re-packs along its own sub-path from the fork). **Phase-3 must confirm:** (1) the re-pack keeps every doorway's perpendicular alignment (corridors only shrink along length, the socket-lane axis stays at room scale); (2) it handles branches (not just a linear chain); (3) `SocketSealer` (cell-space, inherits piece scale per I1 Resolved-moot) still seals correctly when corridors are non-uniformly scaled. **If the branchy re-pack is too costly for greybox**, a Director-acceptable fallback is to ship the lever **only for the linear-spine case** (R4 off / no forks) and no-op it on branchy bands, or to accept the simpler "shorter corridor pieces via a smaller corridor cell_size with the socket lane preserved" form. *Flag the chosen form + its branch handling in the worklog.* This is the one genuinely non-trivial engineering call in J4.

**C. Default corridor-length range + first-sweep values?** *(tuning — Director sweeps; configurable-not-balanced)*
J4 ships the knob, not the right value. Proposed `RANGE_CORRIDOR = Vector2(0.25, 1.0)`, 0.25 steps → mults {0.25, 0.5, 0.75, 1.0} (corridors can shrink to ¼, never exceed room scale). First sweep to propose: at the J1 default (`lvl_size_mult` ≥ 4.0), try `lvl_corridor_len_mult ∈ {0.25, 0.5, 1.0}` and read `corridor_frac` in RG2 — the goal is to pull corridor time *down* while the big rooms stay. **Resolve empirically in RG1/RG2.** *Director sweeps; not a Phase-3 value call.*

**D. Telemetry seam: per-frame accumulator (recommended) vs. entry/exit timestamping vs. sampling at the depth tick?** *(technical — Phase-3 resolves)*
The recommendation is a per-frame `delta` accumulator keyed by the current piece kind (exact, cheap, rides the existing `_player_piece_index`). Alternatives: (i) timestamp every corridor entry/exit (the G4 wording) and sum the intervals — equivalent but needs a per-transition timestamp store and edge-case handling at run-end mid-corridor; (ii) sample at `depth_tick_interval` and multiply by the interval — approximate, cheaper, but loses sub-tick accuracy. **Recommendation: per-frame accumulator** — exact and simplest given the seam already exists. **The one dependency to resolve:** `_player_piece_index` is currently updated *inside* the R4-gated `_maybe_emit_branch_taken`; corridor-time must work with R4 off, so the piece-index update must be hoisted to run unconditionally (or J4 maintains its own `_player_piece_index` off `_cell_to_junction[cell].x`). *Phase-3 confirm; small but real cross-path edit.*

**E. Piece-kind classification: hardcoded `piece_id` set vs. aspect-ratio rule vs. a `kind` tag on the piece resource?** *(technical — Phase-3 resolves)*
A hardcoded `_CORRIDOR_PIECE_IDS` set is simplest and exact for today's 10 pieces, but brittle if M2 adds pieces. An aspect-ratio rule (`max(s) ≥ 3·min(s)` = corridor) auto-classifies future pieces but could mis-tag an oddly-shaped room. The cleanest long-term seam is a `kind` enum (`corridor`/`room`) on `ZonePieceData` (the catalog `.tres`) — but that is a data-schema add. **Recommendation: hardcoded set with the aspect-ratio rule as fallback for M1.3** (greybox, 10 known pieces); flag the `kind`-tag-on-resource as the M2 clean-up if the corridor metric proves load-bearing. *Phase-3 resolves; the recommendation is low-risk.*

**F. Interaction with `lvl_size_mult` and the J1 default preset — what does the *default play-preset* set `lvl_corridor_len_mult` to?** *(Director / fun call — coordinate with J1)*
J1 ships the named default play-preset (size ≥ 4.0, R1+R4 on). The whole point of F3a is that big rooms + short halls is the fun combo — so **the default preset probably wants `lvl_corridor_len_mult < 1.0`** (e.g. 0.5), NOT 1.0. But the *code-level all-off RunConfig default* MUST stay `1.0` (the permanent baseline control, fp byte-match). So: code default = 1.0; play-preset default = the Director's swept value (likely < 1.0). **This is a Director fun call wired into J1's preset, informed by J4's first RG2 read.** *Flag for the Director; J1 owns the preset artifact, J4 owns the knob — coordinate the value at preset-authoring time.*

**G. Interaction with J2 (enemy spread) and J3 (per-room density) — do shorter corridors change where hazards/junk land?** *(cross-task — Phase-3 + Wave-2 ownership)*
J2 spawns hazards across depths; J3 fills big rooms with density. Hazard/junk world positions derive from cell→world (`_band_cell_size_px`, piece floor cells). Under Option (a), corridor compression changes corridor *piece* world positions but the re-pack shifts everything consistently — so a hazard placed on a *room* piece stays correctly inside that room (its world origin shifts with the re-pack). **But junk placed *in corridors* must use the same re-packed coordinates**, or it lands in the gap. Since `JunkPlacer.plan()` runs *before* materialise and computes off the (uncompressed) cell size, the re-pack must either (i) be mirrored in the junk planner, or (ii) junk be re-projected with the same per-piece world offset as the pieces. **This is the I1 junk-seam lesson recurring** (I1 Resolved: thread the effective cell size into JunkPlacer). Phase-3 must confirm corridor compression and junk placement share one coordinate source. *Cross-task with J3's density work — design the materialise/plan coordinate seam as one in Phase-2/3.*

**H. Multi-writer ownership for Wave 2 (`run_config.gd`, `main_game.gd`, `config_menu.gd`, `event_bus.gd`).** *(orchestrator — resolved at brief time, restated here)*
Wave 2 runs J2 (enemy spread) ∥ J4 (this) ∥ J3 (density), all potentially touching `main_game.gd` and the spawn/materialise seam. The Breakdown §5 mandates **single-writer-per-`.gd`-file per wave**. J4's writes: `run_config.gd` (one field — J1 already owns it in Wave 1, so J4's field is a *post-J1-merge* add in Wave 2; no overlap if sequenced after J1 lands on `main`), `main_game.gd` (the materialise branch + accumulators — **collides with J2/J3's hazard-spawn edits**), `config_menu.gd`/`config_strings.csv` (J1 owns in Wave 1 → J4 adds post-merge), `event_bus.gd` (pre-declare the signal on `main` before the wave), `telemetry.gd`/`schema` (J4-only). **Recommendation:** pre-declare `corridor_time_summary` on `main` before Wave 2; assign `main_game.gd` a single Wave-2 owner who integrates J2+J3+J4's edits to that file (or sequence J4's `main_game.gd` edit after J2/J3 on a shared branch), exactly the W1.1-2 single-writer discipline. *Orchestrator resolves the file-ownership map at brief time.*

---

*Authored by `game-director-designer` as Phase-2 of M1.3's four-phase breakdown (`CLAUDE.md` → "Version breakdown authoring"). This doc sets the J4 contract; a Phase-3 fresh-eyes pass resolves §3, then the Wave-2 build (general-purpose) builds against it. Update alongside `M1_As_Built.md` as J4 resolves.*

---

## Resolved Decisions (Phase 3 — fresh-eyes, 2026-06-19)

Independent programmer-lens pass by a reviewer who did **not** author §1–§3. Every cited file/API was read against the real source: `scenes/game/main_game.gd`, `data/run_config/run_config.gd`, `systems/bandgen/band_generator.gd`, `systems/bandgen/placed_piece.gd`, `bands/pieces/zone_piece.gd`, `systems/depth/junk_placer.gd`, `systems/telemetry/telemetry.gd` + `telemetry_schema.gd`, `systems/event_bus.gd`, `ui/config/config_menu.gd`, all 10 `bands/pieces/*.tscn`, and `M1_2_Tasks/I1_level_scale.md` (Resolved Decisions). **Most of the doc holds up — the corridor/room piece table is byte-accurate, the `_player_piece_index` / `_cell_to_junction` / `_maybe_emit_branch_taken` telemetry seam is real, the additive-row + pre-declared-signal patterns are correct, and Part B (corridor-time telemetry) is sound and low-risk.** But the **load-bearing Part-A re-pack has two real defects** that change the recommendation, and Part B needs one small but mandatory hoist. Both corrected below.

### Verification corrections to the body (read before building Part A)

- **⛔ CORRECTION — the "every corridor has ONE length axis" premise is FALSE for `piece_corridor_l`.** The §2 pseudocode (`_corridor_long_axis(p)` → `Vector2i(1,0)` or `(0,1)`) assumes every corridor is a straight H or V piece. `bands/pieces/piece_corridor_l.tscn` is an **L-bend**: its two sockets are on **perpendicular** axes (verified — socket `dir=3`/W at one opening, `dir=2`/S at the other). It has no single "length axis"; an anisotropic `scale = Vector2(sx, sy)` on an L-piece compresses one leg, leaves the other, and **tears the bend cell** (the corner floor cell no longer aligns to either leg). `piece_corridor_l` is in `_CORRIDOR_PIECE_IDS` *and* passes the aspect-ratio fallback's footprint test only as 6×6 (NOT long-and-thin → it would actually classify as a **room** under `max(s) >= 3*min(s)`, since 6 < 18). So the hardcoded set and the fallback rule **disagree** on the L-bend, and neither anisotropic scale nor a length-axis is well-defined for it. **Fix:** the corridor-length lever must **exclude L-bends (and any multi-axis corridor) from length-axis compression** — compress only straight single-axis corridors (`piece_corridor_h`, `piece_corridor_v`, `piece_corridor_long_h`, `piece_hall_v`), and either leave L-bends at room scale or treat them as rooms for both the lever and the re-pack. This is the geometry call Open Q B half-named; resolve it as "straight-corridor-only compression."

- **⛔ CORRECTION — anisotropic scale + the world re-pack is materially harder than the I1 size-mult, NOT "the same family."** §2 calls the re-pack "the same family as I1's size-mult, but per-piece-cumulative." That undersells it on two counts the build must respect:
  1. **I1's mult is UNIFORM and isotropic** (`p.instance.scale = Vector2.ONE * mult`, all pieces, both axes) and re-spacing falls straight out of `offset_cell * cell_size` with one shared integer `cell_size`. J4's lever is **non-uniform** (corridors only) and **anisotropic** (one axis), so the clean `offset_cell * cell_size` formula no longer produces abutting pieces — every downstream piece needs an explicit cumulative world shift. This is a genuine departure from the materialise loop's current shape, not a parameter tweak.
  2. **Anisotropic scale breaks the integer-px guarantee I1 leaned on.** I1 Resolved F snaps `lvl_size_mult` so `round(16*mult)` is an exact integer *and identical across materialise + JunkPlacer*. With a length-axis-only corridor mult the corridor's along-axis px-per-cell becomes `round(16 * lvl_size_mult * lvl_corridor_len_mult)` while its cross-axis stays `round(16 * lvl_size_mult)` — **two different effective cell sizes inside one piece.** Wall collision (a `TileMapLayer` under the scaled `ZonePiece`) follows Node2D `scale`, so it scales fine, but the **doorway seam** at the corridor's end faces must still land on the room's integer grid. That only holds if `corridor_len_mult` is *also* snapped so the compressed corridor's *total* along-axis px is an integer multiple of the room cell size — otherwise the next piece's `offset_cell`-derived origin and the corridor's compressed end face disagree by a sub-cell fraction → a seam. The proposed `RANGE_CORRIDOR = Vector2(0.25, 1.0)` at 0.25 steps does NOT guarantee this on a 16-cell corridor at every room scale; the snap rule must be on the *product* `cell_size * corridor_len_mult * corridor_length_cells` being integer, not on `corridor_len_mult` alone.

- **⛔ CORRECTION — the branchy re-pack is the real blocker, and it is worse than "handle forks."** Open Q B asks the re-pack to "handle branches (each branch re-packs along its own sub-path from the fork)." Verified against the generator: with R4 on (`r4_enabled`, the J1 default preset), `_select_frontier_index` forks to a **random open socket**, so the band is a **tree**, and a fork can leave a *horizontal* corridor through its **N or S** socket (perpendicular to the corridor's compressed X axis). When that corridor is compressed along X, **the fork's attach cell moves along X** — so the branch's entire sub-tree must shift by the corridor's partial compression *measured at the fork cell, not the corridor's full length*. That is a per-edge, per-axis cumulative re-projection over a tree with mixed-axis attachments — correct but non-trivial, and it must keep every doorway's perpendicular alignment while doing it. **This is the one genuinely hard engineering call in J4, and it is NOT greybox-cheap.**

- **✅ CONFIRMED — the telemetry seam is exactly as described, but `_player_piece_index` is R4-gated and MUST be hoisted.** Verified: `_player_piece_index` (main_game.gd:99) is updated **only inside `_maybe_emit_branch_taken`** (line 466), which `return`s early when `rc == null or not rc.r4_enabled` (line 468) **before** ever assigning `_player_piece_index`. So with R4 off, `_player_piece_index` stays `-1` forever and `_accumulate_piece_time` (which gates on `_player_piece_index < 0`) would attribute **zero** corridor/room time. The doc's hoist requirement is correct and **mandatory**: move the piece-index update (read `_cell_to_junction[cell].x`) out of the R4 gate so it runs every `_resolve_player_depth()` regardless of R4. Cleanest: split a tiny `_update_player_piece(cell)` that always runs, leaving only the *emit* (`nav_branch_taken`) R4-gated. The all-off control and J1's default preset both need this (the all-off control has R4 off; corridor-time must still work there for the M1.0/M1.1/M1.2 baseline comparison RG2 wants).

- **✅ CONFIRMED — the JunkPlacer coordinate seam (Open Q G) is real and is the I1 lesson recurring, but WORSE.** Verified: `JunkPlacer.plan()` (junk_placer.gd:42) already takes a `cell_size_override` (I1's fix) and computes `world_pos = cell * cell_size_px + half` (`_cell_to_world`, line 191) off **one uniform cell size**. The J4 re-pack makes per-piece world origins **non-uniform**, so a single `cell_size_override` can no longer place corridor-resident junk correctly — junk planned for a compressed corridor lands in the (now-closed) gap. The I1 fix (thread one scalar) is **insufficient** for J4; J4 would need JunkPlacer to receive the *same per-piece world-offset table* the re-pack builds, or to re-project planned junk after materialise. This is a second build-breaking gap that the "configurable-not-balanced greybox" scope did not budget for.

### Resolved

**A. Corridor-length mechanism: (a) length-mult vs (b) down-weight vs (c) drop the long piece?** → **⚠ NEEDS DIRECTOR REVIEW (mechanism + scope call). Fresh-eyes recommendation REVISED from the author's: ship Option (b)/(c) for M1.3, defer Option (a) to M2.** The author recommends (a) because it is layout-invariant and "directly shortens the same corridors." Verification flips the cost-benefit: Option (a)'s "smallest determinism surface" claim is true *only* for the trivial linear-spine case, but the J1 default preset has **R4 on → a branchy tree**, where (a) requires the non-uniform anisotropic per-edge world re-pack (corrected above) **plus** a JunkPlacer re-projection — two genuinely hard, build-breaking sub-problems for a greybox iteration whose scope guardrail is "configurable-not-balanced, NOT a generator rewrite." Option (b) (`lvl_corridor_weight_mult` — multiply corridor catalog weights down) and Option (c) (`lvl_short_corridors` — drop/zero `piece_corridor_long_h`) are **cell-space changes in the generator's existing weighted-pick path** (`_build_weight_table` / `_weighted_pick_index`), which J4 can do with a small, well-understood edit; they **move `fingerprint()`** (allowed under the (seed+config) contract as a config-keyed layout change, exactly like R4 already does) and their **all-off default leaves the weight table untouched so the fp byte-match (`e943ac9c8bc1`) still holds.** They answer F3a ("less dead corridor time") directly and *more honestly* than (a): (a) compresses a 16-cell corridor into a visually-stubby 16-tile-collision blob (the player still passes 16 wall segments, just faster), whereas (b)/(c) actually yield **fewer / shorter corridor pieces** — which is what "shorten the boring halls" means physically. The author's own worry ("same corridors, just shorter, may read monotonous") cuts *for* (b)/(c), not against. *Caveat for the Director:* (b)/(c) shift the room:corridor *ratio*, which overlaps J3's per-room-density job — so **J4's mechanism and J3's density knob must be designed as one weighted-catalog seam** (see H). *Recommendation: (c) `lvl_short_corridors` as the cheapest honest lever for M1.3 (binary "long halls off"), optionally (b) `lvl_corridor_weight_mult` as the continuous dial; defer the anisotropic re-pack (a) to M2 if "fewer corridors" proves to need finer control.* **This is the load-bearing Director call for J4** — it changes which file J4 edits (generator + catalog for b/c, vs materialise for a) and whether `fingerprint()` moves.

**B. The world-position re-pack: sound? worth the complexity? acceptable fallback?** → **RESOLVED (technical): the linear-spine re-pack is sound; the BRANCHY re-pack is sound in principle but NOT greybox-cheap, and the linear-only fallback is UNACCEPTABLE for M1.3 because the default preset runs R4 ON.**
  - *Is the re-pack approach sound?* For a **linear spine (R4 off)**: yes — a prefix-sum of per-corridor along-axis compression over placement order, with each downstream piece shifted by the cumulative saved length, is correct and preserves perpendicular alignment (only the along-spine distance shrinks). For a **branchy tree (R4 on)**: sound *only* with the per-edge, mixed-axis cumulative re-projection corrected above (shift each branch's whole sub-tree by the compression measured at its fork cell, handling N/S forks off a horizontally-compressed corridor). It is correct math, but it is a real subsystem, not a loop tweak.
  - *Is the linear-spine-only fallback acceptable for greybox?* **No — and this is the key finding.** §2/Open-Q-B offer "ship the lever only for the linear-spine case (R4 off) and no-op on branchy bands" as a Director-acceptable fallback. But the J1 default play-preset has **R4 ON** (Breakdown §3 J1: "R1+R4 on"). So a linear-only lever would be **inert in the exact config the re-gate plays and the corridor metric is measured against** — F3a would go untested in the default. The fallback defeats J4's purpose. *Therefore:* if Option (a) is chosen anyway, it **must** ship the branchy re-pack (full cost), OR the default preset must turn R4 off (a Director call that contradicts J1). Either way the linear-only escape hatch is closed. **This is the decisive reason fresh-eyes recommends (b)/(c) over (a)** — (b)/(c) work identically with R4 on or off (they touch the weighted draw, which already runs in both modes) and need no re-pack at all.
  - *Doorway adjacency / `SocketSealer`:* under (b)/(c) these are non-issues (no scaling change — the band is just composed of different/fewer pieces, materialised by the unchanged isotropic I1 path). Under (a) they are the corrected hard part above.

**C. Default range + first-sweep values?** → **Deferred to RG1/RG2 (configurable-not-balanced; not a Phase-3 call), with one correction.** If (a) survives Director review, the proposed `RANGE_CORRIDOR = Vector2(0.25, 1.0)` at 0.25 steps is **insufficient for the integer-px seam** (corrected above) — the snap must be on the product `room_cell_size * corridor_len_mult * corridor_length_cells` landing on an integer multiple of `room_cell_size`, not on the mult alone. If (b) is chosen, the range is a weight multiplier `Vector2(0.0, 1.0)` on corridor weights; if (c), it is a bool. *Recommendation:* author the range to match whichever mechanism A resolves to; sweep the value empirically in RG2 against `corridor_frac`.

**D. Telemetry seam: per-frame accumulator vs entry/exit timestamping vs depth-tick sampling?** → **RESOLVED: per-frame `delta` accumulator keyed by the current piece kind, as recommended — it is exact, cheap, and rides the existing seam.** Confirmed `_physics_process` (main_game.gd:433) already runs every frame while `run_active` and is the right host for `_accumulate_piece_time(delta)` *before* the depth-tick throttle. **The one mandatory dependency:** hoist `_player_piece_index` out of the R4 gate (confirmed-correction above) — without it the accumulator is dead with R4 off. Build either (i) split `_update_player_piece(cell)` (always runs in `_resolve_player_depth`) from the R4-gated `nav_branch_taken` emit, or (ii) have J4 maintain its own `_player_piece_index` off `_cell_to_junction[cell].x` independent of the R4 path. *Recommendation: (i)* — it is the smaller diff and keeps one source of truth for "which piece am I in." *Edge case to handle:* `_player_piece_index == -1` at frame 0 / mid-doorway (the doc's guard is correct) — that sliver of time is attributed to neither bucket, which is fine (it is a few frames and `corridor_frac` is a ratio of the two tracked buckets).

**E. Piece-kind classification: hardcoded id set vs aspect-ratio vs a `kind` tag?** → **RESOLVED: hardcoded `_CORRIDOR_PIECE_IDS` set for M1.3, with the aspect-ratio rule REMOVED (not "as fallback") because it mis-classifies the L-bend.** Verified: the proposed fallback `max(s) >= 3*min(s)` classifies `piece_corridor_l` (6×6) as a **room** (6 < 18), contradicting its presence in `_CORRIDOR_PIECE_IDS` — the two rules disagree, so shipping both is a latent bug. For 10 known pieces the hardcoded set is exact; the aspect-ratio fallback adds risk with no benefit. **Also confirmed the classification source:** `PlacedPiece.piece_id` (placed_piece.gd:13) is populated by the generator and is the correct key — do **not** read `p.instance.size_cells`, which is an `@export` recomputed in `ZonePiece._ready()` from the `Geometry` layer (zone_piece.gd:66) and is only authoritative after the node enters the tree. Use `p.piece_id`. *Recommendation: hardcoded `_CORRIDOR_PIECE_IDS` keyed on `p.piece_id`, no aspect-ratio fallback; flag a `kind` enum on `ZonePieceData` as the M2 clean-up if the corridor metric proves load-bearing.* Settled technical call, not a Director item.

**F. What does the J1 default play-preset set `lvl_corridor_len_mult` (or the (b)/(c) equivalent) to?** → **⚠ NEEDS DIRECTOR REVIEW (fun call), confirmed — author's flag stands.** The code-level all-off `RunConfig` default MUST stay the neutral baseline (mult `1.0` for a; weight-mult `1.0` / bool `false` for b/c) so the permanent control byte-matches `e943ac9c8bc1` (verified: this is the load-bearing M1.3 contract, Breakdown §2). The **named play-preset** is the separate artifact J1 owns; F3a's whole thesis ("big rooms + short halls is the fun combo") means the preset probably wants corridors shortened (mult `< 1.0`, or `lvl_short_corridors = true`). *Recommendation:* code default = neutral; preset default = the Director's swept value, authored into J1's preset at preset-authoring time, informed by J4's first RG2 `corridor_frac` read. *Director fun call wired into J1's preset; coordinate the value when the preset is authored.* Not a Phase-3 value call.

**G. Interaction with J2 (enemy spread) / J3 (per-room density) — coordinate source for spawned content.** → **RESOLVED (technical) + cross-task flag.** Under Option (a) the JunkPlacer/hazard coordinate seam is **build-breaking** (corrected above — a per-piece non-uniform world-offset table, not the single `cell_size_override` I1 added). Under Option (b)/(c) it is a **non-issue**: the band is just composed of different/fewer pieces materialised by the unchanged isotropic I1 path, so junk/hazard placement (already threaded with the I1 `cell_size_override`) is correct with no further work — another reason fresh-eyes recommends (b)/(c). **Regardless of A's outcome, J4's corridor-mechanism and J3's per-room-density knob both edit the generator's piece-selection / weighted-catalog seam, so they MUST be designed and single-writer-owned as ONE seam** (Breakdown §5 / Open Q H). *Recommendation: assign J3 + J4's generator/catalog edits to one Wave-2 owner, or sequence them on a shared branch.*

**H. Multi-writer ownership for Wave 2.** → **RESOLVED (orchestrator pre-conditions, restated + tightened by the verification):**
  - **`event_bus.gd`:** pre-declare `signal corridor_time_summary(corridor_s: float, room_s: float)` on `main` **before** Wave 2 opens, in the M1.1 opposition-signals block (the same block that holds `nav_branch_taken` at lines 90–110). Verified that block is the established home for additive signals. One-line orchestrator edit on `main`; everyone else subscribes.
  - **`telemetry.gd` + `telemetry_schema.gd`:** J4-only. Add `CORRIDOR_SUMMARY` to `telemetry_schema.gd` (a new **event-type string** in `ALL_TYPES` — verified additive, `SCHEMA_VERSION` stays 1, exactly like `NAV_BRANCH_TAKEN`) and a `_on_corridor_time_summary` handler in `telemetry.gd`. No collision.
  - **`run_config.gd`:** J1 owns it in Wave 1. J4's new knob (one `@export` + its `to_flat_dict()` entry + its CFG MANIFEST/FIELD_RANGE/CSV entries) is a **post-J1-merge add in Wave 2** — sequence after J1 lands on `main`; do not co-write in one wave (the W1.1-2 lesson, Breakdown §5). Verified the `to_flat_dict()` (run_config.gd:189) and `config_menu.gd` MANIFEST/FIELD_RANGE/RANGE_* pattern — J4 follows the exact `lvl_size_mult` precedent.
  - **`main_game.gd` — the real collision.** Verified Wave 2 has **J2 (enemy spread)**, **J3 (per-room density)**, and **J4** all touching `main_game.gd` (J4: the `_player_piece_index` hoist + `_accumulate_piece_time` + accumulator reset on run start + `corridor_time_summary` emit on run end + — under Option a — the materialise re-pack; J2/J3: the hazard/density spawn seam). **`main_game.gd` MUST have a single Wave-2 owner** who integrates J2+J3+J4's edits (or J4's `main_game.gd` edits land last on a shared branch). This is the standing single-writer-per-`.gd`-file rule (Breakdown §5); the orchestrator assigns the owner at brief time. **Under Option (b)/(c) J4's `main_game.gd` footprint shrinks to telemetry-only** (no materialise re-pack), which materially reduces the collision — a further point in (b)/(c)'s favour.

### Net effect on the build (changes to §2 "Files to create / touch")

- **The mechanism is now a Director call (Open Q A) that changes the file set.** If **(b)/(c)** (fresh-eyes recommendation): J4 edits **`band_generator.gd`** (weighted-pick / `_build_weight_table` path) and/or **`data/piece_catalog_ext.tres`** (or a config-gated catalog tweak), `fingerprint()` **moves** for non-neutral configs (all-off default leaves the weight table untouched → fp byte-match holds), and `main_game.gd` is touched **for telemetry only**. If **(a)** survives review: J4 edits **`main_game.gd` `_materialise_band`** with the anisotropic, straight-corridor-only, branch-aware world re-pack **AND** must add **`systems/depth/junk_placer.gd`** (per-piece world-offset table, not the single `cell_size_override`) to the Touch list, and `fingerprint()` stays put.
- **MANDATORY regardless of A:** hoist `_player_piece_index` out of `_maybe_emit_branch_taken`'s R4 gate (split `_update_player_piece(cell)` always-run from the R4-gated emit), or corridor-time is dead with R4 off.
- **Classification:** hardcoded `_CORRIDOR_PIECE_IDS` keyed on `p.piece_id`; **drop the aspect-ratio fallback** (it mis-classifies the L-bend); **do not** read `p.instance.size_cells` (not authoritative pre-`_ready`).
- **L-bend handling (if Option a):** exclude `piece_corridor_l` (and any multi-axis corridor) from length-axis compression — treat as room-scale.
- **CFG/TEL:** confirmed correct as specified (`MANIFEST["lvl_"]` += the new knob, a `FIELD_RANGE` entry, CSV strings, `to_flat_dict()` += the knob, knob-count test bumps) — follows the verified `lvl_size_mult` precedent.

**Changelog (Phase 3):** Resolved D/E on merit (per-frame accumulator + hoist; hardcoded id set, aspect-ratio fallback removed); resolved B as a technical finding (linear-spine re-pack sound, branchy re-pack sound-but-costly, **linear-only fallback UNACCEPTABLE because the default preset runs R4 on**); **revised the author's A recommendation from Option (a) to Option (b)/(c)** on verification grounds (the branchy anisotropic re-pack + JunkPlacer re-projection are two build-breaking sub-problems outside the greybox scope, while b/c are a small generator/catalog edit that works R4-on-or-off and keeps the all-off fp byte-match); deferred C to RG with an integer-px snap correction; confirmed F as a Director fun call; resolved G/H (the JunkPlacer seam is build-breaking under (a), a non-issue under (b)/(c); `event_bus`/`telemetry` additive-and-clean; `main_game.gd` is the Wave-2 single-writer collision, smaller under b/c). **Caught three load-bearing defects:** (1) the L-bend has no single length axis and the two classification rules disagree on it; (2) anisotropic + non-uniform re-pack is materially harder than the I1 isotropic mult and breaks the integer-px doorway-seam guarantee; (3) the linear-spine-only fallback is inert in the R4-on default preset, so it cannot stand in for the branchy re-pack.

---

**Changelog**

- **2026-06-19 — Phase-2 spec authored.** Goal + premise research (G4 §3/§5 F3a: "extra time = corridor traversal," junctions flat while duration grows; real corridor-vs-room piece table from the `.tscn`s + `piece_catalog_ext.tres`; how `lvl_size_mult` couples corridor length to room size at materialise; the existing `_player_piece_index` / `_cell_to_junction` per-piece tracking as the telemetry seam). Two-part design: (A) `lvl_corridor_len_mult` length-axis-only compression with a post-generation world re-pack (recommended over weight/catalog levers; layout-invariant, no `fingerprint()` move), (B) a per-frame corridor/room time accumulator emitted via a pre-declared `corridor_time_summary` signal into a new additive `corridor_summary` JSONL row (no schema-version bump, no `run_ended` arity change). 8 Open Questions (A–H) with Director-review flags on A/F (and the cross-task junk-seam/ownership flags on G/H).

## Director Disposition (2026-06-19, FINAL — design locked)

- **Mechanism (the load-bearing call): Director chose GENERATOR DOWN-WEIGHT/DROP (Option b/c)** — NOT the materialise re-pack. Long corridors become rarer/shorter via the generator's weighted piece-pick / catalog. Works R4-on (the default preset), yields *physically* fewer corridors, and **shrinks J4's `main_game.gd` footprint to telemetry-only**. The change is **config-keyed**, so it legitimately moves `fingerprint()` for the non-default config while the **all-off default stays byte-identical** (fp `e943ac9c8bc1`).
- **Corridor-time telemetry:** per-frame piece-keyed accumulator; **hoist `_player_piece_index` out of the R4-gated branch** so corridor-time works R4-off; emit `corridor_time_summary(corridor_s, room_s)` on run end (**pre-declared on `main`** before Wave 2) → additive `corridor_summary` JSONL row (no schema bump, no `run_ended` arity change). Corridor classification = **hardcoded corridor piece-id set** (drop the aspect-ratio fallback; L-bend excluded from length scaling).
- **Q-F (preset value):** code default = baseline corridor rarity (neutral); the **preset biases toward fewer/shorter corridors** (the Director's swept value, wired into J1's preset).
- **Wave-2:** J4 sequences after the J2→J3 spawn-seam work; with the telemetry-only footprint the `main_game.gd` collision is minimal (single Wave-2 owner integrates).

**Design LOCKED.**
