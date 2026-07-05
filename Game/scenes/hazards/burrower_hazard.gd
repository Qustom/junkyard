class_name BurrowerHazard
extends CharacterBody2D
## BurrowerHazard — "Sinkmaw" (T2b, M1.10). A half-buried scrap-auger left running in
## the cave floor: it tracks the vibration of your footsteps while sunk (a slow floor
## ring that ignores walls), winds up (the floor shivers — the telegraph), then
## breaches to snap at the surface before sinking to re-align. The mechanical id stays
## &"burrower" (telemetry/tests are name-stable); the fiction name is display_name.
##
## THE PHASE-E PROOF HOST (phased vulnerability): this shell is the S2 Actor-host
## family skeleton verbatim (per-frame guard, self-timed run clock, fixed component
## tick order, snapshot at setup) — the behaviour lives in the reused component set +
## the ONE new BurrowCycle:
##   LethalContact (&"external" static-radius kill: emit-always + L5 kills gate + BUG6
##   latch) + ThrowInteraction (&"die", reachable only while surfaced) +
##   TelegraphFSM (the decal throb) + BurrowCycle (the BURIED->TELEGRAPH->SURFACED
##   cycle — NEW).
##
## DECK-DRIVEN KNOBS (the new-def lane): tuning arrives as the def's params bag via
## spawn_ctx["params"] — the EncounterBuilder's ctx merge of burrower.tres params +
## rc.param_overrides. DEFAULTS below MUST mirror burrower.tres so a bare direct-test
## setup() behaves like the authored def (test_burrower pins this).
##
## Collision: layer CYCLES 0<->16 per-phase (BurrowCycle owns it — buried = layer 0 so
## a throw passes clean through + contact is non-lethal; restored on surface); mask
## world(2) but the buried movement is a direct-translate (never move_and_slide'd), so
## walls are ignored underground. The kill is BurrowCycle's deterministic static-radius
## script test, never physics overlap.
##
## ALL-OFF / BAND GATING: ships OFF — not in RunConfig.oppositions_enabled, not in the
## default play preset, not in band_greybox / band_two decks; min_band = 3 hard-gates
## it to band_three. With the shipped default this scene is NEVER loaded (burrower.tres
## is the only referencer), so the permanent all-off fingerprint e943ac9c8bc1 is
## untouched. NEVER references the global RNG autoload.

## Greybox palette (spec §7 — character-animator ratifies the final set at the gate).
## Distinct from every shipped hazard by SILHOUETTE: a low floor RING with no body for
## most of the cycle (charger wedge / splitter blob / R1 diamond / spike star all keep
## an ever-present body).
const COLOR_DECAL := Color(0.5, 0.35, 0.25, 0.35)      # dusty "disturbed earth" ring
const COLOR_DECAL_TELE := Color(0.95, 0.55, 0.15, 0.6)  # amber pulse — "about to pop"
const COLOR_BODY := Color(0.6, 0.42, 0.3)               # earthy breach mound
const COLOR_BODY_RIM := Color(0.95, 0.25, 0.2)          # hot rim — lethal NOW

## Code fallbacks for a direct setup() with no spawn_ctx["params"] — MUST mirror the
## authored burrower.tres entity params (base_count/count_per_depth are builder-read
## spawn-card keys and never reach the entity). test_burrower asserts
## def.params[k] == DEFAULTS[k] for every key here (no silent drift). kill_radius = 34
## per the Phase-3 physics correction (player mask 26 includes hazard 16; sum-of-radii
## ~30px held a 26px catch a safe-to-hug bollard).
const DEFAULTS := {
	"buried_s": 3.0,
	"surface_s": 1.2,
	"track_speed": 80.0,
	"telegraph_lead_s": 0.9,
	"kill_radius": 34.0,
	"lock_surface_at_telegraph": true,
	"kills": true,
}

var _cfg: RunConfig                  # snapshot of the run config at setup (guard only)
var _player: Node2D                  # resolved at setup via setup()'s arg
var _spawn_time := 0.0               # self-timed run clock (host-owned, R1 §4 pattern)

var _lethal: LethalContact = null
var _throw: ThrowInteraction = null
var _fsm: TelegraphFSM = null
var _cycle: BurrowCycle = null

@onready var _decal: Polygon2D = $Decal     # the buried ground ring (always present)
@onready var _bodyvis: Polygon2D = $Body    # the surfaced mound (hidden while buried)


func _ready() -> void:
	# Q4: adopt .tscn-declared components when present, instance defaults otherwise.
	# The refs below fix the tick order regardless of child declaration order.
	_lethal = OppositionComponent.acquire(self, LethalContact) as LethalContact
	_throw = OppositionComponent.acquire(self, ThrowInteraction) as ThrowInteraction
	_fsm = OppositionComponent.acquire(self, TelegraphFSM) as TelegraphFSM
	_cycle = OppositionComponent.acquire(self, BurrowCycle) as BurrowCycle
	_fsm.tell = _decal                 # the pulse throb plays on the DECAL
	_cycle.lethal = _lethal            # reused &"external"-mode kill machinery
	_cycle.on_state_changed = _on_phase


## Bind config + player + the per-instance spawn context (LOCKED family signature).
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_spawn_time = 0.0
	var p := _resolve_params(spawn_ctx)
	_lethal.bind(self, player, p, spawn_ctx)   # resets the BUG6 latch (re-setup safe)
	_throw.bind(self, player, p, spawn_ctx)    # &"die": reachable only while surfaced
	_fsm.bind(self, player, p, spawn_ctx)
	_cycle.bind(self, player, p, spawn_ctx)    # seats BURIED (layer 0, no host-hook fire)
	_seat_buried_visual()


## New-def resolve order (the deck lane): spawn_ctx["params"] (burrower.tres params +
## rc.param_overrides, merged by the EncounterBuilder) over the DEFAULTS mirror.
func _resolve_params(spawn_ctx: Dictionary) -> Dictionary:
	var dp: Dictionary = spawn_ctx.get("params", {})
	var p: Dictionary = {}
	for key: String in DEFAULTS:
		p[key] = dp.get(key, DEFAULTS[key])
	# LethalContact &"external" wiring (the ChargeLane resolve shape):
	p["def_id"] = &"burrower"
	p["emit_family"] = &"new_hazard_killed"
	p["lethal_mode"] = &"external"
	p["latch_rearm"] = true
	p["throw_mode"] = &"die"
	p["pulse_seconds"] = float(p["telegraph_lead_s"])   # TelegraphFSM throb basis
	return p


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return                                 # the family guard, verbatim
	_spawn_time += delta
	_cycle.tick(delta)      # the four-phase FSM (drives LethalContact's external seam)


## The host-owned self-timed run clock (both signal families share this timestamp).
func run_clock_ms() -> int:
	return int(_spawn_time * 1000.0)


## Stable telemetry/def id (service-spawned nodes never fall back to the auto-
## uniquified node name; ThrownItem._hazard_kind reads this).
func get_def_id() -> StringName:
	return &"burrower"


## The thrown-item death seam. Mode &"die" returns false — the thrower frees us. Only
## reachable while surfaced: buried the body is off collision_layer, so body_entered
## never fires against it.
func resolve_throw_death(killer_ctx: Dictionary) -> bool:
	return _throw.resolve_throw_death(killer_ctx)


## Test/inspection seam: the BurrowCycle phase (BurrowCycle.Phase values).
func phase() -> int:
	return _cycle.get_phase()


# --- Greybox tells (inline placeholder, no PixelLab, no sprite sheets) ---------------

## BurrowCycle transition hook: hard tell flips + the S0 LOCKED telemetry vocabulary
## (&"telegraph" for the wind-up, &"state" for every other transition). The emit-
## always contact row (&"hit_player") + the gated opposition_killed_player live in the
## reused LethalContact; &"spawned" is the SpawnService's; &"killed_by_throw" is the
## ThrownItem path's. No new EventBus signal, no new end-cause.
func _on_phase(next: int) -> void:
	var depth: int = GameState.current_depth_index   # live within-band depth (BUG2)
	var run_t_ms: int = run_clock_ms()
	match next:
		BurrowCycle.Phase.TELEGRAPH:
			if _decal != null:
				_decal.color = COLOR_DECAL_TELE
			_fsm.start_throb()      # the pulse (pure juice — the lead clock is BurrowCycle's)
			EventBus.opposition_event.emit(&"burrower", &"telegraph", depth, run_t_ms)
		BurrowCycle.Phase.SURFACED:
			_fsm.stop_throb()
			_show_surfaced_visual()
			EventBus.opposition_event.emit(&"burrower", &"state", depth, run_t_ms)
		BurrowCycle.Phase.BURIED:
			_fsm.stop_throb()
			_seat_buried_visual()
			EventBus.opposition_event.emit(&"burrower", &"state", depth, run_t_ms)


## BURIED/TELEGRAPH read: the floor ring, no body.
func _seat_buried_visual() -> void:
	if _decal != null:
		_decal.color = COLOR_DECAL
		_decal.visible = true
		_decal.scale = Vector2.ONE
	if _bodyvis != null:
		_bodyvis.visible = false


## SURFACED read: the breach mound pops up with a hot rim; the ring dims under it.
func _show_surfaced_visual() -> void:
	if _decal != null:
		_decal.color = COLOR_DECAL
		_decal.scale = Vector2.ONE
	if _bodyvis != null:
		_bodyvis.color = COLOR_BODY
		_bodyvis.visible = true
