class_name ThrowInteraction
extends OppositionComponent
## ThrowInteraction (S2) — the entity-side half of the thrown-item death seam
## (breakdown amendment 4 / S2 Resolved Decisions Q5, locked shape).
##
## ThrownItem._hit_hazard consults the host via the duck-typed
## `resolve_throw_death(killer_ctx: Dictionary) -> bool` host method (a one-liner
## delegating here). Contract: return TRUE = "I handled my own death — do not free
## me again"; FALSE = the thrower performs today's queue_free(), byte-identical.
##
## Mode &"die" (all four legacy hazards, S2): always returns false — the thrower
## frees the host on the same frame, in the same call order as before the seam
## existed. S6b's Splitter assigns `death_handler` (split via svc.spawn + free self
## + return true) with ZERO further thrown_item.gd edits.
##
## Params read: `throw_mode` (&"die" only in S2). `killer_ctx` is primitives-only:
## {item_id, kind, depth, run_t_ms}.

var _mode: StringName = &"die"

## S6b seam: when valid, called with killer_ctx; its bool return IS the resolution.
var death_handler: Callable = Callable()


func _configure(p: Dictionary, _ctx: Dictionary) -> void:
	_mode = StringName(p.get("throw_mode", &"die"))


func resolve_throw_death(killer_ctx: Dictionary) -> bool:
	if death_handler.is_valid():
		return bool(death_handler.call(killer_ctx))
	return false   # mode &"die": the thrower frees us — today's behaviour, verbatim
