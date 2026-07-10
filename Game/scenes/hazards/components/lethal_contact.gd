class_name LethalContact
extends OppositionComponent
## LethalContact (S2) — the shared kill block: all four legacy hazards' lethality
## paths + latches, transplanted from hazard_entity.gd / pingpong_hazard.gd /
## bomb_hazard.gd / spike_hazard.gd. Owns:
##   - the deterministic SCRIPT DISTANCE TESTS (never physics overlap),
##   - the BUG6 rising-edge latch in all three legacy flavors (re-arm on falling
##     edge; the pursuer's cooldown CONJUNCTION handed in by the host; the spike's
##     PERMANENT no-re-arm variant via `latch_rearm=false`),
##   - the emit-always telemetry (legacy signal family per entity) + the S2 generic
##     dual-emit (`opposition_event(def_id, &"hit_player", …)` beside every legacy
##     contact row; `opposition_killed_player` only when the kills gate FIRES),
##   - the L5 `kills` gate → GameState.fail_run(&"death") (GameState._run_ended owns
##     run-end idempotency — the gate call is never locally guarded),
##   - the R1 non-fatal branch via the host-supplied `nonfatal_handler`.
##
## MODES (`lethal_mode` param):
##   &"radius"        — auto per-frame flat-radius test in tick() (pingpong).
##   &"radius_gated"  — host-driven: the host calls test_radius_catch(depth,
##                      can_catch) at its legacy call site, threading the live depth
##                      (radius scales per depth) and the cooldown conjunction
##                      (host-side timer, Resolved Decisions Q1) (pursuer).
##   &"arm_segments"  — auto per-frame analytic capsule test against the rotating
##                      arms, reading SpinMove's live angle (spike).
##   &"on_command"    — no per-frame test; the host invokes the one-frame blast test
##                      at its detonation frame (bomb): command_hit() (pure test,
##                      host juice runs between) then resolve_command_hit().
##   &"external"      — the S6a seam (breakdown amendment 4): an EXTERNAL mover
##                      (ChargeLane's swept test) supplies the contact boolean each
##                      frame via apply_contact(hit, can_catch) — the same latch/
##                      emit/gate machinery, contact math supplied from outside.
##
## Params read: `contact_radius`, `contact_radius_per_depth`, `blast_radius`,
## `arm_length`, `arm_count`, `kill_radius`, `kills`, `def_id`, `lethal_mode`,
## `latch_rearm`.

var _mode: StringName = &"radius"
var _radius: float = 0.0
var _radius_per_depth: float = 0.0
var _blast_radius: float = 0.0
var _arm_length: float = 0.0
var _arm_count: int = 0
var _kill_radius: float = 0.0
var _kills: bool = false
var _def_id: StringName = &""
var _rearm: bool = true          # spike: false (RD-3 — the latch is PERMANENT)
var _latched: bool = false       # BUG6: true while the player is CONTINUOUSLY in contact

## Host-supplied non-fatal branch (R1 knockback/stun/cooldown). Empty = no branch.
var nonfatal_handler: Callable = Callable()
## arm_segments mode: the SpinMove whose live angle positions the lethal arms.
var spin: SpinMove = null


func _configure(p: Dictionary, _ctx: Dictionary) -> void:
	_mode = StringName(p.get("lethal_mode", &"radius"))
	_radius = float(p.get("contact_radius", 0.0))
	_radius_per_depth = float(p.get("contact_radius_per_depth", 0.0))
	_blast_radius = float(p.get("blast_radius", 0.0))
	_arm_length = float(p.get("arm_length", 0.0))
	_arm_count = int(p.get("arm_count", 0))
	_kill_radius = float(p.get("kill_radius", 0.0))
	_kills = bool(p.get("kills", false))
	_def_id = StringName(p.get("def_id", &""))
	_rearm = bool(p.get("latch_rearm", true))
	_latched = false                 # re-setup starts un-latched (BUG6 pooled-respawn rule)


## Patrol re-arms the catch latch so a re-entry's first in-room frame can catch
## cleanly (the original `_patrol()` first line — host calls this at that exact site).
func rearm_latch() -> void:
	_latched = false


## Auto per-frame modes (pingpong radius / spike arms). Gated + command modes are
## host-driven at their legacy call sites and do nothing here.
func tick(_delta: float) -> void:
	match _mode:
		&"radius":
			var in_contact: bool = host.global_position.distance_to(player.global_position) <= _radius
			apply_contact(in_contact, true)
		&"arm_segments":
			apply_contact(point_on_any_arm(player.global_position), true)


## Pursuer path (&"radius_gated"): effective radius = flat + per-depth lunge; the
## host threads the live depth it read at the top of its chase and the cooldown
## conjunction (`_catch_cooldown <= 0.0`) — host-side timer state per Q1.
func test_radius_catch(depth: int, can_catch: bool) -> void:
	var catch_r: float = _radius + _radius_per_depth * float(depth)
	var in_range: bool = host.global_position.distance_to(player.global_position) <= catch_r
	apply_contact(in_range, can_catch)


## THE BUG6 latch machinery — one shape for every mode AND the &"external" seam:
## emit exactly once on the RISING edge into contact (conjoined with the host's
## can-catch when it has a cooldown), re-arm only on the FALLING edge (and only for
## latch_rearm=true — the spike's latch is permanent). The fatal-catch frame is the
## SAME conjunction as the legacy entities, so death timing is byte-identical.
func apply_contact(hit: bool, can_catch: bool) -> void:
	if hit and not _latched and can_catch:
		_latched = true
		_fire()
	elif not hit and _rearm:
		_latched = false   # re-arm only after the player has left contact


## Bomb (&"on_command") step 1: the pure one-frame blast test at the detonation
## frame — no side effects (the host's flash juice runs between test and resolve,
## preserving the legacy statement order).
func command_hit() -> bool:
	return _blast_radius > 0.0 \
		and host.global_position.distance_to(player.global_position) <= _blast_radius


## Bomb (&"on_command") step 2: emit-always + kills gate for the hit the host proved.
func resolve_command_hit() -> void:
	_fire()


## Pure analytic hit test (spike): true iff `point` is within the lethal capsule
## radius of ANY of the arm_count rotating arm segments at SpinMove's CURRENT angle.
## Deterministic closed-form geometry — no physics overlap.
func point_on_any_arm(point: Vector2) -> bool:
	var hub: Vector2 = host.global_position
	var base_angle: float = spin.spin_angle() if spin != null else 0.0
	for i: int in _arm_count:
		var a: float = base_angle + float(i) * (TAU / float(_arm_count))
		var tip: Vector2 = hub + Vector2(cos(a), sin(a)) * _arm_length
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, hub, tip)
		if point.distance_to(closest) <= _kill_radius:
			return true
	return false


## A contact lands. ALWAYS emit the generic &"hit_player" opposition row (fatal or
## not); the L5 kills gate alone decides fail_run (its _run_ended guard is the single
## source of run-end idempotency — never a local "already ended" bool).
## opposition_killed_player fires ONLY when the kills gate actually fires fail_run
## (the kill/contact distinction lives here at the gate — S0 §5).
func _fire() -> void:
	var depth: int = GameState.current_depth_index   # live within-band depth (BUG2)
	var run_t_ms: int = _host_run_t_ms()             # the host-owned self-timed clock
	EventBus.opposition_event.emit(_def_id, &"hit_player", depth, run_t_ms)
	if _kills:
		GameState.fail_run(&"death")   # existing end path; _run_ended owns idempotency
		EventBus.opposition_killed_player.emit(_def_id, depth, run_t_ms)
	elif nonfatal_handler.is_valid():
		nonfatal_handler.call()        # R1's knockback/stun/cooldown branch (host-side)
