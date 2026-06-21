extends Node
## AudioDirector — integration home for the native adaptive-music system
## (TDD §3/§4, research §9 `06_adaptive_audio_middleware_decision.md`).
##
## Built on Godot 4.x native audio: AudioStreamSynchronized (vertical stem
## layering), AudioStreamInteractive (beat-aligned transitions + stingers), and
## audio buses (per-band reverb/low-pass, SFX ducking). The "dread escalates by
## band" curve is driven off EventBus events.
##
## M0 stub: it wires the signals and tracks intensity; streams arrive in M2 when
## the audio subagent prototypes the band-escalation soundscape.

var current_intensity: int = 0  # 0..N, raised by band depth & combat

func _ready() -> void:
	EventBus.band_entered.connect(_on_band_entered)
	EventBus.player_died.connect(_on_player_died)
	EventBus.stamina_low.connect(_on_tension)
	# K4 (M1.4): the live near-end dive-clock warning. Supersedes the dead light_low()
	# signal K0 removed (this is the audio hook that signal used to feed). Gated inside the
	# handler on timer_warning_channel so visual_only runs stay silent here.
	EventBus.dive_clock_warning.connect(_on_clock_warning)

func _on_band_entered(_band_id: StringName, depth: int) -> void:
	current_intensity = depth  # TODO(M2): map depth -> AudioStreamSynchronized layer mix

func _on_tension() -> void:
	pass  # TODO(M2): nudge interactive transition / stinger


## K4 audio half of the near-end warning. GATED on timer_warning_channel == visual_audio (1)
## so audio only plays when the run config asks for it; visual_only runs stay silent. M1.4
## ships a no-op placeholder — AudioDirector is still an M0 stub (no real bus/SFX); M2 owns
## the actual "time low" stinger.
func _on_clock_warning(_seconds_remaining: float, _maximum: float) -> void:
	var cfg: RunConfig = GameState.active_run_config
	if cfg == null or not cfg.timer_enabled or cfg.timer_warning_channel != 1:
		return
	pass  # TODO(M2 / audio-designer): play the placeholder "time low" stinger via the audio bus.

func _on_player_died(_cause: StringName) -> void:
	current_intensity = 0  # TODO(M2): resolve to surface/overworld bed
