# I2 — Hazard Fix (size, navigation, catch) — Expanded Design Spec

**Milestone:** M1.2 (Legibility & Level Scale) · **Workstream:** (b) oppositions retuned to the new canvas · **Wave:** 2 (parallel worktree, after Wave 1 on `main`)
**Task id:** I2 · **dependsOn:** I1 (level scale — tune against the new room scale) · **fixes:** R1 (`design/M1_1_Tasks/R1_pursuing_hazard.md`)
**Assignees:** game-director-designer (this spec + config-default deltas) · general-purpose (behaviour fix) · character-animator (greybox tell tweaks if the body shrinks)
**Author:** game-director-designer · **Status:** Phase-2 design (per `M1.2_Breakdown.md` §4 + `CLAUDE.md` three-phase process). **Design only — no code, no `.tscn`.** Open questions in §6 are resolved by the Phase-3 fresh-eyes pass + Director.

> **What this doc is.** Phase-2 design for I2 — the fix that makes the M1.1 pursuing hazard (R1) **actually catch**. M1.1 telemetry: `hazard_awoke = 7` but `hazard_caught = 0` — the predator wakes but never closes the kill. This spec diagnoses *why* against the real M1.1 code and geometry, prescribes the cheapest greybox fixes, and flags every feel/fairness call for the Director. It **inherits R1's contract wholesale** (`R1_pursuing_hazard.md` §0): throwaway greybox, configurable-not-balanced, all-off == M1.0, reads-only / never widens locked contracts, file-disjoint. I2 changes *only* the closing behaviour, the body size, the catch test, and the awaken-threshold defaults — not the mechanic's shape.

---

## 0. Hard constraints (inherited from R1 §0 — unchanged, restated for the builder)

- **THROWAWAY greybox, NOT the M2 enemy-AI slice.** No A*, no navmesh, no flow field, no behaviour tree, no steering library. The fix is still "a colored shape that moves toward the player." Crude is correct. The whole point of I2 is to make the crude thing *catch* without graduating it into real AI.
- **Configurable, not balanced.** Acceptance is "the catch fires at a fair rate and every knob takes effect," never "the value is right." Ship the new defaults in §5 but assume the Director sweeps every number.
- **All-off reproduces M1.0/M1.1 baseline exactly.** With `r1_enabled = false` no hazard node is instantiated. I2 must not change that: zero cost, zero behavioural delta, zero telemetry rows when off.
- **Reads only; does not widen the locked contracts.** I2 still reads `GameState.active_run_config` (snapshotted at `setup`) and `GameState.current_depth_index` live. It **must NOT edit `event_bus.gd`** (`hazard_awoke`/`hazard_caught` already declared) and **must NOT edit `game_state.gd`** (the read surface + `fail_run(&"death")` are fixed). Kill routing stays `GameState.fail_run(&"death")` — no new end path.
- **File-disjoint.** I2 owns `scenes/hazards/hazard_entity.gd` + `scenes/hazards/hazard_entity.tscn` and the one spawn seam in `scenes/game/main_game.gd` (`_spawn_r1_hazards` / `_hazard_spawn_position`). **Watch the `main_game.gd` collision with I4** (vision/fog) — both Wave-2 tasks may touch the dive-scene wiring (`M1.2_Breakdown.md` §6); coordinate the seam at brief time (sequence or split). I2's `main_game.gd` edits, if any, are confined to the hazard spawn helpers.
- **No new `RunConfig` field unless §6 is resolved to add one.** R0 owns the schema; new knobs are a coordinated I1/R0 change (I1 already edits `run_config.gd` in Wave 1). The default path reuses the existing `r1_*` fields; §6-Q3 flags the one candidate new knob (depth-scaled catch radius) for the Director.

---

## 1. Goal & premise research — why the catch never fires

**One sentence:** *Make the predator actually catch — at a fair, legible rate — on the (now larger, I1-scaled) levels, by shrinking it so it fits the halls, stopping it wall-sticking short of the kill, and giving it a real catch hitbox; everything else about R1 stays.*

### 1.1 What M1.1 measured (the bug)

From `design/M1_1_Tasks/G4_findings_M1.1.md` §2 (issue **I2**) and §1:
- `hazard_awoke = 7` across 8 R1-config runs — **the wake works.** The depth/linger trigger, the tell flip, and the chase-start all fire.
- `hazard_caught = 0` — **the catch never fires.** The hazard wakes and moves but never reaches `r1_catch_radius` of the player. Every `death` in the R1 runs (4 of 8) was the **debug-kill key (K)**, not a hazard (G4 §1 footnote).
- Director report: the hazard is **too large and gets stuck in halls**, and it **wakes at depth 0–1** (instant) on the tiny M1.1 levels.

So the kill *routing* is correct (R1 §2.5: `fail_run(&"death")`) — the body simply never closes to catch range. I2 is a **closing/geometry fix**, not a routing fix.

### 1.2 Root cause, measured against the real code + geometry

I read the actual M1.1 build. The numbers make the failure exact:

| Body | Shape | Diameter | Source |
|---|---|---|---|
| **Cell** | grid unit | **16 px** | `main_game.gd` `DEFAULT_CELL_SIZE_PX := 16` |
| **Player** | `CircleShape2D` radius 14 | **28 px** | `entities/player/player.tscn` |
| **Hazard** | `CircleShape2D` radius 16 | **32 px** | `scenes/hazards/hazard_entity.tscn` (`CircleShape2D_hazard`) |
| **H-corridor open floor** | rows 1–2 of an 8×4 piece (rows 0 & 3 are wall) | **2 cells = 32 px** | `bands/pieces/piece_corridor_h.tscn` (TileMapLayer: floor only on rows 1–2) |

**The hazard's 32 px collision diameter is exactly equal to the 32 px open-floor width of a corridor.** With `move_and_slide()` against the `world` collision layer (R1 §2.3 option (a), as built — `hazard_entity.gd` line 92), the body has **zero clearance**: any sub-pixel mis-centering pins it against the top or bottom wall, and the slide vector along a wall is the wall-tangent component of "toward player," which in a horizontal corridor is purely horizontal — fine *until* the player is offset vertically (in the other corridor lane or in a room above/below), at which point the toward-player vector is mostly the **blocked** (perpendicular-to-wall) component and the slide residue is tiny. The body grinds the wall and **crawls or stalls**, never closing the last 32 px to a player who is themselves only 28 px wide in the same 32 px slot. The note in `hazard_entity.gd` ("getting stuck behind geometry is a *feature*, a partial refuge") was *designed for occasional refuge* but in 4-cell halls it is the **default state**, so the catch effectively never happens.

Compounding it (per the Director report + G4):
- **Awaken at depth 0–1.** R1's suggested default is `r1_depth_threshold = 3` (R1 §6.2), but on M1.1's ~12-piece-but-tiny bands the hazard spawns *at* the threshold piece and the player crosses it almost immediately; in the actual sweeps it woke near entry. An instant wake on a 17-second level gives the player no "deeper = the threat grows" read — the wake and the (attempted) catch collapse into one beat. The threshold must be re-tuned to I1's larger rooms so the wake lands mid-journey, not at the door.
- **Catch radius vs. body.** `r1_catch_radius` suggested default was `~24 px` (R1 §6.2). That is *smaller than the sum of the two body radii* (14 + 16 = 30 px) — the bodies physically collide (center distance 30 px) *before* the script catch test (≤ 24 px) can ever be true. So even a hazard that perfectly overlaps the player is held 30 px away by physics and reports distance 30 > 24 → **no catch, ever**, independent of the corridor problem. This is a second, independent reason `hazard_caught = 0`.

**Two independent root causes, both lethal to the catch:**
1. **Body too big for the hall** → wall-sticks, never closes distance (geometry).
2. **Catch radius < combined body radii** → even at full physics contact the distance test can't pass (hitbox math).

I2 must fix **both** — shrinking the body alone won't help if the radius math still can't trip; widening the radius alone won't help if the body can't reach the corridor where the player is.

### 1.3 Interaction with I1 (must tune against the new scale)

I2 `dependsOn` I1 (`M1.2_Breakdown.md` §4, §5). I1 exposes **room count** and **room size** as `RunConfig` knobs and may scale cells and/or add larger authored pieces. Two consequences for I2:
- **If I1 scales the corridor wider** (e.g. a cell-scale multiplier, or a 6-cell-tall corridor), the body-vs-hall clearance problem eases *at the default I1 size* but I2 must still fit the **narrowest hall I1's defaults can produce** (I1's all-off default reproduces the 32 px corridor — see I1 §"default = current baseline"). **I2's body must fit the M1.1-baseline 32 px corridor** so the all-off + baseline-scale configs still work; bigger I1 rooms only give more margin.
- **If I1 makes the journey longer** (more/larger rooms → longer traversal), the awaken threshold and chase speed should scale so the wake still lands mid-journey and the predator can still close over the longer distances. I2's default-threshold recommendation (§5) is expressed **relative to I1's depth range**, and coordinated with I1's chosen defaults (§6-Q5).

> **Coordination action (brief time):** before building I2, read I1's resolved design for (a) the **minimum corridor floor width** any default config can produce and (b) the **default depth range** (room count). I2 tunes the body radius to (a) and the awaken threshold to (b). If I1 has not landed, build against the M1.1 baseline (32 px corridor, ~12-deep band) — that is the worst case and the permanent control.

---

## 2. Design / approach — the fix

The fix has **four parts**, in priority order. Parts 1–3 are mandatory (they make the catch *possible*); Part 4 is the re-tune that makes it *fair and legible*. All stay inside R1's mechanic — the hazard still wakes, chases toward the player, and routes a fatal catch through `fail_run(&"death")`.

### 2.1 Part 1 — Shrink the body so it fits a hall (geometry root cause)

Reduce the hazard's `CollisionShape2D` so it has real clearance inside the 32 px corridor floor. Target a collision radius that leaves **≥ ~25 % clearance** on each side of the narrowest default hall:

- Narrowest default hall floor = **32 px** (M1.1 baseline; I1 ≥ this). For the body to slide freely without pinning, its **diameter should be ≤ ~24 px → radius ≤ 12 px**, ideally **radius 10 px (20 px diameter)** to leave 6 px clearance each side. Compare: the player is radius 14 (28 px) and *barely* fits; the hazard being **smaller than the player** is fine and reads as "a fast little hunter," not a lumbering block.
- This is a `.tscn` edit (`CircleShape2D_hazard.radius`) plus a matching shrink of the greybox `Tell` polygon so the visual matches the new hitbox (character-animator: scale the diamond `Polygon2D` to ~±12 px; keep the dormant/awake colors and the wake-flash Tween from R1 §3).

> **Why shrink rather than only widen the hall:** shrinking is the cheapest, most local fix (one number in the `.tscn`) and works **independent of I1's final room size**, so I2 is not blocked on I1's exact scale. Widening the hall is I1's job; I2 should fit whatever I1 ships. See §6-Q1.

### 2.2 Part 2 — Anti-wall-stick closing (so it doesn't stall short)

Even a smaller body can pin in a corner or grind a wall when the toward-player vector points mostly *into* a wall. Add cheap anti-stick steering — **no pathfinding**. Pick the cheapest option that reads acceptably in greybox; the spec's default is **(a)**, with **(b)** as the escalation if (a) still stalls, and **(c)** as the nuclear fallback flagged for the Director (§6-Q2):

- **(a) Slide + de-pin nudge (recommended default).** Keep `move_and_slide()` toward the player, but detect a stall and break it:
  - After `move_and_slide()`, if the actual displacement this frame is far below the intended `speed * delta` (i.e. `get_real_velocity().length() < speed * STALL_FRACTION`, e.g. `STALL_FRACTION = 0.35`) **and** the hazard is colliding (`get_slide_collision_count() > 0`), apply a perpendicular "unstick" nudge: pick the wall normal from the slide collision, and bias the next-frame direction along the wall toward the player's side (add a small tangential component so it walks *along* the wall toward the opening rather than grinding into it).
  - This is ~10 lines, uses only `move_and_slide`'s own collision results, and turns "grind the wall forever" into "slide along the wall toward the player." Still crude, still no graph.
- **(b) Axis-decomposed greedy step (escalation).** If (a) still wall-hugs badly in playtest, move on the **dominant free axis** first: compute toward-player `dir`; try moving full-speed along the axis with the larger `|dir|` component; if that frame stalls, fall back to the other axis. This biases the hazard to "go down the corridor it's in, then turn," which matches greybox corridor topology without any navigation. Still no pathfinding — it's a 2-case `if`.
- **(c) Ghost-toward-player (nuclear, Director call — §6-Q2).** Drop the `world` collision mask so the hazard **ignores walls entirely** and lerps straight at the player through geometry. Guarantees the catch can always close, kills all stalling, and is trivially cheap — but **removes wall-refuge entirely** (the player can no longer break line by ducking behind a wall), which changes the *feel* R1 intended ("walls are a partial refuge," R1 §2.3). This is the surest fix and the biggest feel change → **Director decides** (§6-Q2). If chosen, it's a one-line collision-mask change; keep the distance catch test unchanged.

> **Recommendation:** ship **(a)** by default (preserves wall-refuge, cheap), and have the Director sweep it; if the catch rate is still ~0 after Part 1 + (a) + Part 3, escalate to (b), and only adopt (c) if the Director values "the catch always lands" over "walls hide you." All three are throwaway-cheap; this is a feel tradeoff, not an engineering one.

### 2.3 Part 3 — A catch radius that can actually trip (hitbox root cause)

The catch test must be able to return true. Two coupled fixes:

- **Raise the default `r1_catch_radius` above the combined body radii.** With player radius 14 + hazard radius 10 (new) = **24 px** minimum physical center distance. Set the **default catch radius to ~32 px** (> 24) so contact reliably trips the test before/at physical contact, with a small margin so a fast-closing hazard catches on approach rather than needing a perfect overlap. (Under the old 14+16=30 px bodies the radius had to clear 30; with the shrunk body it only has to clear 24, which is why Part 1 and Part 3 are coupled.)
- **Keep the catch a script distance test** (R1 §2.4 — deterministic, no physics overlap), but verify the test compares **center-to-center distance** (`global_position.distance_to(player.global_position)`) against `r1_catch_radius`, and that `r1_catch_radius ≥ player_radius + hazard_radius` for any config that intends to catch. Document this floor in the CFG menu / config notes so a Director sweep doesn't accidentally set a radius below the physical floor and re-create `caught = 0`.
- **Optional: depth- or speed-scaled catch radius (Director call — §6-Q3).** A flat radius is the cheapest and the recommended default. A *depth-scaled* radius (`effective_radius = r1_catch_radius + r1_catch_radius_per_depth * depth`) would make the predator "lunge further" the deeper you are — reinforcing "deeper = more dangerous" on the *catch* axis as well as the *speed* axis. This needs **one new `RunConfig` field** (`r1_catch_radius_per_depth`, default `0.0` = flat = today's behaviour), which is an I1/R0 schema coordination. Flagged for the Director; **default is flat** (no new field) so I2 ships without a schema dependency if the Director declines.

### 2.4 Part 4 — Re-tune the awaken threshold for I1's depths

So the wake lands **mid-journey**, not at the door, on I1's larger levels:

- Express the default `r1_depth_threshold` **relative to I1's default depth range**: aim for the wake at roughly **1/3 of the typical max depth** so the player gets a clear "shallow play is safe, then it stirs" arc. On the M1.1 baseline (max depth ~11) that is `r1_depth_threshold ≈ 4`; on a larger I1 default it scales up. Coordinate the exact number with I1's resolved room-count default (§6-Q5).
- Keep `r1_linger_seconds` as the secondary "don't dawdle" trigger but **raise it to match the longer I1 traversal** (M1.1's 17 s clear made a 20 s linger nearly dead; on longer levels a 30–45 s linger becomes a real anti-camp lever). Still `0.0` disables it.
- **The wake still latches permanently** (R1 §9 Q4 — no re-sleep). I2 does not change awaken stickiness. §6-Q4 re-raises "should it ever give up" only because a fairer, catching hazard makes a frustrating-forever predator more likely — flagged for the Director, default unchanged.
- **Chase speed re-tune:** R1's default was `~0.85 × player speed` (player `max_speed = 200`, so ~170 px/s) with `r1_speed_per_depth` adding depth scaling. With a *smaller, non-sticking* body the hazard is now genuinely faster-effective, so the Director may want the base back **below 0.85×** (e.g. 0.75×) to keep "turn back in time and you escape" true. This is a pure sweep value — §5 gives a starting point, the Director tunes.

### 2.5 What I2 does NOT change

- The R1 mechanic (dormant → awake → chase → catch → `fail_run(&"death")`), the two telemetry signals, the non-fatal `r1_catch_kills = false` path (R1 §2.5), multi-spawn independence (R1 §9 Q3), the spawn-at-threshold-piece location (R1 §9 Q1), the read-only contract, and all-off == baseline. **I2 is a tuning + geometry + closing fix on top of R1, not a redesign.**

---

## 3. Pseudocode — against the real `hazard_entity.gd`

GDScript-flavoured, **illustrative not final**, expressed as *diffs against the M1.1 `hazard_entity.gd`* read above. Only the changed regions are shown; everything else (the `setup`, the `_should_awaken`, the `_awaken`, the non-fatal path, the tell) is unchanged from R1.

### 3.1 `.tscn` change (body + tell shrink — Part 1)

```
# scenes/hazards/hazard_entity.tscn  (illustrative)
[sub_resource type="CircleShape2D" id="CircleShape2D_hazard"]
radius = 10.0          # was 16.0 — fits the 32 px corridor with clearance (§2.1)

[node name="Tell" type="Polygon2D" parent="."]
polygon = PackedVector2Array(0, -12, 12, 0, 0, 12, -12, 0)   # was ±18 — match the smaller body
# colors + groups + collision_layer/mask UNCHANGED (layer hazard, mask world)
```

### 3.2 Anti-wall-stick closing (Part 2, option (a)) — inside `_physics_process`

Replace the AWAKE move/catch block (M1.1 lines ~86–97) with the de-pin variant:

```gdscript
# --- AWAKE (I2: anti-wall-stick closing, §2.2 option (a)) ---------------------
var depth: int = GameState.current_depth_index
var speed: float = _cfg.r1_chase_speed + _cfg.r1_speed_per_depth * float(depth)

var to_player: Vector2 = _player.global_position - global_position
var dir: Vector2 = to_player.normalized() if to_player.length() > 0.001 else Vector2.ZERO

velocity = dir * speed
move_and_slide()

# De-pin: if we barely moved this frame AND we're touching a wall, we're grinding it.
# Nudge along the wall toward the player's side so we walk to the opening, not into it.
# NO pathfinding — pure local slide-collision math (§2.2).
if get_slide_collision_count() > 0 \
        and get_real_velocity().length() < speed * STALL_FRACTION:
    var col := get_last_slide_collision()
    if col != null:
        var n: Vector2 = col.get_normal()
        # tangent along the wall, oriented toward the player
        var tangent: Vector2 = Vector2(-n.y, n.x)
        if tangent.dot(to_player) < 0.0:
            tangent = -tangent
        velocity = tangent * speed
        move_and_slide()   # one corrective step along the wall this frame

# --- Catch test (Part 3): radius now > player_r + hazard_r so contact can trip it.
var catch_r: float = _cfg.r1_catch_radius
# (§6-Q3 optional depth scaling — default OFF / flat:)
# catch_r += _cfg.r1_catch_radius_per_depth * float(depth)
if _catch_cooldown <= 0.0 \
        and global_position.distance_to(_player.global_position) <= catch_r:
    _on_catch(depth)
```

```gdscript
const STALL_FRACTION := 0.35   # < this fraction of intended speed while touching a wall = grinding
```

### 3.3 Part 2 option (c) — ghost-toward-player (ONLY if Director picks §6-Q2(c))

One-line collision change in the `.tscn` (drop the `world` mask) — no script change needed; the existing `move_and_slide()` then passes through walls and the distance catch test is unaffected. Do **not** implement both (a) and (c); they are mutually exclusive Director choices.

```
# scenes/hazards/hazard_entity.tscn  — IF AND ONLY IF §6-Q2 resolves to (c)
[node name="HazardEntity" type="CharacterBody2D" groups=["hazard"]]
collision_layer = 16   # hazard (unchanged)
collision_mask = 0     # was 2 (world) — now ignores walls, lerps straight at player
```

### 3.4 No changes to `_on_catch` / routing

`_on_catch(depth)` is **unchanged** from M1.1 — it emits `hazard_caught(depth, run_t_ms)` and calls `GameState.fail_run(&"death")` on a fatal catch. I2 does not touch the routing; it only makes the test that *calls* `_on_catch` able to fire.

### 3.5 Spawn seam (`main_game.gd`) — likely UNCHANGED

`_spawn_r1_hazards` and `_hazard_spawn_position` (read above) already spawn at the threshold-depth piece and into `_band_container`. **I2 changes no spawn logic** unless §6-Q5 (threshold re-tune coordinated with I1) requires a clamp adjustment for I1's new depth range — and even then the existing `clampi(depth_threshold, 0, max_depth)` already handles an over-range threshold gracefully. The spawn seam is the **shared-file watch point with I4**; if I4 also edits `main_game.gd`, sequence the merges (§0).

---

## 4. Telemetry & acceptance

### 4.1 Telemetry (unchanged signals — the *fix* is that `hazard_caught` now fires)

I2 emits the **same two R1 signals** (`hazard_awoke(depth, trigger)`, `hazard_caught(depth, run_t_ms)`) — no new rows, no `event_bus.gd` edit. The whole success criterion is that **`hazard_caught` rows now appear** where M1.1 logged zero. Fatal catches still ride the existing `run_ended(reason=&"death", …)` arity via `fail_run`.

### 4.2 Acceptance criteria (from `M1.2_Breakdown.md` §4 I2 + §7.2)

1. **With R1 on, the hazard visibly closes and *catches* → `death` at a fair rate** on the I1-scaled (and the baseline 32 px) levels — `hazard_caught > 0` and routes through `fail_run(&"death")` (pockets fraction applies; `run_ended.reason == "death"`). The catch fires from corridors, not only open rooms.
2. **With R1 off (`r1_enabled = false`), behaviour matches M1.0/M1.1 baseline exactly** — no hazard node, no telemetry rows.
3. **All knobs still take effect** from CFG — the shrunk body + raised catch radius + re-tuned threshold defaults are *defaults*, not hardcodes; the Director can still sweep `r1_catch_radius`, `r1_depth_threshold`, `r1_chase_speed`, `r1_speed_per_depth`, etc.
4. **`hazard_caught` rows appear** as config-marked TEL rows in an R1-on playtest; the body fits the narrowest default corridor (no wall-stick stall on the baseline 32 px hall).
5. **Process:** shared I2 worklog naming the programmer + character-animator commit SHA(s); `godot --headless --import` compiles the changed scene/script; the smoke test is green; all-off still reproduces baseline.

> **Fairness is a Director judgment, not a metric.** "Fair rate" in (1) is the Director's playtest call (the M1.2 re-gate, RG2/RG3). I2's job is to make the catch *mechanically possible and tunable*; whether the tuned value *feels* fair is the gate question. The spec recommends defaults (§5) and flags every feel knob (§6).

---

## 5. Config-default deltas (recommendation — Director sweeps from here)

I2 keeps R1's all-off default (the permanent control) and revises the **"interesting" first-sweep set** so the catch can actually fire. These are deltas from R1 §6.2, recoordinated with I1's room scale (numbers assume the M1.1-baseline depth range until I1's defaults are confirmed — §6-Q5):

| Field | R1 (M1.1) suggested | **I2 suggested** | Why it changed |
|---|---|---|---|
| `r1_enabled` | `true` | `true` | unchanged |
| `r1_depth_threshold` | `3` | **`~4` (≈ ⅓ of I1 max depth)** | wake mid-journey, not at the door; scale to I1's depth range (§2.4, §6-Q5) |
| `r1_linger_seconds` | `20.0` | **`~35.0`** | I1's longer traversal makes 20 s nearly instant; raise the anti-camp trigger |
| `r1_chase_speed` | `~0.85 × 200 = 170` | **`~0.75 × 200 ≈ 150`** | a non-sticking smaller body is effectively faster; lower base so "turn back in time" still escapes (§2.4) |
| `r1_speed_per_depth` | `+4 px/s/depth` | **`+4` (unchanged, sweep hardest)** | the core "deeper = faster" lever; Director tunes |
| **`r1_catch_radius`** | `~24` | **`~32`** | **must exceed player_r(14) + hazard_r(10) = 24** or the test can never trip (§1.2, §2.3) |
| `r1_catch_kills` | `true` | `true` | clean binary for the gate |
| `r1_spawn_count` | `1` | `1` | one clear predator |
| **body radius (.tscn)** | `16` | **`10`** | fit the 32 px corridor with clearance (§2.1) |
| `r1_catch_radius_per_depth` | — | **omit (flat)** | new-field candidate; default flat = no schema change (§6-Q3) |

> Velocity/threshold figures reference the player's real `max_speed = 200` (`data/player/player_movement.tres`) and the M1.1 baseline depth range; they are **ratios/targets, not balanced absolutes** — the Director moves every number during the M1.2 sweep. The body radius is the one **structural** change (it must fit the hall); the rest are tunable.

---

## 6. Open Questions (Phase-3 fresh-eyes pass + Director resolve)

Explicit per the three-phase process. Each is flagged **[feel/fairness — Director]** or **[implementation — programmer picks cheapest]**. The body above commits to a *recommended default* for each so an implementer is never blocked; the Director can override at the M1.2 wave brief.

- **Q1 — Shrink the body, or also widen the minimum corridor in I1?** *[Director — coordinate with I1]*
  Recommendation: **shrink the hazard body (radius 10)** so I2 fits the M1.1-baseline 32 px hall *and* is independent of I1's final scale. Widening the minimum corridor is I1's call; if I1 widens it anyway, the shrunk body just gets more margin. **Do not rely on I1 widening** — that couples I2's success to I1's tuning. *Director confirms the body radius and whether I1 should also raise its minimum corridor width.*

- **Q2 — Anti-wall-stick approach: slide+de-pin (a), axis-greedy (b), or ghost-through-walls (c)?** *[feel/fairness — Director]*
  Recommendation: ship **(a) slide + de-pin nudge** (cheap, preserves wall-refuge), escalate to **(b)** if it still stalls in playtest, and adopt **(c) ghost-toward-player** *only* if the Director prioritises "the catch always lands" over "ducking behind a wall hides you." (c) is the surest catch but **deletes the wall-refuge feel R1 intended** — the biggest fairness/feel tradeoff in I2. *Director picks the approach (and may say "start (a), fall back to (c) if the gate shows the catch still ~0").*

- **Q3 — Catch radius: flat, depth-scaled, or body-overlap?** *[Director — flat default, schema flag]*
  Recommendation: **flat `r1_catch_radius ≈ 32`** (default, no schema change), with the documented floor `radius ≥ player_r + hazard_r`. *Depth-scaled* (`r1_catch_radius_per_depth`) reinforces "deeper = more dangerous" on the catch axis but needs **one new `RunConfig` field** (I1/R0 schema coordination, default `0.0` = flat). *Body-overlap* catch (use the physics contact instead of a distance test) is rejected — it re-introduces the "bodies collide before the test trips" coupling and is less deterministic than R1's script test. *Director decides whether the depth-scaled field is worth the schema add for the M1.2 sweep; default ships flat.*

- **Q4 — Should the hazard ever give up / re-sleep?** *[feel/fairness — Director]*
  R1 ratified **no re-sleep** (R1 §9 Q4 — the wake latches for the run). I2 re-raises it *only because a hazard that now actually catches* makes a "frustrating-forever pursuer" more likely, especially on I1's longer levels. Options: keep no-re-sleep (default, unchanged); add a `r1_resleep_on_retreat` valve (deferred R0 follow-up — *not* built in I2 unless the Director asks); or a soft "lose-aggro if the player breaks line for N seconds." Recommendation: **keep no-re-sleep for the M1.2 gate** (one fewer variable; the gate measures "does catching make it fun," and a give-up valve muddies that). *Director confirms; if the playtest feels unfair-forever, this becomes an M1.3 follow-up.*

- **Q5 — Default threshold / speed against I1's room scale — coordinate with I1?** *[Director — coordinate with I1]*
  I2's threshold (`~4`), linger (`~35 s`), and chase-speed (`~0.75×`) defaults assume the **M1.1-baseline depth range** because I1's resolved defaults weren't final at authoring. **Action:** at the Wave-2 brief, read I1's resolved (a) default room count / max depth and (b) default room/corridor size, then set `r1_depth_threshold ≈ ⅓ max_depth` and confirm the body fits I1's minimum corridor. If I1 ships its all-off default == M1.1 baseline (it must — `M1.2_Breakdown.md` §4 I1), the baseline numbers here hold for the all-off control and only the *interesting* sweep set scales with I1's chosen larger defaults. *Director/I1 confirm the shared scale; I2's defaults are expressed as ratios so they re-derive cleanly.*

- **Q6 — `main_game.gd` seam collision with I4.** *[implementation — orchestrator sequences]*
  `M1.2_Breakdown.md` §6 flags that I2 and I4 may both edit `main_game.gd` (single-writer-per-file lesson). I2's edits are confined to the hazard spawn helpers and are likely **none** (the M1.1 spawn seam already works). *If I4 also touches `main_game.gd`, the orchestrator sequences the two merges or splits the seam; not a design call, but recorded here so the brief catches it.*

---

*Spec authored by game-director-designer for M1.2 I2 (Phase 2). Design-only — no code, no `.tscn`. Fixes R1 (`design/M1_1_Tasks/R1_pursuing_hazard.md`); inherits its §0 contract and §9 ratified decisions except where §2/§5 explicitly re-tune. The programmer + character-animator build against this after Phase-3 resolves §6 (Director). Deviations go to `DESIGN_DEVIATIONS.md` for the Wave-2 close-out sweep.*
