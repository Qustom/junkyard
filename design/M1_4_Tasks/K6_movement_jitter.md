# K6 — Movement-jitter fix (Phase-2 design)

**Milestone:** M1.4 · **Task:** K6 · **Role(s):** general-purpose + character-animator
**Authored:** 2026-06-21 (Phase 2 per-task design, four-phase process — `CLAUDE.md`).
**Blocked by:** none (investigation/fix can start immediately).
**Co-owns the camera / `project.godot` display+physics seam with K3** (resolution-independent camera). See §4 (K3 coordination) — single writer on `project.godot` + the camera node this wave; **design together**.

> **Director work-order:** *"There is some slight jitter on the character while moving, investigate why."*

---

## (a) Research

### What moves, and on which clock

`entities/player/player.gd` is a `CharacterBody2D` that integrates **only in `_physics_process(delta)`** (`player.gd:42-54`):

```
func _physics_process(delta: float) -> void:
    var input_dir := Input.get_vector("move_left","move_right","move_up","move_down")
    velocity = step_velocity(velocity, input_dir, delta)   # move_toward accel/friction
    if input_dir != Vector2.ZERO: facing = input_dir.normalized()
    move_and_slide()
    _update_facing_visual()
```

`step_velocity` (`player.gd:62-68`) is a clean `Vector2.move_toward` accel-to-`max_speed` / friction-to-zero. Tuning (`data/player/player_movement.tres`): `max_speed = 200.0`, `acceleration = 2000.0`, `friction = 2000.0`. So from a standstill the body reaches full speed in `200/2000 = 0.1 s` (~6 physics ticks) — accel is effectively instant and **not** a jitter source (see candidate 4 below). The player's transform therefore updates **once per physics tick** and at no other time.

### The clock: physics ticks vs display refresh — and interpolation is OFF

`project.godot` has **no `[physics]` section at all** (the file ends at `[rendering]`, lines 109-113; the sections present are `application`, `autoload`, `debug`, `global_group`, `input`, `internationalization`, `layer_names`, `rendering`). Therefore the engine defaults apply:

- `physics/common/physics_ticks_per_second` = **60** (unset → default).
- **`physics/common/physics_interpolation` = `false`** (unset → default; Godot 4.x ships 2D+3D physics interpolation **disabled by default**).

**Godot 4.6 fact (physics interpolation).** When physics interpolation is OFF, a node moved in `_physics_process` has its on-screen transform snapped to the *latest* physics state on **every drawn frame**, with no smoothing between ticks. On a display refreshing faster than 60 Hz (120/144/165 Hz monitors — and browsers via itch, which render at the display's vsync), multiple frames draw the body at the **same** physics position, then it jumps a whole tick's worth at once. The eye reads this uneven advance as **stutter/jitter even at constant velocity**. With interpolation ON, the renderer interpolates each node's transform between the previous and current physics states using the inter-frame fraction (`Engine.get_physics_interpolation_fraction()`), so motion is smooth at any refresh rate. This is *the* canonical "my character jitters when moving" cause in Godot 4. It also affects the camera (see candidate 2) and every world body identically.

> Note: even on a plain 60 Hz display, physics-tick timing and vsync are not phase-locked, so frames occasionally land on either side of a tick boundary → beat-frequency micro-stutter. Interpolation removes that too.

### The camera: child of the physics body, smoothing ON

`scenes/game/main_game.tscn:17-22`:

```
[node name="Player" parent="." instance=ExtResource("2")]

[node name="Camera2D" type="Camera2D" parent="Player"]
zoom = Vector2(2, 2)
position_smoothing_enabled = true
position_smoothing_speed = 8.0
```

Key facts about this setup:

1. **The camera is a child of `Player`** (a `CharacterBody2D`). So the camera's *world* transform = player transform ∘ local offset. The player only moves on the physics tick, so the camera's follow target also only moves on the physics tick.
2. **`position_smoothing_enabled = true`, speed `8.0`.** `Camera2D` position smoothing steps **in the physics process when the parent moves there** (Godot ties Camera2D smoothing/update to the same process callback as what drives it). The smoothing is an exponential lerp toward the target each step.
3. `make_current()` + `reset_smoothing()` are called once on band entry (`main_game.gd:248-250`, camera resolved at `main_game.gd:51` as `$Player/Camera2D`) — that just snaps the smoothing to target on spawn; it does not change steady-state behaviour.
4. **`zoom = Vector2(2,2)`** magnifies everything 2×, so any sub-pixel positional error or one-frame lag is **doubled** on screen — jitter that would be ~invisible at 1× becomes visible.

There are **two** jitter mechanisms hiding here:

- **(2a) Un-interpolated camera (same as candidate 1).** With physics interpolation OFF, the camera node — like the player — is drawn snapped-to-tick on every frame. On a >60 Hz display the *whole view* (player + world) advances in uneven 60 Hz steps. The player happens to be near screen-centre, so its apparent jitter is really the camera/world jitter.
- **(2b) Smoothing-vs-follow phase mismatch.** Because the camera **smooths** (lerp at speed 8) toward a target that **steps** discretely, the player is *not* pinned to a fixed screen pixel while moving — the camera trails and catches up. With the camera child-of-body, the smoothing target moves with the body in the same tick, so the relative offset between player-on-screen and camera-centre wobbles slightly frame to frame, again magnified by `zoom=2`. Smoothing is desirable for feel but, layered on un-interpolated stepping, it compounds the visible unevenness.

### Pixel snapping: OFF

`project.godot [rendering]` (lines 109-113) contains only `textures/canvas_textures/default_texture_filter=0` and `renderer/rendering_method="gl_compatibility"`. There is **no** `rendering/2d/snap/snap_2d_transforms_to_pixel` and **no** `rendering/2d/snap/snap_2d_vertices_to_pixel` → both default **false** (no pixel snapping). There is also **no `[display]` section** (relevant to K3 — window size, stretch mode, content-scale are all defaults today).

**Godot 4.6 fact (2D snap).** `snap_2d_transforms_to_pixel` rounds each canvas item's final transform to the nearest pixel at draw time. With it OFF (today), bodies render at exact sub-pixel float positions — so snapping is **not** introducing a quantisation wobble today. *Turning it ON naively could itself cause jitter*: a body at sub-pixel velocity under a `zoom=2` camera would visibly snap between integer pixels (1 device-pixel = 0.5 world-units at 2× → the snap step is half-magnified and visible). So pixel snap is a **non-cause today** and a **potential new bug** if added carelessly. Conventions note: texture filtering is OFF (`default_texture_filter=0`), pixel-art project — consistent with not wanting filtered sub-pixel blur, but that's orthogonal to transform snapping.

### Candidate-cause ledger

| # | Candidate | Evidence FOR | Evidence AGAINST | Verdict |
|---|---|---|---|---|
| 1 | **Physics interpolation OFF** (60 Hz body drawn un-interpolated at higher refresh) | No `[physics]` section → `physics_interpolation=false` by default; body moves *only* in `_physics_process`; `zoom=2` magnifies the per-frame step; matches the classic Godot-4 symptom; affects player + world + camera uniformly | Would be less visible on an exact-60 Hz display fully vsync-locked (but beat-frequency micro-stutter persists, and itch/browser + high-refresh monitors are the common case) | **MOST LIKELY ROOT CAUSE** |
| 2 | **Camera child-of-body + smoothing** | Camera child of physics body; `position_smoothing_enabled=true` @8.0; smoothing lerps toward a discretely-stepping target; `zoom=2` magnifies; smoothing on top of un-interpolated stepping compounds | Smoothing alone (with interpolation ON) is normally smooth; reset_smoothing only affects spawn | **CONTRIBUTING / SECONDARY** — fix must be co-designed with #1; reparent or interpolate the camera |
| 3 | **2D pixel snapping × zoom=2 × sub-pixel pos** | `zoom=2` would magnify any snap step; pixel-art project | Snap settings are **absent → OFF**; cannot be the current cause | **NOT the current cause** (but a *trap* — do not "fix" by enabling snap blindly) |
| 4 | **accel/friction `move_toward` micro-oscillation near target** | — | `move_toward` is monotonic, never overshoots a scalar target → cannot oscillate; accel=2000 reaches max_speed in 0.1 s; at cruise `input_dir*max_speed` is a fixed target, velocity sits exactly on it | **RULED OUT** |

**Conclusion:** the jitter is a **physics-interpolation problem** (candidate 1), amplified by the **camera being an un-interpolated, smoothing child of the physics body** (candidate 2) and by **`zoom=2`** doubling every sub-frame error. Candidates 3 and 4 are not causes today.

---

## (b) Proposed fix (settings-diff + pseudocode)

### Primary fix — enable 2D physics interpolation (project-wide)

Add a `[physics]` section to `project.godot`. **This is a one-line engine setting, not a code change**, and it is the root-cause fix:

```diff
+[physics]
+
+common/physics_interpolation=true
+common/physics_ticks_per_second=60
```

(`physics_ticks_per_second=60` is written explicitly only to make the rate intentional/visible; 60 is already the default. The load-bearing line is `physics_interpolation=true`.)

With interpolation ON, every node moved in `_physics_process` — player **and** the child camera — is rendered interpolated between physics states each drawn frame. No per-node code changes are required for correctness; `move_and_slide()` in `_physics_process` is exactly the supported pattern.

**Determinism / baseline safety.** Physics interpolation changes only how transforms are **rendered between ticks** — it does **not** change the physics simulation, `move_and_slide()` results, or any value that feeds `RNG`/`fingerprint(seed+config)`. The all-off `RunConfig` control's fingerprint (`e943ac9c8bc1`) is **unaffected** (interpolation is a render-time concern, not a sim input). This is a global render setting, *not* a `RunConfig` knob (it's a correctness fix, not a swept lever) — consistent with the M1.4 guardrail that knobs are for sweeps, not for engine-correctness fixes.

**Headless note.** The smoke test (`tools/ci_smoke_test.gd`) and GdUnit4 tests run `--headless` (no rendering) → interpolation is inert there; no test should change behaviour. Verify the smoke test stays green.

### Secondary fix — make the camera interpolation-clean (co-design with K3)

Once interpolation is ON, decide the camera's relationship to the body. Two viable shapes (pick in Phase 3 / with K3):

**Option A — keep camera as child of Player, rely on interpolation (smallest change).**
The child camera is interpolated along with the parent; keep `position_smoothing_enabled` for *follow feel* but it is now smoothing an interpolated transform. Lowest risk; verify the smoothing speed still feels right at 2× and doesn't reintroduce trailing wobble. If smoothing looks redundant/laggy once interpolation is smooth, **consider disabling `position_smoothing` entirely** (the player will be pinned to screen-centre, perfectly steady) — a tone/feel call for the Director.

**Option B — reparent the camera off the body (cleaner separation, K3-aligned).**
Move `Camera2D` from `Player` to a level-owned node (or a dedicated follow rig) that *follows* the player. This matches the player.gd doc-comment's own stated intent — *"The camera is level-owned … so this entity stays reusable"* (`player.gd:13-14`) — which the current `.tscn` violates by parenting the camera under Player. A level-owned camera with its own follow logic (lerp in `_physics_process`, or `Camera2D` smoothing) is interpolation-clean and is the natural host for **K3's resolution-independent / fixed-world-units viewport** work. Costs: must re-home `_camera` resolution in `main_game.gd` (currently `$Player/Camera2D`, `main_game.gd:51`) and the `make_current()`/`reset_smoothing()` calls (`main_game.gd:248-250`).

```gdscript
# Option B sketch — level-owned follow camera (interpolation-clean)
# main_game.gd: _camera now a sibling rig, not $Player/Camera2D
@onready var _camera: Camera2D = $CameraRig/Camera2D   # was $Player/Camera2D

func _physics_process(_delta: float) -> void:
    if _player != null and _camera != null:
        # discrete step on the physics tick; physics interpolation smooths the render
        _camera.global_position = _player.global_position
        # (or keep Camera2D position_smoothing for trail feel)
```

### What NOT to do

- **Do not** enable `snap_2d_transforms_to_pixel` to "fix" jitter — with `zoom=2` and sub-pixel velocities it would *introduce* a half-pixel snap wobble (candidate 3). Leave snap OFF unless K3/art explicitly wants pixel-perfect rendering, and only then with interpolation already on and the snap step understood.
- **Do not** move player movement out of `_physics_process` into `_process` — that breaks `move_and_slide()` collision correctness and determinism. Interpolation is the right tool.

---

## (c) Open Questions

1. **Root cause confirmation — is it really interpolation, and on what hardware?**
   The diagnosis is from settings inspection (interpolation default-off + un-interpolated camera child). It should be *confirmed empirically*: does the jitter reproduce on a high-refresh / browser (itch) display and vanish with `physics_interpolation=true`? **Trade-off:** confirming needs a human running the build on a >60 Hz monitor (or the itch web build), since headless can't render. **Recommendation:** land the interpolation flag and have the Director eyeball it during the RG1 build — it's low-risk and the canonical fix, so confirm-by-fixing is acceptable. *(Needs a human eyeball; not headless-verifiable.)*

2. **Interpolation-only vs. interpolation + camera-reparent (Option A vs B).**
   - *Option A (keep child camera):* minimal diff, lowest risk, but leaves the camera parented under a reusable entity (violates `player.gd:13-14`'s stated design) and keeps K3's viewport work tangled with the player scene.
   - *Option B (reparent to level-owned rig):* cleaner, matches the documented intent, gives K3 a clean host for the fixed-world-units viewport — but is a larger change touching `main_game.tscn` + `main_game.gd:51,248-250`.
   **Recommendation:** do **Option B as part of the shared K3+K6 seam** (one writer on `project.godot` + camera node this wave) so the camera ends up both interpolation-clean *and* resolution-independent in a single coherent change, rather than touching the camera twice. If K3 slips, fall back to **A** (interpolation flag alone) as the standalone jitter fix — it resolves the reported symptom on its own.

3. **Keep or drop `position_smoothing` once interpolation is on?**
   With interpolation smoothing the render, the follow smoothing (`speed 8.0`) is now a pure *feel* choice (trail vs pinned-to-centre). Pinned (smoothing off) is rock-steady; smoothed trails slightly. **Trade-off:** feel vs steadiness — this is a **tone/feel call = Director's** (orchestrator loop step 7). **Recommendation:** ship interpolation + keep current smoothing as-is for RG1, flag for the Director to judge in playtest; only disable smoothing if it still reads as wobble.

4. **K3 coordination — the shared seam (load-bearing).**
   K3 (resolution-independent camera) and K6 both write `project.godot` and the camera node. The breakdown names them co-owners (§4, §5 Wave 1: *"K3 + K6 co-own the camera / `project.godot` display+physics seam — one writer, designed together"*). K3 likely adds a `[display]` section (`window/stretch/mode`, base resolution, content-scale) and may reshape the camera into a fixed-world-units rig; K6 adds `[physics] physics_interpolation=true`. **These must land as ONE single-writer change** to avoid a merge that drops one section, and the camera reparent (Option B) is the same node both touch. **Recommendation:** brief K3 + K6 to one agent/worktree (or strict single-writer-on-`project.godot`-and-camera ordering), with the agreed contract: `[physics] physics_interpolation=true` (K6) + K3's `[display]`/content-scale + a level-owned interpolation-clean follow camera (shared). Pixel-snap stays OFF unless K3's content-scale design explicitly opts into pixel-perfect (then revisit candidate 3 jointly). **This question is the gate — resolve the K3 camera approach before finalizing whether K6 ships Option A or B.**

5. **Should `physics_ticks_per_second` be raised (e.g. to 120) instead of/in addition to interpolation?**
   Raising the tick rate narrows the un-interpolated step but doesn't eliminate it and costs CPU (and could subtly affect any tick-count-sensitive logic). **Recommendation:** **no** — keep 60 Hz and fix it properly with interpolation. Documented here only to pre-empt it as a tempting non-fix.

---

## Resolved Decisions (Phase 3)

*Fresh-eyes resolution, 2026-06-21. Resolved jointly with K3 (`K3_resolution_independent_camera.md`) — the two tasks co-own the single `project.godot` + camera-node seam and land as ONE coherent Wave-1 change. Verified against the real `project.godot` (no `[display]`, no `[physics]`; `[rendering]` has only `default_texture_filter=0` + `gl_compatibility`), `scenes/game/main_game.tscn:17-22` (Camera2D child of Player, zoom=(2,2), smoothing on @8.0), `scenes/game/main_game.gd:51,248-250`, and `entities/player/player.gd` (CharacterBody2D, integrates only in `_physics_process`; doc-comment lines 13-14 already assert the camera "is level-owned … so this entity stays reusable" — the `.tscn` currently violates this).*

### RD-1 — Root cause CONFIRMED (by inspection): physics interpolation OFF, amplified by the camera being a smoothing child of the physics body at zoom 2.

The author's diagnosis holds on the evidence. There is no `[physics]` section, so `physics/common/physics_interpolation` defaults to **false** in Godot 4.x; the player integrates only in `_physics_process` (`player.gd:42-54`); the camera is a child of that body with `zoom=(2,2)` doubling every sub-tick error; `move_toward` cannot oscillate (candidate 4 ruled out); snap settings are absent so candidate 3 is a non-cause today. **The root-cause fix is `physics_interpolation=true`**, not pixel-snap, not a higher tick rate, not moving movement into `_process`. Decisive: the candidate ledger's verdicts are correct. The empirical confirmation (does it reproduce on >60 Hz / browser and vanish with the flag) is a render-time eyeball that **NEEDS DIRECTOR REVIEW** — see RD-5 — but it does not gate landing the flag; it is the canonical confirm-by-fixing case.

### RD-2 — The fix: enable interpolation AND reparent the camera to a level-owned follow rig (the author's Option B). NOT Option A.

Resolved in favour of **interpolation flag + Option B (reparent)**, executed as the shared K3+K6 change:

1. **`[physics] common/physics_interpolation=true`** (+ explicit `common/physics_ticks_per_second=60` for intent). This alone resolves the reported symptom — it is the root-cause fix and is mandatory.
2. **Reparent `Camera2D` off the `Player` body onto a level-owned rig** in `main_game.tscn`. This is chosen over Option A (keep child camera) for three converging reasons, all decisive on technical merit:
   - It is what `player.gd:13-14` *already documents as the intended design* ("The camera is level-owned … so this entity stays reusable"); the current `.tscn` is the bug-against-doc. Option B makes code and doc agree — Option A perpetuates the violation.
   - It gives **K3 a clean host** for the resolution-independent viewport. K3 retypes this same camera node to `CameraView`. Doing the reparent and the K3 retype in one change means the camera node is touched **once**, not twice across two milestonish edits.
   - It removes candidate 2b (smoothing-vs-follow phase wobble) at the structural level: a level-owned rig that follows on the physics tick, rendered through interpolation, has no body-child transform composition to compound.

   **Fallback rule (carried from the author):** if K3 were to slip out of this wave, K6 ships the **interpolation flag alone** (Option A semantics) as the standalone, sufficient jitter fix. But K3 and K6 are paired in Wave 1, so the planned-of-record outcome is **flag + reparent**.

**Camera follow shape after reparent.** The rig follows the player by copying `global_position` on the physics tick (interpolation smooths the render). Whether the camera *additionally* runs `position_smoothing` for trail-feel is a feel call — see RD-4. K3's `CameraView.apply_from_config()` runs after `make_current()`+`reset_smoothing()` at the existing seam (`main_game.gd:248-250`), now resolving `_camera` from the rig path rather than `$Player/Camera2D` (`main_game.gd:51`).

### RD-3 — Pixel-snap stays OFF. Confirmed, not a band-aid.

`snap_2d_transforms_to_pixel`/`snap_2d_vertices_to_pixel` are absent (default false) and **stay absent**. Enabling snap is a trap: at `zoom=2`, a sub-pixel-velocity body would snap between integer pixels with a half-magnified, visible step — it would *introduce* a wobble, not fix one. Interpolation is the correct tool; snap remains OFF for M1.4. (K3's `scale_mode="integer"` is a *whole-canvas* scale concern, orthogonal to per-body transform snap — the two do not interact.)

### RD-4 — Keep `position_smoothing` on the rig as-authored for RG1. **NEEDS DIRECTOR REVIEW** (feel call).

Once interpolation is on, the follow smoothing (`speed 8.0`) is a pure feel choice — trail (smoothing on) vs pinned-to-centre rock-steady (smoothing off). This is a tone/feel call and is the Director's. **Recommendation:** ship interpolation + reparent with **smoothing kept on at 8.0** for RG1 so the framing K3 sits inside is unchanged from M1.3, and have the Director judge in the itch playtest whether to drop it to pinned. Do NOT silently disable smoothing — K3's framing assumes the as-authored feel unless the Director rules otherwise. Flagged.

### RD-5 — Empirical hardware confirmation. **NEEDS DIRECTOR REVIEW** (not headless-verifiable).

Headless CI/GdUnit4 (`--headless`) does not render, so interpolation is inert there and no automated test can confirm the jitter is gone — the smoke test only needs to stay green (it will: interpolation is a render-time concern, no sim change). The real confirmation is a human eyeballing the RG1 build on a >60 Hz monitor and/or the itch web build (browsers vsync to the display). **Recommendation:** land the flag + reparent; Director confirms jitter is gone during the standing RG1 itch playtest. Low risk — confirm-by-fixing is acceptable for the canonical Godot-4 jitter fix.

### RD-6 — Determinism fingerprint `e943ac9c8bc1` is UNAFFECTED (confirmed).

Both K6 changes are **render-time only**. `physics_interpolation` changes how transforms are *drawn between ticks*; it does not alter `move_and_slide()` results, the physics sim, RNG draws, or any input to `fingerprint(seed+config)`. Reparenting the camera moves a *presentation* node and does not feed generation. The all-off `RunConfig` control therefore produces the byte-identical band → fingerprint stays `e943ac9c8bc1`. Neither change is a `RunConfig` knob (both are engine-correctness/structure fixes, not swept levers) — consistent with the M1.4 guardrail. The smoke test stays green.

### RD-7 — The SINGLE combined change (shared with K3) — who writes what, in what order.

See K3's RD-7 for the canonical single-writer description. In summary, one agent on one Wave-1 worktree lands **one `project.godot` diff** (K3's `[display]` block + K6's `[physics]` block) and **one camera-node change** (reparent off Player to a level-owned rig + retype to `CameraView`), in this order: (1) add `[physics] physics_interpolation=true` and verify jitter-fix intent; (2) add the `[display]` block (K3); (3) reparent + retype the camera + re-home `_camera` in `main_game.gd:51,248-250`; (4) K3's `CameraView` script + `apply_from_config` wiring. One shared worklog (K3+K6) names the commit SHA(s). This honours Wave-1's single-writer-per-file rule for both `project.godot` and `main_game.tscn`.
