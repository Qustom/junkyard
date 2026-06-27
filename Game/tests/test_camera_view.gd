extends Node
## Headless verification for K3 (M1.4) — the resolution-independent CameraView math.
##
## Runs as a headless SCENE (test_camera_view.tscn) so the EventBus autoload resolves
## via the live SceneTree (M1_As_Built.md §"Testing constraints"). CameraView's runtime
## _recompute() reads a live Viewport (not exercisable headless), so this drives the
## EXTRACTED pure math CameraView.compute_zoom() + the disabled-path contract instead.
##
## Asserts:
##   - fit_width: visible_world_width == cam_visible_world_width at MANY resolutions
##     (640x360, 1152x648, 1920x1080) => RESOLUTION-INDEPENDENCE, the K3 contract;
##   - the disabled path (width <= 0) yields BASE_ZOOM (today's (2,2) framing);
##   - fit_height / contain policies compute the documented axis.
## Run: godot --headless res://tests/test_camera_view.tscn


func _ready() -> void:
	var failures: Array[String] = []

	const W := 576.0   # the M1.3 horizontal FOV (1152 base / zoom 2), the preset sweep start.
	var sizes: Array[Vector2] = [Vector2(640, 360), Vector2(1152, 648), Vector2(1920, 1080)]

	# === Case 1: fit_width holds visible_world_width CONSTANT across resolutions ===
	for vp in sizes:
		var z: float = CameraView.compute_zoom(vp, W, CameraView.POLICY_FIT_WIDTH)
		var visible_w: float = vp.x / z
		if not is_equal_approx(visible_w, W):
			failures.append("fit_width @ %s: visible_world_width=%f, expected %f" % [vp, visible_w, W])

	# === Case 2: disabled path (width <= 0) => BASE_ZOOM (today's look) ===========
	var z_off: float = CameraView.compute_zoom(Vector2(1920, 1080), 0.0, CameraView.POLICY_FIT_WIDTH)
	if not is_equal_approx(z_off, CameraView.BASE_ZOOM.x):
		failures.append("disabled path: zoom=%f, expected BASE_ZOOM.x=%f" % [z_off, CameraView.BASE_ZOOM.x])
	var z_neg: float = CameraView.compute_zoom(Vector2(1920, 1080), -10.0, CameraView.POLICY_FIT_WIDTH)
	if not is_equal_approx(z_neg, CameraView.BASE_ZOOM.x):
		failures.append("negative width: zoom=%f, expected BASE_ZOOM.x=%f" % [z_neg, CameraView.BASE_ZOOM.x])

	# === Case 3: fit_height locks the vertical axis ==============================
	var vp_h := Vector2(1920, 1080)
	var z_h: float = CameraView.compute_zoom(vp_h, W, CameraView.POLICY_FIT_HEIGHT)
	if not is_equal_approx(vp_h.y / z_h, W):
		failures.append("fit_height: visible height %f, expected %f" % [vp_h.y / z_h, W])

	# === Case 4: contain guarantees >= width on the LONGER axis ==================
	# contain uses max(x,y)/width, so the longer axis shows exactly W and the shorter
	# shows <= W (never less than W of world on either axis).
	var vp_c := Vector2(1920, 1080)
	var z_c: float = CameraView.compute_zoom(vp_c, W, CameraView.POLICY_CONTAIN)
	var long_axis_world: float = maxf(vp_c.x, vp_c.y) / z_c
	if not is_equal_approx(long_axis_world, W):
		failures.append("contain: longer-axis world %f, expected %f" % [long_axis_world, W])

	# === Report ==================================================================
	if failures.is_empty():
		print("CAMERA_VIEW OK — K3 resolution-independence verified (fit_width constant across "
			+ "640x360/1152x648/1920x1080), disabled path = BASE_ZOOM (today's framing), "
			+ "fit_height/contain policies correct")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("CAMERA_VIEW FAIL: ", f)
		get_tree().quit(1)
