class_name TelegraphFSM
extends OppositionComponent
## TelegraphFSM (S2) — the shared telegraph-PRESENTATION block: tell coloring and the
## tween juice extracted from the R1 dormant/awake tell flip (wake flash) and the
## K5b bomb's arming throb + blast flash.
##
## SCOPE NOTE (Resolved Decisions Q1, binding): state-advancement TIMING accumulators
## (the bomb's `_pulse_t`, R1's dormant latch) are HOST-side skeleton — "every
## accumulator increment/decrement site is transplanted line-for-line into the host".
## This component therefore owns the tells, never the logic clock: every method here
## is presentation-only by contract (headless/paused-safe — the color flip and the
## host's accumulator carry the state; the tweens are pure juice). S6a's Charger
## composes its telegraph→dash→recover timing in its own host/ChargeLane and drives
## these tells.
##
## Reused by: R1 (dormant/awake tell), bomb (arming throb + blast flash), Charger.
## Params read: `pulse_seconds` (the throb-period basis only).
## `tell` is assigned by the host (its Tell/Core Polygon2D — colors stay host consts,
## passed per call, so each entity keeps its exact legacy palette + tween shapes).

var tell: Polygon2D = null
var _pulse_seconds: float = 0.0
var _pulse_tween: Tween = null


func _configure(p: Dictionary, _ctx: Dictionary) -> void:
	_pulse_seconds = float(p.get("pulse_seconds", 0.0))


## Hard color flip (the R1/K5b tell idiom). Null-tell-safe like the legacy setters.
func set_tell_color(c: Color) -> void:
	if tell != null:
		tell.color = c


## One-shot scale flash (the R1 wake-flash shape: quick scale-up-and-settle).
## R1 wake: flash_scale(1.4, 0.08, 0.12). Pingpong-squash-shaped juice fits too.
func flash_scale(peak: float, up_s: float, down_s: float) -> void:
	if tell == null:
		return
	var tw := host.create_tween()
	tw.tween_property(tell, "scale", Vector2(peak, peak), up_s)
	tw.tween_property(tell, "scale", Vector2.ONE, down_s)


## Accelerating pulse throb (K5b arming): a looping scale throb whose period SHRINKS
## as detonation nears so the tempo itself reads "about to blow". Pure juice — the
## host's accumulator drives detonation, never this tween.
func start_throb() -> void:
	if tell == null:
		return
	_pulse_tween = host.create_tween().set_loops()     # loops until stop_throb()
	var period := maxf(_pulse_seconds, 0.1)
	for step: int in 4:
		var dur := (period / 8.0) * (1.0 - 0.18 * float(step))   # shrinking period
		_pulse_tween.tween_property(tell, "scale", Vector2(1.35, 1.35), dur * 0.5)
		_pulse_tween.tween_property(tell, "scale", Vector2.ONE, dur * 0.5)


func stop_throb() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()


## Brief one-shot explode flash (K5b: hot color + scale pop + alpha fade-out).
func blast_fade(c: Color, peak: float, up_s: float, fade_s: float) -> void:
	if tell == null:
		return
	tell.color = c
	var tw := host.create_tween()
	tw.tween_property(tell, "scale", Vector2(peak, peak), up_s)
	tw.tween_property(tell, "modulate:a", 0.0, fade_s)
