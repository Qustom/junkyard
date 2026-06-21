# K3 (M1.4) — Resolution-independent camera (fixed visible world-units)

**Task:** K3 — Resolution-independent camera.
**Phase:** 2 (per-task design). Authored 2026-06-21 from `M1.4_Breakdown.md` §3/§7 + the Director work-order.
**Role(s):** general-purpose (camera script + `project.godot`) + ui-ux (only if a settings toggle surfaces; greybox HUD untouched).
**BlockedBy:** K0 (pre-declares the `cam_*` knobs + the `camera_view_set` signal). **Co-owns** the camera / `project.godot`
display seam with **K6** (movement-jitter fix) — single writer on `project.godot`, designed together (Breakdown §4, §5).

> **Director work-order (verbatim intent):** "Fix the screen viewport view such that what the camera shows, despite the
> screen resolution, is consistent. This will allow knowing how much knowing what's coming changes the game — if you can't
> see too far out because your screen size is too small, then enemies pop out at you too quickly. Make this configurable."

**Design intent (one line):** the visible world region is a *fixed number of world units* regardless of window/screen
resolution, exposed as a swept `RunConfig` knob, with the **all-off default reproducing today's M1.3 look byte-for-byte**.

---

## (a) Research

### The bug, precisely

- **The camera.** `scenes/game/main_game.tscn:19-22` — `Camera2D` is a **child of `Player`** with `zoom = Vector2(2, 2)`,
  `position_smoothing_enabled = true`, `position_smoothing_speed = 8.0`. `scenes/game/main_game.gd:51`
  `@onready var _camera: Camera2D = $Player/Camera2D`; `start_new_run()` (`main_game.gd:248-250`) calls
  `_camera.make_current()` + `_camera.reset_smoothing()` once per run. The camera has **no script** today — it is pure
  scene data.
- **No `[display]` section.** `project.godot` has `[application]`, `[autoload]`, `[debug]`, `[input]`,
  `[layer_names]`, `[rendering]` — and **no `[display]` block at all** (read the whole file: lines 1-113). So:
  - `display/window/size/viewport_width` / `viewport_height` fall back to the engine defaults (**1152×648** in Godot 4.x).
  - `display/window/stretch/mode` falls back to **`disabled`**, and `display/window/stretch/aspect` to `keep` —
    *its* default. With stretch **disabled**, the viewport size *tracks the OS window size* 1:1, so the world-units the
    camera renders are `window_px / zoom`. **A bigger window literally shows more world. THIS is the bug.**
- **What "more world" means here.** A `Camera2D` with `zoom = (2, 2)` shows `viewport_size / 2` world units. At 1152×648
  that is **576×324 world-px** of visible region; maximise to 1920×1080 and it becomes **960×540** — a 67 %-wider field of
  view, purely from the window. That is exactly the Director's "if your screen is too small you can't see far enough out,
  so enemies pop in too fast" — the sight-line is an *uncontrolled* variable today, varying per tester's monitor.

### Pixel-art constraint (load-bearing, must not regress)

`CLAUDE.md` → Conventions: **pixel art only, texture filtering OFF.** `project.godot:111`
`textures/canvas_textures/default_texture_filter=0` (= `Nearest`), `:112` `renderer/rendering_method="gl_compatibility"`.
Any fix that introduces **fractional/blurry scaling of the framebuffer** (e.g. linear-filtered stretch, or a non-integer
content-scale that resamples) violates the pixel-art rule. The greybox is `ColorRect`/`Polygon2D` (player `Visual` is a
`ColorRect`, `player.tscn:16-21`; nose is a `Polygon2D`), so there are no texture seams *yet*, but the rule is a standing
contract M1.4 must respect because real pixel-art tiles land in M2. The fix must keep pixels crisp.

### Godot 4.6 stretch + zoom facts (the two mechanisms, grounded)

**Mechanism A — project-level content-scale stretch (`canvas_items`).** `display/window/stretch/mode = "canvas_items"`
makes the engine render to a **fixed base resolution** (`viewport_width`×`viewport_height`) and then scale that canvas to
fill the OS window. `display/window/stretch/aspect` controls letterboxing (`keep` = bars to hold the base aspect;
`expand` = grow the smaller axis so more is shown on wide/tall windows; `keep_width`/`keep_height` = lock one axis).
`display/window/stretch/scale_mode` (Godot 4.2+) is **`fractional`** (default, smooth scale — *blurs pixel art at
non-integer factors*) or **`integer`** (snaps the whole-canvas scale to the largest integer that fits, letterboxing the
remainder — the **pixel-perfect** choice; this is the modern replacement for the old `viewport`/`2d` stretch modes for
crisp scaling). Under `canvas_items` + a fixed base, **`get_viewport().get_visible_rect().size` returns the BASE size**,
not the window size — so the world-units the camera shows become **independent of the OS window** automatically, *with no
camera script at all*. The camera `zoom = (2,2)` would then show `base_size / 2` world units, constant forever.

**Mechanism B — dynamic camera zoom-to-fit (script on the `Camera2D`).** Leave stretch `disabled` (or `canvas_items` with
`expand`) and **drive `Camera2D.zoom` from the live viewport size** so a *chosen* world-width always exactly fills the
viewport:
```
zoom = viewport_size.x / target_world_width    # uniform Vector2(z, z) for fit_width
```
Godot's `Camera2D.zoom` is "larger = more zoomed-IN = fewer world units visible" (it scales the canvas transform).
Visible world width = `viewport_size.x / zoom.x`. So to hold `target_world_width` constant we set
`zoom.x = viewport_size.x / target_world_width`. Recompute on `get_viewport().size_changed` (the `Viewport.size_changed`
signal fires whenever the window/viewport resizes). This needs a **script on the camera** (there is none today) and a hook
to the resize signal, but it touches **no `project.godot` settings**, so it does not collide with K6's physics seam.

**The shared seam with K6 (jitter).** K6 owns the movement-jitter root-cause fix. The leading jitter candidates ALL live in
the same two surfaces K3 touches:
1. **`Camera2D.position_smoothing`** (`main_game.tscn:21-22`, smoothing ON at speed 8) on a camera **parented to a
   physics body** — the camera lerps toward the player every *frame* while the player only moves on the *physics tick*, a
   classic top-down follow jitter. K3 must not silently change smoothing without K6's sign-off (and vice-versa).
2. **`display/window/stretch/*` + (a future) `physics/common/physics_interpolation`** — both `project.godot` keys. There
   is **no `[physics]` section** today either (grep confirms no `physics_interpolation` anywhere in the repo), so if K6's
   root cause is physics-tick/frame mismatch, K6 may add `physics/common/physics_interpolation=true` — which **interacts
   with both stretch mode and `Camera2D` smoothing/limits**. K3 + K6 **must land one coordinated `project.godot` diff and
   agree on the camera node's final config** (single writer, Breakdown §4/§5).

### What K0 already pre-declared (the contract K3 fills)

`design/M1_4_Tasks/K0_foundation_knobs_signals.md:161-176` pre-declared the provisional knob set on `run_config.gd`
(off-default), and K0's OQ-4 (`:405-411`) explicitly flagged that **K3's Phase-2 design may reduce this set** if the chosen
approach is project-level stretch (in which case the base resolution is a *project setting*, not a per-run knob):
```gdscript
@export_group("K3 Camera", "cam_")
@export var cam_enabled: bool = false                 # OFF = today's camera (window-dependent)
@export var cam_visible_world_width: float = 0.0      # px the viewport always shows; 0 = today's behaviour
@export_enum("fit_width", "fit_height", "contain") var cam_zoom_policy: int = 0
```
K0 also pre-declared (`event_bus.gd`, K0 `:322-324`) the approach-agnostic telemetry signal:
```gdscript
signal camera_view_set(visible_world_width: float, zoom: float)   # "how far could I see" this run
```
`cam_*` joins `RunConfig.to_flat_dict()` (K0 `:264-267`) and the CFG/telemetry knob-count assertions
(`tests/test_run_config.gd`, `tests/test_config_menu.gd`, `tests/test_telemetry_config_marking.gd`). **Determinism:** the
camera is *pure presentation*, post-generation — it **never** feeds `fingerprint(seed+config)`, so any `cam_*` value
(including a non-neutral sweep) leaves the all-off fingerprint `e943ac9c8bc1` untouched. This is the easy determinism case
(unlike K7 exits): nothing to route through a sub-stream, nothing to keep byte-identical beyond "default reproduces today."

---

## Recommendation (lead with it, both approaches costed below)

**Recommended: a HYBRID that is mostly Mechanism B (dynamic camera zoom) on top of a small, pixel-safe project-stretch
base — with the *default* being today's exact look.**

Concretely:
1. **`project.godot`:** add a `[display]` section with `stretch/mode = "canvas_items"`, `stretch/aspect = "expand"`,
   `stretch/scale_mode = "integer"`, and an explicit base `viewport_width=1152` / `viewport_height=648` (today's implicit
   default, made explicit). `aspect = expand` means **no black bars** (the world fills the window; wide windows show a
   wider band, tall ones taller) and `scale_mode = integer` keeps **pixels crisp** (whole-number canvas scale, the
   modern pixel-perfect setting). *This block is the K3+K6 shared diff — K6 co-authors it.*
2. **A `camera_view.gd` script on the `Camera2D`** that, **only when `cam_enabled`**, sets `zoom` from the live
   `get_viewport().get_visible_rect().size` to hold `cam_visible_world_width` constant (per `cam_zoom_policy`), and
   re-applies on `size_changed`. **When `cam_enabled` is false it does nothing** — the scene-authored `zoom = (2,2)` and
   the project base reproduce today's framing exactly (the all-off control).
3. The dynamic-zoom layer is what makes "visible world width" a true *controlled, swept* number; the project-stretch base
   is what makes it **resolution-independent and pixel-crisp** even before the camera knob is on (it caps the window's
   influence to the integer-scaled base, killing the per-monitor variance the Director called out). They compose.

Why not pure A or pure B (see Open Questions for the full trade-off):
- **Pure A** (just set a base + `canvas_items` + integer scale, no camera script) already fixes resolution-independence
  *for free* and is the least code — but it makes "visible world units" a **project constant**, not a per-run swept knob,
  which is exactly what the Director asked to *make configurable* and what RG2 needs to segment "how far can I see" cohorts
  on. It also can't change FOV mid-experiment without an editor restart.
- **Pure B** (camera script, stretch left `disabled`) makes the knob fully configurable but does **nothing about pixel
  crispness** at odd window sizes and leaves the framebuffer at native window resolution (fine for greybox `ColorRect`s,
  risky for M2 tiles), and the *default-off* path still has the window-dependent FOV bug for anyone who never touches the
  knob. The hybrid's project base fixes the default-off case too.

The hybrid costs one extra `[display]` block (which K6 wants anyway) and ~40 lines of camera script, and it is the only
option where **both** the default look is preserved **and** the world-width is a live swept knob **and** pixels stay crisp.

---

## (b) Pseudocode (against real APIs)

### 1. `project.godot` — the `[display]` block (K3 + K6 shared single-writer diff)

```ini
[display]

window/size/viewport_width=1152            ; today's implicit default, made explicit (the base canvas)
window/size/viewport_height=648
window/stretch/mode="canvas_items"         ; render to the base, scale the canvas to the window
window/stretch/aspect="expand"             ; no letterbox bars; wide windows reveal a wider band
window/stretch/scale_mode="integer"        ; PIXEL-PERFECT: whole-number canvas scale (filter stays OFF)
```

> `aspect = "expand"` keeps the *minimum* visible region equal to the base on the locked axis and lets the other axis grow
> — so the camera-zoom layer (below) keys off the **base width**, the controlled dimension. If K6's jitter root cause turns
> out to need `physics/common/physics_interpolation=true`, that key lands in **this same diff** (K6 owns the physics line;
> K3 owns the stretch lines; one writer commits both). See OQ-5.

### 2. `entities/dive/camera_view.gd` — the dynamic-zoom layer (new script on the `Camera2D`)

```gdscript
class_name CameraView
extends Camera2D
## K3 (M1.4) — holds a FIXED visible world-width regardless of viewport size, when enabled.
## Pure presentation: reads RunConfig at run start, never touches game-state, never feeds
## fingerprint(). Disabled (cam_enabled=false / width<=0) => leaves the scene-authored zoom
## untouched => today's M1.3 framing exactly (the all-off control).

const BASE_ZOOM := Vector2(2, 2)   # mirrors main_game.tscn:20 — the all-off / disabled look

var _cfg: RunConfig = null

func apply_from_config(cfg: RunConfig) -> void:
    # Called by MainGame.start_new_run() right where _camera.make_current() runs today.
    _cfg = cfg
    if not get_viewport().size_changed.is_connected(_recompute):
        get_viewport().size_changed.connect(_recompute)
    _recompute()

func _recompute() -> void:
    if _cfg == null or not _cfg.cam_enabled or _cfg.cam_visible_world_width <= 0.0:
        zoom = BASE_ZOOM                                  # disabled => today's look
        EventBus.camera_view_set.emit(_visible_world_width(), zoom.x)
        return
    var vp: Vector2 = get_viewport().get_visible_rect().size   # = the stretch BASE size under canvas_items
    var z: float
    match _cfg.cam_zoom_policy:
        0:  z = vp.x / _cfg.cam_visible_world_width            # fit_width  (lock horizontal units)
        1:  z = vp.y / _cfg.cam_visible_world_width            # fit_height (treat width as the height target)
        2:  z = max(vp.x, vp.y) / _cfg.cam_visible_world_width # contain    (guarantee >= width on both axes)
        _:  z = vp.x / _cfg.cam_visible_world_width
    zoom = Vector2(z, z)                                       # UNIFORM => square pixels preserved
    EventBus.camera_view_set.emit(_visible_world_width(), zoom.x)

func _visible_world_width() -> float:
    return get_viewport().get_visible_rect().size.x / zoom.x
```

### 3. `main_game.gd` — wire it at the existing camera seam (no new seam)

```gdscript
# main_game.tscn: re-type $Player/Camera2D's script to camera_view.gd (CameraView extends Camera2D),
# keep zoom=(2,2)/smoothing as-authored so cam_enabled=false is byte-identical to today.
@onready var _camera: CameraView = $Player/Camera2D     # was Camera2D (main_game.gd:51)

# inside start_new_run(), replacing main_game.gd:248-250:
if _camera != null:
    _camera.make_current()
    _camera.reset_smoothing()
    _camera.apply_from_config(run_cfg)                  # run_cfg already resolved at top of start_new_run
```

### 4. `RunConfig` default (K0 already declared the fields — K3 only confirms semantics)

```gdscript
# K0-declared, off-default (verbatim from K0 :167-175):
@export var cam_enabled := false           # OFF => CameraView leaves zoom at BASE_ZOOM => M1.3 look
@export var cam_visible_world_width := 0.0  # 0 => no enforcement (redundant guard with cam_enabled)
@export_enum("fit_width","fit_height","contain") var cam_zoom_policy := 0   # fit_width

# make_default_play_preset() (run_config.gd:428) — the SWEEP value the build boots into.
# Provisional sweep start: lock the visible width to today's 1152/2 = 576 world-px so the
# *preset* reproduces today's horizontal FOV but now CONSTANT across resolutions. Director sweeps it.
c.cam_enabled = true
c.cam_visible_world_width = 576.0          # = base_width(1152) / base_zoom(2); the M1.3 horizontal FOV, pinned
c.cam_zoom_policy = 0                       # fit_width
```

### 5. Tests (additive, mirrors the carried contract)

- `tests/test_run_config.gd` — `cam_enabled`/`cam_visible_world_width`/`cam_zoom_policy` already added to `expected_keys`
  by K0; assert `RunConfig.new()` leaves all three at the off-defaults (control unchanged).
- New `tests/test_camera_view.gd` — headless unit test on `CameraView._recompute()`-equivalent pure math: given a viewport
  size + a `cam_visible_world_width`, assert `visible_world_width == cam_visible_world_width` for `fit_width` at several
  sizes (640×360, 1152×648, 1920×1080) → proves resolution-independence. Assert `cam_enabled=false` yields `zoom == (2,2)`.
- Smoke test (`tools/ci_smoke_test.gd`) stays green; the all-off control's fingerprint stays `e943ac9c8bc1` (camera is
  post-generation, never hashed).

---

## (c) Open Questions

**OQ-1 — Mechanism A (project content-scale stretch) vs Mechanism B (dynamic camera zoom) vs the hybrid.**
- *A (stretch only):* least code, resolution-independence + pixel-crispness "for free," but visible-width is a project
  constant — **not the swept per-run knob the Director asked for**, and RG2 can't segment FOV cohorts.
- *B (camera script only):* fully configurable per-run knob, no `project.godot` change (no K6 collision), but no pixel
  crispness guarantee and the **default-off path keeps the window-dependent FOV bug** for anyone who never enables it.
- *Hybrid (recommended):* both — project base fixes the default + crispness, the camera script makes width a live knob.
  Cost: the extra `[display]` block (shared with K6) + ~40 LOC. **Recommendation: hybrid.** *Needs Director/Phase-3 ratify
  — it's a small scope call (one project block vs none), trade-off is documented; not a vision/fun call.*

**OQ-2 — `scale_mode = "integer"` (pixel-perfect, letterbox remainder) vs `"fractional"` (fills window, blurs pixels).**
Integer honours the filter-OFF pixel-art rule but **leaves thin black bars** when the window isn't an exact integer
multiple of the base (e.g. 1152-base at 1366-wide → ~1.18× → snaps to 1× + bars). Fractional fills perfectly but
**resamples → blurry pixels at non-integer factors**, violating the convention. With `aspect = "expand"`, integer-scale
bars are minimised (the expand axis grows by whole rows/cols of base pixels). **Recommendation: `integer`** (crispness is
the hard constraint; greybox now, real tiles in M2). *Phase-3 can confirm; trade-off is bars-vs-blur, lean crisp.*

**OQ-3 — `aspect = "expand"` vs `"keep"`.** `expand` = no bars, but **ultrawide players literally see more world** — which
*re-introduces a (bounded) resolution-dependence on the unlocked axis*, partly against the Director's goal. `keep` = the
visible region is *identical* on every aspect (true equality) but **adds black bars** on non-base aspects. The camera-zoom
layer (Mechanism B) locks the *width* regardless, so with `expand` only the **vertical** extent varies — acceptable for a
top-down game where horizontal sight-line is the Director's stated concern ("see far enough out"). **Recommendation:
`expand` + `cam_zoom_policy = fit_width`** (lock the axis the Director cares about; let height breathe). *If the Director
wants strict equality on both axes, switch to `keep` + `contain` policy — flagged as a fun/feel call: needs Director
review.*

**OQ-4 — The knob shape: `cam_visible_world_width` (px) vs a zoom-override + enable toggle vs a base-resolution field.**
K0 declared `cam_visible_world_width` (px) + `cam_zoom_policy` + `cam_enabled`. Alternatives: (i) a raw `cam_zoom_override`
float (simpler, but couples the knob to viewport size — not resolution-independent, defeats the purpose); (ii) expose the
**base viewport resolution** as the knob (only meaningful under pure-A stretch). **Recommendation: keep K0's
`cam_visible_world_width` in world-px** — it's the directly meaningful "how far can I see" number RG2 segments on, and it's
approach-agnostic (works for the hybrid). `cam_zoom_policy` stays (resolves the aspect axis). Default `width = 0.0` +
`cam_enabled = false` is the redundant-guarded off control. *Resolved enough to build; Phase-3 confirm the enum values.*

**OQ-5 — K6 coordination on the shared `project.godot` + camera node (HARD dependency).** K3 and K6 **must land one
coordinated change**: (a) K3's `[display]` stretch lines and any K6 `physics/common/physics_interpolation` line go in the
**same single-writer `project.godot` diff**; (b) the `Camera2D` node's `position_smoothing_enabled/_speed`
(`main_game.tscn:21-22`) is **co-owned** — if K6's jitter root cause is "smoothing on a physics-body-child camera," K6 may
turn smoothing off or move it to physics-process, which **changes the feel K3's framing sits inside**, so K3 must not
assume smoothing stays as-authored. **Recommendation: K3 and K6 are designed + implemented on ONE shared worktree/branch
(the Breakdown already pairs them in Wave 1), with K6's root-cause investigation landing FIRST** so K3 builds on the final
camera-node config. *This is a sequencing/ownership call already made in the Breakdown — restated here so the two designs
don't diverge; not a new open question, but the load-bearing coordination point.*

**OQ-6 — Does the camera follow break under `canvas_items` + the player-child camera?** The `Camera2D` stays a child of
the player `CharacterBody2D` (`main_game.tscn:17-22`); under `canvas_items` stretch its transform is composed with the
canvas scale by the engine, so following still works — but `make_current()`/`reset_smoothing()` ordering vs the
`size_changed` reconnect must be verified (the camera might recompute zoom on the first frame before `make_current`).
**Recommendation: call `apply_from_config()` AFTER `make_current()`+`reset_smoothing()`** (as pseudocode §3 shows) and
guard the `size_changed` reconnect with `is_connected()`. *Implementation detail, resolvable in build/verify; no Director
call.*

---

## Definition of done (for the eventual build task)

- A bigger/smaller window shows the **same horizontal world-width** when `cam_enabled` (verified at ≥3 resolutions);
  `cam_enabled=false` reproduces today's M1.3 framing exactly (visual + the unchanged `e943ac9c8bc1` fingerprint).
- Pixels stay crisp (filter OFF respected; `scale_mode=integer`); no blur introduced.
- `EventBus.camera_view_set` fires per run with the applied `(visible_world_width, zoom)` for RG2's "how far could I see."
- The `[display]` block + camera-node config are the **single coordinated K3+K6 diff**; K6's jitter fix verified intact.
- `to_flat_dict()` carries `cam_*`; `tests/test_run_config.gd` + `test_config_menu.gd` + `test_telemetry_config_marking.gd`
  knob counts updated (K0's union); new `test_camera_view.gd` green; smoke test green.
- One shared worklog (K3+K6) names the commit SHA(s); any deviation logged to `design/DESIGN_DEVIATIONS.md`.

---

## Resolved Decisions (Phase 3)

*Fresh-eyes resolution, 2026-06-21. Resolved jointly with K6 (`K6_movement_jitter.md`) — same `project.godot` + camera-node seam, one Wave-1 change. Verified against the real `project.godot` (no `[display]` → stretch defaults to `disabled` + base 1152×648; `[rendering]` = `default_texture_filter=0` (Nearest) + `gl_compatibility`; no `[physics]`), `scenes/game/main_game.tscn:17-22` (Camera2D child of Player, `zoom=(2,2)`, smoothing on @8.0, no script), `scenes/game/main_game.gd:51,248-250`, `entities/player/player.gd:13-14` (doc-comment already says the camera should be level-owned).*

### RD-1 — Approach: the HYBRID (project content-scale base + dynamic camera-zoom layer). Confirmed over pure A and pure B.

The author's hybrid is correct and is adopted. The reasoning survives fresh-eyes scrutiny:
- **Pure A** (stretch base only) makes "visible world width" a *project constant* — but the Director's verbatim work-order is "Make this configurable," and RG2 must segment FOV cohorts, which a project constant cannot do. Rejected.
- **Pure B** (camera script only, stretch left `disabled`) leaves the **default-off path with the live window-dependent FOV bug** (the exact thing the Director called out) and gives no pixel-crispness guarantee for M2 tiles. Rejected.
- **Hybrid** fixes the default-off case *and* makes width a live swept knob *and* keeps pixels crisp, for one `[display]` block (which K6 wants the file touched for anyway) + ~40 LOC. **Adopted.**

The two layers compose cleanly: the `canvas_items` base caps the window's influence to an integer-scaled fixed canvas (kills per-monitor variance even with `cam_enabled=false`), and the `CameraView` zoom layer turns "visible world width" into the controlled, telemetry-marked knob.

### RD-2 — Integer scaling, not fractional. Decisive (pixel-art, filter OFF).

`scale_mode="integer"`. The filter-OFF pixel-art convention (`default_texture_filter=0`) is a hard constraint; `fractional` resamples the canvas at non-integer factors → blurry pixels → violates the convention. `integer` snaps the whole-canvas scale to the largest integer that fits and letterboxes the remainder. The cost (thin bars at non-integer window multiples) is minimised by `aspect="expand"` (the expand axis grows by whole base-pixel rows/cols). Crispness is the load-bearing constraint; bars are cosmetic. Decisive on technical merit — no Director call needed. (Greybox `ColorRect`/`Polygon2D` have no texture seams *yet*, but the rule must hold for M2 tiles.)

### RD-3 — Aspect `expand` + `cam_zoom_policy=fit_width`. Default behaviour resolved; strict-both-axes equality flagged.

`aspect="expand"` (no letterbox bars on the unlocked axis) paired with the camera layer locking the **width**. For a top-down game the Director's stated concern is the *horizontal* sight-line ("see far enough out"), so locking width and letting height breathe is the right default. This re-introduces a *bounded* vertical resolution-dependence (ultrawide/tall windows see slightly more/less vertical world) — acceptable and decisive for the default.

**The exact visible-world-width and whether to instead enforce strict equality on BOTH axes (`keep` + `contain` policy, which adds black bars but makes the view pixel-identical on every aspect) is a fun/feel call → NEEDS DIRECTOR REVIEW.** Recommendation: ship `expand` + `fit_width` (width-locked, height breathes) and let the Director judge in the itch playtest whether strict both-axis equality is worth the bars. The knob (`cam_zoom_policy`) supports `contain` already, so flipping is a config sweep, not a code change.

### RD-4 — Knob shape: K0's `cam_enabled` + `cam_visible_world_width` (world-px) + `cam_zoom_policy` enum. Confirmed; matches K0.

Keep exactly the three K0-declared fields (`run_config.gd` K3 group, off-default: `cam_enabled=false`, `cam_visible_world_width=0.0`, `cam_zoom_policy=0`). `cam_visible_world_width` in world-px is the directly meaningful "how far can I see" number RG2 segments on, and it is approach-agnostic (works for the hybrid). Rejected alternatives: a raw `cam_zoom_override` (couples to viewport size → not resolution-independent, defeats the purpose) and exposing the base resolution (only meaningful under pure-A). The enum values `fit_width`/`fit_height`/`contain` stand. This resolves K0's OQ-4: **K3 keeps the full provisional `cam_*` set — it does NOT shrink it**, because the hybrid uses the per-run width knob (a pure-A stretch approach would have collapsed it to `cam_enabled` only, but pure-A is rejected). No change to K0's declared knob count.

### RD-5 — Default that reproduces today's FOV byte-for-byte. Confirmed.

`cam_enabled=false` + `cam_visible_world_width=0.0` (redundant guard) ⇒ `CameraView._recompute()` sets `zoom=BASE_ZOOM=(2,2)`, identical to the scene-authored `main_game.tscn:20`. Combined with the explicit base `viewport_width=1152`/`viewport_height=648` (today's *implicit* engine default, made explicit — NOT a change), the all-off control's framing is byte-identical to M1.3. The preset (`make_default_play_preset()`) is the separate artifact that turns the knob on (provisional sweep start `cam_visible_world_width=576.0 = 1152/2`, the M1.3 horizontal FOV now pinned constant across resolutions) — the Director sweeps that value. **The exact preset width is a feel call → NEEDS DIRECTOR REVIEW** (576 reproduces M1.3 horizontal FOV as the neutral sweep start; the Director may want narrower/wider to tune "how much seeing ahead matters"). The code-level all-off default is never touched.

### RD-6 — Determinism fingerprint `e943ac9c8bc1` UNAFFECTED (confirmed).

The camera is pure presentation, post-generation; it never feeds `fingerprint(seed+config)`. Adding `[display]`/`[physics]` sections and the `CameraView` script changes *rendering*, not the generated band for any config. The all-off control's fingerprint stays `e943ac9c8bc1`. No sub-stream routing is needed (unlike K7 exits) — the only determinism requirement is "default reproduces today," satisfied by RD-5. Smoke test stays green (headless doesn't render; `get_viewport().get_visible_rect().size` returns the base under `canvas_items`, and `cam_enabled=false` short-circuits to BASE_ZOOM regardless).

### RD-7 — The SINGLE combined K3+K6 change: who writes what, in what order (Wave-1 single-writer).

K3 and K6 land as **ONE change on ONE Wave-1 worktree** (single writer on both `project.godot` and `scenes/game/main_game.tscn`). The combined diff:

**`project.godot` — one diff, two new sections:**
```ini
[display]
window/size/viewport_width=1152        ; K3 — today's implicit base, made explicit
window/size/viewport_height=648        ; K3
window/stretch/mode="canvas_items"     ; K3
window/stretch/aspect="expand"         ; K3 (RD-3)
window/stretch/scale_mode="integer"    ; K3 (RD-2 — pixel-crisp)

[physics]
common/physics_interpolation=true      ; K6 — root-cause jitter fix (K6 RD-1/RD-2)
common/physics_ticks_per_second=60     ; K6 — explicit intent (already the default)
```
Pixel-snap keys stay ABSENT (K6 RD-3). Filter stays OFF (`[rendering]` unchanged).

**`scenes/game/main_game.tscn` — one camera-node change:** reparent `Camera2D` **off `Player` onto a level-owned follow rig** (K6 RD-2 / Option B — matches `player.gd:13-14`'s documented intent) and **retype it to `CameraView` (extends Camera2D)**, keeping `zoom=(2,2)` + `position_smoothing_enabled`/`speed=8.0` as-authored (K6 RD-4 keeps smoothing for RG1) so `cam_enabled=false` is byte-identical to today.

**`scenes/game/main_game.gd`:** re-home `_camera` from `$Player/Camera2D` (`:51`) to the rig path, typed as `CameraView`; at the existing seam (`:248-250`) keep `make_current()` + `reset_smoothing()`, then add `_camera.apply_from_config(run_cfg)` (K3, after make_current per OQ-6). The level-owned rig copies `_player.global_position` on the physics tick; interpolation smooths the render.

**Order (one agent):** (1) K6 `[physics]` flag + verify jitter-fix intent; (2) K3 `[display]` block; (3) reparent + retype camera node + re-home `_camera`; (4) K3 `CameraView` script + `apply_from_config`. One shared K3+K6 worklog names the commit SHA(s); any deviation → `design/DESIGN_DEVIATIONS.md`. This is the gate K6 OQ-4 named: the K3 approach (hybrid, RD-1) is now resolved, so K6 ships reparent (Option B), not the standalone-flag fallback.
