class_name OppositionComponent
extends Node
## OppositionComponent (S2, M1.9) — base contract for hazard/opposition behavior
## components (S2 spec §3.1 + Resolved Decisions Q1).
##
## Components are host-owned child Nodes with NO _process/_physics_process of their
## own: the HOST remains the only physics ticker and calls components explicitly, in
## a fixed order — that is what makes frame-order parity provable and keeps per-
## entity cost one physics callback, same as the pre-component entities.
##
## CONFIG-SNAPSHOT DISCIPLINE, MADE STRUCTURAL: components NEVER read
## GameState.active_run_config and NEVER hold a RunConfig — they are bound once, at
## host.setup(), with already-RESOLVED primitive values (`bind(host, player, p, ctx)`
## where `p` is a flat primitive Dictionary the host resolved from its own config
## snapshot). A run-end clearing active_run_config can never reach a component,
## because a component only ever saw floats/ints/bools/StringNames.
##
## LIVE RUN-STATE reads are different from config reads: where a legacy entity read
## GameState.current_depth_index LIVE each frame (the BUG2 within-band-depth
## contract), the transplanted code keeps that live read at the exact same site —
## the ban is on CONFIG, not on the depth run-state the entities always read live.
##
## Discovery-before-instance (Resolved Decisions Q4): `acquire()` first adopts a
## .tscn-declared child of the requested component script, else instances a default.
## ORDER-STABLE: the host's component refs (and therefore its tick order) are built
## in the host's fixed code order regardless of child declaration order, so a
## scene-authored host can never reintroduce tick-order drift.

var host: Node2D = null      # the entity root (CharacterBody2D / Node2D)
var player: Node2D = null    # resolved once by the host at setup
var _run_clock: Callable = Callable()  # the host's run_clock_ms, bound once at bind()


## Bind resolved params + the per-instance spawn context (the LOCKED spawn_ctx
## pass-through). Re-bindable: a re-setup() re-binds, and subclasses reset their
## per-run state (latches, accumulators) in _configure — mirroring how the legacy
## entities reset state in setup().
func bind(host_: Node2D, player_: Node2D, p: Dictionary, ctx: Dictionary) -> void:
	host = host_
	player = player_
	_run_clock = Callable(host_, &"run_clock_ms")
	_configure(p, ctx)


## Subclass hook: snapshot YOUR keys out of `p`/`ctx` into typed fields.
func _configure(_p: Dictionary, _ctx: Dictionary) -> void:
	pass


## Called by the HOST, in the host's fixed order. Components never self-tick.
func tick(_delta: float) -> void:
	pass


## Find-or-make a component child of `component_script` on `host_` (Q4: adopt a
## .tscn-declared child when present, instance a default otherwise).
static func acquire(host_: Node2D, component_script: GDScript) -> OppositionComponent:
	for child: Node in host_.get_children():
		if child.get_script() == component_script and child is OppositionComponent:
			return child as OppositionComponent
	var made: OppositionComponent = component_script.new() as OppositionComponent
	host_.add_child(made)
	return made


## The host-owned self-timed run clock (R1 §4 pattern — both signal families share
## one timestamp, S2 §3.1). Every host implements `run_clock_ms() -> int` off its
## own accumulator; the cross-host seam is the `_run_clock` Callable bound once at
## bind() (hosts share no common script base — CharacterBody2D vs Node2D roots —
## Wave-2 close-out, Director Addressed 2026-07-03: no per-call duck dispatch).
func _host_run_t_ms() -> int:
	return int(_run_clock.call())
