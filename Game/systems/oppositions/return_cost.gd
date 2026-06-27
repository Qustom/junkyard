class_name ReturnCost
extends Node
## R2 — Costlier return trip. RUN-STATE node (TDD §2), created/destroyed per dive
## (sibling of DiveClock). Makes deeper pushes cost more to *undo*: retreating
## toward the gate charges a depth-scaled toll, so "one more room?" trades a known
## extra reward against a known extra exit-cost.
##
## Reads RunConfig (R0, GameState.active_run_config) + the live return distance
## (BUG2: GameState.current_dist_to_gate, refreshed every depth tick from B3's
## reverse-BFS PlacedPiece.dist_to_gate). Writes ONLY through existing public
## surfaces:
##   - clock toll   → DiveClock.modify_light(-cost)   (A3 public mutator)
##   - meter toll   → R2's own run-state debt meter; cap → GameState.fail_run(&"timeout")
##   - exposure toll→ R3's run-state meter, ONLY if R3 present (§9 D4/D5); never meta
## and emits the pre-declared EventBus.return_cost_incurred (declared by TEL).
## It edits NO autoload source file. PROCESS_MODE_PAUSABLE so it freezes with the
## tree like DiveClock.
##
## RG1 owns dive-scene assembly: RG1 instantiates this node and injects the
## `dive_clock` reference. This task builds + unit-tests the node only.
##
## As-built name corrections vs the R2 spec sketch (spec predates BUG2/TEL merge):
##   - live return distance is GameState.current_dist_to_gate (not a per-piece read)
##   - the change trigger is EventBus.depth_changed(depth_index, max_depth)
##   - RunConfig enums are plain @export_enum ints (no RunConfig.R2_* constants);
##     the local consts below name those int values.

# --- RunConfig enum int values (RunConfig uses plain @export_enum ints) -------
const MECH_LENGTHEN := 0
const MECH_DECAY_BEHIND := 1
const MECH_EGRESS_TOLL := 2

const TOLL_CLOCK := 0
const TOLL_EXPOSURE := 1
const TOLL_METER := 2

## Injected by the dive scene (RG1) for the `clock` toll. Null-safe: a config that
## never selects the clock toll, or a test that does not inject one, simply skips
## the clock charge.
@export var dive_clock: DiveClock

## `lengthen` (mechanism 0) is an alias into the egress_toll cost path with a
## distance-multiplier framing (§9 D1): same cost engine, steeper effective curve.
## A multiplier of 1.0 reproduces egress_toll exactly; >1.0 simulates the extra
## "the path felt k× longer" distance. Greybox: we cannot cheaply make the player
## physically walk farther, so the extra distance is charged as toll.
@export var lengthen_multiplier: float = 2.0

var _cfg: RunConfig
var _active: bool = false
var _charged_flat: bool = false      # `mag` is charged once per run, on first taxed retreat
var _last_d: int = -1                # last observed dist_to_gate (retreat = d decreasing)
var _deepest_taxed: int = 0          # bookkeeping for analysis
var _meter: float = 0.0              # only used when toll_resource == meter
var _meter_cap: float = 100.0        # greybox cap for the dedicated meter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)
	# BUG2 supplies the live-depth trigger via depth_changed(depth_index, max_depth);
	# R2 re-reads GameState.current_dist_to_gate (return distance) on each change to
	# decide whether that crossing was a retreat.
	EventBus.depth_changed.connect(_on_depth_changed)


func _on_run_started(_band_id: StringName = &"", _seed: int = 0) -> void:
	_cfg = GameState.active_run_config
	_active = _cfg != null and _cfg.r2_enabled
	_charged_flat = false
	_last_d = -1
	_deepest_taxed = 0
	_meter = 0.0


func _on_run_ended(_reason: StringName = &"", _duration_s: float = 0.0, _depth_reached: int = 0) -> void:
	_active = false


## Driven by BUG2's depth_changed. We read the player's live return distance d and
## detect retreat (d decreased vs the last observed value).
func _on_depth_changed(_depth_index: int, _max_depth: int) -> void:
	if not _active:
		return
	var d: int = _current_dist_to_gate()
	if _last_d < 0:
		_last_d = d
		return
	if d < _last_d:                       # RETREAT: moved one (or more) hops toward the gate
		var hops: int = _last_d - d
		_apply_retreat_cost(d, hops)
	elif d > _last_d and _cfg.r2_mechanism == MECH_DECAY_BEHIND:
		_maybe_decay_links_behind(_last_d)  # pushed deeper past threshold → arm decay
	_last_d = d


## BUG2 surface: the live return distance of the piece the player is in NOW.
## Refreshed every depth tick by GameState.set_current_depth(); on the linear M1.0
## spine this equals depth_index, and diverges once R4 branches.
func _current_dist_to_gate() -> int:
	return GameState.current_dist_to_gate


## Charge the marginal cost for a retreat that closed `hops` of return distance,
## arriving at distance `d`. Only hops that DEPARTED from above the threshold are
## taxed (§3): we charge `per` per taxed hop, plus `mag` once on the first taxed
## retreat of the run. No lump-at-gate (§9 D6).
func _apply_retreat_cost(d: int, hops: int) -> void:
	var thr: int = _cfg.r2_depth_threshold
	var taxed_hops: int = 0
	for step in range(hops):
		# the dist_to_gate the hop DEPARTED from (deepest first): d+hops, ..., d+1
		var hop_d: int = d + hops - step
		if hop_d > thr:
			taxed_hops += 1
	if taxed_hops == 0:
		return

	var cost: float = _cfg.r2_cost_per_depth * float(taxed_hops)
	if not _charged_flat:
		cost += _cfg.r2_cost_magnitude
		_charged_flat = true

	# `lengthen` (mechanism 0): alias into the egress_toll cost path with a
	# distance-multiplier framing — the same cost engine, a steeper effective curve.
	if _cfg.r2_mechanism == MECH_LENGTHEN:
		cost *= maxf(lengthen_multiplier, 0.0)

	if cost <= 0.0:
		return

	_deepest_taxed = maxi(_deepest_taxed, d + hops)
	_charge(d, cost)


## Route the charge through the selected resource — ALL via existing public
## surfaces. Emits the pre-declared return_cost_incurred per charge.
func _charge(d: int, cost: float) -> void:
	match _cfg.r2_toll_resource:
		TOLL_CLOCK:
			if dive_clock != null:
				dive_clock.modify_light(-cost)   # A3 public mutator; may trigger dive_clock_timeout → fail_run(&"timeout")
			EventBus.return_cost_incurred.emit(d, &"clock", cost)
		TOLL_EXPOSURE:
			# §9 D4/D5: `exposure` REQUIRES R3 enabled and adds to R3's SHARED
			# run-state meter — NO meta GameState.add_exposure() (meta persists and
			# would contaminate the comparable baseline). If R3 is absent that is a
			# misconfiguration; we still emit the telemetry row so the misconfig is
			# visible, but charge nothing (no meta fallback).
			var meter: Node = _r3_meter()
			if meter != null and meter.has_method(&"add"):
				meter.call(&"add", cost)
			EventBus.return_cost_incurred.emit(d, &"exposure", cost)
		TOLL_METER:
			_meter += cost
			EventBus.return_cost_incurred.emit(d, &"meter", cost)
			if _meter >= _meter_cap:
				GameState.fail_run(&"timeout")   # existing end-cause vocabulary


## R3's run-state meter, if R3 is present and enabled (§9 D4). R3 is a wave-2
## sibling that may not exist yet; resolve it loosely by group so R2 never hard-
## references R3's class. Returns null when R3 is absent/disabled — the exposure
## toll then charges nothing (no meta fallback).
func _r3_meter() -> Node:
	if _cfg == null or not _cfg.r3_enabled:
		return null
	if not is_inside_tree():
		return null
	var nodes: Array[Node] = get_tree().get_nodes_in_group(&"r3_exposure_meter")
	if nodes.is_empty():
		return null
	return nodes[0]


# --- decay_behind (mechanism 1) ----------------------------------------------
## Collapse a traversed link past the threshold, but ONLY behind a mandatory
## reachability guard (§9 D2): never orphan the player. On the linear M1.0 spine
## there is a single path home, so the guard always trips and decay self-downgrades
## to a toll (the only path home is never severed). Greybox / runtime-only: a true
## link collapse needs R4 branching + B2/B3 graph cooperation, which is R4-dependent
## and deferred — until then this charges the egress toll instead of severing.
func _maybe_decay_links_behind(prev_d: int) -> void:
	if prev_d <= _cfg.r2_depth_threshold:
		return
	var link: Variant = _link_player_just_crossed()
	if link != null and _gate_reachable_without(link):
		_collapse_link(link)
		EventBus.return_cost_incurred.emit(prev_d, &"decay", 1.0)
	# else: skip the collapse (linear-spine self-downgrade) — never orphan the
	# player. The cost still lands as a toll on the eventual retreat via the normal
	# egress_toll path, so deep pushes are not free under decay_behind on the spine.


## decay_behind graph hooks — runtime-only placeholders. The live walkable graph
## is owned by B2/B3 (Band/PlacedPiece sockets); collapsing a mated socket link is
## an R4-branching feature (multiple routes home). Until R4 lands on `main` there
## is no branching graph to sever, so these resolve to "no collapsable link",
## which is exactly the linear-spine self-downgrade-to-toll path (§7 / §9 D2).
func _link_player_just_crossed() -> Variant:
	return null   # R4-dependent; no branching graph to traverse yet (linear spine)


func _gate_reachable_without(_link: Variant) -> bool:
	# Reverse-BFS from gate over the surviving graph would live here once R4 supplies
	# a branching graph. With no collapsable link (linear spine) this is never reached
	# with a non-null link; default to "guard trips" so we never sever.
	return false


func _collapse_link(_link: Variant) -> void:
	pass   # R4-dependent runtime graph edit; no-op on the linear spine.


# --- Read-only accessors (for HUD/telemetry/tests) ---------------------------
func is_active() -> bool:
	return _active


func get_meter() -> float:
	return _meter


func get_meter_cap() -> float:
	return _meter_cap


func get_deepest_taxed() -> int:
	return _deepest_taxed
