# BUG2 — Within-band depth not tracked

**Milestone:** M1.1 (Greybox Cost Axis) · **Workstream:** (a) Foundations · **Wave:** 1
**Assignee role:** `general-purpose` (the programmer)
**Flags:** `[GS]` (edits `systems/game_state.gd`) · **adjacent to BUG1** — run BUG1+BUG2 as one sequential `game_state.gd` pass after R0 lands (M1.1_Breakdown §6, Wave 1)
**dependsOn:** R0 (`active_run_config` + the run-state shape are already on `main`); nothing else.
**Load-bearing:** every R1–R4 opposition reads *live within-band depth at runtime* to scale its cost. This bug is on the wave-2 critical path.

> **Canonical sources this spec defers to:** `M1_As_Built.md` (real autoload APIs — *this wins over any code sketch*), `B3_band_depth_structure.md` (the depth model), `M1.1_Breakdown.md` §4 (the BUG2 entry + acceptance), and the live `systems/game_state.gd` / `systems/event_bus.gd` / `systems/telemetry/telemetry.gd` / `scenes/game/main_game.gd`.

---

## 1. Goal & design intent

M1.1's whole thesis is a **depth-scaled cost/risk axis**: the deeper the player pushes, the more the four oppositions (R1 pursuing hazard, R2 costlier return, R3 exposure, R4 maze) cost them. That only works if **"how deep am I right now" is a real, live, readable number at runtime** — every opposition keys its magnitude off it, and the re-gate analysis ("how deep did they push under risk?") needs it on every run.

Today it is **not real**:

- `GameState.current_depth` is a **band-ENTRY counter**, not within-band depth. `enter_band()` does `current_depth += 1` (`game_state.gd:131-134`), and `MainGame.start_new_run()` calls `enter_band(BAND_ID)` exactly once per run (`main_game.gd:153`). M1 is **one band**, so `current_depth` is **stuck at 1** for the entire dive no matter how far the player walks.
- B3 already built the real spatial depth model — `PlacedPiece.depth_index` (BFS hops from the entry gate), `depth_norm` (0..1), `dist_to_gate` (reverse-BFS hops home), and `Band.max_depth` (`placed_piece.gd:42-55`, `band.gd:38-39`) — but **nothing reads it at runtime.** It's computed at generation time (`DepthGrader.grade()` / `compute_return_distance()` in `main_game.gd:138-140`), used by `JunkPlacer` to scale loot, and then the `Band` data object is **discarded** (it's a local var in `start_new_run()`; only the piece *instances* survive in `_band_container`).
- Consequently `run_ended.depth_reached` (third arg, emitted from `end_run()` as `current_depth`, `game_state.gd:205`) reports **1** on every run. Telemetry's `band_depth_reached` row and `run_ended.data.max_depth` (`telemetry.gd:118-124, 193`) inherit the same stuck value.

**The fix:** track the player's **live within-band depth** — the `depth_index` of the `PlacedPiece` they're physically standing in, plus the **max** reached this run — in run-state; emit it on change; and feed the max into `run_ended.depth_reached`. The depth model already exists (B3); BUG2 only **connects player world-position → piece → depth_index → run-state/telemetry**, which B3 never wired because M1.0 had no consumer for it.

**Design intent in one line:** *the cost axis is depth-scaled, so live within-band depth must be a real run-state value any opposition can read this frame and the gate can trust on `run_ended`.*

---

## 2. Design / approach

### 2.1 New run-state on `GameState`

Add two run-state members (run-scoped, **never persisted** — they sit with the other run-state, reset in `start_run`, cleared on `end_run`):

```gdscript
# --- RUN-STATE (disposable) — M1.1 BUG2: live within-band depth ---------------
var current_depth_index: int = 0    # depth_index of the piece the player is in NOW (entry == 0)
var max_depth_reached: int = 0      # the deepest depth_index reached this run (the gate metric)
var current_dist_to_gate: int = 0   # dist_to_gate of the piece the player is in NOW ("how far home"); == depth on the linear spine, diverges once R4 branches
```

> **Three members, by ratified Decision 4.** `current_depth_index` is the canonical "how deep / how dangerous" read; `current_dist_to_gate` is the parallel "how far home" read R2/R4 scale return cost off once `branch_chance > 0`; `max_depth_reached` is the gate ratchet. On the linear M1.0/M1.1 spine `current_dist_to_gate == current_depth_index`; they diverge only when R4 turns on branching. All three are run-scoped and **never persisted**.

> **Naming — do NOT reuse `current_depth`.** `current_depth` keeps its existing band-entry meaning (it's the `band_entered`/`enter_band` counter and the HUD "Depth N" source today). BUG2 introduces a **separate, spatially-real** number. Reusing the name would silently change the HUD and `band_entered.depth` semantics and break the locked dive lifecycle contract. **By ratified Decision 5, the HUD and Telemetry's `_current_depth()` *do* migrate to read `current_depth_index`** — but as explicit, separately-owned follow-ups (E2 = ui-ux-designer; telemetry = TEL), **not** silently inside this BUG2 pass. BUG2 still only *adds* the new members; it does not repurpose `current_depth`.

### 2.2 Resolving "which piece is the player in?" — point-in-footprint (ratified Decision 1)

**Ratified method (Decision 1): point-in-footprint via a precomputed `{cell: depth_index}` dict.** The two alternatives below are recorded only for context — they are rejected.

The map is BFS-graded into discrete `PlacedPiece`s, each owning a set of **band-global floor cells** (`PlacedPiece.floor_cells: Array[Vector2i]`) at a known `cell_size_px` (16, B1 canonical). The player has a world `global_position`. So the resolution is a **point → cell → owning-piece** lookup:

1. Convert player world pos to a **band-global cell**: `cell = Vector2i((world_pos / cell_size_px).floor())`. (Pieces are materialised at `offset_cell * cell_size`, so band-global cell space and world space share the origin — no per-piece transform needed. See `main_game.gd:_materialise_band`.)
2. Find the piece whose `floor_cells` (or `footprint_cells`) **contains that cell**.
3. That piece's `depth_index` is the live depth.

**Three candidate methods (ratified: #1):**

| # | Method | Pros | Cons |
|---|---|---|---|
| **1 (ratified)** | **Point-in-footprint via a precomputed `cell → depth_index` dict.** At run start, flatten every piece's `floor_cells` into one `Dictionary` `{Vector2i cell : int depth_index}`. Per check: one int-cell floor + one dict lookup — O(1), pure integer math, exact. | O(1), deterministic, exact (no "nearest" ambiguity), trivial to test, survives branching. | Needs the per-run cell→depth map built once (cheap; ~hundreds of cells). |
| 2 | **Nearest-piece by centroid distance.** Compare player pos to each piece's centroid; pick the closest. | No cell map needed. | O(pieces) per check; **wrong at piece boundaries / doorways**; float distance = a determinism smell; ambiguous when two pieces are equidistant. |
| 3 | **An `Area2D` trigger per piece** that emits on body-enter/exit. | Event-driven (no polling); naturally fires only on change. | New nodes + collision layer wiring per piece; overlap at doorways double-fires; couples depth to physics frame timing; more scene-graph churn for greybox. Heavier than the problem. |

**Ratified: method 1** (precomputed `cell → depth_index` dict + point-in-footprint). It's exact, O(1), integer-deterministic, and reuses B3's existing cell data with zero new nodes — the cleanest fit for the integer-cell world. Method 3's "only fires on change" benefit is recovered for free by the throttle in §2.3 (we already emit only on change). Use `floor_cells` (walkable cells) for the map; the player can only stand on floor, and walls/corners shouldn't map to a depth. **By Decision 4, the map carries `dist_to_gate` alongside `depth_index`** so the same lookup yields both metrics (see §2.4 / §4).

> **Where the per-run cell→depth map lives.** The `Band` object that holds the graded pieces is currently a **throwaway local** in `MainGame.start_new_run()`. BUG2 needs the depth data to outlive generation. **Seam:** `MainGame` builds the flat per-cell map from the graded `band` right after `grader.grade()` / `grader.compute_return_distance()` and holds it on the depth driver (§2.4) — `GameState` stays a pure data/lifecycle holder and does **not** gain a dependency on `Band`/`PlacedPiece`. By Decision 4 the map stores **both** metrics per cell (`{cell: {depth_index, dist_to_gate}}`, or two parallel dicts), since `compute_return_distance()` has already populated `dist_to_gate` by this point. (`GameState.start_run` is **not** given the geometry — that keeps `start_run(band_id, seed)` locked and `GameState` free of geometry types.)

### 2.3 When to update — on piece-change, not every frame

Resolving + emitting every physics frame is wasteful and noisy. Update on a **throttle**, and **emit only on a depth change**:

- **Drive** the resolution from a cheap cadence: a **~0.15 s** accumulator over `_physics_process` (≈ every 9 physics frames), exposed as a tunable `@export var depth_tick_interval := 0.15` on the dive-scene driver (ratified Decision 2). The cadence is a pure perf/responsiveness knob — correctness is unaffected because we emit on change, not on tick.
- Each tick: resolve `depth_index` for the player's current cell. **If it differs from `current_depth_index`**, update `current_depth_index`, bump `max_depth_reached = maxi(max_depth_reached, current_depth_index)`, and **emit `depth_changed(current_depth_index, max_depth_reached)` once.** No change → no emit, no signal traffic.
- This makes the signal **edge-triggered** (fires only when the player crosses into a new-depth piece), which is exactly what every consumer wants and keeps the JSONL clean. It also recovers method-3's "only on change" property for free.

### 2.4 Where the driver lives

The driver needs the player's live world position and the per-run cell→depth map. **Recommended home: a small node in `MainGame`'s dive scene** (a `DepthTracker` child, or a few lines folded into `MainGame` itself), because:

- `MainGame` already owns the band → it has the graded pieces to build the cell map from, and it owns the player node (`$Player`, also in the `"player"` group per `player.tscn`).
- `GameState` is an autoload with no scene/world access and no per-frame loop — it shouldn't poll positions. Keep `GameState` as the **state holder + emit surface** (the new members + a tiny `set_current_depth()` mutator that does the max/emit bookkeeping), and let the scene-side driver **call into it** each time it resolves the player's cell.

So the split is:
- **`MainGame` (scene):** builds the per-cell `{depth_index, dist_to_gate}` map at run start; throttled tick resolves the player's piece; each resolve calls `GameState.set_current_depth(depth_index, dist_to_gate)`.
- **`GameState` (autoload):** owns `current_depth_index` / `current_dist_to_gate` / `max_depth_reached`; `set_current_depth()` refreshes them + emits `depth_changed` (edge-triggered on depth); `start_run` resets all three to 0; `end_run` feeds `max_depth_reached` into `run_ended.depth_reached`.

This keeps the run/meta boundary clean and avoids `GameState` importing geometry types.

### 2.5 Feed `max_depth_reached` to `run_ended.depth_reached`

In `end_run()` (`game_state.gd:198-205`), change the emit's third arg from `current_depth` to `max_depth_reached`:

```gdscript
EventBus.run_ended.emit(reason, duration_s, max_depth_reached)   # was: current_depth
```

The arity is **unchanged** (`reason, duration_s, depth_reached`) — we only correct the *value* flowing into the already-locked third slot. Telemetry's `_on_run_ended` already consumes `depth_reached` (`telemetry.gd:163, 184, 193`) and will now record the true max. No telemetry-contract change needed for the run-end row.

---

## 3. Signal design

**New signal:** `depth_changed(depth_index: int, max_depth: int)` on `EventBus`. **Declared by TEL** (the sole `event_bus.gd` editor); **emitted by BUG2/GameState** (Decision 3).

- **Emitted by:** `GameState.set_current_depth()` — **only when `depth_index` actually changes** (edge-triggered). BUG2 emits this signal but does **not** declare it.
- **Payload:** `depth_index` = the player's current within-band depth (entry piece = 0); `max_depth` = the deepest reached this run. Both ints (JSONL-clean for Telemetry).
- **Consumers:** Telemetry (a depth row + keeping its running max honest), the HUD (per ratified Decision 5, the "Depth N" readout migrates to `current_depth_index`), and any R1–R4 opposition that wants to react on the *transition* rather than poll (most will poll the run-state read surface in §4; the signal is the event-driven complement).

### Ownership / `event_bus.gd` edit coordination — **RATIFIED (Decision 3) — must read**

**`depth_changed` is DECLARED by TEL and EMITTED by BUG2/GameState. BUG2 never edits `event_bus.gd`.** This is the ratified split (Decision 3) and is non-negotiable for the wave-1 fan-out:

- **TEL declares it.** TEL is the **sole `event_bus.gd` editor** for the milestone. `depth_changed(depth_index, max_depth)` is folded into TEL's single wave-1 `event_bus.gd` pre-declaration edit, alongside the opposition signals (hazard_awoke, hazard_caught, return_cost_incurred, exposure_crossed, exposure_penalty, nav_branch_taken, nav_lost_proxy). The file is therefore touched **exactly once** in wave 1.
- **BUG2/GameState only emits it.** BUG2 (running as part of the BUG1+BUG2 `game_state.gd` pass) emits the already-declared `depth_changed` from `GameState.set_current_depth()` and **never declares it / never edits `event_bus.gd`** — eliminating any collision with TEL.
- **Sequencing:** TEL's `event_bus.gd` declaration lands on `main` **before** the BUG1+BUG2 pass emits it and before the wave-2 parallel oppositions begin. Because BUG2 does not touch `event_bus.gd`, the two passes cannot collide on that file regardless of order; the only hard requirement is that the declaration exists on `main` before any emitter or consumer ships.

This mirrors the breakdown's §6 rules without contradiction: although `M1.1_Breakdown.md` §6 lists `depth_changed` among the pre-declared signals, its declaration is owned by TEL (the sole `event_bus.gd` editor), not by BUG2.

The declared line (written by TEL) is:

```gdscript
# --- Within-band depth (BUG2) ------------------------------------------------
# Declared HERE by TEL (sole event_bus.gd editor); EMITTED by GameState (BUG2).
# Edge-triggered: emitted by GameState only when the player crosses into a piece
# of a different depth_index. depth_index = current within-band depth (entry == 0);
# max_depth = deepest reached this run. R1–R4 read GameState.current_depth_index /
# .current_dist_to_gate directly; this signal is the event-driven complement +
# Telemetry's depth row.
signal depth_changed(depth_index: int, max_depth: int)
```

---

## 4. Runtime read surface for R1–R4 (the contract all four oppositions build on)

Make the read surface **explicit and uniform** — this is the single thing R1, R2, R3, R4 all depend on, so it must be unambiguous before wave 2.

**Each opposition reads live within-band depth as a plain run-state property on the `GameState` autoload:**

| Read | Meaning | Use |
|---|---|---|
| `GameState.current_depth_index` | The `depth_index` of the piece the player is in **right now** (entry = 0). | The canonical "how deep / how dangerous" scaling input. R1 awaken-threshold, R2 egress-toll curve, R3 exposure climb-rate multiplier, R4 vision-tightening all key off this. |
| `GameState.current_dist_to_gate` | The `dist_to_gate` of the piece the player is in **right now** ("how far home"). == `current_depth_index` on the linear spine; diverges once R4 branches. | The "how expensive to get home" scaling input — **R2's costlier-return toll and R4's nav cost read this** (ratified Decision 4). |
| `GameState.max_depth_reached` | Deepest `depth_index` reached this run. | The gate metric; also useful for "ratchet" oppositions that shouldn't relax when the player retreats. |

**Two access patterns, both supported:**

- **Pull (recommended default for the oppositions):** read `GameState.current_depth_index` directly whenever you need it (in your own `_process`/tick). It's a plain int, always current, no subscription needed. This is the simplest and matches how E2's HUD reads `current_depth` today.
- **Push (event-driven):** `EventBus.depth_changed.connect(...)` to react exactly on the transition into a new-depth piece (e.g. R1 checking "did we just cross the awaken threshold?"). Edge-triggered, fires once per crossing.

> **Branching note for R4 (ratified Decision 4):** on the M1.0/M1.1 linear spine, `depth_index` == `dist_to_gate`, so the two reads coincide. The moment R4 turns on `branch_chance > 0`, "depth" (how far in) and "distance home" (how far the return trip is) **diverge**. `current_depth_index` answers *"how deep / how dangerous"*; **`current_dist_to_gate` answers "how expensive to get home from here," and R2's costlier-return toll and R4's nav cost read that.** Both are exposed live as run-state (Decision 4): BUG2's cell map carries `dist_to_gate` alongside `depth_index`, so each throttled resolution updates **both** members in one lookup — no second resolution pass.

This read surface is the **explicit BUG2→R1–R4 contract**: every opposition spec (`R<n>_*.md`) should state "reads `GameState.current_depth_index`" rather than reinventing position→depth resolution.

---

## 5. Pseudocode

### 5.1 `GameState` (autoload) — state + emit (folded into the BUG1+BUG2 `game_state.gd` pass)

```gdscript
# --- RUN-STATE additions -----------------------------------------------------
var current_depth_index: int = 0
var max_depth_reached: int = 0
var current_dist_to_gate: int = 0    # Decision 4: live "how far home" read

func start_run(band_id: StringName, seed: int) -> void:
    ...
    current_depth_index = 0          # BUG2: reset live depth (player starts at entry == 0)
    max_depth_reached = 0
    current_dist_to_gate = 0
    ...                              # (existing R0 config bind, RNG seed, run_started emit)

## BUG2: the single mutator for live within-band depth. The scene-side driver
## (MainGame) calls this when the player crosses into a new piece, passing both
## metrics (Decision 4). Edge-triggered on depth_index: only emits when depth changes.
func set_current_depth(idx: int, dist_home: int) -> void:
    current_dist_to_gate = dist_home   # always refresh "how far home"
    if idx == current_depth_index:
        return                         # no-op on same-depth ticks → no signal spam
    current_depth_index = idx
    if idx > max_depth_reached:
        max_depth_reached = idx
    EventBus.depth_changed.emit(current_depth_index, max_depth_reached)

func end_run(reason: StringName, duration_s: float) -> void:
    run_active = false
    if run_inventory != null:
        run_inventory.clear_run()
    active_run_config = null
    # BUG2: report the MAX within-band depth, not the stuck band-entry counter.
    EventBus.run_ended.emit(reason, duration_s, max_depth_reached)   # was current_depth
    # (current_depth_index / max_depth_reached reset next start_run; harmless to leave.)
```

> Note: `extract_and_end_run()` and `fail_run()` both route through `end_run()`, so feeding `max_depth_reached` there fixes **all three** end causes (extract / death / timeout) in one place. The "belt-and-suspenders" `current_depth = 0` resets in those funcs are left as-is (they touch the old counter, not BUG2's members).

### 5.2 `MainGame` (scene) — build the cell map + drive the resolution

```gdscript
# Built once per run from the graded band; flattened so per-tick lookup is O(1).
# Decision 4: each cell maps to BOTH metrics (depth_index + dist_to_gate).
var _cell_to_depth: Dictionary = {}   # Vector2i band-global floor cell -> Vector2i(depth_index, dist_to_gate)
var _depth_tick_accum: float = 0.0
@export var depth_tick_interval := 0.15   # throttle, tunable (ratified Decision 2)

func start_new_run() -> void:
    ...
    var grader := DepthGrader.new()
    grader.grade(band)
    grader.compute_return_distance(band)   # populates dist_to_gate (read below)
    _build_cell_depth_map(band)       # BUG2: capture the depth model before `band` is discarded
    ...                               # (existing materialise / spawn / gate / player place)
    GameState.start_run(BAND_ID, seed)
    GameState.enter_band(BAND_ID)
    # Resolve once immediately so depth is correct on frame 0 (player at entry → 0).
    _resolve_player_depth()

func _build_cell_depth_map(band: Band) -> void:
    _cell_to_depth.clear()
    for p in band.pieces:
        if p.depth_index < 0:         # ungraded guard
            continue
        for cell in p.floor_cells:    # band-global floor cells (B3)
            _cell_to_depth[cell] = Vector2i(p.depth_index, p.dist_to_gate)

func _physics_process(delta: float) -> void:
    if not GameState.run_active:
        return
    _depth_tick_accum += delta
    if _depth_tick_accum < depth_tick_interval:
        return
    _depth_tick_accum = 0.0
    _resolve_player_depth()

func _resolve_player_depth() -> void:
    var player := get_tree().get_first_node_in_group(&"player")   # player.tscn is in "player"
    if player == null:
        return
    var cell := Vector2i((player.global_position / float(_band_cell_size_px)).floor())
    if _cell_to_depth.has(cell):
        var d: Vector2i = _cell_to_depth[cell]
        GameState.set_current_depth(d.x, d.y)   # (depth_index, dist_to_gate)
    # else (Decision 6): player over a wall edge / mid-doorway rounding — KEEP the last
    # known depth. Do not snap to 0; that would emit a spurious depth_changed edge.
```

### 5.3 Telemetry (TEL — coordinate, do not edit in this pass)

TEL owns `telemetry.gd`. Two small touches it should make so depth telemetry is real (BUG2 *enables* these; TEL *writes* them):

- Add a `depth_changed` handler that appends a `DEPTH_CHANGED` JSONL row `{depth, max_depth}` (a new `EventType` const), so the analysis can see the within-band depth funnel, not just the per-band-entry `band_depth_reached`.
- `_current_depth()` (used by junk-pickup / bank rows) currently returns `GameState.current_depth` (the stuck counter, `telemetry.gd:210-213`). **TEL migrates it to `GameState.current_depth_index`** so pickup/bank depth-tagging reflects real spatial depth (ratified Decision 5). This is a deliberate, ratified change to the meaning of `depth` on those rows — owned by TEL, not done inside BUG2.

> BUG2 does **not** edit `telemetry.gd`; it makes the data available and flags these as TEL's follow-ups so the §6 "TEL owns telemetry files" boundary holds.

---

## 6. Files to touch

| File | Change | Owner / coordination |
|---|---|---|
| `systems/game_state.gd` `[GS]` | Add `current_depth_index` / `current_dist_to_gate` / `max_depth_reached` run-state; reset all three in `start_run`; add `set_current_depth(idx, dist_home)` mutator (refreshes both, emits `depth_changed` edge-triggered on depth); change `end_run`'s `run_ended` 3rd arg to `max_depth_reached`. | **BUG2.** Runs as **one combined `game_state.gd` pass with BUG1** (start-time capture) — they're small and adjacent; do them on one branch so two agents never edit `game_state.gd` at once (§6). |
| `scenes/game/main_game.gd` | Build `_cell_to_depth` (per-cell `{depth_index, dist_to_gate}`) from the graded band before it's discarded; throttled `_physics_process` driver resolving player→cell→depth; call `GameState.set_current_depth(idx, dist)` each resolve. | **BUG2.** Disjoint from BUG1. |
| `systems/event_bus.gd` `[EB]` | Declare `depth_changed(depth_index, max_depth)`. | **TEL declares it (ratified Decision 3) — NOT BUG2.** Folded into TEL's single wave-1 `event_bus.gd` edit before the wave-2 fan-out. BUG2 only **emits** the already-declared signal. |
| `systems/telemetry/telemetry.gd` | `depth_changed` → `DEPTH_CHANGED` row; **migrate `_current_depth()` to `current_depth_index`** (ratified Decision 5). | **TEL** (sole telemetry-file editor). BUG2 only flags these. |
| `scenes/.../hud` (E2) | **Migrate the "Depth N" readout from `current_depth` to `current_depth_index`** (ratified Decision 5). | **ui-ux-designer** follow-up — separately owned, **not** inside BUG2. |

**Explicitly NOT touched by BUG2:** `placed_piece.gd` / `band.gd` (B3's model is already correct — BUG2 only *reads* it), `systems/event_bus.gd` (TEL declares `depth_changed`, Decision 3 — BUG2 only emits it), the oppositions (they read the §4 surface), the HUD and `telemetry.gd` (their migration to `current_depth_index` per Decision 5 is owned by ui-ux-designer and TEL respectively, not by BUG2).

---

## 7. Acceptance criteria

Restated from `M1.1_Breakdown.md` §4 (BUG2) + made checkable:

1. **Live depth updates as the player moves deeper.** Walking from the entry gate into successively deeper pieces increments `GameState.current_depth_index` (0 at entry, +1 per piece deeper on the spine), updated within one throttle interval of crossing a piece boundary.
2. **`depth_changed` fires edge-triggered.** The signal emits **once** per crossing into a new-depth piece (with `(depth_index, max_depth)`), and **does not** fire while the player stays in the same piece.
3. **Telemetry reflects real depth.** With BUG2 + TEL's follow-up, a run's JSONL shows depth advancing (a `DEPTH_CHANGED`/depth funnel), not a constant 1; pickup/bank rows tag the real spatial depth.
4. **`run_ended.depth_reached` = max within-band depth, not 1.** A run that pushes to piece depth N and extracts/dies/times-out emits `run_ended(reason, duration_s, N)` (and `run_ended.data.max_depth == N`), for **all three** end causes. Retreating before ending does **not** lower the reported max (ratchet via `max_depth_reached`).
5. **R1–R4 can read current depth at runtime.** `GameState.current_depth_index` is a populated, live int any opposition can read this frame (pull) and `EventBus.depth_changed` is connectable (push) — the §4 contract holds.
6. **No regression with oppositions off / baseline.** The all-off M1.0-baseline run is unaffected except that `depth_reached` now reports the true max (a *correction*, the intended behaviour — flag in the wave-1 deviation sweep if any existing test asserts the old stuck-1 value, e.g. `tests/test_decision_hud.gd` reads `current_depth`, which BUG2 leaves untouched).
7. **Determinism preserved.** Depth resolution is pure integer cell math over B3's deterministic graded graph; it introduces no RNG and does not perturb `band.fingerprint()`.
8. **A GdUnit4 / headless assertion covers it** (mirrors BUG1's test bar): given a known graded band + a sequence of player positions, `current_depth_index` / `max_depth_reached` track correctly and `run_ended.depth_reached` equals the max. (Note the `M1_As_Built.md` headless-autoload constraint: run as a headless scene or resolve `GameState` via the SceneTree.)

---

## 8. Resolved Decisions (Director-ratified 2026-06-19 — apply-all-recommendations)

The Director ruled to **adopt every recommendation in the prior "Open Questions" section as a ratified decision.** Each former question is now a committed decision below; the body of this spec (§§2–6) is written to these decisions.

1. **Decision: piece resolution is point-in-footprint via a precomputed `{cell: depth_index}` dict (§2.2 method 1).** Rationale: O(1), exact, integer-deterministic, reuses B3's `floor_cells` with zero new nodes — the only method that is boundary-exact and determinism-safe. Nearest-centroid and per-piece `Area2D` triggers are rejected as boundary-ambiguous and/or heavier.
2. **Decision: drive resolution on a ~0.15 s throttle (≈ every 9 physics frames), exposed as a tunable `@export` on the dive-scene driver.** Rationale: correctness is throttle-independent (we emit on *change*, not on tick), so the cadence is a pure perf/responsiveness knob and is best left adjustable in the scene.
3. **Decision: TEL declares `depth_changed` as part of its single wave-1 `event_bus.gd` edit; BUG2 only emits it, never edits `event_bus.gd`.** Rationale: keeps `event_bus.gd` touched exactly once in wave 1 so no two worktree agents edit it concurrently, and respects "TEL is the sole `event_bus.gd` editor." (Cross-cutting — see §3 and the Files table §6.)
4. **Decision: "depth" canonically means `current_depth_index` ("how deep / how dangerous"), and BUG2 *also* exposes live `current_dist_to_gate` ("how far home"), carried in the same cell map.** Rationale: on the linear spine the two coincide, but once R4 raises `branch_chance` they diverge; carrying `dist_to_gate` in the existing map is nearly free and gives R2's egress-toll and R4's nav cost the real path-home metric without a second resolution pass.
5. **Decision: the HUD (E2) and Telemetry's `_current_depth()` migrate from `current_depth` to `current_depth_index`, as small flagged follow-ups owned by ui-ux-designer (HUD) and TEL (telemetry) — not silently inside BUG2.** Rationale: the player-facing and pickup/bank-tagging "Depth" should mean real within-band spatial depth; BUG2 still adds a *separate* run-state member (it does not repurpose `current_depth`), so the locked `band_entered`/`enter_band` semantics stay intact and the migration is an explicit, separately-owned change.
6. **Decision: when the player's cell is in no piece's `floor_cells` (wall edge / mid-doorway rounding), keep the last known depth — never snap to 0.** Rationale: the player is momentarily over a non-floor cell, not back at the entry; holding the last resolved depth avoids spurious depth flicker and false `depth_changed` edges.
