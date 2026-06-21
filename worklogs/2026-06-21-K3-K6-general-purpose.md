# Worklog — K3 + K6 — Resolution-independent camera + movement-jitter fix

- **Date:** 2026-06-21
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.4
- **Branch:** worktree-agent-a089487f152864536 (isolated worktree feature branch)
- **Commit:** cfaa413d8fe9793a6155f6a930d31e7d481dfc62

## What changed
The combined K3+K6 Wave-1 change (the resolvers wrote them to land as ONE coherent diff,
single writer on `project.godot` + `main_game.tscn`). K3 makes the visible world region a
fixed number of world-units regardless of window/screen resolution (opt-in `cam_*` knob,
default-off = today's framing). K6 fixes the movement jitter at its root cause (physics
interpolation was OFF) and reparents the camera off the player body onto a level-owned rig.

- **`project.godot`:** added a `[display]` section (K3) — explicit base `1152x648`,
  `stretch/mode="canvas_items"`, `stretch/aspect="expand"`, `stretch/scale_mode="integer"`
  (pixel-perfect, filter stays OFF) — and a `[physics]` section (K6) —
  `common/physics_interpolation=true` + explicit `common/physics_ticks_per_second=60`.
- **`entities/dive/camera_view.gd` (new, `CameraView extends Camera2D`):** when
  `cam_enabled`, drives `zoom` from the live viewport size to hold `cam_visible_world_width`
  constant per `cam_zoom_policy`, recomputing on `Viewport.size_changed`; emits
  `EventBus.camera_view_set(visible_world_width, zoom)` every run. When disabled
  (`cam_enabled=false` / width<=0) it snaps to `BASE_ZOOM=(2,2)` → today's framing byte-for-
  byte. Zoom math extracted to a pure static `compute_zoom()` for headless testing.
- **`scenes/game/main_game.tscn`:** reparented `Camera2D` off `Player` onto a new
  level-owned `CameraRig` (Node2D) as `CameraView` (retyped), keeping `zoom=(2,2)` +
  `position_smoothing_enabled`/`speed=8.0` as authored (K6 RD-4: keep smoothing for RG1).
- **`scenes/game/main_game.gd`:** re-homed `_camera` from `$Player/Camera2D` to
  `$CameraRig/CameraView` (typed `CameraView`), added `_camera_rig`. `start_new_run()`
  re-centres the rig on the player at run start, keeps `make_current()`+`reset_smoothing()`,
  then calls `_camera.apply_from_config(run_cfg)` (after make_current, K3 OQ-6).
  `_physics_process` copies `_player.global_position` to the rig every physics tick (the
  level-owned follow); physics interpolation smooths the render between ticks.
- **`tests/test_camera_view.gd` + `.tscn` (new):** headless unit test on the pure
  `compute_zoom()` math — proves resolution-independence (fit_width visible-world-width
  constant at 640x360 / 1152x648 / 1920x1080), the disabled path = `BASE_ZOOM`, and the
  fit_height/contain policies.

## Files touched
- `project.godot` — `[display]` block (K3 stretch) + `[physics]` block (K6 interpolation).
- `entities/dive/camera_view.gd` — new `CameraView` script (fixed visible world-width).
- `entities/dive/camera_view.gd.uid` — generated on import.
- `scenes/game/main_game.tscn` — camera reparented to `CameraRig`, retyped `CameraView`.
- `scenes/game/main_game.gd` — `_camera`/`_camera_rig` refs, rig follow + `apply_from_config`.
- `tests/test_camera_view.gd` + `tests/test_camera_view.tscn` — new K3 unit test.
- `tests/test_camera_view.tscn`'s uid generated on import.

## Checks run
- [x] `godot --headless --import` clean — no parse/script errors (only the pre-existing
  generated-`.translation` "Cannot open file" warnings in a fresh worktree, unrelated).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK** (exit 0).
- [x] `godot --headless -d -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/test_bandgen_determinism.tscn`
  → **BANDGEN OK**, prints **fp=e943ac9c8bc1** (UNCHANGED — both fixes are render-time only).
- [x] `godot --headless res://tests/test_camera_view.tscn` → **CAMERA_VIEW OK** (exit 0).
- [x] `godot --headless res://tests/test_run_config.tscn` → **R0 OK** (81 knobs, all-off
  baseline intact, `cam_*` default-off).
- [x] Definition of done met (K3): "cam_enabled=false reproduces today's M1.3 framing
  exactly (visual + unchanged e943ac9c8bc1)" — disabled path returns `BASE_ZOOM=(2,2)`,
  base viewport made explicit = today's implicit default, fp unchanged. "EventBus.camera_view_set
  fires per run" — emitted in `_recompute()`. (K6): "physics_interpolation on + camera
  reparented to a level-owned rig; one combined project.godot+camera change with K3."

## Deferred / non-headless-verifiable check
The ACTUAL jitter-gone behaviour (K6) and the resolution-independent FOV *look* (K3) are
**render-time and NOT headless-verifiable** — headless does not render, and
`get_viewport().get_visible_rect().size` returns the base under `canvas_items`. Per K6 RD-5 /
K3 DoD, these must be confirmed by the Director eyeballing the **RG1 itch playtest** on a
>60 Hz monitor / browser (browsers vsync to the display). This is the canonical
confirm-by-fixing case; the headless suite only proves the default-off path compiles, the
zoom math is resolution-independent, and the smoke/determinism stay green.

## Design deviations
- **None on the locked Resolved Decisions.** The build follows K3 RD-1..RD-7 and K6 RD-1..RD-7
  exactly (hybrid camera, integer scale, expand/fit_width, default-off=today, interpolation
  on, Option-B reparent to a level-owned rig, smoothing kept @8.0).
- **Minor (no Director call):** added the K3 unit test `tests/test_camera_view.gd` (the K3
  doc listed it as additive). It does NOT alter any knob-count contract (it tests the pure
  CameraView math, not RunConfig). The script's zoom math was extracted into a pure static
  `CameraView.compute_zoom()` so the test can run headless without a live Viewport — an
  internal-structure choice, behaviour-identical to the design pseudocode.
- **Flagged to Director (already in the Phase-3 docs, restated):** the exact preset visible
  world-width (K3 RD-5: 576 as the neutral sweep start) and whether to keep `position_smoothing`
  vs pin-to-centre (K6 RD-4) are feel calls for the RG1 playtest — NOT decided here; the
  all-off code default is untouched and the preset width is owned by `make_default_play_preset()`
  (a separate artifact, not part of this K3+K6 camera change).

## Handoffs / follow-ups
- RG1 build+verify (Wave 4) is where the Director confirms the jitter is gone and judges the
  fixed-FOV feel. The preset camera knob values (`make_default_play_preset()`) are not set by
  this task — that is the Director's sweep, owned by the preset author / K0's preset wiring.
- `make_default_play_preset()` does NOT currently turn the camera on. If the Director wants the
  RG1 build to ship with a fixed FOV by default (K3 RD-5 suggested `cam_enabled=true`,
  `cam_visible_world_width=576.0`, `cam_zoom_policy=0`), that is a one-line preset edit to
  surface to the Director — left untouched here so the camera change is purely opt-in.
