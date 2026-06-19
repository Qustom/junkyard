# I1 — Configurable level scale (room count + size) (M1.2 spec)

**Milestone:** M1.2 — Greybox Cost Axis, Iteration 2 (Legibility & Level Scale) · **Workstream:** (a) Wave 1 — Spatial & data foundation
**Task id:** I1 · **dependsOn:** none (the FIRST task — reshapes the spatial canvas every other M1.2 fix tunes against)
**Assignees (build wave):** `general-purpose` (RunConfig schema + generator/materialise wiring + CFG + TEL) · `environment-artist` (only if Open Q B resolves toward new authored greybox pieces)
**Status:** Phase-2 design spec (this doc). Phase-3 fresh-eyes pass resolves §3 Open Questions before build.
**Companion docs:** `M1.2_Breakdown.md` §I1/§3/§6 · `G4_findings_M1.1.md` (I1 row + "Depth works" finding) · `M1_As_Built.md` (proc-gen + determinism) · `M1_1_Tasks/R4_maze_navigation.md` (the (seed + config) determinism contract this inherits) · `data/run_config/run_config.gd` · `systems/bandgen/band_generator.gd` · `data/bandgen_config.tres` · `ui/config/config_menu.gd`

> **Scope guardrail (Breakdown §2):** I1 is **greybox + configurable-not-balanced**. It exposes two new levers (room *count*, room *size*) as `RunConfig` knobs the Director sweeps from CFG. Acceptance is *"the knob exists, is reachable from CFG, takes effect on the generated/materialised band, and the all-off default reproduces the M1.1 baseline byte-for-byte (count) / pixel-for-pixel (size)."* It is **NOT** new piece content balancing, **NOT** a new band, **NOT** a WFC/loop generator rewrite. If the re-gate (RG3) says "fun," M2/M3 build the real spatial system; if not, we re-tune or cut.

---

## 1. Goal & premise research

**The one sentence:** *Make the depth of a dive feel like a journey worth traversing — let the Director independently sweep how MANY rooms a band has and how BIG each room is — without touching the M1.1 baseline when the knobs are off.*

### Why this task (the G4 finding)

`G4_findings_M1.1.md` ranks I1 the **most important** M1.2 fix. Its triage (I1 row) and its "Depth works" note establish the exact defect:

- **The band already has depth — it just *reads* tiny.** Within-band depth reaches **up to 11** (`G4_findings_M1.1.md` §"Depth works": "the band is a ~12-piece spine, not '5–10 rooms'"). BUG2 (depth tracking) is fine. So the problem is **not** "too few rooms" in the graph sense.
- **The *perception* of "tiny/cramped/few rooms" comes from piece SIZE.** Every authored greybox piece is a fixed **8×4-cell scene = 128×64 px** (`cell_size_px = 16`, B1). A ~12-piece spine of 128×64 px rooms clears in a **median 16.9 s baseline run** — a sprint, not a journey.
- **Neither lever is a knob today.** Room count is the **hardcoded `target_piece_count = 12`** inside `data/bandgen_config.tres` (a `BandGenConfig` `.tres`, not a `RunConfig` field). Room size is **baked into each `.tscn`** (the piece footprint in cells × `cell_size_px`). The Director can change neither from the CFG menu.

So I1 must turn **two currently-baked spatial parameters into swept `RunConfig` knobs**, defaulting to today's values so the all-off control is unchanged.

### What exists in-repo (real files / APIs — `M1_As_Built.md` wins over any sketch)

**Room count — where the generator picks it.**
`systems/bandgen/band_generator.gd` → `generate(seed, cfg, catalog, rc)` is a pure function of its inputs. The grow loop is gated by `cfg.target_piece_count`:

```gdscript
# band_generator.gd, _generate_once()
while band.pieces.size() < cfg.target_piece_count and not frontier.is_empty():
    ...
```

`cfg` is a **`BandGenConfig`** loaded from `data/bandgen_config.tres`:

```
target_piece_count = 12   # the hardcoded room count
branch_chance = 0.0
max_place_attempts = 16
loop_back_count = 0
soft_floor_percent = 80   # _soft_floor() = ceil(target * percent/100); generation "succeeds" at >= this
max_band_attempts = 8
```

The `_soft_floor(cfg)` (= `(target * soft_floor_percent + 99) / 100`) decides whether an attempt "succeeds" or retries with a derived seed; it scales off `target_piece_count`, so changing the target automatically rescales the floor (no separate floor knob needed). The generator is called once, in `scenes/game/main_game.gd` `start_new_run()`:

```gdscript
var band := generator.generate(seed, _cfg, _piece_catalog, run_cfg)   # _cfg = the BandGenConfig
```

So **room count is already a parameter of the generator** — I1 only has to let `run_cfg` (the `RunConfig`) override `cfg.target_piece_count`.

**Room size — where size is baked.**
- Each piece is a `ZonePiece` scene (`bands/pieces/*.tscn`, root script `bands/pieces/zone_piece.gd`). `piece_corridor_h.tscn` declares `size_cells = Vector2i(8, 4)` and `cell_size_px` defaults to **16** (B1 project-wide). The footprint lives in the `Geometry` TileMapLayer; sockets are `Marker2D`s with `dir` + `width_cells = 2` metas.
- The generator works **entirely in integer cells** (`offset_cell`, `footprint_cells`, `_alignment_offset`). Pixels appear only at **materialisation** in `main_game.gd` `_materialise_band(band)`:

```gdscript
func _materialise_band(band: Band) -> int:
    var cell_size := DEFAULT_CELL_SIZE_PX
    for p in band.pieces:
        if p.instance.cell_size_px > 0:
            cell_size = p.instance.cell_size_px          # <-- the px-per-cell used everywhere
        p.instance.position = Vector2(p.offset_cell * cell_size)
        _band_container.add_child(p.instance)
    SocketSealer.new().seal_unused_sockets(band, cell_size)
    return cell_size                                      # -> _band_cell_size_px
```

The returned `cell_size` becomes `_band_cell_size_px`, the single px-per-cell scalar the **whole run** uses: player cell↔world resolution (`_resolve_player_depth()`), `_entry_spawn_position()`, the gate offset, hazard spawn, the R4 vision radius node — all read it. **This is the seam where "room size" can scale without touching the cell-space layout.** A multiplier applied here grows every room (and the spacing between them) uniformly, in pixels, while the deterministic cell-space `band` (and its `fingerprint()`) is **unchanged**.

**Cell size = 16 px (B1).** `DEFAULT_CELL_SIZE_PX` in `main_game.gd`; `cell_size_px = 16` on every piece. The corridor's 2-cell socket openings are therefore 32 px wide today.

**The RunConfig knob schema.** `data/run_config/run_config.gd` — typed `@export` fields, sub-grouped per opposition (`@export_group(... "r4_")`), an `all_oppositions_disabled()` helper, and `to_flat_dict()` (the JSON-safe snapshot TEL puts on the `run_started` row). The all-off default `.tres` reproduces M1.0/M1.1 baseline exactly.

**The CFG coverage assertion.** `ui/config/config_menu.gd` surfaces **100% of RunConfig's `@export` fields**. It is hand-authored (`SECTIONS`, `MANIFEST`, `FIELD_RANGE`) but cross-checked at build time by `_assert_full_coverage()` → `has_full_coverage()`, which compares the bound-field manifest against `_exported_config_fields()` (reflection over `get_property_list()` filtered to `STORAGE|EDITOR`). **Adding a `RunConfig` `@export` without wiring it into `SECTIONS`+`MANIFEST` fails the assertion loudly** — that is the safety net I1 must satisfy.

**The determinism contract (inherited from R4 / B2).** `systems/bandgen/band.gd` `fingerprint()` = the ordered hash of `"piece_id@offset_cell#mated_socket_index"` per placed piece. The committed M1.1 contract (R4 §10 Q5) is **`fingerprint(seed + config)`**: same seed *and* same config → byte-identical band; a different config legitimately → a different band. The **all-off config must byte-match the M1.0 band** for a seed (the permanent control). I1's new knobs join this key.

---

## 2. Design / approach + pseudocode

I1 ships **two independent, independently-swept levers**, both new `RunConfig` knobs under a new `lvl_` group. The all-off default of each = today's baked value, so the all-off control is unchanged.

### Lever 1 — Room COUNT (easy: override `target_piece_count`)

A new `RunConfig` knob whose value, when set, replaces the `BandGenConfig.target_piece_count` the generator grows to. Default sentinel = "use the `.tres` value" so all-off = today's 12.

**Why a RunConfig override and not editing the `.tres`:** the experiment's identity must travel with the swept `RunConfig` (it's what TEL snapshots and what the (seed + config) key hashes). Leaving `bandgen_config.tres` at `target_piece_count = 12` keeps it the canonical baseline; the override layers on top per run.

```gdscript
# run_config.gd — NEW group (illustrative; programmer writes typed GDScript)
@export_group("Level Scale", "lvl_")
## Master toggle. OFF = baseline count + size (M1.1 spine, 16 px cells).
@export var lvl_enabled: bool = false
## Room count override. -1 = "use BandGenConfig.target_piece_count" (baseline 12).
## When >= 1 and lvl_enabled, this REPLACES the generator's target.
@export var lvl_room_count: int = -1
## Room-size multiplier applied at materialisation (px per cell = 16 * mult).
## 1.0 = baseline 16 px cells (128x64 px rooms). > 1.0 = bigger rooms/spacing.
@export var lvl_size_mult: float = 1.0
```

Threading the count into the generator (the generator already receives `rc`):

```gdscript
# band_generator.gd — _generate_once(), the grow-loop gate.
# Resolve the effective target ONCE, before the loop, so the determinism surface
# is a single value (not a per-iteration read).
var target := cfg.target_piece_count                 # baseline path (all-off)
if rc != null and rc.lvl_enabled and rc.lvl_room_count >= 1:
    target = rc.lvl_room_count
# _soft_floor() rescales automatically off `target` (ceil(target*pct/100)).
while band.pieces.size() < target and not frontier.is_empty():
    ...
```

> **Determinism note (Lever 1):** more/fewer rooms means more/fewer placement draws on the SAME `RNG` stream in the SAME order — a longer/shorter prefix of one deterministic sequence. `fingerprint(seed + config)` holds: a given (seed, count) is byte-reproducible; the all-off config (count = baseline 12) byte-matches the M1.1 band. **No new RNG draw, no reorder** — only the loop's termination bound changes. The first N pieces of a count-20 band are identical to a count-12 band on the same seed (the extra 8 are appended), which is the expected, correct behaviour.

### Lever 2 — Room SIZE (the harder one — three options, recommendation below)

"Room size" can be grown three different ways. The Phase-3 agent / Director picks (see Open Qs A–E); the spec presents all three so the choice is informed.

**Option (a) — cell-scale multiplier at materialisation (RECOMMENDED).** Multiply the px-per-cell used in `_materialise_band` (and everywhere `_band_cell_size_px` flows) by `lvl_size_mult`. The cell-space layout, the catalog, and `fingerprint()` are **untouched** — only the pixel projection grows. Every room and every gap between rooms scales uniformly; 2-cell socket openings stay 2 cells (just bigger in px), so doorway alignment is preserved by construction.

```gdscript
# main_game.gd — _materialise_band(band, size_mult: float)
func _materialise_band(band: Band, size_mult: float) -> int:
    var base_cell := DEFAULT_CELL_SIZE_PX
    for p in band.pieces:
        if p.instance.cell_size_px > 0:
            base_cell = p.instance.cell_size_px
    var cell_size := int(round(base_cell * size_mult))   # e.g. 16 * 2.0 = 32 px/cell
    for p in band.pieces:
        if p.instance == null: continue
        p.instance.position = Vector2(p.offset_cell * cell_size)
        p.instance.scale = Vector2.ONE * size_mult       # scale the piece visuals to match
        _band_container.add_child(p.instance)
    SocketSealer.new().seal_unused_sockets(band, cell_size)
    return cell_size                                     # -> _band_cell_size_px (whole run uses it)
```

- **Pros:** smallest, cheapest change; zero new content; one scalar; layout determinism is *provably* untouched (cell space unchanged, `fingerprint()` byte-identical across `size_mult`); every downstream consumer already reads `_band_cell_size_px`, so spawn/gate/hazard/vision auto-scale. Bigger rooms = longer to cross = depth feels like a journey, exactly the G4 ask.
- **Cons:** it scales rooms AND the player's apparent speed-relative-to-the-world the same way, so the player crosses a 2× room in ~2× the time only if player speed is in px/s and unscaled (confirm — see Open Q D). Tile art is greybox rects so visual stretch is a non-issue now; a future real-art pass would need integer multiples. The "two greybox issues" to verify: (1) does scaling the `ZonePiece` node also scale its `Geometry` TileMapLayer **collision** correctly (TileMapLayer collision follows node scale — confirm at build), and (2) the `SocketSealer` must be fed the scaled `cell_size` (already wired above) so seal walls land on the scaled grid.

**Option (b) — a set of larger authored greybox pieces in the catalog.** Author new `.tscn` pieces at e.g. 16×8 or 12×8 cells (still `cell_size_px = 16`), add them to `_piece_catalog`, and let the Director bias the band toward them via weights. This makes rooms genuinely bigger *in cells* (real bigger geometry, not a zoom).
- **Pros:** rooms differ in shape/scale, not just zoom — more spatial variety; integer-cell, so no scale/collision questions.
- **Cons:** **new socket authoring** (every new piece needs B1-compliant 2-cell sockets on the right edges with correct `dir`/`width_cells` metas), it's environment-artist work, and it CHANGES the catalog → **changes `fingerprint()` and the weight table for ALL configs** unless gated behind `lvl_enabled` (a catalog swap is a bigger determinism surface than a scalar). It also doesn't make the *whole* band bigger on demand — it biases piece selection.

**Option (c) — a per-band "size class" enum (S/M/L).** A `lvl_size_class` enum that picks a preset (mult + count) bundle. Sugar over (a)/(b), not a distinct mechanism.
- **Pros:** fast Director sweeps ("try Large"). **Cons:** hides the independent count/size axes the gate wants to read separately; better as a CFG preset than a schema field.

> **Recommendation:** ship **Lever 1 (count override) + Lever 2 Option (a) (size multiplier)** for M1.2 — two clean scalars, zero new content, layout-determinism provably intact, and the all-off default trivially reproduces baseline. Option (b) is the right *eventual* answer for spatial variety but is M2 content work with a determinism cost; flag it as a follow-up if the multiplier-zoom reads as "same rooms, just bigger" in playtest (Open Q B). This recommendation is a **Director-review item** (it trades "real bigger geometry" for "cheap + safe").

### How all-off / default reproduces the M1.1 baseline

| Knob | All-off default | Effect |
|---|---|---|
| `lvl_enabled` | `false` | the whole group inert |
| `lvl_room_count` | `-1` | use `BandGenConfig.target_piece_count` (= 12) |
| `lvl_size_mult` | `1.0` | px/cell = 16 × 1.0 = 16 (today's 128×64 px rooms) |

With all three at default, the generator grows to 12 (unchanged loop bound, identical RNG sequence → `fingerprint()` byte-matches M1.1) and `_materialise_band` returns `cell_size = 16` (pixel-identical to today). `all_oppositions_disabled()` is about the R1–R4 toggles; I1 should add `lvl_enabled` to whatever "is this the pure baseline?" check the gate uses, OR keep `lvl_` out of `all_oppositions_disabled()` and treat level-scale as an orthogonal axis (see Open Q E — a genuine telemetry-labelling call).

### How the new knobs join the determinism key

- **Count** changes the generator's loop bound → already inside the (seed + config) hash by construction (it changes the placed-piece list, hence `fingerprint()`). No new RNG site.
- **Size** is a **pure pixel projection** applied *after* generation; it does **not** change the cell-space `band` and therefore does **not** change `fingerprint()` at all. Two runs that differ only in `lvl_size_mult` produce the **same** `fingerprint()` (same layout, different zoom). This is correct and should be documented: `fingerprint()` keys *layout*, not *presentation*; size is presentation. **Test obligation:** (1) the existing all-off fingerprint test still byte-matches the M1.0/M1.1 band; (2) a new test pins `lvl_room_count` and asserts a stable fingerprint run-to-run for (seed + count); (3) a test asserts `lvl_size_mult` does NOT change `fingerprint()` (layout-invariance of the zoom).

### CFG coverage

Adding the three `lvl_` `@export`s **will trip `has_full_coverage()`** until the menu is updated. I1 must, in `ui/config/config_menu.gd`:
- add a `SECTIONS` entry `{"prefix": "lvl_", "title_key": "CFG_SEC_LVL", "gloss_key": "CFG_GLOSS_LVL", "master": "lvl_enabled", "collapsible": true}`;
- add the `MANIFEST["lvl_"]` ordered field list `["lvl_enabled", "lvl_room_count", "lvl_size_mult"]`;
- add `FIELD_RANGE` entries — propose `lvl_room_count → Vector2(1, 30)` (a new `RANGE_COUNT`) and `lvl_size_mult → Vector2(0.5, 4)` (a new `RANGE_MULT`); the SpinBox always allows exact typing past the slider cap, so these are scrub conveniences;
- add the CSV strings (`CFG_SEC_LVL`, `CFG_GLOSS_LVL`, per-field labels) to `ui/config/config_strings.csv`.
After that, `_assert_full_coverage()` passes (bound set == exported set).

### TEL `to_flat_dict()` snapshot

Append the three knobs to `RunConfig.to_flat_dict()` so the `run_started` row carries the level-scale config (additive payload, NOT a schema bump — same pattern as the R-knobs):

```gdscript
# in to_flat_dict()'s returned Dictionary, add:
"lvl_enabled": lvl_enabled,
"lvl_room_count": lvl_room_count,
"lvl_size_mult": lvl_size_mult,
```

This lets RG2 segment outcomes by room count/size and keep M1.0/M1.1/M1.2 comparable on the same metrics (the all-off rows stay identical to prior versions). No new EventBus signal is needed — I1 is pure config + generator/materialise wiring, projected through the existing `run_started` snapshot.

### Files to create / touch (build wave)

**Touch:**
- `data/run_config/run_config.gd` — the three new `lvl_` `@export`s + the `to_flat_dict()` additions. *(general-purpose; single-writer — I1 owns `run_config.gd` this wave per Breakdown §6.)*
- `systems/bandgen/band_generator.gd` — resolve effective `target` from `rc` in `_generate_once()`. *(general-purpose)*
- `scenes/game/main_game.gd` — pass `rc.lvl_size_mult` into `_materialise_band`; resolve from `run_cfg` (already in hand at the call site). *(general-purpose; watch the Wave-2 `main_game.gd` collision with I2/I4 — I1 lands first on `main`.)*
- `ui/config/config_menu.gd` + `ui/config/config_strings.csv` — the new `lvl_` section/manifest/range/strings. *(general-purpose)*

**Possibly create (only if Open Q B → Option (b)):**
- `bands/pieces/piece_room_large.tscn` (+ siblings) — larger authored greybox pieces with B1-compliant sockets. *(environment-artist)*

**Confirm NOT touched:**
- `systems/bandgen/band.gd` `fingerprint()` — unchanged (size is presentation; count rides the existing piece list).
- `systems/event_bus.gd` — NOT edited (no new signal; I1 projects through `run_started`'s existing config snapshot).
- `data/bandgen_config.tres` — left at `target_piece_count = 12` (the canonical baseline; the override layers on top).

### Acceptance criteria (from Breakdown §I1, made concrete)

1. **Count is settable + visible.** With `lvl_enabled` and `lvl_room_count = N (>=1)` set in CFG, the generated band grows toward N pieces (subject to the soft floor / frontier exhaustion); off (or `-1`) = the baseline 12-piece spine.
2. **Size is settable + visible.** With `lvl_enabled` and `lvl_size_mult != 1.0`, every room and the spacing between rooms scales in px; off (or `1.0`) = today's 128×64 px rooms.
3. **All-off == M1.1 baseline.** With `lvl_enabled = false` (or count `-1` + mult `1.0`), the band is byte-identical (`fingerprint()`) and pixel-identical to the M1.1 baseline for a seed — the permanent control.
4. **Determinism preserved.** `fingerprint(seed + config)` holds for count; `lvl_size_mult` provably does NOT change `fingerprint()` (layout invariance). All-off fingerprint test green.
5. **CFG + TEL pick up the knobs automatically.** `has_full_coverage()` passes with the new section; `to_flat_dict()` carries the three knobs onto `run_started`.
6. **Sealed at any scale.** `SocketSealer` is fed the scaled `cell_size`, so the band stays sealed (no walk-into-void) at any `lvl_size_mult` (pairs with BUG4).

---

## 3. Open Questions (Phase-3 fresh-eyes resolves; Director-review items flagged)

**A. More rooms vs. bigger rooms vs. both — which actually fixes "feels like a sprint"?** *(Director / fun call)*
G4 says the *graph* already has ~12 rooms (depth 11) — so the felt problem is **size**, not count. Trade-off: bumping `lvl_size_mult` alone may fully solve "depth feels like a journey" (bigger rooms = longer to cross) without adding rooms, keeping run time controlled; bumping count alone adds traversal but each room still reads cramped. **Recommendation to test first: size multiplier with count at baseline**, then add count only if needed. *Genuine Director feel call — resolve via the first I1 playtest sweep.*

**B. Size = scale multiplier (Option a) vs. new authored pieces (Option b)?** *(Director / scope call)*
The multiplier is cheap, content-free, and determinism-safe but is a literal *zoom* — same room shapes, bigger. New authored pieces give real spatial variety but cost environment-artist time, new socket authoring, and a catalog change that moves `fingerprint()` for all configs. **Recommendation: ship Option (a) for M1.2; flag Option (b) as an M2 follow-up if the zoom reads as monotonous.** *Director-review: trades variety for safety + speed.*

**C. What default count / mult range makes depth feel like a journey without bloating run time past the ~15-min tier?** *(tuning — Director sweeps)*
Configurable-not-balanced: I1 ships the knobs, not the right value. Starting sweep points to propose to the Director: count `{12 (baseline), 16, 20}`, mult `{1.0 (baseline), 1.5, 2.0, 3.0}`. The constraint: median run should grow from ~17 s toward a "journey" feel but a single dive must not blow past the M1 ~15-min experiment tier when stacked with R2/R3 clock pressure. **Resolve empirically in RG1/RG2.**

**D. Does the size multiplier scale player traversal time, or just the visuals?** *(build-time verification — likely programmer, escalate if it's a feel call)*
Player movement is in px/s and is NOT scaled by `lvl_size_mult` (it's a player property, not band geometry), so a 2× room genuinely takes ~2× longer to cross — which is the desired "journey" effect. **Confirm at build** that nothing scales player speed alongside the band; if it does, the zoom would be cosmetic only (rooms look bigger but cross in the same time), defeating the goal. Also confirm the camera framing (Phantom Camera zoom) reads acceptably at 2–3× rooms. *If "bigger rooms but same crossing time" turns out desirable for some reason, that's a Director call.*

**E. Should `lvl_` count toward the "is this the baseline control?" check, or be an orthogonal axis?** *(telemetry labelling — RG2 / qa)*
`all_oppositions_disabled()` currently keys off R1–R4 only. Two readings: (1) level-scale is an *opposition-orthogonal* presentation axis, so a run with bigger rooms but no R-oppositions is still a "baseline+scale" control — keep `lvl_` OUT of `all_oppositions_disabled()` and segment on `lvl_size_mult`/`lvl_room_count` in RG2; (2) any non-default config is "not the pure M1.0/M1.1 control." **Recommendation: reading (1)** — keep `lvl_` orthogonal, segment in analysis, so RG2 can ask "did bigger rooms help *independently* of the oppositions." *Resolve with qa-playtest-coordinator (owns RG2).*

**F. Does a >1.0 size multiplier break socket/doorway alignment (B1 2-cell openings)?** *(build-time verification)*
Under Option (a) the layout stays in **integer cells**, so 2-cell openings stay 2 cells — alignment is preserved by construction; only the px projection scales (32 px → 64 px at mult 2). **The risk is non-integer `cell_size`**: `int(round(16 * mult))` for fractional mults (e.g. 1.5 → 24 px, fine; but verify no sub-pixel seam between abutting scaled pieces). **Recommendation: clamp/snap `lvl_size_mult` to values yielding integer px-per-cell** (or restrict the slider to .5 steps) so abutting pieces never gap. Confirm at build that scaled `ZonePiece` collision (TileMapLayer follows node `scale`) stays watertight.

**G. Do larger pieces (Option b only) need new socket authoring, and how do they enter the catalog without moving baseline `fingerprint()`?** *(only if Q B → Option b; environment-artist + determinism)*
New pieces in `_piece_catalog` change the weight table and placement draws → `fingerprint()` moves for **every** config, breaking the all-off byte-match unless the larger pieces are gated behind `lvl_enabled` (a config-dependent catalog, a larger determinism surface than a scalar). **If Option (b) is chosen, the resolution must specify a determinism-safe catalog seam** (e.g. baseline catalog when `lvl_` off, extended catalog when on — and a fingerprint test per catalog). This is the strongest argument for shipping Option (a) in M1.2.

**H. Does `lvl_room_count` interact badly with `soft_floor_percent` / `max_band_attempts` at high counts?** *(build-time verification)*
A large target may exhaust the frontier before reaching N (linear spine can only place so many before geometry boxes itself in), tripping `band_generation_failed(&"undersized")` and returning the largest attempt. That's acceptable greybox behaviour (the band is still valid), but **confirm the failure path is graceful** at high counts and that RG2 can see "requested N, got M" (the `band_generated` signal already carries `pieces.size()`). No new code likely needed — just verify the ceiling and document it for the Director's count sweep.

---

*Authored by `game-director-designer` as Phase-2 of M1.2's three-phase breakdown (`CLAUDE.md` → "Version breakdown authoring"). This doc sets the I1 contract; a Phase-3 fresh-eyes pass resolves §3, then the build wave (general-purpose, + environment-artist iff Option b) builds against it. Update alongside `M1_As_Built.md` as I1 resolves.*

---

## Resolved Decisions (Phase 3 — fresh-eyes, 2026-06-19)

Independent programmer-lens pass by a reviewer who did NOT author §1–§3. Verified every cited claim against the real code (`band_generator.gd`, `run_config.gd`, `zone_piece.gd`, `main_game.gd`, `socket_sealer.gd`, `junk_placer.gd`, `config_menu.gd`, `bandgen_config.tres`, the piece `.tscn`s). **The doc's claims hold up — count is `BandGenConfig.target_piece_count`, the generator already takes `rc`, `fingerprint()` keys layout-only, CFG coverage is reflection-asserted — but I found one load-bearing blind spot (the junk/materialise coordinate seam) and one moot worry (the sealer). Both are corrected below.** Lever 1 (count) is clean and confirmed; Lever 2 (size) needs a tightened seam.

### Verification corrections to the body (read before building Lever 2)

- **⛔ CORRECTION — Option (a)'s pseudocode is internally redundant AND breaks junk alignment.** The §2 Option-(a) sketch does *two* things at once: (i) positions pieces at `offset_cell * round(16*mult)`, and (ii) also sets `p.instance.scale = mult`. Setting **both** is the right combo (re-spacing + content-scaling), but the bigger problem is **off-screen**: `JunkPlacer.plan(band, …)` is called at `main_game.gd:179` **before** `_materialise_band` and computes each pickup's `world_pos` from `p.instance.cell_size_px` (= the piece's `@export`, **16**, via `JunkPlacer._cell_size_px()` → `_cell_to_world()`), **not** from the materialise return value. Pickups are then parented to `_band_container` at those raw coords (`_spawner.populate(plan, _band_container)`) — they are **not** children of the scaled piece nodes, so `p.instance.scale` does not move them. Result with a naive Option (a): pieces re-space/scale to 2× but junk stays clustered at the 1× world coords → junk lands outside/atop rooms. **The author's claim "every downstream consumer already reads `_band_cell_size_px`, so spawn/gate/hazard/vision auto-scale" is true for hazard/gate/player-depth/entry-spawn/vision (they all read `_band_cell_size_px`) but FALSE for junk** (planned off the piece export, pre-materialise). **Fix:** thread `lvl_size_mult` into `JunkPlacer.plan()` (multiply its effective cell size) OR re-derive junk world coords from the scaled `_band_cell_size_px` after materialise. Either way **`systems/bandgen/junk_placer.gd` (or the plan call site) MUST be added to the "Touch" list** — the build wave as written would ship mis-placed loot at any `mult != 1.0`.

- **✅ MOOT — `SocketSealer` does NOT need the scaled `cell_size` (Q F's seal concern).** `socket_sealer.gd` ignores its `_cell_size_px` param entirely; it seals in **pure cell space** by writing WALL tiles (`set_cell`, source 0, atlas (1,0)) into each owner piece's own `Geometry` TileMapLayer. Because the cap lives **inside** the piece, it inherits the piece node's `scale` for free. So "feed the sealer the scaled cell_size" (§2 Option-a Cons, Q F) is a non-issue — the seal is scale-correct by construction as long as `p.instance.scale` is applied. (The param can stay 0/ignored.) This is a genuine author blind spot, in the build's favour.

- **✅ CONFIRMED — Q D (player traversal scales): YES, verified in code.** `entities/player/player.gd` moves via `step_velocity` against `max_speed` (px/s, from `player_movement.tres`, 200 px/s), scaled only by the R3 exposure mult — **never by band geometry**. The player node is not parented under the band, so `p.instance.scale` does not touch it. A 2× band → ~2× crossing time. The "journey" effect is real, not cosmetic.

### Resolved

**A. More rooms vs bigger rooms vs both?** → **⚠ NEEDS DIRECTOR REVIEW** (confirmed a genuine fun/feel call; author's flag stands). *Recommendation:* ship both knobs; in the **first sweep, hold count at baseline (12) and raise only `lvl_size_mult`** — G4 already established the graph has depth-11 and the felt defect is *size*, not count, so size-first isolates the cheaper fix and keeps run-time controlled. Add count only if bigger-but-same-number still reads as a sprint. *Rationale:* the data says size is the lever; test the single-variable hypothesis before stacking two. Resolve via the I1 playtest, not in code.

**B. Size = multiplier (Option a) vs new authored pieces (Option b)?** → **⚠ NEEDS DIRECTOR REVIEW** (confirmed; author's flag stands). *Recommendation: ship Option (a) for M1.2, defer Option (b) to M2.* On engineering merit Option (a) is decisively cheaper and safer **even after the junk-seam correction above** (one scalar + JunkPlacer plumbing, vs new socket authoring + a config-dependent catalog that moves `fingerprint()` for every config — see G). The only thing (a) can't give is *shape* variety (it's a literal zoom). *Rationale:* "same rooms, just bigger" may be exactly enough to fix "feels like a sprint"; pay for spatial variety (b) only if the zoom reads monotonous in playtest. The variety-vs-safety trade is the Director's, but the technical recommendation is unambiguous: (a).

**C. Default count/mult range?** → **Deferred to RG1/RG2 (configurable-not-balanced; not a Phase-3 call).** *Recommendation:* ship the author's proposed sweep points — count `{12, 16, 20}`, mult `{1.0, 1.5, 2.0, 3.0}` — as Director sweep candidates, **with the integer-px constraint from F applied** (so mult ∈ {1.0, 1.5, 2.0, 2.5, 3.0…}, each yielding integer px/cell at 16-base: 16, 24, 32, 40, 48). *Rationale:* I1's acceptance is "the knob exists and takes effect," not "the value is right"; the value is empirical and depends on stacking with R2/R3 clock pressure under the ~15-min tier.

**D. Does the multiplier scale traversal time or just visuals?** → **RESOLVED: scales traversal time (verified in code, see above).** No Director call needed; the desired effect is the real one. *Rationale:* player speed is a px/s body property outside the band hierarchy; bigger band = proportionally longer to cross. Build must simply **not** parent the player under the scaled band (it doesn't today) and confirm Phantom/`Camera2D` framing reads acceptably at 2–3× (cosmetic check, not a blocker; the run uses a plain `$Player/Camera2D`).

**E. Does `lvl_` count toward the baseline-control check?** → **RESOLVED: keep `lvl_` OUT of `all_oppositions_disabled()`; treat level-scale as an orthogonal axis, segment in RG2.** *Rationale:* `all_oppositions_disabled()` (run_config.gd:122) is literally `not (r1_enabled or … or r4_enabled)` — it answers "are the *oppositions* off," which is the R1–R4 cost-axis question. Level scale is a presentation/spatial axis, not an opposition; a bigger-room run with no R-toggles is still a meaningful "baseline + scale" cell RG2 wants to read *independently* of the oppositions. Adding `lvl_` would conflate two questions the gate must separate. **Author flagged this for Director/qa; I downgrade it to a settled technical call** — keep the helper opposition-only, add `lvl_*` to `to_flat_dict()` (already specified) so RG2 segments on it. (If the Director wants a separate "pure M1.0 control" predicate, add a distinct `is_pure_baseline()` helper rather than overloading `all_oppositions_disabled()`.) Not a Director-review blocker.

**F. Does a >1.0 multiplier break socket/doorway alignment?** → **RESOLVED: no, provided `lvl_size_mult` is snapped to integer-px-per-cell values.** Layout stays in integer cells, so 2-cell openings stay 2 cells; only the px projection scales, and the sealer is scale-correct (see "moot" above). The single real risk is a **non-integer `cell_size`** (e.g. mult 1.3 → `round(16*1.3)=21`, a lossless int, but `_assert_uniform_cell_size` and `_cell_to_world` assume the px/cell is the *same integer everywhere* — a fractional-derived px that differs between the materialise path and the JunkPlacer path would seam). *Decision:* **clamp/snap `lvl_size_mult` so `round(16 * mult)` is an exact integer multiple-of-cell and identical across both coordinate paths** — restrict the CFG slider to 0.25 steps (16-base → 4-px increments, all integer) and pass the *same* effective `cell_size` to materialise AND JunkPlacer. *Rationale:* abutting pieces gap only if two pieces project at different px/cell; one shared integer `cell_size` derived once from `mult` removes the seam. Build-time check: confirm scaled `ZonePiece` `Geometry` TileMapLayer collision stays watertight (TileMapLayer collision follows Node2D `scale` in Godot 4.x — verify in the editor at mult 2/3).

**G. Do larger pieces (Option b) need new socket authoring + a determinism-safe catalog seam?** → **RESOLVED (conditional on B → Option b, which I recommend deferring): YES to both, and this is the strongest reason to ship (a) now.** Adding pieces to `_piece_catalog` changes `_build_weight_table` and the placement-draw sequence → `fingerprint()` moves for **every** config, breaking the all-off byte-match — **unless** the larger pieces are gated behind a config-dependent catalog (baseline catalog when `lvl_enabled` off, extended when on), which is a strictly larger determinism surface than a scalar and needs a fingerprint test *per catalog*. New pieces also need B1-compliant 2-cell sockets (`dir`/`width_cells` metas on `Marker2D`s, marker on the last interior floor cell). *Rationale/Decision:* not worth it for M1.2; if Option (b) is ever taken (M2), the required seam is "swap the catalog on `lvl_enabled`, fingerprint-test each catalog independently." For M1.2 this question is **N/A** (Option a chosen).

**H. Does `lvl_room_count` interact badly with `soft_floor_percent`/`max_band_attempts` at high counts?** → **RESOLVED: behaviour is already graceful; no new code; document the ceiling for the count sweep.** Verified the failure path: a linear spine that can't reach target before frontier exhaustion keeps the **largest** attempt across `max_band_attempts` (band_generator.gd:62–75), emits `band_generation_failed(seed, &"undersized")` then `band_generated(seed, best.pieces.size())`, and returns a valid (just shorter) band. `_soft_floor` rescales off `target` automatically (line 404), so no separate floor knob is needed (author correct). **RG2 can already see "requested N, got M"** because `band_generated` carries `pieces.size()`. *Decision:* no code change; the build worklog should note the empirical count ceiling (the max a linear spine reaches before boxing itself in) so the Director's count sweep stays under it, and RG2 segments on requested-vs-achieved. *Rationale:* the generator already degrades safely; I1 only needs to surface the lever.

### Net effect on the build (changes to §2 "Files to create / touch")

- **ADD to "Touch": `systems/bandgen/junk_placer.gd`** (or the `plan()` call site in `main_game.gd`) — thread `lvl_size_mult` so junk world coords use the **same** effective `cell_size` as materialise. *Without this, loot mis-places at any `mult != 1.0` — this is the one build-breaking gap in the spec as written.*
- **Lever 2 seam = `p.instance.scale = mult` + position at `offset_cell * cell_size` (one shared integer `cell_size = round(16*mult)`), and the SAME `cell_size` fed to JunkPlacer.** The sealer needs nothing extra (cell-space, inherits scale).
- **Snap `lvl_size_mult` to 0.25 CFG steps** (integer px/cell), per F. Propose `RANGE_MULT = Vector2(0.5, 4)` with 0.25 SpinBox step.
- Lever 1 (count override in `_generate_once`), CFG section/manifest/strings, and `to_flat_dict()` additions are confirmed correct as specified.

**Changelog (Phase 3):** 5 questions resolved on merit (D, E, F, G, H), 1 deferred to RG (C), 2 confirmed as Director-review (A, B). Corrected the junk/materialise coordinate seam (build-breaking blind spot), confirmed the SocketSealer worry is moot, and verified Q D in code.

---

**Changelog**

- **2026-06-19 — Phase-2 spec authored.** Goal + premise research (G4 I1 finding; real generator/RunConfig/CFG/materialise APIs); two-lever design (count override + size multiplier) with Option (a)/(b)/(c) analysis and a recommended (a)+count path; determinism (count rides the piece list, size is layout-invariant presentation), CFG coverage, and TEL snapshot wiring; 8 Open Questions (A–H) with Director-review flags on A/B/E.
- **2026-06-19 — Phase-3 fresh-eyes pass.** Independent programmer-lens verification of all cited code. Added `## Resolved Decisions (Phase 3)`: resolved D/E/F/G/H on merit, deferred C to RG, confirmed A/B as Director-review (revised E from Director/qa down to a settled technical call). **Caught a build-breaking blind spot** — `JunkPlacer.plan()` computes loot world coords off the unscaled piece export pre-materialise, so Option (a) must also thread `lvl_size_mult` into `junk_placer.gd` (added to Touch list) or loot mis-places at `mult != 1.0`. Confirmed the `SocketSealer` cell-size worry (Q F) is moot (cell-space seal inherits piece scale) and verified Q D (player speed is unscaled px/s) in code.

---

## Director Disposition (2026-06-19, FINAL — design locked)

The Director dispositioned the Phase-3 flagged items:

- **A (more rooms vs bigger vs both) + B (size multiplier vs new authored pieces): Director chose "GO FURTHER".**
  M1.2 ships **all three**: the **room-size multiplier** (Phase-3 Option (a), determinism-safe) **+** the **room-count
  override** knob **+ newly authored larger / more-varied greybox room pieces** (the Phase-3 recommendation to defer new
  pieces to M2 is **OVERRIDDEN** — they are in M1.2 scope). Rationale: the Director wants genuine spatial variety + scale,
  not just a uniform zoom.
- **Scope/build implication:** I1 now has a **second builder — `environment-artist`** authoring new larger greybox
  pieces (proper B1 sockets so the generator can stitch them; greybox rects, no real art) alongside `general-purpose`
  (count knob + size multiplier + generator/CFG/`junk_placer.gd` wiring — including the Phase-3 loot-mis-placement fix).
  The new pieces must carry correctly-tagged sockets + floor/wall so BUG3/BUG4 seal them and B2/B3 grade them.
- **C (per-piece-type size) + D/F (traversal/seal):** as resolved in Phase 3 (configurable; seal is cell-space, moot).
- **E:** keep `lvl_` knobs out of `all_oppositions_disabled()` (settled, not a Director call).

**Design LOCKED.** All-off / default still reproduces the M1.1 baseline (default count + mult 1.0 + the existing piece
set); the new larger pieces only appear when the Director dials count/size or selects them.
