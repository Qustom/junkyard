class_name VisionFog
extends Node2D
## VisionFog (R4, reworked in M1.2 I4) — a run-state, purely-cosmetic limited-vision
## overlay for the dive scene. It OCCLUDES the band beyond the player's vision radius
## (hides, not merely dims), keeps a legible three-state fog memory, and surfaces the
## lost-proxy as an on-screen cue.
##
## === M1.2 I4 rework (Director LOCKED, design doc design/M1_2_Tasks/I4_vision_rework.md) ===
## The M1.1 build (CanvasModulate multiply + additive PointLight2D) only DIMMED the far
## band — geometry stayed a visible silhouette. I4 replaces that with a node-based
## OCCLUDER (Resolved Q2, no shader): a player-centred radial-dark sprite in world space
## whose centre is transparent (the live hole, hard rim) and whose surround is near-opaque
## dark (OCCLUDE_ALPHA, Resolved Q1). Beyond the rim the geometry is GONE, not faint.
##   - Q1 (LOCKED): OCCLUDE_ALPHA = 0.94 — near-opaque with a ~6% anti-blindness floor
##     (never pure black: keeps OLED / dark-room from reading as "screen off"). The floor
##     is NON-load-bearing; the hard rim of the hole is the spatial legibility cue.
##   - Q2 (LOCKED): node-based radial-dark sprite, NOT a CanvasLayer-ColorRect cut by a
##     light-mask (that does not composite reliably in Godot 4) and NOT LightOccluder2D
##     (couples to wall geometry — deferred to the real vision system). No fragment shader.
##   - Q5 (LOCKED): three-state fog separated on a NON-hue axis for colourblind safety —
##     never-seen = absence of shape; remembered = flat, static, cool-desaturated ghost
##     (FOG_TINT); live = the bright moving hole. Hue is a reinforcing, not primary, cue.
##   - Q6 (LOCKED): the dark plate sorts ABOVE world geometry / distant pickups / distant
##     I2 hazard (hidden until in-bubble — the point of limited vision), but the PLAYER is
##     always inside the transparent hole (never occluded). Sort order is plain z_index.
##
## COSMETIC ONLY — this node NEVER alters collision, the generated geometry, or the
## proc-gen RNG. It reads config + player position + live within-band depth and writes
## NOTHING to meta-state, the save schema, or game_state.gd. It adds NO EventBus signal
## (the lost cue LISTENS to the pre-declared nav_lost_proxy; lost_proxy.gd is untouched).
## Run-state: created per dive, freed with the band.
##
## RATIFIED §10 Q4 (multiply, don't add): when R3 runs a vision penalty it arrives as
## EventBus.exposure_vision_mult_changed(mult) — a FRACTION multiplied into the
## already-computed effective_radius, then re-floored at MIN_RADIUS. Default 1.0 (R3
## off / no penalty) ⇒ no change.

# --- Occlusion (Q1/Q2) -------------------------------------------------------

## Vision floor (~1.5 cells at 16px) — the player is never fully blind.
const MIN_RADIUS := 24.0

## Occlusion darkness (Q1, Director-LOCKED). 0.94 = near-opaque hide with a ~6%
## anti-blindness floor (NOT pure 1.0 black). Sweepable feel knob.
const OCCLUDE_ALPHA := 0.94

## Dark plate colour (the surround beyond the hole). Cool near-black greybox.
const OCCLUDE_COLOR := Color(0.02, 0.02, 0.03, 1.0)

## Width of the lit->hidden rim as a fraction of the radius. Small = crisp hard edge
## (vs M1.1's soft (1-d)^2 vignette that faded into the dim). The rim itself is the
## redundant non-colour legibility cue ("this is the limit of sight").
const EDGE_HARDNESS := 0.10

## Radius (px) of the radial-dark occluder texture, in TEXTURE space. effective_radius
## is mapped onto the transparent hole via texture scale = effective_radius / this.
const _HOLE_TEX_RADIUS := 256.0

## Half-size (px, texture space) of the full radial-dark sprite. The opaque surround
## must cover the whole viewport at all zoom levels and during camera smoothing lag
## (Resolved Q2 corner case). Camera zoom 2x on a 1152x648 window => ~661px visible
## diagonal; this sprite (2048px) dwarfs it with a wide margin so no un-darkened gutter
## ever shows at the screen edge near a band boundary.
const _PLATE_HALF_PX := 1024.0

# --- Fog memory (Q5) ---------------------------------------------------------

## Remembered-cell ghost (Q5, Director-LOCKED): a cool, desaturated blue-grey, flat and
## static, clearly ABOVE the occlusion floor (~6%) and clearly BELOW the live bubble.
## The "it's a memory" read comes from flatness + lack of live motion, NOT from the hue
## (colourblind-safe). The environment-artist may retune the hue but must not collapse
## the monotonic ladder occlude_floor < remembered < live.
const FOG_TINT := Color(0.34, 0.40, 0.52, 0.85)

## Fog mask is sampled per N px of player travel so the revealed set stays low-res
## (one entry per ~cell), not per-pixel — keeps it a cheap greybox memory.
const _FOG_CELL_PX := 16

# --- Lost cue (Q3/Q4/Q7) -----------------------------------------------------

## Screen-edge "disoriented" pulse colour (cool). The pulse carries MOTION + POSITION
## (it animates at the screen edge); its colour is NOT load-bearing (Q3 redundancy).
const LOST_PULSE_COLOR := Color(0.30, 0.42, 0.62, 1.0)

## Pulse fade in/out duration (s).
const LOST_PULSE_IN := 0.35
const LOST_PULSE_OUT := 0.85

## Peak alpha of the screen-edge pulse vignette.
const LOST_PULSE_PEAK := 0.55

## Border thickness (px) of the screen-edge pulse vignette.
const LOST_BORDER_PX := 90.0

## The persistent HUD word shown on the 2nd+ emit (Q4). Self-contained greybox string
## (NOT in hud_strings.csv — I3 owns the HUD this wave). Inline is fine for greybox.
const LOST_WORD := "DISORIENTED"

## How long the persistent HUD word survives without a re-fire before it self-clears.
## lost_proxy re-emits each additional threshold of continuous wandering; depth progress
## stops the emits, so the word times out within roughly one threshold window.
const LOST_WORD_LINGER_S := 8.0

# --- Occlusion / depth-render layers ----------------------------------------

## Dark plate z_index: above world geometry / distant pickups / distant hazard (all z 0),
## so they are HIDDEN beyond the hole. The player (z 0, a sibling node tree) stays visible
## because it is always inside the transparent hole centred on it (Q6).
const _DARK_Z := 100

## Fog ghosts render ABOVE the dark plate so explored area stays readable, but BELOW the
## live read; ghosts inside the live bubble are hidden so the bright hole isn't tinted.
const _FOG_Z := 101

var _rc: RunConfig
var _player: Node2D
var _dark_sprite: Sprite2D                 # radial-dark occluder, world space, follows player
var _fog_layer: Node2D
var _revealed: Dictionary = {}             # Vector2i fog-cell -> ghost ColorRect
var _r3_vision_fraction := 1.0             # RATIFIED §10 Q4; 1.0 = no R3 penalty
var _active := false

# Lost-cue state (Q7: this node is the SINGLE owner of the "am I lost" episode state).
var _lost_layer: CanvasLayer               # screen-edge pulse + HUD word host (self-contained)
var _lost_border: Control                  # animated screen-edge vignette
var _lost_word_label: Label                # persistent HUD word (2nd+ emit)
var _lost_pulse_tween: Tween
var _lost_word_timer: float = 0.0          # >0 while the persistent word is showing
var _lost_emit_count: int = 0              # emits in the current episode (gates word on 2nd+)


func _ready() -> void:
	_rc = GameState.active_run_config
	_player = get_tree().get_first_node_in_group(&"player")
	# OFF (R4 disabled or full-vision radius 0) ⇒ no overlay at all == the M1.0/M1.1
	# baseline control. set_process is gated on _active, and the lost-cue listener is
	# connected ONLY when active too, so an all-off run is fully inert.
	_active = _rc != null and _rc.r4_enabled and _rc.r4_vision_radius > 0.0
	visible = _active
	set_process(_active)
	if not _active:
		return
	_build_nodes()
	_build_lost_cue()
	# R3 vision penalty arrives multiplicatively (§10 Q4). Pre-declared on EventBus;
	# we only consume it. No-op (mult 1.0) when R3 is off.
	EventBus.exposure_vision_mult_changed.connect(_on_vision_mult_changed)
	# Lost cue: pure LISTENER on the pre-declared signal (Q7 single owner). Adds NO
	# signal, NO game state; lost_proxy.gd detection/telemetry is untouched.
	EventBus.nav_lost_proxy.connect(_on_lost_proxy)
	EventBus.run_ended.connect(_on_run_ended)


func _build_nodes() -> void:
	_fog_layer = Node2D.new()
	_fog_layer.name = "FogLayer"
	add_child(_fog_layer)

	# The radial-dark occluder: ONE world-space sprite centred on the player. Transparent
	# hole in the middle (the live bubble, hard rim), near-opaque dark surround. Sorting
	# above world geometry, it HIDES everything beyond the hole; the player is always in
	# the hole so it is never occluded (Q6).
	_dark_sprite = Sprite2D.new()
	_dark_sprite.name = "DarkOccluder"
	_dark_sprite.texture = _make_occluder_texture()
	_dark_sprite.z_index = _DARK_Z
	_dark_sprite.z_as_relative = false
	add_child(_dark_sprite)


## Build the radial-dark occluder texture procedurally (greybox, no art asset). It is the
## INVERSE of M1.1's light gradient: TRANSPARENT in the centre hole (so live geometry +
## the player show through), a crisp rim, and near-opaque dark (OCCLUDE_ALPHA) outside.
## The dark surround fills the whole texture so the plate covers the viewport.
##   alpha = 0                          for d < (1 - EDGE_HARDNESS)   -> clear hole
##   alpha = smoothstep ramp            in the rim                    -> hard-ish edge
##   alpha = OCCLUDE_ALPHA              for d >= 1 (out to the plate edge) -> hidden
func _make_occluder_texture() -> Texture2D:
	var size := int(_PLATE_HALF_PX * 2.0)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Fill the whole image with the opaque dark first (the surround beyond the hole).
	img.fill(Color(OCCLUDE_COLOR.r, OCCLUDE_COLOR.g, OCCLUDE_COLOR.b, OCCLUDE_ALPHA))
	var c := Vector2(_PLATE_HALF_PX, _PLATE_HALF_PX)
	var inner := 1.0 - EDGE_HARDNESS
	# Carve the transparent hole + rim only within the hole-texture-radius footprint.
	var carve := int(ceil(_HOLE_TEX_RADIUS)) + 2
	for y in range(int(c.y) - carve, int(c.y) + carve):
		for x in range(int(c.x) - carve, int(c.x) + carve):
			var d := Vector2(x, y).distance_to(c) / _HOLE_TEX_RADIUS
			var a: float
			if d < inner:
				a = 0.0                                   # clear hole — live read
			elif d < 1.0:
				# Hard-ish rim: ramp from clear to full occlusion across EDGE_HARDNESS.
				a = smoothstep(inner, 1.0, d) * OCCLUDE_ALPHA
			else:
				continue                                  # already filled opaque
			img.set_pixel(x, y, Color(OCCLUDE_COLOR.r, OCCLUDE_COLOR.g, OCCLUDE_COLOR.b, a))
	return ImageTexture.create_from_image(img)


func _process(_dt: float) -> void:
	if _player == null:
		return
	var depth: int = GameState.current_depth_index   # BUG2 live within-band depth (Q8)
	var radius := maxf(MIN_RADIUS,
		_rc.r4_vision_radius - _rc.r4_vision_tighten_per_depth * float(depth))
	# RATIFIED §10 Q4: multiply R3's vision fraction in, then re-floor — never add,
	# never reach zero. _r3_vision_fraction == 1.0 when R3-vision is off.
	radius = maxf(MIN_RADIUS, radius * _r3_vision_fraction)

	# Move + scale the radial-dark hole to track the player and tighten with depth.
	_dark_sprite.global_position = _player.global_position
	_dark_sprite.scale = Vector2.ONE * (radius / _HOLE_TEX_RADIUS)

	if _rc.r4_fog_enabled:
		_remember_visible_cells(_player.global_position, radius)
		_refresh_fog_visibility(_player.global_position, radius)

	# Tick the persistent lost word down; clear it when the proxy stops re-firing.
	if _lost_word_timer > 0.0:
		_lost_word_timer -= _dt
		if _lost_word_timer <= 0.0:
			_set_lost_word(false)


# --- Fog memory (Q5) ---------------------------------------------------------

## Mark fog cells inside the current vision bubble as revealed. Each newly-seen cell gets
## a cool, flat, static ghost so explored area reads as a distinct "seen but not live"
## state. Low-res (per fog-cell), cosmetic, never touches geometry/collision.
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
	var ghost := ColorRect.new()
	ghost.color = FOG_TINT
	ghost.size = Vector2(_FOG_CELL_PX, _FOG_CELL_PX)
	ghost.position = Vector2(cell * _FOG_CELL_PX)
	# Above the dark plate so remembered area stays readable through the occlusion.
	ghost.z_index = _FOG_Z
	ghost.z_as_relative = false
	_fog_layer.add_child(ghost)
	_revealed[cell] = ghost


## Hide remembered ghosts that are currently inside the live bubble so the bright hole
## isn't double-tinted (Q5 polish); show ghosts elsewhere as the "remembered" state.
func _refresh_fog_visibility(centre: Vector2, radius: float) -> void:
	for cell in _revealed:
		var ghost: ColorRect = _revealed[cell]
		if ghost == null:
			continue
		var cell_centre := Vector2(cell * _FOG_CELL_PX) \
			+ Vector2(_FOG_CELL_PX, _FOG_CELL_PX) * 0.5
		# Inside the live hole -> let live geometry read (hide the stale ghost).
		ghost.visible = cell_centre.distance_to(centre) > radius


# --- Lost cue (Q3/Q4/Q7) -----------------------------------------------------

## Build the self-contained lost-cue overlay: a screen-edge pulse vignette + a HUD word.
## This is I4's OWN CanvasLayer (NOT DecisionHUD — I3 owns the HUD this wave). It is
## run-state, freed with the band. Both cues are pure projections of this node's episode
## state (Q7 single owner); they add no signal and no game state.
func _build_lost_cue() -> void:
	_lost_layer = CanvasLayer.new()
	_lost_layer.name = "LostCue"
	_lost_layer.layer = 60     # above the world; below typical HUD/menu layers
	add_child(_lost_layer)

	# Screen-edge vignette: four border strips so the CENTRE stays clear (non-blocking,
	# peripheral). Built as a single Control with four anchored child ColorRects.
	_lost_border = Control.new()
	_lost_border.name = "EdgePulse"
	_lost_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lost_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lost_border.modulate = Color(1, 1, 1, 0)   # start invisible; tween drives alpha
	_lost_layer.add_child(_lost_border)
	_add_edge_strip(Control.PRESET_TOP_WIDE, Vector2(0, LOST_BORDER_PX))
	_add_edge_strip(Control.PRESET_BOTTOM_WIDE, Vector2(0, LOST_BORDER_PX))
	_add_edge_strip(Control.PRESET_LEFT_WIDE, Vector2(LOST_BORDER_PX, 0))
	_add_edge_strip(Control.PRESET_RIGHT_WIDE, Vector2(LOST_BORDER_PX, 0))

	# Persistent HUD word (2nd+ emit). Top-centre, hidden until escalation confirms.
	_lost_word_label = Label.new()
	_lost_word_label.name = "LostWord"
	_lost_word_label.text = LOST_WORD
	_lost_word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lost_word_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lost_word_label.position = Vector2(-80, 28)
	_lost_word_label.size = Vector2(160, 24)
	_lost_word_label.add_theme_color_override("font_color", LOST_PULSE_COLOR)
	_lost_word_label.add_theme_font_size_override("font_size", 18)
	_lost_word_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lost_word_label.visible = false
	_lost_layer.add_child(_lost_word_label)


func _add_edge_strip(preset: int, min_size: Vector2) -> void:
	var strip := ColorRect.new()
	strip.color = LOST_PULSE_COLOR
	strip.set_anchors_preset(preset)
	strip.custom_minimum_size = min_size
	if min_size.y > 0.0:
		strip.size.y = min_size.y
	if min_size.x > 0.0:
		strip.size.x = min_size.x
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lost_border.add_child(strip)


## Listener for the pre-declared nav_lost_proxy (Q4): pulse on EVERY emit (cheap,
## peripheral nudge); show the persistent HUD WORD only on the 2nd+ emit of the episode
## (the escalating re-fire = "still stuck", higher confidence — avoids nagging a brief
## stall). The episode resets when lost_proxy stops emitting (depth progress / run end),
## which we mirror via the word's linger timeout + run_ended clear.
func _on_lost_proxy(_metric: StringName, _value: float, _depth: int) -> void:
	_lost_emit_count += 1
	_pulse_edge()
	if _lost_emit_count >= 2:
		_set_lost_word(true)
	# Refresh the linger each emit so the episode state survives between rate-limited
	# re-fires; it times out (and clears emit_count) once the proxy stops firing.
	_lost_word_timer = LOST_WORD_LINGER_S


func _pulse_edge() -> void:
	if _lost_border == null:
		return
	if _lost_pulse_tween != null and _lost_pulse_tween.is_valid():
		_lost_pulse_tween.kill()
	_lost_border.modulate.a = 0.0
	_lost_pulse_tween = create_tween()
	_lost_pulse_tween.tween_property(_lost_border, "modulate:a", LOST_PULSE_PEAK, LOST_PULSE_IN)
	_lost_pulse_tween.tween_property(_lost_border, "modulate:a", 0.0, LOST_PULSE_OUT)


func _set_lost_word(do_show: bool) -> void:
	if _lost_word_label != null:
		_lost_word_label.visible = do_show
	if not do_show:
		_lost_word_timer = 0.0
		_lost_emit_count = 0   # episode over -> next stall starts a fresh ramp


func _clear_lost() -> void:
	_set_lost_word(false)
	if _lost_pulse_tween != null and _lost_pulse_tween.is_valid():
		_lost_pulse_tween.kill()
	if _lost_border != null:
		_lost_border.modulate.a = 0.0


func _on_run_ended(_reason: StringName, _duration_s: float, _depth_reached: int) -> void:
	# Safety clear on run end (the node is freed with the band, but guard anyway).
	_clear_lost()


func _on_vision_mult_changed(mult: float) -> void:
	# Clamp defensively so a stray 0 can never blind the player (floor still applies).
	_r3_vision_fraction = maxf(mult, 0.01)
