class_name ExtractGate
extends Area2D
## ExtractGate — the M1 greybox extraction point (E1).
##
## The "safe exit" half of the push-your-luck loop: stepping up to it and pressing
## `interact` ends the run successfully and banks the carried junk into meta-state.
## One gate per band, placed at a fixed hand-authored location (decision #8); the
## offset constant lives on GameState (GATE_SPAWN_OFFSET).
##
## The gate is deliberately DUMB (E1 design note): it owns no save/meta logic and
## does not duplicate A2's selection. It registers an A2 Interactable child on the
## `interactable` layer (bit 3) so the player's InteractionDetector can focus it,
## listens for EventBus.interaction_requested(id, target), and when that id is its
## own it hands off entirely to GameState.extract_and_end_run(). GameState owns the
## run-state → meta-state transfer so extract (E1) and death/timeout (E3) share one
## "the run is ending; resolve the haul" path.
##
## Decision #5: extraction is INSTANT on a single press — no confirm dialog. A short
## input lockout right after a press absorbs fat-finger double-taps so a quick second
## press can't re-trigger an already-resolved extract.

## StringName the child Interactable is authored with; the gate only acts on its own.
@export var interactable_id: StringName = &"gate"

## Fat-finger lockout window (decision #5): 200–300 ms. After a successful extract
## interact, further interacts on this gate are ignored until the window elapses.
@export var input_lockout_s: float = 0.25

## True between an accepted interact and the lockout expiring.
var _locked: bool = false


func _ready() -> void:
	EventBus.interaction_requested.connect(_on_interaction_requested)


## A2 contract: the detector announces the request; the owner (this gate) checks the
## id and acts. We ignore requests for other interactables and our own re-presses
## during the lockout.
func _on_interaction_requested(id: StringName, target: Node) -> void:
	if id != interactable_id:
		return
	# Only respond when WE are the focused target (guards against another gate /
	# stale id collision); the detector always passes the focused Interactable.
	if target != null and target.get_parent() != self:
		return
	if _locked:
		return
	_locked = true
	_start_lockout()
	GameState.extract_and_end_run()


## Arm the fat-finger lockout. Uses a SceneTree timer so it is frame-rate
## independent and needs no _process polling.
func _start_lockout() -> void:
	var tree := get_tree()
	if tree == null:
		_locked = false
		return
	var timer := tree.create_timer(input_lockout_s)
	timer.timeout.connect(func() -> void: _locked = false)
