class_name DeparturePortal
extends Area2D
## DeparturePortal (M2, M1.6) — the "leave the hub, start a dive" interactable.
##
## Built on the ExtractGate pattern (extract_gate.gd): a deliberately DUMB interactable
## whose OWNER acts on EventBus.interaction_requested. Where the gate calls
## GameState.extract_and_end_run(), the portal asks the M0 router to load the dive by
## emitting EventBus.dive_requested(band_id) — the persistent App router observes it and
## swaps the Hub state scene for the dive (scenes/app/app.gd:_on_dive_requested).
##
## The portal owns NO run-state and NO meta truth: it only announces "the player chose to
## dive." The dive scene (main_game) then self-starts the run on its own _ready, resolving
## its RunConfig via GameState.dive_config_or_default(). The portal never calls start_run.
##
## Greybox: an Area2D with a ColorRect body + a child Interactable(id=&"portal") on the
## interactable layer (bit 3 = collision_layer 4); it detects nothing itself (layer/mask 0).

## StringName the child Interactable is authored with; the portal only acts on its own.
@export var interactable_id: StringName = &"portal"

## The band the dive launches into — the ROUTING KEY emitted on dive_requested.
## M1.6's single greybox band is &"near" (the control); S8 (M1.9) adds a second
## portal instance overriding this to &"band_two" (main_game.BAND_ROUTES maps
## key → BandProfile). The portal stays dumb: it only announces the key.
@export var band_id: StringName = &"near"

## S8 (M1.9): per-instance identity, pushed down to the child Interactable in
## _ready. The id/prompt/name live on the child INSIDE this packed scene
## (departure_portal.tscn), which a plain hub.tscn instance override can't reach
## without editable-children noise — so the root re-exports them. Defaults equal
## the authored portal-1 values, so portal 1 needs NO new overrides and renders/
## behaves byte-identically (the tscn itself ships a zero-byte diff).
@export var prompt_text: String = "Dive"
@export var display_name: String = "Departure Portal"

## S8 (M1.9): re-tint placeholders for a visually distinct second portal — a
## modulate over the existing gate/glow art (no new art; D-RAT-1 gives band 2's
## glow ember-orange Color(1.0, 0.58, 0.24)). WHITE is the identity modulate ==
## as-authored rendering (portal 1 unchanged).
@export var glow_tint: Color = Color.WHITE
@export var gate_tint: Color = Color.WHITE

## Fat-finger lockout window (mirrors extract_gate.gd:27): after an accepted interact,
## further interacts on this portal are ignored until the window elapses. Belt-and-braces
## against a held trigger double-firing a scene swap.
@export var input_lockout_s: float = 0.25

## True between an accepted interact and the lockout expiring.
var _locked: bool = false


func _ready() -> void:
	EventBus.interaction_requested.connect(_on_interaction_requested)
	# S8 (M1.9): push the per-instance identity down to the marker child and tint
	# the dressing (single source at the root). With the export defaults (portal 1)
	# every assignment writes the value already authored in the scene — a no-op.
	var it := $Interactable as Interactable
	if it != null:
		it.interactable_id = interactable_id
		it.prompt_text = prompt_text
		it.display_name = display_name
	($PortalGlow as Sprite2D).modulate = glow_tint
	($DiveGate as Sprite2D).modulate = gate_tint


## A2 contract: the detector announces the request; the owner (this portal) checks the
## id and acts. We ignore requests for other interactables and our own re-presses during
## the lockout. Mirrors extract_gate.gd:_on_interaction_requested verbatim, swapping the
## action (dive-launch) for the gate's extract.
func _on_interaction_requested(id: StringName, target: Node) -> void:
	if id != interactable_id:
		return
	# Only respond when WE are the focused target (guards against another same-id
	# interactable / stale id collision); the detector always passes the focused node.
	if target != null and target.get_parent() != self:
		return
	if _locked:
		return
	_locked = true
	_start_lockout()
	# Launch the dive through the M0 router. The router (App) listens for dive_requested,
	# swaps in main_game.tscn, and the dive self-starts its run. The portal does NOT call
	# start_run — run-state is the dive's, never the hub's.
	EventBus.dive_requested.emit(band_id)


## Arm the fat-finger lockout via a SceneTree timer (frame-rate independent, no polling).
## Copied from extract_gate.gd:_start_lockout. Under the persistent-root App router the
## portal is freed on the scene swap before this fires, which is harmless (the timer/
## callback go with it); the lockout only matters if the swap is somehow deferred.
func _start_lockout() -> void:
	var tree := get_tree()
	if tree == null:
		_locked = false
		return
	var timer := tree.create_timer(input_lockout_s)
	timer.timeout.connect(func() -> void: _locked = false)
