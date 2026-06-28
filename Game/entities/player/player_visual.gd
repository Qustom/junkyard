extends Node2D
class_name PlayerVisual
## PlayerVisual — N1 (M1.7) player visual state machine.
##
## Turns the greybox `Player` CharacterBody2D into a legible 8-directional animated
## character. idle/walk are driven by the parent's already-resolved `velocity` and
## `facing`; pickup/throw one-shots are driven by EventBus.junk_picked_up /
## item_thrown. While an action clip plays, a brief movement-lock roots the body —
## implemented in player.gd by zeroing the movement input so the UNCHANGED
## step_velocity friction decelerates it (no velocity clobber, aim/move_and_slide
## still run). The lock is armed ONLY when art is ON; with art OFF this controller
## does no work and player.gd executes its exact M1.6 path (byte-for-byte).
##
## This node is a pure renderer: it reads already-resolved per-frame state
## (velocity, facing) and event-driven actions — it writes nothing that reaches the
## determinism fingerprint, touches no RNG / RunConfig / generator, and never
## touches the r=14 collision shape, collision layers/masks, or player_movement.tres.
## The sprite is scaled/Y-offset on the AnimatedSprite2D (visual transform only) so
## the 124px-canvas character reads against the r=14 body.
##
## The greybox `Visual` (ColorRect) + `Nose` (Polygon2D) are RETAINED on player.tscn
## and toggled with the art: hidden when art is ON, shown when art is OFF (M1.6 look).
## N2 emits EventBus.debug_player_art_toggled to swap at runtime; N1 only listens.

## Lock-duration mode. CLIP_DRIVEN: the action clip's own runtime roots the body
## (released by animation_finished), capped by lock_duration_cap_s. FIXED: a fixed
## fixed_lock_s root regardless of clip length (the clip finishes cosmetically).
## Director-ratified default = CLIP_DRIVEN with a ceiling cap (OQ-3).
enum LockMode { CLIP_DRIVEN, FIXED }

## --- Director-ratified configurable knobs (visual-controller @exports, NOT
## RunConfig fields — they live entirely outside config_menu's MANIFEST / 89-field
## coverage set, so the determinism fingerprint and knob count are untouched). ---

## OQ-5: lock + crouch-grab clip on ACCEPTED pickups only (default). Flip false to
## make accepted pickups cosmetic-only (clip plays, no movement root).
@export var lock_on_pickup: bool = true
## OQ-5: a full-bag (rejected) pickup plays nothing by default — it grabbed nothing,
## so a "stoop and grab" beat would lie. Flip true to animate rejects too.
@export var play_pickup_on_reject: bool = false
## OQ-3: lock duration mode. Default CLIP_DRIVEN (root = exactly the clip runtime).
@export var lock_mode: LockMode = LockMode.CLIP_DRIVEN
## OQ-3: ceiling cap (s) so a mis-authored long clip can't over-root under
## CLIP_DRIVEN. pickup≈0.25 s / throw≈0.29 s, so 0.4 s is a safe cap.
@export var lock_duration_cap_s: float = 0.4
## OQ-3: the fixed root duration (s) used only when lock_mode == FIXED.
@export var fixed_lock_s: float = 0.18

## Walk↔idle speed threshold (px/s). Above → walk; at/below → idle. 8 px/s sits well
## above the friction tail (no walk-in-place) and far below max_speed=200 (OQ-2).
const WALK_SPEED_THRESHOLD: float = 8.0
## Extra angle (deg) a candidate dir must beat the current dir by before the sprite
## switches — angular hysteresis that kills boundary strobe from continuous mouse
## aim. 10° ≈ 22% of a 45° sector (OQ-1).
const DIR_HYSTERESIS_DEG: float = 10.0

## The 8 dir suffixes, indexed by sector = round(deg/45) % 8. Screen space: +x = east
## (0°), +y = south (90°, +y is down). idx increases clockwise from east. This is the
## locked cross-doc contract with N0's SpriteFrames clip suffixes (OQ-7).
const DIRS: Array[StringName] = [
	&"east",       # 0   →   0°
	&"south_east", # 1   →  45°
	&"south",      # 2   →  90°
	&"south_west", # 3   → 135°
	&"west",       # 4   → 180° / -180°
	&"north_west", # 5   → -135°
	&"north",      # 6   →  -90°
	&"north_east", # 7   →  -45°
]

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _player: Player
var _art_on: bool = true
var _lock_remaining: float = 0.0
var _current_dir: StringName = &"south"
var _current_action: StringName = &""   # &"" | &"pickup" | &"throw"


func _ready() -> void:
	_player = get_parent() as Player

	EventBus.junk_picked_up.connect(_on_junk_picked_up)
	EventBus.item_thrown.connect(_on_item_thrown)
	EventBus.debug_player_art_toggled.connect(_on_art_toggled)
	_sprite.animation_finished.connect(_on_anim_finished)

	# Loud-fail a clip-name / dir-spelling mismatch with N0's SpriteFrames so a
	# silent play() no-op can never ship (OQ-7). Asserts one clip per state family.
	var frames := _sprite.sprite_frames
	assert(frames != null, "PlayerVisual: AnimatedSprite2D has no SpriteFrames assigned")
	for clip in [&"idle_south", &"walk_south", &"pickup_south", &"throw_south",
			&"idle_north", &"walk_east", &"pickup_west", &"throw_north_east"]:
		assert(frames.has_animation(clip),
			"PlayerVisual: SpriteFrames missing clip '%s' — clip-name/dir contract broke with N0" % clip)

	_apply_art_visibility()


## Gates player.gd's movement input. ALWAYS false when art is OFF (the lock is only
## ever armed under art ON), so player.gd's _physics_process executes its exact M1.6
## lines whenever art is off — byte-for-byte feel preservation.
func is_locked() -> bool:
	return _art_on and _lock_remaining > 0.0


func _process(delta: float) -> void:
	if not _art_on:
		return   # art OFF → no work; the greybox path is untouched.

	if _lock_remaining > 0.0:
		_lock_remaining -= delta

	# Direction: while an action runs, freeze the dir snapped at lock-start (OQ-4 —
	# no mid-clip dir-flip); otherwise track the parent's facing with hysteresis.
	if _current_action == &"":
		_current_dir = quantize_dir(_player.facing, _current_dir)

	var state := select_state(_player.velocity, is_locked(), _current_action)
	_play(state, _current_dir)


func _play(state: StringName, dir: StringName) -> void:
	var clip := StringName("%s_%s" % [state, dir])
	if _sprite.animation != clip or not _sprite.is_playing():
		_sprite.play(clip)


# --- action one-shots --------------------------------------------------------

func _on_junk_picked_up(_id: StringName, _value: int, _slot: int, _pos: Vector2, accepted: bool) -> void:
	if not _art_on:
		return
	if not accepted and not play_pickup_on_reject:
		return   # OQ-5: full-bag reject grabbed nothing → no animation by default.
	_begin_action(&"pickup", lock_on_pickup)


func _on_item_thrown(_id: StringName, _depth: int, _t: int) -> void:
	if not _art_on:
		return
	_begin_action(&"throw", true)


## Snap the dir at action start and freeze it for the clip, play the one-shot from
## frame 0, and arm the movement-lock (OQ-4). `do_lock` lets pickup honor
## lock_on_pickup while throw always roots.
func _begin_action(action: StringName, do_lock: bool) -> void:
	_current_action = action
	_current_dir = quantize_dir(_player.facing, _current_dir)
	if do_lock:
		_lock_remaining = _lock_duration_for(action)
	else:
		_lock_remaining = 0.0
	_sprite.play(StringName("%s_%s" % [action, _current_dir]))


## The lock window for an action. CLIP_DRIVEN: the clip's real runtime
## (frames / fps), capped by lock_duration_cap_s — released early by
## animation_finished, the cap only guards a mis-authored long clip. FIXED:
## fixed_lock_s regardless of clip length.
func _lock_duration_for(action: StringName) -> float:
	if lock_mode == LockMode.FIXED:
		return fixed_lock_s
	var clip := StringName("%s_%s" % [action, _current_dir])
	var frames := _sprite.sprite_frames
	if frames == null or not frames.has_animation(clip):
		return lock_duration_cap_s
	var fps: float = frames.get_animation_speed(clip)
	var count: int = frames.get_frame_count(clip)
	if fps <= 0.0 or count <= 0:
		return lock_duration_cap_s
	var clip_len: float = float(count) / fps
	return minf(clip_len, lock_duration_cap_s)


func _on_anim_finished() -> void:
	# The one-shot clip ended → return to idle/walk selection next _process, and
	# release any clip-driven lock immediately (the body frees on the same frame).
	if _current_action != &"" \
			and _sprite.animation == StringName("%s_%s" % [_current_action, _current_dir]):
		_current_action = &""
		if lock_mode == LockMode.CLIP_DRIVEN:
			_lock_remaining = 0.0


# --- N2 art swap (N1 listens; N2 emits) --------------------------------------

func _on_art_toggled(enabled: bool) -> void:
	_art_on = enabled
	if not enabled:
		# Release any in-flight lock + action immediately so the greybox returns to
		# exact M1.6 feel with no lingering root.
		_lock_remaining = 0.0
		_current_action = &""
	_apply_art_visibility()


func _apply_art_visibility() -> void:
	_sprite.visible = _art_on
	if not _art_on:
		_sprite.stop()
	# Greybox: hide both nodes when art is ON, show them when art is OFF (OQ-8).
	var vis := _player.get_node_or_null("Visual")
	if vis != null:
		vis.visible = not _art_on
	var nose := _player.get_node_or_null("Nose")
	if nose != null:
		nose.visible = not _art_on


# --- Pure, headless-unit-testable helpers (the N1 test seam) ------------------
# Mirror Player.step_velocity / resolve_aim: no node/tree/physics access, no side
# effects, static so the headless test calls them with no instance.

## Pure: angle of `facing` → one of the 8 DIRS suffixes, with angular hysteresis.
## Keeps `current` unless a different sector beats it by > DIR_HYSTERESIS_DEG,
## killing diagonal flicker when facing hovers on a 22.5° sector boundary. A ZERO
## facing holds `current` (the dir is never undefined). Screen space: +x = east
## (0°), +y = south (90° DOWN).
static func quantize_dir(facing: Vector2, current: StringName) -> StringName:
	if facing == Vector2.ZERO:
		return current
	var deg: float = rad_to_deg(facing.angle())
	var idx: int = int(round(deg / 45.0)) % 8
	if idx < 0:
		idx += 8
	var candidate: StringName = DIRS[idx]
	if candidate == current:
		return current
	# Hysteresis: only switch if the candidate's center beats the current dir's
	# center by more than the band. Compare the angular distance from `facing` to
	# each sector center; the candidate must win by > DIR_HYSTERESIS_DEG.
	var cur_idx: int = DIRS.find(current)
	if cur_idx == -1:
		return candidate   # current is not a known dir → adopt the candidate
	var d_candidate: float = _angle_dist_deg(deg, idx * 45.0)
	var d_current: float = _angle_dist_deg(deg, cur_idx * 45.0)
	if d_current - d_candidate > DIR_HYSTERESIS_DEG:
		return candidate
	return current


## Pure: smallest absolute angular distance (deg) between two angles, wrapped to
## [-180, 180]. Used by quantize_dir's hysteresis band.
static func _angle_dist_deg(a: float, b: float) -> float:
	var d: float = fmod(a - b + 180.0, 360.0)
	if d < 0.0:
		d += 360.0
	return absf(d - 180.0)


## Pure: pick the clip family. An action one-shot (pickup/throw) owns the sprite
## while set; else walk above the speed threshold (but never while locked — a locked
## player reads idle/action, never a walk-in-place), else idle.
static func select_state(velocity: Vector2, locked: bool, action: StringName) -> StringName:
	if action != &"":
		return action
	if not locked and velocity.length() > WALK_SPEED_THRESHOLD:
		return &"walk"
	return &"idle"
