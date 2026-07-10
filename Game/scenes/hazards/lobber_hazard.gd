class_name LobberHazard
extends CharacterBody2D
## LobberHazard — "The Mortar" (U2a, M1.11). A half-buried automated ordnance piece
## still running its fire solution: it ranges you, lobs a shell in a high arc onto
## where you stand, re-ranges. AIM → lock a ground marker at your feet → after
## arc_time_s the blast tests that spot → cycle. The arc IGNORES geometry (cover
## never protects — the whole point; the Sentry is why cover matters, the Lobber is
## why you can't camp it). It punishes standing still — the loot pause and the
## extract dither are exactly what it taxes.
##
## S2 Actor-host family skeleton verbatim (per-frame guard, self-timed run clock,
## fixed component tick order, snapshot at setup) — the behaviour is the reused
## component set + the ONE new MortarCycle:
##   LethalContact (&"external" blast kill: emit-always + L5 kills gate + BUG6 latch)
##   + ThrowInteraction (&"die" — silence the rain) + TelegraphFSM (the fire tell)
##   + MortarCycle (target + locked marker + delayed blast — NEW).
##
## The BODY is NOT contact-lethal — only shells kill (the exploration's slow,
## low-threat body; a deliberate identity choice, spec §2.4). STATIC: no movement
## component, no velocity — its arc reaches everywhere, so it never repositions.
## Collision: layer hazard(16), mask world(2), "hazard" group for its WHOLE life —
## unlike the ambusher/burrower it never hides, so it is ALWAYS a valid throw target.
##
## DECK-DRIVEN KNOBS (the new-def lane): tuning arrives as the def's params bag via
## spawn_ctx["params"] — the EncounterBuilder's ctx merge of lobber.tres params +
## deck-entry overrides + rc.param_overrides. DEFAULTS below MUST mirror lobber.tres
## so a bare direct-test setup() behaves like the authored def (test_lobber pins it).
##
## ALL-OFF / BAND GATING: ships OFF — not in RunConfig.oppositions_enabled, not in
## the default play preset, not in band 1/2/3 decks; min_band = 4 hard-gates it to
## the open-field band (U3's band_four). With the shipped default this scene is
## NEVER loaded (lobber.tres is the only referencer), so the permanent all-off
## fingerprint e943ac9c8bc1 is untouched. NEVER references the global RNG autoload.

## Greybox palette (spec §2.2 — character-animator greybox; PixelLab Director-gated).
## Distinct by SILHOUETTE: a squat static turret with a stubby barrel — no shipped
## hazard is a static square-ish emitter (wedge/blob/diamond/star/ring all differ).
const COLOR_IDLE := Color(0.55, 0.5, 0.45)          # dormant sheller
const COLOR_FIRING := Color(0.95, 0.6, 0.2)         # amber — "a shell is up"
const COLOR_MARKER := Color(0.95, 0.35, 0.15, 0.5)  # the ground ring / danger zone

## Code fallbacks for a direct setup() with no spawn_ctx["params"] — MUST mirror the
## authored lobber.tres entity params (base_count/count_per_depth are builder-read
## spawn-card keys and never reach the entity). test_lobber asserts
## def.params[k] == DEFAULTS[k] for every key here (no silent drift).
const DEFAULTS := {
	"fire_period_s": 2.5,
	"arc_time_s": 0.9,
	"blast_radius": 48.0,
	"lead_factor": 0.0,
	"kills": true,
}

var _cfg: RunConfig                  # snapshot of the run config at setup (guard only)
var _player: Node2D                  # resolved at setup via setup()'s arg
var _spawn_time := 0.0               # self-timed run clock (host-owned, R1 §4 pattern)

var _lethal: LethalContact = null
var _throw: ThrowInteraction = null
var _fsm: TelegraphFSM = null
var _mortar: MortarCycle = null

@onready var _body: Polygon2D = $Body                  # the sheller silhouette (fire tell)
@onready var _marker_root: Node2D = $MarkerRoot        # top_level = true (world-absolute)
@onready var _marker_ring: Polygon2D = $MarkerRoot/Ring
@onready var _marker_fill: Polygon2D = $MarkerRoot/Fill


func _ready() -> void:
	# Q4: adopt .tscn-declared components when present, instance defaults otherwise.
	# The refs below fix the tick order regardless of child declaration order.
	_lethal = OppositionComponent.acquire(self, LethalContact) as LethalContact
	_throw = OppositionComponent.acquire(self, ThrowInteraction) as ThrowInteraction
	_fsm = OppositionComponent.acquire(self, TelegraphFSM) as TelegraphFSM
	_mortar = OppositionComponent.acquire(self, MortarCycle) as MortarCycle
	_fsm.tell = _body                    # the fire-tell colour flip plays on the BODY
	_mortar.lethal = _lethal             # reused &"external"-mode kill machinery
	_mortar.marker_root = _marker_root
	_mortar.marker_ring = _marker_ring
	_mortar.marker_fill = _marker_fill
	_mortar.on_state_changed = _on_phase


## Bind config + player + the per-instance spawn context (LOCKED family signature).
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_spawn_time = 0.0
	var p := _resolve_params(spawn_ctx)
	_lethal.bind(self, player, p, spawn_ctx)   # resets the BUG6 latch (re-setup safe)
	_throw.bind(self, player, p, spawn_ctx)    # &"die": always reachable (never hides)
	_fsm.bind(self, player, p, spawn_ctx)
	_mortar.bind(self, player, p, spawn_ctx)   # seats AIM (marker hidden, offset applied)
	_set_tell_idle()


## New-def resolve order (the deck lane): spawn_ctx["params"] (lobber.tres params +
## deck-entry overrides + rc.param_overrides, merged by the EncounterBuilder) over
## the DEFAULTS mirror.
func _resolve_params(spawn_ctx: Dictionary) -> Dictionary:
	var dp: Dictionary = spawn_ctx.get("params", {})
	var p: Dictionary = {}
	for key: String in DEFAULTS:
		p[key] = dp.get(key, DEFAULTS[key])
	# Reused LethalContact / ThrowInteraction seam flags (the bomb resolve shape).
	# lethal_mode is &"external", NOT &"on_command" — command_hit() tests the HOST's
	# own position (the Lobber body), and the blast lands AWAY from the body;
	# MortarCycle computes the marker-vs-player boolean itself. blast_radius is
	# consumed by MortarCycle's own distance test (&"external" ignores the
	# component's _blast_radius).
	p["def_id"] = &"lobber"
	p["lethal_mode"] = &"external"
	p["latch_rearm"] = true
	p["throw_mode"] = &"die"
	return p


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return                                 # the family guard, verbatim
	_spawn_time += delta
	_mortar.tick(delta)     # the fire-period FSM (drives LethalContact's external seam)
	# No body movement (static sheller). MortarCycle owns the marker; the body is inert.


## The host-owned self-timed run clock (both signal families share this timestamp).
func run_clock_ms() -> int:
	return int(_spawn_time * 1000.0)


## Stable telemetry/def id (service-spawned nodes never fall back to the auto-
## uniquified node name; ThrownItem._hazard_kind reads this).
func get_def_id() -> StringName:
	return &"lobber"


## The thrown-item death seam. Mode &"die" returns false — the thrower frees us,
## ending the rain. Always reachable: the Lobber never leaves layer 16 / the group.
func resolve_throw_death(killer_ctx: Dictionary) -> bool:
	return _throw.resolve_throw_death(killer_ctx)


## Test/inspection seam: the MortarCycle phase (MortarCycle.Phase values).
func phase() -> int:
	return _mortar.get_phase()


# --- Greybox tells (inline placeholder, no PixelLab, no sprite sheets) ---------------

## MortarCycle transition hook: the fire tell + the S0 LOCKED telemetry vocabulary.
## &"telegraph" = a shell is fired (the marker appears — the wind-up); &"state" =
## impact resolved (the cycle beat). The emit-always &"hit_player" + the gated
## opposition_killed_player live in the reused LethalContact; &"spawned" is the
## service's; &"killed_by_throw" the ThrownItem path's. No new EventBus signal, no
## new end-cause.
func _on_phase(next: int) -> void:
	var depth: int = GameState.current_depth_index   # live within-band depth (BUG2)
	var run_t_ms: int = run_clock_ms()
	match next:
		MortarCycle.Phase.IN_FLIGHT:                 # a shell is up: fire tell + marker
			_set_tell_firing()
			_fsm.flash_scale(1.3, 0.06, 0.1)         # muzzle pop (pure juice)
			EventBus.opposition_event.emit(&"lobber", &"telegraph", depth, run_t_ms)
		MortarCycle.Phase.AIM:                       # impact resolved → back to ranging
			_set_tell_idle()
			EventBus.opposition_event.emit(&"lobber", &"state", depth, run_t_ms)


func _set_tell_idle() -> void:
	_fsm.set_tell_color(COLOR_IDLE)


func _set_tell_firing() -> void:
	_fsm.set_tell_color(COLOR_FIRING)
