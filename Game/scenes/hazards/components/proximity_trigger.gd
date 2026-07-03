class_name ProximityTrigger
extends OppositionComponent
## ProximityTrigger (S2) — the K5b bomb's IDLE arm test, transplanted VERBATIM from
## bomb_hazard.gd's IDLE branch: distance from the host to the player CENTRE at/under
## `proximity_radius`. 0 radius = permanently inert (the legacy code-contract gate,
## bomb_hazard.gd IDLE branch). The rising-edge semantics live in the HOST's FSM
## (IDLE→PULSING is a one-way transition — the host stops asking once armed).
##
## Reused by: bomb; S6a's Charger (proximity/sightline arm before the telegraph).
## Params read: `proximity_radius`.

var _proximity_radius: float = 0.0


func _configure(p: Dictionary, _ctx: Dictionary) -> void:
	_proximity_radius = float(p.get("proximity_radius", 0.0))


func player_inside() -> bool:
	if _proximity_radius <= 0.0:
		return false                 # 0 = inert (legacy `> 0.0` gate, inverted guard)
	var d := host.global_position.distance_to(player.global_position)
	return d <= _proximity_radius
