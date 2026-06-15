extends Control
## DiveClockMeter — greybox view for the in-dive clock (A3). PURE VIEW: it holds
## no authoritative state, it just listens to EventBus.dive_clock_changed and
## mirrors the light fraction onto a ProgressBar. DiveClock is the single source
## of truth (TDD §2 signal-driven decoupling) — this never reads or writes it.
##
## Turns red under `warn_fraction` to flag low light. Greybox only; a human/asset
## role replaces the look later. Anchored to the top-right screen corner.

@onready var bar: ProgressBar = $ProgressBar

## Fraction of light at or below which the meter shows the warning color.
@export var warn_fraction: float = 0.25


func _ready() -> void:
	EventBus.dive_clock_changed.connect(_on_changed)


func _on_changed(current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current
	var frac: float = current / maximum if maximum > 0.0 else 0.0
	bar.modulate = Color.RED if frac <= warn_fraction else Color.WHITE
