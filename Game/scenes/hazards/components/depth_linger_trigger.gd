class_name DepthLingerTrigger
extends OppositionComponent
## DepthLingerTrigger (S2) — the R1 pursuer's awaken condition, transplanted VERBATIM
## from hazard_entity.gd `_should_awaken()`: live within-band depth reaching
## `depth_threshold` OR time-in-band reaching `linger_seconds` (>0) — first to fire.
## Records which condition fired in `pending_trigger` (&"depth"/&"linger") for the
## hazard_awoke telemetry. The DORMANT→AWAKE latch itself (no re-sleep) stays a HOST
## state flip — this block is the pure condition.
##
## Reused by: R1; S6a's Charger may reuse it as a proximity-free arm gate.
## Params read: `depth_threshold`, `linger_seconds`. The HOST passes the live depth
## and its own time-in-band accumulator (host-side skeleton, Resolved Decisions Q1).

var _depth_threshold: int = 0
var _linger_seconds: float = 0.0
var pending_trigger: StringName = &"depth"   # which condition fired (telemetry)


func _configure(p: Dictionary, _ctx: Dictionary) -> void:
	_depth_threshold = int(p.get("depth_threshold", 0))
	_linger_seconds = float(p.get("linger_seconds", 0.0))
	pending_trigger = &"depth"


func should_awaken(depth: int, time_in_band: float) -> bool:
	if depth >= _depth_threshold:
		pending_trigger = &"depth"
		return true
	if _linger_seconds > 0.0 and time_in_band >= _linger_seconds:
		pending_trigger = &"linger"
		return true
	return false
