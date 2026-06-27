class_name BombHazard
extends Node2D
## BombHazard (K5b, M1.4) — a stationary greybox proximity bomb. Sits inert showing an
## idle proximity ring; when the player's centre crosses hbomb_proximity_radius it COMMITS
## and pulses for hbomb_pulse_seconds (~2s, accelerating throb), then detonates: player
## within hbomb_blast_radius at the detonation frame => death; else it fizzles.
##
## THROWAWAY GREYBOX, not the M2 enemy-AI slice. No health, no movement, no pathfinding,
## no collision shape — it is a position + two Polygon2D tells + a distance-test state
## machine. The player walks over it; a bomb is not a wall.
##
## READS ONLY, never widens locked contracts:
##   - snapshots the RunConfig (its hbomb_* knobs) at setup (so a later active_run_config
##     clear on run-end can't null it mid-frame — the R1 discipline, hazard_entity.gd:83-91);
##   - reads GameState.current_depth_index live for the telemetry depth;
##   - EMITS the pre-declared EventBus.bomb_pulse_started (on arm) and
##     EventBus.new_hazard_killed(&"bomb", …) (on a FATAL detonation) — never edits event_bus.gd;
##   - routes a fatal blast through the EXISTING GameState.fail_run(&"death") — no new end
##     path, no local "already ended" guard (GameState._run_ended owns idempotency across
##     hazards + extract; multiple bombs detonating the same frame are absorbed for free).
##
## ALL-OFF: with hbomb_enabled = false the spawn seam (K5i) never instantiates this node,
## so the M1.0 baseline is byte-for-byte unchanged (fp=e943ac9c8bc1) — no node, no telemetry,
## no behaviour. Placement is pure run-state, never feeds fingerprint().
##
## Determinism: proximity + blast are SCRIPT DISTANCE TESTS (mirrors R1,
## hazard_entity.gd:24-25/:143-147), driven by an accumulated _pulse_t float in
## _physics_process — NEVER by a tween finished-signal. The tweens are pure juice; the
## state machine and its fatal logic run correctly headless/paused.
##
## COMMITTED, no-defuse (Director-FINAL, K5b Resolved Decisions Q2): once the pulse starts,
## leaving the proximity ring does NOT cancel it. The pulse window is the player's escape
## window — they must run clear of the (smaller) BLAST radius, not the proximity ring (Q3:
## hbomb_proximity_radius >= hbomb_blast_radius is the telegraph-generosity invariant).

enum State { IDLE, PULSING, EXPLODED }

## Greybox tell colors (inline placeholder; mirrors R1's palette idiom, hazard_entity.gd:32-33).
const COLOR_IDLE := Color(0.45, 0.45, 0.55, 0.5)   # dim translucent — "dormant ring"
const COLOR_ARMING := Color(0.95, 0.75, 0.2)        # amber — "pulsing, about to blow"
const COLOR_BLAST := Color(1.0, 0.25, 0.1)          # hot orange-red — "detonation flash"

const _RING_SEGMENTS := 24      # polygon segments approximating the idle proximity ring

var _cfg: RunConfig                  # snapshot of GameState.active_run_config at setup
var _state: int = State.IDLE
var _player: Node2D                  # resolved at setup via the "player" group
var _pulse_t: float = 0.0            # seconds since arming (drives detonation deterministically)
var _time_alive: float = 0.0         # seconds since setup (≈ spawn); self-timed run_t_ms (R1 §4)
var _pulse_tween: Tween              # the accelerating throb (juice only; never gates logic)

@onready var _ring: Polygon2D = $IdleRing     # faint proximity-radius ring (the telegraph)
@onready var _core: Polygon2D = $Core         # the bomb body (throbs while pulsing)


## Bind config + player and seat the IDLE ring sized to the proximity radius. Called by the
## K5i spawn loop right after add_child (mirrors hazard_entity.setup, :83-91).
## spawn_ctx is the LOCKED family signature's third param; the bomb IGNORES it — its blast
## is radial and confined by hbomb_blast_radius, not by room walls, so it needs only its
## world position (set by K5i via global_position).
func setup(cfg: RunConfig, player: Node2D, _spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_state = State.IDLE
	_pulse_t = 0.0
	_time_alive = 0.0
	if _ring != null:
		_draw_idle_ring(cfg.hbomb_proximity_radius)   # sized to the actual telegraph radius
	_set_tell_idle()


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return
	_time_alive += delta

	match _state:
		State.IDLE:
			# Arm on the RISING edge into the proximity ring. Distance to the player CENTRE
			# (player body is radius 14; the ring is generous-by-design — Q3). 0 radius = inert.
			if _cfg.hbomb_proximity_radius > 0.0:
				var d := global_position.distance_to(_player.global_position)
				if d <= _cfg.hbomb_proximity_radius:
					_arm()
		State.PULSING:
			# COMMITTED once-armed (Director-FINAL, Q2): leaving the ring does NOT defuse.
			# Detonation is _pulse_t-driven (deterministic), NOT a tween callback (headless-safe).
			_pulse_t += delta
			if _pulse_t >= _cfg.hbomb_pulse_seconds:
				_detonate()
		State.EXPLODED:
			pass   # one-shot terminal (Q4): frees itself after the explode flash


## IDLE -> PULSING once: amber flash + start the accelerating throb, emit bomb_pulse_started.
func _arm() -> void:
	_state = State.PULSING
	_pulse_t = 0.0
	_set_tell_arming()
	_start_pulse_tween()                          # juice only — detonation is _pulse_t-driven
	EventBus.bomb_pulse_started.emit(GameState.current_depth_index, _run_t_ms())


## PULSING -> EXPLODED: distance test at the detonation frame. Inside blast => fatal via the
## EXISTING end path (GameState._run_ended absorbs same-frame dupes) + the new_hazard_killed
## telemetry row. A fizzle (player outside blast) emits NO kill row (the K5b Resolved-Decisions
## "no separate bomb_detonated" contract — fizzles are derivable from the pulse-vs-kill counts).
## One-shot: frees itself after the explode flash so no lingering ring clutter (Q4).
func _detonate() -> void:
	_state = State.EXPLODED
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	var d := global_position.distance_to(_player.global_position)
	var hit: bool = _cfg.hbomb_blast_radius > 0.0 and d <= _cfg.hbomb_blast_radius
	_flash_blast()                                # brief explode flash (juice; runs even if fatal)
	if hit:
		EventBus.new_hazard_killed.emit(&"bomb", GameState.current_depth_index, _run_t_ms())  # emit-always
		# L5: only the kill is gated (mirrors hazard_entity.gd's r1_catch_kills). Default true =
		# today's lethal behaviour; false = the bomb still arms/pulses/flashes (the _flash_blast +
		# queue_free below sit outside this guard) but a blast-radius hit does NOT end the run.
		if _cfg.hbomb_kills:
			GameState.fail_run(&"death")          # existing end path; _run_ended owns idempotency
	# One-shot (Q4): free after the flash (~0.2s) so the node leaves no lingering ring.
	# Run-state — _clear_band() would also free it on run-end.
	get_tree().create_timer(0.2).timeout.connect(queue_free)


## Self-timed run clock (R1 §4 / hazard_entity.gd:185-187): BUG1's run clock isn't exposed
## read-only, so we self-time from spawn (≈ band entry ≈ run start in single-band M1).
func _run_t_ms() -> int:
	return int(_time_alive * 1000.0)


# --- Greybox tells (inline placeholders; character-animator polish deferred) ----

func _set_tell_idle() -> void:
	if _core != null:
		_core.color = COLOR_IDLE
	if _ring != null:
		_ring.color = Color(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, 0.18)   # faint telegraph


func _set_tell_arming() -> void:
	if _core != null:
		_core.color = COLOR_ARMING


## Accelerating pulse: a looping scale throb whose period SHRINKS as detonation nears so the
## tempo itself reads "about to blow" (the R1 create_tween idiom, chained + looped). Pure juice —
## if paused/headless the color carries the state and _pulse_t still drives _detonate().
func _start_pulse_tween() -> void:
	if _core == null:
		return
	_pulse_tween = create_tween().set_loops()     # loops until kill() in _detonate
	# A few throbs across the pulse window, each faster than the last (illustrative; anim tunes).
	var period := maxf(_cfg.hbomb_pulse_seconds, 0.1)
	for step in 4:
		var dur := (period / 8.0) * (1.0 - 0.18 * float(step))   # shrinking period
		_pulse_tween.tween_property(_core, "scale", Vector2(1.35, 1.35), dur * 0.5)
		_pulse_tween.tween_property(_core, "scale", Vector2.ONE, dur * 0.5)


## Brief one-shot explode flash (the R1 wake-flash shape: hot color + a quick scale pop).
func _flash_blast() -> void:
	if _core == null:
		return
	_core.color = COLOR_BLAST
	var tw := create_tween()
	tw.tween_property(_core, "scale", Vector2(2.2, 2.2), 0.06)
	tw.tween_property(_core, "modulate:a", 0.0, 0.12)


## Draw the faint idle ring as a polygon approximating a circle of radius r (the telegraph).
## Greybox — exact shape is the animator's call; a polygon ring is enough to read the radius.
func _draw_idle_ring(r: float) -> void:
	var pts := PackedVector2Array()
	var rr := maxf(r, 1.0)
	for i in _RING_SEGMENTS:
		var a := TAU * float(i) / float(_RING_SEGMENTS)
		pts.append(Vector2(cos(a), sin(a)) * rr)
	_ring.polygon = pts
