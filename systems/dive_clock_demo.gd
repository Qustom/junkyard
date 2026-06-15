extends Node2D
## DiveClockDemo — tiny driver that makes the in-dive clock observable in-editor.
## Kicks a run via GameState (the sole emitter of run_started) on load so the
## DiveClock child resets and the meter starts draining. Press R to restart the
## dive (re-arms the timeout guard); watch the bar turn red under 25% and the
## console log dive_clock_timeout once at zero. Pure demo — not shipped.


func _ready() -> void:
	EventBus.dive_clock_timeout.connect(_on_timeout)
	_start()


func _start() -> void:
	GameState.start_run(&"demo_band", 1)


func _on_timeout() -> void:
	print("DiveClockDemo: dive_clock_timeout received — light exhausted.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_start()
