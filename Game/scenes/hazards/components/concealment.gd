class_name Concealment
extends OppositionComponent
## Concealment (S2-family, M1.10; FBM-A1) — the ONE new component of the Ambusher proof
## (T2a): the HIDDEN-state presentation + targetability gate that no shipped component
## does. Owns near-invisibility of the body, the alpha of the orange telegraph wedge, and
## a faint floor-tell decal, plus the un-hittable gate — held as BOTH `collision_layer`
## AND `"hazard"`-group membership on its own host node — toggled by reveal state.
##
## Everything else is reused verbatim: pounce = ChargeLane, arm = ProximityTrigger,
## kill = LethalContact(&"external"), tells = TelegraphFSM, throw-death = ThrowInteraction.
##
## WHY LAYER 0, NOT GROUP-ONLY (T2a Resolved Decisions OQ-10 amendment 2, BINDING):
## group-out alone stops a throw-KILL but not a throw-HIT — a hidden body left on
## collision_layer hazard(16) still fires ThrownItem.body_entered → _miss() (the item
## stops mid-air on empty floor and re-drops at the hidden Ambusher's feet: a free
## position-reveal that reads as a glitch), AND the player's body (mask includes
## hazard 16) collides with the invisible lump. Concealment therefore zeroes
## collision_layer while HIDDEN so a throw passes CLEAN THROUGH (no body_entered) and
## the body is no obstacle. T2b's Burrower reached the same layer-0 idiom independently
## — the wave ships ONE un-hittability rule.
##
## NOT a ticker: no _physics_process, no clock, no movement, no kill test, no
## EventBus. Pure presentation + targetability, driven by the host's hide_conceal()/
## reveal() calls off ChargeLane.on_state_changed. Headless/paused-safe — the
## collision_layer + group membership carry the state; the alpha fade is juice.
## RNG-FREE (no global RNG anywhere).

## The `hazard` collision layer bit (charger.tscn:9 / player mask). A resting-state
## write, not a RunConfig knob — the value that pairs with the "hazard" group so a
## revealed Ambusher is both a throw target AND solid debris.
const HAZARD_LAYER := 16

## Host-assigned nodes (the TelegraphFSM.tell idiom): the body silhouette + the faint
## floor decal. Colours/shapes stay host consts (S2 rule); this component only drives
## their `modulate.a`.
var body: Node2D = null            # the Polygon2D silhouette (host's $Body)
var floor_tell: Node2D = null      # the faint floor decal (host's $FloorTell)
var telegraph_tell: Node2D = null  # the orange telegraph wedge (host's $Tell) — alpha only

var _concealed_alpha := 0.0
var _tell_alpha := 0.28


func _configure(p: Dictionary, _ctx: Dictionary) -> void:
	_concealed_alpha = clampf(float(p.get("concealed_alpha", 0.0)), 0.0, 1.0)
	_tell_alpha = clampf(float(p.get("tell_alpha", 0.28)), 0.0, 1.0)


## HIDDEN: body near-invisible, faint floor tell shown, telegraph wedge invisible
## (alpha 0 — no floating "orange arrow at rest"), layer 0 + OUT of the "hazard" group →
## un-hittable (a throw passes clean through, no body_entered; the player does not
## collide with it). Non-lethal for free (no ChargeLane lethal test runs in DORMANT).
## The host seats this LAST in setup() (load-bearing — it neutralises the "hazard"
## group-add ChargeLane._configure does at bind, charge_lane.gd:104) and again on every
## re-hide of the stalker loop (each RECOVER → DORMANT after the first pounce).
func hide_conceal() -> void:
	_set_body_alpha(_concealed_alpha)
	_set_tell_alpha(_tell_alpha)
	_set_wedge_alpha(0.0)
	_set_targetable(false, 0)


## ARMED: the spring — reveal the body, drop the floor tell, show the telegraph wedge,
## restore layer hazard + JOIN the "hazard" group (now throw-killable AND solid). The
## host calls this on the ChargeLane TELEGRAPH transition; it stays in this state through
## POUNCE and EXPOSED (throw-killable across the whole revealed window).
func reveal() -> void:
	_set_body_alpha(1.0)
	_set_tell_alpha(0.0)
	_set_wedge_alpha(1.0)
	_set_targetable(true, HAZARD_LAYER)


## Throw-targetability query (tests + host): true iff the host is in the "hazard"
## group — the single predicate ThrownItem consults for a kill.
func is_hittable() -> bool:
	return host != null and host.is_in_group(&"hazard")


func _set_body_alpha(a: float) -> void:
	if body != null:
		body.modulate.a = a


func _set_tell_alpha(a: float) -> void:
	if floor_tell != null:
		floor_tell.modulate.a = a


## The telegraph wedge's alpha (host's $Tell). Concealment owns ONLY its visibility —
## TelegraphFSM still owns the wedge's colour/scale (host consts). Hidden = alpha 0 so a
## resting Ambusher shows no wedge at all; reveal restores it for the read.
func _set_wedge_alpha(a: float) -> void:
	if telegraph_tell != null:
		telegraph_tell.modulate.a = a


## Own-node targetability write: `in_group` gates the throw-KILL (ThrownItem's
## is_in_group(&"hazard") check, thrown_item.gd:79); `layer` gates physical presence
## (0 = ThrownItem/player mask no-match → clean pass-through; hazard = throw target +
## solid). Both properties on THIS host node only — zero shared-file edits.
func _set_targetable(in_group: bool, layer: int) -> void:
	if host == null:
		return
	if host is CollisionObject2D:
		(host as CollisionObject2D).collision_layer = layer
	if in_group and not host.is_in_group(&"hazard"):
		host.add_to_group(&"hazard")
	elif not in_group and host.is_in_group(&"hazard"):
		host.remove_from_group(&"hazard")
