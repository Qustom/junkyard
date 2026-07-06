class_name SentryHazard
extends CharacterBody2D
## SentryHazard — the lane-denier (U2b, M1.11). S2 Actor-host skeleton verbatim; the
## behaviour is the reused component set + the ONE new LaneWatch:
##   LethalContact(&"external", bolt-fed) + TelegraphFSM(lane flash) +
##   ThrowInteraction(&"die", always throw-killable) + LaneWatch(NEW).
##
## THE AT-RANGE / PROJECTILE PROOF HOST: a stationary emplacement watching one
## derived (or authored) lane — IDLE (lane strip readable, DR-4 always-visible) →
## WINDUP (authored windup_s flash; LOS-gated entry) → FIRE (component-owned bolt
## down the locked lane; wall-blocked, stop-on-first-hit, travel capped at the
## latched effective length) → COOLDOWN (the crossable gap) → IDLE.
##
## Collision: body on layer `hazard` (16), mask `world` (2). The body NEVER moves
## and is NEVER contact-lethal (only the bolt kills — approaching to throw is the
## intended counter); it stays in the &"hazard" group in EVERY state (permanent
## throw-disable, DR-4: "spend an item to open the lane"). id &"sentry".
##
## DECK-DRIVEN KNOBS (the new-def lane): tuning arrives as the def's params bag via
## spawn_ctx["params"] (sentry.tres params + DeckEntry + rc.param_overrides, merged
## by the EncounterBuilder). DEFAULTS below MUST mirror sentry.tres byte-for-byte
## (test_sentry pins it — no code/data drift).
##
## ALL-OFF / BAND GATING: ships OFF — not in RunConfig.oppositions_enabled, not in
## the default play preset, not in bands 1-3 decks; min_band = 4 hard-gates it to
## band_four (U2b OQ-5). With the shipped default this scene is NEVER loaded
## (sentry.tres is the only referencer), so the permanent all-off fingerprint
## e943ac9c8bc1 is untouched. Deterministic and RNG-free by construction.

## Greybox palette (U2b spec §2.7 starting values; character-animator inline greybox,
## D-RAT-4 norm — Director ratifies at the gate). Distinct from every shipped hazard
## by silhouette (a squat FIXED turret with a drawn sightline strip) + the bolt.
const COLOR_IDLE := Color(0.42, 0.45, 0.5)            # cold steel — watching
const COLOR_WINDUP := Color(0.95, 0.55, 0.15)         # amber flash — locking on
const COLOR_FIRE := Color(0.95, 0.15, 0.15)           # alarm red — firing
const COLOR_LANE := Color(0.9, 0.85, 0.3, 0.14)       # faint yellow sightline strip
const COLOR_LANE_HOT := Color(0.95, 0.2, 0.15, 0.3)   # hot strip during windup/fire
const COLOR_BOLT := Color(1.0, 0.9, 0.4)              # bright fast bolt

## Code fallbacks for a direct setup() with no spawn_ctx["params"] — MUST mirror the
## authored sentry.tres entity params (base_count/count_per_depth are builder-read
## spawn-card keys and never reach the entity). test_sentry asserts
## def.params[k] == DEFAULTS[k] for every key here (no silent drift).
const DEFAULTS := {
	"windup_s": 0.4,
	"cooldown_s": 1.2,
	"bolt_speed": 700.0,
	"lane_length": 480.0,
	"lane_width": 28.0,
	"lane_always_visible": true,
	"fire_on_body_edge": false,
	"lane_dir_deg": -1.0,
	"kills": true,
}

var _cfg: RunConfig                  # snapshot of the run config at setup (guard only)
var _player: Node2D                  # resolved at setup via setup()'s arg
var _spawn_time := 0.0               # self-timed run clock (host-owned, R1 §4 pattern)

var _fsm: TelegraphFSM = null
var _lethal: LethalContact = null
var _throw: ThrowInteraction = null
var _watch: LaneWatch = null

@onready var _body_vis: Polygon2D = $Body   # the squat turret silhouette (TelegraphFSM tell)
@onready var _lane_vis: Polygon2D = $Lane   # the sightline strip (LaneWatch-owned geometry)
@onready var _bolt_vis: Polygon2D = $Bolt   # the bolt (LaneWatch-owned, hidden at rest)


func _ready() -> void:
	# Q4: adopt .tscn-declared components when present, instance defaults otherwise.
	# The refs below fix the tick order regardless of child declaration order.
	_fsm = OppositionComponent.acquire(self, TelegraphFSM) as TelegraphFSM
	_lethal = OppositionComponent.acquire(self, LethalContact) as LethalContact
	_throw = OppositionComponent.acquire(self, ThrowInteraction) as ThrowInteraction
	_watch = OppositionComponent.acquire(self, LaneWatch) as LaneWatch
	_fsm.tell = _body_vis
	_watch.lethal = _lethal            # reused &"external"-mode kill machinery (bolt sweep)
	_watch.bolt = _bolt_vis
	_watch.lane_vis = _lane_vis
	_watch.on_state_changed = _on_state


## Bind config + player + the per-instance spawn context (LOCKED family signature).
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_spawn_time = 0.0
	var p := _resolve_params(spawn_ctx)
	_lethal.bind(self, player, p, spawn_ctx)   # resets the BUG6 latch (re-setup safe)
	_fsm.bind(self, player, p, spawn_ctx)
	_throw.bind(self, player, p, spawn_ctx)    # &"die": spend an item to open the lane
	_watch.bind(self, player, p, spawn_ctx)    # seats IDLE (lane derived on tick 2, A1)
	_seat_idle_visual()


## New-def resolve order (the deck lane): spawn_ctx["params"] over the DEFAULTS
## mirror; then the host->component FIXED flags — structural to "this def is a
## Sentry", not tuning (the charger_hazard._resolve_params precedent).
func _resolve_params(spawn_ctx: Dictionary) -> Dictionary:
	var dp: Dictionary = spawn_ctx.get("params", {})
	var p: Dictionary = {}
	for key: String in DEFAULTS:
		p[key] = dp.get(key, DEFAULTS[key])
	p["def_id"] = &"sentry"
	p["emit_family"] = &"new_hazard_killed"
	p["lethal_mode"] = &"external"
	p["latch_rearm"] = true
	p["throw_mode"] = &"die"
	p["pulse_seconds"] = float(p["windup_s"])
	return p


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return                                 # the family guard, verbatim
	_spawn_time += delta
	_watch.tick(delta)     # the four-phase FSM + bolt (drives LethalContact's seam)
	_update_lane_visual()  # presentation only (headless/paused-safe)


## The host-owned self-timed run clock (both signal families share this timestamp).
func run_clock_ms() -> int:
	return int(_spawn_time * 1000.0)


## Stable telemetry/def id (Q5 rider — ThrownItem._hazard_kind reads this).
func get_def_id() -> StringName:
	return &"sentry"


## The thrown-item death seam (Q5 locked shape). Mode &"die" returns false — the
## thrower performs the free (permanent lane-opening, DR-4).
func resolve_throw_death(killer_ctx: Dictionary) -> bool:
	return _throw.resolve_throw_death(killer_ctx)


# --- Test/inspection seams (the charger lane_state() idiom) --------------------------

func watch_state() -> int:
	return _watch.get_state()


func lane_dir() -> Vector2:
	return _watch.get_lane_dir()


func lane_len_eff() -> float:
	return _watch.lane_len_eff()


func lane_acquired() -> bool:
	return _watch.is_acquired()


func bolt_position() -> Vector2:
	return _watch.bolt_position()


# --- Greybox tells (inline placeholder, D-RAT-4: no PixelLab, no sprite sheets) ------

## Per-frame presentation: paint the lane strip faint/hot per state and honor the
## lane_always_visible telegraph mode (DR-4: always-visible route puzzle; the knob
## ships for an A/B). LaneWatch owns the strip GEOMETRY; this owns its read.
func _update_lane_visual() -> void:
	if _lane_vis == null:
		return
	if not _watch.is_acquired():
		_lane_vis.visible = false
		return
	var s: int = _watch.get_state()
	var hot: bool = s == LaneWatch.State.WINDUP or s == LaneWatch.State.FIRE
	_lane_vis.color = COLOR_LANE_HOT if hot else COLOR_LANE
	_lane_vis.visible = _watch.always_visible() or hot


## LaneWatch transition hook: hard tell flips + the S0 LOCKED telemetry vocabulary
## (&"telegraph" for the wind-up, &"state" for every other transition). The
## emit-always contact row (&"hit_player") + the gated opposition_killed_player live
## in the reused LethalContact; &"spawned" is the SpawnService's; &"killed_by_throw"
## is the ThrownItem path's. No new EventBus signal, no new end-cause.
func _on_state(next: int) -> void:
	var depth: int = GameState.current_depth_index   # live within-band depth (BUG2)
	var run_t_ms: int = run_clock_ms()
	match next:
		LaneWatch.State.WINDUP:
			_fsm.set_tell_color(COLOR_WINDUP)
			_fsm.flash_scale(1.3, 0.05, _watch.windup_s())   # amber lock-on ramp
			EventBus.opposition_event.emit(&"sentry", &"telegraph", depth, run_t_ms)
		LaneWatch.State.FIRE:
			_fsm.set_tell_color(COLOR_FIRE)
			EventBus.opposition_event.emit(&"sentry", &"state", depth, run_t_ms)
		LaneWatch.State.COOLDOWN:
			_fsm.set_tell_color(COLOR_IDLE)
			EventBus.opposition_event.emit(&"sentry", &"state", depth, run_t_ms)
		LaneWatch.State.IDLE:
			_fsm.set_tell_color(COLOR_IDLE)
			EventBus.opposition_event.emit(&"sentry", &"state", depth, run_t_ms)


func _seat_idle_visual() -> void:
	_fsm.set_tell_color(COLOR_IDLE)
	if _lane_vis != null:
		_lane_vis.color = COLOR_LANE
		_lane_vis.visible = false      # LaneWatch redraws + shows it at acquisition
	if _bolt_vis != null:
		_bolt_vis.visible = false
		_bolt_vis.color = COLOR_BOLT
