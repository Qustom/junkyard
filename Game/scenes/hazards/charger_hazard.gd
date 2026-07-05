class_name ChargerHazard
extends CharacterBody2D
## ChargerHazard — "The Wrecker" (S6a, M1.9). A junkyard auto-crusher that came
## through half-alive: it sleeps compacted in the scrap, winds its ram back when you
## get close (telegraph), slams forward in a dead-straight line (lethal dash), then
## has to re-pressurize (recover — the throw-punish window). Fiction + name ratified
## D-RAT-2; the mechanical id stays &"charger" (telemetry/tests are name-stable).
##
## THE PHASE-E PROOF HOST: this shell is the S2 Actor-host family skeleton verbatim
## (per-frame guard, self-timed run clock, fixed component tick order, snapshot at
## setup) — the behavior lives in the reused component set + the ONE new ChargeLane:
##   ProximityTrigger (wake) + TelegraphFSM (tells) + LethalContact (&"external"
##   swept-contact kill: emit-always + L5 kills gate + BUG6 latch) +
##   ThrowInteraction (&"die") + ChargeLane (the three-beat FSM — NEW).
##
## DECK-DRIVEN KNOBS (the new-def lane): unlike the legacy hazards (which snapshot
## RunConfig fields), the Charger's tuning arrives as the def's params bag via
## spawn_ctx["params"] — the EncounterBuilder's ctx merge of charger.tres params +
## rc.param_overrides (S3 §Q6(ii)). DEFAULTS below MUST mirror charger.tres so a
## bare direct-test setup() behaves like the authored def (test_charger pins this).
##
## Collision: body on layer `hazard` (16), mask `world` (2) ONLY — walls stop the
## dash; the kill is ChargeLane's deterministic swept script test, never physics
## overlap. Root node name / class registered for the S2 telemetry-kind seam
## (get_def_id() → &"charger").
##
## ALL-OFF / BAND GATING: ships OFF — not in RunConfig.oppositions_enabled, not in
## the default play preset, not in band_greybox's deck; min_band = 2 hard-gates it
## to band_two (D-RAT-2: band-2-exclusive in M1.9). With the shipped default this
## scene is NEVER loaded (charger.tres is the only referencer), so the permanent
## all-off fingerprint e943ac9c8bc1 is untouched. Never touches the global RNG autoload.

## Greybox tell palette (S6a spec §2.7 starting values — Director/character-animator
## ratify the final set-level palette at the gate, OQ-8). Distinct from R1
## (grey-blue/red diamond), pingpong (amber box), spike (steel-cyan star), bomb
## (orange-pulse circle) by silhouette (directional WEDGE) + the three-beat rhythm.
const COLOR_DORMANT := Color(0.45, 0.4, 0.35)        # rust-steel — asleep in the scrap
const COLOR_TELE_FROM := Color(0.95, 0.55, 0.15)     # amber, escalating…
const COLOR_TELE_TO := Color(0.95, 0.2, 0.2)         # …to red over telegraph_s
const COLOR_CHARGE := Color(0.95, 0.15, 0.15)        # alarm red — lethal contact NOW
const COLOR_RECOVER := Color(0.5, 0.55, 0.6)         # stunned grey-blue — hit me
const COLOR_LANE := Color(0.95, 0.25, 0.15, 0.22)    # translucent committed-lane strip

## Code fallbacks for a direct setup() with no spawn_ctx["params"] — MUST mirror the
## authored charger.tres params (the entity-read keys; base_count/count_per_depth
## are builder-read spawn-card keys and never reach the entity). test_charger
## asserts def.params[k] == DEFAULTS[k] for every key here (no silent drift).
const DEFAULTS := {
	"aggro_range": 400.0,
	"telegraph_s": 0.5,
	"charge_speed": 700.0,
	"charge_max_dist": 400.0,
	"recover_s": 1.2,
	"cooldown_s": 0.6,
	"lane_width": 28.0,
	"lock_at_telegraph_start": true,
	"throwable_while_charging": true,
	"wall_crash_recover_mult": 1.0,
	"kills": true,
}

var _cfg: RunConfig                  # snapshot of the run config at setup (guard only)
var _player: Node2D                  # resolved at setup via setup()'s arg
var _spawn_time := 0.0               # self-timed run clock (host-owned, R1 §4 pattern)
var _lane_len := 0.0                 # snapshotted for the telegraph lane strip
var _lane_w := 0.0

var _prox: ProximityTrigger = null
var _fsm: TelegraphFSM = null
var _lethal: LethalContact = null
var _throw: ThrowInteraction = null
var _lane: ChargeLane = null

@onready var _tell: Polygon2D = $Tell            # the directional wedge (rotates to the lane)
@onready var _lane_rect: Polygon2D = $LaneRect   # the telegraphed "you will be hit here" strip


func _ready() -> void:
	# Q4: adopt .tscn-declared components when present, instance defaults otherwise.
	# The refs below fix the tick order regardless of child declaration order.
	_prox = OppositionComponent.acquire(self, ProximityTrigger) as ProximityTrigger
	_fsm = OppositionComponent.acquire(self, TelegraphFSM) as TelegraphFSM
	_lethal = OppositionComponent.acquire(self, LethalContact) as LethalContact
	_throw = OppositionComponent.acquire(self, ThrowInteraction) as ThrowInteraction
	_lane = OppositionComponent.acquire(self, ChargeLane) as ChargeLane
	_fsm.tell = _tell
	_lane.prox = _prox                 # reused wake trigger (aggro_range → proximity_radius)
	_lane.lethal = _lethal             # reused &"external"-mode kill machinery
	_lane.on_state_changed = _on_lane_state


## Bind config + player + the per-instance spawn context (LOCKED family signature).
## The Charger reads spawn_ctx["params"] — the builder's ctx-merged def knob bag.
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_spawn_time = 0.0
	var p := _resolve_params(spawn_ctx)
	_lane_len = float(p["charge_max_dist"])
	_lane_w = float(p["lane_width"])
	_prox.bind(self, player, p, spawn_ctx)
	_fsm.bind(self, player, p, spawn_ctx)
	_lethal.bind(self, player, p, spawn_ctx)   # resets the BUG6 latch (re-setup safe)
	_throw.bind(self, player, p, spawn_ctx)
	_lane.bind(self, player, p, spawn_ctx)     # seats DORMANT (no host-hook fire)
	_seat_dormant_tell()


## New-def resolve order (the deck lane): spawn_ctx["params"] (charger.tres params +
## rc.param_overrides, merged by the EncounterBuilder) over the DEFAULTS mirror.
## The aggro knob doubles as the reused ProximityTrigger's proximity_radius.
func _resolve_params(spawn_ctx: Dictionary) -> Dictionary:
	var dp: Dictionary = spawn_ctx.get("params", {})
	var p: Dictionary = {}
	for key: String in DEFAULTS:
		p[key] = dp.get(key, DEFAULTS[key])
	p["proximity_radius"] = float(p["aggro_range"])
	p["def_id"] = &"charger"
	p["emit_family"] = &"new_hazard_killed"
	p["lethal_mode"] = &"external"
	p["latch_rearm"] = true
	p["throw_mode"] = &"die"
	return p


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return                                 # the family guard, verbatim
	_spawn_time += delta
	_lane.tick(delta)      # the three-beat FSM (drives LethalContact's external seam)
	_update_tell()         # presentation only (headless/paused-safe — color carries state)


## The host-owned self-timed run clock (both signal families share this timestamp).
func run_clock_ms() -> int:
	return int(_spawn_time * 1000.0)


## Stable telemetry/def id (Q5 rider — service-spawned nodes never fall back to the
## auto-uniquified node name; ThrownItem._hazard_kind reads this).
func get_def_id() -> StringName:
	return &"charger"


## The thrown-item death seam (Q5 locked shape). Mode &"die" returns false — the
## thrower performs the free. Dash-invulnerability never reaches here: out of the
## &"hazard" group, ThrownItem resolves _miss() before consulting this seam.
func resolve_throw_death(killer_ctx: Dictionary) -> bool:
	return _throw.resolve_throw_death(killer_ctx)


## Test/inspection seam: the ChargeLane state (ChargeLane.State values).
func lane_state() -> int:
	return _lane.get_state()


# --- Greybox tells (inline placeholder, D-RAT-4: no PixelLab, no sprite sheets) ------

## Per-frame presentation: aim the wedge + lane strip along the (locked) lane and run
## the amber→red escalation while telegraphing. Pure juice — ChargeLane's state +
## the hard color flips in _on_lane_state carry the read if the tree is paused.
func _update_tell() -> void:
	var s: int = _lane.get_state()
	if s == ChargeLane.State.TELEGRAPH or s == ChargeLane.State.CHARGE:
		var angle: float = _lane.get_lane_dir().angle()
		if _tell != null:
			_tell.rotation = angle
		if _lane_rect != null:
			_lane_rect.rotation = angle
		if s == ChargeLane.State.TELEGRAPH:
			_fsm.set_tell_color(COLOR_TELE_FROM.lerp(COLOR_TELE_TO, _lane.telegraph_progress()))


## ChargeLane transition hook: hard tell flips + the S0 generic telemetry rows.
## Vocabulary is S0's LOCKED set (S6a Correction 1): &"telegraph" for the wind-up,
## &"state" for every other transition (the pursuer patrol↔chase idiom). The
## emit-always contact row (&"hit_player") + the gated opposition_killed_player live
## in the reused LethalContact; &"spawned" is the SpawnService's; &"killed_by_throw"
## is the ThrownItem path's. No new EventBus signal, no new end-cause.
func _on_lane_state(state: int, wall_crash: bool) -> void:
	var depth: int = GameState.current_depth_index   # live within-band depth (BUG2)
	var run_t_ms: int = run_clock_ms()
	match state:
		ChargeLane.State.TELEGRAPH:
			if _lane_rect != null:
				# Draw the committed corridor: lane_width wide, charge_max_dist long,
				# from the ram outward along +X (the node rotates to the lane).
				_lane_rect.polygon = PackedVector2Array([
					Vector2(0.0, -_lane_w * 0.5), Vector2(_lane_len, -_lane_w * 0.5),
					Vector2(_lane_len, _lane_w * 0.5), Vector2(0.0, _lane_w * 0.5)])
				_lane_rect.color = COLOR_LANE
				_lane_rect.visible = true
			_fsm.set_tell_color(COLOR_TELE_FROM)
			_fsm.flash_scale(1.3, 0.08, 0.12)        # the rear-back wind-up flash
			EventBus.opposition_event.emit(&"charger", &"telegraph", depth, run_t_ms)
		ChargeLane.State.CHARGE:
			if _lane_rect != null:
				_lane_rect.visible = false           # the wedge itself is now the threat
			_fsm.set_tell_color(COLOR_CHARGE)
			EventBus.opposition_event.emit(&"charger", &"state", depth, run_t_ms)
		ChargeLane.State.RECOVER:
			_fsm.set_tell_color(COLOR_RECOVER)
			# A wall-crash recovery flashes harder/longer — the bait-into-wall payoff
			# tell (D-RAT-2 / OQ-7).
			if wall_crash:
				_fsm.flash_scale(1.6, 0.06, 0.2)
			else:
				_fsm.flash_scale(1.2, 0.06, 0.12)
			EventBus.opposition_event.emit(&"charger", &"state", depth, run_t_ms)
		ChargeLane.State.DORMANT:
			_seat_dormant_tell()
			EventBus.opposition_event.emit(&"charger", &"state", depth, run_t_ms)


func _seat_dormant_tell() -> void:
	_fsm.set_tell_color(COLOR_DORMANT)
	if _lane_rect != null:
		_lane_rect.visible = false
