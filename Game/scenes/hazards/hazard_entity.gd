class_name HazardEntity
extends CharacterBody2D
## HazardEntity (R1, M1.1 · componentized S2, M1.9) — the greybox "pursuing /
## awakening hazard": a throwaway colored shape that wakes up the deeper or longer
## the player goes and chases them, ending the run if it catches them.
##
## S2 (M1.9): the internals now live in the shared opposition component set —
## DepthLingerTrigger (awaken condition) + ChaseMove (chase + I2 de-pin, verbatim) +
## PatrolMove (L2 room-bound pacer, verbatim) + LethalContact (&"radius_gated":
## depth-scaled catch radius, BUG6 latch + the cooldown conjunction handed in by
## the host, emit-always, L5 r1_catch_kills gate, non-fatal branch via handler) +
## TelegraphFSM (dormant/awake tell presentation) + ThrowInteraction (&"die").
##
## THE HOST KEEPS THE PER-FRAME SKELETON LINE-FOR-LINE (S2 Resolved Decisions Q1,
## binding): the family guard, the DORMANT branch + early return, the
## `_catch_cooldown` decrement BEFORE the stun early-return (a stunned pursuer
## keeps counting its cooldown down — the drift specimen the golden trace pins),
## the stun block, the room-bound mode switch, and every accumulator
## (`_time_in_band` / `_catch_cooldown` / `_stun`). OBSERVABLE BEHAVIOR IS
## BYTE/FRAME-IDENTICAL to the pre-component entity (golden frame-trace gated).
##
## READS ONLY, never widens locked contracts (R1 §0): snapshots its params from the
## deck lane's spawn_ctx["params"] bag at setup (V3b M1.12 — the pursuer is now a
## deck card like every modern hazard; the bespoke rc.r1_* knobs + the main_game R1
## machine were retired); reads GameState.current_depth_index (BUG2) live; EMITS the
## pre-declared EventBus signals (+ the S2 generic opposition_event twins); a fatal
## catch routes through the EXISTING GameState.fail_run(&"death") — no local "already
## ended" guard (GameState._run_ended owns idempotency).
##
## ALL-OFF: an all-off run leaves the band_greybox pursuer card NEUTRAL (base_count 0,
## count_per_depth 0 after the ctx-merge), so EncounterBuilder skips it — this node is
## never instantiated and the M1.0 baseline is byte-for-byte unchanged.
##
## Collision: body on layer `hazard` (5), masks `world` (2) ONLY — walls stop it
## (REFUGE intact); catch is a script distance test, never physics overlap.

enum State { DORMANT, AWAKE }

## Greybox tell colors. Cool/desaturated when dormant → hot/alarm-red on wake (the
## TelegraphFSM presentation block renders the flip + the one-shot wake flash).
const COLOR_DORMANT := Color(0.35, 0.4, 0.5)    # dim grey-blue, "asleep"
const COLOR_AWAKE := Color(0.9, 0.2, 0.2)       # alarm red, "hunting"

# --- Non-fatal catch tuning (catch_kills = false path) -------------------------
# Self-contained constants — NOT RunConfig knobs (Q7: feel constants never enter
# params). Knockback + brief stun + short cooldown, no other-system coupling.
const NONFATAL_KNOCKBACK_SPEED := 220.0   # px/s impulse pushed onto the player away from us
const NONFATAL_STUN_SECONDS := 0.35       # hazard freezes (doesn't chase) briefly after a hit
const NONFATAL_COOLDOWN_SECONDS := 1.0    # min seconds between catches (stops per-frame re-fire)

var _cfg: RunConfig                  # snapshot of GameState.active_run_config at setup
var _state: int = State.DORMANT
var _time_in_band: float = 0.0       # seconds since setup (host-side accumulator, Q1)
var _player: Node2D                  # resolved at setup
var _catch_cooldown: float = 0.0     # >0 → can't catch again yet (host-side timer, Q1)
var _stun: float = 0.0               # >0 → frozen, doesn't chase (host-side timer, Q1)

# L2: the spawn-room rect in WORLD space, set from spawn_ctx["room_bounds"]. Empty
# Rect2 (no area) == "no room known" → the spawn_room_only gate falls back to
# chase-everywhere (RD-4, never freeze/crash). Host-side: the mode switch reads it.
var _room_bounds: Rect2 = Rect2()
# L2 (V3b): the spawn-room-only mode flag, snapshotted from spawn_ctx["params"] at
# setup (was cfg.r1_spawn_room_only). The mode switch reads this snapshot per-frame.
var _spawn_room_only: bool = false
# L2: rising-edge latch for the opposition_event(&"state") telemetry mark (BUG6
# pattern — emit once per patrol↔chase transition). Empty == no state emitted yet.
var _last_pursuer_state: StringName = &""

var _trigger: DepthLingerTrigger = null
var _chase_c: ChaseMove = null
var _patrol_c: PatrolMove = null
var _lethal: LethalContact = null
var _telegraph: TelegraphFSM = null
var _throw: ThrowInteraction = null

@onready var _tell: Polygon2D = $Tell


func _ready() -> void:
	# Q4: adopt .tscn-declared components when present, instance defaults otherwise.
	# The refs fix the tick order in host code order, regardless of child order.
	_trigger = OppositionComponent.acquire(self, DepthLingerTrigger) as DepthLingerTrigger
	_chase_c = OppositionComponent.acquire(self, ChaseMove) as ChaseMove
	_patrol_c = OppositionComponent.acquire(self, PatrolMove) as PatrolMove
	_lethal = OppositionComponent.acquire(self, LethalContact) as LethalContact
	_telegraph = OppositionComponent.acquire(self, TelegraphFSM) as TelegraphFSM
	_throw = OppositionComponent.acquire(self, ThrowInteraction) as ThrowInteraction
	_telegraph.tell = _tell
	_lethal.nonfatal_handler = _apply_nonfatal_catch


## Bind the run config + player and seat the dormant tell (LOCKED family signature —
## back-compatible: an empty dict / 2-arg call works as before). Snapshots the
## config so a later active_run_config clear on run-end can't null it mid-frame.
## Reads spawn_ctx["room_bounds"] (Rect2, default empty) for the L2 room-bound mode.
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_state = State.DORMANT
	_time_in_band = 0.0
	_room_bounds = spawn_ctx.get("room_bounds", Rect2())
	_last_pursuer_state = &""
	var dp: Dictionary = spawn_ctx.get("params", {})
	_spawn_room_only = bool(dp.get("spawn_room_only", DEFAULTS.spawn_room_only))
	var p := _resolve_params(spawn_ctx)
	_trigger.bind(self, player, p, spawn_ctx)
	_chase_c.bind(self, player, p, spawn_ctx)    # resets the de-pin (legacy setup reset)
	_patrol_c.bind(self, player, p, spawn_ctx)   # derives the RNG-free patrol endpoints
	_lethal.bind(self, player, p, spawn_ctx)     # BUG6: a respawned hazard starts un-latched
	_telegraph.bind(self, player, p, spawn_ctx)
	_throw.bind(self, player, p, spawn_ctx)
	if _tell != null:
		_set_tell_dormant()


## V3b (M1.12): the pursuer reads its magnitudes from the deck lane's ctx-merged
## param bag (spawn_ctx["params"] — def params < DeckEntry overrides <
## rc.param_overrides, resolved by EncounterBuilder) exactly like the K5 entities,
## instead of the retired rc.r1_* knobs. DEFAULTS mirrors pursuer.tres::params (all
## neutral) + catch_kills, so a missing key = neutral behaviour (all-off byte-clean).
## The input keys (catch_radius / catch_radius_per_depth / catch_kills) map to the
## entity's output keys (contact_radius / contact_radius_per_depth / kills) — the
## SAME mapping the old cfg.r1_* path used, so behaviour is byte-identical.
const DEFAULTS := {
	"depth_threshold": 0, "linger_seconds": 0.0, "chase_speed": 0.0, "speed_per_depth": 0.0,
	"catch_radius": 0.0, "catch_radius_per_depth": 0.0, "patrol_speed": 0.0,
	"spawn_room_only": false, "catch_kills": false,
}
func _resolve_params(spawn_ctx: Dictionary) -> Dictionary:
	var dp: Dictionary = spawn_ctx.get("params", {})
	return {
		"depth_threshold": int(dp.get("depth_threshold", DEFAULTS.depth_threshold)),
		"linger_seconds": float(dp.get("linger_seconds", DEFAULTS.linger_seconds)),
		"chase_speed": float(dp.get("chase_speed", DEFAULTS.chase_speed)),
		"speed_per_depth": float(dp.get("speed_per_depth", DEFAULTS.speed_per_depth)),
		"contact_radius": float(dp.get("catch_radius", DEFAULTS.catch_radius)),
		"contact_radius_per_depth": float(dp.get("catch_radius_per_depth", DEFAULTS.catch_radius_per_depth)),
		"patrol_speed": float(dp.get("patrol_speed", DEFAULTS.patrol_speed)),
		"kills": bool(dp.get("catch_kills", DEFAULTS.catch_kills)),
		"def_id": &"pursuer",
		"lethal_mode": &"radius_gated",
		"latch_rearm": true,
		"throw_mode": &"die",
	}


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return                                 # the family guard, verbatim
	_time_in_band += delta

	if _state == State.DORMANT:
		if _trigger.should_awaken(GameState.current_depth_index, _time_in_band):
			_awaken()
		return   # dormant: no movement, no catch test

	# --- AWAKE ---------------------------------------------------------------
	# Q1 (binding): the cooldown decrement fires BEFORE the stun early-return — a
	# stunned pursuer keeps counting its cooldown down (host-side timers, verbatim).
	if _catch_cooldown > 0.0:
		_catch_cooldown -= delta
	if _stun > 0.0:
		# Briefly frozen after a non-fatal hit: bleed off residual velocity, no chase.
		_stun -= delta
		velocity = velocity.move_toward(Vector2.ZERO, NONFATAL_KNOCKBACK_SPEED * delta)
		move_and_slide()
		return

	# L2: spawn-room-bound mode. ON only when spawn_room_only AND we learned a
	# real room rect (RD-4: empty bounds fall back to chase-everywhere). The player
	# IN the room → chase (exact chase+catch); OUT → slow patrol, no catch.
	if _spawn_room_only and _room_bounds.has_area():
		var in_room: bool = _room_bounds.has_point(_player.global_position)
		_emit_pursuer_state(&"chase" if in_room else &"patrol")
		if in_room:
			_chase_and_catch(delta)
		else:
			# Patrolling re-arms the catch latch so a re-entry's first in-room frame
			# can catch cleanly (the original _patrol() first line, at the same site).
			_lethal.rearm_latch()
			_patrol_c.tick_patrol(delta)
		return

	# r1_spawn_room_only OFF (or no bounds) → the exact chase-everywhere path.
	_chase_and_catch(delta)


## The legacy _chase() call shape: ONE live depth read at the top (BUG2), the
## movement block (ChaseMove, verbatim), then the catch test (LethalContact) with
## the cooldown conjunction handed in — same order, no intervening work. CATCH
## lives ONLY here (RD-2): a patrolling pursuer never runs the distance/latch test.
func _chase_and_catch(delta: float) -> void:
	var depth: int = GameState.current_depth_index
	_chase_c.tick_chase(delta, depth)
	_lethal.test_radius_catch(depth, _catch_cooldown <= 0.0)


## L2: rising-edge-only telemetry mark for the patrol↔chase flip (BUG6 latch
## pattern). Self-times run_t_ms from the host clock. Only emitted in room-bound
## mode (the caller); the chase-everywhere path never marks state. Emits the generic
## opposition_event(&"state") — the patrol/chase discriminant is not carried (V2:
## the legacy hazard_pursuer_state signal that carried it was retired; the transition
## count/timing is preserved on the &"state" event).
func _emit_pursuer_state(state: StringName) -> void:
	if state == _last_pursuer_state:
		return
	_last_pursuer_state = state
	var run_t_ms: int = int(_time_in_band * 1000.0)
	var depth: int = GameState.current_depth_index
	EventBus.opposition_event.emit(&"pursuer", &"state", depth, run_t_ms)


## Transition dormant → awake ONCE: flip the tell hot (+ wake flash) and emit the
## generic opposition_event(&"awoke"). No re-sleep — once awake it stays awake the
## whole run.
func _awaken() -> void:
	_state = State.AWAKE
	_set_tell_awake()
	var depth: int = GameState.current_depth_index
	EventBus.opposition_event.emit(&"pursuer", &"awoke", depth, run_clock_ms())


## The host-owned self-timed run clock (R1 §4: BUG1's run clock isn't exposed
## read-only, so we self-time from spawn ≈ band entry ≈ run start in M1). Both
## signal families share this timestamp.
func run_clock_ms() -> int:
	return int(_time_in_band * 1000.0)


func get_def_id() -> StringName:
	return &"pursuer"


## The thrown-item death seam (Q5 locked shape). Mode &"die" returns false — the
## thrower performs the free, byte-identical to the pre-seam behaviour.
func resolve_throw_death(killer_ctx: Dictionary) -> bool:
	return _throw.resolve_throw_death(killer_ctx)


## Non-fatal cost (catch_kills = false — LethalContact's nonfatal_handler):
## knock the player back, briefly stun ourselves, and go on a short cooldown so we
## can't re-catch every frame. Fully self-contained — NO fail_run, NO item drop /
## clock / exposure coupling. The chase then resumes. Host-side: it writes the
## host's stun/cooldown timers (Q1).
func _apply_nonfatal_catch() -> void:
	var away: Vector2 = (_player.global_position - global_position)
	away = away.normalized() if away.length() > 0.001 else Vector2.RIGHT
	# `velocity` is the standard CharacterBody2D field — setting it on the player is
	# a read/write of an engine member, not an edit to player.gd. The player's own
	# move_and_slide carries the impulse; friction bleeds it off next frame.
	if _player is CharacterBody2D:
		(_player as CharacterBody2D).velocity = away * NONFATAL_KNOCKBACK_SPEED
	_stun = NONFATAL_STUN_SECONDS
	_catch_cooldown = NONFATAL_COOLDOWN_SECONDS


# --- Greybox tell (rendered by the TelegraphFSM presentation block) ------------

func _set_tell_dormant() -> void:
	_telegraph.set_tell_color(COLOR_DORMANT)


func _set_tell_awake() -> void:
	_telegraph.set_tell_color(COLOR_AWAKE)
	# One-shot "wake" flash: a quick scale-up-and-settle so the player registers the
	# beat. Pure juice — if the tree is paused/headless the color flip carries the state.
	_telegraph.flash_scale(1.4, 0.08, 0.12)
