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
	EventBus.light_low.connect(_on_tension)
	EventBus.stamina_low.connect(_on_tension)

func _on_band_entered(_band_id: StringName, depth: int) -> void:
	current_intensity = depth  # TODO(M2): map depth -> AudioStreamSynchronized layer mix

func _on_tension() -> void:
	pass  # TODO(M2): nudge interactive transition / stinger

func _on_player_died(_cause: StringName) -> void:
	current_intensity = 0  # TODO(M2): resolve to surface/overworld bed
