class_name HazardEntity
extends CharacterBody2D
## HazardEntity (R1, M1.1) — the greybox "pursuing / awakening hazard": a throwaway
## colored shape that wakes up the deeper or longer the player goes and chases them,
## ending the run if it catches them.
##
## THROWAWAY GREYBOX, not the M2 enemy-AI slice (R1 spec §0). No combat, no health,
## no pathfinding/navmesh/behaviour-tree/steering library — just a CharacterBody2D
## that lerps straight at the player via move_and_slide() (walls stop it; getting
## stuck behind geometry is a *feature*, a partial refuge — R1 §2.3).
##
## READS ONLY, never widens locked contracts (R1 §0):
##   - reads GameState.active_run_config (R0) for its r1_* knobs (snapshotted at setup);
##   - reads GameState.current_depth_index (BUG2) live for the awaken trigger + speed math;
##   - EMITS the pre-declared EventBus.hazard_awoke / hazard_caught (never edits event_bus.gd);
##   - routes a fatal catch through the EXISTING GameState.fail_run(&"death") — no new
##     end path, no local "already ended" guard (GameState's _run_ended guard owns
##     idempotency across hazards + extract; R1 §2.4 / §5 idempotency note).
##
## ALL-OFF: with r1_enabled = false the spawn seam never instantiates this node, so
## the M1.0 baseline is byte-for-byte unchanged (no node, no telemetry, no behaviour).
##
## Collision: body on layer `hazard` (5), masks `world` (2) ONLY — walls stop it; it
## does NOT mask `player` (catch is a script distance test, deterministic — §9 Q3) and
## does NOT mask `hazard` (multiple hazards never collide/block each other — §9 Q3).

enum State { DORMANT, AWAKE }

## Greybox tell colors (character-animator inline contribution, R1 §3). Cool/desaturated
## when dormant → hot/alarm-red the frame it wakes. A hard color flip is acceptable; we
## add a one-shot wake-flash scale Tween on top so the awaken beat reads.
const COLOR_DORMANT := Color(0.35, 0.4, 0.5)    # dim grey-blue, "asleep"
const COLOR_AWAKE := Color(0.9, 0.2, 0.2)       # alarm red, "hunting"

# --- Non-fatal catch tuning (r1_catch_kills = false path, §2.5 / §9 Q2) -------
# Self-contained constants — NOT RunConfig knobs (R0's schema has no non-fatal-cost
# fields; adding them is an out-of-scope R0 follow-up, §9). Knockback + brief stun +
# short cooldown, no other-system coupling.
const NONFATAL_KNOCKBACK_SPEED := 220.0   # px/s impulse pushed onto the player away from us
const NONFATAL_STUN_SECONDS := 0.35       # hazard freezes (doesn't chase) briefly after a hit
const NONFATAL_COOLDOWN_SECONDS := 1.0    # min seconds between catches (also stops per-frame re-fire)

# --- Anti-wall-stick closing (I2, §2.2 option (a) — REFUGE, Director FINAL) ----
# The hazard KEEPS wall collision (collision_mask `world`): walls are a deliberate
# partial hiding place — the player can break line-of-sight to escape. The fix for
# the M1.1 "wall-grind forever" bug (catch never fired) is a cheap de-pin: when the
# body barely moves while touching a wall, it is grinding it, so the NEXT frame we
# steer along the wall toward the player's side (walk to the opening) instead of
# grinding into it. NO pathfinding/navmesh — pure local move_and_slide collision math.
# Coupled with the r10 body shrink (.tscn), plain slide already mostly closes; this
# only handles the corner/perpendicular-grind residual.
#
# Greybox-internal feel knob (NOT a RunConfig field — like the non-fatal constants
# above; the Director edits it here). Below this fraction of the intended frame
# displacement WHILE touching a wall == "grinding" → trigger a de-pin. Too high →
# false de-pins in open rooms; too low → never de-pins (§2.2, Phase-3 correction 2).
const STALL_FRACTION := 0.35

var _cfg: RunConfig                  # snapshot of GameState.active_run_config at setup
var _state: int = State.DORMANT
var _time_in_band: float = 0.0       # seconds since setup (≈ band entry ≈ run start in M1)
var _player: Node2D                  # resolved at setup via the "player" group
var _pending_trigger: StringName = &"depth"   # which condition fired the awaken (telemetry)
var _catch_cooldown: float = 0.0     # >0 → can't catch again yet (non-fatal path)
var _stun: float = 0.0               # >0 → frozen, doesn't chase (non-fatal path)
var _depin_dir: Vector2 = Vector2.ZERO   # I2: if non-zero, NEXT AWAKE frame steers along this
                                          # wall-tangent (toward the player) instead of straight
                                          # at the player — the anti-wall-stick de-pin (§2.2 (a)).

@onready var _tell: Polygon2D = $Tell


## Bind the run config + player and seat the dormant tell. Called by the spawn seam
## (MainGame.start_new_run) right after add_child. Snapshots the config so a later
## active_run_config clear on run-end can't null it mid-frame.
func setup(cfg: RunConfig, player: Node2D) -> void:
	_cfg = cfg
	_player = player
	_state = State.DORMANT
	_time_in_band = 0.0
	_depin_dir = Vector2.ZERO
	if _tell != null:
		_set_tell_dormant()


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return
	_time_in_band += delta

	if _state == State.DORMANT:
		if _should_awaken():
			_awaken()
		return   # dormant: no movement, no catch test

	# --- AWAKE ---------------------------------------------------------------
	if _catch_cooldown > 0.0:
		_catch_cooldown -= delta
	if _stun > 0.0:
		# Briefly frozen after a non-fatal hit: bleed off any residual velocity, no chase.
		_stun -= delta
		velocity = velocity.move_toward(Vector2.ZERO, NONFATAL_KNOCKBACK_SPEED * delta)
		move_and_slide()
		return

	var depth: int = GameState.current_depth_index   # BUG2 live within-band depth
	var speed: float = _cfg.r1_chase_speed + _cfg.r1_speed_per_depth * float(depth)

	var to_player: Vector2 = _player.global_position - global_position
	var chase_dir: Vector2 = to_player.normalized() if to_player.length() > 0.001 else Vector2.ZERO

	# Anti-wall-stick (§2.2 (a)): if last frame we were grinding a wall, steer along the
	# wall-tangent toward the player THIS frame (walk to the opening, not into the wall);
	# else chase straight. One-shot — consumed each frame, re-armed below if still stuck.
	var dir: Vector2 = _depin_dir if _depin_dir != Vector2.ZERO else chase_dir
	_depin_dir = Vector2.ZERO

	velocity = dir * speed
	move_and_slide()   # walls (layer `world`) stop it; REFUGE intact — wall-collision kept.

	# Grind detection: barely moved this frame WHILE touching a wall → we're pinned.
	# Arm a de-pin for next frame: tangent along the contacted wall, oriented toward the
	# player. NO pathfinding — uses only move_and_slide's own collision results (§2.2).
	if get_slide_collision_count() > 0 \
			and get_real_velocity().length() < speed * STALL_FRACTION:
		var col := get_last_slide_collision()
		if col != null:
			var n: Vector2 = col.get_normal()
			var tangent: Vector2 = Vector2(-n.y, n.x)          # wall tangent
			if tangent.dot(to_player) < 0.0:
				tangent = -tangent                              # orient toward the player
			if tangent.length() > 0.001:
				_depin_dir = tangent.normalized()

	# Catch test: distance-based, deterministic, no physics overlap needed (§2.4).
	# Effective radius = flat r1_catch_radius + optional depth-scaled lunge (Q3 accepted,
	# Director FINAL). r1_catch_radius_per_depth defaults 0.0 → flat (all-off baseline).
	var catch_r: float = _cfg.r1_catch_radius + _cfg.r1_catch_radius_per_depth * float(depth)
	if _catch_cooldown <= 0.0 \
			and global_position.distance_to(_player.global_position) <= catch_r:
		_on_catch(depth)


## Awaken when depth threshold is reached OR linger time elapses — first to fire.
## Latches awake for the run (called only from the DORMANT branch).
func _should_awaken() -> bool:
	if GameState.current_depth_index >= _cfg.r1_depth_threshold:
		_pending_trigger = &"depth"
		return true
	if _cfg.r1_linger_seconds > 0.0 and _time_in_band >= _cfg.r1_linger_seconds:
		_pending_trigger = &"linger"
		return true
	return false


## Transition dormant → awake ONCE: flip the tell hot (+ wake flash) and emit
## hazard_awoke. No re-sleep — once awake it stays awake the whole run (§9 Q4).
func _awaken() -> void:
	_state = State.AWAKE
	_set_tell_awake()
	EventBus.hazard_awoke.emit(GameState.current_depth_index, _pending_trigger)


## A catch lands. Always emit hazard_caught (fatal or non-fatal). Fatal → call the
## EXISTING GameState.fail_run(&"death") and let its _run_ended guard absorb dupes
## (no local "already ended" bool that PREVENTS the call — §5 idempotency note).
func _on_catch(depth: int) -> void:
	# run_t_ms: BUG1's run clock isn't exposed read-only off GameState/Telemetry, so
	# per §4 / §9 Q5 we self-time from spawn (≈ band entry ≈ run start in single-band M1).
	var run_t_ms: int = int(_time_in_band * 1000.0)
	EventBus.hazard_caught.emit(depth, run_t_ms)
	if _cfg.r1_catch_kills:
		GameState.fail_run(&"death")   # existing end path; its _run_ended guard is the
		                                # single source of truth for run-end idempotency.
	else:
		_apply_nonfatal_catch()


## Non-fatal cost (§2.5 / §9 Q2): knock the player back, briefly stun ourselves, and
## go on a short cooldown so we can't re-catch every frame. Fully self-contained — NO
## fail_run, NO item drop / clock / exposure coupling (that would entangle R1 with
## R2/R3/R4 and muddy the single-variable test). The chase then resumes.
func _apply_nonfatal_catch() -> void:
	var away: Vector2 = (_player.global_position - global_position)
	away = away.normalized() if away.length() > 0.001 else Vector2.RIGHT
	# `velocity` is the standard CharacterBody2D field — setting it on the player is a
	# read/write of an engine member, not an edit to player.gd. The player's own
	# move_and_slide carries the impulse; friction bleeds it off next frame.
	if _player is CharacterBody2D:
		(_player as CharacterBody2D).velocity = away * NONFATAL_KNOCKBACK_SPEED
	_stun = NONFATAL_STUN_SECONDS
	_catch_cooldown = NONFATAL_COOLDOWN_SECONDS


# --- Greybox tell (inline placeholder, no sprite sheets / AnimationTree) ------

func _set_tell_dormant() -> void:
	if _tell != null:
		_tell.color = COLOR_DORMANT


func _set_tell_awake() -> void:
	if _tell == null:
		return
	_tell.color = COLOR_AWAKE
	# One-shot "wake" flash: a quick scale-up-and-settle so the player registers the
	# beat. Over-scope-safe — if the tree is paused/headless the color flip already
	# carries the state; the Tween is pure juice.
	var tw := create_tween()
	tw.tween_property(_tell, "scale", Vector2(1.4, 1.4), 0.08)
	tw.tween_property(_tell, "scale", Vector2.ONE, 0.12)
