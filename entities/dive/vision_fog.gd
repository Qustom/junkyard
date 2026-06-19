class_name VisionFog
extends Node2D
## VisionFog (R4, M1.1 Lever 2) — a run-state, purely-cosmetic limited-vision
## overlay for the dive scene. It darkens the band with a CanvasModulate and lights
## a bubble around the player with a PointLight2D whose radius tightens with depth.
##
## RATIFIED §10 Q3 (node, not shader): CanvasModulate dark overlay + a player
## PointLight2D — the cheapest Godot-native "limited vision" vignette. Fog-of-war
## (§10, r4_fog_enabled) keeps a low-res `revealed` cell mask so once-seen cells
## stay faintly lit. No fragment shader for M1.1 (deferred to the real vision system).
##
## COSMETIC ONLY — this node NEVER alters collision, the generated geometry, or the
## proc-gen RNG. It reads config + player position + live within-band depth and
## writes nothing to meta-state, the save schema, or game_state.gd. Run-state: it is
## created per dive and freed with the band.
##
## RATIFIED §10 Q4 (multiply, don't add): when R3 runs a vision penalty it arrives as
## EventBus.exposure_vision_mult_changed(mult) — a FRACTION we multiply into the
## already-computed effective_radius, then re-floor at MIN_RADIUS. Default 1.0 (R3
## off / no penalty) ⇒ no change. The two vision penalties compose multiplicatively
## and never reach zero.

## Vision floor (~1.5 cells at 16px) — the player is never fully blind.
const MIN_RADIUS := 24.0

## Overlay darkness. Greybox look (environment-artist's call to refine): a near-black
## modulate that the player light cuts a hole in.
const OVERLAY_COLOR := Color(0.06, 0.06, 0.08, 1.0)

## Fog-of-war remembered-cell tint: a faint always-lit dim so explored area reads as
## "seen but not live". Cosmetic only.
const FOG_TINT := Color(0.22, 0.22, 0.26, 1.0)

## Base radius (px) of the generated player-light gradient texture. effective_radius
## is mapped onto this by texture_scale = effective_radius / _LIGHT_BASE_RADIUS.
const _LIGHT_BASE_RADIUS := 256.0

## Fog mask is sampled per N px of player travel so the revealed set stays low-res
## (one entry per ~cell), not per-pixel — keeps it a cheap greybox memory.
const _FOG_CELL_PX := 16

var _rc: RunConfig
var _player: Node2D
var _modulate: CanvasModulate
var _light: PointLight2D
var _fog_layer: Node2D
var _revealed: Dictionary = {}            # Vector2i fog-cell -> faint reveal sprite
var _r3_vision_fraction := 1.0            # RATIFIED §10 Q4; 1.0 = no R3 penalty
var _active := false


func _ready() -> void:
	_rc = GameState.active_run_config
	_player = get_tree().get_first_node_in_group(&"player")
	# OFF (R4 disabled or full-vision radius 0) ⇒ no overlay at all == the M1.0 look.
	_active = _rc != null and _rc.r4_enabled and _rc.r4_vision_radius > 0.0
	visible = _active
	set_process(_active)
	if not _active:
		return
	_build_nodes()
	# R3 vision penalty arrives multiplicatively (§10 Q4). Pre-declared on EventBus;
	# we only consume it. No-op (mult 1.0) when R3 is off.
	EventBus.exposure_vision_mult_changed.connect(_on_vision_mult_changed)


func _build_nodes() -> void:
	_modulate = CanvasModulate.new()
	_modulate.color = OVERLAY_COLOR
	add_child(_modulate)

	_fog_layer = Node2D.new()
	_fog_layer.name = "FogLayer"
	add_child(_fog_layer)

	_light = PointLight2D.new()
	_light.texture = _make_light_texture()
	# PointLight2D default scales the texture about its centre; our gradient is
	# centred, so the lit bubble follows the player. Energy slightly >1 so the lit
	# area reads at full brightness against the dark modulate.
	_light.energy = 1.2
	add_child(_light)


## Build a radial white→transparent gradient texture procedurally so the node needs
## no art asset (greybox). The environment-artist can swap a hand-authored falloff in.
func _make_light_texture() -> Texture2D:
	var size := int(_LIGHT_BASE_RADIUS * 2.0)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(_LIGHT_BASE_RADIUS, _LIGHT_BASE_RADIUS)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c) / _LIGHT_BASE_RADIUS
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a  # smoother falloff at the edge
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _process(_dt: float) -> void:
	if _player == null:
		return
	var depth: int = GameState.current_depth_index   # BUG2 live within-band depth
	var radius := maxf(MIN_RADIUS,
		_rc.r4_vision_radius - _rc.r4_vision_tighten_per_depth * float(depth))
	# RATIFIED §10 Q4: multiply R3's vision fraction in, then re-floor — never add,
	# never reach zero. _r3_vision_fraction == 1.0 when R3-vision is off.
	radius = maxf(MIN_RADIUS, radius * _r3_vision_fraction)

	_light.global_position = _player.global_position
	_light.texture_scale = radius / _LIGHT_BASE_RADIUS

	if _rc.r4_fog_enabled:
		_remember_visible_cells(_player.global_position, radius)


## Mark fog cells inside the current vision bubble as revealed. Each newly-seen cell
## gets a faint always-lit tint sprite so the player keeps a partial mental map.
## Low-res (per fog-cell), cosmetic, never touches geometry/collision.
func _remember_visible_cells(centre: Vector2, radius: float) -> void:
	var r_cells := int(ceil(radius / float(_FOG_CELL_PX)))
	var c_cell := Vector2i((centre / float(_FOG_CELL_PX)).floor())
	for dy in range(-r_cells, r_cells + 1):
		for dx in range(-r_cells, r_cells + 1):
			var cell := c_cell + Vector2i(dx, dy)
			if _revealed.has(cell):
				continue
			var cell_centre := Vector2(cell * _FOG_CELL_PX) \
				+ Vector2(_FOG_CELL_PX, _FOG_CELL_PX) * 0.5
			if cell_centre.distance_to(centre) > radius:
				continue
			_mark_revealed(cell)


func _mark_revealed(cell: Vector2i) -> void:
	var tint := ColorRect.new()
	tint.color = FOG_TINT
	tint.size = Vector2(_FOG_CELL_PX, _FOG_CELL_PX)
	tint.position = Vector2(cell * _FOG_CELL_PX)
	# Faint, behind the live light so the bubble still reads brightest.
	tint.z_index = -1
	_fog_layer.add_child(tint)
	_revealed[cell] = tint


func _on_vision_mult_changed(mult: float) -> void:
	# Clamp defensively so a stray 0 can never blind the player (floor still applies).
	_r3_vision_fraction = maxf(mult, 0.01)
