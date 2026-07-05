class_name BurrowCycle
extends OppositionComponent
## BurrowCycle (T2b, M1.10) — the ONE new opposition component of the Burrower's
## Phase-E proof: a BURIED -> TELEGRAPH -> SURFACED -> BURIED cycle that toggles the
## host's collision_layer + &"hazard" group per-phase (so a thrown item PASSES
## CLEAN THROUGH while buried, not a re-drop), tracks the player underground while
## ignoring walls (direct-translate, no move_and_slide), and gates the reused
## LethalContact to the SURFACED window only.
##
## Everything around it is REUSED unchanged (the Charger footprint, exactly):
##   - contact/kill → the S2 LethalContact in &"external" mode: THIS component
##                    computes the static radius contact each SURFACED frame and
##                    hands it to apply_contact(hit, true) — the emit-always + L5
##                    kills gate + BUG6 rising-edge latch machinery runs unchanged.
##   - tells        → the S2 TelegraphFSM (decal throb), driven by the HOST off the
##                    on_state_changed hook (colors stay host consts — S2 rule).
##   - throw death  → the S2 ThrowInteraction (&"die"), reachable only while surfaced
##                    (buried = collision_layer 0 => ThrownItem.body_entered never
##                    fires against the body).
##
## FSM (spec §2.1) — all timing is a host-driven accumulator inside this component:
##   BURIED    — collision_layer 0 + out of &"hazard" group (throw pass-through),
##               NON-LETHAL, direct-translate toward the player ignoring walls. Lasts
##               buried_s (seeded by the per-instance desync offset).
##   TELEGRAPH — still buried + NON-LETHAL (the dodge window). The surface point is
##               LOCKED at telegraph start (lock_surface_at_telegraph); the decal
##               freezes so stepping kill_radius + PLAYER_R away is a guaranteed
##               dodge. Lasts telegraph_lead_s.
##   SURFACED  — collision_layer 16 + in &"hazard" group (throw-killable), STATIC pop
##               (no lunge — the locked decal is an honest "you will be hit HERE"
##               contract), LETHAL: a flat kill_radius test feeds LethalContact.
##               Lasts surface_s.
##
## FAIRNESS (spec §1.4, Phase-3 Q4/Q5 binding): lethality arms ONLY in SURFACED, and
## the FIRST lethal test runs on the surfacing frame ITSELF (correction 2 — the
## player is physically solid to a mask-26 body, so a one-frame-late test would let a
## standing player depenetrate off the locked point). Never lethal inside the
## telegraph lead.
##
## WALL-SURFACING GUARD (correction 3): the wall-ignoring tracker can carry the buried
## body UNDER a wall; surfacing there would be throw-proof yet script-lethal through
## the wall. BURIED->TELEGRAPH is gated on an intersect_point (world mask 2) clearance
## test at the candidate surface point — it stays BURIED and keeps tracking until
## clear (converges because clamp-at-player tracking targets the player, always on
## floor).
##
## RNG-FREE and deterministic: no global RNG reference anywhere. The per-instance
## phase desync is a PURE function of the spawn position (correction 1 — the builder
## does NOT stamp phase_salt for &"burrower"; it derives positionally, with a ctx
## key kept as a test-harness override). The FSM is real-time run-state and never
## feeds fingerprint().

enum Phase { BURIED, TELEGRAPH, SURFACED }

## The shipped hazard collision_layer bit (charger/splitter scene template).
const HAZARD_LAYER := 16
## The `world` collision layer the surfacing-clearance query masks (walls).
const WORLD_MASK := 2
## Player body radius (player.tscn CircleShape2D) — a feel constant living with its
## block (the ChargeLane.PLAYER_R idiom), used only for the desync/documentation.
const PLAYER_R := 14.0
## Irrational multiplier for the RNG-free per-instance desync hash (golden ratio conj).
const DESYNC_PHI := 0.6180339887

## Reused seams, assigned by the HOST at _ready (the ChargeLane.lethal idiom).
var lethal: LethalContact = null            # &"external" gated kill sink
var on_state_changed: Callable = Callable()  # host paints tells + emits S0 rows here

# --- snapshotted knobs (bound once via _configure; never re-read mid-run) --------
var _buried_s := 0.0
var _telegraph_s := 0.0
var _surface_s := 0.0
var _track_speed := 0.0
var _kill_radius := 0.0
var _lock_surface := true

# --- run-state -------------------------------------------------------------------
var _body: CharacterBody2D = null
var _phase: int = Phase.BURIED
var _t := 0.0                     # time-in-phase
var _phase_offset := 0.0          # per-instance desync seed (positional, §5)
var _surface_point := Vector2.ZERO


func _configure(p: Dictionary, ctx: Dictionary) -> void:
	_buried_s = maxf(float(p.get("buried_s", 0.0)), 0.0)
	_telegraph_s = maxf(float(p.get("telegraph_lead_s", 0.0)), 0.0)
	_surface_s = maxf(float(p.get("surface_s", 0.0)), 0.0)
	_track_speed = maxf(float(p.get("track_speed", 0.0)), 0.0)
	_kill_radius = float(p.get("kill_radius", 0.0))
	_lock_surface = bool(p.get("lock_surface_at_telegraph", true))
	_body = host as CharacterBody2D
	# Per-instance desync: a PURE function of the spawn POSITION (correction 1 — the
	# builder stamps no phase_salt for &"burrower"; the ctx key is kept only as a
	# test-harness override). SpawnService sets global_position BEFORE setup(), cells
	# are seed-deterministic, and per_room_cap=1 means no two share a cell — so the
	# offset is deterministic, per-instance unique, and RNG-free.
	var default_salt: int = int(_body.global_position.x) * 31 + int(_body.global_position.y) \
		if _body != null else 0
	var salt: int = int(ctx.get("phase_salt", default_salt))
	_phase_offset = fmod(float(salt) * DESYNC_PHI, 1.0) * maxf(_buried_s, 0.0001)
	# Re-setup seats BURIED (family re-setup reset) WITHOUT firing the host hook — the
	# host seats its own buried visual at setup().
	_phase = Phase.BURIED
	_t = _phase_offset
	_surface_point = _body.global_position if _body != null else Vector2.ZERO
	_enter_buried_body(false)


## Called by the HOST each physics frame (fixed order; components never self-tick).
func tick(delta: float) -> void:
	if _body == null or player == null or not is_instance_valid(player):
		return
	_t += delta
	match _phase:
		Phase.BURIED:
			_track_underground(delta)               # direct-translate, wall-ignoring
			# BURIED->TELEGRAPH only once the timer elapses AND the candidate surface
			# point is clear of world geometry (correction 3 — never surface in a wall).
			if _t >= _buried_s and _surface_point_clear():
				_surface_point = _body.global_position   # captured at telegraph START
				_enter(Phase.TELEGRAPH)
		Phase.TELEGRAPH:
			if not _lock_surface:
				_track_underground(delta)            # unfair variant: keeps chasing
				_surface_point = _body.global_position
			# Body stays buried + NON-LETHAL for the whole lead (the dodge window).
			if lethal != null:
				lethal.apply_contact(false, true)
			if _t >= _telegraph_s:
				_enter_surfaced_body()               # restore layer + group
				_enter(Phase.SURFACED)
				_surfaced_lethal_test()              # SAME-FRAME first test (correction 2)
		Phase.SURFACED:
			_body.velocity = Vector2.ZERO            # static pop (not a lunge)
			_surfaced_lethal_test()
			if _t >= _surface_s:
				if lethal != null:
					lethal.apply_contact(false, true)   # falling edge -> BUG6 re-arm
				_enter_buried_body(true)
				_enter(Phase.BURIED)


# --- queries (host presentation + tests) --------------------------------------------

func get_phase() -> int:
	return _phase


func surface_point() -> Vector2:
	return _surface_point


# --- internals ----------------------------------------------------------------------

## The SURFACED flat-radius contact test feeding the reused &"external" LethalContact
## (emit-always + L5 kills gate + BUG6 latch). The static-radius analogue of
## ChargeLane._test_lethal_sweep.
func _surfaced_lethal_test() -> void:
	if lethal == null:
		return
	var hit: bool = _body.global_position.distance_to(player.global_position) <= _kill_radius
	lethal.apply_contact(hit, true)


## Direct-translate toward the player at track_speed, clamped so it never overshoots
## (Q7: clamp-at-player — reads as "it arrived", deterministic, no jitter). NO
## move_and_slide, so it ignores walls by construction (the exploration's "moves
## under walls").
func _track_underground(delta: float) -> void:
	if _track_speed <= 0.0:
		return
	var to_p: Vector2 = player.global_position - _body.global_position
	var d: float = to_p.length()
	if d <= 0.001:
		return
	var step: float = minf(_track_speed * delta, d)   # never overshoot the player
	_body.global_position += to_p / d * step          # NO move_and_slide -> ignores walls


## True iff the candidate surface point is clear of world (mask 2) geometry — an
## intersect_point query on the host's own body position. A blocked point keeps the
## body BURIED (correction 3). Null/space-less-safe (returns true so a bare harness
## with no physics space still surfaces).
func _surface_point_clear() -> bool:
	if _body == null or not _body.is_inside_tree():
		return true
	var world := _body.get_world_2d()
	if world == null:
		return true
	var space: PhysicsDirectSpaceState2D = world.direct_space_state
	if space == null:
		return true
	var q := PhysicsPointQueryParameters2D.new()
	q.position = _body.global_position
	q.collision_mask = WORLD_MASK
	q.collide_with_bodies = true
	q.collide_with_areas = false
	return space.intersect_point(q, 1).is_empty()


## BURIED/TELEGRAPH: off the hazard layer + group so a throw PASSES CLEAN THROUGH
## (ThrownItem is an Area2D, mask 18 — body_entered never fires against a layer-0
## body) and the body is un-targetable. The layer clear is the load-bearing half;
## the group removal is defensive belt-and-braces (Q8: keep both).
func _enter_buried_body(_show_bury_juice: bool) -> void:
	if _body == null:
		return
	_body.collision_layer = 0
	if _body.is_in_group(&"hazard"):
		_body.remove_from_group(&"hazard")


## SURFACED: restore the layer + group so the throw-kill path + LethalContact work.
func _enter_surfaced_body() -> void:
	if _body == null:
		return
	_body.collision_layer = HAZARD_LAYER
	if not _body.is_in_group(&"hazard"):
		_body.add_to_group(&"hazard")


func _enter(next: int) -> void:
	_phase = next
	_t = 0.0
	if on_state_changed.is_valid():
		on_state_changed.call(next)
