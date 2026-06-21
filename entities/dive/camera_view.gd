class_name CameraView
extends Camera2D
## K3 (M1.4) — resolution-independent camera: holds a FIXED visible world-width
## regardless of viewport/window size, when enabled.
##
## Pure presentation. Reads the run config (the cam_* knobs) at run start, never
## touches game-state, never feeds fingerprint(). When DISABLED
## (cam_enabled == false / cam_visible_world_width <= 0) it leaves the
## scene-authored zoom at BASE_ZOOM => today's M1.3 framing exactly (the all-off
## control). When enabled it sets zoom from the live viewport size so the chosen
## world-width always fills the view, recomputing on Viewport.size_changed so a
## window resize never changes how much world is visible.
##
## K6 (M1.4): this camera lives on a level-owned follow rig (NOT a child of the
## player body) so it is interpolation-clean — see main_game.tscn / main_game.gd.
## The rig copies the player's position on the physics tick; physics interpolation
## (project.godot [physics]) smooths the render between ticks.

## The scene-authored zoom (mirrors main_game.tscn Camera2D zoom). This is the
## all-off / disabled look — what every cam_enabled==false run renders.
const BASE_ZOOM := Vector2(2, 2)

## Zoom-policy enum (mirrors RunConfig.cam_zoom_policy @export_enum order).
const POLICY_FIT_WIDTH := 0
const POLICY_FIT_HEIGHT := 1
const POLICY_CONTAIN := 2

var _cfg: RunConfig = null


## Apply the camera config for a run. Called by MainGame.start_new_run() right
## after make_current() + reset_smoothing() (K3 OQ-6 / RD: after make_current so
## the camera is current before the first recompute). Idempotent: re-connecting
## the resize signal is guarded.
func apply_from_config(cfg: RunConfig) -> void:
	_cfg = cfg
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_recompute):
		vp.size_changed.connect(_recompute)
	_recompute()


## Recompute the zoom from the live viewport size to hold cam_visible_world_width
## constant (per cam_zoom_policy). When disabled, snap back to BASE_ZOOM (today's
## look). Emits EventBus.camera_view_set with the applied (visible_world_width,
## zoom) for RG2's "how far could I see this run" telemetry — every run, on/off.
func _recompute() -> void:
	if _cfg == null or not _cfg.cam_enabled or _cfg.cam_visible_world_width <= 0.0:
		zoom = BASE_ZOOM                                   # disabled => today's framing
		EventBus.camera_view_set.emit(_visible_world_width(), zoom.x)
		return
	var z: float = compute_zoom(_viewport_size(), _cfg.cam_visible_world_width, _cfg.cam_zoom_policy)
	zoom = Vector2(z, z)                                   # UNIFORM => square pixels preserved
	EventBus.camera_view_set.emit(_visible_world_width(), zoom.x)


## Pure zoom math (no node state) — the uniform zoom factor that makes a viewport of
## `vp_size` show `width` world-px on the policy axis. Resolution-independence proof:
## for fit_width, visible_world_width = vp_size.x / zoom = width for ANY vp_size.
## Extracted as a static so test_camera_view.gd can verify it without a live viewport.
static func compute_zoom(vp_size: Vector2, width: float, policy: int) -> float:
	if width <= 0.0:
		return BASE_ZOOM.x
	var z: float
	match policy:
		POLICY_FIT_HEIGHT:
			z = vp_size.y / width                          # treat width as the height target
		POLICY_CONTAIN:
			z = maxf(vp_size.x, vp_size.y) / width         # guarantee >= width on both axes
		_:  # POLICY_FIT_WIDTH (default) — lock horizontal world-units
			z = vp_size.x / width
	if z <= 0.0:                                           # degenerate viewport guard
		z = BASE_ZOOM.x
	return z


## The currently-visible world width (px) given the live viewport + applied zoom.
func _visible_world_width() -> float:
	if zoom.x == 0.0:
		return 0.0
	return _viewport_size().x / zoom.x


## The viewport's visible size. Under canvas_items stretch this returns the fixed
## BASE size (1152x648), NOT the OS window size — which is exactly what makes the
## visible world-units resolution-independent.
func _viewport_size() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(1152, 648)                          # base fallback (headless / unparented)
	return vp.get_visible_rect().size
