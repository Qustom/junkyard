class_name AmbusherHazard
extends CharacterBody2D
## AmbusherHazard — "The Lurker" (T2a, M1.10; FBM-A1 stalker rework). A thing that
## learned to look like the junk it lives in: it rests near-invisible among the cave
## scatter (a faint floor seam the only tell), springs up when you approach the loot
## (telegraph → lethal pounce at where you stood), then a slow exposed throw-window —
## and after that FIRST pounce it becomes a relentless STALKER: it re-hides (invisible +
## un-hittable, the floor-smudge tracking with it) and pursues you while hidden, closing
## to re-pounce again and again until you kill it in the moment it is exposed. It
## punishes the blind walk-up-and-grab, then hunts. Fiction/name is a T3/Director call;
## the mechanical id stays &"ambusher" (telemetry/tests name-stable — the Wrecker
## precedent).
##
## THE TG3 SCALABILITY PROOF HOST: this shell is the S2 Actor-host family skeleton
## verbatim (per-frame guard, self-timed run clock, fixed component tick order,
## snapshot at setup). The pounce is the REUSED S6a ChargeLane (telegraph → locked
## lethal dash → recover) and the hidden pursuit is the REUSED ChaseMove; the ONLY new
## artefact is the Concealment component:
##   ProximityTrigger (arm) + TelegraphFSM (tells) + LethalContact (&"external" swept
##   kill: emit-always + L5 kills gate + BUG6 latch) + ThrowInteraction (&"die") +
##   ChargeLane (pounce, REUSED) + ChaseMove (hidden pursuit, REUSED) + Concealment
##   (HIDDEN presentation + un-hittable gate + telegraph-wedge alpha — NEW).
##
## THE STALKER LOOP is HOST ORCHESTRATION, not a ChargeLane edit: after the first pounce
## (`_has_pounced`), every RECOVER → DORMANT re-hides (Concealment.hide_conceal) instead
## of springing a fresh trap, and while DORMANT the host ticks the REUSED ChaseMove to
## pursue the player (hidden, un-hittable, the floor-smudge tracking) — ChargeLane owns
## velocity in TELEGRAPH/CHARGE/RECOVER, ChaseMove owns it only in DORMANT. The DORMANT→
## TELEGRAPH-on-proximity wake + ChaseMove closing the gap re-pounces automatically;
## re_hide_s (→ ChargeLane's cooldown_s, default 0.6s) is the inter-pounce breath so it
## does not instantly re-spring. The loop runs until a throw kills it in the exposed
## window. ChargeLane / ChaseMove are UNTOUCHED (zero shared-file edits — the whole point).
##
## Collision: layer hazard(16), mask world(2) at author time; Concealment.hide_conceal()
## at setup() then seats layer 0 (HIDDEN = clean pass-through, OQ-10 amendment 2). id
## &"ambusher". Ships OFF-default (not in oppositions_enabled / the play preset / any
## shallow deck; band-3-native via min_band=3 + band_three's deck), so this scene is
## NEVER loaded with the shipped default — the all-off fingerprint e943ac9c8bc1 holds.
## Never touches the global RNG autoload.

## Greybox tell palette (T2a spec §2.7 starting values — Director/character-animator
## ratify the final set-level palette at the gate, OQ-4). Distinct from R1
## (grey-blue/red diamond), pingpong (amber box), spike (steel-cyan star), bomb
## (orange-pulse circle), Charger (rust-steel directional WEDGE), and Splitter by a
## compact non-directional AMBUSH silhouette + its concealment signature (invisible at
## rest, a faint floor tell the only read).
const COLOR_ARMED := Color(0.95, 0.5, 0.15)      # hot amber — the spring
const COLOR_POUNCE := Color(0.95, 0.15, 0.15)    # alarm red — lethal contact NOW
const COLOR_EXPOSED := Color(0.5, 0.55, 0.6)     # stunned grey-blue — hit me

## Code fallbacks for a direct setup() with no spawn_ctx["params"] — MUST mirror the
## authored ambusher.tres params (the ENTITY-read keys; base_count/count_per_depth are
## builder-read spawn-card keys and never reach the entity). test_ambusher asserts
## def.params[k] == DEFAULTS[k] for every key here (no code/data drift).
const DEFAULTS := {
	"arm_radius": 90.0,
	"tell_lead_s": 0.45,
	"lunge_speed": 600.0,
	"lunge_dist": 140.0,
	"exposed_window_s": 1.5,
	"lunge_width": 28.0,
	"concealed_alpha": 0.0,
	"tell_alpha": 0.28,
	"re_hide_s": 0.6,
	"track_speed": 130.0,
	"kills": true,
}

var _cfg: RunConfig                  # snapshot of the run config at setup (guard only)
var _player: Node2D                  # resolved at setup via setup()'s arg
var _spawn_time := 0.0               # self-timed run clock (host-owned, R1 §4 pattern)

var _prox: ProximityTrigger = null
var _fsm: TelegraphFSM = null
var _lethal: LethalContact = null
var _throw: ThrowInteraction = null
var _lane: ChargeLane = null
var _chase: ChaseMove = null
var _conceal: Concealment = null

var _has_pounced := false            # host-owned latch: first pounce done → STALKER mode

@onready var _body: Polygon2D = $Body            # the springing silhouette (Concealment)
@onready var _tell: Polygon2D = $Tell            # the reveal/telegraph tell (TelegraphFSM)
@onready var _floor_tell: Polygon2D = $FloorTell # the faint HIDDEN floor decal (Concealment)


func _ready() -> void:
	# Q4: adopt .tscn-declared components when present, instance defaults otherwise.
	# The refs below fix the tick order regardless of child declaration order.
	_prox = OppositionComponent.acquire(self, ProximityTrigger) as ProximityTrigger
	_fsm = OppositionComponent.acquire(self, TelegraphFSM) as TelegraphFSM
	_lethal = OppositionComponent.acquire(self, LethalContact) as LethalContact
	_throw = OppositionComponent.acquire(self, ThrowInteraction) as ThrowInteraction
	_lane = OppositionComponent.acquire(self, ChargeLane) as ChargeLane
	_chase = OppositionComponent.acquire(self, ChaseMove) as ChaseMove
	_conceal = OppositionComponent.acquire(self, Concealment) as Concealment
	_fsm.tell = _tell
	_conceal.body = _body
	_conceal.floor_tell = _floor_tell
	_conceal.telegraph_tell = _tell    # Concealment gates the wedge's visibility (alpha)
	_lane.prox = _prox                 # reused wake trigger (arm_radius → proximity_radius)
	_lane.lethal = _lethal             # reused &"external"-mode kill machinery
	_lane.on_state_changed = _on_pounce_state


## Bind config + player + the per-instance spawn context (LOCKED family signature).
## The Ambusher reads spawn_ctx["params"] — the builder's ctx-merged def knob bag.
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_spawn_time = 0.0
	_has_pounced = false
	var p := _resolve_params(spawn_ctx)          # Ambusher keys → ChargeLane keys (+ fixed flags)
	_prox.bind(self, player, p, spawn_ctx)
	_fsm.bind(self, player, p, spawn_ctx)
	_lethal.bind(self, player, p, spawn_ctx)     # resets the BUG6 latch (re-setup safe)
	_throw.bind(self, player, p, spawn_ctx)
	_lane.bind(self, player, p, spawn_ctx)       # seats DORMANT (no host-hook fire)
	_chase.bind(self, player, p, spawn_ctx)      # hidden-pursuit movement (track_speed → chase_speed)
	_conceal.bind(self, player, p, spawn_ctx)
	# LOAD-BEARING (OQ-10 amendment 1): hide_conceal() LAST — ChargeLane._configure
	# added us to the "hazard" group at bind (charge_lane.gd:104); this seats HIDDEN
	# (layer 0 + out of group) AFTER, neutralising that bind-time add.
	_conceal.hide_conceal()


## New-def resolve order (the deck lane): spawn_ctx["params"] (ambusher.tres params +
## rc.param_overrides, merged by the EncounterBuilder) over the DEFAULTS mirror. The
## Ambusher-semantic keys are MAPPED to ChargeLane's expected keys (the charger's
## proximity_radius=aggro_range rename, generalized — keeps the generated menu legible).
func _resolve_params(spawn_ctx: Dictionary) -> Dictionary:
	var dp: Dictionary = spawn_ctx.get("params", {})
	var p: Dictionary = {}
	for key: String in DEFAULTS:
		p[key] = dp.get(key, DEFAULTS[key])
	# Ambusher-semantic → ChargeLane keys (+ ProximityTrigger's radius).
	p["aggro_range"] = float(p["arm_radius"])
	p["proximity_radius"] = float(p["arm_radius"])
	p["telegraph_s"] = float(p["tell_lead_s"])
	p["charge_speed"] = float(p["lunge_speed"])
	p["charge_max_dist"] = float(p["lunge_dist"])
	p["recover_s"] = float(p["exposed_window_s"])
	p["lane_width"] = float(p["lunge_width"])
	p["cooldown_s"] = float(p["re_hide_s"])      # inter-pounce breath (DORMANT cooldown)
	# Hidden-pursuit movement (REUSED ChaseMove): the stalker's tracking speed. No
	# per-depth ramp (the Ambusher's threat is the pounce, not raw run-down speed).
	p["chase_speed"] = float(p["track_speed"])
	p["speed_per_depth"] = 0.0
	# Fixed structural flags — this def is an Ambusher, not a Charger (not authored knobs).
	# throwable_while_charging = true so ChargeLane NEVER toggles the "hazard" group,
	# ceding targetability entirely to Concealment (OQ-10 — single owner, no contention).
	p["lock_at_telegraph_start"] = true          # lock the lane at arm-time (dodge the shown lane)
	p["throwable_while_charging"] = true
	p["wall_crash_recover_mult"] = 1.0           # no bonus stun (short pounce, no wall-baiting)
	# Reused LethalContact / ThrowInteraction seam flags.
	p["def_id"] = &"ambusher"
	p["emit_family"] = &"new_hazard_killed"
	p["lethal_mode"] = &"external"
	p["latch_rearm"] = true
	p["throw_mode"] = &"die"
	return p


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return                                     # the family guard, verbatim
	_spawn_time += delta
	_lane.tick(delta)          # the reused pounce FSM (drives LethalContact's external seam)
	# STALKER pursuit: once it has pounced, it hunts while hidden. ChaseMove owns velocity
	# ONLY in DORMANT (ChargeLane zeroed it this tick); TELEGRAPH/CHARGE/RECOVER are the
	# lane's. Live within-band depth read at the same site the legacy chase used (BUG2).
	if _has_pounced and _lane.get_state() == ChargeLane.State.DORMANT:
		_chase.tick_chase(delta, GameState.current_depth_index)
	_update_tell()             # presentation only (headless/paused-safe — colour carries state)
	# Concealment does NOT tick — it is driven by _on_pounce_state.


## The host-owned self-timed run clock (both signal families share this timestamp).
func run_clock_ms() -> int:
	return int(_spawn_time * 1000.0)


## Stable telemetry/def id (Q5 rider — service-spawned nodes never fall back to the
## auto-uniquified node name; ThrownItem._hazard_kind reads this).
func get_def_id() -> StringName:
	return &"ambusher"


## The thrown-item death seam (Q5 locked shape). Mode &"die" returns false — the
## thrower performs the free. Un-hittability never reaches here: while HIDDEN (layer 0,
## out of the "hazard" group) ThrownItem passes clean through before consulting this
## seam. It is killable across the whole revealed window (telegraph → pounce → exposed).
func resolve_throw_death(killer_ctx: Dictionary) -> bool:
	return _throw.resolve_throw_death(killer_ctx)


## Test/inspection seams.
func lane_state() -> int:
	return _lane.get_state()


func is_hittable() -> bool:
	return _conceal.is_hittable()


## Test/inspection seam: true once the first pounce has landed → the stalker loop is live.
func is_stalking() -> bool:
	return _has_pounced


# --- Greybox tells (inline placeholder, D-RAT-4: no PixelLab, no sprite sheets) ------

## Per-frame presentation: aim the reveal tell along the (locked) lunge lane while
## armed/pouncing + run the amber escalation during the wind-up. Pure juice — the hard
## colour flips in _on_pounce_state + Concealment's alpha carry the read if paused.
func _update_tell() -> void:
	var s: int = _lane.get_state()
	if s == ChargeLane.State.TELEGRAPH or s == ChargeLane.State.CHARGE:
		if _tell != null:
			_tell.rotation = _lane.get_lane_dir().angle()


## ChargeLane transition hook: reveal / re-hide (stalker loop) + the S0-LOCKED telemetry
## rows. Vocabulary is S0's locked set: &"telegraph" for the spring wind-up, &"state" for
## every other transition. The emit-always contact row (&"hit_player") + the gated
## opposition_killed_player live in the reused LethalContact; &"spawned" is the
## SpawnService's; &"killed_by_throw" is the ThrownItem path's. No new EventBus signal,
## no new end-cause.
func _on_pounce_state(state: int, _wall_crash: bool) -> void:
	var depth: int = GameState.current_depth_index   # live within-band depth (BUG2)
	var run_t_ms: int = run_clock_ms()
	match state:
		ChargeLane.State.TELEGRAPH:              # ARMED: spring up out of concealment
			_conceal.reveal()
			_fsm.set_tell_color(COLOR_ARMED)
			_fsm.flash_scale(1.4, 0.06, 0.14)    # the sharp reveal pop
			EventBus.opposition_event.emit(&"ambusher", &"telegraph", depth, run_t_ms)
		ChargeLane.State.CHARGE:                 # POUNCE: the one committed lunge
			_has_pounced = true
			_fsm.set_tell_color(COLOR_POUNCE)
			EventBus.opposition_event.emit(&"ambusher", &"state", depth, run_t_ms)
		ChargeLane.State.RECOVER:                # EXPOSED: slow throw-target
			_fsm.set_tell_color(COLOR_EXPOSED)
			_fsm.flash_scale(1.2, 0.06, 0.12)
			EventBus.opposition_event.emit(&"ambusher", &"state", depth, run_t_ms)
		ChargeLane.State.DORMANT:                # cycle end → re-hide (HIDDEN) and stalk
			# This hook only fires post-pounce (TELEGRAPH never falls back to DORMANT), so
			# a DORMANT transition is always a re-hide: invisible + un-hittable again, the
			# floor-smudge tracking, the wedge alpha 0. _physics_process then ticks ChaseMove
			# to pursue the player while hidden until it closes to re-arm (the stalker loop).
			_conceal.hide_conceal()
			EventBus.opposition_event.emit(&"ambusher", &"state", depth, run_t_ms)
